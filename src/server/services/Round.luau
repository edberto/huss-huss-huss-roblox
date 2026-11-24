--!strict
-- The night cycle: Dusk -> Party Night -> Dawn, forever (design doc: core loop).
-- Publishes ReplicatedStorage attributes "Phase", "PhaseEnds" (server time) and "NightClock",
-- and sends each night's ranking to every client at Dawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Night = require(ReplicatedStorage.Shared.Night)
local Focus = require(script.Parent.Focus)
local Rhythm = require(script.Parent.Rhythm)

export type Result = {
	userId: number,
	name: string,
	points: number,
	perfects: number,
	lasted: string?, -- clock time the player gave in; nil = locked in all night
	progress: number, -- how far through the night they lasted, 0-1
}

local Round = {}

local PARTY_LAWN = CFrame.new(-31, 4, 8)

local resultsEvent = Instance.new("RemoteEvent")
resultsEvent.Name = "NightResults" -- server -> client: { Result }, sorted best first
resultsEvent.Parent = ReplicatedStorage:WaitForChild("RhythmRemotes")

local results: { [Player]: Result } = {}
local nightStart = 0

local function setPhase(phase: string, duration: number)
	ReplicatedStorage:SetAttribute("Phase", phase)
	ReplicatedStorage:SetAttribute("PhaseEnds", workspace:GetServerTimeNow() + duration)
end

local function progressNow(): number
	return math.clamp((os.clock() - nightStart) / Night.nightTime, 0, 1)
end

local function setMovement(player: Player, free: boolean)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.UseJumpPower = false
		humanoid.WalkSpeed = if free then 16 else 0
		humanoid.JumpHeight = if free then 7.2 else 0
	end
end

local function record(player: Player, lasted: string?, progress: number)
	local score = Rhythm.stop(player)
	results[player] = {
		userId = player.UserId,
		name = player.DisplayName,
		points = if score then score.points else 0,
		perfects = if score then score.perfects else 0,
		lasted = lasted,
		progress = progress,
	}
end

local function startTraining(player: Player)
	player:SetAttribute("Team", "Trainer")
	Focus.begin(player, os.clock())
	Rhythm.start(player, Night.bpm(progressNow()))
end

-- Focus hit 0: the player walks over to the party and plays as a partier until Dawn.
Focus.onBroken = function(player: Player)
	record(player, Night.clockText(progressNow()), progressNow())
	player:SetAttribute("Team", "Partier")
	setMovement(player, true)
	local root = player.Character
		and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.CFrame = PARTY_LAWN
	end
end
Rhythm.onGrade = Focus.onGrade

local function trainersLeft(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if Focus.isTrainer(player) then
			count += 1
		end
	end
	return count
end

local function runNight()
	table.clear(results)
	nightStart = os.clock()
	setPhase("Night", Night.nightTime)
	for _, player in Players:GetPlayers() do
		startTraining(player)
	end
	local bpm = Night.bpm(0)
	while os.clock() - nightStart < Night.nightTime do
		local progress = progressNow()
		ReplicatedStorage:SetAttribute("NightClock", Night.clockText(progress))
		if Night.bpm(progress) ~= bpm then
			bpm = Night.bpm(progress)
			for _, player in Players:GetPlayers() do
				if Rhythm.isActive(player) then
					Rhythm.start(player, bpm, 0.5)
				end
			end
		end
		Focus.tick(os.clock(), progress)
		-- Everyone gave in: the night ends early (design doc).
		if #Players:GetPlayers() > 0 and trainersLeft() == 0 then
			break
		end
		task.wait(1)
	end
	ReplicatedStorage:SetAttribute("NightClock", Night.clockText(1))
	for _, player in Players:GetPlayers() do
		if Focus.isTrainer(player) then
			Focus.finish(player)
			record(player, nil, 1)
		end
	end
end

local function sortedResults(): { Result }
	local list = {}
	for _, result in results do
		table.insert(list, result)
	end
	-- Whoever lasted longest first (locked in all night = 1); points break ties.
	table.sort(list, function(a, b)
		if a.progress ~= b.progress then
			return a.progress > b.progress
		end
		return a.points > b.points
	end)
	return list
end

function Round.run()
	-- A player who joins mid-night trains from their arrival; at other times they wait for Dusk.
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.defer(setMovement, player, player:GetAttribute("Team") == "Partier")
		end)
		if ReplicatedStorage:GetAttribute("Phase") == "Night" then
			startTraining(player)
		end
	end)

	while true do
		setPhase("Dusk", Night.duskTime)
		ReplicatedStorage:SetAttribute("NightClock", nil)
		for _, player in Players:GetPlayers() do
			player:SetAttribute("Team", "Trainer")
			player:SetAttribute("Focus", Night.focusStart)
			task.spawn(player.LoadCharacter, player) -- everyone back to the driveway
		end
		task.wait(Night.duskTime)

		runNight()

		setPhase("Dawn", Night.dawnTime)
		resultsEvent:FireAllClients(sortedResults())
		task.wait(Night.dawnTime)
	end
end

return Round
