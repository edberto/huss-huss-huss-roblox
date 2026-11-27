--!strict
-- Practice screen: focus bar, night clock, points, beat track, tap button, hit words.
-- Draws the beat from the server clock and sends tap times; the server judges every tap.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BeatClock = require(ReplicatedStorage.Shared.BeatClock)
local Night = require(ReplicatedStorage.Shared.Night)
local Products = require(ReplicatedStorage.Shared.Products)
local Progress = require(ReplicatedStorage.Shared.Progress)
local Score = require(ReplicatedStorage.Shared.Score)
local StationFx = require(script.Parent.StationFx)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RhythmRemotes")
local tapEvent = remotes:WaitForChild("Tap") :: RemoteEvent
local resultEvent = remotes:WaitForChild("Result") :: RemoteEvent

local Ui = require(script.Parent.Ui)
local NAVY, CREAM, AMBER = Ui.colors.navy, Ui.colors.cream, Ui.colors.amber
local ORANGE, MINT, PINK = Ui.colors.orange, Ui.colors.mint, Ui.colors.pink

local GRADE_STYLE = {
	Perfect = { text = "PERFECT", color = MINT },
	Good = { text = "GOOD", color = CREAM },
	Almost = { text = "ALMOST…", color = AMBER },
	Miss = { text = "MISS", color = PINK },
}

local BEATS_SHOWN = 4 -- beats visible ahead of the hit ring

local RhythmClient = {}

local make, corner, label = Ui.make, Ui.corner, Ui.label

function RhythmClient.start()
	local gui = make("ScreenGui", {
		Name = "HussHud",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	local BLACK = Color3.new(0, 0, 0)
	local function stroke(thickness: number): UIStroke
		return make("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = BLACK,
			Thickness = thickness,
		})
	end
	local function gradient(top: string, bottom: string): UIGradient
		return make("UIGradient", {
			Color = ColorSequence.new(Color3.fromHex(top), Color3.fromHex(bottom)),
			Rotation = 90,
		})
	end

	-- Top bar: moon + night clock. The top-left corner belongs to Roblox's menu buttons, so it
	-- sits in the middle. The focus meter sits on top of the beat track (placed below).
	local clock = Ui.shout({
		LayoutOrder = 2,
		Size = UDim2.fromOffset(104, 30),
		Text = "",
		Thickness = 2.5,
	})
	local focusFill = make(
		"Frame",
		{ BackgroundColor3 = Color3.fromHex("46EBA0"), Size = UDim2.fromScale(1, 1) },
		{
			corner(),
			make("Frame", { -- gloss
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.45,
				Position = UDim2.fromScale(0.03, 0.12),
				Size = UDim2.fromScale(0.94, 0.28),
			}, { corner() }),
		}
	)
	local focusText = Ui.label({
		Size = UDim2.fromScale(1, 1),
		Text = "FOCUS 100",
		TextColor3 = NAVY,
		ZIndex = 3,
	}, { make("UIPadding", { PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0) }) })
	local focusBar = make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromHex("140C28"),
		Position = UDim2.fromOffset(14, -10),
		Size = UDim2.new(0.6, 0, 0, 40),
	}, {
		corner(),
		stroke(3),
		focusFill,
		focusText,
		Ui.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(0, 20),
			Rotation = -8,
			Size = UDim2.fromOffset(38, 46),
			Text = "⚡",
			TextColor3 = Color3.fromHex("FFE63C"),
			ZIndex = 4,
		}),
	})
	local topBar = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(0, 46),
		Visible = false,
		Parent = gui,
	}, {
		corner(),
		stroke(3),
		gradient("3C2878", "1E1446"),
		make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) }),
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Ui.label({ LayoutOrder = 1, Size = UDim2.fromOffset(30, 30), Text = "🌙" }),
		clock,
	})
	-- Phones: shrink, and keep clear of Roblox's own top-left buttons and the Huss pill. Centred
	-- on the screen when there's room; otherwise centred in the gap; otherwise a row lower.
	local topScale = make("UIScale", { Parent = topBar })
	local function placeTopBar()
		local s = Ui.hudScale()
		topScale.Scale = s
		local screen = workspace.CurrentCamera.ViewportSize
		local width = topBar.AbsoluteSize.X -- already scaled
		local left = Ui.topInsetRight() + 8
		local right = screen.X - (16 + 168 + 8) * s
		if screen.X / 2 - width / 2 >= left and screen.X / 2 + width / 2 <= right then
			topBar.Position = UDim2.new(0.5, 0, 0, 8)
		elseif right - left >= width then
			topBar.Position = UDim2.fromOffset((left + right) / 2, 8)
		else
			topBar.Position = UDim2.new(0.5, 0, 0, math.max(Ui.topInset(), 46 * s + 8) + 6)
		end
	end
	Ui.onResize(placeTopBar)
	topBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeTopBar)

	local function refreshFocus()
		local focus = math.clamp(tonumber(player:GetAttribute("Focus")) or 100, 0, 100)
		focusFill.Size = UDim2.fromScale(focus / 100, 1)
		focusFill.BackgroundColor3 = if focus > 35
			then Color3.fromHex("46EBA0")
			else Color3.fromHex("FF5064")
		focusText.Text = `FOCUS {math.round(focus)}`
	end
	player:GetAttributeChangedSignal("Focus"):Connect(refreshFocus)
	refreshFocus()
	local function refreshClock()
		local text = ReplicatedStorage:GetAttribute("NightClock")
		topBar.Visible = typeof(text) == "string"
			and ReplicatedStorage:GetAttribute("Phase") == "Night"
		clock.Text = if typeof(text) == "string" then text else ""
	end
	ReplicatedStorage:GetAttributeChangedSignal("NightClock"):Connect(refreshClock)
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(refreshClock)
	refreshClock()

	-- Top right: Huss total in a gold pill with a coin; pops when it goes up.
	local pointsScale = make("UIScale", {})
	-- Centred in the space right of the coin.
	local points = Ui.shout({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 48, 0.5, 0),
		Size = UDim2.new(1, -58, 0.75, 0),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Center,
		Thickness = 2.5,
	})
	make(
		"UIPadding",
		{ PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.04, 0), Parent = points }
	)
	local pill = make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(1, -16, 0, 8),
		Size = UDim2.fromOffset(168, 46),
		Parent = gui,
	}, {
		corner(),
		stroke(3),
		gradient("FFD246", "EB9614"),
		pointsScale,
		make("Frame", { -- the coin
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromHex("FFF096"),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(36, 36),
		}, {
			corner(),
			stroke(3),
			Ui.label({
				Size = UDim2.fromScale(1, 1),
				FontFace = Ui.display,
				Text = "H",
				TextColor3 = Color3.fromHex("B4640A"),
			}, {
				make(
					"UIPadding",
					{ PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.12, 0) }
				),
			}),
		}),
		points,
	})

	-- Right: the HUSS button, a third of the screen height. Glossy, pulses on every beat
	-- and flashes mint on a hit, pink on a miss.
	local tapScale = make("UIScale", {})
	local tapStroke = stroke(6)
	local tapGlow = make("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = AMBER,
		Thickness = 10,
		Transparency = 0.6,
	})
	local tapButton = make("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(1, -24, 1, -20),
		Size = UDim2.fromScale(0.33, 0.33),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Text = "",
		Parent = gui,
	}, {
		corner(),
		tapStroke,
		tapScale,
		gradient("FF9632", "E1460A"),
		make("Frame", { -- glow ring just outside the button
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 18, 1, 18),
		}, { corner(), tapGlow }),
		make("Frame", { -- gloss
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.72,
			Position = UDim2.fromScale(0.5, 0.07),
			Size = UDim2.fromScale(0.7, 0.36),
		}, { corner() }),
		Ui.shout({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.53),
			Rotation = -5,
			Size = UDim2.fromScale(0.9, 0.36),
			Text = "HUSS",
			Thickness = 5,
		}),
	})
	tapButton.MouseButton1Down:Connect(function()
		TweenService:Create(tapScale, TweenInfo.new(0.06), { Scale = 0.92 }):Play()
	end)
	tapButton.MouseButton1Up:Connect(function()
		TweenService:Create(tapScale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 })
			:Play()
	end)
	tapButton.MouseLeave:Connect(function()
		tapScale.Scale = 1
	end)

	-- Bottom: beat track. Dots slide right to left into the ring; orange = skill move.
	local track = make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.new(0.62, 0, 0, 60),
		Parent = gui,
	}, { corner(), stroke(3), gradient("2D1E5A", "190F37") })
	-- Phones: the pill and the track shrink with the rest of the HUD (track width stays 62%).
	local trackScale = make("UIScale", { Parent = track })
	focusBar.Parent = track -- scales with it on phones
	Ui.onResize(function()
		local s = Ui.hudScale()
		pointsScale.Scale = s
		trackScale.Scale = s
		track.Size = UDim2.new(0.62 / s, 0, 0, 60)
	end)
	local RING_X = 36
	local ringGlow =
		make("UIStroke", { Color = Color3.fromHex("50DCFF"), Thickness = 8, Transparency = 0.5 })
	make("Frame", { -- hit ring: white with a cyan glow that flares on every beat
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, RING_X, 0.5, 0),
		Size = UDim2.fromOffset(44, 44),
		ZIndex = 3,
		Parent = track,
	}, {
		corner(),
		make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 4 }),
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 10, 1, 10),
		}, { corner(), ringGlow }),
	})
	local combo = label({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(70, 22),
		Text = "",
		TextColor3 = Ui.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
		Parent = track,
	})
	-- Faint ticks on every beat, so off-beat notes (Burgers) stay readable.
	local ticks: { Frame } = {}
	for i = 1, BEATS_SHOWN + 2 do
		ticks[i] = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = CREAM,
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 2, 0.6, 0),
			Visible = false,
			Parent = track,
		})
	end
	local dots: { Frame } = {}
	for i = 1, BEATS_SHOWN + 2 do
		dots[i] = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = CREAM,
			Visible = false,
			ZIndex = 2,
			Parent = track,
		}, {
			corner(),
			make("UIStroke", { Color = BLACK, Thickness = 3 }),
			Ui.label({ Name = "Star", Size = UDim2.fromScale(1, 1), Text = "★", ZIndex = 2 }),
		})
	end

	-- Hit word over the player, e.g. PERFECT.
	local hitWord = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		FontFace = Ui.display,
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromScale(0.3, 0.09),
		Text = "",
		TextTransparency = 1,
		Parent = gui,
	})
	local hitStroke =
		make("UIStroke", { Color = BLACK, Thickness = 4, Transparency = 1, Parent = hitWord })

	gui.Parent = player:WaitForChild("PlayerGui")

	-- Top right: saved Huss Points plus what this night has earned so far.
	local sessionPoints = 0
	local function refreshPoints()
		local saved = tonumber(player:GetAttribute("HP")) or 0
		local text = tostring(saved + sessionPoints)
		if text ~= points.Text and points.Text ~= "" then
			local base = Ui.hudScale()
			pointsScale.Scale = base * 1.12
			TweenService
				:Create(pointsScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = base })
				:Play()
		end
		points.Text = text
	end
	player:GetAttributeChangedSignal("HP"):Connect(refreshPoints)
	refreshPoints()

	-- Under the pill: the friend bonus, while friends share the server (Products.nightMultiplier).
	local friendChip = Ui.label({
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromHex("C8287A"),
		BackgroundTransparency = 0,
		Position = UDim2.new(1, 0, 1, 6),
		Size = UDim2.new(1, 0, 0, 26),
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = pill,
	}, {
		corner(),
		stroke(2.5),
		make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
	})
	local function refreshFriends()
		local friends = tonumber(player:GetAttribute("FriendsHere")) or 0
		local bonus =
			math.round(math.min(friends, Products.friendBonusMax) * Products.friendBonus * 100)
		friendChip.Visible = friends > 0
		friendChip.Text =
			`👥 {friends} friend{if friends == 1 then "" else "s"} · +{bonus}% Huss`
	end
	player:GetAttributeChangedSignal("FriendsHere"):Connect(refreshFriends)
	refreshFriends()

	-- Under the pill (and the friend chip): the one-time Starter Pack, shining, for players who
	-- don't own it yet. Dusk and Dawn only, like the side menu; tapping opens the purchase.
	local starter = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		AutoButtonColor = true,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, 62),
		Text = "",
		Visible = false,
		Parent = pill,
	}, {
		corner(),
		stroke(3),
		gradient("FF5AC8", "C8287A"),
		Ui.shout({ -- top row: the name, as wide as the button
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(1, -16, 0, 28),
			Text = "STARTER PACK",
			TextColor3 = Color3.fromHex("FFE63C"),
			Thickness = 2.5,
		}),
		Ui.label({ -- bottom row: what's inside, then the price
			Position = UDim2.fromOffset(8, 34),
			Size = UDim2.new(0.62, -8, 0, 22),
			Text = "1,000 Huss + more",
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		make("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Color3.fromHex("3DDC84"),
			Position = UDim2.new(1, -6, 0, 33),
			Size = UDim2.new(0.36, 0, 0, 24),
		}, {
			corner(),
			stroke(2),
			Ui.label({
				Size = UDim2.fromScale(1, 1),
				Text = "R$ 49", -- the Starter Pack game pass price (Creator Hub)
				TextColor3 = Color3.fromHex("04342C"),
			}, {
				make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
			}),
		}),
	})
	local shine = make("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(-0.3, 0),
		Size = UDim2.fromScale(0.25, 1),
		ZIndex = 5,
		Parent = starter,
	}, {
		make("UIGradient", {
			Rotation = 20,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	starter.Activated:Connect(function()
		pcall(
			game:GetService("MarketplaceService").PromptGamePassPurchase,
			game:GetService("MarketplaceService"),
			player,
			Products.starterPassId
		)
	end)
	local function refreshStarter()
		starter.Visible = player:GetAttribute("StarterPack") == false
			and ReplicatedStorage:GetAttribute("Phase") ~= "Night"
		starter.Position = UDim2.new(1, 0, 1, if friendChip.Visible then 38 else 6)
	end
	player:GetAttributeChangedSignal("StarterPack"):Connect(refreshStarter)
	player:GetAttributeChangedSignal("FriendsHere"):Connect(refreshStarter)
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(refreshStarter)
	refreshStarter()
	task.spawn(function() -- a shine sweeps across every few seconds
		while true do
			if starter.Visible then
				shine.Position = UDim2.fromScale(-0.3, 0)
				TweenService:Create(
					shine,
					TweenInfo.new(0.8, Enum.EasingStyle.Sine),
					{ Position = UDim2.fromScale(1.05, 0) }
				):Play()
			end
			task.wait(2.6)
		end
	end)

	local function flashWord(text: string, color: Color3, seconds: number)
		hitWord.Text = text
		hitWord.TextColor3 = color
		hitWord.TextTransparency = 0
		hitStroke.Transparency = 0
		local fade = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(hitWord, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(hitStroke, fade, { Transparency = 1 }):Play()
	end

	type Segment = { startTime: number, bpm: number, pattern: BeatClock.Pattern }
	local function readSegment(startKey: string, bpmKey: string): Segment?
		local startTime, bpm = player:GetAttribute(startKey), player:GetAttribute(bpmKey)
		return if typeof(startTime) == "number" and typeof(bpm) == "number"
			then {
				startTime = startTime,
				bpm = bpm,
				pattern = Night.pattern(player:GetAttribute("Station")),
			}
			else nil
	end
	-- `segment` is the beat now; `nextSegment` is a tempo step waiting on the next bar line
	-- (the server's Rhythm.changeTempo). The switch happens here on the bar line itself, so
	-- the beat carries straight on at the new speed.
	local segment: Segment? = nil
	local nextSegment: Segment? = nil
	local function refreshSegment()
		segment = readSegment("BeatStart", "BeatBpm")
		if not segment then
			sessionPoints = 0
			refreshPoints()
		end
	end
	local function refreshNext()
		local previous = nextSegment
		nextSegment = readSegment("BeatNextStart", "BeatNextBpm")
		if nextSegment and not previous then
			flashWord("TEMPO UP!", ORANGE, 1.4) -- a bar ahead of the change
			StationFx.play("tempo")
		end
	end
	-- The segment to play at `now`: the waiting tempo step once its bar line has passed.
	local function segmentAt(now: number): Segment?
		local waiting = nextSegment
		if waiting and now >= waiting.startTime then
			return waiting
		end
		return segment
	end
	player:GetAttributeChangedSignal("BeatStart"):Connect(refreshSegment)
	player:GetAttributeChangedSignal("BeatBpm"):Connect(refreshSegment)
	player:GetAttributeChangedSignal("BeatNextStart"):Connect(refreshNext)
	player:GetAttributeChangedSignal("BeatNextBpm"):Connect(refreshNext)
	refreshSegment()
	refreshNext()

	-- The audible beat: a thud every beat, a clap on each skill note (up to a frame late).
	-- On top, a training groove on eighth notes that builds as the tempo steps up:
	-- step 2 adds hi-hats, step 3 the bassline, step 4 a stab on every bar.
	-- Bassline: 2 bars of eighths, semitones from C2 (nil = rest).
	local BASSLINE = { 0, nil, 0, 3, nil, 0, nil, 5, 7, nil, 7, 5, nil, 3, nil, nil }
	local clickStart, clickBeat, clapNote, eighth = 0, -1, -1, -1
	RunService.RenderStepped:Connect(function()
		local current = segmentAt(workspace:GetServerTimeNow())
		if current then
			local now = workspace:GetServerTimeNow()
			local beat = math.floor((now - current.startTime) * current.bpm / 60)
			local note = BeatClock.nearest(current.startTime, current.bpm, now, current.pattern)
			if BeatClock.noteTime(current.startTime, current.bpm, note, current.pattern) > now then
				note -= 1
			end
			local step = math.floor((now - current.startTime) * current.bpm / 30)
			if current.startTime ~= clickStart then
				clickStart, clickBeat, clapNote, eighth =
					current.startTime, math.min(beat, -1), math.min(note, -1), math.min(step, -1)
			end
			if step > eighth and step >= 0 then
				eighth = step
				local layers = table.find(Night.bpmSteps, current.bpm) or 1
				if layers >= 2 and (step % 2 == 1 or layers >= 4) then
					StationFx.play("hat", if step % 2 == 1 then 1 else 1.15)
				end
				local semitone = BASSLINE[step % #BASSLINE + 1]
				if layers >= 3 and semitone then
					StationFx.play("bass", 2 ^ (semitone / 12))
				end
				if layers >= 4 and step % 8 == 0 then
					StationFx.play("stab")
				end
			end
			if beat > clickBeat then
				clickBeat = beat
				StationFx.play("kick")
				-- Pulse the button glow and the hit ring on the beat (not with Reduce flashing).
				if player:GetAttribute("CalmFlashing") ~= true then
					tapGlow.Transparency = 0.1
					ringGlow.Transparency = 0.05
					TweenService:Create(tapGlow, TweenInfo.new(0.35), { Transparency = 0.7 }):Play()
					TweenService:Create(ringGlow, TweenInfo.new(0.35), { Transparency = 0.6 })
						:Play()
				end
			end
			if note > clapNote then
				clapNote = note
				if BeatClock.isSkillBeat(note, current.pattern) then
					StationFx.play("clap")
				end
			end
		end
		for _, dot in dots do
			dot.Visible = false
		end
		for _, tick in ticks do
			tick.Visible = false
		end
		-- Track and button only while practising (not at Dusk, Dawn or as a partier).
		track.Visible = current ~= nil
		focusBar.Visible = current ~= nil
		tapButton.Visible = current ~= nil
		if not current then
			return
		end
		local now = workspace:GetServerTimeNow()
		local interval = 60 / current.bpm
		-- Children are laid out before the track's UIScale, so measure in unscaled pixels.
		local span = track.AbsoluteSize.X / trackScale.Scale - RING_X - 100
		local firstBeat = math.ceil((now - current.startTime) / interval - 0.25)
		for i, tick in ticks do
			local x = RING_X
				+ (current.startTime + (firstBeat + i - 1) * interval - now)
					/ (interval * BEATS_SHOWN)
					* span
			if x >= RING_X and x <= RING_X + span then
				tick.Position = UDim2.new(0, x, 0.5, 0)
				tick.Visible = true
			end
		end
		-- Notes to draw: this segment's up to a waiting tempo step's bar line, then the step's.
		local upcoming: { { time: number, skill: boolean } } = {}
		local waiting = if nextSegment and nextSegment ~= current then nextSegment else nil
		local cutoff = if waiting then waiting.startTime else math.huge
		-- (Parenthesised: nearest() also returns the offset, which must not reach math.max.)
		local first = math.max(
			0,
			(
				BeatClock.nearest(
					current.startTime,
					current.bpm,
					now - interval * 0.25,
					current.pattern
				)
			)
		)
		for beat = first, first + #dots - 1 do
			local time = BeatClock.noteTime(current.startTime, current.bpm, beat, current.pattern)
			if time >= cutoff then
				break
			end
			table.insert(
				upcoming,
				{ time = time, skill = BeatClock.isSkillBeat(beat, current.pattern) }
			)
		end
		if waiting then
			for beat = 0, #dots - #upcoming - 1 do
				table.insert(upcoming, {
					time = BeatClock.noteTime(
						waiting.startTime,
						waiting.bpm,
						beat,
						waiting.pattern
					),
					skill = BeatClock.isSkillBeat(beat, waiting.pattern),
				})
			end
		end
		for i, dot in dots do
			local note = upcoming[i]
			local ahead = if note then note.time - now else math.huge
			local x = RING_X + ahead / (interval * BEATS_SHOWN) * span
			if note and x >= RING_X - 20 and x <= RING_X + span then
				local skill = note.skill
				local size = if skill then 36 else 24
				dot.Size = UDim2.fromOffset(size, size)
				dot.BackgroundColor3 = if skill then ORANGE else CREAM
				local star = dot:FindFirstChild("Star") :: TextLabel
				star.Visible = skill
				dot.Position = UDim2.new(0, x, 0.5, 0)
				dot.Visible = true
			end
		end
	end)

	local function tap()
		if segment then
			tapEvent:FireServer(workspace:GetServerTimeNow())
		end
	end
	tapButton.Activated:Connect(tap)
	-- Keys are ignored while typing in chat (Ui.bind skips game-processed input).
	Ui.bind(tapButton, { Enum.KeyCode.Space }, { Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2 }, tap)

	resultEvent.OnClientEvent:Connect(
		function(
			_beat: number,
			grade: string,
			_earned: number,
			total: number,
			streak: number,
			skill: boolean
		)
			local style = GRADE_STYLE[grade]
			if not style then
				return
			end
			sessionPoints = math.floor(total * Progress.hussPerPoint) -- Huss so far, before bonuses
			refreshPoints()
			combo.Text = if streak > 0 then `x{Score.multiplier(streak)} · {streak}` else ""
			flashWord(style.text, style.color, 0.5)
			tapStroke.Color = if grade == "Miss" then PINK else MINT
			TweenService:Create(tapStroke, TweenInfo.new(0.3), { Color = BLACK }):Play()
			RhythmClient.onResult(grade, skill)
		end
	)
end

-- Hook for the station's visuals and sounds; set by the station before start().
function RhythmClient.onResult(_grade: string, _skill: boolean) end

return RhythmClient
