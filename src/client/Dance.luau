--!strict
-- The DANCE button: plays your equipped dance (Shop → Dances; Groove by default) on your avatar
-- whenever you're not practising: at Dusk, at Dawn and as a partier. Your own avatar's
-- animations replicate, so everyone sees it. It keeps going while you move; pressing DANCE
-- again or starting practice stops it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Dance = {}

function Dance.start(practising: () -> boolean)
	local gui = Ui.make("ScreenGui", {
		Name = "Dance",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local button = Ui.make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		AutoButtonColor = true,
		BackgroundColor3 = Ui.colors.purple,
		-- Bottom centre: clear of the partier buttons and the phone jump button (bottom right).
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromScale(0.12, 0.075),
		Text = "",
		Parent = gui,
	}, {
		Ui.corner(),
		Ui.make("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(0, 0, 0),
			Thickness = 4,
		}),
	}) :: TextButton
	local label =
		Ui.shout({ Size = UDim2.fromScale(1, 1), Text = "DANCE", Thickness = 3, Parent = button })
	Ui.make(
		"UIPadding",
		{ PaddingTop = UDim.new(0.22, 0), PaddingBottom = UDim.new(0.14, 0), Parent = label }
	)

	local track: AnimationTrack? = nil
	local function stop()
		if track then
			track:Stop(0.2)
			track = nil
		end
		label.Text = "DANCE"
	end
	local function toggle()
		if track then
			stop()
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if not animator or practising() then
			return
		end
		local equipped = player:GetAttribute("Equipped_dance")
		local item = Cosmetics.items[if typeof(equipped) == "string"
			then equipped
			else "dance_groove"] or Cosmetics.items.dance_groove
		local animation = Instance.new("Animation")
		animation.AnimationId = `rbxassetid://{item.anim}`
		local loaded = animator:LoadAnimation(animation)
		loaded.Looped = true
		loaded.Priority = Enum.AnimationPriority.Action
		loaded:Play(0.2)
		track = loaded
		label.Text = "STOP"
	end
	button.Activated:Connect(toggle)
	Ui.bind(button, { Enum.KeyCode.F }, { Enum.KeyCode.DPadDown }, toggle)

	-- The dance keeps going while you walk or jump (you glide mid-dance); it ends when you press
	-- DANCE again or when practice starts. The button shows only off-practice.
	RunService.Heartbeat:Connect(function()
		local off = not practising()
		button.Visible = off
		-- At Dawn the NEXT NIGHT pill owns the bottom centre; sit just above it.
		local dawn = ReplicatedStorage:GetAttribute("Phase") == "Dawn"
		button.Position = UDim2.new(0.5, 0, if dawn then 0.87 else 1, if dawn then 0 else -14)
		if track and not off then
			stop()
		end
	end)
	player.CharacterAdded:Connect(stop)
end

return Dance
