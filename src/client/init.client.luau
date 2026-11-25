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
-- Trainers get the fixed practice view; partiers walk around with the normal camera.
local function updateCamera()
	local partier = player:GetAttribute("Team") == "Partier"
	-- Trainers never walk; hiding the thumbstick and jump button keeps them off the TAP button.
	GuiService.TouchControlsEnabled = partier
	if partier then
		camera.CameraType = Enum.CameraType.Custom
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

-- The station picked at Dusk gets every hit; the others hide their props.
local stations = {
	Basketball = Basketball.start(home),
	Gym = Gym.start(),
	Burgers = Burger.start(),
}
local function currentStation()
	return stations[player:GetAttribute("Station")] or stations.Basketball
end
local function updateStation()
	for _, station in stations do
		station.setActive(station == currentStation())
	end
end
player:GetAttributeChangedSignal("Station"):Connect(updateStation)
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
