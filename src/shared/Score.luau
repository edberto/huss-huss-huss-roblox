--!strict
-- Points and combo for one practice session. Pure, so the server can own it and tests can run it.
local BeatClock = require(script.Parent.BeatClock)

export type State = { points: number, combo: number }

local Score = {}

Score.points = table.freeze({ Perfect = 3, Good = 1, Almost = 0, Miss = 0 })
Score.maxMultiplier = 4
Score.comboPerStep = 8 -- every 8 hits in a row raise the multiplier by 1

function Score.new(): State
	return { points = 0, combo = 0 }
end

function Score.multiplier(combo: number): number
	return math.min(Score.maxMultiplier, 1 + combo // Score.comboPerStep)
end

-- Returns the next state and the points this tap earned. "Almost" keeps the combo (design doc),
-- "Miss" resets it.
function Score.apply(state: State, grade: BeatClock.Grade): (State, number)
	if grade == "Miss" then
		return { points = state.points, combo = 0 }, 0
	end
	local earned = Score.points[grade] * Score.multiplier(state.combo)
	local combo = if grade == "Almost" then state.combo else state.combo + 1
	return { points = state.points + earned, combo = combo }, earned
end

return Score
