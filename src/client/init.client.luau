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
local function lockCamera()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = cameraPoint.CFrame
end
player.CharacterAdded:Connect(function()
	task.defer(lockCamera)
end)
lockCamera()

RhythmClient.onResult = Basketball.start(home)
RhythmClient.start()
