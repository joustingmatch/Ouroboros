local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local function hubGetHui()
	return CoreGui
end

if getgenv then
	getgenv().gethui = hubGetHui
	local previous = getgenv().__OuroborosCakeMountainLib
	if previous and previous.Unload then
		pcall(function()
			previous:Unload()
		end)
	end
end

pcall(function()
	gethui = hubGetHui
end)

if setthreadidentity then
	setthreadidentity(8)
end

local GAME_NAME = "Cake Mountain"
local DISCORD_INVITE = "https://discord.gg/synapsex"
local RSCRIPTS_LINK = "https://rscripts.net/@Ouroboros"
local WEBSITE_LINK = "https://ouroboros-hub-rbx.web.app/"

local GREEN = "#7fd47f"
local BLUE = "#6ec1ff"
local ORANGE = "#e8a34d"
local GREY = "#8b93a3"
local RED = "#e05a5a"

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DigRequest = Remotes:WaitForChild("DigRequest")
local SellAll = Remotes:WaitForChild("SellAll")
local BuyUpgrade = Remotes:WaitForChild("BuyUpgrade")
local GetInventory = Remotes:WaitForChild("GetInventory")

local CakeConfig = require(ReplicatedStorage:WaitForChild("CakeConfig"))

local RARITY_VALUES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
local FLUSH_VALUES = { "50%", "100%" }
local SELL_MODE_VALUES = { "Full Backpack", "Selected KG", "Sell Anytime" }
local UPGRADE_VALUES = { "Arm", "Arm +10", "Stomach", "Legs", "Scoop" }
local UPGRADE_REMOTE = {
	Arm = "Arm",
	["Arm +10"] = "Arm10",
	Stomach = "Stomach",
	Legs = "Legs",
	Scoop = "ScoopLegacy",
}

local repo = "https://raw.githubusercontent.com/joustingmatch/ObsidianUltra/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

if getgenv then
	getgenv().__OuroborosCakeMountainLib = Library
end

local Toggles = Library.Toggles
local Options = Library.Options

local function copyText(text, message)
	if setclipboard then
		setclipboard(text)
	elseif toclipboard then
		toclipboard(text)
	end
	Library:Notify(message)
end

local function copyDiscord()
	copyText(DISCORD_INVITE, "Copied Discord invite to clipboard")
end

local function colored(text, color)
	return string.format('<font color="%s">%s</font>', color, text)
end

local function field(key, value, color)
	return string.format("<b>%s</b> %s %s", key, colored("-", "#5a6070"), colored(value, color))
end

local function isOn(name)
	if Library.Unloaded then
		return false
	end
	local toggle = Toggles[name]
	return toggle ~= nil and toggle.Value == true
end

local function optionValue(name, fallback)
	local option = Options[name]
	if option == nil then
		return fallback
	end
	return option.Value
end

local function multiSelected(name)
	local value = optionValue(name, {})
	if typeof(value) ~= "table" then
		return {}
	end
	local selected = {}
	for key, on in value do
		if on == true then
			selected[key] = true
		elseif typeof(key) == "number" and typeof(on) == "string" then
			selected[on] = true
		end
	end
	return selected
end

local function multiHasAny(name)
	return next(multiSelected(name)) ~= nil
end

local function getRoot()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
	local character = LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function teleportTo(cf)
	local root = getRoot()
	if not root then
		return false
	end
	if typeof(cf) == "Vector3" then
		root.CFrame = CFrame.new(cf)
	else
		root.CFrame = cf
	end
	return true
end

local function getFullness()
	return tonumber(LocalPlayer:GetAttribute("Fullness")) or 0
end

local function getCrumbs()
	local crumbs = LocalPlayer:FindFirstChild("CrumbsNum")
	return crumbs and tonumber(crumbs.Value) or 0
end

local function getSpoonTier()
	return tonumber(LocalPlayer:GetAttribute("SpoonTier")) or 1
end

local function getInventory()
	local ok, inv = pcall(function()
		return GetInventory:InvokeServer()
	end)
	if ok and type(inv) == "table" then
		return inv
	end
	return nil
end

local function bagIsFull()
	local inv = getInventory()
	if not inv then
		return false
	end
	local used = tonumber(inv.used) or 0
	local capacity = tonumber(inv.capacity) or 0
	if capacity <= 0 then
		return false
	end
	return used >= capacity - 0.05
end

local function bagUsed()
	local inv = getInventory()
	if not inv then
		return 0
	end
	return tonumber(inv.used) or 0
end

local function bagCapacity()
	local inv = getInventory()
	if not inv then
		return 0
	end
	return tonumber(inv.capacity) or 0
end

local function bagRemaining()
	return math.max(bagCapacity() - bagUsed(), 0)
end

local function cakeWeight(model)
	return tonumber(model and model:GetAttribute("Weight")) or 0
end

local function shouldAutoSell()
	local mode = optionValue("SellMode", "Full Backpack")
	local used = bagUsed()
	if used <= 0 then
		return false
	end
	if mode == "Sell Anytime" then
		return true
	end
	if mode == "Selected KG" then
		local kg = tonumber(optionValue("SellKG", 10)) or 10
		return used >= kg
	end
	return bagIsFull()
end

local function getFarmSpeed()
	return math.max(tonumber(optionValue("FarmSpeed", 45)) or 45, 10)
end

local function holdingCake()
	return (tonumber(LocalPlayer:GetAttribute("HeldCakeIndex")) or 0) > 0
end

local function unequipTools()
	local humanoid = getHumanoid()
	if humanoid then
		pcall(function()
			humanoid:UnequipTools()
		end)
	end
end

local function rarityAllowed(rarity)
	if not multiHasAny("FarmRarity") then
		return true
	end
	local selected = multiSelected("FarmRarity")
	return selected[rarity] == true
end

local function claimedByOther(model)
	local digger = model:GetAttribute("DiggerUserId")
	local claimUntil = tonumber(model:GetAttribute("ClaimUntil")) or 0
	if type(digger) ~= "number" then
		return false
	end
	if digger == LocalPlayer.UserId then
		return false
	end
	return Workspace:GetServerTimeNow() < claimUntil
end

local function firePrompt(prompt, holdDuration)
	if not prompt or not fireproximityprompt then
		return false
	end
	local hold = holdDuration
	if hold == nil then
		hold = prompt.HoldDuration
	end
	local ok = pcall(fireproximityprompt, prompt, hold)
	if ok then
		return true
	end
	ok = pcall(fireproximityprompt, prompt)
	return ok
end

local function fireGuiSignal(signal)
	if getconnections then
		local ok, conns = pcall(getconnections, signal)
		if ok and conns then
			for _, conn in conns do
				if conn.Fire then
					pcall(function()
						conn:Fire()
					end)
				elseif conn.Function then
					pcall(conn.Function)
				end
			end
			return true
		end
	end
	if firesignal then
		return pcall(firesignal, signal)
	end
	return false
end

local function getPackButton()
	local gui = LocalPlayer:FindFirstChild("PlayerGui")
	local targetCard = gui and gui:FindFirstChild("UI_TargetCard")
	local card = targetCard and targetCard:FindFirstChild("Card")
	return card, card and card:FindFirstChild("PackButton")
end

local function waitForPackCard(timeout)
	local deadline = os.clock() + (timeout or 2)
	while os.clock() < deadline do
		local card = getPackButton()
		if card and card.Visible then
			task.wait(0.08)
			if card.Visible then
				return card
			end
		end
		task.wait(0.05)
	end
	local card = getPackButton()
	if card and card.Visible then
		return card
	end
	return nil
end

local function packCake(prompt)
	local card, packButton = getPackButton()
	if not (card and card.Visible and packButton and prompt) then
		return false
	end
	local hold = math.max(tonumber(prompt.HoldDuration) or 0, 0.15)
	fireGuiSignal(packButton.MouseButton1Down)
	local deadline = os.clock() + hold + 0.45
	while os.clock() < deadline do
		if not card.Visible then
			fireGuiSignal(packButton.MouseButton1Down)
		end
		task.wait(0.05)
	end
	fireGuiSignal(packButton.MouseButton1Up)
	fireGuiSignal(packButton.MouseLeave)
	task.wait(0.25)
	return true
end

local function getFlushPrompt()
	local toilet = Workspace:FindFirstChild("CakeHouse")
	toilet = toilet and toilet:FindFirstChild("Toilet")
	local tank = toilet and toilet:FindFirstChild("Tank")
	return tank and tank:FindFirstChild("FlushPrompt")
end

local lastDigAt = 0
local farmBusy = false
local farmAssistActive = false
local farmHoverCF = nil
local sellBusy = false
local flushBusy = false
local farmFailUntil = {}

local function digCooldown()
	return tonumber(LocalPlayer:GetAttribute("DigCooldown")) or CakeConfig.DigCooldown or 0.4
end

local function setFarmAssist(active, hoverCf)
	farmAssistActive = active == true
	farmHoverCF = hoverCf
	if not farmAssistActive then
		farmHoverCF = nil
		if not isOn("Fly") then
			local humanoid = getHumanoid()
			if humanoid then
				humanoid.PlatformStand = false
			end
		end
	end
end

local function applyFarmNoclip()
	local character = LocalPlayer.Character
	if not character then
		return
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
end

local function cakeHoverCf(part)
	return CFrame.lookAt(part.Position + Vector3.new(0, 7, 0), part.Position)
end

local function markFarmFail(model)
	if model then
		farmFailUntil[model] = os.clock() + 10
	end
end

local function isFarmFailed(model)
	local untilTime = farmFailUntil[model]
	return untilTime ~= nil and os.clock() < untilTime
end

local function pruneFarmFails()
	local now = os.clock()
	for model, untilTime in pairs(farmFailUntil) do
		if now >= untilTime or not model.Parent then
			farmFailUntil[model] = nil
		end
	end
end

local function doAutoEat()
	if farmBusy or farmAssistActive or flushBusy then
		return
	end
	if getFullness() >= 0.999 then
		return
	end
	local now = os.clock()
	if now - lastDigAt < digCooldown() then
		return
	end
	local root = getRoot()
	local character = LocalPlayer.Character
	if not root or not character then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local look = root.CFrame.LookVector
	local hit = Workspace:Raycast(origin, look * 200, params)
	if not (hit and hit.Instance == Workspace.Terrain) then
		hit = Workspace:Raycast(origin, Vector3.new(0, -60, 0), params)
	end
	local range = CakeConfig.ClientDigRange or 13
	local lookFlat = Vector3.new(look.X, 0, look.Z)
	if lookFlat.Magnitude < 0.05 then
		lookFlat = Vector3.new(0, 0, -1)
	else
		lookFlat = lookFlat.Unit
	end
	local digPos = hit and hit.Position or (root.Position + lookFlat * 4)
	local digNormal = hit and hit.Normal or Vector3.new(0, 1, 0)
	if (digPos - root.Position).Magnitude > range then
		digPos = root.Position + lookFlat * math.min(range - 1, 6)
		digNormal = Vector3.new(0, 1, 0)
	end
	lastDigAt = now
	DigRequest:FireServer(digPos, digNormal)
end

local function pickFarmCake()
	pruneFarmFails()
	local folder = Workspace:FindFirstChild("MiniCakes")
	if not folder then
		return nil
	end
	local root = getRoot()
	local rootPos = root and root.Position or Vector3.zero
	local remaining = bagRemaining()
	local best, bestDist = nil, math.huge
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and not claimedByOther(model) and not isFarmFailed(model) then
			local rarity = model:GetAttribute("Rarity") or "Common"
			if rarityAllowed(rarity) then
				local weight = cakeWeight(model)
				if weight <= remaining + 0.05 then
					local prompt = model:FindFirstChild("CollectPrompt", true)
					local part = prompt and prompt.Parent
					if prompt and prompt.Enabled and part and part:IsA("BasePart") then
						local dist = (part.Position - rootPos).Magnitude
						if dist < bestDist then
							bestDist = dist
							best = { model = model, prompt = prompt, part = part, weight = weight }
						end
					end
				end
			end
		end
	end
	return best
end

local function hoverNearCake(part, timeout)
	if not part then
		return false
	end
	local deadline = os.clock() + (timeout or 5)
	local speed = getFarmSpeed()
	setFarmAssist(true, cakeHoverCf(part))
	while os.clock() < deadline do
		if Library.Unloaded or not part.Parent then
			return false
		end
		local root = getRoot()
		if not root then
			return false
		end
		local targetPos = part.Position + Vector3.new(0, 7, 0)
		local delta = targetPos - root.Position
		if delta.Magnitude <= 3.5 then
			setFarmAssist(true, cakeHoverCf(part))
			return true
		end
		local dt = task.wait()
		local step = math.min(delta.Magnitude, math.max(speed * dt, 0.5))
		local nextPos = root.Position + delta.Unit * step
		setFarmAssist(true, CFrame.lookAt(nextPos, part.Position))
	end
	local root = getRoot()
	return root ~= nil and (root.Position - (part.Position + Vector3.new(0, 7, 0))).Magnitude <= 8
end

local function doAutoFarmCake()
	if farmBusy or flushBusy or sellBusy then
		return
	end
	if Library.Unloaded then
		return
	end
	if bagIsFull() then
		return
	end
	if holdingCake() then
		return
	end
	local target = pickFarmCake()
	if not target then
		return
	end
	farmBusy = true
	local packed = false
	local keepHover = false
	local ok = pcall(function()
		local part = target.part
		local model = target.model
		local prompt = target.prompt
		if not (part and part.Parent and model and model.Parent and prompt and prompt.Parent) then
			return
		end
		if claimedByOther(model) or cakeWeight(model) > bagRemaining() + 0.05 then
			return
		end

		prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 30)
		prompt.RequiresLineOfSight = false
		prompt.Enabled = true
		unequipTools()

		if not hoverNearCake(part, 6) then
			markFarmFail(model)
			return
		end
		if not model.Parent or claimedByOther(model) then
			return
		end

		keepHover = true
		task.spawn(function()
			while keepHover and farmBusy and part.Parent and model.Parent and not Library.Unloaded do
				setFarmAssist(true, cakeHoverCf(part))
				task.wait(0.03)
			end
		end)

		task.wait(0.2)
		unequipTools()
		local card = waitForPackCard(2.5)
		if not card or not model.Parent then
			markFarmFail(model)
			return
		end

		local hold = math.max(tonumber(prompt.HoldDuration) or 0, 0.15)
		local usedBefore = bagUsed()
		packCake(prompt)
		if model.Parent then
			pcall(function()
				prompt:InputHoldBegin()
			end)
			firePrompt(prompt, hold)
			task.wait(hold + 0.45)
			pcall(function()
				prompt:InputHoldEnd()
			end)
		end
		packed = not model.Parent or bagUsed() > usedBefore + 0.01
		if not packed then
			markFarmFail(model)
		end
	end)
	keepHover = false
	setFarmAssist(false)
	farmBusy = false
	if not ok then
		pcall(markFarmFail, target.model)
	end
	return packed
end

local function doAutoSell()
	if sellBusy or farmBusy or flushBusy then
		return
	end
	if not shouldAutoSell() then
		return
	end
	sellBusy = true
	pcall(function()
		SellAll:InvokeServer()
	end)
	task.wait(0.35)
	sellBusy = false
end

local function flushThreshold()
	local value = optionValue("FlushAt", "100%")
	if value == "50%" then
		return 0.5
	end
	return 0.999
end

local function doAutoFlush()
	if flushBusy or farmBusy or farmAssistActive then
		return
	end
	if getFullness() < flushThreshold() then
		return
	end
	local prompt = getFlushPrompt()
	if not prompt then
		return
	end
	local part = prompt.Parent
	if not part or not part:IsA("BasePart") then
		return
	end
	flushBusy = true
	pcall(function()
		teleportTo(CFrame.lookAt((part.CFrame * CFrame.new(0, 0, -5)).Position, part.Position))
		task.wait(0.2)
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 50
		prompt.RequiresLineOfSight = false
		firePrompt(prompt, 0)
		task.wait(0.8)
	end)
	flushBusy = false
end

local buyBusy = false

local function doAutoBuySpoon()
	if buyBusy or farmBusy or flushBusy then
		return
	end
	local tier = getSpoonTier()
	if tier >= 20 then
		return
	end
	local okCost, cost = pcall(CakeConfig.spoonCost, tier)
	if not okCost or type(cost) ~= "number" then
		return
	end
	if getCrumbs() < cost then
		return
	end
	buyBusy = true
	pcall(function()
		BuyUpgrade:InvokeServer("Spoon")
	end)
	task.wait(0.25)
	buyBusy = false
end

local function doAutoBuyUpgrades()
	if buyBusy or farmBusy or flushBusy then
		return
	end
	if not multiHasAny("BuyUpgrades") then
		return
	end
	local selected = multiSelected("BuyUpgrades")
	buyBusy = true
	for _, label in UPGRADE_VALUES do
		if selected[label] then
			local remoteKey = UPGRADE_REMOTE[label]
			if remoteKey then
				pcall(function()
					BuyUpgrade:InvokeServer(remoteKey)
				end)
				task.wait(0.12)
			end
		end
	end
	task.wait(0.15)
	buyBusy = false
end

local Window = Library:CreateWindow({
	Title = "Ouroboros",
	Font = Enum.Font.BuilderSans,
	Footer = {
		{ Text = DISCORD_INVITE, Copyable = true },
		"|",
		GAME_NAME,
	},
	Icon = 78539693571783,
	NotifySide = "Right",
	ShowCustomCursor = false,
	CornerRadius = 0,
	TabSwipeFrom = "bottom",
	Animations = {
		TabSwitch = true,
	},
})

local Tabs = {
	Info = Window:AddTab("Info", "info"),
	Main = Window:AddTab("Main", "cake-slice"),
	Player = Window:AddTab("Player", "person-standing"),
	Settings = Window:AddTab("Settings", "settings"),
}

local function AddDiscordButton(Tab)
	local DiscordGroup = Tab:AddLeftGroupbox("Discord")
	DiscordGroup:AddButton({
		Text = "Join Discord to Make Money",
		Func = copyDiscord,
	})
	DiscordGroup:AddButton({
		Text = "Join Discord for Keyless Scripts",
		Func = copyDiscord,
	})
end

for name, Tab in Tabs do
	if name ~= "Info" then
		AddDiscordButton(Tab)
	end
end

local FarmGroup = Tabs.Main:AddLeftGroupbox("Farm", "utensils")
FarmGroup:AddToggle("AutoFarmCake", { Text = "Auto Farm Cake", Default = false })
FarmGroup:AddDropdown("FarmRarity", {
	Text = "Rarity",
	Values = RARITY_VALUES,
	Default = {},
	Multi = true,
	AllowEmpty = true,
})
FarmGroup:AddSlider("FarmSpeed", {
	Text = "Farm Speed",
	Default = 45,
	Min = 10,
	Max = 120,
	Rounding = 0,
})
FarmGroup:AddToggle("AutoEat", { Text = "Auto Eat", Default = false })
FarmGroup:AddToggle("AutoSell", { Text = "Auto Sell", Default = false })
FarmGroup:AddDropdown("SellMode", {
	Text = "Sell Mode",
	Values = SELL_MODE_VALUES,
	Default = 1,
})
FarmGroup:AddSlider("SellKG", {
	Text = "Sell KG",
	Default = 10,
	Min = 1,
	Max = 100,
	Rounding = 0,
	Suffix = "kg",
})

local function refreshSellKgVisibility()
	local slider = Options.SellKG
	if not slider then
		return
	end
	local show = optionValue("SellMode", "Full Backpack") == "Selected KG"
	if slider.SetVisible then
		slider:SetVisible(show)
	end
end

Options.SellMode:OnChanged(refreshSellKgVisibility)
task.defer(refreshSellKgVisibility)

local StomachGroup = Tabs.Main:AddRightGroupbox("Stomach", "droplet")
StomachGroup:AddToggle("AutoFlush", { Text = "Auto Flush", Default = false })
StomachGroup:AddDropdown("FlushAt", {
	Text = "Flush At",
	Values = FLUSH_VALUES,
	Default = 2,
})

local ShopGroup = Tabs.Main:AddRightGroupbox("Shop", "shopping-bag")
ShopGroup:AddToggle("AutoBuyUpgrades", { Text = "Auto Buy Upgrades", Default = false })
ShopGroup:AddDropdown("BuyUpgrades", {
	Text = "Upgrades",
	Values = UPGRADE_VALUES,
	Default = {},
	Multi = true,
	AllowEmpty = true,
})
ShopGroup:AddToggle("AutoBuySpoon", { Text = "Auto Buy Spoon", Default = false })

local function setupInfoTab()
	local function detectSupport()
		local flags = {
			hookfunction ~= nil,
			hookmetamethod ~= nil,
			getrawmetatable ~= nil,
			setrawmetatable ~= nil,
			getgc ~= nil,
			getgenv ~= nil,
			getreg ~= nil,
			getconnections ~= nil,
			firesignal ~= nil,
			getcallbackvalue ~= nil,
			setclipboard ~= nil,
			getcustomasset ~= nil,
			getnamecallmethod ~= nil,
			isexecutorclosure ~= nil,
			fireproximityprompt ~= nil,
			firetouchinterest ~= nil,
			WebSocket ~= nil,
			readfile ~= nil,
			writefile ~= nil,
			(request or http_request) ~= nil,
			(debug and debug.getupvalues) ~= nil,
			(debug and debug.setupvalue) ~= nil,
		}
		local available = 0
		for _, ok in ipairs(flags) do
			if ok then
				available += 1
			end
		end
		local ratio = available / #flags
		if ratio >= 0.9 then
			return colored("Full Support", GREEN)
		elseif ratio >= 0.6 then
			return colored("Half Support", ORANGE)
		else
			return colored("Low Support", RED)
		end
	end

	local executorName = "Unknown"
	pcall(function()
		if identifyexecutor then
			local name, version = identifyexecutor()
			if type(name) == "string" and name ~= "" then
				executorName = type(version) == "string" and version ~= "" and (name .. " " .. version) or name
			end
		end
	end)

	local supportText = detectSupport()
	local sessionStart = os.clock()

	local function sessionElapsed()
		local elapsed = math.floor(os.clock() - sessionStart)
		if elapsed < 60 then
			return elapsed .. "s"
		elseif elapsed < 3600 then
			return string.format("%dm %ds", elapsed // 60, elapsed % 60)
		else
			return string.format("%dh %dm", elapsed // 3600, (elapsed % 3600) // 60)
		end
	end

	local UserGroup = Tabs.Info:AddLeftGroupbox("User", "circle-user")
	UserGroup:AddPlayerInfo("InfoUserCard", {
		Player = LocalPlayer,
		Title = "User",
		HeaderIcon = "user",
		Collapsible = false,
	})
	UserGroup:AddLabel(field("User", LocalPlayer.DisplayName .. " @" .. LocalPlayer.Name, GREEN), true)
	UserGroup:AddLabel(field("UserId", tostring(LocalPlayer.UserId), BLUE), true)
	UserGroup:AddLabel(field("Executor", executorName .. "  " .. supportText, GREEN), true)
	UserGroup:AddDivider()
	local SessionLabel = UserGroup:AddLabel(field("Session", sessionElapsed(), ORANGE), true)
	UserGroup:AddDivider()
	UserGroup:AddButton({
		Text = "Copy Username",
		Func = function()
			copyText(LocalPlayer.Name, "Copied username")
		end,
	})
	UserGroup:AddButton({
		Text = "Copy Profile Link",
		Func = function()
			copyText("https://www.roblox.com/users/" .. tostring(LocalPlayer.UserId) .. "/profile", "Copied profile link")
		end,
	})

	local SessionGroup = Tabs.Info:AddRightGroupbox("Session", "signal")
	SessionGroup:AddDivider("Server")
	SessionGroup:AddLabel(field("Game", GAME_NAME, BLUE), true)
	local PlayersLabel = SessionGroup:AddLabel(field("Players", "0/0", GREEN), true)
	local jobId = tostring(game.JobId)
	local shortJobId = #jobId > 18 and (string.sub(jobId, 1, 18) .. "...") or jobId
	SessionGroup:AddLabel(field("Job", shortJobId, GREY), true)
	local PingLabel = SessionGroup:AddLabel(field("Ping", "0 ms", ORANGE), true)
	SessionGroup:AddDivider()
	SessionGroup:AddButton({
		Text = "Rejoin Server",
		Func = function()
			TeleportService:Teleport(game.PlaceId, LocalPlayer)
		end,
	})
	SessionGroup:AddButton({
		Text = "Copy Job ID",
		Func = function()
			copyText(jobId, "Copied Job ID")
		end,
	})

	task.spawn(function()
		while true do
			task.wait(1)
			if Library.Unloaded then
				break
			end
			SessionLabel:SetText(field("Session", sessionElapsed(), ORANGE))
			PlayersLabel:SetText(field("Players", #Players:GetPlayers() .. "/" .. tostring(Players.MaxPlayers), GREEN))
			local ok, ping = pcall(function()
				return math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
			end)
			PingLabel:SetText(field("Ping", ok and (ping .. " ms") or "n/a", ORANGE))
		end
	end)

	local SocialsGroup = Tabs.Info:AddRightGroupbox("Socials", "link")
	SocialsGroup:AddButton({ Text = "Discord", Func = copyDiscord })
	SocialsGroup:AddButton({
		Text = "Rscripts",
		Func = function()
			if setclipboard then
				setclipboard(RSCRIPTS_LINK)
			elseif toclipboard then
				toclipboard(RSCRIPTS_LINK)
			end
			Library:Notify("Copied Rscripts profile to clipboard")
		end,
	})
	SocialsGroup:AddButton({
		Text = "Website",
		Func = function()
			copyText(WEBSITE_LINK, "Copied website link")
		end,
	})
end

local function setupPlayerTab()
	local MovementGroup = Tabs.Player:AddLeftGroupbox("Movement", "footprints")
	MovementGroup:AddToggle("WalkSpeedEnabled", { Text = "WalkSpeed", Default = false })
	MovementGroup:AddSlider("WalkSpeed", {
		Text = "WalkSpeed Amount",
		Default = 32,
		Min = 16,
		Max = 250,
		Rounding = 0,
	})
	MovementGroup:AddToggle("InfJump", { Text = "Infinite Jump", Default = false })
	MovementGroup:AddToggle("NoClip", { Text = "NoClip", Default = false })
	MovementGroup:AddToggle("AntiGameplayPause", { Text = "No Gameplay Paused", Default = true })
	MovementGroup:AddToggle("InstantProximityPrompt", { Text = "Instant ProximityPrompt", Default = false })

	local FlyGroup = Tabs.Player:AddRightGroupbox("Fly", "feather")
	FlyGroup:AddToggle("Fly", { Text = "Fly", Default = false })
	FlyGroup:AddSlider("FlySpeed", {
		Text = "Fly Speed",
		Default = 60,
		Min = 10,
		Max = 400,
		Rounding = 0,
	})

	local function applyAntiGameplayPause(enabled)
		pcall(function()
			GuiService:SetGameplayPausedNotificationEnabled(not enabled)
		end)
		pcall(function()
			local notification = CoreGui:FindFirstChild("RobloxNetworkPauseNotification")
			if notification then
				notification.Enabled = not enabled
			end
		end)
		if not enabled then
			return
		end
		pcall(function()
			if sethiddenproperty then
				sethiddenproperty(LocalPlayer, "GameplayPaused", false)
			else
				LocalPlayer.GameplayPaused = false
			end
		end)
	end

	local function applyInstantPrompt(prompt)
		if not prompt:IsA("ProximityPrompt") then
			return
		end
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 50
		prompt.RequiresLineOfSight = false
	end

	local instantPromptConnection

	RunService.Stepped:Connect(function()
		if Library.Unloaded then
			return
		end
		if isOn("NoClip") or farmAssistActive then
			local character = LocalPlayer.Character
			if character then
				for _, part in ipairs(character:GetDescendants()) do
					if part:IsA("BasePart") and part.CanCollide then
						part.CanCollide = false
					end
				end
			end
		end
		if farmAssistActive then
			applyFarmNoclip()
		end
	end)

	UserInputService.JumpRequest:Connect(function()
		if Library.Unloaded then
			return
		end
		if isOn("InfJump") then
			local humanoid = getHumanoid()
			if humanoid then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		if Library.Unloaded then
			return
		end
		if isOn("WalkSpeedEnabled") then
			local humanoid = getHumanoid()
			local walkSpeed = Options.WalkSpeed
			if humanoid and walkSpeed then
				humanoid.WalkSpeed = walkSpeed.Value
			end
		end
		if farmAssistActive and farmHoverCF then
			local root = getRoot()
			local humanoid = getHumanoid()
			if root and humanoid then
				humanoid.PlatformStand = true
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				root.CFrame = farmHoverCF
			end
		elseif isOn("Fly") then
			local root = getRoot()
			local humanoid = getHumanoid()
			local flySpeed = Options.FlySpeed
			local cam = Workspace.CurrentCamera
			if root and humanoid and flySpeed and cam then
				humanoid.PlatformStand = true
				local direction = Vector3.zero
				if UserInputService:IsKeyDown(Enum.KeyCode.W) then
					direction += cam.CFrame.LookVector
				end
				if UserInputService:IsKeyDown(Enum.KeyCode.S) then
					direction -= cam.CFrame.LookVector
				end
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then
					direction -= cam.CFrame.RightVector
				end
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then
					direction += cam.CFrame.RightVector
				end
				if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
					direction += Vector3.new(0, 1, 0)
				end
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
					direction -= Vector3.new(0, 1, 0)
				end
				root.AssemblyLinearVelocity = Vector3.zero
				if direction.Magnitude > 0 then
					root.CFrame += direction.Unit * flySpeed.Value * dt
				end
			end
		end
	end)

	Toggles.Fly:OnChanged(function()
		if not Toggles.Fly.Value and not farmAssistActive then
			local humanoid = getHumanoid()
			if humanoid then
				humanoid.PlatformStand = false
			end
		end
	end)

	Toggles.WalkSpeedEnabled:OnChanged(function()
		if not Toggles.WalkSpeedEnabled.Value then
			local humanoid = getHumanoid()
			if humanoid then
				humanoid.WalkSpeed = 16
			end
		end
	end)

	Toggles.AntiGameplayPause:OnChanged(function()
		applyAntiGameplayPause(Toggles.AntiGameplayPause.Value)
	end)

	task.spawn(function()
		while not Library.Unloaded do
			task.wait(1)
			if Toggles.AntiGameplayPause.Value then
				applyAntiGameplayPause(true)
			end
		end
	end)

	Toggles.InstantProximityPrompt:OnChanged(function()
		if Toggles.InstantProximityPrompt.Value then
			for _, prompt in ipairs(Workspace:GetDescendants()) do
				pcall(applyInstantPrompt, prompt)
			end
			instantPromptConnection = Workspace.DescendantAdded:Connect(function(descendant)
				if Toggles.InstantProximityPrompt.Value then
					pcall(applyInstantPrompt, descendant)
				end
			end)
		elseif instantPromptConnection then
			instantPromptConnection:Disconnect()
			instantPromptConnection = nil
		end
	end)

	Library:OnUnload(function()
		setFarmAssist(false)
		farmBusy = false
		applyAntiGameplayPause(false)
		if instantPromptConnection then
			instantPromptConnection:Disconnect()
		end
	end)
end

setupInfoTab()
setupPlayerTab()

LocalPlayer.CharacterAdded:Connect(function()
	setFarmAssist(false)
	farmBusy = false
	flushBusy = false
end)

task.spawn(function()
	while not Library.Unloaded do
		if isOn("AutoFlush") then
			pcall(doAutoFlush)
		end
		if isOn("AutoEat") and getFullness() < flushThreshold() then
			pcall(doAutoEat)
			task.wait(math.max(digCooldown() * 0.5, 0.05))
		else
			task.wait(0.2)
		end
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		if isOn("AutoFarmCake") then
			pcall(doAutoFarmCake)
			task.wait(0.2)
		else
			if farmAssistActive and not farmBusy then
				setFarmAssist(false)
			end
			task.wait(0.4)
		end
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		if isOn("AutoSell") then
			pcall(doAutoSell)
		end
		if isOn("AutoBuyUpgrades") then
			pcall(doAutoBuyUpgrades)
		end
		if isOn("AutoBuySpoon") then
			pcall(doAutoBuySpoon)
		end
		task.wait(0.9)
	end
end)

local function setupSettings()
	local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu")
	MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
		Default = "RightShift",
		NoUI = true,
		Text = "Menu keybind",
	})
	Library.ToggleKeybind = Options.MenuKeybind

	local antiAfkTriggerCount = 0
	local antiAfkLastPulse = tick()
	local antiAfkStat

	local function antiAfkTap()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0), camera.CFrame)
		antiAfkTriggerCount += 1
		antiAfkLastPulse = tick()
		if antiAfkStat then
			pcall(function()
				antiAfkStat:SetText("AFK triggers: " .. antiAfkTriggerCount)
			end)
		end
	end

	local antiAfkIdledConnection = LocalPlayer.Idled:Connect(function()
		if isOn("AntiAfk") then
			pcall(antiAfkTap)
		end
	end)

	MenuGroup:AddToggle("AntiAfk", {
		Text = "Anti-AFK",
		Default = true,
	})
	antiAfkStat = MenuGroup:AddLabel("AFK triggers: 0")
	MenuGroup:AddButton({
		Text = "Unload UI",
		Func = function()
			Library:Unload()
		end,
	})

	task.spawn(function()
		while not Library.Unloaded do
			task.wait(2)
			if isOn("AntiAfk") and tick() - antiAfkLastPulse >= 60 then
				pcall(antiAfkTap)
			end
		end
	end)

	Library:OnUnload(function()
		if antiAfkIdledConnection then
			antiAfkIdledConnection:Disconnect()
		end
		if getgenv then
			getgenv().__OuroborosCakeMountainLib = nil
		end
	end)

	ThemeManager:SetLibrary(Library)
	ThemeManager:SetFolder("OuroborosHub")
	ThemeManager:SaveDefault("Evil Hello Kitty")
	ThemeManager:ApplyToTab(Tabs.Settings)
	ThemeManager:LoadDefault()

	SaveManager:SetLibrary(Library)
	SaveManager:IgnoreThemeSettings()
	SaveManager:SetIgnoreIndexes({ "MenuKeybind", "SaveManager_ImportSource" })
	SaveManager:SetFolder("OuroborosHub/CakeMountain")

	local ConfigurationBox = SaveManager:BuildConfigSection(Tabs.Settings)

	local function configElement(objectType, index)
		local holder = objectType == "Toggle" and Toggles or Options
		local element = holder[index]
		return type(element) == "table" and element.Type == objectType and element or nil
	end

	local function encodeConfigObject(index, element)
		local elementType = element.Type
		if elementType == "Toggle" then
			return { idx = index, type = "Toggle", value = element.Value == true }
		elseif elementType == "Slider" then
			return { idx = index, type = "Slider", value = tostring(element.Value) }
		elseif elementType == "Dropdown" then
			return { idx = index, type = "Dropdown", multi = element.Multi == true, value = element.Value }
		elseif elementType == "Input" then
			return { idx = index, type = "Input", text = tostring(element.Value or "") }
		elseif elementType == "ColorPicker" then
			return {
				idx = index,
				type = "ColorPicker",
				value = element.Value:ToHex(),
				transparency = element.Transparency,
			}
		elseif elementType == "KeyPicker" then
			return {
				idx = index,
				type = "KeyPicker",
				mode = element.Mode,
				key = element.Value,
				modifiers = element.Modifiers,
				toggled = element.Toggled,
			}
		end
		return nil
	end

	local function buildConfigPayload()
		local objects = {}
		for _, holder in ipairs({ Toggles, Options }) do
			for index, element in pairs(holder) do
				if type(element) == "table" and type(element.Type) == "string" and not SaveManager.Ignore[index] then
					local encoded = encodeConfigObject(index, element)
					if encoded then
						objects[#objects + 1] = encoded
					end
				end
			end
		end
		table.sort(objects, function(a, b)
			if a.type ~= b.type then
				return a.type < b.type
			end
			return a.idx < b.idx
		end)
		return { objects = objects }
	end

	local function applyConfigObject(object)
		if type(object) ~= "table"
			or type(object.idx) ~= "string"
			or type(object.type) ~= "string"
			or SaveManager.Ignore[object.idx]
		then
			return false
		end
		local element = configElement(object.type, object.idx)
		if not element then
			return false
		end
		local applied = pcall(function()
			if object.type == "Input" then
				if type(object.text) ~= "string" then
					return
				end
				element:SetValue(object.text)
			elseif object.type == "ColorPicker" then
				element:SetValueRGB(Color3.fromHex(object.value), object.transparency)
			elseif object.type == "KeyPicker" then
				element:SetValue({ object.key, object.mode, object.modifiers })
				if object.mode == "Toggle" and object.toggled ~= nil then
					element.Toggled = object.toggled
					element:Update()
				end
			else
				element:SetValue(object.value)
			end
		end)
		return applied
	end

	ConfigurationBox:AddDivider()
	ConfigurationBox:AddInput("SaveManager_ImportSource", {
		Text = "Paste exported config here",
		Finished = true,
		AllowEmpty = true,
	})
	ConfigurationBox:AddButton({
		Text = "Export Config to Clipboard",
		Func = function()
			local encodeSuccess, encoded = pcall(HttpService.JSONEncode, HttpService, buildConfigPayload())
			if not encodeSuccess then
				Library:Notify("Failed to encode the config")
				return
			end
			local writeClipboard = setclipboard or toclipboard
			if type(writeClipboard) ~= "function" or not pcall(writeClipboard, encoded) then
				Library:Notify("Your executor does not support copying to the clipboard")
				return
			end
			Library:Notify("Config copied to clipboard", 6)
		end,
	})
	ConfigurationBox:AddButton({
		Text = "Import Config from Clipboard Text",
		Func = function()
			local source = tostring(Options.SaveManager_ImportSource.Value or ""):match("^%s*(.-)%s*$")
			if source == "" then
				Library:Notify("Paste an exported config into the box first")
				return
			end
			local decodeSuccess, decoded = pcall(HttpService.JSONDecode, HttpService, source)
			if not decodeSuccess or type(decoded) ~= "table" or type(decoded.objects) ~= "table" then
				Library:Notify("That is not a valid exported config")
				return
			end
			local applied = 0
			for _, object in ipairs(decoded.objects) do
				if applyConfigObject(object) then
					applied += 1
				end
			end
			if applied == 0 then
				Library:Notify("No settings in that config matched this script")
				return
			end
			Options.SaveManager_ImportSource:SetValue("")
			refreshSellKgVisibility()
			Library:Notify(("Imported %d setting%s"):format(applied, applied == 1 and "" or "s"), 6)
		end,
	})

	SaveManager:LoadAutoloadConfig()
	task.defer(refreshSellKgVisibility)
end

setupSettings()
