local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local Directories = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Directories")
local DataClient = require(ReplicatedStorage.Modules.Client.DataClient)
local UpgradeConfig = require(Directories.UpgradeConfig)
local StarShopConfig = require(Directories.StarShopConfig)
local WormholeConfig = require(Directories.WormholeConfig)

local GAME_NAME = "Merge a Black Hole"
local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"
local RSCRIPTS_LINK = "https://rscripts.net/@Ouroboros"

local HoleService = Knit.GetService("HoleService")
local ShieldService = Knit.GetService("ShieldService")
local RebirthService = Knit.GetService("RebirthService")
local UpgradeService = Knit.GetService("UpgradeService")
local StarShopService = Knit.GetService("StarShopService")
local WheelService = Knit.GetService("WheelService")
local SunService = Knit.GetService("SunService")
local RaidService = Knit.GetService("RaidService")
local WormholeService = Knit.GetService("WormholeService")
local QuestService = Knit.GetService("QuestService")

local MAX_TIER = 500

local UPGRADE_DISPLAY = {}
local UPGRADE_KEY = {}
for _, upgrade in ipairs(UpgradeConfig.GetAll()) do
    local display = upgrade.Name or upgrade.Key
    table.insert(UPGRADE_DISPLAY, display)
    UPGRADE_KEY[display] = upgrade.Key
end
table.sort(UPGRADE_DISPLAY)

local SHOP_DISPLAY = {}
local SHOP_KEY = {}
local SHOP_RARITIES = {}
do
    local seen = {}
    for _, item in ipairs(StarShopConfig.Catalog) do
        local display = item.Name or item.Key
        table.insert(SHOP_DISPLAY, display)
        SHOP_KEY[display] = item.Key
        if item.Rarity and not seen[item.Rarity] then
            seen[item.Rarity] = true
            table.insert(SHOP_RARITIES, item.Rarity)
        end
    end
    table.sort(SHOP_DISPLAY)
end

local function holesFolder()
    local map = Workspace:FindFirstChild("Map")
    return map and map:FindFirstChild("Holes")
end

local function ownedHoles()
    local holes = {}
    local folder = holesFolder()
    if not folder then
        return holes
    end
    for _, model in folder:GetChildren() do
        if model:GetAttribute("OwnerUserId") == LocalPlayer.UserId and model:GetAttribute("InFlight") ~= true then
            local id = model:GetAttribute("HoleId")
            local tier = model:GetAttribute("Tier")
            if id and tier then
                table.insert(holes, {
                    Id = id,
                    Tier = tier,
                    Position = (model:GetAttribute("BaseCF") or model:GetPivot()).Position,
                })
            end
        end
    end
    return holes
end

local function attackHoles(minTier, maxTier)
    local holes = {}
    for _, hole in ownedHoles() do
        if hole.Tier >= minTier and hole.Tier <= maxTier then
            table.insert(holes, hole)
        end
    end
    table.sort(holes, function(a, b)
        return a.Tier > b.Tier
    end)
    return holes
end

local function groupByTier(holes, minTier, maxTier)
    local buckets = {}
    for _, hole in holes do
        if hole.Tier >= minTier and hole.Tier <= maxTier then
            local bucket = buckets[hole.Tier]
            if not bucket then
                bucket = {}
                buckets[hole.Tier] = bucket
            end
            table.insert(bucket, hole)
        end
    end
    local tiers = {}
    for tier in pairs(buckets) do
        table.insert(tiers, tier)
    end
    table.sort(tiers)
    return buckets, tiers
end

local function upgradeLevel(key)
    local upgrades = DataClient.Get("Upgrades")
    if type(upgrades) ~= "table" then
        return 0
    end
    return tonumber(upgrades[key]) or 0
end

local function canAffordUpgrade(upgrade)
    local level = upgradeLevel(upgrade.Key)
    if not upgrade.Uncapped and upgrade.MaxLevel and level >= upgrade.MaxLevel then
        return false
    end
    local rebirths = tonumber(DataClient.Get("Rebirths")) or 0
    local cost = UpgradeConfig.CostForNextLevel(upgrade.Key, level, rebirths)
    local cash = tonumber(DataClient.Get("Cash")) or 0
    return cost ~= nil and cash >= cost
end

local function islandTargets(includePlayers, includeAi)
    local targets = {}
    local map = Workspace:FindFirstChild("Map")
    local islands = map and map:FindFirstChild("Islands")
    if not islands then
        return targets
    end
    for _, island in islands:GetChildren() do
        local index = tonumber(string.match(island.Name, "%d+"))
        local owner = island:GetAttribute("OwnerUserId")
        local isAi = island:GetAttribute("IsAI") == true
        if index and island:GetAttribute("Occupied") == true and owner ~= LocalPlayer.UserId then
            if (isAi and includeAi) or (not isAi and includePlayers) then
                table.insert(targets, index)
            end
        end
    end
    table.sort(targets)
    return targets
end

local function wormholeEntries(state)
    local entries = {}
    local raw = type(state) == "table" and state.Entries or nil
    if type(raw) ~= "table" then
        return entries
    end
    for key, entry in pairs(raw) do
        if type(entry) == "table" then
            local id = entry.Id or entry.Key or (type(key) == "string" and key or nil)
            local config = type(id) == "string" and WormholeConfig.Get(id)
            if config then
                table.insert(entries, {
                    Id = id,
                    Rank = tonumber(WormholeConfig.GetRarityRank(config.Rarity)) or 0,
                    Stars = math.max(1, math.floor(tonumber(entry.Stars) or 1)),
                    Level = math.max(0, math.floor(tonumber(entry.Level) or 0)),
                    Equipped = entry.Equipped == true,
                })
            end
        end
    end
    table.sort(entries, function(a, b)
        if a.Rank ~= b.Rank then
            return a.Rank > b.Rank
        end
        if a.Stars ~= b.Stars then
            return a.Stars > b.Stars
        end
        if a.Level ~= b.Level then
            return a.Level > b.Level
        end
        return a.Id < b.Id
    end)
    return entries
end

local repo = "https://raw.githubusercontent.com/joustingmatch/ObsidianUltra/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Toggles = Library.Toggles
local Options = Library.Options

local Window = Library:CreateWindow({
    Title = "Ouroboros Hub",
    Footer = {
        { Text = DISCORD_INVITE, Copyable = true },
        "|",
        GAME_NAME,
    },
    Icon = 18657887261,
    NotifySide = "Right",
    ShowCustomCursor = false,
    CornerRadius = 10,
})

local Tabs = {
    Info = Window:AddTab("Info", "info"),
    Main = Window:AddTab("Main", "gamepad-2"),
    Combat = Window:AddTab("Combat", "swords"),
    Items = Window:AddTab("Items", "package-open"),
    Shop = Window:AddTab("Shop", "shopping-cart"),
    Settings = Window:AddTab("Settings", "settings"),
}

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

local function copyText(text)
    if setclipboard then
        setclipboard(text)
    elseif toclipboard then
        toclipboard(text)
    end
end

local function copyDiscord()
    copyText(DISCORD_INVITE)
    Library:Notify("Copied Discord invite to clipboard")
end

local function AddDiscordButton(Tab)
    local DiscordGroup = Tab:AddLeftGroupbox("Discord", nil, nil, nil, true)
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
    if Tab ~= Tabs.Info then
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
        copyText(string.format(
            'game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s", game:GetService("Players").LocalPlayer)',
            game.PlaceId,
            jobId
        ))
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

local AdGroup = Tabs.Info:AddLeftGroupbox("Ouroboros Hub", "sparkles")

AdGroup:AddLabel("Every script in the hub is keyless. No key systems, no checkpoints, no linkvertise.", true)
AdGroup:AddLabel("The Discord has ready made configs, dupe methods, giveaways, and early access to new scripts.", true)
AdGroup:AddLabel("Requests get taken seriously. A lot of what is in this script started as a Discord message.", true)

AdGroup:AddButton({
    Text = "Copy Discord Invite",
    Func = copyDiscord,
})

local ScriptsGroup = Tabs.Info:AddRightGroupbox("Scripts", "package")

ScriptsGroup:AddLabel(colored("Included in this hub", GREY), true)
ScriptsGroup:AddLabel(colored(GAME_NAME, BLUE), true)

local FeaturesGroup = Tabs.Info:AddRightGroupbox("Features", "list")

FeaturesGroup:AddLabel(colored("Auto Merge", BLUE), true)
FeaturesGroup:AddLabel(colored("Auto Rebirth & Upgrades", BLUE), true)
FeaturesGroup:AddLabel(colored("Auto Attack Sun & Rivals", ORANGE), true)
FeaturesGroup:AddLabel(colored("Auto Wormholes & Quests", ORANGE), true)
FeaturesGroup:AddLabel(colored("Auto Star Shop & Wheel", GREEN), true)
FeaturesGroup:AddLabel(colored("Misc Utilities", GREY), true)

local SocialsGroup = Tabs.Info:AddRightGroupbox("Socials", "link")

SocialsGroup:AddButton({
    Text = "Discord",
    Func = copyDiscord,
})

SocialsGroup:AddButton({
    Text = "Rscripts",
    Func = function()
        copyText(RSCRIPTS_LINK)
        Library:Notify("Copied Rscripts profile to clipboard")
    end,
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

local MergeGroup = Tabs.Main:AddLeftGroupbox("Merge", "git-merge")

MergeGroup:AddToggle("AutoMerge", {
    Text = "Auto Merge",
    Default = false,
})

MergeGroup:AddSlider("MergeMinTier", {
    Text = "Min Tier",
    Default = 1,
    Min = 1,
    Max = MAX_TIER,
    Rounding = 0,
})

MergeGroup:AddSlider("MergeMaxTier", {
    Text = "Max Tier",
    Default = MAX_TIER,
    Min = 1,
    Max = MAX_TIER,
    Rounding = 0,
})

MergeGroup:AddSlider("MergeDelay", {
    Text = "Merge Delay",
    Default = 0.4,
    Min = 0.1,
    Max = 3,
    Rounding = 1,
    Suffix = "s",
})

MergeGroup:AddToggle("NativeAutoMerge", {
    Text = "Enable In-Game Auto Merge",
    Default = false,
})

local BaseGroup = Tabs.Main:AddLeftGroupbox("Base", "lock")

BaseGroup:AddToggle("AutoLockBase", {
    Text = "Auto Lock Base",
    Default = false,
})

local RebirthGroup = Tabs.Main:AddRightGroupbox("Rebirth", "rotate-ccw")

RebirthGroup:AddToggle("AutoRebirth", {
    Text = "Auto Rebirth",
    Default = false,
})

local UpgradeGroup = Tabs.Main:AddRightGroupbox("Upgrades", "trending-up")

UpgradeGroup:AddToggle("AutoUpgrades", {
    Text = "Auto Buy Upgrades",
    Default = false,
})

UpgradeGroup:AddDropdown("UpgradeList", {
    Values = UPGRADE_DISPLAY,
    Default = {},
    Multi = true,
    Text = "Upgrades",
})

local SunGroup = Tabs.Combat:AddLeftGroupbox("Solar Core", "sun")

SunGroup:AddToggle("AutoAttackSun", {
    Text = "Auto Attack Sun",
    Default = false,
})

SunGroup:AddSlider("SunMinTier", {
    Text = "Min Tier",
    Default = 1,
    Min = 1,
    Max = MAX_TIER,
    Rounding = 0,
})

SunGroup:AddSlider("SunMaxTier", {
    Text = "Max Tier",
    Default = MAX_TIER,
    Min = 1,
    Max = MAX_TIER,
    Rounding = 0,
})

SunGroup:AddSlider("SunDelay", {
    Text = "Attack Delay",
    Default = 1,
    Min = 0.2,
    Max = 5,
    Rounding = 1,
    Suffix = "s",
})

local RaidGroup = Tabs.Combat:AddRightGroupbox("Rivals", "crosshair")

RaidGroup:AddToggle("AutoAttackPlayers", {
    Text = "Auto Attack Players",
    Default = false,
})

RaidGroup:AddDropdown("RaidTargets", {
    Values = { "Players", "AI" },
    Default = { "Players" },
    Multi = true,
    Text = "Targets",
})

RaidGroup:AddSlider("RaidMinTier", {
    Text = "Min Tier",
    Default = 1,
    Min = 1,
    Max = MAX_TIER,
    Rounding = 0,
})

RaidGroup:AddSlider("RaidMaxTier", {
    Text = "Max Tier",
    Default = MAX_TIER,
    Min = 1,
    Max = MAX_TIER,
    Rounding = 0,
})

RaidGroup:AddSlider("RaidDelay", {
    Text = "Attack Delay",
    Default = 1,
    Min = 0.2,
    Max = 5,
    Rounding = 1,
    Suffix = "s",
})

local WormholeGroup = Tabs.Items:AddLeftGroupbox("Wormholes", "circle-dot")

WormholeGroup:AddToggle("AutoEquipWormholes", {
    Text = "Auto Equip Best Wormholes",
    Default = false,
})

local QuestGroup = Tabs.Items:AddRightGroupbox("Quests", "scroll-text")

QuestGroup:AddToggle("AutoClaimDailyQuest", {
    Text = "Auto Claim Daily Quests",
    Default = false,
})

local StarShopGroup = Tabs.Shop:AddLeftGroupbox("Star Shop", "star")

StarShopGroup:AddToggle("AutoStarShop", {
    Text = "Auto Buy Star Shop",
    Default = false,
})

StarShopGroup:AddDropdown("StarShopList", {
    Values = SHOP_DISPLAY,
    Default = {},
    Multi = true,
    Text = "Items",
})

StarShopGroup:AddDropdown("StarShopRarities", {
    Values = SHOP_RARITIES,
    Default = {},
    Multi = true,
    Text = "Rarities",
})

local WheelGroup = Tabs.Shop:AddRightGroupbox("Wheel", "disc")

WheelGroup:AddToggle("AutoSpinWheel", {
    Text = "Auto Spin Wheel",
    Default = false,
})

WheelGroup:AddToggle("AutoClaimDailySpin", {
    Text = "Auto Claim Daily Spin",
    Default = false,
})

task.spawn(function()
    while not Library.Unloaded do
        local delay = Options.MergeDelay and Options.MergeDelay.Value or 0.4
        if Toggles.AutoMerge.Value then
            local minTier = Options.MergeMinTier.Value
            local maxTier = Options.MergeMaxTier.Value
            local buckets, tiers = groupByTier(ownedHoles(), minTier, maxTier)
            for _, tier in ipairs(tiers) do
                local bucket = buckets[tier]
                for index = 1, #bucket - 1, 2 do
                    if Library.Unloaded or not Toggles.AutoMerge.Value then
                        break
                    end
                    local source = bucket[index]
                    local target = bucket[index + 1]
                    pcall(function()
                        HoleService:RequestMerge(source.Id, target.Id, target.Position)
                    end)
                    task.wait(delay)
                end
            end
        end
        task.wait(delay)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        local delay = Options.SunDelay and Options.SunDelay.Value or 1
        if Toggles.AutoAttackSun.Value then
            local ok, alive = pcall(function()
                return (SunService:GetState())
            end)
            if ok and alive then
                for _, hole in attackHoles(Options.SunMinTier.Value, Options.SunMaxTier.Value) do
                    if Library.Unloaded or not Toggles.AutoAttackSun.Value then
                        break
                    end
                    pcall(function()
                        SunService:LaunchAt(hole.Id)
                    end)
                    task.wait(delay)
                end
            end
        end
        task.wait(delay)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        local delay = Options.RaidDelay and Options.RaidDelay.Value or 1
        if Toggles.AutoAttackPlayers.Value then
            local modes = Options.RaidTargets.Value
            local targets = islandTargets(modes["Players"] == true, modes["AI"] == true)
            if #targets > 0 then
                local cursor = 1
                for _, hole in attackHoles(Options.RaidMinTier.Value, Options.RaidMaxTier.Value) do
                    if Library.Unloaded or not Toggles.AutoAttackPlayers.Value then
                        break
                    end
                    pcall(function()
                        RaidService:LaunchAt(hole.Id, targets[cursor], nil)
                    end)
                    cursor = cursor % #targets + 1
                    task.wait(delay)
                end
            end
        end
        task.wait(delay)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        task.wait(3)
        if Toggles.AutoEquipWormholes.Value then
            local ok, state = pcall(function()
                return WormholeService:GetState()
            end)
            if ok and type(state) == "table" then
                local entries = wormholeEntries(state)
                local limit = math.max(0, tonumber(state.EquipLimit) or 0)
                for index, entry in ipairs(entries) do
                    if Library.Unloaded or not Toggles.AutoEquipWormholes.Value then
                        break
                    end
                    local shouldEquip = index <= limit
                    if shouldEquip ~= entry.Equipped then
                        pcall(function()
                            WormholeService:Equip(entry.Id)
                        end)
                        task.wait(0.3)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        task.wait(5)
        if Toggles.AutoClaimDailyQuest.Value then
            local ok, state = pcall(function()
                return QuestService:GetState()
            end)
            if ok and type(state) == "table" and type(state.Daily) == "table" then
                for _, quest in ipairs(state.Daily.Quests or {}) do
                    if Library.Unloaded or not Toggles.AutoClaimDailyQuest.Value then
                        break
                    end
                    if quest.Done and not quest.Claimed and quest.Key then
                        pcall(function()
                            QuestService:ClaimDaily(quest.Key)
                        end)
                        task.wait(0.5)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        task.wait(1)
        if Toggles.AutoLockBase.Value then
            local ok, remaining = pcall(function()
                return ShieldService:GetShieldState()
            end)
            if ok and (tonumber(remaining) or 0) <= 0 then
                pcall(function()
                    ShieldService:ActivateShield()
                end)
            end
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        task.wait(5)
        if Toggles.AutoRebirth.Value then
            local ok, info = pcall(function()
                return RebirthService:GetRebirthInfo()
            end)
            if ok and type(info) == "table" and info.CanRebirth then
                pcall(function()
                    RebirthService:RequestRebirth()
                end)
            end
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        task.wait(1)
        if Toggles.AutoUpgrades.Value then
            for display in pairs(Options.UpgradeList.Value) do
                local key = UPGRADE_KEY[display]
                local upgrade = key and UpgradeConfig.GetByKey(key)
                if upgrade and canAffordUpgrade(upgrade) then
                    pcall(function()
                        UpgradeService:PurchaseUpgrade(key)
                    end)
                end
            end
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        task.wait(3)
        if Toggles.AutoStarShop.Value then
            local ok, state = pcall(function()
                return StarShopService:GetState()
            end)
            if ok and type(state) == "table" and state.Open and type(state.Stock) == "table" then
                local wantedKeys = {}
                for display in pairs(Options.StarShopList.Value) do
                    local key = SHOP_KEY[display]
                    if key then
                        wantedKeys[key] = true
                    end
                end
                local wantedRarities = Options.StarShopRarities.Value
                local stars = tonumber(state.Stars) or 0
                for _, entry in ipairs(state.Stock) do
                    if entry.Available and (wantedKeys[entry.Key] or wantedRarities[entry.Rarity]) then
                        local price = tonumber(entry.Price) or 0
                        if price <= stars then
                            local bought = pcall(function()
                                return StarShopService:Purchase(entry.Key)
                            end)
                            if bought then
                                stars = stars - price
                            end
                            task.wait(0.3)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        task.wait(2)
        if Toggles.AutoSpinWheel.Value or Toggles.AutoClaimDailySpin.Value then
            local ok, state = pcall(function()
                return WheelService:GetState()
            end)
            if ok and type(state) == "table" then
                if Toggles.AutoClaimDailySpin.Value and state.DailyClaimable then
                    pcall(function()
                        WheelService:ClaimDaily()
                    end)
                end
                if Toggles.AutoSpinWheel.Value and (tonumber(state.Tickets) or 0) > 0 then
                    pcall(function()
                        WheelService:Spin()
                    end)
                    task.wait(6)
                end
            end
        end
    end
end)

Toggles.NativeAutoMerge:OnChanged(function()
    pcall(function()
        HoleService:SetAutoMergeEnabled(Toggles.NativeAutoMerge.Value)
    end)
end)

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

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "menu")

MenuGroup:AddToggle("AntiAfk", {
    Text = "Anti-AFK",
    Default = true,
})

MenuGroup:AddButton("Unload", function()
    Library:Unload()
end)

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Menu keybind",
})

Library.ToggleKeybind = Options.MenuKeybind

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
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

ThemeManager:SetFolder("OuroborosHub")
SaveManager:SetFolder("OuroborosHub/merge-a-black-hole")

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SaveDefault("Monochrome")
ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()

SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
