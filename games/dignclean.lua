    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local CollectionService = game:GetService("CollectionService")
    local UserInputService = game:GetService("UserInputService")
    local VirtualUser = game:GetService("VirtualUser")
    local Workspace = game:GetService("Workspace")

    local LocalPlayer = Players.LocalPlayer

    local GAME_NAME = "Dig & Clean"
    local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"
    local RSCRIPTS_LINK = "https://rscripts.net/@Ouroboros"

    local Flamework = require(ReplicatedStorage.rbxts_include.node_modules["@flamework"].core.out).Flamework

    local Shovels = require(ReplicatedStorage.TS.constants.digging.Shovels)
    local Detectors = require(ReplicatedStorage.TS.constants.digging.Detectors)
    local SprayBottles = require(ReplicatedStorage.TS.constants.cleaning.SprayBottles)
    local DiggingConfig = require(ReplicatedStorage.TS.constants.digging.DiggingConfig)
    local Items = require(ReplicatedStorage.TS.constants.items.Items)
    local Conditions = require(ReplicatedStorage.TS.constants.items.Conditions)
    local BackpackModule = require(ReplicatedStorage.TS.constants.inventory.BackpackCapacity)
    local BackpackCapacity = BackpackModule.BackpackCapacity
    local IslandConstants = require(ReplicatedStorage.TS.constants.world.Islands)
    local DigZoneSpawn = require(ReplicatedStorage.TS.utils.world.DigZoneSpawn)
    local teleportStreamed = require(ReplicatedStorage.TS.utils.world.teleportStreamed).teleportStreamed
    local PlotSections = require(ReplicatedStorage.TS.constants.plot.PlotSections)

    local NetworkFolder = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("TS"):WaitForChild("network")
    local ShopFunctions = require(NetworkFolder.ShopNetwork).ShopFunctions
    local SellFunctions = require(NetworkFolder.SellNetwork).SellFunctions
    local PedestalFunctions = require(NetworkFolder.PedestalNetwork).PedestalFunctions
    local TravelFunctions = require(NetworkFolder.TravelNetwork).TravelFunctions
    local ShovelNetwork = require(NetworkFolder.ShovelNetwork)
    local ShovelEvents = ShovelNetwork.ShovelEvents
    local ShovelFunctions = ShovelNetwork.ShovelFunctions

    local IslandOptions = {}
    local IslandByName = {}
    local IslandById = {}
    local travelCooldownUntil = {}
    local travelNotified = {}

    local function refreshIslandSpawns()
        pcall(function()
            for _, island in ipairs(TravelFunctions.getIslands:invoke():expect()) do
                IslandById[island.id] = island
                if type(island.name) == "string" then
                    IslandByName[island.name] = island
                end
            end
        end)
    end

    refreshIslandSpawns()

    for _, id in ipairs(IslandConstants.ISLAND_ORDER) do
        local island = IslandById[id]
        local name = island and island.name or id
        IslandOptions[#IslandOptions + 1] = name
        IslandByName[name] = island or { id = id }
    end

    local RARITY_INDEX = {}
    for index, rarity in ipairs(Items.RARITY_ORDER) do
        RARITY_INDEX[rarity] = index
    end

    local CONDITION_INDEX = {}
    for index, condition in ipairs(Conditions.CONDITION_ORDER) do
        CONDITION_INDEX[condition] = index
    end

    local surfacedItems = {}
    local surfacedConnections = {}

    local function refreshSurfacedItems()
        local ok, items = pcall(function()
            return ShovelFunctions.GetSurfacedItems:invoke():expect()
        end)
        if not ok or type(items) ~= "table" then
            return
        end
        table.clear(surfacedItems)
        for _, item in ipairs(items) do
            surfacedItems[item.id] = item
        end
    end

    local function trackSurfaced(item)
        surfacedItems[item.id] = item
    end

    local function untrackSurfaced(id)
        surfacedItems[id] = nil
    end

    table.insert(surfacedConnections, ShovelEvents.SurfacedItemSpawned:connect(trackSurfaced))
    table.insert(surfacedConnections, ShovelEvents.SurfacedItemReleased:connect(trackSurfaced))
    table.insert(surfacedConnections, ShovelEvents.SurfacedItemRemoved:connect(untrackSurfaced))
    table.insert(surfacedConnections, ShovelEvents.SurfacedItemClaimed:connect(untrackSurfaced))

    refreshSurfacedItems()

    local DIG_CONTROLLER = "client/controllers/world/DigController@DigController"
    local SWEEP_CONTROLLER = "client/controllers/world/DetectorSweepController@DetectorSweepController"
    local SURFACED_CONTROLLER = "client/controllers/world/SurfacedItemController@SurfacedItemController"
    local WORKBENCH_CONTROLLER = "client/controllers/world/WorkbenchController@WorkbenchController"
    local SPRAY_CONTROLLER = "client/controllers/world/SprayBottleController@SprayBottleController"
    local DATA_CONTROLLER = "client/controllers/data/DataController@DataController"

    local function resolve(identifier)
        local ok, controller = pcall(Flamework.resolveDependency, identifier)
        if ok then
            return controller
        end
        return nil
    end

    local function getData()
        local data = resolve(DATA_CONTROLLER)
        if not data then
            return nil
        end
        local ok, value = pcall(data.getDataIfLoaded, data)
        if ok then
            return value
        end
        return nil
    end

    local function getCharacter()
        return LocalPlayer.Character
    end

    local function getRoot()
        local character = getCharacter()
        return character and character:FindFirstChild("HumanoidRootPart")
    end

    local function getHumanoid()
        local character = getCharacter()
        return character and character:FindFirstChildOfClass("Humanoid")
    end

    local function teleportTo(position)
        local root = getRoot()
        if not root or not root:IsA("BasePart") then
            return false
        end
        root.CFrame = CFrame.new(position)
        return true
    end

    local function getPlot()
        local plots = Workspace:FindFirstChild("Plots")
        if not plots then
            return nil
        end
        for _, plot in ipairs(plots:GetChildren()) do
            if plot:GetAttribute("OwnerUserId") == tostring(LocalPlayer.UserId) or plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                return plot
            end
        end
        return nil
    end

    local function collectOwnedPedestals(plot)
        local list = {}
        if not plot then
            return list
        end
        for _, folder in ipairs(plot:GetDescendants()) do
            if folder.Name == "Pedestals" then
                local section = folder.Parent
                if section and section:GetAttribute(PlotSections.SECTION_ID_ATTRIBUTE) ~= nil then
                    if section:GetAttribute(PlotSections.SECTION_UNLOCKED_ATTRIBUTE) ~= true then
                        continue
                    end
                end
                for _, pedestal in ipairs(folder:GetChildren()) do
                    local slot = pedestal:GetAttribute("Slot")
                    if type(slot) == "number" and pedestal:GetAttribute("Owned") == true then
                        list[#list + 1] = pedestal
                    end
                end
            end
        end
        return list
    end

    local function getIslandModel(islandId)
        local islands = Workspace:FindFirstChild("Islands")
        if not islands then
            return nil
        end
        for _, island in ipairs(islands:GetChildren()) do
            if island:GetAttribute(IslandConstants.ISLAND_ID_ATTRIBUTE) == islandId then
                return island
            end
        end
        return nil
    end

    local function getNpc(islandId, npcName)
        local island = getIslandModel(islandId)
        if not island then
            return nil
        end
        local npcs = island:FindFirstChild("NPCs")
        if not npcs then
            return nil
        end
        return npcs:FindFirstChild(npcName)
    end

    local function itemValue(entry)
        if entry.dirty == true then
            local ok, value = pcall(Items.dirtyItemValueFor, entry.id, entry.kg)
            if ok and type(value) == "number" then
                return value
            end
            return 0
        end
        local ok, value = pcall(Items.itemValueFor, entry.id, entry.condition, entry.kg)
        if ok and type(value) == "number" then
            return value
        end
        return 0
    end

    local function findToolByInventoryId(inventoryId)
        local character = getCharacter()
        if character then
            for _, tool in ipairs(character:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("inventoryId") == inventoryId then
                    return tool, true
                end
            end
        end
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if backpack then
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("inventoryId") == inventoryId then
                    return tool, false
                end
            end
        end
        return nil, false
    end

    local function dirtyToolRarityIndex(tool)
        local itemId = tool:GetAttribute("itemId")
        local definition = itemId and Items.Items[itemId]
        if not definition then
            return 0
        end
        return RARITY_INDEX[definition.rarity] or 0
    end

    local function cleanRarityAllowed(tool)
        local minimum = 1
        if Options and Options.CleanRarityPriority then
            minimum = RARITY_INDEX[Options.CleanRarityPriority.Value] or 1
        end
        return dirtyToolRarityIndex(tool) >= minimum
    end

    local function findDirtyTool()
        local character = getCharacter()
        if character then
            for _, tool in ipairs(character:GetChildren()) do
                if tool:IsA("Tool") and CollectionService:HasTag(tool, "Dirt") and cleanRarityAllowed(tool) then
                    return tool, true
                end
            end
        end

        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not backpack then
            return nil, false
        end

        local best, bestScore
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and CollectionService:HasTag(tool, "Dirt") and cleanRarityAllowed(tool) then
                local score = dirtyToolRarityIndex(tool)
                if not best or score > bestScore then
                    best = tool
                    bestScore = score
                end
            end
        end

        if best then
            return best, false
        end
        return nil, false
    end

    local function bestAffordableGear(order, definitions, owned, unlocked, budget)
        local best = nil
        for _, id in ipairs(order) do
            local definition = definitions[id]
            if definition and definition.cost > 0 and definition.cost <= budget then
                if table.find(unlocked, definition.islandId) and not table.find(owned, id) then
                    best = id
                end
            end
        end
        return best
    end

    local function highestOwnedGear(order, owned)
        local best = nil
        for _, id in ipairs(order) do
            if table.find(owned, id) then
                best = id
            end
        end
        return best
    end

    local repo = "https://raw.githubusercontent.com/joustingmatch/ObsidianUltra/main/"
    local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
    local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
    local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

    local Options = Library.Options
    local Toggles = Library.Toggles

    local function copyToClipboard(text)
        if setclipboard then
            setclipboard(text)
        elseif toclipboard then
            toclipboard(text)
        end
    end

    local function copyDiscord()
        copyToClipboard(DISCORD_INVITE)
        Library:Notify("Copied Discord invite to clipboard")
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

    local Window = Library:CreateWindow({
        Title = "Ouroboros Hub",
        Footer = {
            { Text = DISCORD_INVITE, Copyable = true },
            "|",
            GAME_NAME,
        },
        Icon = 12645376577,
        Size = UDim2.fromOffset(880, 620),
        NotifySide = "Right",
        ShowCustomCursor = false,
        CornerRadius = 10,
        GlobalSearch = true,
    })

    local Tabs = {
        Info = Window:AddTab("Info", "info"),
        Priority = Window:AddTab("Priority", "list-ordered"),
        Digging = Window:AddTab("Digging", "shovel"),
        Cleaning = Window:AddTab("Cleaning", "spray-can"),
        Storage = Window:AddTab("Storage", "package"),
        Shop = Window:AddTab("Shop", "shopping-cart"),
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
            copyToClipboard(joinScript)
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

    FeaturesGroup:AddLabel(colored("Auto Dig", BLUE), true)
    FeaturesGroup:AddLabel(colored("Auto Clean", BLUE), true)
    FeaturesGroup:AddLabel(colored("Auto Place", ORANGE), true)
    FeaturesGroup:AddLabel(colored("Auto Replace", ORANGE), true)
    FeaturesGroup:AddLabel(colored("Auto Sell", ORANGE), true)
    FeaturesGroup:AddLabel(colored("Auto Buy Gear", GREEN), true)

    local SocialsGroup = Tabs.Info:AddRightGroupbox("Socials", "link")

    SocialsGroup:AddButton({
        Text = "Discord",
        Func = copyDiscord,
    })

    SocialsGroup:AddButton({
        Text = "Rscripts",
        Func = function()
            copyToClipboard(RSCRIPTS_LINK)
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

    local DigGroup = Tabs.Digging:AddLeftGroupbox("Auto Dig", "shovel")

    DigGroup:AddToggle("AutoDig", {
        Text = "Auto Dig",
        Default = false,
    })

    DigGroup:AddDropdown("DigMode", {
        Values = { "Teleport", "Walk" },
        Default = "Teleport",
        Text = "Dig Mode",
    })

    DigGroup:AddToggle("AutoDigTravel", {
        Text = "Teleport To Dig Spots",
        Default = true,
    })

    DigGroup:AddDropdown("DigIsland", {
        Values = IslandOptions,
        Default = IslandOptions[1],
        Text = "Dig Island",
    })

    DigGroup:AddToggle("AutoTravelIsland", {
        Text = "Return Home To Clean And Sell",
        Default = true,
    })

    DigGroup:AddDropdown("DigMinRarity", {
        Values = Items.RARITY_ORDER,
        Default = "common",
        Text = "Minimum Rarity",
    })

    DigGroup:AddDropdown("DigPowerMode", {
        Values = { "Max Luck", "Fastest" },
        Default = "Max Luck",
        Text = "Power Timing",
    })

    DigGroup:AddSlider("DigClickRate", {
        Text = "Dig Clicks Per Second",
        Default = 25,
        Min = 1,
        Max = 50,
        Rounding = 0,
        Suffix = " cps",
    })

    DigGroup:AddToggle("DigStopWhenFull", {
        Text = "Pause When Backpack Full",
        Default = true,
    })

    local DigStatusGroup = Tabs.Digging:AddRightGroupbox("Status", "activity")

    local DigSpotsLabel = DigStatusGroup:AddLabel(field("Buried spots", "0", BLUE), true)
    local DigPhaseLabel = DigStatusGroup:AddLabel(field("Dig phase", "idle", ORANGE), true)
    local DigBackpackLabel = DigStatusGroup:AddLabel(field("Backpack", "0", GREEN), true)

    local CleanGroup = Tabs.Cleaning:AddLeftGroupbox("Auto Clean", "spray-can")

    CleanGroup:AddToggle("AutoClean", {
        Text = "Auto Clean",
        Default = false,
    })

    CleanGroup:AddDropdown("CleanPriority", {
        Values = { "When Backpack Full", "Always", "When Not Digging" },
        Default = "When Backpack Full",
        Text = "Clean Priority",
    })

    CleanGroup:AddDropdown("CleanRarityPriority", {
        Values = Items.RARITY_ORDER,
        Default = "common",
        Text = "Rarity Priority",
    })

    CleanGroup:AddToggle("CleanTeleport", {
        Text = "Teleport To Workbench",
        Default = true,
    })

    CleanGroup:AddSlider("CleanFinishDelay", {
        Text = "Scrub Time Before Finishing",
        Default = 1,
        Min = 0,
        Max = 10,
        Rounding = 1,
        Suffix = "s",
    })

    CleanGroup:AddToggle("CleanReturn", {
        Text = "Return After Cleaning",
        Default = true,
    })

    local CleanStatusGroup = Tabs.Cleaning:AddRightGroupbox("Status", "activity")

    local CleanDirtyLabel = CleanStatusGroup:AddLabel(field("Dirty items", "0", ORANGE), true)
    local CleanStateLabel = CleanStatusGroup:AddLabel(field("Workbench", "idle", BLUE), true)

    local PlaceGroup = Tabs.Storage:AddLeftGroupbox("Auto Place", "layout-grid")

    PlaceGroup:AddToggle("AutoPlace", {
        Text = "Auto Place",
        Default = false,
    })

    PlaceGroup:AddDropdown("PlaceConditions", {
        Values = Conditions.CONDITION_ORDER,
        Multi = true,
        AllowNull = true,
        Text = "Conditions (empty = all)",
    })

    PlaceGroup:AddSlider("PlaceMinValue", {
        Text = "Minimum Item Value",
        Default = 0,
        Min = 0,
        Max = 100000,
        Rounding = 0,
        Prefix = "$",
    })

    PlaceGroup:AddToggle("PlaceReplaceWorse", {
        Text = "Replace Lower Value Items",
        Default = false,
    })

    PlaceGroup:AddToggle("PlaceTeleport", {
        Text = "Teleport To Pedestal",
        Default = true,
    })

    local ReplaceGroup = Tabs.Storage:AddLeftGroupbox("Auto Replace", "refresh-cw")

    ReplaceGroup:AddToggle("AutoReplace", {
        Text = "Auto Replace",
        Default = false,
    })

    ReplaceGroup:AddDropdown("ReplaceMode", {
        Values = { "Higher Value", "Higher Rarity", "Better Condition", "Configuration" },
        Default = "Higher Value",
        Text = "Replace Mode",
    })

    ReplaceGroup:AddDropdown("ReplaceMinRarity", {
        Values = Items.RARITY_ORDER,
        Default = "common",
        Text = "Minimum Candidate Rarity",
    })

    ReplaceGroup:AddDropdown("ReplaceMinCondition", {
        Values = Conditions.CONDITION_ORDER,
        Default = "poor",
        Text = "Minimum Candidate Condition",
    })

    ReplaceGroup:AddSlider("ReplaceMinValue", {
        Text = "Minimum Candidate Value",
        Default = 0,
        Min = 0,
        Max = 100000,
        Rounding = 0,
        Prefix = "$",
    })

    ReplaceGroup:AddSlider("ReplaceImprovement", {
        Text = "Minimum Value Improvement",
        Default = 0,
        Min = 0,
        Max = 100,
        Rounding = 0,
        Suffix = "%",
    })

    local SellGroup = Tabs.Storage:AddRightGroupbox("Auto Sell", "hand-coins")

    SellGroup:AddToggle("AutoSell", {
        Text = "Auto Sell",
        Default = false,
    })

    SellGroup:AddDropdown("SellTarget", {
        Values = { "Everything", "Junk Only" },
        Default = "Junk Only",
        Text = "Sell Target",
    })

    SellGroup:AddDropdown("SellMode", {
        Values = { "Backpack Full", "Item Count", "Timer", "Junk Found" },
        Default = "Junk Found",
        Text = "Sell Trigger",
    })

    SellGroup:AddSlider("SellItemCount", {
        Text = "Sell At Item Count",
        Default = 20,
        Min = 1,
        Max = 50,
        Rounding = 0,
    })

    SellGroup:AddSlider("SellInterval", {
        Text = "Sell Every",
        Default = 120,
        Min = 15,
        Max = 900,
        Rounding = 0,
        Suffix = "s",
    })

    SellGroup:AddSlider("SellBelowValue", {
        Text = "Sell Below Value",
        Default = 1000,
        Min = 0,
        Max = 1000000,
        Rounding = 0,
        Prefix = "$",
    })

    SellGroup:AddSlider("SellBelowKg", {
        Text = "Sell Below Weight",
        Default = 100,
        Min = 0,
        Max = 10000,
        Rounding = 1,
        Suffix = " kg",
    })

    SellGroup:AddDropdown("SellMaxRarity", {
        Values = Items.RARITY_ORDER,
        Default = "uncommon",
        Text = "Sell Max Rarity",
    })

    SellGroup:AddToggle("SellTeleport", {
        Text = "Teleport To Seller",
        Default = true,
    })

    SellGroup:AddToggle("SellReturn", {
        Text = "Return After Selling",
        Default = true,
    })

    local ShopGroup = Tabs.Shop:AddLeftGroupbox("Auto Buy", "shopping-cart")

    ShopGroup:AddToggle("AutoBuyShovel", {
        Text = "Auto Buy Best Affordable Shovel",
        Default = false,
    })

    ShopGroup:AddToggle("AutoBuySpray", {
        Text = "Auto Buy Best Affordable Spray Bottle",
        Default = false,
    })

    ShopGroup:AddToggle("AutoBuyDetector", {
        Text = "Auto Buy Best Affordable Detector",
        Default = false,
    })

    ShopGroup:AddToggle("AutoEquipGear", {
        Text = "Auto Equip Best Owned Gear",
        Default = true,
    })

    ShopGroup:AddSlider("GoldReserve", {
        Text = "Keep Gold Reserve",
        Default = 0,
        Min = 0,
        Max = 1000000,
        Rounding = 0,
        Prefix = "$",
    })

    ShopGroup:AddToggle("ShopTeleport", {
        Text = "Teleport To Gear Shop",
        Default = true,
    })

    local ShopStatusGroup = Tabs.Shop:AddRightGroupbox("Status", "activity")

    local GoldLabel = ShopStatusGroup:AddLabel(field("Gold", "0", GREEN), true)
    local ShovelLabel = ShopStatusGroup:AddLabel(field("Shovel", "none", BLUE), true)
    local SprayLabel = ShopStatusGroup:AddLabel(field("Spray", "none", BLUE), true)
    local DetectorLabel = ShopStatusGroup:AddLabel(field("Detector", "none", BLUE), true)

    local PRIORITY_ROUTINES = {
        ["Dig then Clean"] = { "dig", "clean" },
        ["Clean then Sell"] = { "clean", "sell" },
        ["Dig then Sell"] = { "dig", "sell" },
        ["Dig, Clean then Sell"] = { "dig", "clean", "sell" },
        ["Dig, Clean, Place then Sell"] = { "dig", "clean", "place", "sell" },
        ["Dig, Clean, Replace, Sell"] = { "dig", "clean", "replace", "sell" },
    }

    local PRIORITY_ROUTINE_NAMES = {
        "Dig, Clean then Sell",
        "Dig, Clean, Place then Sell",
        "Dig, Clean, Replace, Sell",
        "Clean then Sell",
        "Dig then Clean",
        "Dig then Sell",
    }

    local PriorityGroup = Tabs.Priority:AddLeftGroupbox("AFK Routine", "list-ordered")

    PriorityGroup:AddToggle("PriorityMode", {
        Text = "Enable Priority Routine",
        Default = false,
    })

    PriorityGroup:AddDropdown("PriorityRoutine", {
        Values = PRIORITY_ROUTINE_NAMES,
        Default = "Dig, Clean then Sell",
        Text = "Routine",
    })

    PriorityGroup:AddDropdown("PriorityDigMode", {
        Values = { "Teleport", "Walk" },
        Default = "Teleport",
        Text = "Dig Mode",
    })

    PriorityGroup:AddDropdown("PrioritySwitch", {
        Values = { "Backpack Full", "Item Count" },
        Default = "Backpack Full",
        Text = "Leave Digging When",
    })

    PriorityGroup:AddSlider("PrioritySwitchCount", {
        Text = "Leave Digging At Item Count",
        Default = 25,
        Min = 1,
        Max = 50,
        Rounding = 0,
    })

    PriorityGroup:AddToggle("PriorityBuyGear", {
        Text = "Buy And Equip Gear Between Cycles",
        Default = true,
    })

    local PriorityStatusGroup = Tabs.Priority:AddRightGroupbox("Status", "activity")

    local PriorityStageLabel = PriorityStatusGroup:AddLabel(field("Stage", "off", ORANGE), true)
    local PriorityStepLabel = PriorityStatusGroup:AddLabel(field("Routine", "-", BLUE), true)
    local PriorityCycleLabel = PriorityStatusGroup:AddLabel(field("Cycles", "0", GREEN), true)

    local suppressConflictWarning = false

    local function warnAgainstAutoDig(toggleName, label, description)
        Toggles[toggleName]:OnChanged(function(value)
            if suppressConflictWarning or Toggles.PriorityMode.Value or not value or not Toggles.AutoDig.Value then
                return
            end

            suppressConflictWarning = true
            Toggles[toggleName]:SetValue(false)
            suppressConflictWarning = false

            local dialogId = "Conflict" .. toggleName
            local existing = Library.Dialogues[dialogId]
            if existing then
                existing:Dismiss()
            end

            Window:AddDialog(dialogId, {
                Title = "Conflicts With Auto Dig",
                Description = description,
                AutoDismiss = true,
                OutsideClickDismiss = false,
                FooterButtons = {
                    {
                        Id = "cancel",
                        Title = "Keep " .. label .. " Off",
                        Variant = "Destructive",
                        Order = 1,
                    },
                    {
                        Id = "keep",
                        Title = "Enable Anyway",
                        Variant = "Primary",
                        Order = 2,
                        Callback = function()
                            suppressConflictWarning = true
                            Toggles[toggleName]:SetValue(true)
                            suppressConflictWarning = false
                        end,
                    },
                },
            })
        end)
    end

    warnAgainstAutoDig(
        "AutoClean",
        "Auto Clean",
        "Auto Dig is running. Cleaning takes you to the workbench and pauses digging until the backpack is clean. Set Clean Priority so the two take turns the way you want."
    )

    warnAgainstAutoDig(
        "AutoSell",
        "Auto Sell",
        "Auto Dig is running. Selling teleports you to the seller and sells everything still in the backpack, including items you have not cleaned or placed yet."
    )

    local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "menu")

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

    local digConnection
    local walkNoclipConnection
    local stopDigWalk
    local travelBusy
    local syncingDigMode

    ;(function()
    local POWER_TIERS = DiggingConfig.DIG_POWER_TIERS
    local POWER_TARGET = POWER_TIERS[#POWER_TIERS].minPower

    local digClickBudget = 0
    local cleanActive = false
    local buyActive = false
    travelBusy = false

    local WALK_ARRIVAL_DISTANCE = 6
    local WALK_SPEED_WHILE_ACTIVE = 100
    local WALK_POINTS_BY_ISLAND = {
        starterIsland = {
            Vector3.new(-119, 18, -660),
            Vector3.new(-119, 18, -178),
            Vector3.new(-96, 17, -178),
            Vector3.new(-94, 17, -659),
            Vector3.new(-66, 14, -660),
            Vector3.new(-60, 13, -178),
        },
        island2 = {
            Vector3.new(1380, 14, -89),
            Vector3.new(1280, 16, -15),
            Vector3.new(1270, 15, 76),
            Vector3.new(1323, 14, 165),
            Vector3.new(1416, 12, 163),
            Vector3.new(1510, 17, 94),
            Vector3.new(1519, 14, -12),
            Vector3.new(1428, 15, -82),
        },
        island3 = {
            Vector3.new(2431, 24, 1791),
            Vector3.new(2280, 23, 1852),
            Vector3.new(2253, 24, 1986),
            Vector3.new(2309, 27, 2046),
            Vector3.new(2327, 26, 2179),
            Vector3.new(2388, 20, 2225),
            Vector3.new(2503, 19, 2185),
            Vector3.new(2685, 22, 2053),
            Vector3.new(2682, 22, 1931),
            Vector3.new(2711, 23, 1831),
            Vector3.new(2687, 20, 1718),
            Vector3.new(2592, 25, 1672),
            Vector3.new(2505, 20, 1682),
        },
    }

local walkIndex = 1
local walkOriginalSpeed = 16
local walkSpeedActive = false
syncingDigMode = false
local WALK_RESUME_DELAY = 1.25
local walkResumeAt = 0

local function selectedIslandId()
    local island = IslandByName[Options.DigIsland.Value]
    return island and island.id
end

local function digModeIsWalk()
    return Options.DigMode.Value == "Walk"
end

stopDigWalk = function()
    if not walkSpeedActive then
        return
    end
    walkSpeedActive = false
    local humanoid = getHumanoid()
    local root = getRoot()
    if humanoid then
        humanoid.WalkSpeed = walkOriginalSpeed
        if root then
            humanoid:MoveTo(root.Position)
        end
    end
    local character = getCharacter()
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end
end

local function teleportToWalkStart()
    local points = WALK_POINTS_BY_ISLAND[selectedIslandId()]
    if not points or not points[1] then
        return false
    end
    walkIndex = 1
    local cf = CFrame.new(points[1] + Vector3.new(0, 3, 0))
    local ok = pcall(teleportStreamed, LocalPlayer, cf)
    if not ok then
        return teleportTo(points[1] + Vector3.new(0, 3, 0))
    end
    return true
end

local function beginWalkResume()
    stopDigWalk()
    walkResumeAt = os.clock() + WALK_RESUME_DELAY
end

local function stepDigWalk()
    local humanoid = getHumanoid()
    local root = getRoot()
    if not humanoid or not root or humanoid.Health <= 0 then
        return
    end

    if os.clock() < walkResumeAt then
        humanoid:MoveTo(root.Position)
        return
    end

    if not walkSpeedActive then
        walkOriginalSpeed = humanoid.WalkSpeed
        walkSpeedActive = true
    end

    if humanoid.WalkSpeed ~= WALK_SPEED_WHILE_ACTIVE then
        humanoid.WalkSpeed = WALK_SPEED_WHILE_ACTIVE
    end

    local points = WALK_POINTS_BY_ISLAND[selectedIslandId()]
    if not points or #points == 0 then
        return
    end

    if walkIndex < 1 or walkIndex > #points then
        walkIndex = 1
    end

    local target = points[walkIndex]
    if (root.Position - target).Magnitude <= WALK_ARRIVAL_DISTANCE then
        walkIndex += 1
        if walkIndex > #points then
            walkIndex = 1
        end
        target = points[walkIndex]
    end

    humanoid:MoveTo(target)
end

walkNoclipConnection = RunService.Stepped:Connect(function()
    if Library.Unloaded or not walkSpeedActive then
        return
    end
    local character = getCharacter()
    if not character then
        return
    end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            part.CanCollide = false
        end
    end
end)

    Options.DigMode:OnChanged(function(value)
        if value ~= "Walk" then
            stopDigWalk()
        end
        if syncingDigMode then
            return
        end
        syncingDigMode = true
        Options.PriorityDigMode:SetValue(value)
        syncingDigMode = false
    end)

    Options.PriorityDigMode:OnChanged(function(value)
        if syncingDigMode then
            return
        end
        syncingDigMode = true
        Options.DigMode:SetValue(value)
        syncingDigMode = false
    end)

    Options.DigIsland:OnChanged(function()
        table.clear(travelCooldownUntil)
        table.clear(travelNotified)
        walkIndex = 1
    end)

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if walkSpeedActive then
            local humanoid = getHumanoid()
            if humanoid then
                humanoid.WalkSpeed = WALK_SPEED_WHILE_ACTIVE
            end
        end
    end)

    local function rarityAllowed(rarity)
        local minimum = RARITY_INDEX[Options.DigMinRarity.Value]
        if not minimum or minimum <= 1 then
            return true
        end
        local index = RARITY_INDEX[rarity]
        return index ~= nil and index >= minimum
    end

    local function isRarityFiltered()
        local minimum = RARITY_INDEX[Options.DigMinRarity.Value]
        return minimum ~= nil and minimum > 1
    end

    local DIG_ZONE_TAG = "DigZone"
    local ZONE_HOP_SECONDS = 3

    local lastZoneHopAt = 0

    local function wanderDigZone(islandId)
        local island = getIslandModel(islandId)
        if not island then
            return false
        end

        local zones = {}
        for _, zone in ipairs(CollectionService:GetTagged(DIG_ZONE_TAG)) do
            if zone:IsA("BasePart") and zone:IsDescendantOf(island) then
                zones[#zones + 1] = zone
            end
        end

        if #zones == 0 then
            return false
        end

        local point = DigZoneSpawn.randomDigZonePoint(zones)
        if not point then
            return false
        end

        return teleportTo(point.position + Vector3.new(0, 3, 0))
    end

    local function bestSurfacedTarget(position)
        local best, bestDistance
        for _, item in pairs(surfacedItems) do
            local definition = Items.Items[item.itemId]
            if definition and rarityAllowed(definition.rarity) then
                local distance = (item.position - position).Magnitude
                if not bestDistance or distance < bestDistance then
                    best = item
                    bestDistance = distance
                end
            end
        end
        return best, bestDistance
    end

    local function islandSpawnCFrame(islandId)
        refreshIslandSpawns()
        local island = IslandById[islandId]
        local spawn = island and island.spawn
        if typeof(spawn) == "CFrame" then
            return spawn + Vector3.new(0, 4, 0)
        end
        if typeof(spawn) == "Vector3" then
            return CFrame.new(spawn + Vector3.new(0, 4, 0))
        end
        if typeof(spawn) == "Instance" then
            return spawn:GetPivot() + Vector3.new(0, 4, 0)
        end
        local model = getIslandModel(islandId)
        if model then
            local marker = model:FindFirstChild("Spawn") or model:FindFirstChildWhichIsA("SpawnLocation", true)
            if marker then
                return marker:GetPivot() + Vector3.new(0, 4, 0)
            end
            return model:GetPivot() + Vector3.new(0, 20, 0)
        end
        return nil
    end

    local function ensureIsland(islandId)
        if not islandId then
            return true
        end
        local data = getData()
        if data and data.CurrentIsland == islandId then
            return true
        end
        if travelBusy or not data then
            return false
        end
        if travelCooldownUntil[islandId] and os.clock() < travelCooldownUntil[islandId] then
            return false
        end

        travelBusy = true
        task.spawn(function()
            local ok, result = pcall(function()
                return TravelFunctions.travel:invoke(islandId):expect()
            end)

            local island = IslandById[islandId]
            local name = island and island.name or islandId
            local spawnCf = islandSpawnCFrame(islandId)

            if ok and result == "ok" then
                if spawnCf then
                    pcall(teleportStreamed, LocalPlayer, spawnCf)
                end
                for _ = 1, 20 do
                    task.wait(0.15)
                    local latest = getData()
                    if latest and latest.CurrentIsland == islandId then
                        break
                    end
                end
                refreshSurfacedItems()
                travelNotified[islandId] = nil
                travelCooldownUntil[islandId] = nil
                if digModeIsWalk() then
                    beginWalkResume()
                end
            elseif result == "poor" then
                travelCooldownUntil[islandId] = os.clock() + 8
                if not travelNotified[islandId] then
                    travelNotified[islandId] = true
                    local definition = IslandConstants.Islands[islandId]
                    local cost = definition and definition.cost
                    if type(cost) == "number" and cost > 0 then
                        Library:Notify(string.format("Need $%s to unlock %s", tostring(cost), name))
                    else
                        Library:Notify("Could not travel to " .. name)
                    end
                end
            else
                travelCooldownUntil[islandId] = os.clock() + 5
                if spawnCf then
                    pcall(teleportStreamed, LocalPlayer, spawnCf)
                end
                if not travelNotified[islandId] then
                    travelNotified[islandId] = true
                    Library:Notify("Could not travel to " .. name)
                end
                if digModeIsWalk() then
                    beginWalkResume()
                end
            end

            task.wait(0.35)
            travelBusy = false
        end)

        return false
    end

    local function isWorkbenchBusy()
        local workbench = resolve(WORKBENCH_CONTROLLER)
        if not workbench then
            return false
        end
        return workbench.session ~= nil or workbench.cleaning == true
    end

    local function isDigBusy()
        local dig = resolve(DIG_CONTROLLER)
        if not dig then
            return false
        end
        return dig.session ~= nil
    end

    local function stepAutoDig(delta)
        if cleanActive or buyActive or isWorkbenchBusy() then
            return
        end

        local dig = resolve(DIG_CONTROLLER)
        if not dig then
            return
        end

        local session = dig.session
        if session then
            if session.phase == "power" then
                local elapsed = Workspace:GetServerTimeNow() - session.powerStartedAt
                if elapsed >= DiggingConfig.DIG_POWER_MIN_STOP_SECONDS then
                    local ready = Options.DigPowerMode.Value == "Fastest"
                        or DiggingConfig.digPowerAt(elapsed) >= POWER_TARGET
                        or elapsed >= DiggingConfig.DIG_POWER_MAX_SECONDS - 0.25
                    if ready then
                        pcall(dig.stopPower, dig)
                    end
                end
            elseif session.phase == "minigame" then
                digClickBudget = math.min(digClickBudget + delta * Options.DigClickRate.Value, 20)
                while digClickBudget >= 1 and dig.session == session and session.clickCredits >= 1 do
                    digClickBudget -= 1
                    pcall(dig.onDigInput, dig)
                end
            end
            return
        end

        digClickBudget = 0

        local root = getRoot()
        if not root then
            return
        end

        local humanoid = getHumanoid()
        if not humanoid or humanoid.Health <= 0 then
            return
        end

        local data = getData()
        if Toggles.DigStopWhenFull.Value and data and BackpackCapacity.isFull(data) then
            stopDigWalk()
            return
        end

        local character = getCharacter()
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Tool") and child:GetAttribute("inventoryId") ~= nil then
                if Toggles.AutoClean.Value and CollectionService:HasTag(child, "Dirt") then
                    return
                end
                humanoid:UnequipTools()
                return
            end
        end

        if not ensureIsland(selectedIslandId()) then
            return
        end

        if dig:isBusyDigging() then
            return
        end

        local sweep = resolve(SWEEP_CONTROLLER)
        local surfaced = resolve(SURFACED_CONTROLLER)
        local filtered = isRarityFiltered()

        local targetItem, targetDistance = bestSurfacedTarget(root.Position)

        local hasSpot = false
        if sweep then
            local ok, node = pcall(sweep.nearestSpot, sweep, root.Position)
            hasSpot = ok and node ~= nil and rarityAllowed(node.rarity)
        end
        if not hasSpot and targetDistance then
            hasSpot = targetDistance <= 6
        end
        if not hasSpot and not filtered and surfaced then
            local ok, result = pcall(surfaced.hasDigSpotNear, surfaced, root.Position)
            hasSpot = ok and result ~= nil and result ~= false
        end

        if hasSpot then
            if walkSpeedActive then
                humanoid:MoveTo(root.Position)
            end
            pcall(dig.requestSession, dig)
            return
        end

        if digModeIsWalk() then
            stepDigWalk()
            return
        end

        if not Toggles.AutoDigTravel.Value then
            return
        end

        local bestPosition, bestDistance, bestNodeId, bestNode

        if sweep then
            for nodeId, node in pairs(sweep.nodes) do
                if rarityAllowed(node.rarity) then
                    local distance = (node.position - root.Position).Magnitude
                    if not bestDistance or distance < bestDistance then
                        bestPosition = node.position
                        bestDistance = distance
                        bestNodeId = nodeId
                        bestNode = node
                    end
                end
            end
        end

        if targetItem and (not bestDistance or targetDistance < bestDistance) then
            bestPosition = targetItem.position
            bestDistance = targetDistance
            bestNodeId = nil
            bestNode = nil
        end

        if bestPosition then
            if bestDistance > 4 then
                teleportTo(bestPosition + Vector3.new(0, 3, 0))
            elseif bestNode and not sweep.surfaced[bestNodeId] then
                -- Detector nodes are only diggable after the client surfaces them.
                -- Shipwreck Cove uses these buried nodes exclusively, so waiting for
                -- nearestSpot here otherwise leaves Auto Dig stuck beside the target.
                pcall(sweep.surface, sweep, bestNodeId, bestNode)
            end
            return
        end

        if os.clock() - lastZoneHopAt < ZONE_HOP_SECONDS then
            return
        end

        lastZoneHopAt = os.clock()
        wanderDigZone(selectedIslandId() or (getData() and getData().CurrentIsland))
    end

local CLEAN_ENTER_TIMEOUT = 5

local cleanSessionStartedAt = 0
local cleanEnterStartedAt = 0
local cleanReturnCFrame = nil
local cleanNeedsReturn = false

local function stepAutoClean()
    local workbench = resolve(WORKBENCH_CONTROLLER)
    if not workbench then
        return false
    end

    if workbench.session then
        local spray = resolve(SPRAY_CONTROLLER)
        if not spray or spray.finishing then
            return true
        end

        if cleanSessionStartedAt == 0 then
            cleanSessionStartedAt = os.clock()
        end

        local primed = spray.dirtCells ~= nil
            or (type(spray.dirtBlocks) == "table" and #spray.dirtBlocks > 0)
        local waited = os.clock() - cleanSessionStartedAt
        if not primed and waited < 15 then
            return true
        end
        if primed and waited < Options.CleanFinishDelay.Value then
            return true
        end

        pcall(function()
            if spray.popAllDirt then
                spray:popAllDirt()
            end
            spray:sweepRemaining()
            spray:forceFinish()
        end)
        return true
    end

    if cleanSessionStartedAt ~= 0 then
        cleanSessionStartedAt = 0
        if Toggles.CleanReturn.Value then
            cleanNeedsReturn = true
        else
            cleanReturnCFrame = nil
        end
    end

    if cleanNeedsReturn then
        local targetIsland = selectedIslandId()
        if Toggles.AutoTravelIsland.Value and targetIsland and not ensureIsland(targetIsland) then
            return true
        end
        if digModeIsWalk() then
            teleportToWalkStart()
            beginWalkResume()
        elseif cleanReturnCFrame then
            pcall(teleportStreamed, LocalPlayer, cleanReturnCFrame)
        end
        cleanReturnCFrame = nil
        cleanNeedsReturn = false
        return true
    end

    if workbench.cleaning then
        if cleanEnterStartedAt == 0 then
            cleanEnterStartedAt = os.clock()
        end
        return os.clock() - cleanEnterStartedAt < CLEAN_ENTER_TIMEOUT
    end

    cleanEnterStartedAt = 0

    local tool, held = findDirtyTool()
    if not tool then
        return false
    end

    if not held then
        local humanoid = getHumanoid()
        if not humanoid then
            return false
        end
        humanoid:EquipTool(tool)
        return true
    end

    if not cleanReturnCFrame then
        local root = getRoot()
        if root then
            cleanReturnCFrame = root.CFrame
        end
    end

    if Toggles.AutoTravelIsland.Value and not ensureIsland(IslandConstants.STARTER_ISLAND_ID) then
        return true
    end

    local bench = workbench.workbench
    if not bench then
        return false
    end

    local root = getRoot()
    if not root then
        return false
    end

    if Toggles.CleanTeleport.Value then
        teleportTo(bench:GetPivot().Position + Vector3.new(0, 4, 0))
        task.wait(0.2)
    end

    pcall(workbench.onTriggered, workbench)

    return true
end

    local function hasDirtyItems()
        local data = getData()
        if not data then
            return false
        end
        local minimum = 1
        if Options and Options.CleanRarityPriority then
            minimum = RARITY_INDEX[Options.CleanRarityPriority.Value] or 1
        end
        for _, entry in pairs(data.Inventory) do
            if entry.dirty == true then
                local definition = Items.Items[entry.id]
                local index = definition and RARITY_INDEX[definition.rarity] or 0
                if index >= minimum then
                    return true
                end
            end
        end
        return false
    end

    local function shouldStartCleaning()
        if not Toggles.AutoClean.Value then
            return false
        end
        if isWorkbenchBusy() then
            return true
        end
        if isDigBusy() then
            return false
        end
        if not hasDirtyItems() then
            return false
        end

        local mode = Options.CleanPriority.Value
        if mode == "Always" then
            return true
        end
        if mode == "When Not Digging" then
            return not Toggles.AutoDig.Value
        end

        local data = getData()
        return data ~= nil and BackpackCapacity.isFull(data)
    end

    local function conditionAllowed(condition)
        local selected = Options.PlaceConditions.Value
        local any = false
        for _, enabled in pairs(selected) do
            if enabled then
                any = true
                break
            end
        end
        if not any then
            return true
        end
        return selected[condition] == true
    end

    local function itemRarityIndex(entry)
        local definition = Items.Items[entry.id]
        if not definition then
            return 0
        end
        return RARITY_INDEX[definition.rarity] or 0
    end

    local function itemConditionIndex(entry)
        return CONDITION_INDEX[entry.condition] or 0
    end

    local function placeCandidateAllowed(entry)
        if entry.dirty ~= false or entry.pedestalSlot ~= nil or entry.polisherSlot ~= nil then
            return false
        end
        if not conditionAllowed(entry.condition) then
            return false
        end
        return itemValue(entry) >= Options.PlaceMinValue.Value
    end

    local function replaceCandidateAllowed(entry)
        if entry.dirty ~= false or entry.pedestalSlot ~= nil or entry.polisherSlot ~= nil then
            return false
        end
        if itemRarityIndex(entry) < (RARITY_INDEX[Options.ReplaceMinRarity.Value] or 1) then
            return false
        end
        if itemConditionIndex(entry) < (CONDITION_INDEX[Options.ReplaceMinCondition.Value] or 1) then
            return false
        end
        return itemValue(entry) >= Options.ReplaceMinValue.Value
    end

    local function pedestalFailsConfiguration(entry)
        if itemRarityIndex(entry) < (RARITY_INDEX[Options.ReplaceMinRarity.Value] or 1) then
            return true
        end
        if itemConditionIndex(entry) < (CONDITION_INDEX[Options.ReplaceMinCondition.Value] or 1) then
            return true
        end
        return itemValue(entry) < Options.ReplaceMinValue.Value
    end

    local function shouldReplacePedestal(candidate, current)
        local mode = Options.ReplaceMode.Value
        local candidateValue = itemValue(candidate)
        local currentValue = itemValue(current)
        local candidateRarity = itemRarityIndex(candidate)
        local currentRarity = itemRarityIndex(current)
        local candidateCondition = itemConditionIndex(candidate)
        local currentCondition = itemConditionIndex(current)
        local improvement = Options.ReplaceImprovement.Value
        local neededValue = currentValue * (1 + improvement / 100)

        if mode == "Higher Rarity" then
            return candidateRarity > currentRarity
        elseif mode == "Better Condition" then
            return candidateCondition > currentCondition
        elseif mode == "Configuration" then
            if pedestalFailsConfiguration(current) then
                return true
            end
            return candidateValue > neededValue
        end

        return candidateValue > neededValue
    end

    local function replaceScore(entry)
        local mode = Options.ReplaceMode.Value
        if mode == "Higher Rarity" then
            return itemRarityIndex(entry)
        elseif mode == "Better Condition" then
            return itemConditionIndex(entry)
        end
        return itemValue(entry)
    end

    local function hasPlaceCandidate()
        local data = getData()
        if not data then
            return false
        end
        for _, entry in pairs(data.Inventory) do
            if placeCandidateAllowed(entry) then
                return true
            end
        end
        return false
    end

    local function hasReplaceCandidate()
        local data = getData()
        if not data then
            return false
        end

        local occupied = {}
        for _, entry in pairs(data.Inventory) do
            if entry.pedestalSlot then
                occupied[#occupied + 1] = entry
            end
        end
        if #occupied == 0 then
            return false
        end

        for _, entry in pairs(data.Inventory) do
            if replaceCandidateAllowed(entry) then
                for _, current in ipairs(occupied) do
                    if shouldReplacePedestal(entry, current) then
                        return true
                    end
                end
            end
        end
        return false
    end

    local function findReplacement()
        local data = getData()
        if not data then
            return nil
        end

        local plot = getPlot()
        if not plot then
            return nil
        end

        local pedestals = collectOwnedPedestals(plot)
        if #pedestals == 0 then
            return nil
        end

        local occupied = {}
        for _, entry in pairs(data.Inventory) do
            if entry.pedestalSlot then
                occupied[entry.pedestalSlot] = entry
            end
        end

        local bestCandidate = nil
        local targetSlot = nil
        local targetPedestal = nil
        local bestPairScore = nil

        for _, entry in pairs(data.Inventory) do
            if replaceCandidateAllowed(entry) then
                local value = itemValue(entry)
                for _, pedestal in ipairs(pedestals) do
                    local slot = pedestal:GetAttribute("Slot")
                    local current = type(slot) == "number" and occupied[slot]
                    if current and shouldReplacePedestal(entry, current) then
                        local pairScore = value * 1000000 - replaceScore(current)
                        if bestPairScore == nil or pairScore > bestPairScore then
                            bestCandidate = entry
                            targetSlot = slot
                            targetPedestal = pedestal
                            bestPairScore = pairScore
                        end
                    end
                end
            end
        end

        if not bestCandidate then
            return nil
        end

        return bestCandidate, targetSlot, targetPedestal
    end

    local function findPlacement(forcePlace)
        local data = getData()
        if not data then
            return nil
        end

        local plot = getPlot()
        if not plot then
            return nil
        end

        local pedestals = collectOwnedPedestals(plot)
        if #pedestals == 0 then
            return nil
        end

        local occupied = {}
        for _, entry in pairs(data.Inventory) do
            if entry.pedestalSlot then
                occupied[entry.pedestalSlot] = entry
            end
        end

        if forcePlace or Toggles.AutoPlace.Value then
            local candidate = nil
            local candidateValue = 0
            for _, entry in pairs(data.Inventory) do
                if placeCandidateAllowed(entry) then
                    local value = itemValue(entry)
                    if value > candidateValue then
                        candidate = entry
                        candidateValue = value
                    end
                end
            end

            if candidate then
                local targetSlot = nil
                local targetPedestal = nil
                local worstValue = nil

                for _, pedestal in ipairs(pedestals) do
                    local slot = pedestal:GetAttribute("Slot")
                    if type(slot) == "number" then
                        local current = occupied[slot]
                        if not current then
                            return candidate, slot, pedestal
                        elseif Toggles.PlaceReplaceWorse.Value then
                            local value = itemValue(current)
                            if value < candidateValue and (worstValue == nil or value < worstValue) then
                                targetSlot = slot
                                targetPedestal = pedestal
                                worstValue = value
                            end
                        end
                    end
                end

                if targetSlot then
                    return candidate, targetSlot, targetPedestal
                end
            end
        end

        if Toggles.AutoReplace.Value then
            return findReplacement()
        end

        return nil
    end

    local function applyPedestalAction(candidate, targetSlot, targetPedestal)
        if not candidate then
            return
        end

        local tool, held = findToolByInventoryId(candidate.uid)
        if tool and not held then
            local humanoid = getHumanoid()
            if humanoid then
                humanoid:EquipTool(tool)
            end
        end

        if Toggles.PlaceTeleport.Value and targetPedestal then
            teleportTo(targetPedestal:GetPivot().Position + Vector3.new(0, 4, 0))
            task.wait(0.2)
        end

        pcall(function()
            PedestalFunctions.placeItem:invoke(targetSlot, candidate.uid)
        end)
    end

    local function stepAutoPlace()
        local needsTravel = (Toggles.AutoPlace.Value and hasPlaceCandidate()) or (Toggles.AutoReplace.Value and hasReplaceCandidate())
        if Toggles.AutoTravelIsland.Value and needsTravel and not ensureIsland(IslandConstants.STARTER_ISLAND_ID) then
            return
        end

        applyPedestalAction(findPlacement())
    end

    local function stepAutoReplace()
        if Toggles.AutoTravelIsland.Value and hasReplaceCandidate() and not ensureIsland(IslandConstants.STARTER_ISLAND_ID) then
            return
        end

        applyPedestalAction(findReplacement())
    end

    local lastSellAt = os.clock()

    local function isSellableEntry(entry)
        if entry.favorited == true or entry.pedestalSlot ~= nil or entry.polisherSlot ~= nil then
            return false
        end
        return true
    end

    local function isJunkEntry(entry)
        if not isSellableEntry(entry) then
            return false
        end
        local maxRarity = RARITY_INDEX[Options.SellMaxRarity.Value] or 1
        if itemRarityIndex(entry) > maxRarity then
            return false
        end

        local belowValue = Options.SellBelowValue.Value
        local belowKg = Options.SellBelowKg.Value
        local valueEnabled = belowValue > 0
        local kgEnabled = belowKg > 0
        if not valueEnabled and not kgEnabled then
            return true
        end

        local kg = tonumber(entry.kg) or 0
        local valueMatch = valueEnabled and itemValue(entry) < belowValue
        local kgMatch = kgEnabled and kg < belowKg
        if valueEnabled and kgEnabled then
            return valueMatch or kgMatch
        end
        if valueEnabled then
            return valueMatch
        end
        return kgMatch
    end

    local function collectJunkEntries(data)
        local junk = {}
        for key, entry in pairs(data.Inventory) do
            if isJunkEntry(entry) then
                local uid = entry.uid
                if type(uid) ~= "string" then
                    uid = key
                end
                if type(uid) == "string" then
                    junk[#junk + 1] = { entry = entry, uid = uid }
                end
            end
        end
        return junk
    end

    local function sellHeldEntry(uid)
        if type(uid) ~= "string" then
            return false
        end
        local tool, held = findToolByInventoryId(uid)
        if not tool then
            return false
        end
        if not held then
            local humanoid = getHumanoid()
            if not humanoid then
                return false
            end
            humanoid:EquipTool(tool)
            task.wait(0.25)
            tool, held = findToolByInventoryId(uid)
            if not tool or not held then
                return false
            end
        end
        local ok, result = pcall(function()
            return SellFunctions.sellHeldItem:invoke():expect()
        end)
        return ok and type(result) == "number"
    end

    local function stepAutoSell(force)
        local data = getData()
        if not data then
            return
        end

        local junkOnly = Options.SellTarget.Value == "Junk Only"
        local count = BackpackCapacity.count(data.Inventory)
        if count <= 0 then
            return
        end

        local junk = collectJunkEntries(data)
        if junkOnly and #junk <= 0 and not force then
            return
        end

        if not force then
            local mode = Options.SellMode.Value
            local trigger
            if mode == "Item Count" then
                trigger = count >= Options.SellItemCount.Value
            elseif mode == "Timer" then
                trigger = os.clock() - lastSellAt >= Options.SellInterval.Value
            elseif mode == "Junk Found" then
                trigger = #junk > 0
            else
                trigger = BackpackCapacity.isFull(data)
            end

            if not trigger then
                return
            end
        end

        local root = getRoot()
        local returnIsland = selectedIslandId() or data.CurrentIsland
        local returnCFrame = nil
        if root and data.CurrentIsland ~= IslandConstants.STARTER_ISLAND_ID then
            returnCFrame = root.CFrame
        end

        if Toggles.AutoTravelIsland.Value and not ensureIsland(IslandConstants.STARTER_ISLAND_ID) then
            return
        end

        lastSellAt = os.clock()

        if Toggles.SellTeleport.Value then
            local npc = getNpc(data.CurrentIsland, "Sell") or getNpc(IslandConstants.STARTER_ISLAND_ID, "Sell")
            if npc then
                teleportTo(npc:GetPivot().Position + Vector3.new(0, 4, 4))
                task.wait(0.3)
            end
        end

        if force or not junkOnly then
            local humanoid = getHumanoid()
            if humanoid then
                humanoid:UnequipTools()
            end
            pcall(function()
                SellFunctions.sellInventory:invoke()
            end)
            task.wait(0.3)
        else
            for _, item in ipairs(junk) do
                if Library.Unloaded then
                    break
                end
                pcall(sellHeldEntry, item.uid)
                task.wait(0.3)
            end
            local humanoid = getHumanoid()
            if humanoid then
                humanoid:UnequipTools()
            end
        end

        if Toggles.SellReturn.Value then
            if Toggles.AutoTravelIsland.Value and returnIsland then
                ensureIsland(returnIsland)
            elseif digModeIsWalk() then
                teleportToWalkStart()
                beginWalkResume()
            elseif returnCFrame then
                pcall(teleportStreamed, LocalPlayer, returnCFrame)
            end
        end
    end

    local function teleportToGearShop(data)
        local npc = getNpc(data.CurrentIsland, "Gear") or getNpc(IslandConstants.STARTER_ISLAND_ID, "Gear")
        if not npc then
            return nil
        end
        local root = getRoot()
        local returnCFrame = root and root.CFrame
        teleportTo(npc:GetPivot().Position + Vector3.new(0, 4, 4))
        task.wait(0.3)
        return returnCFrame
    end

    local function stepAutoBuy(forceAll)
        if buyActive then
            return
        end

        local data = getData()
        if not data then
            return
        end

        local budget = data.Gold - Options.GoldReserve.Value
        if budget <= 0 then
            return
        end

        local purchases = {}

        if forceAll or Toggles.AutoBuyShovel.Value then
            local id = bestAffordableGear(Shovels.SHOVEL_TIER_ORDER, Shovels.Shovels, data.OwnedShovels, data.UnlockedIslands, budget)
            if id then
                table.insert(purchases, { "shovel", id })
            end
        end

        if forceAll or Toggles.AutoBuySpray.Value then
            local id = bestAffordableGear(SprayBottles.SPRAY_TIER_ORDER, SprayBottles.SprayBottles, data.OwnedSprays, data.UnlockedIslands, budget)
            if id then
                table.insert(purchases, { "spray", id })
            end
        end

        if forceAll or Toggles.AutoBuyDetector.Value then
            local id = bestAffordableGear(Detectors.DETECTOR_TIER_ORDER, Detectors.Detectors, data.OwnedDetectors, data.UnlockedIslands, budget)
            if id then
                table.insert(purchases, { "detector", id })
            end
        end

        if #purchases == 0 then
            return
        end

        buyActive = true
        stopDigWalk()
        pcall(function()
            local returnCFrame = nil
            if Toggles.ShopTeleport.Value then
                returnCFrame = teleportToGearShop(data)
            end

            for _, purchase in ipairs(purchases) do
                pcall(function()
                    ShopFunctions.buyGear:invoke(purchase[1], purchase[2])
                end)
                task.wait(0.4)
            end

            if returnCFrame then
                if digModeIsWalk() then
                    teleportToWalkStart()
                    beginWalkResume()
                else
                    local root = getRoot()
                    if root then
                        root.CFrame = returnCFrame
                    end
                end
            end
        end)
        buyActive = false
    end

    local function stepAutoEquip()
        local data = getData()
        if not data then
            return
        end

        local shovel = highestOwnedGear(Shovels.SHOVEL_TIER_ORDER, data.OwnedShovels)
        if shovel and shovel ~= data.EquippedShovel then
            pcall(function()
                ShopFunctions.equipGear:invoke("shovel", shovel)
            end)
        end

        local spray = highestOwnedGear(SprayBottles.SPRAY_TIER_ORDER, data.OwnedSprays)
        if spray and spray ~= data.EquippedSpray then
            pcall(function()
                ShopFunctions.equipGear:invoke("spray", spray)
            end)
        end

        local detector = highestOwnedGear(Detectors.DETECTOR_TIER_ORDER, data.OwnedDetectors)
        if detector and detector ~= data.EquippedDetector then
            pcall(function()
                ShopFunctions.equipGear:invoke("detector", detector)
            end)
        end
    end

    local priorityIndex = 1
    local priorityCycles = 0

    Toggles.PriorityMode:OnChanged(function(enabled)
        if enabled then
            priorityIndex = 1
            cleanActive = false
        end
    end)

    local function priorityStages()
        return PRIORITY_ROUTINES[Options.PriorityRoutine.Value] or PRIORITY_ROUTINES["Dig, Clean then Sell"]
    end

    local function priorityStage()
        if not Toggles.PriorityMode.Value then
            return nil
        end
        local stages = priorityStages()
        return stages[priorityIndex], stages
    end

    local function digStageDone()
        local data = getData()
        if not data then
            return false
        end
        if BackpackCapacity.isFull(data) then
            return true
        end
        if Options.PrioritySwitch.Value == "Item Count" then
            return BackpackCapacity.count(data.Inventory) >= Options.PrioritySwitchCount.Value
        end
        return false
    end

    local function stageDone(stage)
        if stage == "dig" then
            return digStageDone()
        elseif stage == "clean" then
            return not cleanActive and not isWorkbenchBusy() and not hasDirtyItems()
        elseif stage == "place" then
            local canPlace = hasPlaceCandidate()
            local canReplace = Toggles.AutoReplace.Value and hasReplaceCandidate()
            if not canPlace and not canReplace then
                return true
            end
            return getPlot() ~= nil and findPlacement(true) == nil
        elseif stage == "replace" then
            if not hasReplaceCandidate() then
                return true
            end
            return getPlot() ~= nil and findReplacement() == nil
        elseif stage == "sell" then
            local data = getData()
            return data ~= nil and BackpackCapacity.count(data.Inventory) <= 0
        end
        return true
    end

    local function stepPriorityStage(stage)
        if stage == "dig" then
            cleanActive = false
        elseif stage == "clean" then
            local ok, busy = pcall(stepAutoClean)
            cleanActive = ok and busy == true
        elseif stage == "place" then
            local needsTravel = hasPlaceCandidate() or (Toggles.AutoReplace.Value and hasReplaceCandidate())
            if Toggles.AutoTravelIsland.Value and needsTravel and not ensureIsland(IslandConstants.STARTER_ISLAND_ID) then
                return
            end
            pcall(function()
                applyPedestalAction(findPlacement(true))
            end)
        elseif stage == "replace" then
            pcall(stepAutoReplace)
        elseif stage == "sell" then
            pcall(stepAutoSell, true)
        end
    end

    digConnection = RunService.Heartbeat:Connect(function(delta)
        if Library.Unloaded then
            return
        end

        local digging = false
        if Toggles.PriorityMode.Value then
            if priorityStage() == "dig" then
                digging = true
                cleanActive = false
            end
        elseif Toggles.AutoDig.Value then
            digging = true
        end

        if not digging then
            stopDigWalk()
            return
        end

        pcall(stepAutoDig, delta)
    end)

    task.spawn(function()
        while not Library.Unloaded do
            task.wait(0.35)

            if not Toggles.PriorityMode.Value then
                continue
            end

            local stages = priorityStages()
            if priorityIndex > #stages then
                priorityIndex = 1
                priorityCycles += 1
                if Toggles.PriorityBuyGear.Value and not buyActive and not isDigBusy() then
                    pcall(stepAutoBuy, true)
                    pcall(stepAutoEquip)
                end
            end

            local stage = stages[priorityIndex]
            if stageDone(stage) then
                priorityIndex += 1
            else
                stepPriorityStage(stage)
            end
        end
    end)

    task.spawn(function()
        while not Library.Unloaded do
            task.wait(0.35)
            if Toggles.PriorityMode.Value then
                continue
            end
            if not Toggles.AutoClean.Value then
                cleanActive = false
            else
                local shouldClean = cleanActive
                if not shouldClean then
                    local okStart, startNow = pcall(shouldStartCleaning)
                    shouldClean = okStart and startNow == true
                end
                if shouldClean then
                    cleanActive = true
                    local ok, busy = pcall(stepAutoClean)
                    cleanActive = ok and busy == true
                end
            end
        end
    end)

    task.spawn(function()
        while not Library.Unloaded do
            task.wait(1)
            if Toggles.PriorityMode.Value then
                continue
            end
            if not cleanActive and not isDigBusy() then
                if Toggles.AutoPlace.Value or Toggles.AutoReplace.Value then
                    pcall(stepAutoPlace)
                end
                if Toggles.AutoSell.Value then
                    pcall(stepAutoSell, false)
                end
            end
        end
    end)

    task.spawn(function()
        while not Library.Unloaded do
            task.wait(3)
            if Toggles.PriorityMode.Value then
                continue
            end
            if not cleanActive and not buyActive and not isDigBusy() then
                if Toggles.AutoBuyShovel.Value or Toggles.AutoBuySpray.Value or Toggles.AutoBuyDetector.Value then
                    pcall(stepAutoBuy)
                end
                if Toggles.AutoEquipGear.Value then
                    pcall(stepAutoEquip)
                end
            end
        end
    end)

    task.spawn(function()
        while not Library.Unloaded do
            task.wait(1)

            local sweep = resolve(SWEEP_CONTROLLER)
            local nodeCount = 0
            if sweep then
                for _ in pairs(sweep.nodes) do
                    nodeCount += 1
                end
            end
            DigSpotsLabel:SetText(field("Buried spots", tostring(nodeCount), BLUE))

            local dig = resolve(DIG_CONTROLLER)
            local phase = "idle"
            if dig and dig.session then
                phase = dig.session.phase or "active"
            end
            DigPhaseLabel:SetText(field("Dig phase", phase, ORANGE))

            local data = getData()
            if data then
                local count = BackpackCapacity.count(data.Inventory)
                DigBackpackLabel:SetText(field("Backpack", string.format("%d / %d", count, BackpackCapacity.limitFor(data)), GREEN))

                local dirty = 0
                for _, entry in pairs(data.Inventory) do
                    if entry.dirty == true then
                        dirty += 1
                    end
                end
                CleanDirtyLabel:SetText(field("Dirty items", tostring(dirty), ORANGE))

                GoldLabel:SetText(field("Gold", tostring(data.Gold), GREEN))

                local shovelDefinition = Shovels.Shovels[data.EquippedShovel]
                ShovelLabel:SetText(field("Shovel", shovelDefinition and shovelDefinition.displayName or "none", BLUE))

                local sprayDefinition = SprayBottles.SprayBottles[data.EquippedSpray]
                SprayLabel:SetText(field("Spray", sprayDefinition and sprayDefinition.displayName or "none", BLUE))

                local detectorDefinition = Detectors.Detectors[data.EquippedDetector]
                DetectorLabel:SetText(field("Detector", detectorDefinition and detectorDefinition.displayName or "none", BLUE))
            end

            if Toggles.PriorityMode.Value then
                local stages = priorityStages()
                local stage = stages[priorityIndex] or "-"
                PriorityStageLabel:SetText(field("Stage", stage, ORANGE))
                PriorityStepLabel:SetText(field("Routine", string.format("%d / %d", math.min(priorityIndex, #stages), #stages), BLUE))
            else
                PriorityStageLabel:SetText(field("Stage", "off", ORANGE))
                PriorityStepLabel:SetText(field("Routine", "-", BLUE))
            end
            PriorityCycleLabel:SetText(field("Cycles", tostring(priorityCycles), GREEN))

            local workbench = resolve(WORKBENCH_CONTROLLER)
            local state = "idle"
            if workbench then
                if workbench.session then
                    state = "cleaning"
                elseif workbench.cleaning then
                    state = "entering"
                end
            end
            CleanStateLabel:SetText(field("Workbench", state, BLUE))
        end
    end)

    end)()

    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder("OuroborosHub")
    ThemeManager:SaveDefault("Monochrome")
    ThemeManager:ApplyToTab(Tabs.Settings)
    ThemeManager:LoadDefault()

    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
    SaveManager:SetFolder("OuroborosHub/dig-and-clean")
    SaveManager:BuildConfigSection(Tabs.Settings)

    suppressConflictWarning = true
    SaveManager:LoadAutoloadConfig()
    suppressConflictWarning = false

    syncingDigMode = true
    Options.PriorityDigMode:SetValue(Options.DigMode.Value)
    syncingDigMode = false

    task.spawn(function()
        while not Library.Unloaded do
            task.wait(10)
            if not travelBusy then
                refreshSurfacedItems()
            end
        end
    end)

    Library:OnUnload(function()
        stopDigWalk()
        walkNoclipConnection:Disconnect()
        for _, connection in ipairs(surfacedConnections) do
            pcall(function()
                connection:Disconnect()
            end)
        end
        digConnection:Disconnect()
        antiAfkBeganConnection:Disconnect()
        antiAfkChangedConnection:Disconnect()
    end)
