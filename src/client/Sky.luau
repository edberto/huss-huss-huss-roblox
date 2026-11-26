--!strict
-- The sky tells the time: a sunset at Dusk, then the sky follows the night clock (9 PM to 6 AM,
-- so the moon crosses and the horizon starts to glow near the end), the sun up at Dawn, and a
-- quick sweep through the day back to the next sunset. The sky only ever moves forward.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Night = require(ReplicatedStorage.Shared.Night)

local DUSK, DAWN = 18.6, 6.5

local function target(): number
	local phase = ReplicatedStorage:GetAttribute("Phase")
	if phase == "Night" then
		local ends = ReplicatedStorage:GetAttribute("PhaseEnds") :: number?
		local left = if ends then ends - workspace:GetServerTimeNow() else 0
		local progress = math.clamp(1 - left / Night.nightTime, 0, 1)
		local minutes = Night.clockStartMinutes
			+ (Night.clockEndMinutes - Night.clockStartMinutes) * progress
		return (minutes / 60) % 24
	end
	return if phase == "Dawn" then DAWN else DUSK
end

local Sky = {}

function Sky.start()
	Lighting.ClockTime = target()
	RunService.RenderStepped:Connect(function(dt)
		-- Hours still to go, counting forward only (Dawn -> Dusk is half a day ahead).
		local ahead = (target() - Lighting.ClockTime) % 24
		if ahead > 20 then
			return -- target is just behind us (clock jitter): wait rather than spin a whole day
		end
		-- Catch up quickly (a phase change sweeps in about 3 s) and track the night clock smoothly.
		Lighting.ClockTime = (Lighting.ClockTime + ahead * math.min(1, dt * 1.5)) % 24
	end)
end

return Sky
