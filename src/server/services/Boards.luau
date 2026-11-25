--!strict
-- The floating leaderboards over the party house: three in a row facing the street (skill,
-- Most Huss, practices) with the partier board above the middle. Each is a real part with a
-- SurfaceGui showing the top 10 of its current category; boards with several categories rotate
-- every ROTATE seconds. Clients make them bob and flip (tag "FloatBoard"), and tapping one opens
-- the Ranks panel (ClickDetector).
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stats = require(ReplicatedStorage.Shared.Stats)

local ROTATE = 8
local SHOWN = 10
local PIXELS_PER_STUD = 40

local Boards = {}

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local MEDALS = { Color3.fromHex("FFD23C"), Color3.fromHex("D2D7E6"), Color3.fromHex("E18C46") }
local DISPLAY = Font.fromEnum(Enum.Font.LuckiestGuy)
local BODY = Font.fromEnum(Enum.Font.FredokaOne)

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	return inst
end

local function corner(scale: number?): UICorner
	return make("UICorner", { CornerRadius = UDim.new(scale or 1, 0) })
end

local function outlined(props: { [string]: any }, thickness: number): TextLabel
	props.BackgroundTransparency = 1
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or WHITE
	props.FontFace = props.FontFace or DISPLAY
	return make("TextLabel", props, {
		make("UIStroke", { Color = BLACK, Thickness = thickness, LineJoinMode = Enum.LineJoinMode.Round }),
	})
end

type Board = {
	part: Part,
	categories: { typeof(Stats.categories[1]) },
	index: number,
	header: Frame,
	title: TextLabel,
	rows: { { frame: Frame, medal: Frame, place: TextLabel, face: ImageLabel, name: TextLabel, value: TextLabel } },
	dots: { Frame },
	empty: TextLabel,
}

local boards: { Board } = {}

local function build(name: string, cframe: CFrame, size: Vector2, categories): Board
	local part = make("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = true,
		CastShadow = false,
		CFrame = cframe,
		Color = Color3.fromHex("190F37"),
		Material = Enum.Material.SmoothPlastic,
		Name = `Board_{name}`,
		Size = Vector3.new(size.X, size.Y, 0.6),
	})
	part:SetAttribute("Base", cframe)
	part:SetAttribute("Phase", #boards * 1.3)
	CollectionService:AddTag(part, "FloatBoard")
	make("ClickDetector", { MaxActivationDistance = 1000, Parent = part })

	local gui = make("SurfaceGui", {
		Face = Enum.NormalId.Front,
		LightInfluence = 0,
		PixelsPerStud = PIXELS_PER_STUD,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		Parent = part,
	})
	local root = make("Frame", {
		BackgroundColor3 = Color3.fromHex("231646"),
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	}, { corner(0.06), make("UIStroke", { Color = BLACK, Thickness = 14 }) })
	local title = outlined({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.72),
		Text = "",
	}, 8)
	local header = make("Frame", {
		BackgroundColor3 = Color3.fromHex(categories[1].color),
		Size = UDim2.fromScale(1, 0.13),
		Parent = root,
	}, { corner(0.4), make("UIStroke", { Color = BLACK, Thickness = 12 }), title })

	local rows = {}
	local list = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.04, 0.16),
		Size = UDim2.fromScale(0.92, 0.76),
		Parent = root,
	}, { make("UIListLayout", { Padding = UDim.new(0.012, 0), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i = 1, SHOWN do
		local place = outlined({
			Size = UDim2.fromScale(1, 1),
			FontFace = BODY,
			Text = tostring(i),
			TextColor3 = BLACK,
		}, 0)
		local medal = make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = MEDALS[i] or Color3.fromHex("5A5082"),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromScale(0.8, 0.8),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
		}, { corner(), make("UIStroke", { Color = BLACK, Thickness = 4 }), place })
		local face = make("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromHex("C8AA8C"),
			Position = UDim2.fromScale(0.1, 0.5),
			Size = UDim2.fromScale(0.86, 0.86),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
		}, { corner(), make("UIStroke", { Color = BLACK, Thickness = 4 }) })
		local nameLabel = outlined({
			Position = UDim2.fromScale(0.2, 0.12),
			Size = UDim2.fromScale(0.5, 0.76),
			FontFace = BODY,
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
		}, 0)
		local value = outlined({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(0.98, 0.08),
			Size = UDim2.fromScale(0.3, 0.84),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Right,
		}, 5)
		local frame = make("Frame", {
			BackgroundColor3 = Color3.fromHex("32235F"),
			LayoutOrder = i,
			Size = UDim2.fromScale(1, 0.088),
			Parent = list,
		}, { corner(0.3), medal, face, nameLabel, value })
		rows[i] = { frame = frame, medal = medal, place = place, face = face, name = nameLabel, value = value }
	end
	local empty = outlined({
		AnchorPoint = Vector2.new(0.5, 0.5),
		FontFace = BODY,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.08),
		Text = "Be the first!",
		Visible = false,
		Parent = root,
	}, 0)
	local dots = {}
	if #categories > 1 then
		local dotRow = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.975),
			Size = UDim2.fromScale(0.3, 0.025),
			Parent = root,
		}, {
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.06, 0),
			}),
		})
		for i = 1, #categories do
			dots[i] = make("Frame", {
				BackgroundColor3 = WHITE,
				LayoutOrder = i,
				Size = UDim2.fromScale(1, 1),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Parent = dotRow,
			}, { corner() })
		end
	end
	part.Parent = workspace:WaitForChild("Town")
	return {
		part = part,
		categories = categories,
		index = 1,
		header = header,
		title = title,
		rows = rows,
		dots = dots,
		empty = empty,
	}
end

local function render(board: Board)
	local category = board.categories[board.index]
	board.part:SetAttribute("Category", category.key)
	board.header.BackgroundColor3 = Color3.fromHex(category.color)
	board.title.Text = category.title
	local value = ReplicatedStorage.Leaderboards:FindFirstChild(category.key) :: StringValue?
	local entries = if value then HttpService:JSONDecode(value.Value) else {}
	for i, row in board.rows do
		local entry = entries[i]
		row.frame.Visible = entry ~= nil
		if entry then
			row.name.Text = entry.name
			row.value.Text = Stats.format(category.key, entry.value)
			row.value.TextColor3 = Color3.fromHex(category.color)
			row.face.Image = `rbxthumb://type=AvatarHeadShot&id={entry.id}&w=150&h=150`
		end
	end
	board.empty.Visible = entries[1] == nil
	for i, dot in board.dots do
		dot.BackgroundTransparency = if i == board.index then 0 else 0.65
	end
end

function Boards.build()
	local house = workspace:WaitForChild("Town"):WaitForChild("PartyHouse") :: Model
	local lawn = house:WaitForChild("Lawn") :: BasePart
	local box, extents = house:GetBoundingBox()
	-- Face the street: from the house's middle towards its lawn, kept level.
	local toLawn = lawn.Position - box.Position
	local front = Vector3.new(toLawn.X, 0, toLawn.Z).Unit
	local middle = Vector3.new(box.Position.X, box.Position.Y + extents.Y / 2 + 16, box.Position.Z)
	local facing = CFrame.lookAt(middle, middle + front)
	-- Board-space +X is the viewer's left.
	local groups: { [string]: { typeof(Stats.categories[1]) } } = {}
	for _, category in Stats.categories do
		groups[category.board] = groups[category.board] or {}
		table.insert(groups[category.board], category)
	end
	table.insert(boards, build("Center", facing, Vector2.new(22, 22), groups.Center))
	table.insert(boards, build("Left", facing * CFrame.new(21, -2, -2), Vector2.new(17, 18), groups.Left))
	table.insert(boards, build("Right", facing * CFrame.new(-21, -2, -2), Vector2.new(17, 18), groups.Right))
	table.insert(boards, build("Party", facing * CFrame.new(0, 21, -4), Vector2.new(17, 18), groups.Party))

	for _, board in boards do
		render(board)
	end
	for _, value in ReplicatedStorage.Leaderboards:GetChildren() do
		if value:IsA("StringValue") then
			value.Changed:Connect(function()
				for _, board in boards do
					if board.categories[board.index].key == value.Name then
						render(board)
					end
				end
			end)
		end
	end
	while true do
		task.wait(ROTATE)
		for _, board in boards do
			if #board.categories > 1 then
				board.index = board.index % #board.categories + 1
				render(board)
			end
		end
	end
end

return Boards
