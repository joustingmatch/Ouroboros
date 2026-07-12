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

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PlantSeed = Remotes:WaitForChild("PlantSeed")
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

local seedNames, seedIdByName = {}, {}
for _, v in ipairs(SeedData.List) do
    local label = string.format("%s (t%s)", v.name, tostring(v.tier))
    table.insert(seedNames, label)
    seedIdByName[label] = v.id
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

local sprinklerList = {}
for _, v in ipairs(DecorationData.List) do
    if string.find(v.name, "Sprinkler") then
        table.insert(sprinklerList, v)
    end
end
local sprinklerNames, sprinklerIdByName, sprinklerPriceByName = buildShopEntries(sprinklerList)

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

local Window = Library:CreateWindow({
    Title = "Ouroboros | Grow It RNG",
    Footer = "version: 1.3",
    Icon = 18657887261,
    NotifySide = "Right",
    ShowCustomCursor = false,
    Size = UDim2.fromOffset(940, 720),
})

local Tabs = {
    Main = Window:AddTab("Main Tab", "sprout"),
    Shop = Window:AddTab("Shop", "store"),
    Settings = Window:AddTab("Settings", "settings"),
}

local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"

local function AddDiscordButton(Tab)
    Tab:AddLeftGroupbox("Discord", "message-circle", true, false, true):AddButton({
        Text = "Join Discord For Dupe",
        Func = function()
            setclipboard(DISCORD_INVITE)
            Library:Notify("Copied Discord invite to clipboard")
        end,
    })
end

for _, Tab in Tabs do
    AddDiscordButton(Tab)
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
GrowBox:AddToggle("AutoGrow", { Text = "Auto Grow Rush (tap speed)", Default = false })
GrowBox:AddSlider("GrowClicks", { Text = "Rush taps per cycle", Default = 10, Min = 1, Max = 40, Rounding = 0 })
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

local CrateBox = Tabs.Shop:AddRightGroupbox("Crates", "package")
CrateBox:AddToggle("AutoBuyCrates", { Text = "Auto Buy Crates", Default = false })
CrateBox:AddDropdown("BuyCrates", {
    Values = crateNames, Default = {}, Multi = true, Searchable = true, AllowNull = true,
    Text = "Crates to open",
})
CrateBox:AddSlider("CrateInterval", { Text = "Crate interval", Default = 2, Min = 0.5, Max = 15, Rounding = 1, Suffix = "s" })

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

-- ===== Loops =====

task.spawn(function()
    while task.wait(Options.PlantInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoPlant.Value then
            for _, slot in ipairs((ownedBedSlots())) do
                if Library.Unloaded or not Toggles.AutoPlant.Value then break end
                local seed = ownedToolsOfKind("Seed")[1]
                if not seed then break end
                equipTool(seed)
                pcall(function() PlantSeed:InvokeServer(slot, seed) end)
                task.wait(0.1)
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
    while task.wait(Options.GrowInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoGrow.Value then
            local _, growing = ownedBedSlots()
            safeFarmLoop(growing, 14, function() return Toggles.AutoGrow.Value end, function(slot)
                return slot:FindFirstChild("SpeedupClick", true) or slot:FindFirstChildOfClass("ClickDetector", true)
            end, function(slot, target)
                for _ = 1, Options.GrowClicks.Value do
                    if slot:GetAttribute("Ripe") == true then break end
                    pcall(function() fireclickdetector(target) end)
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(Options.HarvestInterval.Value) do
        if Library.Unloaded then break end
        if Toggles.AutoHarvest.Value then
            local _, _, ripe = ownedBedSlots()
            safeFarmLoop(ripe, 6, function() return Toggles.AutoHarvest.Value end, function(slot)
                return slot:FindFirstChild("HarvestPrompt", true)
            end, function(slot, target)
                pcall(function() fireproximityprompt(target) end)
                task.wait(0.05)
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
