--!strict
-- Night cycle tuning (design doc: core loop, party pressure). Shared so the client can show
-- the same timings it is judged by.
local Night = {}

Night.duskTime = 30
Night.nightTime = 150 -- 2.5 min; a full Dusk-Night-Dawn cycle is 3.5 min
Night.dawnTime = 30

-- The night clock runs from 9:00 PM to 6:00 AM over the Party Night phase.
Night.clockStartMinutes = 21 * 60
Night.clockEndMinutes = 30 * 60

-- One BPM per quarter of the night: the beat gets faster towards dawn.
Night.bpmSteps = table.freeze({ 100, 108, 116, 124 })

-- Practice stations, in picker order. Every home has all of them.
Night.stations = table.freeze({ "Basketball", "Gym", "Burgers" })
-- Each station's rhythm (BeatClock.Pattern) and difficulty; harder stations pay more Huss.
Night.stationInfo = table.freeze({
	Basketball = table.freeze({ difficulty = "Easy", bonus = 0, pattern = { 0, 2, 4, 6 } }),
	Gym = table.freeze({ difficulty = "Medium", bonus = 0.1, pattern = { 0, 4, 6, 7 } }),
	Burgers = table.freeze({ difficulty = "Hard", bonus = 0.25, pattern = { 1, 3, 5, 7 } }),
})

function Night.pattern(station: unknown): { number }
	local info = Night.stationInfo[station :: any]
	return if info then info.pattern else Night.stationInfo.Basketball.pattern
end

Night.focusStart = 100
Night.missDrain = 1 -- focus lost per missed tap (doubled during a bass drop)
Night.skipDrain = 1 -- focus lost per beat not tapped at all (idle all night = gives in)
-- Focus never comes back during a night (only a Second Wind refills it): it's a stamina bar to
-- protect, so misses stay cheap and the pressure builds.

export type TemptationKind = "Doorbell" | "Phone" | "Friend" | "BassDrop"
-- window: seconds to answer; taps: answers needed (0 = nothing to answer); drain: focus lost if
-- not answered in time.
Night.temptations = table.freeze({
	Doorbell = { window = 2, taps = 1, drain = 10 },
	Phone = { window = 2.5, taps = 1, drain = 8 },
	Friend = { window = 3, taps = 3, drain = 15 },
	BassDrop = { window = 8, taps = 0, drain = 0 },
})
Night.temptationOrder =
	table.freeze({ "Doorbell", "Phone", "Friend", "BassDrop" } :: { TemptationKind })

-- Partier abilities (design doc: partiers). range in studs, cooldown and duration in seconds.
export type Ability = "Invite" | "Speaker" | "Dance"
Night.abilities = table.freeze({
	Invite = { cooldown = 15, duration = 4, points = 5 },
	Speaker = { cooldown = 15, duration = 5, points = 5 },
	Dance = { cooldown = 15, duration = 5, points = 0, drainPerSecond = 3 },
})
Night.abilityRange = 14
Night.shieldTime = 3 -- a trainer can't be hit by another ability this soon after one
Night.partierSpeed = 24
Night.giveInBonus = 50 -- party points for the partier who last tempted a trainer who gives in
Night.lockedInCount = 3 -- the last trainers standing glow for everyone

-- Seconds between temptations for one player: 14 at the start of the night, 6 at the end.
function Night.temptationGap(progress: number): number
	return 14 - 8 * math.clamp(progress, 0, 1)
end

function Night.bpm(progress: number): number
	local step = math.clamp(math.floor(progress * #Night.bpmSteps) + 1, 1, #Night.bpmSteps)
	return Night.bpmSteps[step]
end

-- progress 0..1 through the night -> "11:40 PM"
function Night.clockText(progress: number): string
	local span = Night.clockEndMinutes - Night.clockStartMinutes
	local minutes = Night.clockStartMinutes
		+ math.floor(span * math.clamp(progress, 0, 1) / 10) * 10
	local hour24 = (minutes // 60) % 24
	local hour12 = if hour24 % 12 == 0 then 12 else hour24 % 12
	return string.format("%d:%02d %s", hour12, minutes % 60, if hour24 < 12 then "AM" else "PM")
end

return Night
