--!strict
-- Points and combo for one practice session. Pure, so the server can own it and tests can run it.
local BeatClock = require(script.Parent.BeatClock)

export type State = { points: number, combo: number, perfects: number }

local Score = {}

Score.points = table.freeze({ Perfect = 3, Good = 1, Almost = 0, Miss = 0 })
Score.maxMultiplier = 4
Score.comboPerStep = 8 -- every 8 hits in a row raise the multiplier by 1
Score.skillBonus = 2 -- the skill move (every 4th beat) pays double

function Score.new(): State
	return { points = 0, combo = 0, perfects = 0 }
end

function Score.multiplier(combo: number): number
	return math.min(Score.maxMultiplier, 1 + combo // Score.comboPerStep)
end

-- Returns the next state and the points this tap earned. "Almost" keeps the combo (design doc),
-- "Miss" resets it. `skill` is true on the skill-move beat.
function Score.apply(state: State, grade: BeatClock.Grade, skill: boolean?): (State, number)
	if grade == "Miss" then
		return { points = state.points, combo = 0, perfects = state.perfects }, 0
	end
	local earned = Score.points[grade]
		* Score.multiplier(state.combo)
		* (if skill then Score.skillBonus else 1)
	local combo = if grade == "Almost" then state.combo else state.combo + 1
	local perfects = state.perfects + (if grade == "Perfect" then 1 else 0)
	return { points = state.points + earned, combo = combo, perfects = perfects }, earned
end

return Score
