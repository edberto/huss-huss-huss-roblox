-- Builds the night town in the open place (run in Studio's command bar or through the Studio MCP).
-- Re-running replaces workspace.Home and workspace.Town. Logged in docs/rollout.md.
-- Layout: the street runs along X at z = -6. Home lot is z > 0 (house at z 24-40, hoop over the
-- garage). The party house is next door at x = -52, behind the player in the practice camera.
local Lighting = game:GetService("Lighting")

local C = {
	navy = Color3.fromHex("141B36"),
	cream = Color3.fromHex("F2EEDC"),
	amber = Color3.fromHex("FFB547"),
	orange = Color3.fromHex("FF6B1A"),
	pink = Color3.fromHex("FF2E93"),
	purple = Color3.fromHex("8A3CFF"),
	lawn = Color3.fromHex("2E3D52"),
	asphalt = Color3.fromHex("23262E"),
	concrete = Color3.fromHex("6B6E78"),
	wall = Color3.fromHex("C9C2B0"),
	roof = Color3.fromHex("3C3489"),
	partyWall = Color3.fromHex("4B2A6B"),
}

for _, name in { "Home", "Town" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	props: { [string]: any }?
)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props or {} do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

local function house(parent: Instance, origin: Vector3, wallColor: Color3, roofColor: Color3)
	part(
		parent,
		"Walls",
		Vector3.new(28, 14, 16),
		CFrame.new(origin + Vector3.new(0, 7, 0)),
		wallColor
	)
	local roofL = part(
		parent,
		"RoofL",
		Vector3.new(30, 1, 11),
		CFrame.new(origin + Vector3.new(0, 17, -4)) * CFrame.Angles(math.rad(-35), 0, 0),
		roofColor
	)
	local roofR = part(
		parent,
		"RoofR",
		Vector3.new(30, 1, 11),
		CFrame.new(origin + Vector3.new(0, 17, 4)) * CFrame.Angles(math.rad(35), 0, 0),
		roofColor
	)
	return roofL, roofR
end

-- Ground and street -----------------------------------------------------------------------------
local base = workspace:FindFirstChild("Baseplate") :: BasePart?
if base then
	base.Color = C.lawn
	base.Material = Enum.Material.SmoothPlastic
	for _, child in base:GetChildren() do
		if child:IsA("Texture") then
			child:Destroy()
		end
	end
end
local town = Instance.new("Folder")
town.Name = "Town"
part(town, "Street", Vector3.new(400, 0.2, 14), CFrame.new(0, 0.1, -6), C.asphalt)
for x = -190, 190, 20 do
	part(town, "Line", Vector3.new(8, 0.1, 0.6), CFrame.new(x, 0.25, -6), C.cream)
end
for _, x in { -90, 20, 60 } do
	local pole = part(town, "Lamp", Vector3.new(0.8, 14, 0.8), CFrame.new(x, 7, 2.5), C.asphalt)
	local bulb = part(
		town,
		"LampBulb",
		Vector3.new(2, 1, 2),
		CFrame.new(x, 14.3, 2.5),
		C.amber,
		{ Material = Enum.Material.Neon }
	)
	light(bulb, C.amber, 26, 1.4)
	pole.CastShadow = false
end

-- Party house next door down the block: it sits behind the player in the practice camera.
local party = Instance.new("Model")
party.Name = "PartyHouse"
house(party, Vector3.new(-52, 0, 8), C.partyWall, C.roof)
for i, z in { 2, 8, 14 } do
	local color = if i == 2 then C.purple else C.pink
	local w = part(
		party,
		"Window",
		Vector3.new(0.4, 4, 4),
		CFrame.new(-37.9, 9, z),
		color,
		{ Material = Enum.Material.Neon }
	)
	light(w, color, 30, 2.5)
end
part(
	party,
	"Door",
	Vector3.new(0.4, 7, 4),
	CFrame.new(-37.9, 3.5, 8),
	C.amber,
	{ Material = Enum.Material.Neon }
)
for i = 1, 6 do
	part(
		party,
		"Guest",
		Vector3.new(2, 5, 2),
		CFrame.new(-33 + (i % 2) * 2.5, 2.5, -1 + i * 3),
		if i % 2 == 0 then C.pink else C.purple
	)
end
party.Parent = town

local moon = part(town, "Moon", Vector3.new(40, 40, 40), CFrame.new(-300, 110, 70), C.cream, {
	Shape = Enum.PartType.Ball,
	Material = Enum.Material.Neon,
	CanCollide = false,
	CastShadow = false,
})
moon.Transparency = 0.05
town.Parent = workspace

-- Player home: house, garage, driveway, hoop, ball, practice spot, camera ----------------------
local home = Instance.new("Model")
home.Name = "Home"
house(home, Vector3.new(0, 0, 32), C.wall, C.roof)
part(home, "GarageDoor", Vector3.new(10, 8, 0.4), CFrame.new(-7, 4, 23.9), C.concrete)
local win = part(
	home,
	"Window",
	Vector3.new(5, 4, 0.4),
	CFrame.new(6, 8, 23.9),
	C.amber,
	{ Material = Enum.Material.Neon }
)
light(win, C.amber, 16, 1)
part(home, "Driveway", Vector3.new(12, 0.2, 25), CFrame.new(-7, 0.15, 11.5), C.concrete)

-- Hoop on the garage, facing the street.
part(home, "Backboard", Vector3.new(7, 4.5, 0.3), CFrame.new(-7, 12, 23.5), C.cream)
part(home, "BoardSquare", Vector3.new(2.4, 1.8, 0.1), CFrame.new(-7, 11.4, 23.3), C.orange)
local rimCenter = Vector3.new(-7, 10.4, 21.8)
for i = 0, 11 do
	local a = i / 12 * math.pi * 2
	local pos = rimCenter + Vector3.new(math.cos(a) * 1.5, 0, math.sin(a) * 1.5)
	part(
		home,
		"Rim",
		Vector3.new(0.85, 0.22, 0.22),
		CFrame.lookAt(pos, rimCenter) * CFrame.Angles(0, math.rad(90), 0),
		C.orange,
		{ CanCollide = false, Material = Enum.Material.Neon }
	)
end

part(home, "Ball", Vector3.new(1.6, 1.6, 1.6), CFrame.new(-5.6, 3.4, 13.2), C.orange, {
	Shape = Enum.PartType.Ball,
	CanCollide = false,
})

-- Practice spot: the player stands here facing the hoop.
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then
	spawn.CFrame = CFrame.lookAt(Vector3.new(-7, 0.5, 12), Vector3.new(-7, 0.5, 30))
	spawn.Size = Vector3.new(4, 1, 4)
	spawn.Transparency = 1
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Duration = 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
end

-- Camera from the side of the driveway looking west: hoop on the right, party house behind the player.
part(
	home,
	"PracticeCamera",
	Vector3.new(1, 1, 1),
	CFrame.lookAt(Vector3.new(5, 6.5, 5), Vector3.new(-20, 6, 13)),
	C.cream,
	{
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}
)
home.Parent = workspace

-- Lighting: cold full-moon night (art style section).
Lighting.ClockTime = 0
Lighting.Brightness = 1.5
Lighting.Ambient = Color3.fromRGB(40, 48, 88)
Lighting.OutdoorAmbient = Color3.fromRGB(70, 80, 130)
Lighting.EnvironmentDiffuseScale = 0.3
Lighting.EnvironmentSpecularScale = 0.2
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	atmosphere.Density = 0.32
	atmosphere.Color = Color3.fromRGB(60, 72, 130)
	atmosphere.Decay = C.navy
	atmosphere.Glare = 0
	atmosphere.Haze = 1.2
end
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
if bloom then
	bloom.Intensity = 0.6
	bloom.Threshold = 1.6
	bloom.Size = 30
end
local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if dof then
	dof.Enabled = false
end
local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect")
if sunRays then
	sunRays.Enabled = false
end

return "scene built"
