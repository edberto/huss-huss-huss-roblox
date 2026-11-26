--!strict
-- Station arm motions for your own avatar while practising. The default animations (the
-- character's Animate script) are switched off for the night and switched back on after, and
-- the arms are posed here by offsetting the shoulder and elbow Motor6D C0s each frame (the
-- Animator still resets Transform, so C0 is what sticks): a rest pose per station plus a short
-- motion on every hit. The original C0s come back when posing stops. No animation assets.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

type Joints = { [string]: CFrame }
type Move = { duration: number, at: (p: number) -> Joints }

local rad = math.rad
local function arm(forward: number, out: number, twist: number?): CFrame
	return CFrame.Angles(rad(forward), rad(twist or 0), rad(out))
end
local function bump(p: number): number -- 0 -> 1 -> 0
	return math.sin(p * math.pi)
end

-- Rest poses: arms held where the station's prop is.
local REST: { [string]: Joints } = {
	Basketball = { RightShoulder = arm(45, 0), RightElbow = arm(30, 0) },
	Gym = {
		RightShoulder = arm(20, 0),
		LeftShoulder = arm(20, 0),
		RightElbow = arm(20, 0),
		LeftElbow = arm(20, 0),
	},
	Burgers = {
		RightShoulder = arm(55, 0),
		LeftShoulder = arm(55, 0),
		RightElbow = arm(35, 0),
		LeftElbow = arm(35, 0),
	},
}

local MOVES: { [string]: Move } = {
	dribble = { -- push the ball down and catch it
		duration = 0.28,
		at = function(p)
			return {
				RightShoulder = arm(45 - 25 * bump(p), 0),
				RightElbow = arm(30 - 25 * bump(p), 0),
			}
		end,
	},
	shoot = { -- both arms up, release
		duration = 0.5,
		at = function(p)
			local up = bump(math.min(1, p * 1.4))
			return {
				RightShoulder = arm(45 + 120 * up, 0),
				LeftShoulder = arm(140 * up, 0),
				RightElbow = arm(30 * (1 - up), 0),
			}
		end,
	},
	curl = { -- both forearms up
		duration = 0.3,
		at = function(p)
			local c = 20 + 110 * bump(p)
			return {
				RightShoulder = arm(20, 0),
				LeftShoulder = arm(20, 0),
				RightElbow = arm(c, 0),
				LeftElbow = arm(c, 0),
			}
		end,
	},
	press = { -- overhead press
		duration = 0.55,
		at = function(p)
			local up = bump(p)
			return {
				RightShoulder = arm(20 + 150 * up, 0),
				LeftShoulder = arm(20 + 150 * up, 0),
				RightElbow = arm(20 * (1 - up), 0),
				LeftElbow = arm(20 * (1 - up), 0),
			}
		end,
	},
	chop = { -- right hand slaps a layer down
		duration = 0.22,
		at = function(p)
			local d = bump(p)
			return {
				RightShoulder = arm(55 + 30 * d, 0),
				LeftShoulder = arm(55, 0),
				RightElbow = arm(35 - 25 * d, 0),
				LeftElbow = arm(35, 0),
			}
		end,
	},
	wrap = { -- both hands sweep the burger across
		duration = 0.3,
		at = function(p)
			local d = bump(p)
			return {
				RightShoulder = arm(55, 0, -40 * d),
				LeftShoulder = arm(55, 0, -40 * d),
				RightElbow = arm(35, 0),
				LeftElbow = arm(35, 0),
			}
		end,
	},
}

local Pose = {}

local station: string? = nil -- posing for this station; nil = off
local move: Move? = nil
local moveStart = 0
local animate: LocalScript? = nil
local originalC0: { [Motor6D]: CFrame } = {}

local MOTORS = {
	RightShoulder = { "RightUpperArm", "RightShoulder", "Torso", "Right Shoulder" },
	LeftShoulder = { "LeftUpperArm", "LeftShoulder", "Torso", "Left Shoulder" },
	RightElbow = { "RightLowerArm", "RightElbow" },
	LeftElbow = { "LeftLowerArm", "LeftElbow" },
}
local function motors(character: Model): { [string]: Motor6D }
	local found = {}
	for name, path in MOTORS do
		local r15 = character:FindFirstChild(path[1])
		local motor = r15 and r15:FindFirstChild(path[2])
		if not motor and path[3] then -- R6
			local torso = character:FindFirstChild(path[3])
			motor = torso and torso:FindFirstChild(path[4])
		end
		if motor and motor:IsA("Motor6D") then
			found[name] = motor
		end
	end
	return found
end

-- Turn station posing on (default animations off) or off (animations back on).
function Pose.set(name: string?)
	local character = player.Character
	if name == station or not character then
		return
	end
	station = name
	move = nil
	if name then
		local script = character:FindFirstChild("Animate")
		if script and script:IsA("LocalScript") then
			animate = script
			script.Enabled = false
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				track:Stop(0.1)
			end
		end
	else
		for motor, c0 in originalC0 do
			motor.C0 = c0
		end
		table.clear(originalC0)
		if animate and animate.Parent then
			animate.Enabled = true
		end
		animate = nil
	end
end

-- A hit at the current station: plays that station's motion.
function Pose.hit(grade: string, skill: boolean)
	if not station or grade == "Miss" then
		return
	end
	local kind = if station == "Basketball"
		then (if skill then "shoot" else "dribble")
		elseif station == "Gym" then (if skill then "press" else "curl")
		else (if skill then "wrap" else "chop")
	move = MOVES[kind]
	moveStart = os.clock()
end

-- Every frame while posing.
RunService.Stepped:Connect(function()
	local character = player.Character
	if not station or not character then
		return
	end
	local joints = table.clone(REST[station] or {})
	local current = move
	if current then
		local p = (os.clock() - moveStart) / current.duration
		if p >= 1 then
			move = nil
		else
			for name, cf in current.at(p) do
				joints[name] = cf
			end
		end
	end
	for name, motor in motors(character) do
		local c0 = originalC0[motor]
		if not c0 then
			c0 = motor.C0
			originalC0[motor] = c0
		end
		motor.C0 = c0 * (joints[name] or CFrame.identity)
	end
end)

player.CharacterAdded:Connect(function()
	station = nil -- the new character has its own Animate, running, and its own C0s
	move = nil
	animate = nil
	table.clear(originalC0)
end)

return Pose
