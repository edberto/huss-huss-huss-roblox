--!strict
-- Roblox badges. Milestones in saved data (station levels, rank, combo, dawns, drag-ins, party
-- points) are checked every time Data publishes; moments (gave in, party night, the whole street
-- giving in) call Badges.award directly. Icons: scripts/badges.py. An id of 0 = not created yet.
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Night = require(ReplicatedStorage.Shared.Night)
local Progress = require(ReplicatedStorage.Shared.Progress)

local Badges = {}

local PRODUCTION = 10778958069 -- universe id

Badges.ids = {
	welcome = 2729952847267139,
	first_dawn = 2410536785469302,
	party_starter = 4336268289171617,
	life_of_party = 3637131010736431,
	cant_resist = 2908580743569424,
	combo_50 = 2838855070897681,
	bad_influence = 188704454098752,
	peer_pressure = 0,
	party_legend = 0,
	hype_crew = 3376701504986193,
	hype_machine = 0,
	full_house = 0,
	rank_grinder = 904989648169522,
	rank_locked_in = 0,
	rank_pro = 0,
	rank_legend = 0,
	rank_goat = 0,
} :: { [string]: number }

-- Station level badges: `{station}_{level}`, e.g. Gym_50.
Badges.levels = { 5, 10, 25, 50, 100, 150, 200 }
local created = { -- station level badges made so far (docs/badges.md)
	Basketball_5 = 1893988389891274,
	Gym_5 = 807095768225117,
	Burgers_5 = 2316353506831693,
	Basketball_10 = 939063667821837,
	Gym_10 = 297372027911914,
	Burgers_10 = 3787531535521495,
}
for _, station in Night.stations do
	for _, level in Badges.levels do
		local key = `{station}_{level}`
		Badges.ids[key] = created[key] or 0
	end
end

-- Tried this session (owned or just awarded), so each badge is asked for once per session.
local tried: { [Player]: { [string]: boolean } } = {}

function Badges.award(player: Player, key: string)
	local id = Badges.ids[key]
	local done = tried[player]
	-- Badges belong to the Production experience; anywhere else (PLAYTEST) awarding fails.
	if game.GameId ~= PRODUCTION or not id or id == 0 or not done or done[key] then
		return
	end
	done[key] = true
	task.spawn(function()
		local ok, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
		if not ok then
			done[key] = nil -- try again on the next check
			warn(`[Badges] {key}: {err}`)
		end
	end)
end

type Data = {
	stationXp: { [string]: number },
	stats: {
		bestCombo: number,
		dawns: { [string]: number },
		draggedIn: number,
		partyPoints: number,
	},
}

local RANKS = {
	rank_grinder = "Grinder",
	rank_locked_in = "Locked In",
	rank_pro = "Pro",
	rank_legend = "Legend",
	rank_goat = "GOAT",
}

-- Milestones reached in saved data. Called by Data whenever it publishes.
function Badges.check(player: Player, data: Data)
	if not tried[player] then
		return
	end
	local total = 0
	for _, station in Night.stations do
		local level = Progress.level(data.stationXp[station] or 0)
		total += level
		for _, need in Badges.levels do
			if level >= need then
				Badges.award(player, `{station}_{need}`)
			end
		end
	end
	for key, name in RANKS do
		for _, entry in Progress.ranks do
			if entry[2] == name and total >= entry[1] then
				Badges.award(player, key)
			end
		end
	end
	local stats = data.stats
	for _, count in stats.dawns do
		if count > 0 then
			Badges.award(player, "first_dawn")
		end
	end
	local milestones = {
		{ stats.bestCombo, 50, "combo_50" },
		{ stats.draggedIn, 1, "life_of_party" },
		{ stats.draggedIn, 10, "bad_influence" },
		{ stats.draggedIn, 50, "peer_pressure" },
		{ stats.draggedIn, 250, "party_legend" },
		{ stats.partyPoints, 1000, "hype_crew" },
		{ stats.partyPoints, 10000, "hype_machine" },
	}
	for _, m in milestones do
		if m[1] >= m[2] then
			Badges.award(player, m[3] :: string)
		end
	end
end

local function joined(player: Player)
	tried[player] = {}
	Badges.award(player, "welcome")
end
Players.PlayerAdded:Connect(joined)
for _, player in Players:GetPlayers() do
	joined(player)
end
Players.PlayerRemoving:Connect(function(player)
	tried[player] = nil
end)

return Badges
