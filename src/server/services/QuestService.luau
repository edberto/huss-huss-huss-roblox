--!strict
-- Daily quests on the server (rules in Shared/Quests). Other services report stats with
-- QuestService.add; a completed quest pays its Huss at once and tells the client (QuestDone).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Night = require(ReplicatedStorage.Shared.Night)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Data = require(script.Parent.Data)

local QuestService = {}

local doneEvent = Instance.new("RemoteEvent")
doneEvent.Name = "QuestDone" -- server -> client: quest text, Huss earned (bonus included)
doneEvent.Parent = ReplicatedStorage -- not RhythmRemotes: Rhythm requires this module first

-- 3 AM as night progress (the night clock runs 9 PM to 6 AM).
local THREE_AM = (27 * 60 - Night.clockStartMinutes)
	/ (Night.clockEndMinutes - Night.clockStartMinutes)

-- Today's quests, rolled fresh when the UTC day has changed. Returns true if it rolled.
function QuestService.ensureToday(player: Player, data: any): boolean
	local today = Rewards.today(os.time())
	if data.quests.day ~= today then
		data.quests = Quests.fresh(today, player.UserId)
		return true
	end
	return false
end

-- Re-rolls stale quests (called at Dusk, so the card shows the new day's quests).
function QuestService.refresh(player: Player)
	Data.update(player, function(data)
		return if QuestService.ensureToday(player, data) then nil else "Unchanged"
	end)
end

function QuestService.add(player: Player, stat: string, amount: number)
	if amount <= 0 then
		return
	end
	-- Cheap check first: most calls (every Perfect tap) match no open quest.
	local data = Data.get(player) :: any
	if not data then
		return
	end
	local open = Rewards.today(os.time()) ~= data.quests.day
	for _, id in data.quests.ids do
		local quest = Quests.get(id)
		open = open or (quest ~= nil and quest.stat == stat and not data.quests.done[id])
	end
	if not open then
		return
	end
	local finished: { string }, paid = {}, 0
	Data.update(player, function(fresh: any)
		QuestService.ensureToday(player, fresh)
		local earned, completed = Quests.record(fresh.quests, stat, amount)
		fresh.hp += earned
		finished, paid = completed, earned
		return nil
	end, "Gameplay", "Quest")
	for _, id in finished do
		local quest = Quests.get(id) :: Quests.Quest
		paid -= quest.reward
		doneEvent:FireClient(player, quest.text, quest.reward)
	end
	if paid > 0 then -- what's left is the all-three bonus
		doneEvent:FireClient(player, "All 3 quests!", paid)
	end
end

-- End of a night for one player (Round at Dawn): nights, dawn, 3 AM, station, friends, party.
function QuestService.night(player: Player, result: any)
	QuestService.add(player, "nights", 1)
	if result.points > 0 then
		if result.progress >= THREE_AM then
			QuestService.add(player, "until3am", 1)
		end
		if result.lasted == nil then
			QuestService.add(player, "dawn", 1)
		end
		if result.station == "Gym" or result.station == "Burgers" then
			QuestService.add(player, "hardnight", 1)
		end
	end
	if (tonumber(player:GetAttribute("FriendsHere")) or 0) > 0 then
		QuestService.add(player, "friendNight", 1)
	end
	QuestService.add(player, "partyPoints", result.party or 0)
end

Players.PlayerAdded:Connect(function(player)
	-- Wait for the save, then make sure today's quests exist.
	for _ = 1, 30 do
		if Data.get(player) then
			QuestService.refresh(player)
			return
		end
		task.wait(1)
	end
end)

return QuestService
