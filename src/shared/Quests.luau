--!strict
-- Daily quests (audit milestone M2): three a day, one from each group, rolled per player and
-- reset with the daily reward (UTC day). Pure, so the server applies it and tests check it.
-- Each quest counts one stat; Huss is paid the moment a quest completes, plus a bonus for all 3.
local Quests = {}

export type Quest = {
	id: string,
	group: string,
	text: string,
	stat: string,
	goal: number,
	reward: number,
}
export type State = {
	day: number,
	ids: { string },
	progress: { [string]: number }, -- by quest id
	done: { [string]: boolean },
	bonus: boolean, -- all-three bonus paid
}

Quests.bonus = 150

Quests.pool = table.freeze({
	{
		id = "perfects30",
		group = "practice",
		text = "Hit 30 Perfects",
		stat = "perfects",
		goal = 30,
		reward = 75,
	},
	{
		id = "combo4",
		group = "practice",
		text = "Reach a x4 combo",
		stat = "multiplier",
		goal = 4,
		reward = 75,
	},
	{
		id = "until3am",
		group = "practice",
		text = "Last until 3 AM",
		stat = "until3am",
		goal = 1,
		reward = 100,
	},
	{
		id = "dawn",
		group = "practice",
		text = "Make it to Dawn",
		stat = "dawn",
		goal = 1,
		reward = 100,
	},
	{
		id = "hardnight",
		group = "practice",
		text = "Practise at Gym or Burgers",
		stat = "hardnight",
		goal = 1,
		reward = 75,
	},
	{
		id = "party100",
		group = "partier",
		text = "Earn 100 party points",
		stat = "partyPoints",
		goal = 100,
		reward = 75,
	},
	{
		id = "dragin",
		group = "partier",
		text = "Drag in a trainer",
		stat = "dragIn",
		goal = 1,
		reward = 100,
	},
	{
		id = "danceoff3",
		group = "partier",
		text = "Use Dance-Off 3 times",
		stat = "danceOff",
		goal = 3,
		reward = 50,
	},
	{
		id = "friend",
		group = "social",
		text = "Play with a friend here",
		stat = "friendNight",
		goal = 1,
		reward = 100,
	},
	{
		id = "nights3",
		group = "social",
		text = "Play 3 nights",
		stat = "nights",
		goal = 3,
		reward = 50,
	},
	{
		id = "shop",
		group = "social",
		text = "Buy anything in the shop",
		stat = "shopBuy",
		goal = 1,
		reward = 50,
	},
} :: { Quest })
Quests.groups = table.freeze({ "practice", "partier", "social" })

-- Stats that keep the best value instead of adding up.
local BEST = { multiplier = true }

function Quests.get(id: string): Quest?
	for _, quest in Quests.pool do
		if quest.id == id then
			return quest
		end
	end
	return nil
end

-- A new day's state: one quest per group, chosen by a seed (the player's id) and the day.
function Quests.fresh(day: number, seed: number): State
	local rng = Random.new(day * 7919 + seed % 1000003)
	local ids = {}
	for _, group in Quests.groups do
		local choices = {}
		for _, quest in Quests.pool do
			if quest.group == group then
				table.insert(choices, quest.id)
			end
		end
		table.insert(ids, choices[rng:NextInteger(1, #choices)])
	end
	return { day = day, ids = ids, progress = {}, done = {}, bonus = false }
end

-- Counts `amount` of `stat` toward today's quests. Returns the Huss earned (quests just
-- completed, plus the bonus when the third one completes) and the ids completed.
function Quests.record(state: State, stat: string, amount: number): (number, { string })
	local earned, completed = 0, {}
	for _, id in state.ids do
		local quest = Quests.get(id)
		if quest and quest.stat == stat and not state.done[id] then
			local now = state.progress[id] or 0
			now = if BEST[stat] then math.max(now, amount) else now + amount
			state.progress[id] = math.min(now, quest.goal)
			if now >= quest.goal then
				state.done[id] = true
				earned += quest.reward
				table.insert(completed, id)
			end
		end
	end
	if not state.bonus and #completed > 0 then
		local all = true
		for _, id in state.ids do
			all = all and state.done[id] == true
		end
		if all then
			state.bonus = true
			earned += Quests.bonus
		end
	end
	return earned, completed
end

return Quests
