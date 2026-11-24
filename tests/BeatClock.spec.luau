local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local BeatClock = require(ReplicatedStorage.Shared.BeatClock)

local describe, expect, it = JestGlobals.describe, JestGlobals.expect, JestGlobals.it

describe("BeatClock", function()
	-- 120 BPM = one beat every 0.5 s, starting at t = 10.
	it("finds the nearest beat and the signed offset", function()
		local beat, offset = BeatClock.nearest(10, 120, 11.04)
		expect(beat).toBe(2)
		expect(offset).toBeCloseTo(0.04)

		beat, offset = BeatClock.nearest(10, 120, 11.46)
		expect(beat).toBe(3)
		expect(offset).toBeCloseTo(-0.04)
	end)

	it("grades by distance from the beat, early or late", function()
		expect(BeatClock.grade(0.05)).toBe("Perfect")
		expect(BeatClock.grade(-0.1)).toBe("Good")
		expect(BeatClock.grade(0.15)).toBe("Almost")
		expect(BeatClock.grade(-0.25)).toBe("Miss")
	end)

	it("makes every fourth beat the skill move", function()
		expect(BeatClock.isSkillBeat(2)).toBe(false)
		expect(BeatClock.isSkillBeat(3)).toBe(true)
		expect(BeatClock.isSkillBeat(7)).toBe(true)
	end)

	it("trusts reported tap times only near arrival, then calibrates", function()
		-- Honest: reported 50 ms before it arrived with 50 ms one-way delay -> unchanged.
		expect(BeatClock.trustedTapTime(10.0, 10.05, 0.05, 0, 0.1)).toBeCloseTo(10.0)
		-- Tampered: claims a time 0.4 s earlier than possible -> clamped to 0.1 s early.
		expect(BeatClock.trustedTapTime(9.6, 10.05, 0.05, 0, 0.1)).toBeCloseTo(9.9)
		-- Calibration of 0.2 s (late audio) moves the judged tap 0.2 s earlier.
		expect(BeatClock.trustedTapTime(10.0, 10.05, 0.05, 0.2, 0.1)).toBeCloseTo(9.8)
	end)

	it("calibrates from the average lateness, ignoring stray taps", function()
		local beats = { 1, 1.6, 2.2, 2.8 }
		local taps = { 1.14, 1.74, 2.34, 2.94, 2.5 } -- 2.5 is 0.3 off any beat: ignored
		expect(BeatClock.averageOffset(taps, beats, 0.25, 4)).toBeCloseTo(0.14)
		expect(BeatClock.averageOffset({ 1.1, 1.7 }, beats, 0.25, 4)).toBe(nil)
	end)
end)
