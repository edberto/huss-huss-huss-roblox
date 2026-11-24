-- Server entry. Services are added here as they are built; see the design doc's technical notes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(script.services.Rhythm) -- creates the RhythmRemotes folder the other services use
require(script.services.Stations)
require(script.services.Shop)
require(script.services.RewardService)
require(script.services.Store)
local Round = require(script.services.Round)

local isPlaytest = ReplicatedStorage:GetAttribute("DevelopmentPlaytest") == true
print(`[Huss] server started{if isPlaytest then " (PLAYTEST)" else ""}`)

Round.run()
