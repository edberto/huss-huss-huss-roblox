--!strict
-- Station arm motions while practising, for every trainer on your screen: your own avatar
-- and, replayed from StationHit, everyone else's. Joint Transforms don't replicate, so each
-- client poses everyone. For your own avatar the default animations (its Animate script) are
-- switched off for the night and back on after; that also stops them for everyone else, so
-- other avatars only need posing. The arms are posed by setting the shoulder and elbow joint
-- Transforms each Stepped (after animations): a rest pose per station plus a short motion on
-- every hit. Works for Motor6D and AnimationConstraint joints. No animation assets needed.
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
	fumble = { -- a miss: arms flail out, any station
		duration = 0.45,
		at = function(p)
			local f = bump(p) * math.sin(p * math.pi * 4)
			return {
				RightShoulder = arm(30, -70 * bump(p) + 25 * f),
				LeftShoulder = arm(30, 70 * bump(p) - 25 * f),
				RightElbow = arm(10, 0),
				LeftElbow = arm(10, 0),
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

type State = { station: string?, move: Move?, moveStart: number, animate: LocalScript? }
local states: { [Player]: State } = {}
local function stateOf(who: Player): State
	local state = states[who]
	if not state then
		state = { station = nil, move = nil, moveStart = 0, animate = nil }
		states[who] = state
		-- A new character has its own Animate (running) and its own joints.
		who.CharacterAdded:Connect(function()
			state.station, state.move, state.animate = nil, nil, nil
		end)
	end
	return state :: State
end
Players.PlayerRemoving:Connect(function(who)
	states[who] = nil
end)

local MOTORS = {
	RightShoulder = { "RightUpperArm", "RightShoulder", "Torso", "Right Shoulder" },
	LeftShoulder = { "LeftUpperArm", "LeftShoulder", "Torso", "Left Shoulder" },
	RightElbow = { "RightLowerArm", "RightElbow" },
	LeftElbow = { "LeftLowerArm", "LeftElbow" },
}
local function motors(character: Model): { [string]: any }
	local found = {}
	for name, path in MOTORS do
		local r15 = character:FindFirstChild(path[1])
		local motor = r15 and r15:FindFirstChild(path[2])
		if not motor and path[3] then -- R6
			local torso = character:FindFirstChild(path[3])
			motor = torso and torso:FindFirstChild(path[4])
		end
		-- Newer avatars use AnimationConstraint joints instead of Motor6D; both have a Transform.
		if motor and (motor:IsA("Motor6D") or motor:IsA("AnimationConstraint")) then
			found[name] = motor
		end
	end
	return found
end

-- Turn station posing on (default animations off) or off (animations back on) for `who`.
function Pose.set(who: Player, name: string?)
	local state = stateOf(who)
	local character = who.Character
	if name == state.station or not character then
		return
	end
	state.station = name
	state.move = nil
	local mine = who == player
	if name then
		if mine then
			local script = character:FindFirstChild("Animate")
			if script and script:IsA("LocalScript") then
				state.animate = script
				script.Enabled = false
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if animator then
				for _, track in animator:GetPlayingAnimationTracks() do
					track:Stop(0.1)
				end
			end
		end
	else
		for _, motor in motors(character) do
			motor.Transform = CFrame.identity
		end
		local animate = state.animate
		if animate and animate.Parent then
			animate.Enabled = true
		end
		state.animate = nil
	end
end

-- A hit at `who`'s current station: plays that station's motion.
function Pose.hit(who: Player, grade: string, skill: boolean)
	local state = stateOf(who)
	local station = state.station
	if not station then
		return
	end
	local kind = if grade == "Miss" then "fumble"
		elseif station == "Basketball"
		then (if skill then "shoot" else "dribble")
		elseif station == "Gym" then (if skill then "press" else "curl")
		else (if skill then "wrap" else "chop")
	state.move = MOVES[kind]
	state.moveStart = os.clock()
end

-- Every frame: pose everyone who's practising.
RunService.Stepped:Connect(function()
	for who, state in states do
		local character = who.Character
		local station = state.station
		if station and character then
			local joints = table.clone(REST[station] or {})
			local current = state.move
			if current then
				local p = (os.clock() - state.moveStart) / current.duration
				if p >= 1 then
					state.move = nil
				else
					for name, cf in current.at(p) do
						joints[name] = cf
					end
				end
			end
			for name, motor in motors(character) do
				motor.Transform = joints[name] or CFrame.identity
			end
		end
	end
end)

return Pose
