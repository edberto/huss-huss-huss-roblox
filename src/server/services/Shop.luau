--!strict
-- Cosmetics shop: buy and equip with Huss Points, and show equipped cosmetics to everyone:
-- a trail behind the character and an overhead tag with the player's rank and title.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Data = require(script.Parent.Data)

local remotes = ReplicatedStorage:WaitForChild("RhythmRemotes")
local buyEvent = Instance.new("RemoteFunction")
buyEvent.Name = "ShopBuy" -- client -> server: item id; returns nil or a failure reason
buyEvent.Parent = remotes
local equipEvent = Instance.new("RemoteFunction")
equipEvent.Name = "ShopEquip" -- client -> server: slot, item id or nil; returns nil or a reason
equipEvent.Parent = remotes

local function applyTrail(player: Player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, name in { "HussTrail", "HussTrailTop", "HussTrailBottom" } do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local item = Cosmetics.items[player:GetAttribute("Equipped_trail") :: string]
	if not item or not item.colors then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "HussTrailTop"
	top.Position = Vector3.new(0, 0.8, 0.4)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "HussTrailBottom"
	bottom.Position = Vector3.new(0, -0.8, 0.4)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "HussTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.5
	trail.LightEmission = 0.6
	trail.Color = ColorSequence.new(
		Color3.fromHex(item.colors[1]),
		Color3.fromHex(item.colors[2] or item.colors[1])
	)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = root
end

local function applyTag(player: Player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then
		return
	end
	local tag = head:FindFirstChild("HussTag") :: BillboardGui?
	if not tag then
		local gui = Instance.new("BillboardGui")
		gui.Name = "HussTag"
		gui.Size = UDim2.fromOffset(200, 26)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 80
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		text.TextScaled = true
		text.TextColor3 = Color3.fromHex("3DFFB0")
		text.TextStrokeTransparency = 0.4
		text.Parent = gui
		gui.Parent = head
		tag = gui
	end
	local item = Cosmetics.items[player:GetAttribute("Equipped_title") :: string]
	local rank = tostring(player:GetAttribute("Rank") or "Rookie")
	local label = (tag :: BillboardGui):FindFirstChild("Text") :: TextLabel
	local text = if item then `{rank} · {item.name}` else rank
	local vip = player:GetAttribute("VIP") == true
	label.Text = if vip then `VIP · {text}` else text
	label.TextColor3 = if vip then Color3.fromHex("FAC775") else Color3.fromHex("3DFFB0")
end

buyEvent.OnServerInvoke = function(player: Player, id: unknown): string?
	if typeof(id) ~= "string" then
		return "NotForSale"
	end
	return Data.update(player, function(data)
		return Cosmetics.buy(data :: any, id)
	end)
end

equipEvent.OnServerInvoke = function(player: Player, slot: unknown, id: unknown): string?
	if typeof(slot) ~= "string" or (id ~= nil and typeof(id) ~= "string") then
		return "BadSlot"
	end
	return Data.update(player, function(data)
		return Cosmetics.equip(data :: any, slot, id :: string?)
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head")
		character:WaitForChild("HumanoidRootPart")
		applyTrail(player)
		applyTag(player)
	end)
	player:GetAttributeChangedSignal("Equipped_trail"):Connect(function()
		applyTrail(player)
	end)
	player:GetAttributeChangedSignal("Equipped_title"):Connect(function()
		applyTag(player)
	end)
	player:GetAttributeChangedSignal("Rank"):Connect(function()
		applyTag(player)
	end)
	player:GetAttributeChangedSignal("VIP"):Connect(function()
		applyTag(player)
	end)
end)

return {}
