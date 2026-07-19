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

local GAME_NAME = "Merge a Black Hole"
local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"

local HoleService = Knit.GetService("HoleService")
local ShieldService = Knit.GetService("ShieldService")
local RebirthService = Knit.GetService("RebirthService")
local UpgradeService = Knit.GetService("UpgradeService")
local StarShopService = Knit.GetService("StarShopService")
local WheelService = Knit.GetService("WheelService")

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

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Toggles = Library.Toggles
local Options = Library.Options

local Window = Library:CreateWindow({
    Title = "Ouroboros Hub",
    Footer = DISCORD_INVITE .. " | " .. GAME_NAME,
    Icon = 18657887261,
    NotifySide = "Right",
    ShowCustomCursor = false,
})

local Tabs = {
    Main = Window:AddTab("Main", "gamepad-2"),
    Shop = Window:AddTab("Shop", "shopping-cart"),
    Settings = Window:AddTab("Settings", "settings"),
}

local function AddDiscordButton(Tab)
    Tab:AddLeftGroupbox("Discord", nil, nil, nil, true):AddButton({
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

local MergeGroup = Tabs.Main:AddLeftGroupbox("Merge", "git-merge")

MergeGroup:AddToggle("AutoMerge", {
    Text = "Auto Merge",
    Default = false,
})

MergeGroup:AddSlider("MergeMinTier", {
    Text = "Min Tier",
    Default = 1,
    Min = 1,
    Max = 55,
    Rounding = 0,
})

MergeGroup:AddSlider("MergeMaxTier", {
    Text = "Max Tier",
    Default = 55,
    Min = 1,
    Max = 55,
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

ThemeManager:SaveDefault("Mint")
ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()

SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
