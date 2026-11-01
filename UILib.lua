local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local Library = {
	IsMobile = IsMobile,
	FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
	FontFaceBold = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
	Radius = 3,
	DPIScale = 1,
	IconModule = nil,
	LucideUrl = "https://raw.githubusercontent.com/deividcomsono/lucide-roblox-direct/refs/heads/main/source.lua",
	Toggles = {},
	Options = {},
	Windows = {},
	Connections = {},
	Theme = {
		Background = Color3.fromRGB(10, 10, 10),
		Sidebar = Color3.fromRGB(14, 14, 14),
		Panel = Color3.fromRGB(19, 19, 19),
		Header = Color3.fromRGB(22, 22, 23),
		Control = Color3.fromRGB(24, 24, 24),
		ControlHover = Color3.fromRGB(31, 31, 32),
		Selected = Color3.fromRGB(21, 21, 22),
		Track = Color3.fromRGB(38, 38, 40),
		Line = Color3.fromRGB(30, 30, 30),
		Accent = Color3.fromRGB(7, 121, 251),
		AccentDark = Color3.fromRGB(5, 77, 153),
		Text = Color3.fromRGB(239, 239, 239),
		TextDim = Color3.fromRGB(95, 95, 95),
		TextHover = Color3.fromRGB(160, 160, 160),
		KnobOff = Color3.fromRGB(78, 78, 78),
		SliderKnob = Color3.fromRGB(46, 46, 48),
	},
}

local WindowClass = {}
WindowClass.__index = WindowClass
local TabClass = {}
TabClass.__index = TabClass
local SubtabClass = {}
SubtabClass.__index = SubtabClass
local GroupboxClass = {}
GroupboxClass.__index = GroupboxClass

local S = 12
local T_GAP = 6
local BTN = 34
local ICON = 16
local SIDEBAR_W = BTN + T_GAP * 2
local TOPBAR_H = SIDEBAR_W
local SUBTAB_BAR_H = BTN + T_GAP * 2
local HEADER_H = BTN
local ROW_H = IsMobile and 34 or 30
local CONTROL_H = 24
local CONTROL_W = 0.55
local FADE = 14

local function Connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(Library.Connections, c)
	return c
end

local function New(class, props)
	local inst = Instance.new(class)
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		inst.BackgroundTransparency = 1
		inst.FontFace = Library.FontFace
		inst.TextSize = 13
		inst.TextColor3 = Library.Theme.Text
		if inst:IsA("TextButton") then
			inst.AutoButtonColor = false
		end
	elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		inst.BackgroundTransparency = 1
	end
	local parent = props.Parent
	for k, v in pairs(props) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	inst.Parent = parent
	return inst
end

local function Corner(inst, r)
	return New("UICorner", { CornerRadius = UDim.new(0, r or Library.Radius), Parent = inst })
end

local function FocusStroke(inst)
	return New("UIStroke", {
		Color = Library.Theme.Accent,
		Transparency = 1,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

local function Pad(inst, l, t, r, b)
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0),
		PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or 0),
		PaddingBottom = UDim.new(0, b or 0),
		Parent = inst,
	})
end

local function List(parent, padding, dir)
	return New("UIListLayout", {
		Padding = UDim.new(0, padding or 0),
		FillDirection = dir or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

local function Tween(inst, props, time, style, dir)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(time or 0.18, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

local function IsPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function GetGuiParent()
	local ok, hui = pcall(function()
		return gethui and gethui()
	end)
	if ok and hui then
		return hui
	end
	local ok2, core = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok2 and core then
		return core
	end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function MakeDraggable(handle, target, onTap, getScale)
	local dragging, moved, startMouse, startPos = false, false, nil, nil
	Connect(handle.InputBegan, function(input)
		if IsPress(input) then
			dragging, moved = true, false
			startMouse = input.Position
			startPos = target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					if onTap and not moved then
						onTap()
					end
				end
			end)
		end
	end)
	Connect(UserInputService.InputChanged, function(input)
		if dragging and IsMove(input) then
			local delta = input.Position - startMouse
			if delta.Magnitude > 6 then
				moved = true
			end
			if moved then
				local s = getScale and getScale() or 1
				target.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X / s,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y / s
				)
			end
		end
	end)
end

local function CreateScrollView(parent, getScale, class, props)
	local view = { Token = 0, Cache = "" }
	local clip = New("CanvasGroup", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	local gradient = New("UIGradient", { Parent = clip })
	props.AutomaticSize = Enum.AutomaticSize.X
	props.Size = UDim2.fromScale(1, 1)
	props.Parent = clip
	local content = New(class, props)
	view.Clip, view.Content = clip, content

	local function measure()
		local s = getScale()
		return clip.AbsoluteSize.X / s, content.AbsoluteSize.X / s
	end

	local function paint()
		local clipW, contentW = measure()
		local over = math.max(contentW - clipW, 0)
		local x = content.Position.X.Offset
		local key
		if over < 1 or clipW < 1 then
			key = "none"
		else
			key = string.format("%.2f|%.2f|%.1f", x, over, clipW)
		end
		if key == view.Cache then
			return
		end
		view.Cache = key
		if key == "none" then
			gradient.Transparency = NumberSequence.new(0)
			return
		end
		local f = math.min(FADE / clipW, 0.4)
		local l = math.clamp(-x / FADE, 0, 1)
		local r = math.clamp((over + x) / FADE, 0, 1)
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, l),
			NumberSequenceKeypoint.new(f, 0),
			NumberSequenceKeypoint.new(1 - f, 0),
			NumberSequenceKeypoint.new(1, r),
		})
	end
	Connect(RunService.Heartbeat, paint)

	function view:Overflow()
		local clipW, contentW = measure()
		return math.max(contentW - clipW, 0)
	end

	function view:Stop()
		self.Token += 1
	end

	function view:Restart()
		self.Token += 1
		local tok = self.Token
		Tween(content, { Position = UDim2.fromOffset(0, 0) }, 0.25)
		task.spawn(function()
			task.wait(0.3)
			while tok == self.Token and clip.Parent do
				local over = self:Overflow()
				if over < 1 then
					return
				end
				task.wait(1.1)
				if tok ~= self.Token then
					return
				end
				local dur = math.clamp(over / 38, 0.6, 5)
				Tween(content, { Position = UDim2.fromOffset(-over, 0) }, dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				task.wait(dur + 0.9)
				if tok ~= self.Token then
					return
				end
				Tween(content, { Position = UDim2.fromOffset(0, 0) }, dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				task.wait(dur)
			end
		end)
	end

	function view:Follow(caretFraction)
		self.Token += 1
		local clipW, contentW = measure()
		if contentW <= clipW + 1 then
			Tween(content, { Position = UDim2.fromOffset(0, 0) }, 0.15)
			return
		end
		local minX = clipW - contentW
		local target
		if not caretFraction or caretFraction >= 1 then
			target = minX
		else
			local caretX = contentW * caretFraction
			target = content.Position.X.Offset
			if caretX + target > clipW - 10 then
				target = clipW - 10 - caretX
			elseif caretX + target < 10 then
				target = 10 - caretX
			end
			target = math.clamp(target, minX, 0)
		end
		Tween(content, { Position = UDim2.fromOffset(target, 0) }, 0.15)
	end

	local pending = false
	local function resized()
		if pending or view.Locked then
			return
		end
		pending = true
		task.delay(0.1, function()
			pending = false
			if not view.Locked then
				view:Restart()
			end
		end)
	end
	Connect(clip:GetPropertyChangedSignal("AbsoluteSize"), resized)
	Connect(content:GetPropertyChangedSignal("AbsoluteSize"), resized)

	return view
end

function Library:SetIconModule(module)
	self.IconModule = module
end

function Library:LoadLucide(url)
	local ok, module = pcall(function()
		return loadstring(game:HttpGet(url or self.LucideUrl))()
	end)
	if ok and type(module) == "table" and module.GetAsset then
		self.IconModule = module
		return true
	end
	warn("[UILib] Could not load the Lucide module. Use Library:SetIconModule(...) with your own.")
	return false
end

function Library:GetIcon(name)
	if name == nil or name == 0 or name == "rbxassetid://0" then
		return nil
	end
	if typeof(name) == "number" then
		return { Url = "rbxassetid://" .. name, ImageRectOffset = Vector2.zero, ImageRectSize = Vector2.zero }
	end
	if typeof(name) == "string" then
		if string.find(name, "^rbxasset") then
			return { Url = name, ImageRectOffset = Vector2.zero, ImageRectSize = Vector2.zero }
		end
		if self.IconModule then
			local clean = string.gsub(name, "^lucide[-_:]", "")
			local ok, asset = pcall(self.IconModule.GetAsset, clean)
			if ok and asset then
				return asset
			end
		end
	end
	return nil
end

function Library:ApplyIcon(img, name)
	local asset = self:GetIcon(name)
	if not asset then
		return false
	end
	img.Image = asset.Url
	img.ImageRectOffset = asset.ImageRectOffset or Vector2.zero
	img.ImageRectSize = asset.ImageRectSize or Vector2.zero
	return true
end

function Library:CreateIcon(parent, name, size, color, fallback)
	local holder = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	local icon = { Holder = holder }
	local img = New("ImageLabel", { Size = UDim2.fromScale(1, 1), ImageColor3 = color, Parent = holder })
	if self:ApplyIcon(img, name) then
		icon.Image = img
	else
		img:Destroy()
		local letter = fallback
		if not letter then
			local clean = string.gsub(tostring(name or "?"), "^lucide[-_:]", "")
			letter = string.upper(string.sub(clean, 1, 1))
		end
		icon.Fallback = New("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = letter,
			TextColor3 = color,
			TextSize = math.max(size - 3, 8),
			FontFace = self.FontFaceBold,
			Parent = holder,
		})
	end
	function icon:SetColor(c, time)
		if self.Image then
			Tween(self.Image, { ImageColor3 = c }, time or 0.2)
		else
			Tween(self.Fallback, { TextColor3 = c }, time or 0.2)
		end
	end
	return icon
end

function Library:CreateWindow(cfg)
	cfg = cfg or {}
	local T = self.Theme
	if cfg.CornerRadius then
		self.Radius = cfg.CornerRadius
	end
	if not self.IconModule and cfg.AutoLoadLucide ~= false then
		self:LoadLucide()
	end

	local window = setmetatable({ Tabs = {}, ActiveTab = nil, Visible = true, BaseScale = 1 }, WindowClass)

	local gui = New("ScreenGui", {
		Name = "UILib",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 1000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	pcall(function()
		gui.Parent = GetGuiParent()
	end)
	if not gui.Parent then
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	window.Gui = gui

	local size = cfg.Size or (IsMobile and UDim2.fromOffset(600, 360) or UDim2.fromOffset(640, 470))
	local baseW, baseH = size.X.Offset, size.Y.Offset

	local main = New("CanvasGroup", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = T.Background,
		GroupTransparency = 0,
		Parent = gui,
	})
	Corner(main, Library.Radius + 1)
	window.Main = main

	local scale = New("UIScale", { Parent = main })
	window.Scale = scale
	local function fit()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local vp = cam.ViewportSize
		window.BaseScale = math.max(math.min(1, (vp.X - 16) / baseW, (vp.Y - 16) / baseH), 0.35) * Library.DPIScale
		if window.Visible then
			scale.Scale = window.BaseScale
		end
	end
	fit()
	if workspace.CurrentCamera then
		Connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), fit)
	end

	local sidebar = New("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, SIDEBAR_W, 1, 0),
		BackgroundColor3 = T.Sidebar,
		Parent = main,
	})

	local logoCell = New("Frame", {
		Name = "LogoCell",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(SIDEBAR_W, TOPBAR_H),
		Parent = sidebar,
	})
	local logo = self:CreateIcon(logoCell, cfg.Logo or cfg.Title or "?", 22, T.Accent)
	logo.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
	logo.Holder.Position = UDim2.fromScale(0.5, 0.5)

	local tabListY = TOPBAR_H + T_GAP
	window.TabList = New("Frame", {
		Name = "TabList",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, tabListY),
		Size = UDim2.new(1, 0, 1, -tabListY),
		Parent = sidebar,
	})
	List(window.TabList, T_GAP).HorizontalAlignment = Enum.HorizontalAlignment.Center

	local content = New("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(SIDEBAR_W, 0),
		Size = UDim2.new(1, -SIDEBAR_W, 1, 0),
		Parent = main,
	})
	local topbar = New("Frame", {
		Name = "Topbar",
		Active = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TOPBAR_H),
		Parent = content,
	})
	New("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(S, 7),
		Size = UDim2.new(1, -S * 2, 0, 18),
		Text = cfg.Title or "Window",
		TextSize = 15,
		FontFace = self.FontFaceBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = topbar,
	})
	window.TabLabel = New("TextLabel", {
		Name = "TabName",
		Position = UDim2.fromOffset(S, 25),
		Size = UDim2.new(1, -S * 2, 0, 14),
		TextSize = 12,
		TextColor3 = T.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = topbar,
	})
	window.TabHolder = New("Frame", {
		Name = "TabHolder",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, TOPBAR_H),
		Size = UDim2.new(1, 0, 1, -TOPBAR_H),
		Parent = content,
	})

	window.Overlay = New("Frame", {
		Name = "Overlay",
		Active = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 100,
		Parent = main,
	})
	Connect(window.Overlay.InputBegan, function(input)
		if IsPress(input) then
			window:ClosePopup()
		end
	end)

	local tip = New("Frame", {
		Name = "Tooltip",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 24),
		BackgroundColor3 = T.Header,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 90,
		Parent = main,
	})
	Corner(tip)
	Pad(tip, 8, 0, 8, 0)
	local tipLabel = New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 24),
		TextSize = 12,
		TextTransparency = 1,
		ZIndex = 91,
		Parent = tip,
	})
	window._ShowTip = function(gobj, text)
		local s = scale.Scale
		local mp = main.AbsolutePosition
		local bp, bs = gobj.AbsolutePosition, gobj.AbsoluteSize
		tipLabel.Text = text
		tip.Position = UDim2.fromOffset((bp.X - mp.X + bs.X) / s + 6, (bp.Y - mp.Y + bs.Y / 2) / s - 12)
		tip.Visible = true
		Tween(tip, { BackgroundTransparency = 0 }, 0.12)
		Tween(tipLabel, { TextTransparency = 0 }, 0.12)
	end
	window._HideTip = function()
		Tween(tip, { BackgroundTransparency = 1 }, 0.08)
		Tween(tipLabel, { TextTransparency = 1 }, 0.08)
		task.delay(0.09, function()
			if tip.BackgroundTransparency >= 0.99 then
				tip.Visible = false
			end
		end)
	end

	MakeDraggable(topbar, main, nil, function()
		return scale.Scale
	end)

	local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
	Connect(UserInputService.InputBegan, function(input, processed)
		if not processed and input.KeyCode == toggleKey then
			window:Toggle()
		end
	end)

	if IsMobile or cfg.MobileButton then
		local btn = New("Frame", {
			Name = "MobileToggle",
			Active = true,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = T.Sidebar,
			ZIndex = 5,
			Parent = gui,
		})
		Corner(btn, Library.Radius + 1)
		local mi = self:CreateIcon(btn, cfg.Logo or cfg.Title or "?", 22, T.Accent)
		mi.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
		mi.Holder.Position = UDim2.fromScale(0.5, 0.5)
		MakeDraggable(btn, btn, function()
			window:Toggle()
		end)
	end

	main.GroupTransparency = 1
	scale.Scale = window.BaseScale * 0.94
	Tween(main, { GroupTransparency = 0 }, 0.25)
	Tween(scale, { Scale = window.BaseScale }, 0.3)

	table.insert(self.Windows, window)
	return window
end

function WindowClass:SetVisible(v)
	if v == self.Visible then
		return
	end
	self.Visible = v
	self:ClosePopup(true)
	self._HideTip()
	local main, scale = self.Main, self.Scale
	if v then
		main.Visible = true
		main.GroupTransparency = 1
		scale.Scale = self.BaseScale * 0.94
		Tween(main, { GroupTransparency = 0 }, 0.22)
		Tween(scale, { Scale = self.BaseScale }, 0.28)
	else
		Tween(main, { GroupTransparency = 1 }, 0.15)
		Tween(scale, { Scale = self.BaseScale * 0.96 }, 0.15)
		task.delay(0.16, function()
			if not self.Visible then
				main.Visible = false
			end
		end)
	end
end

function WindowClass:Toggle()
	self:SetVisible(not self.Visible)
end

function WindowClass:ClosePopup(instant)
	local ov = self.Overlay
	ov.Active = false
	local kids = ov:GetChildren()
	for _, c in ipairs(kids) do
		if instant or not c:IsA("CanvasGroup") then
			c:Destroy()
		else
			Tween(c, { GroupTransparency = 1, Position = c.Position + UDim2.fromOffset(0, 4) }, 0.12)
			task.delay(0.14, function()
				c:Destroy()
			end)
		end
	end
	if instant or #kids == 0 then
		ov.Visible = false
	else
		task.delay(0.15, function()
			if #ov:GetChildren() == 0 then
				ov.Visible = false
			end
		end)
	end
	if self.PopupClosed then
		local f = self.PopupClosed
		self.PopupClosed = nil
		f()
	end
end

function WindowClass:SelectTab(tab)
	if self.ActiveTab == tab then
		return
	end
	self:ClosePopup(true)
	local first = self.ActiveTab == nil
	if self.ActiveTab then
		self.ActiveTab:_SetActive(false)
	end
	self.ActiveTab = tab
	tab:_SetActive(true, not first)
	self.TabLabel.Text = tab.Name
end

function WindowClass:Destroy()
	self.Gui:Destroy()
end

function Library:Unload()
	for _, c in ipairs(self.Connections) do
		pcall(function()
			c:Disconnect()
		end)
	end
	for _, w in ipairs(self.Windows) do
		pcall(function()
			w.Gui:Destroy()
		end)
	end
	self.Connections, self.Windows, self.Toggles, self.Options = {}, {}, {}, {}
end

function WindowClass:AddTab(cfg, icon)
	if typeof(cfg) == "string" then
		cfg = { Name = cfg, Icon = icon }
	end
	local T = Library.Theme
	local tab = setmetatable({
		Window = self,
		Name = cfg.Name or "Tab",
		Subtabs = {},
		ActiveSubtab = nil,
	}, TabClass)

	local button = New("TextButton", {
		Name = tab.Name,
		Size = UDim2.fromOffset(BTN, BTN),
		BackgroundColor3 = T.Selected,
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = #self.Tabs,
		Parent = self.TabList,
	})
	Corner(button)
	tab.Button = button
	tab.Icon = Library:CreateIcon(button, cfg.Icon or tab.Name, ICON, T.TextDim)
	tab.Icon.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
	tab.Icon.Holder.Position = UDim2.fromScale(0.5, 0.5)

	local frame = New("CanvasGroup", {
		Name = tab.Name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = self.TabHolder,
	})
	tab.Frame = frame

	tab.SubtabBar = New("Frame", {
		Name = "SubtabBar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, SUBTAB_BAR_H),
		Visible = false,
		Parent = frame,
	})
	List(tab.SubtabBar, T_GAP, Enum.FillDirection.Horizontal).VerticalAlignment = Enum.VerticalAlignment.Center
	Pad(tab.SubtabBar, S, 0, S, 0)

	tab.PageHolder = New("Frame", {
		Name = "PageHolder",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	})

	Connect(button.MouseButton1Click, function()
		self:SelectTab(tab)
	end)
	Connect(button.MouseEnter, function()
		if self.ActiveTab ~= tab then
			Tween(button, { BackgroundTransparency = 0.5 }, 0.12)
			tab.Icon:SetColor(T.TextHover, 0.12)
		end
		if not IsMobile then
			self._ShowTip(button, tab.Name)
		end
	end)
	Connect(button.MouseLeave, function()
		if self.ActiveTab ~= tab then
			Tween(button, { BackgroundTransparency = 1 }, 0.12)
			tab.Icon:SetColor(T.TextDim, 0.12)
		end
		self._HideTip()
	end)
	Connect(button.MouseButton1Down, function()
		Tween(tab.Icon.Holder, { Size = UDim2.fromOffset(ICON - 3, ICON - 3) }, 0.08)
	end)
	Connect(button.MouseButton1Up, function()
		Tween(tab.Icon.Holder, { Size = UDim2.fromOffset(ICON, ICON) }, 0.2, Enum.EasingStyle.Back)
	end)

	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then
		self:SelectTab(tab)
	end
	return tab
end

function TabClass:_SetActive(active, animate)
	local T = Library.Theme
	self.Frame.Visible = active
	if active and animate then
		self.Frame.GroupTransparency = 1
		self.Frame.Position = UDim2.fromOffset(0, 8)
		Tween(self.Frame, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.25)
	elseif active then
		self.Frame.GroupTransparency = 0
		self.Frame.Position = UDim2.fromOffset(0, 0)
	end
	Tween(self.Button, { BackgroundTransparency = active and 0 or 1 }, 0.18)
	self.Icon:SetColor(active and T.Accent or T.TextDim)
end

function TabClass:_UpdateLayout()
	local multi = #self.Subtabs > 1
	self.SubtabBar.Visible = multi
	local off = multi and SUBTAB_BAR_H or T_GAP
	self.PageHolder.Position = UDim2.fromOffset(0, off)
	self.PageHolder.Size = UDim2.new(1, 0, 1, -off)
end

function TabClass:SelectSubtab(sub)
	if self.ActiveSubtab == sub then
		return
	end
	self.Window:ClosePopup(true)
	local first = self.ActiveSubtab == nil
	if self.ActiveSubtab then
		self.ActiveSubtab:_SetActive(false)
	end
	self.ActiveSubtab = sub
	sub:_SetActive(true, not first)
end

function TabClass:AddSubtab(cfg, icon)
	if typeof(cfg) == "string" then
		cfg = { Name = cfg, Icon = icon }
	end
	local T = Library.Theme
	local sub = setmetatable({ Tab = self, Window = self.Window, Name = cfg.Name or "Subtab" }, SubtabClass)

	local button = New("TextButton", {
		Name = sub.Name,
		Size = UDim2.new(0, 0, 0, BTN),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = T.Selected,
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = #self.Subtabs,
		Parent = self.SubtabBar,
	})
	Corner(button)
	Pad(button, 10, 0, 10, 0)
	List(button, 8, Enum.FillDirection.Horizontal).VerticalAlignment = Enum.VerticalAlignment.Center
	sub.Icon = Library:CreateIcon(button, cfg.Icon or sub.Name, ICON, T.TextDim)
	sub.Icon.Holder.LayoutOrder = 1
	sub.Label = New("TextLabel", {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = sub.Name,
		TextColor3 = T.TextDim,
		LayoutOrder = 2,
		Parent = button,
	})
	sub.Button = button

	local page = New("CanvasGroup", {
		Name = sub.Name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = self.PageHolder,
	})
	Pad(page, S, S - T_GAP, S, S)
	sub.Page = page

	local function column(name, pos)
		local col = New("ScrollingFrame", {
			Name = name,
			BackgroundTransparency = 1,
			Position = pos,
			Size = UDim2.new(0.5, -S / 2, 1, 0),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 2,
			VerticalScrollBarInset = Enum.ScrollBarInset.None,
			ScrollBarImageColor3 = T.Track,
			BorderSizePixel = 0,
			Parent = page,
		})
		List(col, S)
		return col
	end
	sub.Left = column("Left", UDim2.fromOffset(0, 0))
	sub.Right = column("Right", UDim2.new(0.5, S / 2, 0, 0))

	Connect(button.MouseButton1Click, function()
		self:SelectSubtab(sub)
	end)
	Connect(button.MouseEnter, function()
		if self.ActiveSubtab ~= sub then
			Tween(button, { BackgroundTransparency = 0.5 }, 0.12)
			Tween(sub.Label, { TextColor3 = T.TextHover }, 0.12)
			sub.Icon:SetColor(T.TextHover, 0.12)
		end
	end)
	Connect(button.MouseLeave, function()
		if self.ActiveSubtab ~= sub then
			Tween(button, { BackgroundTransparency = 1 }, 0.12)
			Tween(sub.Label, { TextColor3 = T.TextDim }, 0.12)
			sub.Icon:SetColor(T.TextDim, 0.12)
		end
	end)

	table.insert(self.Subtabs, sub)
	self:_UpdateLayout()
	if #self.Subtabs == 1 then
		self:SelectSubtab(sub)
	end
	return sub
end

function SubtabClass:_SetActive(active, animate)
	local T = Library.Theme
	self.Page.Visible = active
	if active and animate then
		self.Page.GroupTransparency = 1
		self.Page.Position = UDim2.fromOffset(0, 8)
		Tween(self.Page, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.25)
	elseif active then
		self.Page.GroupTransparency = 0
		self.Page.Position = UDim2.fromOffset(0, 0)
	end
	Tween(self.Button, { BackgroundTransparency = active and 0 or 1 }, 0.18)
	Tween(self.Label, { TextColor3 = active and T.Text or T.TextDim }, 0.18)
	self.Icon:SetColor(active and T.Accent or T.TextDim)
end

function SubtabClass:AddGroupbox(cfg, icon)
	if typeof(cfg) == "string" then
		cfg = { Name = cfg, Icon = icon }
	end
	local T = Library.Theme
	local window = self.Window
	local parent = (string.lower(cfg.Side or "left") == "right") and self.Right or self.Left
	local box = setmetatable({ Subtab = self, Window = window, Collapsed = false, _token = 0 }, GroupboxClass)

	local frame = New("Frame", {
		Name = cfg.Name or "Groupbox",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Header,
		Parent = parent,
	})
	Corner(frame)
	List(frame, 0)

	local header = New("TextButton", {
		Size = UDim2.new(1, 0, 0, HEADER_H),
		Text = "",
		LayoutOrder = 1,
		Parent = frame,
	})
	local nameX = S
	if cfg.Icon then
		local gi = Library:CreateIcon(header, cfg.Icon, ICON, T.Accent)
		gi.Holder.AnchorPoint = Vector2.new(0, 0.5)
		gi.Holder.Position = UDim2.new(0, S, 0.5, 0)
		nameX = S + ICON + 8
	end
	New("TextLabel", {
		Position = UDim2.fromOffset(nameX, 0),
		Size = UDim2.new(1, -nameX - 34, 1, 0),
		Text = cfg.Name or "Groupbox",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	local chevron = Library:CreateIcon(header, "chevron-down", 14, T.TextDim, "v")
	chevron.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
	chevron.Holder.Position = UDim2.new(1, -(S + 7), 0.5, 0)

	local clip = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 2,
		Parent = frame,
	})
	local body = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Panel,
		Parent = clip,
	})
	Corner(body)
	New("Frame", {
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = T.Panel,
		Parent = body,
	})
	local container = New("Frame", {
		Name = "Container",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = body,
	})
	List(container, 0)
	Pad(container, S, 4, S, 4)

	local TIME = 0.24
	function box:SetCollapsed(state, instant)
		if state == self.Collapsed then
			return
		end
		self.Collapsed = state
		self._token += 1
		local tok = self._token
		Tween(chevron.Holder, { Rotation = state and -90 or 0 }, 0.2)
		local s = window.Scale.Scale
		if state then
			if instant then
				clip.Visible = false
				return
			end
			local h = clip.AbsoluteSize.Y / s
			self._height = h
			clip.AutomaticSize = Enum.AutomaticSize.None
			clip.Size = UDim2.new(1, 0, 0, h)
			Tween(clip, { Size = UDim2.new(1, 0, 0, 0) }, TIME)
			task.delay(TIME, function()
				if self._token == tok and self.Collapsed then
					clip.Visible = false
				end
			end)
		else
			task.spawn(function()
				clip.Visible = true
				local h = self._height
				if not h then
					task.wait()
					h = body.AbsoluteSize.Y / window.Scale.Scale
				end
				if self._token ~= tok then
					return
				end
				clip.AutomaticSize = Enum.AutomaticSize.None
				Tween(clip, { Size = UDim2.new(1, 0, 0, h) }, TIME)
				task.delay(TIME, function()
					if self._token == tok and not self.Collapsed then
						clip.AutomaticSize = Enum.AutomaticSize.Y
						clip.Size = UDim2.new(1, 0, 0, 0)
					end
				end)
			end)
		end
	end
	Connect(header.MouseButton1Click, function()
		box:SetCollapsed(not box.Collapsed)
	end)
	if cfg.Collapsed then
		box:SetCollapsed(true, true)
	end

	box.Frame, box.Container = frame, container
	return box
end

function SubtabClass:AddLeftGroupbox(name, icon)
	return self:AddGroupbox({ Name = name, Icon = icon, Side = "Left" })
end

function SubtabClass:AddRightGroupbox(name, icon)
	return self:AddGroupbox({ Name = name, Icon = icon, Side = "Right" })
end

local function Fire(obj, cfg, ...)
	if cfg.Callback then
		task.spawn(cfg.Callback, ...)
	end
	for _, fn in ipairs(obj.Changed) do
		task.spawn(fn, ...)
	end
end

local function NewRow(box, idx)
	return New("Frame", {
		Name = tostring(idx),
		Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundTransparency = 1,
		Parent = box.Container,
	})
end

local function RowLabel(row, text)
	return New("TextLabel", {
		Size = UDim2.new(1 - CONTROL_W, -S / 2, 1, 0),
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
end

local function RowControl(row, class, props)
	props.AnchorPoint = Vector2.new(1, 0.5)
	props.Position = UDim2.fromScale(1, 0.5)
	props.Size = UDim2.new(CONTROL_W, 0, 0, CONTROL_H)
	props.Parent = row
	return New(class, props)
end

function GroupboxClass:AddToggle(idx, cfg)
	cfg = cfg or {}
	local T = Library.Theme
	local toggle = { Type = "Toggle", Value = false, Changed = {} }

	local row = New("TextButton", {
		Name = tostring(idx),
		Size = UDim2.new(1, 0, 0, ROW_H),
		Text = "",
		Parent = self.Container,
	})
	local label = New("TextLabel", {
		Size = UDim2.new(1, -(30 + S), 1, 0),
		Text = cfg.Text or tostring(idx),
		TextColor3 = T.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	local track = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(30, 16),
		BackgroundColor3 = T.Track,
		Parent = row,
	})
	Corner(track, 8)
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = T.KnobOff,
		Parent = track,
	})
	Corner(knob, 5)

	local pressed, hovered = false, false
	local function render(instant)
		local on = toggle.Value
		local t = instant and 0 or 0.22
		local w = pressed and 14 or 10
		Tween(knob, {
			Position = UDim2.new(0, on and (30 - 3 - w) or 3, 0.5, 0),
			Size = UDim2.fromOffset(w, 10),
			BackgroundColor3 = on and T.Accent or T.KnobOff,
		}, t)
		Tween(label, { TextColor3 = on and T.Text or (hovered and T.TextHover or T.TextDim) }, t)
	end

	function toggle:SetValue(value, silent)
		value = value and true or false
		if self.Value == value then
			return
		end
		self.Value = value
		render()
		if not silent then
			Fire(self, cfg, value)
		end
	end
	function toggle:OnChanged(fn)
		table.insert(self.Changed, fn)
	end
	function toggle:SetText(text)
		label.Text = text
	end

	Connect(row.MouseEnter, function()
		hovered = true
		render()
	end)
	Connect(row.MouseLeave, function()
		hovered, pressed = false, false
		render()
	end)
	Connect(row.MouseButton1Down, function()
		pressed = true
		render()
	end)
	Connect(row.MouseButton1Up, function()
		pressed = false
	end)
	Connect(row.MouseButton1Click, function()
		pressed = false
		toggle.Value = not toggle.Value
		render()
		Fire(toggle, cfg, toggle.Value)
	end)

	toggle.Value = cfg.Default and true or false
	render(true)
	Library.Toggles[idx] = toggle
	return toggle
end

function GroupboxClass:AddSlider(idx, cfg)
	cfg = cfg or {}
	local T = Library.Theme
	local min, max = cfg.Min or 0, cfg.Max or 100
	local rounding = cfg.Rounding or 0
	local suffix = cfg.Suffix or ""
	local KNOB_W = 20
	local VALUE_W = 38
	local slider = { Type = "Slider", Value = min, Min = min, Max = max, Changed = {} }

	local row = NewRow(self, idx)
	RowLabel(row, cfg.Text or tostring(idx))
	local region = RowControl(row, "TextButton", { Text = "" })
	local valueLabel = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(VALUE_W, CONTROL_H),
		TextColor3 = T.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = region,
	})
	local track = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, -(VALUE_W + 8), 0, 5),
		BackgroundColor3 = T.Control,
		Parent = region,
	})
	Corner(track, 3)
	local fill = New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = T.AccentDark,
		Parent = track,
	})
	Corner(fill, 3)
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(KNOB_W, 14),
		BackgroundColor3 = T.SliderKnob,
		Parent = track,
	})
	Corner(knob, 3)

	local function render(instant)
		local rel = (max == min) and 0 or (slider.Value - min) / (max - min)
		local offset = (0.5 - rel) * KNOB_W
		local t = instant and 0 or 0.08
		Tween(fill, { Size = UDim2.new(rel, offset, 1, 0) }, t, Enum.EasingStyle.Linear)
		Tween(knob, { Position = UDim2.new(rel, offset, 0.5, 0) }, t, Enum.EasingStyle.Linear)
		valueLabel.Text = string.format("%." .. rounding .. "f", slider.Value) .. suffix
	end

	function slider:SetValue(v, silent)
		local m = 10 ^ rounding
		v = math.floor(math.clamp(v, min, max) * m + 0.5) / m
		if v == self.Value then
			return
		end
		self.Value = v
		render()
		if not silent then
			Fire(self, cfg, v)
		end
	end
	function slider:OnChanged(fn)
		table.insert(self.Changed, fn)
	end

	local dragging, hovered = false, false
	local function state()
		Tween(knob, {
			BackgroundColor3 = (dragging or hovered) and Color3.fromRGB(64, 64, 68) or T.SliderKnob,
		}, 0.15)
		Tween(fill, { BackgroundColor3 = dragging and T.Accent or T.AccentDark }, 0.15)
		Tween(valueLabel, { TextColor3 = dragging and T.Text or T.TextDim }, 0.15)
	end
	local function fromX(x)
		local kw = knob.AbsoluteSize.X
		local usable = math.max(track.AbsoluteSize.X - kw, 1)
		local rel = math.clamp((x - track.AbsolutePosition.X - kw / 2) / usable, 0, 1)
		slider:SetValue(min + (max - min) * rel)
	end
	Connect(region.MouseEnter, function()
		hovered = true
		state()
	end)
	Connect(region.MouseLeave, function()
		hovered = false
		state()
	end)
	Connect(region.InputBegan, function(input)
		if IsPress(input) then
			dragging = true
			state()
			fromX(input.Position.X)
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					state()
				end
			end)
		end
	end)
	Connect(UserInputService.InputChanged, function(input)
		if dragging and IsMove(input) then
			fromX(input.Position.X)
		end
	end)

	slider.Value = nil
	slider:SetValue(cfg.Default or min, true)
	render(true)
	Library.Options[idx] = slider
	return slider
end

function GroupboxClass:AddDropdown(idx, cfg)
	cfg = cfg or {}
	local T = Library.Theme
	local window = self.Window
	local multi = cfg.Multi and true or false
	local dd = { Type = "Dropdown", Values = cfg.Values or {}, Multi = multi, Changed = {}, Value = multi and {} or nil }
	local ITEM_H = IsMobile and 30 or 24
	local OPEN_BG = Color3.fromRGB(22, 26, 31)

	local row = NewRow(self, idx)
	RowLabel(row, cfg.Text or tostring(idx))
	local box = RowControl(row, "TextButton", { BackgroundColor3 = T.Control, Text = "" })
	Corner(box)
	local boxStroke = FocusStroke(box)
	local holder = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -34, 1, 0),
		Parent = box,
	})
	local view = CreateScrollView(holder, function()
		return window.Scale.Scale
	end, "TextLabel", {
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local valueLabel = view.Content
	local arrow = Library:CreateIcon(box, "chevron-down", 14, T.TextDim, "v")
	arrow.Holder.AnchorPoint = Vector2.new(1, 0.5)
	arrow.Holder.Position = UDim2.new(1, -9, 0.5, 0)

	local isOpen, hovered = false, false
	local function boxState()
		Tween(boxStroke, { Transparency = isOpen and 0.35 or 1 }, 0.15)
		Tween(box, { BackgroundColor3 = isOpen and OPEN_BG or (hovered and T.ControlHover or T.Control) }, 0.15)
		Tween(arrow.Holder, { Rotation = isOpen and 180 or 0 }, 0.2)
		arrow:SetColor(isOpen and T.Accent or T.TextDim)
	end

	local function display()
		local text
		if multi then
			local list = {}
			for _, v in ipairs(dd.Values) do
				if dd.Value[v] then
					table.insert(list, tostring(v))
				end
			end
			text = #list > 0 and table.concat(list, ", ") or "None"
		else
			text = dd.Value ~= nil and tostring(dd.Value) or "None"
		end
		if valueLabel.Text ~= text then
			valueLabel.Text = text
			view:Restart()
		end
	end

	local refreshItems

	function dd:SetValue(v, silent)
		if multi then
			local set = {}
			if type(v) == "table" then
				for k, val in pairs(v) do
					if type(k) == "number" then
						set[val] = true
					elseif val then
						set[k] = true
					end
				end
			end
			self.Value = set
		else
			self.Value = v
		end
		display()
		if refreshItems then
			refreshItems()
		end
		if not silent then
			Fire(self, cfg, self.Value)
		end
	end
	function dd:SetValues(values)
		self.Values = values
		display()
	end
	function dd:OnChanged(fn)
		table.insert(self.Changed, fn)
	end

	local function open()
		window:ClosePopup(true)
		local ov = window.Overlay
		local s = window.Scale.Scale
		local mp = window.Main.AbsolutePosition
		local ms = window.Main.AbsoluteSize
		local bp, bs = box.AbsolutePosition, box.AbsoluteSize
		local count = math.max(#dd.Values, 1)
		local h = math.min(count, 6) * ITEM_H + 8
		local w = math.max(bs.X / s, 120)
		local x = math.min((bp.X - mp.X) / s, ms.X / s - w - 4)
		local y = (bp.Y - mp.Y + bs.Y) / s + 4
		local up = false
		if y + h > ms.Y / s - 4 then
			y = (bp.Y - mp.Y) / s - h - 4
			up = true
		end

		local popup = New("CanvasGroup", {
			Active = true,
			Position = UDim2.fromOffset(x, y + (up and 5 or -5)),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = T.Control,
			GroupTransparency = 1,
			Parent = ov,
		})
		Corner(popup)
		local list = New("ScrollingFrame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 2,
			VerticalScrollBarInset = Enum.ScrollBarInset.None,
			ScrollBarImageColor3 = T.Track,
			BorderSizePixel = 0,
			Parent = popup,
		})
		List(list, 0)
		Pad(list, 0, 4, 0, 4)

		local items = {}
		local function isSel(v)
			if multi then
				return dd.Value[v] and true or false
			end
			return dd.Value == v
		end
		for i, v in ipairs(dd.Values) do
			local item = New("TextButton", {
				Size = UDim2.new(1, 0, 0, ITEM_H),
				Text = tostring(v),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = T.TextDim,
				LayoutOrder = i,
				Parent = list,
			})
			Pad(item, 10, 0, 10, 0)
			items[v] = item
			Connect(item.MouseButton1Click, function()
				if multi then
					local copy = {}
					for k, val in pairs(dd.Value) do
						copy[k] = val
					end
					copy[v] = (not copy[v]) or nil
					dd:SetValue(copy)
				else
					dd:SetValue(v)
					window:ClosePopup()
				end
			end)
			Connect(item.MouseEnter, function()
				if not isSel(v) then
					Tween(item, { TextColor3 = T.TextHover }, 0.08)
				end
			end)
			Connect(item.MouseLeave, function()
				Tween(item, { TextColor3 = isSel(v) and T.Accent or T.TextDim }, 0.1)
			end)
		end

		refreshItems = function()
			for v, item in pairs(items) do
				Tween(item, { TextColor3 = isSel(v) and T.Accent or T.TextDim }, 0.15)
			end
		end
		for v, item in pairs(items) do
			item.TextColor3 = isSel(v) and T.Accent or T.TextDim
		end

		ov.Visible = true
		ov.Active = true
		Tween(popup, { GroupTransparency = 0, Position = UDim2.fromOffset(x, y) }, 0.18)
		isOpen = true
		boxState()
		window.PopupClosed = function()
			refreshItems = nil
			isOpen = false
			boxState()
		end
	end

	Connect(box.MouseButton1Click, open)
	Connect(box.MouseEnter, function()
		hovered = true
		boxState()
	end)
	Connect(box.MouseLeave, function()
		hovered = false
		boxState()
	end)

	dd:SetValue(cfg.Default, true)
	Library.Options[idx] = dd
	return dd
end

function GroupboxClass:AddInput(idx, cfg)
	cfg = cfg or {}
	local T = Library.Theme
	local window = self.Window
	local input = { Type = "Input", Value = cfg.Default or "", Changed = {} }
	local FOCUS_BG = Color3.fromRGB(18, 20, 24)

	local row = NewRow(self, idx)
	RowLabel(row, cfg.Text or tostring(idx))
	local back = RowControl(row, "Frame", { BackgroundColor3 = T.Control })
	Corner(back)
	local stroke = FocusStroke(back)
	local holder = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Parent = back,
	})
	local view = CreateScrollView(holder, function()
		return window.Scale.Scale
	end, "TextBox", {
		Text = input.Value,
		PlaceholderText = cfg.Placeholder or "",
		PlaceholderColor3 = T.TextDim,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local box = view.Content

	function input:SetValue(v, silent)
		v = tostring(v)
		if cfg.Numeric then
			v = string.gsub(v, "[^%d%.%-]", "")
		end
		self.Value = v
		box.Text = v
		if not silent then
			Fire(self, cfg, v)
		end
	end
	function input:OnChanged(fn)
		table.insert(self.Changed, fn)
	end

	local focused, hovered = false, false
	local function state()
		Tween(stroke, { Transparency = focused and 0 or 1 }, 0.15)
		Tween(back, { BackgroundColor3 = focused and FOCUS_BG or (hovered and T.ControlHover or T.Control) }, 0.15)
	end
	local function paintText()
		box.TextColor3 = focused and T.Accent or T.Text
	end

	local function follow()
		if not focused then
			return
		end
		view.Locked = true
		task.defer(function()
			task.wait()
			if not focused then
				return
			end
			local len = #box.Text
			local cur = box.CursorPosition
			local fraction = 1
			if cur >= 1 and cur <= len then
				fraction = (cur - 1) / math.max(len, 1)
			end
			view:Follow(fraction)
		end)
	end

	Connect(box.Focused, function()
		focused = true
		paintText()
		state()
		follow()
	end)
	Connect(box.FocusLost, function()
		focused = false
		paintText()
		state()
		view.Locked = false
		view:Restart()
		if box.Text ~= input.Value then
			input:SetValue(box.Text)
		end
	end)
	Connect(box:GetPropertyChangedSignal("Text"), function()
		paintText()
		follow()
		if cfg.Finished == false and box.Text ~= input.Value then
			input.Value = box.Text
			Fire(input, cfg, box.Text)
		end
	end)
	Connect(box:GetPropertyChangedSignal("CursorPosition"), follow)
	Connect(back.MouseEnter, function()
		hovered = true
		state()
	end)
	Connect(back.MouseLeave, function()
		hovered = false
		state()
	end)
	Connect(back.InputBegan, function(inputObject)
		if IsPress(inputObject) and not box:IsFocused() then
			box:CaptureFocus()
		end
	end)

	paintText()
	Library.Options[idx] = input
	return input
end

function GroupboxClass:AddButton(cfg)
	if typeof(cfg) == "string" then
		cfg = { Text = cfg }
	end
	local T = Library.Theme
	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	local group = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, CONTROL_H),
		BackgroundTransparency = 1,
		Parent = row,
	})
	local buttons = {}

	local function layout()
		local n = #buttons
		for i, b in ipairs(buttons) do
			b.Size = UDim2.new(1 / n, -T_GAP * (n - 1) / n, 1, 0)
			b.Position = UDim2.new((i - 1) / n, (i - 1) * T_GAP / n, 0, 0)
		end
	end

	local function addOne(c)
		if typeof(c) == "string" then
			c = { Text = c }
		end
		local b = New("TextButton", {
			BackgroundColor3 = T.Control,
			BackgroundTransparency = 0,
			Text = c.Text or "Button",
			TextColor3 = T.TextDim,
			Parent = group,
		})
		Corner(b)
		table.insert(buttons, b)
		layout()

		local obj = { Button = b }
		local pending, hovered = false, false
		local function rest()
			Tween(b, {
				BackgroundColor3 = hovered and T.ControlHover or T.Control,
				TextColor3 = hovered and T.Text or T.TextDim,
			}, 0.12)
		end
		Connect(b.MouseEnter, function()
			hovered = true
			rest()
		end)
		Connect(b.MouseLeave, function()
			hovered = false
			rest()
		end)
		Connect(b.MouseButton1Down, function()
			Tween(b, { BackgroundColor3 = T.Control:Lerp(T.Accent, 0.2), TextColor3 = T.Text }, 0.06)
		end)
		Connect(b.MouseButton1Up, rest)
		Connect(b.MouseButton1Click, function()
			if c.DoubleClick then
				if not pending then
					pending = true
					b.Text = "Click again to confirm"
					task.delay(2, function()
						if pending then
							pending = false
							b.Text = c.Text or "Button"
						end
					end)
					return
				end
				pending = false
				b.Text = c.Text or "Button"
			end
			local fn = c.Func or c.Callback
			if fn then
				task.spawn(fn)
			end
		end)
		function obj:SetText(t)
			c.Text = t
			b.Text = t
		end
		function obj:AddButton(c2)
			return addOne(c2)
		end
		return obj
	end

	return addOne(cfg)
end

function GroupboxClass:AddLabel(cfg)
	if typeof(cfg) == "string" then
		cfg = { Text = cfg }
	end
	local T = Library.Theme
	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, ROW_H),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	List(row, 2).VerticalAlignment = Enum.VerticalAlignment.Center
	Pad(row, 0, 5, 0, 5)
	local label = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = cfg.Text or "",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Parent = row,
	})
	local desc
	if cfg.Description then
		desc = New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = cfg.Description,
			TextColor3 = T.TextDim,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			Parent = row,
		})
	end
	local obj = {}
	function obj:SetText(t)
		label.Text = t
	end
	function obj:SetDescription(t)
		if desc then
			desc.Text = t
		end
	end
	return obj
end

function GroupboxClass:AddDivider(text)
	local T = Library.Theme
	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = T.Line,
		Parent = row,
	})
	if text then
		local l = New("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 0, 0, 16),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			BackgroundColor3 = T.Panel,
			Text = text,
			TextColor3 = T.TextDim,
			TextSize = 12,
			Parent = row,
		})
		Pad(l, S / 2, 0, S / 2, 0)
	end
	return row
end

return Library
