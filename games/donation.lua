--!nonstrict

--[[
    Ouroboros — donation popup.

    Shown once per game (the cache below decides), then this window: a squared
    Hello Kitty panel with donation tiers on the left and every payment address
    on the right, each row copying on click with a rainbow outline on hover.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local CACHE_DIR = "Ouroboros"
local CACHE_FILE = CACHE_DIR .. "/donation_shown.json"
local GAME_KEY = tostring(game.GameId)

local hasFileApi = (typeof(writefile) == "function")
    and (typeof(readfile) == "function")
    and (typeof(isfile) == "function")

local function readShown(): { [string]: boolean }
    if hasFileApi then
        local ok, contents = pcall(function()
            if isfile(CACHE_FILE) then
                return readfile(CACHE_FILE)
            end
            return nil
        end)
        if ok and contents then
            local okDecode, data = pcall(HttpService.JSONDecode, HttpService, contents)
            if okDecode and typeof(data) == "table" then
                return data
            end
        end
        return {}
    end
    local env = getgenv()
    env.__OuroborosDonationShown = env.__OuroborosDonationShown or {}
    return env.__OuroborosDonationShown
end

local function markShown()
    local shown = readShown()
    shown[GAME_KEY] = true
    if hasFileApi then
        pcall(function()
            if typeof(makefolder) == "function" and typeof(isfolder) == "function" then
                if not isfolder(CACHE_DIR) then
                    makefolder(CACHE_DIR)
                end
            end
            writefile(CACHE_FILE, HttpService:JSONEncode(shown))
        end)
    else
        getgenv().__OuroborosDonationShown = shown
    end
end

if readShown()[GAME_KEY] then
    return
end
local function copyToClipboard(text: string)
    local setcb = (getfenv()["setclipboard"] or getfenv()["toclipboard"] or (getfenv()["syn"] and getfenv()["syn"].write_clipboard))
    if setcb then
        setcb(text)
    end
end

if PlayerGui:FindFirstChild("DonationGui") then
    PlayerGui.DonationGui:Destroy()
end

markShown()

--// Content \\--

local Project = "Ouroboros Hub"

local Tiers = {
    { Name = "Donator", Price = "$5" },
    { Name = "Ultra Donator", Price = "$15" },
    { Name = "The True Ouro", Price = "$50" },
}

local Methods = {
    { Name = "Litecoin", Address = "LSZPqKSsD1x6QXea2H8JS17nXMLnmtew3w", Color = Color3.fromRGB(160, 166, 178) },
    { Name = "Bitcoin", Address = "bc1qwc9exvcn3ykjqnsa0t9gakuccr494ljjuuqj99", Color = Color3.fromRGB(247, 147, 26) },
    { Name = "Ethereum", Address = "0xaE95A405D007a6F858E5d35714111B075fEFb40a", Color = Color3.fromRGB(120, 130, 220) },
    { Name = "USDT · ETH", Address = "0xaE95A405D007a6F858E5d35714111B075fEFb40a", Color = Color3.fromRGB(38, 161, 123) },
    { Name = "USDT · SOL", Address = "Hq5jPHKDKjyHhccc6UULcbYTK6aKBBbTDmHNRXGKBKGp", Color = Color3.fromRGB(38, 161, 123) },
    { Name = "Solana", Address = "Hq5jPHKDKjyHhccc6UULcbYTK6aKBBbTDmHNRXGKBKGp", Color = Color3.fromRGB(153, 69, 255) },
    { Name = "PayPal", Address = "https://paypal.me/TheTruckerGOD", Color = Color3.fromRGB(0, 112, 186) },
    { Name = "Venmo", Address = "https://venmo.com/u/miserablemusic", Color = Color3.fromRGB(0, 143, 214) },
}


-- Addresses are long and the row is one line, so show a middle-elided form.
-- The click always copies the full string.
local function Short(Address: string): string
    local Display = (Address:gsub("^https://", ""))
    if #Display <= 30 then
        return Display
    end
    return Display:sub(1, 12) .. "…" .. Display:sub(-6)
end


--// Palette \\--

local Scheme = {
    Ground = Color3.fromRGB(255, 241, 247), -- window background, warm white
    Card = Color3.fromRGB(255, 255, 255),
    Sunk = Color3.fromRGB(255, 230, 241),
    Pink = Color3.fromRGB(232, 64, 127), -- primary accent, 4.3:1 under white text
    Deep = Color3.fromRGB(168, 20, 76), -- pressed / emphasis, 7:1 on white
    Bow = Color3.fromRGB(232, 56, 79), -- the red bow
    Gold = Color3.fromRGB(255, 197, 61), -- her nose
    Ink = Color3.fromRGB(35, 22, 30), -- body text, 14:1 on white
    Muted = Color3.fromRGB(106, 78, 94), -- 6:1 on white
    Line = Color3.fromRGB(240, 178, 206),
}

local HEAD = Enum.Font.FredokaOne
local BODY = Enum.Font.Gotham
local BOLD = Enum.Font.GothamBold

--// Tiny builders \\--

local function New(Class: string, Props: { [string]: any }, Children: { Instance }?): Instance
    local Object = Instance.new(Class)
    for Key, Value in pairs(Props) do
        if Key ~= "Parent" then
            (Object :: any)[Key] = Value
        end
    end
    for _, Child in ipairs(Children or {}) do
        Child.Parent = Object
    end
    if Props.Parent then
        Object.Parent = Props.Parent
    end
    return Object
end

-- The window is squared off. The helper keeps its argument so the radius
-- sites stay in the code if the look is ever softened again.
local function Corner(_Radius: number): Instance
    return New("UICorner", { CornerRadius = UDim.new(0, 0) })
end

local function Stroke(Color: Color3?, Thickness: number?): Instance
    return New("UIStroke", {
        Color = Color or Scheme.Line,
        Thickness = Thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function Pad(All: number, Extra: { [string]: number }?): Instance
    local P = New("UIPadding", {
        PaddingTop = UDim.new(0, All),
        PaddingBottom = UDim.new(0, All),
        PaddingLeft = UDim.new(0, All),
        PaddingRight = UDim.new(0, All),
    })
    for Key, Value in pairs(Extra or {}) do
        (P :: any)[Key] = UDim.new(0, Value)
    end
    return P
end

local function List(Padding: number, Horizontal: boolean?): Instance
    return New("UIListLayout", {
        Padding = UDim.new(0, Padding),
        FillDirection = Horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
end

local function Text(Props: { [string]: any }): Instance
    local Defaults = {
        BackgroundTransparency = 1,
        Font = BODY,
        TextColor3 = Scheme.Ink,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        RichText = true,
    }
    for Key, Value in pairs(Props) do
        Defaults[Key] = Value
    end
    return New("TextLabel", Defaults)
end

--// Screen \--

local Gui = New("ScreenGui", {
    Parent = PlayerGui,
    Name = "DonationGui",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    DisplayOrder = 100,
})

-- Tapping outside the window closes it. On a phone this is the escape hatch:
-- even if a viewport is so small the panel fills it, the backdrop is reachable.
local Backdrop = New("TextButton", {
    Parent = Gui,
    Name = "Backdrop",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(24, 8, 16),
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "",
    ZIndex = 0,
})

Backdrop.MouseButton1Click:Connect(function()
    Gui:Destroy()
end)

--// Window \\--

local WIDTH, HEIGHT, BAR = 760, 430, 46

local Window = New("Frame", {
    Parent = Gui,
    Name = "Window",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Size = UDim2.fromOffset(WIDTH, HEIGHT),
    ZIndex = 1,
    BackgroundColor3 = Scheme.Ground,
    BorderSizePixel = 0,
}, {
    Corner(16),
    Stroke(Scheme.Pink, 2),
})

--// Fit to the screen \--
-- The panel is authored at 760x430. Phones are smaller than that, so it is
-- scaled down to whatever the viewport can hold and kept fully on screen —
-- otherwise the window overflows and the close button sits off the edge.

local Touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local Scale = New("UIScale", { Parent = Window, Scale = 1 })

local Centre = Vector2.new()
local Entered = false

local function FitScale(): number
    local Viewport = Gui.AbsoluteSize
    if Viewport.X <= 0 or Viewport.Y <= 0 then
        return 1
    end
    local Margin = Touch and 16 or 32
    return math.min(1, (Viewport.X - Margin) / WIDTH, (Viewport.Y - Margin) / HEIGHT)
end

local function Place(Wanted: Vector2)
    local Viewport = Gui.AbsoluteSize
    local Half = Vector2.new(WIDTH, HEIGHT) * (Scale.Scale / 2)

    local X = Viewport.X > Half.X * 2 and math.clamp(Wanted.X, Half.X, Viewport.X - Half.X) or Viewport.X / 2
    local Y = Viewport.Y > Half.Y * 2 and math.clamp(Wanted.Y, Half.Y, Viewport.Y - Half.Y) or Viewport.Y / 2

    Centre = Vector2.new(X, Y)
    Window.Position = UDim2.fromOffset(X, Y)
end

local function Fit()
    local Target = FitScale()
    Scale.Scale = Entered and Target or Target * 0.94
    Place(Centre.Magnitude > 0 and Centre or Gui.AbsoluteSize / 2)
    return Target
end

Fit()
Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(Fit)

--// Title bar \\--

local TitleBar = New("Frame", {
    Parent = Window,
    Name = "TitleBar",
    Size = UDim2.new(1, 0, 0, BAR),
    BackgroundColor3 = Scheme.Deep,
    BorderSizePixel = 0,
}, {
    Corner(16),
    New("Frame", { -- square the bottom corners so the bar meets the body flat
        Size = UDim2.new(1, 0, 0, 16),
        Position = UDim2.new(0, 0, 1, -16),
        BackgroundColor3 = Scheme.Deep,
        BorderSizePixel = 0,
    }),
})

-- A bow, drawn: two tilted rounded petals with a knot over the seam.
local Bow = New("Frame", {
    Parent = TitleBar,
    Name = "Bow",
    Position = UDim2.new(0, 16, 0.5, -11),
    Size = UDim2.fromOffset(34, 22),
    BackgroundTransparency = 1,
    ZIndex = 2,
})

for Index, Rotation in ipairs({ -18, 18 }) do
    New("Frame", {
        Parent = Bow,
        Name = "Petal" .. Index,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(Index == 1 and 0.28 or 0.72, 0, 0.5, 0),
        Size = UDim2.fromOffset(17, 18),
        Rotation = Rotation,
        BackgroundColor3 = Scheme.Bow,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, { Corner(7), Stroke(Color3.fromRGB(255, 255, 255), 1) })
end

New("Frame", {
    Parent = Bow,
    Name = "Knot",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(9, 9),
    BackgroundColor3 = Scheme.Gold,
    BorderSizePixel = 0,
    ZIndex = 3,
}, { Corner(5) })

New("TextLabel", {
    Parent = TitleBar,
    Name = "Title",
    Position = UDim2.new(0, 60, 0, 0),
    Size = UDim2.new(1, -140, 1, 0),
    BackgroundTransparency = 1,
    Font = HEAD,
    Text = Project .. "  ·  Donate",
    TextSize = 19,
    TextColor3 = Color3.new(1, 1, 1),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2,
})

New("TextLabel", {
    Parent = TitleBar,
    Name = "Tagline",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -56, 0.5, 0),
    Size = UDim2.fromOffset(220, 20),
    BackgroundTransparency = 1,
    Font = BODY,
    Text = "consider supporting ouroboros",
    TextSize = 13,
    TextColor3 = Color3.fromRGB(255, 214, 232),
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 2,
})

local Close = New("TextButton", {
    Parent = TitleBar,
    Name = "Close",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0),
    -- Bigger on touch: the panel is scaled down on a phone, so the button has
    -- to start large enough to still be a thumb target afterwards.
    Size = UDim2.fromOffset(Touch and 42 or 34, Touch and 42 or 34),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 0.75,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = BOLD,
    Text = "×",
    TextSize = Touch and 26 or 22,
    TextColor3 = Color3.new(1, 1, 1),
    ZIndex = 2,
}, { Corner(12) })

Close.MouseEnter:Connect(function()
    TweenService:Create(Close, TweenInfo.new(0.12), { BackgroundTransparency = 0.35 }):Play()
end)
Close.MouseLeave:Connect(function()
    TweenService:Create(Close, TweenInfo.new(0.12), { BackgroundTransparency = 0.75 }):Play()
end)
Close.MouseButton1Click:Connect(function()
    Gui:Destroy()
end)

--// Dragging \--

do
    local Dragging, Start, Origin = false, nil, nil

    TitleBar.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            Dragging, Start, Origin = true, Input.Position, Centre
        end
    end)

    TitleBar.InputEnded:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            Dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(Input)
        if not Dragging then
            return
        end
        if Input.UserInputType ~= Enum.UserInputType.MouseMovement and Input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local Delta = Input.Position - Start
        -- Place() clamps, so a drag can never carry the window off screen.
        Place(Origin + Vector2.new(Delta.X, Delta.Y))
    end)
end

--// Columns (fixed sizes — nothing scrolls) \\--

local PADDING, GAP = 16, 12
local COLUMN = (WIDTH - PADDING * 2 - GAP) / 2

local Body = New("Frame", {
    Parent = Window,
    Name = "Body",
    Position = UDim2.new(0, 0, 0, BAR),
    Size = UDim2.new(1, 0, 1, -BAR),
    BackgroundTransparency = 1,
}, {
    Pad(PADDING),
    List(GAP, true),
})

local function Column(Order: number): Instance
    return New("Frame", {
        Parent = Body,
        Name = "Column" .. Order,
        LayoutOrder = Order,
        Size = UDim2.new(0, COLUMN, 1, 0),
        BackgroundTransparency = 1,
    }, { List(GAP) })
end

local Left, Right = Column(1), Column(2)

local function Card(Parent: Instance, TitleText: string, Height: number, Order: number): Instance
    local Box = New("Frame", {
        Parent = Parent,
        Name = TitleText,
        LayoutOrder = Order,
        Size = UDim2.new(1, 0, 0, Height),
        BackgroundColor3 = Scheme.Card,
        BorderSizePixel = 0,
    }, {
        Corner(12),
        Stroke(),
        Pad(12),
        List(8),
    })

    New("TextLabel", {
        Parent = Box,
        Name = "Header",
        LayoutOrder = -1,
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Font = HEAD,
        Text = TitleText,
        TextSize = 15,
        TextColor3 = Scheme.Deep,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    return Box
end

--// Left column: tiers \\--

local Selected = Tiers[1]
local TierButtons = {}

local function PaintTiers()
    for _, Entry in ipairs(TierButtons) do
        local Active = Entry.Tier == Selected
        Entry.Button.BackgroundColor3 = Active and Scheme.Sunk or Scheme.Card
        Entry.Heart.TextTransparency = Active and 0 or 1
        Entry.Price.TextColor3 = Active and Scheme.Deep or Scheme.Ink
        local Line = Entry.Button:FindFirstChildOfClass("UIStroke")
        if Line then
            Line.Color = Active and Scheme.Pink or Scheme.Line
            Line.Thickness = Active and 2 or 1
        end
    end
end

do
    local Box = Card(Left, "Pick a tier", 224, 1)
    Box:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 9)

    for Index, Tier in ipairs(Tiers) do
        local Button = New("TextButton", {
            Parent = Box,
            Name = Tier.Name,
            LayoutOrder = Index,
            Size = UDim2.new(1, 0, 0, 52),
            BackgroundColor3 = Scheme.Card,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
        }, { Corner(10), Stroke() })

        local Heart = Text({
            Parent = Button,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 14, 0.5, 0),
            Size = UDim2.fromOffset(18, 18),
            Font = BOLD,
            Text = "♥",
            TextSize = 16,
            TextColor3 = Scheme.Pink,
            TextTransparency = 1,
        })

        Text({
            Parent = Button,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 36, 0.5, 0),
            Size = UDim2.new(1, -120, 0, 20),
            Font = BOLD,
            Text = Tier.Name,
            TextSize = 16,
        })

        local Price = New("TextLabel", {
            Parent = Button,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(72, 28),
            BackgroundTransparency = 1,
            Font = HEAD,
            Text = Tier.Price,
            TextSize = 22,
            TextColor3 = Scheme.Ink,
            TextXAlignment = Enum.TextXAlignment.Right,
        })

        table.insert(TierButtons, { Tier = Tier, Button = Button, Heart = Heart, Price = Price })

        Button.MouseButton1Click:Connect(function()
            Selected = Tier
            PaintTiers()
        end)
    end

    PaintTiers()
end

--// Left column: side note \--

do
    local Box = Card(Left, "Another way to pay?", 96, 2)

    Text({
        Parent = Box,
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 46),
        Text = "If you'd like to support Ouroboros through another payment option, join the Discord and DM the owner.",
        TextSize = 12,
        TextColor3 = Scheme.Muted,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
    })
end

--// Rainbow driver \--
-- One RenderStepped loop scrolls every hovered row's gradient, so hovering
-- ten rows costs the same as hovering one.

local Rainbow = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 64, 96)),
    ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 156, 46)),
    ColorSequenceKeypoint.new(0.34, Color3.fromRGB(240, 214, 40)),
    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(74, 208, 116)),
    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(64, 168, 255)),
    ColorSequenceKeypoint.new(0.84, Color3.fromRGB(150, 96, 255)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 64, 96)),
})

local Glowing: { [UIGradient]: true } = {}

RunService.RenderStepped:Connect(function()
    if not next(Glowing) then
        return
    end
    local Offset = Vector2.new((tick() * 0.45) % 2 - 1, 0)
    for Gradient in pairs(Glowing) do
        Gradient.Offset = Offset
    end
end)

--// Right column: click to copy \--

do
    local Box = Card(Right, "Click to copy", 332, 1)
    Box:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 6)

    for Index, Method in ipairs(Methods) do
        local Row = New("Frame", {
            Parent = Box,
            Name = Method.Name,
            LayoutOrder = Index,
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
        })

        local Scale = New("UIScale", { Parent = Row, Scale = 1 })

        local Button = New("TextButton", {
            Parent = Row,
            Name = "Hit",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Scheme.Sunk,
            BackgroundTransparency = 0.35,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
        }, { Corner(9), Stroke(Scheme.Line, 1), Pad(0, { PaddingLeft = 10, PaddingRight = 10 }) })

        local Line = Button:FindFirstChildOfClass("UIStroke")

        -- The rainbow rides the outline, not the fill: the address stays
        -- readable on white while the row still lights up.
        local Glow = New("UIGradient", {
            Parent = Line,
            Color = Rainbow,
            Enabled = false,
        }) :: UIGradient

        -- Coin dot: a tiny colour-coded marker so the list scans by chain.
        New("Frame", {
            Parent = Button,
            Name = "Dot",
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = Method.Color,
            BorderSizePixel = 0,
        }, { Corner(4) })

        local Name = Text({
            Parent = Button,
            Position = UDim2.new(0, 16, 0, 0),
            Size = UDim2.new(0, 96, 1, 0),
            Font = BOLD,
            Text = Method.Name,
            TextSize = 12,
            TextColor3 = Scheme.Ink,
        })

        local Value = Text({
            Parent = Button,
            Position = UDim2.new(0, 116, 0, 0),
            Size = UDim2.new(1, -116, 1, 0),
            Font = Enum.Font.Code,
            Text = Short(Method.Address),
            TextSize = 12,
            TextColor3 = Scheme.Muted,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })

        local Quick = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local Bounce = TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        local Hovered, Copied = false, false

        local function Rest()
            if Copied then
                return
            end
            TweenService:Create(Button, Quick, {
                BackgroundTransparency = Hovered and 0 or 0.35,
            }):Play()
            if Hovered then
                Line.Color = Color3.new(1, 1, 1)
            else
                TweenService:Create(Line, Quick, { Color = Scheme.Line }):Play()
            end
            TweenService:Create(Line, Quick, { Thickness = Hovered and 2 or 1 }):Play()
            TweenService:Create(Name, Quick, {
                TextColor3 = Hovered and Scheme.Deep or Scheme.Ink,
            }):Play()
            TweenService:Create(Scale, Quick, { Scale = Hovered and 1.012 or 1 }):Play()
        end

        Button.MouseEnter:Connect(function()
            Hovered = true
            if not Copied then
                Line.Color = Color3.new(1, 1, 1) -- let the gradient show pure
                Glow.Enabled = true
                Glowing[Glow] = true
            end
            Rest()
        end)

        Button.MouseLeave:Connect(function()
            Hovered = false
            Glowing[Glow] = nil
            Glow.Enabled = false
            Rest()
        end)

        Button.MouseButton1Down:Connect(function()
            TweenService:Create(Scale, Quick, { Scale = 0.975 }):Play()
        end)

        Button.MouseButton1Click:Connect(function()
            Copied = true

            -- Squash, then spring back: the whole feedback is one gesture.
            TweenService:Create(Scale, Bounce, { Scale = 1 }):Play()
            TweenService:Create(Button, Quick, { BackgroundColor3 = Scheme.Pink, BackgroundTransparency = 0 }):Play()
            Glowing[Glow] = nil
            Glow.Enabled = false
            Line.Color = Scheme.Deep
            TweenService:Create(Line, Quick, { Thickness = 2 }):Play()
            TweenService:Create(Name, Quick, { TextColor3 = Color3.new(1, 1, 1) }):Play()

            copyToClipboard(Method.Address)
            Value.Text = "copied ♥"

            Value.Font = BOLD
            Value.TextColor3 = Color3.new(1, 1, 1)
            Value.TextTransparency = 1
            TweenService:Create(Value, TweenInfo.new(0.18), { TextTransparency = 0 }):Play()

            task.delay(1.4, function()
                if not Button.Parent then
                    return
                end
                Copied = false
                if Hovered then
                    Glow.Enabled = true
                    Glowing[Glow] = true
                end
                Value.Text = Short(Method.Address)
                Value.Font = Enum.Font.Code
                Value.TextColor3 = Scheme.Muted
                TweenService:Create(Button, Quick, { BackgroundColor3 = Scheme.Sunk }):Play()
                Rest()
            end)
        end)
    end
end

--// Entrance \--

Window.BackgroundTransparency = 1
Entered = true

TweenService:Create(Window, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
    BackgroundTransparency = 0,
}):Play()
TweenService:Create(Scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Scale = FitScale(),
}):Play()
