--!strict
-- The give-in cutscene (~3 s, tap to skip): the camera whips from the station to the party
-- house as the music swells, "YOU GAVE IN" slams in under confetti, then normal partier play.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local PartyMusic = require(script.Parent.PartyMusic)
local StationFx = require(script.Parent.StationFx)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local GiveIn = {}

local CONFETTI =
	{ Ui.colors.pink, Ui.colors.mint, Ui.colors.amber, Ui.colors.purple, Color3.new(1, 1, 1) }

-- Plays the cutscene, then calls done (also when skipped).
function GiveIn.play(done: () -> ())
	local camera = workspace.CurrentCamera
	local house = workspace:WaitForChild("Town"):WaitForChild("PartyHouse") :: Model
	local lawn = house:WaitForChild("Lawn") :: BasePart
	local from = camera.CFrame
	local target = lawn.Position + Vector3.new(0, 6, 0)
	local shot =
		CFrame.lookAt(target + (from.Position - target).Unit * 28 + Vector3.new(0, 8, 0), target)

	StationFx.play("tempo", 0.7)
	PartyMusic.swell()
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService
		:Create(camera, TweenInfo.new(1.1, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
			CFrame = shot,
			FieldOfView = 80,
		})
		:Play()

	local gui = Ui.make("ScreenGui", {
		Name = "GiveIn",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 20,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local title = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Rotation = -6,
		Size = UDim2.fromScale(0.9, 0.2),
		Text = "YOU GAVE IN",
		TextColor3 = Ui.colors.amber,
		TextTransparency = 1,
		Parent = gui,
	}, { Ui.make("UIStroke", { Color = Ui.colors.navy, Thickness = 5 }) })
	local sub = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromScale(0.6, 0.07),
		Text = "Now drag the others in. Tap to skip",
		TextTransparency = 1,
		Parent = gui,
	}, { Ui.make("UIStroke", { Color = Ui.colors.navy, Thickness = 3 }) })

	task.delay(0.7, function()
		title.Size = UDim2.fromScale(1.6, 0.36)
		TweenService
			:Create(title, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(0.9, 0.2),
				TextTransparency = 0,
			})
			:Play()
		TweenService:Create(sub, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
		for _ = 1, 40 do
			local bit = Ui.make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = CONFETTI[math.random(#CONFETTI)],
				BorderSizePixel = 0,
				Position = UDim2.fromScale(math.random(), -0.05),
				Rotation = math.random(0, 360),
				Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22)),
				Parent = gui,
			})
			TweenService:Create(
				bit,
				TweenInfo.new(1.6 + math.random(), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					Position = UDim2.fromScale(
						bit.Position.X.Scale + (math.random() - 0.5) * 0.3,
						1.1
					),
					Rotation = bit.Rotation + math.random(-360, 360),
				}
			):Play()
		end
	end)

	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		gui:Destroy()
		camera.FieldOfView = 70
		done()
	end
	local skip = UserInputService.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.Space
		then
			finish()
		end
	end)
	task.delay(3, finish)
	gui.Destroying:Connect(function()
		skip:Disconnect()
	end)
end

return GiveIn
