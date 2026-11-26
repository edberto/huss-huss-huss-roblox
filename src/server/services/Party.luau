--!strict
-- Partier abilities: Invite, Speaker, Dance (design doc: partiers). A partier near a trainer
-- uses an ability on them; the server checks team, range, cooldown and the trainer's shield.
-- Party points go to the player's "PartyPoints" attribute and count at Dawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Night = require(ReplicatedStorage.Shared.Night)
local Data = require(script.Parent.Data)
local Focus = require(script.Parent.Focus)
local QuestService = require(script.Parent.QuestService)

local Party = {}

local remotes = ReplicatedStorage:WaitForChild("RhythmRemotes")
local abilityEvent = Instance.new("RemoteEvent")
abilityEvent.Name = "PartyAbility" -- client -> server: ability, target (Player)
abilityEvent.Parent = remotes
local effectEvent = Instance.new("RemoteEvent")
effectEvent.Name = "PartyEffect" -- server -> target client: ability, duration, from (Player)
effectEvent.Parent = remotes

local cooldowns: { [Player]: { [string]: number } } = {}
local shields: { [Player]: number } = {}
local lastTempter: { [Player]: Player } = {}

local function root(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function addPoints(player: Player, points: number)
	player:SetAttribute("PartyPoints", (tonumber(player:GetAttribute("PartyPoints")) or 0) + points)
end

-- A trainer (player or NPC) gave in right after this partier tempted them.
function Party.creditDragIn(tempter: Player)
	if tempter.Parent then
		addPoints(tempter, Night.giveInBonus)
		Data.recordStats(tempter, { draggedIn = 1 })
		QuestService.add(tempter, "dragIn", 1)
	end
end

-- Called by Round when a trainer gives in: whoever tempted them last gets the bonus.
function Party.creditGiveIn(trainer: Player)
	local tempter = lastTempter[trainer]
	lastTempter[trainer] = nil
	if tempter then
		Party.creditDragIn(tempter)
	end
end

-- For abilities aimed at NPC trainers (Npcs): the same team and cooldown rules as players.
-- Returns the ability's spec if it can be used now, and starts its cooldown.
function Party.spend(partier: Player, ability: unknown): { cooldown: number, points: number }?
	local spec = if typeof(ability) == "string" then (Night.abilities :: any)[ability] else nil
	if not spec or partier:GetAttribute("Team") ~= "Partier" then
		return nil
	end
	local now = os.clock()
	local mine = cooldowns[partier] or {}
	cooldowns[partier] = mine
	if now < (mine[ability :: string] or 0) then
		return nil
	end
	mine[ability :: string] = now + spec.cooldown
	return spec
end

function Party.addPoints(partier: Player, points: number)
	addPoints(partier, points)
end

Party.abilityEvent = abilityEvent

function Party.reset(player: Player)
	cooldowns[player] = nil
	shields[player] = nil
	lastTempter[player] = nil
	player:SetAttribute("PartyPoints", 0)
end

local function rootOfSource(source: Player | Model): BasePart?
	local character = if source:IsA("Player") then source.Character else source
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function sourceInRange(source: Player | Model, trainer: Player): boolean
	local a, b = rootOfSource(source), root(trainer)
	return a ~= nil and b ~= nil and (a.Position - b.Position).Magnitude <= Night.abilityRange
end

-- Applies an ability from a partier (player or NPC model) to a trainer. Checks the phase, range
-- and the trainer's shield; returns true when it landed. Cooldowns are the caller's job.
-- `onDrain` receives focus drained by a Dance (party points for player partiers).
function Party.apply(
	source: Player | Model,
	trainer: Player,
	ability: string,
	onDrain: ((number) -> ())?
): boolean
	local spec = Night.abilities[ability]
	if
		not spec
		or not Focus.isTrainer(trainer)
		or ReplicatedStorage:GetAttribute("Phase") ~= "Night"
	then
		return false
	end
	local now = os.clock()
	if now < (shields[trainer] or 0) or not sourceInRange(source, trainer) then
		return false
	end
	shields[trainer] = now + Night.shieldTime
	effectEvent:FireClient(trainer, ability, spec.duration)
	if ability == "Dance" then
		-- Drains while the partier stays close; stops if they walk away or the trainer gives in.
		task.spawn(function()
			local ends = now + spec.duration
			while
				os.clock() < ends
				and Focus.isTrainer(trainer)
				and sourceInRange(source, trainer)
			do
				local drained = Focus.drain(trainer, (spec.drainPerSecond or 0) * 0.5)
				if onDrain then
					onDrain(drained)
				end
				task.wait(0.5)
			end
		end)
	end
	return true
end

abilityEvent.OnServerEvent:Connect(function(partier: Player, ability: unknown, target: unknown)
	if typeof(ability) ~= "string" or typeof(target) ~= "Instance" or not target:IsA("Player") then
		return
	end
	local spec = Night.abilities[ability]
	if not spec or partier:GetAttribute("Team") ~= "Partier" then
		return
	end
	local now = os.clock()
	local mine = cooldowns[partier] or {}
	cooldowns[partier] = mine
	if now < (mine[ability] or 0) then
		return
	end
	local trainer = target :: Player
	if
		not Party.apply(partier, trainer, ability, function(drained)
			addPoints(partier, drained)
		end)
	then
		return
	end
	mine[ability] = now + spec.cooldown
	lastTempter[trainer] = partier
	if ability == "Dance" then
		QuestService.add(partier, "danceOff", 1)
	end
	addPoints(partier, spec.points)
end)

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
	shields[player] = nil
	lastTempter[player] = nil
	for trainer, tempter in lastTempter do
		if tempter == player then
			lastTempter[trainer] = nil
		end
	end
end)

return Party
