local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Toggles = Library.Toggles
local Options = Library.Options

local NukeRemotes = ReplicatedStorage:WaitForChild("NukeRemotes")
local Remotes = require(ReplicatedStorage.Packages.Remotes)
local Config = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NukeClientModules"):WaitForChild("Config"))
local HeldNuke = require(LocalPlayer.PlayerScripts.NukeClientModules.HeldNuke)
local DataController = require(ReplicatedStorage.Controllers.DataController)
local UpgradeConfig = require(ReplicatedStorage.NukeShared.UpgradeConfig)
local BigNum = require(ReplicatedStorage.NukeShared.BigNum)
local Products = require(ReplicatedStorage.NukeShared.Products)

local DropRemote = NukeRemotes:WaitForChild("Drop")
local PurchaseUpgrade = NukeRemotes:WaitForChild("PurchaseUpgrade")
local RequestRebirth = NukeRemotes:WaitForChild("RequestRebirth")

local MERGE_RADIUS = Config.MERGE_RADIUS or 6
local PICKUP_RADIUS = Config.PICKUP_RADIUS or 7
local DROP_DEBOUNCE = Config.DROP_DEBOUNCE or 0.75
local INDIVIDUAL_DROP_DEBOUNCE = Config.INDIVIDUAL_DROP_DEBOUNCE or 2.5

local UPGRADE_LABELS = {
    ["Spawn Tier"] = "TIER",
    ["Max Spawn"] = "MAX",
    ["Lock Base"] = "LOCKBASE",
}

local cachedFolder
local walkSpeed = 22
local attackMode = "City"
local selectedUpgrades = {}

local function getRoot()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local controls
local function getControls()
    if controls then return controls end
    local ok, playerModule = pcall(function()
        return require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
    end)
    if ok and playerModule then
        local ok2, result = pcall(function() return playerModule:GetControls() end)
        if ok2 then controls = result end
    end
    return controls
end

local function getNukesFolder()
    if cachedFolder and cachedFolder.Parent then
        return cachedFolder
    end
    cachedFolder = nil
    local bases = Workspace:FindFirstChild("Bases")
    if not bases then return nil end
    for _, base in ipairs(bases:GetChildren()) do
        local nukes = base:FindFirstChild("Nukes")
        if nukes then
            for _, nuke in ipairs(nukes:GetChildren()) do
                if nuke:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                    cachedFolder = nukes
                    return nukes
                end
            end
        end
    end
    return nil
end

local function heldTier()
    local ok, tier = pcall(HeldNuke.GetTier)
    if ok then return tier end
    return nil
end

local function isAvailable(nuke)
    local state = nuke:GetAttribute("State")
    if state ~= "floor" and state ~= "based" then return false end
    local dropTime = nuke:GetAttribute("DropTime")
    if dropTime and Workspace:GetServerTimeNow() - dropTime < INDIVIDUAL_DROP_DEBOUNCE then
        return false
    end
    return true
end

local function scanNukes(folder)
    local list = {}
    for _, nuke in ipairs(folder:GetChildren()) do
        if (nuke:IsA("Model") or nuke:IsA("BasePart")) and isAvailable(nuke) then
            list[#list + 1] = {
                inst = nuke,
                tier = nuke:GetAttribute("Tier"),
                pos = nuke:GetPivot().Position,
            }
        end
    end
    return list
end

local function horizontalDist(a, b)
    local dx = a.X - b.X
    local dz = a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

local function nearestOfTier(list, tier, from)
    local best, bestDist
    for _, entry in ipairs(list) do
        if entry.tier == tier then
            local d = horizontalDist(entry.pos, from)
            if not bestDist or d < bestDist then
                best, bestDist = entry, d
            end
        end
    end
    return best
end

local function choosePickup(list, from)
    local counts = {}
    for _, entry in ipairs(list) do
        counts[entry.tier] = (counts[entry.tier] or 0) + 1
    end
    local lowest
    for tier, count in pairs(counts) do
        if count >= 2 and (not lowest or tier < lowest) then
            lowest = tier
        end
    end
    if not lowest then return nil end
    return nearestOfTier(list, lowest, from)
end

local function glideTo(pos, shouldStop)
    local startClock = os.clock()
    local hum
    local ctrl = getControls()
    if ctrl then pcall(function() ctrl:Disable() end) end
    while true do
        if Library.Unloaded or not Toggles.AutoMerge.Value or shouldStop() then break end
        if os.clock() - startClock > 12 then break end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        hum = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then break end
        if hum.WalkSpeed ~= walkSpeed then hum.WalkSpeed = walkSpeed end
        local dir = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
        if dir.Magnitude <= 3 then break end
        hum:Move(dir.Unit, false)
        task.wait(0.08)
    end
    if hum then hum:Move(Vector3.zero, false) end
    if ctrl then pcall(function() ctrl:Enable() end) end
end

local function dropHeld()
    local root = getRoot()
    local ok, cf = pcall(HeldNuke.GetCFrame)
    local target = (ok and cf) or (root and root.CFrame) or CFrame.new()
    pcall(function() DropRemote:FireServer(target) end)
end

local function cityCenter()
    local city = Workspace:FindFirstChild("CityModel")
    if city then
        local ok, pivot = pcall(function() return city:GetPivot().Position end)
        if ok then return pivot end
    end
    return Vector3.new(415, 11, 131)
end

local function nearestCommander(from)
    local best, bestDist
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and string.find(model.Name, "Commander") then
            local ok, pivot = pcall(function() return model:GetPivot().Position end)
            if ok then
                local d = (pivot - from).Magnitude
                if not bestDist or d < bestDist then
                    best, bestDist = pivot, d
                end
            end
        end
    end
    return best
end

local function attackTarget()
    if attackMode == "Commanders" then
        local commander = nearestCommander(cityCenter())
        if commander then return commander end
    end
    return cityCenter()
end

local function getUpgradeInfo(key)
    local holder = DataController:Get()
    local data = holder and holder.Data
    if not data then return nil end
    local level = ({ MAX = data.maxLevel, LOCKBASE = data.lockBaseLevel, TIER = data.tierLevel })[key] or 1
    local rebirth = data.rebirthLevel or 0
    local maxed = UpgradeConfig.IsMaxed(key, level)
    if key == "LOCKBASE" then
        maxed = UpgradeConfig.GetMaxLevel("LOCKBASE", rebirth) <= level
    end
    if not maxed and key == "TIER" then
        local nextValue = UpgradeConfig.GetValue("TIER", level + 1)
        local cap = Products.MergeCapForRebirth(rebirth)
        if nextValue and cap < nextValue then maxed = true end
    end
    if maxed then return { maxed = true } end
    local ok, affordable = pcall(function()
        return BigNum.gte(BigNum.deserialize(data.cash), BigNum.deserialize(BigNum.serialize(UpgradeConfig.GetCost(key, level))))
    end)
    return { maxed = false, affordable = ok and affordable }
end

local Window = Library:CreateWindow({
    Title = "Merge a Nuke",
    Footer = "Ouroboros Hub",
    Icon = 18657887261,
    NotifySide = "Right",
    Size = UDim2.fromOffset(920, 680),
})

local Tabs = {
    Main = Window:AddTab("Main", "atom"),
    Settings = Window:AddTab("Settings", "settings"),
}

local MergeGroup = Tabs.Main:AddLeftGroupbox("Auto Merge", "combine")

MergeGroup:AddToggle("AutoMerge", {
    Text = "Auto Merge",
    Default = false,
})

MergeGroup:AddSlider("WalkSpeed", {
    Text = "Walk Speed",
    Default = 22,
    Min = 16,
    Max = 32,
    Rounding = 0,
    Suffix = " sps",
    Callback = function(value)
        walkSpeed = value
    end,
})

local AttackGroup = Tabs.Main:AddLeftGroupbox("Attack", "crosshair")

AttackGroup:AddToggle("AutoAttack", {
    Text = "Auto Attack",
    Default = false,
})

local ATTACK_VALUES = { "City", "Commanders" }

AttackGroup:AddDropdown("AttackTarget", {
    Text = "Target",
    Values = ATTACK_VALUES,
    Default = 1,
    Multi = false,
    Callback = function(value)
        if type(value) == "number" then value = ATTACK_VALUES[value] end
        attackMode = value
    end,
})

local UpgradesGroup = Tabs.Main:AddRightGroupbox("Upgrades", "trending-up")

UpgradesGroup:AddToggle("AutoUpgrades", {
    Text = "Auto Upgrades",
    Default = false,
})

UpgradesGroup:AddDropdown("UpgradeSelection", {
    Text = "Upgrades",
    Values = { "Spawn Tier", "Max Spawn", "Lock Base" },
    Default = {},
    Multi = true,
    Callback = function(value)
        local set = {}
        if type(value) == "table" then
            for k, v in pairs(value) do
                local label = (v == true) and k or (type(v) == "string" and v or nil)
                local key = label and UPGRADE_LABELS[label]
                if key then set[key] = true end
            end
        end
        selectedUpgrades = set
    end,
})

local RebirthGroup = Tabs.Main:AddRightGroupbox("Rebirth", "refresh-cw")

RebirthGroup:AddToggle("AutoRebirth", {
    Text = "Auto Rebirth",
    Default = false,
})

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddLabel("UI Keybind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "UI Keybind",
})

local UI_SCALE_VALUES = { "50%", "75%", "90%", "100%", "110%", "125%", "150%" }

MenuGroup:AddDropdown("UIScale", {
    Text = "UI Scale",
    Values = UI_SCALE_VALUES,
    Default = 4,
    Multi = false,
    Callback = function(value)
        if type(value) == "number" then value = UI_SCALE_VALUES[value] end
        local percent = tonumber((tostring(value):gsub("%%", "")))
        if percent and percent >= 25 then
            Library:SetDPIScale(percent)
        end
    end,
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

local function buildMinimizeButton()
    local parent = (gethui and gethui()) or LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not parent then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "MergeANukeMinimize"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999
    gui.Parent = parent

    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(72, 72)
    button.Position = UDim2.fromOffset(20, 140)
    button.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    button.Text = "N"
    button.TextColor3 = Color3.fromRGB(120, 235, 170)
    button.TextScaled = true
    button.Font = Enum.Font.GothamBold
    button.AutoButtonColor = true
    button.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(120, 235, 170)
    stroke.Thickness = 1
    stroke.Transparency = 0.4
    stroke.Parent = button

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 12)
    padding.PaddingBottom = UDim.new(0, 12)
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    padding.Parent = button

    local dragging, dragStart, startPos, moved = false, nil, nil, false
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            dragStart = input.Position
            startPos = button.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 4 then moved = true end
            button.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    button.MouseButton1Click:Connect(function()
        if moved then return end
        Library:Toggle(not Library.Toggled)
    end)

    Library:OnUnload(function()
        gui:Destroy()
    end)
end

buildMinimizeButton()

Library:OnUnload(function()
    if antiAfkConnection then
        antiAfkConnection:Disconnect()
        antiAfkConnection = nil
    end
    print("Merge a Nuke unloaded")
end)

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("OuroborosHub")
ThemeManager:SaveDefault("Mint")

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("OuroborosHub/MergeANuke")
SaveManager:BuildConfigSection(Tabs.Settings)

ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()

SaveManager:LoadAutoloadConfig()

Remotes.LaunchAllowed.OnClientEvent:Connect(function()
    if Library.Unloaded or not Toggles.AutoAttack.Value then return end
    pcall(function() Remotes.LaunchConfirm:FireServer(attackTarget()) end)
end)

task.spawn(function()
    while not Library.Unloaded do
        task.wait(0.05)
        if not Toggles.AutoMerge.Value then
            task.wait(0.2)
        else
            local root = getRoot()
            local folder = getNukesFolder()
            if not root or not folder then
                task.wait(0.3)
            else
                local held = heldTier()
                if Toggles.AutoAttack.Value and held then
                    task.wait(0.15)
                else
                    local list = scanNukes(folder)
                    if held then
                        local partner = nearestOfTier(list, held, root.Position)
                        if partner then
                            glideTo(partner.pos, function()
                                return heldTier() ~= held or partner.inst.Parent == nil
                            end)
                        else
                            dropHeld()
                            task.wait(DROP_DEBOUNCE + 0.1)
                        end
                    else
                        local target = choosePickup(list, root.Position)
                        if target then
                            glideTo(target.pos, function()
                                return heldTier() ~= nil or target.inst.Parent == nil
                            end)
                        else
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
        task.wait(1)
        if Toggles.AutoAttack.Value and heldTier() ~= nil then
            pcall(function() Remotes.LaunchRequest:FireServer() end)
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        task.wait(1)
        if Toggles.AutoUpgrades.Value then
            for key in pairs(selectedUpgrades) do
                local info = getUpgradeInfo(key)
                if info and not info.maxed and info.affordable then
                    pcall(function() PurchaseUpgrade:FireServer(key) end)
                end
            end
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        task.wait(5)
        if Toggles.AutoRebirth.Value then
            pcall(function() RequestRebirth:FireServer() end)
        end
    end
end)
