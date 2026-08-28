local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

if getgenv then
    getgenv().gethui = function()
        return LocalPlayer:WaitForChild("PlayerGui")
    end
end

local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local BusinessFolder = StarterPlayerScripts:WaitForChild("Business")

local OnClientGameEvent = require(ReplicatedStorage:WaitForChild("Business"):WaitForChild("OnClientGameEvent"))
local MainBusiness = require(ReplicatedStorage:WaitForChild("Business"):WaitForChild("MainBusiness"))
local C_Data = require(BusinessFolder:WaitForChild("C_Data"))
local BusinessBase = require(BusinessFolder:WaitForChild("BusinessBase"))
local PlayConfig = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("PlayConfig"))
local BigNumber = require(ReplicatedStorage:WaitForChild("Framework"):WaitForChild("X0000"):WaitForChild("BigNumber"))

local UNIT = "\229\141\149\228\189\141"
local STAT_UPGRADE = "\228\186\186\231\137\169\229\177\158\230\128\167\229\141\135\231\186\167"
local AUTOROLL = "\232\135\170\229\138\168\230\138\189\229\143\150\229\141\149\228\189\141_"
local AUTOROLL_OPEN = AUTOROLL .. "\230\152\175\229\144\166\229\188\128\229\144\175"
local AUTOROLL_BUY = AUTOROLL .. "\230\152\175\229\144\166\232\180\173\228\185\176"
local AUTOROLL_RARITY = AUTOROLL .. "\231\168\128\230\156\137\229\186\166"
local AUTOROLL_MUTATION = AUTOROLL .. "\230\157\144\232\180\168\231\168\128\230\156\137\229\186\166"
local EQUIP_BEST_UNIT = "\232\163\133\229\164\135\230\156\128\229\165\189_" .. UNIT
local MERGE_UNITS = "\229\144\136\230\136\144\229\141\149\228\189\141_\230\152\159\230\152\159\231\173\137\231\186\167"
local REBIRTH = "\233\135\141\231\148\159"
local PLACE_UNIT = "\230\148\190\231\189\174_" .. UNIT
local DAOJU = "\233\129\147\229\133\183"
local DAY_GIFT = "\230\175\143\230\151\165\229\165\150\229\138\177"
local DAY_BOX = "\230\175\143\230\151\165\229\174\157\231\174\177"
local START_CRAFT = "\229\188\128\229\167\139\229\136\182\228\189\156"
local CLAIM_CRAFT = "\233\162\134\229\143\150\229\136\182\228\189\156"
local USE_ITEM_TYPE = 2

local UNIVERSAL_CD = 0.35

local GAME_NAME = "Mutant Plants: Base Defense"
local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"
local RSCRIPTS_LINK = "https://rscripts.net/@Ouroboros"

local repo = "https://raw.githubusercontent.com/joustingmatch/ObsidianUltra/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

pcall(function()
    Library.ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end)

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

local GREEN = "#7fd47f"
local BLUE = "#6ec1ff"
local ORANGE = "#e8a34d"
local GREY = "#8b93a3"

local function isOn(name)
    if Library.Unloaded then
        return false
    end
    local toggle = Toggles[name]
    return type(toggle) == "table" and toggle.Value == true
end

local function getNumber(name, fallback)
    local option = Options[name]
    if type(option) ~= "table" then
        return fallback
    end
    return tonumber(option.Value) or fallback
end

local function getMulti(name)
    local option = Options[name]
    if type(option) ~= "table" then
        return {}
    end
    return option.Value or {}
end

local function hasAny(map)
    for _, enabled in pairs(map) do
        if enabled then
            return true
        end
    end
    return false
end

local function getData()
    local ok, data = pcall(C_Data.GetData)
    if ok then
        return data
    end
    return nil
end

local function getServerData()
    local data = getData()
    return data and data.serverData
end

local rarityNames = {}
local rarityIdByName = {}
for index, cfg in PlayConfig.allRarity do
    rarityNames[index] = cfg.name
    rarityIdByName[cfg.name] = cfg.id
end

local mutationNames = {}
local mutationIdByName = {}
for index, cfg in PlayConfig.allMaterialRarity do
    mutationNames[index] = cfg.name
    mutationIdByName[cfg.name] = cfg.id
end

local upgradeNames = {}
local upgradeIdByName = {}
for index, cfg in PlayConfig.allStatUpgrade do
    upgradeNames[index] = cfg.title
    upgradeIdByName[cfg.title] = cfg.id
end

local plantNames = {}
local plantIdByName = {}
local plantIndexByName = {}
for _, cfg in PlayConfig.allUnit do
    if cfg and cfg.name and (cfg.MaterialRarity == 1 or cfg.MaterialRarity == nil) and not plantIdByName[cfg.name] then
        plantNames[#plantNames + 1] = cfg.name
        plantIdByName[cfg.name] = cfg.id
        plantIndexByName[cfg.name] = cfg.index
    end
end

local fruitNames = {}
local fruitIdByName = {}
for _, cfg in PlayConfig.allUseItem do
    if cfg and cfg.name and cfg.useType == 1 then
        fruitNames[#fruitNames + 1] = cfg.name
        fruitIdByName[cfg.name] = cfg.id
    end
end

local craftNames = {}
local craftIdByName = {}
for _, cfg in PlayConfig.allProduction do
    local label = "Craft " .. tostring(cfg.id)
    if cfg.award then
        if cfg.award.itemEnum == UNIT then
            local unitCfg = PlayConfig.allUnit[cfg.award.value]
            if unitCfg and unitCfg.name then
                label = unitCfg.name
            end
        elseif cfg.award.itemEnum == DAOJU then
            local itemCfg = PlayConfig.allUseItem[cfg.award.value]
            if itemCfg and itemCfg.name then
                label = itemCfg.name
            end
        end
    end
    if craftIdByName[label] then
        label = label .. " #" .. tostring(cfg.id)
    end
    craftNames[#craftNames + 1] = label
    craftIdByName[label] = cfg.id
end

local plantCraftByUnitId = {}
for _, cfg in PlayConfig.allProduction do
    if cfg.award and cfg.award.itemEnum == UNIT then
        plantCraftByUnitId[cfg.award.value] = cfg.id
    end
end

local unitStarMax = PlayConfig.unitStarMax

local function selectedIdSet(optionName, idByName)
    local set = {}
    for name, enabled in pairs(getMulti(optionName)) do
        if enabled and idByName[name] then
            set[idByName[name]] = true
        end
    end
    return set
end

local function isSceneUnit(serverData, gid)
    for _, sceneGid in serverData.sceneUnit do
        if sceneGid == gid then
            return true
        end
    end
    return false
end

local function isEquippedUnit(serverData, gid)
    local hand = serverData.hand
    for index = 1, math.min(PlayConfig.handShowSize, #hand) do
        if hand[index] == gid then
            return true
        end
    end
    return false
end

local Window = Library:CreateWindow({
    Title = "Ouroboros Hub",
    Footer = DISCORD_INVITE .. " | " .. GAME_NAME,
    Icon = 18657887261,
    NotifySide = "Right",
    ShowCustomCursor = false,
})

local Tabs = {
    Info = Window:AddTab("Info", "info"),
    Main = Window:AddTab("Main", "gamepad-2"),
    Progress = Window:AddTab("Progress", "trending-up"),
    Player = Window:AddTab("Player", "user"),
    Settings = Window:AddTab("Settings", "settings"),
}

Tabs.Roll = Tabs.Main:AddSubTab("Roll", "dices")
Tabs.Units = Tabs.Main:AddSubTab("Units", "sprout")
Tabs.Shop = Tabs.Main:AddSubTab("Shop", "shopping-bag")
Tabs.Match = Tabs.Main:AddSubTab("Match", "swords")

local function AddDiscordButton(Tab)
    local DiscordGroup = Tab:AddLeftGroupbox("Discord", "message-circle", true, false, true)
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
    if Tab ~= Tabs.Main then
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

FeaturesGroup:AddLabel(colored("Auto Roll with Mutation Filters", BLUE), true)
FeaturesGroup:AddLabel(colored("Auto Lock by Rarity", GREEN), true)
FeaturesGroup:AddLabel(colored("Auto Sell by Rarity", ORANGE), true)
FeaturesGroup:AddLabel(colored("Auto Merge", BLUE), true)
FeaturesGroup:AddLabel(colored("Auto Equip Best", GREEN), true)
FeaturesGroup:AddLabel(colored("Auto Replace", BLUE), true)
FeaturesGroup:AddLabel(colored("Auto Buy / Delete Plants", GREEN), true)
FeaturesGroup:AddLabel(colored("Auto Buy / Use Fruit", ORANGE), true)
FeaturesGroup:AddLabel(colored("Auto Craft", BLUE), true)
FeaturesGroup:AddLabel(colored("Auto Claim Mission / Daily", GREEN), true)
FeaturesGroup:AddLabel(colored("Auto Get All Plants", ORANGE), true)
FeaturesGroup:AddLabel(colored("Auto Start / Stop at Wave", ORANGE), true)
FeaturesGroup:AddLabel(colored("Auto Rebirth", ORANGE), true)
FeaturesGroup:AddLabel(colored("Auto Upgrades", GREEN), true)
FeaturesGroup:AddLabel(colored("Player Movement", GREY), true)

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

local RollGroup = Tabs.Roll:AddLeftGroupbox("Auto Roll", "dices")

RollGroup:AddToggle("AutoRoll", {
    Text = "Auto Roll",
    Default = false,
})

RollGroup:AddToggle("AutoRollBuy", {
    Text = "Auto Buy Rolls",
    Default = false,
})

local RollFilterGroup = Tabs.Roll:AddRightGroupbox("Keep Filters", "filter")

RollFilterGroup:AddDropdown("RollRarities", {
    Values = rarityNames,
    Multi = true,
    Searchable = true,
    AllowNull = true,
    Text = "Rarities",
    Default = {},
})

RollFilterGroup:AddDropdown("RollMutations", {
    Values = mutationNames,
    Multi = true,
    Searchable = true,
    AllowNull = true,
    Text = "Mutations",
    Default = {},
})

local LockGroup = Tabs.Units:AddLeftGroupbox("Auto Lock", "lock")

LockGroup:AddToggle("AutoLock", {
    Text = "Auto Lock",
    Default = false,
})

LockGroup:AddDropdown("LockRarities", {
    Values = rarityNames,
    Multi = true,
    Searchable = true,
    AllowNull = true,
    Text = "Rarities",
    Default = {},
})

LockGroup:AddDropdown("LockMutations", {
    Values = mutationNames,
    Multi = true,
    Searchable = true,
    AllowNull = true,
    Text = "Mutations",
    Default = {},
})

local SellGroup = Tabs.Units:AddLeftGroupbox("Auto Sell", "trash-2")

SellGroup:AddToggle("AutoSell", {
    Text = "Auto Sell",
    Default = false,
})

SellGroup:AddDropdown("SellRarities", {
    Values = rarityNames,
    Multi = true,
    Searchable = true,
    AllowNull = true,
    Text = "Rarities",
    Default = {},
})

SellGroup:AddDropdown("SellMutations", {
    Values = mutationNames,
    Multi = true,
    Searchable = true,
    AllowNull = true,
    Text = "Mutations",
    Default = {},
})

SellGroup:AddSlider("SellMaxStar", {
    Text = "Max Star",
    Default = unitStarMax,
    Min = 0,
    Max = unitStarMax,
    Rounding = 0,
})

local UnitGroup = Tabs.Units:AddRightGroupbox("Units", "sprout")

UnitGroup:AddToggle("AutoMerge", {
    Text = "Auto Merge",
    Default = false,
})

UnitGroup:AddToggle("AutoEquipBest", {
    Text = "Auto Equip Best",
    Default = false,
})

UnitGroup:AddToggle("AutoReplace", {
    Text = "Auto Replace",
    Default = false,
})

local BuyPlantGroup = Tabs.Shop:AddLeftGroupbox("Buy Plant", "sprout")

BuyPlantGroup:AddToggle("AutoBuyPlant", {
    Text = "Auto Buy Plant",
    Default = false,
})

BuyPlantGroup:AddDropdown("BuyPlants", {
    Values = plantNames,
    Multi = true,
    Searchable = true,
    AllowNull = true,
    Text = "Plants",
    Default = {},
})

local DeletePlantGroup = Tabs.Shop:AddLeftGroupbox("Delete Plant", "trash-2")

DeletePlantGroup:AddToggle("AutoDeletePlant", {
    Text = "Auto Delete Plant",
    Default = false,
})

DeletePlantGroup:AddDropdown("DeletePlants", {
    Values = plantNames,
    Multi = true,
    Searchable = true,
    AllowNull = true,
    Text = "Plants",
    Default = {},
})

local FruitGroup = Tabs.Shop:AddRightGroupbox("Fruit", "apple")

FruitGroup:AddToggle("AutoBuyFruit", {
    Text = "Auto Buy Fruit",
    Default = false,
})

FruitGroup:AddToggle("AutoUseFruit", {
    Text = "Auto Use Fruit",
    Default = false,
})

FruitGroup:AddDropdown("Fruits", {
    Values = fruitNames,
    Multi = true,
    Searchable = true,
    AllowNull = true,
    Text = "Fruits",
    Default = {},
})

local CraftGroup = Tabs.Shop:AddRightGroupbox("Craft", "hammer")

CraftGroup:AddToggle("AutoCraft", {
    Text = "Auto Craft",
    Default = false,
})

CraftGroup:AddDropdown("CraftRecipes", {
    Values = craftNames,
    Multi = true,
    Searchable = true,
    AllowNull = true,
    Text = "Recipes",
    Default = {},
})

CraftGroup:AddSlider("CraftSize", {
    Text = "Craft Size",
    Default = 1,
    Min = 1,
    Max = 20,
    Rounding = 0,
})

local MatchGroup = Tabs.Match:AddRightGroupbox("Match", "swords")

MatchGroup:AddToggle("AutoStart", {
    Text = "Auto Start",
    Default = false,
})

MatchGroup:AddToggle("AutoStopWave", {
    Text = "Auto Stop at Wave",
    Default = false,
})

MatchGroup:AddSlider("StopWave", {
    Text = "Stop Wave",
    Default = 25,
    Min = 1,
    Max = 200,
    Rounding = 0,
})

local RebirthGroup = Tabs.Progress:AddLeftGroupbox("Rebirth", "rotate-ccw")

RebirthGroup:AddToggle("AutoRebirth", {
    Text = "Auto Rebirth",
    Default = false,
})

local UpgradeGroup = Tabs.Progress:AddRightGroupbox("Upgrades", "arrow-big-up")

UpgradeGroup:AddToggle("AutoUpgrade", {
    Text = "Auto Upgrades",
    Default = false,
})

UpgradeGroup:AddDropdown("UpgradeTypes", {
    Values = upgradeNames,
    Multi = true,
    Searchable = true,
    AllowNull = true,
    Text = "Upgrades",
    Default = {},
})

local MissionGroup = Tabs.Progress:AddLeftGroupbox("Missions", "list-checks")

MissionGroup:AddToggle("AutoClaimMission", {
    Text = "Auto Claim Mission",
    Default = false,
})

MissionGroup:AddToggle("AutoGetAllPlant", {
    Text = "Auto Get All Plant",
    Default = false,
})

local DailyGroup = Tabs.Progress:AddRightGroupbox("Daily", "calendar")

DailyGroup:AddToggle("AutoClaimDaily", {
    Text = "Auto Claim Daily Rewards",
    Default = false,
})

local function syncRollFlag(key, current, desired)
    if current == desired then
        return false
    end
    OnClientGameEvent:Business(key)
    return true
end

local function syncRollList(key, stateList, wanted, count)
    for index = 1, count do
        if Library.Unloaded then
            return
        end
        local current = stateList[index] == true
        local desired = wanted[index] == true
        if current ~= desired then
            OnClientGameEvent:BusinessToId(key, index)
            task.wait(UNIVERSAL_CD)
        end
    end
end

task.spawn(function()
    while not Library.Unloaded do
        task.wait(1)
        if isOn("AutoRoll") then
            local serverData = getServerData()
            if serverData then
                local wantedRarities = selectedIdSet("RollRarities", rarityIdByName)
                local wantedMutations = selectedIdSet("RollMutations", mutationIdByName)

                syncRollList(AUTOROLL_RARITY, serverData.aotuRollUnitRarity, wantedRarities, #rarityNames)
                syncRollList(AUTOROLL_MUTATION, serverData.aotuRollUnitMaterialRarity, wantedMutations, #mutationNames)

                if syncRollFlag(AUTOROLL_BUY, serverData.aotuRollBuy == true, isOn("AutoRollBuy")) then
                    task.wait(UNIVERSAL_CD)
                end
                syncRollFlag(AUTOROLL_OPEN, serverData.aotuRollOpen == true, true)
            end
        end
    end
end)

Toggles.AutoRoll:OnChanged(function()
    if isOn("AutoRoll") then
        return
    end
    local serverData = getServerData()
    if serverData and serverData.aotuRollOpen then
        OnClientGameEvent:Business(AUTOROLL_OPEN)
    end
end)

local function readFilter(rarityOption, mutationOption)
    return {
        rarities = selectedIdSet(rarityOption, rarityIdByName),
        mutations = selectedIdSet(mutationOption, mutationIdByName),
        hasMutation = hasAny(getMulti(mutationOption)),
    }
end

local function filterMatches(filter, cfg)
    if not filter.rarities[cfg.rarity] then
        return false
    end
    if filter.hasMutation and not filter.mutations[cfg.MaterialRarity] then
        return false
    end
    return true
end

local function getUnit(data, gid)
    local card = data.playData.allCard[gid]
    if card == nil or card.typeId ~= 1 then
        return nil
    end
    return card, PlayConfig.allUnit[card.cfgId]
end

task.spawn(function()
    while not Library.Unloaded do
        task.wait(2)

        local lockFilter = nil
        if isOn("AutoLock") then
            local filter = readFilter("LockRarities", "LockMutations")
            if hasAny(filter.rarities) then
                lockFilter = filter
            end
        end

        if lockFilter then
            local data = getData()
            if data then
                for _, entry in data.serverData.allCard do
                    if Library.Unloaded or not isOn("AutoLock") then
                        break
                    end
                    local card, cfg = getUnit(data, entry.gid)
                    if card ~= nil and cfg ~= nil and not card.isLock and filterMatches(lockFilter, cfg) then
                        OnClientGameEvent:Lock_GidData_Item(UNIT, entry.gid)
                        task.wait(UNIVERSAL_CD)
                    end
                end
            end
        end

        if isOn("AutoSell") then
            local sellFilter = readFilter("SellRarities", "SellMutations")
            if hasAny(sellFilter.rarities) then
                local data = getData()
                if data then
                    local maxStar = getNumber("SellMaxStar", unitStarMax)
                    local gids = {}
                    for _, entry in data.serverData.allCard do
                        local gid = entry.gid
                        local card, cfg = getUnit(data, gid)
                        if card ~= nil and cfg ~= nil and not card.isLock and card.star <= maxStar then
                            local protected = lockFilter ~= nil and filterMatches(lockFilter, cfg)
                            if not protected and filterMatches(sellFilter, cfg) then
                                if not isSceneUnit(data.serverData, gid) and not isEquippedUnit(data.serverData, gid) then
                                    table.insert(gids, gid)
                                end
                            end
                        end
                    end
                    if #gids > 0 then
                        OnClientGameEvent:Destroy_GidData_Item(UNIT, gids)
                    end
                end
            end
        end
    end
end)

local function hasMergeableUnit(serverData)
    local data = getData()
    if not data then
        return false
    end
    local counts = {}
    for _, entry in serverData.allCard do
        local gid = entry.gid
        local card = data.playData.allCard[gid]
        if card ~= nil and card.typeId == 1 and not card.isLock and card.star < unitStarMax then
            if not isSceneUnit(serverData, gid) then
                local key = tostring(card.cfgId) .. "_" .. tostring(card.star)
                counts[key] = (counts[key] or 0) + 1
                if counts[key] >= 2 then
                    return true
                end
            end
        end
    end
    return false
end

task.spawn(function()
    while not Library.Unloaded do
        task.wait(3)
        if isOn("AutoMerge") then
            local serverData = getServerData()
            if serverData and hasMergeableUnit(serverData) then
                OnClientGameEvent:Business(MERGE_UNITS)
            end
        end
    end
end)

task.spawn(function()
    local lastCardCount = -1
    while not Library.Unloaded do
        task.wait(2)
        if isOn("AutoEquipBest") then
            local serverData = getServerData()
            if serverData then
                local count = #serverData.allCard
                if count ~= lastCardCount then
                    lastCardCount = count
                    OnClientGameEvent:Business(EQUIP_BEST_UNIT)
                end
            end
        else
            lastCardCount = -1
        end
    end
end)

local function isInMatch()
    local ok, state = pcall(function()
        local FrameworkLink = require(BusinessFolder:WaitForChild("FrameworkLink"))
        local upUI = FrameworkLink.UIManager:Find("\228\184\138UI")
        return upUI and upUI.isGpStart and upUI.isGpStart.nowState
    end)
    return ok and state == 2
end

local function currentWave()
    local data = getData()
    local wave = data and data.playData.wave
    return wave and wave.Value or 0
end

task.spawn(function()
    while not Library.Unloaded do
        task.wait(2)
        local inMatch = isInMatch()
        if isOn("AutoStopWave") and inMatch and currentWave() >= getNumber("StopWave", 25) then
            OnClientGameEvent:ExitGp()
            task.wait(3)
        elseif isOn("AutoStart") and not inMatch then
            OnClientGameEvent:StartGp()
            task.wait(3)
        end
    end
end)

local function unitDps(data, card)
    return MainBusiness.Get_UnitDps(data.playData.bestUnitAtk.Value, card, data.playData.AtkRep.Value, data.playData.atkSpeedRep.Value)
end

local function unitCard(data, gid)
    if gid == nil or gid <= 0 then
        return nil
    end
    local card = data.playData.allCard[gid]
    if card == nil or card.typeId ~= 1 then
        return nil
    end
    return card
end

local function findBetterHandSlot(data, chunkDps)
    local bestSlot, bestDps
    for slot = 1, PlayConfig.handShowSize do
        local gid = data.serverData.hand[slot]
        local card = unitCard(data, gid)
        if card ~= nil and not isSceneUnit(data.serverData, gid) then
            local dps = unitDps(data, card)
            if chunkDps == nil or BigNumber.BigCompareNoEqual(dps, chunkDps) then
                if bestDps == nil or BigNumber.BigCompareNoEqual(dps, bestDps) then
                    bestSlot, bestDps = slot, dps
                end
            end
        end
    end
    return bestSlot
end

task.spawn(function()
    while not Library.Unloaded do
        task.wait(2)
        if isOn("AutoReplace") then
            local data = getData()
            if data then
                for chunk = 1, #data.serverData.sceneUnit do
                    if Library.Unloaded or not isOn("AutoReplace") then
                        break
                    end
                    if data.serverData.sceneUnitChunkUnlock[chunk] == true then
                        local card = unitCard(data, data.serverData.sceneUnit[chunk])
                        local slot = findBetterHandSlot(data, card and unitDps(data, card) or nil)
                        if slot ~= nil then
                            OnClientGameEvent:SelectHandUnit(slot)
                            task.wait(UNIVERSAL_CD)
                            OnClientGameEvent:BusinessToId(PLACE_UNIT, chunk)
                            task.wait(UNIVERSAL_CD)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        task.wait(5)
        if isOn("AutoRebirth") then
            local serverData = getServerData()
            if serverData then
                local cfg = PlayConfig.allRebirth[serverData.rebirth + 1]
                if cfg ~= nil then
                    local ok, ready = pcall(function()
                        return BusinessBase.Con(cfg.con, false) and BusinessBase.Con(cfg.cost, false)
                    end)
                    if ok and ready then
                        OnClientGameEvent:Business(REBIRTH)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        task.wait(0.1)
        if isOn("AutoUpgrade") then
            local serverData = getServerData()
            if serverData then
                local wanted = selectedIdSet("UpgradeTypes", upgradeIdByName)
                for index, cfg in PlayConfig.allStatUpgrade do
                    if Library.Unloaded then
                        break
                    end
                    if wanted[cfg.id] then
                        local level = serverData.allStatUpgrade[index]
                        while level < cfg.size do
                            if Library.Unloaded or not isOn("AutoUpgrade") then
                                break
                            end
                            local cost = BigNumber.MulNumber(cfg.cost, cfg.costRep ^ level)
                            local ok, affordable = pcall(BusinessBase.Con, {
                                value = cost,
                                size = 1,
                                itemEnum = cfg.costItemEnum,
                            }, false)
                            if not (ok and affordable) then
                                break
                            end
                            OnClientGameEvent:Buy_Backpack_Item(STAT_UPGRADE, cfg.id)
                            local deadline = os.clock() + UNIVERSAL_CD
                            repeat
                                task.wait()
                            until serverData.allStatUpgrade[index] ~= level or os.clock() >= deadline
                            if serverData.allStatUpgrade[index] == level then
                                break
                            end
                            level = serverData.allStatUpgrade[index]
                        end
                    end
                end
            end
        end
    end
end)

local function selectedNameSet(optionName)
    local set = {}
    for name, enabled in pairs(getMulti(optionName)) do
        if enabled then
            set[name] = true
        end
    end
    return set
end

local function getUnixTime()
    local FrameworkLink = require(BusinessFolder:WaitForChild("FrameworkLink"))
    local ok, ms = pcall(function()
        return FrameworkLink.TimeSynch:Get_UnixTimestampMillis()
    end)
    if ok and type(ms) == "number" then
        return math.floor(ms / 1000)
    end
    return os.time()
end

local function canAfford(con)
    if type(con) ~= "table" then
        return true
    end
    local ok, ready = pcall(BusinessBase.Con, con, false)
    return ok and ready == true
end

local function craftAffordable(cfg)
    if type(cfg.data) ~= "table" then
        return true
    end
    for _, entry in pairs(cfg.data) do
        if type(entry) == "table" then
            local cost = entry.cost or entry
            if type(cost) == "table" and cost.itemEnum and not canAfford(cost) then
                return false
            end
        end
    end
    return true
end

local function productionReady(serverData)
    local productionId = serverData.productionId
    if productionId == nil or productionId == 0 then
        return false
    end
    local startTime = serverData.productionStartTime or 0
    local maxTime = serverData.productionMaxTime or 0
    return getUnixTime() >= (startTime + maxTime)
end

task.spawn(function()
    while not Library.Unloaded do
        task.wait(1)

        if isOn("AutoDeletePlant") then
            local wanted = selectedNameSet("DeletePlants")
            if hasAny(wanted) then
                local data = getData()
                if data then
                    local indexes = {}
                    for name in pairs(wanted) do
                        local index = plantIndexByName[name]
                        if index then
                            indexes[index] = true
                        end
                    end
                    local gids = {}
                    for _, entry in data.serverData.allCard do
                        local gid = entry.gid
                        local card, cfg = getUnit(data, gid)
                        if card ~= nil and cfg ~= nil and indexes[cfg.index] and not card.isLock then
                            if not isSceneUnit(data.serverData, gid) and not isEquippedUnit(data.serverData, gid) then
                                table.insert(gids, gid)
                            end
                        end
                    end
                    if #gids > 0 then
                        OnClientGameEvent:Destroy_GidData_Item(UNIT, gids)
                        task.wait(UNIVERSAL_CD)
                    end
                end
            end
        end

        if isOn("AutoBuyPlant") then
            local wanted = selectedNameSet("BuyPlants")
            if hasAny(wanted) then
                local serverData = getServerData()
                if serverData and (serverData.productionId == nil or serverData.productionId == 0) then
                    for name in pairs(wanted) do
                        if Library.Unloaded or not isOn("AutoBuyPlant") then
                            break
                        end
                        local unitId = plantIdByName[name]
                        if unitId then
                            local craftId = plantCraftByUnitId[unitId]
                            if craftId then
                                local cfg = PlayConfig.allProduction[craftId]
                                if cfg and craftAffordable(cfg) then
                                    OnClientGameEvent:BusinessToIdSize(START_CRAFT, craftId, 1)
                                    task.wait(UNIVERSAL_CD)
                                    break
                                end
                            else
                                if canAfford(PlayConfig.allUnit[unitId] and PlayConfig.allUnit[unitId].cost) then
                                    OnClientGameEvent:Buy_Backpack_Item(UNIT, unitId)
                                    task.wait(UNIVERSAL_CD)
                                end
                            end
                        end
                    end
                end
            end
        end

        if isOn("AutoBuyFruit") then
            local wanted = selectedNameSet("Fruits")
            if hasAny(wanted) then
                for name in pairs(wanted) do
                    if Library.Unloaded or not isOn("AutoBuyFruit") then
                        break
                    end
                    local fruitId = fruitIdByName[name]
                    local cfg = fruitId and PlayConfig.allUseItem[fruitId]
                    if cfg and canAfford(cfg.cost) then
                        OnClientGameEvent:Buy_Backpack_Item(DAOJU, cfg.id)
                        task.wait(UNIVERSAL_CD)
                    end
                end
            end
        end

        if isOn("AutoUseFruit") then
            local wanted = selectedNameSet("Fruits")
            if hasAny(wanted) then
                local serverData = getServerData()
                if serverData and serverData.allUseItemStoreSize then
                    for name in pairs(wanted) do
                        if Library.Unloaded or not isOn("AutoUseFruit") then
                            break
                        end
                        local fruitId = fruitIdByName[name]
                        if fruitId and (serverData.allUseItemStoreSize[fruitId] or 0) > 0 then
                            OnClientGameEvent:UseItem(fruitId, USE_ITEM_TYPE)
                            task.wait(UNIVERSAL_CD)
                        end
                    end
                end
            end
        end

        if isOn("AutoCraft") then
            local serverData = getServerData()
            if serverData then
                if productionReady(serverData) then
                    OnClientGameEvent:Business(CLAIM_CRAFT)
                    task.wait(UNIVERSAL_CD)
                elseif serverData.productionId == nil or serverData.productionId == 0 then
                    local wanted = selectedNameSet("CraftRecipes")
                    if hasAny(wanted) then
                        local size = math.max(1, math.floor(getNumber("CraftSize", 1)))
                        for name in pairs(wanted) do
                            if Library.Unloaded or not isOn("AutoCraft") then
                                break
                            end
                            local craftId = craftIdByName[name]
                            local cfg = craftId and PlayConfig.allProduction[craftId]
                            if cfg and craftAffordable(cfg) then
                                OnClientGameEvent:BusinessToIdSize(START_CRAFT, craftId, size)
                                task.wait(UNIVERSAL_CD)
                                break
                            end
                        end
                    end
                end
            end
        elseif isOn("AutoBuyPlant") then
            local serverData = getServerData()
            if serverData and productionReady(serverData) then
                OnClientGameEvent:Business(CLAIM_CRAFT)
                task.wait(UNIVERSAL_CD)
            end
        end

        if isOn("AutoClaimMission") then
            local serverData = getServerData()
            if serverData then
                for index, cfg in PlayConfig.allDayTask do
                    if Library.Unloaded or not isOn("AutoClaimMission") then
                        break
                    end
                    local need = cfg.con and cfg.con.size or 0
                    local progress = serverData.dayTaskSize and serverData.dayTaskSize[index] or 0
                    local claimed = serverData.dayTaskIsOk and serverData.dayTaskIsOk[index] == true
                    if need > 0 and progress >= need and not claimed and cfg.con and cfg.con.itemEnum then
                        OnClientGameEvent:BusinessToId(cfg.con.itemEnum, cfg.id)
                        task.wait(UNIVERSAL_CD)
                    end
                end
            end
        end

        if isOn("AutoClaimDaily") then
            local serverData = getServerData()
            if serverData then
                local nextDay = (serverData.dayGift or 0) + 1
                if PlayConfig.dayGift[nextDay] then
                    OnClientGameEvent:BusinessToId(DAY_GIFT, nextDay)
                    task.wait(UNIVERSAL_CD)
                end
                local boxTime = serverData.dailyBoxTime or 0
                if boxTime > 0 and getUnixTime() >= boxTime then
                    OnClientGameEvent:GetGift(DAY_BOX)
                    task.wait(UNIVERSAL_CD)
                end
            end
        end

        if isOn("AutoGetAllPlant") then
            local data = getData()
            if data then
                for chunk = 1, #data.serverData.sceneUnit do
                    if Library.Unloaded or not isOn("AutoGetAllPlant") then
                        break
                    end
                    if data.serverData.sceneUnitChunkUnlock[chunk] == true then
                        local sceneGid = data.serverData.sceneUnit[chunk]
                        if sceneGid == nil or sceneGid <= 0 then
                            local slot = findBetterHandSlot(data, nil)
                            if slot ~= nil then
                                OnClientGameEvent:SelectHandUnit(slot)
                                task.wait(UNIVERSAL_CD)
                                OnClientGameEvent:BusinessToId(PLACE_UNIT, chunk)
                                task.wait(UNIVERSAL_CD)
                            end
                        end
                    end
                end
            end
        end
    end
end)

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

local function getHumanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local steppedConnection = RunService.Stepped:Connect(function()
    if Library.Unloaded then
        return
    end
    if isOn("NoClip") then
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

local jumpConnection = UserInputService.JumpRequest:Connect(function()
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

local Camera = workspace.CurrentCamera

local renderConnection = RunService.RenderStepped:Connect(function(dt)
    if Library.Unloaded then
        return
    end

    if isOn("WalkSpeedEnabled") then
        local humanoid = getHumanoid()
        if humanoid then
            humanoid.WalkSpeed = getNumber("WalkSpeed", 32)
        end
    end

    if isOn("Fly") then
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
                root.CFrame = root.CFrame + direction.Unit * getNumber("FlySpeed", 60) * dt
            end
        end
    end
end)

Toggles.Fly:OnChanged(function()
    if not isOn("Fly") then
        local humanoid = getHumanoid()
        if humanoid then
            humanoid.PlatformStand = false
        end
    end
end)

Toggles.WalkSpeedEnabled:OnChanged(function()
    if not isOn("WalkSpeedEnabled") then
        local humanoid = getHumanoid()
        if humanoid then
            humanoid.WalkSpeed = 16
        end
    end
end)

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "menu")

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
    local camera = workspace.CurrentCamera
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

MenuGroup:AddToggle("AntiAfk", {
    Text = "Anti-AFK",
    Default = true,
})

task.spawn(function()
    while not Library.Unloaded do
        task.wait(2)
        if isOn("AntiAfk") then
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

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Menu keybind",
})

Library.ToggleKeybind = Options.MenuKeybind

MenuGroup:AddButton("Unload", function()
    Library:Unload()
end)

Library:OnUnload(function()
    steppedConnection:Disconnect()
    jumpConnection:Disconnect()
    renderConnection:Disconnect()
    antiAfkBeganConnection:Disconnect()
    antiAfkChangedConnection:Disconnect()

    local humanoid = getHumanoid()
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.WalkSpeed = 16
    end
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("OuroborosHub")
SaveManager:SetFolder("OuroborosHub/mutant-plants-base-defense")

ThemeManager:SaveDefault("Mint")

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

ThemeManager:LoadDefault()
SaveManager:LoadAutoloadConfig()
