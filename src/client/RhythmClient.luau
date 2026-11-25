--!strict
-- Practice screen: focus bar, night clock, points, beat track, tap button, hit words.
-- Draws the beat from the server clock and sends tap times; the server judges every tap.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local BeatClock = require(ReplicatedStorage.Shared.BeatClock)
local Night = require(ReplicatedStorage.Shared.Night)
local Score = require(ReplicatedStorage.Shared.Score)
local StationFx = require(script.Parent.StationFx)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RhythmRemotes")
local tapEvent = remotes:WaitForChild("Tap") :: RemoteEvent
local resultEvent = remotes:WaitForChild("Result") :: RemoteEvent

local Ui = require(script.Parent.Ui)
local NAVY, CREAM, AMBER = Ui.colors.navy, Ui.colors.cream, Ui.colors.amber
local ORANGE, MINT, PINK, PANEL = Ui.colors.orange, Ui.colors.mint, Ui.colors.pink, Ui.colors.panel
local FONT = Ui.font

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

	-- Top left: focus bar. FocusService will set the player's "Focus" attribute (0-100).
	local focusFill = make(
		"Frame",
		{ BackgroundColor3 = MINT, Size = UDim2.fromScale(1, 1) },
		{ corner() }
	)
	local focusText = label({
		Text = "Focus 100",
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	-- Under the clock: the top-left corner belongs to Roblox's menu buttons.
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.fromOffset(170, 36),
		Parent = gui,
	}, {
		focusText,
		make("Frame", {
			BackgroundColor3 = PANEL,
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(1, 0, 0, 12),
		}, { corner(), focusFill }),
	})
	local function refreshFocus()
		local focus = math.clamp(tonumber(player:GetAttribute("Focus")) or 100, 0, 100)
		focusFill.Size = UDim2.fromScale(focus / 100, 1)
		focusText.Text = `Focus {math.round(focus)}`
	end
	player:GetAttributeChangedSignal("Focus"):Connect(refreshFocus)
	refreshFocus()

	-- Top middle: night clock. RoundService will set ReplicatedStorage's "NightClock" attribute.
	local clock = label({
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0,
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(110, 30),
		Parent = gui,
	})
	make(
		"UIPadding",
		{ PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), Parent = clock }
	)
	corner(10).Parent = clock
	local function refreshClock()
		local text = ReplicatedStorage:GetAttribute("NightClock")
		clock.Visible = typeof(text) == "string"
		clock.Text = if typeof(text) == "string" then text else ""
	end
	ReplicatedStorage:GetAttributeChangedSignal("NightClock"):Connect(refreshClock)
	refreshClock()

	-- Top right: Huss Points earned this session.
	local points = label({
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0,
		Position = UDim2.new(1, -16, 0, 10),
		Size = UDim2.fromOffset(120, 30),
		Text = "",
		TextColor3 = AMBER,
		Parent = gui,
	})
	make(
		"UIPadding",
		{ PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), Parent = points }
	)
	corner(10).Parent = points

	-- Right: tap button, a third of the screen height.
	local tapButton = make("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = ORANGE,
		FontFace = FONT,
		Position = UDim2.new(1, -20, 1, -16),
		Size = UDim2.fromScale(0.33, 0.33),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Text = "HUSS",
		TextColor3 = NAVY,
		TextScaled = true,
		Parent = gui,
	}, {
		corner(),
		make(
			"UIStroke",
			{ Color = CREAM, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
		),
		make("UIPadding", {
			PaddingTop = UDim.new(0.3, 0),
			PaddingBottom = UDim.new(0.3, 0),
			PaddingLeft = UDim.new(0.15, 0),
			PaddingRight = UDim.new(0.15, 0),
		}),
	})

	-- Bottom: beat track. Dots slide right to left into the ring; orange = skill move.
	local track = make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = PANEL,
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.new(0.62, 0, 0, 56),
		Parent = gui,
	}, { corner() })
	local RING_X = 34
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, RING_X, 0.5, 0),
		Size = UDim2.fromOffset(40, 40),
		Parent = track,
	}, { corner(), make("UIStroke", { Color = CREAM, Thickness = 3 }) })
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
		}, { corner() })
	end

	-- Hit word over the player, e.g. PERFECT.
	local hitWord = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromScale(0.3, 0.09),
		Text = "",
		TextTransparency = 1,
		Parent = gui,
	})
	local hitStroke =
		make("UIStroke", { Color = NAVY, Thickness = 3, Transparency = 1, Parent = hitWord })

	gui.Parent = player:WaitForChild("PlayerGui")

	-- Top right: saved Huss Points plus what this night has earned so far.
	local sessionPoints = 0
	local function refreshPoints()
		local saved = tonumber(player:GetAttribute("HP")) or 0
		points.Text = `{saved + sessionPoints} Huss`
	end
	player:GetAttributeChangedSignal("HP"):Connect(refreshPoints)
	refreshPoints()

	local function flashWord(text: string, color: Color3, seconds: number)
		hitWord.Text = text
		hitWord.TextColor3 = color
		hitWord.TextTransparency = 0
		hitStroke.Transparency = 0
		local fade = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(hitWord, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(hitStroke, fade, { Transparency = 1 }):Play()
	end

	local segment: { startTime: number, bpm: number, pattern: BeatClock.Pattern }? = nil
	local function refreshSegment()
		local startTime, bpm = player:GetAttribute("BeatStart"), player:GetAttribute("BeatBpm")
		local previous = segment
		segment = if typeof(startTime) == "number" and typeof(bpm) == "number"
			then {
				startTime = startTime,
				bpm = bpm,
				pattern = Night.pattern(player:GetAttribute("Station")),
			}
			else nil
		-- Tempo steps restart the beat half a second later, off the old grid: a deliberate
		-- distraction, so announce it.
		if previous and segment and segment.bpm > previous.bpm then
			flashWord("TEMPO UP!", ORANGE, 1.2)
			StationFx.play("tempo")
		end
		if not segment then
			sessionPoints = 0
			refreshPoints()
		end
	end
	player:GetAttributeChangedSignal("BeatStart"):Connect(refreshSegment)
	player:GetAttributeChangedSignal("BeatBpm"):Connect(refreshSegment)
	refreshSegment()

	-- The audible beat: a thud every beat, a clap on each skill note (up to a frame late).
	-- On top, a training groove on eighth notes that builds as the tempo steps up:
	-- step 2 adds hi-hats, step 3 the bassline, step 4 a stab on every bar.
	-- Bassline: 2 bars of eighths, semitones from C2 (nil = rest).
	local BASSLINE = { 0, nil, 0, 3, nil, 0, nil, 5, 7, nil, 7, 5, nil, 3, nil, nil }
	local clickStart, clickBeat, clapNote, eighth = 0, -1, -1, -1
	RunService.RenderStepped:Connect(function()
		local current = segment
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
		tapButton.Visible = current ~= nil
		if not current then
			return
		end
		local now = workspace:GetServerTimeNow()
		local interval = 60 / current.bpm
		local span = track.AbsoluteSize.X - RING_X - 100
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
		local first = BeatClock.nearest(
			current.startTime,
			current.bpm,
			now - interval * 0.25,
			current.pattern
		)
		first = math.max(0, first)
		for i, dot in dots do
			local beat = first + i - 1
			local ahead = BeatClock.noteTime(current.startTime, current.bpm, beat, current.pattern)
				- now
			local x = RING_X + ahead / (interval * BEATS_SHOWN) * span
			if x >= RING_X - 20 and x <= RING_X + span then
				local skill = BeatClock.isSkillBeat(beat, current.pattern)
				local size = if skill then 34 else 24
				dot.Size = UDim2.fromOffset(size, size)
				dot.BackgroundColor3 = if skill then ORANGE else CREAM
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
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- gameProcessed is true while typing in chat, so taps never fire from chat.
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			tap()
		end
	end)

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
			sessionPoints = total
			refreshPoints()
			combo.Text = if streak > 0 then `x{Score.multiplier(streak)} · {streak}` else ""
			flashWord(style.text, style.color, 0.5)
			RhythmClient.onResult(grade, skill)
		end
	)
end

-- Hook for the station's visuals and sounds; set by the station before start().
function RhythmClient.onResult(_grade: string, _skill: boolean) end

return RhythmClient
