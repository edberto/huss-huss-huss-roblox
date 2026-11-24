-- Server entry. Services are added here as they are built; see the design doc's technical notes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rhythm = require(script.services.Rhythm)

local isPlaytest = ReplicatedStorage:GetAttribute("DevelopmentPlaytest") == true
print(`[Huss] server started{if isPlaytest then " (PLAYTEST)" else ""}`)

-- ponytail: every player practices at 100 BPM from joining until RoundService exists.
Players.PlayerAdded:Connect(function(player)
	Rhythm.start(player, 100)
end)
