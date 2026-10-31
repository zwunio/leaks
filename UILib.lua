--[[
	UILib v0.2
	- Icon-only sidebar, topbar (script name + tab name), subtabs, collapsible groupboxes
	- Components: Toggle (switch), Slider, Dropdown (single/multi), Input, Button (+side by side), Label, Divider
	- Lucide icons (Obsidian-compatible icon module: Module.GetAsset(name) -> { Url, ImageRectOffset, ImageRectSize })
	- Mobile: auto-fit scaling, touch dragging/sliders, floating open/close button
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local Library = {
	IsMobile = IsMobile,
	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
	DPIScale = 1,
	IconModule = nil,
	LucideUrl = "https://raw.githubusercontent.com/deividcomsono/lucide-roblox-direct/refs/heads/main/source.lua",
	Toggles = {},
	Options = {},
	Windows = {},
	Connections = {},
	Theme = {
		Background = Color3.fromRGB(11, 11, 11),
		Sidebar = Color3.fromRGB(9, 9, 9),
		Header = Color3.fromRGB(21, 21, 22),
		Panel = Color3.fromRGB(16, 16, 17),
		Control = Color3.fromRGB(27, 27, 29),
		ControlHover = Color3.fromRGB(34, 34, 37),
		Outline = Color3.fromRGB(30, 30, 32),
		Accent = Color3.fromRGB(15, 105, 245),
		Text = Color3.fromRGB(240, 240, 240),
		TextDim = Color3.fromRGB(112, 112, 118),
		Warning = Color3.fromRGB(255, 205, 70),
		Danger = Color3.fromRGB(238, 66, 66),
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

local SIDEBAR_W = 56
local TOPBAR_H = 52
local SUBTAB_H = 40
local HEADER_H = 34
local ROW_H = IsMobile and 26 or 22

--------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------

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
		inst.Font = Library.Font
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
	return New("UICorner", { CornerRadius = UDim.new(0, r), Parent = inst })
end

local function Stroke(inst, color, transparency)
	return New("UIStroke", {
		Color = color,
		Transparency = transparency or 0,
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

local function Tween(inst, props, time)
	TweenService:Create(inst, TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
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

local function PickColor(cfg)
	if cfg.Color then
		return cfg.Color
	elseif cfg.Warning then
		return Library.Theme.Danger
	elseif cfg.Risky then
		return Library.Theme.Warning
	end
	return nil
end

-- Works with the mouse and touch. onTap fires when released without moving.
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

--------------------------------------------------------------------
-- Icons (Lucide)
--------------------------------------------------------------------

function Library:SetIconModule(module)
	self.IconModule = module
end

-- Tries to load a Lucide module in the Obsidian format. Safe to fail.
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
	if name == nil then
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

-- fallback = text shown if the icon can't be resolved (default: first letter of the name)
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
			TextSize = math.max(size - 4, 8),
			Font = self.FontBold,
			Parent = holder,
		})
	end
	function icon:SetColor(c)
		if self.Image then
			Tween(self.Image, { ImageColor3 = c })
		else
			Tween(self.Fallback, { TextColor3 = c })
		end
	end
	return icon
end

--------------------------------------------------------------------
-- Window
--------------------------------------------------------------------

function Library:CreateWindow(cfg)
	cfg = cfg or {}
	local T = self.Theme

	if not self.IconModule and cfg.AutoLoadLucide ~= false then
		self:LoadLucide()
	end

	local window = setmetatable({ Tabs = {}, ActiveTab = nil }, WindowClass)

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

	local size = cfg.Size or (IsMobile and UDim2.fromOffset(600, 360) or UDim2.fromOffset(660, 460))
	local baseW, baseH = size.X.Offset, size.Y.Offset

	local main = New("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = T.Background,
		Parent = gui,
	})
	Corner(main, 8)
	Stroke(main, T.Outline)
	window.Main = main

	-- Fit to the screen (phones / small windows) -------------------
	local scale = New("UIScale", { Parent = main })
	window.Scale = scale
	local function fit()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local vp = cam.ViewportSize
		local s = math.min(1, (vp.X - 16) / baseW, (vp.Y - 16) / baseH)
		scale.Scale = math.max(s, 0.35) * Library.DPIScale
	end
	fit()
	if workspace.CurrentCamera then
		Connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), fit)
	end
	window.Fit = fit

	-- Sidebar --------------------------------------------------------
	local sidebar = New("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, SIDEBAR_W, 1, 0),
		BackgroundColor3 = T.Sidebar,
		Parent = main,
	})
	Corner(sidebar, 8)
	New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 10, 1, 0),
		BackgroundColor3 = T.Sidebar,
		Parent = sidebar,
	})
	New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = T.Outline,
		ZIndex = 2,
		Parent = sidebar,
	})

	local logo = self:CreateIcon(sidebar, cfg.Logo or cfg.Title or "?", 28, T.Accent)
	logo.Holder.AnchorPoint = Vector2.new(0.5, 0)
	logo.Holder.Position = UDim2.new(0.5, 0, 0, 14)

	window.TabList = New("Frame", {
		Name = "TabList",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 1, -62),
		Parent = sidebar,
	})
	do
		local l = List(window.TabList, 6)
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	window.BottomList = New("Frame", {
		Name = "BottomList",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -10),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = sidebar,
	})
	do
		local l = List(window.BottomList, 6)
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end

	-- Content + topbar -----------------------------------------------
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
	New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = T.Outline,
		Parent = topbar,
	})
	New("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(18, 9),
		Size = UDim2.new(1, -36, 0, 18),
		Text = cfg.Title or "Window",
		TextSize = 15,
		Font = self.FontBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = topbar,
	})
	window.TabLabel = New("TextLabel", {
		Name = "TabName",
		Position = UDim2.fromOffset(18, 29),
		Size = UDim2.new(1, -36, 0, 14),
		Text = "",
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

	-- Popup overlay (dropdown lists) ----------------------------------
	window.Overlay = New("Frame", {
		Name = "Overlay",
		Active = true,
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

	-- Tooltip (tab names on hover) ---------------------------------
	local tip = New("Frame", {
		Name = "Tooltip",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 24),
		BackgroundColor3 = T.Header,
		Visible = false,
		ZIndex = 90,
		Parent = main,
	})
	Corner(tip, 5)
	Stroke(tip, T.Outline)
	Pad(tip, 8, 0, 8, 0)
	local tipLabel = New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 24),
		Text = "",
		TextSize = 12,
		ZIndex = 91,
		Parent = tip,
	})
	window._ShowTip = function(gobj, text)
		local s = scale.Scale
		local mp = main.AbsolutePosition
		local bp, bs = gobj.AbsolutePosition, gobj.AbsoluteSize
		tipLabel.Text = text
		tip.Position = UDim2.fromOffset((bp.X - mp.X + bs.X) / s + 8, (bp.Y - mp.Y + bs.Y / 2) / s - 12)
		tip.Visible = true
	end
	window._HideTip = function()
		tip.Visible = false
	end

	-- Dragging --------------------------------------------------------
	MakeDraggable(topbar, main, nil, function()
		return scale.Scale
	end)

	-- Visibility ------------------------------------------------------
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
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = T.Background,
			ZIndex = 5,
			Parent = gui,
		})
		Corner(btn, 22)
		Stroke(btn, T.Outline)
		local mi = self:CreateIcon(btn, cfg.Logo or cfg.Title or "?", 24, T.Accent)
		mi.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
		mi.Holder.Position = UDim2.fromScale(0.5, 0.5)
		MakeDraggable(btn, btn, function()
			window:Toggle()
		end)
	end

	table.insert(self.Windows, window)
	return window
end

function WindowClass:SetVisible(v)
	self.Main.Visible = v
	if not v then
		self:ClosePopup()
		self._HideTip()
	end
end

function WindowClass:Toggle()
	self:SetVisible(not self.Main.Visible)
end

function WindowClass:ClosePopup()
	for _, c in ipairs(self.Overlay:GetChildren()) do
		c:Destroy()
	end
	self.Overlay.Visible = false
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
	self:ClosePopup()
	if self.ActiveTab then
		self.ActiveTab:_SetActive(false)
	end
	self.ActiveTab = tab
	tab:_SetActive(true)
	self.TabLabel.Text = tab.Name
end

-- Thin line in the sidebar to group tabs
function WindowClass:AddSidebarDivider(bottom)
	local holder = New("Frame", {
		Size = UDim2.fromOffset(24, 1),
		BackgroundColor3 = Library.Theme.Outline,
		LayoutOrder = 1000 + #self.Tabs,
		Parent = bottom and self.BottomList or self.TabList,
	})
	return holder
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

--------------------------------------------------------------------
-- Tabs (icon only)
--------------------------------------------------------------------

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
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = T.Control,
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = #self.Tabs,
		Parent = cfg.Bottom and self.BottomList or self.TabList,
	})
	Corner(button, 8)
	tab.Button = button
	tab.Icon = Library:CreateIcon(button, cfg.Icon or tab.Name, 20, T.TextDim)
	tab.Icon.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
	tab.Icon.Holder.Position = UDim2.fromScale(0.5, 0.5)

	local frame = New("Frame", {
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
		Size = UDim2.new(1, 0, 0, SUBTAB_H),
		Visible = false,
		Parent = frame,
	})
	do
		local l = List(tab.SubtabBar, 4, Enum.FillDirection.Horizontal)
		l.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	Pad(tab.SubtabBar, 12, 0, 12, 0)

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
			Tween(button, { BackgroundTransparency = 0.6 })
		end
		if not IsMobile then
			self._ShowTip(button, tab.Name)
		end
	end)
	Connect(button.MouseLeave, function()
		if self.ActiveTab ~= tab then
			Tween(button, { BackgroundTransparency = 1 })
		end
		self._HideTip()
	end)

	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then
		self:SelectTab(tab)
	end
	return tab
end

function TabClass:_SetActive(active)
	local T = Library.Theme
	self.Frame.Visible = active
	Tween(self.Button, { BackgroundTransparency = active and 0 or 1 })
	self.Icon:SetColor(active and T.Accent or T.TextDim)
end

-- The subtab bar only appears when there are 2+ subtabs
function TabClass:_UpdateLayout()
	local multi = #self.Subtabs > 1
	self.SubtabBar.Visible = multi
	local off = multi and SUBTAB_H or 0
	self.PageHolder.Position = UDim2.fromOffset(0, off)
	self.PageHolder.Size = UDim2.new(1, 0, 1, -off)
end

function TabClass:SelectSubtab(sub)
	if self.ActiveSubtab == sub then
		return
	end
	self.Window:ClosePopup()
	if self.ActiveSubtab then
		self.ActiveSubtab:_SetActive(false)
	end
	self.ActiveSubtab = sub
	sub:_SetActive(true)
end

--------------------------------------------------------------------
-- Subtabs
--------------------------------------------------------------------

function TabClass:AddSubtab(cfg, icon)
	if typeof(cfg) == "string" then
		cfg = { Name = cfg, Icon = icon }
	end
	local T = Library.Theme
	local sub = setmetatable({ Tab = self, Window = self.Window, Name = cfg.Name or "Subtab" }, SubtabClass)

	local button = New("TextButton", {
		Name = sub.Name,
		Size = UDim2.new(0, 0, 0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = T.Control,
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = #self.Subtabs,
		Parent = self.SubtabBar,
	})
	Corner(button, 6)
	Pad(button, 10, 0, 12, 0)
	do
		local l = List(button, 7, Enum.FillDirection.Horizontal)
		l.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	if cfg.Icon then
		sub.Icon = Library:CreateIcon(button, cfg.Icon, 14, T.TextDim)
		sub.Icon.Holder.LayoutOrder = 1
	end
	sub.Label = New("TextLabel", {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = sub.Name,
		TextColor3 = T.TextDim,
		LayoutOrder = 2,
		Parent = button,
	})
	sub.Button = button

	local page = New("Frame", {
		Name = sub.Name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = self.PageHolder,
	})
	Pad(page, 12, 10, 12, 8)
	sub.Page = page

	local function column(name, pos)
		local col = New("ScrollingFrame", {
			Name = name,
			BackgroundTransparency = 1,
			Position = pos,
			Size = UDim2.new(0.5, -5, 1, 0),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = T.Outline,
			Parent = page,
		})
		List(col, 10)
		Pad(col, 0, 0, 3, 0)
		return col
	end
	sub.Left = column("Left", UDim2.fromOffset(0, 0))
	sub.Right = column("Right", UDim2.new(0.5, 5, 0, 0))

	Connect(button.MouseButton1Click, function()
		self:SelectSubtab(sub)
	end)
	Connect(button.MouseEnter, function()
		if self.ActiveSubtab ~= sub then
			Tween(button, { BackgroundTransparency = 0.6 })
		end
	end)
	Connect(button.MouseLeave, function()
		if self.ActiveSubtab ~= sub then
			Tween(button, { BackgroundTransparency = 1 })
		end
	end)

	table.insert(self.Subtabs, sub)
	self:_UpdateLayout()
	if #self.Subtabs == 1 then
		self:SelectSubtab(sub)
	end
	return sub
end

function SubtabClass:_SetActive(active)
	local T = Library.Theme
	self.Page.Visible = active
	Tween(self.Button, { BackgroundTransparency = active and 0 or 1 })
	Tween(self.Label, { TextColor3 = active and T.Text or T.TextDim })
	if self.Icon then
		self.Icon:SetColor(active and T.Accent or T.TextDim)
	end
end

--------------------------------------------------------------------
-- Groupbox (collapsible)
--------------------------------------------------------------------

function SubtabClass:AddGroupbox(cfg, icon)
	if typeof(cfg) == "string" then
		cfg = { Name = cfg, Icon = icon }
	end
	local T = Library.Theme
	local side = string.lower(cfg.Side or "left")
	local parent = (side == "right") and self.Right or self.Left
	local box = setmetatable({ Subtab = self, Window = self.Window, Collapsed = false }, GroupboxClass)

	local frame = New("Frame", {
		Name = cfg.Name or "Groupbox",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Header,
		Parent = parent,
	})
	Corner(frame, 6)
	Stroke(frame, T.Outline)
	List(frame, 0)

	local header = New("TextButton", {
		Size = UDim2.new(1, 0, 0, HEADER_H),
		Text = "",
		LayoutOrder = 1,
		Parent = frame,
	})
	local nameX = 12
	if cfg.Icon then
		local gi = Library:CreateIcon(header, cfg.Icon, 15, T.Accent)
		gi.Holder.AnchorPoint = Vector2.new(0, 0.5)
		gi.Holder.Position = UDim2.new(0, 12, 0.5, 0)
		nameX = 34
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
	chevron.Holder.Position = UDim2.new(1, -20, 0.5, 0)

	local body = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Panel,
		LayoutOrder = 2,
		Parent = frame,
	})
	Corner(body, 6)
	New("Frame", { -- squares off the top corners of the body
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
	List(container, 9)
	Pad(container, 12, 12, 12, 12)

	function box:SetCollapsed(state)
		self.Collapsed = state
		body.Visible = not state
		Tween(chevron.Holder, { Rotation = state and -90 or 0 })
	end
	Connect(header.MouseButton1Click, function()
		box:SetCollapsed(not box.Collapsed)
	end)
	if cfg.Collapsed then
		box:SetCollapsed(true)
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

--------------------------------------------------------------------
-- Components
--------------------------------------------------------------------

local function Fire(obj, cfg, ...)
	if cfg.Callback then
		task.spawn(cfg.Callback, ...)
	end
	for _, fn in ipairs(obj.Changed) do
		task.spawn(fn, ...)
	end
end

-- Toggle (switch) ----------------------------------------------------
function GroupboxClass:AddToggle(idx, cfg)
	cfg = cfg or {}
	local T = Library.Theme
	local custom = PickColor(cfg)
	local toggle = { Type = "Toggle", Value = false, Changed = {} }

	local row = New("TextButton", {
		Name = tostring(idx),
		Size = UDim2.new(1, 0, 0, ROW_H),
		Text = "",
		Parent = self.Container,
	})
	local label = New("TextLabel", {
		Size = UDim2.new(1, -44, 1, 0),
		Text = cfg.Text or tostring(idx),
		TextColor3 = custom or T.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local track = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(32, 18),
		BackgroundColor3 = Color3.fromRGB(36, 36, 39),
		Parent = row,
	})
	Corner(track, 9)
	local trackStroke = Stroke(track, T.Outline)
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.fromRGB(92, 92, 98),
		Parent = track,
	})
	Corner(knob, 6)

	local function render(instant)
		local on = toggle.Value
		local t = instant and 0 or 0.16
		Tween(knob, {
			Position = UDim2.new(0, on and 17 or 3, 0.5, 0),
			BackgroundColor3 = on and T.Accent or Color3.fromRGB(92, 92, 98),
		}, t)
		Tween(trackStroke, { Color = on and T.Accent or T.Outline, Transparency = on and 0.55 or 0 }, t)
		if not custom then
			Tween(label, { TextColor3 = on and T.Text or T.TextDim }, t)
		end
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

	Connect(row.MouseButton1Click, function()
		toggle:SetValue(not toggle.Value)
	end)

	toggle.Value = cfg.Default and true or false
	render(true)
	Library.Toggles[idx] = toggle
	return toggle
end

-- Slider -------------------------------------------------------------
function GroupboxClass:AddSlider(idx, cfg)
	cfg = cfg or {}
	local T = Library.Theme
	local custom = PickColor(cfg)
	local min, max = cfg.Min or 0, cfg.Max or 100
	local rounding = cfg.Rounding or 0
	local suffix = cfg.Suffix or ""
	local slider = { Type = "Slider", Value = min, Min = min, Max = max, Changed = {} }

	local row = New("Frame", {
		Name = tostring(idx),
		Size = UDim2.new(1, 0, 0, IsMobile and 42 or 38),
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	New("TextLabel", {
		Size = UDim2.new(1, -64, 0, 16),
		Text = cfg.Text or tostring(idx),
		TextColor3 = custom or T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local valueLabel = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(60, 16),
		TextColor3 = custom or T.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
	local track = New("Frame", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = Color3.fromRGB(32, 32, 35),
		Parent = row,
	})
	Corner(track, 2)
	local fill = New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = T.Accent,
		Parent = track,
	})
	Corner(fill, 2)
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(16, 11),
		BackgroundColor3 = Color3.fromRGB(78, 78, 84),
		Parent = track,
	})
	Corner(knob, 3)
	local hit = New("TextButton", {
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 1, -14),
		Text = "",
		Parent = row,
	})

	local function render()
		local rel = (max == min) and 0 or (slider.Value - min) / (max - min)
		fill.Size = UDim2.fromScale(rel, 1)
		knob.Position = UDim2.new(rel, 0, 0.5, 0)
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

	local dragging = false
	local function fromX(x)
		local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		slider:SetValue(min + (max - min) * rel)
	end
	Connect(hit.InputBegan, function(input)
		if IsPress(input) then
			dragging = true
			fromX(input.Position.X)
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
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
	Library.Options[idx] = slider
	return slider
end

-- Dropdown (single / multi) -----------------------------------------
function GroupboxClass:AddDropdown(idx, cfg)
	cfg = cfg or {}
	local T = Library.Theme
	local window = self.Window
	local multi = cfg.Multi and true or false
	local dd = { Type = "Dropdown", Values = cfg.Values or {}, Multi = multi, Changed = {}, Value = multi and {} or nil }
	local hasLabel = cfg.Text ~= nil
	local ITEM_H = IsMobile and 28 or 24

	local row = New("Frame", {
		Name = tostring(idx),
		Size = UDim2.new(1, 0, 0, hasLabel and 48 or 28),
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	if hasLabel then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 16),
			Text = cfg.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
	end
	local box = New("TextButton", {
		Position = UDim2.fromOffset(0, hasLabel and 20 or 0),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = T.Control,
		Text = "",
		Parent = row,
	})
	Corner(box, 5)
	local boxStroke = Stroke(box, T.Outline)
	local valueLabel = New("TextLabel", {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -34, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = box,
	})
	local arrow = Library:CreateIcon(box, "chevron-down", 14, T.TextDim, "v")
	arrow.Holder.AnchorPoint = Vector2.new(1, 0.5)
	arrow.Holder.Position = UDim2.new(1, -9, 0.5, 0)

	local function display()
		if multi then
			local list = {}
			for _, v in ipairs(dd.Values) do
				if dd.Value[v] then
					table.insert(list, tostring(v))
				end
			end
			valueLabel.Text = #list > 0 and table.concat(list, ", ") or "None"
		else
			valueLabel.Text = dd.Value ~= nil and tostring(dd.Value) or "None"
		end
	end

	local refreshItems -- set while the popup is open

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
		window:ClosePopup()
		local ov = window.Overlay
		local s = window.Scale.Scale
		local mp = window.Main.AbsolutePosition
		local bp, bs = box.AbsolutePosition, box.AbsoluteSize
		local count = math.max(#dd.Values, 1)
		local h = math.min(count, 6) * ITEM_H + 8
		local x = (bp.X - mp.X) / s
		local y = (bp.Y - mp.Y + bs.Y) / s + 4
		if y + h > window.Main.AbsoluteSize.Y / s - 4 then
			y = (bp.Y - mp.Y) / s - h - 4
		end

		local popup = New("Frame", {
			Active = true,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(bs.X / s, h),
			BackgroundColor3 = T.Header,
			Parent = ov,
		})
		Corner(popup, 6)
		Stroke(popup, T.Outline)
		local list = New("ScrollingFrame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = T.Outline,
			Parent = popup,
		})
		List(list, 0)
		Pad(list, 4, 4, 4, 4)

		local items = {}
		for i, v in ipairs(dd.Values) do
			local item = New("TextButton", {
				Size = UDim2.new(1, 0, 0, ITEM_H),
				BackgroundColor3 = T.Control,
				BackgroundTransparency = 1,
				Text = tostring(v),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = i,
				Parent = list,
			})
			Corner(item, 4)
			Pad(item, 8, 0, 8, 0)
			local dot = New("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(6, 6),
				BackgroundColor3 = T.Accent,
				Visible = false,
				Parent = item,
			})
			Corner(dot, 3)
			items[v] = { Item = item, Dot = dot }
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
				Tween(item, { BackgroundTransparency = 0.4 }, 0.08)
			end)
			Connect(item.MouseLeave, function()
				local sel = multi and dd.Value[v] or (dd.Value == v)
				Tween(item, { BackgroundTransparency = sel and 0 or 1 }, 0.08)
			end)
		end

		refreshItems = function()
			for v, o in pairs(items) do
				local sel = multi and dd.Value[v] or (dd.Value == v)
				o.Item.TextColor3 = sel and T.Text or T.TextDim
				o.Item.BackgroundTransparency = sel and 0 or 1
				o.Dot.Visible = multi and sel and true or false
			end
		end
		refreshItems()

		ov.Visible = true
		Tween(boxStroke, { Color = T.Accent }, 0.12)
		Tween(arrow.Holder, { Rotation = 180 }, 0.12)
		window.PopupClosed = function()
			refreshItems = nil
			Tween(boxStroke, { Color = T.Outline }, 0.12)
			Tween(arrow.Holder, { Rotation = 0 }, 0.12)
		end
	end

	Connect(box.MouseButton1Click, open)
	Connect(box.MouseEnter, function()
		Tween(box, { BackgroundColor3 = T.ControlHover }, 0.1)
	end)
	Connect(box.MouseLeave, function()
		Tween(box, { BackgroundColor3 = T.Control }, 0.1)
	end)

	dd:SetValue(cfg.Default, true)
	Library.Options[idx] = dd
	return dd
end

-- Input --------------------------------------------------------------
function GroupboxClass:AddInput(idx, cfg)
	cfg = cfg or {}
	local T = Library.Theme
	local input = { Type = "Input", Value = cfg.Default or "", Changed = {} }
	local hasLabel = cfg.Text ~= nil

	local row = New("Frame", {
		Name = tostring(idx),
		Size = UDim2.new(1, 0, 0, hasLabel and 48 or 28),
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	if hasLabel then
		New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 16),
			Text = cfg.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
	end
	local back = New("Frame", {
		Position = UDim2.fromOffset(0, hasLabel and 20 or 0),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = T.Control,
		Parent = row,
	})
	Corner(back, 5)
	local stroke = Stroke(back, T.Outline)
	local box = New("TextBox", {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Text = input.Value,
		PlaceholderText = cfg.Placeholder or "",
		PlaceholderColor3 = T.TextDim,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = back,
	})

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

	Connect(box.Focused, function()
		Tween(stroke, { Color = T.Accent }, 0.12)
	end)
	Connect(box.FocusLost, function()
		Tween(stroke, { Color = T.Outline }, 0.12)
		if box.Text ~= input.Value then
			input:SetValue(box.Text)
		end
	end)
	if cfg.Finished == false then
		Connect(box:GetPropertyChangedSignal("Text"), function()
			if box.Text ~= input.Value then
				input.Value = box.Text
				Fire(input, cfg, box.Text)
			end
		end)
	end

	Library.Options[idx] = input
	return input
end

-- Button (+ side-by-side buttons via :AddButton) ---------------------
function GroupboxClass:AddButton(cfg)
	if typeof(cfg) == "string" then
		cfg = { Text = cfg }
	end
	local T = Library.Theme
	local GAP = 6
	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, IsMobile and 32 or 28),
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	local buttons = {}

	local function layout()
		local n = #buttons
		for i, b in ipairs(buttons) do
			b.Size = UDim2.new(1 / n, -GAP * (n - 1) / n, 1, 0)
			b.Position = UDim2.new((i - 1) / n, (i - 1) * GAP / n, 0, 0)
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
			Parent = row,
		})
		Corner(b, 5)
		Stroke(b, T.Outline)
		table.insert(buttons, b)
		layout()

		local obj = { Button = b }
		local pending = false
		Connect(b.MouseEnter, function()
			Tween(b, { BackgroundColor3 = T.ControlHover, TextColor3 = T.Text }, 0.1)
		end)
		Connect(b.MouseLeave, function()
			Tween(b, { BackgroundColor3 = T.Control, TextColor3 = T.TextDim }, 0.1)
		end)
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

-- Label ----------------------------------------------------------------
function GroupboxClass:AddLabel(cfg)
	if typeof(cfg) == "string" then
		cfg = { Text = cfg }
	end
	local T = Library.Theme
	local custom = PickColor(cfg)
	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	List(row, 2)
	local label = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = cfg.Text or "",
		TextColor3 = custom or T.Text,
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

-- Divider (optional centered text) ---------------------------------
function GroupboxClass:AddDivider(text)
	local T = Library.Theme
	if not text then
		return New("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = T.Outline,
			Parent = self.Container,
		})
	end
	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = T.Outline,
		Parent = row,
	})
	local l = New("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		BackgroundColor3 = T.Panel,
		Text = text,
		TextColor3 = T.TextDim,
		TextSize = 12,
		Parent = row,
	})
	Pad(l, 8, 0, 8, 0)
	return row
end

return Library
