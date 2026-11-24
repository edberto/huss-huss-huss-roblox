--!strict
-- Saved player data through ProfileStore (session-locked, autosaving). Mirrors what the client
-- shows into attributes: "HP" (Huss Points), "Lv_<Station>" per station, "Rank".
-- Also fills the Roblox player list (leaderstats) with HP and Rank.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Night = require(ReplicatedStorage.Shared.Night)
local Progress = require(ReplicatedStorage.Shared.Progress)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

export type Data = {
	hp: number,
	stationXp: { [string]: number },
	nights: number,
}

local TEMPLATE: Data = {
	hp = 0,
	stationXp = { Basketball = 0, Gym = 0, Burgers = 0 },
	nights = 0,
}

local store = ProfileStore.New("PlayerData_v1", TEMPLATE)
local profiles: { [Player]: any } = {}

local Data = {}

local function totalLevels(data: Data): number
	local total = 0
	for _, station in Night.stations do
		total += Progress.level(data.stationXp[station] or 0)
	end
	return total
end

-- Push saved values to attributes and the player list.
local function publish(player: Player, data: Data)
	player:SetAttribute("HP", data.hp)
	for _, station in Night.stations do
		player:SetAttribute(`Lv_{station}`, Progress.level(data.stationXp[station] or 0))
	end
	local rank = Progress.rank(totalLevels(data))
	player:SetAttribute("Rank", rank)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		(stats:FindFirstChild("HP") :: IntValue).Value = data.hp;
		(stats:FindFirstChild("Rank") :: StringValue).Value = rank
	end
end

function Data.get(player: Player): Data?
	local profile = profiles[player]
	return profile and profile.Data
end

-- Credit one night: Huss Points plus XP for the station the player practised.
-- Returns the station level before and after, for the Dawn card.
function Data.creditNight(player: Player, hp: number, station: string, xp: number): (number, number)
	local data = Data.get(player)
	if not data then
		return 1, 1
	end
	local before = Progress.level(data.stationXp[station] or 0)
	data.hp += math.max(0, math.floor(hp))
	data.stationXp[station] = (data.stationXp[station] or 0) + math.max(0, math.floor(xp))
	data.nights += 1
	publish(player, data)
	return before, Progress.level(data.stationXp[station])
end

local function onPlayerAdded(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	Instance.new("IntValue", stats).Name = "HP"
	Instance.new("StringValue", stats).Name = "Rank"
	stats.Parent = player

	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Couldn't load your save. Please rejoin.")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your save was opened on another server. Please rejoin.")
	end)
	if player.Parent == Players then
		profiles[player] = profile
		publish(player, profile.Data)
	else
		profile:EndSession()
	end
end

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	local profile = profiles[player]
	if profile then
		profile:EndSession()
	end
end)

return Data
