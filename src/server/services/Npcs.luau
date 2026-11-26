--!strict
-- NPC fill for small servers: NPC trainers practise in free homes so the street feels alive.
-- Some give in during the night, walk to the party and tempt real trainers with the same
-- abilities partiers use. NPCs show in the Dawn ranking but never count for placement bonuses.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Night = require(ReplicatedStorage.Shared.Night)
local Focus = require(script.Parent.Focus)
local Homes = require(script.Parent.Homes)
local Decor = require(script.Parent.Decor)
local Looks = require(script.Parent.Looks)
local Party = require(script.Parent.Party)

local FILL_TO = 6 -- real players + NPC trainers per night
local NAMES = {
	"Rafi",
	"Mia",
	"Aiko",
	"Omar",
	"Sari",
	"Mateo",
	"Priya",
	"Kwame",
	"Lucia",
	"Bayu",
	"Hana",
	"Joel",
	"Zoe",
	"Dimas",
}
local TEMPT_EVERY = 12 -- seconds between an NPC partier's tries

type Npc = {
	name: string,
	model: Model,
	humanoid: Humanoid,
	giveInAt: number, -- night progress when they give in (> 1 = locked in all night)
	partier: boolean,
	lasted: string?,
	progress: number,
	points: number,
}

local Npcs = {}

local npcs: { Npc } = {}
local folder = Instance.new("Folder")
folder.Name = "Npcs"
folder.Parent = workspace

local function partyLawn(): BasePart
	return workspace
			:WaitForChild("Town")
			:WaitForChild("PartyHouse")
			:WaitForChild("Lawn") :: BasePart
end

local nameOffset = 0 -- new random start each night, so names vary but never repeat in a server

local function spawnNpc(home: Model, index: number): Npc?
	local description = Looks.random()
	local ok, model = pcall(
		Players.CreateHumanoidModelFromDescription,
		Players,
		description,
		Enum.HumanoidRigType.R15
	)
	if not ok or not model then
		return nil
	end
	local name = NAMES[(index + nameOffset) % #NAMES + 1] -- distinct within a night
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = name
	humanoid.WalkSpeed = 0
	local spot = home:FindFirstChild("PracticeSpot") :: BasePart
	model:PivotTo(spot.CFrame + Vector3.new(0, 2, 0))
	model.Parent = folder
	return {
		name = name,
		model = model,
		humanoid = humanoid,
		giveInAt = 0.15 + math.random() * 1.1,
		partier = false,
		progress = 1,
		points = 0,
	}
end

local function nearestTrainer(npc: Npc): Player?
	local best, bestDistance = nil, math.huge
	local root = npc.model:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, player in Players:GetPlayers() do
		local theirs = player.Character
			and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and theirs and Focus.isTrainer(player) then
			local distance = (theirs.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	return best
end

-- An NPC partier walks up to the nearest real trainer and uses a random ability.
local function tempt(npc: Npc)
	local trainer = nearestTrainer(npc)
	local theirs = trainer
		and trainer.Character
		and trainer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not trainer or not theirs then
		return
	end
	npc.humanoid:MoveTo(theirs.Position + Vector3.new(math.random(-4, 4), 0, -5))
	task.delay(6, function()
		local abilities = { "Invite", "Speaker", "Dance" }
		Party.apply(npc.model, trainer, abilities[math.random(1, #abilities)])
	end)
end

-- Fill free homes at the start of a night.
function Npcs.beginNight()
	Npcs.clear()
	nameOffset = math.random(0, #NAMES - 1)
	local count = math.max(0, FILL_TO - #Players:GetPlayers())
	for i = 1, count do
		local home = Homes.claimForNpc()
		local npc = home and spawnNpc(home, i)
		if npc then
			(home :: Model):SetAttribute("Owner", npc.name)
			table.insert(npcs, npc)
		end
	end
end

-- Called about once a second during the night.
function Npcs.tick(progress: number, clockText: string, bpm: number)
	for _, npc in npcs do
		if not npc.partier then
			-- About 2-4 points a beat while they practise.
			npc.points += math.random(2, 4) * bpm / 60
			if progress >= npc.giveInAt then
				npc.partier = true
				Decor.dressPartier(npc.model)
				npc.lasted = clockText
				npc.progress = progress
				npc.humanoid.WalkSpeed = Night.partierSpeed
				npc.humanoid:MoveTo(
					partyLawn().Position + Vector3.new(math.random(-6, 6), 0, math.random(-4, 4))
				)
				npc.model:SetAttribute("NextTempt", os.clock() + TEMPT_EVERY)
			end
		elseif os.clock() >= (npc.model:GetAttribute("NextTempt") :: number? or 0) then
			npc.model:SetAttribute("NextTempt", os.clock() + TEMPT_EVERY)
			tempt(npc)
		end
	end
end

-- Night over: NPCs still training lasted until now (not 6 AM if the night ended early).
function Npcs.finish(progress: number, clockText: string)
	for _, npc in npcs do
		if not npc.partier then
			npc.progress = progress
			npc.lasted = clockText
		end
	end
end

-- Ranking rows for the Dawn card (negative ids so they never match a real player).
function Npcs.results(): { any }
	local rows = {}
	for i, npc in npcs do
		table.insert(rows, {
			userId = -i,
			name = npc.name,
			points = math.floor(npc.points),
			perfects = 0,
			lasted = npc.lasted,
			progress = npc.progress,
			party = 0,
			station = "Basketball",
			npc = true,
		})
	end
	return rows
end

function Npcs.clear()
	for _, npc in npcs do
		npc.model:Destroy()
	end
	table.clear(npcs)
	Homes.releaseNpcHomes()
end

return Npcs
