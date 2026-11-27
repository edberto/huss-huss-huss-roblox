--!strict
-- Daily quests card (top right, under the Huss count) at Dusk and Dawn, and a banner when a
-- quest completes. State comes from the "Quests" attribute (Data); rules in Shared/Quests.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Quests = require(ReplicatedStorage.Shared.Quests)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local make, corner, label = Ui.make, Ui.corner, Ui.label

local GOLD = Color3.fromHex("FFCD3C")
local MINT = Color3.fromHex("46EBA0")
local NAVY = Color3.fromHex("281A5A")
local DARK = Color3.fromHex("190F37")
local LILAC = Color3.fromHex("C8B4E6")
local BAR = { MINT, Color3.fromHex("FF5AC8"), Color3.fromHex("50DCFF") }

local QuestClient = {}

local function stroke(thickness: number): UIStroke
	return make("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.new(0, 0, 0),
		Thickness = thickness,
	})
end

function QuestClient.start()
	local gui = make("ScreenGui", {
		Name = "QuestScreens",
		DisplayOrder = 1, -- under the shop and settings panels
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- The card: title, 3 rows (text, reward, progress bar), bonus line.
	local card = make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = NAVY,
		BackgroundTransparency = 0.05,
		Size = UDim2.fromOffset(300, 290),
		Visible = false,
		Parent = gui,
	}, { corner(16), stroke(3.5) })
	local scale = make("UIScale", { Parent = card })
	local title = Ui.shout({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.fromOffset(270, 30),
		Text = "TODAY'S QUESTS",
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Thickness = 2.5,
		Parent = card,
	})
	local resets = label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(286, 252),
		Size = UDim2.fromOffset(80, 18),
		Text = "",
		TextColor3 = LILAC,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = card,
	})
	type Row = { name: TextLabel, reward: TextLabel, fill: Frame, count: TextLabel }
	local rows: { Row } = {}
	for i = 1, 3 do
		local row = make("Frame", {
			BackgroundColor3 = DARK,
			Position = UDim2.fromOffset(10, 46 + (i - 1) * 66),
			Size = UDim2.fromOffset(280, 58),
			Parent = card,
		}, { corner(12), stroke(2.5) })
		local fill = make("Frame", {
			BackgroundColor3 = BAR[i],
			Size = UDim2.fromScale(0, 1),
		}, { corner(8) })
		local count = label({
			Size = UDim2.fromScale(1, 1),
			Text = "",
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 3,
		}, { stroke(1.5) })
		make("Frame", {
			BackgroundColor3 = Color3.fromHex("0A0619"),
			Position = UDim2.fromOffset(10, 36),
			Size = UDim2.fromOffset(260, 14),
			Parent = row,
		}, { corner(8), fill, count })
		rows[i] = {
			name = label({
				Position = UDim2.fromOffset(10, 6),
				Size = UDim2.fromOffset(200, 24),
				FontFace = Ui.display,
				Text = "",
				TextColor3 = Color3.new(1, 1, 1),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			}, { make("UITextSizeConstraint", { MaxTextSize = 20 }) }),
			reward = label({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromOffset(270, 6),
				Size = UDim2.fromOffset(60, 24),
				FontFace = Ui.display,
				Text = "",
				TextColor3 = GOLD,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = row,
			}),
			fill = fill,
			count = count,
		}
	end
	local bonus = label({
		Position = UDim2.fromOffset(14, 248),
		Size = UDim2.fromOffset(190, 26),
		FontFace = Ui.display,
		Text = `All 3: +{Quests.bonus} bonus`,
		TextColor3 = Color3.fromHex("FFE63C"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})

	local folded = false -- set by the overlap check below
	local function refresh()
		local ok, list =
			pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Quests") or "[]")
		list = if ok and typeof(list) == "table" then list else {}
		local allDone = #list > 0
		for i, row in rows do
			local quest = list[i]
			local rowFrame = row.name.Parent :: Frame
			rowFrame.Visible = quest ~= nil
			if quest then
				row.name.Text = quest.text
				row.reward.Text = if quest.done then "DONE" else `+{quest.reward}`
				row.reward.TextColor3 = if quest.done then MINT else GOLD
				row.fill.Size = UDim2.fromScale(math.clamp(quest.progress / quest.goal, 0, 1), 1)
				row.count.Text = `{math.floor(quest.progress)}/{quest.goal}`
				allDone = allDone and quest.done
			end
		end
		local doneCount = 0
		for _, quest in list do
			doneCount += if quest.done then 1 else 0
		end
		title.Text = if folded then `TODAY'S QUESTS · {doneCount}/{#list}` else "TODAY'S QUESTS"
		for _, row in rows do
			local rowFrame = row.name.Parent :: Frame
			rowFrame.Visible = rowFrame.Visible and not folded
		end
		bonus.Visible = not folded
		resets.Visible = not folded
		bonus.Text = if allDone then "All 3 done!" else `All 3: +{Quests.bonus} bonus`
		card.Visible = #list > 0 and ReplicatedStorage:GetAttribute("Phase") ~= "Night"
	end
	-- On small screens the card would cover the Dusk cards or the Dawn card (frames holding a
	-- "QuestCardAvoid" marker): it folds to its title row, with done/3, until there's room.
	local function overlapping(): boolean
		-- The unfolded card's rectangle, whatever it shows now.
		local a = card.AbsolutePosition
		local b = a + Vector2.new(300, 290) * scale.Scale
		for _, marker in player.PlayerGui:GetDescendants() do
			local frame = marker.Parent
			if
				marker.Name == "QuestCardAvoid"
				and frame
				and frame:IsA("GuiObject")
				and frame.Visible
			then
				local screen = frame:FindFirstAncestorWhichIsA("ScreenGui")
				local shown = screen ~= nil and screen.Enabled
				local ancestor = frame.Parent
				while shown and ancestor and ancestor:IsA("GuiObject") do
					shown = ancestor.Visible
					ancestor = ancestor.Parent
				end
				local c, d = frame.AbsolutePosition, frame.AbsolutePosition + frame.AbsoluteSize
				if shown and a.X < d.X and c.X < b.X and a.Y < d.Y and c.Y < b.Y then
					return true
				end
			end
		end
		return false
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			local fold = card.Visible and overlapping()
			if fold ~= folded then
				folded = fold
				card.Size = if folded then UDim2.fromOffset(300, 44) else UDim2.fromOffset(300, 290)
				refresh()
			end
		end
	end)

	player:GetAttributeChangedSignal("Quests"):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(refresh)
	refresh()

	-- Under the Huss pill, and under the friend chip when it shows (RhythmClient).
	local function place()
		local s = Ui.hudScale()
		local friends = (tonumber(player:GetAttribute("FriendsHere")) or 0) > 0
		scale.Scale = s
		card.Position = UDim2.new(1, -16, 0, (8 + 46 + 10 + (if friends then 32 else 0)) * s)
	end
	Ui.onResize(place)
	player:GetAttributeChangedSignal("FriendsHere"):Connect(place)

	task.spawn(function()
		while true do
			local left = 86400 - os.time() % 86400 -- quests reset with the UTC day
			resets.Text = if left >= 3600
				then `resets in {left // 3600}h`
				else `resets in {left // 60}m`
			task.wait(30)
		end
	end)

	-- Banner when a quest completes (also mid-night).
	local banner = Ui.shout({
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = NAVY,
		BackgroundTransparency = 0,
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.fromOffset(470, 54),
		Text = "",
		TextColor3 = GOLD,
		Thickness = 2.5,
		Visible = false,
		Parent = gui,
	})
	corner(20).Parent = banner
	stroke(3.5).Parent = banner
	make("UIPadding", {
		PaddingTop = UDim.new(0.2, 0),
		PaddingBottom = UDim.new(0.16, 0),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		Parent = banner,
	})
	local bannerScale = make("UIScale", { Parent = banner })
	local queue: { string } = {}
	local showing = false
	local function nextBanner()
		if showing or #queue == 0 then
			return
		end
		showing = true
		banner.Text = table.remove(queue, 1) :: string
		banner.Visible = true
		bannerScale.Scale = 0.6 * Ui.hudScale()
		TweenService
			:Create(
				bannerScale,
				TweenInfo.new(0.2, Enum.EasingStyle.Back),
				{ Scale = Ui.hudScale() }
			)
			:Play()
		task.delay(2.6, function()
			banner.Visible = false
			showing = false
			nextBanner()
		end)
	end
	(ReplicatedStorage:WaitForChild("QuestDone") :: RemoteEvent).OnClientEvent:Connect(
		function(text: string, huss: number)
			table.insert(
				queue,
				if text == "All 3 quests!"
					then `ALL 3 QUESTS DONE!  +{huss} HUSS`
					else `QUEST DONE!  {text}  +{huss} HUSS`
			)
			nextBanner()
		end
	)
end

return QuestClient
