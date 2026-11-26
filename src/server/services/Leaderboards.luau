--!strict
-- Global leaderboards: one OrderedDataStore per category (Stats.categories). Players' values
-- are written at Dawn and when they leave; the top 100 of each category is read in turn (one
-- every 10 s, inside the GetSorted budget) and published to ReplicatedStorage.Leaderboards as
-- JSON for the floating boards and the Ranks panel. Fireworks go off for a new #1 on any board
-- and when a top-5 player joins.
-- ponytail: in Studio without API access the boards show this server's players instead.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Stats = require(ReplicatedStorage.Shared.Stats)
local Data = require(script.Parent.Data)

local TOP = 100
local READ_EVERY = 10 -- seconds between category reads

export type Entry = { id: number, name: string, value: number }

local Leaderboards = {}

local folder = Instance.new("Folder")
folder.Name = "Leaderboards"
folder.Parent = ReplicatedStorage
local fireworks = Instance.new("RemoteEvent")
fireworks.Name = "Fireworks"
fireworks.Parent = folder

-- Weekly categories get a new store each week (LB_w<week>_<key>); Most Huss stays all-time.
local stores: { [string]: OrderedDataStore } = {}
local function storeFor(category: any): OrderedDataStore
	local name = if category.weekly
		then `LB_w{Stats.week(os.time())}_{category.key}`
		else `LB_v1_{category.key}`
	if not stores[name] then
		stores[name] = DataStoreService:GetOrderedDataStore(name)
	end
	return stores[name]
end
local categoriesByKey = {}
local values: { [string]: StringValue } = {}
for _, category in Stats.categories do
	categoriesByKey[category.key] = category
	local value = Instance.new("StringValue")
	value.Name = category.key
	value.Value = "[]"
	value.Parent = folder
	values[category.key] = value
end

local names: { [number]: string } = {}
local function fillNames(ids: { number })
	local missing = {}
	for _, id in ids do
		if not names[id] then
			table.insert(missing, id)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, missing)
	if ok then
		for _, info in infos do
			names[info.Id] = info.DisplayName
		end
	end
end

-- The current value of every category for a player, from their save.
local function valuesFor(player: Player): { [string]: number }?
	local data = Data.get(player)
	if not data then
		return nil
	end
	local out = {}
	for _, category in Stats.categories do
		out[category.key] = Data.weekValue(data, category :: any)
	end
	return out
end

-- Last written value per player and category, so unchanged values aren't rewritten.
local written: { [Player]: { [string]: number } } = {}
function Leaderboards.write(player: Player)
	local current = valuesFor(player)
	if not current then
		return
	end
	local week = Stats.week(os.time())
	local last = written[player] or {}
	if last.week ~= week then
		last = { week = week } -- new week, new stores: write everything again
	end
	written[player] = last
	for key, value in current do
		if value > 0 and last[key] ~= value then
			last[key] = value
			task.spawn(function()
				pcall(function()
					storeFor(categoriesByKey[key]):SetAsync(
						tostring(player.UserId),
						math.floor(value)
					)
				end)
			end)
		end
	end
end

local function publish(key: string, entries: { Entry })
	local old = HttpService:JSONDecode(values[key].Value)
	values[key].Value = HttpService:JSONEncode(entries)
	-- A new #1 (not the first read) sets off fireworks.
	if old[1] and entries[1] and old[1].id ~= entries[1].id then
		fireworks:FireAllClients(key)
	end
end

-- Top entries from this server's players, for Studio without DataStore access.
local function localTop(key: string): { Entry }
	local entries = {}
	for _, player in Players:GetPlayers() do
		local current = valuesFor(player)
		if current then
			table.insert(
				entries,
				{ id = player.UserId, name = player.DisplayName, value = current[key] }
			)
		end
	end
	table.sort(entries, function(a, b)
		return a.value > b.value
	end)
	return entries
end

local function read(key: string)
	local ok, pages = pcall(function()
		return storeFor(categoriesByKey[key]):GetSortedAsync(false, TOP)
	end)
	if not ok then
		publish(key, localTop(key))
		return
	end
	local page = (pages :: DataStorePages):GetCurrentPage()
	local ids = {}
	for _, item in page do
		table.insert(ids, tonumber(item.key) :: number)
	end
	fillNames(ids)
	local entries = {}
	for _, item in page do
		local id = tonumber(item.key) :: number
		table.insert(entries, { id = id, name = names[id] or "Player", value = item.value })
	end
	publish(key, entries)
end

-- Whether a player is in the top 5 of any board right now.
local function isTopFive(player: Player): boolean
	for _, value in values do
		for place, entry in HttpService:JSONDecode(value.Value) do
			if place <= 5 and entry.id == player.UserId then
				return true
			end
		end
	end
	return false
end

function Leaderboards.dawnFireworks()
	fireworks:FireAllClients("Dawn")
end

-- The last trainer gave in mid-night: fireworks and the "everyone gave in" banner.
function Leaderboards.allInFireworks()
	fireworks:FireAllClients("AllIn")
end

function Leaderboards.start()
	Players.PlayerAdded:Connect(function(player)
		task.wait(5) -- let the boards' first reads land
		if player.Parent and isTopFive(player) then
			fireworks:FireAllClients("Join", player.DisplayName)
		end
	end)
	Data.beforeLeave = function(player)
		Leaderboards.write(player)
		written[player] = nil
	end
	task.spawn(function()
		while true do
			for _, category in Stats.categories do
				read(category.key)
				task.wait(READ_EVERY)
			end
		end
	end)
end

return Leaderboards
