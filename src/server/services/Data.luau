--!strict
-- Saved player data through ProfileStore (session-locked, autosaving). Mirrors what the client
-- shows into attributes: "HP" (Huss Points), "Lv_<Station>" per station, "Rank".
-- Also fills the Roblox player list (leaderstats) with HP and Rank.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Night = require(ReplicatedStorage.Shared.Night)
local Progress = require(ReplicatedStorage.Shared.Progress)
local Products = require(ReplicatedStorage.Shared.Products)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Stats = require(ReplicatedStorage.Shared.Stats)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local Analytics = require(script.Parent.Analytics)
local Badges = require(script.Parent.Badges)

export type Data = {
	hp: number,
	stationXp: { [string]: number },
	nights: number,
	owned: { [string]: boolean },
	equipped: { [string]: string },
	daily: { lastDay: number, streak: number },
	groupClaimed: boolean,
	receipts: { string }, -- recent Robux purchase ids, so a receipt is never granted twice
	secondWinds: number, -- bought but not yet used
	tutorialDone: boolean,
	codes: { [string]: boolean }, -- redeem codes already used
	tapOffset: number, -- timing calibration in seconds (positive = audio heard late)
	boostNights: number, -- nights of x2 Huss left from Huss Boost purchases
	stats: Stats.Stats, -- lifetime stats for the leaderboards
	volume: { music: number, beat: number, sfx: number }, -- Settings sliders, 0-2 (1 = default)
	partyTickets: number, -- each skips one night's practice (Gifts; Party Animal skips for free)
}

local TEMPLATE: Data = {
	hp = 0,
	stationXp = { Basketball = 0, Gym = 0, Burgers = 0 },
	nights = 0,
	owned = {},
	equipped = {},
	daily = { lastDay = 0, streak = 0 },
	groupClaimed = false,
	receipts = {},
	secondWinds = 0,
	tutorialDone = false,
	codes = {},
	tapOffset = 0,
	boostNights = 0,
	stats = Stats.new(),
	volume = { music = 1, beat = 1, sfx = 1 },
	partyTickets = 0,
}

local store = ProfileStore.New("PlayerData_v1", TEMPLATE)
local profiles: { [Player]: any } = {}

local Data = {}

local function totalLevels(data: Data): number
	local total = 0
	for _, station in Night.stations do
		total += Progress.level(data.stationXp[station] or 0)
	end
	return total
end

-- Push saved values to attributes and the player list.
local function publish(player: Player, data: Data)
	player:SetAttribute("HP", data.hp)
	for _, station in Night.stations do
		player:SetAttribute(`Lv_{station}`, Progress.level(data.stationXp[station] or 0))
	end
	local rank = Progress.rank(totalLevels(data))
	player:SetAttribute("Rank", rank)
	-- Shop and rewards state for the client screens.
	local owned = {}
	for id in data.owned do
		table.insert(owned, id)
	end
	player:SetAttribute("Owned", table.concat(owned, ","))
	if data.owned.perk_party_animal then
		player:SetAttribute("PartyAnimal", true) -- bought with Huss; the pass sets it too (Store)
	end
	for _, slot in Cosmetics.slots do
		player:SetAttribute(`Equipped_{slot}`, data.equipped[slot])
	end
	player:SetAttribute("DailyLastDay", data.daily.lastDay)
	player:SetAttribute("DailyStreak", data.daily.streak)
	player:SetAttribute("GroupClaimed", data.groupClaimed)
	player:SetAttribute("SecondWinds", data.secondWinds)
	player:SetAttribute("TutorialDone", data.tutorialDone)
	player:SetAttribute("TapOffset", data.tapOffset)
	player:SetAttribute("BoostNights", data.boostNights)
	player:SetAttribute("Vol_music", data.volume.music)
	player:SetAttribute("Vol_beat", data.volume.beat)
	player:SetAttribute("Vol_sfx", data.volume.sfx)
	player:SetAttribute("PartyTickets", data.partyTickets)
	-- Own leaderboard values, so the Ranks panel can pin the player's row.
	for _, category in Stats.categories do
		player:SetAttribute(`Stat_{category.key}`, Stats.value(data.hp, data.stats, category.key))
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		(stats:FindFirstChild("Huss") :: IntValue).Value = data.hp;
		(stats:FindFirstChild("Rank") :: StringValue).Value = rank
	end
	Badges.check(player, data)
end

-- Saves now (after a Robux purchase) instead of waiting for the autosave.
function Data.save(player: Player)
	local profile = profiles[player]
	if profile then
		profile:Save()
	end
end

function Data.get(player: Player): Data?
	local profile = profiles[player]
	return profile and profile.Data
end

-- Change saved data and push the result to the client. `change` returns a reason string to
-- refuse (nothing is published) or nil to accept.
-- transaction/sku: when the change moves Huss, logged as an economy event (Analytics.economy).
function Data.update(
	player: Player,
	change: (Data) -> string?,
	transaction: string?,
	sku: string?
): string?
	local data = Data.get(player)
	if not data then
		return "NotLoaded"
	end
	local before = data.hp
	local refused = change(data)
	if not refused then
		publish(player, data)
		if transaction and data.hp ~= before then
			Analytics.economy(player, data.hp - before, data.hp, transaction, sku)
		end
	end
	return refused
end

-- Credit one night: Huss Points plus XP for the station the player practised.
-- Returns the station level before and after, for the Dawn card.
-- Credits a night's Huss and practice XP. Returns the level before and after, the Huss actually
-- credited (after group, VIP and boost) and whether a boost night was used.
function Data.creditNight(
	player: Player,
	hp: number,
	station: string,
	xp: number
): (number, number, number, boolean)
	local data = Data.get(player)
	if not data then
		return 1, 1, 0, false
	end
	local before = Progress.level(data.stationXp[station] or 0)
	local boosted = data.boostNights > 0
	local multiplier, boostLeft = Products.nightMultiplier(
		player:GetAttribute("InGroup") == true,
		Rewards.groupBonus,
		player:GetAttribute("VIP") == true,
		data.boostNights
	)
	data.boostNights = boostLeft
	local credited = math.max(0, math.floor(hp * multiplier))
	data.hp += credited
	if credited > 0 then
		Analytics.economy(player, credited, data.hp, "Gameplay", `Night_{station}`)
	end
	data.stationXp[station] = (data.stationXp[station] or 0) + math.max(0, math.floor(xp))
	data.nights += 1
	publish(player, data)
	return before, Progress.level(data.stationXp[station]), credited, boosted
end

-- Lifetime leaderboard stats (best combo, dawns, drag-ins, party points).
function Data.recordStats(player: Player, change: Stats.Change)
	local data = Data.get(player)
	if data then
		Stats.apply(data.stats, change)
		publish(player, data)
	end
end

-- Playtime counts from join; banked at each Dawn and when the player leaves.
local sessionStart: { [Player]: number } = {}
function Data.bankPlaytime(player: Player)
	local started = sessionStart[player]
	if started then
		sessionStart[player] = os.clock()
		Data.recordStats(player, { seconds = os.clock() - started })
	end
end

local function onPlayerAdded(player: Player)
	sessionStart[player] = os.clock()
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	Instance.new("IntValue", stats).Name = "Huss"
	Instance.new("StringValue", stats).Name = "Rank"
	stats.Parent = player

	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Couldn't load your save. Please rejoin.")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your save was opened on another server. Please rejoin.")
	end)
	if player.Parent == Players then
		profiles[player] = profile
		publish(player, profile.Data)
		Analytics.step(player, "Joined")
	else
		profile:EndSession()
	end
end

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
-- Set by Leaderboards: runs while the save is still loaded.
function Data.beforeLeave(_player: Player) end

Players.PlayerRemoving:Connect(function(player)
	Data.bankPlaytime(player)
	Data.beforeLeave(player)
	sessionStart[player] = nil
	local profile = profiles[player]
	if profile then
		profile:EndSession()
	end
end)

return Data
