--!strict
-- Redeem codes. Server-only (ServerScriptService never replicates), so clients can't list them.
-- Keys are normalized: upper case, letters and digits only. Adding a code = code change + publish.
local Rewards = require(game:GetService("ReplicatedStorage").Shared.Rewards)

return table.freeze({
	HUSS = table.freeze({ hp = 200 }),
} :: { [string]: Rewards.Code })
