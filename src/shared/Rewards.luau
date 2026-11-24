--!strict
-- Reward rules (design doc: rewards for joining and coming back). Pure; the server applies them.
local Rewards = {}

Rewards.daily = table.freeze({ 50, 75, 100, 150, 200, 300, 500 }) -- HP for streak day 1-7
Rewards.dailyItem = "trail_streak" -- extra on day 7
Rewards.gifts = table.freeze({ -- minutes played this session -> HP
	{ minutes = 5, hp = 25 },
	{ minutes = 15, hp = 50 },
	{ minutes = 30, hp = 100 },
	{ minutes = 45, hp = 150 },
	{ minutes = 60, hp = 250 },
})
Rewards.groupHp = 250
Rewards.groupBonus = 0.1 -- +10% night HP while in the group

export type DailyState = { lastDay: number, streak: number }

function Rewards.today(unixTime: number): number
	return unixTime // 86400 -- UTC day number
end

-- Claims today's check-in. Returns the next state and the streak day paid (1-7), or nil when
-- already claimed today. Missing a day restarts at day 1; after day 7 the cycle restarts.
function Rewards.claimDaily(state: DailyState, today: number): (DailyState, number?)
	if state.lastDay == today then
		return state, nil
	end
	local day = if state.lastDay == today - 1 then state.streak % #Rewards.daily + 1 else 1
	return { lastDay = today, streak = day }, day
end

-- The day a claim today would pay (for the calendar), without claiming.
function Rewards.nextDailyDay(state: DailyState, today: number): number
	if state.lastDay == today then
		return state.streak
	end
	return if state.lastDay == today - 1 then state.streak % #Rewards.daily + 1 else 1
end

export type Code = { hp: number, expiresAt: number? }

-- Players type codes in any case, with or without spaces/dashes.
function Rewards.normalizeCode(input: string): string
	return (string.upper(input):gsub("[^%w]", ""))
end

-- Redeems a typed code against the server's code list. Returns the HP to grant and the key to
-- mark as used, or nil and a reason. Each code pays once per account; expired = unknown.
function Rewards.redeem(
	codes: { [string]: Code },
	used: { [string]: boolean },
	input: string,
	now: number
): (number?, string)
	local key = Rewards.normalizeCode(input)
	local code = codes[key]
	if not code or (code.expiresAt and now > code.expiresAt) then
		return nil, "Invalid"
	elseif used[key] then
		return nil, "AlreadyRedeemed"
	end
	return code.hp, key
end

return Rewards
