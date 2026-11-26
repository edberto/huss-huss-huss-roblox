--!strict
-- The neighbourhood around scripts/build_scene.luau's street, built at server start so a code
-- publish carries it (no manual place edit): grass, sidewalks, yards (mailboxes, bushes,
-- trees, flowers, name signs), fences, a cul-de-sac, tree belts with fields of mixed trees,
-- rocks, flowers and fireflies, and a distant skyline; the party (dancers, DJ, light-up dance
-- floor, lights, speaker, beams, confetti, balloons, entrance arch, backyard pool) and parked
-- cars. Also the partier look (glow sticks).
-- Yard props don't collide: NPC partiers walk straight at trainers and must never get stuck.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Looks = require(script.Parent.Looks)

local Decor = {}

local DANCES = { "rbxassetid://507771019", "rbxassetid://507776043", "rbxassetid://507777268" }
local PARTY_COLORS = {
	Color3.fromRGB(255, 70, 200),
	Color3.fromRGB(80, 220, 255),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(150, 90, 255),
}

-- Layout from scripts/build_scene.luau.
local HOME_XS = { -110, -74, -38, -2, 34, 70 }
local STREET_WEST, STREET_EAST = -140, 110 -- street spans z -13..1

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
	local ok, created = pcall(
		Players.CreateHumanoidModelFromDescription,
		Players,
		Looks.random(),
		Enum.HumanoidRigType.R15
	)
	if not ok then
		return
	end
	local model = created :: Model
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

-- Cars don't collide: NPC partiers walk straight at trainers (no pathfinding) and must not
-- get stuck on one.
local function car(at: CFrame, color: Color3)
	part({
		Name = "CarBody",
		Size = Vector3.new(9, 2, 4.4),
		CFrame = at * CFrame.new(0, 1.6, 0),
		Color = color,
		CanCollide = false,
	})
	part({
		Name = "CarCabin",
		Size = Vector3.new(5, 1.8, 4),
		CFrame = at * CFrame.new(-0.5, 3.4, 0),
		Color = Color3.fromRGB(30, 40, 70),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		CanCollide = false,
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

-- Three kinds of tree, mixed: round, pine (stacked turned blocks) and pink blossom.
local LEAF_GREENS = { Color3.fromRGB(40, 70, 75), Color3.fromRGB(45, 85, 60), Color3.fromRGB(55, 90, 50) }
local BLOSSOM = { Color3.fromRGB(235, 140, 185), Color3.fromRGB(245, 175, 205) }
local function tree(x: number, z: number, kind: string?)
	kind = kind or pick({ "round", "round", "round", "pine", "pine", "blossom" })
	local height = if kind == "pine" then math.random(6, 9) else math.random(9, 14)
	local trunk = part({
		Name = "Trunk",
		Size = Vector3.new(1.4, height, 1.4),
		Position = Vector3.new(x, height / 2, z),
		Color = Color3.fromRGB(80, 55, 45),
	})
	if kind == "pine" then
		local turn = math.random() * math.pi
		for i, width in { 9, 7, 5, 3 } do
			part({
				Name = "Needles",
				Size = Vector3.new(width, 3.2, width),
				CFrame = CFrame.new(x, height - 1 + i * 2.6, z) * CFrame.Angles(0, turn + i * 0.4, 0),
				Color = Color3.fromRGB(30, 70, 55),
				CanCollide = false,
			})
		end
	elseif kind == "blossom" then
		local size = math.random(8, 10)
		part({
			Name = "Blossom",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			Position = Vector3.new(x, height + 2, z),
			Color = pick(BLOSSOM),
			CanCollide = false,
		})
		for _ = 1, 3 do
			part({
				Name = "Blossom",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * (size * 0.55),
				Position = Vector3.new(x, height + 2, z)
					+ Vector3.new(math.random(-3, 3), math.random(-1, 2), math.random(-3, 3)),
				Color = pick(BLOSSOM),
				CanCollide = false,
			})
		end
	else
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * math.random(8, 11),
			Position = Vector3.new(x, height + 2, z),
			Color = pick(LEAF_GREENS),
			CanCollide = false,
		})
	end
	return trunk
end

-- A patch of flowers: small coloured heads on short stems around `center`.
local FLOWER_COLORS = {
	Color3.fromRGB(255, 90, 120),
	Color3.fromRGB(255, 210, 70),
	Color3.fromRGB(190, 120, 255),
	Color3.fromRGB(255, 255, 240),
	Color3.fromRGB(255, 150, 60),
}
local function flowers(center: Vector3, radius: number, count: number)
	local color = pick(FLOWER_COLORS)
	for _ = 1, count do
		local angle, distance = math.random() * math.pi * 2, math.sqrt(math.random()) * radius
		local at = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		part({
			Name = "Flower",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (0.55 + math.random() * 0.25),
			Position = at + Vector3.new(0, 0.7 + math.random() * 0.3, 0),
			Color = if math.random() < 0.2 then pick(FLOWER_COLORS) else color,
			CanCollide = false,
			CastShadow = false,
		})
	end
end

local function rock(x: number, z: number)
	local size = math.random(15, 35) / 10
	part({
		Name = "Rock",
		Size = Vector3.new(size * 1.4, size, size * 1.1),
		CFrame = CFrame.new(x, size * 0.35, z)
			* CFrame.Angles(math.random() * 0.4, math.random() * math.pi, math.random() * 0.4),
		Color = Color3.fromRGB(95, 98, 108),
		Material = Enum.Material.Slate,
		CanCollide = false,
	})
end

-- Fireflies drifting over the grass: a slow, faint particle glow.
local function fireflies(center: Vector3, size: Vector3)
	local zone = part({
		Name = "Fireflies",
		Size = size,
		Position = center,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 4
	emitter.Lifetime = NumberRange.new(4, 7)
	emitter.Speed = NumberRange.new(0.3, 0.8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.25),
		NumberSequenceKeypoint.new(0.7, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(220, 255, 120))
	emitter.LightEmission = 1
	emitter.Brightness = 3
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Parent = zone
end

-- Balloons on strings, tied at `at`.
local function balloons(at: Vector3)
	for i = 1, 5 do
		local top = at + Vector3.new(math.random(-12, 12) / 10, 6 + i * 0.5, math.random(-12, 12) / 10)
		part({
			Name = "Balloon",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.7, 2, 1.7),
			Position = top,
			Color = PARTY_COLORS[(i - 1) % #PARTY_COLORS + 1],
			Reflectance = 0.15,
			CanCollide = false,
		})
		local length = (top - at).Magnitude
		part({
			Name = "String",
			Size = Vector3.new(0.06, length, 0.06),
			CFrame = CFrame.lookAt((at + top) / 2, top) * CFrame.Angles(math.rad(90), 0, 0),
			Color = Color3.fromRGB(240, 240, 240),
			CanCollide = false,
			CastShadow = false,
		})
	end
end

-- A sign with the same text on both faces.
local function signText(sign: BasePart, text: string, color: Color3): { TextLabel }
	local labels = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Face = face
		surface.PixelsPerStud = 40
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
		label.Text = text
		label.TextColor3 = color
		label.TextScaled = true
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Parent = label
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0.12, 0)
		padding.PaddingBottom = UDim.new(0.06, 0)
		padding.PaddingLeft = UDim.new(0.04, 0)
		padding.PaddingRight = UDim.new(0.04, 0)
		padding.Parent = label
		label.Parent = surface
		surface.Parent = sign
		table.insert(labels, label)
	end
	return labels
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

	-- Four light beams from the roof ridge. Each client sweeps them (init.client: PartyBeam tag)
	-- around their "Base"; the server only places them.
	for i, z in { -18, -10, -2, 6 } do
		local base = CFrame.new(-150, 17, z)
		local beam = part({
			Name = "Beam",
			Size = Vector3.new(1.2, 60, 1.2),
			CFrame = base * CFrame.new(0, 30, 0),
			Material = Enum.Material.Neon,
			Color = PARTY_COLORS[(i - 1) % #PARTY_COLORS + 1],
			Transparency = 0.6,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		beam:SetAttribute("Base", base)
		beam:SetAttribute("Phase", i * 1.7)
		CollectionService:AddTag(beam, "PartyBeam")
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

	-- Light-up dance floor under the dancers (each client cycles the tiles: DanceTile tag).
	part({
		Name = "DanceFloorBase",
		Size = Vector3.new(8, 0.85, 24),
		Position = Vector3.new(-138, 0.425, -5),
		Color = Color3.fromRGB(20, 18, 30),
	})
	for column = 0, 3 do
		for row = 0, 11 do
			local tile = part({
				Name = "DanceTile",
				Size = Vector3.new(1.9, 0.2, 1.9),
				Position = Vector3.new(-141 + column * 2, 0.95, -16 + row * 2),
				Material = Enum.Material.Neon,
				Color = PARTY_COLORS[(column + row) % #PARTY_COLORS + 1],
				CastShadow = false,
			})
			tile:SetAttribute("Index", column + row)
			CollectionService:AddTag(tile, "DanceTile")
		end
	end

	-- DJ booth in front of the door, the DJ behind it facing the crowd.
	local booth = part({
		Name = "DJBooth",
		Size = Vector3.new(1.6, 3, 6),
		Position = Vector3.new(-141.6, 2.35, -6),
		Color = Color3.fromRGB(25, 25, 32),
	})
	part({
		Name = "DJStrip",
		Size = Vector3.new(0.1, 0.5, 6),
		CFrame = booth.CFrame * CFrame.new(0.85, 0.7, 0),
		Material = Enum.Material.Neon,
		Color = PARTY_COLORS[1],
		CanCollide = false,
	})
	for _, z in { -1.6, 1.6 } do
		part({
			Name = "Turntable",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 1.8, 1.8),
			CFrame = booth.CFrame * CFrame.new(0, 1.6, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(10, 10, 12),
			CanCollide = false,
		})
	end
	dancer(CFrame.lookAt(Vector3.new(-143.2, 4.3, -6), Vector3.new(-130, 4.3, -6)), 9)

	-- Entrance arch over the end of the street: "THE PARTY", read from the homes.
	for _, z in { -15.6, 3.6 } do
		part({
			Name = "ArchPost",
			Size = Vector3.new(1.2, 13, 1.2),
			Position = Vector3.new(-124, 6.5, z),
			Color = Color3.fromRGB(40, 25, 60),
			CanCollide = false,
		})
		balloons(Vector3.new(-123, 1, z + (if z < 0 then -0.8 else 0.8)))
	end
	part({
		Name = "ArchGlow",
		Size = Vector3.new(21.6, 4.6, 0.8),
		CFrame = CFrame.new(-124, 12.5, -6) * CFrame.Angles(0, math.rad(90), 0),
		Material = Enum.Material.Neon,
		Color = PARTY_COLORS[1],
		CanCollide = false,
	})
	local sign = part({
		Name = "ArchSign",
		Size = Vector3.new(21, 4, 1),
		CFrame = CFrame.new(-124, 12.5, -6) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(40, 25, 60),
		CanCollide = false,
	})
	signText(sign, "THE PARTY", Color3.fromRGB(255, 220, 60))
	balloons(Vector3.new(-142.5, 1, -17.5))
	balloons(Vector3.new(-142.5, 1, 7.5))

	-- Backyard pool with a float, two loungers and an umbrella.
	part({
		Name = "PoolRim",
		Size = Vector3.new(14, 0.8, 20),
		Position = Vector3.new(-170, 0.4, -6),
		Color = Color3.fromRGB(225, 220, 205),
		Material = Enum.Material.Concrete,
	})
	local water = part({
		Name = "PoolWater",
		Size = Vector3.new(12, 0.3, 18),
		Position = Vector3.new(-170, 0.8, -6),
		Color = Color3.fromRGB(50, 190, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		CastShadow = false,
	})
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(80, 200, 255)
	glow.Range = 18
	glow.Brightness = 1.5
	glow.Parent = water
	for i = 0, 9 do
		local angle = i / 10 * math.pi * 2
		part({
			Name = "Float",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9,
			Position = Vector3.new(-168 + math.cos(angle) * 1.1, 1.15, -9 + math.sin(angle) * 1.1),
			Color = if i % 2 == 0 then PARTY_COLORS[1] else Color3.fromRGB(250, 250, 250),
			CanCollide = false,
		})
	end
	for _, x in { -174, -166 } do
		part({
			Name = "Lounger",
			Size = Vector3.new(2.4, 0.6, 5),
			Position = Vector3.new(x, 0.9, 7.5),
			Color = Color3.fromRGB(250, 250, 250),
			CanCollide = false,
		})
		part({
			Name = "LoungerBack",
			Size = Vector3.new(2.4, 0.4, 2.2),
			CFrame = CFrame.new(x, 1.8, 9.6) * CFrame.Angles(math.rad(50), 0, 0),
			Color = PARTY_COLORS[2],
			CanCollide = false,
		})
	end
	part({
		Name = "UmbrellaPole",
		Size = Vector3.new(0.3, 7, 0.3),
		Position = Vector3.new(-170, 3.5, 8.5),
		Color = Color3.fromRGB(240, 240, 240),
		CanCollide = false,
	})
	part({
		Name = "Umbrella",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 7, 7),
		CFrame = CFrame.new(-170, 7, 8.5) * CFrame.Angles(0, 0, math.rad(90)),
		Color = PARTY_COLORS[3],
		CanCollide = false,
	})

	-- Parked cars at the curbs, clear of every driveway (scripts/build_scene.luau HOME_XS).
	local carColors = {
		Color3.fromRGB(200, 60, 60),
		Color3.fromRGB(60, 110, 200),
		Color3.fromRGB(235, 235, 230),
	}
	for i, x in { -99, -27, 45 } do
		car(CFrame.new(x, 0, -1.3), carColors[i])
	end
	for i, x in { -85, -13, 59 } do
		car(CFrame.new(x, 0, -10.7) * CFrame.Angles(0, math.pi, 0), carColors[(i % 3) + 1])
	end

	-- Trees behind both rows of houses, two deep, and closing off both ends of the town.
	for x = -128, 92, 20 do
		tree(x + math.random(-3, 3), 52 + math.random(-2, 2))
		tree(x + 10 + math.random(-3, 3), 62 + math.random(-2, 2))
		tree(x + 10 + math.random(-3, 3), -64 + math.random(-2, 2))
		tree(x + math.random(-3, 3), -74 + math.random(-2, 2))
	end
	for z = -70, 60, 12 do
		tree(-182 + math.random(-3, 3), z + math.random(-2, 2))
		if z < -24 or z > 14 then
			tree(140 + math.random(-3, 3), z + math.random(-2, 2))
		end
	end

	-- Fields beyond the tree belts: scattered mixed trees, rocks and flower patches, so the
	-- town doesn't end in flat dark grass.
	for _ = 1, 34 do
		for _, band in { { 72, 98 }, { -110, -84 } } do
			local x, z = math.random(-200, 150), math.random(band[1], band[2])
			if math.random() < 0.7 then
				tree(x, z)
			elseif math.random() < 0.5 then
				rock(x, z)
			else
				flowers(Vector3.new(x, 0, z), 2.5, 9)
			end
		end
	end
	-- West of the party: trees around the pool garden, flowers and rocks among them.
	for z = -60, 50, 14 do
		if z < -24 or z > 14 then
			flowers(Vector3.new(-168 + math.random(-6, 6), 0, z + math.random(-3, 3)), 2.5, 8)
		end
	end
	for _ = 1, 10 do
		rock(math.random(-200, 150), pick({ 56, 66, -68, -78 }) + math.random(-3, 3))
	end
	-- Fireflies over the tree belts and the pool garden.
	fireflies(Vector3.new(-25, 4, 60), Vector3.new(230, 6, 18))
	fireflies(Vector3.new(-25, 4, -72), Vector3.new(230, 6, 18))
	fireflies(Vector3.new(-170, 4, -6), Vector3.new(22, 6, 70))

	Decor.buildNeighbourhood()
end

local GRASS = Color3.fromRGB(38, 58, 50)
local CONCRETE = Color3.fromRGB(110, 112, 120)
local WOOD = Color3.fromRGB(215, 205, 185)

local function fence(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	local along = CFrame.lookAt(mid, to)
	part({
		Name = "Fence",
		Size = Vector3.new(0.3, 3, length),
		CFrame = along + Vector3.new(0, 1.5, 0),
		Color = WOOD,
	})
	part({
		Name = "FenceRail",
		Size = Vector3.new(0.5, 0.4, length),
		CFrame = along + Vector3.new(0, 3.1, 0),
		Color = WOOD:Lerp(Color3.new(0, 0, 0), 0.15),
	})
end

-- One front yard: mailbox at the sidewalk, bushes under the window, and a tall tree in the gap
-- beside the house. Nothing tall in the front yard or along the curb: the practice cameras look
-- diagonally across them to see the party.
-- `lot` is the home's origin at the street edge, local -Z towards the street (build_scene).
local function yard(lot: CFrame, home: Model?)
	local post = part({
		Name = "MailboxPost",
		Size = Vector3.new(0.3, 3, 0.3),
		CFrame = lot * CFrame.new(3, 1.5, 4.5),
		Color = WOOD,
		CanCollide = false,
	})
	part({
		Name = "Mailbox",
		Size = Vector3.new(0.9, 0.9, 1.6),
		CFrame = post.CFrame * CFrame.new(0, 1.8, 0),
		Color = Color3.fromRGB(60, 70, 110),
		CanCollide = false,
	})
	for i = 0, 2 do
		part({
			Name = "Bush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (2.6 + i % 2 * 0.6),
			CFrame = lot * CFrame.new(3 + i * 3, 1, 22.5),
			Color = Color3.fromRGB(35, 75, 55),
			CanCollide = false,
		})
	end
	-- Flowers in front of the bushes and round the mailbox.
	flowers((lot * CFrame.new(6, 0, 20.2)).Position, 3, 12)
	flowers((lot * CFrame.new(3, 0, 4.5)).Position, 1.2, 5)
	-- Name sign: "<NAME>'S HOUSE" for whoever lives here this round, else FOR SALE.
	for _, x in { 5.6, 10.4 } do
		part({
			Name = "SignPost",
			Size = Vector3.new(0.3, 3.2, 0.3),
			CFrame = lot * CFrame.new(x, 1.6, 5),
			Color = WOOD,
			CanCollide = false,
		})
	end
	local board = part({
		Name = "NameSign",
		Size = Vector3.new(6, 1.9, 0.3),
		CFrame = lot * CFrame.new(8, 2.6, 5),
		Color = Color3.fromRGB(40, 25, 60),
		CanCollide = false,
	})
	local labels = signText(board, "FOR SALE", Color3.new(1, 1, 1))
	if home then
		local function refresh()
			local owner = home:GetAttribute("Owner")
			for _, label in labels do
				label.Text = if typeof(owner) == "string" then `{string.upper(owner)}'S HOUSE` else "FOR SALE"
				label.TextColor3 = if typeof(owner) == "string"
					then Color3.fromRGB(255, 220, 60)
					else Color3.new(1, 1, 1)
			end
		end
		home:GetAttributeChangedSignal("Owner"):Connect(refresh)
		refresh()
	end
	local trunk = part({
		Name = "YardTrunk",
		Size = Vector3.new(1.1, 10, 1.1),
		CFrame = lot * CFrame.new(16, 5, 29),
		Color = Color3.fromRGB(80, 55, 45),
		CanCollide = false,
	})
	part({
		Name = "YardLeaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 8,
		CFrame = trunk.CFrame * CFrame.new(0, 7, 0),
		Color = Color3.fromRGB(45, 85, 70),
		CanCollide = false,
	})
end

function Decor.buildNeighbourhood()
	-- Grass everywhere the town isn't.
	local baseplate = workspace:FindFirstChild("Baseplate") :: BasePart?
	if baseplate then
		baseplate.Material = Enum.Material.Grass
		baseplate.Color = GRASS
	end

	-- Raised sidewalks with a curb along both sides of the street.
	local length = STREET_EAST - STREET_WEST
	local midX = (STREET_EAST + STREET_WEST) / 2
	for _, z in { 2.5, -14.5 } do
		part({
			Name = "Sidewalk",
			Size = Vector3.new(length, 0.35, 3),
			Position = Vector3.new(midX, 0.175, z),
			Color = CONCRETE,
			Material = Enum.Material.Concrete,
		})
		part({
			Name = "Curb",
			Size = Vector3.new(length, 0.4, 0.3),
			Position = Vector3.new(midX, 0.2, if z > 0 then 1.15 else -13.15),
			Color = Color3.fromRGB(150, 150, 155),
		})
	end

	-- Cul-de-sac closing the east end of the street.
	part({
		Name = "CulDeSac",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 34, 34),
		CFrame = CFrame.new(STREET_EAST + 12, 0.1, -6) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(35, 38, 46),
	})
	part({
		Name = "CulDeSacIsland",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 10, 10),
		CFrame = CFrame.new(STREET_EAST + 14, 0.3, -6) * CFrame.Angles(0, 0, math.rad(90)),
		Color = GRASS,
		Material = Enum.Material.Grass,
	})
	tree(STREET_EAST + 14, -6)

	-- Yards, side fences between houses (behind the front yards) and a back fence per row.
	local homes = workspace:WaitForChild("Homes")
	for i, x in HOME_XS do
		yard(CFrame.new(x, 0, 1), homes:FindFirstChild(`Home{i}`) :: Model?)
		yard(
			CFrame.new(x, 0, -13) * CFrame.Angles(0, math.pi, 0),
			homes:FindFirstChild(`Home{i + #HOME_XS}`) :: Model?
		)
	end
	local westEdge, eastEdge = HOME_XS[1] - 18, HOME_XS[#HOME_XS] + 18
	for _, z in { 33, -45 } do -- house centres (build_scene: lot + 32)
		local back = if z > 0 then z + 11 else z - 11
		for _, x in HOME_XS do
			for _, side in { -1, 1 } do
				fence(Vector3.new(x + side * 14, 0, z), Vector3.new(x + side * 18, 0, z))
			end
		end
		fence(Vector3.new(westEdge, 0, back), Vector3.new(eastEdge, 0, back))
		fence(Vector3.new(westEdge, 0, z), Vector3.new(westEdge, 0, back))
		fence(Vector3.new(eastEdge, 0, z), Vector3.new(eastEdge, 0, back))
	end

	-- Distant skyline: dark houses with a few lit windows, past the tree lines.
	for _, z in { 110, -122 } do
		for x = -220, 180, 28 do
			local height = math.random(14, 30)
			local block = part({
				Name = "FarHouse",
				Size = Vector3.new(math.random(16, 24), height, 14),
				Position = Vector3.new(x + math.random(-5, 5), height / 2, z + math.random(-6, 6)),
				Color = Color3.fromRGB(24, 26, 44),
				CanCollide = false,
				CastShadow = false,
			})
			for _ = 1, math.random(1, 3) do
				part({
					Name = "FarWindow",
					Size = Vector3.new(2, 2, 0.2),
					CFrame = block.CFrame * CFrame.new(
						math.random(-6, 6),
						math.random(-height // 2 + 3, height // 2 - 3),
						(if z > 0 then -7.1 else 7.1)
					),
					Material = Enum.Material.Neon,
					Color = Color3.fromRGB(255, 200, 110),
					CanCollide = false,
				})
			end
		end
	end
end

return Decor
