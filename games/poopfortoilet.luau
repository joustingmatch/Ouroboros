local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local function hubGetHui()
	return CoreGui
end

if getgenv then
	getgenv().gethui = hubGetHui
	local previous = getgenv().__OuroborosPoopPerClickLib
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

local function cref(instance)
	if cloneref and typeof(instance) == "Instance" then
		return cloneref(instance)
	end
	return instance
end

local GAME_NAME = "+1 Poop Per Click"
local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"
local RSCRIPTS_LINK = "https://rscripts.net/@Ouroboros"
local WEBSITE_LINK = "https://ouroboros-hub-rbx.web.app/"

local GameShared = ReplicatedStorage:WaitForChild("GameShared")
local Remotes = GameShared:WaitForChild("Remotes")
local GameConfig = require(GameShared:WaitForChild("Config"):WaitForChild("GameConfig"))

local RequestClick = cref(Remotes:WaitForChild("RequestClick"))
local RequestRebirth = cref(Remotes:WaitForChild("RequestRebirth"))
local RequestUpgrade = cref(Remotes:WaitForChild("RequestUpgrade"))
local RequestAuraRoll = cref(Remotes:WaitForChild("RequestAuraRoll"))
local BattleEvent = cref(Remotes:WaitForChild("BattleEvent"))
local StateChanged = cref(Remotes:WaitForChild("StateChanged"))

local MANUAL_CLICKS_PER_SECOND = tonumber(GameConfig.MANUAL_CLICKS_PER_SECOND) or 14
local CLICK_INTERVAL = 1 / math.max(1, MANUAL_CLICKS_PER_SECOND)
local WIN_PAD_COOLDOWN = tonumber(GameConfig.WIN_PAD_COOLDOWN_SECONDS) or 0.5
local AURA_ROLL_COST = tonumber(GameConfig.AURA_ROLL_COST) or 1000
local STAGE_COUNT = 20

local WIN_MODE_BEST = "Best Unlocked"
local WIN_MODE_SELECTED = "Selected"

local UPGRADE_ORDER = { "WalkSpeed", "AuraLuck" }
local UPGRADE_LABELS = {}
local UPGRADE_BY_LABEL = {}
for _, id in UPGRADE_ORDER do
	local data = GameConfig.UPGRADES[id]
	local label = data and data.displayName or id
	UPGRADE_LABELS[#UPGRADE_LABELS + 1] = label
	UPGRADE_BY_LABEL[label] = id
end

local TOILET_LABELS = {}
local TOILET_BY_LABEL = {}
do
	local list = {}
	for id, data in GameConfig.TOILETS do
		list[#list + 1] = {
			id = id,
			multiplier = tonumber(data.multiplier) or 0,
		}
	end
	table.sort(list, function(a, b)
		return a.multiplier < b.multiplier
	end)
	for _, entry in list do
		local label = entry.multiplier .. "x"
		TOILET_LABELS[#TOILET_LABELS + 1] = label
		TOILET_BY_LABEL[label] = entry.id
	end
end

local Toggles
local Options

local connections = {}
local function track(connection)
	if connection then
		connections[#connections + 1] = connection
	end
	return connection
end

local replica = nil
local lastWorldId = 0
local lastClickAt = 0
local lastFoodAt = 0
local lastUpgradeAt = 0
local lastAuraAt = 0
local lastBattleAt = 0
local lastWinTouchAt = 0
local parkedWinStage = nil
local parkedWinCharacter = nil
local battleBusy = false
local battleBusyAt = 0
local battleLockUntil = 0
local CUTSCENE_BIND = "OuroborosPoopNoCutscene"

local function isOn(name)
	local toggle = Toggles and Toggles[name]
	return toggle ~= nil and toggle.Value == true
end

local function getChoice(name)
	local option = Options[name]
	return option and option.Value or nil
end

local function selectedHas(option, label)
	local value = option and option.Value
	if type(value) ~= "table" then
		return false
	end
	if value[label] == true then
		return true
	end
	for _, entry in value do
		if entry == label then
			return true
		end
	end
	return false
end

local function asNumber(value)
	local n = tonumber(value)
	if n then
		return n
	end
	if type(value) == "string" then
		n = tonumber((string.gsub(value, "[,%s]", "")))
		if n then
			return n
		end
	end
	return 0
end

local function getHumanoid()
	local character = LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getLeaderstat(name)
	local stats = LocalPlayer:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild(name)
	return value and asNumber(value.Value) or 0
end

local function captureReplicaFromConnections()
	if not getconnections or not debug or not debug.getupvalues then
		return
	end
	local ok, conns = pcall(getconnections, StateChanged.OnClientEvent)
	if not ok or type(conns) ~= "table" then
		return
	end
	for _, connection in conns do
		local fn = connection.Function
		if type(fn) == "function" then
			local uvOk, uvs = pcall(debug.getupvalues, fn)
			if uvOk and type(uvs) == "table" then
				for _, value in uvs do
					if type(value) == "table" and value.rebirths ~= nil and value.highestUnlockedStage ~= nil then
						replica = value
						return
					end
				end
			end
		end
	end
end

track(StateChanged.OnClientEvent:Connect(function(state)
	if type(state) == "table" then
		replica = state
	end
end))

captureReplicaFromConnections()

local function cancelCameraTweens(camera)
	if not camera then
		return
	end
	pcall(function()
		for _, tween in TweenService:GetPlayingTweens() do
			if tween.Instance == camera then
				tween:Cancel()
			end
		end
	end)
end

local function restoreBattleCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		return
	end
	cancelCameraTweens(camera)
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = getHumanoid()
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

track(BattleEvent.OnClientEvent:Connect(function(action)
	if action == "Start" or action == "Begin" or action == "Update" then
		battleBusy = true
		battleBusyAt = os.clock()
		restoreBattleCamera()
	elseif action == "StageCompleted" then
		battleLockUntil = math.max(battleLockUntil, os.clock() + 2.2)
		restoreBattleCamera()
	elseif action == "Result" then
		battleBusy = false
		battleLockUntil = math.max(battleLockUntil, os.clock() + 1.7)
		restoreBattleCamera()
	end
end))

local function getState()
	local state = replica
	if type(state) ~= "table" then
		return {
			wins = getLeaderstat("Wins"),
			poop = getLeaderstat("Poop"),
			rebirths = getLeaderstat("Rebirths"),
			level = getLeaderstat("Level"),
			highestUnlockedStage = 1,
			currentWorldId = Workspace:GetAttribute("ActiveWorldId") or 1,
			equippedFoodId = "",
			unlockedFoods = {},
			ownedAuras = {},
			passOwnership = {},
			walkSpeedLevel = 0,
			auraLuckLevel = 0,
			luckyAuraRolls = 0,
			superAuraRolls = 0,
			autoWinsEnabled = false,
			isBattling = false,
			worldProgress = {},
		}
	end
	return state
end

local function battleBlocking()
	return battleBusy or getState().isBattling or os.clock() < battleLockUntil
end

local function currentWorldId()
	local state = getState()
	local worldId = tonumber(state.currentWorldId)
	if not worldId then
		worldId = tonumber(Workspace:GetAttribute("ActiveWorldId"))
	end
	return math.clamp(worldId or 1, 1, 3)
end

local function highestUnlockedStage()
	local state = getState()
	local stage = tonumber(state.highestUnlockedStage) or 1
	return math.clamp(stage, 1, STAGE_COUNT + 1)
end

local function foodOwned(foodId)
	local state = getState()
	if state.equippedFoodId == foodId then
		return true
	end
	local unlocked = state.unlockedFoods
	if type(unlocked) ~= "table" then
		return false
	end
	for _, id in unlocked do
		if id == foodId then
			return true
		end
	end
	return false
end

local function hasPass(passKey)
	if type(passKey) ~= "string" or passKey == "" then
		return true
	end
	local ownership = getState().passOwnership
	return type(ownership) == "table" and ownership[passKey] == true
end

local function stageLabel(worldId, stageIndex)
	local worldStages = GameConfig.WORLD_STAGES[worldId]
	local data = worldStages and worldStages[stageIndex]
	local npcName = data and data.npcName or ("Stage " .. stageIndex)
	return stageIndex .. " · " .. npcName
end

local function stageValues(worldId)
	local values = {}
	for index = 1, STAGE_COUNT do
		values[index] = stageLabel(worldId, index)
	end
	return values
end

local function parseStage(label)
	return tonumber(string.match(tostring(label), "^(%d+)"))
end

local function selectedStages(optionName)
	local option = Options and Options[optionName]
	local stages = {}
	if not option then
		return stages
	end
	local value = option.Value
	if type(value) ~= "table" then
		return stages
	end
	for key, entry in value do
		local label = type(key) == "string" and entry == true and key or entry
		local stage = parseStage(label)
		if stage then
			stages[#stages + 1] = stage
		end
	end
	table.sort(stages)
	return stages
end

local function worldFolder(name)
	local authority = Workspace:FindFirstChild("WorldInteractionAuthority")
	if authority then
		local world = authority:FindFirstChild("World" .. tostring(currentWorldId()))
		if world then
			local child = world:FindFirstChild(name)
			if child then
				return child
			end
		end
	end
	local visuals = Workspace:FindFirstChild("WorldClientVisuals")
	if visuals then
		return visuals:FindFirstChild(name)
	end
	return nil
end

local function stageFolder(stageIndex)
	local interactables = Workspace:FindFirstChild("Interactables")
	local stages = interactables and interactables:FindFirstChild("Stages")
	return stages and stages:FindFirstChild("Stage" .. tostring(stageIndex))
end

local function winPad(stageIndex)
	local folder = stageFolder(stageIndex)
	if not folder then
		return nil
	end
	local useDouble = hasPass("DoubleWins")
	local pad = folder:FindFirstChild(useDouble and "2xLevelWinsPad" or "LevelWinsPad")
	if pad and pad:IsA("BasePart") then
		return pad
	end
	return nil
end

local function battlePrompt(stageIndex)
	local folder = stageFolder(stageIndex)
	local toilet = folder and folder:FindFirstChild("Playertoilet")
	if not toilet then
		return nil
	end
	local prompt = toilet:FindFirstChild("BattlePrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		return prompt
	end
	return nil
end

local function teleportTo(part, extra)
	local root = getRoot()
	if not root or not part then
		return false
	end
	local position
	if typeof(part) == "Vector3" then
		position = part
	elseif part:IsA("BasePart") then
		position = part.Position
	elseif part:IsA("Model") then
		position = part:GetPivot().Position
	else
		return false
	end
	local offset = extra or Vector3.new(0, 3, 0)
	local look = root.CFrame.LookVector
	root.CFrame = CFrame.new(position + offset, position + offset + look)
	return true
end

local function touchPart(part)
	local root = getRoot()
	if not root or not part or not part:IsA("BasePart") then
		return
	end
	if firetouchinterest then
		pcall(firetouchinterest, root, part, 0)
		task.defer(function()
			pcall(firetouchinterest, root, part, 1)
		end)
	end
end

local function firePrompt(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return false
	end
	pcall(function()
		prompt.Enabled = true
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
	end)
	local parent = prompt.Parent
	local root = getRoot()
	if parent and parent:IsA("BasePart") then
		if not root or (root.Position - parent.Position).Magnitude > 5 then
			teleportTo(parent, Vector3.new(0, 2, 0))
		end
	elseif parent then
		teleportTo(parent)
	end
	local ok = false
	if fireproximityprompt then
		ok = pcall(fireproximityprompt, prompt)
	end
	if firesignal then
		pcall(firesignal, prompt.Triggered, LocalPlayer)
		ok = true
	end
	if not ok then
		ok = pcall(function()
			ProximityPromptService.PromptTriggered:Fire(prompt, LocalPlayer)
		end)
	end
	return ok
end

local function requestClick()
	local now = os.clock()
	if now - lastClickAt < CLICK_INTERVAL then
		return
	end
	lastClickAt = now
	RequestClick:FireServer()
end

local function toiletModel(toiletId)
	local toilets = worldFolder("Toilets")
	if not toilets then
		return nil
	end
	return toilets:FindFirstChild("Toilet_" .. toiletId)
end

local function toiletSeat(model)
	if not model then
		return nil
	end
	local seat = model:FindFirstChild("ToiletSeat", true)
	if seat and seat:IsA("Seat") then
		return seat
	end
	return model:FindFirstChildWhichIsA("Seat", true)
end

local function bestFood()
	local pads = worldFolder("FoodPads")
	if not pads then
		return nil
	end
	local wins = tonumber(getState().wins) or 0
	local best
	for _, pad in pads:GetChildren() do
		local foodId = pad:GetAttribute("FoodId")
		if type(foodId) == "string" then
			local data = GameConfig.FOODS[foodId]
			if data and hasPass(data.passKey) then
				local cost = tonumber(data.winCost) or 0
				local owned = foodOwned(foodId)
				if owned or wins >= cost then
					local power = tonumber(data.basePower) or 0
					if not best or power > best.power then
						local prompt = pad:FindFirstChild("FoodPrompt")
						if prompt and prompt:IsA("ProximityPrompt") and prompt.MaxActivationDistance > 0 then
							best = {
								id = foodId,
								power = power,
								owned = owned,
								pad = pad,
								prompt = prompt,
							}
						end
					end
				end
			end
		end
	end
	return best
end

local function ensureFood(foodId)
	if type(foodId) ~= "string" or foodOwned(foodId) then
		return foodOwned(foodId)
	end
	local pads = worldFolder("FoodPads")
	local pad = pads and pads:FindFirstChild(foodId)
	if not pad then
		return false
	end
	local data = GameConfig.FOODS[foodId]
	local cost = data and tonumber(data.winCost) or 0
	if (tonumber(getState().wins) or 0) < cost then
		return false
	end
	local prompt = pad:FindFirstChild("FoodPrompt")
	if prompt then
		firePrompt(prompt)
	end
	return false
end

local Farm = {}

function Farm.click()
	if isOn("AutoClick") or battleBusy or getState().isBattling then
		requestClick()
	end
end

function Farm.rebirth()
	if not isOn("AutoRebirth") then
		return
	end
	local state = getState()
	if battleBlocking() then
		return
	end
	local rebirths = tonumber(state.rebirths) or 0
	local level = tonumber(state.level) or 0
	local requirement = GameConfig.getRebirthRequirement(rebirths)
	if level >= requirement then
		RequestRebirth:FireServer()
	end
end

function Farm.upgrades()
	if not isOn("AutoBuyUpgrades") then
		return
	end
	local now = os.clock()
	if now - lastUpgradeAt < 0.35 then
		return
	end
	local state = getState()
	local wins = tonumber(state.wins) or 0
	local worldId = currentWorldId()
	local scale = GameConfig.getWorldNumericScale(worldId)
	local option = Options.UpgradeKinds
	for _, label in UPGRADE_LABELS do
		if selectedHas(option, label) then
			local id = UPGRADE_BY_LABEL[label]
			local data = GameConfig.UPGRADES[id]
			if data then
				local level = 0
				if id == "WalkSpeed" then
					level = tonumber(state.walkSpeedLevel) or 0
				elseif id == "AuraLuck" then
					level = tonumber(state.auraLuckLevel) or 0
				end
				if level < (tonumber(data.maxLevel) or 0) then
					local ok, cost = pcall(GameConfig.getUpgradeWinCost, id, level)
					if ok then
						local scaled = cost * (tonumber(scale) or 1)
						if wins >= scaled then
							lastUpgradeAt = now
							RequestUpgrade:FireServer(id)
							return
						end
					end
				end
			end
		end
	end
end

function Farm.auras()
	if not isOn("AutoRollAura") then
		return
	end
	local now = os.clock()
	if now - lastAuraAt < 0.85 then
		return
	end
	local state = getState()
	if (tonumber(state.superAuraRolls) or 0) > 0 then
		lastAuraAt = now
		RequestAuraRoll:FireServer("Super")
		return
	end
	if (tonumber(state.luckyAuraRolls) or 0) > 0 then
		lastAuraAt = now
		RequestAuraRoll:FireServer("Lucky")
		return
	end
	local wins = math.max(asNumber(state.wins), getLeaderstat("Wins"))
	if wins >= AURA_ROLL_COST then
		lastAuraAt = now
		RequestAuraRoll:FireServer("Regular")
	end
end

function Farm.buyClick()
	if not isOn("AutoBuyClick") then
		return
	end
	if battleBlocking() then
		return
	end
	local now = os.clock()
	if now - lastFoodAt < 0.45 then
		return
	end
	local food = bestFood()
	if not food then
		return
	end
	if getState().equippedFoodId == food.id then
		return
	end
	lastFoodAt = now
	firePrompt(food.prompt)
end

function Farm.train()
	if not isOn("AutoTrain") then
		return
	end
	if isOn("AutoWin") or battleBlocking() then
		return
	end
	local toiletId = TOILET_BY_LABEL[getChoice("TrainToilet")]
	if type(toiletId) ~= "string" then
		return
	end
	local model = toiletModel(toiletId)
	local seat = toiletSeat(model)
	local target = seat
	if not target and model then
		target = model:FindFirstChild("Pad") or model
	end
	if not target then
		return
	end
	local root = getRoot()
	local position = target:IsA("BasePart") and target.Position or target:GetPivot().Position
	if root and (root.Position - position).Magnitude < 8 then
		return
	end
	teleportTo(target, Vector3.new(0, 3, 0))
end

function Farm.battle()
	if not isOn("AutoBattleInOrder") then
		return
	end
	if battleBusy and os.clock() - battleBusyAt > 45 then
		battleBusy = false
	end
	if battleBusy or getState().isBattling then
		restoreBattleCamera()
		return
	end
	local now = os.clock()
	if now < battleLockUntil then
		return
	end
	if now - lastBattleAt < 0.55 then
		return
	end
	local target = highestUnlockedStage()
	if target < 1 or target > STAGE_COUNT then
		return
	end
	local prompt = battlePrompt(target)
	if not prompt then
		return
	end
	pcall(function()
		local api
		if getrenv then
			local env = getrenv()
			api = env.EwwPooBattlePrompt or (env._G and env._G.EwwPooBattlePrompt)
		end
		api = api or rawget(_G, "EwwPooBattlePrompt")
		if type(api) == "table" and type(api.set) == "function" then
			api.set(target, true)
		end
		prompt.Enabled = true
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 15
	end)
	lastBattleAt = now
	battleLockUntil = now + 2.5
	firePrompt(prompt)
end

function Farm.win()
	if not isOn("AutoWin") then
		parkedWinStage = nil
		parkedWinCharacter = nil
		return
	end
	if battleBlocking() then
		return
	end
	local unlocked = highestUnlockedStage()
	local target
	if getChoice("WinMode") == WIN_MODE_SELECTED then
		for _, stage in selectedStages("SelectedStages") do
			if stage >= 1 and stage <= STAGE_COUNT and stage <= unlocked then
				if not target or stage > target then
					target = stage
				end
			end
		end
	else
		target = math.clamp(unlocked, 1, STAGE_COUNT)
	end
	if not target then
		return
	end
	local pad = winPad(target)
	if not pad then
		return
	end
	local character = LocalPlayer.Character
	local root = getRoot()
	local far = not root or (root.Position - pad.Position).Magnitude > 10
	if parkedWinStage ~= target or parkedWinCharacter ~= character or far then
		parkedWinStage = target
		parkedWinCharacter = character
		teleportTo(pad, Vector3.new(0, 3, 0))
	end
	local now = os.clock()
	if now - lastWinTouchAt >= WIN_PAD_COOLDOWN then
		lastWinTouchAt = now
		touchPart(pad)
	end
end

function Farm.skipCutscene()
	if battleBusy and os.clock() - battleBusyAt > 45 then
		battleBusy = false
	end
	local fighting = battleBusy or getState().isBattling
	if not fighting and not isOn("AutoBattleInOrder") then
		return
	end
	restoreBattleCamera()
end

function Farm.refreshStageDropdown()
	local worldId = currentWorldId()
	if worldId == lastWorldId then
		return
	end
	lastWorldId = worldId
	local values = stageValues(worldId)
	if Options.SelectedStages then
		Options.SelectedStages:SetValues(values)
	end
end

local repo = "https://raw.githubusercontent.com/joustingmatch/ObsidianUltra/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

if getgenv then
	getgenv().__OuroborosPoopPerClickLib = Library
end

Toggles = Library.Toggles
Options = Library.Options

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
	SidebarCompacted = true,
	TabSwipeFrom = "bottom",
	Animations = {
		TabSwitch = true,
	},
})

Window:SetGlow(true, {
	Color = Color3.fromRGB(242, 154, 196),
	Radius = 24,
	Transparency = 0.3,
})

local Tabs = {
	Info = Window:AddTab("Info", "info"),
	Main = Window:AddTab("Main", "gamepad-2"),
	Player = Window:AddTab("Player", "person-standing"),
	Settings = Window:AddTab("Settings", "settings"),
}

for name, Tab in Tabs do
	if name ~= "Info" then
		AddDiscordButton(Tab)
	end
end

local FarmGroup = Tabs.Main:AddLeftGroupbox("Farm", "trophy")
FarmGroup:AddToggle("AutoWin", { Text = "Auto Win", Default = false })
FarmGroup:AddDropdown("WinMode", {
	Text = "Win Mode",
	Values = { WIN_MODE_BEST, WIN_MODE_SELECTED },
	Default = WIN_MODE_BEST,
})
FarmGroup:AddDropdown("SelectedStages", {
	Text = "Win Stages",
	Values = stageValues(currentWorldId()),
	Multi = true,
	Default = {},
	Expandable = true,
})
FarmGroup:AddDivider("Battle")
FarmGroup:AddToggle("AutoBattleInOrder", { Text = "Auto Battle In Order", Default = false })

local ProgressGroup = Tabs.Main:AddRightGroupbox("Progress", "trending-up")
ProgressGroup:AddToggle("AutoRebirth", { Text = "Auto Rebirth", Default = false })
ProgressGroup:AddDivider("Click")
ProgressGroup:AddToggle("AutoClick", { Text = "Auto Click", Default = false })
ProgressGroup:AddToggle("AutoBuyClick", { Text = "Auto Buy Click", Default = false })
ProgressGroup:AddToggle("AutoTrain", { Text = "Auto Train", Default = false })
ProgressGroup:AddDropdown("TrainToilet", {
	Text = "Toilet",
	Values = TOILET_LABELS,
	Default = TOILET_LABELS[1],
	Expandable = true,
})
ProgressGroup:AddDivider("Shop")
ProgressGroup:AddToggle("AutoBuyUpgrades", { Text = "Auto Buy Upgrades", Default = false })
ProgressGroup:AddDropdown("UpgradeKinds", {
	Text = "Upgrades",
	Values = UPGRADE_LABELS,
	Multi = true,
	Default = { ["Walk Speed"] = true, ["Aura Luck"] = true },
	Expandable = true,
})
ProgressGroup:AddToggle("AutoRollAura", { Text = "Auto Roll Aura", Default = false })

lastWorldId = currentWorldId()

local function setupInfoTab()
	local GREEN = "#7fd47f"
	local BLUE = "#6ec1ff"
	local ORANGE = "#e8a34d"
	local GREY = "#8b93a3"
	local RED = "#e05a5a"

	local function colored(text, color)
		return string.format('<font color="%s">%s</font>', color, text)
	end

	local function field(key, value, color)
		return string.format("<b>%s</b> %s %s", key, colored("-", "#5a6070"), colored(value, color))
	end

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
	UserGroup:AddButton({ Text = "Copy Username", Func = function() copyText(LocalPlayer.Name, "Copied username") end })
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
	SessionGroup:AddButton({ Text = "Rejoin Server", Func = function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end })
	SessionGroup:AddButton({ Text = "Copy Job ID", Func = function() copyText(jobId, "Copied Job ID") end })

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
	SocialsGroup:AddButton({ Text = "Website", Func = function() copyText(WEBSITE_LINK, "Copied website link") end })
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

	track(RunService.Stepped:Connect(function()
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
	end))

	track(UserInputService.JumpRequest:Connect(function()
		if Library.Unloaded then
			return
		end
		if Toggles.InfJump and Toggles.InfJump.Value then
			local humanoid = getHumanoid()
			if humanoid then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	end))

	local Camera = Workspace.CurrentCamera
	track(RunService.RenderStepped:Connect(function(dt)
		if Library.Unloaded then
			return
		end
		if Toggles.WalkSpeedEnabled and Toggles.WalkSpeedEnabled.Value then
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
				Camera = Workspace.CurrentCamera
				if Camera then
					if UserInputService:IsKeyDown(Enum.KeyCode.W) then
						direction += Camera.CFrame.LookVector
					end
					if UserInputService:IsKeyDown(Enum.KeyCode.S) then
						direction -= Camera.CFrame.LookVector
					end
					if UserInputService:IsKeyDown(Enum.KeyCode.A) then
						direction -= Camera.CFrame.RightVector
					end
					if UserInputService:IsKeyDown(Enum.KeyCode.D) then
						direction += Camera.CFrame.RightVector
					end
				end
				if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
					direction += Vector3.new(0, 1, 0)
				end
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
					direction -= Vector3.new(0, 1, 0)
				end
				root.AssemblyLinearVelocity = Vector3.zero
				if direction.Magnitude > 0 then
					root.CFrame += direction.Unit * Options.FlySpeed.Value * dt
				end
			end
		end
	end))

	Toggles.Fly:OnChanged(function()
		if not Toggles.Fly.Value then
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

	local function applyInstantPrompt(prompt)
		if not prompt:IsA("ProximityPrompt") then
			return
		end
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 50
		prompt.RequiresLineOfSight = false
	end

	local instantPromptConnection
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
			track(instantPromptConnection)
		elseif instantPromptConnection then
			instantPromptConnection:Disconnect()
			instantPromptConnection = nil
		end
	end)

	Library:OnUnload(function()
		if instantPromptConnection then
			instantPromptConnection:Disconnect()
		end
	end)
end

local function setupMenuFeatures()
	local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "logs")
	MenuGroup:AddToggle("AntiAfk", {
		Text = "Anti-AFK",
		Default = true,
	})
	local antiAfkStat = MenuGroup:AddLabel("AFK triggers: 0")
	MenuGroup:AddToggle("AntiGameplayPause", { Text = "No Gameplay Paused", Default = true })
	MenuGroup:AddToggle("AutoReconnect", { Text = "Auto Reconnect on Kick", Default = false })
	MenuGroup:AddToggle("Disable3D", { Text = "Disable 3D Rendering", Default = false })
	MenuGroup:AddToggle("FpsBoost", { Text = "FPS Boost", Default = false })
	MenuGroup:AddToggle("HideUiOnStart", { Text = "Hide UI On Start", Default = false })
	MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
		Default = "RightShift",
		NoUI = true,
		Text = "Menu keybind",
	})
	Library.ToggleKeybind = Options.MenuKeybind

	local antiAfkTriggerCount = 0
	local antiAfkLastPulse = tick()
	local function antiAfkTap()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0), camera.CFrame)
		antiAfkTriggerCount += 1
		antiAfkLastPulse = tick()
		pcall(function()
			antiAfkStat:SetText("AFK triggers: " .. antiAfkTriggerCount)
		end)
	end

	local antiAfkIdledConnection = LocalPlayer.Idled:Connect(function()
		if Toggles.AntiAfk.Value then
			pcall(antiAfkTap)
		end
	end)
	track(antiAfkIdledConnection)

	task.spawn(function()
		while not Library.Unloaded do
			task.wait(2)
			if Toggles.AntiAfk.Value and tick() - antiAfkLastPulse >= 60 then
				pcall(antiAfkTap)
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

	local reconnecting = false
	local function rejoin()
		if reconnecting then
			return
		end
		reconnecting = true
		local placeId, jobId = game.PlaceId, game.JobId
		local ok = pcall(function()
			TeleportService:TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
		end)
		if not ok then
			pcall(function()
				TeleportService:Teleport(placeId, LocalPlayer)
			end)
		end
	end

	task.spawn(function()
		local overlay = CoreGui:WaitForChild("RobloxPromptGui", 30)
		overlay = overlay and overlay:WaitForChild("promptOverlay", 30)
		if not overlay then
			return
		end
		track(overlay.ChildAdded:Connect(function(child)
			if Library.Unloaded then
				return
			end
			if Toggles.AutoReconnect.Value and child.Name == "ErrorPrompt" then
				rejoin()
			end
		end))
	end)

	track(TeleportService.TeleportInitFailed:Connect(function()
		if Toggles.AutoReconnect.Value then
			reconnecting = false
			rejoin()
		end
	end))

	Toggles.Disable3D:OnChanged(function()
		pcall(function()
			RunService:Set3dRenderingEnabled(not Toggles.Disable3D.Value)
		end)
	end)

	local strippedClasses = {
		ParticleEmitter = true,
		Trail = true,
		Smoke = true,
		Fire = true,
		Sparkles = true,
		Explosion = true,
		Beam = true,
	}

	local function stripEffect(instance)
		if strippedClasses[instance.ClassName] then
			pcall(function()
				instance.Enabled = false
			end)
		end
	end

	local fpsBoostConnection
	Toggles.FpsBoost:OnChanged(function()
		if Toggles.FpsBoost.Value then
			pcall(function()
				settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
			end)
			pcall(function()
				Lighting.GlobalShadows = false
			end)
			pcall(function()
				Lighting.FogEnd = 9e9
			end)
			for _, instance in ipairs(Workspace:GetDescendants()) do
				pcall(stripEffect, instance)
			end
			fpsBoostConnection = Workspace.DescendantAdded:Connect(function(instance)
				if Toggles.FpsBoost.Value then
					pcall(stripEffect, instance)
				end
			end)
			track(fpsBoostConnection)
		else
			pcall(function()
				settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
			end)
			pcall(function()
				Lighting.GlobalShadows = true
			end)
			if fpsBoostConnection then
				fpsBoostConnection:Disconnect()
				fpsBoostConnection = nil
			end
		end
	end)

	local ScriptGroup = Tabs.Settings:AddLeftGroupbox("Script", "terminal")
	ScriptGroup:AddButton({
		Text = "Unload Script",
		Func = function()
			Library:Unload()
		end,
	})

	Library:OnUnload(function()
		if antiAfkIdledConnection then
			antiAfkIdledConnection:Disconnect()
		end
		applyAntiGameplayPause(false)
		pcall(function()
			RunService:Set3dRenderingEnabled(true)
		end)
		pcall(function()
			RunService:UnbindFromRenderStep(CUTSCENE_BIND)
		end)
		if fpsBoostConnection then
			fpsBoostConnection:Disconnect()
		end
		for _, connection in connections do
			pcall(function()
				connection:Disconnect()
			end)
		end
		table.clear(connections)
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
			humanoid.WalkSpeed = 16
		end
		if getgenv then
			getgenv().__OuroborosPoopPerClickLib = nil
		end
	end)
end

local function setupConfigExport(ConfigurationBox)
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
end

setupInfoTab()
setupPlayerTab()
setupMenuFeatures()

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("OuroborosHub")
ThemeManager:SaveDefault("Evil Hello Kitty")
ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind", "SaveManager_ImportSource" })
SaveManager:SetFolder("OuroborosHub/PoopPerClick")
local ConfigurationBox = SaveManager:BuildConfigSection(Tabs.Settings)
setupConfigExport(ConfigurationBox)
SaveManager:LoadAutoloadConfig()

if Toggles.HideUiOnStart and Toggles.HideUiOnStart.Value then
	Library:Toggle(false)
end

local function farmLoop(interval, runner)
	task.spawn(function()
		while not Library.Unloaded do
			pcall(runner)
			task.wait(interval)
		end
	end)
end

farmLoop(CLICK_INTERVAL, Farm.click)
farmLoop(0.2, Farm.win)
farmLoop(0.35, Farm.battle)
farmLoop(0.4, Farm.buyClick)
farmLoop(0.35, Farm.train)
farmLoop(0.4, Farm.upgrades)
farmLoop(0.45, Farm.auras)
farmLoop(1, Farm.rebirth)
farmLoop(1, Farm.refreshStageDropdown)

pcall(function()
	RunService:BindToRenderStep(CUTSCENE_BIND, Enum.RenderPriority.Camera.Value + 1, function()
		if Library.Unloaded then
			return
		end
		Farm.skipCutscene()
	end)
end)
