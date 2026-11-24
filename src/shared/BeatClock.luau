--!strict
-- Beat timing shared by client and server. Both compute beats from the same server clock
-- (workspace:GetServerTimeNow()), so a tap gets the same grade on both sides and the server
-- can re-judge every tap the client sends.
-- ponytail: one fixed BPM per segment; when the night speeds up, RoundService starts a new
-- segment (new startTime + bpm) instead of this module tracking a tempo curve.

export type Grade = "Perfect" | "Good" | "Almost" | "Miss"

local BeatClock = {}

-- Seconds either side of a beat. Tune from phone playtests (design doc: about 120 ms for lag).
BeatClock.windows = table.freeze({
	Perfect = 0.05,
	Good = 0.12,
	Almost = 0.2,
})

-- Nearest beat index to time `t` and the offset from it in seconds (negative = early).
function BeatClock.nearest(startTime: number, bpm: number, t: number): (number, number)
	local interval = 60 / bpm
	local beat = math.floor((t - startTime) / interval + 0.5)
	return beat, t - (startTime + beat * interval)
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

-- Beats 0, 1, 2 of every bar are "huss" taps; beat 3 is the station's skill move.
function BeatClock.isSkillBeat(beat: number): boolean
	return beat % 4 == 3
end

return BeatClock
