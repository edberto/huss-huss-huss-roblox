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
end)
