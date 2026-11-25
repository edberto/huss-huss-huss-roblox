--!strict
-- Gym station: every hit pulls the barbell up to the chest (and curls the dumbbell); the skill
-- beat presses it overhead. A skill-beat
-- "Almost" gets the bar halfway up, then it drops with a clank: "ahh almost almost".
-- Props are local to the player's own screen, like the basketball's dribble.
local RunService = game:GetService("RunService")

local StationFx = require(script.Parent.StationFx)
local Ui = require(script.Parent.Ui)

local CURL_TIME = 0.28
local PRESS_TIME = 0.55

type Motion = { kind: "curl" | "press" | "fail", start: number }

local Gym = {}

local function part(parent: Instance, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Parent = parent
	return p
end

-- A bar with a weight on each end; returns the model and a function that places it.
local function weight(parent: Instance, barLength: number, plate: number): (Model, (CFrame) -> ())
	local model = Instance.new("Model")
	local bar = part(
		model,
		Vector3.new(barLength, 0.25, 0.25),
		Color3.fromHex("B4B2A9"),
		Enum.PartType.Cylinder
	)
	local left = part(model, Vector3.new(0.4, plate, plate), Ui.colors.navy, Enum.PartType.Cylinder)
	local right =
		part(model, Vector3.new(0.4, plate, plate), Ui.colors.navy, Enum.PartType.Cylinder)
	model.Parent = parent
	return model,
		function(cf: CFrame)
			bar.CFrame = cf
			left.CFrame = cf * CFrame.new(-barLength / 2 + 0.3, 0, 0)
			right.CFrame = cf * CFrame.new(barLength / 2 - 0.3, 0, 0)
		end
end

function Gym.start(): StationFx.Station
	local folder = Instance.new("Folder")
	folder.Name = "GymProps"
	local _, placeDumbbell = weight(folder, 1.4, 0.9)
	local _, placeBarbell = weight(folder, 6, 2.2)
	local active = false
	local motion: Motion? = nil

	RunService.RenderStepped:Connect(function()
		local root = StationFx.rootCFrame()
		local hand = StationFx.handPosition()
		if not active or not root or not hand then
			return
		end
		-- Plates resting on the driveway in front of the player.
		local barRest = CFrame.lookAlong(root * Vector3.new(0, -2, -2.6), root.RightVector)
		local barTop = CFrame.lookAlong(root * Vector3.new(0, 3.6, -0.8), root.RightVector)
		local barChest = CFrame.lookAlong(root * Vector3.new(0, 0.8, -1.2), root.RightVector)
		local dumbbellRest = CFrame.lookAlong(hand, root.LookVector)

		local current = motion
		local elapsed = if current then os.clock() - current.start else 0
		if current and current.kind == "curl" then
			local p = math.clamp(elapsed / CURL_TIME, 0, 1)
			local lift = math.sin(p * math.pi) * 1.6
			placeDumbbell(dumbbellRest + Vector3.new(0, lift, 0))
			if p >= 1 then
				motion = nil
			end
		else
			placeDumbbell(dumbbellRest)
		end

		if current and current.kind == "press" then
			local p = math.clamp(elapsed / PRESS_TIME, 0, 1)
			-- Up from the floor to overhead and back down.
			local up = math.sin(p * math.pi)
			placeBarbell(barRest:Lerp(barTop, up))
			if p >= 1 then
				motion = nil
			end
		elseif current and current.kind == "fail" then
			local p = math.clamp(elapsed / PRESS_TIME, 0, 1)
			-- Halfway to the chest, wobble, then drop.
			if p < 0.45 then
				placeBarbell(
					barRest:Lerp(barChest, p / 0.45) * CFrame.Angles(math.sin(p * 40) * 0.15, 0, 0)
				)
			else
				placeBarbell(barChest:Lerp(barRest, math.clamp((p - 0.45) / 0.15, 0, 1)))
			end
			if p >= 1 then
				motion = nil
			end
		elseif current and current.kind == "curl" then
			-- A quick pull to the chest, so every hit shows on the big bar.
			local p = math.clamp(elapsed / CURL_TIME, 0, 1)
			placeBarbell(barRest:Lerp(barChest, math.sin(p * math.pi)))
		else
			placeBarbell(barRest)
		end
	end)

	local function onResult(grade: string, skill: boolean)
		if grade == "Miss" then
			return
		end
		StationFx.huss()
		if motion and motion.kind ~= "curl" and os.clock() - motion.start < PRESS_TIME then
			return
		end
		if not skill then
			motion = { kind = "curl", start = os.clock() }
		elseif grade == "Almost" then
			motion = { kind = "fail", start = os.clock() }
			task.delay(PRESS_TIME * 0.6, StationFx.play, "clank", 0.8)
			task.delay(PRESS_TIME * 0.6, StationFx.almost)
		else
			motion = { kind = "press", start = os.clock() }
			task.delay(PRESS_TIME, StationFx.play, "clank")
		end
	end

	return {
		onResult = onResult,
		setActive = function(on: boolean)
			active = on
			motion = nil
			folder.Parent = if on then workspace else nil
		end,
	}
end

return Gym
