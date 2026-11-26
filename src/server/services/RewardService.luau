--!strict
-- Daily check-in, playtime gifts and the group reward (design doc: rewards for joining and
-- coming back). Likes and favourites are never rewarded; the client only asks for them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Data = require(script.Parent.Data)
local RedeemCodes = require(script.Parent.RedeemCodes)

-- The game's Roblox group. 0 turns the group reward off until the group exists.
local GROUP_ID = 962391373 -- Flamingo Skies Pier

local remotes = ReplicatedStorage:WaitForChild("RhythmRemotes")
local function remote(name: string): RemoteFunction
	local r = Instance.new("RemoteFunction")
	r.Name = name
	r.Parent = remotes
	return r
end
local claimDaily = remote("ClaimDaily") -- returns nil or a failure reason
local claimGift = remote("ClaimGift") -- arg: minutes threshold; returns nil or a reason
local claimGroup = remote("ClaimGroup") -- returns nil or a reason
local completeTutorial = remote("CompleteTutorial") -- first Dawn reached; returns nil or a reason

local redeemCode = remote("RedeemCode") -- arg: typed code; returns HP granted, or nil and a reason

local TUTORIAL_HP = 100

redeemCode.OnServerInvoke = function(player: Player, input: unknown): (number?, string?)
	if typeof(input) ~= "string" or #input > 40 then
		return nil, "Invalid"
	end
	local granted
	local failure = Data.update(player, function(data)
		local hp, keyOrReason = Rewards.redeem(RedeemCodes, data.codes, input, os.time())
		if not hp then
			return keyOrReason
		end
		data.codes[keyOrReason] = true
		data.hp += hp
		granted = hp
		return nil
	end, "TimedReward", "Code")
	return granted, failure
end

completeTutorial.OnServerInvoke = function(player: Player): string?
	return Data.update(player, function(data)
		if data.tutorialDone then
			return "AlreadyClaimed"
		end
		data.tutorialDone = true
		data.hp += TUTORIAL_HP
		return nil
	end, "Onboarding", "Tutorial")
end

local joinedAt: { [Player]: number } = {}
local giftsClaimed: { [Player]: { [number]: boolean } } = {}

claimDaily.OnServerInvoke = function(player: Player): string?
	return Data.update(player, function(data)
		local nextState, day = Rewards.claimDaily(data.daily, Rewards.today(os.time()))
		if not day then
			return "AlreadyClaimed"
		end
		data.daily = nextState
		data.hp += Rewards.daily[day]
		if day == #Rewards.daily then
			data.owned[Rewards.dailyItem] = true
		end
		return nil
	end, "TimedReward", "Daily")
end

claimGift.OnServerInvoke = function(player: Player, minutes: unknown): string?
	local gift
	for _, entry in Rewards.gifts do
		if entry.minutes == minutes then
			gift = entry
		end
	end
	local claimed = giftsClaimed[player]
	if not gift or not claimed or not joinedAt[player] then
		return "NoSuchGift"
	elseif claimed[gift.minutes] then
		return "AlreadyClaimed"
	elseif os.clock() - joinedAt[player] < gift.minutes * 60 then
		return "NotYet"
	end
	return Data.update(player, function(data)
		claimed[gift.minutes] = true
		data.hp += gift.hp or 0
		data.partyTickets += gift.tickets or 0
		return nil
	end, "TimedReward", "PlaytimeGift")
end

claimGroup.OnServerInvoke = function(player: Player): string?
	if GROUP_ID == 0 then
		return "NoGroup"
	end
	local ok, inGroup = pcall(player.IsInGroup, player, GROUP_ID)
	if not ok or not inGroup then
		return "NotInGroup"
	end
	player:SetAttribute("InGroup", true)
	return Data.update(player, function(data)
		if data.groupClaimed then
			return "AlreadyClaimed"
		end
		data.groupClaimed = true
		data.hp += Rewards.groupHp
		return nil
	end, "TimedReward", "Group")
end

Players.PlayerAdded:Connect(function(player)
	joinedAt[player] = os.clock()
	giftsClaimed[player] = {}
	player:SetAttribute("JoinedAt", workspace:GetServerTimeNow())
	player:SetAttribute("GroupId", GROUP_ID)
	if GROUP_ID ~= 0 then
		local ok, inGroup = pcall(player.IsInGroup, player, GROUP_ID)
		player:SetAttribute("InGroup", ok and inGroup)
	end
end)
Players.PlayerRemoving:Connect(function(player)
	joinedAt[player] = nil
	giftsClaimed[player] = nil
end)

-- Friend bonus: "FriendsHere" = how many of the player's Roblox friends share the server
-- (Products.nightMultiplier turns it into +10% each, up to +50%).
local friendPairs: { [Player]: { [Player]: boolean } } = {}
local function countFriends(player: Player)
	local count = 0
	for _ in friendPairs[player] or {} do
		count += 1
	end
	player:SetAttribute("FriendsHere", count)
end
Players.PlayerAdded:Connect(function(player)
	friendPairs[player] = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and friendPairs[other] then
			local ok, friends = pcall(player.IsFriendsWith, player, other.UserId)
			if ok and friends and player.Parent and other.Parent then
				friendPairs[player][other] = true
				friendPairs[other][player] = true
				countFriends(other)
			end
		end
	end
	countFriends(player)
end)
Players.PlayerRemoving:Connect(function(player)
	for other in friendPairs[player] or {} do
		if friendPairs[other] then
			friendPairs[other][player] = nil
			countFriends(other)
		end
	end
	friendPairs[player] = nil
end)

return {}
