--!strict
-- Beat timing shared by client and server. Both compute beats from the same server clock
-- (workspace:GetServerTimeNow()), so a tap gets the same grade on both sides and the server
-- can re-judge every tap the client sends.
-- ponytail: one fixed BPM per segment; when the night speeds up, RoundService starts a new
-- segment (new startTime + bpm) instead of this module tracking a tempo curve.

export type Grade = "Perfect" | "Good" | "Almost" | "Miss"
-- Note positions in eighth notes within a 4-beat bar (0-7, ascending). Notes are numbered
-- 0, 1, 2... across bars; the last note of each bar is the skill move.
export type Pattern = { number }

local BeatClock = {}

BeatClock.everyBeat = table.freeze({ 0, 2, 4, 6 }) :: Pattern

-- Seconds either side of a beat. Tune from phone playtests (design doc: about 120 ms for lag).
BeatClock.windows = table.freeze({
	Perfect = 0.05,
	Good = 0.12,
	Almost = 0.2,
})

-- When note `n` is due.
function BeatClock.noteTime(startTime: number, bpm: number, n: number, pattern: Pattern?): number
	local p = pattern or BeatClock.everyBeat
	return startTime + ((n // #p) * 8 + p[n % #p + 1]) * 30 / bpm
end

-- Nearest note to time `t` and the offset from it in seconds (negative = early).
function BeatClock.nearest(
	startTime: number,
	bpm: number,
	t: number,
	pattern: Pattern?
): (number, number)
	local p = pattern or BeatClock.everyBeat
	local bar = math.floor((t - startTime) / (240 / bpm))
	local best, bestOffset = 0, math.huge
	for n = (bar - 1) * #p, (bar + 2) * #p - 1 do
		local offset = t - BeatClock.noteTime(startTime, bpm, n, p)
		if math.abs(offset) < math.abs(bestOffset) then
			best, bestOffset = n, offset
		end
	end
	return best, bestOffset
end

function BeatClock.grade(offset: number): Grade
	local distance = math.abs(offset)
	if distance <= BeatClock.windows.Perfect then
		return "Perfect"
	elseif distance <= BeatClock.windows.Good then
		return "Good"
	elseif distance <= BeatClock.windows.Almost then
		return "Almost"
	end
	return "Miss"
end

-- The tap time the server judges. The client reports when it tapped; the server only trusts that
-- within `tolerance` of when the tap actually arrived (minus the one-way network delay), so a
-- tampered client can shift a tap by at most `tolerance`. `offset` is the player's saved timing
-- calibration (positive = their audio runs late, e.g. Bluetooth earbuds).
-- ponytail: a cheater still gains up to `tolerance`; tighten it if phone playtests allow.
function BeatClock.trustedTapTime(
	claimed: number,
	received: number,
	oneWay: number,
	offset: number,
	tolerance: number
): number
	local arrived = received - oneWay
	return math.clamp(claimed, arrived - tolerance, arrived + tolerance) - offset
end

-- Timing calibration: the average lateness of taps against the beats they were aimed at,
-- ignoring taps further than `maxError` from any beat. Returns nil with fewer than `minTaps`.
function BeatClock.averageOffset(
	taps: { number },
	beats: { number },
	maxError: number,
	minTaps: number
): number?
	local sum, count = 0, 0
	for _, tap in taps do
		local best = math.huge
		for _, beat in beats do
			if math.abs(tap - beat) < math.abs(best) then
				best = tap - beat
			end
		end
		if math.abs(best) <= maxError then
			sum += best
			count += 1
		end
	end
	return if count >= minTaps then sum / count else nil
end

-- The last note of every bar is the station's skill move; the others are "huss" taps.
function BeatClock.isSkillBeat(note: number, pattern: Pattern?): boolean
	local count = #(pattern or BeatClock.everyBeat)
	return note % count == count - 1
end

return BeatClock
