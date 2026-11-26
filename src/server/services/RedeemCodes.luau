--!strict
-- Redeem codes. Server-only (ServerScriptService never replicates), so clients can't list them.
-- Keys are normalized: upper case, letters and digits only. Adding a code = code change + publish.
local Rewards = require(game:GetService("ReplicatedStorage").Shared.Rewards)

return table.freeze({
	HUSS = table.freeze({ hp = 200 }),
	LAUNCH = table.freeze({ hp = 500, expiresAt = 1797120000 }), -- launch week, until 13 Dec 2026 00:00 UTC
	FLAMINGO = table.freeze({ hp = 300 }), -- Discord-only code
} :: { [string]: Rewards.Code })
