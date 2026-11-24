--!strict
-- Basketball station: the ball follows the player, dribbles on every hit and is shot on the skill
-- beat. A skill-beat "Almost" rims out with the "ahh almost almost" moment.
-- Everything here is local to the player's own screen; scoring stays on the server.
local RunService = game:GetService("RunService")

local StationFx = require(script.Parent.StationFx)

local DRIBBLE_TIME = 0.28
local FLIGHT_TIME = 0.45
local GROUND_Y = 1.05 -- driveway top + ball radius

type Motion = { kind: "dribble" | "make" | "rimout", start: number, from: Vector3? }

local Basketball = {}

function Basketball.start(home: Model): StationFx.Station
	local ball = home:WaitForChild("Ball") :: BasePart
	local active = true
	-- The rim pieces ring the hoop, so their average position is its centre.
	local rimSum, rimCount = Vector3.zero, 0
	for _, child in home:GetChildren() do
		if child.Name == "Rim" and child:IsA("BasePart") then
			rimSum += child.Position
			rimCount += 1
		end
	end
	local rimCenter = rimSum / math.max(rimCount, 1)

	local motion: Motion? = nil

	RunService.RenderStepped:Connect(function()
		local hand = StationFx.handPosition()
		if not hand or not active then
			return
		end
		local current = motion
		if not current then
			ball.Position = hand
			return
		end
		local elapsed = os.clock() - current.start
		if current.kind == "dribble" then
			local p = math.clamp(elapsed / DRIBBLE_TIME, 0, 1)
			-- Parabola: hand at p = 0 and 1, ground at p = 0.5.
			local y = GROUND_Y + (hand.Y - GROUND_Y) * (2 * p - 1) ^ 2
			ball.Position = Vector3.new(hand.X, y, hand.Z)
			if p >= 1 then
				motion = nil
			end
			return
		end
		local from = current.from or hand
		local target = if current.kind == "make"
			then rimCenter
			else rimCenter + Vector3.new(1.4, 0.2, -0.6)
		if elapsed < FLIGHT_TIME then
			local p = elapsed / FLIGHT_TIME
			ball.Position = from:Lerp(target, p) + Vector3.new(0, math.sin(p * math.pi) * 5, 0)
		elseif current.kind == "make" then
			-- Drop through the net.
			local p = math.clamp((elapsed - FLIGHT_TIME) / 0.25, 0, 1)
			ball.Position = rimCenter - Vector3.new(0, 3.5 * p, 0)
			if p >= 1 then
				motion = nil
			end
		else
			-- Rim out: bounce off towards the street.
			local p = math.clamp((elapsed - FLIGHT_TIME) / 0.4, 0, 1)
			local away = target:Lerp(target + Vector3.new(3, -8, -5), p)
			ball.Position = away + Vector3.new(0, math.sin(p * math.pi) * 1.5, 0)
			if p >= 1 then
				motion = nil
			end
		end
	end)

	local function onResult(grade: string, skill: boolean)
		if grade == "Miss" then
			return
		end
		StationFx.huss()
		local inFlight = motion
			and motion.kind ~= "dribble"
			and os.clock() - motion.start < FLIGHT_TIME
		if inFlight then
			return
		end
		if not skill then
			motion = { kind = "dribble", start = os.clock() }
			task.delay(DRIBBLE_TIME / 2, StationFx.play, "bounce")
		elseif grade == "Almost" then
			motion = { kind = "rimout", start = os.clock(), from = ball.Position }
			task.delay(FLIGHT_TIME, StationFx.play, "rim")
			task.delay(FLIGHT_TIME, StationFx.almost)
		else
			motion = { kind = "make", start = os.clock(), from = ball.Position }
		end
	end

	return {
		onResult = onResult,
		setActive = function(on: boolean)
			active = on
			motion = nil
			ball.LocalTransparencyModifier = if on then 0 else 1
		end,
	}
end

return Basketball
