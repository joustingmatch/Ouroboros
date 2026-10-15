local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

if getgenv then
    getgenv().gethui = function()
        return LocalPlayer:WaitForChild("PlayerGui")
    end
end

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Packets = require(Packages:WaitForChild("Packets"))
local client = require(Packages:WaitForChild("DataService")).client
local Configs = ReplicatedStorage:WaitForChild("Configs")
local GameConfig = require(Configs:WaitForChild("GameConfig"))
local UpgradeConfig = require(Configs:WaitForChild("UpgradeConfig"))
local HiveLayout = require(Configs:WaitForChild("HiveLayout"))
local RarityConfig = require(Configs:WaitForChild("RarityConfig"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local ProductionMath = require(Modules:WaitForChild("ProductionMath"))
local ToolBuilderShared = require(Modules:WaitForChild("ToolBuilderShared"))
local BeeConfig = require(Configs:WaitForChild("BeeConfig"))
local MutationConfig = require(Configs:WaitForChild("MutationConfig"))

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

pcall(function()
    Library.ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end)

local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Toggles = Library.Toggles
local Options = Library.Options

local DISCORD_LINK = "https://discord.gg/ehKVq7pf7v"

local function copyDiscord()
    if setclipboard then
        setclipboard(DISCORD_LINK)
    elseif toclipboard then
        toclipboard(DISCORD_LINK)
    end
    Library:Notify("Copied Discord invite to clipboard")
end

local RARITY_ORDER = {}
for _, tier in ipairs(RarityConfig.Ladder) do
    RARITY_ORDER[#RARITY_ORDER + 1] = tier.Name
end

local UPGRADE_IDS = { "BeeLuck", "BeeRolls", "FlowerLevel", "BeeSpeed", "VacuumRange" }

local RARITY_INDEX = {}
for i, name in ipairs(RARITY_ORDER) do
    RARITY_INDEX[name] = i
end

local BEE_NAMES = {}
local BEE_NAME_TO_ID = {}
for _, def in ipairs(BeeConfig.Roster) do
    if def.Id and def.Name and not BEE_NAME_TO_ID[def.Name] then
        BEE_NAMES[#BEE_NAMES + 1] = def.Name
        BEE_NAME_TO_ID[def.Name] = def.Id
    end
end
table.sort(BEE_NAMES)

local MUTATION_NAMES = {}
for _, m in ipairs(MutationConfig.List) do
    local name = type(m) == "table" and m.Name or m
    if name then
        MUTATION_NAMES[#MUTATION_NAMES + 1] = tostring(name)
    end
end
table.sort(MUTATION_NAMES)

local function getData(key)
    local ok, value = pcall(function()
        return client:get(key)
    end)
    if ok then
        return value
    end
    return nil
end

local function selectedSet(value)
    local set = {}
    for name, state in value do
        if state then
            set[name] = true
        end
    end
    return set
end

local wantedRarities = {}

local function shouldBuyRolled(result)
    local mode = Options.RollBuyMode.Value
    local minOdds = tonumber(Options.RollMinOdds.Value) or 0
    if (result.OddsOneInX or 1) < minOdds then
        return false
    end
    if mode == "Buy All" then
        return true
    elseif mode == "Minimum Rarity" then
        return RarityConfig.AtOrAbove(result.Rarity, Options.RollMinRarity.Value)
    elseif mode == "Specific Rarities" then
        if next(wantedRarities) == nil then
            return false
        end
        return wantedRarities[result.Rarity] == true
    end
    return false
end

local function doRoll()
    local ok, fired, resp = pcall(function()
        return Packets.RequestRoll:Fire()
    end)
    if not ok or not fired or type(resp) ~= "table" or type(resp.Results) ~= "table" then
        return
    end
    if not Toggles.RollAutoBuy.Value then
        return
    end
    for _, result in ipairs(resp.Results) do
        if Library.Unloaded or not Toggles.AutoRoll.Value then
            return
        end
        if result.Podium and shouldBuyRolled(result) then
            local bok, bfired, bresp = pcall(function()
                return Packets.BuyBee:Fire({ Podium = result.Podium })
            end)
            if bok and bfired and type(bresp) == "table" and bresp.UUID then
                if Toggles.RollNotify.Value then
                    Library:Notify(("Bought %s (1 in %s)"):format(tostring(result.Rarity), tostring(result.OddsOneInX or 1)))
                end
            end
            task.wait(0.15)
        end
    end
end

local function doHoney()
    if Toggles.AutoTakeHoney.Value then
        pcall(function()
            Packets.GrabHoney:Fire()
        end)
    end
    if Toggles.AutoSellHoney.Value then
        local carried = tonumber(getData("CarriedHoney")) or 0
        local minSell = tonumber(Options.MinHoneyToSell.Value) or 0
        if carried > 0 and carried >= minSell then
            pcall(function()
                Packets.SellHoney:Fire()
            end)
        end
    end
end

local function doEquipBest()
    pcall(function()
        Packets.EquipBest:Fire()
    end)
end

local selectedUpgrades = {}

local function upgradeLevel(id, floor)
    return tonumber(getData(UpgradeConfig.LevelPath(id, floor))) or 0
end

local function tryUpgrade(id, floor, reserve)
    local level = upgradeLevel(id, floor)
    if UpgradeConfig.IsMaxed(id, level) then
        return false
    end
    local cost = UpgradeConfig.GetCost(id, level, floor)
    local cash = tonumber(getData("Cash")) or 0
    if cost == math.huge or cash - cost < reserve then
        return false
    end
    pcall(function()
        Packets.BuyUpgrade:Fire({ HiveIndex = 0, UpgradeId = id, Floor = floor })
    end)
    return true
end

local function doUpgrades()
    local reserve = tonumber(Options.UpgradeReserve.Value) or 0
    local revealedFloors = HiveLayout.RevealedFloors(tonumber(getData("ExpandLevel")) or 1)
    for _, id in ipairs(UPGRADE_IDS) do
        if Library.Unloaded or not Toggles.AutoUpgrade.Value then
            return
        end
        if selectedUpgrades[id] then
            if UpgradeConfig.IsPerFloor(id) then
                for floor = 1, revealedFloors do
                    if tryUpgrade(id, floor, reserve) then
                        task.wait(0.15)
                    end
                end
            else
                if tryUpgrade(id, 1, reserve) then
                    task.wait(0.15)
                end
            end
        end
    end
    if Toggles.AutoExpandHive.Value then
        local expandLevel = tonumber(getData("ExpandLevel")) or 1
        if expandLevel < HiveLayout.MaxExpandLevel then
            pcall(function()
                Packets.ExpandHive:Fire()
            end)
        end
    end
end

local function doUpgradeBees()
    local hives = getData("Hives") or {}
    local reserve = tonumber(Options.BeeUpgradeReserve.Value) or 0
    local maxLevel = tonumber(Options.BeeMaxLevel.Value) or ProductionMath.MaxLevel
    local maxCost = tonumber(Options.BeeMaxCost.Value) or 0
    for key, entry in pairs(hives) do
        if Library.Unloaded or not Toggles.AutoUpgradeBees.Value then
            return
        end
        if type(entry) == "table" and entry.BeeId and entry.Unlocked then
            local level = entry.OutputLevel or 0
            if level < maxLevel and not ProductionMath.IsMaxed(level) then
                local cost = ProductionMath.UpgradeCost(entry.BeeId, level)
                local cash = tonumber(getData("Cash")) or 0
                local costOk = cost ~= math.huge and cash - cost >= reserve
                if maxCost > 0 and cost > maxCost then
                    costOk = false
                end
                if costOk then
                    local floor, index = HiveLayout.ParseHiveKey(key)
                    if index then
                        pcall(function()
                            Packets.BuyUpgrade:Fire({ UpgradeId = "HoneyOutput", HiveIndex = index, Floor = floor })
                        end)
                        task.wait(0.15)
                    end
                end
            end
        end
    end
end

local function doBuyHives()
    local hives = getData("Hives") or {}
    local owned = 0
    for _, v in pairs(hives) do
        if v then
            owned = owned + 1
        end
    end
    local prices = GameConfig.HivePrices
    local price = prices[math.clamp(owned, 1, #prices)]
    if not price then
        return
    end
    local reserve = tonumber(Options.HiveReserve.Value) or 0
    local cash = tonumber(getData("Cash")) or 0
    if cash - price < reserve then
        return
    end
    local expand = tonumber(getData("ExpandLevel")) or 1
    local revealedFloors = HiveLayout.RevealedFloors(expand)
    for floor = 1, revealedFloors do
        for _, index in ipairs(HiveLayout.AllIndices()) do
            if Library.Unloaded or not Toggles.AutoBuyHives.Value then
                return
            end
            local layer = HiveLayout.LayerOf(index)
            if layer and HiveLayout.IsFloorLayerUnlocked(floor, layer, expand) then
                local key = HiveLayout.HiveKey(floor, index)
                if not hives[key] then
                    pcall(function()
                        Packets.UnlockHive:Fire({ HiveIndex = index, Floor = floor })
                    end)
                    return
                end
            end
        end
    end
end

local wantedDeleteRarities = {}
local wantedDeleteBees = {}
local wantedDeleteMutations = {}

local function beeRarityName(beeId)
    local def = BeeConfig.Get(beeId)
    return def and def.Rarity
end

local function matchesDeleteFilter(entry)
    local mode = Options.DeleteMode.Value
    if mode == "Below Minimum Rarity" then
        local keepIdx = RARITY_INDEX[Options.DeleteMinRarity.Value]
        local rarity = beeRarityName(entry.BeeId)
        local idx = rarity and RARITY_INDEX[rarity]
        return keepIdx ~= nil and idx ~= nil and idx < keepIdx
    elseif mode == "Selected Rarities" then
        local rarity = beeRarityName(entry.BeeId)
        return rarity ~= nil and wantedDeleteRarities[rarity] == true
    elseif mode == "Selected Bees" then
        return wantedDeleteBees[entry.BeeId] == true
    elseif mode == "Selected Mutations" then
        return entry.Mutation ~= nil and wantedDeleteMutations[entry.Mutation] == true
    end
    return false
end

local function collectDeletable()
    local owned = getData("OwnedBees") or {}
    local counts = {}
    for _, entry in pairs(owned) do
        if type(entry) == "table" and entry.BeeId then
            counts[entry.BeeId] = (counts[entry.BeeId] or 0) + 1
        end
    end
    local keepPerType = tonumber(Options.DeleteKeepPerType.Value) or 0
    local protectMutated = Toggles.DeleteProtectMutated.Value
    local mode = Options.DeleteMode.Value
    local result = {}
    for _, entry in pairs(owned) do
        if type(entry) == "table" and entry.BeeId and entry.UUID then
            local skip = false
            if protectMutated and entry.Mutation ~= nil and mode ~= "Selected Mutations" then
                skip = true
            end
            if not skip and keepPerType > 0 and (counts[entry.BeeId] or 0) <= keepPerType then
                skip = true
            end
            if not skip and matchesDeleteFilter(entry) then
                result[#result + 1] = entry
                counts[entry.BeeId] = (counts[entry.BeeId] or 1) - 1
            end
        end
    end
    return result
end

local function toolForUUID(uuid)
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local character = LocalPlayer.Character
    for _, container in ipairs({ backpack, character }) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute(ToolBuilderShared.ATTR_UUID) == uuid then
                    return tool
                end
            end
        end
    end
    return nil
end

local function trashBee(uuid)
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return false
    end
    local tool = toolForUUID(uuid)
    if not tool then
        return false
    end
    humanoid:EquipTool(tool)
    task.wait()
    local held = character:FindFirstChildOfClass("Tool")
    if not held or held:GetAttribute(ToolBuilderShared.ATTR_UUID) ~= uuid then
        return false
    end
    pcall(function()
        Packets.TrashBee:Fire()
    end)
    return true
end

local function doAutoDelete()
    local candidates = collectDeletable()
    local maxPer = tonumber(Options.DeleteMaxPerCycle.Value) or 10
    local delay = tonumber(Options.DeleteActionDelay.Value) or 0.3
    local done = 0
    for _, entry in ipairs(candidates) do
        if Library.Unloaded or not Toggles.AutoDelete.Value then
            return
        end
        if done >= maxPer then
            return
        end
        if trashBee(entry.UUID) then
            done = done + 1
            if Toggles.DeleteNotify.Value then
                local def = BeeConfig.Get(entry.BeeId)
                Library:Notify(("Deleted %s"):format(def and def.Name or entry.BeeId))
            end
            task.wait(delay)
        end
    end
end

local function deleteMatchingNow()
    local maxPer = tonumber(Options.DeleteMaxPerCycle.Value) or 10
    local delay = tonumber(Options.DeleteActionDelay.Value) or 0.3
    local candidates = collectDeletable()
    local done = 0
    for _, entry in ipairs(candidates) do
        if Library.Unloaded or done >= maxPer then
            break
        end
        if trashBee(entry.UUID) then
            done = done + 1
            task.wait(delay)
        end
    end
    Library:Notify(("Deleted %d bee(s)"):format(done))
end

local Window = Library:CreateWindow({
    Title = "Grow a Beehive",
    Footer = "Ouroboros Hub",
    Size = UDim2.fromOffset(900, 640),
    ShowCustomCursor = false,
})

Library.ShowCustomCursor = false

local Tabs = {
    Main = Window:AddTab("Main", "flower"),
    Upgrades = Window:AddTab("Upgrades", "trending-up"),
    Delete = Window:AddTab("Auto Delete", "trash-2"),
    Settings = Window:AddTab("Settings", "settings"),
}

local function AddDiscordButton(Tab)
    Tab:AddLeftGroupbox("Discord"):AddButton({
        Text = "Join Discord For Dupe",
        Func = copyDiscord,
    })
end

for _, Tab in Tabs do
    AddDiscordButton(Tab)
end

local RollGroup = Tabs.Main:AddLeftGroupbox("Auto Roll", "dices")

RollGroup:AddToggle("AutoRoll", {
    Text = "Auto Roll",
    Default = false,
})

RollGroup:AddSlider("RollDelay", {
    Text = "Roll Delay",
    Default = 2,
    Min = 1.5,
    Max = 10,
    Rounding = 1,
})

RollGroup:AddToggle("RollAutoBuy", {
    Text = "Auto Buy Rolled Bees",
    Default = true,
})

RollGroup:AddDropdown("RollBuyMode", {
    Text = "Buy Mode",
    Values = { "Buy All", "Minimum Rarity", "Specific Rarities" },
    Default = "Minimum Rarity",
    Multi = false,
})

RollGroup:AddDropdown("RollMinRarity", {
    Text = "Minimum Rarity",
    Values = RARITY_ORDER,
    Default = "Rare",
    Multi = false,
})

RollGroup:AddDropdown("RollRarities", {
    Text = "Specific Rarities",
    Values = RARITY_ORDER,
    Default = {},
    Multi = true,
    Callback = function(value)
        wantedRarities = selectedSet(value)
    end,
})

RollGroup:AddInput("RollMinOdds", {
    Text = "Only Buy If 1 in X >=",
    Default = "0",
    Numeric = true,
    Finished = true,
})

RollGroup:AddToggle("RollNotify", {
    Text = "Notify On Buy",
    Default = true,
})

local HoneyGroup = Tabs.Main:AddRightGroupbox("Auto Honey", "droplet")

HoneyGroup:AddToggle("AutoTakeHoney", {
    Text = "Auto Take Honey",
    Default = false,
})

HoneyGroup:AddToggle("AutoSellHoney", {
    Text = "Auto Sell Honey",
    Default = false,
})

HoneyGroup:AddSlider("MinHoneyToSell", {
    Text = "Min Honey To Sell",
    Default = 0,
    Min = 0,
    Max = 100000,
    Rounding = 0,
})

HoneyGroup:AddSlider("HoneyDelay", {
    Text = "Loop Delay",
    Default = 1,
    Min = 0.2,
    Max = 10,
    Rounding = 1,
})

local EquipGroup = Tabs.Main:AddRightGroupbox("Auto Equip", "sparkles")

EquipGroup:AddToggle("AutoEquipBest", {
    Text = "Auto Equip Best",
    Default = false,
})

EquipGroup:AddSlider("EquipDelay", {
    Text = "Loop Delay",
    Default = 5,
    Min = 1,
    Max = 30,
    Rounding = 1,
})

local UpgradeGroup = Tabs.Upgrades:AddLeftGroupbox("Auto Upgrades", "trending-up")

UpgradeGroup:AddToggle("AutoUpgrade", {
    Text = "Auto Upgrade",
    Default = false,
})

UpgradeGroup:AddDropdown("Upgrades", {
    Text = "Upgrades To Buy",
    Values = UPGRADE_IDS,
    Default = {},
    Multi = true,
    Callback = function(value)
        selectedUpgrades = selectedSet(value)
    end,
})

UpgradeGroup:AddToggle("AutoExpandHive", {
    Text = "Auto Expand Hive",
    Default = false,
})

UpgradeGroup:AddInput("UpgradeReserve", {
    Text = "Keep Cash Reserve",
    Default = "0",
    Numeric = true,
    Finished = true,
})

UpgradeGroup:AddSlider("UpgradeDelay", {
    Text = "Loop Delay",
    Default = 1,
    Min = 0.2,
    Max = 10,
    Rounding = 1,
})

local BeeUpgradeGroup = Tabs.Upgrades:AddLeftGroupbox("Auto Upgrade Bees", "arrow-up-circle")

BeeUpgradeGroup:AddToggle("AutoUpgradeBees", {
    Text = "Auto Upgrade Bees",
    Default = false,
})

BeeUpgradeGroup:AddSlider("BeeMaxLevel", {
    Text = "Max Bee Level",
    Default = ProductionMath.MaxLevel,
    Min = 1,
    Max = ProductionMath.MaxLevel,
    Rounding = 0,
})

BeeUpgradeGroup:AddInput("BeeMaxCost", {
    Text = "Max Cost Per Upgrade (0 = off)",
    Default = "0",
    Numeric = true,
    Finished = true,
})

BeeUpgradeGroup:AddInput("BeeUpgradeReserve", {
    Text = "Keep Cash Reserve",
    Default = "0",
    Numeric = true,
    Finished = true,
})

BeeUpgradeGroup:AddSlider("BeeUpgradeDelay", {
    Text = "Loop Delay",
    Default = 1,
    Min = 0.2,
    Max = 10,
    Rounding = 1,
})

local HiveGroup = Tabs.Upgrades:AddRightGroupbox("Auto Buy Hives", "hexagon")

HiveGroup:AddToggle("AutoBuyHives", {
    Text = "Auto Buy Hives",
    Default = false,
})

HiveGroup:AddInput("HiveReserve", {
    Text = "Keep Cash Reserve",
    Default = "0",
    Numeric = true,
    Finished = true,
})

HiveGroup:AddSlider("HiveDelay", {
    Text = "Loop Delay",
    Default = 1,
    Min = 0.2,
    Max = 10,
    Rounding = 1,
})

local DeleteGroup = Tabs.Delete:AddLeftGroupbox("Auto Delete Bees", "trash-2")

DeleteGroup:AddToggle("AutoDelete", {
    Text = "Auto Delete Bees",
    Default = false,
})

DeleteGroup:AddDropdown("DeleteMode", {
    Text = "Delete Filter",
    Values = { "Below Minimum Rarity", "Selected Rarities", "Selected Bees", "Selected Mutations" },
    Default = "Below Minimum Rarity",
    Multi = false,
})

DeleteGroup:AddDropdown("DeleteMinRarity", {
    Text = "Delete Below Rarity",
    Values = RARITY_ORDER,
    Default = "Uncommon",
    Multi = false,
})

DeleteGroup:AddDropdown("DeleteRarities", {
    Text = "Rarities To Delete",
    Values = RARITY_ORDER,
    Default = {},
    Multi = true,
    Callback = function(value)
        wantedDeleteRarities = selectedSet(value)
    end,
})

DeleteGroup:AddDropdown("DeleteBees", {
    Text = "Bees To Delete",
    Values = BEE_NAMES,
    Default = {},
    Multi = true,
    Callback = function(value)
        local set = {}
        for name, state in value do
            if state then
                local id = BEE_NAME_TO_ID[name]
                if id then
                    set[id] = true
                end
            end
        end
        wantedDeleteBees = set
    end,
})

DeleteGroup:AddDropdown("DeleteMutations", {
    Text = "Mutations To Delete",
    Values = MUTATION_NAMES,
    Default = {},
    Multi = true,
    Callback = function(value)
        wantedDeleteMutations = selectedSet(value)
    end,
})

local DeleteSafetyGroup = Tabs.Delete:AddRightGroupbox("Filters & Safety", "shield")

DeleteSafetyGroup:AddToggle("DeleteProtectMutated", {
    Text = "Protect Mutated Bees",
    Default = true,
})

DeleteSafetyGroup:AddSlider("DeleteKeepPerType", {
    Text = "Keep Per Bee Type",
    Default = 0,
    Min = 0,
    Max = 50,
    Rounding = 0,
})

DeleteSafetyGroup:AddSlider("DeleteMaxPerCycle", {
    Text = "Max Deletes Per Cycle",
    Default = 10,
    Min = 1,
    Max = 100,
    Rounding = 0,
})

DeleteSafetyGroup:AddSlider("DeleteActionDelay", {
    Text = "Delete Delay",
    Default = 0.3,
    Min = 0.1,
    Max = 2,
    Rounding = 2,
})

DeleteSafetyGroup:AddSlider("DeleteLoopDelay", {
    Text = "Loop Delay",
    Default = 3,
    Min = 0.5,
    Max = 30,
    Rounding = 1,
})

DeleteSafetyGroup:AddToggle("DeleteNotify", {
    Text = "Notify On Delete",
    Default = false,
})

DeleteSafetyGroup:AddButton({
    Text = "Count Matching Bees",
    Func = function()
        Library:Notify(("%d bee(s) match"):format(#collectDeletable()))
    end,
})

DeleteSafetyGroup:AddButton({
    Text = "Delete Matching Now",
    Func = function()
        task.spawn(deleteMatchingNow)
    end,
})

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddLabel("UI Keybind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "UI Keybind",
})

local antiAfkConnection

MenuGroup:AddToggle("AntiAfk", {
    Text = "Anti-AFK",
    Default = true,
    Callback = function(state)
        if state then
            if not antiAfkConnection then
                antiAfkConnection = LocalPlayer.Idled:Connect(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end
        elseif antiAfkConnection then
            antiAfkConnection:Disconnect()
            antiAfkConnection = nil
        end
    end,
})

MenuGroup:AddButton("Unload", function()
    Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

Library:OnUnload(function()
    if antiAfkConnection then
        antiAfkConnection:Disconnect()
        antiAfkConnection = nil
    end
    print("Grow a Beehive unloaded")
end)

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("OuroborosHub")
ThemeManager:SaveDefault("Mint")

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("OuroborosHub/GrowABeehive")
SaveManager:BuildConfigSection(Tabs.Settings)

ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()

SaveManager:LoadAutoloadConfig()

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoRoll.Value then
            doRoll()
        end
        task.wait(Options.RollDelay.Value or 1)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoTakeHoney.Value or Toggles.AutoSellHoney.Value then
            doHoney()
        end
        task.wait(Options.HoneyDelay.Value or 1)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoEquipBest.Value then
            doEquipBest()
        end
        task.wait(Options.EquipDelay.Value or 5)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoUpgrade.Value or Toggles.AutoExpandHive.Value then
            doUpgrades()
        end
        task.wait(Options.UpgradeDelay.Value or 1)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoBuyHives.Value then
            doBuyHives()
        end
        task.wait(Options.HiveDelay.Value or 1)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoUpgradeBees.Value then
            doUpgradeBees()
        end
        task.wait(Options.BeeUpgradeDelay.Value or 1)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoDelete.Value then
            doAutoDelete()
        end
        task.wait(Options.DeleteLoopDelay.Value or 3)
    end
end)

Library:Notify("Grow a Beehive loaded")
