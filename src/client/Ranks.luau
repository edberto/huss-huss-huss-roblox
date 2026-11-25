--!strict
-- The Ranks panel: a tab per leaderboard, the top 100 in a scrolling list, and the player's
-- own row pinned at the bottom. Opens from the Ranks side button or by tapping a floating board.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Stats = require(ReplicatedStorage.Shared.Stats)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local make, corner = Ui.make, Ui.corner
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local MEDALS = { Color3.fromHex("FFD23C"), Color3.fromHex("D2D7E6"), Color3.fromHex("E18C46") }

local Ranks = {}

local panel: Frame
local scale: UIScale
local list: ScrollingFrame
local tabs: { [string]: TextButton } = {}
local mine: { place: TextLabel, value: TextLabel }
local current = "hp"

local function stroke(thickness: number): UIStroke
	return make(
		"UIStroke",
		{ ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = BLACK, Thickness = thickness }
	)
end

local function category(key: string)
	for _, c in Stats.categories do
		if c.key == key then
			return c
		end
	end
	return Stats.categories[1]
end

local function render()
	local info = category(current)
	for key, tab in tabs do
		local on = key == current
		tab.BackgroundColor3 = if on
			then Color3.fromHex(category(key).color)
			else Color3.fromHex("3C2D6E")
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local value = ReplicatedStorage:FindFirstChild("Leaderboards")
		and ReplicatedStorage.Leaderboards:FindFirstChild(current) :: StringValue?
	local entries = if value then HttpService:JSONDecode(value.Value) else {}
	local myPlace = nil
	for place, entry in entries do
		if entry.id == player.UserId then
			myPlace = place
		end
		make("Frame", {
			BackgroundColor3 = Color3.fromHex("32235F"),
			LayoutOrder = place,
			Size = UDim2.new(1, -14, 0, 44),
			Parent = list,
		}, {
			corner(12),
			make("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = MEDALS[place] or Color3.fromHex("5A5082"),
				Position = UDim2.new(0, 10, 0.5, 0),
				Size = UDim2.fromOffset(32, 32),
			}, {
				corner(),
				make("UIStroke", { Color = BLACK, Thickness = 2 }),
				Ui.label(
					{ Size = UDim2.fromScale(1, 1), Text = tostring(place), TextColor3 = BLACK },
					{
						make(
							"UIPadding",
							{ PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0) }
						),
					}
				),
			}),
			make("ImageLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.fromHex("C8AA8C"),
				Image = `rbxthumb://type=AvatarHeadShot&id={entry.id}&w=48&h=48`,
				Position = UDim2.new(0, 50, 0.5, 0),
				Size = UDim2.fromOffset(34, 34),
			}, { corner(), make("UIStroke", { Color = BLACK, Thickness = 2 }) }),
			Ui.label({
				Position = UDim2.new(0, 94, 0.2, 0),
				Size = UDim2.new(0.55, -94, 0.6, 0),
				Text = entry.name,
				TextColor3 = WHITE,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Ui.shout({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0.15, 0),
				Size = UDim2.fromScale(0.35, 0.7),
				Text = Stats.format(current, entry.value),
				TextColor3 = Color3.fromHex(info.color),
				TextXAlignment = Enum.TextXAlignment.Right,
				Thickness = 2,
			}),
		})
	end
	if #entries == 0 then
		make(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), Parent = list },
			{
				Ui.label({ Size = UDim2.fromScale(1, 0.6), Text = "Nobody yet. Be the first!" }),
			}
		)
	end
	local own = tonumber(player:GetAttribute(`Stat_{current}`)) or 0
	mine.place.Text = if myPlace then `YOU  #{myPlace}` else "YOU  · not in top 100 yet"
	mine.value.Text = Stats.format(current, own)
end

function Ranks.open(key: string?)
	current = key or current
	panel.Visible = true
	scale.Scale = 0.85
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	render()
end

function Ranks.toggle()
	if panel.Visible then
		panel.Visible = false
	else
		Ranks.open()
	end
end

function Ranks.start()
	local gui = make("ScreenGui", {
		Name = "Ranks",
		DisplayOrder = 8,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	scale = make("UIScale", {})
	list = make("ScrollingFrame", {
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		Position = UDim2.new(0.03, 0, 0, 132),
		ScrollBarImageColor3 = Color3.fromHex("FFD23C"),
		ScrollBarThickness = 10,
		Size = UDim2.new(0.94, 0, 1, -212),
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local tabRow = make("ScrollingFrame", {
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		Position = UDim2.new(0.03, 0, 0, 78),
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Size = UDim2.new(0.94, 0, 0, 44),
	}, {
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
	})
	for i, c in Stats.categories do
		local tab = make("TextButton", {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.fromHex("3C2D6E"),
			FontFace = Ui.display,
			LayoutOrder = i,
			Size = UDim2.fromOffset(0, 34),
			Text = c.short,
			TextColor3 = WHITE,
			TextSize = 18,
			Parent = tabRow,
		}, {
			corner(),
			stroke(2.5),
			make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
		})
		tab.Activated:Connect(function()
			current = c.key
			render()
		end)
		tabs[c.key] = tab
	end
	local minePlace = Ui.shout({
		Position = UDim2.fromScale(0.04, 0.18),
		Size = UDim2.fromScale(0.6, 0.64),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Thickness = 3,
	})
	local mineValue = Ui.shout({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.96, 0.18),
		Size = UDim2.fromScale(0.34, 0.64),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		Thickness = 3,
	})
	mine = { place = minePlace, value = mineValue }
	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromHex("FF505A"),
		Position = UDim2.new(1, -16, 0, 14),
		Size = UDim2.fromOffset(44, 44),
		Text = "",
	}, {
		corner(),
		stroke(3),
		Ui.shout({ Size = UDim2.fromScale(1, 1), Text = "X", Thickness = 2.5 }),
	})
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	panel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromHex("23164B"),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.9),
		Visible = false,
		Parent = gui,
	}, {
		corner(24),
		stroke(5),
		scale,
		make("UISizeConstraint", { MaxSize = Vector2.new(900, 760) }),
		Ui.shout({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 12),
			Size = UDim2.new(0.4, 0, 0, 56),
			Text = "RANKS",
			TextColor3 = Color3.fromHex("FFD23C"),
			Thickness = 4,
		}),
		close,
		tabRow,
		list,
		make("Frame", { -- the player's own row
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromHex("FFD23C"),
			Position = UDim2.new(0.5, 0, 1, -16),
			Size = UDim2.new(0.94, 0, 0, 56),
		}, { corner(16), stroke(4), minePlace, mineValue }),
	})
	-- Keep an open panel fresh as the boards update.
	local folder = ReplicatedStorage:WaitForChild("Leaderboards")
	for _, value in folder:GetChildren() do
		if value:IsA("StringValue") then
			value.Changed:Connect(function()
				if panel.Visible and value.Name == current then
					render()
				end
			end)
		end
	end
end

return Ranks
