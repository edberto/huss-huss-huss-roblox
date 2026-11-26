--!strict
-- Burger station: each hit stacks a layer on the counter; the skill beat wraps the burger and
-- slides it onto the served pile. A skill-beat "Almost" topples the stack: "ahh almost almost".
-- Each client runs this for every trainer, like the basketball's dribble.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local StationFx = require(script.Parent.StationFx)
local Ui = require(script.Parent.Ui)

local LAYERS = {
	{ color = Color3.fromHex("E3A857"), height = 0.5 }, -- bottom bun
	{ color = Color3.fromHex("5A3825"), height = 0.45 }, -- patty
	{ color = Color3.fromHex("F5C542"), height = 0.18 }, -- cheese
	{ color = Color3.fromHex("6BBF59"), height = 0.22 }, -- lettuce
	{ color = Color3.fromHex("E3A857"), height = 0.65 }, -- top bun
}
local MAX_SERVED = 8

local Burger = {}

local function part(parent: Instance, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

function Burger.start(owner: Player): StationFx.Station
	local fx = StationFx.forPlayer(owner)
	local folder = Instance.new("Folder")
	folder.Name = "BurgerProps"
	local counter = part(folder, Vector3.new(6, 0.4, 2.6), Color3.fromHex("C9C2B0"))
	local legs = part(folder, Vector3.new(5.6, 2.6, 2.2), Color3.fromHex("6B6E78"))
	local active = false
	local stack: { Part } = {}
	local served: { Part } = {}
	local stackHeight = 0

	-- The counter sits in front of the player; everything is placed from its top centre.
	local function counterTop(): CFrame?
		local root = fx.rootCFrame()
		if not root then
			return nil
		end
		return CFrame.lookAlong(root * Vector3.new(0, -0.4, -2.4), root.LookVector)
	end

	local stepped = RunService.RenderStepped:Connect(function()
		local top = counterTop()
		if not active or not top then
			return
		end
		counter.CFrame = top * CFrame.new(0, -0.2, 0)
		legs.CFrame = top * CFrame.new(0, -1.7, 0)
	end)

	local function clearStack()
		for _, layer in stack do
			layer:Destroy()
		end
		table.clear(stack)
		stackHeight = 0
	end

	local function addLayer()
		local top = counterTop()
		if not top then
			return
		end
		local spec = LAYERS[(#stack % #LAYERS) + 1]
		local layer = part(folder, Vector3.new(2.4, spec.height, 2.4), spec.color)
		layer.Shape = Enum.PartType.Cylinder
		layer.Size = Vector3.new(spec.height, 2.4, 2.4)
		local resting = top
			* CFrame.new(-0.8, stackHeight + spec.height / 2, 0)
			* CFrame.Angles(0, 0, math.rad(90))
		layer.CFrame = resting + Vector3.new(0, 1.2, 0)
		TweenService:Create(
			layer,
			TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = resting }
		):Play()
		stackHeight += spec.height
		table.insert(stack, layer)
		fx.play("thud", 1.2)
	end

	local function wrap()
		local top = counterTop()
		if not top then
			return
		end
		clearStack()
		if #served >= MAX_SERVED then
			for _, box in served do
				box:Destroy()
			end
			table.clear(served)
		end
		-- A wrapped burger appears where the stack was and slides to the served pile.
		local box = part(folder, Vector3.new(1.4, 0.9, 1.4), Color3.fromHex("F2EEDC"))
		local band = part(box, Vector3.new(1.45, 0.25, 1.45), Ui.colors.orange)
		box.CFrame = top * CFrame.new(-0.8, 0.45, 0)
		band.CFrame = box.CFrame
		local slot = #served
		local target = top * CFrame.new(1.2 + (slot % 2) * 1.5, 0.45 + (slot // 2) * 0.9, 0)
		local slide = TweenInfo.new(0.25, Enum.EasingStyle.Quad)
		TweenService:Create(box, slide, { CFrame = target }):Play()
		TweenService:Create(band, slide, { CFrame = target }):Play()
		table.insert(served, box)
		fx.play("wrap")
	end

	local function topple()
		-- Let the layers fall off the counter for real, then clean up.
		local fallen = table.clone(stack)
		table.clear(stack)
		stackHeight = 0
		for _, layer in fallen do
			layer.Anchored = false
			layer.CanCollide = true
			layer.AssemblyLinearVelocity = Vector3.new(math.random(-4, 4), 4, math.random(-6, -2))
		end
		fx.play("thud", 0.7)
		fx.almost()
		task.delay(2, function()
			for _, layer in fallen do
				layer:Destroy()
			end
		end)
	end

	local function onResult(grade: string, skill: boolean)
		if grade == "Miss" then
			return
		end
		fx.huss()
		if not skill then
			addLayer()
		elseif grade == "Almost" then
			topple()
		else
			wrap()
		end
	end

	return {
		onResult = onResult,
		setActive = function(on: boolean)
			active = on
			clearStack()
			folder.Parent = if on then workspace else nil
		end,
		destroy = function()
			stepped:Disconnect()
			folder:Destroy()
		end,
	}
end

return Burger
