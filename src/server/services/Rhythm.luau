--!strict
-- Server side of practice: owns each player's beat segment and judges every tap they send.
-- The client only draws the track and reports when the player tapped (server clock time).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local BeatClock = require(Shared.BeatClock)
local Score = require(Shared.Score)

type Session = {
	startTime: number,
	bpm: number,
	lastBeat: number,
	score: Score.State,
}

local Rhythm = {}

-- Taps reported more than this far from the server's own clock are dropped (lag or tampering).
Rhythm.maxClockSkew = 1

local sessions: { [Player]: Session } = {}

local remotes = Instance.new("Folder")
remotes.Name = "RhythmRemotes"
local tapEvent = Instance.new("RemoteEvent")
tapEvent.Name = "Tap" -- client -> server: tapTime (number, server clock)
tapEvent.Parent = remotes
local segmentEvent = Instance.new("RemoteEvent")
segmentEvent.Name = "Segment" -- server -> client: startTime, bpm (nil = stopped)
segmentEvent.Parent = remotes
local resultEvent = Instance.new("RemoteEvent")
resultEvent.Name = "Result" -- server -> client: beat, grade, earned, points, combo
resultEvent.Parent = remotes
remotes.Parent = ReplicatedStorage

function Rhythm.start(player: Player, bpm: number, leadIn: number?)
	local startTime = workspace:GetServerTimeNow() + (leadIn or 2)
	local previous = sessions[player]
	sessions[player] = {
		startTime = startTime,
		bpm = bpm,
		lastBeat = -1,
		-- A tempo change starts a new segment but keeps the score and combo.
		score = if previous then previous.score else Score.new(),
	}
	segmentEvent:FireClient(player, startTime, bpm)
end

function Rhythm.stop(player: Player): Score.State?
	local session = sessions[player]
	sessions[player] = nil
	if session then
		segmentEvent:FireClient(player, nil, nil)
		return session.score
	end
	return nil
end

tapEvent.OnServerEvent:Connect(function(player: Player, tapTime: unknown)
	local session = sessions[player]
	if not session or typeof(tapTime) ~= "number" or tapTime ~= tapTime then
		return
	end
	local now = workspace:GetServerTimeNow()
	if math.abs(now - tapTime) > Rhythm.maxClockSkew or tapTime < session.startTime then
		return
	end
	local beat, offset = BeatClock.nearest(session.startTime, session.bpm, tapTime)
	-- One judged tap per beat: extra taps are ignored, which also caps tap spam at the BPM.
	if beat <= session.lastBeat then
		return
	end
	session.lastBeat = beat
	local grade = BeatClock.grade(offset)
	local earned
	session.score, earned = Score.apply(session.score, grade)
	resultEvent:FireClient(player, beat, grade, earned, session.score.points, session.score.combo)
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)

return Rhythm
