local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

if getgenv then
    getgenv().gethui = function()
        return LocalPlayer:WaitForChild("PlayerGui")
    end
end

local GAME_NAME = "My Moo Farm"

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Format = require(Shared:WaitForChild("Format"))
local Economy = require(Shared:WaitForChild("Economy"))
local Config = require(Shared:WaitForChild("Config"))
local ItemTypes = require(Shared:WaitForChild("ItemTypes"))
local SellCatalog = require(Shared:WaitForChild("SellCatalog"))
local ShopCatalog = require(Shared:WaitForChild("ShopCatalog"))
local ItemShopCatalog = require(Shared:WaitForChild("ItemShopCatalog"))
local CowCatalog = require(Shared:WaitForChild("CowCatalog"))

local ClientFolder = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
local InventoryUI = require(ClientFolder:WaitForChild("InventoryUI"))
local SelectionState = require(ClientFolder:WaitForChild("SelectionState"))
local MyLandState = require(ClientFolder:WaitForChild("MyLandState"))

local repo = "https://raw.githubusercontent.com/joustingmatch/ObsidianUltra/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

pcall(function()
    Library.ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end)

local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Toggles = Library.Toggles
local Options = Library.Options

local function on(name)
    local toggle = Toggles[name]
    return toggle ~= nil and toggle.Value == true
end

local function opt(name, fallback)
    local option = Options[name]
    if option == nil or option.Value == nil then
        return fallback
    end
    return option.Value
end

local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"
local RSCRIPTS_LINK = "https://rscripts.net/@Ouroboros"

local function copyDiscord()
    if setclipboard then
        setclipboard(DISCORD_INVITE)
    elseif toclipboard then
        toclipboard(DISCORD_INVITE)
    end
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

local MILK_TIMEOUT = 60
local MILK_START_GRACE = 2

local money = nil
local seedStock = nil
local itemStock = nil
local cowStock = nil

local levels = {
    expand = {},
    market = {},
    tip = {},
    npc = {},
}

local UPGRADE_KINDS = {
    {
        key = "expand",
        name = "Expand Farm",
        default = 1,
        max = Config.MAX_LAND_LEVEL,
        prices = Economy.EXPAND_PRICE,
        remote = Remotes.ExpandRequest,
    },
    {
        key = "market",
        name = "Upgrade Market",
        default = 1,
        max = Economy.SELL_MARKET_MAX_LEVEL,
        prices = Economy.SELL_MARKET_PRICES,
        remote = Remotes.MarketUpgradeRequest,
    },
    {
        key = "tip",
        name = "Tip Chance",
        default = 0,
        max = Economy.TIP_CHANCE_MAX_LEVEL,
        prices = Economy.TIP_CHANCE_PRICES,
        remote = Remotes.TipChanceUpgradeRequest,
    },
    {
        key = "npc",
        name = "NPC Speed",
        default = 0,
        max = Economy.NPC_SPEED_MAX_LEVEL,
        prices = Economy.NPC_SPEED_PRICES,
        remote = Remotes.NpcSpeedUpgradeRequest,
    },
}

local UPGRADE_BY_NAME = {}
local UPGRADE_NAMES = {}
for _, entry in ipairs(UPGRADE_KINDS) do
    UPGRADE_NAMES[#UPGRADE_NAMES + 1] = entry.name
    UPGRADE_BY_NAME[entry.name] = entry
end

local SEED_NAMES = {}
local SEED_NAME_TO_ID = {}
for _, entry in ipairs(ShopCatalog) do
    if not entry.packOnly and (entry.price or 0) > 0 then
        local name = ("%s ($%s)"):format(entry.seedDisplay, Format.commas(entry.price))
        SEED_NAMES[#SEED_NAMES + 1] = name
        SEED_NAME_TO_ID[name] = entry.itemId
    end
end

local ITEM_NAMES = {}
local ITEM_NAME_TO_ID = {}
for _, entry in ipairs(ItemShopCatalog) do
    local name = ("%s ($%s)"):format(entry.displayName, Format.commas(entry.price))
    ITEM_NAMES[#ITEM_NAMES + 1] = name
    ITEM_NAME_TO_ID[name] = entry.itemId
end

local COW_NAMES = {}
local COW_NAME_TO_ID = {}
local COW_ITEM_IDS = {}
for _, entry in ipairs(CowCatalog) do
    local name = ("%s ($%s)"):format(entry.displayName, Format.commas(entry.price))
    COW_NAMES[#COW_NAMES + 1] = name
    COW_NAME_TO_ID[name] = entry.itemId
    COW_ITEM_IDS[entry.itemId] = true
end

local MILK_NAMES = {}
local MILK_NAME_TO_ID = {}
local MILK_SET = {}
for id, info in pairs(ItemTypes) do
    if type(info) == "table" and string.sub(id, 1, 4) == "milk" and SellCatalog.IsSellable(id) then
        local name = info.displayName or id
        MILK_NAMES[#MILK_NAMES + 1] = name
        MILK_NAME_TO_ID[name] = id
        MILK_SET[id] = true
    end
end
table.sort(MILK_NAMES)

local PRICE_BY_ID = {}
for _, entry in ipairs(ShopCatalog) do
    PRICE_BY_ID[entry.itemId] = entry.price
end
for _, entry in ipairs(ItemShopCatalog) do
    PRICE_BY_ID[entry.itemId] = entry.price
end
for _, entry in ipairs(CowCatalog) do
    PRICE_BY_ID[entry.itemId] = entry.price
end

local wantedSeeds = {}
local wantedItems = {}
local wantedCows = {}
local wantedMilk = {}
local wantedUpgrades = {}

local function getPrice(entry, level)
    return entry.prices[level]
end

local function getLevel(entry, areaIndex)
    local value = levels[entry.key][areaIndex]
    if value == nil then
        return entry.default
    end
    return value
end

local function getAreaIndex()
    return MyLandState.GetAreaIndex()
end

local function getArea()
    local index = getAreaIndex()
    if not index then
        return nil
    end
    local areas = workspace:FindFirstChild("Area")
    if not areas then
        return nil
    end
    return areas:FindFirstChild(tostring(index))
end

local function getCharacter()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil
    end
    return root
end

local function getInventory()
    local data = InventoryUI.GetLast()
    if type(data) ~= "table" or type(data.items) ~= "table" then
        return nil
    end
    return data.items
end

local function canAfford(price, reserve)
    if not price then
        return false
    end
    if money == nil then
        return true
    end
    return money - price >= (reserve or 0)
end

local function stockOf(stock, id)
    if type(stock) ~= "table" then
        return nil
    end
    return stock[id]
end

local function doBuyList(wanted, buyAll, catalogNames, nameToId, stock, remote, reserveOption, notifyToggle, delayOption)
    local reserve = tonumber(opt(reserveOption)) or 0
    for _, name in ipairs(catalogNames) do
        if Library.Unloaded then
            return
        end
        local id = nameToId[name]
        if id and (buyAll or wanted[id]) then
            local available = stockOf(stock, id)
            if (available == nil or available > 0) and canAfford(PRICE_BY_ID[id], reserve) then
                remote:FireServer(id, "money")
                if on(notifyToggle) then
                    Library:Notify(("Bought %s"):format(name))
                end
                task.wait(opt(delayOption) or 0.2)
            end
        end
    end
end

local function doBuySeeds()
    doBuyList(
        wantedSeeds,
        on("BuyAllSeeds"),
        SEED_NAMES,
        SEED_NAME_TO_ID,
        seedStock,
        Remotes.BuyRequest,
        "SeedReserve",
        "SeedNotify",
        "SeedActionDelay"
    )
end

local function doBuyItems()
    doBuyList(
        wantedItems,
        on("BuyAllItems"),
        ITEM_NAMES,
        ITEM_NAME_TO_ID,
        itemStock,
        Remotes.BuyItemRequest,
        "ItemReserve",
        "ItemNotify",
        "ItemActionDelay"
    )
end

local function doBuyCows()
    doBuyList(
        wantedCows,
        on("BuyAllCows"),
        COW_NAMES,
        COW_NAME_TO_ID,
        cowStock,
        Remotes.BuyCowRequest,
        "CowReserve",
        "CowNotify",
        "CowActionDelay"
    )
end

local function doBuyUpgrades()
    local areaIndex = getAreaIndex()
    if not areaIndex then
        return
    end
    local reserve = tonumber(opt("UpgradeReserve")) or 0
    for _, entry in ipairs(UPGRADE_KINDS) do
        if Library.Unloaded then
            return
        end
        if on("UpgradeAll") or wantedUpgrades[entry.key] then
            local level = getLevel(entry, areaIndex)
            if level < entry.max then
                local price = getPrice(entry, level + 1)
                if canAfford(price, reserve) then
                    entry.remote:FireServer(areaIndex)
                    if on("UpgradeNotify") then
                        Library:Notify(("Upgrading %s"):format(entry.name))
                    end
                    task.wait(opt("UpgradeActionDelay", 0.4))
                end
            end
        end
    end
end

local homeCFrame = nil

local function rememberHome()
    if homeCFrame then
        return
    end
    local root = getCharacter()
    if root then
        homeCFrame = root.CFrame
    end
end

local function goHome()
    if not homeCFrame then
        return
    end
    local root = getCharacter()
    if root then
        root.CFrame = homeCFrame
    end
end

local function moveTo(part)
    local root = getCharacter()
    if not root or not part then
        return false
    end
    rememberHome()
    root.CFrame = CFrame.new(part.Position + Vector3.new(0, 4, 0))
    task.wait(opt("MoveSettle", 0.5))
    return true
end

local function firePrompt(prompt)
    if not prompt or not prompt.Enabled then
        return false
    end
    local part = prompt.Parent
    if not part or not part:IsA("BasePart") then
        return false
    end
    if not moveTo(part) then
        return false
    end
    fireproximityprompt(prompt)
    task.wait(0.25)
    return true
end

local function getOwnedCows()
    local list = {}
    for _, model in CollectionService:GetTagged("Placed") do
        if model:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            local placedId = model:GetAttribute("PlacedItemId")
            if placedId and COW_ITEM_IDS[placedId] then
                list[#list + 1] = model
            end
        end
    end
    return list
end

local function cowMilkPrompt(model)
    local part = model:FindFirstChild("Cow")
    local prompt = part and part:FindFirstChild("MilkPrompt")
    if prompt and prompt.Enabled then
        return prompt, part
    end
    return nil, nil
end

local function nextReadyCow()
    local minLiters = opt("MilkMinLiters", 1)
    for _, model in ipairs(getOwnedCows()) do
        if not model:GetAttribute("IsBeingMilked") and (model:GetAttribute("StoredLiters") or 0) >= minLiters then
            if cowMilkPrompt(model) then
                return model
            end
        end
    end
    return nil
end

local function getMoneyPrompt()
    local area = getArea()
    local front = area and area:FindFirstChild("Front")
    if not front then
        return nil
    end
    return front:FindFirstChild("CollectMoney", true)
end

local function getSellSpot()
    local area = getArea()
    local front = area and area:FindFirstChild("Front")
    return front and front:FindFirstChild("SELLHERE")
end

local function pickMilk()
    local items = getInventory()
    if not items then
        return nil
    end
    local all = on("SellAllMilk")
    local best, bestCount = nil, 0
    for _, entry in pairs(items) do
        local id = entry.id
        local allowed = id and (all and MILK_SET[id] or wantedMilk[id])
        if allowed then
            local count = entry.count or 0
            if count > bestCount then
                best, bestCount = id, count
            end
        end
    end
    return best
end

local function standAt(part)
    local root = getCharacter()
    if not root or not part then
        return false
    end
    rememberHome()
    root.CFrame = CFrame.new(part.Position + Vector3.new(0, 4, 0))
    return true
end

local function dropHeldMilk()
    local held = SelectionState.Get()
    if held and MILK_SET[held] then
        SelectionState.Set(nil)
    end
end

local function doSellMilk()
    local part = getSellSpot()
    if not part then
        return false
    end
    local id = pickMilk()
    if not id then
        dropHeldMilk()
        return false
    end
    if SelectionState.Get() ~= id then
        SelectionState.Set(id)
    end
    return standAt(part)
end

local milkTarget = nil
local milkDeadline = 0
local sellUntil = 0

local function startMilking(model)
    local prompt, part = cowMilkPrompt(model)
    if not prompt or not moveTo(part) then
        return false
    end
    dropHeldMilk()
    fireproximityprompt(prompt)
    milkTarget = model
    milkDeadline = os.clock() + MILK_TIMEOUT
    return true
end

local function milkingActive()
    if not milkTarget then
        return false
    end
    if not on("AutoMilkCows") or not milkTarget.Parent or os.clock() > milkDeadline then
        milkTarget = nil
        return false
    end
    if os.clock() < milkDeadline - MILK_TIMEOUT + MILK_START_GRACE then
        return true
    end
    if not milkTarget:GetAttribute("IsBeingMilked") then
        milkTarget = nil
        return false
    end
    return true
end

local function runFarmLoop()
    if milkingActive() then
        local _, part = cowMilkPrompt(milkTarget)
        standAt(part or milkTarget:FindFirstChild("Cow"))
        return
    end

    if on("AutoCollectMoney") then
        local prompt = getMoneyPrompt()
        if prompt and prompt.Enabled then
            firePrompt(prompt)
            return
        end
    end

    if on("AutoSellMilk") and os.clock() < sellUntil then
        if doSellMilk() then
            return
        end
        sellUntil = 0
    end

    if on("AutoMilkCows") then
        local cow = nextReadyCow()
        if cow and startMilking(cow) then
            return
        end
    end

    if on("AutoSellMilk") and doSellMilk() then
        sellUntil = os.clock() + (opt("SellDwell", 5))
        return
    end

    if on("ReturnHome") then
        goHome()
    end
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
    Size = UDim2.fromOffset(900, 640),
    ShowCustomCursor = false,
    CornerRadius = 10,
})

Library.ShowCustomCursor = false

local Tabs = {
    Info = Window:AddTab("Info", "info"),
    Farm = Window:AddTab("Farm", "tractor"),
    Shop = Window:AddTab("Shop", "shopping-cart"),
    Upgrades = Window:AddTab("Upgrades", "trending-up"),
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

FeaturesGroup:AddLabel(colored("Auto Farm", BLUE), true)
FeaturesGroup:AddLabel(colored("Auto Sell", ORANGE), true)
FeaturesGroup:AddLabel(colored("Auto Buy", GREEN), true)
FeaturesGroup:AddLabel(colored("Auto Upgrade", GREY), true)

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

local FarmGroup = Tabs.Farm:AddLeftGroupbox("Cows", "beef")

FarmGroup:AddToggle("AutoMilkCows", {
    Text = "Auto Milk Cows",
    Default = false,
})

FarmGroup:AddSlider("MilkMinLiters", {
    Text = "Minimum Liters",
    Default = 1,
    Min = 1,
    Max = 50,
    Rounding = 0,
})

FarmGroup:AddToggle("AutoCollectMoney", {
    Text = "Auto Collect Money",
    Default = false,
})

local SellGroup = Tabs.Farm:AddRightGroupbox("Sell Table", "milk")

SellGroup:AddToggle("AutoSellMilk", {
    Text = "Auto Place Milk In Table",
    Default = false,
})

SellGroup:AddToggle("SellAllMilk", {
    Text = "All Milk Types",
    Default = true,
})

SellGroup:AddSlider("SellDwell", {
    Text = "Time At Table",
    Default = 5,
    Min = 1,
    Max = 60,
    Rounding = 1,
})

SellGroup:AddDropdown("SellMilkTypes", {
    Text = "Milk To Place",
    Values = MILK_NAMES,
    Default = {},
    Multi = true,
    Callback = function(value)
        local set = {}
        for name, state in value do
            if state then
                local id = MILK_NAME_TO_ID[name]
                if id then
                    set[id] = true
                end
            end
        end
        wantedMilk = set
    end,
})

local MoveGroup = Tabs.Farm:AddLeftGroupbox("Movement", "move")

MoveGroup:AddToggle("ReturnHome", {
    Text = "Return To Start Position",
    Default = true,
})

MoveGroup:AddSlider("MoveSettle", {
    Text = "Teleport Settle",
    Default = 0.5,
    Min = 0.1,
    Max = 3,
    Rounding = 2,
})

MoveGroup:AddButton({
    Text = "Set Start Position Here",
    Func = function()
        local root = getCharacter()
        if root then
            homeCFrame = root.CFrame
            Library:Notify("Start position saved")
        end
    end,
})

MoveGroup:AddSlider("FarmTickDelay", {
    Text = "Loop Delay",
    Default = 0.5,
    Min = 0.1,
    Max = 5,
    Rounding = 2,
})

local SeedGroup = Tabs.Shop:AddLeftGroupbox("Auto Buy Seeds", "sprout")

SeedGroup:AddToggle("AutoBuySeeds", {
    Text = "Auto Buy Seeds",
    Default = false,
})

SeedGroup:AddToggle("BuyAllSeeds", {
    Text = "Buy All Seeds",
    Default = false,
})

SeedGroup:AddDropdown("BuySeeds", {
    Text = "Seeds To Buy",
    Values = SEED_NAMES,
    Default = {},
    Multi = true,
    Callback = function(value)
        local set = {}
        for name, state in value do
            if state then
                local id = SEED_NAME_TO_ID[name]
                if id then
                    set[id] = true
                end
            end
        end
        wantedSeeds = set
    end,
})

SeedGroup:AddInput("SeedReserve", {
    Text = "Keep Money Reserve",
    Default = "0",
    Numeric = true,
    Finished = false,
    ClearTextOnFocus = false,
})

SeedGroup:AddToggle("SeedNotify", {
    Text = "Notify On Buy",
    Default = false,
})

SeedGroup:AddSlider("SeedActionDelay", {
    Text = "Buy Delay",
    Default = 0.2,
    Min = 0.1,
    Max = 2,
    Rounding = 2,
})

SeedGroup:AddSlider("SeedLoopDelay", {
    Text = "Loop Delay",
    Default = 2,
    Min = 0.5,
    Max = 30,
    Rounding = 1,
})

local ItemGroup = Tabs.Shop:AddRightGroupbox("Auto Buy Items", "package-open")

ItemGroup:AddToggle("AutoBuyItems", {
    Text = "Auto Buy Items",
    Default = false,
})

ItemGroup:AddToggle("BuyAllItems", {
    Text = "Buy All Items",
    Default = false,
})

ItemGroup:AddDropdown("BuyItems", {
    Text = "Items To Buy",
    Values = ITEM_NAMES,
    Default = {},
    Multi = true,
    Callback = function(value)
        local set = {}
        for name, state in value do
            if state then
                local id = ITEM_NAME_TO_ID[name]
                if id then
                    set[id] = true
                end
            end
        end
        wantedItems = set
    end,
})

ItemGroup:AddInput("ItemReserve", {
    Text = "Keep Money Reserve",
    Default = "0",
    Numeric = true,
    Finished = false,
    ClearTextOnFocus = false,
})

ItemGroup:AddToggle("ItemNotify", {
    Text = "Notify On Buy",
    Default = false,
})

ItemGroup:AddSlider("ItemActionDelay", {
    Text = "Buy Delay",
    Default = 0.2,
    Min = 0.1,
    Max = 2,
    Rounding = 2,
})

ItemGroup:AddSlider("ItemLoopDelay", {
    Text = "Loop Delay",
    Default = 2,
    Min = 0.5,
    Max = 30,
    Rounding = 1,
})

local CowGroup = Tabs.Shop:AddLeftGroupbox("Auto Buy Cows", "beef")

CowGroup:AddToggle("AutoBuyCows", {
    Text = "Auto Buy Cows",
    Default = false,
})

CowGroup:AddToggle("BuyAllCows", {
    Text = "Buy All Cows",
    Default = false,
})

CowGroup:AddDropdown("BuyCows", {
    Text = "Cows To Buy",
    Values = COW_NAMES,
    Default = {},
    Multi = true,
    Callback = function(value)
        local set = {}
        for name, state in value do
            if state then
                local id = COW_NAME_TO_ID[name]
                if id then
                    set[id] = true
                end
            end
        end
        wantedCows = set
    end,
})

CowGroup:AddInput("CowReserve", {
    Text = "Keep Money Reserve",
    Default = "0",
    Numeric = true,
    Finished = false,
    ClearTextOnFocus = false,
})

CowGroup:AddToggle("CowNotify", {
    Text = "Notify On Buy",
    Default = false,
})

CowGroup:AddSlider("CowActionDelay", {
    Text = "Buy Delay",
    Default = 0.2,
    Min = 0.1,
    Max = 2,
    Rounding = 2,
})

CowGroup:AddSlider("CowLoopDelay", {
    Text = "Loop Delay",
    Default = 2,
    Min = 0.5,
    Max = 30,
    Rounding = 1,
})

local UpgradeGroup = Tabs.Upgrades:AddLeftGroupbox("Auto Buy Upgrades", "hammer")

UpgradeGroup:AddToggle("AutoBuyUpgrades", {
    Text = "Auto Buy Farm Upgrades",
    Default = false,
})

UpgradeGroup:AddToggle("UpgradeAll", {
    Text = "Buy All Upgrades",
    Default = false,
})

UpgradeGroup:AddDropdown("Upgrades", {
    Text = "Upgrades To Buy",
    Values = UPGRADE_NAMES,
    Default = {},
    Multi = true,
    Callback = function(value)
        local set = {}
        for name, state in value do
            if state then
                local entry = UPGRADE_BY_NAME[name]
                if entry then
                    set[entry.key] = true
                end
            end
        end
        wantedUpgrades = set
    end,
})

UpgradeGroup:AddInput("UpgradeReserve", {
    Text = "Keep Money Reserve",
    Default = "0",
    Numeric = true,
    Finished = false,
    ClearTextOnFocus = false,
})

UpgradeGroup:AddToggle("UpgradeNotify", {
    Text = "Notify On Upgrade",
    Default = false,
})

UpgradeGroup:AddSlider("UpgradeActionDelay", {
    Text = "Upgrade Delay",
    Default = 0.4,
    Min = 0.1,
    Max = 3,
    Rounding = 2,
})

UpgradeGroup:AddSlider("UpgradeLoopDelay", {
    Text = "Loop Delay",
    Default = 3,
    Min = 0.5,
    Max = 60,
    Rounding = 1,
})

local StatusGroup = Tabs.Upgrades:AddRightGroupbox("Status", "activity")

local MoneyLabel = StatusGroup:AddLabel(field("Money", "?", GREEN), true)
local AreaLabel = StatusGroup:AddLabel(field("Farm", "?", BLUE), true)
local LevelLabels = {}
for _, entry in ipairs(UPGRADE_KINDS) do
    LevelLabels[entry.key] = StatusGroup:AddLabel(field(entry.name, "?", ORANGE), true)
end

local function refreshStatus()
    MoneyLabel:SetText(field("Money", money and ("$" .. Format.commas(money)) or "?", GREEN))
    local areaIndex = getAreaIndex()
    AreaLabel:SetText(field("Farm", areaIndex and tostring(areaIndex) or "?", BLUE))
    for _, entry in ipairs(UPGRADE_KINDS) do
        local text = "?"
        if areaIndex then
            local level = getLevel(entry, areaIndex)
            text = ("%d / %d"):format(level, entry.max)
        end
        LevelLabels[entry.key]:SetText(field(entry.name, text, ORANGE))
    end
end

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

local connections = {}

connections[#connections + 1] = Remotes.MoneyUpdate.OnClientEvent:Connect(function(value)
    if typeof(value) == "number" then
        money = value
    end
end)

connections[#connections + 1] = Remotes.ShopState.OnClientEvent:Connect(function(state)
    if typeof(state) == "table" then
        seedStock = state.stock or {}
    end
end)

connections[#connections + 1] = Remotes.ItemShopState.OnClientEvent:Connect(function(state)
    if typeof(state) == "table" then
        itemStock = state.stock or {}
    end
end)

connections[#connections + 1] = Remotes.CowShopState.OnClientEvent:Connect(function(state)
    if typeof(state) == "table" then
        cowStock = state.stock or {}
    end
end)

connections[#connections + 1] = Remotes.LandAssigned.OnClientEvent:Connect(function(payload)
    if typeof(payload) == "table" and typeof(payload.areaIndex) == "number" and typeof(payload.lvl) == "number" then
        levels.expand[payload.areaIndex] = payload.lvl
    end
end)

connections[#connections + 1] = Remotes.LandLvlUpdate.OnClientEvent:Connect(function(areaIndex, lvl)
    if typeof(areaIndex) == "number" and typeof(lvl) == "number" then
        levels.expand[areaIndex] = lvl
    end
end)

connections[#connections + 1] = Remotes.MarketLvlUpdate.OnClientEvent:Connect(function(areaIndex, lvl)
    if typeof(areaIndex) == "number" and typeof(lvl) == "number" then
        levels.market[areaIndex] = lvl
    end
end)

connections[#connections + 1] = Remotes.TipChanceLvlUpdate.OnClientEvent:Connect(function(areaIndex, lvl)
    if typeof(areaIndex) == "number" and typeof(lvl) == "number" then
        levels.tip[areaIndex] = lvl
    end
end)

connections[#connections + 1] = Remotes.NpcSpeedLvlUpdate.OnClientEvent:Connect(function(areaIndex, lvl)
    if typeof(areaIndex) == "number" and typeof(lvl) == "number" then
        levels.npc[areaIndex] = lvl
    end
end)

pcall(function()
    Remotes.RequestLandSync:FireServer()
end)

Library:OnUnload(function()
    antiAfkBeganConnection:Disconnect()
    antiAfkChangedConnection:Disconnect()
    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    print("My Moo Farm unloaded")
end)

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("OuroborosHub")
ThemeManager:SaveDefault("Monochrome")

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("OuroborosHub/MyMooFarm")
SaveManager:BuildConfigSection(Tabs.Settings)

ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()

SaveManager:LoadAutoloadConfig()

task.spawn(function()
    while not Library.Unloaded do
        if on("AutoMilkCows") or on("AutoCollectMoney") or on("AutoSellMilk") then
            pcall(runFarmLoop)
        elseif homeCFrame and on("ReturnHome") then
            pcall(goHome)
            homeCFrame = nil
        end
        task.wait(opt("FarmTickDelay", 0.5))
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if on("AutoBuySeeds") then
            pcall(doBuySeeds)
        end
        task.wait(opt("SeedLoopDelay", 2))
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if on("AutoBuyItems") then
            pcall(doBuyItems)
        end
        task.wait(opt("ItemLoopDelay", 2))
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if on("AutoBuyCows") then
            pcall(doBuyCows)
        end
        task.wait(opt("CowLoopDelay", 2))
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if on("AutoBuyUpgrades") then
            pcall(doBuyUpgrades)
        end
        task.wait(opt("UpgradeLoopDelay", 3))
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        pcall(refreshStatus)
        task.wait(1)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        task.wait(2)
        if on("AntiAfk") then
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

Library:Notify("My Moo Farm loaded")
