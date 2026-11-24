--!strict
-- Server side of practice: owns each player's beat segment and judges every tap they send.
-- The client only draws the track and reports when the player tapped (server clock time).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local BeatClock = require(Shared.BeatClock)
local Score = require(Shared.Score)
local Analytics = require(script.Parent.Analytics)
local Data = require(script.Parent.Data)

type Session = {
	startTime: number,
	bpm: number,
	lastBeat: number,
	score: Score.State,
	tapped: { [number]: boolean }, -- tapped beats not yet settled by the sweep
	settled: number, -- beats up to here are tapped or counted as skipped
}

local Rhythm = {}

-- Taps reported more than this far from the server's own clock are dropped (lag or tampering).
Rhythm.maxClockSkew = 1
-- How far a reported tap time may differ from its arrival time (BeatClock.trustedTapTime).
Rhythm.tapTolerance = 0.1
-- A beat is settled (tapped or skipped) this long after the midpoint to the next beat, so a
-- late-arriving tap is never counted as both.
Rhythm.settleDelay = 0.35
Rhythm.maxCalibration = 0.3 -- seconds, either way

local sessions: { [Player]: Session } = {}

-- Called with every judged tap; the night cycle uses it to drain focus on misses.
function Rhythm.onGrade(_player: Player, _grade: BeatClock.Grade) end
-- Called once per beat the player didn't tap at all.
function Rhythm.onSkip(_player: Player) end

local remotes = Instance.new("Folder")
remotes.Name = "RhythmRemotes"
local tapEvent = Instance.new("RemoteEvent")
tapEvent.Name = "Tap" -- client -> server: tapTime (number, server clock)
tapEvent.Parent = remotes
local resultEvent = Instance.new("RemoteEvent")
resultEvent.Name = "Result" -- server -> client: beat, grade, earned, points, combo, skill
resultEvent.Parent = remotes
local calibrate = Instance.new("RemoteFunction")
calibrate.Name = "SetTapOffset" -- client -> server: seconds; saved, returns nil or a reason
calibrate.Parent = remotes
remotes.Parent = ReplicatedStorage

calibrate.OnServerInvoke = function(player: Player, offset: unknown): string?
	if typeof(offset) ~= "number" or offset ~= offset then
		return "Invalid"
	end
	return Data.update(player, function(data)
		data.tapOffset = math.clamp(offset, -Rhythm.maxCalibration, Rhythm.maxCalibration)
		return nil
	end)
end

function Rhythm.start(player: Player, bpm: number, leadIn: number?)
	local startTime = workspace:GetServerTimeNow() + (leadIn or 2)
	local previous = sessions[player]
	sessions[player] = {
		startTime = startTime,
		bpm = bpm,
		lastBeat = -1,
		tapped = {},
		settled = -1,
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
	if math.abs(now - tapTime) > Rhythm.maxClockSkew then
		return
	end
	local judged = BeatClock.trustedTapTime(
		tapTime,
		now,
		player:GetNetworkPing() / 2,
		tonumber(player:GetAttribute("TapOffset")) or 0,
		Rhythm.tapTolerance
	)
	if judged < session.startTime - 60 / session.bpm / 2 then
		return
	end
	local beat, offset = BeatClock.nearest(session.startTime, session.bpm, judged)
	-- One judged tap per beat: extra taps are ignored, which also caps tap spam at the BPM.
	-- Beats the sweep already settled as skipped can't be tapped any more.
	if beat <= session.lastBeat or beat <= session.settled then
		return
	end
	session.lastBeat = beat
	session.tapped[beat] = true
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
	Analytics.step(player, "FirstTap")
	if Score.multiplier(session.score.combo) >= 2 then
		Analytics.step(player, "Combo")
	end
end)

-- Settle past beats: untapped ones break the combo and cost focus (Rhythm.onSkip).
RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	for player, session in sessions do
		local interval = 60 / session.bpm
		local closed = math.floor((now - Rhythm.settleDelay - session.startTime) / interval - 0.5)
		for beat = session.settled + 1, closed do
			if session.tapped[beat] then
				session.tapped[beat] = nil
			else
				session.score = Score.apply(session.score, "Miss")
				Rhythm.onSkip(player)
			end
		end
		session.settled = math.max(session.settled, closed)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)

return Rhythm
