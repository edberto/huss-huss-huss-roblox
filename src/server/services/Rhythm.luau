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

-- Called with every judged tap; the night cycle uses it to drain focus on misses.
function Rhythm.onGrade(_player: Player, _grade: BeatClock.Grade) end

local remotes = Instance.new("Folder")
remotes.Name = "RhythmRemotes"
local tapEvent = Instance.new("RemoteEvent")
tapEvent.Name = "Tap" -- client -> server: tapTime (number, server clock)
tapEvent.Parent = remotes
local resultEvent = Instance.new("RemoteEvent")
resultEvent.Name = "Result" -- server -> client: beat, grade, earned, points, combo, skill
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
	-- The client reads the segment from attributes, so it can't miss it while loading.
	player:SetAttribute("BeatBpm", bpm)
	player:SetAttribute("BeatStart", startTime)
end

function Rhythm.isActive(player: Player): boolean
	return sessions[player] ~= nil
end

function Rhythm.stop(player: Player): Score.State?
	local session = sessions[player]
	sessions[player] = nil
	player:SetAttribute("BeatStart", nil)
	player:SetAttribute("BeatBpm", nil)
	if session then
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
	-- A skipped beat breaks the combo (no focus loss: idle players lose focus to temptations).
	if session.lastBeat >= 0 and beat > session.lastBeat + 1 then
		session.score = Score.apply(session.score, "Miss")
	end
	session.lastBeat = beat
	local grade = BeatClock.grade(offset)
	local skill = BeatClock.isSkillBeat(beat)
	local earned
	session.score, earned = Score.apply(session.score, grade, skill)
	resultEvent:FireClient(
		player,
		beat,
		grade,
		earned,
		session.score.points,
		session.score.combo,
		skill
	)
	Rhythm.onGrade(player, grade)
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)

return Rhythm
