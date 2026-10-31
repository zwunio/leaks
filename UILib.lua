--[[
	UILib - Step 1
	Window / Sidebar (icon-only tabs) / Topbar / Subtabs / Groupbox / Toggle (Obsidian style)
	Lucide icons through an Obsidian-compatible icon module.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Library = {
	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
	IconModule = nil,
	Toggles = {},
	Windows = {},
	Theme = {
		Background = Color3.fromRGB(12, 12, 12),
		Sidebar = Color3.fromRGB(9, 9, 9),
		Panel = Color3.fromRGB(18, 18, 18),
		Control = Color3.fromRGB(27, 27, 27),
		Outline = Color3.fromRGB(36, 36, 36),
		Accent = Color3.fromRGB(20, 110, 245),
		Text = Color3.fromRGB(255, 255, 255),
		TextDim = Color3.fromRGB(125, 125, 125),
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

--------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------

local function New(class, props)
	local inst = Instance.new(class)
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") then
		inst.BackgroundTransparency = 1
		inst.Font = Library.Font
		inst.TextSize = 13
		inst.TextColor3 = Library.Theme.Text
		if inst:IsA("TextButton") then
			inst.AutoButtonColor = false
		end
	elseif inst:IsA("ImageLabel") then
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

local function Corner(inst, radius)
	return New("UICorner", { CornerRadius = UDim.new(0, radius), Parent = inst })
end

local function Stroke(inst, color, thickness)
	return New("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
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

local function Tween(inst, props, time)
	TweenService:Create(inst, TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
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

--------------------------------------------------------------------
-- Icons
--------------------------------------------------------------------

-- Module must follow the Obsidian format: Module.GetAsset(name) -> { Url, ImageRectOffset, ImageRectSize }
function Library:SetIconModule(module)
	self.IconModule = module
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

-- Creates an icon (Lucide name / rbxassetid / number). Falls back to the first letter if no icon is found.
function Library:CreateIcon(parent, name, size, color)
	local holder = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	local icon = { Holder = holder }
	local img = New("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		ImageColor3 = color,
		Parent = holder,
	})
	if self:ApplyIcon(img, name) then
		icon.Image = img
	else
		img:Destroy()
		local letter = string.upper(string.sub(string.gsub(tostring(name or "?"), "^lucide[-_:]", ""), 1, 1))
		icon.Fallback = New("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = letter,
			TextColor3 = color,
			TextSize = size - 4,
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

local SIDEBAR_WIDTH = 56
local TOPBAR_HEIGHT = 50
local SUBTAB_HEIGHT = 36

function Library:CreateWindow(cfg)
	cfg = cfg or {}
	local T = self.Theme

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

	local main = New("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = cfg.Size or UDim2.fromOffset(640, 420),
		BackgroundColor3 = T.Background,
		Parent = gui,
	})
	Corner(main, 6)
	Stroke(main, T.Outline)
	window.Main = main

	-- Sidebar ------------------------------------------------------
	local sidebar = New("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0),
		BackgroundColor3 = T.Sidebar,
		Parent = main,
	})
	Corner(sidebar, 6)
	-- squares off the right side of the rounded sidebar
	New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 8, 1, 0),
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
	logo.Holder.Position = UDim2.new(0.5, 0, 0, 12)

	local tabList = New("Frame", {
		Name = "TabList",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -56),
		Parent = sidebar,
	})
	New("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabList,
	})
	window.TabList = tabList

	-- Content area + topbar ---------------------------------------
	local content = New("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(SIDEBAR_WIDTH, 0),
		Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, 0),
		Parent = main,
	})

	local topbar = New("Frame", {
		Name = "Topbar",
		Active = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TOPBAR_HEIGHT),
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
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 18),
		Text = cfg.Title or "Window",
		TextSize = 15,
		Font = self.FontBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = topbar,
	})
	window.TabLabel = New("TextLabel", {
		Name = "TabName",
		Position = UDim2.fromOffset(16, 27),
		Size = UDim2.new(1, -32, 0, 14),
		Text = "",
		TextSize = 12,
		TextColor3 = T.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = topbar,
	})

	window.TabHolder = New("Frame", {
		Name = "TabHolder",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, TOPBAR_HEIGHT),
		Size = UDim2.new(1, 0, 1, -TOPBAR_HEIGHT),
		Parent = content,
	})

	-- Dragging (topbar) --------------------------------------------
	local dragging, dragStart, startPos = false, nil, nil
	topbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)

	-- Toggle visibility --------------------------------------------
	local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == toggleKey then
			gui.Enabled = not gui.Enabled
		end
	end)

	table.insert(self.Windows, window)
	return window
end

function WindowClass:SelectTab(tab)
	if self.ActiveTab == tab then
		return
	end
	if self.ActiveTab then
		self.ActiveTab:_SetActive(false)
	end
	self.ActiveTab = tab
	tab:_SetActive(true)
	self.TabLabel.Text = tab.Name
end

function WindowClass:Destroy()
	self.Gui:Destroy()
end

--------------------------------------------------------------------
-- Tab (icon only, lives in the sidebar)
--------------------------------------------------------------------

function WindowClass:AddTab(cfg)
	if typeof(cfg) == "string" then
		cfg = { Name = cfg }
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
		Parent = self.TabList,
	})
	Corner(button, 6)
	tab.Button = button

	tab.Icon = Library:CreateIcon(button, cfg.Icon or tab.Name, 20, T.TextDim)
	tab.Icon.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
	tab.Icon.Holder.Position = UDim2.fromScale(0.5, 0.5)

	-- Frame that holds subtab bar + pages
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
		Size = UDim2.new(1, 0, 0, SUBTAB_HEIGHT),
		Visible = false,
		Parent = frame,
	})
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tab.SubtabBar,
	})
	Pad(tab.SubtabBar, 8, 0, 8, 0)
	New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = T.Outline,
		BorderSizePixel = 0,
		Parent = tab.SubtabBar,
	})

	tab.PageHolder = New("Frame", {
		Name = "PageHolder",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	})

	button.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end)
	button.MouseEnter:Connect(function()
		if self.ActiveTab ~= tab then
			Tween(button, { BackgroundTransparency = 0.6 })
		end
	end)
	button.MouseLeave:Connect(function()
		if self.ActiveTab ~= tab then
			Tween(button, { BackgroundTransparency = 1 })
		end
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

-- Subtab bar is only shown when the tab has 2+ subtabs
function TabClass:_UpdateLayout()
	local multi = #self.Subtabs > 1
	self.SubtabBar.Visible = multi
	local offset = multi and SUBTAB_HEIGHT or 0
	self.PageHolder.Position = UDim2.fromOffset(0, offset)
	self.PageHolder.Size = UDim2.new(1, 0, 1, -offset)
end

function TabClass:SelectSubtab(sub)
	if self.ActiveSubtab == sub then
		return
	end
	if self.ActiveSubtab then
		self.ActiveSubtab:_SetActive(false)
	end
	self.ActiveSubtab = sub
	sub:_SetActive(true)
end

--------------------------------------------------------------------
-- Subtab (tabs inside a tab)
--------------------------------------------------------------------

function TabClass:AddSubtab(cfg)
	if typeof(cfg) == "string" then
		cfg = { Name = cfg }
	end
	local T = Library.Theme
	local sub = setmetatable({
		Tab = self,
		Name = cfg.Name or "Subtab",
	}, SubtabClass)

	local button = New("TextButton", {
		Name = sub.Name,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "",
		LayoutOrder = #self.Subtabs,
		Parent = self.SubtabBar,
	})
	Pad(button, 10, 0, 10, 0)

	local inner = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = button,
	})
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = inner,
	})

	if cfg.Icon then
		sub.Icon = Library:CreateIcon(inner, cfg.Icon, 14, T.TextDim)
		sub.Icon.Holder.LayoutOrder = 1
	end
	sub.Label = New("TextLabel", {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = sub.Name,
		TextColor3 = T.TextDim,
		LayoutOrder = 2,
		Parent = inner,
	})
	sub.Underline = New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = T.Accent,
		BackgroundTransparency = 1,
		Parent = button,
	})
	sub.Button = button

	-- Page: two scrolling columns
	local page = New("Frame", {
		Name = sub.Name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = self.PageHolder,
	})
	Pad(page, 10, 10, 10, 6)
	sub.Page = page

	local function column(name, position, anchor)
		local col = New("ScrollingFrame", {
			Name = name,
			BackgroundTransparency = 1,
			Position = position,
			Size = UDim2.new(0.5, -5, 1, 0),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = T.Outline,
			Parent = page,
		})
		New("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = col,
		})
		Pad(col, 0, 0, 3, 0)
		return col
	end
	sub.Left = column("Left", UDim2.fromOffset(0, 0))
	sub.Right = column("Right", UDim2.new(0.5, 5, 0, 0))

	button.MouseButton1Click:Connect(function()
		self:SelectSubtab(sub)
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
	Tween(self.Underline, { BackgroundTransparency = active and 0 or 1 })
	Tween(self.Label, { TextColor3 = active and T.Text or T.TextDim })
	if self.Icon then
		self.Icon:SetColor(active and T.Accent or T.TextDim)
	end
end

--------------------------------------------------------------------
-- Groupbox
--------------------------------------------------------------------

function SubtabClass:AddGroupbox(cfg)
	if typeof(cfg) == "string" then
		cfg = { Name = cfg }
	end
	local T = Library.Theme
	local side = string.lower(cfg.Side or "left")
	local parent = (side == "right") and self.Right or self.Left

	local box = setmetatable({ Subtab = self }, GroupboxClass)

	local frame = New("Frame", {
		Name = cfg.Name or "Groupbox",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Panel,
		Parent = parent,
	})
	Corner(frame, 5)
	Stroke(frame, T.Outline)
	New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })

	local header = New("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = frame,
	})
	New("TextLabel", {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Text = cfg.Name or "Groupbox",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = T.Outline,
		Parent = header,
	})

	local container = New("Frame", {
		Name = "Container",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = frame,
	})
	New("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = container,
	})
	Pad(container, 10, 10, 10, 10)

	box.Frame = frame
	box.Container = container
	return box
end

--------------------------------------------------------------------
-- Toggle (Obsidian style: checkbox on the left, label on the right)
--------------------------------------------------------------------

function GroupboxClass:AddToggle(idx, cfg)
	cfg = cfg or {}
	local T = Library.Theme

	local toggle = {
		Type = "Toggle",
		Value = false,
		Changed = {},
	}

	local row = New("TextButton", {
		Name = tostring(idx),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		Parent = self.Container,
	})
	local box = New("Frame", {
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = T.Control,
		Parent = row,
	})
	Corner(box, 4)
	local stroke = Stroke(box, T.Outline)

	local check = New("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		ImageColor3 = T.Text,
		ImageTransparency = 1,
		Parent = box,
	})
	Library:ApplyIcon(check, "check")

	local label = New("TextLabel", {
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Text = cfg.Text or tostring(idx),
		TextColor3 = T.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local function render(instant)
		local on = toggle.Value
		local time = instant and 0 or 0.15
		Tween(box, { BackgroundColor3 = on and T.Accent or T.Control }, time)
		Tween(stroke, { Color = on and T.Accent or T.Outline }, time)
		Tween(check, { ImageTransparency = on and 0 or 1 }, time)
		Tween(label, { TextColor3 = on and T.Text or T.TextDim }, time)
	end

	function toggle:SetValue(value, silent)
		value = value and true or false
		if self.Value == value then
			return
		end
		self.Value = value
		render()
		if silent then
			return
		end
		if cfg.Callback then
			task.spawn(cfg.Callback, value)
		end
		for _, fn in ipairs(self.Changed) do
			task.spawn(fn, value)
		end
	end

	function toggle:OnChanged(fn)
		table.insert(self.Changed, fn)
	end

	function toggle:SetText(text)
		label.Text = text
	end

	row.MouseButton1Click:Connect(function()
		toggle:SetValue(not toggle.Value)
	end)

	toggle.Value = cfg.Default and true or false
	render(true)

	Library.Toggles[idx] = toggle
	return toggle
end

return Library
