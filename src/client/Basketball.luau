--!strict
-- Basketball station visuals and sounds: the ball follows the player, dribbles on every hit and
-- is shot on the skill beat. A skill-beat "Almost" rims out with the "ahh almost almost" moment.
-- Everything here is local to the player's own screen; scoring stays on the server.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Creator Store sound effects (free to use in experiences). Swap for our own recordings later.
local SOUNDS = {
	huss = "rbxassetid://9113702955", -- Pro Sound Effects: airy breath exhale
	bounce = "rbxassetid://377958030", -- basketball bounce
	rim = "rbxassetid://81912260477958", -- brick rim hit
}

local DRIBBLE_TIME = 0.28
local FLIGHT_TIME = 0.45
local ALMOST_COOLDOWN = 20 -- seconds between "ahh almost almost" moments (design doc)
local GROUND_Y = 1.05 -- driveway top + ball radius

type Motion = { kind: "dribble" | "make" | "rimout", start: number, from: Vector3? }

local Basketball = {}

local function makeSound(id: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end

local function play(sound: Sound, pitch: number?)
	sound.PlaybackSpeed = pitch or 1
	SoundService:PlayLocalSound(sound)
end

function Basketball.start(home: Model): (grade: string, skill: boolean) -> ()
	local ball = home:WaitForChild("Ball") :: BasePart
	-- The rim pieces ring the hoop, so their average position is its centre.
	local rimSum, rimCount = Vector3.zero, 0
	for _, child in home:GetChildren() do
		if child.Name == "Rim" and child:IsA("BasePart") then
			rimSum += child.Position
			rimCount += 1
		end
	end
	local rimCenter = rimSum / math.max(rimCount, 1)
	local huss = makeSound(SOUNDS.huss, 0.5)
	local bounce = makeSound(SOUNDS.bounce, 0.6)
	local rim = makeSound(SOUNDS.rim, 0.8)
	local lastAlmost = -math.huge

	-- "huss" bubble over the head, and the bigger "ahh almost almost" bubble.
	local bubble = Instance.new("BillboardGui")
	bubble.Size = UDim2.fromOffset(160, 50)
	bubble.StudsOffset = Vector3.new(0, 3.2, 0)
	bubble.AlwaysOnTop = true
	local bubbleText = Instance.new("TextLabel")
	bubbleText.BackgroundColor3 = Color3.fromHex("F2EEDC")
	bubbleText.BackgroundTransparency = 1
	bubbleText.TextColor3 = Color3.fromHex("141B36")
	bubbleText.TextTransparency = 1
	bubbleText.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	bubbleText.TextScaled = true
	bubbleText.AnchorPoint = Vector2.new(0.5, 0.5)
	bubbleText.Position = UDim2.fromScale(0.5, 0.5)
	bubbleText.Size = UDim2.fromScale(0.5, 0.6)
	local bubbleCorner = Instance.new("UICorner")
	bubbleCorner.CornerRadius = UDim.new(0.4, 0)
	bubbleCorner.Parent = bubbleText
	bubbleText.Parent = bubble

	local function say(text: string, big: boolean)
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		bubble.Adornee = head or (character and character.PrimaryPart)
		bubble.Parent = player:FindFirstChildOfClass("PlayerGui")
		bubbleText.Text = text
		bubbleText.Size = if big then UDim2.fromScale(1, 0.9) else UDim2.fromScale(0.5, 0.6)
		bubbleText.TextTransparency = 0
		bubbleText.BackgroundTransparency = 0
		local fade =
			TweenInfo.new(if big then 1.4 else 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(bubbleText, fade, { TextTransparency = 1, BackgroundTransparency = 1 })
			:Play()
	end

	-- Where the ball rests: just below the right hand, or in front of the player's right side for
	-- avatars without one.
	local function handPosition(): Vector3?
		local character = player.Character
		local hand = character
			and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
		if hand and hand:IsA("BasePart") then
			return hand.Position - Vector3.new(0, hand.Size.Y / 2 + 0.6, 0)
		end
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return nil
		end
		return (root.CFrame * CFrame.new(1.6, -0.6, -1.4)).Position
	end

	local motion: Motion? = nil

	RunService.RenderStepped:Connect(function()
		local hand = handPosition()
		if not hand then
			return
		end
		local current = motion
		local now = os.clock()
		if not current then
			ball.Position = hand
			return
		end
		local elapsed = now - current.start
		if current.kind == "dribble" then
			local p = math.clamp(elapsed / DRIBBLE_TIME, 0, 1)
			-- Parabola: hand at p = 0 and 1, ground at p = 0.5.
			local y = GROUND_Y + (hand.Y - GROUND_Y) * (2 * p - 1) ^ 2
			ball.Position = Vector3.new(hand.X, y, hand.Z)
			if p >= 1 then
				motion = nil
			end
		else
			local from = current.from or hand
			local target = if current.kind == "make"
				then rimCenter
				else rimCenter + Vector3.new(1.4, 0.2, -0.6)
			if elapsed < FLIGHT_TIME then
				local p = elapsed / FLIGHT_TIME
				local arc = math.sin(p * math.pi) * 5
				ball.Position = from:Lerp(target, p) + Vector3.new(0, arc, 0)
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
		end
	end)

	return function(grade: string, skill: boolean)
		if grade == "Miss" then
			return
		end
		play(huss, 0.9 + math.random() * 0.25)
		say("huss", false)
		local inFlight = motion
			and motion.kind ~= "dribble"
			and os.clock() - motion.start < FLIGHT_TIME
		if inFlight then
			return
		end
		if not skill then
			motion = { kind = "dribble", start = os.clock() }
			task.delay(DRIBBLE_TIME / 2, play, bounce)
		elseif grade == "Almost" then
			motion = { kind = "rimout", start = os.clock(), from = ball.Position }
			task.delay(FLIGHT_TIME, play, rim)
			if os.clock() - lastAlmost >= ALMOST_COOLDOWN then
				lastAlmost = os.clock()
				task.delay(FLIGHT_TIME, function()
					say("ahh almost almost", true)
					local camera = workspace.CurrentCamera
					local fov = camera.FieldOfView
					local punch = TweenInfo.new(
						0.25,
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.Out,
						0,
						true
					)
					TweenService:Create(camera, punch, { FieldOfView = fov - 8 }):Play()
				end)
			end
		else
			motion = { kind = "make", start = os.clock(), from = ball.Position }
		end
	end
end

return Basketball
