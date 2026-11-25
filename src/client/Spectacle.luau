--!strict
-- The sky over the party house: the floating leaderboards bob and flip when they change
-- category (tag "FloatBoard"), tapping one opens the Ranks panel on that category, and the
-- server's Fireworks event fires rockets that burst above the boards.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Ranks = require(script.Parent.Ranks)

local FLIP_TIME = 0.6
local FIREWORK_SOUND = "rbxassetid://117443960759635"
local COLORS = {
	Color3.fromHex("FF50C8"),
	Color3.fromHex("50DCFF"),
	Color3.fromHex("FFE63C"),
	Color3.fromHex("5AF0A0"),
	Color3.fromHex("FF8C32"),
}

local Spectacle = {}

local flipping: { [BasePart]: number } = {}

local function watch(board: Instance)
	if not board:IsA("BasePart") then
		return
	end
	board:GetAttributeChangedSignal("Category"):Connect(function()
		flipping[board] = os.clock()
	end)
	local click = board:FindFirstChildOfClass("ClickDetector")
	if click then
		click.MouseClick:Connect(function()
			Ranks.open(board:GetAttribute("Category"))
		end)
	end
end

local function burst(at: Vector3, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = at - Vector3.new(0, 30, 0)
	anchor.Parent = workspace
	-- The rocket: a glowing trail climbing to the burst point.
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.3, 0), Vector3.new(0, -0.3, 0)
	a0.Parent, a1.Parent = anchor, anchor
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 1
	trail.Lifetime = 0.4
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = anchor
	local rise = TweenService:Create(anchor, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = at,
	})
	rise:Play()
	rise.Completed:Connect(function()
		local sparks = Instance.new("ParticleEmitter")
		sparks.Acceleration = Vector3.new(0, -12, 0)
		sparks.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		sparks.Drag = 2.5
		sparks.Enabled = false
		sparks.LightEmission = 1
		sparks.Lifetime = NumberRange.new(1, 1.6)
		sparks.Size = NumberSequence.new(0.9, 0)
		sparks.Speed = NumberRange.new(28, 40)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Transparency = NumberSequence.new(0, 1)
		sparks.Parent = anchor
		sparks:Emit(140)
		local light = Instance.new("PointLight")
		light.Brightness = 4
		light.Color = color
		light.Range = 40
		light.Parent = anchor
		TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()
		local boom = Instance.new("Sound")
		boom.SoundId = FIREWORK_SOUND
		boom.Volume = 0.5
		boom.PlaybackSpeed = 0.9 + math.random() * 0.25
		boom.Parent = SoundService
		SoundService:PlayLocalSound(boom)
		Debris:AddItem(boom, 3)
	end)
	Debris:AddItem(anchor, 3.5)
end

-- A short volley over the boards; bigger at Dawn.
function Spectacle.fireworks(count: number)
	local center = workspace:FindFirstChild("Town") and workspace.Town:FindFirstChild("Board_Center") :: BasePart?
	if not center then
		return
	end
	for i = 1, count do
		task.delay((i - 1) * 0.35, function()
			local offset = center.CFrame.RightVector * math.random(-40, 40) + Vector3.new(0, math.random(22, 40), 0)
			burst(center.Position + offset, COLORS[math.random(#COLORS)])
		end)
	end
end

function Spectacle.start()
	for _, board in CollectionService:GetTagged("FloatBoard") do
		watch(board)
	end
	CollectionService:GetInstanceAddedSignal("FloatBoard"):Connect(watch)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, board in CollectionService:GetTagged("FloatBoard") do
			local base, phase = board:GetAttribute("Base"), board:GetAttribute("Phase")
			if board:IsA("BasePart") and typeof(base) == "CFrame" and typeof(phase) == "number" then
				local spin = 0
				local started = flipping[board]
				if started then
					local p = (t - started) / FLIP_TIME
					if p >= 1 then
						flipping[board] = nil
					else
						spin = math.sin(p * math.pi) * 0.5 * math.pi * (1 - p) -- a quick wobble-flip
					end
				end
				board.CFrame = base
					* CFrame.new(0, math.sin(t * 1.1 + phase) * 0.8, 0)
					* CFrame.Angles(0, math.sin(t * 0.6 + phase) * 0.05 + spin, 0)
			end
		end
	end)
	local folder = ReplicatedStorage:WaitForChild("Leaderboards")
	local event = folder:WaitForChild("Fireworks") :: RemoteEvent
	event.OnClientEvent:Connect(function(reason: string)
		Spectacle.fireworks(if reason == "Dawn" then 10 else 6)
	end)
end

return Spectacle
