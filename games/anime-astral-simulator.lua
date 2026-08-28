if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local SimpleWorld
for _, child in ReplicatedStorage:GetChildren() do
	if child.Name == "SimpleWorld" then
		SimpleWorld = child
		break
	end
end

local Library = require(SimpleWorld.Library)
local ClientFolder = SimpleWorld.Library.Client
local WorldController = require(ClientFolder.WorldController)
local AutoActionController = require(ClientFolder.AutoActionController)
local TeleportController = require(ClientFolder.TeleportController)

local WorldConfig = Library.getConfig("WorldConfig")
local EnemyConfig = Library.getConfig("EnemyConfig")
local SideQuestConfig = Library.getConfig("SideQuestConfig")

local function getBridge(name)
	local bridge
	local pending = true
	task.spawn(function()
		local ok, result = pcall(Library.getBridge, name)
		if ok then
			bridge = result
		end
		pending = false
	end)
	local deadline = os.clock() + 5
	while pending and os.clock() < deadline do
		task.wait(0.1)
	end
	return bridge
end

local Bridges = {
	Click = getBridge("Click"),
	RankUp = getBridge("RankUp"),
	AutoClaimAchievementsSet = getBridge("AutoClaimAchievementsSet"),
	AutoClaimRewardsSet = getBridge("AutoClaimRewardsSet"),
	AutoAvatarBuffSet = getBridge("AutoAvatarBuffSet"),
	BuyWorld = getBridge("BuyWorld"),
	RequestChangeWorld = getBridge("RequestChangeWorld"),
	FuseAllSwords = getBridge("FuseAllSwords"),
	EquipBest = getBridge("EquipBest"),
	EquipBestSword = getBridge("EquipBestSword"),
	EquipBestTitan = getBridge("EquipBestTitan"),
	OpenEgg = getBridge("OpenEgg"),
	QuestCollect = getBridge("QuestCollect"),
	GlobalQuestClaimAll = getBridge("GlobalQuestClaimAll"),
	SideQuestAcceptRequest = getBridge("SideQuestAcceptRequest"),
	EquipBestLoadout = getBridge("EquipBestLoadout"),
	RaidGateTeleport = getBridge("RaidGateTeleport"),
	GachaRoll = getBridge("GachaRoll"),
	SwordRoll = getBridge("SwordRoll"),
	TitanRoll = getBridge("TitanRoll"),
	PlayerPassiveRoll = getBridge("PlayerPassiveRoll"),
}

local GachaConfig = Library.getConfig("GachaConfig")
local SwordConfig = Library.getConfig("SwordConfig")
local TitansConfig = Library.getConfig("TitansConfig")

local RarityRank = {}
for rank, rarity in ipairs(GachaConfig.Rarity_Order) do
	RarityRank[rarity] = rank
end

local GachaNames = {}
local GachaNameToKey = {}
local GachaMaxRarity = {}

for key, gacha in pairs(GachaConfig.Gachas) do
	table.insert(GachaNames, gacha.Name)
	GachaNameToKey[gacha.Name] = key

	local best, bestRank
	for rarity in pairs(gacha.Items or {}) do
		local rank = RarityRank[rarity]
		if rank and (not bestRank or rank > bestRank) then
			best, bestRank = rarity, rank
		end
	end
	GachaMaxRarity[key] = best
end
table.sort(GachaNames)

local function BuildBannerData(entries)
	local names = {}
	local map = {}
	for key, entry in pairs(entries) do
		table.insert(names, entry.Name)
		map[entry.Name] = key
	end
	table.sort(names)
	return names, map
end

local SwordBannerNames, SwordBannerToKey = BuildBannerData(SwordConfig.Swords)
local TitanBannerNames, TitanBannerToKey = BuildBannerData(TitansConfig.Titans)

local ActiveGachas = {}

local GAMEMODES = {
	{
		Id = "Trial",
		Arenas = "TimeTrialArenas",
		Config = "TimeTrialConfig",
		Getter = "GetAllTrials",
		TotalField = "TotalRooms",
		Counter = "Room",
		Join = "TimeTrialJoin",
		Leave = "TimeTrialLeave",
		State = "TimeTrialState",
		Ended = "TimeTrialEnded",
		FarmTitle = "Time Trial Farm",
		LeaveTitle = "Time Trial Leave At Floor",
		SelectText = "Select Trials",
		AutoFarmText = "Auto Farm Trial",
		AutoLeaveText = "Auto leave At Time Trial Floor",
	},
	{
		Id = "Raid",
		Arenas = "RaidArenas",
		Config = "RaidConfig",
		Getter = "GetAllRaids",
		TotalField = "TotalWaves",
		Counter = "Wave",
		Join = "RaidJoin",
		Leave = "RaidLeave",
		State = "RaidState",
		Ended = "RaidEnded",
		Status = "RaidActiveStatus",
		Controller = "RaidController",
		Afford = "HasEnoughForRaid",
		CanJoinActive = "CanAutoJoinActiveRaid",
		FarmTitle = "Raid Farm",
		LeaveTitle = "Raid Leave At Wave",
		SelectText = "Select Raids",
		AutoFarmText = "Auto Farm Raid",
		AutoLeaveText = "Auto leave At Raid Floor",
	},
	{
		Id = "Defense",
		Arenas = "DefenseArenas",
		Config = "DefenseConfig",
		Getter = "GetAllDefenses",
		TotalField = "TotalWaves",
		Counter = "Wave",
		Join = "DefenseJoin",
		Leave = "DefenseLeave",
		State = "DefenseState",
		Ended = "DefenseEnded",
		Status = "DefenseActiveStatus",
		Controller = "DefenseController",
		Afford = "HasEnoughForDefense",
		CanJoinActive = "CanAutoJoinActiveDefense",
		FarmTitle = "Defense Farm",
		LeaveTitle = "Defense Leave At Wave",
		SelectText = "Select Defenses",
		AutoFarmText = "Auto Farm Defense",
		AutoLeaveText = "Auto leave At Defense Floor",
	},
	{
		Id = "Dungeon",
		Arenas = "DungeonArenas",
		Config = "DungeonConfig",
		Getter = "GetAllDungeons",
		TotalField = "TotalRooms",
		Counter = "Room",
		Join = "DungeonJoin",
		Leave = "DungeonLeave",
		State = "DungeonState",
		Ended = "DungeonEnded",
		FarmTitle = "Dungeon Farm",
		LeaveTitle = "Dungeon Leave At Wave",
		SelectText = "Select Dungeons",
		AutoFarmText = "Auto Farm Dungeon",
		AutoLeaveText = "Auto leave At Dungeon Room",
	},
}

for _, gamemode in ipairs(GAMEMODES) do
	local config = Library.getConfig(gamemode.Config)
	local entries = {}

	for key, entry in pairs(config[gamemode.Getter](config)) do
		table.insert(entries, {
			Key = key,
			Name = entry.Name,
			WorldId = tonumber(entry.WorldId),
			Total = tonumber(entry[gamemode.TotalField]) or 100,
			GateRanks = entry.GateRanks,
		})
	end

	table.sort(entries, function(a, b)
		return a.Name < b.Name
	end)

	gamemode.Entries = entries
	gamemode.NameToEntry = {}
	gamemode.Names = {}

	for _, entry in ipairs(entries) do
		table.insert(gamemode.Names, entry.Name)
		gamemode.NameToEntry[entry.Name] = entry

		if entry.GateRanks then
			local ranks = {}
			for _, rank in ipairs(entry.GateRanks) do
				table.insert(ranks, rank.Rank)
			end
			gamemode.GateRankValues = ranks
		end
	end

	Bridges[gamemode.Join] = getBridge(gamemode.Join)
	Bridges[gamemode.Leave] = getBridge(gamemode.Leave)
	Bridges[gamemode.State] = getBridge(gamemode.State)

	if gamemode.Status then
		Bridges[gamemode.Status] = getBridge(gamemode.Status)
	end
end

local ActiveGamemode = nil
local GateAnnouncements = {}

local RaidAnnouncement = getBridge("RaidAnnouncement")
if RaidAnnouncement then
	RaidAnnouncement:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.Key) ~= "string" then
			return
		end

		local rank
		if type(payload.Description) == "string" then
			rank = payload.Description:match("Rank%s+(%a+)%s+Gate")
		end

		GateAnnouncements[payload.Key] = {
			Rank = rank,
			GateTeleport = payload.GateTeleport,
		}
	end)
end

local GamemodeActiveKeys = {}
local GamemodeJoinIndex = {}
local GamemodeLeftKeys = {}

for _, gamemode in ipairs(GAMEMODES) do
	GamemodeActiveKeys[gamemode.Id] = {}
	GamemodeLeftKeys[gamemode.Id] = {}

	local status = gamemode.Status and Bridges[gamemode.Status]
	if status then
		status:Connect(function(payload)
			local keys = {}
			if type(payload) == "table" then
				for key, value in pairs(payload) do
					if type(key) == "string" then
						if value == true then
							keys[key] = true
						elseif type(value) == "table" and value.Active ~= false then
							keys[key] = true
						end
					end
				end
			end
			GamemodeActiveKeys[gamemode.Id] = keys

			for key in pairs(GamemodeLeftKeys[gamemode.Id]) do
				if not keys[key] then
					GamemodeLeftKeys[gamemode.Id][key] = nil
				end
			end

			if gamemode.Id == "Raid" then
				for key in pairs(GateAnnouncements) do
					if keys[key] then
						GateAnnouncements[key] = nil
					end
				end
			end
		end)
	end
end

local LOADOUT_STATS = { "Luck", "Drop", "Power", "XP", "Damage", "Yen", "None" }
local FARM_MODES = { "Selected", "Nearest", "All" }
local TARGET_MODES = { "Nearest", "Highest HP", "Furthest" }
local DIFFICULTIES = { "VeryEasy", "Easy", "Medium", "Hard", "MiniBoss", "Boss", "Secret" }

local DifficultyRank = {}
for rank, difficulty in ipairs(DIFFICULTIES) do
	DifficultyRank[difficulty] = rank
end

local ActiveMode = nil

local function BindMode(name, enterBridges, endBridge)
	for _, bridgeName in enterBridges do
		local bridge = getBridge(bridgeName)
		if bridge then
			bridge:Connect(function()
				ActiveMode = name
			end)
		end
	end

	local ended = getBridge(endBridge)
	if ended then
		ended:Connect(function()
			if ActiveMode == name then
				ActiveMode = nil
			end
		end)
	end
end

BindMode("Dungeon", { "DungeonState", "DungeonMapReady" }, "DungeonEnded")
BindMode("Defense", { "DefenseState", "DefenseMapReady" }, "DefenseEnded")
BindMode("Raid", { "RaidState", "RaidMapReady" }, "RaidEnded")
BindMode("Trial", { "TimeTrialState", "TimeTrialMapReady" }, "TimeTrialEnded")

local WorldChanged = getBridge("WorldChanged")
if WorldChanged then
	WorldChanged:Connect(function()
		ActiveMode = nil
	end)
end

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local ObsidianLibrary = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = ObsidianLibrary.Options
local Toggles = ObsidianLibrary.Toggles

local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"

local Worlds = {}
for _, world in ipairs(WorldConfig:GetAllWorlds()) do
	local id = tonumber(world.Order)
	if id then
		table.insert(Worlds, { Id = id, Name = world.Name })
	end
end
table.sort(Worlds, function(a, b)
	return a.Id < b.Id
end)

local WorldLabels = {}
local WorldLabelToId = {}
for _, world in ipairs(Worlds) do
	local label = world.Name .. " | " .. world.Id
	table.insert(WorldLabels, label)
	WorldLabelToId[label] = world.Id
end

local MobLabelToName = {}

local function BuildMobData(worldIds)
	local entries = {}
	local map = {}

	for _, worldId in ipairs(worldIds) do
		local list = EnemyConfig:GetEnemiesByWorld(worldId)
		if list then
			for _, enemy in pairs(list) do
				if enemy and enemy.Name then
					local difficulty = tostring(enemy.Type or "Unknown")
					local label = enemy.Name .. " | " .. difficulty
					if not map[label] then
						map[label] = enemy.Name
						table.insert(entries, {
							Label = label,
							Name = enemy.Name,
							Rank = DifficultyRank[difficulty] or #DIFFICULTIES + 1,
							WorldId = worldId,
						})
					end
				end
			end
		end
	end

	table.sort(entries, function(a, b)
		if a.Rank ~= b.Rank then
			return a.Rank < b.Rank
		end
		if a.WorldId ~= b.WorldId then
			return a.WorldId < b.WorldId
		end
		return a.Name < b.Name
	end)

	local labels = {}
	for _, entry in ipairs(entries) do
		table.insert(labels, entry.Label)
	end

	return labels, map
end

local function BuildMobLabels(worldIds)
	local labels, map = BuildMobData(worldIds)
	MobLabelToName = map
	return labels
end

local SideQuestIds = {}
for id in pairs(SideQuestConfig.Quests) do
	table.insert(SideQuestIds, id)
end
table.sort(SideQuestIds)

local function GetSelected(option, values)
	local selected = {}
	local value = option and option.Value
	if type(value) ~= "table" then
		return selected
	end

	for _, entry in ipairs(values) do
		if value[entry] then
			table.insert(selected, entry)
		end
	end
	return selected
end

local function GetFirstSelected(option, values)
	return GetSelected(option, values)[1]
end

local function GetSelectedWorldId()
	local label = Options.FarmWorld and Options.FarmWorld.Value
	return label and WorldLabelToId[label]
end

local function GetSelectedMobNames()
	local names = {}
	local value = Options.FarmMob and Options.FarmMob.Value
	if type(value) ~= "table" then
		return names
	end

	for label, active in pairs(value) do
		if active and MobLabelToName[label] then
			names[MobLabelToName[label]] = true
		end
	end
	return names
end

local function GetRoot()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function GetCurrentWorldId()
	local ok, id = pcall(function()
		return WorldController:GetCurrentWorld()
	end)
	if ok and id then
		return tonumber(id)
	end
	return nil
end

local function GetEnemyList(worldId)
	local worldsFolder = workspace:FindFirstChild("Worlds")
	local world = worldsFolder and worldsFolder:FindFirstChild(tostring(worldId))
	local folder = world and world:FindFirstChild("Enemies")
	if not folder then
		return {}
	end

	local alive = {}
	for _, enemy in folder:GetChildren() do
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		local root = enemy:FindFirstChild("HumanoidRootPart")
		if humanoid and root and enemy:GetAttribute("EnemyDead") ~= true then
			table.insert(alive, enemy)
		end
	end
	return alive
end

local function GetNearestEnemy(worldId, root, nameFilter)
	local nearest, nearestDist
	for _, enemy in GetEnemyList(worldId) do
		if not nameFilter or nameFilter[enemy.Name] then
			local enemyRoot = enemy:FindFirstChild("HumanoidRootPart")
			local dist = (enemyRoot.Position - root.Position).Magnitude
			if not nearestDist or dist < nearestDist then
				nearest = enemy
				nearestDist = dist
			end
		end
	end
	return nearest
end

local function PickTarget(enemies, root, mode)
	local best, bestScore

	for _, enemy in ipairs(enemies) do
		local enemyRoot = enemy:FindFirstChild("HumanoidRootPart")
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")

		if enemyRoot and humanoid then
			local score
			if mode == "Highest HP" then
				score = humanoid.Health
			else
				score = (enemyRoot.Position - root.Position).Magnitude
				if mode ~= "Furthest" then
					score = -score
				end
			end

			if not bestScore or score > bestScore then
				best, bestScore = enemy, score
			end
		end
	end

	return best
end

local Window = ObsidianLibrary:CreateWindow({
	Title = "Ouroboros Hub",
	Footer = "https://discord.gg/f3dJhDgyTq | Anime Astral Simulator",
	Icon = 18657887261,
	EnableSidebarResize = true,
	NotifySide = "Right",
	ShowCustomCursor = false,
	ShowMobileButtons = false,
	Size = UDim2.fromOffset(960, 720),
})

local Tabs = {
	Main = Window:AddTab("Main", "swords"),
	Secondary = Window:AddTab("Secondary", "sparkles"),
	Gamemodes = Window:AddTab("Gamemodes", "castle"),
	Gacha = Window:AddTab("Gacha", "dices"),
	Priority = Window:AddTab("Priority", "list-ordered"),
	Webhook = Window:AddTab("Webhook", "webhook"),
	Settings = Window:AddTab("Settings", "settings"),
}

local function AddDiscordButton(Tab)
	Tab:AddLeftGroupbox("Discord", nil, nil, nil, true):AddButton({
		Text = "Join Discord For Dupe",
		Func = function()
			setclipboard(DISCORD_INVITE)
			ObsidianLibrary:Notify("Copied Discord invite to clipboard")
		end,
	})
end

for _, Tab in Tabs do
	AddDiscordButton(Tab)
end

local FarmGroup = Tabs.Main:AddLeftGroupbox("Farm")

FarmGroup:AddDropdown("FarmWorld", {
	Values = WorldLabels,
	Default = WorldLabels[1],
	Searchable = true,
	AllowNull = true,
	Text = "World",
	Callback = function()
		if Options.FarmMob then
			local worldId = GetSelectedWorldId()
			Options.FarmMob:SetValues(BuildMobLabels(worldId and { worldId } or {}))
		end
	end,
})

FarmGroup:AddDropdown("FarmMob", {
	Values = BuildMobLabels({ WorldLabelToId[WorldLabels[1]] }),
	Default = {},
	Multi = true,
	Searchable = true,
	AllowNull = true,
	Text = "Mob",
})

FarmGroup:AddDropdown("FarmMode", {
	Values = FARM_MODES,
	Default = "Nearest",
	Searchable = true,
	AllowNull = true,
	Text = "Farm Mode",
})

FarmGroup:AddToggle("TeleportBeforeFarm", {
	Text = "Teleport To World Before Farm",
	Default = true,
})

FarmGroup:AddToggle("AutoFarm", {
	Text = "Auto Farm",
	Default = false,
})

FarmGroup:AddToggle("FastAutoClick", {
	Text = "Fast Auto Click",
	Default = false,
})

local RoundRobinGroup = Tabs.Main:AddLeftGroupbox("Round Robin Farm")

local RoundRobinMobMap = {}
local RefreshRoundRobinKillSliders

local function RefreshRoundRobinMobs()
	local worldIds = {}
	for _, label in ipairs(GetSelected(Options.RoundRobinWorlds, WorldLabels)) do
		table.insert(worldIds, WorldLabelToId[label])
	end

	local labels, map = BuildMobData(worldIds)
	RoundRobinMobMap = map

	if Options.RoundRobinMobs then
		Options.RoundRobinMobs:SetValues(labels)
	end

	RefreshRoundRobinKillSliders()
end

RoundRobinGroup:AddDropdown("RoundRobinWorlds", {
	Values = WorldLabels,
	Default = {},
	Multi = true,
	Searchable = true,
	AllowNull = true,
	Text = "Worlds",
	Callback = RefreshRoundRobinMobs,
})

RoundRobinGroup:AddDropdown("RoundRobinMobs", {
	Values = {},
	Default = {},
	Multi = true,
	Searchable = true,
	AllowNull = true,
	Text = "Mobs",
	Callback = function()
		RefreshRoundRobinKillSliders()
	end,
})

local AllWorldIds = {}
for _, world in ipairs(Worlds) do
	table.insert(AllWorldIds, world.Id)
end

local AllMobLabels = BuildMobData(AllWorldIds)

for _, label in ipairs(AllMobLabels) do
	RoundRobinGroup:AddSlider("RoundRobinKills_" .. label, {
		Text = "Kills before next - " .. label,
		Default = 3,
		Min = 1,
		Max = 100,
		Rounding = 0,
		Visible = false,
	})
end

RoundRobinGroup:AddSlider("RoundRobinSeconds", {
	Text = "Max Seconds Per Target",
	Default = 60,
	Min = 5,
	Max = 300,
	Rounding = 0,
	Suffix = "s",
})

RoundRobinGroup:AddToggle("RoundRobinFarm", {
	Text = "Round Robin Auto Farm",
	Default = false,
})

function RefreshRoundRobinKillSliders()
	local selected = Options.RoundRobinMobs and Options.RoundRobinMobs.Value


	for _, label in ipairs(AllMobLabels) do
		local slider = Options["RoundRobinKills_" .. label]
		if slider then
			slider:SetVisible(type(selected) == "table" and selected[label] == true)
		end
	end
end

local AutoGroup = Tabs.Main:AddRightGroupbox("Automation")

AutoGroup:AddToggle("AutoClaimAchievements", {
	Text = "Auto Claim Achievements",
	Default = false,
	Callback = function(value)
		if Bridges.AutoClaimAchievementsSet then
			Bridges.AutoClaimAchievementsSet:Fire(value)
		end
	end,
})

AutoGroup:AddToggle("AutoRankUp", {
	Text = "Auto Rank Up",
	Default = false,
	Callback = function(value)
		if Bridges.RankUp then
			Bridges.RankUp:Fire("SetAutoRankUp", value)
		end
	end,
})

AutoGroup:AddToggle("AutoUnlockWorld", {
	Text = "Auto Unlock Next Affordable World",
	Default = false,
})

AutoGroup:AddToggle("AutoClaimRewards", {
	Text = "Auto Claim Time/Week Reward",
	Default = false,
	Callback = function(value)
		if Bridges.AutoClaimRewardsSet then
			Bridges.AutoClaimRewardsSet:Fire(value)
		end
	end,
})

AutoGroup:AddToggle("AutoFuseSwords", {
	Text = "Auto Fuse All Swords",
	Default = false,
})

local StarGroup = Tabs.Secondary:AddLeftGroupbox("Star Hatch")

StarGroup:AddDropdown("StarWorld", {
	Values = WorldLabels,
	Default = { WorldLabels[1] },
	Multi = true,
	Searchable = true,
	AllowNull = true,
	Text = "Star",
})

StarGroup:AddToggle("AutoHatch", {
	Text = "Auto Hatch",
	Default = false,
})

local QuestGroup = Tabs.Secondary:AddLeftGroupbox("Quests")

QuestGroup:AddToggle("AutoNextWorldQuest", {
	Text = "Auto Next World Quest",
	Default = false,
})

QuestGroup:AddToggle("AutoMainQuest", {
	Text = "Auto Main Quest",
	Default = false,
})

QuestGroup:AddDropdown("SideQuest", {
	Values = SideQuestIds,
	Default = { SideQuestConfig.DefaultQuestId },
	Multi = true,
	Searchable = true,
	AllowNull = true,
	Text = "Side Quest",
})

QuestGroup:AddToggle("AutoSideQuest", {
	Text = "Auto Side Quest",
	Default = false,
})

local EquipGroup = Tabs.Secondary:AddRightGroupbox("Auto Equip")

EquipGroup:AddToggle("AutoEquipPets", {
	Text = "Auto Equip Best Pets",
	Default = false,
})

EquipGroup:AddToggle("AutoEquipSwords", {
	Text = "Auto Equip Best Swords",
	Default = false,
})

EquipGroup:AddToggle("AutoEquipAvatars", {
	Text = "Auto Equip Best Avatars",
	Default = false,
	Callback = function(value)
		if Bridges.AutoAvatarBuffSet then
			Bridges.AutoAvatarBuffSet:Fire(value)
		end
	end,
})

EquipGroup:AddToggle("AutoEquipTitan", {
	Text = "Auto Equip Best Titan",
	Default = false,
})

local function GamemodeSelectedEntries(gamemode)
	local entries = {}
	for _, name in ipairs(GetSelected(Options[gamemode.Id .. "Select"], gamemode.Names)) do
		table.insert(entries, gamemode.NameToEntry[name])
	end
	return entries
end

local function IsArenaRunning(gamemode, key)
	local arenas = workspace:FindFirstChild(gamemode.Arenas)
	return (arenas and arenas:FindFirstChild(key)) ~= nil
end

local function GetArenaEnemies(gamemode, key)
	local arenas = workspace:FindFirstChild(gamemode.Arenas)
	local arena = arenas and arenas:FindFirstChild(key)
	local folder = arena and arena:FindFirstChild("Enemies")
	if not folder then
		return {}
	end

	local alive = {}
	for _, enemy in folder:GetChildren() do
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		local root = enemy:FindFirstChild("HumanoidRootPart")
		if humanoid and root and enemy:GetAttribute("EnemyDead") ~= true then
			table.insert(alive, enemy)
		end
	end
	return alive
end

for _, gamemode in ipairs(GAMEMODES) do
	local FarmBox = Tabs.Gamemodes:AddLeftGroupbox(gamemode.FarmTitle)

	FarmBox:AddDropdown(gamemode.Id .. "Select", {
		Values = gamemode.Names,
		Default = {},
		Multi = true,
		Searchable = true,
		AllowNull = true,
		Text = gamemode.SelectText,
	})

	if gamemode.GateRankValues then
		FarmBox:AddDropdown(gamemode.Id .. "GateRank", {
			Values = gamemode.GateRankValues,
			Default = {},
			Multi = true,
			Searchable = true,
			AllowNull = true,
			Text = "Select Gate Rank",
		})
	end

	FarmBox:AddDropdown(gamemode.Id .. "Target", {
		Values = TARGET_MODES,
		Default = TARGET_MODES[1],
		Searchable = true,
		AllowNull = true,
		Text = "Select Mob Priority",
	})

	FarmBox:AddToggle(gamemode.Id .. "AutoFarm", {
		Text = gamemode.AutoFarmText,
		Default = false,
	})

	local LeaveBox = Tabs.Gamemodes:AddRightGroupbox(gamemode.LeaveTitle)

	for _, entry in ipairs(gamemode.Entries) do
		LeaveBox:AddSlider(gamemode.Id .. "Leave" .. entry.Key, {
			Text = entry.Name,
			Default = entry.Total + 1,
			Min = 2,
			Max = entry.Total + 1,
			Rounding = 0,
		})
	end

	LeaveBox:AddToggle(gamemode.Id .. "AutoLeave", {
		Text = gamemode.AutoLeaveText,
		Default = false,
	})
end

local ScheduleGroup = Tabs.Gamemodes:AddLeftGroupbox("Spawn Schedule")

local ScheduleLabels = {}

local STALE_GAMEMODE_SECONDS = 45
local JOIN_CONFIRM_SECONDS = 6

local SPAWN_SCHEDULE = {
	Raid = { [0] = "Random Tier", [10] = "Gate", [20] = "Gate", [30] = "Random Tier", [40] = "Gate", [50] = "Gate" },
	Dungeon = { [0] = "Easy", [15] = "Medium", [30] = "Easy", [45] = "Medium" },
	Trial = { [0] = "Easy", [15] = "Medium", [30] = "Easy", [45] = "Medium" },
}

local function GetSpawnMinutes(id)
	local schedule = SPAWN_SCHEDULE[id]
	if not schedule then
		return nil
	end

	local minutes = {}
	for minute in pairs(schedule) do
		table.insert(minutes, minute)
	end
	table.sort(minutes)
	return minutes
end

local function GetNextSpawn(id)
	local schedule = SPAWN_SCHEDULE[id]
	local minutes = GetSpawnMinutes(id)
	if not minutes then
		return nil
	end

	local now = os.date("*t")
	local remaining, tier

	for _, minute in ipairs(minutes) do
		local seconds = ((minute - now.min) % 60) * 60 - now.sec
		if seconds <= 0 then
			seconds += 3600
		end
		if not remaining or seconds < remaining then
			remaining, tier = seconds, schedule[minute]
		end
	end
	return remaining, tier
end

local function FormatCountdown(seconds)
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

for _, gamemode in ipairs(GAMEMODES) do
	if SPAWN_SCHEDULE[gamemode.Id] then
		ScheduleLabels[gamemode.Id] = ScheduleGroup:AddLabel(gamemode.Id .. ": --:--", true)
	end
end


local function IsInGamemode()
	local ok, inside = pcall(function()
		return TeleportController:IsInGamemode()
	end)
	return ok and inside == true
end

local function IsLoading()
	local ok, loading = pcall(function()
		return TeleportController:IsLoading()
	end)
	return ok and loading == true
end

local GamemodeControllers = {}

local function GetGamemodeController(gamemode)
	if not gamemode.Controller then
		return nil
	end

	if GamemodeControllers[gamemode.Id] == nil then
		local ok, controller = pcall(function()
			return require(ClientFolder[gamemode.Controller])
		end)
		GamemodeControllers[gamemode.Id] = ok and controller or false
	end

	return GamemodeControllers[gamemode.Id] or nil
end

local function CanEnterKey(gamemode, key, isActive)
	local controller = GetGamemodeController(gamemode)
	if not controller then
		return true
	end

	local method = isActive and gamemode.CanJoinActive or gamemode.Afford
	if not method then
		return true
	end

	local ok, allowed = pcall(function()
		return controller[method](controller, key)
	end)
	return not ok or allowed == true
end

local function GateRankAllowed(gamemode, entry)
	if not entry.GateRanks then
		return true
	end

	local selected = GetSelected(Options[gamemode.Id .. "GateRank"], gamemode.GateRankValues or {})
	if #selected == 0 then
		return true
	end

	local announced = GateAnnouncements[entry.Key]
	if not (announced and announced.Rank) then
		return false
	end

	for _, rank in ipairs(selected) do
		if rank == announced.Rank then
			return true
		end
	end
	return false
end

local GachaGroup = Tabs.Gacha:AddLeftGroupbox("Gacha")

GachaGroup:AddDropdown("GachaSelect", {
	Values = GachaNames,
	Default = {},
	Multi = true,
	Searchable = true,
	AllowNull = true,
	Text = "Select Gacha",
})

GachaGroup:AddToggle("AutoSpinGacha", {
	Text = "Auto Spin Gacha",
	Default = false,
})

local SwordGroup = Tabs.Gacha:AddRightGroupbox("Sword")

SwordGroup:AddDropdown("SwordBanner", {
	Values = SwordBannerNames,
	Default = {},
	Multi = true,
	Searchable = true,
	AllowNull = true,
	Text = "Select Banner",
})

SwordGroup:AddToggle("AutoRollSword", {
	Text = "Auto Roll Sword Banner",
	Default = false,
})

local TitanGroup = Tabs.Gacha:AddRightGroupbox("Titan")

TitanGroup:AddDropdown("TitanBanner", {
	Values = TitanBannerNames,
	Default = {},
	Multi = true,
	Searchable = true,
	AllowNull = true,
	Text = "Select Banner",
})

TitanGroup:AddToggle("AutoRollTitan", {
	Text = "Auto Roll Titan Banner",
	Default = false,
})

local PassiveGroup = Tabs.Gacha:AddRightGroupbox("Passive")

PassiveGroup:AddToggle("AutoRollPassive", {
	Text = "Auto Roll Passive",
	Default = false,
})

local WEBHOOK_INVITE = "discord.gg/f3dJhDgyTq"

local WebhookGroup = Tabs.Webhook:AddLeftGroupbox("Webhook")

WebhookGroup:AddInput("WebhookUrl", {
	Text = "Webhook URL",
	Default = "",
	Placeholder = "https://discord.com/api/webhooks/...",
	Finished = true,
})

WebhookGroup:AddInput("WebhookPingId", {
	Text = "Ping ID",
	Default = "",
	Placeholder = "Your Discord user ID",
	Numeric = true,
	Finished = true,
})

WebhookGroup:AddToggle("WebhookOnDisconnect", {
	Text = "Send When Disconnected",
	Default = false,
})

WebhookGroup:AddToggle("WebhookOnDivineGacha", {
	Text = "Send When Divine Gacha",
	Default = false,
})

WebhookGroup:AddToggle("WebhookOnSpawn", {
	Text = "Send When Gamemode Spawns",
	Default = false,
})

local httpRequest = http_request or request or (syn and syn.request)

local function SendWebhook(resultLines)
	local url = Options.WebhookUrl.Value
	if not httpRequest or type(url) ~= "string" or url == "" then
		return
	end

	local pingId = Options.WebhookPingId.Value
	local content = ""
	if type(pingId) == "string" and pingId ~= "" then
		content = "<@" .. pingId .. ">"
	end

	local name = LocalPlayer.Name
	local ok, data = pcall(function()
		return Library.Network.Functions.GetPlayerData:InvokeServer()
	end)
	if ok and type(data) == "table" and data.Rank then
		name = "[" .. tostring(data.Rank) .. "] " .. name
	end

	local payload = HttpService:JSONEncode({
		content = content,
		embeds = {
			{
				title = "Anime Astral Simulator",
				color = 5793266,
				fields = {
					{ name = "Name", value = name, inline = false },
					{ name = "Result", value = table.concat(resultLines, "\n"), inline = false },
				},
				footer = { text = WEBHOOK_INVITE },
				timestamp = DateTime.now():ToIsoDate(),
			},
		},
	})

	task.spawn(function()
		pcall(httpRequest, {
			Url = url,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = payload,
		})
	end)
end

task.spawn(function()
	local GachaResult = getBridge("GachaResult")
	if GachaResult then
		GachaResult:Connect(function(success, _, result)
			if not (success and type(result) == "table") then
				return
			end
			if not Toggles.WebhookOnDivineGacha.Value then
				return
			end

			local gacha = GachaConfig:GetGacha(result.GachaKey)
			local gachaName = gacha and gacha.Name or tostring(result.GachaKey)

			local rolls = type(result.Rolls) == "table" and result.Rolls or { result }
			for _, roll in ipairs(rolls) do
				if type(roll) == "table" and roll.RolledRarity == "Divine" then
					local item = roll.RolledItem
					local itemName = item and item.Name or "Divine"

					SendWebhook({
						"Divine Gacha - Obtained",
						"- Gacha: " .. gachaName,
						"- Power: " .. itemName,
						"- Rarity: Divine",
					})
					break
				end
			end
		end)
	end
end)

task.spawn(function()
	local LastSpawnMinute = {}

	while true do
		if ObsidianLibrary.Unloaded then
			break
		end

		local minute = os.date("*t").min

		for _, gamemode in ipairs(GAMEMODES) do
			local schedule = SPAWN_SCHEDULE[gamemode.Id]
			if schedule then
				local label = ScheduleLabels[gamemode.Id]
				if label then
					local remaining, tier = GetNextSpawn(gamemode.Id)
					label:SetText(gamemode.Id .. ": " .. tostring(tier) .. " in " .. FormatCountdown(remaining))
				end

				if schedule[minute] and LastSpawnMinute[gamemode.Id] ~= minute then
					LastSpawnMinute[gamemode.Id] = minute

					if Toggles.WebhookOnSpawn.Value then
						SendWebhook({
							"Spawned - " .. gamemode.Id,
							"- Tier: " .. tostring(schedule[minute]),
							"- Time: " .. os.date("%H:%M"),
						})
					end
				end
			end
		end

		task.wait(1)
	end
end)

local SwapGroup = Tabs.Secondary:AddRightGroupbox("Load Out Swap")

local SwapContexts = {
	{ Index = "SwapDungeon", Text = "Swap At Dungeon", Mode = "Dungeon" },
	{ Index = "SwapDefense", Text = "Swap At Defense", Mode = "Defense" },
	{ Index = "SwapStarSummon", Text = "Swap At Star Summon", Mode = "StarSummon" },
	{ Index = "SwapRaid", Text = "Swap At Raid", Mode = "Raid" },
	{ Index = "SwapTrial", Text = "Swap At Trial", Mode = "Trial" },
	{ Index = "SwapNormalFarm", Text = "Swap At Normal Farm", Mode = "NormalFarm" },
}

for _, context in ipairs(SwapContexts) do
	SwapGroup:AddDropdown(context.Index, {
		Values = LOADOUT_STATS,
		Default = { "None" },
		Multi = true,
		Searchable = true,
		AllowNull = true,
		Text = context.Text,
	})
end

SwapGroup:AddToggle("AutoSwapLoadout", {
	Text = "Auto Swap LoadOut",
	Default = false,
})

ObsidianLibrary.ToggleKeybind = Options.MenuKeybind

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu")

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
	Default = "RightShift",
	NoUI = true,
	Text = "Menu keybind",
})

MenuGroup:AddToggle("AntiAFK", {
	Text = "Anti-AFK",
	Default = true,
})

local HasAutoHidden = false

local function AutoHideOnce()
	if HasAutoHidden or not Toggles.AutoHideUI.Value then
		return
	end
	HasAutoHidden = true
	Window:Toggle(false)
end

MenuGroup:AddToggle("AutoHideUI", {
	Text = "Auto Hide UI",
	Default = false,
	Callback = AutoHideOnce,
})

local ToggleGui = Instance.new("ScreenGui")
ToggleGui.Name = "OuroborosToggle"
ToggleGui.ResetOnSpawn = false
ToggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ToggleGui.DisplayOrder = 999

if syn and syn.protect_gui then
	syn.protect_gui(ToggleGui)
end
ToggleGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local ToggleButton = Instance.new("ImageButton")
ToggleButton.Name = "Toggle"
ToggleButton.Size = UDim2.fromOffset(56, 56)
ToggleButton.Position = UDim2.fromOffset(20, 20)
ToggleButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
ToggleButton.BorderSizePixel = 0
ToggleButton.AutoButtonColor = false
ToggleButton.Image = "rbxassetid://18657887261"
ToggleButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.ScaleType = Enum.ScaleType.Fit
ToggleButton.Parent = ToggleGui

local TogglePadding = Instance.new("UIPadding")
TogglePadding.PaddingTop = UDim.new(0, 10)
TogglePadding.PaddingBottom = UDim.new(0, 10)
TogglePadding.PaddingLeft = UDim.new(0, 10)
TogglePadding.PaddingRight = UDim.new(0, 10)
TogglePadding.Parent = ToggleButton

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = Color3.fromRGB(60, 60, 60)
ToggleStroke.Thickness = 1
ToggleStroke.Parent = ToggleButton

local UserInputService = game:GetService("UserInputService")

local dragInput
local dragMoved = false
local dragStart
local startPosition

local function SyncToggleVisual()
	ToggleButton.ImageTransparency = ObsidianLibrary.Toggled and 0 or 0.45
end

ToggleButton.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	dragInput = input
	dragMoved = false
	dragStart = input.Position
	startPosition = ToggleButton.Position
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragInput then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	local delta = input.Position - dragStart
	if delta.Magnitude > 4 then
		dragMoved = true
	end

	if dragMoved then
		ToggleButton.Position = UDim2.fromOffset(
			startPosition.X.Offset + delta.X,
			startPosition.Y.Offset + delta.Y
		)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if not dragInput or input.UserInputType ~= dragInput.UserInputType then
		return
	end

	dragInput = nil

	if not dragMoved then
		ObsidianLibrary:Toggle()
		SyncToggleVisual()
	end
end)

ObsidianLibrary:OnUnload(function()
	ToggleGui:Destroy()
end)

MenuGroup:AddButton("Unload", function()
	ObsidianLibrary:Unload()
end)

ObsidianLibrary:OnUnload(function()
	print("Unloaded!")
end)

local PRIORITY_FEATURES = {
	{ Id = "Trial", Text = "Time Trial" },
	{ Id = "Defense", Text = "Defense" },
	{ Id = "Raid", Text = "Raid" },
	{ Id = "Dungeon", Text = "Dungeon" },
	{ Id = "Quest", Text = "Auto Quest" },
	{ Id = "Star", Text = "Auto Open Star" },
	{ Id = "Farm", Text = "Auto Farm" },
}

local PriorityGroup = Tabs.Priority:AddLeftGroupbox("Feature Priority")

PriorityGroup:AddToggle("PriorityEnabled", {
	Text = "Enable Priority System",
	Default = true,
})

PriorityGroup:AddLabel("1 = Highest Priority, 7 = Lowest Priority", true)
PriorityGroup:AddLabel("1 = Ưu tiên cao nhất, 7 = Ưu tiên thấp nhất", true)
PriorityGroup:AddLabel("1 = ลำดับความสำคัญสูงสุด, 7 = ลำดับความสำคัญต่ำสุด", true)
PriorityGroup:AddLabel("1 = Pinakamataas na Prayoridad, 7 = Pinakamababang Prayoridad", true)

for rank, feature in ipairs(PRIORITY_FEATURES) do
	PriorityGroup:AddSlider("Priority" .. feature.Id, {
		Text = feature.Text,
		Default = rank,
		Min = 1,
		Max = #PRIORITY_FEATURES,
		Rounding = 0,
	})
end

local function IsFeatureEligible(id)
	if id == "Quest" then
		return Toggles.AutoMainQuest.Value or Toggles.AutoNextWorldQuest.Value or Toggles.AutoSideQuest.Value
	elseif id == "Star" then
		return Toggles.AutoHatch.Value
	elseif id == "Farm" then
		return Toggles.AutoFarm.Value or Toggles.RoundRobinFarm.Value
	end

	local toggle = Toggles[id .. "AutoFarm"]
	if not (toggle and toggle.Value) then
		return false
	end

	for _, gamemode in ipairs(GAMEMODES) do
		if gamemode.Id == id then
			return #GamemodeSelectedEntries(gamemode) > 0
		end
	end
	return false
end

local function GetActiveFeature()
	if ActiveGamemode then
		return ActiveGamemode.Id
	end

	local best, bestRank
	for _, feature in ipairs(PRIORITY_FEATURES) do
		if IsFeatureEligible(feature.Id) then
			local rank = Options["Priority" .. feature.Id].Value
			if not bestRank or rank < bestRank then
				best, bestRank = feature.Id, rank
			end
		end
	end
	return best
end

local function IsAllowed(id)
	if not Toggles.PriorityEnabled.Value then
		return true
	end
	return GetActiveFeature() == id
end

task.spawn(function()
	for _, gamemode in ipairs(GAMEMODES) do
		local ended = getBridge(gamemode.Ended)
		if ended then
			ended:Connect(function()
				if not gamemode.Status then
					GamemodeLeftKeys[gamemode.Id] = {}
				end

				if ActiveGamemode and ActiveGamemode.Id == gamemode.Id then
					ActiveGamemode = nil
				end
			end)
		end

		local state = Bridges[gamemode.State]
		if state then
			state:Connect(function(payload)
				if type(payload) ~= "table" then
					return
				end

				if not (ActiveGamemode and ActiveGamemode.Id == gamemode.Id) then
					return
				end

				ActiveGamemode.LastState = os.clock()

				if not Toggles[gamemode.Id .. "AutoLeave"].Value then
					return
				end

				local counter = tonumber(payload[gamemode.Counter])
				local limit = Options[gamemode.Id .. "Leave" .. ActiveGamemode.Key]
				if not (counter and limit) then
					return
				end

				if counter >= limit.Value and Bridges[gamemode.Leave] then
					Bridges[gamemode.Leave]:Fire()
					GamemodeLeftKeys[gamemode.Id][ActiveGamemode.Key] = true
					ActiveGamemode = nil
				end
			end)
		end
	end
end)

task.spawn(function()
	while true do
		if ObsidianLibrary.Unloaded then
			break
		end

		if Toggles.AutoSpinGacha.Value and Bridges.GachaRoll then
			local ok, data = pcall(function()
				return Library.Network.Functions.GetPlayerData:InvokeServer()
			end)
			if ok and type(data) == "table" and type(data.ActiveGachas) == "table" then
				ActiveGachas = data.ActiveGachas
			end

			for _, name in ipairs(GetSelected(Options.GachaSelect, GachaNames)) do
				local key = GachaNameToKey[name]
				if key and ActiveGachas[key] ~= GachaMaxRarity[key] then
					Bridges.GachaRoll:Fire(key)
				end
			end
		end

		if Toggles.AutoRollSword.Value and Bridges.SwordRoll then
			for _, name in ipairs(GetSelected(Options.SwordBanner, SwordBannerNames)) do
				Bridges.SwordRoll:Fire(SwordBannerToKey[name])
			end
		end

		if Toggles.AutoRollTitan.Value and Bridges.TitanRoll then
			for _, name in ipairs(GetSelected(Options.TitanBanner, TitanBannerNames)) do
				Bridges.TitanRoll:Fire(TitanBannerToKey[name])
			end
		end

		if Toggles.AutoRollPassive.Value and Bridges.PlayerPassiveRoll then
			Bridges.PlayerPassiveRoll:Fire()
		end

		task.wait(1)
	end
end)

task.spawn(function()
	local CoreGui = game:GetService("CoreGui")
	local ok, overlay = pcall(function()
		return CoreGui:WaitForChild("RobloxPromptGui"):WaitForChild("promptOverlay")
	end)
	if not ok or not overlay then
		return
	end

	overlay.ChildAdded:Connect(function(child)
		if ObsidianLibrary.Unloaded then
			return
		end
		if not Toggles.WebhookOnDisconnect.Value then
			return
		end
		if not child.Name:find("ErrorPrompt") then
			return
		end

		local reason = "Connection lost"
		local label = child:FindFirstChild("ErrorMessage", true)
		if label and label:IsA("TextLabel") and label.Text ~= "" then
			reason = label.Text
		end

		SendWebhook({
			"Disconnected",
			"- Reason: " .. reason,
		})
	end)
end)

task.spawn(function()
	while true do
		if ObsidianLibrary.Unloaded then
			break
		end

		for _, gamemode in ipairs(GAMEMODES) do
			if Toggles[gamemode.Id .. "AutoFarm"].Value and IsAllowed(gamemode.Id) then
				local entries = GamemodeSelectedEntries(gamemode)

				if ActiveGamemode and ActiveGamemode.Id == gamemode.Id then
					local root = GetRoot()
					local enemies = GetArenaEnemies(gamemode, ActiveGamemode.Key)

					if os.clock() - ActiveGamemode.LastState > STALE_GAMEMODE_SECONDS and not IsInGamemode() then
						ActiveGamemode = nil
					elseif root and #enemies > 0 then
						local target = PickTarget(enemies, root, Options[gamemode.Id .. "Target"].Value)

						if target then
							local targetRoot = target:FindFirstChild("HumanoidRootPart")
							if targetRoot then
								root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 5)
							end
							if Bridges.Click then
								Bridges.Click:Fire()
							end
						end
					end
				elseif not ActiveGamemode and #entries > 0 and not IsInGamemode() and not IsLoading() then
					local index = GamemodeJoinIndex[gamemode.Id] or 1
					if index > #entries then
						index = 1
					end

					for offset = 0, #entries - 1 do
						local slot = ((index - 1 + offset) % #entries) + 1
						local entry = entries[slot]
						local isActive = gamemode.Status and GamemodeActiveKeys[gamemode.Id][entry.Key] == true
						local leftBehind = GamemodeLeftKeys[gamemode.Id][entry.Key] == true

						if leftBehind and not gamemode.Status and not IsArenaRunning(gamemode, entry.Key) then
							GamemodeLeftKeys[gamemode.Id][entry.Key] = nil
							leftBehind = false
						end

						local canEnter
						if gamemode.Status then
							canEnter = CanEnterKey(gamemode, entry.Key, isActive)
						else
							canEnter = IsArenaRunning(gamemode, entry.Key)
						end

						if GateRankAllowed(gamemode, entry) and Bridges[gamemode.Join] and not leftBehind and canEnter then
							local action = "Join"
							if gamemode.Status and not isActive then
								action = "Create"
							end

							Bridges[gamemode.Join]:Fire(action, entry.Key)

							local deadline = os.clock() + JOIN_CONFIRM_SECONDS
							while os.clock() < deadline do
								if IsInGamemode() or IsArenaRunning(gamemode, entry.Key) then
									ActiveGamemode = { Id = gamemode.Id, Key = entry.Key, LastState = os.clock() }
									GamemodeJoinIndex[gamemode.Id] = slot + 1
									break
								end
								task.wait(0.25)
							end

							break
						end
					end
				end
			end
		end

		task.wait(0.1)
	end
end)

task.spawn(function()
	local lastStat

	while true do
		if ObsidianLibrary.Unloaded then
			break
		end

		if Toggles.AutoSwapLoadout.Value and Bridges.EquipBestLoadout then
			local mode = ActiveMode
			if not mode and Toggles.AutoHatch.Value then
				mode = "StarSummon"
			end
			if not mode then
				mode = "NormalFarm"
			end

			local stat
			for _, context in ipairs(SwapContexts) do
				if context.Mode == mode then
					stat = GetFirstSelected(Options[context.Index], LOADOUT_STATS)
					break
				end
			end

			if stat and stat ~= "None" and stat ~= lastStat then
				Bridges.EquipBestLoadout:Fire(stat)
				lastStat = stat
			end
		else
			lastStat = nil
		end

		task.wait(1)
	end
end)

task.spawn(function()
	while true do
		if ObsidianLibrary.Unloaded then
			break
		end

		local doFarm = Toggles.AutoFarm.Value and not Toggles.RoundRobinFarm.Value and IsAllowed("Farm")
		local fastClick = Toggles.FastAutoClick.Value

		if (doFarm or fastClick) and Bridges.Click then
			local root = GetRoot()
			if root then
				if doFarm then
					local selectedWorldId = GetSelectedWorldId()
					local currentWorldId = GetCurrentWorldId()

					if Toggles.TeleportBeforeFarm.Value and Bridges.RequestChangeWorld and selectedWorldId then
						if currentWorldId ~= selectedWorldId then
							Bridges.RequestChangeWorld:Fire(selectedWorldId)
							task.wait(2)
							currentWorldId = GetCurrentWorldId()
						end
					end

					currentWorldId = currentWorldId or selectedWorldId

					if currentWorldId then
						local mode = Options.FarmMode.Value or "Nearest"
						local target

						if mode == "Selected" then
							local names = GetSelectedMobNames()
							if next(names) then
								target = GetNearestEnemy(currentWorldId, root, names)
							end
						elseif mode == "All" then
							local list = GetEnemyList(currentWorldId)
							if #list > 0 then
								target = list[math.random(1, #list)]
							end
						else
							target = GetNearestEnemy(currentWorldId, root)
						end

						if target then
							local targetRoot = target:FindFirstChild("HumanoidRootPart")
							if targetRoot then
								root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 5)
							end
						end
					end
				end

				Bridges.Click:Fire()
			end
		end

		task.wait(Toggles.FastAutoClick.Value and 0.05 or 0.15)
	end
end)

local function BuildRotation()
	local rotation = {}

	for _, label in ipairs(GetSelected(Options.RoundRobinWorlds, WorldLabels)) do
		local worldId = WorldLabelToId[label]
		local names = {}

		for mobLabel, active in pairs(Options.RoundRobinMobs.Value) do
			if active and RoundRobinMobMap[mobLabel] then
				names[RoundRobinMobMap[mobLabel]] = true
			end
		end

		local list = EnemyConfig:GetEnemiesByWorld(worldId)
		if list then
			local worldMobs = {}
			for _, enemy in pairs(list) do
				if enemy and enemy.Name and names[enemy.Name] then
					local difficulty = tostring(enemy.Type or "Unknown")
					table.insert(worldMobs, {
						WorldId = worldId,
						Name = enemy.Name,
						Label = enemy.Name .. " | " .. difficulty,
						Rank = DifficultyRank[difficulty] or #DIFFICULTIES + 1,
					})
				end
			end

			table.sort(worldMobs, function(a, b)
				if a.Rank ~= b.Rank then
					return a.Rank < b.Rank
				end
				return a.Name < b.Name
			end)

			for _, entry in ipairs(worldMobs) do
				table.insert(rotation, entry)
			end
		end
	end

	return rotation
end

local function IsEnemyDead(enemy)
	if not enemy.Parent then
		return true
	end
	if enemy:GetAttribute("EnemyDead") == true then
		return true
	end

	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health <= 0
end

task.spawn(function()
	local index = 1
	local dwellStart = 0
	local currentKey
	local kills = 0
	local engaged

	while true do
		if ObsidianLibrary.Unloaded then
			break
		end

		if Toggles.RoundRobinFarm.Value and IsAllowed("Farm") and Bridges.Click then
			local rotation = BuildRotation()

			if #rotation > 0 then
				if index > #rotation then
					index = 1
				end

				local target = rotation[index]
				local key = target.WorldId .. "|" .. target.Name

				if key ~= currentKey then
					currentKey = key
					dwellStart = os.clock()
					kills = 0
					engaged = nil
				end

				local root = GetRoot()
				local currentWorldId = GetCurrentWorldId()

				if root and currentWorldId ~= target.WorldId and Bridges.RequestChangeWorld then
					Bridges.RequestChangeWorld:Fire(target.WorldId)
					task.wait(2)
					currentWorldId = GetCurrentWorldId()
				end

				if engaged and IsEnemyDead(engaged) then
					kills += 1
					engaged = nil
				end

				local enemy = root and GetNearestEnemy(target.WorldId, root, { [target.Name] = true })

				if enemy then
					engaged = enemy

					local enemyRoot = enemy:FindFirstChild("HumanoidRootPart")
					if enemyRoot then
						root.CFrame = enemyRoot.CFrame * CFrame.new(0, 0, 5)
					end
					Bridges.Click:Fire()
				end

				local killSlider = Options["RoundRobinKills_" .. target.Label]
				local killTarget = killSlider and killSlider.Value or 3
				local timedOut = os.clock() - dwellStart >= Options.RoundRobinSeconds.Value

				if kills >= killTarget or timedOut then
					index += 1
					currentKey = nil
				end
			end
		end

		task.wait(Toggles.FastAutoClick.Value and 0.05 or 0.15)
	end
end)

task.spawn(function()
	while true do
		if ObsidianLibrary.Unloaded then
			break
		end

		if Toggles.AutoFuseSwords.Value and Bridges.FuseAllSwords then
			Bridges.FuseAllSwords:Fire()
		end

		if Toggles.AutoUnlockWorld.Value and Bridges.BuyWorld then
			for _, world in ipairs(Worlds) do
				local unlocked = false
				pcall(function()
					unlocked = TeleportController:IsWorldUnlocked(world.Id)
				end)
				if not unlocked then
					Bridges.BuyWorld:Fire(world.Id)
					break
				end
			end
		end

		if Toggles.AutoEquipPets.Value and Bridges.EquipBest then
			Bridges.EquipBest:Fire()
		end

		if Toggles.AutoEquipSwords.Value and Bridges.EquipBestSword then
			Bridges.EquipBestSword:Fire()
		end

		if Toggles.AutoEquipTitan.Value and Bridges.EquipBestTitan then
			Bridges.EquipBestTitan:Fire()
		end

		if Toggles.AutoHatch.Value and IsAllowed("Star") and Bridges.OpenEgg then
			for _, label in ipairs(GetSelected(Options.StarWorld, WorldLabels)) do
				local eggKey = "World" .. tostring(WorldLabelToId[label])
				local actions
				pcall(function()
					actions = AutoActionController:GetActionsForEgg(eggKey)
				end)
				Bridges.OpenEgg:Fire(eggKey, actions)
			end
		end

		local questAllowed = IsAllowed("Quest")

		if Toggles.AutoMainQuest.Value and questAllowed and Bridges.QuestCollect then
			Bridges.QuestCollect:Fire()
		end

		if Toggles.AutoNextWorldQuest.Value and questAllowed and Bridges.GlobalQuestClaimAll then
			Bridges.GlobalQuestClaimAll:Fire()
		end

		if Toggles.AutoSideQuest.Value and questAllowed and Bridges.SideQuestAcceptRequest then
			for _, questId in ipairs(GetSelected(Options.SideQuest, SideQuestIds)) do
				Bridges.SideQuestAcceptRequest:Fire(questId)
			end
		end

		task.wait(1)
	end
end)

LocalPlayer.Idled:Connect(function()
	if ObsidianLibrary.Unloaded then
		return
	end
	if not Options.AntiAFK.Value then
		return
	end
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

task.spawn(function()
	while true do
		task.wait(600)

		if ObsidianLibrary.Unloaded then
			break
		end

		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if humanoid and humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end)

ThemeManager:SetLibrary(ObsidianLibrary)
SaveManager:SetLibrary(ObsidianLibrary)

ThemeManager:SetFolder("OuroborosHub")
SaveManager:SetFolder("OuroborosHub/astral-simulator")

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SaveDefault("Mint")

ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

ThemeManager:LoadDefault()
SaveManager:LoadAutoloadConfig()

AutoHideOnce()

SyncToggleVisual()
