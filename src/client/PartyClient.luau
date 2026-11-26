--!strict
-- Partier screen (ability buttons, party points, marker on the nearest trainer in range) and
-- what a trainer sees when tempted: Invite flyer, Speaker fake beats, Dance battle border.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Night = require(ReplicatedStorage.Shared.Night)
local StationFx = require(script.Parent.StationFx)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RhythmRemotes")
local abilityEvent = remotes:WaitForChild("PartyAbility") :: RemoteEvent
local effectEvent = remotes:WaitForChild("PartyEffect") :: RemoteEvent

local C = Ui.colors
local make, corner, label = Ui.make, Ui.corner, Ui.label

local BUTTONS = {
	{ ability = "Invite", name = "Invite", color = C.pink },
	{ ability = "Speaker", name = "Speaker", color = C.orange },
	-- Shown as Dance-Off so it isn't confused with the DANCE emote button.
	{ ability = "Dance", name = "Dance-Off", color = C.purple },
}

local PartyClient = {}

-- A trainer is a player, or an NPC trainer's model (workspace.Npcs, "NpcTrainer" attribute).
type Target = Player | Model
local function rootOf(target: Target): BasePart?
	local character = if target:IsA("Player") then target.Character else target
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end
local function nameOf(target: Target): string
	return if target:IsA("Player") then target.DisplayName else target.Name
end

-- Nearest trainer within ability range, or nil.
local function nearestTrainer(): Target?
	local mine = rootOf(player)
	if not mine then
		return nil
	end
	local candidates: { Target } = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("Team") == "Trainer" then
			table.insert(candidates, other)
		end
	end
	local npcs = workspace:FindFirstChild("Npcs")
	for _, model in if npcs then npcs:GetChildren() else {} do
		if model:IsA("Model") and model:GetAttribute("NpcTrainer") == true then
			table.insert(candidates, model)
		end
	end
	local best, bestDistance = nil, Night.abilityRange
	for _, candidate in candidates do
		local root = rootOf(candidate)
		local distance = if root then (root.Position - mine.Position).Magnitude else math.huge
		if distance <= bestDistance then
			best, bestDistance = candidate, distance
		end
	end
	return best
end

function PartyClient.start()
	local gui = make("ScreenGui", {
		Name = "PartyScreens",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 4,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Partier view ----------------------------------------------------------------------------
	local partierView = make(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = gui }
	)
	-- Under the Huss pill, top right (top left belongs to Roblox's buttons and the side menu).
	local pointsLabel = label({
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = C.partyWall,
		BackgroundTransparency = 0,
		Position = UDim2.new(1, -16, 0, 62),
		Size = UDim2.fromOffset(200, 28),
		TextColor3 = C.pink,
		Parent = partierView,
	}, {
		corner(10),
		make("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }),
	})
	local pointsScale = make("UIScale", { Parent = pointsLabel })
	-- Below the Huss pill, and below the friend bonus chip when it shows (RhythmClient).
	local function placePoints()
		local s = Ui.hudScale()
		local friends = (tonumber(player:GetAttribute("FriendsHere")) or 0) > 0
		pointsScale.Scale = s
		pointsLabel.Position = UDim2.new(1, -16, 0, (8 + 46 + 8 + (if friends then 32 else 0)) * s)
	end
	Ui.onResize(placePoints)
	player:GetAttributeChangedSignal("FriendsHere"):Connect(placePoints)
	-- Just above the DANCE button, bottom centre.
	label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.925, -22),
		Size = UDim2.fromOffset(320, 20),
		Text = "Walk up to a trainer, then tap an ability",
		TextColor3 = Color3.fromHex("B4B2A9"),
		Parent = partierView,
	})
	local buttonRow = make("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		-- On phones, sit above the jump button.
		Position = UDim2.new(1, -16, 1, if UserInputService.TouchEnabled then -150 else -16),
		Size = UDim2.fromScale(0.42, 0.2),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Parent = partierView,
	}, {
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0.04, 0),
		}),
	})
	local readyAt: { [string]: number } = {}
	local buttons: { [string]: TextButton } = {}
	for i, spec in BUTTONS do
		local button = make("TextButton", {
			BackgroundColor3 = spec.color,
			FontFace = Ui.font,
			LayoutOrder = i,
			Size = UDim2.fromScale(1, 1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Text = spec.name,
			TextColor3 = C.cream,
			TextScaled = true,
			Parent = buttonRow,
		}, {
			corner(),
			make(
				"UIStroke",
				{ Color = C.cream, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
			),
			make("UIPadding", {
				PaddingTop = UDim.new(0.3, 0),
				PaddingBottom = UDim.new(0.3, 0),
				PaddingLeft = UDim.new(0.12, 0),
				PaddingRight = UDim.new(0.12, 0),
			}),
		})
		buttons[spec.ability] = button
		local function use()
			local target = nearestTrainer()
			if not target or os.clock() < (readyAt[spec.ability] or 0) then
				return
			end
			readyAt[spec.ability] = os.clock() + Night.abilities[spec.ability].cooldown
			abilityEvent:FireServer(spec.ability, target)
		end
		button.Activated:Connect(use)
		Ui.bind(
			button,
			{ ({ Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.R })[i] },
			{ ({ Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonB })[i] },
			use
		)
	end

	-- Marker over the nearest trainer in range.
	local marker = make("BillboardGui", {
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(150, 30),
		StudsOffset = Vector3.new(0, 4, 0),
		Enabled = false,
		Parent = gui,
	})
	local markerText = label({
		BackgroundColor3 = C.navy,
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = C.pink,
		Parent = marker,
	}, {
		corner(10),
		make(
			"UIStroke",
			{ Color = C.pink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
		),
		make("UIPadding", { PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.15, 0) }),
	})

	RunService.Heartbeat:Connect(function()
		local isPartier = player:GetAttribute("Team") == "Partier"
			and ReplicatedStorage:GetAttribute("Phase") == "Night"
		partierView.Visible = isPartier
		if not isPartier then
			marker.Enabled = false
			return
		end
		pointsLabel.Text =
			`Partier · {math.floor(tonumber(player:GetAttribute("PartyPoints")) or 0)} party pts`
		local target = nearestTrainer()
		marker.Enabled = target ~= nil
		if target then
			marker.Adornee = rootOf(target)
			markerText.Text = `{nameOf(target)} · in range`
		end
		for _, spec in BUTTONS do
			local left = math.ceil((readyAt[spec.ability] or 0) - os.clock())
			local button = buttons[spec.ability]
			button.Text = if left > 0 then `{left} s` else spec.name
			button.BackgroundColor3 = if left > 0 or not target then C.panel else spec.color
		end
	end)

	-- Trainer effects -------------------------------------------------------------------------
	-- Same frame as the beat track (RhythmClient) so the flyer and fake beats sit on it.
	local trackOverlay = make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.new(0.62, 0, 0, 56),
		Parent = gui,
	})
	-- The Invite flyer covers the beat track until it times out, or until you toss it (tap it,
	-- E, or X on a controller).
	local flyer = make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = false,
		BackgroundColor3 = C.gold,
		FontFace = Ui.font,
		Position = UDim2.fromScale(0.45, 0.3),
		Rotation = -8,
		Size = UDim2.fromOffset(120, 110),
		Text = "PARTY\nTONIGHT",
		TextColor3 = C.partyWall,
		TextScaled = true,
		Visible = false,
		ZIndex = 5,
		Parent = trackOverlay,
	}, {
		corner(4),
		make("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0) }),
	})
	local function tossFlyer()
		flyer.Visible = false
	end
	-- NightScreens' E-spam lock ignores presses aimed at the flyer.
	flyer:GetPropertyChangedSignal("Visible"):Connect(function()
		player:SetAttribute("FlyerUp", flyer.Visible)
	end)
	flyer.Activated:Connect(tossFlyer)
	Ui.bind(flyer, { Enum.KeyCode.E }, { Enum.KeyCode.ButtonX }, tossFlyer)
	local fakeDots: { Frame } = {}
	for i = 1, 4 do
		fakeDots[i] = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = C.pink,
			Size = UDim2.fromOffset(24, 24),
			Visible = false,
			ZIndex = 4,
			Parent = trackOverlay,
		}, { corner() })
	end
	local danceBorder = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = gui,
	}, { make("UIStroke", { Color = C.pink, Thickness = 8 }) })
	local danceBanner = label({
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.purple,
		BackgroundTransparency = 0,
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromOffset(300, 34),
		Text = "Dance battle! Keep hitting",
		Visible = false,
		Parent = gui,
	}, {
		corner(10),
		make("UIPadding", { PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.15, 0) }),
	})

	local speakerUntil = 0
	effectEvent.OnClientEvent:Connect(function(ability: string, duration: number)
		if ability == "Invite" then
			flyer.Visible = true
			task.delay(duration, function()
				flyer.Visible = false
			end)
		elseif ability == "Speaker" then
			speakerUntil = os.clock() + duration
		elseif ability == "Dance" then
			danceBorder.Visible = true
			danceBanner.Visible = true
			task.delay(duration, function()
				danceBorder.Visible = false
				danceBanner.Visible = false
			end)
		end
	end)

	-- Fake beats sit a quarter beat off the real ones (between notes on every station), sliding at
	-- the same speed, and you hear them.
	local fakeHeard = math.huge
	RunService.RenderStepped:Connect(function()
		local active = os.clock() < speakerUntil
		local startTime, bpm = player:GetAttribute("BeatStart"), player:GetAttribute("BeatBpm")
		for _, dot in fakeDots do
			dot.Visible = false
		end
		if not active or typeof(startTime) ~= "number" or typeof(bpm) ~= "number" then
			fakeHeard = math.huge -- first frame of the next Speaker only arms it
			return
		end
		local now = workspace:GetServerTimeNow()
		local interval = 60 / bpm
		local half = math.floor((now - startTime) / interval - 0.25)
		if half > fakeHeard then
			StationFx.play("kick", 1.15)
		end
		fakeHeard = half
		local span = trackOverlay.AbsoluteSize.X - 34 - 100
		local first = math.ceil((now - startTime) / interval - 0.25)
		for i, dot in fakeDots do
			local ahead = startTime + (first + i - 0.75) * interval - now
			local x = 34 + ahead / (interval * 4) * span
			if x >= 34 and x <= 34 + span then
				dot.Position = UDim2.new(0, x, 0.5, 0)
				dot.Visible = true
			end
		end
	end)
end

return PartyClient
