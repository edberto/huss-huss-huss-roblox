--!strict
-- Funnel and custom events for the Creator Hub analytics (Roblox AnalyticsService). The
-- onboarding funnel only counts new players (tutorial not done), each step once per session.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")

local Analytics = {}

-- Onboarding steps, in order. Read the drop-off between them in Creator Hub > Analytics.
Analytics.steps = table.freeze({
	Joined = 1,
	Training = 2, -- first night started
	FirstTap = 3,
	Combo = 4, -- reached an x2 multiplier: they get the rhythm
	NightOver = 5, -- gave in or lasted until dawn
	Dawn = 6, -- saw the results (tutorial done)
})

local logged: { [Player]: { [string]: boolean } } = {}

function Analytics.step(player: Player, name: string)
	local done = logged[player]
	if not done or done[name] or player:GetAttribute("TutorialDone") ~= false then
		return
	end
	done[name] = true
	pcall(
		AnalyticsService.LogOnboardingFunnelStepEvent,
		AnalyticsService,
		player,
		Analytics.steps[name],
		name
	)
end

function Analytics.event(player: Player, name: string, value: number)
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value)
end

-- Huss Points sources and sinks for Creator Hub > Analytics > Economy. transaction: a Roblox
-- AnalyticsEconomyTransactionType name (IAP, Shop, Gameplay, TimedReward, Onboarding, ...).
function Analytics.economy(
	player: Player,
	amount: number,
	balance: number,
	transaction: string,
	sku: string?
)
	local flow = if amount > 0
		then Enum.AnalyticsEconomyFlowType.Source
		else Enum.AnalyticsEconomyFlowType.Sink
	pcall(
		AnalyticsService.LogEconomyEvent,
		AnalyticsService,
		player,
		flow,
		"Huss",
		math.abs(amount),
		balance,
		transaction,
		sku
	)
end

Players.PlayerAdded:Connect(function(player)
	logged[player] = {}
end)
for _, player in Players:GetPlayers() do
	logged[player] = {}
end
Players.PlayerRemoving:Connect(function(player)
	logged[player] = nil
end)

return Analytics
