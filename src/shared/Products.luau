--!strict
-- Robux products (design doc: monetization). IDs belong to the Production experience
-- (universe 10778958069), so purchases only work there; an id of 0 shows "Coming soon".
local Products = {}

-- game pass: Party Animal (149 Robux): skip practice and party any night.
Products.partyAnimalPassId = 2100270141
Products.vipPassId = 2100887538 -- game pass: VIP (199 Robux): x2 Huss Points, VIP tag
Products.vipMultiplier = 2

export type Product = { id: number, name: string, robux: number, hp: number? }
Products.items = table.freeze({
	hp_small = { id = 3736028510, name = "500 Huss", robux = 25, hp = 500 },
	hp_medium = { id = 3736028729, name = "1,750 Huss", robux = 75, hp = 1750 },
	hp_large = { id = 3736028812, name = "5,000 Huss", robux = 199, hp = 5000 },
	second_wind = { id = 3736028871, name = "Second Wind", robux = 15 },
	throw_party = { id = 3736028927, name = "Throw a Party", robux = 99 },
	huss_boost = { id = 3736030396, name = "x2 Boost: 3 nights", robux = 29 },
} :: { [string]: Product })

Products.boostNights = 3 -- nights of x2 Huss per Huss Boost purchase (they stack)
Products.boostMultiplier = 2

-- The night's Huss multiplier and the boost nights left after this night. Group members get a
-- small bonus, VIP doubles, and a Huss Boost doubles again while it lasts.
Products.friendBonus = 0.1 -- per friend in the same server
Products.friendBonusMax = 5 -- so +50% at most

-- friends: how many of the player's Roblox friends are in the server (adds to the group bonus).
function Products.nightMultiplier(
	inGroup: boolean,
	groupBonus: number,
	vip: boolean,
	boostNightsLeft: number,
	friends: number?
): (number, number)
	local multiplier = (if inGroup then 1 + groupBonus else 1)
		+ math.min(friends or 0, Products.friendBonusMax) * Products.friendBonus
	if vip then
		multiplier *= Products.vipMultiplier
	end
	if boostNightsLeft > 0 then
		return multiplier * Products.boostMultiplier, boostNightsLeft - 1
	end
	return multiplier, 0
end

Products.secondWindFocus = 50 -- focus restored, once per night
Products.secondWindShowBelow = 30 -- the button appears when focus drops below this
Products.partyHpForEveryone = 100 -- everyone in the server gets this when someone throws a party

function Products.byId(id: number): (string?, Product?)
	if id == 0 then
		return nil, nil
	end
	for key, product in Products.items do
		if product.id == id then
			return key, product
		end
	end
	return nil, nil
end

return Products
