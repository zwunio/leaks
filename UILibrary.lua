--[[
    UILibrary.lua
    A standalone Roblox UI library (topbar + tabs + subtabs + elements).
    Drop into a ModuleScript (or loadstring it) and `local UI = require(...)`.

    USAGE:
        local UI = loadstring(game:HttpGet("...UILibrary.lua"))()

        local Window = UI:CreateWindow({
            Title = "sportsclub",
            SubTitle = "Bloxstrike",
        })

        local AimTab = Window:CreateTab("Aim Assistance", "Aimbot, silent aim and trigger settings")
        local Aimbot = AimTab:CreateSubTab("Aimbot", "Core aimbot behaviour")

        Aimbot:CreateToggle({
            Text = "Enabled",
            Description = "This is a description",
            Default = true,
            Callback = function(value) end,
        })

        Aimbot:CreateSlider({
            Text = "FOV Size",
            Min = 0, Max = 100, Default = 50,
            Suffix = "%",
            Callback = function(value) end,
        })
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// ================= THEME =================
local Theme = {
    Background      = Color3.fromRGB(18, 18, 20),
    Sidebar         = Color3.fromRGB(14, 14, 16),
    Panel           = Color3.fromRGB(24, 24, 27),
    PanelAlt        = Color3.fromRGB(28, 28, 32),
    Border          = Color3.fromRGB(38, 38, 42),
    Accent          = Color3.fromRGB(59, 130, 246),   -- blue
    AccentDim       = Color3.fromRGB(37, 80, 160),
    Text            = Color3.fromRGB(235, 235, 240),
    TextDim         = Color3.fromRGB(150, 150, 158),
    TextFaint       = Color3.fromRGB(100, 100, 108),
    TrackOff        = Color3.fromRGB(50, 50, 55),
    TrackOn         = Color3.fromRGB(59, 130, 246),
    Font            = Enum.Font.GothamMedium,
    FontBold        = Enum.Font.GothamBold,
    FontRegular     = Enum.Font.Gotham,
    Corner          = UDim.new(0, 6),
    CornerSmall     = UDim.new(0, 4),
}

--// ================= UTIL =================
local function create(className, props, children)
    local inst = Instance.new(className)
    for prop, value in pairs(props or {}) do
        inst[prop] = value
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    return inst
end

local function tween(obj, props, time, style, dir)
    return TweenService:Create(
        obj,
        TweenInfo.new(time or 0.18, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
end

local function corner(radius)
    return create("UICorner", { CornerRadius = radius or Theme.Corner })
end

local function stroke(color, thickness)
    return create("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function round(n, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(n * mult + 0.5) / mult
end

--// ================= LIBRARY =================
local Library = {}
Library.__index = Library

function Library:CreateWindow(config)
    config = config or {}
    local windowTitle = config.Title or "Window"
    local windowSubTitle = config.SubTitle or ""

    -- remove previous instance of this lib if re-run
    local existing = PlayerGui:FindFirstChild("UILibraryRoot")
    if existing then existing:Destroy() end

    local ScreenGui = create("ScreenGui", {
        Name = "UILibraryRoot",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = PlayerGui,
    })

    local Root = create("Frame", {
        Name = "Root",
        Size = UDim2.fromOffset(820, 520),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Background,
        Parent = ScreenGui,
    }, { corner(UDim.new(0, 10)), stroke(Theme.Border, 1) })
    create("UIStroke", {Color = Theme.Border, Thickness=1}, {}).Parent = Root

    -- drag
    do
        local dragging, dragStart, startPos
        local dragHandle = Root
        dragHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and input.Position.Y - Root.AbsolutePosition.Y < 50 then
                dragging = true
                dragStart = input.Position
                startPos = Root.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                Root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end

    --// ===== TOPBAR =====
    local TopBar = create("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = Theme.Sidebar,
        Parent = Root,
    }, {
        create("UICorner", { CornerRadius = UDim.new(0, 10) }),
    })
    -- square off bottom corners of topbar via a mask frame
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = TopBar,
    })
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Parent = TopBar,
    })

    local Logo = create("Frame", {
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.fromOffset(16, 11),
        BackgroundColor3 = Theme.Accent,
        Parent = TopBar,
    }, { corner(UDim.new(0, 6)) })
    create("TextLabel", {
        Text = windowTitle:sub(1,1):upper(),
        Font = Theme.FontBold,
        TextSize = 15,
        TextColor3 = Color3.new(1,1,1),
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1,1),
        Parent = Logo,
    })

    create("TextLabel", {
        Text = windowTitle,
        Font = Theme.FontBold,
        TextSize = 14,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(54, 9),
        Size = UDim2.fromOffset(200, 16),
        Parent = TopBar,
    })
    create("TextLabel", {
        Text = windowSubTitle,
        Font = Theme.FontRegular,
        TextSize = 12,
        TextColor3 = Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(54, 25),
        Size = UDim2.fromOffset(200, 16),
        Parent = TopBar,
    })

    -- middle: active tab name + description
    local ActiveTabLabel = create("TextLabel", {
        Text = "",
        Font = Theme.FontBold,
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 8),
        Size = UDim2.fromOffset(300, 16),
        Parent = TopBar,
    })
    local ActiveTabDesc = create("TextLabel", {
        Text = "",
        Font = Theme.FontRegular,
        TextSize = 11,
        TextColor3 = Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 25),
        Size = UDim2.fromOffset(340, 16),
        Parent = TopBar,
    })

    -- right: search
    local SearchBox = create("Frame", {
        Size = UDim2.fromOffset(170, 30),
        Position = UDim2.new(1, -186, 0, 10),
        BackgroundColor3 = Theme.Panel,
        Parent = TopBar,
    }, { corner(UDim.new(0, 6)), stroke(Theme.Border, 1) })
    create("TextLabel", {
        Text = "🔍",
        Font = Theme.FontRegular,
        TextSize = 12,
        TextColor3 = Theme.TextFaint,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, 0),
        Size = UDim2.fromOffset(18, 30),
        Parent = SearchBox,
    })
    local SearchInput = create("TextBox", {
        Text = "",
        PlaceholderText = "Search...",
        Font = Theme.FontRegular,
        TextSize = 12,
        TextColor3 = Theme.Text,
        PlaceholderColor3 = Theme.TextFaint,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        ClearTextOnFocus = false,
        Position = UDim2.fromOffset(28, 0),
        Size = UDim2.fromOffset(130, 30),
        Parent = SearchBox,
    })

    --// ===== SIDEBAR (tab list) =====
    local Sidebar = create("ScrollingFrame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 170, 1, -60),
        Position = UDim2.fromOffset(0, 54),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Border,
        CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = Root,
    }, {
        create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
        create("UIPadding", { PaddingTop = UDim.new(0,8), PaddingLeft = UDim.new(0,10), PaddingRight = UDim.new(0,10) }),
    })

    -- vertical divider
    create("Frame", {
        Size = UDim2.new(0, 1, 1, -60),
        Position = UDim2.fromOffset(170, 54),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Parent = Root,
    })

    --// ===== CONTENT AREA =====
    local ContentArea = create("Frame", {
        Name = "ContentArea",
        Size = UDim2.new(1, -171, 1, -60),
        Position = UDim2.fromOffset(171, 54),
        BackgroundTransparency = 1,
        Parent = Root,
    })

    local Window = setmetatable({
        _root = Root,
        _sidebar = Sidebar,
        _contentArea = ContentArea,
        _activeTabLabel = ActiveTabLabel,
        _activeTabDesc = ActiveTabDesc,
        _tabs = {},
        _currentTab = nil,
    }, { __index = {} })

    --// ================= TAB =================
    local TabMethods = {}
    TabMethods.__index = TabMethods

    function Window:CreateTab(name, description)
        local order = #self._tabs + 1

        local TabButton = create("TextButton", {
            Text = "",
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = Theme.Panel,
            BackgroundTransparency = 1,
            LayoutOrder = order,
            Parent = self._sidebar,
        }, { corner(Theme.CornerSmall) })

        local activeBar = create("Frame", {
            Size = UDim2.new(0, 3, 0, 16),
            Position = UDim2.fromOffset(0, 9),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1,
            Parent = TabButton,
        }, { corner(UDim.new(1,0)) })

        create("TextLabel", {
            Text = name,
            Font = Theme.Font,
            TextSize = 13,
            TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(14, 0),
            Size = UDim2.new(1, -20, 1, 0),
            Name = "Label",
            Parent = TabButton,
        })

        local Page = create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Visible = false,
            Parent = self._contentArea,
        })

        -- sub-tab strip (only shown if subtabs exist)
        local SubTabStrip = create("Frame", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 1,
            Visible = false,
            Parent = Page,
        }, {
            create("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                Padding = UDim.new(0, 6),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingTop = UDim.new(0, 4) }),
        })

        local SubPageHolder = create("Frame", {
            Size = UDim2.new(1, 0, 1, -34),
            Position = UDim2.fromOffset(0, 34),
            BackgroundTransparency = 1,
            Parent = Page,
        })

        -- a default content page used if the tab has no subtabs
        local DirectPage = create("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Border,
            CanvasSize = UDim2.new(0,0,0,0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Parent = Page,
        }, {
            create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
            create("UIPadding", {
                PaddingTop = UDim.new(0, 14), PaddingLeft = UDim.new(0, 16),
                PaddingRight = UDim.new(0, 16), PaddingBottom = UDim.new(0, 14),
            }),
        })

        local Tab = setmetatable({
            _window = self,
            _button = TabButton,
            _activeBar = activeBar,
            _label = TabButton.Label,
            _page = Page,
            _directPage = DirectPage,
            _subTabStrip = SubTabStrip,
            _subPageHolder = SubPageHolder,
            _subTabs = {},
            _name = name,
            _description = description or "",
            _order = order,
        }, TabMethods)

        table.insert(self._tabs, Tab)

        local function setActive(tab)
            for _, t in ipairs(self._tabs) do
                local isActive = (t == tab)
                t._page.Visible = isActive
                tween(t._label, { TextColor3 = isActive and Theme.Text or Theme.TextDim }, 0.15):Play()
                tween(t._activeBar, { BackgroundTransparency = isActive and 0 or 1 }, 0.15):Play()
            end
            self._activeTabLabel.Text = tab._name
            self._activeTabDesc.Text = tab._description
            self._currentTab = tab
        end

        TabButton.MouseButton1Click:Connect(function()
            setActive(Tab)
        end)
        TabButton.MouseEnter:Connect(function()
            if self._currentTab ~= Tab then
                tween(TabButton, { BackgroundTransparency = 0.5 }, 0.12):Play()
            end
        end)
        TabButton.MouseLeave:Connect(function()
            tween(TabButton, { BackgroundTransparency = 1 }, 0.12):Play()
        end)

        if order == 1 then
            setActive(Tab)
        end

        Tab._setActive = setActive
        return Tab
    end

    --// ================= SUBTAB =================
    local SubTabMethods = {}
    SubTabMethods.__index = SubTabMethods

    function TabMethods:CreateSubTab(name, description)
        -- first subtab created: hide direct page, show strip
        if #self._subTabs == 0 then
            self._directPage.Visible = false
            self._subTabStrip.Visible = true
        end

        local order = #self._subTabs + 1

        local Btn = create("TextButton", {
            Text = name,
            Font = Theme.Font,
            TextSize = 12,
            TextColor3 = Theme.TextDim,
            AutoButtonColor = false,
            BackgroundColor3 = Theme.Panel,
            Size = UDim2.fromOffset(0, 26),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = order,
            Parent = self._subTabStrip,
        }, {
            corner(Theme.CornerSmall),
            create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
        })

        local Page = create("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Border,
            CanvasSize = UDim2.new(0,0,0,0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
            Parent = self._subPageHolder,
        }, {
            create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
            create("UIPadding", {
                PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 16),
                PaddingRight = UDim.new(0, 16), PaddingBottom = UDim.new(0, 14),
            }),
        })

        local SubTab = setmetatable({
            _tab = self,
            _button = Btn,
            _page = Page,
            _name = name,
            _description = description or "",
        }, SubTabMethods)

        table.insert(self._subTabs, SubTab)

        local function setActive()
            for _, st in ipairs(self._subTabs) do
                local isActive = (st == SubTab)
                st._page.Visible = isActive
                tween(st._button, {
                    BackgroundColor3 = isActive and Theme.Accent or Theme.Panel,
                    TextColor3 = isActive and Color3.new(1,1,1) or Theme.TextDim,
                }, 0.15):Play()
            end
        end

        Btn.MouseButton1Click:Connect(setActive)

        if order == 1 then
            setActive()
        end

        return SubTab
    end

    --// ================= ELEMENTS =================
    -- shared element-builder, used by both TabMethods (direct page) and SubTabMethods
    local function buildElementFactory(getParent)
        local factory = {}

        function factory.CreateSection(_, text)
            create("TextLabel", {
                Text = text,
                Font = Theme.FontBold,
                TextSize = 12,
                TextColor3 = Theme.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Parent = getParent(),
            })
        end

        function factory.CreateLabel(_, text)
            create("TextLabel", {
                Text = text,
                Font = Theme.FontRegular,
                TextSize = 12,
                TextColor3 = Theme.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                Size = UDim2.new(1, 0, 0, 0),
                Parent = getParent(),
            })
        end

        function factory.CreateToggle(_, opts)
            opts = opts or {}
            local state = opts.Default or false

            local Holder = create("Frame", {
                Size = UDim2.new(1, 0, 0, opts.Description and 40 or 32),
                BackgroundColor3 = Theme.Panel,
                Parent = getParent(),
            }, { corner(), create("UIPadding", {
                PaddingLeft = UDim.new(0,12), PaddingRight = UDim.new(0,12), PaddingTop=UDim.new(0,0)
            }) })

            create("TextLabel", {
                Text = opts.Text or "Toggle",
                Font = Theme.Font,
                TextSize = 13,
                TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, opts.Description and 6 or 0),
                Size = UDim2.new(1, -60, 0, 18),
                Parent = Holder,
            })
            if opts.Description then
                create("TextLabel", {
                    Text = opts.Description,
                    Font = Theme.FontRegular,
                    TextSize = 11,
                    TextColor3 = Theme.TextFaint,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(0, 22),
                    Size = UDim2.new(1, -60, 0, 14),
                    Parent = Holder,
                })
            end

            -- redesigned switch: track + thumb, clear on/off color, smooth thumb slide
            local SwitchBtn = create("TextButton", {
                Text = "",
                AutoButtonColor = false,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(38, 20),
                BackgroundColor3 = state and Theme.TrackOn or Theme.TrackOff,
                Parent = Holder,
            }, { corner(UDim.new(1, 0)) })

            local Thumb = create("Frame", {
                Size = UDim2.fromOffset(16, 16),
                Position = state and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                Parent = SwitchBtn,
            }, { corner(UDim.new(1, 0)) })

            local function refresh(animate)
                local track = state and Theme.TrackOn or Theme.TrackOff
                local pos = state and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
                if animate then
                    tween(SwitchBtn, { BackgroundColor3 = track }, 0.15):Play()
                    tween(Thumb, { Position = pos }, 0.15, Enum.EasingStyle.Quad):Play()
                else
                    SwitchBtn.BackgroundColor3 = track
                    Thumb.Position = pos
                end
            end
            refresh(false)

            local toggleObj = {}
            SwitchBtn.MouseButton1Click:Connect(function()
                state = not state
                refresh(true)
                if opts.Callback then opts.Callback(state) end
            end)

            function toggleObj:Set(value)
                state = value
                refresh(true)
                if opts.Callback then opts.Callback(state) end
            end
            function toggleObj:Get()
                return state
            end

            return toggleObj
        end

        function factory.CreateSlider(_, opts)
            opts = opts or {}
            local min = opts.Min or 0
            local max = opts.Max or 100
            local decimals = opts.Decimals or 0
            local suffix = opts.Suffix or ""
            local value = math.clamp(opts.Default or min, min, max)

            local Holder = create("Frame", {
                Size = UDim2.new(1, 0, 0, 46),
                BackgroundColor3 = Theme.Panel,
                Parent = getParent(),
            }, { corner(), create("UIPadding", { PaddingLeft = UDim.new(0,12), PaddingRight = UDim.new(0,12) }) })

            create("TextLabel", {
                Text = opts.Text or "Slider",
                Font = Theme.Font,
                TextSize = 13,
                TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, 6),
                Size = UDim2.new(1, -80, 0, 16),
                Parent = Holder,
            })

            local ValueLabel = create("TextLabel", {
                Text = tostring(round(value, decimals)) .. suffix,
                Font = Theme.FontBold,
                TextSize = 12,
                TextColor3 = Theme.Accent,
                TextXAlignment = Enum.TextXAlignment.Right,
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, 0, 0, 6),
                Size = UDim2.fromOffset(60, 16),
                Parent = Holder,
            })

            -- track with filled progress + draggable thumb (not just a flat bar)
            local Track = create("Frame", {
                Size = UDim2.new(1, 0, 0, 6),
                Position = UDim2.fromOffset(0, 32),
                BackgroundColor3 = Theme.TrackOff,
                Parent = Holder,
            }, { corner(UDim.new(1, 0)) })

            local Fill = create("Frame", {
                Size = UDim2.fromScale(0, 1),
                BackgroundColor3 = Theme.Accent,
                Parent = Track,
            }, { corner(UDim.new(1, 0)) })

            local Thumb = create("Frame", {
                Size = UDim2.fromOffset(14, 14),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                BackgroundColor3 = Color3.new(1, 1, 1),
                ZIndex = 2,
                Parent = Track,
            }, { corner(UDim.new(1, 0)), stroke(Theme.Accent, 2) })

            local function setFromAlpha(alpha, fire)
                alpha = math.clamp(alpha, 0, 1)
                local raw = min + (max - min) * alpha
                if decimals == 0 then
                    raw = math.floor(raw + 0.5)
                else
                    raw = round(raw, decimals)
                end
                value = raw
                local visualAlpha = (value - min) / (max - min)
                Fill.Size = UDim2.fromScale(visualAlpha, 1)
                Thumb.Position = UDim2.new(visualAlpha, 0, 0.5, 0)
                ValueLabel.Text = tostring(value) .. suffix
                if fire and opts.Callback then opts.Callback(value) end
            end
            setFromAlpha((value - min) / (max - min), false)

            local dragging = false
            local function updateFromInput(input)
                local relX = (input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X
                setFromAlpha(relX, true)
            end

            Track.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    updateFromInput(input)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    updateFromInput(input)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)

            local sliderObj = {}
            function sliderObj:Set(v)
                setFromAlpha((v - min) / (max - min), true)
            end
            function sliderObj:Get()
                return value
            end
            return sliderObj
        end

        return factory
    end

    -- attach element creators to TabMethods (direct page) and SubTabMethods (subtab page)
    function TabMethods:CreateToggle(opts)
        local f = buildElementFactory(function() return self._directPage end)
        return f.CreateToggle(f, opts)
    end
    function TabMethods:CreateSlider(opts)
        local f = buildElementFactory(function() return self._directPage end)
        return f.CreateSlider(f, opts)
    end
    function TabMethods:CreateLabel(text)
        local f = buildElementFactory(function() return self._directPage end)
        return f.CreateLabel(f, text)
    end
    function TabMethods:CreateSection(text)
        local f = buildElementFactory(function() return self._directPage end)
        return f.CreateSection(f, text)
    end

    function SubTabMethods:CreateToggle(opts)
        local f = buildElementFactory(function() return self._page end)
        return f.CreateToggle(f, opts)
    end
    function SubTabMethods:CreateSlider(opts)
        local f = buildElementFactory(function() return self._page end)
        return f.CreateSlider(f, opts)
    end
    function SubTabMethods:CreateLabel(text)
        local f = buildElementFactory(function() return self._page end)
        return f.CreateLabel(f, text)
    end
    function SubTabMethods:CreateSection(text)
        local f = buildElementFactory(function() return self._page end)
        return f.CreateSection(f, text)
    end

    return Window
end

return Library
