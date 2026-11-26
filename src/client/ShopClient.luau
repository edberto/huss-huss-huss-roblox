--!strict
-- Side buttons (Shop, Daily, Gifts with a red dot when something is ready), the cosmetics shop
-- and the rewards panel. All state comes from player attributes the server publishes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local MarketplaceService = game:GetService("MarketplaceService")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Products = require(ReplicatedStorage.Shared.Products)
local BeatClock = require(ReplicatedStorage.Shared.BeatClock)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Ranks = require(script.Parent.Ranks)
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
local volumeRemote = remotes:WaitForChild("SetVolume") :: RemoteFunction

local C = Ui.colors
local make, corner, label = Ui.make, Ui.corner, Ui.label
local TABS = {
	{ slot = "trail", name = "Trails" },
	{ slot = "title", name = "Titles" },
	{ slot = "ball", name = "Ball" },
	{ slot = "dance", name = "Dances" },
	{ slot = "perk", name = "Perks" },
	{ slot = "robux", name = "Robux" },
}
-- Robux tab cards, in order.
local ROBUX_CARDS = {
	{ key = "vip", name = "VIP: x2 Huss", robux = 199, color = "FAC775" },
	{ key = "party_animal", name = "Party Animal", robux = 149, color = "FF2E93" },
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
	local passId = if key == "vip"
		then Products.vipPassId
		elseif key == "party_animal" then Products.partyAnimalPassId
		else nil
	if passId then
		if passId == 0 then
			return "Coming soon"
		end
		MarketplaceService:PromptGamePassPurchase(player, passId)
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

local BLACK, WHITE, GOLD = Color3.new(0, 0, 0), Color3.new(1, 1, 1), Color3.fromHex("FFD75A")
local GOLD_TILE = Color3.fromHex("FFC83C") -- a reward ready to claim
local PURPLE, CARD, IDLE =
	Color3.fromHex("23164B"), Color3.fromHex("32235F"), Color3.fromHex("3C2D6E")
local GREEN = Color3.fromHex("5AD278")

local function outline(thickness: number): UIStroke
	return make("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = BLACK,
		Thickness = thickness,
	})
end

-- A purple panel with a big title, a note on the right and a round X; pops in when opened.
local function panel(gui: ScreenGui, title: string): (Frame, Frame, TextLabel)
	local scale = make("UIScale", {})
	local frame = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = PURPLE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.74),
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	}, { corner(24), outline(5), scale })
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			scale.Scale = 0.85
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 })
				:Play()
		end
	end)
	Ui.shout({
		Position = UDim2.fromScale(0.04, 0.035),
		Size = UDim2.fromScale(0.4, 0.11),
		Text = string.upper(title),
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Thickness = 4,
		ZIndex = 21,
		Parent = frame,
	})
	local note = Ui.shout({
		Position = UDim2.fromScale(0.42, 0.055),
		Size = UDim2.fromScale(0.42, 0.07),
		Text = "",
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Right,
		Thickness = 2.5,
		ZIndex = 21,
		Parent = frame,
	})
	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromHex("FF505A"),
		Position = UDim2.fromScale(0.975, 0.035),
		Size = UDim2.fromScale(0.1, 0.1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Text = "",
		ZIndex = 21,
		Parent = frame,
	}, {
		corner(),
		outline(3),
		Ui.shout({ Size = UDim2.fromScale(1, 1), Text = "X", Thickness = 2.5, ZIndex = 22 }),
	})
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

-- A chunky button: solid colour, black outline, gloss, white outlined text. `_textColor` is
-- kept for callers; text is always white with a black outline now.
local function button(
	parent: Instance,
	text: string,
	color: Color3,
	_textColor: Color3?
): TextButton
	return make("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = color,
		FontFace = Ui.display,
		Text = text,
		TextColor3 = WHITE,
		TextScaled = true,
		ZIndex = 22,
		Parent = parent,
	}, {
		corner(12),
		outline(3),
		make("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Color = BLACK,
			Thickness = 2,
		}),
		make("Frame", { -- gloss, kept thin so it never strikes through the text
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.78,
			Position = UDim2.new(0.08, 0, 0, 4),
			Size = UDim2.new(0.84, 0, 0, 5),
			ZIndex = 22,
		}, { corner() }),
		make("UIPadding", {
			PaddingTop = UDim.new(0.17, 0),
			PaddingBottom = UDim.new(0.13, 0),
			PaddingLeft = UDim.new(0.08, 0),
			PaddingRight = UDim.new(0.08, 0),
		}),
	})
end

-- Store icons for the Robux cards, from the pass/product itself (cached; empty if it fails,
-- e.g. in the PLAYTEST place where the products don't exist).
local icons: { [string]: string } = {}
local function iconFor(key: string): string
	if icons[key] == nil then
		icons[key] = ""
		local ok, info = pcall(function()
			if key == "vip" then
				return MarketplaceService:GetProductInfo(Products.vipPassId, Enum.InfoType.GamePass)
			end
			return MarketplaceService:GetProductInfo(Products.items[key].id, Enum.InfoType.Product)
		end)
		if ok and info and info.IconImageAssetId and info.IconImageAssetId > 0 then
			icons[key] = `rbxassetid://{info.IconImageAssetId}`
		end
	end
	return icons[key]
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
		make("UIPadding", { -- room for the cards' outlines
			PaddingTop = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 8),
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
		elseif item.slot == "perk" then
			reason = "AlreadyOwned"
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
			else `{player:GetAttribute("HP") or 0} HUSS`
		for slot, tab in tabButtons do
			tab.BackgroundColor3 = if slot == currentTab then Color3.fromHex("FFBE28") else IDLE
		end
		for _, child in grid:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		if currentTab == "robux" then
			for order, card in ROBUX_CARDS do
				local frame = make("Frame", {
					BackgroundColor3 = CARD,
					LayoutOrder = order,
					ZIndex = 22,
					Parent = grid,
				}, { corner(14), outline(3) })
				local swatch = make("Frame", {
					BackgroundColor3 = Color3.fromHex(card.color),
					Position = UDim2.fromScale(0.08, 0.08),
					Size = UDim2.fromScale(0.84, 0.3),
					ZIndex = 23,
					Parent = frame,
				}, { corner(10), outline(2.5) })
				local icon = make("ImageLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1.5, 1.5),
					SizeConstraint = Enum.SizeConstraint.RelativeYY,
					ZIndex = 24,
					Parent = swatch,
				})
				task.spawn(function()
					icon.Image = iconFor(card.key)
				end)
				label({
					Position = UDim2.fromScale(0.05, 0.42),
					Size = UDim2.fromScale(0.9, 0.22),
					FontFace = Ui.display,
					Text = string.upper(card.name),
					TextColor3 = WHITE,
					ZIndex = 23,
					Parent = frame,
				})
				local owns = (card.key == "vip" and player:GetAttribute("VIP") == true)
					or (card.key == "party_animal" and player:GetAttribute("PartyAnimal") == true)
				local action = button(
					frame,
					if owns then "OWNED" else `R$ {card.robux}`,
					if owns then GREEN else C.orange
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
				elseif item.price == 0 then "Free"
				else `{item.price} Huss`
			local card = make("Frame", {
				BackgroundColor3 = CARD,
				LayoutOrder = order,
				ZIndex = 22,
				Parent = grid,
			}, { corner(14), outline(3) })
			make("Frame", {
				BackgroundColor3 = if item.colors then Color3.fromHex(item.colors[1]) else C.navy,
				Position = UDim2.fromScale(0.08, 0.08),
				Size = UDim2.fromScale(0.84, 0.3),
				ZIndex = 23,
				Parent = card,
			}, { corner(10), outline(2.5) })
			label({
				Position = UDim2.fromScale(0.05, 0.42),
				Size = UDim2.fromScale(0.9, 0.22),
				FontFace = Ui.display,
				Text = string.upper(item.name),
				TextColor3 = WHITE,
				ZIndex = 23,
				Parent = card,
			})
			local action = button(
				card,
				string.upper(status),
				if equipped then GREEN elseif mine[id] then Color3.fromHex("50AAFF") else C.orange
			)
			action.Position = UDim2.fromScale(0.08, 0.7)
			action.Size = UDim2.fromScale(0.84, 0.24)
			action.Activated:Connect(function()
				act(id, item)
			end)
		end
	end

	for _, tab in TABS do
		local tabButton = button(tabRow, string.upper(tab.name), IDLE)
		tabButton.Size = UDim2.fromScale(0.155, 1)
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
		Position = UDim2.fromScale(0, 0.44),
		Size = UDim2.fromScale(1, 0.3),
		ZIndex = 21,
		Parent = rewardsBody,
	}, {
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0.015, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- A reward card: icon (Huss coin or Party Ticket), amount, and a status pill underneath.
	local COIN, TICKET = "rbxassetid://117706289482395", "rbxassetid://96730617685238"
	type RewardCard = { cell: TextButton, icon: ImageLabel, amount: TextLabel, status: TextLabel }
	local function rewardCard(parent: Instance, width: number): RewardCard
		local cell = button(parent, "", IDLE)
		cell.Size = UDim2.fromScale(width, 1)
		local padding = cell:FindFirstChildOfClass("UIPadding")
		if padding then
			padding:Destroy()
		end
		local icon = make("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.04),
			Size = UDim2.fromScale(0.95, 0.46),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 23,
			Parent = cell,
		})
		local amount = Ui.shout({
			Position = UDim2.fromScale(0.05, 0.5),
			Size = UDim2.fromScale(0.9, 0.21),
			Text = "",
			Thickness = 2,
			ZIndex = 23,
			Parent = cell,
		})
		local status = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromHex("140C28"),
			FontFace = Ui.display,
			Position = UDim2.fromScale(0.5, 0.95),
			Size = UDim2.fromScale(0.86, 0.2),
			Text = "",
			TextColor3 = WHITE,
			TextScaled = true,
			ZIndex = 23,
			Parent = cell,
		}, {
			corner(8),
			make("UIStroke", { Color = BLACK, Thickness = 2 }),
			make("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.1, 0) }),
		})
		return { cell = cell, icon = icon, amount = amount, status = status }
	end
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
	local dayCells: { RewardCard } = {}
	for day, hp in Rewards.daily do
		local card = rewardCard(calendar, 0.13)
		local cell = card.cell
		card.icon.Image = COIN
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
		dayCells[day] = card
	end
	local giftCells: { RewardCard } = {}
	for i, gift in Rewards.gifts do
		local card = rewardCard(gifts, 0.188)
		local cell = card.cell
		cell.LayoutOrder = i
		card.icon.Image = if gift.tickets then TICKET else COIN
		card.amount.Text = if gift.tickets then "PARTY TICKET" else tostring(gift.hp)
		cell.Activated:Connect(function()
			local reason = giftRemote:InvokeServer(gift.minutes)
			if not reason or reason == "AlreadyClaimed" then
				claimedGifts[gift.minutes] = true
			end
			rewardsNote.Text = if reason
				then REASONS[reason] or reason
				elseif gift.tickets then `+{gift.tickets} Party Ticket`
				else `+{gift.hp} Huss`
		end)
		giftCells[i] = card
	end
	local groupButton =
		button(rewardsBody, `JOIN THE GROUP · {Rewards.groupHp} HUSS`, Color3.fromHex("FF50C8"))
	groupButton.Position = UDim2.fromScale(0, 0.755)
	groupButton.Size = UDim2.fromScale(1, 0.08)
	groupButton.Activated:Connect(function()
		local reason = groupRemote:InvokeServer()
		rewardsNote.Text = if reason then REASONS[reason] or reason else `+{Rewards.groupHp} Huss`
	end)

	-- Code row under the gifts: box + Redeem, result on the line below.
	local codeRow = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.85),
		Size = UDim2.fromScale(1, 0.15),
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
	}, { corner(12), outline(3), make("UIPadding", { PaddingLeft = UDim.new(0.03, 0) }) }) :: TextBox
	local redeemButton = button(codeRow, "REDEEM", C.orange)
	redeemButton.Position = UDim2.fromScale(0.68, 0)
	redeemButton.Size = UDim2.fromScale(0.32, 0.6)
	local codeResult = label({
		Position = UDim2.fromScale(0, 0.62),
		Size = UDim2.fromScale(0.66, 0.38),
		Text = "",
		TextColor3 = GOLD,
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
		for day, card in dayCells do
			local hp = Rewards.daily[day]
			local claimable = day == nextDay and ready
			local done = day < nextDay or (day == nextDay and not ready)
			card.amount.Text = if day == 7 then `{hp} + TRAIL` else tostring(hp)
			card.status.Text = if claimable then "CLAIM!" elseif done then "✓" else `DAY {day}`
			card.status.BackgroundColor3 = if claimable
				then C.pink
				elseif done then GREEN
				else Color3.fromHex("140C28")
			card.cell.BackgroundColor3 = if claimable then GOLD_TILE else IDLE
		end
		local now = workspace:GetServerTimeNow()
		local joined = tonumber(player:GetAttribute("JoinedAt")) or now
		for i, gift in Rewards.gifts do
			local left = math.max(0, gift.minutes * 60 - (now - joined))
			local card = giftCells[i]
			local claimed = claimedGifts[gift.minutes]
			local claimable = left <= 0 and not claimed
			card.status.Text = if claimed
				then "✓"
				elseif claimable then "CLAIM!"
				else Ui.countdown(now + left)
			card.status.BackgroundColor3 = if claimable
				then C.pink
				elseif claimed then GREEN
				else Color3.fromHex("140C28")
			card.cell.BackgroundColor3 = if claimable then GOLD_TILE else IDLE
		end
		groupButton.Visible = player:GetAttribute("GroupClaimed") ~= true
	end

	-- Timing: tap along to 8 thuds for a first guess, then fine-tune with the slider while a beat
	-- plays and a ring flashes. The offset (sound lateness) is what the server subtracts from taps.
	local CAL_BEATS, CAL_BPM = 8, 100
	local MAX_OFFSET, STEP = 0.3, 0.01
	-- Settings: a SOUND tab (volume sliders) and a TIMING tab (calibration).
	local timing, settingsBody, timingNote = panel(gui, "Settings")
	local settingsTab = "sound"
	local settingsTabRow = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.12),
		ZIndex = 21,
		Parent = settingsBody,
	}, {
		make(
			"UIListLayout",
			{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0) }
		),
	})
	local soundBody = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.16),
		Size = UDim2.fromScale(1, 0.84),
		ZIndex = 21,
		Parent = settingsBody,
	})
	local timingBody = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.16),
		Size = UDim2.fromScale(1, 0.84),
		Visible = false,
		ZIndex = 21,
		Parent = settingsBody,
	})

	-- Volume rows: NAME ... 100%, then − [bar] +, then a hint. 0-200%, saved shortly after the
	-- last change. The attribute is set locally at once so the sound follows the slider.
	local VOLUME_ROWS = {
		{
			key = "music",
			name = "MUSIC",
			color = "FF2E93",
			hint = "The party next door (faint through the wall while you practise)",
		},
		{
			key = "beat",
			name = "BEAT",
			color = "3DFFB0",
			hint = "Your practice groove: kick, hats, bass",
		},
		{
			key = "sfx",
			name = "SOUNDS",
			color = "50DCFF",
			hint = "Your huss voice, ball, doorbell, phone",
		},
	}
	local volumeRefreshers: { () -> () } = {}
	for i, row in VOLUME_ROWS do
		local y = (i - 1) * 0.33
		local attribute = `Vol_{row.key}`
		label({
			Position = UDim2.fromScale(0, y),
			Size = UDim2.fromScale(0.5, 0.1),
			Text = row.name,
			FontFace = Ui.display,
			TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 22,
			Parent = soundBody,
		})
		local percent = Ui.shout({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, y),
			Size = UDim2.fromScale(0.3, 0.1),
			Text = "100%",
			TextColor3 = GOLD,
			TextXAlignment = Enum.TextXAlignment.Right,
			Thickness = 2.5,
			ZIndex = 22,
			Parent = soundBody,
		})
		local down = button(soundBody, "−", IDLE)
		down.Position = UDim2.fromScale(0, y + 0.11)
		down.Size = UDim2.fromScale(0.09, 0.11)
		local up = button(soundBody, "+", IDLE)
		up.Position = UDim2.fromScale(0.91, y + 0.11)
		up.Size = UDim2.fromScale(0.09, 0.11)
		local fill = make("Frame", {
			BackgroundColor3 = Color3.fromHex(row.color),
			Size = UDim2.fromScale(0.5, 1),
			ZIndex = 23,
		}, { corner() })
		local bar = make("Frame", {
			BackgroundColor3 = Color3.fromHex("140C28"),
			Position = UDim2.fromScale(0.12, y + 0.14),
			Size = UDim2.fromScale(0.76, 0.05),
			ZIndex = 22,
			Parent = soundBody,
		}, { corner(), outline(2.5), fill })
		local knob = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = GOLD,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(2.4, 2.4),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ZIndex = 24,
			Parent = bar,
		}, { corner(), outline(3) })
		label({
			Position = UDim2.fromScale(0, y + 0.23),
			Size = UDim2.fromScale(1, 0.07),
			Text = row.hint,
			TextColor3 = Color3.fromHex("C8B4E6"),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 22,
			Parent = soundBody,
		})

		local value = 1
		local saveToken = 0
		local function show()
			fill.Size = UDim2.fromScale(value / 2, 1)
			knob.Position = UDim2.fromScale(value / 2, 0.5)
			percent.Text = `{math.round(value * 100)}%`
		end
		local function set(v: number)
			value = math.clamp(math.round(v * 20) / 20, 0, 2) -- 5% steps
			show()
			player:SetAttribute(attribute, value)
			saveToken += 1
			local token = saveToken
			task.delay(0.6, function()
				if token == saveToken then
					local reason = volumeRemote:InvokeServer(row.key, value)
					if reason then
						timingNote.Text = REASONS[reason] or reason
					end
				end
			end)
		end
		table.insert(volumeRefreshers, function()
			value = tonumber(player:GetAttribute(attribute)) or 1
			show()
		end)
		-- A sample so you hear the new level: a kick for the beat, a huss for sounds.
		local function sample()
			if row.key == "beat" then
				StationFx.play("kick")
			elseif row.key == "sfx" then
				StationFx.play("huss1")
			end
		end
		down.Activated:Connect(function()
			set(value - 0.1)
			sample()
		end)
		up.Activated:Connect(function()
			set(value + 0.1)
			sample()
		end)
		local dragging = false
		local function dragTo(x: number)
			set(math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1) * 2)
		end
		bar.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = true
				dragTo(input.Position.X)
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				dragTo(input.Position.X)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				dragging = false
				sample()
			end
		end)
	end
	local function refreshVolumes()
		for _, refresh in volumeRefreshers do
			refresh()
		end
	end
	label({
		Size = UDim2.fromScale(1, 0.11),
		Text = "Earbuds or lag? Tap along to the beat, then slide until the beat and the flash match.",
		TextColor3 = WHITE,
		TextWrapped = true,
		ZIndex = 22,
		Parent = timingBody,
	})
	local calDots: { Frame } = {}
	for i = 1, CAL_BEATS do
		calDots[i] = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = IDLE,
			Position = UDim2.fromScale(0.15 + (i - 1) * 0.1, 0.19),
			Size = UDim2.fromScale(0.045, 0.045),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			ZIndex = 22,
			Parent = timingBody,
		}, { corner(), outline(2.5) })
	end
	local calTap = button(timingBody, "TAP", C.orange)
	calTap.Position = UDim2.fromScale(0.32, 0.26)
	calTap.Size = UDim2.fromScale(0.36, 0.16)
	local calResult = label({
		Position = UDim2.fromScale(0, 0.44),
		Size = UDim2.fromScale(1, 0.08),
		Text = "",
		TextColor3 = GOLD,
		ZIndex = 22,
		Parent = timingBody,
	})

	-- Slider: − [track with knob] +
	local minus = button(timingBody, "−", IDLE)
	minus.Position = UDim2.fromScale(0, 0.56)
	minus.Size = UDim2.fromScale(0.09, 0.12)
	local plus = button(timingBody, "+", IDLE)
	plus.Position = UDim2.fromScale(0.91, 0.56)
	plus.Size = UDim2.fromScale(0.09, 0.12)
	local track = make("Frame", {
		BackgroundColor3 = Color3.fromHex("140C28"),
		Position = UDim2.fromScale(0.12, 0.595),
		Size = UDim2.fromScale(0.76, 0.05),
		ZIndex = 22,
		Parent = timingBody,
	}, {
		corner(),
		outline(2.5),
		make("Frame", { -- the 0 ms mark
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.5,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 3, 1.6, 0),
			ZIndex = 23,
		}),
	})
	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = GOLD,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(2.4, 2.4),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		ZIndex = 24,
		Parent = track,
	}, { corner(), outline(3) })
	local flash = make("Frame", { -- flashes on the shifted beat
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = IDLE,
		Position = UDim2.fromScale(0.25, 0.76),
		Size = UDim2.fromScale(0.06, 0.06),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		ZIndex = 22,
		Parent = timingBody,
	}, { corner(), outline(3) })
	local offsetText = Ui.shout({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.31, 0.76),
		Size = UDim2.fromScale(0.5, 0.08),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Thickness = 2.5,
		ZIndex = 22,
		Parent = timingBody,
	})
	local calRetry = button(timingBody, "RETRY", IDLE)
	calRetry.Position = UDim2.fromScale(0.04, 0.86)
	calRetry.Size = UDim2.fromScale(0.27, 0.13)
	local calReset = button(timingBody, "RESET", IDLE)
	calReset.Position = UDim2.fromScale(0.365, 0.86)
	calReset.Size = UDim2.fromScale(0.27, 0.13)
	local calSave = button(timingBody, "SAVE", GREEN)
	calSave.Position = UDim2.fromScale(0.69, 0.86)
	calSave.Size = UDim2.fromScale(0.27, 0.13)

	local offset = 0 -- seconds; positive = the sound reaches you late
	local function setOffset(value: number)
		offset = math.clamp(math.round(value / STEP) * STEP, -MAX_OFFSET, MAX_OFFSET)
		knob.Position = UDim2.fromScale(0.5 + offset / (2 * MAX_OFFSET), 0.5)
		local ms = math.round(offset * 1000)
		offsetText.Text = if ms == 0
			then "0 MS · NO ADJUSTMENT"
			else `{if ms > 0 then "+" else ""}{ms} MS · SOUND {if ms > 0
				then "LATE"
				else "EARLY"}`
	end
	minus.Activated:Connect(function()
		setOffset(offset - STEP)
	end)
	plus.Activated:Connect(function()
		setOffset(offset + STEP)
	end)
	calReset.Activated:Connect(function()
		setOffset(0)
	end)
	local dragging = false
	local function dragTo(x: number)
		local fraction = (x - track.AbsolutePosition.X) / track.AbsoluteSize.X
		setOffset((math.clamp(fraction, 0, 1) - 0.5) * 2 * MAX_OFFSET)
	end
	track.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragTo(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			dragTo(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)

	local calTaps: { number } = {}
	local calBeats: { number } = {}
	local calRun = 0
	local calibrating = false
	-- The preview: a beat every 0.6 s, with the ring flashing `offset` after the sound.
	local function preview(run: number)
		local beat = os.clock() + 0.3
		while run == calRun and timing.Visible and not calibrating do
			local soundAt, flashAt = beat, beat + offset
			task.delay(math.max(0, soundAt - os.clock()), function()
				if run == calRun and timing.Visible and not calibrating then
					StationFx.play("kick")
				end
			end)
			task.delay(math.max(0, flashAt - os.clock()), function()
				flash.BackgroundColor3 = GOLD
				task.delay(0.12, function()
					flash.BackgroundColor3 = IDLE
				end)
			end)
			beat += 60 / CAL_BPM
			task.wait(math.max(0, beat - os.clock() - 0.3))
		end
	end
	local function runCalibration()
		calRun += 1
		local run = calRun
		calibrating = true
		table.clear(calTaps)
		table.clear(calBeats)
		setOffset(tonumber(player:GetAttribute("TapOffset")) or 0)
		calResult.Text = "Get ready... tap on every thud"
		local first = os.clock() + 1.5
		for i = 1, CAL_BEATS do
			calBeats[i] = first + (i - 1) * 60 / CAL_BPM
			calDots[i].BackgroundColor3 = IDLE
		end
		for i, at in calBeats do
			task.wait(math.max(0, at - os.clock()))
			if run ~= calRun or not timing.Visible then
				calibrating = false
				return
			end
			StationFx.play("kick")
			calDots[i].BackgroundColor3 = C.orange
		end
		task.wait(0.4)
		if run ~= calRun then
			return
		end
		calibrating = false
		local measured = BeatClock.averageOffset(calTaps, calBeats, 0.25, 5)
		if measured then
			setOffset(measured)
			calResult.Text = "Now slide until the beat and the flash match"
		else
			calResult.Text = "Not enough taps on the beat. Retry, or just use the slider"
		end
		preview(run)
	end
	calTap.Activated:Connect(function()
		table.insert(calTaps, os.clock())
	end)
	calRetry.Activated:Connect(function()
		task.spawn(runCalibration)
	end)
	calSave.Activated:Connect(function()
		local reason = offsetRemote:InvokeServer(offset)
		timingNote.Text = if reason then REASONS[reason] or reason else "SAVED ✓"
	end)

	local settingsTabs: { [string]: TextButton } = {}
	local function showSettingsTab(tab: string)
		settingsTab = tab
		soundBody.Visible = tab == "sound"
		timingBody.Visible = tab == "timing"
		for key, tabButton in settingsTabs do
			tabButton.BackgroundColor3 = if key == tab then Color3.fromHex("FFBE28") else IDLE
		end
		timingNote.Text = ""
		calRun += 1 -- stops a calibration or preview in progress
		if tab == "timing" then
			task.spawn(runCalibration)
		else
			refreshVolumes()
		end
	end
	for _, tab in { { "sound", "SOUND" }, { "timing", "TIMING" } } do
		local tabButton = button(settingsTabRow, tab[2], IDLE)
		tabButton.Size = UDim2.fromScale(0.22, 1)
		tabButton.Activated:Connect(function()
			showSettingsTab(tab[1])
		end)
		settingsTabs[tab[1]] = tabButton
	end

	-- Side buttons -----------------------------------------------------------------------------
	-- Side buttons: chunky colour tiles with an icon and label (assets/ui, scripts/ui_icons.py).
	local side = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 28, 0.46, 0), -- room for the labels spilling past the tiles
		Size = UDim2.fromScale(0.09, 0.74),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Parent = gui,
	}, { make("UIListLayout", { Padding = UDim.new(0.05, 0) }) })
	local dots: { [string]: Frame } = {}
	local SIDE = {
		{ "Shop", "74703712629649", "FF9628", "EB5A14" },
		{ "Daily", "85898827711145", "5AD278", "28A05A" },
		{ "Gifts", "77368354228555", "BE6EFF", "8246DC" },
		{ "Settings", "111747124734544", "46C8FF", "1E8CDC" },
		{ "Ranks", "108570200348915", "FFD23C", "E6A014" },
	}
	for i, spec in SIDE do
		local side_button = make("TextButton", {
			AutoButtonColor = true,
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = i,
			Size = UDim2.fromScale(1, 0.16),
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
			if spec[1] == "Ranks" then
				shop.Visible, rewards.Visible, timing.Visible = false, false, false
				Ranks.toggle()
			elseif spec[1] == "Settings" then
				shop.Visible, rewards.Visible = false, false
				timing.Visible = not timing.Visible
				if timing.Visible then
					showSettingsTab(settingsTab)
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
			"Equipped_dance",
			"PartyAnimal",
			"VIP",
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
	local function useSecondWind()
		if (tonumber(player:GetAttribute("SecondWinds")) or 0) > 0 then
			remotes:WaitForChild("UseSecondWind"):InvokeServer()
		else
			local note = promptRobux("second_wind")
			if note then
				secondWind.Text = note
			end
		end
	end
	secondWind.Activated:Connect(useSecondWind)
	Ui.bind(secondWind, { Enum.KeyCode.G }, { Enum.KeyCode.ButtonY }, useSecondWind)
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
