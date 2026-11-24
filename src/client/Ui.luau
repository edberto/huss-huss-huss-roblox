--!strict
-- Shared UI helpers and the art-style palette (design doc) for every screen.
local Ui = {}

Ui.colors = table.freeze({
	navy = Color3.fromHex("141B36"),
	cream = Color3.fromHex("F2EEDC"),
	amber = Color3.fromHex("FFB547"),
	orange = Color3.fromHex("FF6B1A"),
	mint = Color3.fromHex("3DFFB0"),
	pink = Color3.fromHex("FF2E93"),
	purple = Color3.fromHex("8A3CFF"),
	partyWall = Color3.fromHex("4B2A6B"),
	dawn = Color3.fromHex("F2C6A0"),
	panel = Color3.fromHex("2C2C2A"),
	muted = Color3.fromHex("888780"),
	rule = Color3.fromHex("D3D1C7"),
	gold = Color3.fromHex("FAC775"),
})
Ui.font = Font.fromEnum(Enum.Font.FredokaOne)

function Ui.make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	return inst
end

-- Rounded corners; no radius = fully round (pill or circle).
function Ui.corner(radius: number?): UICorner
	return Ui.make(
		"UICorner",
		{ CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0) }
	)
end

function Ui.label(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.FontFace = Ui.font
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or Ui.colors.cream
	return Ui.make("TextLabel", props)
end

-- "m:ss" until a server-clock time.
function Ui.countdown(endsAt: number): string
	local left = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
	return string.format("%d:%02d", left // 60, left % 60)
end

return Ui
