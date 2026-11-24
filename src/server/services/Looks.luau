--!strict
-- Random, varied avatars for NPC trainers/partiers and the party dancers: skin tone, body shape,
-- hair, face, glasses or cap, shirt and pants colours. Catalog ids were checked with
-- MarketplaceService:GetProductInfo (hair = type 41, face = 18, face accessory = 42, hat = 8).

local Looks = {}

local SKIN = {
	"FFDBC4",
	"F2C29B",
	"E0AC80",
	"C68A5E",
	"A86F48",
	"8A5636",
	"6B3F26",
	"4A2B1B",
}
local SHIRTS = {
	"378ADD",
	"D4537E",
	"1D9E75",
	"BA7517",
	"7F77DD",
	"D85A30",
	"F2EEDC",
	"222630",
	"E8C547",
	"5CC8C8",
}
local PANTS = { "23273A", "3A4A6B", "4B3A2E", "1E1E22", "7A6A55", "5A3A6B" }
local HAIR = {
	"451220849", -- Lavender Updo
	"451221329", -- True Blue Hair
	"376548738", -- Brown Charmer Hair
	"63690008", -- Pal Hair
	"62743701", -- Stylish Brown Hair
	"5890690147", -- Popstar Hair
	"62234425", -- Brown Hair
	"80922374", -- Chestnut Spikes
}
local FACES = { 144075659, 7074764, 7076110, 7699174, 209995366, 12145366, 7317773 }
local GLASSES = "376526673" -- Stylish Aviators
local CAP = "48474313" -- Red Roblox Cap

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

local function between(low: number, high: number): number
	return low + math.random() * (high - low)
end

function Looks.random(): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	local skin = Color3.fromHex(pick(SKIN))
	local shirt = Color3.fromHex(pick(SHIRTS))
	local pants = Color3.fromHex(pick(PANTS))
	local longSleeves = math.random() < 0.5
	d.HeadColor = skin
	d.TorsoColor = shirt
	d.LeftArmColor = if longSleeves then shirt else skin
	d.RightArmColor = d.LeftArmColor
	d.LeftLegColor, d.RightLegColor = pants, pants
	d.HeightScale = between(0.9, 1.08)
	d.WidthScale = between(0.82, 1)
	d.DepthScale = d.WidthScale
	d.HeadScale = between(0.95, 1.05)
	d.BodyTypeScale = between(0, 0.3)
	d.ProportionScale = between(0, 1)
	d.HairAccessory = pick(HAIR)
	d.Face = pick(FACES)
	local extra = math.random()
	if extra < 0.2 then
		d.FaceAccessory = GLASSES
	elseif extra < 0.3 then
		d.HatAccessory = CAP
	end
	return d
end

return Looks
