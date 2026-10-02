local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local GAME_NAME = "Merge a Tank"
local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"
local RSCRIPTS_LINK = "https://rscripts.net/@Ouroboros"

local repo = "https://raw.githubusercontent.com/joustingmatch/ObsidianUltra/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

pcall(function()
    if Library.ScreenGui then
        Library.ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end)

local oldSetNotifySide = Library.SetNotifySide
Library.SetNotifySide = function(self, ...)
    pcall(oldSetNotifySide, self, ...)
end

local oldAddDraggableMenu = Library.AddDraggableMenu
Library.AddDraggableMenu = function(self, ...)
    local ok, res1, res2 = pcall(oldAddDraggableMenu, self, ...)
    if ok and res1 and res2 then
        return res1, res2
    end
    local dummyHolder = Instance.new("Frame")
    local dummyContainer = Instance.new("Frame")
    dummyHolder.Visible = false
    dummyContainer.Visible = false
    return dummyHolder, dummyContainer
end

local Options = Library.Options
local Toggles = Library.Toggles

local Modules = ReplicatedStorage:WaitForChild("Modules")
local RemoteHandler = require(Modules:WaitForChild("RemoteHandler"))
local GenericFunctionUtil = require(Modules:WaitForChild("HGUtils"):WaitForChild("GenericFunctionUtil"))
local FarmGameModules = Modules:WaitForChild("FarmGame")
local FarmEggData = require(FarmGameModules:WaitForChild("FarmEggData"))
local BrainrotCalculationFunctions = require(Modules:WaitForChild("FishAGame"):WaitForChild("BrainrotCalculationFunctions"))
local PotionTypeData = require(Modules:WaitForChild("PotionTypeData"))
local PlaytimeRewardsData = require(Modules:WaitForChild("PlaytimeRewards"))

local MergeTower = RemoteHandler.GetRemoteFunction("MergeTower")
local UpgradeBoardEvent = RemoteHandler.GetRemoteEvent("UpgradeBoardEvent")
local UpgradeBoardState = RemoteHandler.GetRemoteFunction("UpgradeBoardState")
local EquipBestTowers = RemoteHandler.GetRemoteEvent("EquipBestTowers")
local RodShopPurchaseEvent = RemoteHandler.GetRemoteEvent("RodShopPurchaseEvent")
local GenerateWorkerInventoryEvent = RemoteHandler.GetRemoteFunction("GenerateWorkerInventoryEvent")
local EquipWorker = RemoteHandler.GetRemoteEvent("EquipWorker")
local UnequipWorker = RemoteHandler.GetRemoteEvent("UnequipWorker")
local MergeTankWorker = RemoteHandler.GetRemoteEvent("MergeTankWorker")
local CashRebirth = RemoteHandler.GetRemoteEvent("CashRebirth")
local PlaytimeRewardUpdateEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlaytimeRewardUpdateEvent")
local PlayerUsePotion = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlayerUsePotion")
local UpdatePotionsUI = ReplicatedStorage:WaitForChild("Events"):WaitForChild("UpdatePotionsUI")

local UpgradeKeys = { "SpawnLevel", "BaseHealth", "CoinValue", "GemDropChance", "FireRate", "PickupRadius", "ActiveSlots" }
local WorkerCrateNames = {}
local WorkerCrateKeyByName = {}
local PotionNames = {}
local PotionKeyByName = {}

do
    local crates = {}
    for key, data in FarmEggData do
        if data.availableInShop ~= false and data.gemCost ~= nil then
            table.insert(crates, { key = key, name = data.name, cost = data.gemCost })
        end
    end
    table.sort(crates, function(a, b)
        return a.cost < b.cost
    end)
    for _, crate in crates do
        table.insert(WorkerCrateNames, crate.name)
        WorkerCrateKeyByName[crate.name] = crate.key
    end

    local potions = {}
    for key, data in PotionTypeData do
        table.insert(potions, { key = key, name = data.displayName or data.name or key })
    end
    table.sort(potions, function(a, b)
        return a.name < b.name
    end)
    for _, potion in potions do
        table.insert(PotionNames, potion.name)
        PotionKeyByName[potion.name] = potion.key
    end
end

local CurrencyCache = {}
local UpdatePlayerCurrency = ReplicatedStorage:WaitForChild("UpdatePlayerCurrency")
UpdatePlayerCurrency.OnClientEvent:Connect(function(currencyName, amount)
    if currencyName ~= nil and amount ~= nil then
        CurrencyCache[currencyName] = amount
    end
end)

local function copyDiscord()
    if setclipboard then
        setclipboard(DISCORD_INVITE)
    elseif toclipboard then
        toclipboard(DISCORD_INVITE)
    end
    Library:Notify("Copied Discord invite to clipboard")
end

local function getPlayerPlot()
    local ok, plot = pcall(GenericFunctionUtil.getPlayerPlot, LocalPlayer)
    if ok then
        return plot
    end
    return nil
end

local function collectTanks()
    local plot = getPlayerPlot()
    if not plot then
        return {}
    end

    local Interactive = plot:FindFirstChild("Interactive")
    if not Interactive then
        return {}
    end

    local tanks = {}
    for _, folderName in { "Merge", "Frontline" } do
        local folder = Interactive:FindFirstChild(folderName)
        if folder then
            for _, tile in folder:GetChildren() do
                if tile:IsA("Model") then
                    for _, child in tile:GetChildren() do
                        if child:IsA("Model") and child:GetAttribute("UUID") then
                            table.insert(tanks, child)
                        end
                    end
                end
            end
        end
    end
    return tanks
end

local function getBoardState()
    local ok, result = pcall(function()
        return UpgradeBoardState:InvokeServer()
    end)
    if ok then
        return result
    end
    return nil
end

local function canAfford(entry)
    if not entry or entry.isMaxed or entry.cost == nil then
        return false
    end
    local currencyName = entry.currency == "gems" and "Gems" or "Coins"
    local total = CurrencyCache[currencyName]
    if total == nil then
        return true
    end
    return entry.cost <= total
end

local function SelectedSet(value)
    local set = {}
    if typeof(value) == "table" then
        for name, on in value do
            if on then
                set[name] = true
            end
        end
    end
    return set
end

local function IsEmptySet(set)
    return next(set) == nil
end

local function getWorkerInventory()
    local ok, inventory = pcall(function()
        return GenerateWorkerInventoryEvent:InvokeServer()
    end)
    if ok and typeof(inventory) == "table" then
        return inventory
    end
    return {}
end

local function getBestUnplacedWorker(inventory)
    local bestID
    local bestValue = -math.huge
    for workerID, worker in inventory do
        if worker.placed ~= true then
            local ok, value = pcall(BrainrotCalculationFunctions.CalculateBrainrotValue, worker, true)
            if ok and value > bestValue then
                bestID = workerID
                bestValue = value
            end
        end
    end
    return bestID
end

local function equipBestWorker()
    local inventory = getWorkerInventory()
    local bestID = getBestUnplacedWorker(inventory)
    if not bestID then
        return false
    end

    for workerID, worker in inventory do
        if worker.equipped and workerID ~= bestID then
            pcall(function()
                UnequipWorker:FireServer(workerID, true, true)
            end)
            task.wait(0.15)
        end
    end

    if not inventory[bestID].equipped then
        pcall(function()
            EquipWorker:FireServer(bestID, true, true)
        end)
        task.wait(0.25)
    end
    return true
end

local function getEmptyFrontlineTank()
    local plot = getPlayerPlot()
    local Interactive = plot and plot:FindFirstChild("Interactive")
    local Frontline = Interactive and Interactive:FindFirstChild("Frontline")
    if not Frontline then
        return nil
    end

    for _, tile in Frontline:GetChildren() do
        for _, tank in tile:GetChildren() do
            if tank:IsA("Model") and tank:GetAttribute("UUID") then
                local workerID = tank:GetAttribute("WorkerID")
                if workerID == nil or workerID == "" then
                    return tank
                end
            end
        end
    end
    return nil
end

local function getPotionState()
    local inventory = {}
    local active = {}
    local bestInventoryCount = 0
    if not getconnections or not getupvalues then
        return inventory, active
    end

    pcall(function()
        for _, connection in ipairs(getconnections(UpdatePotionsUI.OnClientEvent)) do
            local callback = connection.Function
            if callback then
                for _, callbackUpvalue in pairs(getupvalues(callback)) do
                    if type(callbackUpvalue) == "function" then
                        for _, candidate in pairs(getupvalues(callbackUpvalue)) do
                            if type(candidate) == "table" then
                                local potionCount = 0
                                local activeCount = 0
                                for _, potion in pairs(candidate) do
                                    if type(potion) == "table" and potion.potionName then
                                        potionCount = potionCount + 1
                                        if potion.endTime then
                                            activeCount = activeCount + 1
                                        end
                                    end
                                end
                                if potionCount > 0 then
                                    if activeCount > 0 then
                                        for _, potion in pairs(candidate) do
                                            if type(potion) == "table" and potion.potionName and potion.endTime and potion.endTime > os.time() then
                                                active[potion.potionName] = true
                                            end
                                        end
                                    elseif potionCount > bestInventoryCount then
                                        inventory = candidate
                                        bestInventoryCount = potionCount
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    return inventory, active
end

local lastEquipBestFire = 0
local function fireEquipBest()
    local now = os.clock()
    if now - lastEquipBestFire < 0.5 then
        return
    end
    lastEquipBestFire = now
    pcall(function()
        EquipBestTowers:FireServer()
    end)
end

local Window = Library:CreateWindow({
    Title = "Ouroboros Hub",
    Footer = {
        { Text = DISCORD_INVITE, Copyable = true },
        "|",
        GAME_NAME,
    },
    Icon = 12645376577,
    NotifySide = "Right",
    ShowCustomCursor = false,
    CornerRadius = 10,
})

local Tabs = {
    Info = Window:AddTab("Info", "info"),
    Main = Window:AddTab("Main", "gamepad-2"),
    Settings = Window:AddTab("Settings", "settings"),
}

Tabs.Merge = Tabs.Main:AddSubTab("Merge", "swords")
Tabs.Economy = Tabs.Main:AddSubTab("Economy", "coins")
Tabs.Rebirth = Tabs.Main:AddSubTab("Rebirth", "sparkles")

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

AddDiscordButton(Tabs.Info)
AddDiscordButton(Tabs.Merge)
AddDiscordButton(Tabs.Economy)
AddDiscordButton(Tabs.Rebirth)
AddDiscordButton(Tabs.Settings)

-- Info tab

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
        if setclipboard then
            setclipboard(joinScript)
        elseif toclipboard then
            toclipboard(joinScript)
        end
        Library:Notify("Copied join script to clipboard")
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

FeaturesGroup:AddLabel(colored("Merge & Placement Automation", BLUE), true)
FeaturesGroup:AddLabel(colored("Economy Automation", ORANGE), true)
FeaturesGroup:AddLabel(colored("Rebirth Automation", GREY), true)

local SocialsGroup = Tabs.Info:AddRightGroupbox("Socials", "link")

SocialsGroup:AddButton({
    Text = "Discord",
    Func = copyDiscord,
})

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

-- Merge sub tab

local AutoMergeBox = Tabs.Merge:AddLeftGroupbox("Auto Merge")
AutoMergeBox:AddToggle("AutoMerge", { Text = "Auto Merge", Default = false })
AutoMergeBox:AddSlider("MergeDelay", {
    Text = "Delay",
    Default = 0.5,
    Min = 0.2,
    Max = 3,
    Rounding = 2,
})

local AutoPlaceBox = Tabs.Merge:AddLeftGroupbox("Auto Place")
AutoPlaceBox:AddToggle("AutoPlace", { Text = "Auto Place Tanks", Default = false })
AutoPlaceBox:AddSlider("AutoPlaceDelay", {
    Text = "Delay",
    Default = 2,
    Min = 0.5,
    Max = 10,
    Rounding = 1,
})

local AutoReplaceBox = Tabs.Merge:AddRightGroupbox("Auto Replace with Better")
AutoReplaceBox:AddToggle("AutoReplaceBetter", { Text = "Auto Replace with Better", Default = false })
AutoReplaceBox:AddSlider("AutoReplaceDelay", {
    Text = "Delay",
    Default = 3,
    Min = 0.5,
    Max = 10,
    Rounding = 1,
})

local WorkersBox = Tabs.Merge:AddRightGroupbox("Workers")
WorkersBox:AddToggle("AutoEquipBestWorker", { Text = "Equip Best Worker", Default = false })
WorkersBox:AddToggle("AutoAddWorkerToTanks", { Text = "Auto Add Workers to Tanks", Default = false })
WorkersBox:AddSlider("WorkerDelay", {
    Text = "Delay",
    Default = 1,
    Min = 0.5,
    Max = 5,
    Rounding = 1,
})

-- Economy sub tab

local BuyUnitsBox = Tabs.Economy:AddLeftGroupbox("Auto Buy Units")
BuyUnitsBox:AddToggle("AutoBuyUnits", { Text = "Auto Buy Units", Default = false })
BuyUnitsBox:AddSlider("BuyUnitsDelay", {
    Text = "Delay",
    Default = 1,
    Min = 0.2,
    Max = 5,
    Rounding = 2,
})

local BuyUpgradesBox = Tabs.Economy:AddLeftGroupbox("Auto Buy Upgrades")
BuyUpgradesBox:AddToggle("AutoBuyUpgrades", { Text = "Auto Buy Upgrades", Default = false })
BuyUpgradesBox:AddDropdown("UpgradeList", {
    Text = "Upgrades",
    Values = UpgradeKeys,
    Default = {},
    Multi = true,
    AllowNull = true,
    Searchable = true,
})
BuyUpgradesBox:AddSlider("BuyUpgradesDelay", {
    Text = "Delay",
    Default = 1,
    Min = 0.2,
    Max = 5,
    Rounding = 2,
})

local CollectBox = Tabs.Economy:AddRightGroupbox("Auto Collect Money")
CollectBox:AddToggle("AutoCollect", { Text = "Auto Collect Money on Ground", Default = false })
CollectBox:AddSlider("CollectDelay", {
    Text = "Delay",
    Default = 0.2,
    Min = 0.05,
    Max = 1,
    Rounding = 2,
})

local WorkerCratesBox = Tabs.Economy:AddRightGroupbox("Worker Crates")
WorkerCratesBox:AddToggle("AutoBuyWorkerCrates", { Text = "Auto Buy Worker Crates", Default = false })
WorkerCratesBox:AddDropdown("WorkerCrateList", {
    Text = "Worker Crates",
    Values = WorkerCrateNames,
    Default = {},
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Expandable = true,
    ExpandColumns = 2,
})
WorkerCratesBox:AddSlider("WorkerCrateDelay", {
    Text = "Delay",
    Default = 1,
    Min = 0.5,
    Max = 5,
    Rounding = 1,
})

local GiftsBox = Tabs.Economy:AddRightGroupbox("Free Gifts")
GiftsBox:AddToggle("AutoClaimFreeGifts", { Text = "Auto Claim Free Gifts", Default = false })

local PotionsBox = Tabs.Economy:AddRightGroupbox("Potions")
PotionsBox:AddToggle("AutoUsePotions", { Text = "Auto Use Potions", Default = false })
PotionsBox:AddDropdown("PotionList", {
    Text = "Potions",
    Values = PotionNames,
    Default = {},
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Expandable = true,
    ExpandColumns = 2,
})

-- Rebirth sub tab

local RebirthBox = Tabs.Rebirth:AddLeftGroupbox("Auto Rebirth")
RebirthBox:AddToggle("AutoRebirth", { Text = "Auto Rebirth", Default = false })
RebirthBox:AddSlider("RebirthDelay", {
    Text = "Delay",
    Default = 3,
    Min = 1,
    Max = 15,
    Rounding = 1,
})

local AetherBox = Tabs.Rebirth:AddRightGroupbox("Aether")
AetherBox:AddToggle("AutoUnlockAether", { Text = "Auto Unlock Aether", Default = false })

-- Auto Merge loop

task.spawn(function()
    while task.wait(Options.MergeDelay and Options.MergeDelay.Value or 0.5) do
        if Library.Unloaded then
            break
        end
        if Toggles.AutoMerge.Value then
            local tanks = collectTanks()
            local groups = {}
            for _, tank in tanks do
                local list = groups[tank.Name]
                if not list then
                    list = {}
                    groups[tank.Name] = list
                end
                table.insert(list, tank)
            end

            for _, list in groups do
                if Library.Unloaded then
                    break
                end
                if #list >= 2 then
                    local uuidA = list[1]:GetAttribute("UUID")
                    local uuidB = list[2]:GetAttribute("UUID")
                    pcall(function()
                        MergeTower:InvokeServer(uuidA, uuidB)
                    end)
                    task.wait(0.15)
                end
            end
        end
    end
end)

-- Auto Place / Auto Replace loops

task.spawn(function()
    while task.wait(Options.AutoPlaceDelay and Options.AutoPlaceDelay.Value or 2) do
        if Library.Unloaded then
            break
        end
        if Toggles.AutoPlace.Value then
            fireEquipBest()
        end
    end
end)

task.spawn(function()
    while task.wait(Options.AutoReplaceDelay and Options.AutoReplaceDelay.Value or 3) do
        if Library.Unloaded then
            break
        end
        if Toggles.AutoReplaceBetter.Value then
            fireEquipBest()
        end
    end
end)

task.spawn(function()
    while task.wait(Options.WorkerDelay and Options.WorkerDelay.Value or 1) do
        if Library.Unloaded then
            break
        end
        if Toggles.AutoAddWorkerToTanks.Value then
            local tank = getEmptyFrontlineTank()
            if tank and equipBestWorker() then
                pcall(function()
                    MergeTankWorker:FireServer("Attach", tank:GetAttribute("UUID"))
                end)
            end
        elseif Toggles.AutoEquipBestWorker.Value then
            equipBestWorker()
        end
    end
end)

-- Auto Buy Units loop

task.spawn(function()
    while task.wait(Options.BuyUnitsDelay and Options.BuyUnitsDelay.Value or 1) do
        if Library.Unloaded then
            break
        end
        if Toggles.AutoBuyUnits.Value then
            local state = getBoardState()
            if state and canAfford(state.BuyUnit) then
                pcall(function()
                    UpgradeBoardEvent:FireServer("BuyUnit")
                end)
            end
        end
    end
end)

task.spawn(function()
    while task.wait(Options.WorkerCrateDelay and Options.WorkerCrateDelay.Value or 1) do
        if Library.Unloaded then
            break
        end
        if Toggles.AutoBuyWorkerCrates.Value then
            local selected = SelectedSet(Options.WorkerCrateList.Value)
            for _, crateName in WorkerCrateNames do
                if Library.Unloaded or not Toggles.AutoBuyWorkerCrates.Value then
                    break
                end
                if IsEmptySet(selected) or selected[crateName] then
                    local crateKey = WorkerCrateKeyByName[crateName]
                    local crateData = FarmEggData[crateKey]
                    local gems = CurrencyCache.Gems or (_G.TotalCurrency and _G.TotalCurrency.Gems)
                    if gems == nil or crateData.gemCost <= gems then
                        pcall(function()
                            RodShopPurchaseEvent:FireServer(crateKey)
                        end)
                        task.wait(0.2)
                    end
                end
            end
        end
    end
end)

-- Auto Buy Upgrades loop

task.spawn(function()
    while task.wait(Options.BuyUpgradesDelay and Options.BuyUpgradesDelay.Value or 1) do
        if Library.Unloaded then
            break
        end
        if Toggles.AutoBuyUpgrades.Value then
            local set = SelectedSet(Options.UpgradeList.Value)
            local state = getBoardState()
            if state then
                for _, key in UpgradeKeys do
                    if Library.Unloaded then
                        break
                    end
                    if (IsEmptySet(set) or set[key]) and canAfford(state[key]) then
                        pcall(function()
                            UpgradeBoardEvent:FireServer(key)
                        end)
                        task.wait(0.2)
                    end
                end
            end
        end
    end
end)

-- Auto Collect Money loop

task.spawn(function()
    while task.wait(Options.CollectDelay and Options.CollectDelay.Value or 0.2) do
        if Library.Unloaded then
            break
        end
        if Toggles.AutoCollect.Value then
            local dropsFolder = workspace:FindFirstChild("ClientCoinsGems")
            local character = LocalPlayer.Character
            local touchPart = character and character:FindFirstChild("HumanoidRootPart")
            if dropsFolder and touchPart then
                for _, drop in dropsFolder:GetChildren() do
                    if Library.Unloaded then
                        break
                    end
                    if drop:IsA("BasePart") and drop.Name == "CurrencyDrop" then
                        pcall(function()
                            firetouchinterest(drop, touchPart, 0)
                            firetouchinterest(drop, touchPart, 1)
                        end)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        if Library.Unloaded then
            break
        end
        if Toggles.AutoClaimFreeGifts.Value then
            local PlaytimeRewards = LocalPlayer.PlayerGui:FindFirstChild("PlaytimeRewards")
            local RewardsFrame = PlaytimeRewards and PlaytimeRewards:FindFirstChild("Frame")
            RewardsFrame = RewardsFrame and RewardsFrame:FindFirstChild("Frame")
            if RewardsFrame then
                for rewardID in PlaytimeRewardsData do
                    local Gift = RewardsFrame:FindFirstChild("Gift" .. tostring(rewardID))
                    local Timer = Gift and Gift:FindFirstChild("Timer")
                    if Timer and Timer.Text == "Claim!" then
                        pcall(function()
                            PlaytimeRewardUpdateEvent:FireServer(tostring(rewardID))
                        end)
                        task.wait(0.2)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        if Library.Unloaded then
            break
        end
        if Toggles.AutoUsePotions.Value then
            local selectedNames = SelectedSet(Options.PotionList.Value)
            local selectedKeys = {}
            for potionName in selectedNames do
                selectedKeys[PotionKeyByName[potionName]] = true
            end
            local inventory, active = getPotionState()
            for potionID, potion in inventory do
                if (IsEmptySet(selectedKeys) or selectedKeys[potion.potionName]) and not active[potion.potionName] then
                    pcall(function()
                        PlayerUsePotion:FireServer(potionID)
                    end)
                    break
                end
            end
        end
    end
end)

-- Auto Rebirth loop

task.spawn(function()
    while task.wait(Options.RebirthDelay and Options.RebirthDelay.Value or 3) do
        if Library.Unloaded then
            break
        end
        if Toggles.AutoRebirth.Value then
            local plot = getPlayerPlot()
            local Interactive = plot and plot:FindFirstChild("Interactive")
            local Rebirths = Interactive and Interactive:FindFirstChild("Rebirths")
            local Model = Rebirths and Rebirths:FindFirstChild("Model")
            local Portal = Model and Model:FindFirstChild("EnterHeavenPortal")
            local EnterHeaven = Portal and Portal:FindFirstChild("EnterHeaven")
            local Prompt = EnterHeaven and EnterHeaven:FindFirstChildOfClass("ProximityPrompt")
            if Prompt then
                pcall(function()
                    fireproximityprompt(Prompt)
                end)
            end
        end
    end
end)

task.spawn(function()
    while task.wait(2) do
        if Library.Unloaded then
            break
        end
        if Toggles.AutoUnlockAether.Value and _G.isHeavenUnlocked ~= true then
            pcall(function()
                CashRebirth:FireServer("rebirth")
            end)
        end
    end
end)

-- Settings tab

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu")
MenuGroup:AddButton("Unload", function()
    Library:Unload()
end)
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Menu keybind",
})
Library.ToggleKeybind = Options.MenuKeybind

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

local AntiAfkGroup = Tabs.Settings:AddRightGroupbox("Anti-AFK")
AntiAfkGroup:AddToggle("AntiAfk", {
    Text = "Anti-AFK",
    Default = true,
})

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

Library:OnUnload(function()
    antiAfkBeganConnection:Disconnect()
    antiAfkChangedConnection:Disconnect()
    print(GAME_NAME .. " unloaded")
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

ThemeManager:SetFolder("OuroborosHub")
SaveManager:SetFolder("OuroborosHub/MergeATank")

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SaveDefault("Monochrome")
ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()

SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
