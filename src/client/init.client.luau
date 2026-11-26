-- Client entry: practice screen, fixed practice camera, basketball station.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Basketball = require(script.Basketball)
local Burger = require(script.Burger)
local GiveIn = require(script.GiveIn)
local Gym = require(script.Gym)
local NightScreens = require(script.NightScreens)
local PartyClient = require(script.PartyClient)
local PartyMusic = require(script.PartyMusic)
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
-- partiers) walks around with the normal camera.
local function practising(): boolean
	return ReplicatedStorage:GetAttribute("Phase") == "Night"
		and player:GetAttribute("Team") ~= "Partier"
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
-- apart, on each client.
local TILE_COLORS = {
	Color3.fromRGB(255, 70, 200),
	Color3.fromRGB(80, 220, 255),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(150, 90, 255),
}
task.spawn(function()
	local step = 0
	while true do
		step += 1
		for _, tile in CollectionService:GetTagged("DanceTile") do
			local index = tonumber(tile:GetAttribute("Index")) or 0
			(tile :: BasePart).Color = TILE_COLORS[(index + step) % #TILE_COLORS + 1]
		end
		task.wait(0.48)
	end
end)

-- The station picked at Dusk gets every hit; the others hide their props.
local stations = {
	Basketball = Basketball.start(home),
	Gym = Gym.start(),
	Burgers = Burger.start(),
}
local function currentStation()
	return stations[player:GetAttribute("Station")] or stations.Basketball
end
-- Props only while practising, so they don't trail a player roaming at Dusk or Dawn.
local function updateStation()
	for _, station in stations do
		station.setActive(station == currentStation() and practising())
	end
end
player:GetAttributeChangedSignal("Station"):Connect(updateStation)
player:GetAttributeChangedSignal("Team"):Connect(updateStation)
ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(updateStation)
updateStation()
RhythmClient.onResult = function(grade, skill)
	currentStation().onResult(grade, skill)
end
RhythmClient.start()
NightScreens.start()
PartyClient.start()
PartyMusic.start()
Ranks.start()
Spectacle.start()
ShopClient.start()
task.spawn(Tutorial.start)
ShopClient.applyBallSkin(home:WaitForChild("Ball") :: BasePart)
