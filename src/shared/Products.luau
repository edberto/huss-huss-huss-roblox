--!strict
-- Robux products (design doc: monetization). IDs belong to the Production experience
-- (universe 10778958069), so purchases only work there; an id of 0 shows "Coming soon".
local Products = {}

Products.vipPassId = 2100887538 -- game pass: VIP (199 Robux): x2 Huss Points, VIP tag
Products.vipMultiplier = 2

export type Product = { id: number, name: string, robux: number, hp: number? }
Products.items = table.freeze({
	hp_small = { id = 3736028510, name = "500 Huss", robux = 25, hp = 500 },
	hp_medium = { id = 3736028729, name = "1,750 Huss", robux = 75, hp = 1750 },
	hp_large = { id = 3736028812, name = "5,000 Huss", robux = 199, hp = 5000 },
	second_wind = { id = 3736028871, name = "Second Wind", robux = 15 },
	throw_party = { id = 3736028927, name = "Throw a Party", robux = 99 },
} :: { [string]: Product })

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
