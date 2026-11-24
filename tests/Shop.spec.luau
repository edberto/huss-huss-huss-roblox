local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Rewards = require(ReplicatedStorage.Shared.Rewards)

local describe, expect, it = JestGlobals.describe, JestGlobals.expect, JestGlobals.it

describe("Cosmetics", function()
	it("buys once, spends HP, refuses when short or not for sale", function()
		local wallet = { hp = 600, owned = {}, equipped = {} }
		expect(Cosmetics.buy(wallet, "trail_fire")).toBe(nil)
		expect(wallet.hp).toBe(100)
		expect(Cosmetics.buy(wallet, "trail_fire")).toBe("AlreadyOwned")
		expect(Cosmetics.buy(wallet, "trail_gold")).toBe("NotEnoughHP")
		expect(Cosmetics.buy(wallet, "trail_streak")).toBe("NotForSale")
		expect(wallet.hp).toBe(100)
	end)

	it("equips only owned items in their own slot", function()
		local wallet = { hp = 0, owned = { trail_fire = true }, equipped = {} }
		expect(Cosmetics.equip(wallet, "trail", "trail_ice")).toBe("NotOwned")
		expect(Cosmetics.equip(wallet, "title", "trail_fire")).toBe("NotOwned")
		expect(Cosmetics.equip(wallet, "trail", "trail_fire")).toBe(nil)
		expect(wallet.equipped.trail).toBe("trail_fire")
		expect(Cosmetics.equip(wallet, "trail", nil)).toBe(nil)
		expect(wallet.equipped.trail).toBe(nil)
	end)
end)

describe("Rewards", function()
	it("counts a daily streak and restarts after a missed day or day 7", function()
		local state = { lastDay = 0, streak = 0 }
		local day
		state, day = Rewards.claimDaily(state, 100)
		expect(day).toBe(1)
		local _, again = Rewards.claimDaily(state, 100)
		expect(again).toBe(nil)
		state, day = Rewards.claimDaily(state, 101)
		expect(day).toBe(2)
		_, day = Rewards.claimDaily(state, 103)
		expect(day).toBe(1)
		_, day = Rewards.claimDaily({ lastDay = 200, streak = 7 }, 201)
		expect(day).toBe(1)
	end)
end)
