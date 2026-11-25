--[[
    🌴 PARADISE UI LIBRARY 🌴
    ModuleScript / library única - Luau / Roblox
    Tema: céu azul, água, nuvens e detalhes tropicais.

    API nativa Paradise + adaptador de componentes compatíveis com Rayfield.
    A demonstração fica em ParadiseUI_Demo.lua (arquivo separado).
]]

-- ═══════════════════════════════════════════════════════════
--  Serviços
-- ═══════════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local rng = Random.new()

local Diagnostics = {
    Events = {},
    MaxEvents = 80,
    ComponentErrors = 0,
    CallbackErrors = 0,
}

function Diagnostics.Log(level, code, message)
    local event = {
        Time = os.clock(),
        Level = tostring(level or "INFO"),
        Code = tostring(code or "GENERAL"),
        Message = tostring(message or ""),
    }
    table.insert(Diagnostics.Events, event)
    while #Diagnostics.Events > Diagnostics.MaxEvents do
        table.remove(Diagnostics.Events, 1)
    end

    local output = string.format("[ParadiseUI][%s][%s] %s", event.Level, event.Code, event.Message)
    if event.Level == "ERROR" or event.Level == "WARN" then
        warn(output)
    else
        print(output)
    end
    return event
end

local function ErrorTrace(err)
    local message = tostring(err)
    if debug and type(debug.traceback) == "function" then
        return debug.traceback(message, 2)
    end
    return message
end

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
    if typeof(callback) ~= "function" then
        return
    end

    local args = table.pack(...)
    task.spawn(function()
        local ok, err = pcall(function()
            callback(table.unpack(args, 1, args.n))
        end)
        if not ok then
            Diagnostics.CallbackErrors += 1
            Diagnostics.Log("ERROR", "CALLBACK_FAILED", ErrorTrace(err))
        end
    end)
end

local function Round(n, decimals)
	local m = 10 ^ (decimals or 0)
	return math.floor(n * m + 0.5) / m
end

local function GetGuiParent()
    -- Preferência: GUI do executor, quando a função existir.
    local ok, ui = pcall(function()
        if type(gethui) == "function" then
            return gethui()
        end
        return nil
    end)
    if ok and ui then
        Diagnostics.Log("INFO", "GUI_PARENT", "Usando gethui().")
        return ui
    end

    -- Fallback padrão: PlayerGui.
    local player = Players.LocalPlayer
    if not player then
        local okPlayer, result = pcall(function()
            return Players.PlayerAdded:Wait()
        end)
        if okPlayer then player = result end
    end

    if player then
        local okGui, playerGui = pcall(function()
            return player:FindFirstChildOfClass("PlayerGui")
                or player:WaitForChild("PlayerGui", 10)
        end)
        if okGui and playerGui then
            Diagnostics.Log("INFO", "GUI_PARENT_FALLBACK", "gethui indisponível; usando PlayerGui.")
            return playerGui
        end
    end

    -- Último fallback; permissões variam conforme o ambiente.
    local okCore, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if okCore and coreGui then
        Diagnostics.Log("WARN", "GUI_PARENT_COREGUI", "PlayerGui indisponível; tentando CoreGui.")
        return coreGui
    end

    Diagnostics.Log("ERROR", "GUI_PARENT_NOT_FOUND", "Nenhum parent de GUI válido foi encontrado.")
    error("[ParadiseUI] Nenhum parent de GUI disponível (gethui, PlayerGui ou CoreGui).")
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
	self.__ParadiseType = "Window"
	self.ComponentCount = 0
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
	self.Diagnostics = Diagnostics
	Paradise._activeWindow = self

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
		Size = UDim2.new(0, 146, 1, -58 - 36),
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
		Size = UDim2.new(1, -180, 1, -58 - 36),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = main,
	})
	self.Content = content

	-- Barra inferior vazia no estilo Rayfield: área de arraste sem texto.
	-- Ela fica insetada para não atravessar os cantos arredondados da janela.
	local dragbar = Create("Frame", {
		Name = "BottomDragBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -36, 0, 20),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = main,
	})
	Corner(dragbar, UDim.new(1, 0))
	local grip = Create("Frame", {
		Name = "Grip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(38, 3),
		BackgroundColor3 = Theme.White,
		BackgroundTransparency = 0.48,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = dragbar,
	})
	Corner(grip, UDim.new(1, 0))
	MakeDraggable(dragbar, main, self.Connections)

	-- Animação contínua apenas do fundo.
	local t0 = os.clock()
	table.insert(self.Connections, RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		sky.Rotation = 90 + math.sin(t * 0.35) * 14
		sky.Offset = Vector2.new(math.sin(t * 0.2) * 0.08, 0)
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

	self.Elements = { sidebar = sidebar, content = content, dragbar = dragbar }

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
		self.Elements.dragbar.Visible = false
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
				self.Elements.dragbar.Visible = true
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
	-- Também permite o padrão Rayfield:Notify(...) na tabela do módulo.
	if not self.NotifHolder then
		local active = Paradise._activeWindow
		if active and active.NotifHolder then
			return active:Notify(opts)
		end
		return
	end
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
	local tab = setmetatable({ Window = window, Order = 0, ComponentCount = 0, __ParadiseType = "Tab" }, Tab)

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

	-- Campos visuais não podem ter o mesmo nome dos métodos públicos da Tab.
	-- Antes, Button e Label sobrescreviam Tab:Button() e Tab:Label().
	tab.Page = page
	tab.TabButton = button
	tab.TabIndicator = indicator
	tab.TabLabel = label

	function tab:Select()
		for _, other in ipairs(window.Tabs) do
			local active = (other == self)
			other.Page.Visible = active
			Tween(other.TabButton, { BackgroundTransparency = active and 0.7 or 1 }, 0.25)
			Tween(other.TabIndicator, { BackgroundTransparency = active and 0 or 1 }, 0.25)
			Tween(other.TabLabel, { TextTransparency = active and 0 or 0.25 }, 0.25)
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
	local sectionLabel = Create("TextLabel", {
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
	return {
		Set = function(_, value) sectionLabel.Text = string.upper(tostring(value)) end,
		Destroy = function() holder:Destroy() end,
	}
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
	local titleLabel = NameLabel(f, opts.Name or "Botão")
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
	return {
		Set = function(_, value) titleLabel.Text = tostring(value) end,
		Destroy = function() f:Destroy() end,
	}
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
	local multiple = opts.Multiple == true
	local current = opts.Default
	if multiple then
		if type(current) ~= "table" then current = current ~= nil and { current } or {} end
	else
		if type(current) == "table" then current = current[1] end
	end
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

	local function isSelected(opt)
		if multiple then
			for _, selected in ipairs(current) do
				if selected == opt then return true end
			end
			return false
		end
		return opt == current
	end
	local function displayValue()
		if multiple then return #current > 0 and table.concat(current, ", ") or "Selecionar..." end
		return current ~= nil and tostring(current) or "Selecionar..."
	end
	local function expandedHeight() return 38 + #options * 30 + 8 end
	local function refreshHighlight()
		for opt, b in pairs(buttons) do
			Tween(b, { BackgroundTransparency = isSelected(opt) and 0.45 or 1 }, 0.2)
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
			b.MouseEnter:Connect(function() if not isSelected(opt) then Tween(b, { BackgroundTransparency = 0.8 }, 0.12) end end)
			b.MouseLeave:Connect(function() if not isSelected(opt) then Tween(b, { BackgroundTransparency = 1 }, 0.12) end end)
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
		if multiple then
			if type(v) == "table" then
				current = table.clone(v)
			else
				local found
				for i, selected in ipairs(current) do
					if selected == v then table.remove(current, i); found = true; break end
				end
				if not found then table.insert(current, v) end
			end
		else
			current = type(v) == "table" and v[1] or v
		end
		valueLabel.Text = displayValue()
		refreshHighlight()
		if not multiple then setOpen(false) end
		if not silent then Fire(opts.Callback, multiple and table.clone(current) or current) end
	end
	function api:Get() return multiple and table.clone(current) or current end
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

	valueLabel.Text = displayValue()
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
		local value = box.Text
		Fire(opts.Callback, value, enter)
		if opts.RemoveTextAfterFocusLost then box.Text = "" end
	end)

	return {
		Set = function(_, t) box.Text = t end,
		Get = function() return box.Text end,
	}
end

function Tab:Keybind(opts)
	opts = opts or {}
	local key = opts.Default or Enum.KeyCode.F
	if type(key) == "string" then
		local ok, parsed = pcall(function() return Enum.KeyCode[key] end)
		if ok and parsed then key = parsed else key = Enum.KeyCode.F end
	end
	local listening = false
	local held = false

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
				Fire(opts.Changed or opts.ChangedCallback, key)
			end
		elseif not gp and input.KeyCode == key then
			if opts.HoldToInteract then
				held = true
				Fire(opts.Callback, true)
			else
				Fire(opts.Callback, key)
			end
		end
	end))
	if opts.HoldToInteract then
		table.insert(self.Window.Connections, UserInputService.InputEnded:Connect(function(input)
			if held and input.KeyCode == key then
				held = false
				Fire(opts.Callback, false)
			end
		end))
	end

	return {
		Get = function() return key end,
		Set = function(_, k)
			if type(k) == "string" then k = Enum.KeyCode[k] end
			if typeof(k) == "EnumItem" then key = k; btn.Text = k.Name end
		end,
	}
end

-- ═══════════════════════════════════════════════════════════
--  Controles adicionais da Paradise
-- ═══════════════════════════════════════════════════════════
function Tab:Checkbox(opts)
    opts = opts or {}
    local state = opts.Default == true or opts.CurrentValue == true
    local f = Element(self, 38)
    NameLabel(f, opts.Name or "Checkbox")

    local box = Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(20, 20),
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = f,
    })
    Corner(box, UDim.new(0, 6))
    Stroke(box, Theme.White, 0.55, 1)
    local tick = Create("TextLabel", {
        Text = "✓",
        Font = Theme.FontBold,
        TextSize = 15,
        TextColor3 = Theme.White,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        TextTransparency = state and 0 or 1,
        ZIndex = 7,
        Parent = box,
    })
    local api = {}
    function api:Set(value, silent)
        state = value == true
        Tween(box, { BackgroundColor3 = state and Theme.Grass or Theme.Panel }, 0.18)
        Tween(tick, { TextTransparency = state and 0 or 1 }, 0.15)
        if not silent then Fire(opts.Callback, state) end
    end
    function api:Get() return state end

    local click = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = f,
    })
    click.MouseButton1Click:Connect(function() api:Set(not state) end)
    api:Set(state, true)
    return api
end

function Tab:Paragraph(opts)
    opts = opts or {}
    local f = Element(self, opts.Height or 76)
    local title = Create("TextLabel", {
        Text = tostring(opts.Title or "Informação"),
        Font = Theme.FontBold,
        TextSize = 13,
        TextColor3 = Theme.White,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 8),
        Size = UDim2.new(1, -28, 0, 20),
        ZIndex = 6,
        Parent = f,
    })
    local body = Create("TextLabel", {
        Text = tostring(opts.Content or ""),
        Font = Theme.Font,
        TextSize = 12,
        TextColor3 = Theme.White,
        TextTransparency = 0.18,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 30),
        Size = UDim2.new(1, -28, 1, -38),
        ZIndex = 6,
        Parent = f,
    })
    return {
        Set = function(_, content) body.Text = tostring(content) end,
        SetTitle = function(_, value) title.Text = tostring(value) end,
        Destroy = function() f:Destroy() end,
    }
end

function Tab:Divider(text)
    local holder = Create("Frame", {
        Size = UDim2.new(1, 0, 0, text and 30 or 16),
        BackgroundTransparency = 1,
        LayoutOrder = self:_next(),
        ZIndex = 5,
        Parent = self.Page,
    })
    local line = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, text and 0.72 or 0.5),
        Size = UDim2.new(1, -14, 0, 1),
        BackgroundColor3 = Theme.White,
        BackgroundTransparency = 0.72,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = holder,
    })
    if text then
        Create("TextLabel", {
            Text = string.upper(tostring(text)),
            Font = Theme.FontBold,
            TextSize = 10,
            TextColor3 = Theme.White,
            TextTransparency = 0.2,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(4, 0),
            Size = UDim2.new(1, -8, 0, 16),
            ZIndex = 6,
            Parent = holder,
        })
    end
    return { Destroy = function() holder:Destroy() end }
end

function Tab:ColorPicker(opts)
    opts = opts or {}
    local colors = {
        Color3.fromRGB(255, 105, 97), Color3.fromRGB(255, 180, 70),
        Color3.fromRGB(255, 220, 90), Color3.fromRGB(104, 204, 76),
        Color3.fromRGB(90, 210, 170), Color3.fromRGB(75, 190, 235),
        Color3.fromRGB(75, 125, 235), Color3.fromRGB(150, 105, 220),
        Color3.fromRGB(225, 115, 190), Color3.fromRGB(255, 255, 255),
    }
    local selected = typeof(opts.Default or opts.Color) == "Color3" and (opts.Default or opts.Color) or colors[6]
    local expanded = false
    local f = Element(self, 40)
    NameLabel(f, opts.Name or "Cor")
    local preview = Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0, 20),
        Size = UDim2.fromOffset(34, 20),
        BackgroundColor3 = selected,
        BorderSizePixel = 0,
        ZIndex = 7,
        Parent = f,
    })
    Corner(preview, UDim.new(0, 6))
    Stroke(preview, Theme.White, 0.45, 1)

    local palette = Create("Frame", {
        Position = UDim2.fromOffset(10, 42),
        Size = UDim2.new(1, -20, 0, 42),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 7,
        Parent = f,
    })
    Create("UIGridLayout", {
        CellSize = UDim2.fromOffset(24, 18),
        CellPadding = UDim2.fromOffset(7, 4),
        FillDirectionMaxCells = 5,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = palette,
    })
    local api = {}
    local function setColor(color, silent)
        if typeof(color) ~= "Color3" then return end
        selected = color
        preview.BackgroundColor3 = color
        if not silent then Fire(opts.Callback, color) end
    end
    function api:Set(color, silent) setColor(color, silent) end
    function api:Get() return selected end

    for index, color in ipairs(colors) do
        local swatch = Create("TextButton", {
            Text = "", AutoButtonColor = false,
            BackgroundColor3 = color, BorderSizePixel = 0,
            LayoutOrder = index, ZIndex = 8, Parent = palette,
        })
        Corner(swatch, UDim.new(0, 5))
        Stroke(swatch, Theme.White, 0.5, 1)
        swatch.MouseButton1Click:Connect(function()
            setColor(color)
            expanded = false
            palette.Visible = false
            Tween(f, { Size = UDim2.new(1, 0, 0, 40) }, 0.2)
        end)
    end

    local head = Create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 40), ZIndex = 9, Parent = f,
    })
    head.MouseButton1Click:Connect(function()
        expanded = not expanded
        palette.Visible = expanded
        Tween(f, { Size = UDim2.new(1, 0, 0, expanded and 94 or 40) }, 0.22)
    end)
    return api
end

-- ═══════════════════════════════════════════════════════════
--  Adaptador de API: Paradise também entende a forma clássica do Rayfield.
--  Métodos e propriedades usam PascalCase, como nos exemplos do Rayfield.
-- ═══════════════════════════════════════════════════════════
local function ReadKey(config, primary, fallback)
    local value = config[primary]
    if value == nil and fallback then value = config[fallback] end
    return value
end

local function ParseKey(value, defaultValue)
    if typeof(value) == "EnumItem" then return value end
    if type(value) == "string" then
        local ok, parsed = pcall(function() return Enum.KeyCode[value] end)
        if ok and parsed then return parsed end
    end
    return defaultValue or Enum.KeyCode.RightShift
end

function Paradise:CreateWindow(config)
    config = config or {}
    local key = ParseKey(ReadKey(config, "ToggleUIKeybind", "ToggleKey"), Enum.KeyCode.RightShift)
    local window = Paradise.new({
        Name = ReadKey(config, "Name", "name") or "Paradise UI",
        Subtitle = ReadKey(config, "LoadingSubtitle", "Subtitle") or "uma interface tropical",
        ToggleKey = key,
        Size = config.Size,
    })
    window.Configuration = config
    window.Flags = {}
    return window
end

function Paradise:CreateTab(name, icon)
    if type(name) == "table" then
        icon = name.Icon or name.icon or icon
        name = name.Name or name.name or "Tab"
    end
    -- A numeric Rayfield asset id is not an emoji; use a clean default icon instead.
    if type(icon) == "number" then icon = nil end
    return self:Tab(tostring(name or "Tab"), icon)
end

function Paradise:Unload()
    return self:Destroy()
end

function Tab:CreateSection(name)
    if type(name) == "table" then name = name.Name or name.name end
    return self:Section(tostring(name or "Section"))
end

function Tab:CreateButton(opts)
    opts = opts or {}
    return self:Button({ Name = opts.Name or opts.name, Callback = opts.Callback or opts.callback })
end

function Tab:CreateToggle(opts)
    opts = opts or {}
    local flag = opts.Flag or opts.flag
    local initial = opts.CurrentValue
    if initial == nil then initial = opts.Default end
    local control = self:Toggle({
        Name = opts.Name or opts.name,
        Default = initial,
        Callback = opts.Callback or opts.callback,
    })
    if flag then self.Window.Flags[flag] = control:Get() end
    return control
end

function Tab:CreateCheckbox(opts)
    opts = opts or {}
    local control = self:Checkbox({
        Name = opts.Name or opts.name,
        CurrentValue = opts.CurrentValue,
        Default = opts.Default,
        Callback = opts.Callback or opts.callback,
    })
    local flag = opts.Flag or opts.flag
    if flag then self.Window.Flags[flag] = control:Get() end
    return control
end

function Tab:CreateSlider(opts)
    opts = opts or {}
    local range = opts.Range or opts.range or { opts.Min or 0, opts.Max or 100 }
    local initial = opts.CurrentValue
    if initial == nil then initial = opts.Default end
    local control = self:Slider({
        Name = opts.Name or opts.name,
        Min = range[1] or 0,
        Max = range[2] or 100,
        Increment = opts.Increment or opts.increment or 1,
        Default = initial,
        Suffix = opts.Suffix or opts.suffix or "",
        Callback = opts.Callback or opts.callback,
    })
    local flag = opts.Flag or opts.flag
    if flag then self.Window.Flags[flag] = control:Get() end
    return control
end

function Tab:CreateDropdown(opts)
    opts = opts or {}
    local multiple = opts.MultipleOptions == true or opts.Multiple == true
    local current = opts.CurrentOption
    if current == nil then current = opts.Default end
    if not multiple and type(current) == "table" then current = current[1] end
    local callback = opts.Callback or opts.callback
    local control = self:Dropdown({
        Name = opts.Name or opts.name,
        Options = opts.Options or opts.options or {},
        Default = current,
        Multiple = multiple,
        Callback = function(value)
            if callback then
                if multiple then Fire(callback, value) else Fire(callback, value ~= nil and { value } or {}) end
            end
        end,
    })
    local flag = opts.Flag or opts.flag
    if flag then self.Window.Flags[flag] = control:Get() end
    return control
end

function Tab:CreateInput(opts)
    opts = opts or {}
    return self:TextBox({
        Name = opts.Name or opts.name,
        Default = opts.CurrentValue or opts.Default or "",
        Placeholder = opts.PlaceholderText or opts.Placeholder or "Digite aqui...",
        RemoveTextAfterFocusLost = opts.RemoveTextAfterFocusLost == true,
        Callback = opts.Callback or opts.callback,
    })
end

function Tab:CreateKeybind(opts)
    opts = opts or {}
    return self:Keybind({
        Name = opts.Name or opts.name,
        Default = ParseKey(opts.CurrentKeybind or opts.Default, Enum.KeyCode.F),
        HoldToInteract = opts.HoldToInteract == true,
        Callback = opts.Callback or opts.callback,
        ChangedCallback = opts.ChangedCallback or opts.Changed,
    })
end

function Tab:CreateLabel(text)
    if type(text) == "table" then text = text.Text or text.Name or "Label" end
    return self:Label(tostring(text or "Label"))
end

function Tab:CreateParagraph(opts)
    return self:Paragraph(opts)
end

function Tab:CreateColorPicker(opts)
    return self:ColorPicker(opts)
end

function Tab:CreateDivider(opts)
    local text = type(opts) == "table" and (opts.Text or opts.Name) or opts
    return self:Divider(text)
end

function Tab:CreateTextBox(opts)
    return self:CreateInput(opts)
end

-- Friendly aliases for scripts that mix Paradise and Rayfield naming.
Tab.CreateText = Tab.CreateLabel
Tab.CreateToggleSwitch = Tab.CreateToggle
Tab.CreateCheckBox = Tab.CreateCheckbox

Paradise.Version = "2.1.0-diagnostics"
Paradise.Diagnostics = Diagnostics
Paradise.__ParadiseLibrary = true

function Diagnostics.DetectExecutionContext()
    local context = "DynamicChunk / executor / loadstring (não confirmado)"
    local scriptObject
    pcall(function() scriptObject = script end)

    if typeof(scriptObject) == "Instance" then
        if scriptObject:IsA("ModuleScript") then
            context = "ModuleScript"
        elseif scriptObject:IsA("LocalScript") then
            context = "LocalScript ou chunk chamado por LocalScript"
        elseif scriptObject:IsA("Script") then
            context = "Script ou chunk chamado por Script"
        else
            context = scriptObject.ClassName
        end
    end
    return context
end

function Diagnostics.CheckLibrary(value)
    local target = value or Paradise
    local problems = {}
    if type(target) ~= "table" then
        table.insert(problems, "O resultado da library não é uma table.")
    else
        for _, methodName in ipairs({"new", "CreateWindow", "CreateTab"}) do
            if type(target[methodName]) ~= "function" then
                table.insert(problems, "Método ausente: " .. methodName)
            end
        end
        if target.__ParadiseLibrary ~= true then
            table.insert(problems, "Assinatura da Paradise ausente; possível versão antiga ou objeto incorreto.")
        end
    end

    if #problems > 0 then
        Diagnostics.Log("ERROR", "LIBRARY_VALIDATION_FAILED", table.concat(problems, " | "))
        return false, problems
    end
    Diagnostics.Log("INFO", "LIBRARY_VALIDATED", "API principal da Paradise encontrada.")
    return true, problems
end

function Diagnostics.CheckWindow(window)
    local problems = {}
    if type(window) ~= "table" then
        table.insert(problems, "Window não é uma table.")
    else
        if getmetatable(window) ~= Paradise then
            table.insert(problems, "Metatable da Window não corresponde à classe Paradise.")
        end
        if not window.Gui or not window.Main or not window.Content then
            table.insert(problems, "Window sem Gui, Main ou Content.")
        end
        if not window.Elements or not window.Tabs then
            table.insert(problems, "Window sem Elements ou Tabs.")
        end
    end

    if #problems > 0 then
        Diagnostics.Log("ERROR", "WINDOW_VALIDATION_FAILED", table.concat(problems, " | "))
        return false, problems
    end
    Diagnostics.Log("INFO", "WINDOW_VALIDATED", "Metatable e estrutura da Window corretas.")
    return true, problems
end

function Diagnostics.CheckTab(tab)
    local problems = {}
    if type(tab) ~= "table" then
        table.insert(problems, "Tab não é uma table.")
    else
        if getmetatable(tab) ~= Tab then
            table.insert(problems, "Metatable da Tab não corresponde à classe Tab.")
        end

        for _, methodName in ipairs({
            "Section", "Label", "Button", "Toggle", "Slider", "Dropdown",
            "TextBox", "Keybind", "Checkbox", "Paragraph", "Divider",
            "ColorPicker", "CreateButton", "CreateToggle", "CreateSlider",
            "CreateDropdown", "CreateLabel", "CreateCheckbox",
        }) do
            if type(tab[methodName]) ~= "function" then
                table.insert(problems, "Método ausente ou sombreado: " .. methodName)
            end
        end

        if tab.TabButton == nil or tab.TabLabel == nil or tab.TabIndicator == nil then
            table.insert(problems, "Elementos visuais internos da Tab incompletos.")
        end
        if typeof(tab.Button) == "Instance" then
            table.insert(problems, "Campo Button está sombreando um método; deveria ser TabButton.")
        end
        if typeof(tab.Label) == "Instance" then
            table.insert(problems, "Campo Label está sombreando um método; deveria ser TabLabel.")
        end
    end

    if #problems > 0 then
        Diagnostics.Log("ERROR", "TAB_VALIDATION_FAILED", table.concat(problems, " | "))
        return false, problems
    end
    Diagnostics.Log("INFO", "TAB_VALIDATED", "Metatable e métodos da Tab corretos.")
    return true, problems
end

function Diagnostics.CheckComponent(component, name)
    if type(component) ~= "table" then
        Diagnostics.Log("ERROR", "COMPONENT_MISSING", tostring(name or "Componente") .. " não retornou um handle válido.")
        return false
    end
    Diagnostics.Log("INFO", "COMPONENT_CREATED", tostring(name or "Componente") .. " criado.")
    return true
end

function Diagnostics.CheckUsage()
    local active = Paradise._activeWindow
    if not active then
        Diagnostics.Log("WARN", "LIBRARY_ONLY_NO_WINDOW", "A library foi carregada, mas nenhuma janela foi criada. Para exibir UI, chame Paradise:CreateWindow(...).")
        return false
    end
    if not active.Gui or not active.Gui.Parent then
        Diagnostics.Log("ERROR", "WINDOW_NOT_PARENTED", "A Window existe, mas a ScreenGui não está parentada.")
        return false
    end
    return Diagnostics.CheckWindow(active)
end

function Diagnostics.CheckEnvironment()
    local results = {}
    local function add(name, passed, detail, optional)
        table.insert(results, {
            Name = name,
            Passed = passed == true,
            Optional = optional == true,
            Details = detail or "",
        })
        if passed then
            Diagnostics.Log("INFO", "ENV_OK", name .. ": " .. (detail or "OK"))
        elseif optional then
            Diagnostics.Log("WARN", "ENV_OPTIONAL_MISSING", name .. ": " .. (detail or "não disponível"))
        else
            Diagnostics.Log("ERROR", "ENV_REQUIRED_MISSING", name .. ": " .. (detail or "não disponível"))
        end
    end

    add("Instance.new", type(Instance) == "table" and type(Instance.new) == "function",
        "Criação de instâncias Roblox.")
    add("game:GetService", game ~= nil and type(game.GetService) == "function",
        "Acesso aos serviços.")
    local hasTweenService = pcall(function() game:GetService("TweenService") end)
    add("TweenService", hasTweenService, "Animações da interface.")
    local hasInputService = pcall(function() game:GetService("UserInputService") end)
    add("UserInputService", hasInputService, "Entrada de mouse/teclado.")
    add("loadstring", type(loadstring) == "function",
        "Necessário somente para carregar código remoto; não é exigido com require(ModuleScript).", true)
    add("gethui", type(gethui) == "function",
        "Opcional; a biblioteca tenta PlayerGui quando está ausente.", true)

    local player = Players.LocalPlayer
    add("LocalPlayer", player ~= nil,
        player and ("Jogador: " .. player.Name) or "LocalPlayer não foi encontrado.")
    local hasPlayerGui = false
    if player then
        hasPlayerGui = pcall(function()
            return player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 2)
        end)
    end
    local hasGuiFallback = type(gethui) == "function" or hasPlayerGui
    add("GUI parent fallback", hasGuiFallback,
        "Precisa de gethui() ou PlayerGui.")
    return results
end

function Diagnostics.SelfTest(window, tab)
    local results = {}
    local function add(name, ok, details)
        table.insert(results, { Name = name, Passed = ok == true, Details = details or "" })
    end

    local libOk = Diagnostics.CheckLibrary(Paradise)
    add("Library/API", libOk)

    local environment = Diagnostics.CheckEnvironment()
    local requiredEnvironmentOk = true
    for _, item in ipairs(environment) do
        if not item.Passed and not item.Optional then
            requiredEnvironmentOk = false
        end
    end
    add("Runtime environment", requiredEnvironmentOk, "Verifique o relatório para detalhes do ambiente.")

    local probe = setmetatable({ Window = {}, Order = 0 }, Tab)
    local methodsOk = type(probe.Label) == "function"
        and type(probe.Button) == "function"
        and type(probe.CreateLabel) == "function"
        and type(probe.CreateButton) == "function"
    add("Tab metatable / method collision", methodsOk,
        methodsOk and "Métodos não estão sombreados." or "Campo está ocultando um método da Tab.")
    add("Execution context", true, Diagnostics.DetectExecutionContext())

    if window then
        local ok, issues = Diagnostics.CheckWindow(window)
        add("Window metatable", ok, table.concat(issues, " | "))
    end
    if tab then
        local ok, issues = Diagnostics.CheckTab(tab)
        add("Tab metatable", ok, table.concat(issues, " | "))
    end

    local passed = 0
    for _, item in ipairs(results) do
        if item.Passed then passed += 1 end
    end
    Diagnostics.Log(passed == #results and "INFO" or "WARN", "SELF_TEST",
        string.format("%d/%d verificações passaram.", passed, #results))
    return passed == #results, results
end

function Diagnostics.Report()
    local output = {
        "ParadiseUI " .. tostring(Paradise.Version),
        "Contexto: " .. Diagnostics.DetectExecutionContext(),
        "Erros de componentes: " .. tostring(Diagnostics.ComponentErrors),
        "Erros de callbacks: " .. tostring(Diagnostics.CallbackErrors),
        "Componentes criados: " .. tostring(Paradise._activeWindow and Paradise._activeWindow.ComponentCount or 0),
        "Eventos armazenados: " .. tostring(#Diagnostics.Events),
    }
    for _, event in ipairs(Diagnostics.Events) do
        table.insert(output, string.format("[%s][%s] %s", event.Level, event.Code, event.Message))
    end
    return table.concat(output, "\n")
end

-- Loader opcional com checagem de HttpGet, loadstring, compilação e retorno.
function Paradise.Load(url)
    if type(url) ~= "string" or url == "" then
        Diagnostics.Log("ERROR", "LOAD_URL_INVALID", "URL vazia ou inválida.")
        return nil, "URL inválida."
    end
    if type(loadstring) ~= "function" then
        Diagnostics.Log("ERROR", "LOADSTRING_UNAVAILABLE", "loadstring não está disponível neste ambiente.")
        return nil, "loadstring indisponível; use require(ModuleScript) ou um carregador compatível."
    end

    local okHttp, source = pcall(function() return game:HttpGet(url) end)
    if not okHttp or type(source) ~= "string" or source == "" then
        Diagnostics.Log("ERROR", "HTTP_GET_FAILED", tostring(source))
        return nil, "Falha no HttpGet: " .. tostring(source)
    end

    local okCompile, chunk, compileError = pcall(loadstring, source)
    if not okCompile or type(chunk) ~= "function" then
        local reason = okCompile and compileError or chunk
        Diagnostics.Log("ERROR", "COMPILE_FAILED", tostring(reason))
        return nil, "Falha de compilação: " .. tostring(reason)
    end

    local okRun, result = pcall(chunk)
    if not okRun then
        Diagnostics.Log("ERROR", "LIBRARY_RUNTIME_FAILED", ErrorTrace(result))
        return nil, "Falha na inicialização: " .. tostring(result)
    end

    local valid, issues = Diagnostics.CheckLibrary(result)
    if not valid then
        return nil, "Retorno inválido da library: " .. table.concat(issues, " | ")
    end
    return result
end

-- Protege cada método de criação: um controle com falha é registrado,
-- mas não impede os controles seguintes de serem criados.
local function GuardMethod(classTable, methodName, category, countComponent)
    local original = classTable[methodName]
    if type(original) ~= "function" then
        Diagnostics.Log("ERROR", "METHOD_NOT_FOUND", tostring(methodName))
        return
    end

    classTable[methodName] = function(self, ...)
        local args = table.pack(...)
        local ok, result = pcall(function()
            return original(self, table.unpack(args, 1, args.n))
        end)
        if not ok then
            if category == "COMPONENT" then
                Diagnostics.ComponentErrors += 1
            end
            Diagnostics.Log("ERROR", category .. "_FAILED", methodName .. ": " .. ErrorTrace(result))
            return nil, tostring(result)
        end
        if countComponent and type(self) == "table" then
            self.ComponentCount = (self.ComponentCount or 0) + 1
            if self.Window then
                self.Window.ComponentCount = (self.Window.ComponentCount or 0) + 1
            end
            Diagnostics.Log("INFO", "COMPONENT_CREATED",
                methodName .. " criado com sucesso. Total nesta aba: " .. tostring(self.ComponentCount))
        elseif (category == "COMPONENT" or category == "RAYFIELD_ADAPTER") and result == nil then
            Diagnostics.ComponentErrors += 1
            Diagnostics.Log("ERROR", "COMPONENT_RETURNED_NIL",
                methodName .. " não retornou um handle. Verifique o componente anterior no relatório.")
        end
        return result
    end
end

GuardMethod(Paradise, "new", "WINDOW_CREATE", false)
GuardMethod(Paradise, "CreateWindow", "WINDOW_CREATE", false)
GuardMethod(Paradise, "Tab", "TAB_CREATE", false)
GuardMethod(Paradise, "CreateTab", "TAB_CREATE", false)

for _, methodName in ipairs({
    "Section", "Label", "Button", "Toggle", "Slider", "Dropdown",
    "TextBox", "Keybind", "Checkbox", "Paragraph", "Divider", "ColorPicker",
}) do
    GuardMethod(Tab, methodName, "COMPONENT", true)
end

for _, methodName in ipairs({
    "CreateSection", "CreateButton", "CreateToggle", "CreateCheckbox",
    "CreateSlider", "CreateDropdown", "CreateInput", "CreateKeybind",
    "CreateLabel", "CreateParagraph", "CreateColorPicker", "CreateDivider",
    "CreateTextBox",
}) do
    GuardMethod(Tab, methodName, "RAYFIELD_ADAPTER", false)
end

-- Após o chunk terminar, detecta library carregada isoladamente.
-- O defer permite que o script chamador crie a Window no mesmo ciclo.
task.defer(function()
    if not Paradise._activeWindow then
        Diagnostics.CheckUsage()
    end
end)

-- A biblioteca termina aqui; exemplos de uso ficam em arquivo separado.
return Paradise
