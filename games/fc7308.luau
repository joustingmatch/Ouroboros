local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

if not playerGui then
	return
end

local executorName = "Unknown"

if type(identifyexecutor) == "function" then
	local ok, name = pcall(identifyexecutor)

	if ok and type(name) == "string" and name ~= "" then
		executorName = name
	end
end

local translations = {
	en = {
		title = "DISCONTINUED",
		notError = "THIS IS NOT AN ERROR",
		status = "THIS SCRIPT WAS INTENTIONALLY DISABLED",
		desc = "This script has been permanently discontinued and will no longer work. It was intentionally disabled by the developer. Please do not report this screen as an error. Use another script.",
		final = "THIS MESSAGE IS INTENTIONAL"
	},

	fil = {
		title = "ITINIGIL NA",
		notError = "HINDI ITO ERROR",
		status = "SADYANG HINDI NA PINAGANA ANG SCRIPT",
		desc = "Permanenteng itinigil na ang script na ito at hindi na ito gagana. Sadyang hindi na ito pinagana ng developer. Huwag i-report ang screen na ito bilang error. Gumamit na lamang ng ibang script.",
		final = "SADYANG IPINAPAKITA ANG MENSAHENG ITO"
	},

	tl = {
		title = "ITINIGIL NA",
		notError = "HINDI ITO ERROR",
		status = "SADYANG HINDI NA PINAGANA ANG SCRIPT",
		desc = "Permanenteng itinigil na ang script na ito at hindi na ito gagana. Sadyang hindi na ito pinagana ng developer. Huwag i-report ang screen na ito bilang error. Gumamit na lamang ng ibang script.",
		final = "SADYANG IPINAPAKITA ANG MENSAHENG ITO"
	},

	id = {
		title = "DIHENTIKAN",
		notError = "INI BUKAN ERROR",
		status = "SCRIPT INI SENGAJA DINONAKTIFKAN",
		desc = "Script ini telah dihentikan secara permanen dan tidak akan berfungsi lagi. Script ini sengaja dinonaktifkan oleh pengembang. Jangan laporkan layar ini sebagai error. Gunakan script lain.",
		final = "PESAN INI MEMANG DISENGAJA"
	},

	vi = {
		title = "ĐÃ NGỪNG",
		notError = "ĐÂY KHÔNG PHẢI LỖI",
		status = "SCRIPT ĐÃ ĐƯỢC CỐ Ý VÔ HIỆU HÓA",
		desc = "Script này đã bị ngừng vĩnh viễn và sẽ không còn hoạt động. Nhà phát triển đã chủ động vô hiệu hóa nó. Vui lòng không báo màn hình này là lỗi. Hãy sử dụng script khác.",
		final = "THÔNG BÁO NÀY LÀ CỐ Ý"
	},

	th = {
		title = "ยกเลิกแล้ว",
		notError = "นี่ไม่ใช่ข้อผิดพลาด",
		status = "สคริปต์นี้ถูกปิดใช้งานโดยตั้งใจ",
		desc = "สคริปต์นี้ถูกยกเลิกอย่างถาวรและจะไม่สามารถใช้งานได้อีก ผู้พัฒนาได้ปิดใช้งานโดยตั้งใจ โปรดอย่ารายงานหน้าจอนี้ว่าเป็นข้อผิดพลาด และให้ใช้สคริปต์อื่นแทน",
		final = "ข้อความนี้แสดงขึ้นโดยตั้งใจ"
	},

	ru = {
		title = "ПРЕКРАЩЕНО",
		notError = "ЭТО НЕ ОШИБКА",
		status = "СКРИПТ БЫЛ НАМЕРЕННО ОТКЛЮЧЕН",
		desc = "Этот скрипт окончательно закрыт и больше не будет работать. Разработчик намеренно отключил его. Не сообщайте об этом экране как об ошибке. Используйте другой скрипт.",
		final = "ЭТО СООБЩЕНИЕ ПОКАЗАНО НАМЕРЕННО"
	},

	pt = {
		title = "DESCONTINUADO",
		notError = "ISTO NÃO É UM ERRO",
		status = "ESTE SCRIPT FOI DESATIVADO INTENCIONALMENTE",
		desc = "Este script foi descontinuado permanentemente e não funcionará mais. Ele foi desativado intencionalmente pelo desenvolvedor. Não reporte esta tela como erro. Use outro script.",
		final = "ESTA MENSAGEM É INTENCIONAL"
	},

	es = {
		title = "DESCONTINUADO",
		notError = "ESTO NO ES UN ERROR",
		status = "ESTE SCRIPT FUE DESACTIVADO INTENCIONALMENTE",
		desc = "Este script ha sido descontinuado permanentemente y ya no funcionará. Fue desactivado intencionalmente por el desarrollador. No reportes esta pantalla como un error. Utiliza otro script.",
		final = "ESTE MENSAJE ES INTENCIONAL"
	},

	fr = {
		title = "ABANDONNÉ",
		notError = "CECI N'EST PAS UNE ERREUR",
		status = "CE SCRIPT A ÉTÉ DÉSACTIVÉ VOLONTAIREMENT",
		desc = "Ce script a été définitivement abandonné et ne fonctionnera plus. Il a été volontairement désactivé par le développeur. Ne signalez pas cet écran comme une erreur. Utilisez un autre script.",
		final = "CE MESSAGE EST INTENTIONNEL"
	},

	de = {
		title = "EINGESTELLT",
		notError = "DAS IST KEIN FEHLER",
		status = "DIESES SCRIPT WURDE ABSICHTLICH DEAKTIVIERT",
		desc = "Dieses Script wurde dauerhaft eingestellt und funktioniert nicht mehr. Es wurde vom Entwickler absichtlich deaktiviert. Meldet diesen Bildschirm nicht als Fehler. Verwendet ein anderes Script.",
		final = "DIESE MELDUNG IST BEABSICHTIGT"
	},

	ja = {
		title = "公開終了",
		notError = "これはエラーではありません",
		status = "このスクリプトは意図的に無効化されています",
		desc = "このスクリプトは完全に公開終了しており、今後動作しません。開発者によって意図的に無効化されています。この画面をエラーとして報告せず、別のスクリプトを使用してください。",
		final = "このメッセージは意図的に表示されています"
	},

	ko = {
		title = "지원 종료",
		notError = "오류가 아닙니다",
		status = "이 스크립트는 의도적으로 비활성화되었습니다",
		desc = "이 스크립트는 영구적으로 지원이 종료되었으며 더 이상 작동하지 않습니다. 개발자가 의도적으로 비활성화했습니다. 이 화면을 오류로 신고하지 말고 다른 스크립트를 사용해 주세요.",
		final = "이 메시지는 의도적으로 표시됩니다"
	},

	zh = {
		title = "已停止",
		notError = "这不是错误",
		status = "此脚本已被开发者主动禁用",
		desc = "此脚本已永久停止使用，并且不会再次运行。这是开发者主动禁用的。请不要把此界面报告为错误，请使用其他脚本。",
		final = "此消息是有意显示的"
	}
}

local lang = string.match(player.LocaleId or "", "^([^%-_]+)") or "en"
lang = string.lower(lang)

local t = translations[lang] or translations.en

local existingGui

if type(gethui) == "function" then
	local ok, hui = pcall(gethui)

	if ok and hui then
		existingGui = hui:FindFirstChild("DiscontinuedScreen")
	end
else
	existingGui = playerGui:FindFirstChild("DiscontinuedScreen")
end

if existingGui then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DiscontinuedScreen"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if type(gethui) == "function" then
	local ok, hui = pcall(gethui)

	if ok and hui then
		screenGui.Parent = hui
	else
		screenGui.Parent = playerGui
	end
else
	screenGui.Parent = playerGui
end

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.Position = UDim2.fromScale(0, 0)
dim.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.Parent = screenGui

local container = Instance.new("Frame")
container.Name = "Content"
container.Size = UDim2.fromOffset(850, 430)
container.Position = UDim2.fromScale(0.5, 0.5)
container.AnchorPoint = Vector2.new(0.5, 0.5)
container.BackgroundTransparency = 1
container.BorderSizePixel = 0
container.Parent = dim

local uiScale = Instance.new("UIScale")
uiScale.Name = "ResponsiveScale"
uiScale.Scale = 1
uiScale.Parent = container

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "DiscontinuedTitle"
titleLabel.Size = UDim2.new(1, 0, 0, 72)
titleLabel.Position = UDim2.fromOffset(0, 15)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 54
titleLabel.TextColor3 = Color3.fromRGB(255, 72, 72)
titleLabel.TextTransparency = 1
titleLabel.TextWrapped = true
titleLabel.Text = t.title
titleLabel.Parent = container

local notErrorLabel = Instance.new("TextLabel")
notErrorLabel.Name = "NotAnError"
notErrorLabel.Size = UDim2.new(1, 0, 0, 42)
notErrorLabel.Position = UDim2.fromOffset(0, 88)
notErrorLabel.BackgroundTransparency = 1
notErrorLabel.Font = Enum.Font.GothamBold
notErrorLabel.TextSize = 25
notErrorLabel.TextColor3 = Color3.fromRGB(255, 218, 120)
notErrorLabel.TextTransparency = 1
notErrorLabel.TextWrapped = true
notErrorLabel.Text = t.notError
notErrorLabel.Parent = container

local divider = Instance.new("Frame")
divider.Name = "Divider"
divider.Size = UDim2.fromOffset(0, 2)
divider.Position = UDim2.new(0.5, 0, 0, 144)
divider.AnchorPoint = Vector2.new(0.5, 0.5)
divider.BackgroundColor3 = Color3.fromRGB(255, 72, 72)
divider.BackgroundTransparency = 1
divider.BorderSizePixel = 0
divider.Parent = container

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(0.92, 0, 0, 52)
statusLabel.Position = UDim2.new(0.5, 0, 0, 162)
statusLabel.AnchorPoint = Vector2.new(0.5, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 20
statusLabel.TextColor3 = Color3.fromRGB(238, 238, 238)
statusLabel.TextTransparency = 1
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabel.TextYAlignment = Enum.TextYAlignment.Center
statusLabel.Text = t.status
statusLabel.Parent = container

local descLabel = Instance.new("TextLabel")
descLabel.Name = "Description"
descLabel.Size = UDim2.new(0.82, 0, 0, 120)
descLabel.Position = UDim2.new(0.5, 0, 0, 225)
descLabel.AnchorPoint = Vector2.new(0.5, 0)
descLabel.BackgroundTransparency = 1
descLabel.Font = Enum.Font.Gotham
descLabel.TextSize = 17
descLabel.TextColor3 = Color3.fromRGB(205, 205, 205)
descLabel.TextTransparency = 1
descLabel.TextWrapped = true
descLabel.TextXAlignment = Enum.TextXAlignment.Center
descLabel.TextYAlignment = Enum.TextYAlignment.Top
descLabel.Text = t.desc
descLabel.Parent = container

local executorLabel = Instance.new("TextLabel")
executorLabel.Name = "Executor"
executorLabel.Size = UDim2.new(1, 0, 0, 24)
executorLabel.Position = UDim2.fromOffset(0, 355)
executorLabel.BackgroundTransparency = 1
executorLabel.Font = Enum.Font.Gotham
executorLabel.TextSize = 13
executorLabel.TextColor3 = Color3.fromRGB(125, 125, 125)
executorLabel.TextTransparency = 1
executorLabel.Text = "Executor: " .. executorName
executorLabel.Parent = container

local finalLabel = Instance.new("TextLabel")
finalLabel.Name = "FinalNotice"
finalLabel.Size = UDim2.new(0.92, 0, 0, 30)
finalLabel.Position = UDim2.new(0.5, 0, 0, 392)
finalLabel.AnchorPoint = Vector2.new(0.5, 0)
finalLabel.BackgroundTransparency = 1
finalLabel.Font = Enum.Font.GothamBold
finalLabel.TextSize = 14
finalLabel.TextColor3 = Color3.fromRGB(255, 105, 105)
finalLabel.TextTransparency = 1
finalLabel.TextWrapped = true
finalLabel.Text = t.final
finalLabel.Parent = container

local camera = Workspace.CurrentCamera

local viewportConnection

local function updateScale()
	camera = Workspace.CurrentCamera

	if not camera then
		return
	end

	local viewport = camera.ViewportSize

	-- UI was designed around 950x540.
	-- This keeps the entire notice visible on small windows/mobile.
	local widthScale = viewport.X / 950
	local heightScale = viewport.Y / 540

	uiScale.Scale = math.clamp(
		math.min(widthScale, heightScale),
		0.38,
		1
	)
end

local function connectCamera()
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end

	camera = Workspace.CurrentCamera

	if camera then
		updateScale()

		viewportConnection = camera
			:GetPropertyChangedSignal("ViewportSize")
			:Connect(updateScale)
	end
end

connectCamera()

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	connectCamera()
end)

local smooth = TweenInfo.new(
	0.65,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

local slow = TweenInfo.new(
	1,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

TweenService:Create(dim, slow, {
	BackgroundTransparency = 0.04
}):Play()

task.delay(0.15, function()
	if titleLabel.Parent then
		TweenService:Create(titleLabel, smooth, {
			TextTransparency = 0
		}):Play()
	end
end)

task.delay(0.3, function()
	if notErrorLabel.Parent then
		TweenService:Create(notErrorLabel, smooth, {
			TextTransparency = 0
		}):Play()
	end
end)

task.delay(0.45, function()
	if divider.Parent then
		TweenService:Create(divider, slow, {
			BackgroundTransparency = 0,
			Size = UDim2.new(0.45, 0, 0, 2)
		}):Play()
	end
end)

task.delay(0.6, function()
	if statusLabel.Parent then
		TweenService:Create(statusLabel, smooth, {
			TextTransparency = 0
		}):Play()
	end
end)

task.delay(0.8, function()
	if descLabel.Parent then
		TweenService:Create(descLabel, smooth, {
			TextTransparency = 0
		}):Play()
	end
end)

task.delay(1, function()
	if executorLabel.Parent then
		TweenService:Create(executorLabel, smooth, {
			TextTransparency = 0
		}):Play()
	end

	if finalLabel.Parent then
		TweenService:Create(finalLabel, smooth, {
			TextTransparency = 0
		}):Play()
	end
end)

task.delay(1.8, function()
	if notErrorLabel.Parent then
		local pulse = TweenInfo.new(
			1.3,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1,
			true
		)

		TweenService:Create(notErrorLabel, pulse, {
			TextTransparency = 0.25
		}):Play()
	end
end)
