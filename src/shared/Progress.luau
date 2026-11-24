--!strict
-- Progression rules (design doc: progression and economy). Pure, so the server applies them and
-- tests check them: station levels from XP, the Locked-In rank, and what a night pays.
local Progress = {}

Progress.maxLevel = 100
Progress.xpStep = 50 -- level L -> L+1 costs 50 * L XP

-- Rank by the sum of all station levels: { minimum total, name }, lowest first.
Progress.ranks = table.freeze({
	{ 0, "Rookie" },
	{ 10, "Grinder" },
	{ 25, "Locked In" },
	{ 50, "Pro" },
	{ 100, "Legend" },
	{ 200, "GOAT" },
})

-- Dawn rewards in Huss Points (design doc).
Progress.lastStandingBonus = 500
Progress.topThreeBonus = 250
Progress.finishBonus = 50
Progress.placementMinPlayers = 3 -- placement bonuses need a real field to beat

-- Total XP needed to reach `level` from level 1.
function Progress.xpForLevel(level: number): number
	return Progress.xpStep * level * (level - 1) // 2
end

function Progress.level(xp: number): number
	local level = 1
	while level < Progress.maxLevel and xp >= Progress.xpForLevel(level + 1) do
		level += 1
	end
	return level
end

function Progress.rank(totalLevels: number): string
	local name = Progress.ranks[1][2]
	for _, entry in Progress.ranks do
		if totalLevels >= entry[1] then
			name = entry[2]
		end
	end
	return name
end

-- What one player earns for a night. `place` is 1 for whoever lasted longest; `players` is how
-- many took part; `finished` means locked in until dawn.
-- Practice points after the station's difficulty bonus (Night.stationInfo).
function Progress.stationPoints(points: number, bonus: number): number
	return math.floor(points * (1 + bonus))
end

function Progress.nightReward(
	points: number,
	partyPoints: number,
	place: number,
	players: number,
	finished: boolean
): number
	local hp = math.floor(points) + math.floor(partyPoints)
	if players >= Progress.placementMinPlayers then
		if place == 1 then
			hp += Progress.lastStandingBonus
		elseif place <= 3 then
			hp += Progress.topThreeBonus
		end
	end
	if finished then
		hp += Progress.finishBonus
	end
	return hp
end

return Progress
