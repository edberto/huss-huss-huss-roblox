--!strict
-- The approved night-cycle screens: Dusk station picker, temptation prompts, the give-in screen
-- and the Dawn results card. Driven by ReplicatedStorage "Phase"/"PhaseEnds" and the remotes.
local AvatarEditorService = game:GetService("AvatarEditorService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local Night = require(ReplicatedStorage.Shared.Night)
local StationFx = require(script.Parent.StationFx)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RhythmRemotes")
local temptationEvent = remotes:WaitForChild("Temptation") :: RemoteEvent
local answerEvent = remotes:WaitForChild("TemptationAnswer") :: RemoteEvent
local resultsEvent = remotes:WaitForChild("NightResults") :: RemoteEvent

local C = Ui.colors
local make, corner, label = Ui.make, Ui.corner, Ui.label
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local GOLD = Color3.fromHex("FFD75A")
local MEDALS = { Color3.fromHex("FFD23C"), Color3.fromHex("D2D7E6"), Color3.fromHex("E18C46") }
local function outline(thickness: number): UIStroke
	return make("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = BLACK,
		Thickness = thickness,
	})
end
local function purplePanel(props: { [string]: any }): Frame
	props.BackgroundColor3 = Color3.fromHex("23164B")
	return make("Frame", props, { corner(22), outline(5) })
end

local PROMPTS = {
	Doorbell = { text = "Ding dong! Party's next door", button = "Ignore" },
	Phone = { text = "New message: party at the end of the street", button = "Decline" },
	Friend = { text = "Come on, just one hour!", button = "Not tonight" },
	BassDrop = { text = "BASS DROP! Misses count double", button = nil },
}

local NightScreens = {}

function NightScreens.start()
	local gui = make("ScreenGui", {
		Name = "NightScreens",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- 1. Dusk: pick a station ---------------------------------------------------------------------
	local dusk = make(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = gui }
	)
	local duskTitle = Ui.shout({
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0,
		Position = UDim2.fromScale(0.5, 0.04),
		Size = UDim2.fromScale(0.5, 0.08),
		Text = "",
		Thickness = 3,
		Parent = dusk,
	})
	corner().Parent = duskTitle
	outline(4).Parent = duskTitle
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromHex("3C2878"), Color3.fromHex("1E1446")),
		Rotation = 90,
		Parent = duskTitle,
	})
	make(
		"UIPadding",
		{ PaddingTop = UDim.new(0.17, 0), PaddingBottom = UDim.new(0.13, 0), Parent = duskTitle }
	)
	-- Station cards: art, difficulty colour (green / blue / red), bonus chip and a 3-pip meter.
	local STYLE = {
		Basketball = { art = "131564544711416", top = "5AD278", bottom = "1E8C50", pips = 1 },
		Gym = { art = "113372981054456", top = "50C3FF", bottom = "1E6ED2", pips = 2 },
		Burgers = { art = "107620291266706", top = "FF6464", bottom = "C81E3C", pips = 3 },
	}
	local cards = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromScale(0.62, 0.5),
		Parent = dusk,
	}, {
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.035, 0),
		}),
	})
	local pickEvent = remotes:WaitForChild("PickStation") :: RemoteEvent
	type CardParts = {
		card: TextButton,
		stroke: UIStroke,
		glow: UIStroke,
		badge: Frame,
		scale: UIScale,
	}
	local cardParts: { [string]: CardParts } = {}
	for i, name in Night.stations do
		local info = Night.stationInfo[name]
		local style = STYLE[name]
		local scale = make("UIScale", {})
		local stroke = make("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = C.navy,
			Thickness = 4,
		})
		local card = make("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = i,
			Size = UDim2.fromScale(0.3, 0.92),
			Text = "",
			Parent = cards,
		}, {
			corner(18),
			stroke,
			scale,
			make("UIGradient", {
				Color = ColorSequence.new(Color3.fromHex(style.top), Color3.fromHex(style.bottom)),
				Rotation = 90,
			}),
			make("Frame", { -- glossy top highlight
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.7,
				Position = UDim2.fromScale(0.06, 0.03),
				Size = UDim2.fromScale(0.88, 0.05),
			}, { corner() }),
			make("Frame", { -- soft spotlight behind the art
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.75,
				Position = UDim2.fromScale(0.5, 0.34),
				Size = UDim2.fromScale(0.78, 0.78),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
			}, { corner() }),
			make("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://" .. style.art,
				Position = UDim2.fromScale(0.5, 0.34),
				Size = UDim2.fromScale(0.68, 0.68),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
			}),
			Ui.shout({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.71),
				Size = UDim2.fromScale(1.05, 0.17),
				Text = string.upper(name),
				Thickness = 4,
				ZIndex = 3,
			}),
			make("Frame", { -- difficulty pill (+ bonus chip)
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.79),
				Size = UDim2.fromScale(0.9, 0.08),
			}, {
				make("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0.04, 0),
				}),
				label({
					BackgroundColor3 = C.navy,
					BackgroundTransparency = 0,
					LayoutOrder = 1,
					Size = UDim2.fromScale(0.44, 1),
					Text = string.upper(info.difficulty),
					TextColor3 = Color3.new(1, 1, 1),
				}, {
					corner(),
					make(
						"UIPadding",
						{ PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }
					),
				}),
				if info.bonus > 0
					then label({
						BackgroundColor3 = Color3.fromHex("FFE63C"),
						BackgroundTransparency = 0,
						LayoutOrder = 2,
						Size = UDim2.fromScale(0.48, 1),
						Text = `+{math.round(info.bonus * 100)}% HUSS`,
						TextColor3 = C.navy,
					}, {
						corner(),
						make("UIStroke", {
							Color = C.navy,
							Thickness = 2,
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						}),
						make(
							"UIPadding",
							{ PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }
						),
					})
					else nil,
			}),
		})
		-- Difficulty meter: filled white pips with a dark outline.
		local meter = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.895),
			Size = UDim2.fromScale(0.4, 0.05),
			Parent = card,
		}, {
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.08, 0),
			}),
		})
		for pip = 1, 3 do
			make("Frame", {
				BackgroundColor3 = if pip <= style.pips then Color3.new(1, 1, 1) else C.navy,
				BackgroundTransparency = if pip <= style.pips then 0 else 0.6,
				LayoutOrder = pip,
				Size = UDim2.fromScale(0.27, 1),
				Parent = meter,
			}, { corner(), make("UIStroke", { Color = C.navy, Thickness = 2 }) })
		end
		local glow = make("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromHex("FFE63C"),
			Thickness = 8,
			Transparency = 1,
		})
		make("Frame", { -- glow ring around the selected card
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-6, -6),
			Size = UDim2.new(1, 12, 1, 12),
			ZIndex = 0,
			Parent = card,
		}, { corner(24), glow })
		local badge = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromHex("FFE63C"),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(0.66, 0.08),
			Visible = false,
			ZIndex = 3,
			Parent = card,
		}, {
			corner(),
			make(
				"UIStroke",
				{ Color = C.navy, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
			),
			label({
				Size = UDim2.fromScale(1, 1),
				Text = "✓ SELECTED",
				TextColor3 = C.navy,
				ZIndex = 4,
			}, {
				make(
					"UIPadding",
					{ PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.15, 0) }
				),
			}),
		})
		-- Press feedback: squash on press, pop on release.
		card.MouseButton1Down:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.94 }):Play()
		end)
		card.MouseLeave:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
		end)
		card.Activated:Connect(function()
			StationFx.play("clap", 1.3)
			pickEvent:FireServer(name)
		end)
		cardParts[name] =
			{ card = card, stroke = stroke, glow = glow, badge = badge, scale = scale }
	end
	-- The picked card lifts, glows and gets the SELECTED badge; the others sit back a little.
	local function refreshCards()
		local picked = player:GetAttribute("Station")
		for name, parts in cardParts do
			local on = name == picked
			parts.badge.Visible = on
			parts.stroke.Color = if on then Color3.new(1, 1, 1) else C.navy
			TweenService
				:Create(parts.glow, TweenInfo.new(0.2), { Transparency = if on then 0.15 else 1 })
				:Play()
			TweenService:Create(
				parts.scale,
				TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = if on then 1.06 else 0.97 }
			):Play()
		end
	end
	player:GetAttributeChangedSignal("Station"):Connect(refreshCards)
	refreshCards()
	label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.93),
		Size = UDim2.fromScale(0.6, 0.05),
		Text = "In this town, everybody goes out partying… except me.",
		TextColor3 = Color3.fromHex("B4B2A9"),
		Parent = dusk,
	})

	-- 2. Temptation prompt ------------------------------------------------------------------------
	local prompt = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.cream,
		Position = UDim2.fromScale(0.5, 0.11),
		Size = UDim2.fromScale(0.42, 0.25),
		Visible = false,
		Parent = gui,
	}, { corner(18), outline(5) })
	local promptText = label({
		FontFace = Ui.display,
		Position = UDim2.fromScale(0.06, 0.1),
		Size = UDim2.fromScale(0.88, 0.26),
		TextColor3 = C.navy,
		Parent = prompt,
	})
	local timerBack = make("Frame", {
		BackgroundColor3 = Color3.fromHex("140C28"),
		Position = UDim2.fromScale(0.06, 0.43),
		Size = UDim2.fromScale(0.88, 0.08),
		Parent = prompt,
	}, { corner(), outline(2.5) })
	local timerFill = make(
		"Frame",
		{ BackgroundColor3 = C.pink, Size = UDim2.fromScale(1, 1), Parent = timerBack },
		{ corner() }
	)
	local promptButton = make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = WHITE,
		FontFace = Ui.display,
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromScale(0.56, 0.3),
		TextColor3 = WHITE,
		TextScaled = true,
		Parent = prompt,
	}, {
		corner(14),
		outline(4),
		make("UIGradient", {
			Color = ColorSequence.new(Color3.fromHex("5AD278"), Color3.fromHex("1E8C50")),
			Rotation = 90,
		}),
		make("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Color = BLACK,
			Thickness = 2.5,
		}),
		make("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.14, 0) }),
	})

	local activeId = 0
	local tapsLeft = 0
	local buttonText = ""
	local function refreshButton()
		promptButton.Text = if tapsLeft > 1 then `{buttonText} ({tapsLeft})` else buttonText
	end
	promptButton.Activated:Connect(function()
		if tapsLeft <= 0 then
			return
		end
		answerEvent:FireServer(activeId)
		tapsLeft -= 1
		if tapsLeft <= 0 then
			prompt.Visible = false
		else
			refreshButton()
		end
	end)

	temptationEvent.OnClientEvent:Connect(function(id: number, kind: string, window: number)
		local spec = PROMPTS[kind]
		if not spec then
			return
		end
		activeId = id
		tapsLeft = if kind == "Friend" then 3 elseif spec.button then 1 else 0
		buttonText = spec.button or ""
		refreshButton()
		promptText.Text = spec.text
		promptButton.Visible = spec.button ~= nil
		prompt.BackgroundColor3 = if spec.button then C.cream else C.pink
		promptText.TextColor3 = if spec.button then C.navy else C.cream
		prompt.Visible = true
		timerFill.Size = UDim2.fromScale(1, 1)
		TweenService:Create(
			timerFill,
			TweenInfo.new(window, Enum.EasingStyle.Linear),
			{ Size = UDim2.fromScale(0, 1) }
		):Play()
		task.delay(window, function()
			if activeId == id then
				prompt.Visible = false
			end
		end)
	end)

	-- 3. Gave in to the party ---------------------------------------------------------------------
	local gaveIn = make("Frame", {
		BackgroundColor3 = C.partyWall,
		BackgroundTransparency = 0.25,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = gui,
	})
	local gaveInScale = make("UIScale", {})
	local gaveInTitle = Ui.shout({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Rotation = -4,
		Size = UDim2.fromScale(0.75, 0.15),
		Text = "YOU GAVE IN TO THE PARTY!",
		TextColor3 = Color3.fromHex("FF50C8"),
		Thickness = 6,
		Parent = gaveIn,
	})
	gaveInScale.Parent = gaveInTitle
	local gaveInStats = Ui.shout({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromScale(0.5, 0.065),
		Text = "",
		Thickness = 3,
		Parent = gaveIn,
	})
	local tempt = Ui.shout({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0,
		Position = UDim2.fromScale(0.5, 0.8),
		Size = UDim2.fromScale(0.44, 0.075),
		Text = "NOW DRAG THE OTHERS IN UNTIL DAWN",
		Thickness = 3,
		Parent = gaveIn,
	})
	corner().Parent = tempt
	outline(4).Parent = tempt
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromHex("FF64D2"), Color3.fromHex("B42896")),
		Rotation = 90,
		Parent = tempt,
	})
	make("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.14, 0), Parent = tempt })
	player:GetAttributeChangedSignal("Team"):Connect(function()
		if player:GetAttribute("Team") ~= "Partier" then
			return
		end
		prompt.Visible = false
		activeId = 0
		gaveInStats.Text =
			`LASTED UNTIL {player:GetAttribute("LastedUntil") or "?"} · {player:GetAttribute(
				"NightPoints"
			) or 0} HUSS`
		gaveIn.Visible = true
		gaveInScale.Scale = 1.4
		TweenService:Create(gaveInScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(4, function()
			gaveIn.Visible = false
		end)
	end)

	-- 4. Dawn results -----------------------------------------------------------------------------
	-- Sun + banner, the night's top 5 (who lasted longest) with your row highlighted, then your
	-- reward: Huss earned with a coin, Perfects, level, and a next-night countdown.
	local dawn = make(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = gui }
	)
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.5, 0.1),
		Parent = dawn,
	}, {
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.02, 0),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		make("Frame", { -- the sun
			BackgroundColor3 = Color3.fromHex("FFC83C"),
			LayoutOrder = 1,
			Size = UDim2.fromScale(0.8, 0.8),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
		}, { corner(), outline(4) }),
		Ui.shout({
			LayoutOrder = 2,
			Size = UDim2.fromScale(0.75, 0.85),
			Text = "DAWN · 6:00 AM",
			TextColor3 = GOLD,
			Thickness = 5,
		}),
	})
	local card = purplePanel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.14),
		Size = UDim2.fromScale(0.4, 0),
		Parent = dawn,
	})
	make("UISizeConstraint", { MinSize = Vector2.new(420, 0), Parent = card })
	make("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		Parent = card,
	})
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
	local nextNight = Ui.shout({
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.fromHex("3C2878"),
		BackgroundTransparency = 0,
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromScale(0.2, 0.065),
		Text = "",
		Thickness = 3,
		Parent = dawn,
	})
	corner().Parent = nextNight
	outline(4).Parent = nextNight
	make("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.14, 0), Parent = nextNight })

	local function line(order: number, height: number): Frame
		return make("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, height),
			Parent = card,
		})
	end

	local function row(place: number, result: any)
		local me = result.userId == player.UserId
		make("Frame", {
			BackgroundColor3 = if me then GOLD else Color3.fromHex("32235F"),
			LayoutOrder = place + 1,
			Size = UDim2.new(1, 0, 0, 40),
			Parent = card,
		}, {
			corner(12),
			if me then outline(3) else nil,
			make("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = MEDALS[place] or Color3.fromHex("5A5082"),
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(28, 28),
			}, {
				corner(),
				make("UIStroke", { Color = BLACK, Thickness = 2 }),
				label({ Size = UDim2.fromScale(1, 1), Text = tostring(place), TextColor3 = BLACK }, {
					make("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0) }),
				}),
			}),
			make("ImageLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.fromHex("C8AA8C"),
				Image = if result.userId > 0
					then `rbxthumb://type=AvatarHeadShot&id={result.userId}&w=48&h=48`
					else "",
				Position = UDim2.new(0, 44, 0.5, 0),
				Size = UDim2.fromOffset(30, 30),
			}, { corner(), make("UIStroke", { Color = BLACK, Thickness = 2 }) }),
			label({
				Position = UDim2.new(0, 84, 0.2, 0),
				Size = UDim2.new(0.45, -84, 0.6, 0),
				Text = if me then "You" else result.name,
				TextColor3 = if me then BLACK else WHITE,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Ui.shout({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0.18, 0),
				Size = UDim2.fromScale(0.5, 0.64),
				Text = string.upper(result.lasted or "Locked in all night"),
				TextColor3 = if me then WHITE else GOLD,
				TextXAlignment = Enum.TextXAlignment.Right,
				Thickness = 2,
			}),
		})
	end

	-- At most one prompt per Dawn, each once per session (no rewards: Roblox forbids rewarding
	-- favorites). A top-3 finish asks to favorite; otherwise, invite friends.
	-- ponytail: once per session, not once per account; save flags if players find it nagging.
	local askedFavorite, askedInvite = false, false
	resultsEvent.OnClientEvent:Connect(function(results: { any })
		local topThree = false
		for i, result in results do
			if i <= 3 and result.userId == player.UserId then
				topThree = true
			end
		end
		local ask: (() -> ())? = nil
		if topThree and not askedFavorite then
			askedFavorite = true
			ask = function()
				AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
			end
		elseif not askedInvite then
			askedInvite = true
			ask = function()
				if SocialService:CanSendGameInviteAsync(player) then
					SocialService:PromptGameInvite(player)
				end
			end
		end
		if ask then
			task.delay(4, pcall, ask) -- after the Dawn card has had its moment
		end
	end)

	resultsEvent.OnClientEvent:Connect(function(results: { any })
		for _, child in card:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		Ui.shout({
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 30),
			Text = "WHO LASTED LONGEST",
			Thickness = 3,
			Parent = line(0, 30),
		})
		local mine = nil
		for i, result in results do
			if result.userId == player.UserId then
				mine = result
			end
			if i <= 5 then
				row(i, result)
			end
		end
		if mine then
			make("Frame", {
				BackgroundColor3 = Color3.fromHex("5A4B96"),
				BorderSizePixel = 0,
				LayoutOrder = 50,
				Size = UDim2.new(1, 0, 0, 3),
				Parent = card,
			})
			local reward = line(51, 56)
			make("Frame", { -- coin
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.fromHex("FFF096"),
				Position = UDim2.new(0, 4, 0.5, 0),
				Size = UDim2.fromOffset(46, 46),
				Parent = reward,
			}, {
				corner(),
				outline(3),
				label({
					FontFace = Ui.display,
					Size = UDim2.fromScale(1, 1),
					Text = "H",
					TextColor3 = Color3.fromHex("B4640A"),
				}, { make("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.12, 0) }) }),
			})
			local earned = Ui.shout({
				Position = UDim2.new(0, 60, 0, 2),
				Size = UDim2.new(0.6, -60, 1, -4),
				Text = `+{mine.earned or 0} HUSS`,
				TextColor3 = GOLD,
				TextXAlignment = Enum.TextXAlignment.Left,
				Thickness = 4,
				Parent = reward,
			})
			if mine.boosted then
				local chip = Ui.shout({
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromHex("5CC8C8"),
					BackgroundTransparency = 0,
					Position = UDim2.new(1, -4, 0.5, 0),
					Size = UDim2.fromOffset(110, 30),
					Text = "x2 BOOST",
					Thickness = 2,
					Parent = reward,
				})
				corner().Parent = chip
				outline(3).Parent = chip
				make("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.12, 0), Parent = chip })
			end
			local pop = make("UIScale", { Scale = 1.5, Parent = earned })
			TweenService:Create(pop, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()

			local detail = line(52, 32)
			label({
				Size = UDim2.fromScale(0.55, 1),
				Text = `While they partied, you hit {mine.perfects} Perfects`
					.. if (mine.party or 0) > 0 then ` · {mine.party} party pts` else "",
				TextColor3 = Color3.fromHex("DCD2F5"),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = detail,
			})
			local up = (mine.levelAfter or 1) > (mine.levelBefore or 1)
			local level = Ui.shout({
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = if up then Color3.fromHex("5AD278") else Color3.fromHex("3C2D6E"),
				BackgroundTransparency = 0,
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromScale(0.43, 1),
				Text = string.upper(
					if up
						then `LEVEL UP! {mine.station} LV {mine.levelAfter}`
						else `{mine.station} LV {mine.levelAfter or 1}`
				),
				Thickness = 2,
				Parent = detail,
			})
			corner().Parent = level
			outline(3).Parent = level
			make("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.14, 0), Parent = level })
		end
		-- Size the card to its rows (padding 12 + 14, 6 between rows).
		local height = 26
		for _, child in card:GetChildren() do
			if child:IsA("Frame") then
				height += child.Size.Y.Offset + 6
			end
		end
		card.Size = UDim2.new(0.4, 0, 0, height)
	end)

	-- Phase changes: show the right screen, move the sky between night and dawn -----------------
	local function onPhase()
		local phase = ReplicatedStorage:GetAttribute("Phase")
		dusk.Visible = phase == "Dusk"
		dawn.Visible = phase == "Dawn"
		if phase ~= "Night" then
			prompt.Visible = false
		end
		local clockTime = if phase == "Dawn" then 6.3 else 0
		TweenService:Create(Lighting, TweenInfo.new(3), { ClockTime = clockTime }):Play()
	end
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(onPhase)
	onPhase()

	-- Countdowns tick once a second.
	task.spawn(function()
		while true do
			local endsAt = ReplicatedStorage:GetAttribute("PhaseEnds")
			if typeof(endsAt) == "number" then
				duskTitle.Text = `DUSK · PICK YOUR PRACTICE · {Ui.countdown(endsAt)}`
				nextNight.Text = `NEXT NIGHT IN {Ui.countdown(endsAt)}`
			end
			task.wait(0.5)
		end
	end)
end

return NightScreens
