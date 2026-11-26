--!strict
-- The sky tells the time: a sunset at Dusk, then the sky follows the night clock (9 PM to 6 AM,
-- so the moon crosses and the horizon starts to glow near the end), the sun up at Dawn, and a
-- quick sweep through the day back to the next sunset. The sky only ever moves forward.
-- A high latitude keeps the moon low (about 20-35 degrees up) so it crosses where people look
-- instead of straight overhead.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Night = require(ReplicatedStorage.Shared.Night)

-- Dusk and Dawn drift across their phase: the sun sinks onto the horizon, then rises off it.
local DUSK_FROM, DUSK_TO = 17.6, 18.5
local DAWN_FROM, DAWN_TO = 6.0, 7.0
local LATITUDE, MOON_SIZE = 78, 18 -- Roblox defaults are about 42 and 11

-- The haze, not the sun, sets the mood here (the Atmosphere's Haze is high), so it gets its
-- own colours through the day. Night is whatever the place has (cold full moon).
type Palette = { haze: Color3, decay: Color3, outdoor: Color3 }
local GLOW: Palette = { -- sunset / first light
	haze = Color3.fromRGB(255, 130, 120),
	decay = Color3.fromRGB(110, 50, 110),
	outdoor = Color3.fromRGB(150, 110, 150),
}
local MORNING: Palette = {
	haze = Color3.fromRGB(255, 205, 170),
	decay = Color3.fromRGB(170, 130, 170),
	outdoor = Color3.fromRGB(150, 145, 170),
}
local DAY: Palette = {
	haze = Color3.fromRGB(190, 215, 255),
	decay = Color3.fromRGB(120, 150, 210),
	outdoor = Color3.fromRGB(150, 150, 165),
}

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
	local dawn = phase == "Dawn"
	local ends = ReplicatedStorage:GetAttribute("PhaseEnds") :: number?
	local length = if dawn then Night.dawnTime else Night.duskTime
	local left = if ends then ends - workspace:GetServerTimeNow() else length
	local t = math.clamp(1 - left / length, 0, 1)
	return if dawn
		then DAWN_FROM + (DAWN_TO - DAWN_FROM) * t
		else DUSK_FROM + (DUSK_TO - DUSK_FROM) * t
end

local function mix(a: Palette, b: Palette, t: number): Palette
	return {
		haze = a.haze:Lerp(b.haze, t),
		decay = a.decay:Lerp(b.decay, t),
		outdoor = a.outdoor:Lerp(b.outdoor, t),
	}
end

local Sky = {}

function Sky.start()
	Lighting.GeographicLatitude = LATITUDE
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		sky.MoonAngularSize = MOON_SIZE
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local night: Palette = {
		haze = if atmosphere then atmosphere.Color else Color3.new(),
		decay = if atmosphere then atmosphere.Decay else Color3.new(),
		outdoor = Lighting.OutdoorAmbient,
	}
	-- Hour -> palette, looping round the clock; night holds from 20:00 to 4:30.
	local keys: { { number | Palette } } = {
		{ 4.5, night },
		{ 5.6, GLOW },
		{ 6.5, MORNING },
		{ 11, DAY },
		{ 16.5, MORNING },
		{ 18.4, GLOW },
		{ 20, night },
		{ 28.5, night },
	}
	local function paint(hour: number)
		local h = if hour < 4.5 then hour + 24 else hour
		for i = 1, #keys - 1 do
			local h0, h1 = keys[i][1] :: number, keys[i + 1][1] :: number
			if h >= h0 and h <= h1 then
				local p =
					mix(keys[i][2] :: Palette, keys[i + 1][2] :: Palette, (h - h0) / (h1 - h0))
				if atmosphere then
					atmosphere.Color = p.haze
					atmosphere.Decay = p.decay
				end
				Lighting.OutdoorAmbient = p.outdoor
				return
			end
		end
	end

	Lighting.ClockTime = target()
	RunService.RenderStepped:Connect(function(dt)
		-- Hours still to go, counting forward only (Dawn -> Dusk is half a day ahead).
		local ahead = (target() - Lighting.ClockTime) % 24
		if ahead > 20 then
			ahead = 0 -- target is just behind us (rounding, clock jitter): hold, don't spin a whole day
		end
		-- Catch up quickly (a phase change sweeps in about 3 s) and track the night clock smoothly.
		Lighting.ClockTime = (Lighting.ClockTime + ahead * math.min(1, dt * 1.5)) % 24
		paint(Lighting.ClockTime)
	end)
end

return Sky
