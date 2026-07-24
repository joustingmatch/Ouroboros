local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

if getgenv then
    getgenv().gethui = function()
        return LocalPlayer:WaitForChild("PlayerGui")
    end
end

local GAME_NAME = "Greedy Growers"

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local SeedConfig = require(ReplicatedStorage.Shared.Info.SeedConfig)
local ExpandedRarities = require(ReplicatedStorage.Shared.Info.ExpandedRarities)
local RebirthConfig = require(ReplicatedStorage.Shared.Info.RebirthConfig)
local FertilizerConfig = require(ReplicatedStorage.Shared.Info.FertilizerConfig)
local CustomEnum = require(ReplicatedStorage.Shared.Info.CustomEnum)
local Constants = require(ReplicatedStorage.Shared.Info.Constants)
local WeatherConfig = require(ReplicatedStorage.Shared.Info.WeatherConfig)

local SeedConveyorService = Knit.GetService("SeedConveyorService")
local PlayerPlotService = Knit.GetService("PlayerPlotService")
local PlantRoundService = Knit.GetService("PlantRoundService")
local ToolService = Knit.GetService("ToolService")
local SellStandService = Knit.GetService("SellStandService")
local SellFruitsService = Knit.GetService("SellFruitsService")
local RebirthService = Knit.GetService("RebirthService")
local DataClient = Knit.GetController("DataClient")

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

pcall(function()
    Library.ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end)

local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Toggles = Library.Toggles
local Options = Library.Options

local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"

local function copyDiscord()
    if setclipboard then
        setclipboard(DISCORD_INVITE)
    elseif toclipboard then
        toclipboard(DISCORD_INVITE)
    end
    Library:Notify("Copied Discord invite to clipboard")
end

local RARITY_ORDER = {
    "COMMON",
    "UNCOMMON",
    "RARE",
    "EPIC",
    "LEGENDARY",
    "MYTHIC",
    "CELESTIAL",
    "SECRET",
    "DIVINE",
}

local RARITY_INDEX = {}
local RARITY_NAMES = {}
local RARITY_NAME_TO_KEY = {}
for i, key in ipairs(RARITY_ORDER) do
    RARITY_INDEX[key] = i
    local name = ExpandedRarities[key] and ExpandedRarities[key].name or key
    RARITY_NAMES[i] = name
    RARITY_NAME_TO_KEY[name] = key
end

local SEED_NAMES = {}
local SEED_NAME_TO_KEY = {}
for key in pairs(SeedConfig.Seeds) do
    local name = SeedConfig.SeedDisplayName(key)
    SEED_NAMES[#SEED_NAMES + 1] = name
    SEED_NAME_TO_KEY[name] = key
end
table.sort(SEED_NAMES)

local function selectedSet(value)
    local set = {}
    for name, state in value do
        if state then
            set[name] = true
        end
    end
    return set
end

local wantedSeeds = {}

local function getData()
    return DataClient.currentData
end

local function getCoins()
    local data = getData()
    if not data or not data.Currency then
        return 0
    end
    return data.Currency[CustomEnum.CURRENCIES.COINS] or 0
end

local function hasInventorySpace()
    local data = getData()
    if not data or not data.Inventory then
        return true
    end
    for _, slot in data.Inventory.Hotbar or {} do
        if slot and slot.empty == true then
            return true
        end
    end
    return #(data.Inventory.Storage or {}) < Constants.STORAGE_MAX_SIZE
end

local function getMyPlot()
    local field = workspace:FindFirstChild("BigField")
    local plots = field and field:FindFirstChild("PlayerPlots")
    if not plots then
        return nil
    end
    for _, plot in plots:GetChildren() do
        if plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            return plot
        end
    end
    return nil
end

local function getRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local purchasedSpawns = {}

local function shouldBuySeed(seedType, rarity, mutation)
    if Toggles.BuyMutatedOnly.Value and (mutation == nil or mutation == "") then
        return false
    end

    local seed = SeedConfig.GetSeed(seedType)
    local cost = seed and seed.plantCost or 0
    local maxCost = tonumber(Options.BuyMaxCost.Value) or 0
    if maxCost > 0 and cost > maxCost then
        return false
    end
    local reserve = tonumber(Options.BuyReserve.Value) or 0
    if getCoins() - cost < reserve then
        return false
    end

    local mode = Options.BuyMode.Value
    if mode == "Buy All" then
        return true
    elseif mode == "Selected Seeds" then
        return wantedSeeds[seedType] == true
    end

    local minKey = RARITY_NAME_TO_KEY[Options.BuyMinRarity.Value]
    local have = RARITY_INDEX[rarity]
    local want = RARITY_INDEX[minKey]
    if not have or not want then
        return false
    end
    return have >= want
end

local function doBuySeeds()
    if not hasInventorySpace() then
        return
    end

    local field = workspace:FindFirstChild("BigField")
    local folder = field and field:FindFirstChild("ConveyorSeeds")
    if not folder then
        return
    end

    for _, holder in folder:GetChildren() do
        local spawnId = holder:GetAttribute("SpawnId")
        if spawnId and not purchasedSpawns[spawnId] then
            local seedType = holder:GetAttribute("SeedType")
            local rarity = holder:GetAttribute("Rarity")
            if seedType and rarity and shouldBuySeed(seedType, rarity, holder:GetAttribute("Mutation")) then
                purchasedSpawns[spawnId] = true
                local ok, success = SeedConveyorService:RequestPurchase(spawnId):await()
                if ok and success then
                    if Toggles.BuyNotify.Value then
                        Library:Notify(("Bought %s"):format(SeedConfig.SeedDisplayName(seedType)))
                    end
                    if not hasInventorySpace() then
                        return
                    end
                end
                task.wait(Options.BuyActionDelay.Value or 0.2)
            end
        end
    end

    for spawnId in pairs(purchasedSpawns) do
        local stillThere = false
        for _, holder in folder:GetChildren() do
            if holder:GetAttribute("SpawnId") == spawnId then
                stillThere = true
                break
            end
        end
        if not stillThere then
            purchasedSpawns[spawnId] = nil
        end
    end
end

local activeRound = nil
local harvestedRoundId = nil

local function roundMultiplier(startTime)
    local elapsed = math.max(0, workspace:GetServerTimeNow() - startTime)
    return math.max(0, math.floor((math.exp(elapsed * 0.28) - 1) * 100) / 100)
end

local function refreshRound()
    local ok, rounds = PlantRoundService:GetActiveRounds():await()
    if not ok or type(rounds) ~= "table" then
        return
    end
    for _, round in rounds do
        if round.userId == LocalPlayer.UserId then
            activeRound = round
            return
        end
    end
    activeRound = nil
end

local function doRoundHarvest()
    local round = activeRound
    if not round then
        return
    end

    if round.crashed then
        if Toggles.AutoCollectDead.Value and harvestedRoundId ~= round.roundId then
            harvestedRoundId = round.roundId
            PlantRoundService:CollectDeadTree():await()
        end
        return
    end

    if round.stopped or harvestedRoundId == round.roundId or not Toggles.AutoHarvest.Value then
        return
    end

    local target = tonumber(Options.HarvestMultiplier.Value) or 2
    if roundMultiplier(round.startTime) < target then
        return
    end

    harvestedRoundId = round.roundId
    PlantRoundService:StopPlant():await()
    if Toggles.HarvestNotify.Value then
        Library:Notify(("Harvested at %.2fx"):format(roundMultiplier(round.startTime)))
    end
end

local FERTILIZER_NAMES = {}
for _, key in ipairs(FertilizerConfig.Order) do
    FERTILIZER_NAMES[#FERTILIZER_NAMES + 1] = key
end

local WEATHER_NAMES = {}
local WEATHER_NAME_TO_KEY = {}
for _, key in ipairs(WeatherConfig.Order) do
    local weather = WeatherConfig.Weathers[key]
    local name = weather and weather.displayName or key
    WEATHER_NAMES[#WEATHER_NAMES + 1] = name
    WEATHER_NAME_TO_KEY[name] = key
end

local wantedWeathers = {}
for _, key in ipairs(WeatherConfig.Order) do
    wantedWeathers[key] = true
end

local function getActiveWeatherKey()
    local value = ReplicatedStorage:FindFirstChild("CurrentWeather")
    return value and WeatherConfig.Normalize(value.Value)
end

local wantedPlantSeeds = {}

local function getEquippedSeedTool()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end
    for _, tool in character:GetChildren() do
        if tool:IsA("Tool") and tool:GetAttribute("IsSeed") then
            return tool
        end
    end
    return nil
end

local function findPlantableSlot()
    local data = getData()
    if not data or not data.Inventory then
        return nil
    end

    local mode = Options.PlantMode.Value
    local best, bestSlot, bestHotbar = nil, nil, nil
    for _, container in ipairs({ { data.Inventory.Hotbar, true }, { data.Inventory.Storage, false } }) do
        local items, isHotbar = container[1], container[2]
        for slot, item in items or {} do
            if item and item.itemType == "Seed" and item.seedType then
                local allowed = mode == "Any Seed" or wantedPlantSeeds[item.seedType] == true
                if allowed then
                    local seed = SeedConfig.GetSeed(item.seedType)
                    local cost = seed and seed.plantCost or 0
                    if mode == "Highest Value" then
                        if not best or cost > best then
                            best, bestSlot, bestHotbar = cost, slot, isHotbar
                        end
                    elseif mode == "Lowest Value" then
                        if not best or cost < best then
                            best, bestSlot, bestHotbar = cost, slot, isHotbar
                        end
                    else
                        return slot, isHotbar
                    end
                end
            end
        end
    end
    return bestSlot, bestHotbar
end

local function doPlant()
    if activeRound and not activeRound.stopped and not activeRound.crashed then
        return
    end

    if Toggles.PlantDuringWeatherOnly.Value then
        local weather = getActiveWeatherKey()
        if not weather or not wantedWeathers[weather] then
            return
        end
    end

    local tool = getEquippedSeedTool()
    if not tool then
        local slot, isHotbar = findPlantableSlot()
        if not slot then
            return
        end
        ToolService.ToggleEquip:Fire(isHotbar, slot)
        local deadline = tick() + 3
        repeat
            task.wait(0.1)
            tool = getEquippedSeedTool()
        until tool or tick() > deadline
    end

    if not tool then
        return
    end

    local seedType = tool:GetAttribute("SeedType")
    if not seedType then
        return
    end

    local fertilizer = Options.PlantFertilizer.Value or "None"
    local data = getData()
    if (data and data.Rebirth or 0) < 1 then
        fertilizer = "None"
    end

    local ok, started = PlantRoundService:StartRound(seedType, fertilizer):await()
    if ok and started then
        harvestedRoundId = nil
        pcall(refreshRound)
        if Toggles.PlantNotify.Value then
            Library:Notify(("Planted %s"):format(SeedConfig.SeedDisplayName(seedType)))
        end
    end
end

local function collectTreePrompts(tree)
    local prompts = {}
    for _, descendant in tree:GetDescendants() do
        if descendant:IsA("ProximityPrompt") and descendant.Enabled and descendant.ActionText == "Collect" then
            prompts[#prompts + 1] = descendant
        end
    end
    return prompts
end

local function doHarvest()
    local plot = getMyPlot()
    if not plot then
        return
    end

    if Toggles.HarvestCollectAll.Value then
        pcall(function()
            PlayerPlotService:CollectAllFruits():await()
        end)
    end

    local root = getRoot()
    local returnCFrame = root and root.CFrame

    for _, tree in plot:GetChildren() do
        if tree.Name:match("^PlotTree_") then
            local prompts = collectTreePrompts(tree)
            if #prompts > 0 then
                if Toggles.HarvestTeleport.Value and root then
                    local base = tree:FindFirstChild("Base")
                    if base then
                        root.CFrame = base.CFrame + Vector3.new(0, 5, 0)
                        task.wait(0.1)
                    end
                end
                for _, prompt in prompts do
                    if Library.Unloaded or not Toggles.AutoCollectFruit.Value then
                        break
                    end
                    pcall(fireproximityprompt, prompt)
                    task.wait(Options.HarvestActionDelay.Value or 0.1)
                end
            end
        end
    end

    if Toggles.HarvestTeleport.Value and root and returnCFrame then
        root.CFrame = returnCFrame
    end
end

local function countFruitTools()
    local count = 0
    local character = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    for _, container in { character, backpack } do
        if container then
            for _, tool in container:GetChildren() do
                if tool:IsA("Tool") and tool:GetAttribute("IsFruit") then
                    count += 1
                end
            end
        end
    end
    return count
end

local function doSellFruits()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not humanoid or not backpack then
        return
    end

    if countFruitTools() < (tonumber(Options.SellMinFruits.Value) or 1) then
        return
    end

    if Toggles.SellTeleport.Value then
        local field = workspace:FindFirstChild("BigField")
        local stand = field and field:FindFirstChild("SellStand")
        local root = getRoot()
        local pivot = stand and stand:GetPivot()
        if root and pivot then
            root.CFrame = pivot + Vector3.new(0, 5, 0)
            task.wait(0.2)
        end
    end

    while not Library.Unloaded and Toggles.AutoSellFruits.Value do
        local fruit
        for _, tool in character:GetChildren() do
            if tool:IsA("Tool") and tool:GetAttribute("IsFruit") then
                fruit = tool
                break
            end
        end
        if not fruit then
            for _, tool in backpack:GetChildren() do
                if tool:IsA("Tool") and tool:GetAttribute("IsFruit") then
                    humanoid:EquipTool(tool)
                    fruit = tool
                    break
                end
            end
        end
        if not fruit then
            break
        end
        SellFruitsService:SellFruit():await()
        task.wait(Options.SellActionDelay.Value or 0.2)
    end
end

local function doSellAll()
    SellStandService:SellAll():await()
end

local function doRebirth()
    local data = getData()
    if not data then
        return
    end

    local current = data.Rebirth or 0
    if current >= (tonumber(Options.RebirthMaxLevel.Value) or RebirthConfig.MaxLevel) then
        return
    end

    local nextRebirth = RebirthConfig.GetNext(current)
    if not nextRebirth or getCoins() < nextRebirth.cost then
        return
    end

    RebirthService:DoRebirth():await()
    if Toggles.RebirthNotify.Value then
        Library:Notify(("Rebirthed to %d"):format(current + 1))
    end
end

local Window = Library:CreateWindow({
    Title = "Ouroboros Hub",
    Footer = DISCORD_INVITE .. " | " .. GAME_NAME,
    Icon = 18657887261,
    NotifySide = "Right",
    Size = UDim2.fromOffset(900, 640),
    ShowCustomCursor = false,
})

Library.ShowCustomCursor = false

local Tabs = {
    Info = Window:AddTab("Info", "info"),
    Seeds = Window:AddTab("Seeds", "sprout"),
    Farm = Window:AddTab("Farm", "trees"),
    Settings = Window:AddTab("Settings", "settings"),
}

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
    AddDiscordButton(Tab)
end

local InfoGroup = Tabs.Info:AddLeftGroupbox("Basic Info", "circle-user")

local executorName = "Unknown"
pcall(function()
    if identifyexecutor then
        local name, version = identifyexecutor()
        if type(name) == "string" and name ~= "" then
            executorName = type(version) == "string" and version ~= "" and (name .. " " .. version) or name
        end
    end
end)

InfoGroup:AddLabel("Executor: " .. executorName, true)
InfoGroup:AddLabel("Game: " .. GAME_NAME, true)
InfoGroup:AddLabel("Player: " .. LocalPlayer.Name, true)
InfoGroup:AddLabel("Status: Keyless", true)

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
FaqGroup:AddLabel('<font color="rgb(85, 255, 85)">Is Harvest before Lightning Strike Possible?</font>', true)
FaqGroup:AddLabel('<font color="rgb(85, 255, 85)">No</font>', true)

local BuyGroup = Tabs.Seeds:AddLeftGroupbox("Auto Buy Seeds", "shopping-cart")

BuyGroup:AddToggle("AutoBuySeeds", {
    Text = "Auto Buy Seeds",
    Default = false,
})

BuyGroup:AddDropdown("BuyMode", {
    Text = "Buy Mode",
    Values = { "Minimum Rarity", "Selected Seeds", "Buy All" },
    Default = "Minimum Rarity",
    Multi = false,
})

BuyGroup:AddDropdown("BuyMinRarity", {
    Text = "Minimum Rarity",
    Values = RARITY_NAMES,
    Default = RARITY_NAMES[1],
    Multi = false,
})

BuyGroup:AddDropdown("BuySeeds", {
    Text = "Seeds To Buy",
    Values = SEED_NAMES,
    Default = {},
    Multi = true,
    Callback = function(value)
        local set = {}
        for name, state in value do
            if state then
                local key = SEED_NAME_TO_KEY[name]
                if key then
                    set[key] = true
                end
            end
        end
        wantedSeeds = set
    end,
})

BuyGroup:AddToggle("BuyMutatedOnly", {
    Text = "Only Mutated Seeds",
    Default = false,
})

local BuyLimitGroup = Tabs.Seeds:AddRightGroupbox("Limits", "sliders-horizontal")

BuyLimitGroup:AddInput("BuyMaxCost", {
    Text = "Max Cost Per Seed (0 = off)",
    Default = "0",
    Numeric = true,
    Finished = false,
    ClearTextOnFocus = false,
})

BuyLimitGroup:AddInput("BuyReserve", {
    Text = "Keep Coin Reserve",
    Default = "0",
    Numeric = true,
    Finished = false,
    ClearTextOnFocus = false,
})

BuyLimitGroup:AddToggle("BuyNotify", {
    Text = "Notify On Buy",
    Default = false,
})

BuyLimitGroup:AddSlider("BuyActionDelay", {
    Text = "Buy Delay",
    Default = 0.2,
    Min = 0.1,
    Max = 2,
    Rounding = 2,
})

BuyLimitGroup:AddSlider("BuyLoopDelay", {
    Text = "Loop Delay",
    Default = 0.5,
    Min = 0.1,
    Max = 10,
    Rounding = 1,
})

local PlantGroup = Tabs.Farm:AddRightGroupbox("Auto Plant", "sprout")

PlantGroup:AddToggle("AutoPlant", {
    Text = "Auto Plant",
    Default = false,
})

PlantGroup:AddDropdown("PlantMode", {
    Text = "Seed Choice",
    Values = { "Any Seed", "Selected Seeds", "Highest Value", "Lowest Value" },
    Default = "Any Seed",
    Multi = false,
})

PlantGroup:AddDropdown("PlantSeeds", {
    Text = "Seeds To Plant",
    Values = SEED_NAMES,
    Default = {},
    Multi = true,
    Callback = function(value)
        local set = {}
        for name, state in value do
            if state then
                local key = SEED_NAME_TO_KEY[name]
                if key then
                    set[key] = true
                end
            end
        end
        wantedPlantSeeds = set
    end,
})

PlantGroup:AddDropdown("PlantFertilizer", {
    Text = "Fertilizer",
    Values = FERTILIZER_NAMES,
    Default = "None",
    Multi = false,
})

PlantGroup:AddToggle("PlantDuringWeatherOnly", {
    Text = "Only Plant During Weather",
    Default = false,
})

PlantGroup:AddDropdown("PlantWeathers", {
    Text = "Weathers To Plant In",
    Values = WEATHER_NAMES,
    Default = WEATHER_NAMES,
    Multi = true,
    Callback = function(value)
        local set = {}
        for name, state in value do
            if state then
                local key = WEATHER_NAME_TO_KEY[name]
                if key then
                    set[key] = true
                end
            end
        end
        wantedWeathers = set
    end,
})

PlantGroup:AddToggle("PlantNotify", {
    Text = "Notify On Plant",
    Default = false,
})

PlantGroup:AddSlider("PlantLoopDelay", {
    Text = "Loop Delay",
    Default = 1,
    Min = 0.2,
    Max = 20,
    Rounding = 1,
})

local HarvestGroup = Tabs.Farm:AddLeftGroupbox("Auto Harvest", "apple")

HarvestGroup:AddToggle("AutoHarvest", {
    Text = "Auto Harvest",
    Default = false,
})

HarvestGroup:AddInput("HarvestMultiplier", {
    Text = "Harvest At Multiplier",
    Default = "2",
    Numeric = true,
    Finished = false,
    ClearTextOnFocus = false,
})

local function greenLabel(text)
    HarvestGroup:AddLabel('<font color="rgb(85, 255, 85)">' .. text .. "</font>", true)
end

greenLabel("Examples")
greenLabel("1 for 1x")
greenLabel("1.50 for 1.50x")
greenLabel("0.50 for 0.5x")

HarvestGroup:AddToggle("AutoCollectDead", {
    Text = "Auto Collect Dead Tree",
    Default = true,
})

HarvestGroup:AddToggle("HarvestNotify", {
    Text = "Notify On Harvest",
    Default = false,
})

local FruitGroup = Tabs.Farm:AddLeftGroupbox("Auto Collect Fruit", "grape")

FruitGroup:AddToggle("AutoCollectFruit", {
    Text = "Auto Collect Fruit",
    Default = false,
})

FruitGroup:AddToggle("HarvestTeleport", {
    Text = "Teleport To Each Tree",
    Default = false,
})

FruitGroup:AddToggle("HarvestCollectAll", {
    Text = "Use Collect All",
    Default = false,
})

FruitGroup:AddSlider("HarvestActionDelay", {
    Text = "Collect Delay",
    Default = 0.1,
    Min = 0.05,
    Max = 2,
    Rounding = 2,
})

FruitGroup:AddSlider("HarvestLoopDelay", {
    Text = "Loop Delay",
    Default = 1,
    Min = 0.2,
    Max = 20,
    Rounding = 1,
})

local SellGroup = Tabs.Farm:AddRightGroupbox("Auto Sell", "banknote")

SellGroup:AddToggle("AutoSellFruits", {
    Text = "Auto Sell Fruits",
    Default = false,
})

SellGroup:AddToggle("AutoSellAll", {
    Text = "Auto Sell All",
    Default = false,
})

SellGroup:AddToggle("SellTeleport", {
    Text = "Teleport To Sell Stand",
    Default = false,
})

SellGroup:AddSlider("SellMinFruits", {
    Text = "Minimum Fruits",
    Default = 1,
    Min = 1,
    Max = 50,
    Rounding = 0,
})

SellGroup:AddSlider("SellActionDelay", {
    Text = "Sell Delay",
    Default = 0.2,
    Min = 0.1,
    Max = 2,
    Rounding = 2,
})

SellGroup:AddSlider("SellLoopDelay", {
    Text = "Loop Delay",
    Default = 2,
    Min = 0.5,
    Max = 30,
    Rounding = 1,
})

local RebirthGroup = Tabs.Farm:AddRightGroupbox("Auto Rebirth", "refresh-cw")

RebirthGroup:AddToggle("AutoRebirth", {
    Text = "Auto Rebirth",
    Default = false,
})

RebirthGroup:AddSlider("RebirthMaxLevel", {
    Text = "Max Rebirth Level",
    Default = RebirthConfig.MaxLevel,
    Min = 1,
    Max = RebirthConfig.MaxLevel,
    Rounding = 0,
})

RebirthGroup:AddToggle("RebirthNotify", {
    Text = "Notify On Rebirth",
    Default = true,
})

RebirthGroup:AddSlider("RebirthLoopDelay", {
    Text = "Loop Delay",
    Default = 5,
    Min = 1,
    Max = 60,
    Rounding = 1,
})

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Menu keybind",
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

MenuGroup:AddButton("Unload", function()
    Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

Library:OnUnload(function()
    antiAfkBeganConnection:Disconnect()
    antiAfkChangedConnection:Disconnect()
    print("Greedy Growers unloaded")
end)

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("OuroborosHub")
ThemeManager:SaveDefault("Mint")

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("OuroborosHub/GreedyGrowers")
SaveManager:BuildConfigSection(Tabs.Settings)

ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()

SaveManager:LoadAutoloadConfig()

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoBuySeeds.Value then
            pcall(doBuySeeds)
        end
        task.wait(Options.BuyLoopDelay.Value or 0.5)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoHarvest.Value or Toggles.AutoCollectDead.Value or Toggles.AutoPlant.Value then
            pcall(refreshRound)
        else
            activeRound = nil
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoHarvest.Value or Toggles.AutoCollectDead.Value then
            pcall(doRoundHarvest)
        end
        task.wait(0.05)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoPlant.Value then
            pcall(doPlant)
        end
        task.wait(Options.PlantLoopDelay.Value or 1)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoCollectFruit.Value then
            pcall(doHarvest)
        end
        task.wait(Options.HarvestLoopDelay.Value or 1)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoSellFruits.Value then
            pcall(doSellFruits)
        end
        if Toggles.AutoSellAll.Value then
            pcall(doSellAll)
        end
        task.wait(Options.SellLoopDelay.Value or 2)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoRebirth.Value then
            pcall(doRebirth)
        end
        task.wait(Options.RebirthLoopDelay.Value or 5)
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

Library:Notify("Greedy Growers loaded")
