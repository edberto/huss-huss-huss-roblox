--!strict
-- Partier abilities: Invite, Speaker, Dance (design doc: partiers). A partier near a trainer
-- uses an ability on them; the server checks team, range, cooldown and the trainer's shield.
-- Party points go to the player's "PartyPoints" attribute and count at Dawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Night = require(ReplicatedStorage.Shared.Night)
local Focus = require(script.Parent.Focus)

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

local function inRange(a: Player, b: Player): boolean
	local ra, rb = root(a), root(b)
	return ra ~= nil and rb ~= nil and (ra.Position - rb.Position).Magnitude <= Night.abilityRange
end

local function addPoints(player: Player, points: number)
	player:SetAttribute("PartyPoints", (tonumber(player:GetAttribute("PartyPoints")) or 0) + points)
end

-- Called by Round when a trainer gives in: whoever tempted them last gets the bonus.
function Party.creditGiveIn(trainer: Player)
	local tempter = lastTempter[trainer]
	lastTempter[trainer] = nil
	if tempter and tempter.Parent then
		addPoints(tempter, Night.giveInBonus)
	end
end

function Party.reset(player: Player)
	cooldowns[player] = nil
	shields[player] = nil
	lastTempter[player] = nil
	player:SetAttribute("PartyPoints", 0)
end

abilityEvent.OnServerEvent:Connect(function(partier: Player, ability: unknown, target: unknown)
	if typeof(ability) ~= "string" or typeof(target) ~= "Instance" or not target:IsA("Player") then
		return
	end
	local spec = Night.abilities[ability]
	local trainer = target :: Player
	if not spec or partier:GetAttribute("Team") ~= "Partier" or not Focus.isTrainer(trainer) then
		return
	end
	if ReplicatedStorage:GetAttribute("Phase") ~= "Night" or not inRange(partier, trainer) then
		return
	end
	local now = os.clock()
	local mine = cooldowns[partier] or {}
	cooldowns[partier] = mine
	if now < (mine[ability] or 0) or now < (shields[trainer] or 0) then
		return
	end
	mine[ability] = now + spec.cooldown
	shields[trainer] = now + Night.shieldTime
	lastTempter[trainer] = partier
	addPoints(partier, spec.points)
	effectEvent:FireClient(trainer, ability, spec.duration, partier)

	if ability == "Dance" then
		-- Drains while the partier stays close; stops if they walk away or the trainer gives in.
		task.spawn(function()
			local ends = now + spec.duration
			while os.clock() < ends and Focus.isTrainer(trainer) and inRange(partier, trainer) do
				addPoints(partier, Focus.drain(trainer, (spec.drainPerSecond or 0) * 0.5))
				task.wait(0.5)
			end
		end)
	end
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
