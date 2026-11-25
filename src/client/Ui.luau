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
Ui.display = Font.fromEnum(Enum.Font.LuckiestGuy) -- chunky headline font for button labels

-- Big white button label with a thick black outline, allowed to spill past its button.
function Ui.shout(props: { [string]: any }): TextLabel
	local thickness = props.Thickness or 3.5
	props.Thickness = nil
	props.FontFace = Ui.display
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	return Ui.label(props, {
		Ui.make("UIStroke", {
			Color = Color3.new(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = thickness,
		}),
	})
end

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

function Ui.label(props: { [string]: any }, children: { Instance }?): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.FontFace = props.FontFace or Ui.font
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or Ui.colors.cream
	return Ui.make("TextLabel", props, children)
end

-- A gradient pill (black outline) with a shout label inside. The gradient sits on the frame,
-- not the label, so it never tints the text. Returns the frame and the label.
function Ui.pill(props: { [string]: any }, top: string, bottom: string): (Frame, TextLabel)
	props.BackgroundColor3 = Color3.new(1, 1, 1)
	local text = Ui.shout({ Size = UDim2.fromScale(1, 1), Text = "", Thickness = 3 })
	local frame = Ui.make("Frame", props, {
		Ui.corner(),
		Ui.make("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(0, 0, 0),
			Thickness = 4,
		}),
		Ui.make("UIGradient", {
			Color = ColorSequence.new(Color3.fromHex(top), Color3.fromHex(bottom)),
			Rotation = 90,
		}),
		Ui.make("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.14, 0) }),
		text,
	})
	return frame, text
end

-- "m:ss" until a server-clock time.
function Ui.countdown(endsAt: number): string
	local left = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
	return string.format("%d:%02d", left // 60, left % 60)
end


-- Keybinds ----------------------------------------------------------------------------------------
-- `Ui.bind(button, pcKeys, padKeys, run)`: pressing any listed key runs `run` while the button is
-- on screen, and a small badge in the button's corner names the key for the current device
-- (keyboard key, or the controller button in its usual colour; hidden on touch).
local UserInputService = game:GetService("UserInputService")

local PAD = { -- label and colour for controller buttons
	ButtonA = { "A", "3CC864" },
	ButtonB = { "B", "E6463C" },
	ButtonX = { "X", "3C8CF0" },
	ButtonY = { "Y", "F0C83C" },
	ButtonR2 = { "RT", "5A5A64" },
	DPadLeft = { "◀", "5A5A64" },
	DPadUp = { "▲", "5A5A64" },
	DPadRight = { "▶", "5A5A64" },
}
local KEY_NAMES = { Space = "SPACE", One = "1", Two = "2", Three = "3" }

local function device(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "touch"
	elseif string.find(last.Name, "^Gamepad") then
		return "pad"
	end
	return if UserInputService.KeyboardEnabled then "pc" else "touch"
end

local function onScreen(gui: GuiObject): boolean
	local node: Instance? = gui
	while node and not node:IsA("LayerCollector") do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node ~= nil and (not node:IsA("ScreenGui") or node.Enabled)
end

local badges: { () -> () } = {}
UserInputService.LastInputTypeChanged:Connect(function()
	for _, refresh in badges do
		refresh()
	end
end)

function Ui.bind(button: GuiObject, pcKeys: { Enum.KeyCode }, padKeys: { Enum.KeyCode }, run: () -> ())
	local text = Ui.make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Ui.display,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.new(0, 0, 0),
		TextScaled = true,
		ZIndex = button.ZIndex + 3,
	}, { Ui.make("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.12, 0) }) })
	local badge = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.3, 0.3),
		AutomaticSize = Enum.AutomaticSize.None,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Name = "KeyBadge",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.new(0, 30, 0, 26),
		ZIndex = button.ZIndex + 2,
		Parent = button,
	}, {
		Ui.corner(8),
		Ui.make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		text,
	})
	local function refresh()
		local kind = device()
		badge.Visible = kind ~= "touch"
		if kind == "pad" then
			local spec = PAD[padKeys[1].Name]
			text.Text = spec[1]
			text.TextColor3 = Color3.new(1, 1, 1)
			badge.BackgroundColor3 = Color3.fromHex(spec[2])
		else
			local name = pcKeys[1].Name
			text.Text = KEY_NAMES[name] or name
			text.TextColor3 = Color3.new(0, 0, 0)
			badge.BackgroundColor3 = Color3.new(1, 1, 1)
		end
		badge.Size = UDim2.new(0, if #text.Text > 2 then 62 else 30, 0, 26)
	end
	table.insert(badges, refresh)
	refresh()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not onScreen(button) then
			return
		end
		if table.find(pcKeys, input.KeyCode) or table.find(padKeys, input.KeyCode) then
			run()
		end
	end)
end

return Ui
