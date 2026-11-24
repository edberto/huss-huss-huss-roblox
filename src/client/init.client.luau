-- Client entry: practice screen, fixed practice camera, ball bounce on each hit.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local RhythmClient = require(script.RhythmClient)

local player = Players.LocalPlayer
local home = workspace:WaitForChild("Home")

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

-- Ball bounces from the player's hand height to the ground and back on every hit.
local ball = home:WaitForChild("Ball") :: BasePart
local ballTop = ball.CFrame
local bounce = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
RhythmClient.onResult = function(grade)
	if grade ~= "Miss" then
		TweenService:Create(ball, bounce, { CFrame = ballTop - Vector3.new(0, 2.6, 0) }):Play()
	end
end

RhythmClient.start()
