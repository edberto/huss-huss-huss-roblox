--!strict
-- One home per player (12 per server). The player's "Home" attribute names their model in
-- workspace.Homes; trainers are placed on its PracticeSpot whenever their character spawns.
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
	table.clear(npcHomes)
end

function Homes.of(player: Player): Model?
	return owners[player]
end

function Homes.placeOnSpot(player: Player)
	local home = owners[player]
	local spot = home and home:FindFirstChild("PracticeSpot") :: BasePart?
	if spot and player.Character then
		player.Character:PivotTo(spot.CFrame + Vector3.new(0, 2, 0))
	end
end

Players.PlayerRemoving:Connect(function(player)
	owners[player] = nil
end)

return Homes
