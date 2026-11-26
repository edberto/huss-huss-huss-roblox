--!strict
-- Effects every station shares: sounds, the "huss" bubble, the hand position, and the
-- "ahh almost almost" moment (bubble + camera punch, at most once every 20 s).
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

-- huss1-6 and almost: our own recordings (assets/audio). 1-3 and 4-6 are each one "huss huss huss" phrase.
-- The rest are Creator Store sound effects (free to use in experiences).
local SOUND_IDS = {
	huss1 = "rbxassetid://90960262508418",
	huss2 = "rbxassetid://71869590388356",
	huss3 = "rbxassetid://116677625462859",
	huss4 = "rbxassetid://96533280196463",
	huss5 = "rbxassetid://71587162942892",
	huss6 = "rbxassetid://97272623021431",
	almost = "rbxassetid://71905871777804", -- our "ahh almost almost"
	hat = "rbxassetid://83093406318494", -- training groove, synthesized (scripts/beat_samples.py)
	bass = "rbxassetid://114400841827078",
	stab = "rbxassetid://103199292468203",
	bounce = "rbxassetid://377958030", -- basketball bounce
	rim = "rbxassetid://81912260477958", -- brick rim hit
	clank = "rbxassetid://9116717775", -- Pro Sound Effects: metal knock
	wrap = "rbxassetid://9117410302", -- Pro Sound Effects: cellophane crunch
	thud = "rbxassetid://9119342958", -- Pro Sound Effects: muted thud
	kick = "rbxassetid://128535338677323", -- the beat: our punchy kick, audible on phone speakers
	clap = "rbxassetid://9114771714", -- Pro Sound Effects: hand slap claps; skill beats
	tempo = "rbxassetid://9113551773", -- Pro Sound Effects: boom thump; "TEMPO UP!"
}

local VOLUMES = { kick = 1, hat = 0.5, bass = 0.8, stab = 0.5, clap = 0.9 }
-- The training groove; Settings → BEAT scales these (player attribute "Vol_beat", 0-2) and
-- SOUNDS scales the rest: the voice and effects ("Vol_sfx").
local BEAT = { kick = true, hat = true, bass = true, stab = true, clap = true }

local ALMOST_COOLDOWN = 20

local StationFx = {}

-- What every station module's start() returns.
export type Station =
	{ onResult: (grade: string, skill: boolean) -> (), setActive: (boolean) -> () }

local sounds: { [string]: Sound } = {}
for name, id in SOUND_IDS do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	VOLUMES[name] = VOLUMES[name] or if string.find(name, "^huss") then 0.6 else 0.7
	sound.Parent = SoundService
	sounds[name] = sound
end
local function applyVolumes()
	local beat = tonumber(player:GetAttribute("Vol_beat")) or 1
	local sfx = tonumber(player:GetAttribute("Vol_sfx")) or 1
	for name, sound in sounds do
		sound.Volume = VOLUMES[name] * if BEAT[name] then beat else sfx
	end
end
player:GetAttributeChangedSignal("Vol_beat"):Connect(applyVolumes)
player:GetAttributeChangedSignal("Vol_sfx"):Connect(applyVolumes)
applyVolumes()

function StationFx.play(name: string, pitch: number?)
	local sound = sounds[name]
	if sound then
		sound.PlaybackSpeed = pitch or 1
		SoundService:PlayLocalSound(sound)
	end
end

-- Over the head: a "HUSS!" pop per hit (each one lands at a slightly different spot and angle,
-- so a run of hits stacks up like comic sound effects) and the big "ahh almost almost" bubble.
-- PlayerGui clears the BillboardGui when the character respawns (every Dusk), so it's rebuilt
-- whenever it's gone; reusing the destroyed one errored and stopped every station's hit
-- animation after the first night.
local bubble: BillboardGui, bubbleText: TextLabel
local function newBubble()
	bubble = Instance.new("BillboardGui")
	bubble.Size = UDim2.fromOffset(240, 120)
	bubble.StudsOffset = Vector3.new(0, 3.6, 0)
	bubble.AlwaysOnTop = true
	bubble.ResetOnSpawn = false
	bubbleText = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Ui.colors.cream,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(170, 48),
		TextColor3 = Ui.colors.navy,
		TextTransparency = 1,
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = bubble,
	}, { Ui.make("UICorner", { CornerRadius = UDim.new(0.4, 0) }) })
end
newBubble()

local function attach()
	local ok = pcall(function()
		bubble.Parent = player:FindFirstChildOfClass("PlayerGui")
	end)
	if not ok then
		newBubble()
		bubble.Parent = player:FindFirstChildOfClass("PlayerGui")
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	bubble.Adornee = head or (character and character.PrimaryPart)
end

function StationFx.say(text: string)
	attach()
	bubbleText.Text = text
	bubbleText.TextTransparency = 0
	bubbleText.BackgroundTransparency = 0
	local fade = TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(bubbleText, fade, { TextTransparency = 1, BackgroundTransparency = 1 })
		:Play()
end

local POP_COLORS = { Color3.fromHex("FFD75A"), Color3.new(1, 1, 1), Color3.fromHex("3DFFB0") }
-- One "HUSS!": pops in at a random spot near the middle with a slight tilt, drifts up, fades.
function StationFx.pop()
	attach()
	local label = Ui.shout({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(
			0.5 + (math.random() - 0.5) * 0.4,
			0.5 + (math.random() - 0.5) * 0.4
		),
		Rotation = math.random(-14, 14),
		Size = UDim2.fromOffset(110, 40),
		Text = "HUSS!",
		TextColor3 = POP_COLORS[math.random(#POP_COLORS)],
		Thickness = 3,
		Parent = bubble,
	})
	local scale = Ui.make("UIScale", { Scale = 0.4, Parent = label })
	local stroke = label:FindFirstChildOfClass("UIStroke") :: UIStroke
	TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local fade = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.15)
	TweenService:Create(label, fade, {
		TextTransparency = 1,
		Position = label.Position - UDim2.fromScale(0, 0.12),
	}):Play()
	TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	task.delay(0.75, label.Destroy, label)
end

-- The meme rhythm: three hits each say one "huss", the fourth says the whole "huss huss huss"
-- at once. Takes 1-3 and 4-6 are two recordings of the phrase; each round of four uses one for
-- the singles and the other for the phrase, then they swap. While the phrase plays, the next
-- hit keeps quiet (its pop still shows) so voices don't pile up. A pause over 1.5 s starts over.
local PHRASE_GAP = 0.16 -- takes are ~0.2 s; tight so the phrase ends before the next bar starts
local hits, round, lastHuss, quietUntil = 0, 0, -math.huge, 0
function StationFx.huss()
	local now = os.clock()
	if now - lastHuss > 1.5 then
		hits = 0
	end
	lastHuss = now
	hits += 1
	local singles = if round % 2 == 0 then 0 else 3 -- take offset for this round's singles
	if hits <= 3 then
		if now >= quietUntil then
			StationFx.play("huss" .. singles + hits)
		end
		StationFx.pop()
		return
	end
	local phrase = 3 - singles
	for k = 1, 3 do
		task.delay((k - 1) * PHRASE_GAP, function()
			StationFx.play("huss" .. phrase + k)
			StationFx.pop()
		end)
	end
	quietUntil = now + 2 * PHRASE_GAP + 0.05 -- until the last take has started
	hits, round = 0, round + 1
end

local lastAlmost = -math.huge
-- A near miss on the skill move. Rate-limited so it stays funny.
function StationFx.almost()
	if os.clock() - lastAlmost < ALMOST_COOLDOWN then
		return
	end
	lastAlmost = os.clock()
	StationFx.play("almost")
	StationFx.say("ahh almost almost")
	local camera = workspace.CurrentCamera
	local punch = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
	TweenService:Create(camera, punch, { FieldOfView = camera.FieldOfView - 8 }):Play()
end

-- Just below the right hand, or in front of the player's right side for avatars without one.
function StationFx.handPosition(): Vector3?
	local character = player.Character
	local hand = character
		and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hand and hand:IsA("BasePart") then
		local at = hand.Position - Vector3.new(0, hand.Size.Y / 2 + 0.6, 0)
		-- Avatars whose hands hang near the floor would hold the ball under the driveway.
		local floor = if root then root.Position.Y - 2 else at.Y
		return Vector3.new(at.X, math.max(at.Y, floor), at.Z)
	end
	if not root then
		return nil
	end
	return (root.CFrame * CFrame.new(1.6, -0.6, -1.4)).Position
end

function StationFx.rootCFrame(): CFrame?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.CFrame
end

return StationFx
