local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local Progress = require(ReplicatedStorage.Shared.Progress)

local describe, expect, it = JestGlobals.describe, JestGlobals.expect, JestGlobals.it

describe("Progress", function()
	it("levels up as XP passes each step", function()
		expect(Progress.level(0)).toBe(1)
		expect(Progress.level(49)).toBe(1)
		expect(Progress.level(50)).toBe(2)
		expect(Progress.level(150)).toBe(3)
		expect(Progress.level(10 ^ 9)).toBe(100)
	end)

	it("ranks by total levels", function()
		expect(Progress.rank(3)).toBe("Rookie")
		expect(Progress.rank(25)).toBe("Locked In")
		expect(Progress.rank(300)).toBe("GOAT")
	end)

	it("pays placement bonuses only with enough players", function()
		expect(Progress.nightReward(100, 20, 1, 5, true)).toBe(100 + 20 + 500 + 50)
		expect(Progress.nightReward(100, 0, 3, 5, false)).toBe(100 + 250)
		expect(Progress.nightReward(100, 0, 1, 1, true)).toBe(100 + 50)
	end)

	it("pays harder stations more", function()
		expect(Progress.stationPoints(200, 0)).toBe(200)
		expect(Progress.stationPoints(200, 0.1)).toBe(220)
		expect(Progress.stationPoints(201, 0.25)).toBe(251)
	end)
end)
