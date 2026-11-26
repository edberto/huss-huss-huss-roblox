--!strict
-- Cosmetics catalog and the pure buy/equip rules (design doc: what HP buys, cosmetic only).
-- Trails and titles show to everyone; ball skins show on your own ball. The equipped dance is
-- what the DANCE button plays (everyone sees it). Perks unlock a feature for good.
export type Slot = "trail" | "title" | "ball" | "dance" | "perk"
export type Item = {
	slot: Slot,
	name: string,
	price: number?,
	colors: { string }?,
	anim: string?, -- dance animation (Roblox-owned)
}
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
	dance_groove = {
		slot = "dance",
		name = "Groove",
		price = 0,
		colors = { "8A3CFF" },
		anim = "507771019",
	},
	dance_shuffle = {
		slot = "dance",
		name = "Shuffle",
		price = 500,
		colors = { "50C3FF" },
		anim = "507776043",
	},
	dance_bounce = {
		slot = "dance",
		name = "Bounce",
		price = 750,
		colors = { "5AD278" },
		anim = "507777268",
	},
	dance_cheer = {
		slot = "dance",
		name = "Cheer",
		price = 1000,
		colors = { "FFD246" },
		anim = "507770677",
	},
	dance_hype = {
		slot = "dance",
		name = "Hype",
		price = 1500,
		colors = { "FF6B1A" },
		anim = "3695333486",
	},
	dance_floss = {
		slot = "dance",
		name = "Floss",
		price = 2500,
		colors = { "FF2E93" },
		anim = "5917459365",
	},
	dance_robot = {
		slot = "dance",
		name = "Robot",
		price = 3500,
		colors = { "85B7EB" },
		anim = "10714392953",
	},
	dance_celebrate = {
		slot = "dance",
		name = "Celebrate",
		price = 5000,
		colors = { "FAC775" },
		anim = "3338097973",
	},
	-- Same as the Party Animal game pass: skip practice and party any night, for good.
	perk_party_animal = {
		slot = "perk",
		name = "Party Animal",
		price = 50000,
		colors = { "FF2E93" },
	},
} :: { [string]: Item })

Cosmetics.slots = table.freeze({ "trail", "title", "ball", "dance" } :: { Slot }) -- equippable

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
