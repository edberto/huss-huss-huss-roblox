--!strict
-- Friend Invite Rewards (Roblox referral links; Creator Hub > Engagement > Referral Rewards shows
-- the banner). A player new to the game who arrives through someone's referral link gets
-- 250 Huss; the inviter gets 250 Huss too, for up to 10 new players. The inviter may be offline
-- or on another server, so their reward waits in a DataStore and is paid when they're next here.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Data = require(script.Parent.Data)

local Referrals = {}

Referrals.reward = 250
Referrals.maxPerInviter = 10

local pending = DataStoreService:GetDataStore("ReferralRewards_v1") -- key: inviter id -> count owed

-- The inviter's owed rewards: moved into their save and paid (capped at maxPerInviter).
function Referrals.collect(player: Player)
	local data = Data.get(player) :: any
	if not data or data.referralsPaid >= Referrals.maxPerInviter then
		return
	end
	local owed = 0
	local ok = pcall(function()
		pending:UpdateAsync(tostring(player.UserId), function(count: number?)
			owed = count or 0
			return if owed > 0 then 0 else nil -- nil = leave unchanged
		end)
	end)
	if not ok or owed <= 0 then
		return
	end
	local paid = math.min(owed, Referrals.maxPerInviter - data.referralsPaid)
	Data.update(player, function(fresh: any)
		fresh.referralsPaid += paid
		fresh.hp += paid * Referrals.reward
		return nil
	end, "TimedReward", "ReferralInviter")
	Data.save(player)
end

local function joined(player: Player)
	-- Wait for the save.
	for _ = 1, 30 do
		if Data.get(player) or not player.Parent then
			break
		end
		task.wait(1)
	end
	local data = Data.get(player) :: any
	if not data then
		return
	end
	local ok, joinData = pcall(player.GetJoinData, player)
	local inviter = if ok then tonumber(joinData.ReferredByPlayerId) or 0 else 0
	-- Only players new to the game count, once per account, and never yourself.
	if inviter ~= 0 and inviter ~= player.UserId and data.referredBy == 0 and data.nights == 0 then
		Data.update(player, function(fresh: any)
			fresh.referredBy = inviter
			fresh.hp += Referrals.reward
			return nil
		end, "TimedReward", "ReferralInvitee")
		pcall(function()
			pending:UpdateAsync(tostring(inviter), function(count: number?)
				return (count or 0) + 1
			end)
		end)
		local here = Players:GetPlayerByUserId(inviter)
		if here then
			Referrals.collect(here)
		end
	end
	Referrals.collect(player)
end

Players.PlayerAdded:Connect(joined)

return Referrals
