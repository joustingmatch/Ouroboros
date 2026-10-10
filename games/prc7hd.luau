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
	en = {
		status = "discontinued",
		desc = "This script is now discontinued. I've disabled it so people stop bothering me. Don't bother asking and go find another script."
	},

	fil = {
		status = "itinigil na",
		desc = "Itinigil na ang script na ito. Hindi ko na ito pinagana para tumigil na ang mga tao sa pangungulit. Huwag nang magtanong at humanap na lang ng ibang script."
	},

	tl = {
		status = "itinigil na",
		desc = "Itinigil na ang script na ito. Hindi ko na ito pinagana para tumigil na ang mga tao sa pangungulit. Huwag nang magtanong at humanap na lang ng ibang script."
	},

	id = {
		status = "dihentikan",
		desc = "Script ini sekarang telah dihentikan. Saya sudah menonaktifkannya agar orang-orang berhenti mengganggu saya. Jangan bertanya lagi dan cari script lain."
	},

	vi = {
		status = "đã ngừng",
		desc = "Script này hiện đã ngừng hoạt động. Tôi đã vô hiệu hóa nó để mọi người ngừng làm phiền tôi. Đừng hỏi nữa và hãy tìm script khác."
	},

	th = {
		status = "ยกเลิกแล้ว",
		desc = "สคริปต์นี้ถูกยกเลิกแล้ว ฉันปิดการใช้งานมันเพื่อให้คนหยุดมารบกวน อย่าถามอีกและไปหาสคริปต์อื่นใช้"
	},

	ru = {
		status = "закрыт",
		desc = "Этот скрипт больше не поддерживается. Я отключил его, чтобы люди перестали меня беспокоить. Не спрашивайте об этом и найдите другой скрипт."
	},

	pt = {
		status = "descontinuado",
		desc = "Este script foi descontinuado. Eu o desativei para que as pessoas parem de me incomodar. Não adianta perguntar, procure outro script."
	},

	es = {
		status = "descontinuado",
		desc = "Este script ha sido descontinuado. Lo desactivé para que la gente deje de molestarme. No preguntes más y busca otro script."
	},

	fr = {
		status = "abandonné",
		desc = "Ce script est maintenant abandonné. Je l'ai désactivé pour que les gens arrêtent de me déranger. Inutile de demander, trouvez un autre script."
	},

	de = {
		status = "eingestellt",
		desc = "Dieses Script wurde eingestellt. Ich habe es deaktiviert, damit die Leute aufhören, mich damit zu nerven. Fragt nicht danach und sucht euch ein anderes Script."
	},

	ja = {
		status = "公開終了",
		desc = "このスクリプトは現在公開終了しています。これ以上問い合わせされないよう無効化しました。聞かずに別のスクリプトを探してください。"
	},

	ko = {
		status = "지원 종료",
		desc = "이 스크립트는 이제 지원이 종료되었습니다. 사람들이 계속 귀찮게 하지 않도록 비활성화했습니다. 더 이상 묻지 말고 다른 스크립트를 찾아주세요."
	},

	zh = {
		status = "已停止",
		desc = "这个脚本现已停止使用。我已经将其禁用，这样大家就不会再来烦我了。别再问了，去找其他脚本吧。"
	}
}

local lang = string.match(player.LocaleId or "", "^([^%-_]+)") or "en"
lang = string.lower(lang)

local t = translations[lang] or translations.en

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DiscontinuedScreen"
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
container.Size = UDim2.fromScale(0.85, 0.42)
container.Position = UDim2.fromScale(0.5, 0.5)
container.AnchorPoint = Vector2.new(0.5, 0.5)
container.BackgroundTransparency = 1
container.Parent = dim

local nameLabel = Instance.new("TextLabel")
nameLabel.Name = "ExecutorName"
nameLabel.Size = UDim2.new(1, 0, 0, 50)
nameLabel.Position = UDim2.fromScale(0.5, 0.28)
nameLabel.AnchorPoint = Vector2.new(0.5, 1)
nameLabel.BackgroundTransparency = 1
nameLabel.Font = Enum.Font.GothamBold
nameLabel.TextSize = 42
nameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
nameLabel.TextTransparency = 1
nameLabel.Text = executorName
nameLabel.Parent = container

local line = Instance.new("Frame")
line.Name = "Divider"
line.Size = UDim2.new(0, 0, 0, 1)
line.Position = UDim2.fromScale(0.5, 0.4)
line.AnchorPoint = Vector2.new(0.5, 0.5)
line.BackgroundColor3 = Color3.fromRGB(170, 170, 170)
line.BackgroundTransparency = 1
line.BorderSizePixel = 0
line.Parent = container

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, 0, 0, 32)
statusLabel.Position = UDim2.fromScale(0.5, 0.48)
statusLabel.AnchorPoint = Vector2.new(0.5, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 22
statusLabel.TextColor3 = Color3.fromRGB(215, 215, 215)
statusLabel.TextTransparency = 1
statusLabel.Text = t.status
statusLabel.Parent = container

local descLabel = Instance.new("TextLabel")
descLabel.Name = "Description"
descLabel.Size = UDim2.new(0.8, 0, 0, 100)
descLabel.Position = UDim2.fromScale(0.5, 0.62)
descLabel.AnchorPoint = Vector2.new(0.5, 0)
descLabel.BackgroundTransparency = 1
descLabel.Font = Enum.Font.Gotham
descLabel.TextSize = 16
descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
descLabel.TextTransparency = 1
descLabel.TextWrapped = true
descLabel.TextXAlignment = Enum.TextXAlignment.Center
descLabel.TextYAlignment = Enum.TextYAlignment.Top
descLabel.Text = t.desc
descLabel.Parent = container

local smooth = TweenInfo.new(
	0.8,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

local slow = TweenInfo.new(
	1.2,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

TweenService:Create(dim, slow, {
	BackgroundTransparency = 0.12
}):Play()

task.delay(0.3, function()
	TweenService:Create(nameLabel, smooth, {
		TextTransparency = 0
	}):Play()
end)

task.delay(0.5, function()
	TweenService:Create(line, slow, {
		BackgroundTransparency = 0,
		Size = UDim2.new(0.3, 0, 0, 1)
	}):Play()
end)

task.delay(0.7, function()
	TweenService:Create(statusLabel, smooth, {
		TextTransparency = 0
	}):Play()
end)

task.delay(1.1, function()
	TweenService:Create(descLabel, smooth, {
		TextTransparency = 0
	}):Play()
end)

task.delay(2.5, function()
	local breathe = TweenInfo.new(
		2.5,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1,
		true
	)

	TweenService:Create(statusLabel, breathe, {
		TextTransparency = 0.2
	}):Play()
end)
