-- Client entry: practice screen, fixed practice camera, basketball station.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Basketball = require(script.Basketball)
local Burger = require(script.Burger)
local Dance = require(script.Dance)
local Sky = require(script.Sky)
local StationFx = require(script.StationFx)
local GiveIn = require(script.GiveIn)
local Gym = require(script.Gym)
local NightScreens = require(script.NightScreens)
local PartyClient = require(script.PartyClient)
local PartyMusic = require(script.PartyMusic)
local QuestClient = require(script.QuestClient)
local Pose = require(script.Pose)
local Ranks = require(script.Ranks)
local RhythmClient = require(script.RhythmClient)
local ShopClient = require(script.ShopClient)
local Spectacle = require(script.Spectacle)
local Tutorial = require(script.Tutorial)

local player = Players.LocalPlayer
while player:GetAttribute("Home") == nil do
	player:GetAttributeChangedSignal("Home"):Wait()
end
local home = workspace:WaitForChild("Homes"):WaitForChild(player:GetAttribute("Home")) :: Model

-- Fixed view of the player's driveway with the party house behind them (design doc: camera).
local camera = workspace.CurrentCamera
local CAMERA_TILT = 12 -- degrees
-- Each station has its own view: the driveway, the garage gym or the kitchen.
local function cameraPoint(): BasePart
	return (
		home:FindFirstChild(`PracticeCamera_{player:GetAttribute("Station")}`)
		or home:WaitForChild("PracticeCamera")
	) :: BasePart
end
-- Trainers practising at Night get the fixed practice view; everyone else (Dusk, Dawn,
-- partiers, AFK players) walks around with the normal camera.
local function practising(): boolean
	return ReplicatedStorage:GetAttribute("Phase") == "Night"
		and player:GetAttribute("Team") == "Trainer"
end
local function updateCamera()
	local free = not practising()
	-- Practising trainers never walk; hiding the thumbstick and jump button keeps them off TAP.
	GuiService.TouchControlsEnabled = free
	if free then
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	else
		camera.CameraType = Enum.CameraType.Scriptable
		-- The driveway view tilts up so the floating leaderboards over the party house are in
		-- view; the room views have a ceiling, so they keep their own aim.
		local point = cameraPoint()
		local tilt = if point.Name == "PracticeCamera" then CAMERA_TILT else 0
		camera.CFrame = point.CFrame * CFrame.Angles(math.rad(tilt), 0, 0)
	end
end
player.CharacterAdded:Connect(function()
	task.defer(updateCamera)
end)
-- Giving in mid-night plays the cutscene first; any other team change just swaps the camera.
local team = player:GetAttribute("Team")
player:GetAttributeChangedSignal("Team"):Connect(function()
	local was = team
	team = player:GetAttribute("Team")
	if
		was == "Trainer"
		and team == "Partier"
		and ReplicatedStorage:GetAttribute("Phase") == "Night"
	then
		GiveIn.play(updateCamera)
	else
		updateCamera()
	end
end)
player:GetAttributeChangedSignal("Station"):Connect(updateCamera)
ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(updateCamera)
updateCamera()

-- Party beams sweep the sky (built by the server's Decor; animated here so it's smooth and free).
local CollectionService = game:GetService("CollectionService")
game:GetService("RunService").RenderStepped:Connect(function()
	local t = os.clock()
	for _, beam in CollectionService:GetTagged("PartyBeam") do
		local base, phase = beam:GetAttribute("Base"), beam:GetAttribute("Phase")
		if typeof(base) == "CFrame" and typeof(phase) == "number" then
			local tilt = CFrame.Angles(
				math.sin(t * 0.7 + phase) * 0.45,
				0,
				-0.25 + math.cos(t * 0.5 + phase) * 0.3
			)
			beam.CFrame = base * tilt * CFrame.new(0, 30, 0)
		end
	end
end)

-- The dance floor (Decor's DanceTile parts) steps through the party colours, about one beat
-- apart, on each client, and the tile under anyone standing on it flashes white on the beat.
local TILE_COLORS = {
	Color3.fromRGB(255, 70, 200),
	Color3.fromRGB(80, 220, 255),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(150, 90, 255),
}
local TILE_STEP = 0.48
local TILE_HALF = 1.05 -- tiles are 1.9 wide on a 2-stud grid
game:GetService("RunService").Heartbeat:Connect(function()
	-- Settings > Visual > Reduce flashing: colours drift 4x slower and feet don't flash white.
	local calm = player:GetAttribute("CalmFlashing") == true
	local step = math.floor(os.clock() / (if calm then TILE_STEP * 4 else TILE_STEP))
	local onBeat = not calm and os.clock() % TILE_STEP < TILE_STEP * 0.5
	local feet = {}
	for _, other in Players:GetPlayers() do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(feet, root.Position)
		end
	end
	for _, tile in CollectionService:GetTagged("DanceTile") do
		local part = tile :: BasePart
		local index = tonumber(part:GetAttribute("Index")) or 0
		local color = TILE_COLORS[(index + step) % #TILE_COLORS + 1]
		for _, at in feet do
			local offset = at - part.Position
			if
				math.abs(offset.X) < TILE_HALF
				and math.abs(offset.Z) < TILE_HALF
				and offset.Y < 6
			then
				color = if onBeat then Color3.new(1, 1, 1) else color:Lerp(Color3.new(1, 1, 1), 0.5)
				break
			end
		end
		part.Color = color
	end
end)

-- Every trainer's station runs on every screen: yours from your own hits, everyone else's from
-- StationHit, so you can watch the street practise. Joint poses and props are local, so each
-- client draws them all. The station picked at Dusk gets every hit; the others hide their props.
type Rig = { owner: Player, stations: { [string]: StationFx.Station } }
local rigs: { [Player]: Rig } = {}

local function isPractising(who: Player): boolean
	return ReplicatedStorage:GetAttribute("Phase") == "Night"
		and who:GetAttribute("Team") == "Trainer"
		and who:GetAttribute("Station") ~= nil
end
local function stationOf(rig: Rig): StationFx.Station
	return rig.stations[rig.owner:GetAttribute("Station")] or rig.stations.Basketball
end

-- While practising: station arm motions instead of the default animations (Pose), and the
-- title tag hides so it doesn't sit over the ball, barbell or burger.
local function updateRig(rig: Rig)
	local who = rig.owner
	local on = if who == player then practising() else isPractising(who)
	for _, station in rig.stations do
		station.setActive(on and station == stationOf(rig))
	end
	local character = who.Character
	if not character then
		return
	end
	Pose.set(who, if on then who:GetAttribute("Station") :: string? else nil)
	local head = character:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("HussTag")
	if tag and tag:IsA("BillboardGui") then
		tag.Enabled = not on
	end
end

local function addRig(who: Player)
	if rigs[who] then
		return
	end
	while who.Parent and who:GetAttribute("Home") == nil do
		who:GetAttributeChangedSignal("Home"):Wait()
	end
	local theirHome = who.Parent and workspace.Homes:WaitForChild(who:GetAttribute("Home"), 10)
	if not theirHome or rigs[who] then
		return
	end
	local rig: Rig = {
		owner = who,
		stations = {
			Basketball = Basketball.start(theirHome :: Model, who),
			Gym = Gym.start(who),
			Burgers = Burger.start(who),
		},
	}
	rigs[who] = rig
	local function refresh()
		updateRig(rig)
	end
	who:GetAttributeChangedSignal("Station"):Connect(refresh)
	who:GetAttributeChangedSignal("Team"):Connect(refresh)
	who.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 5)
		task.wait(0.5) -- accessories and the title tag arrive a moment later
		refresh()
	end)
	refresh()
end
ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(function()
	for _, rig in rigs do
		updateRig(rig)
	end
end)
Players.PlayerRemoving:Connect(function(who)
	local rig = rigs[who]
	rigs[who] = nil
	if rig then
		for _, station in rig.stations do
			station.destroy()
		end
	end
end)
addRig(player)
for _, other in Players:GetPlayers() do
	task.spawn(addRig, other)
end
Players.PlayerAdded:Connect(addRig)

RhythmClient.onResult = function(grade, skill)
	local rig = rigs[player]
	stationOf(rig).onResult(grade, skill)
	Pose.hit(player, grade, skill)
end
local stationHit =
	ReplicatedStorage:WaitForChild("RhythmRemotes"):WaitForChild("StationHit") :: RemoteEvent
stationHit.OnClientEvent:Connect(function(who: Player, grade: string, skill: boolean)
	local rig = rigs[who]
	if rig and isPractising(who) then
		stationOf(rig).onResult(grade, skill)
		Pose.hit(who, grade, skill)
		if grade == "Miss" then
			StationFx.missOver(who)
		end
	end
end)
RhythmClient.start()
NightScreens.start()
PartyClient.start()
PartyMusic.start()
Ranks.start()
Spectacle.start()
Dance.start(practising)
Sky.start()
ShopClient.start()
QuestClient.start()
task.spawn(Tutorial.start)
ShopClient.applyBallSkin(home:WaitForChild("Ball") :: BasePart)
