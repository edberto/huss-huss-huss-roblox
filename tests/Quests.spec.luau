local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, expect, it = JestGlobals.describe, JestGlobals.expect, JestGlobals.it

local Quests = require(ReplicatedStorage.Shared.Quests)

describe("Quests", function()
	it("rolls one quest per group, the same for the same day and player", function()
		local a, b = Quests.fresh(20000, 7089502211), Quests.fresh(20000, 7089502211)
		expect(#a.ids).toBe(3)
		for i, group in Quests.groups do
			expect((Quests.get(a.ids[i]) :: any).group).toBe(group)
			expect(a.ids[i]).toBe(b.ids[i])
		end
	end)

	it("pays each quest once and the bonus when all three are done", function()
		local state: Quests.State =
			{ day = 1, ids = { "perfects30", "dragin", "nights3" }, progress = {}, done = {}, bonus = false }
		expect((Quests.record(state, "perfects", 29))).toBe(0)
		expect((Quests.record(state, "perfects", 5))).toBe(75)
		expect((Quests.record(state, "perfects", 5))).toBe(0) -- already done
		expect((Quests.record(state, "dragIn", 1))).toBe(100)
		expect((Quests.record(state, "nights", 2))).toBe(0)
		expect((Quests.record(state, "nights", 1))).toBe(50 + Quests.bonus)
		expect(state.progress.perfects30).toBe(30)
	end)

	it("keeps the best value for the combo quest", function()
		local state: Quests.State = { day = 1, ids = { "combo4" }, progress = {}, done = {}, bonus = false }
		Quests.record(state, "multiplier", 3)
		Quests.record(state, "multiplier", 2)
		expect(state.progress.combo4).toBe(3)
	end)
end)
