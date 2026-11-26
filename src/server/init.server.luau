-- Server entry. Services are added here as they are built; see the design doc's technical notes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(script.services.Rhythm) -- creates the RhythmRemotes folder the other services use
require(script.services.Stations)
require(script.services.Shop)
require(script.services.RewardService)
require(script.services.Store)
local Round = require(script.services.Round)
require(script.services.Leaderboards).start()
task.spawn(require(script.services.Boards).build)
task.spawn(require(script.services.Decor).build)

-- The town is small: a zoom cap keeps the camera close enough to stay inside the hills.
game:GetService("StarterPlayer").CameraMaxZoomDistance = 50

local isPlaytest = ReplicatedStorage:GetAttribute("DevelopmentPlaytest") == true
print(`[Huss] server started{if isPlaytest then " (PLAYTEST)" else ""}`)

Round.run()
