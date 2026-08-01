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

local Options = Library.Options
local Toggles = Library.Toggles

local Modules = ReplicatedStorage:WaitForChild("Modules")
local RemoteHandler = require(Modules:WaitForChild("RemoteHandler"))
local GenericFunctionUtil = require(Modules:WaitForChild("HGUtils"):WaitForChild("GenericFunctionUtil"))

local MergeTower = RemoteHandler.GetRemoteFunction("MergeTower")
local UpgradeBoardEvent = RemoteHandler.GetRemoteEvent("UpgradeBoardEvent")
local UpgradeBoardState = RemoteHandler.GetRemoteFunction("UpgradeBoardState")
local EquipBestTowers = RemoteHandler.GetRemoteEvent("EquipBestTowers")

local UpgradeKeys = { "SpawnLevel", "BaseHealth", "CoinValue", "GemDropChance", "FireRate", "PickupRadius", "ActiveSlots" }

local CurrencyCache = {}
local UpdatePlayerCurrency = ReplicatedStorage:WaitForChild("UpdatePlayerCurrency")
UpdatePlayerCurrency.OnClientEvent:Connect(function(currencyName, amount)
    if currencyName ~= nil and amount ~= nil then
        CurrencyCache[currencyName] = amount
    end
end)

local function copyDiscord()
    setclipboard(DISCORD_INVITE)
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
