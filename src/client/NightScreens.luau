--!strict
-- The approved night-cycle screens: Dusk station picker, temptation prompts, the give-in screen
-- and the Dawn results card. Driven by ReplicatedStorage "Phase"/"PhaseEnds" and the remotes.
local AvatarEditorService = game:GetService("AvatarEditorService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Night = require(ReplicatedStorage.Shared.Night)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RhythmRemotes")
local temptationEvent = remotes:WaitForChild("Temptation") :: RemoteEvent
local answerEvent = remotes:WaitForChild("TemptationAnswer") :: RemoteEvent
local resultsEvent = remotes:WaitForChild("NightResults") :: RemoteEvent

local C = Ui.colors
local make, corner, label = Ui.make, Ui.corner, Ui.label

local PROMPTS = {
	Doorbell = { text = "Ding dong! Party's next door", button = "Ignore" },
	Phone = { text = "New message: party at the end of the street", button = "Decline" },
	Friend = { text = "Come on, just one hour!", button = "Not tonight" },
	BassDrop = { text = "BASS DROP! Misses count double", button = nil },
}

local NightScreens = {}

function NightScreens.start()
	local gui = make("ScreenGui", {
		Name = "NightScreens",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- 1. Dusk: pick a station ---------------------------------------------------------------------
	local dusk = make(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = gui }
	)
	local duskTitle = label({
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.navy,
		BackgroundTransparency = 0.15,
		Position = UDim2.fromScale(0.5, 0.05),
		Size = UDim2.fromScale(0.5, 0.08),
		Parent = dusk,
	}, nil)
	corner().Parent = duskTitle
	make(
		"UIPadding",
		{ PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.15, 0), Parent = duskTitle }
	)
	local cards = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.6, 0.24),
		Parent = dusk,
	}, {
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.03, 0),
		}),
	})
	local pickEvent = remotes:WaitForChild("PickStation") :: RemoteEvent
	local cardParts: { [string]: { card: TextButton, stroke: UIStroke, status: TextLabel } } = {}
	for _, name in Night.stations do
		local card = make("TextButton", {
			BackgroundColor3 = C.panel,
			Size = UDim2.fromScale(0.3, 1),
			Text = "",
			Parent = cards,
		}, { corner(12) })
		local stroke = make("UIStroke", {
			Color = C.cream,
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = card,
		})
		label({
			Position = UDim2.fromScale(0.08, 0.18),
			Size = UDim2.fromScale(0.84, 0.36),
			Text = name,
			Parent = card,
		})
		local status = label({
			Position = UDim2.fromScale(0.1, 0.6),
			Size = UDim2.fromScale(0.8, 0.22),
			Text = "Tap to pick",
			Parent = card,
		})
		card.Activated:Connect(function()
			pickEvent:FireServer(name)
		end)
		cardParts[name] = { card = card, stroke = stroke, status = status }
	end
	-- The picked card is orange with a cream outline; the others are dark.
	local function refreshCards()
		local picked = player:GetAttribute("Station")
		for name, parts in cardParts do
			local on = name == picked
			parts.card.BackgroundColor3 = if on then C.orange else C.panel
			parts.stroke.Enabled = on
			parts.status.Text = if on then "Selected" else "Tap to pick"
			for _, child in parts.card:GetChildren() do
				if child:IsA("TextLabel") then
					child.TextColor3 = if on then C.navy else C.cream
				end
			end
		end
	end
	player:GetAttributeChangedSignal("Station"):Connect(refreshCards)
	refreshCards()
	label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.93),
		Size = UDim2.fromScale(0.6, 0.05),
		Text = "In this town, everybody goes out partying… except me.",
		TextColor3 = Color3.fromHex("B4B2A9"),
		Parent = dusk,
	})

	-- 2. Temptation prompt ------------------------------------------------------------------------
	local prompt = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.cream,
		Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.fromScale(0.42, 0.24),
		Visible = false,
		Parent = gui,
	}, { corner(14) })
	local promptText = label({
		Position = UDim2.fromScale(0.06, 0.1),
		Size = UDim2.fromScale(0.88, 0.26),
		TextColor3 = C.navy,
		Parent = prompt,
	})
	local timerBack = make("Frame", {
		BackgroundColor3 = C.rule,
		Position = UDim2.fromScale(0.06, 0.44),
		Size = UDim2.fromScale(0.88, 0.06),
		Parent = prompt,
	}, { corner() })
	local timerFill = make(
		"Frame",
		{ BackgroundColor3 = C.pink, Size = UDim2.fromScale(1, 1), Parent = timerBack },
		{ corner() }
	)
	local promptButton = make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.navy,
		FontFace = Ui.font,
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromScale(0.5, 0.3),
		TextColor3 = C.cream,
		TextScaled = true,
		Parent = prompt,
	}, {
		corner(10),
		make("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }),
	})

	local activeId = 0
	local tapsLeft = 0
	local buttonText = ""
	local function refreshButton()
		promptButton.Text = if tapsLeft > 1 then `{buttonText} ({tapsLeft})` else buttonText
	end
	promptButton.Activated:Connect(function()
		if tapsLeft <= 0 then
			return
		end
		answerEvent:FireServer(activeId)
		tapsLeft -= 1
		if tapsLeft <= 0 then
			prompt.Visible = false
		else
			refreshButton()
		end
	end)

	temptationEvent.OnClientEvent:Connect(function(id: number, kind: string, window: number)
		local spec = PROMPTS[kind]
		if not spec then
			return
		end
		activeId = id
		tapsLeft = if kind == "Friend" then 3 elseif spec.button then 1 else 0
		buttonText = spec.button or ""
		refreshButton()
		promptText.Text = spec.text
		promptButton.Visible = spec.button ~= nil
		prompt.BackgroundColor3 = if spec.button then C.cream else C.pink
		promptText.TextColor3 = if spec.button then C.navy else C.cream
		prompt.Visible = true
		timerFill.Size = UDim2.fromScale(1, 1)
		TweenService:Create(
			timerFill,
			TweenInfo.new(window, Enum.EasingStyle.Linear),
			{ Size = UDim2.fromScale(0, 1) }
		):Play()
		task.delay(window, function()
			if activeId == id then
				prompt.Visible = false
			end
		end)
	end)

	-- 3. Gave in to the party ---------------------------------------------------------------------
	local gaveIn = make("Frame", {
		BackgroundColor3 = C.partyWall,
		BackgroundTransparency = 0.15,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = gui,
	})
	label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromScale(0.7, 0.12),
		Text = "You gave in to the party",
		TextColor3 = C.pink,
		Parent = gaveIn,
	})
	local gaveInStats = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromScale(0.5, 0.06),
		Parent = gaveIn,
	})
	label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.82),
		Size = UDim2.fromScale(0.5, 0.05),
		Text = "Now tempt the others until dawn",
		Parent = gaveIn,
	})
	player:GetAttributeChangedSignal("Team"):Connect(function()
		if player:GetAttribute("Team") ~= "Partier" then
			return
		end
		prompt.Visible = false
		activeId = 0
		gaveInStats.Text =
			`You lasted until {player:GetAttribute("LastedUntil") or "?"} · {player:GetAttribute(
				"NightPoints"
			) or 0} HP`
		gaveIn.Visible = true
		task.delay(4, function()
			gaveIn.Visible = false
		end)
	end)

	-- 4. Dawn results -----------------------------------------------------------------------------
	local dawn = make(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = gui }
	)
	label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.fromScale(0.4, 0.07),
		Text = "Dawn · 6:00 AM",
		TextColor3 = C.navy,
		BackgroundColor3 = C.dawn,
		BackgroundTransparency = 0,
		Parent = dawn,
	}, {
		corner(),
		make("UIPadding", { PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.15, 0) }),
	})
	local card = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.cream,
		Position = UDim2.fromScale(0.5, 0.18),
		Size = UDim2.fromScale(0.5, 0),
		Parent = dawn,
	}, {
		corner(14),
		make("UIPadding", {
			PaddingTop = UDim.new(0.05, 0),
			PaddingBottom = UDim.new(0.05, 0),
			PaddingLeft = UDim.new(0.05, 0),
			PaddingRight = UDim.new(0.05, 0),
		}),
		make(
			"UIListLayout",
			{ Padding = UDim.new(0.02, 0), SortOrder = Enum.SortOrder.LayoutOrder }
		),
	})
	local nextNight = label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.93),
		Size = UDim2.fromScale(0.3, 0.05),
		TextColor3 = C.navy,
		Parent = dawn,
	})

	local function row(order: number, left: string, right: string, bold: boolean)
		local line = make("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = card,
		})
		label({
			Size = UDim2.fromScale(0.55, 1),
			Text = left,
			TextColor3 = C.navy,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = if bold then Ui.font else Font.fromEnum(Enum.Font.Gotham),
			Parent = line,
		})
		label({
			Position = UDim2.fromScale(0.55, 0),
			Size = UDim2.fromScale(0.45, 1),
			Text = right,
			TextColor3 = C.navy,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = line,
		})
	end

	-- First top-3 finish this session: ask to favorite (no reward; Roblox forbids rewarding favorites).
	-- ponytail: once per session, not once per account; save a flag if players find it nagging.
	local askedFavorite = false
	resultsEvent.OnClientEvent:Connect(function(results: { any })
		for i, result in results do
			if i <= 3 and result.userId == player.UserId and not askedFavorite then
				askedFavorite = true
				task.delay(4, function() -- after the Dawn card has had its moment
					pcall(function()
						AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
					end)
				end)
			end
		end
	end)

	resultsEvent.OnClientEvent:Connect(function(results: { any })
		for _, child in card:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local mine = nil
		for i, result in results do
			if result.userId == player.UserId then
				mine = result
			end
			if i <= 5 then
				local name = if result.userId == player.UserId then "You" else result.name
				row(
					i,
					`{i}. {name}`,
					result.lasted or "Locked in all night",
					result.userId == player.UserId
				)
			end
		end
		if mine and mine.earned then
			local levelText = if (mine.levelAfter or 1) > (mine.levelBefore or 1)
				then `LEVEL UP! {mine.station} Lv {mine.levelAfter}`
				else `{mine.station} Lv {mine.levelAfter or 1}`
			local reward = make("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 52,
				Size = UDim2.new(1, 0, 0, 30),
				Parent = card,
			})
			label({
				Size = UDim2.fromScale(1, 1),
				Text = `+{mine.earned} HP · {levelText}`,
				TextColor3 = C.orange,
				Parent = reward,
			})
		end
		if mine then
			make("Frame", {
				BackgroundColor3 = C.rule,
				BorderSizePixel = 0,
				LayoutOrder = 50,
				Size = UDim2.new(1, 0, 0, 2),
				Parent = card,
			})
			local line = make("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 51,
				Size = UDim2.new(1, 0, 0, 30),
				Parent = card,
			})
			label({
				Size = UDim2.fromScale(1, 1),
				Text = `While they partied, you hit {mine.perfects} Perfects · {mine.points} HP`
					.. if (mine.party or 0) > 0 then ` · {mine.party} party pts` else "",
				TextColor3 = C.navy,
				Parent = line,
			})
		end
		-- Size the card to its rows (list padding 6, card padding 14 top and bottom).
		local height = 28
		for _, child in card:GetChildren() do
			if child:IsA("Frame") then
				height += child.Size.Y.Offset + 6
			end
		end
		card.Size = UDim2.new(0.5, 0, 0, height)
	end)

	-- Phase changes: show the right screen, move the sky between night and dawn -----------------
	local function onPhase()
		local phase = ReplicatedStorage:GetAttribute("Phase")
		dusk.Visible = phase == "Dusk"
		dawn.Visible = phase == "Dawn"
		if phase ~= "Night" then
			prompt.Visible = false
		end
		local clockTime = if phase == "Dawn" then 6.3 else 0
		TweenService:Create(Lighting, TweenInfo.new(3), { ClockTime = clockTime }):Play()
	end
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(onPhase)
	onPhase()

	-- Countdowns tick once a second.
	task.spawn(function()
		while true do
			local endsAt = ReplicatedStorage:GetAttribute("PhaseEnds")
			if typeof(endsAt) == "number" then
				duskTitle.Text = `Dusk · pick your practice · {Ui.countdown(endsAt)}`
				nextNight.Text = `Next night in {Ui.countdown(endsAt)}`
			end
			task.wait(0.5)
		end
	end)
end

return NightScreens
