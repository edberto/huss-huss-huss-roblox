-- Client entry: practice screen, fixed practice camera, basketball station.
local Players = game:GetService("Players")

local Basketball = require(script.Basketball)
local RhythmClient = require(script.RhythmClient)

local player = Players.LocalPlayer
local home = workspace:WaitForChild("Home") :: Model

-- Fixed three-quarter view of the driveway with the party house behind (design doc: camera).
-- ponytail: one shared home until homes are assigned per player.
local camera = workspace.CurrentCamera
local cameraPoint = home:WaitForChild("PracticeCamera") :: BasePart
-- Trainers get the fixed practice view; partiers walk around with the normal camera.
local function updateCamera()
	if player:GetAttribute("Team") == "Partier" then
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

RhythmClient.onResult = Basketball.start(home)
RhythmClient.start()
