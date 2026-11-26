local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Products = require(ReplicatedStorage.Shared.Products)

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
		expect(Cosmetics.buy(wallet, "dance_groove")).toBe(nil) -- free
		expect(wallet.hp).toBe(100)
		expect(Cosmetics.buy(wallet, "perk_party_animal")).toBe("NotEnoughHP")
		expect(Cosmetics.equip(wallet, "perk", "perk_party_animal")).toBe("BadSlot") -- not equippable
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

	it("redeems a code once per account, any case, and refuses unknown or expired codes", function()
		local codes = { HUSS = { hp = 200 }, OLD = { hp = 50, expiresAt = 1000 } }
		local used = {}
		local hp, key = Rewards.redeem(codes, used, " huss-", 500)
		expect(hp).toBe(200)
		expect(key).toBe("HUSS")
		used[key] = true
		expect(select(2, Rewards.redeem(codes, used, "HUSS", 500))).toBe("AlreadyRedeemed")
		expect(select(2, Rewards.redeem(codes, used, "NOPE", 500))).toBe("Invalid")
		expect((Rewards.redeem(codes, used, "old", 999))).toBe(50)
		expect(select(2, Rewards.redeem(codes, used, "old", 1001))).toBe("Invalid")
	end)

	it("stacks group, VIP and boost multipliers and counts boost nights down", function()
		local m, left = Products.nightMultiplier(false, 0.1, false, 0)
		expect(m).toBe(1)
		expect(left).toBe(0)
		m, left = Products.nightMultiplier(true, 0.1, true, 3)
		expect(m).toBeCloseTo(1.1 * 2 * 2)
		expect(left).toBe(2)
		m, left = Products.nightMultiplier(false, 0.1, false, 1)
		expect(m).toBe(2)
		expect(left).toBe(0)
	end)

	it("repeat boost purchases add nights; the multiplier stays x2", function()
		local left = 0
		left += Products.boostNights -- bought once
		local _m1
		_m1, left = Products.nightMultiplier(false, 0, false, left) -- night 1 used
		left += Products.boostNights -- bought again with 2 nights left
		expect(left).toBe(5)
		local nights = 0
		while left > 0 do
			local m
			m, left = Products.nightMultiplier(false, 0, false, left)
			expect(m).toBe(2) -- never x4
			nights += 1
		end
		expect(nights).toBe(5)
		expect(Products.nightMultiplier(false, 0, false, left)).toBe(1) -- then back to normal
	end)
end)
