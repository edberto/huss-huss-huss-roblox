--!strict
-- Lifetime stats for the leaderboards, saved with the player. Pure, so tests can run it.
local Stats = {}

export type Stats = {
	bestCombo: number,
	playtime: number, -- seconds in game
	dawns: { [string]: number }, -- nights finished without giving in, per practice
	draggedIn: number, -- trainers who gave in right after this player tempted them
	partyPoints: number, -- party points earned as a partier, all nights
}

function Stats.new(): Stats
	return {
		bestCombo = 0,
		playtime = 0,
		dawns = { Basketball = 0, Gym = 0, Burgers = 0 },
		draggedIn = 0,
		partyPoints = 0,
	}
end

export type Change = {
	combo: number?, -- a session's longest combo; kept only if it beats the record
	seconds: number?,
	dawnAt: string?, -- the practice of a night survived
	draggedIn: number?,
	partyPoints: number?,
}

function Stats.apply(stats: Stats, change: Change)
	if change.combo then
		stats.bestCombo = math.max(stats.bestCombo, math.floor(change.combo))
	end
	if change.seconds and change.seconds > 0 then
		stats.playtime += math.floor(change.seconds)
	end
	if change.dawnAt then
		stats.dawns[change.dawnAt] = (stats.dawns[change.dawnAt] or 0) + 1
	end
	if change.draggedIn then
		stats.draggedIn += change.draggedIn
	end
	if change.partyPoints and change.partyPoints > 0 then
		stats.partyPoints += math.floor(change.partyPoints)
	end
end

-- The leaderboards, in board order. `key` names the OrderedDataStore; `board` groups the
-- categories that rotate on one floating board.
Stats.categories = table.freeze({
	{ key = "hp", title = "MOST HUSS", short = "HUSS", board = "Center", color = "FFBE28" },
	{
		key = "bestCombo",
		title = "LONGEST COMBO",
		short = "COMBO",
		board = "Left",
		color = "50DCFF",
	},
	{
		key = "playtime",
		title = "MOST PLAYTIME",
		short = "PLAYTIME",
		board = "Left",
		color = "50DCFF",
	},
	{
		key = "dawns_Basketball",
		title = "BASKETBALL DAWNS",
		short = "BASKETBALL",
		board = "Right",
		color = "5AD278",
	},
	{ key = "dawns_Gym", title = "GYM DAWNS", short = "GYM", board = "Right", color = "50AAFF" },
	{
		key = "dawns_Burgers",
		title = "BURGERS DAWNS",
		short = "BURGERS",
		board = "Right",
		color = "FF5A5A",
	},
	{
		key = "draggedIn",
		title = "TRAINERS DRAGGED IN",
		short = "DRAGGED IN",
		board = "Party",
		color = "FF50C8",
	},
	{
		key = "partyPoints",
		title = "PARTY POINTS",
		short = "PARTY PTS",
		board = "Party",
		color = "FF50C8",
	},
})

-- A category's value for a player's saved data (hp lives outside stats).
function Stats.value(hp: number, stats: Stats, key: string): number
	if key == "hp" then
		return hp
	end
	local station = string.match(key, "^dawns_(.+)$")
	if station then
		return stats.dawns[station] or 0
	end
	return (stats :: any)[key] or 0
end

-- How a value reads on a board: playtime as hours/minutes, combos as x12, the rest with commas.
function Stats.format(key: string, value: number): string
	if key == "playtime" then
		local hours = value // 3600
		return if hours > 0 then `{hours}h {value % 3600 // 60}m` else `{value // 60}m`
	elseif key == "bestCombo" then
		return `x{value}`
	end
	local text = tostring(math.floor(value))
	while true do
		local next, n = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
		text = next
		if n == 0 then
			return text
		end
	end
end

return Stats
