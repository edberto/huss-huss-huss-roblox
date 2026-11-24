--!strict
-- The night cycle: Dusk -> Party Night -> Dawn, forever (design doc: core loop).
-- Publishes ReplicatedStorage attributes "Phase", "PhaseEnds" (server time) and "NightClock",
-- and sends each night's ranking to every client at Dawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Night = require(ReplicatedStorage.Shared.Night)
local Focus = require(script.Parent.Focus)
local Homes = require(script.Parent.Homes)
local Party = require(script.Parent.Party)
local Rhythm = require(script.Parent.Rhythm)

export type Result = {
	userId: number,
	name: string,
	points: number,
	perfects: number,
	lasted: string?, -- clock time the player gave in; nil = locked in all night
	progress: number, -- how far through the night they lasted, 0-1
	party: number, -- party points earned as a partier
}

local Round = {}

local partyLawn =
	workspace:WaitForChild("Town"):WaitForChild("PartyHouse"):WaitForChild("Lawn") :: BasePart

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
		humanoid.WalkSpeed = if free then Night.partierSpeed else 0
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
		party = 0,
	}
	-- The give-in screen shows these straight away; the full ranking comes at Dawn.
	player:SetAttribute("NightPoints", results[player].points)
	player:SetAttribute("LastedUntil", lasted)
end

local function startTraining(player: Player)
	player:SetAttribute("Team", "Trainer")
	Focus.begin(player, os.clock())
	Rhythm.start(player, Night.bpm(progressNow()))
end

-- Focus hit 0: the player walks over to the party and plays as a partier until Dawn.
Focus.onBroken = function(player: Player)
	record(player, Night.clockText(progressNow()), progressNow())
	Party.creditGiveIn(player)
	player:SetAttribute("Team", "Partier")
	setMovement(player, true)
	if player.Character then
		player.Character:PivotTo(
			partyLawn.CFrame + Vector3.new(math.random(-6, 6), 3, math.random(-4, 4))
		)
	end
end
Rhythm.onGrade = Focus.onGrade

local function setLockedIn(player: Player, on: boolean)
	local character = player.Character
	local glow = character and character:FindFirstChild("LockedInGlow")
	if on and character and not glow then
		local highlight = Instance.new("Highlight")
		highlight.Name = "LockedInGlow"
		highlight.FillTransparency = 1
		highlight.OutlineColor = Color3.fromHex("3DFFB0")
		highlight.Parent = character
	elseif not on and glow then
		glow:Destroy()
	end
end

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
		Party.reset(player)
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
		-- The last few trainers glow for everyone (only meaningful with more players than that).
		local left = trainersLeft()
		for _, player in Players:GetPlayers() do
			setLockedIn(
				player,
				Focus.isTrainer(player)
					and left <= Night.lockedInCount
					and #Players:GetPlayers() > Night.lockedInCount
			)
		end
		-- Everyone gave in: the night ends early (design doc).
		if #Players:GetPlayers() > 0 and trainersLeft() == 0 then
			break
		end
		task.wait(1)
	end
	ReplicatedStorage:SetAttribute("NightClock", Night.clockText(1))
	for _, player in Players:GetPlayers() do
		setLockedIn(player, false)
		if Focus.isTrainer(player) then
			Focus.finish(player)
			record(player, nil, 1)
		end
	end
end

local function sortedResults(): { Result }
	local list = {}
	for player, result in results do
		result.party = math.floor(tonumber(player:GetAttribute("PartyPoints")) or 0)
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
		Homes.assign(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart")
			local partier = player:GetAttribute("Team") == "Partier"
			if not partier then
				Homes.placeOnSpot(player)
			end
			setMovement(player, partier)
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
