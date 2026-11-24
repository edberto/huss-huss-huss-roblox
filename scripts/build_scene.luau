-- Builds the night town in the open place (run in Studio's command bar or through the Studio MCP).
-- Re-running replaces workspace.Homes and workspace.Town. Logged in docs/rollout.md.
-- Layout: one street along X (z = -6). Six homes on each side face the street. The party house
-- closes the west end of the street, so every home's practice camera has it behind the player.
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
local HOME_XS = { -110, -74, -38, -2, 34, 70 }
local PARTY_CENTER = Vector3.new(-152, 0, -6)

for _, name in { "Home", "Homes", "Town" } do
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

-- A house whose front faces local -Z, centred on `base`.
local function house(parent: Instance, base: CFrame, wallColor: Color3, roofColor: Color3)
	part(parent, "Walls", Vector3.new(28, 14, 16), base * CFrame.new(0, 7, 0), wallColor)
	part(
		parent,
		"RoofL",
		Vector3.new(30, 1, 11),
		base * CFrame.new(0, 17, -4) * CFrame.Angles(math.rad(-35), 0, 0),
		roofColor
	)
	part(
		parent,
		"RoofR",
		Vector3.new(30, 1, 11),
		base * CFrame.new(0, 17, 4) * CFrame.Angles(math.rad(35), 0, 0),
		roofColor
	)
end

-- Ground and street ------------------------------------------------------------------------------
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
part(town, "Street", Vector3.new(250, 0.2, 14), CFrame.new(-15, 0.1, -6), C.asphalt)
for x = -130, 100, 20 do
	part(town, "Line", Vector3.new(8, 0.1, 0.6), CFrame.new(x, 0.25, -6), C.cream)
end
for _, x in { -128, -92, -56, -20, 16, 52, 88 } do
	for _, z in { 2.5, -14.5 } do
		part(
			town,
			"Lamp",
			Vector3.new(0.8, 14, 0.8),
			CFrame.new(x, 7, z),
			C.asphalt,
			{ CastShadow = false }
		)
		local bulb = part(
			town,
			"LampBulb",
			Vector3.new(2, 1, 2),
			CFrame.new(x, 14.3, z),
			C.amber,
			{ Material = Enum.Material.Neon }
		)
		light(bulb, C.amber, 26, 1.4)
	end
end

-- Party house at the west end of the street, front facing east down the street.
local party = Instance.new("Model")
party.Name = "PartyHouse"
local partyBase = CFrame.new(PARTY_CENTER) * CFrame.Angles(0, math.rad(-90), 0) -- local -Z = world +X
house(party, partyBase, C.partyWall, C.roof)
for i, lx in { -8, 0, 8 } do
	local color = if i == 2 then C.purple else C.pink
	local w = part(
		party,
		"Window",
		Vector3.new(5, 4, 0.4),
		partyBase * CFrame.new(lx, 9, -8.1),
		color,
		{ Material = Enum.Material.Neon }
	)
	light(w, color, 34, 2.5)
end
part(
	party,
	"Door",
	Vector3.new(4, 7, 0.4),
	partyBase * CFrame.new(0, 3.5, -8.1),
	C.amber,
	{ Material = Enum.Material.Neon }
)
-- Side windows, so the homes nearest the party also see it glowing.
for _, side in { -14.1, 14.1 } do
	for i, lz in { -4, 4 } do
		local color = if i == 1 then C.pink else C.purple
		local w = part(
			party,
			"Window",
			Vector3.new(0.4, 4, 4),
			partyBase * CFrame.new(side, 9, lz),
			color,
			{ Material = Enum.Material.Neon }
		)
		light(w, color, 26, 2)
	end
end
for i = 1, 8 do
	local lx = -10 + (i - 1) * 3
	part(
		party,
		"Guest",
		Vector3.new(2, 5, 2),
		partyBase * CFrame.new(lx, 2.5, -13 - (i % 2) * 2),
		if i % 2 == 0 then C.pink else C.purple
	)
end
-- Partiers gather here (Round moves players who give in to this spot).
part(party, "Lawn", Vector3.new(16, 1, 10), partyBase * CFrame.new(0, 0.5, -20), C.lawn, {
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
})
party.Parent = town

local moon = part(town, "Moon", Vector3.new(40, 40, 40), CFrame.new(-420, 120, 60), C.cream, {
	Shape = Enum.PartType.Ball,
	Material = Enum.Material.Neon,
	CanCollide = false,
	CastShadow = false,
})
moon.Transparency = 0.05
town.Parent = workspace

-- Homes: house, garage, driveway, hoop, ball, practice spot and camera ----------------------------
-- `lot` is the home's origin at the street edge; its local -Z faces the street.
local homes = Instance.new("Folder")
homes.Name = "Homes"

local function buildHome(index: number, lot: CFrame)
	local home = Instance.new("Model")
	home.Name = `Home{index}`
	house(home, lot * CFrame.new(0, 0, 32), C.wall, C.roof)
	part(home, "GarageDoor", Vector3.new(10, 8, 0.4), lot * CFrame.new(-7, 4, 23.9), C.concrete)
	local win = part(
		home,
		"Window",
		Vector3.new(5, 4, 0.4),
		lot * CFrame.new(6, 8, 23.9),
		C.amber,
		{ Material = Enum.Material.Neon }
	)
	light(win, C.amber, 16, 1)
	part(home, "Driveway", Vector3.new(12, 0.2, 25), lot * CFrame.new(-7, 0.15, 11.5), C.concrete)

	part(home, "Backboard", Vector3.new(7, 4.5, 0.3), lot * CFrame.new(-7, 12, 23.5), C.cream)
	part(
		home,
		"BoardSquare",
		Vector3.new(2.4, 1.8, 0.1),
		lot * CFrame.new(-7, 11.4, 23.3),
		C.orange
	)
	local rimCenter = (lot * CFrame.new(-7, 10.4, 21.8)).Position
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local pos = rimCenter + Vector3.new(math.cos(a) * 1.5, 0, math.sin(a) * 1.5)
		part(
			home,
			"Rim",
			Vector3.new(0.85, 0.22, 0.22),
			CFrame.lookAt(pos, rimCenter) * CFrame.Angles(0, math.rad(90), 0),
			C.orange,
			{
				CanCollide = false,
				Material = Enum.Material.Neon,
			}
		)
	end

	part(home, "Ball", Vector3.new(1.6, 1.6, 1.6), lot * CFrame.new(-5.6, 3.4, 13.2), C.orange, {
		Shape = Enum.PartType.Ball,
		CanCollide = false,
	})

	-- The player stands here facing the hoop.
	local spot = lot * CFrame.new(-7, 3, 12)
	part(
		home,
		"PracticeSpot",
		Vector3.new(4, 1, 4),
		CFrame.lookAt(spot.Position, (lot * CFrame.new(-7, 3, 30)).Position),
		C.cream,
		{
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		}
	)

	-- Camera on the far side of the player from the party house, so the party glows behind them;
	-- aimed a little towards the hoop so both stay in frame.
	local away = (spot.Position - PARTY_CENTER) * Vector3.new(1, 0, 1)
	local cameraPos = spot.Position + away.Unit * 14 + Vector3.new(0, 4, 0)
	local towardHoop = lot:VectorToWorldSpace(Vector3.new(0, 0, 4))
	part(
		home,
		"PracticeCamera",
		Vector3.new(1, 1, 1),
		CFrame.lookAt(cameraPos, spot.Position + towardHoop + Vector3.new(0, 1.5, 0)),
		C.cream,
		{
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		}
	)
	home.Parent = homes
end

for i, x in HOME_XS do
	buildHome(i, CFrame.new(x, 0, 1)) -- north side, facing the street (-Z)
	buildHome(i + #HOME_XS, CFrame.new(x, 0, -13) * CFrame.Angles(0, math.pi, 0)) -- south side
end
homes.Parent = workspace

-- Players are placed at their home's PracticeSpot; the spawn only matters before that.
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then
	spawn.CFrame = CFrame.new(-20, 0.5, -6)
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
end

-- Lighting: cold full-moon night (art style section).
Lighting.ClockTime = 0
Lighting.Brightness = 1.5
Lighting.Ambient = Color3.fromRGB(40, 48, 88)
Lighting.OutdoorAmbient = Color3.fromRGB(70, 80, 130)
Lighting.EnvironmentDiffuseScale = 0.3
Lighting.EnvironmentSpecularScale = 0.2
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	atmosphere.Density = 0.25
	atmosphere.Color = Color3.fromRGB(60, 72, 130)
	atmosphere.Decay = C.navy
	atmosphere.Glare = 0
	atmosphere.Haze = 1
end
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
if bloom then
	bloom.Intensity = 0.6
	bloom.Threshold = 1.6
	bloom.Size = 30
end
for _, className in { "DepthOfFieldEffect", "SunRaysEffect" } do
	local effect = Lighting:FindFirstChildOfClass(className) :: PostEffect?
	if effect then
		effect.Enabled = false
	end
end

return "scene built"
