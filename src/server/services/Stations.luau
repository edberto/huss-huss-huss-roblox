--!strict
-- Station choice: players pick at Dusk; the choice is the player's "Station" attribute and
-- stays until they pick again. Basketball by default.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Night = require(ReplicatedStorage.Shared.Night)

local pickEvent = Instance.new("RemoteEvent")
pickEvent.Name = "PickStation" -- client -> server: station name
pickEvent.Parent = ReplicatedStorage:WaitForChild("RhythmRemotes")

pickEvent.OnServerEvent:Connect(function(player: Player, station: unknown)
	if
		ReplicatedStorage:GetAttribute("Phase") == "Dusk" and table.find(Night.stations, station)
	then
		player:SetAttribute("Station", station)
	end
end)

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("Station", Night.stations[1])
end)

return {}
