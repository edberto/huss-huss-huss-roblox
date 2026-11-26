--!strict
-- The night cycle: Dusk -> Party Night -> Dawn, forever (design doc: core loop).
-- Publishes ReplicatedStorage attributes "Phase", "PhaseEnds" (server time) and "NightClock",
-- and sends each night's ranking to every client at Dawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Night = require(ReplicatedStorage.Shared.Night)
local Analytics = require(script.Parent.Analytics)
local Decor = require(script.Parent.Decor)
local Focus = require(script.Parent.Focus)
local Homes = require(script.Parent.Homes)
local Party = require(script.Parent.Party)
local Data = require(script.Parent.Data)
local Leaderboards = require(script.Parent.Leaderboards)
local Npcs = require(script.Parent.Npcs)
local Progress = require(ReplicatedStorage.Shared.Progress)
local Rhythm = require(script.Parent.Rhythm)

export type Result = {
	userId: number,
	name: string,
	points: number,
	perfects: number,
	lasted: string?, -- clock time the player gave in; nil = locked in all night
	progress: number, -- how far through the night they lasted, 0-1
	party: number, -- party points earned as a partier
	station: string,
	earned: number?, -- Huss Points credited at Dawn
	levelBefore: number?,
	levelAfter: number?,
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

-- Free = walk around (partier speed at Night, normal speed at Dusk and Dawn); not free = held on
-- the practice spot.
local function setMovement(player: Player, free: boolean)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local night = ReplicatedStorage:GetAttribute("Phase") == "Night"
		humanoid.UseJumpPower = false
		humanoid.WalkSpeed = if not free then 0 elseif night then Night.partierSpeed else 16
		humanoid.JumpHeight = if free then 7.2 else 0
	end
end

local function record(player: Player, lasted: string?, progress: number)
	local score = Rhythm.stop(player)
	if score then
		Data.recordStats(player, { combo = score.best })
	end
	results[player] = {
		userId = player.UserId,
		name = player.DisplayName,
		points = if score then score.points else 0,
		perfects = if score then score.perfects else 0,
		lasted = lasted,
		progress = progress,
		party = 0,
		station = tostring(player:GetAttribute("Station") or "Basketball"),
	}
	-- The give-in screen shows these straight away; the full ranking comes at Dawn.
	player:SetAttribute("NightPoints", results[player].points)
	player:SetAttribute("LastedUntil", lasted)
end

local function startTraining(player: Player)
	Analytics.step(player, "Training")
	player:SetAttribute("Team", "Trainer")
	-- Roaming since Dusk: now to the picked station's spot, held there.
	Homes.placeOnSpot(player)
	setMovement(player, false)
	Focus.begin(player, os.clock())
	Rhythm.start(player, Night.bpm(progressNow()))
end

-- Focus hit 0: the player walks over to the party and plays as a partier until Dawn.
Focus.onBroken = function(player: Player)
	record(player, Night.clockText(progressNow()), progressNow())
	Analytics.step(player, "NightOver")
	Analytics.event(player, "GiveInProgress", math.floor(progressNow() * 100)) -- % of the night
	Party.creditGiveIn(player)
	player:SetAttribute("Team", "Partier")
	setMovement(player, true)
	if player.Character then
		player.Character:PivotTo(
			partyLawn.CFrame + Vector3.new(math.random(-6, 6), 3, math.random(-4, 4))
		)
		Decor.dressPartier(player.Character)
	end
end
Rhythm.onGrade = Focus.onGrade
Rhythm.onSkip = Focus.onSkip

-- "Skip practice, just party": free with Party Animal, otherwise one Party Ticket.
local function spendSkip(player: Player): boolean
	if player:GetAttribute("PartyAnimal") == true then
		return true
	end
	return Data.update(player, function(data)
		if data.partyTickets <= 0 then
			return "NoTickets"
		end
		data.partyTickets -= 1
		return nil
	end) == nil
end

-- Straight to the party lawn as a partier for the whole night.
local function joinPartyNow(player: Player)
	Analytics.event(player, "SkippedToParty", 1)
	record(player, "Partied all night", 0)
	player:SetAttribute("Team", "Partier")
	setMovement(player, true)
	if player.Character then
		player.Character:PivotTo(
			partyLawn.CFrame + Vector3.new(math.random(-6, 6), 3, math.random(-4, 4))
		)
		Decor.dressPartier(player.Character)
	end
end

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
		player:SetAttribute("UsedSecondWind", false)
		if player:GetAttribute("PartyTonight") == true and spendSkip(player) then
			joinPartyNow(player)
		else
			startTraining(player)
		end
	end
	Npcs.beginNight()
	local bpm = Night.bpm(0)
	local hadTrainers, allIn = false, false
	while os.clock() - nightStart < Night.nightTime do
		local progress = progressNow()
		ReplicatedStorage:SetAttribute("NightClock", Night.clockText(progress))
		if Night.bpm(progress) ~= bpm then
			bpm = Night.bpm(progress)
			for _, player in Players:GetPlayers() do
				if Rhythm.isActive(player) then
					Rhythm.changeTempo(player, bpm)
				end
			end
		end
		Focus.tick(os.clock(), progress)
		Npcs.tick(progress, Night.clockText(progress), bpm)
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
		-- No early end when everyone gives in: partiers (and Party Animal skippers) get the
		-- whole night to party. The moment the last trainer falls, the street celebrates once.
		if left > 0 then
			hadTrainers = true
		elseif hadTrainers and not allIn and progressNow() < 0.95 then
			allIn = true
			Leaderboards.allInFireworks()
		end
		task.wait(1)
	end
	ReplicatedStorage:SetAttribute("NightClock", Night.clockText(1))
	local ended = math.min(1, progressNow())
	Npcs.finish(ended, Night.clockText(ended))
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
	for _, row in Npcs.results() do
		table.insert(list, row)
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
			-- Everyone starts at home; only a trainer spawning mid-Night is held on the spot.
			local partier = player:GetAttribute("Team") == "Partier"
			if not partier then
				Homes.placeOnSpot(player)
			end
			setMovement(player, partier or ReplicatedStorage:GetAttribute("Phase") ~= "Night")
		end)
		if ReplicatedStorage:GetAttribute("Phase") == "Night" then
			startTraining(player)
		end
	end)

	while true do
		setPhase("Dusk", Night.duskTime)
		ReplicatedStorage:SetAttribute("NightClock", nil)
		Npcs.clear()
		for _, player in Players:GetPlayers() do
			player:SetAttribute("Team", "Trainer")
			player:SetAttribute("PartyTonight", false) -- choose again each Dusk
			player:SetAttribute("Focus", Night.focusStart)
			task.spawn(player.LoadCharacter, player) -- everyone back to the driveway
		end
		task.wait(Night.duskTime)

		runNight()

		setPhase("Dawn", Night.dawnTime)
		for _, player in Players:GetPlayers() do
			setMovement(player, true) -- free to roam until the next Dusk
		end
		local ranking = sortedResults()
		-- Pay everyone: points, party points and placement bonuses become saved Huss Points,
		-- and the night's points become XP for the station they practised.
		for place, result in ranking do
			local player = Players:GetPlayerByUserId(result.userId)
			if player then
				-- Second Wind users can't win the last-trainer-standing bonus (design doc).
				local rewardPlace = if player:GetAttribute("UsedSecondWind") == true
					then math.max(place, 2)
					else place
				local info = Night.stationInfo[result.station] or Night.stationInfo.Basketball
				local hp = Progress.nightReward(
					Progress.stationPoints(result.points, info.bonus),
					result.party,
					rewardPlace,
					#Players:GetPlayers(), -- placement bonuses count real players only
					result.lasted == nil
				)
				result.earned = hp
				Analytics.step(player, "NightOver") -- no-op if they already gave in
				Analytics.step(player, "Dawn")
				Analytics.event(player, "DawnPlace", place)
				Data.recordStats(player, {
					dawnAt = if result.lasted == nil then result.station else nil,
					partyPoints = result.party,
				})
				Data.bankPlaytime(player)
				result.levelBefore, result.levelAfter, result.earned, result.boosted =
					Data.creditNight(player, hp, result.station, result.points)
			end
		end
		resultsEvent:FireAllClients(ranking)
		for _, player in Players:GetPlayers() do
			Leaderboards.write(player)
		end
		Leaderboards.dawnFireworks()
		task.wait(Night.dawnTime)
	end
end

return Round
