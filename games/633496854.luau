local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)
if not playerGui then return end

local executorName = "Unknown"
if type(identifyexecutor) == "function" then
	local ok, name = pcall(identifyexecutor)
	if ok and type(name) == "string" and name ~= "" then
		executorName = name
	end
end

local translations = {
	en  = { status = "unsupported",           desc = "this script is not compatible with your executor" },
	fil = { status = "hindi suportado",       desc = "ang script na ito ay hindi compatible sa iyong executor" },
	tl  = { status = "hindi suportado",       desc = "ang script na ito ay hindi compatible sa iyong executor" },
	id  = { status = "tidak didukung",        desc = "skrip ini tidak kompatibel dengan executor anda" },
	vi  = { status = "kh\195\180ng \196\145\198\176\225\187\163c h\225\187\151 tr\225\187\163", desc = "t\225\186\173p l\225\187\135nh n\195\160y kh\195\180ng t\198\176\198\161ng th\195\173ch v\225\187\155i executor c\225\187\167a b\225\186\161n" },
	th  = { status = "\224\185\132\224\184\161\224\185\136\224\184\163\224\184\173\224\184\135\224\184\163\224\184\177\224\184\154", desc = "\224\184\170\224\184\132\224\184\163\224\184\180\224\184\155\224\184\151\224\185\140\224\184\153\224\184\181\224\185\137\224\185\132\224\184\161\224\185\136\224\184\163\224\184\173\224\184\135\224\184\163\224\184\177\224\184\154\224\184\129\224\184\177\224\184\154 executor \224\184\130\224\184\173\224\184\135\224\184\132\224\184\184\224\184\147" },
	ru  = { status = "\208\189\208\181 \208\191\208\190\208\180\208\180\208\181\209\128\208\182\208\184\208\178\208\176\208\181\209\130\209\129\209\143", desc = "\209\141\209\130\208\190\209\130 \209\129\208\186\209\128\208\184\208\191\209\130 \208\189\208\181\209\129\208\190\208\178\208\188\208\181\209\129\209\130\208\184\208\188 \209\129 \208\178\208\176\209\136\208\184\208\188 executor" },
	pt  = { status = "n\195\163o suportado",  desc = "este script n\195\163o \195\169 compat\195\173vel com seu executor" },
}

local lang = string.match(player.LocaleId or "", "^([^%-_]+)") or "en"
lang = string.lower(lang)
local t = translations[lang] or translations.en

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UnsupportedScreen"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if type(gethui) == "function" then
	screenGui.Parent = gethui()
else
	screenGui.Parent = playerGui
end

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.Parent = screenGui

local container = Instance.new("Frame")
container.Name = "Content"
container.Size = UDim2.fromScale(0.8, 0.3)
container.Position = UDim2.fromScale(0.5, 0.5)
container.AnchorPoint = Vector2.new(0.5, 0.5)
container.BackgroundTransparency = 1
container.Parent = dim

local nameLabel = Instance.new("TextLabel")
nameLabel.Name = "ExecutorName"
nameLabel.Size = UDim2.new(1, 0, 0, 42)
nameLabel.Position = UDim2.fromScale(0.5, 0.4)
nameLabel.AnchorPoint = Vector2.new(0.5, 1)
nameLabel.BackgroundTransparency = 1
nameLabel.Font = Enum.Font.GothamBold
nameLabel.TextSize = 42
nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
nameLabel.TextTransparency = 1
nameLabel.Text = executorName
nameLabel.Parent = container

local line = Instance.new("Frame")
line.Name = "Divider"
line.Size = UDim2.new(0, 0, 0, 1)
line.Position = UDim2.fromScale(0.5, 0.5)
line.AnchorPoint = Vector2.new(0.5, 0.5)
line.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
line.BackgroundTransparency = 1
line.BorderSizePixel = 0
line.Parent = container

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, 0, 0, 28)
statusLabel.Position = UDim2.fromScale(0.5, 0.6)
statusLabel.AnchorPoint = Vector2.new(0.5, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 20
statusLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
statusLabel.TextTransparency = 1
statusLabel.Text = t.status
statusLabel.Parent = container

local descLabel = Instance.new("TextLabel")
descLabel.Name = "Description"
descLabel.Size = UDim2.new(0.6, 0, 0, 20)
descLabel.Position = UDim2.fromScale(0.5, 0.72)
descLabel.AnchorPoint = Vector2.new(0.5, 0)
descLabel.BackgroundTransparency = 1
descLabel.Font = Enum.Font.Gotham
descLabel.TextSize = 14
descLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
descLabel.TextTransparency = 1
descLabel.Text = t.desc
descLabel.Parent = container

local smooth = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local slow = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

TweenService:Create(dim, slow, { BackgroundTransparency = 0.35 }):Play()

task.delay(0.3, function()
	TweenService:Create(nameLabel, smooth, { TextTransparency = 0 }):Play()
end)

task.delay(0.5, function()
	TweenService:Create(line, slow, { BackgroundTransparency = 0, Size = UDim2.new(0.25, 0, 0, 1) }):Play()
end)

task.delay(0.7, function()
	TweenService:Create(statusLabel, smooth, { TextTransparency = 0 }):Play()
end)

task.delay(1.1, function()
	TweenService:Create(descLabel, smooth, { TextTransparency = 0 }):Play()
end)

task.delay(2.5, function()
	local breathe = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(statusLabel, breathe, { TextTransparency = 0.5 }):Play()
end)
