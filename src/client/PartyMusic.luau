--!strict
-- The party next door as a DJ set: a shuffled playlist from the house lawn, each song
-- crossfading into the next over its last FADE seconds. Partiers only (trainers hear their
-- own training groove): full through the Night, fading out at Dawn, with a now-playing pop-up
-- for each new song. Licensed Creator Store tracks.
-- ponytail: each client shuffles on its own, so two partiers may hear different songs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.Ui)

local TRACKS = {
	{ id = 1839059453, title = "House Of Techno", credit = "APM Music" },
	{ id = 1839246734, title = "Euro Techno", credit = "APM Music" },
	{ id = 1840081722, title = "Dance Baby Dance", credit = "APM Music" },
	{ id = 125418384596720, title = "Techno Rave", credit = "via DistroKid" },
	{ id = 9042020196, title = "Powerful Engine", credit = "APM Music" },
	{ id = 118888070605046, title = "Miami Nights", credit = "via DistroKid" },
	{ id = 1839016134, title = "Trance Telecom", credit = "APM Music" },
	{ id = 1846760367, title = "Tektrance A", credit = "APM Music" },
	{ id = 1837674078, title = "Radiation", credit = "APM Music" },
}
type Track = typeof(TRACKS[1])

local FADE = 5
local VOLUME = 0.65
local PHASE_LEVEL = { Dusk = 0.35, Night = 1, Dawn = 0 }
local LOAD_TIMEOUT = 10 -- a song that won't load (moderation, outage) is skipped

local player = Players.LocalPlayer
local PartyMusic = {}

local function isPartier(): boolean
	return player:GetAttribute("Team") == "Partier"
end

-- Shuffle bag: every song once before any repeats, and never the same song twice in a row.
local bag: { Track } = {}
local last: Track? = nil
local function nextTrack(): Track
	if #bag == 0 then
		bag = table.clone(TRACKS)
		for i = #bag, 2, -1 do
			local j = math.random(i)
			bag[i], bag[j] = bag[j], bag[i]
		end
		if bag[#bag] == last then
			bag[1], bag[#bag] = bag[#bag], bag[1]
		end
	end
	last = table.remove(bag) :: Track
	return last :: Track
end

-- Now-playing pop-up: slides in from the right, holds, slides out.
local toast: Frame
local toastTitle: TextLabel
local toastCredit: TextLabel
local toastTween: Tween? = nil
local function buildToast()
	local gui = Ui.make("ScreenGui", {
		Name = "NowPlaying",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	toastTitle = Ui.label({
		Position = UDim2.fromScale(0.3, 0.32),
		Size = UDim2.fromScale(0.66, 0.36),
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	toastCredit = Ui.label({
		Position = UDim2.fromScale(0.3, 0.68),
		Size = UDim2.fromScale(0.66, 0.2),
		Text = "",
		TextColor3 = Color3.fromHex("C8B4E6"),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	toast = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromHex("281250"),
		Position = UDim2.new(1, 20, 0.97, 0),
		Size = UDim2.fromScale(0.24, 0.09),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(14),
		Ui.make("UIStroke", { Color = Ui.colors.pink, Thickness = 3 }),
		Ui.make("UIAspectRatioConstraint", { AspectRatio = 3.1 }),
		Ui.make("Frame", { -- the record
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromHex("140A1E"),
			Position = UDim2.fromScale(0.15, 0.5),
			Size = UDim2.fromScale(0.7, 0.7),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
		}, {
			Ui.corner(),
			Ui.make("UIStroke", { Color = Ui.colors.pink, Thickness = 2 }),
			Ui.make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromHex("50DCFF"),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.3, 0.3),
			}, { Ui.corner() }),
		}),
		Ui.label({
			Position = UDim2.fromScale(0.3, 0.1),
			Size = UDim2.fromScale(0.66, 0.2),
			Text = "♪ NOW PLAYING",
			TextColor3 = Color3.fromHex("50DCFF"),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		toastTitle,
		toastCredit,
	})
end

function PartyMusic.showNowPlaying(track: Track)
	toastTitle.Text = track.title
	toastCredit.Text = track.credit
	if toastTween then
		toastTween:Cancel()
	end
	toast.Visible = true
	toast.Position = UDim2.new(1, 20, 0.97, 0)
	local slideIn = TweenService:Create(
		toast,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.985, -toast.AbsoluteSize.X, 0.97, 0) }
	)
	toastTween = slideIn
	slideIn:Play()
	slideIn.Completed:Connect(function(state)
		if state ~= Enum.PlaybackState.Completed then
			return
		end
		task.wait(4)
		if toastTween ~= slideIn then
			return
		end
		local slideOut = TweenService:Create(
			toast,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(1, 20, 0.97, 0) }
		)
		toastTween = slideOut
		slideOut:Play()
	end)
end

-- Two decks on the lawn, like a DJ: one playing, one fading out.
type Deck = { sound: Sound, track: Track?, startedAt: number, fadingSince: number? }
local decks: { Deck } = {}
local live = 1
local level = 0
local current: Track? = nil

local function play(deck: Deck)
	local track = nextTrack()
	deck.track = track
	deck.sound.SoundId = "rbxassetid://" .. track.id
	deck.sound.TimePosition = 0
	deck.sound:Play()
	deck.startedAt = os.clock()
	deck.fadingSince = nil
	current = track
	if isPartier() then
		PartyMusic.showNowPlaying(track)
	end
end

-- Start the next song on the other deck and fade this one out over FADE seconds.
local function crossfade()
	decks[live].fadingSince = os.clock()
	live = live % 2 + 1
	play(decks[live])
end

local function step(dt: number)
	local phase = ReplicatedStorage:GetAttribute("Phase")
	local target = PHASE_LEVEL[phase :: any] or 1
	level += (target - level) * math.min(1, dt * 0.6) -- eases over a few seconds
	local gain = if isPartier() then VOLUME * level else 0

	local deck = decks[live]
	local sound = deck.sound
	local age = os.clock() - deck.startedAt
	local stuck = not sound.IsLoaded and age > LOAD_TIMEOUT
	local ending = sound.IsLoaded
		and sound.TimeLength > FADE * 2
		and sound.TimePosition >= sound.TimeLength - FADE
	if stuck or ending then
		crossfade()
	end

	for _, d in decks do
		local weight
		if d.fadingSince then
			weight = 1 - math.clamp((os.clock() - d.fadingSince) / FADE, 0, 1)
			if weight <= 0 and d.sound.IsPlaying then
				d.sound:Stop()
			end
		elseif d == decks[live] then
			weight = math.clamp((os.clock() - d.startedAt) / FADE, 0, 1)
		else
			weight = 0
		end
		d.sound.Volume = gain * weight
	end
end

function PartyMusic.start()
	buildToast()
	local lawn = workspace:WaitForChild("Town"):WaitForChild("PartyHouse"):WaitForChild("Lawn")
	for i = 1, 2 do
		local sound = Ui.make("Sound", {
			Name = "PartyDeck" .. i,
			Volume = 0,
			RollOffMode = Enum.RollOffMode.InverseTapered,
			RollOffMinDistance = 25,
			RollOffMaxDistance = 260,
			Parent = lawn,
		}) :: Sound
		decks[i] = { sound = sound, track = nil, startedAt = 0, fadingSince = nil }
	end
	play(decks[live])
	-- Becoming a partier mid-song: show what's on.
	player:GetAttributeChangedSignal("Team"):Connect(function()
		if isPartier() and current then
			PartyMusic.showNowPlaying(current)
		end
	end)
	RunService.Heartbeat:Connect(step)
end

-- The give-in cutscene swells the party in at once.
function PartyMusic.swell()
	level = math.max(level, 1)
end

return PartyMusic
