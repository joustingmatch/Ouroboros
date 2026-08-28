--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
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

local CONFIG = {
    GameName = "Ouroboros",
    Tagline = "Wanna help support %s? Start by donating.",
    BgColor = Color3.fromRGB(11, 12, 16),
    CardBg = Color3.fromRGB(15, 17, 23),
    CardHoverBg = Color3.fromRGB(21, 24, 33),
    BorderColor = Color3.fromRGB(28, 32, 42),
    BorderHoverColor = Color3.fromRGB(56, 64, 84),
    BorderActiveColor = Color3.fromRGB(255, 255, 255),
    TextColor = Color3.fromRGB(255, 255, 255),
    TextMuted = Color3.fromRGB(130, 138, 156),

    Methods = {
        {
            Tag = "LTC",
            Name = "Litecoin",
            Value = "LSZPqKSsD1x6QXea2H8JS17nXMLnmtew3w",
            Display = "LSZPqKSs...mtew3w",
            TagColor = Color3.fromRGB(52, 211, 153),
        },
        {
            Tag = "BTC",
            Name = "Bitcoin",
            Value = "bc1qwc9exvcn3ykjqnsa0t9gakuccr494ljjuuqj99",
            Display = "bc1qwc9e...uqj99",
            TagColor = Color3.fromRGB(251, 191, 36),
        },
        {
            Tag = "ETH",
            Name = "ERC-20",
            Value = "0xaE95A405D007a6F858E5d35714111B075fEFb40a",
            Display = "0xaE95A4...Fb40a",
            TagColor = Color3.fromRGB(129, 140, 248),
        },
        {
            Tag = "SOL",
            Name = "Solana",
            Value = "Hq5jPHKDKjyHhccc6UULcbYTK6aKBBbTDmHNRXGKBKGp",
            Display = "Hq5jPHKD...BKGp",
            TagColor = Color3.fromRGB(192, 132, 252),
        },
        {
            Tag = "USDT",
            Name = "ETH",
            Value = "0xaE95A405D007a6F858E5d35714111B075fEFb40a",
            Display = "0xaE95A4...Fb40a",
            TagColor = Color3.fromRGB(45, 212, 191),
        },
        {
            Tag = "USDT",
            Name = "SOLANA",
            Value = "Hq5jPHKDKjyHhccc6UULcbYTK6aKBBbTDmHNRXGKBKGp",
            Display = "Hq5jPHKD...BKGp",
            TagColor = Color3.fromRGB(45, 212, 191),
        },
        {
            Tag = "PAYPAL",
            Name = "LINK",
            Value = "https://paypal.me/TheTruckerGOD",
            Display = "paypal.me/...",
            TagColor = Color3.fromRGB(56, 189, 248),
        },
        {
            Tag = "VENMO",
            Name = "LINK",
            Value = "https://venmo.com/u/miserablemusic",
            Display = "venmo.com/...",
            TagColor = Color3.fromRGB(96, 165, 250),
        },
    }
}

local function createStroke(parent: Instance, color: Color3, thickness: number?): UIStroke
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = color
    stroke.Thickness = thickness or 1
    stroke.Parent = parent
    return stroke
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

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DonationGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 580, 0, 330)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = CONFIG.BgColor
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
createStroke(MainFrame, CONFIG.BorderColor, 1)

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.new(0, 26, 0, 26)
CloseButton.Position = UDim2.new(1, -44, 0, 20)
CloseButton.BackgroundColor3 = Color3.fromRGB(17, 19, 26)
CloseButton.BorderSizePixel = 0
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Text = "X"
CloseButton.TextColor3 = CONFIG.TextMuted
CloseButton.TextSize = 12
CloseButton.AutoButtonColor = false
CloseButton.Parent = MainFrame
local closeStroke = createStroke(CloseButton, CONFIG.BorderColor, 1)

CloseButton.MouseEnter:Connect(function()
    TweenService:Create(CloseButton, TweenInfo.new(0.12), {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        TextColor3 = Color3.fromRGB(0, 0, 0)
    }):Play()
    TweenService:Create(closeStroke, TweenInfo.new(0.12), { Color = Color3.fromRGB(255, 255, 255) }):Play()
end)

CloseButton.MouseLeave:Connect(function()
    TweenService:Create(CloseButton, TweenInfo.new(0.12), {
        BackgroundColor3 = Color3.fromRGB(17, 19, 26),
        TextColor3 = CONFIG.TextMuted
    }):Play()
    TweenService:Create(closeStroke, TweenInfo.new(0.12), { Color = CONFIG.BorderColor }):Play()
end)

CloseButton.MouseButton1Click:Connect(function()
    local tween = TweenService:Create(MainFrame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 540, 0, 300),
        BackgroundTransparency = 1
    })
    tween:Play()
    tween.Completed:Connect(function()
        ScreenGui:Destroy()
    end)
end)

local TopSection = Instance.new("Frame")
TopSection.Name = "TopSection"
TopSection.Size = UDim2.new(1, -50, 0, 52)
TopSection.Position = UDim2.new(0, 25, 0, 20)
TopSection.BackgroundTransparency = 1
TopSection.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -35, 0, 26)
TitleLabel.Position = UDim2.new(0, 0, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "Support " .. CONFIG.GameName
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 22
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopSection

local TaglineLabel = Instance.new("TextLabel")
TaglineLabel.Size = UDim2.new(1, -35, 0, 18)
TaglineLabel.Position = UDim2.new(0, 0, 0, 28)
TaglineLabel.BackgroundTransparency = 1
TaglineLabel.Font = Enum.Font.GothamMedium
TaglineLabel.Text = string.format(CONFIG.Tagline, CONFIG.GameName)
TaglineLabel.TextColor3 = CONFIG.TextMuted
TaglineLabel.TextSize = 12
TaglineLabel.TextXAlignment = Enum.TextXAlignment.Left
TaglineLabel.Parent = TopSection

local Grid = Instance.new("Frame")
Grid.Name = "Grid"
Grid.Size = UDim2.new(1, -50, 0, 218)
Grid.Position = UDim2.new(0, 25, 0, 84)
Grid.BackgroundTransparency = 1
Grid.Parent = MainFrame

local UIGridLayout = Instance.new("UIGridLayout")
UIGridLayout.CellSize = UDim2.new(0.234, 0, 0.46, 0)
UIGridLayout.CellPadding = UDim2.new(0.021, 0, 0.08, 0)
UIGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIGridLayout.Parent = Grid

local Toast = Instance.new("Frame")
Toast.Name = "Toast"
Toast.Size = UDim2.new(0, 260, 0, 36)
Toast.Position = UDim2.new(0.5, 0, 1, -25)
Toast.AnchorPoint = Vector2.new(0.5, 1)
Toast.BackgroundColor3 = Color3.fromRGB(17, 20, 27)
Toast.BorderSizePixel = 0
Toast.Visible = false
Toast.Parent = ScreenGui
createStroke(Toast, Color3.fromRGB(60, 68, 88), 1)

local ToastText = Instance.new("TextLabel")
ToastText.Size = UDim2.new(1, -20, 1, 0)
ToastText.Position = UDim2.new(0, 10, 0, 0)
ToastText.BackgroundTransparency = 1
ToastText.Font = Enum.Font.GothamBold
ToastText.Text = "COPIED TO CLIPBOARD"
ToastText.TextColor3 = Color3.fromRGB(255, 255, 255)
ToastText.TextSize = 11
ToastText.Parent = Toast

local toastDebounce = 0
local function showToast(methodName: string)
    ToastText.Text = "COPIED " .. string.upper(methodName) .. " TO CLIPBOARD"
    Toast.Visible = true
    Toast.Position = UDim2.new(0.5, 0, 1, -15)
    Toast.BackgroundTransparency = 0.5

    local anim = TweenService:Create(Toast, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 1, -30),
        BackgroundTransparency = 0
    })
    anim:Play()

    local currentDebounce = tick()
    toastDebounce = currentDebounce
    task.delay(1.8, function()
        if toastDebounce == currentDebounce then
            local hideAnim = TweenService:Create(Toast, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 1, -15),
                BackgroundTransparency = 1
            })
            hideAnim:Play()
            hideAnim.Completed:Connect(function()
                if toastDebounce == currentDebounce then
                    Toast.Visible = false
                end
            end)
        end
    end)
end

for i, method in ipairs(CONFIG.Methods) do
    local Card = Instance.new("TextButton")
    Card.Name = "Card_" .. method.Tag .. "_" .. i
    Card.BackgroundColor3 = CONFIG.CardBg
    Card.BorderSizePixel = 0
    Card.AutoButtonColor = false
    Card.Text = ""
    Card.LayoutOrder = i
    Card.Parent = Grid

    local stroke = createStroke(Card, CONFIG.BorderColor, 1)

    local TagLabel = Instance.new("TextLabel")
    TagLabel.Size = UDim2.new(0.5, 0, 0, 18)
    TagLabel.Position = UDim2.new(0, 10, 0, 10)
    TagLabel.BackgroundTransparency = 1
    TagLabel.Font = Enum.Font.GothamBold
    TagLabel.Text = method.Tag
    TagLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TagLabel.TextSize = 13
    TagLabel.TextXAlignment = Enum.TextXAlignment.Left
    TagLabel.Parent = Card

    local SubLabel = Instance.new("TextLabel")
    SubLabel.Size = UDim2.new(0.5, -10, 0, 18)
    SubLabel.Position = UDim2.new(0.5, 0, 0, 10)
    SubLabel.BackgroundTransparency = 1
    SubLabel.Font = Enum.Font.GothamMedium
    SubLabel.Text = string.upper(method.Name)
    SubLabel.TextColor3 = Color3.fromRGB(95, 103, 122)
    SubLabel.TextSize = 9
    SubLabel.TextXAlignment = Enum.TextXAlignment.Right
    SubLabel.Parent = Card

    local AddressLabel = Instance.new("TextLabel")
    AddressLabel.Size = UDim2.new(1, -20, 0, 16)
    AddressLabel.Position = UDim2.new(0, 10, 0, 36)
    AddressLabel.BackgroundTransparency = 1
    AddressLabel.Font = Enum.Font.GothamMedium
    AddressLabel.Text = method.Display
    AddressLabel.TextColor3 = Color3.fromRGB(80, 87, 105)
    AddressLabel.TextSize = 10
    AddressLabel.TextTruncate = Enum.TextTruncate.AtEnd
    AddressLabel.TextXAlignment = Enum.TextXAlignment.Left
    AddressLabel.Parent = Card

    local ActionLabel = Instance.new("TextLabel")
    ActionLabel.Size = UDim2.new(1, -20, 0, 16)
    ActionLabel.Position = UDim2.new(0, 10, 1, -24)
    ActionLabel.BackgroundTransparency = 1
    ActionLabel.Font = Enum.Font.GothamBold
    ActionLabel.Text = "COPY →"
    ActionLabel.TextColor3 = Color3.fromRGB(122, 131, 152)
    ActionLabel.TextSize = 10
    ActionLabel.TextXAlignment = Enum.TextXAlignment.Left
    ActionLabel.Parent = Card

    Card.MouseEnter:Connect(function()
        TweenService:Create(Card, TweenInfo.new(0.12), { BackgroundColor3 = CONFIG.CardHoverBg }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.12), { Color = CONFIG.BorderHoverColor }):Play()
        TweenService:Create(TagLabel, TweenInfo.new(0.12), { TextColor3 = method.TagColor }):Play()
        TweenService:Create(ActionLabel, TweenInfo.new(0.12), { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
    end)

    Card.MouseLeave:Connect(function()
        TweenService:Create(Card, TweenInfo.new(0.12), { BackgroundColor3 = CONFIG.CardBg }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.12), { Color = CONFIG.BorderColor }):Play()
        TweenService:Create(TagLabel, TweenInfo.new(0.12), { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
        TweenService:Create(ActionLabel, TweenInfo.new(0.12), { TextColor3 = Color3.fromRGB(122, 131, 152) }):Play()
    end)

    Card.MouseButton1Click:Connect(function()
        copyToClipboard(method.Value)
        showToast(method.Tag)

        ActionLabel.Text = "COPIED ✓"
        ActionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TweenService:Create(Card, TweenInfo.new(0.08), { BackgroundColor3 = Color3.fromRGB(26, 30, 42) }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.08), { Color = CONFIG.BorderActiveColor }):Play()

        task.delay(1.1, function()
            ActionLabel.Text = "COPY →"
            TweenService:Create(Card, TweenInfo.new(0.12), { BackgroundColor3 = CONFIG.CardBg }):Play()
            TweenService:Create(stroke, TweenInfo.new(0.12), { Color = CONFIG.BorderColor }):Play()
            TweenService:Create(ActionLabel, TweenInfo.new(0.12), { TextColor3 = Color3.fromRGB(122, 131, 152) }):Play()
        end)
    end)
end

MainFrame.Size = UDim2.new(0, 550, 0, 310)
MainFrame.BackgroundTransparency = 0.4
TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 580, 0, 330),
    BackgroundTransparency = 0
}):Play()
