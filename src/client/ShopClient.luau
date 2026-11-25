--!strict
-- Side buttons (Shop, Daily, Gifts with a red dot when something is ready), the cosmetics shop
-- and the rewards panel. All state comes from player attributes the server publishes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarketplaceService = game:GetService("MarketplaceService")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Products = require(ReplicatedStorage.Shared.Products)
local BeatClock = require(ReplicatedStorage.Shared.BeatClock)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local StationFx = require(script.Parent.StationFx)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RhythmRemotes")
local buyRemote = remotes:WaitForChild("ShopBuy") :: RemoteFunction
local equipRemote = remotes:WaitForChild("ShopEquip") :: RemoteFunction
local dailyRemote = remotes:WaitForChild("ClaimDaily") :: RemoteFunction
local giftRemote = remotes:WaitForChild("ClaimGift") :: RemoteFunction
local groupRemote = remotes:WaitForChild("ClaimGroup") :: RemoteFunction
local codeRemote = remotes:WaitForChild("RedeemCode") :: RemoteFunction
local offsetRemote = remotes:WaitForChild("SetTapOffset") :: RemoteFunction

local C = Ui.colors
local make, corner, label = Ui.make, Ui.corner, Ui.label
local TABS = {
	{ slot = "trail", name = "Trails" },
	{ slot = "title", name = "Titles" },
	{ slot = "ball", name = "Ball" },
	{ slot = "robux", name = "Robux" },
}
-- Robux tab cards, in order.
local ROBUX_CARDS = {
	{ key = "vip", name = "VIP: x2 Huss", robux = 199, color = "FAC775" },
	{ key = "hp_small", name = "500 Huss", robux = 25, color = "FFB547" },
	{ key = "hp_medium", name = "1,750 Huss", robux = 75, color = "FFB547" },
	{ key = "hp_large", name = "5,000 Huss", robux = 199, color = "FFB547" },
	{ key = "huss_boost", name = "x2 Boost: 3 nights", robux = 29, color = "5CC8C8" },
	{ key = "throw_party", name = "Throw a Party", robux = 99, color = "FF2E93" },
}
local REASONS = {
	NotEnoughHP = "Not enough Huss yet",
	AlreadyOwned = "You already own this",
	AlreadyClaimed = "Already claimed",
	NotYet = "Not yet",
	NotInGroup = "Join the group first",
	NoGroup = "Group coming soon",
	Invalid = "Unknown code",
	AlreadyRedeemed = "Already used",
}

local ShopClient = {}

-- Opens the Robux prompt for a card; returns a note to show, or nil.
local function promptRobux(key: string): string?
	if key == "vip" then
		if Products.vipPassId == 0 then
			return "Coming soon"
		end
		MarketplaceService:PromptGamePassPurchase(player, Products.vipPassId)
		return nil
	end
	local product = Products.items[key]
	if not product or product.id == 0 then
		return "Coming soon"
	end
	MarketplaceService:PromptProductPurchase(player, product.id)
	return nil
end

local function owned(): { [string]: boolean }
	local set = {}
	for id in string.gmatch(tostring(player:GetAttribute("Owned") or ""), "[^,]+") do
		set[id] = true
	end
	return set
end

local function panel(gui: ScreenGui, title: string): (Frame, Frame, TextLabel)
	local frame = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.cream,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.72),
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	}, { corner(16) })
	label({
		Position = UDim2.fromScale(0.04, 0.04),
		Size = UDim2.fromScale(0.4, 0.1),
		Text = title,
		TextColor3 = C.navy,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
		Parent = frame,
	})
	local note = label({
		Position = UDim2.fromScale(0.45, 0.05),
		Size = UDim2.fromScale(0.38, 0.08),
		Text = "",
		TextColor3 = Color3.fromHex("854F0B"),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 21,
		Parent = frame,
	})
	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = C.navy,
		FontFace = Ui.font,
		Position = UDim2.fromScale(0.97, 0.04),
		Size = UDim2.fromScale(0.08, 0.1),
		Text = "X",
		TextColor3 = C.cream,
		TextScaled = true,
		ZIndex = 21,
		Parent = frame,
	}, { corner(10) })
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	local body = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.04, 0.18),
		Size = UDim2.fromScale(0.92, 0.78),
		ZIndex = 21,
		Parent = frame,
	})
	return frame, body, note
end

local function button(parent: Instance, text: string, color: Color3, textColor: Color3): TextButton
	return make("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = color,
		FontFace = Ui.font,
		Text = text,
		TextColor3 = textColor,
		TextScaled = true,
		ZIndex = 22,
		Parent = parent,
	}, {
		corner(10),
		make("UIPadding", {
			PaddingTop = UDim.new(0.15, 0),
			PaddingBottom = UDim.new(0.15, 0),
			PaddingLeft = UDim.new(0.1, 0),
			PaddingRight = UDim.new(0.1, 0),
		}),
	})
end

function ShopClient.start()
	local gui = make("ScreenGui", {
		Name = "ShopScreens",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Shop ----------------------------------------------------------------------------------------
	local shop, shopBody, shopNote = panel(gui, "Shop")
	local currentTab = "trail"
	local tabRow = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.13),
		ZIndex = 21,
		Parent = shopBody,
	}, {
		make(
			"UIListLayout",
			{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0) }
		),
	})
	local grid = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0.17),
		Size = UDim2.fromScale(1, 0.83),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		ZIndex = 21,
		Parent = shopBody,
	}, {
		make("UIGridLayout", {
			CellPadding = UDim2.fromScale(0.02, 0.04),
			CellSize = UDim2.fromScale(0.235, 0.44),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local tabButtons: { [string]: TextButton } = {}

	local renderShop: () -> ()
	local function act(id: string, item: Cosmetics.Item)
		local mine = owned()
		local reason
		if not mine[id] then
			reason = buyRemote:InvokeServer(id)
			if not reason then
				reason = equipRemote:InvokeServer(item.slot, id)
			end
		elseif player:GetAttribute(`Equipped_{item.slot}`) == id then
			reason = equipRemote:InvokeServer(item.slot, nil)
		else
			reason = equipRemote:InvokeServer(item.slot, id)
		end
		shopNote.Text = if reason then REASONS[reason] or reason else ""
		renderShop()
	end

	renderShop = function()
		shopNote.Text = if shopNote.Text ~= ""
			then shopNote.Text
			else `{player:GetAttribute("HP") or 0} HP`
		for slot, tab in tabButtons do
			tab.BackgroundColor3 = if slot == currentTab then C.navy else C.rule
			tab.TextColor3 = if slot == currentTab then C.cream else C.navy
		end
		for _, child in grid:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		if currentTab == "robux" then
			for order, card in ROBUX_CARDS do
				local frame = make("Frame", {
					BackgroundColor3 = Color3.new(1, 1, 1),
					LayoutOrder = order,
					ZIndex = 22,
					Parent = grid,
				}, { corner(10) })
				make("Frame", {
					BackgroundColor3 = Color3.fromHex(card.color),
					Position = UDim2.fromScale(0.08, 0.08),
					Size = UDim2.fromScale(0.84, 0.3),
					ZIndex = 23,
					Parent = frame,
				}, { corner(6) })
				label({
					Position = UDim2.fromScale(0.05, 0.42),
					Size = UDim2.fromScale(0.9, 0.22),
					Text = card.name,
					TextColor3 = C.navy,
					ZIndex = 23,
					Parent = frame,
				})
				local owns = card.key == "vip" and player:GetAttribute("VIP") == true
				local action = button(
					frame,
					if owns then "Owned" else `R$ {card.robux}`,
					if owns then Color3.fromHex("C0DD97") else C.orange,
					C.navy
				)
				action.Position = UDim2.fromScale(0.08, 0.7)
				action.Size = UDim2.fromScale(0.84, 0.24)
				action.Activated:Connect(function()
					if not owns then
						shopNote.Text = promptRobux(card.key) or ""
					end
				end)
			end
			return
		end
		local mine = owned()
		local ids = {}
		for id, item in Cosmetics.items do
			if item.slot == currentTab and (item.price or mine[id]) then
				table.insert(ids, id)
			end
		end
		table.sort(ids, function(a, b)
			return (Cosmetics.items[a].price or 0) < (Cosmetics.items[b].price or 0)
		end)
		for order, id in ids do
			local item = Cosmetics.items[id]
			local equipped = player:GetAttribute(`Equipped_{item.slot}`) == id
			local status = if equipped
				then "Equipped"
				elseif mine[id] then "Owned"
				else `{item.price} Huss`
			local card = make("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				LayoutOrder = order,
				ZIndex = 22,
				Parent = grid,
			}, { corner(10) })
			make("Frame", {
				BackgroundColor3 = if item.colors then Color3.fromHex(item.colors[1]) else C.navy,
				Position = UDim2.fromScale(0.08, 0.08),
				Size = UDim2.fromScale(0.84, 0.3),
				ZIndex = 23,
				Parent = card,
			}, { corner(6) })
			label({
				Position = UDim2.fromScale(0.05, 0.42),
				Size = UDim2.fromScale(0.9, 0.22),
				Text = item.name,
				TextColor3 = C.navy,
				ZIndex = 23,
				Parent = card,
			})
			local action = button(
				card,
				status,
				if equipped then Color3.fromHex("C0DD97") else C.orange,
				C.navy
			)
			action.Position = UDim2.fromScale(0.08, 0.7)
			action.Size = UDim2.fromScale(0.84, 0.24)
			action.Activated:Connect(function()
				act(id, item)
			end)
		end
	end

	for _, tab in TABS do
		local tabButton = button(tabRow, tab.name, C.rule, C.navy)
		tabButton.Size = UDim2.fromScale(0.18, 1)
		tabButton.Activated:Connect(function()
			currentTab = tab.slot
			shopNote.Text = ""
			renderShop()
		end)
		tabButtons[tab.slot] = tabButton
	end

	-- Rewards (Daily + Gifts share one panel) ------------------------------------------------------
	local rewards, rewardsBody, rewardsNote = panel(gui, "Rewards")
	local calendar = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.4),
		ZIndex = 21,
		Parent = rewardsBody,
	}, {
		make(
			"UIListLayout",
			{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.012, 0) }
		),
	})
	local gifts = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.46),
		Size = UDim2.fromScale(1, 0.54),
		ZIndex = 21,
		Parent = rewardsBody,
	}, {
		make(
			"UIGridLayout",
			{ CellPadding = UDim2.fromScale(0.02, 0.06), CellSize = UDim2.fromScale(0.32, 0.27) }
		),
	})
	local claimedGifts: { [number]: boolean } = {}

	local function dailyReady(): boolean
		local lastDay = tonumber(player:GetAttribute("DailyLastDay")) or 0
		return lastDay ~= Rewards.today(os.time())
	end
	local function giftReady(): boolean
		local joined = tonumber(player:GetAttribute("JoinedAt")) or math.huge
		for _, gift in Rewards.gifts do
			if
				not claimedGifts[gift.minutes]
				and workspace:GetServerTimeNow() - joined >= gift.minutes * 60
			then
				return true
			end
		end
		return false
	end

	-- Cells are built once; refreshRewards() only updates their text and colour, so a tap is
	-- never lost to a rebuild while the countdowns tick.
	local dayCells: { TextButton } = {}
	for day, hp in Rewards.daily do
		local cell = button(calendar, "", C.rule, C.navy)
		cell.Size = UDim2.fromScale(0.13, 1)
		cell.Activated:Connect(function()
			local state = {
				lastDay = tonumber(player:GetAttribute("DailyLastDay")) or 0,
				streak = tonumber(player:GetAttribute("DailyStreak")) or 0,
			}
			if dailyReady() and day == Rewards.nextDailyDay(state, Rewards.today(os.time())) then
				local reason = dailyRemote:InvokeServer()
				rewardsNote.Text = if reason then REASONS[reason] or reason else `+{hp} Huss`
			end
		end)
		dayCells[day] = cell
	end
	local giftCells: { TextButton } = {}
	for i, gift in Rewards.gifts do
		local cell = button(gifts, "", C.rule, C.navy)
		cell.LayoutOrder = i
		cell.Activated:Connect(function()
			local reason = giftRemote:InvokeServer(gift.minutes)
			if not reason or reason == "AlreadyClaimed" then
				claimedGifts[gift.minutes] = true
			end
			rewardsNote.Text = if reason then REASONS[reason] or reason else `+{gift.hp} Huss`
		end)
		giftCells[i] = cell
	end
	local groupButton = button(gifts, `Join the group · {Rewards.groupHp} Huss`, C.navy, C.cream)
	groupButton.LayoutOrder = #Rewards.gifts + 1
	groupButton.Activated:Connect(function()
		local reason = groupRemote:InvokeServer()
		rewardsNote.Text = if reason then REASONS[reason] or reason else `+{Rewards.groupHp} Huss`
	end)

	-- Code row under the gifts: box + Redeem, result on the line below.
	local codeRow = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.83),
		Size = UDim2.fromScale(1, 0.17),
		ZIndex = 21,
		Parent = rewardsBody,
	})
	local codeBox = make("TextBox", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClearTextOnFocus = false,
		FontFace = Ui.font,
		PlaceholderText = "type a code...",
		Size = UDim2.fromScale(0.66, 0.6),
		Text = "",
		TextColor3 = C.navy,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
		Parent = codeRow,
	}, { corner(10), make("UIPadding", { PaddingLeft = UDim.new(0.02, 0) }) }) :: TextBox
	local redeemButton = button(codeRow, "Redeem", C.orange, C.navy)
	redeemButton.Position = UDim2.fromScale(0.68, 0)
	redeemButton.Size = UDim2.fromScale(0.32, 0.6)
	local codeResult = label({
		Position = UDim2.fromScale(0, 0.62),
		Size = UDim2.fromScale(0.66, 0.38),
		Text = "",
		TextColor3 = Color3.fromHex("854F0B"),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
		Parent = codeRow,
	})
	local function redeem()
		if codeBox.Text == "" then
			return
		end
		local hp, reason = codeRemote:InvokeServer(codeBox.Text)
		codeResult.Text = if hp then `+{hp} Huss!` else REASONS[reason] or tostring(reason)
		if hp then
			codeBox.Text = ""
		end
	end
	redeemButton.Activated:Connect(redeem)
	codeBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			redeem()
		end
	end)

	local function refreshRewards()
		local state = {
			lastDay = tonumber(player:GetAttribute("DailyLastDay")) or 0,
			streak = tonumber(player:GetAttribute("DailyStreak")) or 0,
		}
		local nextDay = Rewards.nextDailyDay(state, Rewards.today(os.time()))
		local ready = dailyReady()
		for day, cell in dayCells do
			local hp = Rewards.daily[day]
			local claimable = day == nextDay and ready
			local done = day < nextDay or (day == nextDay and not ready)
			cell.Text = if claimable
				then `Day {day}\nClaim`
				else `Day {day}\n{hp}{if day == 7 then " + trail" else ""}`
			cell.BackgroundColor3 = if claimable
				then C.orange
				elseif done then Color3.fromHex("C0DD97")
				else C.rule
		end
		local now = workspace:GetServerTimeNow()
		local joined = tonumber(player:GetAttribute("JoinedAt")) or now
		for i, gift in Rewards.gifts do
			local left = math.max(0, gift.minutes * 60 - (now - joined))
			local cell = giftCells[i]
			cell.Text = if claimedGifts[gift.minutes]
				then `{gift.minutes} min · claimed`
				elseif left > 0 then `{gift.minutes} min · {gift.hp} Huss · {Ui.countdown(
					now + left
				)}`
				else `{gift.minutes} min · Claim {gift.hp} Huss`
			cell.BackgroundColor3 = if left <= 0 and not claimedGifts[gift.minutes]
				then C.orange
				else C.rule
		end
		groupButton.Visible = player:GetAttribute("GroupClaimed") ~= true
	end

	-- Timing: tap along to 8 thuds; the average lateness becomes the saved calibration -------------
	local CAL_BEATS, CAL_BPM = 8, 100
	local timing, timingBody, timingNote = panel(gui, "Timing")
	label({
		Size = UDim2.fromScale(1, 0.2),
		Text = "Using earbuds? Tap along to the beat so we can match your sound.",
		TextColor3 = C.navy,
		TextWrapped = true,
		ZIndex = 22,
		Parent = timingBody,
	})
	local calDots: { Frame } = {}
	for i = 1, CAL_BEATS do
		calDots[i] = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = C.rule,
			Position = UDim2.fromScale(0.15 + (i - 1) * 0.1, 0.3),
			Size = UDim2.fromScale(0.06, 0.06),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			ZIndex = 22,
			Parent = timingBody,
		}, { corner() })
	end
	local calTap = button(timingBody, "TAP", C.orange, C.navy)
	calTap.Position = UDim2.fromScale(0.3, 0.4)
	calTap.Size = UDim2.fromScale(0.4, 0.25)
	local calResult = label({
		Position = UDim2.fromScale(0, 0.68),
		Size = UDim2.fromScale(1, 0.12),
		Text = "",
		TextColor3 = C.navy,
		ZIndex = 22,
		Parent = timingBody,
	})
	local calRetry = button(timingBody, "Retry", C.rule, C.navy)
	calRetry.Position = UDim2.fromScale(0.2, 0.84)
	calRetry.Size = UDim2.fromScale(0.25, 0.15)
	local calSave = button(timingBody, "Save", C.navy, C.cream)
	calSave.Position = UDim2.fromScale(0.55, 0.84)
	calSave.Size = UDim2.fromScale(0.25, 0.15)

	local calTaps: { number } = {}
	local calBeats: { number } = {}
	local calOffset: number? = nil
	local calRun = 0
	local function runCalibration()
		calRun += 1
		local run = calRun
		table.clear(calTaps)
		table.clear(calBeats)
		calOffset = nil
		calSave.Visible = false
		local saved = math.round((tonumber(player:GetAttribute("TapOffset")) or 0) * 1000)
		calResult.Text = `Get ready... (now {saved} ms)`
		local first = os.clock() + 1.5
		for i = 1, CAL_BEATS do
			calBeats[i] = first + (i - 1) * 60 / CAL_BPM
			calDots[i].BackgroundColor3 = C.rule
		end
		for i, at in calBeats do
			task.wait(math.max(0, at - os.clock()))
			if run ~= calRun or not timing.Visible then
				return
			end
			StationFx.play("kick")
			calDots[i].BackgroundColor3 = C.orange
		end
		task.wait(0.4)
		if run ~= calRun then
			return
		end
		calOffset = BeatClock.averageOffset(calTaps, calBeats, 0.25, 5)
		if calOffset then
			local ms = math.round(calOffset * 1000)
			calResult.Text = if math.abs(ms) < 15
				then "Your timing is spot on!"
				else `You tap {math.abs(ms)} ms {if ms > 0 then "late" else "early"} → Save to adjust`
			calSave.Visible = true
		else
			calResult.Text = "Not enough taps on the beat. Retry!"
		end
	end
	calTap.Activated:Connect(function()
		table.insert(calTaps, os.clock())
	end)
	calRetry.Activated:Connect(function()
		task.spawn(runCalibration)
	end)
	calSave.Activated:Connect(function()
		if calOffset then
			local reason = offsetRemote:InvokeServer(calOffset)
			timingNote.Text = if reason then REASONS[reason] or reason else "Saved ✓"
		end
	end)

	-- Side buttons -----------------------------------------------------------------------------
	-- Side buttons: chunky colour tiles with an icon and label (assets/ui, scripts/ui_icons.py).
	local side = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 28, 0.45, 0), -- room for the labels spilling past the tiles
		Size = UDim2.fromScale(0.1, 0.62),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Parent = gui,
	}, { make("UIListLayout", { Padding = UDim.new(0.07, 0) }) })
	local dots: { [string]: Frame } = {}
	local SIDE = {
		{ "Shop", "74703712629649", "FF9628", "EB5A14" },
		{ "Daily", "85898827711145", "5AD278", "28A05A" },
		{ "Gifts", "77368354228555", "BE6EFF", "8246DC" },
		{ "Timing", "126839820801921", "46C8FF", "1E8CDC" },
	}
	for i, spec in SIDE do
		local side_button = make("TextButton", {
			AutoButtonColor = true,
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = i,
			Size = UDim2.fromScale(1, 0.2),
			Text = "",
			ZIndex = 5,
			Parent = side,
		}, {
			corner(14),
			make("UIGradient", {
				Color = ColorSequence.new(Color3.fromHex(spec[3]), Color3.fromHex(spec[4])),
				Rotation = 90,
			}),
			make("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(0, 0, 0),
				Thickness = 4,
			}),
			make("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://" .. spec[2],
				Position = UDim2.fromScale(0.5, 0.42),
				Size = UDim2.fromScale(0.74, 0.74),
				ZIndex = 6,
			}),
			-- The label spills over the bottom edge, Roblox-style.
			Ui.shout({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.94),
				Rotation = -4,
				Size = UDim2.fromScale(1.35, 0.4),
				Text = string.upper(spec[1]),
				ZIndex = 7,
			}),
		})
		dots[spec[1]] = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromHex("FF3250"),
			Position = UDim2.fromScale(0.92, 0.08),
			Size = UDim2.fromScale(0.32, 0.32),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			Visible = false,
			ZIndex = 7,
			Parent = side_button,
		}, {
			corner(),
			make("UIStroke", { Color = C.navy, Thickness = 2 }),
			Ui.label({
				Size = UDim2.fromScale(1, 1),
				Text = "!",
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 8,
			}),
		})
		side_button.Activated:Connect(function()
			if spec[1] == "Timing" then
				shop.Visible, rewards.Visible = false, false
				timing.Visible = not timing.Visible
				timingNote.Text = ""
				if timing.Visible then
					task.spawn(runCalibration)
				end
			elseif spec[1] == "Shop" then
				timing.Visible = false
				rewards.Visible = false
				shop.Visible = not shop.Visible
				shopNote.Text = ""
				renderShop()
			else
				shop.Visible, timing.Visible = false, false
				rewards.Visible = not rewards.Visible
				rewardsNote.Text = ""
				refreshRewards()
			end
		end)
	end

	-- Keep dots, open panels and the ball skin in step with saved data.
	for _, name in
		{
			"HP",
			"Owned",
			"Equipped_trail",
			"Equipped_title",
			"Equipped_ball",
			"DailyLastDay",
			"GroupClaimed",
		}
	do
		player:GetAttributeChangedSignal(name):Connect(function()
			if shop.Visible then
				renderShop()
			end
		end)
	end
	-- Second Wind: shown to a trainer at low focus during the night, once per night.
	local secondWind = button(gui, "Second Wind", C.mint, C.navy)
	secondWind.AnchorPoint = Vector2.new(0.5, 0)
	secondWind.Position = UDim2.fromScale(0.5, 0.12)
	secondWind.Size = UDim2.fromScale(0.2, 0.08)
	secondWind.ZIndex = 8
	secondWind.Visible = false
	secondWind.Activated:Connect(function()
		if (tonumber(player:GetAttribute("SecondWinds")) or 0) > 0 then
			remotes:WaitForChild("UseSecondWind"):InvokeServer()
		else
			local note = promptRobux("second_wind")
			if note then
				secondWind.Text = note
			end
		end
	end)
	local function refreshSecondWind()
		local focus = tonumber(player:GetAttribute("Focus")) or 100
		secondWind.Visible = player:GetAttribute("Team") == "Trainer"
			and ReplicatedStorage:GetAttribute("Phase") == "Night"
			and player:GetAttribute("UsedSecondWind") ~= true
			and focus > 0
			and focus < Products.secondWindShowBelow
		if secondWind.Visible and secondWind.Text ~= "Coming soon" then
			local banked = tonumber(player:GetAttribute("SecondWinds")) or 0
			secondWind.Text = if banked > 0
				then `Second Wind ({banked})`
				else `Second Wind · R$ {Products.items.second_wind.robux}`
		end
	end
	for _, name in { "Focus", "Team", "UsedSecondWind", "SecondWinds" } do
		player:GetAttributeChangedSignal(name):Connect(refreshSecondWind)
	end
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(refreshSecondWind)

	-- Someone threw a party: banner for everyone.
	local banner = label({
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.pink,
		BackgroundTransparency = 0,
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromScale(0.5, 0.07),
		Visible = false,
		ZIndex = 8,
		Parent = gui,
	}, {
		corner(12),
		make("UIPadding", { PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.15, 0) }),
	})
	remotes:WaitForChild("PartyThrown").OnClientEvent:Connect(function(name: string)
		banner.Text = `{name} threw a party! +{Products.partyHpForEveryone} Huss for everyone`
		banner.Visible = true
		task.delay(5, function()
			banner.Visible = false
		end)
	end)

	task.spawn(function()
		while true do
			dots.Daily.Visible = dailyReady()
			dots.Gifts.Visible = giftReady()
			if rewards.Visible then
				refreshRewards()
			end
			task.wait(1)
		end
	end)
end

-- Ball skin from the shop, shown on your own ball.
function ShopClient.applyBallSkin(ball: BasePart)
	local plain, plainMaterial = ball.Color, ball.Material
	local function apply()
		local item = Cosmetics.items[player:GetAttribute("Equipped_ball") :: string]
		ball.Color = if item and item.colors then Color3.fromHex(item.colors[1]) else plain
		ball.Material = if item then Enum.Material.Neon else plainMaterial
	end
	player:GetAttributeChangedSignal("Equipped_ball"):Connect(apply)
	apply()
end

return ShopClient
