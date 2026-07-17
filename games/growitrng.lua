local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

if getgenv()._GrowItRNG_Unload then
    pcall(getgenv()._GrowItRNG_Unload)
end
getgenv()._GrowItRNG_Unload = function()
    if Library and not Library.Unloaded then
        Library:Unload()
    end
end

local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PlantSeed = Remotes:WaitForChild("PlantSeed")
local PlaceBed = Remotes:WaitForChild("PlaceBed")
local PlaceSellTable = Remotes:WaitForChild("PlaceSellTable")
local PlaceCrate = Remotes:WaitForChild("PlaceCrate")
local DepositCrop = Remotes:WaitForChild("DepositCrop")
local CustomerOffer = Remotes:WaitForChild("CustomerOffer")
local CustomerOfferClear = Remotes:WaitForChild("CustomerOfferClear")
local CustomerDecision = Remotes:WaitForChild("CustomerDecision")
local BuySeedRequest = Remotes:WaitForChild("BuySeedRequest")
local BuyStructure = Remotes:WaitForChild("BuyStructure")
local OpenCrateCash = Remotes:WaitForChild("OpenCrateCash")
local BuyUpgrade = Remotes:WaitForChild("BuyUpgrade")
local QuestClaim = Remotes:WaitForChild("QuestClaim")
local PlaytimeClaim = Remotes:WaitForChild("PlaytimeClaim")
local RebirthRequest = Remotes:WaitForChild("RebirthRequest")
local RebirthBuyUpgrade = Remotes:WaitForChild("RebirthBuyUpgrade")
local TrashHeld = Remotes:WaitForChild("TrashHeld")
local PlaceTotem = Remotes:WaitForChild("PlaceTotem")
local PlaceDecoration = Remotes:WaitForChild("PlaceDecoration")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local SeedData = require(Modules:WaitForChild("SeedData"))
local PetData = require(Modules:WaitForChild("PetData"))
local RebirthConfig = require(Modules:WaitForChild("RebirthConfig"))
local BedData = require(Modules:WaitForChild("BedData"))
local SellTableData = require(Modules:WaitForChild("SellTableData"))
local TotemData = require(Modules:WaitForChild("TotemData"))
local DecorationData = require(Modules:WaitForChild("DecorationData"))
local GearData = require(Modules:WaitForChild("GearData"))
local CrateData = require(Modules:WaitForChild("CrateData"))

local seedNames, seedIdByName, seedNameById, seedDisplayNameById, seedTierById = {}, {}, {}, {}, {}
for _, v in ipairs(SeedData.List) do
    local label = string.format("%s (t%s)", v.name, tostring(v.tier))
    table.insert(seedNames, label)
    seedIdByName[label] = v.id
    seedNameById[v.id] = label
    seedDisplayNameById[v.id] = v.name
    seedTierById[v.id] = tonumber(v.tier) or 0
end

local petNames = {}
for _, v in ipairs(PetData.Pets) do
    if v.model then
        table.insert(petNames, v.model)
    end
end

local rebirthUpgradeNames, rebirthUpgradeKey = {}, {}
for _, v in ipairs(RebirthConfig.Upgrades) do
    table.insert(rebirthUpgradeNames, v.name)
    rebirthUpgradeKey[v.name] = v.key
end

local rebirthItemNames, rebirthItemKey = {}, {}
for _, v in ipairs(RebirthConfig.Items) do
    table.insert(rebirthItemNames, v.name)
    rebirthItemKey[v.name] = v.key
end

local function buildShopEntries(list)
    local names, idByName, priceByName = {}, {}, {}
    for _, v in ipairs(list) do
        local price = v.cost or v.cashCost or 0
        local label = string.format("%s ($%s)", v.name, tostring(price))
        table.insert(names, label)
        idByName[label] = v.id
        priceByName[label] = price
    end
    return names, idByName, priceByName
end

local bedNames, bedIdByName, bedPriceByName = buildShopEntries(BedData.List)
local tableNames, tableIdByName, tablePriceByName = buildShopEntries(SellTableData.List)
local totemNames, totemIdByName, totemPriceByName = buildShopEntries(TotemData.List)
local decorNames, decorIdByName, decorPriceByName = buildShopEntries(DecorationData.List)
local gearNames, gearIdByName, gearPriceByName = buildShopEntries(GearData.List)
local crateNames, crateIdByName, cratePriceByName = buildShopEntries(CrateData.List)

local placeShopNames, placeShopLabelByKey = {}, {}
local function addPlaceShopEntries(kind, names, ids)
    for _, name in ipairs(names) do
        local displayKind = kind == "SellTable" and "Sell Table" or kind
        local label = displayKind .. " | " .. name
        local itemId = ids[name]
        table.insert(placeShopNames, label)
        placeShopLabelByKey[kind .. ":" .. tostring(itemId)] = label
    end
end
addPlaceShopEntries("Bed", bedNames, bedIdByName)
addPlaceShopEntries("SellTable", tableNames, tableIdByName)
addPlaceShopEntries("Totem", totemNames, totemIdByName)
addPlaceShopEntries("Decoration", decorNames, decorIdByName)
addPlaceShopEntries("Crate", crateNames, crateIdByName)

local trashShopNames, trashShopLabelByKey = {}, {}
local function addTrashShopEntries(kind, names, ids)
    for _, name in ipairs(names) do
        local displayKind = kind == "SellTable" and "Sell Table" or kind
        local label = displayKind .. " | " .. name
        local itemId = ids[name]
        table.insert(trashShopNames, label)
        trashShopLabelByKey[kind .. ":" .. tostring(itemId)] = label
    end
end
addTrashShopEntries("Bed", bedNames, bedIdByName)
addTrashShopEntries("SellTable", tableNames, tableIdByName)
addTrashShopEntries("Totem", totemNames, totemIdByName)
addTrashShopEntries("Decoration", decorNames, decorIdByName)
addTrashShopEntries("Gear", gearNames, gearIdByName)
addTrashShopEntries("Crate", crateNames, crateIdByName)

local sprinklerList = {}
for _, v in ipairs(DecorationData.List) do
    if string.find(v.name, "Sprinkler") then
        table.insert(sprinklerList, v)
    end
end
local sprinklerNames, sprinklerIdByName, sprinklerPriceByName = buildShopEntries(sprinklerList)

local wateringCanList = {}
for _, v in ipairs(GearData.List) do
    if string.find(v.name, "Watering Can") then
        table.insert(wateringCanList, v)
    end
end
local wateringCanNames, wateringCanIdByName, wateringCanPriceByName = buildShopEntries(wateringCanList)

local playtimeMinutes = {}
local playtimeCfg = ReplicatedStorage:FindFirstChild("PlaytimeRewardsConfig")
if playtimeCfg then
    for _, c in ipairs(playtimeCfg:GetChildren()) do
        local m = c:GetAttribute("Minutes") or c:GetAttribute("minutes") or tonumber(c.Name)
        if m then
            table.insert(playtimeMinutes, m)
        end
    end
    table.sort(playtimeMinutes)
end

local function ownsModel(model)
    return model and model:GetAttribute("OwnerUserId") == LocalPlayer.UserId
end

local function myPlot()
    local plots = workspace:FindFirstChild("Plots")
    local id = LocalPlayer:GetAttribute("PlotId")
    return plots and id and plots:FindFirstChild("Plot" .. tostring(id))
end

local function ownedToolsOfKind(kind)
    local result = {}
    local character = LocalPlayer.Character
    if character then
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Tool") and child:GetAttribute("ToolKind") == kind then
                table.insert(result, child)
            end
        end
    end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            if child:IsA("Tool") and child:GetAttribute("ToolKind") == kind then
                table.insert(result, child)
            end
        end
    end
    return result
end

local function equipTool(tool)
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:EquipTool(tool)
    end
end

local function ownedBedSlots()
    local empty, growing, ripe = {}, {}, {}
    for _, slot in ipairs(CollectionService:GetTagged("GardenBedSlot")) do
        if slot:IsDescendantOf(workspace) and ownsModel(slot.Parent) then
            local seedId = slot:GetAttribute("SeedId") or 0
            if seedId == 0 then
                table.insert(empty, slot)
            elseif slot:GetAttribute("Ripe") == true then
                table.insert(ripe, slot)
            else
                table.insert(growing, slot)
            end
        end
    end
    return empty, growing, ripe
end

local function emptyTableSlots()
    local result = {}
    for _, slot in ipairs(CollectionService:GetTagged("SellTableSlot")) do
        if slot:IsDescendantOf(workspace) and ownsModel(slot.Parent) and (slot:GetAttribute("CropId") or 0) == 0 then
            table.insert(result, slot)
        end
    end
    return result
end

local organizeBase
local organizingBase = false
local farmRevision = 0
local growRevision = 0
local placingOwnedItem = false

local Window = Library:CreateWindow({
    Title = "Ouroboros Hub",
    Footer = "https://discord.gg/ehKVq7pf7v | Grow it RNG",
    Icon = 18657887261,
    NotifySide = "Right",
    ShowCustomCursor = false,
    Size = UDim2.fromOffset(940, 720),
})

local Tabs = {
    Main = Window:AddTab("Main Tab", "sprout"),
    Shop = Window:AddTab("Shop", "store"),
    Player = Window:AddTab("Player", "user"),
    Settings = Window:AddTab("Settings", "settings"),
}

local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"

local function AddDiscordButton(Tab, addOrganize)
    local DiscordBox = Tab:AddLeftGroupbox("Discord", "message-circle", true, false, true)
    DiscordBox:AddButton({
        Text = "Join Discord For Dupe",
        Func = function()
            setclipboard(DISCORD_INVITE)
            Library:Notify("Copied Discord invite to clipboard")
        end,
    })
    if addOrganize then
        DiscordBox:AddButton("Organize Base", function()
            if organizeBase then task.spawn(organizeBase) end
        end)
    end
end

for name, Tab in Tabs do
    AddDiscordButton(Tab, name == "Main")
end

local Toggles = Library.Toggles
local Options = Library.Options

local function selectedList(value, map)
    local out = {}
    for name in pairs(value) do
        local key = map[name]
        if key ~= nil then
            table.insert(out, key)
        end
    end
    return out
end

-- Auto Plant
local PlantBox = Tabs.Main:AddLeftGroupbox("Auto Plant", "shovel")
PlantBox:AddToggle("AutoPlant", { Text = "Auto Plant Seeds", Default = false })
PlantBox:AddSlider("PlantInterval", { Text = "Plant interval", Default = 0.5, Min = 0.1, Max = 5, Rounding = 1, Suffix = "s" })
PlantBox:AddDropdown("PlantSeedLogic", {
    Values = { "Highest Weight", "Highest Tier", "Closest to Target Weight", "Lowest Weight", "Lowest Tier", "Random", "Inventory Order" },
    Default = 1,
    Text = "Auto Plant Seed Logic",
})
PlantBox:AddDropdown("PlantSeeds", {
    Values = seedNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Seeds allowed (none = all)",
})
PlantBox:AddInput("PlantMinWeight", { Text = "Minimum seed weight (g, 0 = off)", Default = "0", Numeric = true, Finished = true })
PlantBox:AddInput("PlantMaxWeight", { Text = "Maximum seed weight (g, 0 = off)", Default = "0", Numeric = true, Finished = true })
PlantBox:AddInput("PlantTargetWeight", { Text = "Target seed weight (g)", Default = "5", Numeric = true, Finished = true })
PlantBox:AddDivider()
PlantBox:AddToggle("AutoPlaceShopItems", { Text = "Auto Place Shop Items", Default = false })
PlantBox:AddDropdown("PlaceShopItems", {
    Values = placeShopNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Shop items to place",
})
PlantBox:AddSlider("PlaceShopInterval", { Text = "Shop item place interval", Default = 1, Min = 0.2, Max = 10, Rounding = 1, Suffix = "s" })

-- Auto Buy Seeds (separate)
local BuyBox = Tabs.Main:AddLeftGroupbox("Auto Buy Seeds", "shopping-cart")
BuyBox:AddToggle("AutoBuySeeds", { Text = "Auto Buy Seeds", Default = false })
BuyBox:AddDropdown("BuySeeds", {
    Values = seedNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Seeds to buy",
})
BuyBox:AddSlider("BuyAmount", { Text = "Buys per cycle", Default = 6, Min = 1, Max = 50, Rounding = 0 })
BuyBox:AddSlider("BuyInterval", { Text = "Buy interval", Default = 0.5, Min = 0.1, Max = 5, Rounding = 1, Suffix = "s" })

-- Grow & Harvest
local GrowBox = Tabs.Main:AddLeftGroupbox("Grow & Harvest", "sun")
GrowBox:AddToggle("AutoGrow", { Text = "Auto Grow Rush", Default = false })
GrowBox:AddSlider("GrowClicks", { Text = "Rush taps per crop", Default = 10, Min = 1, Max = 40, Rounding = 0 })
GrowBox:AddSlider("GrowTapDelay", { Text = "Rush tap delay", Default = 0.05, Min = 0.03, Max = 0.2, Rounding = 2, Suffix = "s" })
GrowBox:AddSlider("GrowInterval", { Text = "Grow rush interval", Default = 0.3, Min = 0.1, Max = 5, Rounding = 1, Suffix = "s" })
GrowBox:AddDivider()
GrowBox:AddToggle("AutoHarvest", { Text = "Auto Harvest", Default = false })
GrowBox:AddSlider("HarvestInterval", { Text = "Harvest interval", Default = 0.5, Min = 0.1, Max = 5, Rounding = 1, Suffix = "s" })

-- Expansion & Farm Upgrades
local UpgradeBox = Tabs.Main:AddLeftGroupbox("Expansion & Upgrades", "trending-up")
UpgradeBox:AddToggle("AutoExpand", { Text = "Auto Expansion", Default = false })
UpgradeBox:AddSlider("ExpandInterval", { Text = "Expansion interval", Default = 1, Min = 0.2, Max = 10, Rounding = 1, Suffix = "s" })
UpgradeBox:AddDivider()
UpgradeBox:AddToggle("AutoUpgrade", { Text = "Auto Farm Upgrades", Default = false })
UpgradeBox:AddDropdown("FarmUpgrades", {
    Values = { "Grow", "Eat" }, Default = {}, Multi = true, AllowNull = true,
    Text = "Farm upgrades to buy",
})
UpgradeBox:AddSlider("UpgradeInterval", { Text = "Upgrade interval", Default = 1, Min = 0.2, Max = 10, Rounding = 1, Suffix = "s" })

-- Selling
local SellBox = Tabs.Main:AddRightGroupbox("Selling", "coins")
SellBox:AddToggle("AutoDeposit", { Text = "Auto Place Seeds on Table", Default = false })
SellBox:AddSlider("DepositInterval", { Text = "Place interval", Default = 0.5, Min = 0.1, Max = 5, Rounding = 1, Suffix = "s" })
SellBox:AddDivider()
SellBox:AddToggle("AutoAccept", { Text = "Auto Accept Customer Offer", Default = false })
SellBox:AddInput("MinPrice", { Text = "Minimum offer price", Default = "0", Numeric = true, Finished = true })
SellBox:AddToggle("DeclineBelow", { Text = "Decline Offers Below Minimum", Default = false })
SellBox:AddDivider()
SellBox:AddToggle("AutoRush", { Text = "Auto Rush Customer", Default = false })
SellBox:AddSlider("RushInterval", { Text = "Rush interval", Default = 0.5, Min = 0.1, Max = 5, Rounding = 1, Suffix = "s" })

-- Wild Pets
local PetBox = Tabs.Main:AddRightGroupbox("Wild Pets", "paw-print")
PetBox:AddToggle("AutoCatch", { Text = "Auto Catch Wild Pets", Default = false })
PetBox:AddDropdown("CatchPets", {
    Values = petNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Pets to catch (none = all)",
})
PetBox:AddInput("MaxCatchPrice", { Text = "Max catch price (0 = any)", Default = "0", Numeric = true, Finished = true })
PetBox:AddSlider("CatchInterval", { Text = "Catch interval", Default = 0.5, Min = 0.1, Max = 5, Rounding = 1, Suffix = "s" })

-- Rewards
local RewardBox = Tabs.Main:AddRightGroupbox("Rewards", "gift")
RewardBox:AddToggle("AutoQuests", { Text = "Auto Claim Quests", Default = false })
RewardBox:AddSlider("QuestInterval", { Text = "Quest claim interval", Default = 2, Min = 0.5, Max = 15, Rounding = 1, Suffix = "s" })
RewardBox:AddDivider()
RewardBox:AddToggle("AutoPlaytime", { Text = "Auto Claim Playtime Rewards", Default = false })
RewardBox:AddSlider("PlaytimeInterval", { Text = "Playtime claim interval", Default = 5, Min = 1, Max = 30, Rounding = 0, Suffix = "s" })

-- Rebirth
local RebirthBox = Tabs.Main:AddRightGroupbox("Rebirth", "repeat")
RebirthBox:AddToggle("AutoRebirth", { Text = "Auto Rebirth", Default = false })
RebirthBox:AddToggle("AutoRebirthUpgrades", { Text = "Auto Buy Rebirth Upgrades", Default = false })
RebirthBox:AddDropdown("RebirthUpgrades", {
    Values = rebirthUpgradeNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Rebirth upgrades to buy",
})
RebirthBox:AddToggle("AutoRebirthItems", { Text = "Auto Buy Rebirth Items", Default = false })
RebirthBox:AddDropdown("RebirthItems", {
    Values = rebirthItemNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Rebirth items to buy",
})
RebirthBox:AddSlider("RebirthInterval", { Text = "Rebirth interval", Default = 1, Min = 0.2, Max = 10, Rounding = 1, Suffix = "s" })

-- Shop
local ShopBox = Tabs.Shop:AddLeftGroupbox("Auto Buy Shop", "shopping-bag")
ShopBox:AddToggle("AutoBuyShop", { Text = "Auto Buy Shop", Default = false })
ShopBox:AddSlider("ShopBuyAmount", { Text = "Buys per cycle", Default = 5, Min = 1, Max = 50, Rounding = 0 })
ShopBox:AddSlider("ShopInterval", { Text = "Shop interval", Default = 1, Min = 0.2, Max = 10, Rounding = 1, Suffix = "s" })
ShopBox:AddInput("ShopKeepCash", { Text = "Keep cash reserve", Default = "0", Numeric = true, Finished = true })

local StructureBox = Tabs.Shop:AddLeftGroupbox("Structures", "layout-grid")
StructureBox:AddDropdown("BuyBeds", {
    Values = bedNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Beds to buy",
})
StructureBox:AddDropdown("BuySellTables", {
    Values = tableNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Sell tables to buy",
})
StructureBox:AddDropdown("BuyTotems", {
    Values = totemNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Totems to buy",
})

local CosmeticBox = Tabs.Shop:AddRightGroupbox("Gear & Decorations", "swords")
CosmeticBox:AddDropdown("BuyGear", {
    Values = gearNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Gear to buy",
})
CosmeticBox:AddDropdown("BuyDecorations", {
    Values = decorNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Decorations to buy",
})

local SprinklerBox = Tabs.Shop:AddLeftGroupbox("Sprinklers", "droplets")
SprinklerBox:AddToggle("AutoBuySprinklers", { Text = "Auto Buy Sprinklers", Default = false })
SprinklerBox:AddDropdown("BuySprinklers", {
    Values = sprinklerNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Sprinklers to buy",
})
SprinklerBox:AddSlider("SprinklerAmount", { Text = "Buys per cycle", Default = 1, Min = 1, Max = 20, Rounding = 0 })
SprinklerBox:AddSlider("SprinklerInterval", { Text = "Sprinkler interval", Default = 1, Min = 0.2, Max = 10, Rounding = 1, Suffix = "s" })

local WateringCanBox = Tabs.Shop:AddLeftGroupbox("Watering Cans", "droplet")
WateringCanBox:AddToggle("AutoBuyWateringCans", { Text = "Auto Buy Watering Cans", Default = false })
WateringCanBox:AddDropdown("BuyWateringCans", {
    Values = wateringCanNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Watering cans to buy",
})
WateringCanBox:AddSlider("WateringCanAmount", { Text = "Buys per cycle", Default = 1, Min = 1, Max = 20, Rounding = 0 })
WateringCanBox:AddSlider("WateringCanInterval", { Text = "Watering can interval", Default = 1, Min = 0.2, Max = 10, Rounding = 1, Suffix = "s" })

local CrateBox = Tabs.Shop:AddRightGroupbox("Crates", "package")
CrateBox:AddToggle("AutoBuyCrates", { Text = "Auto Buy Crates", Default = false })
CrateBox:AddDropdown("BuyCrates", {
    Values = crateNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Crates to open",
})
CrateBox:AddSlider("CrateInterval", { Text = "Crate interval", Default = 2, Min = 0.5, Max = 15, Rounding = 1, Suffix = "s" })

local TrashBox = Tabs.Main:AddRightGroupbox("Auto Trash", "trash-2")
TrashBox:AddToggle("AutoTrash", { Text = "Auto Trash Items", Default = false })
TrashBox:AddDropdown("TrashSeeds", {
    Values = seedNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Seeds to trash",
})
TrashBox:AddDropdown("TrashShopItems", {
    Values = trashShopNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Shop items to trash",
})
TrashBox:AddInput("KeepWeight", { Text = "Keep at or above weight (g, 0 = off)", Default = "0", Numeric = true, Finished = true })
TrashBox:AddSlider("TrashInterval", { Text = "Trash interval", Default = 0.5, Min = 0.1, Max = 5, Rounding = 1, Suffix = "s" })

local UseBox = Tabs.Shop:AddRightGroupbox("Use Items", "package-open")
UseBox:AddToggle("AutoPlaceTotems", { Text = "Auto Place Totems", Default = false })
UseBox:AddDropdown("PlaceTotems", {
    Values = totemNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Totems to place (none = all)",
})
UseBox:AddSlider("TotemPlaceInterval", { Text = "Totem place interval", Default = 1, Min = 0.2, Max = 10, Rounding = 1, Suffix = "s" })
UseBox:AddDivider()
UseBox:AddToggle("AutoUseSprinklers", { Text = "Auto Use Sprinklers", Default = false })
UseBox:AddDropdown("UseSprinklers", {
    Values = sprinklerNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Sprinklers to use (none = all)",
})
UseBox:AddSlider("UseSprinklerInterval", { Text = "Sprinkler use interval", Default = 1, Min = 0.2, Max = 10, Rounding = 1, Suffix = "s" })
UseBox:AddDivider()
UseBox:AddToggle("AutoUseWateringCans", { Text = "Auto Use Watering Cans", Default = false })
UseBox:AddDropdown("UseWateringCans", {
    Values = wateringCanNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Watering cans to use (none = all)",
})
UseBox:AddSlider("UseWateringCanInterval", { Text = "Watering can use interval", Default = 0.5, Min = 0.2, Max = 10, Rounding = 1, Suffix = "s" })

local MovementBox = Tabs.Player:AddLeftGroupbox("Movement")
MovementBox:AddToggle("WalkSpeedEnabled", { Text = "Walk Speed", Default = false })
MovementBox:AddSlider("WalkSpeed", { Text = "Walk speed", Default = 16, Min = 16, Max = 300, Rounding = 0 })
MovementBox:AddToggle("Fly", { Text = "Fly", Default = false })
MovementBox:AddSlider("FlySpeed", { Text = "Fly speed", Default = 60, Min = 10, Max = 300, Rounding = 0 })
MovementBox:AddToggle("Noclip", { Text = "Noclip", Default = false })
MovementBox:AddToggle("InfiniteJump", { Text = "Infinite Jump", Default = false })

local ESPBox = Tabs.Player:AddRightGroupbox("ESP")
ESPBox:AddToggle("SeedSizeESP", { Text = "Seed Size ESP", Default = false })
ESPBox:AddToggle("PetESP", { Text = "Pet ESP", Default = false })

local shopCategories = {
    { kind = "Bed", option = "BuyBeds", ids = bedIdByName, prices = bedPriceByName },
    { kind = "SellTable", option = "BuySellTables", ids = tableIdByName, prices = tablePriceByName },
    { kind = "Totem", option = "BuyTotems", ids = totemIdByName, prices = totemPriceByName },
    { kind = "Gear", option = "BuyGear", ids = gearIdByName, prices = gearPriceByName },
    { kind = "Decoration", option = "BuyDecorations", ids = decorIdByName, prices = decorPriceByName },
}

local function rootPart()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local flyVelocity
local flyUp = false
local flyDown = false
local collisionStates = {}
local walkSpeedOriginals = {}
local seedEspObjects = {}
local petEspObjects = {}
local playerConnections = {}

local function humanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function restoreWalkSpeed()
    for hum, speed in pairs(walkSpeedOriginals) do
        if hum.Parent then
            hum.WalkSpeed = speed
        end
        walkSpeedOriginals[hum] = nil
    end
end

local function restoreNoclip()
    for part, canCollide in pairs(collisionStates) do
        if part.Parent then
            part.CanCollide = canCollide
        end
        collisionStates[part] = nil
    end
end

local function stopFlying()
    if flyVelocity then
        flyVelocity:Destroy()
        flyVelocity = nil
    end
    flyUp = false
    flyDown = false
end

local function makeEspLabel(adornee, text, color)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "_OuroborosESP"
    billboard.Adornee = adornee
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 1000
    billboard.Size = UDim2.fromOffset(220, 32)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Parent = adornee

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.Text = text
    label.TextColor3 = color
    label.TextSize = 14
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.Parent = billboard
    return billboard, label
end

local function clearSeedEsp()
    for slot, entry in pairs(seedEspObjects) do
        if entry.gui then entry.gui:Destroy() end
        seedEspObjects[slot] = nil
    end
end

local function clearPetEsp()
    for pet, entry in pairs(petEspObjects) do
        if entry.gui then entry.gui:Destroy() end
        if entry.highlight then entry.highlight:Destroy() end
        petEspObjects[pet] = nil
    end
end

local function updateSeedEsp()
    local seen = {}
    for _, slot in ipairs(CollectionService:GetTagged("GardenBedSlot")) do
        local seedId = slot:GetAttribute("SeedId") or 0
        if slot:IsDescendantOf(workspace) and seedId ~= 0 and slot:IsA("BasePart") then
            seen[slot] = true
            local entry = seedEspObjects[slot]
            if not entry or not entry.gui.Parent then
                if entry and entry.gui then entry.gui:Destroy() end
                local gui, label = makeEspLabel(slot, "", Color3.fromRGB(95, 255, 150))
                entry = { gui = gui, label = label }
                seedEspObjects[slot] = entry
            end
            local weight = tonumber(slot:GetAttribute("SeedWeight")) or 0
            entry.label.Text = string.format("%s | %.1fg", seedDisplayNameById[seedId] or "Seed", weight)
        end
    end
    for slot, entry in pairs(seedEspObjects) do
        if not seen[slot] then
            if entry.gui then entry.gui:Destroy() end
            seedEspObjects[slot] = nil
        end
    end
end

local function updatePetEsp()
    local runtime = workspace:FindFirstChild("PetsRuntime")
    local seen = {}
    if runtime then
        for _, pet in ipairs(runtime:GetChildren()) do
            local part = pet:IsA("Model") and (pet.PrimaryPart or pet:FindFirstChildWhichIsA("BasePart", true))
            if part then
                seen[pet] = true
                local entry = petEspObjects[pet]
                if not entry or not entry.gui.Parent then
                    if entry then
                        if entry.gui then entry.gui:Destroy() end
                        if entry.highlight then entry.highlight:Destroy() end
                    end
                    local gui, label = makeEspLabel(part, pet.Name, Color3.fromRGB(255, 190, 80))
                    local highlight = Instance.new("Highlight")
                    highlight.Name = "_OuroborosPetESP"
                    highlight.Adornee = pet
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.FillColor = Color3.fromRGB(255, 190, 80)
                    highlight.FillTransparency = 0.8
                    highlight.OutlineColor = Color3.fromRGB(255, 235, 170)
                    highlight.OutlineTransparency = 0
                    highlight.Parent = pet
                    entry = { gui = gui, label = label, highlight = highlight }
                    petEspObjects[pet] = entry
                end
                entry.label.Text = pet.Name
            end
        end
    end
    for pet, entry in pairs(petEspObjects) do
        if not seen[pet] then
            if entry.gui then entry.gui:Destroy() end
            if entry.highlight then entry.highlight:Destroy() end
            petEspObjects[pet] = nil
        end
    end
end

table.insert(playerConnections, UserInputService.InputBegan:Connect(function(input, processed)
    if processed or Library.Unloaded or not Toggles.Fly.Value then return end
    if input.KeyCode == Enum.KeyCode.Space then
        flyUp = true
    elseif input.KeyCode == Enum.KeyCode.LeftControl then
        flyDown = true
    end
end))

table.insert(playerConnections, UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then
        flyUp = false
    elseif input.KeyCode == Enum.KeyCode.LeftControl then
        flyDown = false
    end
end))

table.insert(playerConnections, UserInputService.JumpRequest:Connect(function()
    if Library.Unloaded or not Toggles.InfiniteJump.Value then return end
    local hum = humanoid()
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end))

table.insert(playerConnections, RunService.Heartbeat:Connect(function()
    if Library.Unloaded then return end
    local character = LocalPlayer.Character
    local hum = humanoid()
    local root = rootPart()

    if Toggles.WalkSpeedEnabled.Value and hum then
        if walkSpeedOriginals[hum] == nil then walkSpeedOriginals[hum] = hum.WalkSpeed end
        hum.WalkSpeed = Options.WalkSpeed.Value
    end

    if Toggles.Noclip.Value and character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if collisionStates[part] == nil then collisionStates[part] = part.CanCollide end
                part.CanCollide = false
            end
        end
    end

    if Toggles.Fly.Value and root and hum then
        if not flyVelocity or not flyVelocity.Parent then
            if flyVelocity then flyVelocity:Destroy() end
            flyVelocity = Instance.new("BodyVelocity")
            flyVelocity.Name = "_OuroborosFly"
            flyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            flyVelocity.P = 1250
            flyVelocity.Parent = root
        end
        local vertical = (flyUp and 1 or 0) - (flyDown and 1 or 0)
        flyVelocity.Velocity = hum.MoveDirection * Options.FlySpeed.Value + Vector3.new(0, vertical * Options.FlySpeed.Value, 0)
    elseif flyVelocity then
        stopFlying()
    end
end))

Toggles.WalkSpeedEnabled:OnChanged(function()
    if not Toggles.WalkSpeedEnabled.Value then restoreWalkSpeed() end
end)

Toggles.Noclip:OnChanged(function()
    if not Toggles.Noclip.Value then restoreNoclip() end
end)

Toggles.Fly:OnChanged(function()
    if not Toggles.Fly.Value then stopFlying() end
end)

Toggles.SeedSizeESP:OnChanged(function()
    if not Toggles.SeedSizeESP.Value then clearSeedEsp() end
end)

Toggles.PetESP:OnChanged(function()
    if not Toggles.PetESP.Value then clearPetEsp() end
end)

task.spawn(function()
    while task.wait(0.25) do
        if Library.Unloaded then break end
        if Toggles.SeedSizeESP.Value then updateSeedEsp() end
        if Toggles.PetESP.Value then updatePetEsp() end
    end
end)

local function selectionContainsItem(selection, itemId, labelsById)
    if next(selection) == nil then return true end
    local label = labelsById[itemId]
    return label ~= nil and selection[label] == true
end

local function labelsById(ids)
    local result = {}
    for label, id in pairs(ids) do
        result[id] = label
    end
    return result
end

local totemLabelById = labelsById(totemIdByName)
local sprinklerLabelById = labelsById(sprinklerIdByName)
local wateringCanLabelById = labelsById(wateringCanIdByName)
local activeWateringCan

Toggles.AutoUseWateringCans:OnChanged(function()
    if not Toggles.AutoUseWateringCans.Value and activeWateringCan then
        pcall(function() activeWateringCan:Deactivate() end)
        activeWateringCan = nil
    end
end)

local function itemModel(tool)
    local itemId = tool:GetAttribute("ItemId")
    local kind = tool:GetAttribute("ToolKind")
    if kind == "Bed" then
        local data = BedData.getById(itemId)
        local folder = ReplicatedStorage.Models:FindFirstChild("Beds")
        return data and folder and folder:FindFirstChild(data.modelName or "")
    end
    if kind == "SellTable" then
        local data = SellTableData.getById(itemId)
        local folder = ReplicatedStorage.Models:FindFirstChild("SellTables")
        return data and folder and folder:FindFirstChild(data.modelName or "")
    end
    if kind == "Totem" then
        local data = TotemData.getById(itemId)
        local folder = ReplicatedStorage.Models:FindFirstChild("Totems")
        return data and folder and folder:FindFirstChild(data.modelName or "")
    end
    if kind == "Crate" then
        local data = CrateData.getById(itemId)
        local folder = ReplicatedStorage.Models:FindFirstChild("Crates")
        return data and folder and folder:FindFirstChild(data.modelName or "")
    end
    local data = DecorationData.getById(itemId)
    local folder = ReplicatedStorage.Models:FindFirstChild("Decorations")
    return data and folder and folder:FindFirstChild(data.modelName or "")
end

local function placementCandidates(tool)
    local plot = myPlot()
    local floor = plot and plot:FindFirstChild("InteriorFloor")
    local model = itemModel(tool)
    if not floor or not model then return {} end
    local boxCFrame, boxSize = model:GetBoundingBox()
    local pivotOffset = model:GetPivot().Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
    local y = floor.Position.Y + floor.Size.Y / 2 + pivotOffset
    local candidates = {}
    local seen = {}
    local nature = plot:FindFirstChild("Nature")
    local halfX = boxSize.X / 2 + 0.5
    local halfZ = boxSize.Z / 2 + 0.5
    local function locked(x, z)
        if not nature then return false end
        for _, region in ipairs(nature:GetChildren()) do
            if region:GetAttribute("Price") ~= nil and not region:GetAttribute("Unlocked") then
                local centerX = region:GetAttribute("CenterX")
                local centerZ = region:GetAttribute("CenterZ")
                local regionHalfX = region:GetAttribute("HalfX") or 15
                local regionHalfZ = region:GetAttribute("HalfZ") or 15
                if centerX and centerZ and math.abs(x - centerX) < halfX + regionHalfX and math.abs(z - centerZ) < halfZ + regionHalfZ then
                    return true
                end
            end
        end
        return false
    end
    local function occupied(x, z)
        for _, tag in ipairs({ "GardenBed", "SellTable", "Totem", "PlacedCrate" }) do
            for _, placed in ipairs(CollectionService:GetTagged(tag)) do
                if placed:IsA("Model") and placed:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                    local placedCFrame, placedSize = placed:GetBoundingBox()
                    if math.abs(x - placedCFrame.X) < halfX + placedSize.X / 2 - 0.3 and math.abs(z - placedCFrame.Z) < halfZ + placedSize.Z / 2 - 0.3 then
                        return true
                    end
                end
            end
        end
        return false
    end
    local function add(x, z)
        local key = string.format("%.1f:%.1f", x, z)
        if not seen[key] and not locked(x, z) and not occupied(x, z) and math.abs(x - floor.Position.X) <= floor.Size.X / 2 - halfX and math.abs(z - floor.Position.Z) <= floor.Size.Z / 2 - halfZ then
            seen[key] = true
            table.insert(candidates, CFrame.new(x, y, z))
        end
    end
    local kind = tool:GetAttribute("ToolKind")
    if kind == "Totem" or kind == "Decoration" then
        local _, growing, ripe = ownedBedSlots()
        for _, slot in ipairs(growing) do
            for _, offset in ipairs({ Vector3.new(5, 0, 0), Vector3.new(-5, 0, 0), Vector3.new(0, 0, 5), Vector3.new(0, 0, -5) }) do
                add(slot.Position.X + offset.X, slot.Position.Z + offset.Z)
            end
        end
        for _, slot in ipairs(ripe) do
            for _, offset in ipairs({ Vector3.new(5, 0, 0), Vector3.new(-5, 0, 0), Vector3.new(0, 0, 5), Vector3.new(0, 0, -5) }) do
                add(slot.Position.X + offset.X, slot.Position.Z + offset.Z)
            end
        end
    end
    local footprint = math.max(boxSize.X, boxSize.Z)
    local margin = math.ceil(footprint / 2) + 1
    local step = math.max(5, math.ceil(footprint + 1))
    for x = -math.floor(floor.Size.X / 2) + margin, math.floor(floor.Size.X / 2) - margin, step do
        for z = -math.floor(floor.Size.Z / 2) + margin, math.floor(floor.Size.Z / 2) - margin, step do
            add(floor.Position.X + x, floor.Position.Z + z)
        end
    end
    local root = rootPart()
    if root then
        table.sort(candidates, function(a, b)
            return (a.Position - root.Position).Magnitude < (b.Position - root.Position).Magnitude
        end)
    end
    return candidates
end

local function placeOwnedTool(tool, remote, shouldContinue)
    if placingOwnedItem then return false end
    placingOwnedItem = true
    equipTool(tool)
    task.wait(0.1)
    for _, cframe in ipairs(placementCandidates(tool)) do
        if Library.Unloaded or not shouldContinue() or not tool.Parent then break end
        remote:FireServer(tool, cframe)
        task.wait(0.3)
        if not tool.Parent then
            placingOwnedItem = false
            return true
        end
    end
    placingOwnedItem = false
    return false
end

local placeRemoteByKind = {
    Bed = PlaceBed,
    SellTable = PlaceSellTable,
    Totem = PlaceTotem,
    Decoration = PlaceDecoration,
    Crate = PlaceCrate,
}

local function shouldTrash(tool)
    local kind = tool:GetAttribute("ToolKind")
    local itemId = tool:GetAttribute("ItemId")
    if kind == "Seed" then
        local seedLabel = seedNameById[itemId]
        if not seedLabel or not Options.TrashSeeds.Value[seedLabel] then return false end
        local keepWeight = tonumber(Options.KeepWeight.Value) or 0
        if keepWeight > 0 and (tonumber(tool:GetAttribute("SeedWeight")) or 0) >= keepWeight then return false end
        return true
    end
    local shopLabel = trashShopLabelByKey[kind .. ":" .. tostring(itemId)]
    return shopLabel ~= nil and Options.TrashShopItems.Value[shopLabel] == true
end

local function ownTrashPrompt()
    local plot = myPlot()
    local trashCan = plot and plot:FindFirstChild("TrashCan")
    return trashCan and trashCan:FindFirstChild("TrashPrompt", true)
end

local function safeFarmLoop(slots, maxDist, shouldContinueFunc, getInteractableFunc, actionFunc)
    local root = rootPart()
    if not root then return end
    local originalCFrame = root.CFrame
    local moved = false

    for _, slot in ipairs(slots) do
        if Library.Unloaded or not shouldContinueFunc() then break end

        local target = getInteractableFunc(slot)
        if target then
            if (root.Position - slot.Position).Magnitude > maxDist then
                root.CFrame = slot.CFrame + Vector3.new(0, 3, 0)
                moved = true
                task.wait(0.15)
            end

            if Library.Unloaded or not shouldContinueFunc() then break end
            actionFunc(slot, target)
        end
    end

    if moved then
        root.CFrame = originalCFrame
    end
end

local function structureModel(tool)
    local kind = tool:GetAttribute("ToolKind")
    local itemId = tool:GetAttribute("ItemId")
    if kind == "Bed" then
        local data = BedData.getById(itemId)
        return data and ReplicatedStorage.Models.Beds:FindFirstChild(data.modelName or "")
    end
    if kind == "SellTable" then
        local data = SellTableData.getById(itemId)
        return data and ReplicatedStorage.Models.SellTables:FindFirstChild(data.modelName or "")
    end
end

local function structureCFrame(tool, x, z, floor)
    local model = structureModel(tool)
    if not model then return nil end
    local boxCFrame, boxSize = model:GetBoundingBox()
    local pivotOffset = model:GetPivot().Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
    return CFrame.new(x, floor.Position.Y + floor.Size.Y / 2 + pivotOffset, z), boxSize
end

local function touchesLockedExpansion(plot, cframe, size)
    local nature = plot:FindFirstChild("Nature")
    if not nature then return false end
    local halfX = size.X / 2 + 0.5
    local halfZ = size.Z / 2 + 0.5
    for _, region in ipairs(nature:GetChildren()) do
        if region:GetAttribute("Price") ~= nil and not region:GetAttribute("Unlocked") then
            local centerX = region:GetAttribute("CenterX")
            local centerZ = region:GetAttribute("CenterZ")
            local regionHalfX = region:GetAttribute("HalfX") or 15
            local regionHalfZ = region:GetAttribute("HalfZ") or 15
            if centerX and centerZ and math.abs(cframe.X - centerX) < halfX + regionHalfX and math.abs(cframe.Z - centerZ) < halfZ + regionHalfZ then
                return true
            end
        end
    end
    return false
end

local function structureCandidates(tool, plot, floor)
    local candidates = {}
    local minX = floor.Position.X - floor.Size.X / 2 + 7
    local maxX = floor.Position.X + floor.Size.X / 2 - 7
    local minZ = floor.Position.Z - floor.Size.Z / 2 + 7
    local maxZ = floor.Position.Z + floor.Size.Z / 2 - 7
    for z = minZ, maxZ, 12 do
        for x = minX, maxX, 12 do
            local cframe, size = structureCFrame(tool, x, z, floor)
            if cframe and not touchesLockedExpansion(plot, cframe, size) then
                table.insert(candidates, cframe)
            end
        end
    end
    return candidates
end

organizeBase = function()
    if organizingBase or Library.Unloaded then return end
    organizingBase = true
    farmRevision = farmRevision + 1
    local plot = myPlot()
    local floor = plot and plot:FindFirstChild("InteriorFloor")
    local root = rootPart()
    if not plot or not floor or not root then
        organizingBase = false
        Library:Notify("Unable to find your plot")
        return
    end
    local originalCFrame = root.CFrame
    local inventoryBefore = {}
    for _, kind in ipairs({ "Bed", "SellTable" }) do
        for _, tool in ipairs(ownedToolsOfKind(kind)) do
            local key = kind .. ":" .. tostring(tool:GetAttribute("ItemId"))
            inventoryBefore[key] = (inventoryBefore[key] or 0) + 1
        end
    end
    local structures = {}
    for _, tag in ipairs({ "GardenBed", "SellTable" }) do
        for _, model in ipairs(CollectionService:GetTagged(tag)) do
            if model:IsA("Model") and model:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                table.insert(structures, model)
            end
        end
    end
    table.sort(structures, function(a, b)
        local aBed = CollectionService:HasTag(a, "GardenBed")
        local bBed = CollectionService:HasTag(b, "GardenBed")
        if aBed ~= bBed then return aBed end
        return (a:GetAttribute("ItemId") or 0) < (b:GetAttribute("ItemId") or 0)
    end)
    for _, model in ipairs(structures) do
        if Library.Unloaded then break end
        local prompt = model:FindFirstChild("PickupPrompt", true)
        local target = prompt and prompt.Parent
        if prompt and target and target:IsA("BasePart") then
            root = rootPart()
            if not root then break end
            root.CFrame = target.CFrame + Vector3.new(0, 3, 0)
            task.wait(0.1)
            fireproximityprompt(prompt)
            local deadline = os.clock() + 2
            repeat task.wait(0.05) until not model.Parent or os.clock() >= deadline or Library.Unloaded
        end
    end
    task.wait(0.5)
    local tools = {}
    local inventoryAfter = {}
    for _, kind in ipairs({ "Bed", "SellTable" }) do
        for _, tool in ipairs(ownedToolsOfKind(kind)) do
            local key = kind .. ":" .. tostring(tool:GetAttribute("ItemId"))
            inventoryAfter[key] = (inventoryAfter[key] or 0) + 1
            if inventoryAfter[key] > (inventoryBefore[key] or 0) then
                table.insert(tools, tool)
            end
        end
    end
    table.sort(tools, function(a, b)
        local aBed = a:GetAttribute("ToolKind") == "Bed"
        local bBed = b:GetAttribute("ToolKind") == "Bed"
        if aBed ~= bBed then return aBed end
        return (a:GetAttribute("ItemId") or 0) < (b:GetAttribute("ItemId") or 0)
    end)
    local occupied = {}
    local placed = 0
    for _, tool in ipairs(tools) do
        if Library.Unloaded then break end
        local remote = tool:GetAttribute("ToolKind") == "Bed" and PlaceBed or PlaceSellTable
        equipTool(tool)
        for _, cframe in ipairs(structureCandidates(tool, plot, floor)) do
            if Library.Unloaded or not tool.Parent then break end
            local key = string.format("%.1f:%.1f", cframe.X, cframe.Z)
            if not occupied[key] then
                remote:FireServer(tool, cframe)
                task.wait(0.2)
                if not tool.Parent then
                    occupied[key] = true
                    placed = placed + 1
                    break
                end
            end
        end
    end
    root = rootPart()
    if root then root.CFrame = originalCFrame end
    organizingBase = false
    farmRevision = farmRevision + 1
    Library:Notify(string.format("Organized %d beds and tables", placed))
end

-- ===== Loops =====

Toggles.AutoPlant:OnChanged(function()
    farmRevision = farmRevision + 1
end)

Toggles.AutoHarvest:OnChanged(function()
    farmRevision = farmRevision + 1
end)

Toggles.AutoGrow:OnChanged(function()
    growRevision = growRevision + 1
end)

local function plantSlot(slot, revision)
    if organizingBase or revision ~= farmRevision or not Toggles.AutoPlant.Value then return end
    local candidates = {}
    local selectedSeeds = Options.PlantSeeds.Value
    local minWeight = tonumber(Options.PlantMinWeight.Value) or 0
    local maxWeight = tonumber(Options.PlantMaxWeight.Value) or 0
    for _, tool in ipairs(ownedToolsOfKind("Seed")) do
        local itemId = tool:GetAttribute("ItemId")
        local weight = tonumber(tool:GetAttribute("SeedWeight")) or 0
        local allowed = next(selectedSeeds) == nil or selectedSeeds[seedNameById[itemId]] == true
        if allowed and (minWeight <= 0 or weight >= minWeight) and (maxWeight <= 0 or weight <= maxWeight) then
            table.insert(candidates, tool)
        end
    end
    if #candidates == 0 then return end
    local logic = Options.PlantSeedLogic.Value
    if logic == "Random" then
        local randomIndex = math.random(1, #candidates)
        candidates[1], candidates[randomIndex] = candidates[randomIndex], candidates[1]
    elseif logic ~= "Inventory Order" then
        local targetWeight = tonumber(Options.PlantTargetWeight.Value) or 0
        table.sort(candidates, function(a, b)
            local aWeight = tonumber(a:GetAttribute("SeedWeight")) or 0
            local bWeight = tonumber(b:GetAttribute("SeedWeight")) or 0
            local aTier = seedTierById[a:GetAttribute("ItemId")] or 0
            local bTier = seedTierById[b:GetAttribute("ItemId")] or 0
            if logic == "Highest Tier" then
                return aTier == bTier and aWeight > bWeight or aTier > bTier
            elseif logic == "Lowest Tier" then
                return aTier == bTier and aWeight > bWeight or aTier < bTier
            elseif logic == "Lowest Weight" then
                return aWeight < bWeight
            elseif logic == "Closest to Target Weight" then
                return math.abs(aWeight - targetWeight) < math.abs(bWeight - targetWeight)
            end
            return aWeight > bWeight
        end)
    end
    local seed = candidates[1]
    if not seed then return end
    equipTool(seed)
    if organizingBase or revision ~= farmRevision or not Toggles.AutoPlant.Value then return end
    pcall(function() PlantSeed:InvokeServer(slot, seed) end)
end

task.spawn(function()
    local nextPlant = 0
    local nextHarvest = 0
    while task.wait(0.05) do
        if Library.Unloaded then break end
        if not organizingBase then
            local now = os.clock()
            local revision = farmRevision
            if Toggles.AutoHarvest.Value and now >= nextHarvest then
                nextHarvest = now + Options.HarvestInterval.Value
                local _, _, ripe = ownedBedSlots()
                safeFarmLoop(ripe, 6, function()
                    return not organizingBase and revision == farmRevision and Toggles.AutoHarvest.Value
                end, function(slot)
                    return slot:FindFirstChild("HarvestPrompt", true)
                end, function(slot, target)
                    if revision ~= farmRevision or not Toggles.AutoHarvest.Value then return end
                    pcall(function() fireproximityprompt(target) end)
                    task.wait(0.05)
                end)
            end
            if Toggles.AutoPlant.Value and now >= nextPlant then
                nextPlant = now + Options.PlantInterval.Value
                local empty, _, ripe = ownedBedSlots()
                if not Toggles.AutoHarvest.Value or #ripe == 0 then
                    for _, slot in ipairs(empty) do
                        if Library.Unloaded or organizingBase or revision ~= farmRevision or not Toggles.AutoPlant.Value then break end
                        plantSlot(slot, revision)
                        task.wait(0.05)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(Options.BuyInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoBuySeeds.Value then
            local ids = selectedList(Options.BuySeeds.Value, seedIdByName)
            if #ids > 0 then
                for i = 1, Options.BuyAmount.Value do
                    if Library.Unloaded or not Toggles.AutoBuySeeds.Value then break end
                    local id = ids[(i - 1) % #ids + 1]
                    pcall(function() BuySeedRequest:InvokeServer(id) end)
                end
            end
        end
    end
end)

task.spawn(function()
    local nextRush = 0
    while task.wait(0.05) do
        if Library.Unloaded then break end
        local now = os.clock()
        if not organizingBase and Toggles.AutoGrow.Value and now >= nextRush then
            nextRush = now + Options.GrowInterval.Value
            local revision = growRevision
            local _, growing = ownedBedSlots()
            safeFarmLoop(growing, 14, function()
                return not organizingBase and revision == growRevision and Toggles.AutoGrow.Value
            end, function(slot)
                return slot:FindFirstChild("SpeedupClick", true) or slot:FindFirstChildOfClass("ClickDetector", true)
            end, function(slot, target)
                for _ = 1, Options.GrowClicks.Value do
                    if Library.Unloaded or organizingBase or revision ~= growRevision or not Toggles.AutoGrow.Value then break end
                    if slot:GetAttribute("Ripe") == true or (slot:GetAttribute("SeedId") or 0) == 0 or not target.Parent then break end
                    pcall(function() fireclickdetector(target) end)
                    task.wait(Options.GrowTapDelay.Value)
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(Options.DepositInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoDeposit.Value then
            if #ownedToolsOfKind("Crop") > 0 then
                for _, slot in ipairs(emptyTableSlots()) do
                    if Library.Unloaded or not Toggles.AutoDeposit.Value then break end
                    local crop = ownedToolsOfKind("Crop")[1]
                    if not crop then break end
                    equipTool(crop)
                    DepositCrop:FireServer(slot, crop)
                    task.wait(0.1)
                end
            end
        end
    end
end)

local pendingOffers = {}

local function resolveOffer(customer, price)
    if not customer or not customer.Parent then return end
    local minPrice = tonumber(Options.MinPrice.Value) or 0
    if (price or 0) >= minPrice then
        pendingOffers[customer] = nil
        pcall(function() CustomerDecision:FireServer(customer, true) end)
    elseif Toggles.DeclineBelow.Value then
        pendingOffers[customer] = nil
        pcall(function() CustomerDecision:FireServer(customer, false) end)
    end
end

CustomerOffer.OnClientEvent:Connect(function(customer, _, price)
    if not customer then return end
    pendingOffers[customer] = price or 0
    if Toggles.AutoAccept.Value then
        resolveOffer(customer, price or 0)
    end
end)

CustomerOfferClear.OnClientEvent:Connect(function(customer)
    if customer then
        pendingOffers[customer] = nil
    else
        table.clear(pendingOffers)
    end
end)

task.spawn(function()
    while task.wait(0.1) do
        if Library.Unloaded then break end
        if Toggles.AutoAccept.Value then
            for customer, price in pairs(pendingOffers) do
                if customer.Parent then
                    resolveOffer(customer, price)
                else
                    pendingOffers[customer] = nil
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(Options.RushInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoRush.Value then
            for _, prompt in ipairs(workspace:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") and prompt.Name == "RushPrompt" then
                    pcall(function() fireproximityprompt(prompt) end)
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(Options.ExpandInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoExpand.Value then
            local plot = myPlot()
            if plot then
                for _, prompt in ipairs(plot:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") and prompt.Name == "UnlockPrompt" then
                        pcall(function() fireproximityprompt(prompt) end)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(Options.UpgradeInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoUpgrade.Value then
            for key in pairs(Options.FarmUpgrades.Value) do
                pcall(function() BuyUpgrade:FireServer(key) end)
            end
        end
    end
end)

task.spawn(function()
    while task.wait(Options.CatchInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoCatch.Value then
            local runtime = workspace:FindFirstChild("PetsRuntime")
            local root = rootPart()
            if runtime and root then
                local wanted = Options.CatchPets.Value
                local hasFilter = next(wanted) ~= nil
                local maxPrice = tonumber(Options.MaxCatchPrice.Value) or 0
                local origin = root.CFrame
                local moved = false
                for _, pet in ipairs(runtime:GetChildren()) do
                    if Library.Unloaded or not Toggles.AutoCatch.Value then break end
                    if (not hasFilter or wanted[pet.Name]) and pet:IsDescendantOf(workspace) then
                        local prompt = pet:FindFirstChildWhichIsA("ProximityPrompt", true)
                        local target = prompt and prompt.Parent
                        if prompt and target and target:IsA("BasePart") then
                            local ok = true
                            if maxPrice > 0 then
                                local priceStr = tostring(prompt.ActionText):match("%$([%d,]+)")
                                local price = priceStr and tonumber((priceStr:gsub(",", ""))) or 0
                                ok = price <= maxPrice
                            end
                            if ok then
                                root = rootPart()
                                if not root then break end
                                root.CFrame = target.CFrame + Vector3.new(0, 4, 0)
                                moved = true
                                task.wait(0.15)
                                if prompt.Parent and prompt.Enabled then
                                    pcall(function() fireproximityprompt(prompt) end)
                                    task.wait(math.max(prompt.HoldDuration + 0.05, 0.1))
                                end
                            end
                        end
                    end
                end
                if moved then
                    root = rootPart()
                    if root then
                        root.CFrame = origin
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(Options.QuestInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoQuests.Value then
            pcall(function() QuestClaim:FireServer() end)
        end
    end
end)

task.spawn(function()
    while task.wait(Options.PlaytimeInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoPlaytime.Value then
            for _, minutes in ipairs(playtimeMinutes) do
                pcall(function() PlaytimeClaim:InvokeServer(minutes) end)
            end
        end
    end
end)

task.spawn(function()
    while task.wait(Options.RebirthInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoRebirthUpgrades.Value then
            for _, key in ipairs(selectedList(Options.RebirthUpgrades.Value, rebirthUpgradeKey)) do
                pcall(function() RebirthBuyUpgrade:InvokeServer(key) end)
            end
        end
        if Toggles.AutoRebirthItems.Value then
            for _, key in ipairs(selectedList(Options.RebirthItems.Value, rebirthItemKey)) do
                pcall(function() RebirthBuyItem:InvokeServer(key) end)
            end
        end
        if Toggles.AutoRebirth.Value then
            local cash = LocalPlayer:GetAttribute("Cash") or 0
            if RebirthConfig.canRebirth(cash) then
                pcall(function() RebirthRequest:FireServer() end)
            end
        end
    end
end)

local function affordable(price)
    local cash = LocalPlayer:GetAttribute("Cash") or 0
    local reserve = tonumber(Options.ShopKeepCash.Value) or 0
    return cash - price >= reserve
end

task.spawn(function()
    while task.wait(Options.ShopInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoBuyShop.Value then
            local bought = 0
            for _, category in ipairs(shopCategories) do
                if Library.Unloaded or not Toggles.AutoBuyShop.Value then break end
                for label in pairs(Options[category.option].Value) do
                    if bought >= Options.ShopBuyAmount.Value then break end
                    local id = category.ids[label]
                    if id and affordable(category.prices[label] or 0) then
                        pcall(function() BuyStructure:InvokeServer(category.kind, id) end)
                        bought = bought + 1
                        task.wait(0.1)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(Options.SprinklerInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoBuySprinklers.Value then
            local bought = 0
            for label in pairs(Options.BuySprinklers.Value) do
                if Library.Unloaded or not Toggles.AutoBuySprinklers.Value then break end
                if bought >= Options.SprinklerAmount.Value then break end
                local id = sprinklerIdByName[label]
                if id and affordable(sprinklerPriceByName[label] or 0) then
                    pcall(function() BuyStructure:InvokeServer("Decoration", id) end)
                    bought = bought + 1
                    task.wait(0.1)
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(Options.WateringCanInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoBuyWateringCans.Value then
            local bought = 0
            for label in pairs(Options.BuyWateringCans.Value) do
                if Library.Unloaded or not Toggles.AutoBuyWateringCans.Value then break end
                if bought >= Options.WateringCanAmount.Value then break end
                local id = wateringCanIdByName[label]
                if id and affordable(wateringCanPriceByName[label] or 0) then
                    pcall(function() BuyStructure:InvokeServer("Gear", id) end)
                    bought = bought + 1
                    task.wait(0.1)
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(Options.CrateInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoBuyCrates.Value then
            for label in pairs(Options.BuyCrates.Value) do
                if Library.Unloaded or not Toggles.AutoBuyCrates.Value then break end
                local id = crateIdByName[label]
                if id and affordable(cratePriceByName[label] or 0) then
                    pcall(function() OpenCrateCash:InvokeServer(id) end)
                    task.wait(0.2)
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(Options.TrashInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoTrash.Value then
            local toolsToTrash = {}
            for _, kind in ipairs({ "Seed", "Bed", "SellTable", "Totem", "Decoration", "Gear", "Crate" }) do
                for _, tool in ipairs(ownedToolsOfKind(kind)) do
                    if shouldTrash(tool) then
                        table.insert(toolsToTrash, tool)
                    end
                end
            end
            local root = rootPart()
            local prompt = ownTrashPrompt()
            local target = prompt and prompt.Parent
            if #toolsToTrash > 0 and root and target and target:IsA("BasePart") then
                local originalCFrame = root.CFrame
                root.CFrame = target.CFrame + Vector3.new(0, 3, 0)
                task.wait(0.1)
                for _, tool in ipairs(toolsToTrash) do
                    if Library.Unloaded or not Toggles.AutoTrash.Value then break end
                    if tool.Parent then
                        equipTool(tool)
                        task.wait(0.1)
                        if tool.Parent == LocalPlayer.Character then
                            TrashHeld:FireServer(tool)
                        end
                        task.wait(0.1)
                    end
                end
                root = rootPart()
                if root then root.CFrame = originalCFrame end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(Options.TotemPlaceInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoPlaceTotems.Value then
            for _, tool in ipairs(ownedToolsOfKind("Totem")) do
                if selectionContainsItem(Options.PlaceTotems.Value, tool:GetAttribute("ItemId"), totemLabelById) then
                    placeOwnedTool(tool, PlaceTotem, function() return Toggles.AutoPlaceTotems.Value end)
                    break
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(Options.PlaceShopInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoPlaceShopItems.Value and next(Options.PlaceShopItems.Value) ~= nil then
            local placed = false
            for _, kind in ipairs({ "Bed", "SellTable", "Totem", "Decoration", "Crate" }) do
                for _, tool in ipairs(ownedToolsOfKind(kind)) do
                    if Library.Unloaded or not Toggles.AutoPlaceShopItems.Value then break end
                    local label = placeShopLabelByKey[kind .. ":" .. tostring(tool:GetAttribute("ItemId"))]
                    if label and Options.PlaceShopItems.Value[label] then
                        placeOwnedTool(tool, placeRemoteByKind[kind], function() return Toggles.AutoPlaceShopItems.Value end)
                        placed = true
                        break
                    end
                end
                if placed or Library.Unloaded or not Toggles.AutoPlaceShopItems.Value then break end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(Options.UseSprinklerInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoUseSprinklers.Value then
            for _, tool in ipairs(ownedToolsOfKind("Decoration")) do
                local itemId = tool:GetAttribute("ItemId")
                if sprinklerLabelById[itemId] and selectionContainsItem(Options.UseSprinklers.Value, itemId, sprinklerLabelById) then
                    placeOwnedTool(tool, PlaceDecoration, function() return Toggles.AutoUseSprinklers.Value end)
                    break
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(Options.UseWateringCanInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoUseWateringCans.Value then
            for _, tool in ipairs(ownedToolsOfKind("Gear")) do
                local itemId = tool:GetAttribute("ItemId")
                local waterLeft = tonumber(tool:GetAttribute("WaterLeft")) or 0
                if wateringCanLabelById[itemId] and waterLeft > 0 and selectionContainsItem(Options.UseWateringCans.Value, itemId, wateringCanLabelById) then
                    activeWateringCan = tool
                    equipTool(tool)
                    task.wait(0.1)
                    if Library.Unloaded or not Toggles.AutoUseWateringCans.Value or not tool.Parent then break end
                    pcall(function() tool:Activate() end)
                    task.wait(math.min(0.4, Options.UseWateringCanInterval.Value))
                    pcall(function() tool:Deactivate() end)
                    activeWateringCan = nil
                    break
                end
            end
        end
    end
end)

-- ===== Settings =====

Tabs.Settings:AddLeftGroupbox("Anti-AFK"):AddToggle("AntiAFK", { Text = "Anti-AFK", Default = true })

LocalPlayer.Idled:Connect(function()
    if Library.Unloaded then return end
    if not Toggles.AntiAFK.Value then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu")

Library.ToggleKeybind = Options.MenuKeybind

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })

MenuGroup:AddButton("Unload", function()
    Library:Unload()
end)

Library:OnUnload(function()
    if activeWateringCan then
        pcall(function() activeWateringCan:Deactivate() end)
        activeWateringCan = nil
    end
    restoreWalkSpeed()
    restoreNoclip()
    stopFlying()
    clearSeedEsp()
    clearPetEsp()
    for _, connection in ipairs(playerConnections) do
        connection:Disconnect()
    end
    print("[Grow It RNG] Unloaded")
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("OuroborosHub")
SaveManager:SetFolder("OuroborosHub/GrowItRNG")

ThemeManager:SaveDefault("Mint")

ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

ThemeManager:LoadDefault()
SaveManager:LoadAutoloadConfig()
