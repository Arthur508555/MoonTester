--[[
    🌴 PARADISE UI LIBRARY 🌴
    LocalScript único - Luau / Roblox
    Tema: céu azul, grama, bolhas, nuvens, água e margaridas.

    Componentes: Janela, Abas, Seções, Label, Botão, Toggle, Slider,
                 Dropdown, TextBox, Keybind e Notificações.

    Coloque em StarterPlayerScripts (LocalScript).
    Troque RUN_DEMO para false se quiser usar apenas a library.
]]

local RUN_DEMO = true

-- ═══════════════════════════════════════════════════════════
--  Serviços
-- ═══════════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local rng = Random.new()

-- ═══════════════════════════════════════════════════════════
--  Tema
-- ═══════════════════════════════════════════════════════════
local Theme = {
	SkyTop     = Color3.fromRGB(32, 118, 210),
	SkyMid     = Color3.fromRGB(92, 176, 240),
	SkyBottom  = Color3.fromRGB(184, 228, 250),
	Grass      = Color3.fromRGB(104, 204, 76),
	GrassDark  = Color3.fromRGB(40, 142, 58),
	Water      = Color3.fromRGB(110, 214, 246),
	Daisy      = Color3.fromRGB(255, 200, 45),
	Coral      = Color3.fromRGB(255, 120, 110),
	Panel      = Color3.fromRGB(10, 56, 112),
	White      = Color3.fromRGB(255, 255, 255),
	Font       = Enum.Font.GothamMedium,
	FontBold   = Enum.Font.GothamBold,
}

-- ═══════════════════════════════════════════════════════════
--  Helpers
-- ═══════════════════════════════════════════════════════════
local function Create(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then inst.Parent = parent end
	return inst
end

local function Tween(inst, props, time, style, dir)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(time or 0.25, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

local function Corner(inst, radius)
	return Create("UICorner", { CornerRadius = radius or UDim.new(0, 10), Parent = inst })
end

local function Stroke(inst, color, transparency, thickness)
	return Create("UIStroke", {
		Color = color or Theme.White,
		Transparency = transparency or 0.7,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

local function Gradient(inst, c0, c1, rotation)
	return Create("UIGradient", {
		Color = ColorSequence.new(c0, c1),
		Rotation = rotation or 90,
		Parent = inst,
	})
end

local function Fire(callback, ...)
	if typeof(callback) == "function" then
		task.spawn(pcall, callback, ...)
	end
end

local function Round(n, decimals)
	local m = 10 ^ (decimals or 0)
	return math.floor(n * m + 0.5) / m
end

local function GetGuiParent()
	local ok, ui = pcall(function()
		return gethui and gethui()
	end)
	if ok and ui then return ui end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function MakeDraggable(handle, target, connections)
	local dragging, dragStart, startPos = false, nil, nil

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			target.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end))
end

-- Nuvem feita com formas arredondadas
local function MakeCloud(parent, scale, transparency)
	local s = scale or 1
	local cloud = Create("Frame", {
		Size = UDim2.fromOffset(96 * s, 40 * s),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = parent,
	})
	local parts = {
		{ 0, 18, 96, 22 },
		{ 14, 6, 38, 30 },
		{ 40, 0, 36, 34 },
		{ 64, 10, 28, 24 },
	}
	for _, p in ipairs(parts) do
		local f = Create("Frame", {
			Position = UDim2.fromOffset(p[1] * s, p[2] * s),
			Size = UDim2.fromOffset(p[3] * s, p[4] * s),
			BackgroundColor3 = Theme.White,
			BackgroundTransparency = transparency or 0.45,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = cloud,
		})
		Corner(f, UDim.new(1, 0))
	end
	return cloud
end

-- ═══════════════════════════════════════════════════════════
--  Library
-- ═══════════════════════════════════════════════════════════
local Paradise = {}
Paradise.__index = Paradise
Paradise.Theme = Theme

local Tab = {}
Tab.__index = Tab

function Paradise.new(config)
	config = config or {}
	local self = setmetatable({}, Paradise)

	self.Connections = {}
	self.Tabs = {}
	self.CurrentTab = nil
	self.Visible = true
	self.Collapsed = false
	self.ToggleKey = config.ToggleKey or Enum.KeyCode.RightShift

	local fullSize = config.Size or UDim2.fromOffset(620, 420)
	local W, H = fullSize.X.Offset, fullSize.Y.Offset
	self.FullHeight = H

	-- ScreenGui
	local gui = Create("ScreenGui", {
		Name = "ParadiseUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
		Parent = GetGuiParent(),
	})
	self.Gui = gui

	-- Janela principal
	local main = Create("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = fullSize,
		BackgroundColor3 = Theme.White,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = gui,
	})
	Corner(main, UDim.new(0, 20))
	Stroke(main, Theme.White, 0.35, 2)
	local sky = Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.SkyTop),
			ColorSequenceKeypoint.new(0.55, Theme.SkyMid),
			ColorSequenceKeypoint.new(1, Theme.SkyBottom),
		}),
		Rotation = 90,
		Parent = main,
	})
	local scaler = Create("UIScale", { Scale = 0, Parent = main })
	self.Main, self.Scaler = main, scaler

	-- Camada de fundo (bolhas + nuvens)
	local bg = Create("Frame", {
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 1,
		Parent = main,
	})

	-- Nuvens à deriva
	local function drift(cloud, y, duration, startX)
		task.spawn(function()
			local first = true
			while gui.Parent do
				local x0 = first and startX or -0.25
				first = false
				cloud.Position = UDim2.new(x0, 0, 0, y)
				local remaining = (1.1 - x0) / 1.35
				local tw = Tween(cloud, { Position = UDim2.new(1.1, 0, 0, y) },
					duration * remaining, Enum.EasingStyle.Linear)
				tw.Completed:Wait()
			end
		end)
	end
	drift(MakeCloud(bg, 1.1, 0.42), 22, 55, 0.15)
	drift(MakeCloud(bg, 0.7, 0.55), 70, 40, 0.6)
	drift(MakeCloud(bg, 0.9, 0.5), 130, 70, 0.9)

	-- Bolhas
	local bubbleCount = 0
	local function spawnBubble()
		if bubbleCount >= 14 or self.Collapsed or not self.Visible then return end
		bubbleCount += 1
		local size = rng:NextInteger(10, 34)
		local x = rng:NextNumber(0.02, 0.96)
		local drift = rng:NextNumber(-0.08, 0.08)
		local bubble = Create("Frame", {
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.new(x, 0, 1, size),
			BackgroundColor3 = Theme.White,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = bg,
		})
		Corner(bubble, UDim.new(1, 0))
		Stroke(bubble, Theme.White, 0.35, 1.2)
		local shine = Create("Frame", {
			Size = UDim2.fromScale(0.28, 0.28),
			Position = UDim2.fromScale(0.2, 0.18),
			BackgroundColor3 = Theme.White,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = bubble,
		})
		Corner(shine, UDim.new(1, 0))

		local tw = Tween(bubble, {
			Position = UDim2.new(x + drift, 0, 0, -size),
			BackgroundTransparency = 0.95,
		}, rng:NextNumber(6, 11), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		tw.Completed:Connect(function()
			bubbleCount -= 1
			bubble:Destroy()
		end)
	end
	task.spawn(function()
		while gui.Parent do
			spawnBubble()
			task.wait(rng:NextNumber(0.5, 1.3))
		end
	end)

	-- Barra de topo
	local topbar = Create("Frame", {
		Name = "Topbar",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = main,
	})
	Create("TextLabel", {
		Text = "🌼  " .. (config.Name or "Paradise"),
		Font = Theme.FontBold,
		TextSize = 19,
		TextColor3 = Theme.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.new(1, -140, 0, 22),
		ZIndex = 6,
		Parent = topbar,
	})
	Create("TextLabel", {
		Text = config.Subtitle or "paraíso • feito com carinho",
		Font = Theme.Font,
		TextSize = 12,
		TextColor3 = Theme.White,
		TextTransparency = 0.25,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 30),
		Size = UDim2.new(1, -140, 0, 16),
		ZIndex = 6,
		Parent = topbar,
	})

	local function topButton(text, xOffset, color)
		local b = Create("TextButton", {
			Text = text,
			Font = Theme.FontBold,
			TextSize = 16,
			TextColor3 = Theme.Panel,
			BackgroundColor3 = color,
			AutoButtonColor = false,
			Position = UDim2.new(1, xOffset, 0, 12),
			Size = UDim2.fromOffset(28, 28),
			ZIndex = 6,
			Parent = topbar,
		})
		Corner(b, UDim.new(1, 0))
		Stroke(b, Theme.White, 0.4, 1)
		b.MouseEnter:Connect(function() Tween(b, { Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, xOffset - 2, 0, 10) }, 0.15) end)
		b.MouseLeave:Connect(function() Tween(b, { Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, xOffset, 0, 12) }, 0.15) end)
		return b
	end
	local closeBtn = topButton("×", -42, Theme.Coral)
	local minBtn = topButton("–", -78, Theme.Daisy)

	MakeDraggable(topbar, main, self.Connections)

	-- Sidebar
	local sidebar = Create("Frame", {
		Name = "Sidebar",
		Position = UDim2.fromOffset(12, 58),
		Size = UDim2.new(0, 146, 1, -58 - 44),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = main,
	})
	Corner(sidebar, UDim.new(0, 14))
	Stroke(sidebar, Theme.White, 0.75, 1)
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
		Parent = sidebar,
	})
	local tabList = Create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 4,
		Parent = sidebar,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabList,
	})
	self.TabList = tabList

	-- Conteúdo
	local content = Create("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(168, 58),
		Size = UDim2.new(1, -180, 1, -58 - 44),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = main,
	})
	self.Content = content

	-- Faixa de grama inferior
	local grass = Create("Frame", {
		Name = "Grass",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = Theme.White,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = main,
	})
	Gradient(grass, Theme.Grass, Theme.GrassDark, 90)
	-- topo ondulado da grama
	for i = 0, 11 do
		local hill = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(i / 11, 0, 0, 2),
			Size = UDim2.fromOffset(rng:NextInteger(70, 110), rng:NextInteger(14, 22)),
			BackgroundColor3 = Theme.Grass,
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = grass,
		})
		Corner(hill, UDim.new(1, 0))
	end
	Create("TextLabel", {
		Text = "🌴  Paradise UI  •  " .. self.ToggleKey.Name .. " para ocultar",
		Font = Theme.FontBold,
		TextSize = 11,
		TextColor3 = Theme.White,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 1, -8),
		ZIndex = 10,
		Parent = grass,
	})
	-- margaridas balançando
	local daisies = {}
	local daisyX = { 0.03, 0.09, 0.2, 0.78, 0.91, 0.97 }
	for _, dx in ipairs(daisyX) do
		local d = Create("TextLabel", {
			Text = "🌼",
			TextSize = 16,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(dx, 0, 0, 14),
			Size = UDim2.fromOffset(20, 20),
			ZIndex = 9,
			Parent = grass,
		})
		table.insert(daisies, d)
	end

	-- Animações contínuas (céu + margaridas)
	local t0 = os.clock()
	table.insert(self.Connections, RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		sky.Rotation = 90 + math.sin(t * 0.35) * 14
		sky.Offset = Vector2.new(math.sin(t * 0.2) * 0.08, 0)
		for i, d in ipairs(daisies) do
			d.Rotation = math.sin(t * 1.6 + i) * 9
		end
	end))

	-- Notificações
	local notifHolder = Create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -18),
		Size = UDim2.new(0, 300, 1, -36),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Parent = notifHolder,
	})
	self.NotifHolder = notifHolder

	-- Controles da janela
	closeBtn.MouseButton1Click:Connect(function() self:Destroy() end)
	minBtn.MouseButton1Click:Connect(function() self:SetCollapsed(not self.Collapsed) end)

	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, gp)
		if not gp and input.KeyCode == self.ToggleKey then
			self:SetVisible(not self.Visible)
		end
	end))

	self.Elements = { sidebar = sidebar, content = content, grass = grass }

	-- Animação de abertura
	Tween(scaler, { Scale = 1 }, 0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	return self
end

function Paradise:SetVisible(state)
	self.Visible = state
	if state then
		self.Main.Visible = true
		Tween(self.Scaler, { Scale = 1 }, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	else
		local tw = Tween(self.Scaler, { Scale = 0 }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tw.Completed:Connect(function()
			if not self.Visible then self.Main.Visible = false end
		end)
	end
end

function Paradise:SetCollapsed(state)
	if self.Collapsed == state then return end
	self.Collapsed = state
	local dy = (self.FullHeight - 52) / 2
	local pos = self.Main.Position
	local width = self.Main.Size.X.Offset

	if state then
		self.Elements.sidebar.Visible = false
		self.Elements.content.Visible = false
		self.Elements.grass.Visible = false
		Tween(self.Main, {
			Size = UDim2.fromOffset(width, 52),
			Position = UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset - dy),
		}, 0.35)
	else
		Tween(self.Main, {
			Size = UDim2.fromOffset(width, self.FullHeight),
			Position = UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset + dy),
		}, 0.35).Completed:Connect(function()
			if not self.Collapsed then
				self.Elements.sidebar.Visible = true
				self.Elements.content.Visible = true
				self.Elements.grass.Visible = true
			end
		end)
	end
end

function Paradise:Destroy()
	for _, c in ipairs(self.Connections) do c:Disconnect() end
	local tw = Tween(self.Scaler, { Scale = 0 }, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	tw.Completed:Connect(function()
		if self.Gui then self.Gui:Destroy() end
	end)
end

-- ═══════════════════════════════════════════════════════════
--  Notificações
-- ═══════════════════════════════════════════════════════════
function Paradise:Notify(opts)
	opts = opts or {}
	local duration = opts.Duration or 4

	local wrapper = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Parent = self.NotifHolder,
	})
	local card = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.new(1.3, 0, 0, 0),
		BackgroundColor3 = Theme.White,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = wrapper,
	})
	Corner(card, UDim.new(0, 14))
	Stroke(card, Theme.White, 0.3, 1.5)
	Gradient(card, Theme.SkyTop, Theme.Water, 20)

	Create("TextLabel", {
		Text = "🌼  " .. (opts.Title or "Aviso"),
		Font = Theme.FontBold,
		TextSize = 14,
		TextColor3 = Theme.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 18),
		Parent = card,
	})
	Create("TextLabel", {
		Text = opts.Content or "",
		Font = Theme.Font,
		TextSize = 12,
		TextColor3 = Theme.White,
		TextTransparency = 0.1,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 28),
		Size = UDim2.new(1, -28, 0, 28),
		Parent = card,
	})
	local barBack = Create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Parent = card,
	})
	local bar = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Daisy,
		BorderSizePixel = 0,
		Parent = barBack,
	})

	Tween(wrapper, { Size = UDim2.new(1, 0, 0, 66) }, 0.3)
	task.delay(0.1, function()
		Tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.5, Enum.EasingStyle.Back)
	end)
	Tween(bar, { Size = UDim2.new(0, 0, 1, 0) }, duration, Enum.EasingStyle.Linear)

	task.delay(duration, function()
		Tween(card, { Position = UDim2.new(1.3, 0, 0, 0) }, 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.wait(0.35)
		Tween(wrapper, { Size = UDim2.new(1, 0, 0, 0) }, 0.25).Completed:Wait()
		wrapper:Destroy()
	end)
end

-- ═══════════════════════════════════════════════════════════
--  Abas
-- ═══════════════════════════════════════════════════════════
function Paradise:Tab(name, icon)
	local window = self
	local tab = setmetatable({ Window = window, Order = 0 }, Tab)

	local button = Create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.White,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = #window.Tabs + 1,
		ZIndex = 5,
		Parent = window.TabList,
	})
	Corner(button, UDim.new(0, 10))
	local indicator = Create("Frame", {
		Position = UDim2.new(0, 0, 0.2, 0),
		Size = UDim2.new(0, 4, 0.6, 0),
		BackgroundColor3 = Theme.Daisy,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = button,
	})
	Corner(indicator, UDim.new(1, 0))
	local label = Create("TextLabel", {
		Text = (icon or "🌿") .. "  " .. name,
		Font = Theme.Font,
		TextSize = 13,
		TextColor3 = Theme.White,
		TextTransparency = 0.25,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -14, 1, 0),
		ZIndex = 6,
		Parent = button,
	})

	local page = Create("ScrollingFrame", {
		Name = name,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.White,
		ScrollBarImageTransparency = 0.3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 4,
		Parent = window.Content,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8),
		Parent = page,
	})

	tab.Page, tab.Button, tab.Indicator, tab.Label = page, button, indicator, label

	function tab:Select()
		for _, other in ipairs(window.Tabs) do
			local active = (other == self)
			other.Page.Visible = active
			Tween(other.Button, { BackgroundTransparency = active and 0.7 or 1 }, 0.25)
			Tween(other.Indicator, { BackgroundTransparency = active and 0 or 1 }, 0.25)
			Tween(other.Label, { TextTransparency = active and 0 or 0.25 }, 0.25)
		end
		window.CurrentTab = self
		page.Position = UDim2.fromOffset(0, 14)
		Tween(page, { Position = UDim2.fromOffset(0, 0) }, 0.35)
	end

	button.MouseButton1Click:Connect(function() tab:Select() end)
	button.MouseEnter:Connect(function()
		if window.CurrentTab ~= tab then Tween(button, { BackgroundTransparency = 0.88 }, 0.15) end
	end)
	button.MouseLeave:Connect(function()
		if window.CurrentTab ~= tab then Tween(button, { BackgroundTransparency = 1 }, 0.15) end
	end)

	table.insert(window.Tabs, tab)
	if #window.Tabs == 1 then tab:Select() end
	return tab
end

-- ═══════════════════════════════════════════════════════════
--  Elementos
-- ═══════════════════════════════════════════════════════════
function Tab:_next()
	self.Order += 1
	return self.Order
end

local function Element(tab, height)
	local f = Create("Frame", {
		Size = UDim2.new(1, 0, 0, height or 40),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = tab:_next(),
		ZIndex = 5,
		Parent = tab.Page,
	})
	Corner(f, UDim.new(0, 12))
	Stroke(f, Theme.White, 0.78, 1)
	f.MouseEnter:Connect(function() Tween(f, { BackgroundTransparency = 0.35 }, 0.15) end)
	f.MouseLeave:Connect(function() Tween(f, { BackgroundTransparency = 0.5 }, 0.15) end)
	return f
end

local function NameLabel(parent, text, width)
	return Create("TextLabel", {
		Text = text,
		Font = Theme.Font,
		TextSize = 13,
		TextColor3 = Theme.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(width or 1, -28, 0, 38),
		ZIndex = 6,
		Parent = parent,
	})
end

function Tab:Section(text)
	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		LayoutOrder = self:_next(),
		ZIndex = 5,
		Parent = self.Page,
	})
	local dot = Create("Frame", {
		Position = UDim2.new(0, 4, 0.5, -4),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Theme.Daisy,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = holder,
	})
	Corner(dot, UDim.new(1, 0))
	Create("TextLabel", {
		Text = string.upper(text),
		Font = Theme.FontBold,
		TextSize = 12,
		TextColor3 = Theme.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -20, 1, 0),
		ZIndex = 6,
		Parent = holder,
	})
end

function Tab:Label(text)
	local f = Element(self, 34)
	local lbl = NameLabel(f, text)
	lbl.Size = UDim2.new(1, -28, 1, 0)
	lbl.TextTransparency = 0.1
	return {
		Set = function(_, t) lbl.Text = t end,
	}
end

function Tab:Button(opts)
	opts = opts or {}
	local f = Element(self, 38)
	NameLabel(f, opts.Name or "Botão")
	local icon = Create("TextLabel", {
		Text = "💧",
		TextSize = 15,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		ZIndex = 6,
		Parent = f,
	})
	local click = Create("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
		Parent = f,
	})
	click.MouseButton1Click:Connect(function()
		f.BackgroundColor3 = Theme.Grass
		f.BackgroundTransparency = 0.1
		Tween(f, { BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.35 }, 0.45)
		icon.Rotation = -25
		Tween(icon, { Rotation = 0 }, 0.5, Enum.EasingStyle.Elastic)
		Fire(opts.Callback)
	end)
end

function Tab:Toggle(opts)
	opts = opts or {}
	local state = opts.Default == true
	local f = Element(self, 38)
	NameLabel(f, opts.Name or "Toggle")

	local track = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(44, 22),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = f,
	})
	Corner(track, UDim.new(1, 0))
	Stroke(track, Theme.White, 0.6, 1)
	local knob = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Theme.White,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = track,
	})
	Corner(knob, UDim.new(1, 0))

	local api = {}
	local function render(animate)
		local t = animate and 0.25 or 0
		Tween(track, { BackgroundColor3 = state and Theme.Grass or Theme.Panel }, t)
		Tween(knob, {
			Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = state and Theme.White or Color3.fromRGB(190, 220, 245),
		}, t, Enum.EasingStyle.Back)
	end
	function api:Set(v, silent)
		state = v and true or false
		render(true)
		if not silent then Fire(opts.Callback, state) end
	end
	function api:Get() return state end

	local click = Create("TextButton", {
		Text = "", BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = f,
	})
	click.MouseButton1Click:Connect(function() api:Set(not state) end)

	render(false)
	if state then Fire(opts.Callback, state) end
	return api
end

function Tab:Slider(opts)
	opts = opts or {}
	local min, max = opts.Min or 0, opts.Max or 100
	local inc = opts.Increment or 1
	local value = math.clamp(opts.Default or min, min, max)

	local f = Element(self, 54)
	NameLabel(f, opts.Name or "Slider").Size = UDim2.new(1, -90, 0, 30)
	local valueLabel = Create("TextLabel", {
		Font = Theme.FontBold,
		TextSize = 13,
		TextColor3 = Theme.Daisy,
		TextXAlignment = Enum.TextXAlignment.Right,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 0),
		Size = UDim2.fromOffset(80, 30),
		ZIndex = 6,
		Parent = f,
	})

	local bar = Create("Frame", {
		Position = UDim2.new(0, 14, 0, 36),
		Size = UDim2.new(1, -28, 0, 8),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = f,
	})
	Corner(bar, UDim.new(1, 0))
	local fill = Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.White,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = bar,
	})
	Corner(fill, UDim.new(1, 0))
	Gradient(fill, Theme.Water, Theme.Grass, 0)
	local knob = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Theme.White,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = bar,
	})
	Corner(knob, UDim.new(1, 0))
	Stroke(knob, Theme.Daisy, 0, 2)

	local api = {}
	local function render()
		local alpha = (max == min) and 0 or (value - min) / (max - min)
		Tween(fill, { Size = UDim2.fromScale(alpha, 1) }, 0.08, Enum.EasingStyle.Linear)
		Tween(knob, { Position = UDim2.fromScale(alpha, 0.5) }, 0.08, Enum.EasingStyle.Linear)
		valueLabel.Text = tostring(Round(value, 3)) .. (opts.Suffix or "")
	end
	local function setFromX(x)
		local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		local raw = min + (max - min) * rel
		local v = math.clamp(Round(raw / inc) * inc, min, max)
		if v ~= value then
			value = v
			render()
			Fire(opts.Callback, Round(value, 3))
		end
	end
	function api:Set(v)
		value = math.clamp(v, min, max)
		render()
		Fire(opts.Callback, Round(value, 3))
	end
	function api:Get() return Round(value, 3) end

	local dragging = false
	local hit = Create("TextButton", {
		Text = "", BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 9, Parent = f,
	})
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			Tween(knob, { Size = UDim2.fromOffset(20, 20) }, 0.15, Enum.EasingStyle.Back)
			setFromX(input.Position.X)
		end
	end)
	table.insert(self.Window.Connections, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end))
	table.insert(self.Window.Connections, UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			Tween(knob, { Size = UDim2.fromOffset(16, 16) }, 0.15)
		end
	end))

	task.defer(render)
	return api
end

function Tab:Dropdown(opts)
	opts = opts or {}
	local options = opts.Options or {}
	local current = opts.Default
	local open = false

	local f = Element(self, 38)
	NameLabel(f, opts.Name or "Dropdown").Size = UDim2.new(0.5, -14, 0, 38)

	local valueLabel = Create("TextLabel", {
		Text = current and tostring(current) or "Selecionar...",
		Font = Theme.FontBold,
		TextSize = 12,
		TextColor3 = Theme.Water,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -34, 0, 0),
		Size = UDim2.new(0.5, -34, 0, 38),
		ZIndex = 6,
		Parent = f,
	})
	local arrow = Create("TextLabel", {
		Text = "▾",
		Font = Theme.FontBold,
		TextSize = 16,
		TextColor3 = Theme.White,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.fromOffset(20, 38),
		ZIndex = 6,
		Parent = f,
	})
	local list = Create("Frame", {
		Position = UDim2.fromOffset(8, 40),
		Size = UDim2.new(1, -16, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = f,
	})
	Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local api = {}
	local buttons = {}

	local function expandedHeight() return 38 + #options * 30 + 8 end
	local function refreshHighlight()
		for opt, b in pairs(buttons) do
			Tween(b, { BackgroundTransparency = (opt == current) and 0.45 or 1 }, 0.2)
		end
	end
	local function build()
		for _, b in pairs(buttons) do b:Destroy() end
		buttons = {}
		for i, opt in ipairs(options) do
			local b = Create("TextButton", {
				Text = tostring(opt),
				Font = Theme.Font,
				TextSize = 12,
				TextColor3 = Theme.White,
				BackgroundColor3 = Theme.Water,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, 28),
				LayoutOrder = i,
				ZIndex = 7,
				Parent = list,
			})
			Corner(b, UDim.new(0, 8))
			b.MouseEnter:Connect(function() if opt ~= current then Tween(b, { BackgroundTransparency = 0.8 }, 0.12) end end)
			b.MouseLeave:Connect(function() if opt ~= current then Tween(b, { BackgroundTransparency = 1 }, 0.12) end end)
			b.MouseButton1Click:Connect(function() api:Set(opt) end)
			buttons[opt] = b
		end
		refreshHighlight()
	end
	local function setOpen(state)
		open = state
		Tween(f, { Size = UDim2.new(1, 0, 0, open and expandedHeight() or 38) }, 0.3)
		Tween(arrow, { Rotation = open and 180 or 0 }, 0.3)
	end

	function api:Set(v, silent)
		current = v
		valueLabel.Text = tostring(v)
		refreshHighlight()
		setOpen(false)
		if not silent then Fire(opts.Callback, v) end
	end
	function api:Get() return current end
	function api:Refresh(newOptions)
		options = newOptions or {}
		build()
		if open then setOpen(true) end
	end

	local head = Create("TextButton", {
		Text = "", BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 38), ZIndex = 8, Parent = f,
	})
	head.MouseButton1Click:Connect(function() setOpen(not open) end)

	build()
	return api
end

function Tab:TextBox(opts)
	opts = opts or {}
	local f = Element(self, 38)
	NameLabel(f, opts.Name or "Texto").Size = UDim2.new(0.45, -14, 0, 38)

	local box = Create("TextBox", {
		Text = opts.Default or "",
		PlaceholderText = opts.Placeholder or "digite aqui...",
		PlaceholderColor3 = Color3.fromRGB(170, 205, 235),
		ClearTextOnFocus = false,
		Font = Theme.Font,
		TextSize = 12,
		TextColor3 = Theme.White,
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.25,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0.55, -8, 0, 26),
		ZIndex = 7,
		Parent = f,
	})
	Corner(box, UDim.new(0, 8))
	local stroke = Stroke(box, Theme.White, 0.75, 1)
	box.Focused:Connect(function() Tween(stroke, { Transparency = 0, Color = Theme.Daisy }, 0.2) end)
	box.FocusLost:Connect(function(enter)
		Tween(stroke, { Transparency = 0.75, Color = Theme.White }, 0.2)
		Fire(opts.Callback, box.Text, enter)
	end)

	return {
		Set = function(_, t) box.Text = t end,
		Get = function() return box.Text end,
	}
end

function Tab:Keybind(opts)
	opts = opts or {}
	local key = opts.Default or Enum.KeyCode.F
	local listening = false

	local f = Element(self, 38)
	NameLabel(f, opts.Name or "Keybind").Size = UDim2.new(0.6, -14, 0, 38)

	local btn = Create("TextButton", {
		Text = key.Name,
		Font = Theme.FontBold,
		TextSize = 12,
		TextColor3 = Theme.Panel,
		BackgroundColor3 = Theme.Daisy,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(86, 26),
		ZIndex = 7,
		Parent = f,
	})
	Corner(btn, UDim.new(0, 8))

	btn.MouseButton1Click:Connect(function()
		listening = true
		btn.Text = "..."
		Tween(btn, { BackgroundColor3 = Theme.Water }, 0.2)
	end)

	table.insert(self.Window.Connections, UserInputService.InputBegan:Connect(function(input, gp)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				listening = false
				if input.KeyCode ~= Enum.KeyCode.Escape then key = input.KeyCode end
				btn.Text = key.Name
				Tween(btn, { BackgroundColor3 = Theme.Daisy }, 0.2)
				Fire(opts.Changed, key)
			end
		elseif not gp and input.KeyCode == key then
			Fire(opts.Callback, key)
		end
	end))

	return {
		Get = function() return key end,
		Set = function(_, k) key = k; btn.Text = k.Name end,
	}
end

-- ═══════════════════════════════════════════════════════════
--  DEMO (apague ou ponha RUN_DEMO = false)
-- ═══════════════════════════════════════════════════════════
if RUN_DEMO then
	local Window = Paradise.new({
		Name = "Paradise Hub",
		Subtitle = "sol, água e boas vibrações",
		ToggleKey = Enum.KeyCode.RightShift,
	})

	local Main = Window:Tab("Principal", "🌴")
	Main:Section("Ações")
	Main:Label("Bem-vindo ao paraíso! Arraste a barra de cima para mover.")
	Main:Button({
		Name = "Mostrar notificação",
		Callback = function()
			Window:Notify({ Title = "Paraíso", Content = "Tudo funcionando perfeitamente!", Duration = 4 })
		end,
	})
	Main:Toggle({
		Name = "Modo ensolarado",
		Default = true,
		Callback = function(v) print("Ensolarado:", v) end,
	})
	Main:Section("Ajustes")
	Main:Slider({
		Name = "Velocidade",
		Min = 0, Max = 100, Default = 40, Suffix = "%",
		Callback = function(v) print("Velocidade:", v) end,
	})
	Main:Slider({
		Name = "Brilho",
		Min = 0, Max = 1, Increment = 0.05, Default = 0.7,
		Callback = function(v) print("Brilho:", v) end,
	})

	local Extra = Window:Tab("Extras", "🌊")
	Extra:Section("Seleção")
	Extra:Dropdown({
		Name = "Ilha",
		Options = { "Bora Bora", "Maldivas", "Fernando de Noronha", "Havaí" },
		Default = "Fernando de Noronha",
		Callback = function(v) print("Ilha:", v) end,
	})
	Extra:TextBox({
		Name = "Apelido",
		Placeholder = "seu nome...",
		Callback = function(text) print("Apelido:", text) end,
	})
	Extra:Keybind({
		Name = "Tecla de ação",
		Default = Enum.KeyCode.E,
		Callback = function() Window:Notify({ Title = "Tecla", Content = "Você apertou a tecla!", Duration = 2 }) end,
	})

	local Config = Window:Tab("Config", "🌼")
	Config:Section("Interface")
	Config:Button({ Name = "Fechar interface", Callback = function() Window:Destroy() end })

	task.delay(0.8, function()
		Window:Notify({ Title = "Bem-vindo 🌴", Content = "Paradise UI carregada com sucesso.", Duration = 5 })
	end)
end

return Paradise