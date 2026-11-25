--!strict
-- First-night tutorial (design doc): a new player's first night shows short hints at the moment
-- each thing first matters. Reaching Dawn completes it (+100 HP, saved).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RhythmRemotes")

local HINTS = {
	dusk = if game:GetService("UserInputService").TouchEnabled
		then "Pick your practice! Earbuds? Tap Timing"
		else "Pick your practice!",
	beat = "Tap HUSS as dots hit the ring",
	skill = "Orange dot = skill move, x2!",
	temptation = "Say no! Tap before it runs out",
	partiers = "Partiers will distract you. Last till dawn!",
	done = "You made it! +100 Huss. Spend it in the Shop",
}

local Tutorial = {}

function Tutorial.start()
	if player:GetAttribute("TutorialDone") == nil then
		player:GetAttributeChangedSignal("TutorialDone"):Wait()
	end
	if player:GetAttribute("TutorialDone") == true then
		return
	end

	local gui = Ui.make("ScreenGui", {
		Name = "Tutorial",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 6,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- Hint card: bottom middle, above the beat track and the Dusk tagline, clear of the side
	-- buttons, the HUSS button and the temptation prompt up top. Pops in when it changes.
	local cardScale = Ui.make("UIScale", {})
	local card = Ui.label({
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Ui.colors.cream,
		BackgroundTransparency = 0,
		Position = UDim2.fromScale(0.5, 0.83),
		Size = UDim2.fromScale(0.42, 0.075),
		TextColor3 = Ui.colors.navy,
		TextWrapped = true,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(14),
		cardScale,
		Ui.make("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(0, 0, 0),
			Thickness = 3,
		}),
		Ui.make("UIPadding", {
			PaddingTop = UDim.new(0.16, 0),
			PaddingBottom = UDim.new(0.16, 0),
			PaddingLeft = UDim.new(0.1, 0),
			PaddingRight = UDim.new(0.04, 0),
		}),
		Ui.make("Frame", { -- the "i" badge
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromHex("50DCFF"),
			Position = UDim2.new(0, -18, 0.5, 0),
			Size = UDim2.fromScale(1.15, 1.15),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
		}, {
			Ui.corner(),
			Ui.make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2.5 }),
			Ui.shout({ Size = UDim2.fromScale(1, 1), Text = "i", Thickness = 2 }),
		}),
	})

	local shown: { [string]: boolean } = {}
	local token = 0
	local function hint(key: string, seconds: number)
		if shown[key] then
			return
		end
		if player:GetAttribute("Team") == "Partier" and key ~= "done" then
			return -- trainer hints only; partiers have their own give-in card
		end
		shown[key] = true
		token += 1
		local mine = token
		card.Text = HINTS[key]
		card.Visible = true
		cardScale.Scale = 0.8
		TweenService:Create(cardScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(seconds, function()
			if token == mine then
				card.Visible = false
			end
		end)
	end

	local function onPhase()
		local phase = ReplicatedStorage:GetAttribute("Phase")
		if phase == "Dusk" then
			hint("dusk", 12)
		elseif phase == "Night" then
			hint("beat", 8)
			task.delay(25, hint, "partiers", 8)
		elseif phase == "Dawn" and shown.beat then
			hint("done", 8)
			remotes:WaitForChild("CompleteTutorial"):InvokeServer()
			task.delay(10, gui.Destroy, gui)
		end
	end
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(onPhase)
	onPhase()
	-- Giving in clears any trainer hint so it never sits over the give-in card.
	player:GetAttributeChangedSignal("Team"):Connect(function()
		if player:GetAttribute("Team") == "Partier" then
			token += 1
			card.Visible = false
		end
	end)

	remotes
		:WaitForChild("Result").OnClientEvent
		:Connect(function(_beat, _grade, _earned, _total, _combo, skill)
			if skill then
				hint("skill", 6)
			end
		end)
	remotes:WaitForChild("Temptation").OnClientEvent:Connect(function()
		hint("temptation", 4)
	end)
end

return Tutorial
