-- Server entry. Services (RoundService, StationService, FocusService, PartyService,
-- DataService) are added here as they are built; see the design doc's technical notes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local isPlaytest = ReplicatedStorage:GetAttribute("DevelopmentPlaytest") == true
print(`[Huss] server started{if isPlaytest then " (PLAYTEST)" else ""}`)
