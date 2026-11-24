-- Client entry: practice screen, fixed practice camera, basketball station.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local Basketball = require(script.Basketball)
local Burger = require(script.Burger)
local Gym = require(script.Gym)
local NightScreens = require(script.NightScreens)
local PartyClient = require(script.PartyClient)
local RhythmClient = require(script.RhythmClient)
local ShopClient = require(script.ShopClient)
local Tutorial = require(script.Tutorial)

local player = Players.LocalPlayer
while player:GetAttribute("Home") == nil do
	player:GetAttributeChangedSignal("Home"):Wait()
end
local home = workspace:WaitForChild("Homes"):WaitForChild(player:GetAttribute("Home")) :: Model

-- Fixed view of the player's driveway with the party house behind them (design doc: camera).
local camera = workspace.CurrentCamera
local cameraPoint = home:WaitForChild("PracticeCamera") :: BasePart
-- Trainers get the fixed practice view; partiers walk around with the normal camera.
local function updateCamera()
	local partier = player:GetAttribute("Team") == "Partier"
	-- Trainers never walk; hiding the thumbstick and jump button keeps them off the TAP button.
	GuiService.TouchControlsEnabled = partier
	if partier then
		camera.CameraType = Enum.CameraType.Custom
	else
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cameraPoint.CFrame
	end
end
player.CharacterAdded:Connect(function()
	task.defer(updateCamera)
end)
player:GetAttributeChangedSignal("Team"):Connect(updateCamera)
updateCamera()

-- The party next door never stops: music from the lawn, loud up close, faint down the street.
-- APM library track via the Creator Store (licensed for experiences).
local music = Instance.new("Sound")
music.SoundId = "rbxassetid://1840650601" -- APM: Style Revolution
music.Looped = true
music.Volume = 0.45
music.RollOffMode = Enum.RollOffMode.InverseTapered
music.RollOffMinDistance = 25
music.RollOffMaxDistance = 260
music.Parent = workspace:WaitForChild("Town"):WaitForChild("PartyHouse"):WaitForChild("Lawn")
music:Play()

-- Party beams sweep the sky (built by the server's Decor; animated here so it's smooth and free).
local CollectionService = game:GetService("CollectionService")
game:GetService("RunService").RenderStepped:Connect(function()
	local t = os.clock()
	for _, beam in CollectionService:GetTagged("PartyBeam") do
		local base, phase = beam:GetAttribute("Base"), beam:GetAttribute("Phase")
		if typeof(base) == "CFrame" and typeof(phase) == "number" then
			local tilt = CFrame.Angles(math.sin(t * 0.7 + phase) * 0.45, 0, -0.25 + math.cos(t * 0.5 + phase) * 0.3)
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
ShopClient.start()
task.spawn(Tutorial.start)
ShopClient.applyBallSkin(home:WaitForChild("Ball") :: BasePart)
