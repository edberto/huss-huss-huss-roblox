--!strict
-- Street dressing built at server start, so a code publish carries it (no manual place edit):
-- dancers on the party lawn, string lights, speaker, light beams, confetti, parked cars and
-- trees. Also the partier look (glow sticks) for anyone who gives in.
local Players = game:GetService("Players")

local Decor = {}

local DANCES = { "rbxassetid://507771019", "rbxassetid://507776043", "rbxassetid://507777268" }
local PARTY_COLORS = {
	Color3.fromRGB(255, 70, 200),
	Color3.fromRGB(80, 220, 255),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(150, 90, 255),
}

local folder = Instance.new("Folder")
folder.Name = "Decor"
folder.Parent = workspace

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = props.Parent or folder
	return p
end

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

-- Two neon glow sticks, welded to the hands. Removed with the character at Dusk.
function Decor.dressPartier(character: Model)
	if character:FindFirstChild("GlowStick") then
		return
	end
	for _, handName in { "LeftHand", "RightHand" } do
		local hand = character:FindFirstChild(handName) :: BasePart?
		if hand then
			local stick = part({
				Name = "GlowStick",
				Anchored = false,
				CanCollide = false,
				Massless = true,
				Material = Enum.Material.Neon,
				Color = pick(PARTY_COLORS),
				Size = Vector3.new(0.25, 1.6, 0.25),
				CFrame = hand.CFrame * CFrame.new(0, -0.5, 0),
				Parent = character,
			})
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = hand, stick
			weld.Parent = stick
		end
	end
end

local function dancer(at: CFrame, index: number)
	local description = Instance.new("HumanoidDescription")
	local skin = pick({
		Color3.fromRGB(234, 184, 146),
		Color3.fromRGB(160, 110, 80),
		Color3.fromRGB(105, 70, 50),
		Color3.fromRGB(250, 210, 180),
	})
	description.HeadColor, description.LeftArmColor, description.RightArmColor = skin, skin, skin
	description.TorsoColor = pick(PARTY_COLORS)
	description.LeftLegColor = Color3.fromRGB(40, 40, 60)
	description.RightLegColor = description.LeftLegColor
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = `Dancer{index}`
	model:PivotTo(at)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	model.Parent = folder
	Decor.dressPartier(model)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = DANCES[(index - 1) % #DANCES + 1]
	local track = (animator :: Animator):LoadAnimation(animation)
	track.Looped = true
	track:Play()
end

local function car(at: CFrame, color: Color3)
	part({
		Name = "CarBody",
		Size = Vector3.new(9, 2, 4.4),
		CFrame = at * CFrame.new(0, 1.6, 0),
		Color = color,
	})
	part({
		Name = "CarCabin",
		Size = Vector3.new(5, 1.8, 4),
		CFrame = at * CFrame.new(-0.5, 3.4, 0),
		Color = Color3.fromRGB(30, 40, 70),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
	})
	for _, x in { -3, 3 } do
		for _, z in { -2.2, 2.2 } do
			part({
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.8, 1.8, 1.8),
				CFrame = at * CFrame.new(x, 0.9, z) * CFrame.Angles(0, math.rad(90), 0),
				Color = Color3.fromRGB(25, 25, 30),
				CanCollide = false,
			})
		end
	end
end

local function tree(x: number, z: number)
	local height = math.random(9, 14)
	part({
		Name = "Trunk",
		Size = Vector3.new(1.4, height, 1.4),
		Position = Vector3.new(x, height / 2, z),
		Color = Color3.fromRGB(80, 55, 45),
	})
	part({
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * math.random(8, 11),
		Position = Vector3.new(x, height + 2, z),
		Color = Color3.fromRGB(40, 70, 75),
		CanCollide = false,
	})
end

function Decor.build()
	local party = workspace:WaitForChild("Town"):WaitForChild("PartyHouse")
	-- Dancers replace the placeholder guest blocks, facing the street (+x).
	local index = 0
	for _, guest in party:GetChildren() do
		if guest.Name == "Guest" and guest:IsA("BasePart") then
			index += 1
			local at = guest.Position + Vector3.new(0, 1, 0)
			guest:Destroy()
			dancer(CFrame.lookAt(at, at + Vector3.new(1, 0, math.random(-3, 3) / 10)), index)
		end
	end

	-- String lights along the front roof edge and down both sides of the porch.
	for z = -21, 9, 2 do
		part({
			Name = "Bulb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.7,
			Position = Vector3.new(-137.5, 14.2 - math.abs(((z + 21) % 6) - 3) * 0.25, z),
			Material = Enum.Material.Neon,
			Color = PARTY_COLORS[(z // 2) % #PARTY_COLORS + 1],
			CanCollide = false,
		})
	end

	-- Speaker stack on the lawn.
	local speaker = part({
		Name = "Speaker",
		Size = Vector3.new(3, 7, 4),
		Position = Vector3.new(-129, 4, 4),
		Color = Color3.fromRGB(20, 20, 26),
	})
	for _, y in { 2, -1.5 } do
		part({
			Name = "Cone",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 2.4, 2.4),
			CFrame = speaker.CFrame * CFrame.new(1.55, y, 0),
			Material = Enum.Material.Neon,
			Color = PARTY_COLORS[1],
			CanCollide = false,
		})
	end

	-- Two light beams from the roof into the sky.
	for i, z in { -16, 4 } do
		part({
			Name = "Beam",
			Size = Vector3.new(1.2, 60, 1.2),
			CFrame = CFrame.new(-146, 46, z)
				* CFrame.Angles(math.rad(if i == 1 then -14 else 14), 0, math.rad(-10)),
			Material = Enum.Material.Neon,
			Color = PARTY_COLORS[i + 1],
			Transparency = 0.6,
			CanCollide = false,
			CanQuery = false,
		})
	end

	-- Confetti over the lawn.
	local emitterPart = part({
		Name = "Confetti",
		Size = Vector3.new(12, 1, 14),
		Position = Vector3.new(-133, 16, -6),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local confetti = Instance.new("ParticleEmitter")
	confetti.Rate = 25
	confetti.Lifetime = NumberRange.new(4, 6)
	confetti.Speed = NumberRange.new(1, 3)
	confetti.SpreadAngle = Vector2.new(30, 30)
	confetti.EmissionDirection = Enum.NormalId.Bottom
	confetti.Acceleration = Vector3.new(0, -2, 0)
	confetti.Rotation = NumberRange.new(0, 360)
	confetti.RotSpeed = NumberRange.new(-180, 180)
	confetti.Size = NumberSequence.new(0.25)
	confetti.LightEmission = 0.6
	confetti.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PARTY_COLORS[1]),
		ColorSequenceKeypoint.new(0.33, PARTY_COLORS[2]),
		ColorSequenceKeypoint.new(0.66, PARTY_COLORS[3]),
		ColorSequenceKeypoint.new(1, PARTY_COLORS[4]),
	})
	confetti.Parent = emitterPart

	-- Parked cars at the curbs, clear of every driveway (scripts/build_scene.luau HOME_XS).
	local carColors = {
		Color3.fromRGB(200, 60, 60),
		Color3.fromRGB(60, 110, 200),
		Color3.fromRGB(235, 235, 230),
	}
	for i, x in { -99, -27, 45 } do
		car(CFrame.new(x, 0, -1.8), carColors[i])
	end
	for i, x in { -85, -13, 59 } do
		car(CFrame.new(x, 0, -10.2) * CFrame.Angles(0, math.pi, 0), carColors[(i % 3) + 1])
	end

	-- Trees behind both rows of houses.
	for x = -128, 92, 20 do
		tree(x + math.random(-3, 3), 52 + math.random(-2, 2))
		tree(x + 10 + math.random(-3, 3), -64 + math.random(-2, 2))
	end
end

return Decor
