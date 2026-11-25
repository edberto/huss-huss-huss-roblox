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

-- Speech bubble over the head: small "huss" or the big "ahh almost almost".
local bubble = Instance.new("BillboardGui")
bubble.Size = UDim2.fromOffset(160, 50)
bubble.StudsOffset = Vector3.new(0, 3.2, 0)
bubble.AlwaysOnTop = true
local bubbleText = Ui.label({
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Ui.colors.cream,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.5, 0.6),
	TextColor3 = Ui.colors.navy,
	TextTransparency = 1,
	Parent = bubble,
}, { Ui.make("UICorner", { CornerRadius = UDim.new(0.4, 0) }) })

function StationFx.say(text: string, big: boolean)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	bubble.Adornee = head or (character and character.PrimaryPart)
	bubble.Parent = player:FindFirstChildOfClass("PlayerGui")
	bubbleText.Text = text
	bubbleText.Size = if big then UDim2.fromScale(1, 0.9) else UDim2.fromScale(0.5, 0.6)
	bubbleText.TextTransparency = 0
	bubbleText.BackgroundTransparency = 0
	local fade =
		TweenInfo.new(if big then 1.4 else 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(bubbleText, fade, { TextTransparency = 1, BackgroundTransparency = 1 })
		:Play()
end

-- Every hit: the next take in order, so steady hits say "huss huss huss" (1-3), then again (4-6).
-- After a pause, start a fresh phrase rather than finishing the old one.
local hussIndex, lastHuss = 0, -math.huge
function StationFx.huss()
	if os.clock() - lastHuss > 1.5 and hussIndex % 3 ~= 0 then
		hussIndex += 3 - hussIndex % 3
	end
	lastHuss = os.clock()
	hussIndex = hussIndex % 6 + 1
	StationFx.play("huss" .. hussIndex)
	StationFx.say("huss", false)
end

local lastAlmost = -math.huge
-- A near miss on the skill move. Rate-limited so it stays funny.
function StationFx.almost()
	if os.clock() - lastAlmost < ALMOST_COOLDOWN then
		return
	end
	lastAlmost = os.clock()
	StationFx.play("almost")
	StationFx.say("ahh almost almost", true)
	local camera = workspace.CurrentCamera
	local punch = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
	TweenService:Create(camera, punch, { FieldOfView = camera.FieldOfView - 8 }):Play()
end

-- Just below the right hand, or in front of the player's right side for avatars without one.
function StationFx.handPosition(): Vector3?
	local character = player.Character
	local hand = character
		and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if hand and hand:IsA("BasePart") then
		return hand.Position - Vector3.new(0, hand.Size.Y / 2 + 0.6, 0)
	end
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
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
