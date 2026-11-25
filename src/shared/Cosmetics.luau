--!strict
-- Cosmetics catalog and the pure buy/equip rules (design doc: what HP buys, cosmetic only).
-- Trails and titles show to everyone; ball skins show on your own ball.
export type Slot = "trail" | "title" | "ball"
export type Item = { slot: Slot, name: string, price: number?, colors: { string }? }
export type Wallet = { hp: number, owned: { [string]: boolean }, equipped: { [string]: string } }

local Cosmetics = {}

-- price nil = not sold (earned from rewards).
Cosmetics.items = table.freeze({
	trail_mint = { slot = "trail", name = "Mint", price = 250, colors = { "3DFFB0", "3DFFB0" } },
	trail_fire = { slot = "trail", name = "Fire", price = 500, colors = { "FF6B1A", "FFB547" } },
	trail_ice = { slot = "trail", name = "Ice", price = 750, colors = { "85B7EB", "F2EEDC" } },
	trail_party = { slot = "trail", name = "Party", price = 2500, colors = { "FF2E93", "8A3CFF" } },
	trail_gold = { slot = "trail", name = "Gold", price = 6000, colors = { "FAC775", "FFB547" } },
	trail_streak = { slot = "trail", name = "7-Day Streak", colors = { "3DFFB0", "FF2E93" } },
	title_hooper = { slot = "title", name = "Hooper", price = 300 },
	title_gymrat = { slot = "title", name = "Gym Rat", price = 300 },
	title_burgerboss = { slot = "title", name = "Burger Boss", price = 300 },
	title_neverpartied = { slot = "title", name = "Never Partied", price = 5000 },
	title_legend = { slot = "title", name = "Huss Legend", price = 15000 },
	ball_glow = { slot = "ball", name = "Glow", price = 500, colors = { "FF6B1A" } },
	ball_party = { slot = "ball", name = "Party", price = 2500, colors = { "FF2E93" } },
	ball_gold = { slot = "ball", name = "Gold", price = 5000, colors = { "FAC775" } },
} :: { [string]: Item })

Cosmetics.slots = table.freeze({ "trail", "title", "ball" } :: { Slot })

-- Buys `id` into the wallet (mutates it). Returns nil on success or the reason it failed.
function Cosmetics.buy(wallet: Wallet, id: string): string?
	local item = Cosmetics.items[id]
	if not item or not item.price then
		return "NotForSale"
	elseif wallet.owned[id] then
		return "AlreadyOwned"
	elseif wallet.hp < item.price then
		return "NotEnoughHP"
	end
	wallet.hp -= item.price
	wallet.owned[id] = true
	return nil
end

-- Equips an owned item, or unequips `slot` when id is nil. Returns nil or the reason it failed.
function Cosmetics.equip(wallet: Wallet, slot: string, id: string?): string?
	if not table.find(Cosmetics.slots, slot :: Slot) then
		return "BadSlot"
	end
	if id == nil then
		wallet.equipped[slot] = nil
		return nil
	end
	local item = Cosmetics.items[id]
	if not item or item.slot ~= slot or not wallet.owned[id] then
		return "NotOwned"
	end
	wallet.equipped[slot] = id
	return nil
end

return Cosmetics
