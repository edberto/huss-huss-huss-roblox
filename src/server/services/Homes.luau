--!strict
-- One home per player (12 per server). The player's "Home" attribute names their model in
-- workspace.Homes; trainers are placed on its spot for their station (driveway for Basketball,
-- PracticeSpot_Gym in the garage, PracticeSpot_Burgers in the kitchen) when their character
-- spawns and when the night starts.
local Players = game:GetService("Players")

local Homes = {}

local homesFolder = workspace:WaitForChild("Homes")
local owners: { [Player]: Model } = {}
local npcHomes: { [Model]: boolean } = {}

local function isTaken(home: Model): boolean
	for _, owned in owners do
		if owned == home then
			return true
		end
	end
	return false
end

function Homes.assign(player: Player): Model?
	for i = 1, #homesFolder:GetChildren() do
		local home = homesFolder:FindFirstChild(`Home{i}`) :: Model?
		if home and not isTaken(home) and not npcHomes[home] then
			owners[player] = home
			player:SetAttribute("Home", home.Name)
			home:SetAttribute("Owner", player.DisplayName) -- the yard sign (Decor) shows it
			return home
		end
	end
	return nil -- more players than homes; MaxPlayers should prevent this
end

-- Homes for NPCs come from the far end of the street, so players (from Home1 up) keep theirs.
function Homes.claimForNpc(): Model?
	for i = #homesFolder:GetChildren(), 1, -1 do
		local home = homesFolder:FindFirstChild(`Home{i}`) :: Model?
		if home and not isTaken(home) and not npcHomes[home] then
			npcHomes[home] = true
			return home
		end
	end
	return nil
end

function Homes.releaseNpcHomes()
	for home in npcHomes do
		home:SetAttribute("Owner", nil)
	end
	table.clear(npcHomes)
end

function Homes.of(player: Player): Model?
	return owners[player]
end

function Homes.placeOnSpot(player: Player)
	local home = owners[player]
	local station = player:GetAttribute("Station")
	local spot = home
		and (
			home:FindFirstChild(`PracticeSpot_{station}`) or home:FindFirstChild("PracticeSpot")
		) :: BasePart?
	if spot and player.Character then
		player.Character:PivotTo(spot.CFrame + Vector3.new(0, 2, 0))
	end
end

Players.PlayerRemoving:Connect(function(player)
	local home = owners[player]
	if home then
		home:SetAttribute("Owner", nil)
	end
	owners[player] = nil
end)

return Homes
