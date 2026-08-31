local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local parentGui
pcall(function() parentGui = CoreGui end)
if not parentGui then
    parentGui = Players.LocalPlayer:WaitForChild("PlayerGui")
end

if parentGui:FindFirstChild("DQ_Notice") then
    parentGui.DQ_Notice:Destroy()
end
if Lighting:FindFirstChild("DQ_NoticeBlur") then
    Lighting.DQ_NoticeBlur:Destroy()
end

local THEME = {
    Background    = Color3.fromRGB(9, 9, 11),
    Surface       = Color3.fromRGB(18, 18, 22),
    SurfaceHover  = Color3.fromRGB(27, 27, 33),
    Border        = Color3.fromRGB(39, 39, 42),
    BorderHover   = Color3.fromRGB(34, 197, 94),
    Green         = Color3.fromRGB(34, 197, 94),
    TextPrimary   = Color3.fromRGB(244, 244, 245),
    TextBody      = Color3.fromRGB(212, 212, 216),
    TextMuted     = Color3.fromRGB(140, 140, 148),
}

local Translations = {
    ["en"] = {
        name = "English",
        flag = "🇺🇸",
        title = "Script is currently down",
        body = "Dungeon Quest updated their anticheat, so the script is temporarily unusable. We're actively working on a bypass—if it's not possible, we'll post an announcement.",
        button = "Close"
    },
    ["ph"] = {
        name = "Filipino",
        flag = "🇵🇭",
        title = "Down ang script ngayon",
        body = "Nag-update ng anticheat ang Dungeon Quest kaya hindi gumagana ang script ngayon. Sinusubukan naming gawan ng bypass—kung hindi kaya, mag-aannounce kami.",
        button = "Isara"
    },
    ["vn"] = {
        name = "Tiếng Việt",
        flag = "🇻🇳",
        title = "Script đang bảo trì",
        body = "Dungeon Quest vừa cập nhật anticheat nên script tạm thời không dùng được. Tụi mình đang tìm cách bypass—nếu không được thì sẽ thông báo sau.",
        button = "Đóng"
    },
    ["id"] = {
        name = "Bahasa Indonesia",
        flag = "🇮🇩",
        title = "Skrip sedang bermasalah",
        body = "Dungeon Quest baru saja update anticheat, jadi skrip belum bisa dipakai. Kami sedang coba bypass—kalau tidak bisa, nanti akan diumumkan.",
        button = "Tutup"
    },
    ["ru"] = {
        name = "Русский",
        flag = "🇷🇺",
        title = "Скрипт временно недоступен",
        body = "В Dungeon Quest обновили античит, поэтому скрипт сейчас не работает. Мы пытаемся сделать обход—если не получится, сообщим в анонсах.",
        button = "Закрыть"
    },
    ["th"] = {
        name = "ไทย",
        flag = "🇹🇭",
        title = "สคริปต์ใช้งานไม่ได้ชั่วคราว",
        body = "Dungeon Quest อัปเดตระบบกันแบนใหม่ ทำให้สคริปต์ใช้งานไม่ได้ในตอนนี้ ทางเรากำลังพยายามแก้บายพาสอยู่ ถ้าทำไม่ได้จะประกาศให้ทราบ",
        button = "ปิด"
    },
    ["de"] = {
        name = "Deutsch",
        flag = "🇩🇪",
        title = "Skript momentan offline",
        body = "Dungeon Quest hat das Anticheat aktualisiert, weshalb das Skript momentan nicht funktioniert. Wir arbeiten an einem Bypass—falls es nicht klappt, geben wir Bescheid.",
        button = "Schließen"
    },
    ["br"] = {
        name = "Português",
        flag = "🇧🇷",
        title = "Script temporariamente desativado",
        body = "Dungeon Quest atualizou o anti-cheat, então o script está temporariamente inutilizável. Estamos tentando criar um bypass—se não for possível, postaremos um aviso.",
        button = "Fechar"
    }
}

local LanguageOrder = {"en", "ph", "vn", "id", "ru", "th", "de", "br"}

local Blur = Instance.new("BlurEffect")
Blur.Name = "DQ_NoticeBlur"
Blur.Size = 0
Blur.Parent = Lighting

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DQ_Notice"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parentGui

local Backdrop = Instance.new("Frame")
Backdrop.Size = UDim2.new(1, 0, 1, 0)
Backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Backdrop.BackgroundTransparency = 1
Backdrop.BorderSizePixel = 0
Backdrop.Parent = ScreenGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Size = UDim2.new(0, 460, 0, 275)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.BackgroundColor3 = THEME.Background
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = Backdrop

local MainBorder = Instance.new("UIStroke")
MainBorder.Color = THEME.Border
MainBorder.Thickness = 1
MainBorder.Parent = MainFrame

local ChooserFrame = Instance.new("CanvasGroup")
ChooserFrame.Name = "ChooserFrame"
ChooserFrame.Size = UDim2.new(1, 0, 1, 0)
ChooserFrame.BackgroundTransparency = 1
ChooserFrame.BorderSizePixel = 0
ChooserFrame.GroupTransparency = 0
ChooserFrame.Parent = MainFrame

local ChooserHeader = Instance.new("Frame")
ChooserHeader.Size = UDim2.new(1, 0, 0, 46)
ChooserHeader.BackgroundTransparency = 1
ChooserHeader.Parent = ChooserFrame

local ChooserTitle = Instance.new("TextLabel")
ChooserTitle.Size = UDim2.new(1, -36, 0, 20)
ChooserTitle.Position = UDim2.new(0, 18, 0, 14)
ChooserTitle.Font = Enum.Font.GothamBold
ChooserTitle.TextSize = 14
ChooserTitle.TextColor3 = THEME.TextPrimary
ChooserTitle.TextXAlignment = Enum.TextXAlignment.Left
ChooserTitle.BackgroundTransparency = 1
ChooserTitle.Text = "Select Language"
ChooserTitle.Parent = ChooserHeader

local ChooserSub = Instance.new("TextLabel")
ChooserSub.Size = UDim2.new(1, -36, 0, 14)
ChooserSub.Position = UDim2.new(0, 18, 0, 36)
ChooserSub.Font = Enum.Font.Gotham
ChooserSub.TextSize = 10
ChooserSub.TextColor3 = THEME.TextMuted
ChooserSub.TextXAlignment = Enum.TextXAlignment.Left
ChooserSub.BackgroundTransparency = 1
ChooserSub.Text = "Pumili ng wika • Chọn ngôn ngữ • Pilih bahasa • Escolha o idioma"
ChooserSub.Parent = ChooserHeader

local ChooserDivider = Instance.new("Frame")
ChooserDivider.Size = UDim2.new(1, 0, 0, 1)
ChooserDivider.Position = UDim2.new(0, 0, 0, 58)
ChooserDivider.BackgroundColor3 = THEME.Border
ChooserDivider.BorderSizePixel = 0
ChooserDivider.Parent = ChooserFrame

local Grid = Instance.new("Frame")
Grid.Size = UDim2.new(1, -36, 0, 195)
Grid.Position = UDim2.new(0, 18, 0, 70)
Grid.BackgroundTransparency = 1
Grid.Parent = ChooserFrame

local GridLayout = Instance.new("UIGridLayout")
GridLayout.CellSize = UDim2.new(0, 206, 0, 38)
GridLayout.CellPadding = UDim2.new(0, 12, 0, 8)
GridLayout.SortOrder = Enum.SortOrder.LayoutOrder
GridLayout.Parent = Grid

local NoticeFrame = Instance.new("CanvasGroup")
NoticeFrame.Name = "NoticeFrame"
NoticeFrame.Size = UDim2.new(1, 0, 1, 0)
NoticeFrame.BackgroundTransparency = 1
NoticeFrame.BorderSizePixel = 0
NoticeFrame.GroupTransparency = 1
NoticeFrame.Visible = false
NoticeFrame.Parent = MainFrame

local NoticeHeader = Instance.new("Frame")
NoticeHeader.Size = UDim2.new(1, 0, 0, 46)
NoticeHeader.BackgroundTransparency = 1
NoticeHeader.Parent = NoticeFrame

local AppTitle = Instance.new("TextLabel")
AppTitle.Size = UDim2.new(1, -150, 1, 0)
AppTitle.Position = UDim2.new(0, 18, 0, 0)
AppTitle.Font = Enum.Font.GothamBold
AppTitle.TextSize = 14
AppTitle.TextColor3 = THEME.TextPrimary
AppTitle.TextXAlignment = Enum.TextXAlignment.Left
AppTitle.BackgroundTransparency = 1
AppTitle.Text = "Dungeon Quest"
AppTitle.Parent = NoticeHeader

local SwitchBtn = Instance.new("TextButton")
SwitchBtn.Text = ""
SwitchBtn.Size = UDim2.new(0, 110, 0, 26)
SwitchBtn.Position = UDim2.new(1, -128, 0, 10)
SwitchBtn.BackgroundColor3 = THEME.Surface
SwitchBtn.BorderSizePixel = 0
SwitchBtn.AutoButtonColor = false
SwitchBtn.Parent = NoticeHeader

local SwitchStroke = Instance.new("UIStroke")
SwitchStroke.Color = THEME.Border
SwitchStroke.Thickness = 1
SwitchStroke.Parent = SwitchBtn

local SwitchText = Instance.new("TextLabel")
SwitchText.Size = UDim2.new(1, 0, 1, 0)
SwitchText.Font = Enum.Font.GothamMedium
SwitchText.TextSize = 11
SwitchText.TextColor3 = THEME.TextMuted
SwitchText.BackgroundTransparency = 1
SwitchText.Text = "Change Lang"
SwitchText.Parent = SwitchBtn

local NoticeDivider = Instance.new("Frame")
NoticeDivider.Size = UDim2.new(1, 0, 0, 46)
NoticeDivider.BackgroundColor3 = THEME.Border
NoticeDivider.BorderSizePixel = 0
NoticeDivider.Parent = NoticeFrame

local NoticeTitle = Instance.new("TextLabel")
NoticeTitle.Size = UDim2.new(1, -36, 0, 20)
NoticeTitle.Position = UDim2.new(0, 18, 0, 60)
NoticeTitle.Font = Enum.Font.GothamBold
NoticeTitle.TextSize = 15
NoticeTitle.TextColor3 = THEME.TextPrimary
NoticeTitle.TextXAlignment = Enum.TextXAlignment.Left
NoticeTitle.BackgroundTransparency = 1
NoticeTitle.Parent = NoticeFrame

local NoticeBody = Instance.new("TextLabel")
NoticeBody.Size = UDim2.new(1, -36, 0, 65)
NoticeBody.Position = UDim2.new(0, 18, 0, 86)
NoticeBody.Font = Enum.Font.GothamMedium
NoticeBody.TextSize = 13
NoticeBody.TextColor3 = THEME.TextBody
NoticeBody.TextWrapped = true
NoticeBody.LineHeight = 1.35
NoticeBody.TextXAlignment = Enum.TextXAlignment.Left
NoticeBody.TextYAlignment = Enum.TextYAlignment.Top
NoticeBody.BackgroundTransparency = 1
NoticeBody.Parent = NoticeFrame

local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = ""
CloseBtn.Size = UDim2.new(1, -36, 0, 36)
CloseBtn.Position = UDim2.new(0, 18, 1, -48)
CloseBtn.BackgroundColor3 = THEME.Surface
CloseBtn.BorderSizePixel = 0
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = NoticeFrame

local CloseBtnStroke = Instance.new("UIStroke")
CloseBtnStroke.Color = THEME.Border
CloseBtnStroke.Thickness = 1
CloseBtnStroke.Parent = CloseBtn

local CloseBtnText = Instance.new("TextLabel")
CloseBtnText.Size = UDim2.new(1, 0, 1, 0)
CloseBtnText.Font = Enum.Font.GothamBold
CloseBtnText.TextSize = 13
CloseBtnText.TextColor3 = THEME.TextPrimary
CloseBtnText.BackgroundTransparency = 1
CloseBtnText.Parent = CloseBtn

local function bindHover(btn, stroke, baseBg, hoverBg, baseBorder, hoverBorder)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = hoverBg}):Play()
        if stroke then
            TweenService:Create(stroke, TweenInfo.new(0.1), {Color = hoverBorder}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = baseBg}):Play()
        if stroke then
            TweenService:Create(stroke, TweenInfo.new(0.1), {Color = baseBorder}):Play()
        end
    end)
end

bindHover(SwitchBtn, SwitchStroke, THEME.Surface, THEME.SurfaceHover, THEME.Border, THEME.Green)
bindHover(CloseBtn, CloseBtnStroke, THEME.Surface, THEME.SurfaceHover, THEME.Border, THEME.Green)

local function openNotice(langCode)
    local data = Translations[langCode]
    if not data then return end

    NoticeTitle.Text = data.title
    NoticeBody.Text = data.body
    CloseBtnText.Text = data.button
    SwitchText.Text = data.flag .. " " .. data.name

    local fadeOut = TweenService:Create(ChooserFrame, TweenInfo.new(0.15), {GroupTransparency = 1})
    fadeOut:Play()
    fadeOut.Completed:Connect(function()
        ChooserFrame.Visible = false
        NoticeFrame.Visible = true

        local resize = TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 460, 0, 215)})
        resize:Play()

        TweenService:Create(NoticeFrame, TweenInfo.new(0.18), {GroupTransparency = 0}):Play()
    end)
end

local function backToChooser()
    local fadeOut = TweenService:Create(NoticeFrame, TweenInfo.new(0.15), {GroupTransparency = 1})
    fadeOut:Play()
    fadeOut.Completed:Connect(function()
        NoticeFrame.Visible = false
        ChooserFrame.Visible = true

        local resize = TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 460, 0, 275)})
        resize:Play()

        TweenService:Create(ChooserFrame, TweenInfo.new(0.18), {GroupTransparency = 0}):Play()
    end)
end

SwitchBtn.MouseButton1Click:Connect(backToChooser)

for _, langKey in ipairs(LanguageOrder) do
    local info = Translations[langKey]

    local btn = Instance.new("TextButton")
    btn.Name = langKey
    btn.Text = ""
    btn.BackgroundColor3 = THEME.Surface
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = Grid

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.Border
    stroke.Thickness = 1
    stroke.Parent = btn

    local flag = Instance.new("TextLabel")
    flag.Size = UDim2.new(0, 28, 1, 0)
    flag.Position = UDim2.new(0, 8, 0, 0)
    flag.Font = Enum.Font.GothamMedium
    flag.TextSize = 14
    flag.Text = info.flag
    flag.BackgroundTransparency = 1
    flag.Parent = btn

    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, -40, 1, 0)
    name.Position = UDim2.new(0, 36, 0, 0)
    name.Font = Enum.Font.GothamMedium
    name.TextSize = 12
    name.TextColor3 = THEME.TextPrimary
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.BackgroundTransparency = 1
    name.Text = info.name
    name.Parent = btn

    bindHover(btn, stroke, THEME.Surface, THEME.SurfaceHover, THEME.Border, THEME.Green)

    btn.MouseButton1Click:Connect(function()
        openNotice(langKey)
    end)
end

CloseBtn.MouseButton1Click:Connect(function()
    TweenService:Create(Blur, TweenInfo.new(0.2), {Size = 0}):Play()
    TweenService:Create(Backdrop, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()

    local modalClose = TweenService:Create(MainFrame, TweenInfo.new(0.18), {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 0.5, 12)
    })
    modalClose:Play()
    modalClose.Completed:Connect(function()
        ScreenGui:Destroy()
        Blur:Destroy()
    end)
end)

TweenService:Create(Blur, TweenInfo.new(0.3), {Size = 20}):Play()
TweenService:Create(Backdrop, TweenInfo.new(0.25), {BackgroundTransparency = 0.6}):Play()
