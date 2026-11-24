--!strict
-- First-night tutorial (design doc): a new player's first night shows short hints at the moment
-- each thing first matters. Reaching Dawn completes it (+100 HP, saved).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RhythmRemotes")

local HINTS = {
	dusk = "Pick what you'll practise tonight. Everyone else is going to the party.",
	beat = "Tap HUSS when a dot reaches the ring. On the beat = Perfect.",
	skill = "Orange dots are your skill move. They're worth double!",
	temptation = "The party wants you! Tap the button before the bar runs out.",
	partiers = "Players who give in become partiers and try to drag you in too. Last until dawn!",
	done = "You made it to dawn! +100 HP. Spend Huss Points in the Shop.",
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
	local card = Ui.label({
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Ui.colors.cream,
		BackgroundTransparency = 0,
		Position = UDim2.new(0, 16, 1, -90),
		Size = UDim2.fromScale(0.46, 0.11),
		TextColor3 = Ui.colors.navy,
		TextWrapped = true,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(12),
		Ui.make("UIPadding", {
			PaddingTop = UDim.new(0.12, 0),
			PaddingBottom = UDim.new(0.12, 0),
			PaddingLeft = UDim.new(0.04, 0),
			PaddingRight = UDim.new(0.04, 0),
		}),
	})

	local shown: { [string]: boolean } = {}
	local token = 0
	local function hint(key: string, seconds: number)
		if shown[key] then
			return
		end
		shown[key] = true
		token += 1
		local mine = token
		card.Text = HINTS[key]
		card.Visible = true
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
