local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

if getgenv then
    getgenv().gethui = function()
        return LocalPlayer:WaitForChild("PlayerGui")
    end
end

local Misc = ReplicatedStorage:WaitForChild("BrainrotsThings"):WaitForChild("Misc")
local Events = Misc:WaitForChild("Events")
local PlayerEvents = Events:WaitForChild("Player")
local TableEvents = Events:WaitForChild("Tables")

local QuickJoin = PlayerEvents:WaitForChild("QuickJoin")
local RequestInventory = PlayerEvents:WaitForChild("RequestInventory")
local InventoryUpdated = PlayerEvents:WaitForChild("InventoryUpdated")
local CollectCash = PlayerEvents:WaitForChild("CollectCash")
local ClaimOfflineEarnings = PlayerEvents:WaitForChild("ClaimOfflineEarnings")
local EquipBestBrainrots = PlayerEvents:WaitForChild("EquipBestBrainrots")
local ToggleFavourite = PlayerEvents:WaitForChild("ToggleFavourite")
local SellAll = PlayerEvents:WaitForChild("SellAll")
local RebirthRequest = PlayerEvents:WaitForChild("RebirthRequest")
local PurchaseLuckUpgrade = PlayerEvents:WaitForChild("PurchaseLuckUpgrade")
local RequestIndex = PlayerEvents:WaitForChild("RequestIndex")

local AuctionStarted = TableEvents:WaitForChild("AuctionStarted")
local AuctionEnded = TableEvents:WaitForChild("AuctionEnded")
local AuctionCancelled = TableEvents:WaitForChild("AuctionCancelled")
local AuctionPrompt = TableEvents:WaitForChild("AuctionPrompt")
local BidSubmitted = TableEvents:WaitForChild("BidSubmitted")
local BidRejected = TableEvents:WaitForChild("BidRejected")
local PlayWithAIRequest = TableEvents:WaitForChild("PlayWithAIRequest")
local TableOptionRequest = TableEvents:WaitForChild("TableOptionRequest")
local GetTableOptionConfig = TableEvents:WaitForChild("GetTableOptionConfig")

local SpinWheelRemotes = ReplicatedStorage:WaitForChild("SpinWheelRemotes")
local SpinRequest = SpinWheelRemotes:WaitForChild("SpinRequest")
local SpinResult = SpinWheelRemotes:WaitForChild("SpinResult")
local RewardedAdSpinRequest = SpinWheelRemotes:WaitForChild("RewardedAdSpinRequest")

local GAME_NAME = "Bid for Anime!"
local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

pcall(function()
    Library.ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end)

local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Toggles = Library.Toggles
local Options = Library.Options

local function copyDiscord()
    if setclipboard then
        setclipboard(DISCORD_INVITE)
    elseif toclipboard then
        toclipboard(DISCORD_INVITE)
    end
    Library:Notify("Copied Discord invite to clipboard")
end

local RARITIES = {
    "Common",
    "Uncommon",
    "Rare",
    "Epic",
    "Legendary",
    "Mythic",
    "Cosmic",
    "Secret",
    "Celestial",
    "Divine",
    "Anime God",
}

local SELLABLE_RARITIES = {
    "Common",
    "Uncommon",
    "Rare",
    "Epic",
    "Legendary",
    "Mythic",
    "Cosmic",
    "Secret",
    "Celestial",
}

local VARIANTS = {
    "Normal",
    "Golden",
    "Diamond",
    "Galaxy",
    "Lava",
    "Volcanic",
    "Rainbow",
    "Hacked",
    "Void",
}

local BID_TIERS = { "Small", "Medium", "High", "Extreme" }
local TABLE_OPTIONS = { "GuaranteedSecret", "GuaranteedDivine", "LuckyBlock" }

local inventory = {}
local favourites = {}
local activeAuction = nil
local activePrompt = nil
local lastPromptId = nil
local spinning = false

InventoryUpdated.OnClientEvent:Connect(function(items, _, favourited)
    inventory = type(items) == "table" and items or {}
    favourites = type(favourited) == "table" and favourited or {}
end)

AuctionStarted.OnClientEvent:Connect(function(payload)
    activeAuction = payload
end)

local function clearAuction()
    activeAuction = nil
    activePrompt = nil
end

AuctionEnded.OnClientEvent:Connect(clearAuction)
AuctionCancelled.OnClientEvent:Connect(clearAuction)

SpinResult.OnClientEvent:Connect(function()
    spinning = false
end)

RequestInventory:FireServer()

local function isOn(name)
    local toggle = Toggles[name]
    return toggle ~= nil and toggle.Value == true
end

local function getNumber(name, fallback)
    local option = Options[name]
    return option and tonumber(option.Value) or fallback
end

local function getSelected(name)
    local option = Options[name]
    local value = option and option.Value
    return type(value) == "table" and value or {}
end

local function getMoney()
    local stats = LocalPlayer:FindFirstChild("leaderstats")
    local money = stats and stats:FindFirstChild("Money")
    return money and money.Value or 0
end

local function isFavourited(id)
    for _, favourite in favourites do
        if favourite == id then
            return true
        end
    end
    return false
end

local function isCheapAuction(prompt)
    local floor = getNumber("PassUnder", 0)
    if floor <= 0 then
        return false
    end

    local options = type(prompt.options) == "table" and prompt.options or {}
    local lowest = nil

    for _, option in options do
        local amount = tonumber(option and option.amount)
        if amount and (not lowest or amount < lowest) then
            lowest = amount
        end
    end

    return lowest ~= nil and lowest < floor
end

local function pickBidIndex(prompt)
    local cap = getNumber("MaxBid", 0)
    local strategy = Options.BidStrategy and Options.BidStrategy.Value or "Highest Affordable"
    local options = type(prompt.options) == "table" and prompt.options or {}

    local function usable(index)
        local option = options[index]
        if not option or option.canAfford ~= true then
            return false
        end
        local amount = tonumber(option.amount) or 0
        return cap <= 0 or amount <= cap
    end

    for tier, name in BID_TIERS do
        if strategy == name then
            return usable(tier) and tier or nil
        end
    end

    if strategy == "Lowest" then
        for index = 1, #BID_TIERS do
            if usable(index) then
                return index
            end
        end
        return nil
    end

    for index = #BID_TIERS, 1, -1 do
        if usable(index) then
            return index
        end
    end
    return nil
end

local function respondToPrompt(prompt)
    local index = not (isOn("AutoPassCheap") and isCheapAuction(prompt)) and pickBidIndex(prompt) or nil

    if index then
        local option = prompt.options[index]
        BidSubmitted:FireServer({
            action = "bid",
            auctionId = prompt.auctionId,
            promptId = prompt.promptId,
            amount = option.amount,
        })
        return
    end

    if prompt.canPass == true then
        BidSubmitted:FireServer({
            action = "pass",
            auctionId = prompt.auctionId,
            promptId = prompt.promptId,
        })
    end
end

AuctionPrompt.OnClientEvent:Connect(function(prompt)
    if type(prompt) ~= "table" then
        return
    end

    activePrompt = prompt

    if not prompt.active or Library.Unloaded or not isOn("AutoBid") then
        return
    end

    lastPromptId = prompt.promptId

    task.delay(getNumber("BidDelay", 0.5), function()
        if Library.Unloaded or not isOn("AutoBid") or activePrompt ~= prompt then
            return
        end
        respondToPrompt(prompt)
    end)
end)

BidRejected.OnClientEvent:Connect(function(payload)
    if not isOn("AutoBid") or type(activePrompt) ~= "table" or not activePrompt.active then
        return
    end

    if type(payload) == "table" and payload.promptId and payload.promptId ~= lastPromptId then
        return
    end

    if activePrompt.canPass == true then
        BidSubmitted:FireServer({
            action = "pass",
            auctionId = activePrompt.auctionId,
            promptId = activePrompt.promptId,
        })
    end
end)

local Window = Library:CreateWindow({
    Title = "Ouroboros Hub",
    Footer = DISCORD_INVITE .. " | " .. GAME_NAME,
    Icon = 18657887261,
    NotifySide = "Right",
    ShowCustomCursor = false,
})

local Tabs = {
    Info = Window:AddTab("Info", "info"),
    Auction = Window:AddTab("Auction", "gavel"),
    Luck = Window:AddTab("Luck", "clover"),
    Economy = Window:AddTab("Economy", "coins"),
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

AddDiscordButton(Tabs.Info)
AddDiscordButton(Tabs.Auction)
AddDiscordButton(Tabs.Luck)
AddDiscordButton(Tabs.Economy)
AddDiscordButton(Tabs.Settings)

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

local JoinGroup = Tabs.Auction:AddLeftGroupbox("Auto Join", "door-open")

JoinGroup:AddToggle("AutoJoin", {
    Text = "Auto Join Auction",
    Default = false,
})

JoinGroup:AddToggle("AutoPlayAI", {
    Text = "Duel AI When Empty",
    Default = false,
})

JoinGroup:AddSlider("JoinDelay", {
    Text = "Join Delay",
    Default = 3,
    Min = 1,
    Max = 20,
    Rounding = 1,
})

local BidGroup = Tabs.Auction:AddRightGroupbox("Auto Bid", "gavel")

BidGroup:AddToggle("AutoBid", {
    Text = "Auto Bid",
    Default = false,
})

BidGroup:AddDropdown("BidStrategy", {
    Values = { "Highest Affordable", "Lowest", "Small", "Medium", "High", "Extreme" },
    Default = "Highest Affordable",
    Text = "Bid Strategy",
})

BidGroup:AddInput("MaxBid", {
    Text = "Max Bid",
    Default = "0",
    Numeric = true,
    Finished = true,
})

BidGroup:AddToggle("AutoPassCheap", {
    Text = "Auto Pass Cheap Animes",
    Default = false,
})

BidGroup:AddInput("PassUnder", {
    Text = "Pass Under",
    Default = "0",
    Numeric = true,
    Finished = true,
})

BidGroup:AddSlider("BidDelay", {
    Text = "Bid Delay",
    Default = 0.5,
    Min = 0,
    Max = 8,
    Rounding = 1,
})

local SpinGroup = Tabs.Luck:AddLeftGroupbox("Spin Wheel", "disc-3")

SpinGroup:AddToggle("AutoSpin", {
    Text = "Auto Spin",
    Default = false,
})

SpinGroup:AddSlider("SpinDelay", {
    Text = "Spin Delay",
    Default = 8,
    Min = 3,
    Max = 30,
    Rounding = 1,
})

SpinGroup:AddButton({
    Text = "Use Rewarded Ad Spin",
    Func = function()
        if (LocalPlayer:GetAttribute("RewardedAdSpinsRemaining") or 0) <= 0 then
            Library:Notify("No rewarded ad spins left today")
            return
        end
        RewardedAdSpinRequest:FireServer()
    end,
})

local LuckGroup = Tabs.Luck:AddRightGroupbox("Luck Upgrades", "trending-up")

LuckGroup:AddToggle("AutoLuck", {
    Text = "Auto Buy Luck",
    Default = false,
})

LuckGroup:AddDropdown("LuckAmount", {
    Values = { "10", "50", "100" },
    Default = "100",
    Text = "Luck Per Purchase",
})

LuckGroup:AddInput("LuckReserve", {
    Text = "Keep Money Reserve",
    Default = "0",
    Numeric = true,
    Finished = true,
})

LuckGroup:AddSlider("LuckDelay", {
    Text = "Loop Delay",
    Default = 2,
    Min = 0.5,
    Max = 30,
    Rounding = 1,
})

local BlockGroup = Tabs.Luck:AddLeftGroupbox("Lucky Blocks", "package-open")

BlockGroup:AddToggle("AutoTableOption", {
    Text = "Auto Use Tokens",
    Default = false,
})

BlockGroup:AddDropdown("TableOption", {
    Values = TABLE_OPTIONS,
    Default = "GuaranteedSecret",
    Text = "Token Type",
})

local CashGroup = Tabs.Economy:AddLeftGroupbox("Cash", "hand-coins")

CashGroup:AddToggle("AutoCollect", {
    Text = "Auto Collect Cash",
    Default = false,
})

CashGroup:AddToggle("AutoEquipBest", {
    Text = "Auto Equip Best",
    Default = false,
})

CashGroup:AddToggle("AutoRebirth", {
    Text = "Auto Rebirth",
    Default = false,
})

CashGroup:AddSlider("CashDelay", {
    Text = "Loop Delay",
    Default = 2,
    Min = 0.5,
    Max = 30,
    Rounding = 1,
})

CashGroup:AddButton({
    Text = "Claim Offline Earnings",
    Func = function()
        ClaimOfflineEarnings:FireServer()
    end,
})

local CollectionGroup = Tabs.Economy:AddRightGroupbox("Collection", "star")

CollectionGroup:AddToggle("AutoFavourite", {
    Text = "Auto Favorite",
    Default = false,
})

CollectionGroup:AddDropdown("FavouriteRarities", {
    Values = RARITIES,
    Default = {},
    Multi = true,
    Text = "Favorite Rarities",
})

CollectionGroup:AddDropdown("FavouriteVariants", {
    Values = VARIANTS,
    Default = {},
    Multi = true,
    Text = "Favorite Variants",
})

local SellGroup = Tabs.Economy:AddRightGroupbox("Auto Sell", "banknote")

SellGroup:AddToggle("AutoSell", {
    Text = "Auto Sell",
    Default = false,
})

SellGroup:AddDropdown("SellRarities", {
    Values = SELLABLE_RARITIES,
    Default = {},
    Multi = true,
    Text = "Sell Rarities",
})

SellGroup:AddSlider("SellDelay", {
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
    print("Bid for Anime unloaded")
end)

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("OuroborosHub")
ThemeManager:SaveDefault("Mint")

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("OuroborosHub/BidForAnime")
SaveManager:BuildConfigSection(Tabs.Settings)

ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()

SaveManager:LoadAutoloadConfig()

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

task.spawn(function()
    while not Library.Unloaded do
        if isOn("AutoJoin") and not activeAuction and LocalPlayer:GetAttribute("ClientInDuel") ~= true then
            QuickJoin:FireServer()

            if isOn("AutoPlayAI") then
                task.wait(getNumber("JoinDelay", 3))
                if isOn("AutoJoin") and isOn("AutoPlayAI") and not activeAuction then
                    PlayWithAIRequest:FireServer()
                end
            end
        end
        task.wait(getNumber("JoinDelay", 3))
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if isOn("AutoTableOption") and not activeAuction then
            local ok, config = pcall(function()
                return GetTableOptionConfig:InvokeServer()
            end)

            if ok and type(config) == "table" then
                local key = Options.TableOption and Options.TableOption.Value
                local entry = key and config[key]
                if entry and (tonumber(entry.tokenCount) or 0) > 0 and config._activeKey ~= key then
                    TableOptionRequest:FireServer(key)
                end
            end
        end
        task.wait(5)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if isOn("AutoSpin") and not spinning and (LocalPlayer:GetAttribute("SpinRounds") or 0) > 0 then
            spinning = true
            SpinRequest:FireServer()
            task.delay(getNumber("SpinDelay", 8) + 5, function()
                spinning = false
            end)
        end
        task.wait(getNumber("SpinDelay", 8))
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if isOn("AutoLuck") and getMoney() > getNumber("LuckReserve", 0) then
            PurchaseLuckUpgrade:FireServer(Options.LuckAmount and Options.LuckAmount.Value or "100")
        end
        task.wait(getNumber("LuckDelay", 2))
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if isOn("AutoCollect") then
            CollectCash:FireServer()
        end
        if isOn("AutoEquipBest") then
            EquipBestBrainrots:FireServer()
        end
        if isOn("AutoRebirth") then
            RebirthRequest:FireServer()
        end
        task.wait(getNumber("CashDelay", 2))
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if isOn("AutoFavourite") then
            local rarities = getSelected("FavouriteRarities")
            local variants = getSelected("FavouriteVariants")

            for _, item in inventory do
                if type(item) == "table" and item.id and not isFavourited(item.id) then
                    if rarities[item.rarity] or variants[item.variant] then
                        ToggleFavourite:FireServer(item.id)
                        task.wait(0.15)
                    end
                end
            end
        end
        task.wait(1)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if isOn("AutoSell") then
            local rarities = getSelected("SellRarities")
            for _, rarity in SELLABLE_RARITIES do
                if rarities[rarity] then
                    SellAll:FireServer(rarity)
                    task.wait(0.3)
                end
            end
        end
        task.wait(getNumber("SellDelay", 5))
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        RequestInventory:FireServer()
        RequestIndex:FireServer()
        task.wait(10)
    end
end)
