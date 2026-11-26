--!strict
-- Station choice: players pick at Dusk; the choice is the player's "Station" attribute and
-- stays until they pick again. Basketball by default.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Night = require(ReplicatedStorage.Shared.Night)

local pickEvent = Instance.new("RemoteEvent")
pickEvent.Name = "PickStation" -- client -> server: station name
pickEvent.Parent = ReplicatedStorage:WaitForChild("RhythmRemotes")

-- "Skip practice, just party": the player's "PartyTonight" attribute. Allowed with the Party
-- Animal pass or at least one Party Ticket; the ticket is spent when the night starts (Round).
local skipEvent = Instance.new("RemoteEvent")
skipEvent.Name = "SkipToParty" -- client -> server: no arguments
skipEvent.Parent = ReplicatedStorage:WaitForChild("RhythmRemotes")

pickEvent.OnServerEvent:Connect(function(player: Player, station: unknown)
	if
		ReplicatedStorage:GetAttribute("Phase") == "Dusk" and table.find(Night.stations, station)
	then
		player:SetAttribute("Station", station)
		player:SetAttribute("PartyTonight", false)
	end
end)

skipEvent.OnServerEvent:Connect(function(player: Player)
	local allowed = player:GetAttribute("PartyAnimal") == true
		or (tonumber(player:GetAttribute("PartyTickets")) or 0) > 0
	if ReplicatedStorage:GetAttribute("Phase") == "Dusk" and allowed then
		player:SetAttribute("PartyTonight", true)
	end
end)

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("Station", Night.stations[1])
end)

return {}
