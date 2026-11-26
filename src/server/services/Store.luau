--!strict
-- Robux purchases (design doc: monetization): VIP pass, HP packs, Second Wind, Throw a Party.
-- Receipts are recorded in the player's save so each purchase is granted exactly once.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Products = require(ReplicatedStorage.Shared.Products)
local Data = require(script.Parent.Data)
local Focus = require(script.Parent.Focus)

local RECEIPTS_KEPT = 50

local remotes = ReplicatedStorage:WaitForChild("RhythmRemotes")
local useSecondWind = Instance.new("RemoteFunction")
useSecondWind.Name = "UseSecondWind" -- spend a banked Second Wind; returns nil or a reason
useSecondWind.Parent = remotes
local partyEvent = Instance.new("RemoteEvent")
partyEvent.Name = "PartyThrown" -- server -> all clients: thrower's display name
partyEvent.Parent = remotes

-- Second Wind can be used once per night by a trainer who is still in.
local function trySecondWind(player: Player): boolean
	if player:GetAttribute("UsedSecondWind") == true then
		return false
	end
	if Focus.refill(player, Products.secondWindFocus) then
		player:SetAttribute("UsedSecondWind", true)
		return true
	end
	return false
end

useSecondWind.OnServerInvoke = function(player: Player): string?
	return Data.update(player, function(data)
		if data.secondWinds <= 0 then
			return "NoneBanked"
		end
		if not trySecondWind(player) then
			return "NotNow"
		end
		data.secondWinds -= 1
		return nil
	end)
end

-- Everyone in the server gets a little HP and sees who threw the party.
local function throwParty(thrower: Player)
	partyEvent:FireAllClients(thrower.DisplayName)
	for _, player in Players:GetPlayers() do
		Data.update(player, function(data)
			data.hp += Products.partyHpForEveryone
			return nil
		end, "Gameplay", "ThrownParty")
	end
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local key, product = Products.byId(receipt.ProductId)
	if not player or not product or not Data.get(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries later
	end
	local alreadyGranted = false
	Data.update(player, function(data)
		if table.find(data.receipts, receipt.PurchaseId) then
			alreadyGranted = true
			return "Duplicate"
		end
		if product.hp then
			data.hp += product.hp
		elseif key == "second_wind" then
			data.secondWinds += 1
		elseif key == "huss_boost" then
			data.boostNights += Products.boostNights
		end
		table.insert(data.receipts, receipt.PurchaseId)
		while #data.receipts > RECEIPTS_KEPT do
			table.remove(data.receipts, 1)
		end
		return nil
	end, "IAP", key)
	if not alreadyGranted then
		Data.save(player)
		if key == "second_wind" then
			-- Bought mid-night at low focus: use it straight away.
			Data.update(player, function(data)
				if data.secondWinds > 0 and trySecondWind(player) then
					data.secondWinds -= 1
					return nil
				end
				return "NotNow"
			end)
		elseif key == "throw_party" then
			throwParty(player)
		end
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function checkVip(player: Player)
	if Products.vipPassId == 0 then
		return
	end
	local ok, owns = pcall(
		MarketplaceService.UserOwnsGamePassAsync,
		MarketplaceService,
		player.UserId,
		Products.vipPassId
	)
	player:SetAttribute("VIP", ok and owns)
end

local function checkPartyAnimal(player: Player)
	if Products.partyAnimalPassId == 0 then
		return
	end
	local ok, owns = pcall(
		MarketplaceService.UserOwnsGamePassAsync,
		MarketplaceService,
		player.UserId,
		Products.partyAnimalPassId
	)
	if ok and owns then -- never false: the Huss-bought perk sets it too (Data)
		player:SetAttribute("PartyAnimal", true)
	end
end

-- Starter Pack pass: its Huss, trail and Boost nights are granted once (Data.starterPack),
-- whether it was bought here or on the game page.
local function checkStarter(player: Player)
	for _ = 1, 30 do -- wait for the save
		if Data.get(player) or not player.Parent then
			break
		end
		task.wait(1)
	end
	local data = Data.get(player)
	if not data or data.starterPack then
		return
	end
	local ok, owns = pcall(
		MarketplaceService.UserOwnsGamePassAsync,
		MarketplaceService,
		player.UserId,
		Products.starterPassId
	)
	if not (ok and owns) then
		return
	end
	Data.update(player, function(fresh)
		if fresh.starterPack then
			return "AlreadyGranted"
		end
		fresh.starterPack = true
		fresh.hp += Products.starterHp
		fresh.owned.trail_starter = true
		fresh.boostNights += Products.boostNights
		return nil
	end, "IAP", "starter_pack")
	Data.save(player)
end

Players.PlayerAdded:Connect(checkStarter)
Players.PlayerAdded:Connect(checkVip)
Players.PlayerAdded:Connect(checkPartyAnimal)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == Products.vipPassId then
		player:SetAttribute("VIP", true)
	elseif purchased and passId == Products.partyAnimalPassId then
		player:SetAttribute("PartyAnimal", true)
	elseif purchased and passId == Products.starterPassId then
		task.spawn(checkStarter, player)
	end
end)

return {}
