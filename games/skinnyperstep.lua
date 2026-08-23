local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local GAME_NAME = "+1 Skinny Per Step"
local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"
local RSCRIPTS_LINK = "https://rscripts.net/@Ouroboros"

local LTC_ADDRESS = "LSZPqKSsD1x6QXea2H8JS17nXMLnmtew3w"
local BTC_ADDRESS = "bc1qwc9exvcn3ykjqnsa0t9gakuccr494ljjuuqj99"
local ETH_ADDRESS = "0xaE95A405D007a6F858E5d35714111B075fEFb40a"
local USDT_ADDRESS = "0xaE95A405D007a6F858E5d35714111B075fEFb40a"
local SOL_ADDRESS = "Hq5jPHKDKjyHhccc6UULcbYTK6aKBBbTDmHNRXGKBKGp"
local PAYPAL_LINK = "https://paypal.me/TheTruckerGOD"
local VENMO_LINK = "https://venmo.com/u/miserablemusic"

local LTC = "#345d9d"
local BTC = "#f7931a"
local ETH = "#627eea"
local USDT = "#26a17b"
local SOL = "#14f195"
local PAYPAL = "#0070ba"
local VENMO = "#008cff"

local GREEN = "#7fd47f"
local BLUE = "#6ec1ff"
local ORANGE = "#e8a34d"
local GREY = "#8b93a3"

local AutoWinsRoute = ReplicatedStorage:WaitForChild("AutoWinsRoute")
local Resources = ReplicatedStorage:WaitForChild("Resources")
local EggsFolder = Resources:WaitForChild("Eggs")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BuyEgg = Remotes:WaitForChild("Eggs"):WaitForChild("BuyEgg")
local EquipBestPets = Remotes:WaitForChild("Pets"):WaitForChild("EquipBest")

local RebirthRequest = ReplicatedStorage:WaitForChild("RebirthRequest")
local TrailEquipRequest = ReplicatedStorage:WaitForChild("TrailEquipRequest")
local TeleportRequest = ReplicatedStorage:WaitForChild("TeleportRequest")

local WORLD_REBIRTHS = {
	[1] = 0,
	[2] = 16,
	[3] = 33,
}

local TRAIL_ORDER = {
	{ Name = "WhiteTrail", Cost = 5, Speed = 17 },
	{ Name = "RedTrail", Cost = 100, Speed = 22 },
	{ Name = "BlueTrail", Cost = 1000, Speed = 25 },
	{ Name = "YellowTrail", Cost = 50000, Speed = 28 },
	{ Name = "GreenTrail", Cost = 500000, Speed = 31 },
	{ Name = "PurpleTrail", Cost = 1000000, Speed = 35 },
	{ Name = "RainbowTrail", Cost = 10000000, Speed = 40 },
	{ Name = "AuroraTrail", Cost = 50000000, Speed = 45 },
	{ Name = "LavaTrail", Cost = 100000000, Speed = 50 },
	{ Name = "BeachTrail", Cost = 1000000000, Speed = 54 },
	{ Name = "ObsidianTrail", Cost = 1e12, Speed = 59 },
	{ Name = "DiamondTrail", Cost = 1e15, Speed = 65 },
}

local repo = "https://raw.githubusercontent.com/joustingmatch/ObsidianUltra/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

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
	local toggle = Toggles[name]
	return toggle ~= nil and toggle.Value == true
end

local function getCharacter()
	return LocalPlayer.Character
end

local function getHumanoid()
	local character = getCharacter()
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
	local character = getCharacter()
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function attr(name, default)
	local value = LocalPlayer:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

local function getLevel()
	return tonumber(attr("Level", 1)) or 1
end

local function getWins()
	return tonumber(attr("Wins", 0)) or 0
end

local function getRebirths()
	return tonumber(attr("Rebirths", 0)) or 0
end

local function getCurrentWorld()
	return tonumber(attr("CurrentWorld", 1)) or 1
end

local function requiredRebirthLevel(rebirths)
	return (rebirths + 1) * 25
end

local function csvOwns(csv, name)
	return ("," .. tostring(csv or "") .. ","):find("," .. name .. ",", 1, true) ~= nil
end

local function ownsFruit(name)
	return csvOwns(attr("OwnedFruits", ""), name)
end

local function ownsTrail(name)
	return csvOwns(attr("OwnedTrails", ""), name)
end

local function worldFolder(world)
	return AutoWinsRoute:FindFirstChild("W" .. tostring(world)) or AutoWinsRoute:FindFirstChild("W1")
end

local function buildWinPlateValues()
	local values = { "Best" }
	for world = 1, 3 do
		local folder = worldFolder(world)
		if folder then
			local levels = {}
			for _, child in folder:GetChildren() do
				local level = tonumber(child.Name)
				if level and child:IsA("Vector3Value") then
					levels[#levels + 1] = level
				end
			end
			table.sort(levels)
			for _, level in levels do
				values[#values + 1] = string.format("W%d | Lv %d", world, level)
			end
		end
	end
	return values
end

local function parseWinPlate(label)
	if not label or label == "Best" then
		return nil
	end
	local world, level = string.match(label, "^W(%d+) | Lv (%d+)$")
	if not world then
		return nil
	end
	return tonumber(world), tonumber(level)
end

local function bestUnlockedPad(world)
	local folder = worldFolder(world)
	if not folder then
		return nil
	end
	local level = getLevel()
	local bestLevel = -1
	local bestPos = nil
	for _, child in folder:GetChildren() do
		local padLevel = tonumber(child.Name)
		if padLevel and child:IsA("Vector3Value") and padLevel <= level and padLevel > bestLevel then
			bestLevel = padLevel
			bestPos = child.Value
		end
	end
	if not bestPos then
		return nil
	end
	return bestLevel, bestPos
end

local function resolveWinTarget()
	local selected = Options.WinPlate and Options.WinPlate.Value or "Best"
	local world, level = parseWinPlate(selected)
	if not world then
		world = getCurrentWorld()
		local bestLevel, bestPos = bestUnlockedPad(world)
		if not bestLevel then
			return nil
		end
		return world, bestLevel, bestPos
	end
	local playerLevel = getLevel()
	if level > playerLevel then
		local bestLevel, bestPos = bestUnlockedPad(world)
		if not bestLevel then
			return nil
		end
		return world, bestLevel, bestPos
	end
	local folder = worldFolder(world)
	local pad = folder and folder:FindFirstChild(tostring(level))
	if pad and pad:IsA("Vector3Value") then
		return world, level, pad.Value
	end
	return nil
end

local worldTeleportAt = 0

local function ensureWorld(world)
	if getCurrentWorld() == world then
		return true
	end
	local need = WORLD_REBIRTHS[world] or 0
	if getRebirths() < need then
		return false
	end
	if os.clock() - worldTeleportAt < 2 then
		return false
	end
	worldTeleportAt = os.clock()
	pcall(function()
		TeleportRequest:FireServer(world)
	end)
	return false
end

local function findWinTouch(world, level)
	local name
	if world == 1 then
		name = "WinZoneLevel" .. level .. "Model"
	else
		name = "WinZoneLevel" .. level .. "ModelW" .. world
	end
	local zone = Workspace:FindFirstChild(name)
	if not zone then
		return nil
	end
	return zone:FindFirstChild("TouchWin", true)
end

local playerControls = nil
pcall(function()
	playerControls = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
end)

local controlsEnabled = true

local function setAutoWinControls(enabled)
	if not playerControls or controlsEnabled == enabled then
		return
	end
	controlsEnabled = enabled
	pcall(function()
		if enabled then
			playerControls:Enable()
		else
			playerControls:Disable()
		end
	end)
end

local function laneZ(world)
	local folder = worldFolder(world)
	return tonumber(folder and folder:GetAttribute("LaneZ")) or 0
end

local function spawnPos(world)
	local folder = worldFolder(world)
	local pos = folder and folder:GetAttribute("SpawnPos")
	if typeof(pos) == "Vector3" then
		return pos
	end
	return Vector3.new(-33.763, 0.923, laneZ(world))
end

local function resetToLaneSpawn(world)
	local root = getRoot()
	if not root then
		return
	end
	local spawn = spawnPos(world)
	root.CFrame = CFrame.new(spawn + Vector3.new(0, 3, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local lastPadTouchAt = 0

local function retriggerWinTouch(touch)
	local root = getRoot()
	if not root or not touch or not touch:IsA("BasePart") then
		return
	end
	if not firetouchinterest then
		return
	end
	if os.clock() - lastPadTouchAt < 0.2 then
		return
	end
	lastPadTouchAt = os.clock()
	pcall(firetouchinterest, root, touch, 0)
	pcall(firetouchinterest, root, touch, 1)
end

local function walkToward(position, speed, world)
	local root = getRoot()
	local humanoid = getHumanoid()
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end

	humanoid.Sit = false
	humanoid.PlatformStand = false

	local lane = laneZ(world)
	local positionXZ = root.Position
	if math.abs(positionXZ.Z - lane) >= 24 then
		resetToLaneSpawn(world)
		return false
	end

	local deltaX = position.X - positionXZ.X
	local deltaLane = lane - positionXZ.Z
	local goal
	if math.abs(deltaX) <= 15 then
		goal = Vector3.new(position.X, positionXZ.Y, position.Z)
	elseif math.abs(deltaLane) > 2.5 then
		goal = Vector3.new(positionXZ.X, positionXZ.Y, lane)
	else
		goal = Vector3.new(position.X, positionXZ.Y, lane)
	end

	local flat = (goal - positionXZ) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.5 then
		humanoid.WalkSpeed = math.min(speed, 16)
		humanoid:Move(Vector3.zero, false)
		return math.abs(deltaX) <= 5
	end

	if math.abs(deltaX) < 24 then
		humanoid.WalkSpeed = math.min(speed, 16)
	else
		humanoid.WalkSpeed = speed
	end

	humanoid:Move(flat.Unit, false)
	return false
end

local function autoWinStep()
	local world, level, position = resolveWinTarget()
	if not world or not position then
		return
	end
	if getCurrentWorld() ~= world then
		ensureWorld(world)
		return
	end

	setAutoWinControls(false)

	local speed = Options.AutoWinWalkSpeed and Options.AutoWinWalkSpeed.Value or 60
	local touch = findWinTouch(world, level)
	local target = touch and touch.Position or position
	local arrived = walkToward(target, speed, world)

	local root = getRoot()
	if touch and root then
		local near = (Vector3.new(touch.Position.X - root.Position.X, 0, touch.Position.Z - root.Position.Z)).Magnitude
		if arrived or near <= 12 then
			retriggerWinTouch(touch)
		end
	end
end

local function getTreadmills()
	local list = {}
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") and child.Name:find("Treadmill") and child.Name ~= "TreadmillsGUI" then
			local required = tonumber(child:GetAttribute("RequiredRebirths")) or 0
			local mult = tonumber(child:GetAttribute("Multiplier")) or 0
			local conveyor = child:FindFirstChild("Conveyor", true)
			if conveyor and conveyor:IsA("BasePart") then
				list[#list + 1] = {
					Model = child,
					Required = required,
					Multiplier = mult,
					Conveyor = conveyor,
				}
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Multiplier > b.Multiplier
	end)
	return list
end

local function treadmillUnlocked(entry)
	local name = entry.Model.Name
	if name == "HackerTreadmill" then
		return attr("HasHacker", false) == true
	end
	if name == "GalaxyTreadmill" then
		return attr("HasGalaxy", false) == true
	end
	if name == "LavaTreadmill" then
		return attr("HasLava", false) == true
	end
	if name == "W1GoldenCrownTreadmill"
		or name == "W2GoldenCrownTreadmill"
		or name == "W3GoldenCrownTreadmill"
	then
		return attr("HasVIP", false) == true
	end
	return getRebirths() >= entry.Required
end

local function bestTreadmill()
	for _, entry in getTreadmills() do
		if treadmillUnlocked(entry) then
			return entry
		end
	end
	return nil
end

local function teleportToPart(part)
	local root = getRoot()
	if not root or not part then
		return
	end
	root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
end

local function getBuyPrompt(model)
	local prompt = model:FindFirstChild("BuyPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		return prompt
	end
	return nil
end

local function fireBuyPrompt(model)
	local prompt = getBuyPrompt(model)
	if not prompt then
		return false
	end
	local part = prompt.Parent
	if part and part:IsA("BasePart") then
		teleportToPart(part)
		task.wait(0.1)
	end
	if fireproximityprompt then
		pcall(fireproximityprompt, prompt)
		return true
	end
	pcall(function()
		prompt:InputHoldBegin()
		task.wait(0.05)
		prompt:InputHoldEnd()
	end)
	return true
end

local function getFoods()
	local list = {}
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("RequiredWins") ~= nil then
			local req = tonumber(child:GetAttribute("RequiredWins"))
			local boost = tonumber(child:GetAttribute("ThinBoost")) or 0
			if req and req == req and req ~= math.huge then
				list[#list + 1] = {
					Model = child,
					Name = child.Name,
					Required = req,
					Boost = boost,
				}
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Boost > b.Boost
	end)
	return list
end

local function foodAction(model)
	local prompt = getBuyPrompt(model)
	return prompt and prompt.ActionText or nil
end

local function foodUnlocked(food, wins)
	return ownsFruit(food.Name) or wins >= food.Required
end

local lastFoodActionAt = 0

local function autoBuyFoodsOnce()
	local wins = getWins()
	local equipped = tostring(attr("EquippedItem", "") or "")
	local bestBuy = nil
	local bestOwned = nil

	for _, food in getFoods() do
		local action = foodAction(food.Model)
		if action == "Buy" and wins >= food.Required then
			if not bestBuy then
				bestBuy = food
			end
		elseif foodUnlocked(food, wins) then
			if not bestOwned then
				bestOwned = food
			end
		end
	end

	if os.clock() - lastFoodActionAt < 1.5 then
		return
	end

	if bestBuy then
		lastFoodActionAt = os.clock()
		fireBuyPrompt(bestBuy.Model)
		return
	end

	if bestOwned and equipped ~= bestOwned.Name then
		lastFoodActionAt = os.clock()
		fireBuyPrompt(bestOwned.Model)
	end
end

local function buildEggValues()
	local values = {}
	local entries = {}
	for _, egg in EggsFolder:GetChildren() do
		local cost = egg:FindFirstChild("Cost")
		local amount = cost and tonumber(cost.Value) or 0
		if amount > 0 then
			entries[#entries + 1] = { Name = egg.Name, Cost = amount }
		end
	end
	table.sort(entries, function(a, b)
		return a.Cost < b.Cost
	end)
	for _, entry in entries do
		values[#values + 1] = entry.Name
	end
	return values
end

local function eggCost(name)
	local egg = EggsFolder:FindFirstChild(name)
	local cost = egg and egg:FindFirstChild("Cost")
	return cost and tonumber(cost.Value) or 0
end

local function autoTrainOnce()
	local entry = bestTreadmill()
	if not entry then
		return
	end
	if attr("OnTreadmill", false) == true then
		local root = getRoot()
		if root and (root.Position - entry.Conveyor.Position).Magnitude > 14 then
			teleportToPart(entry.Conveyor)
		end
		return
	end
	teleportToPart(entry.Conveyor)
end

local function autoRebirthOnce()
	local rebirths = getRebirths()
	local need = requiredRebirthLevel(rebirths)
	if getLevel() < need then
		return
	end
	pcall(function()
		RebirthRequest:FireServer()
	end)
end

local function autoBuyTrailsOnce()
	local wins = getWins()
	local bestOwned = nil
	local bestSpeed = -1
	for _, trail in TRAIL_ORDER do
		if ownsTrail(trail.Name) then
			if trail.Speed > bestSpeed then
				bestSpeed = trail.Speed
				bestOwned = trail.Name
			end
		elseif wins >= trail.Cost then
			pcall(function()
				TrailEquipRequest:FireServer(trail.Name)
			end)
			task.wait(0.15)
			if ownsTrail(trail.Name) and trail.Speed > bestSpeed then
				bestSpeed = trail.Speed
				bestOwned = trail.Name
			end
		end
	end
	local equipped = tostring(attr("EquippedTrail", "") or "")
	if bestOwned and equipped ~= bestOwned then
		pcall(function()
			TrailEquipRequest:FireServer(bestOwned)
		end)
	end
end

local function autoHatchOnce()
	local eggName = Options.HatchEgg and Options.HatchEgg.Value
	if type(eggName) ~= "string" or eggName == "" then
		return
	end
	local egg = EggsFolder:FindFirstChild(eggName)
	if not egg then
		return
	end
	local cost = eggCost(eggName)
	if getWins() < cost then
		return
	end
	local ok, result = pcall(function()
		return BuyEgg:InvokeServer(egg)
	end)
	if ok and result then
		if isOn("AutoEquipBestPets") then
			pcall(function()
				EquipBestPets:FireServer()
			end)
		end
	end
end

local WIN_PLATE_VALUES = buildWinPlateValues()
local EGG_VALUES = buildEggValues()
if #EGG_VALUES == 0 then
	EGG_VALUES = { "Common" }
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
})

local Tabs = {
	Info = Window:AddTab("Info", "info"),
	Main = Window:AddTab("Main", "gauge"),
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

for _, Tab in Tabs do
	if Tab ~= Tabs.Info then
		AddDiscordButton(Tab)
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

local AccountGroup = Tabs.Info:AddLeftGroupbox("Account", "circle-user")
AccountGroup:AddLabel(field("User", LocalPlayer.Name, GREEN), true)
AccountGroup:AddLabel(field("Status", "Keyless", GREEN), true)
AccountGroup:AddLabel(field("Executor", executorName, GREEN), true)

local GameGroup = Tabs.Info:AddLeftGroupbox("Game Info", "gamepad-2")
GameGroup:AddLabel(colored(GAME_NAME .. " [" .. tostring(game.PlaceId) .. "]", BLUE), true)
GameGroup:AddLabel(field("Place ID", tostring(game.PlaceId), BLUE), true)

local SessionLabel = GameGroup:AddLabel(field("Session time", "0s", ORANGE), true)
local jobId = tostring(game.JobId)
local shortJobId = #jobId > 18 and (string.sub(jobId, 1, 18) .. "...") or jobId
GameGroup:AddLabel(field("Server", shortJobId, GREY), true)

GameGroup:AddButton({
	Text = "Copy join script (Job ID)",
	Func = function()
		local joinScript = string.format(
			'game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s", game:GetService("Players").LocalPlayer)',
			game.PlaceId,
			jobId
		)
		copyText(joinScript, "Copied join script to clipboard")
	end,
})

local sessionStart = os.clock()
task.spawn(function()
	while true do
		task.wait(1)
		if Library.Unloaded then
			break
		end
		local elapsed = math.floor(os.clock() - sessionStart)
		local text
		if elapsed < 60 then
			text = elapsed .. "s"
		elseif elapsed < 3600 then
			text = string.format("%dm %ds", elapsed // 60, elapsed % 60)
		else
			text = string.format("%dh %dm", elapsed // 3600, (elapsed % 3600) // 60)
		end
		SessionLabel:SetText(field("Session time", text, ORANGE))
	end
end)

local ScriptsGroup = Tabs.Info:AddRightGroupbox("Scripts", "package")
ScriptsGroup:AddLabel(colored("Included in this hub", GREY), true)
ScriptsGroup:AddLabel(colored(GAME_NAME, BLUE), true)

local FeaturesGroup = Tabs.Info:AddRightGroupbox("Features", "list")
FeaturesGroup:AddLabel(colored("Auto Win", ORANGE), true)
FeaturesGroup:AddLabel(colored("Auto Train", BLUE), true)
FeaturesGroup:AddLabel(colored("Auto Shop", GREEN), true)
FeaturesGroup:AddLabel(colored("Auto Hatch", BLUE), true)
FeaturesGroup:AddLabel(colored("Player Utilities", GREY), true)

local SocialsGroup = Tabs.Info:AddRightGroupbox("Socials", "link")
SocialsGroup:AddButton({
	Text = "Discord",
	Func = copyDiscord,
})
SocialsGroup:AddButton({
	Text = "Rscripts",
	Func = function()
		copyText(RSCRIPTS_LINK, "Copied Rscripts profile to clipboard")
	end,
})

local AdGroup = Tabs.Info:AddLeftGroupbox("Ouroboros Hub", "sparkles")
AdGroup:AddLabel("Every script in the hub is keyless. No key systems, no checkpoints, no linkvertise.", true)
AdGroup:AddLabel("The Discord has ready made configs, dupe methods, giveaways, and early access to new scripts.", true)
AdGroup:AddLabel("Requests get taken seriously. A lot of what is in this script started as a Discord message.", true)
AdGroup:AddButton({
	Text = "Copy Discord Invite",
	Func = copyDiscord,
})

local DonationsGroup = Tabs.Info:AddRightGroupbox("Donations", "heart")
DonationsGroup:AddLabel(colored("All donations are optional but appreciated.", ORANGE), true)
DonationsGroup:AddLabel(colored("If you donate you get a special role, just PING after you donate.", GREEN), true)
DonationsGroup:AddDivider()
DonationsGroup:AddLabel(colored("LTC / Litecoin", LTC), true)
DonationsGroup:AddButton({
	Text = "Copy Litecoin Address",
	Func = function()
		copyText(LTC_ADDRESS, "Copied Litecoin address")
	end,
})
DonationsGroup:AddLabel(colored("BTC / Bitcoin", BTC), true)
DonationsGroup:AddButton({
	Text = "Copy Bitcoin Address",
	Func = function()
		copyText(BTC_ADDRESS, "Copied Bitcoin address")
	end,
})
DonationsGroup:AddLabel(colored("ETH / Ethereum", ETH), true)
DonationsGroup:AddButton({
	Text = "Copy Ethereum Address",
	Func = function()
		copyText(ETH_ADDRESS, "Copied Ethereum address")
	end,
})
DonationsGroup:AddLabel(colored("USDT", USDT), true)
DonationsGroup:AddButton({
	Text = "Copy USDT Address",
	Func = function()
		copyText(USDT_ADDRESS, "Copied USDT address")
	end,
})
DonationsGroup:AddLabel(colored("Solana", SOL), true)
DonationsGroup:AddButton({
	Text = "Copy Solana Address",
	Func = function()
		copyText(SOL_ADDRESS, "Copied Solana address")
	end,
})
DonationsGroup:AddLabel(colored("PayPal", PAYPAL), true)
DonationsGroup:AddButton({
	Text = "Copy PayPal Link",
	Func = function()
		copyText(PAYPAL_LINK, "Copied PayPal link")
	end,
})
DonationsGroup:AddLabel(colored("Venmo", VENMO), true)
DonationsGroup:AddButton({
	Text = "Copy Venmo Link",
	Func = function()
		copyText(VENMO_LINK, "Copied Venmo link")
	end,
})
DonationsGroup:AddDivider()
DonationsGroup:AddLabel(colored("Don't have any of the listed currencies but still wanna donate?", GREY), true)
DonationsGroup:AddLabel(colored("DM me and we'll work something out.", BLUE), true)

local FaqGroup = Tabs.Info:AddRightGroupbox("FAQ", "circle-help")
FaqGroup:AddLabel("Where do I get a good config?", true)
FaqGroup:AddLabel("Join the Discord, the config channel has configs shared for every script.", true)
FaqGroup:AddLabel("How do I import / export configs?", true)
FaqGroup:AddLabel("Join the Discord, the guide is pinned and people share config links daily.", true)
FaqGroup:AddLabel("How do I report bugs?", true)
FaqGroup:AddLabel("Join the Discord and post it in the bugs channel.", true)
FaqGroup:AddLabel("How do I make suggestions?", true)
FaqGroup:AddLabel("Join the Discord and drop it in suggestions, most of them get added.", true)
FaqGroup:AddLabel("How do I get help or updates?", true)
FaqGroup:AddLabel("Join the Discord, updates and support are posted there first.", true)

local FarmGroup = Tabs.Main:AddLeftGroupbox("Farm", "bot")
FarmGroup:AddToggle("AutoWin", {
	Text = "Auto Win",
	Default = false,
})
FarmGroup:AddDropdown("WinPlate", {
	Text = "Win Plate",
	Values = WIN_PLATE_VALUES,
	Default = "Best",
	Expandable = true,
	ExpandColumns = 2,
})
FarmGroup:AddSlider("AutoWinWalkSpeed", {
	Text = "Auto Win WalkSpeed",
	Default = 60,
	Min = 16,
	Max = 250,
	Rounding = 0,
})
FarmGroup:AddToggle("AutoTrain", {
	Text = "Auto Train",
	Default = false,
})
FarmGroup:AddToggle("AutoRebirth", {
	Text = "Auto Rebirth",
	Default = false,
})

local ShopGroup = Tabs.Main:AddRightGroupbox("Shop", "shopping-bag")
ShopGroup:AddToggle("AutoBuyTrail", {
	Text = "Auto Buy Trail",
	Default = false,
})
ShopGroup:AddToggle("AutoBuyFoods", {
	Text = "Auto Buy Foods",
	Default = false,
})

local HatchGroup = Tabs.Main:AddRightGroupbox("Pets", "paw-print")
HatchGroup:AddToggle("AutoHatch", {
	Text = "Auto Hatch Pets",
	Default = false,
})
HatchGroup:AddDropdown("HatchEgg", {
	Text = "Egg",
	Values = EGG_VALUES,
	Default = EGG_VALUES[1],
})
HatchGroup:AddSlider("HatchDelay", {
	Text = "Hatch Delay",
	Default = 0.35,
	Min = 0.1,
	Max = 3,
	Rounding = 2,
})
HatchGroup:AddToggle("AutoEquipBestPets", {
	Text = "Auto Equip Best Pets",
	Default = true,
})

local MovementGroup = Tabs.Player:AddLeftGroupbox("Movement", "footprints")
MovementGroup:AddToggle("WalkSpeedEnabled", {
	Text = "WalkSpeed",
	Default = false,
})
MovementGroup:AddSlider("WalkSpeed", {
	Text = "WalkSpeed Amount",
	Default = 32,
	Min = 16,
	Max = 250,
	Rounding = 0,
})
MovementGroup:AddToggle("InfJump", {
	Text = "Infinite Jump",
	Default = false,
})
MovementGroup:AddToggle("NoClip", {
	Text = "NoClip",
	Default = false,
})
MovementGroup:AddToggle("AntiGameplayPause", {
	Text = "No Gameplay Paused",
	Default = true,
})

local FlyGroup = Tabs.Player:AddRightGroupbox("Fly", "feather")
FlyGroup:AddToggle("Fly", {
	Text = "Fly",
	Default = false,
})
FlyGroup:AddSlider("FlySpeed", {
	Text = "Fly Speed",
	Default = 60,
	Min = 10,
	Max = 400,
	Rounding = 0,
})

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu")
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
	Default = "RightShift",
	NoUI = true,
	Text = "Menu keybind",
})
Library.ToggleKeybind = Options.MenuKeybind

MenuGroup:AddToggle("AntiAfk", {
	Text = "Anti-AFK",
	Default = true,
})

MenuGroup:AddButton({
	Text = "Unload",
	Func = function()
		Library:Unload()
	end,
})

local antiAfkLastInput = tick()
local antiAfkLastTap = tick()

pcall(function()
	for _, connection in ipairs(getconnections(LocalPlayer.Idled)) do
		pcall(function()
			connection:Disable()
		end)
	end
end)

local function antiAfkTap()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	VirtualUser:Button2Down(Vector2.new(0, 0), camera.CFrame)
	task.wait(0.1)
	VirtualUser:Button2Up(Vector2.new(0, 0), camera.CFrame)
	antiAfkLastTap = tick()
end

local antiAfkBeganConnection = UserInputService.InputBegan:Connect(function()
	antiAfkLastInput = tick()
end)

local antiAfkChangedConnection = UserInputService.InputChanged:Connect(function(input)
	local inputType = input.UserInputType
	if inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Gamepad1 then
		antiAfkLastInput = tick()
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		task.wait(2)
		if Toggles.AntiAfk.Value then
			local idle = tick() - antiAfkLastInput
			local sinceTap = tick() - antiAfkLastTap
			if idle >= 300 and sinceTap >= 60 then
				pcall(antiAfkTap)
			elseif idle < 300 and sinceTap >= 300 then
				pcall(antiAfkTap)
			end
		end
	end
end)

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

RunService.Stepped:Connect(function()
	if Library.Unloaded then
		return
	end
	if Toggles.NoClip and Toggles.NoClip.Value then
		local character = LocalPlayer.Character
		if character then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end
	end
end)

UserInputService.JumpRequest:Connect(function()
	if Library.Unloaded then
		return
	end
	if Toggles.InfJump and Toggles.InfJump.Value then
		local humanoid = getHumanoid()
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end)

local Camera = Workspace.CurrentCamera

RunService.RenderStepped:Connect(function(dt)
	if Library.Unloaded then
		return
	end

	if Toggles.WalkSpeedEnabled and Toggles.WalkSpeedEnabled.Value and not isOn("AutoWin") then
		local humanoid = getHumanoid()
		if humanoid then
			humanoid.WalkSpeed = Options.WalkSpeed.Value
		end
	end

	if Toggles.Fly and Toggles.Fly.Value then
		local root = getRoot()
		local humanoid = getHumanoid()
		if root and humanoid then
			humanoid.PlatformStand = true
			local direction = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				direction = direction + Camera.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				direction = direction - Camera.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				direction = direction - Camera.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				direction = direction + Camera.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				direction = direction + Vector3.new(0, 1, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				direction = direction - Vector3.new(0, 1, 0)
			end
			root.AssemblyLinearVelocity = Vector3.zero
			if direction.Magnitude > 0 then
				root.CFrame = root.CFrame + direction.Unit * Options.FlySpeed.Value * dt
			end
		end
	end
end)

Toggles.Fly:OnChanged(function()
	if not Toggles.Fly.Value then
		local humanoid = getHumanoid()
		if humanoid then
			humanoid.PlatformStand = false
		end
	end
end)

Toggles.WalkSpeedEnabled:OnChanged(function()
	if not Toggles.WalkSpeedEnabled.Value and not isOn("AutoWin") then
		local humanoid = getHumanoid()
		if humanoid then
			humanoid.WalkSpeed = 16
		end
	end
end)

Toggles.AutoWin:OnChanged(function()
	if not Toggles.AutoWin.Value then
		setAutoWinControls(true)
		local humanoid = getHumanoid()
		if humanoid then
			humanoid:Move(Vector3.zero, false)
			if not (Toggles.WalkSpeedEnabled and Toggles.WalkSpeedEnabled.Value) then
				humanoid.WalkSpeed = 16
			end
		end
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		RunService.Heartbeat:Wait()
		if isOn("AutoWin") then
			pcall(autoWinStep)
		end
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		task.wait(0.35)
		if isOn("AutoTrain") then
			pcall(autoTrainOnce)
		end
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		task.wait(1)
		if isOn("AutoRebirth") then
			pcall(autoRebirthOnce)
		end
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		task.wait(1)
		if isOn("AutoBuyTrail") then
			pcall(autoBuyTrailsOnce)
		end
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		task.wait(1.25)
		if isOn("AutoBuyFoods") then
			pcall(autoBuyFoodsOnce)
		end
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		local delayTime = Options.HatchDelay and Options.HatchDelay.Value or 0.35
		task.wait(delayTime)
		if isOn("AutoHatch") then
			pcall(autoHatchOnce)
		end
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
SaveManager:SetFolder("OuroborosHub/SkinnyPerStep")
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
			if type(element) == "table"
				and type(element.Type) == "string"
				and not SaveManager.Ignore[index]
			then
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

ConfigurationBox:AddButton("Export Config to Clipboard", function()
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
end)

ConfigurationBox:AddButton("Import Config from Clipboard Text", function()
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
	Library:Notify(("Imported %d setting%s"):format(applied, applied == 1 and "" or "s"), 6)
end)

SaveManager:LoadAutoloadConfig()

Library:OnUnload(function()
	antiAfkBeganConnection:Disconnect()
	antiAfkChangedConnection:Disconnect()
	applyAntiGameplayPause(false)
	setAutoWinControls(true)
	local humanoid = getHumanoid()
	if humanoid then
		humanoid:Move(Vector3.zero, false)
		humanoid.PlatformStand = false
		humanoid.WalkSpeed = 16
	end
	print("Unloaded!")
end)
