--!strict
-- Effects every station shares: sounds, the "huss" bubble, the hand position, and the
-- "ahh almost almost" moment (bubble + camera punch, at most once every 20 s).
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

-- Creator Store sound effects (free to use in experiences). Swap for our own recordings later.
local SOUND_IDS = {
	huss = "rbxassetid://9113702955", -- Pro Sound Effects: airy breath exhale
	bounce = "rbxassetid://377958030", -- basketball bounce
	rim = "rbxassetid://81912260477958", -- brick rim hit
	clank = "rbxassetid://9116717775", -- Pro Sound Effects: metal knock
	wrap = "rbxassetid://9117410302", -- Pro Sound Effects: cellophane crunch
	thud = "rbxassetid://9119342958", -- Pro Sound Effects: muted thud
	kick = "rbxassetid://9119342958", -- the beat (same muted thud, its own Sound so they don't cut)
	clap = "rbxassetid://9114771714", -- Pro Sound Effects: hand slap claps; skill beats
	tempo = "rbxassetid://9113551773", -- Pro Sound Effects: boom thump; "TEMPO UP!"
}

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
	sound.Volume = if name == "huss" then 0.5 else 0.7
	sound.Parent = SoundService
	sounds[name] = sound
end

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

-- Every hit: breath sound with a little pitch variety and the "huss" bubble.
function StationFx.huss()
	StationFx.play("huss", 0.9 + math.random() * 0.25)
	StationFx.say("huss", false)
end

local lastAlmost = -math.huge
-- A near miss on the skill move. Rate-limited so it stays funny.
function StationFx.almost()
	if os.clock() - lastAlmost < ALMOST_COOLDOWN then
		return
	end
	lastAlmost = os.clock()
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
