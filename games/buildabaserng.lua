local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local getIdentity = getthreadidentity or getidentity or get_thread_identity
local setIdentity = setthreadidentity or setidentity or set_thread_identity
local executorIdentity = (getIdentity and getIdentity()) or 8

local function asGameScript(callback, ...)
    if not setIdentity then
        return callback(...)
    end

    pcall(setIdentity, 2)
    local results = table.pack(pcall(callback, ...))
    pcall(setIdentity, executorIdentity)

    if not results[1] then
        error(results[2], 0)
    end
    return table.unpack(results, 2, results.n)
end

local Modules = asGameScript(function()
    local DataService = require(ReplicatedStorage.Modules.Core.DataService)
    return {
        GameModule = require(ReplicatedStorage.GameModule),
        Warp = require(ReplicatedStorage.Modules.Core.Warp),
        client = DataService.client,
        RandModule = require(ReplicatedStorage.Modules.Core.RandModule),
        BuildingsUtility = require(ReplicatedStorage.Modules.Features.Buildings.Utility),
        SkillsUtility = require(ReplicatedStorage.Modules.Features.Skills.Utility),
        RecipesUtility = require(ReplicatedStorage.Modules.Features.Recipes.Utility),
        WeaponsConfig = require(ReplicatedStorage.Modules.Features.Weapons.WeaponsConfig),
        SharedPlacementModule = require(ReplicatedStorage.Modules.Gameplay.PlacementModule.SharedPlacementModule),
        ClientBuildModule = require(ReplicatedStorage.Modules.Gameplay.ClientBuildModule),
        ClientRollModule = require(ReplicatedStorage.Modules.Gameplay.ClientRollModule),
    }
end)

local GameModule = Modules.GameModule
local Warp = Modules.Warp
local client = Modules.client
local RandModule = Modules.RandModule
local BuildingsUtility = Modules.BuildingsUtility
local SkillsUtility = Modules.SkillsUtility
local RecipesUtility = Modules.RecipesUtility
local WeaponsConfig = Modules.WeaponsConfig
local SharedPlacementModule = Modules.SharedPlacementModule
local ClientBuildModule = Modules.ClientBuildModule
local ClientRollModule = Modules.ClientRollModule

local Net = asGameScript(function()
    return {
        Roll = Warp.Client("Roll"),
        PlaceBuilding = Warp.Client("PlaceBuilding"),
        BuySkill = Warp.Client("BuySkill"),
        Craft = Warp.Client("Craft"),
        ClearPlot = Warp.Client("ClearPlot"),
        AttackWeapon = Warp.Client("AttackWeapon"),
        StartWave = Warp.Client("StartWave"),
        StopWave = Warp.Client("StopWave"),
        SetAutoWave = Warp.Client("SetAutoWave"),
        UpgradeBuilding = Warp.Client("UpgradeBuilding"),
    }
end)

local function netFire(channel, ...)
    local args = table.pack(...)
    return asGameScript(function()
        return channel:Fire(table.unpack(args, 1, args.n))
    end)
end

local function netInvoke(channel, ...)
    local args = table.pack(...)
    return asGameScript(function()
        return channel:Invoke(table.unpack(args, 1, args.n))
    end)
end

local GRID = SharedPlacementModule.CONFIG.GridSize
local MAX_STACK = SharedPlacementModule.CONFIG.MaxStackHeight
local RARITY_ORDER = {
    "Basic", "Rare", "Refined", "Epic", "Legendary",
    "Mythic", "Glorious", "Primordial", "Atomic", "Divine", "Lunatic",
}
local MUTATION_ORDER = { "Normal", "Shiny", "Galaxy" }
local RARITY_INDEX = {}
for index, name in RARITY_ORDER do
    RARITY_INDEX[name] = index
end

local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local function safeGetHui()
    return playerGui
end
if getgenv then
    getgenv().gethui = safeGetHui
end
_G.gethui = safeGetHui

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Toggles = Library.Toggles
local Options = Library.Options

local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"
local GAME_NAME = "Build a Base RNG"

local executorName = "Unknown"
pcall(function()
    if identifyexecutor then
        local name, version = identifyexecutor()
        if type(name) == "string" and name ~= "" then
            executorName = type(version) == "string" and version ~= "" and (name .. " " .. version) or name
        end
    end
end)

local function copyDiscord()
    setclipboard(DISCORD_INVITE)
    Library:Notify("Copied Discord invite to clipboard")
end

local Window = Library:CreateWindow({
    Title = "Ouroboros Hub",
    Footer = DISCORD_INVITE .. " | " .. GAME_NAME,
    Icon = 18657887261,
    NotifySide = "Right",
    ShowCustomCursor = false,
    Size = UDim2.fromOffset(760, 620),
})

local Tabs = {
    Info = Window:AddTab("Info", "info"),
    Roll = Window:AddTab("Roll", "dices"),
    Combat = Window:AddTab("Combat", "swords"),
    Build = Window:AddTab("Build", "hammer"),
    Craft = Window:AddTab("Craft", "flask-conical"),
    Steal = Window:AddTab("Steal (Beta)", "copy"),
    Settings = Window:AddTab("Settings", "settings"),
}

local function AddDiscordButton(Tab)
    local DiscordGroup = Tab:AddLeftGroupbox("Discord", nil, true, false, true)
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

local InfoGroup = Tabs.Info:AddLeftGroupbox("Basic Info", "circle-user")

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

local function getMyPlot()
    return GameModule.GetPlayerPlot(LocalPlayer)
end

local function getPlacementFolder(plot)
    local placement = plot:FindFirstChild("Placement")
    if placement and #placement:GetChildren() > 0 then
        return placement
    end
    local base = plot:FindFirstChild("Base")
    if base and #base:GetChildren() > 0 then
        return base
    end
    return placement or base
end

local function getConfigFromModel(model)
    return BuildingsUtility.GetConfig({
        Name = model.Name,
        Mutation = model:GetAttribute("Mutation") or "Normal",
    })
end

local function getOwnedCounts()
    local counts = {}
    for name, mutations in BuildingsUtility.GetOwnedBuildings(LocalPlayer) do
        for mutation, quantity in mutations do
            local config = BuildingsUtility.GetConfig({ Name = name, Mutation = mutation })
            if config then
                counts[config.Identifier] = quantity
            end
        end
    end
    return counts
end

local function getBuildingSize(identifier)
    local building = BuildingsUtility.MakeBuildingFromIdentifier(identifier)
    local model = ReplicatedStorage.Buildings:FindFirstChild(building.Name)
    if model and model.PrimaryPart then
        return model.PrimaryPart.Size
    end
end

local Reserved = {}

local function clearReserved()
    table.clear(Reserved)
end

local function rotatedSize(size, rotation)
    if math.round(rotation / 90) % 2 == 1 then
        return Vector3.new(size.Z, size.Y, size.X)
    end
    return size
end

local function overlapsReserved(localPosition, size)
    for _, entry in Reserved do
        local delta = entry.Position - localPosition
        local extents = (entry.Size + size) / 2
        if math.abs(delta.X) < extents.X - 0.05
            and math.abs(delta.Y) < extents.Y - 0.05
            and math.abs(delta.Z) < extents.Z - 0.05 then
            return true
        end
    end
    return false
end

local function reserve(localPosition, size)
    table.insert(Reserved, { Position = localPosition, Size = size })
end

local function findPlacement(plot, identifier, rotation)
    local size = getBuildingSize(identifier)
    if not size then
        return nil
    end

    local worldSize = rotatedSize(size, rotation)
    local floor = plot.Floor
    local origin = SharedPlacementModule.GetOrigin(plot)
    local floorLocal = origin:PointToObjectSpace(floor.Position)
    local baseY = floorLocal.Y + floor.Size.Y / 2
    local layers = math.max(0, MAX_STACK - size.Y / GRID)
    local minX = floorLocal.X - floor.Size.X / 2 + worldSize.X / 2
    local maxX = floorLocal.X + floor.Size.X / 2 - worldSize.X / 2
    local minZ = floorLocal.Z - floor.Size.Z / 2 + worldSize.Z / 2
    local maxZ = floorLocal.Z + floor.Size.Z / 2 - worldSize.Z / 2

    for layer = 0, layers do
        local y = baseY + layer * GRID + worldSize.Y / 2
        local z = minZ
        while z <= maxZ + 0.001 do
            local x = minX
            while x <= maxX + 0.001 do
                local candidate = SharedPlacementModule.SnapLocalPosition(plot, size, Vector3.new(x, y, z), rotation)
                if not overlapsReserved(candidate, worldSize)
                    and SharedPlacementModule.IsPlacementEmpty(plot, size, candidate, rotation)
                    and not SharedPlacementModule.IsColliding(plot, size, candidate, rotation, identifier) then
                    return candidate, size, worldSize
                end
                x = x + GRID
            end
            z = z + GRID
        end
    end
end

local function placementCount(plot)
    local total = 0
    local placement = plot:FindFirstChild("Placement")
    local base = plot:FindFirstChild("Base")
    if placement then
        total = total + #placement:GetChildren()
    end
    if base then
        total = total + #base:GetChildren()
    end
    return total
end

local function place(plot, identifier, localPosition, rotation)
    local before = placementCount(plot)
    netInvoke(Net.PlaceBuilding, 10, identifier, localPosition, rotation)
    local deadline = os.clock() + 1
    while os.clock() < deadline and placementCount(plot) <= before do
        task.wait(0.05)
    end
    return placementCount(plot) > before
end

local RollGroup = Tabs.Roll:AddLeftGroupbox("Auto Roll")

RollGroup:AddToggle("AutoRoll", { Text = "Auto Roll", Default = false })
RollGroup:AddToggle("InstantRoll", { Text = "Instant Roll", Default = true })

local RollInfo = Tabs.Roll:AddRightGroupbox("Session")
local RollCountLabel = RollInfo:AddLabel("Rolls this session: 0")
local LastRollLabel = RollInfo:AddLabel("Last: none", true)

local rollsThisSession = 0
local ROLL_MIN_DELAY = 1.2
local ROLL_BACKOFF = 8

local function getRollCount()
    local doubleRollPower = SkillsUtility.GetPowerForSkillSubtype(LocalPlayer, "DoubleRoll")
    local count = 1
    if RandModule.RollChance(doubleRollPower) then
        count = count + 1
    end
    if LocalPlayer:GetAttribute("IsVip") then
        count = count + 1
    end
    return count, doubleRollPower
end

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoRoll.Value then
            local count, doubleRollPower = getRollCount()
            local ok, results = pcall(function()
                if Toggles.InstantRoll.Value then
                    return netInvoke(Net.Roll, 8, count, doubleRollPower)
                end

                local container = LocalPlayer.PlayerGui.BigRoller.Enabled
                    and LocalPlayer.PlayerGui.BigRoller.RollerContainer
                    or LocalPlayer.PlayerGui.HUD.RollerContainer
                local roll = ClientRollModule.PlayRoll(container, count)
                local result, meta = netInvoke(Net.Roll, 8, count, doubleRollPower)
                if typeof(result) == "table" then
                    ClientRollModule.UpdateRollResult(roll, result, meta)
                end
                return result
            end)

            if ok and typeof(results) == "table" then
                rollsThisSession = rollsThisSession + #results
                RollCountLabel:SetText("Rolls this session: " .. rollsThisSession)
                LastRollLabel:SetText("Last: " .. table.concat(results, ", "))
                task.wait(ROLL_MIN_DELAY)
            else
                task.wait(ROLL_BACKOFF)
            end
        else
            task.wait(0.1)
        end
    end
end)

local CombatGroup = Tabs.Combat:AddLeftGroupbox("Auto Farm")

CombatGroup:AddToggle("KillAura", { Text = "Auto Farm", Default = false })
CombatGroup:AddToggle("OnlyDuringWave", { Text = "Only During Wave", Default = true })
CombatGroup:AddToggle("ApproachEnemy", { Text = "Move To Enemies", Default = true })
CombatGroup:AddDropdown("AuraMode", {
    Text = "Target Mode",
    Values = { "Nearest", "Densest Cluster", "Cycle All" },
    Default = "Densest Cluster",
})
CombatGroup:AddSlider("AuraHover", {
    Text = "Hover Distance",
    Default = 2,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Suffix = " studs",
})
CombatGroup:AddSlider("ClusterRadius", {
    Text = "Cluster Radius",
    Default = 14,
    Min = 4,
    Max = 60,
    Rounding = 0,
    Suffix = " studs",
})
CombatGroup:AddSlider("AttackDelay", {
    Text = "Attack Delay",
    Default = 0.14,
    Min = 0.05,
    Max = 1,
    Rounding = 2,
    Suffix = "s",
})
CombatGroup:AddToggle("IgnoreCooldown", { Text = "Ignore Weapon Cooldown", Default = false })

local function getWeaponCooldown()
    local tier = 1
    for _, skill in SkillsUtility.GetAllOwned(LocalPlayer) do
        local level = tonumber(skill:match("^UnlockWeapon(%d+)$"))
        if level and tier < level then
            tier = level
        end
    end
    local weapon = WeaponsConfig.Melee[WeaponsConfig.MeleeOrder[tier]]
    return weapon and weapon.Stats.Cooldown or 0.1
end

local function getEnemyParts(plot)
    local parts = {}
    local enemies = plot:FindFirstChild("Enemies")
    if not enemies then
        return parts
    end
    for _, enemy in enemies:GetChildren() do
        local part = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
        if part then
            table.insert(parts, part)
        end
    end
    return parts
end

local function getNearest(parts, position)
    local nearest, nearestDistance
    for _, part in parts do
        local distance = (part.Position - position).Magnitude
        if not nearestDistance or distance < nearestDistance then
            nearest = part
            nearestDistance = distance
        end
    end
    return nearest, nearestDistance
end

local function getDensestPoint(parts)
    local radius = Options.ClusterRadius.Value
    local best, bestCount
    for _, anchor in parts do
        local total = Vector3.zero
        local count = 0
        for _, other in parts do
            if (other.Position - anchor.Position).Magnitude <= radius then
                total = total + other.Position
                count = count + 1
            end
        end
        if not bestCount or count > bestCount then
            best = total / count
            bestCount = count
        end
    end
    return best
end

local auraCycleIndex = 1
local auraReturnCFrame = nil

local function moveTo(root, position)
    if not auraReturnCFrame then
        auraReturnCFrame = root.CFrame
    end
    root.CFrame = CFrame.new(position + Vector3.new(0, Options.AuraHover.Value, 0))
end

local function releaseCharacter(root)
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")

    if auraReturnCFrame and root then
        root.CFrame = auraReturnCFrame
    end
    auraReturnCFrame = nil

    if humanoid then
        humanoid.PlatformStand = false
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

local function swing()
    LocalPlayer:SetAttribute("LastMeleeSwing", os.clock())
    pcall(function()
        netFire(Net.AttackWeapon, true)
    end)
end

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.KillAura.Value then
            local plot = getMyPlot()
            local character = LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")

            if plot and root and (ClientBuildModule.WaveActive or not Toggles.OnlyDuringWave.Value) then
                local parts = getEnemyParts(plot)
                local mode = Options.AuraMode.Value

                if #parts == 0 then
                    releaseCharacter(root)
                elseif Toggles.ApproachEnemy.Value then
                    if mode == "Cycle All" then
                        auraCycleIndex = auraCycleIndex % #parts + 1
                        moveTo(root, parts[auraCycleIndex].Position)
                    elseif mode == "Densest Cluster" then
                        moveTo(root, getDensestPoint(parts))
                    else
                        local nearest = getNearest(parts, root.Position)
                        moveTo(root, nearest.Position)
                    end
                end

                if #parts > 0 then
                    swing()
                end
            elseif auraReturnCFrame and root then
                releaseCharacter(root)
            end

            local delay = Options.AttackDelay.Value
            if not Toggles.IgnoreCooldown.Value then
                delay = math.max(delay, getWeaponCooldown())
            end
            task.wait(delay)
        else
            if auraReturnCFrame then
                local character = LocalPlayer.Character
                releaseCharacter(character and character:FindFirstChild("HumanoidRootPart"))
            end
            task.wait(0.1)
        end
    end
end)

local WaveGroup = Tabs.Combat:AddLeftGroupbox("Waves")

WaveGroup:AddToggle("AutoStartWave", { Text = "Auto Start Wave", Default = false })
WaveGroup:AddToggle("AutoStopAtWave", { Text = "Auto Stop At Wave", Default = false })
WaveGroup:AddSlider("StopWaveNumber", {
    Text = "Stop At Wave",
    Default = 50,
    Min = 1,
    Max = 500,
    Rounding = 0,
})
WaveGroup:AddSlider("WaveStartDelay", {
    Text = "Start Delay",
    Default = 2,
    Min = 0.5,
    Max = 30,
    Rounding = 1,
    Suffix = "s",
})
local WaveStatus = WaveGroup:AddLabel("Idle", true)

local function getCurrentWave()
    local counter = LocalPlayer.PlayerGui.HUD.Wave.Layout.WaveCounter.Counter
    return tonumber(counter.Text:match("Wave (%d+)")) or 0
end

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoStartWave.Value or Toggles.AutoStopAtWave.Value then
            local wave = getCurrentWave()
            local active = ClientBuildModule.WaveActive
            local reached = Toggles.AutoStopAtWave.Value and wave >= Options.StopWaveNumber.Value

            if reached then
                WaveStatus:SetText(string.format("Reached wave %d, stopped", wave))
                if active then
                    netFire(Net.SetAutoWave, true, false)
                    netFire(Net.StopWave, true)
                end
            elseif Toggles.AutoStartWave.Value then
                if active then
                    WaveStatus:SetText(string.format("Wave %d running", wave))
                else
                    WaveStatus:SetText("Starting wave")
                    ClientBuildModule.ExitBuildMode()
                    netFire(Net.StartWave, true)
                    task.wait(Options.WaveStartDelay.Value)
                end
            end
        else
            WaveStatus:SetText("Idle")
        end
        task.wait(1)
    end
end)

local GoldGroup = Tabs.Combat:AddRightGroupbox("Gold")

GoldGroup:AddToggle("AutoCollectGold", { Text = "Auto Collect Gold", Default = false })
GoldGroup:AddSlider("GoldRange", {
    Text = "Search Range",
    Default = 250,
    Min = 25,
    Max = 1000,
    Rounding = 0,
    Suffix = " studs",
})

local goldReturnCFrame = nil

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoCollectGold.Value then
            local temp = workspace:FindFirstChild("Temp")
            local character = LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local busy = Toggles.KillAura.Value and Toggles.ApproachEnemy.Value

            if temp and root and not busy then
                local nearest, nearestDistance
                for _, part in temp:GetDescendants() do
                    if part:IsA("BasePart") and (part.Name == "Coin" or part.Name == "CoinBag") then
                        local distance = (part.Position - root.Position).Magnitude
                        if distance <= Options.GoldRange.Value
                            and (not nearestDistance or distance < nearestDistance) then
                            nearest = part
                            nearestDistance = distance
                        end
                    end
                end

                if nearest then
                    if not goldReturnCFrame then
                        goldReturnCFrame = root.CFrame
                    end
                    root.CFrame = CFrame.new(nearest.Position)
                elseif goldReturnCFrame then
                    root.CFrame = goldReturnCFrame
                    goldReturnCFrame = nil
                end
            end
            task.wait(0.15)
        else
            goldReturnCFrame = nil
            task.wait(0.5)
        end
    end
end)

local SkillsGroup = Tabs.Combat:AddRightGroupbox("Skills")

SkillsGroup:AddToggle("AutoBuySkills", { Text = "Auto Buy Affordable Skills", Default = false })
SkillsGroup:AddSlider("SkillDelay", {
    Text = "Buy Delay",
    Default = 0.5,
    Min = 0.1,
    Max = 5,
    Rounding = 1,
    Suffix = "s",
})

local function getPurchasableSkills()
    local money = client:get("Money")
    local rolls = client:get("Rolls")
    local owned = { TreeStart = true }
    local seen = {}
    local purchasable = {}

    for _, skill in SkillsUtility.GetAllOwned(LocalPlayer) do
        owned[skill] = true
    end

    for skill in owned do
        local config = SkillsUtility.GetConfig(skill)
        if config then
            for _, connection in config.Connections do
                if not owned[connection] and not seen[connection] then
                    seen[connection] = true
                    local target = SkillsUtility.GetConfig(connection)
                    if target and not target.SectionLink
                        and money >= (target.MoneyPrice or 0)
                        and rolls >= (target.RollsPrice or 0) then
                        table.insert(purchasable, connection)
                    end
                end
            end
        end
    end

    return purchasable
end

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoBuySkills.Value then
            for _, skill in getPurchasableSkills() do
                if Library.Unloaded or not Toggles.AutoBuySkills.Value then
                    break
                end
                pcall(function()
                    netInvoke(Net.BuySkill, 8, skill)
                end)
                task.wait(Options.SkillDelay.Value)
            end
            task.wait(Options.SkillDelay.Value)
        else
            task.wait(0.5)
        end
    end
end)

local PlaceGroup = Tabs.Build:AddLeftGroupbox("Auto Place")

PlaceGroup:AddToggle("AutoPlace", { Text = "Auto Place", Default = false })
PlaceGroup:AddToggle("AutoPlaceRandom", { Text = "Auto Place Random", Default = false })
PlaceGroup:AddDropdown("PlaceBuildings", {
    Text = "Buildings",
    Values = {},
    Multi = true,
    Default = {},
})
PlaceGroup:AddButton({
    Text = "Refresh Buildings",
    Func = function()
        local values = {}
        for identifier in pairs(getOwnedCounts()) do
            table.insert(values, identifier)
        end
        table.sort(values)
        Options.PlaceBuildings:SetValues(values)
        Library:Notify(string.format("Found %d owned buildings", #values))
    end,
})
PlaceGroup:AddDropdown("PlaceCategory", {
    Text = "Category",
    Values = { "Any", "Block", "Turret" },
    Default = "Any",
})
PlaceGroup:AddDropdown("PlaceMinRarity", {
    Text = "Minimum Rarity",
    Values = RARITY_ORDER,
    Default = "Basic",
})
PlaceGroup:AddDropdown("PlaceRotation", {
    Text = "Rotation",
    Values = { "0", "90", "180", "270" },
    Default = "0",
})

local PlaceOptions = Tabs.Build:AddRightGroupbox("Placement Rules")

PlaceOptions:AddSlider("PlaceKeep", {
    Text = "Keep In Inventory",
    Default = 0,
    Min = 0,
    Max = 50,
    Rounding = 0,
})
PlaceOptions:AddSlider("PlaceMax", {
    Text = "Max Per Building",
    Default = 40,
    Min = 1,
    Max = 200,
    Rounding = 0,
})
PlaceOptions:AddToggle("RespectLimit", { Text = "Respect Placement Limit", Default = true })
PlaceOptions:AddToggle("StopOnFull", { Text = "Pause When Nothing Fits", Default = true })
PlaceOptions:AddSlider("PlaceDelay", {
    Text = "Place Delay",
    Default = 0.2,
    Min = 0.05,
    Max = 3,
    Rounding = 2,
    Suffix = "s",
})
PlaceOptions:AddButton({
    Text = "Clear My Plot",
    Func = function()
        netFire(Net.ClearPlot, true)
        clearReserved()
        Library:Notify("Cleared plot")
    end,
})

local function passesFilters(identifier)
    local config = BuildingsUtility.GetConfig(identifier)
    if not config then
        return false
    end
    local category = Options.PlaceCategory.Value
    if category ~= "Any" and config.Category ~= category then
        return false
    end
    local minimum = RARITY_INDEX[Options.PlaceMinRarity.Value] or 1
    return (RARITY_INDEX[config.Rarity] or 1) >= minimum
end

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoPlace.Value then
            local plot = getMyPlot()
            if plot then
                local limit = SharedPlacementModule.GetPlacementLimit(LocalPlayer)
                local rotation = tonumber(Options.PlaceRotation.Value) or 0
                local placedPerBuilding = {}
                local placedThisPass = 0
                local full = false

                clearReserved()

                for identifier, selected in Options.PlaceBuildings.Value do
                    if Library.Unloaded or not Toggles.AutoPlace.Value or full then
                        break
                    end
                    if selected and passesFilters(identifier) then
                        local config = BuildingsUtility.GetConfig(identifier)
                        local useRotation = config.Category == "Turret" and 0 or rotation

                        while true do
                            if Library.Unloaded or not Toggles.AutoPlace.Value then
                                break
                            end
                            local owned = getOwnedCounts()[identifier] or 0
                            if owned - Options.PlaceKeep.Value <= 0 then
                                break
                            end
                            if (placedPerBuilding[identifier] or 0) >= Options.PlaceMax.Value then
                                break
                            end
                            if Toggles.RespectLimit.Value and placementCount(plot) >= limit then
                                full = true
                                break
                            end

                            local localPosition, size, worldSize = findPlacement(plot, identifier, useRotation)
                            if not localPosition then
                                break
                            end

                            if place(plot, identifier, localPosition, useRotation) then
                                placedThisPass = placedThisPass + 1
                            else
                                reserve(localPosition, worldSize)
                            end
                            placedPerBuilding[identifier] = (placedPerBuilding[identifier] or 0) + 1
                            task.wait(Options.PlaceDelay.Value)
                        end
                    end
                end

                if full or (placedThisPass == 0 and Toggles.StopOnFull.Value) then
                    task.wait(1)
                end
            end
            task.wait(0.5)
        else
            clearReserved()
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoPlaceRandom.Value and not Toggles.AutoPlace.Value then
            local plot = getMyPlot()
            if plot then
                local limit = SharedPlacementModule.GetPlacementLimit(LocalPlayer)
                local rotation = tonumber(Options.PlaceRotation.Value) or 0
                local pool = {}

                for identifier, owned in getOwnedCounts() do
                    if owned - Options.PlaceKeep.Value > 0 and passesFilters(identifier) then
                        table.insert(pool, identifier)
                    end
                end

                if #pool == 0 or (Toggles.RespectLimit.Value and placementCount(plot) >= limit) then
                    clearReserved()
                    task.wait(1)
                else
                    local identifier = pool[math.random(#pool)]
                    local config = BuildingsUtility.GetConfig(identifier)
                    local useRotation = config.Category == "Turret" and 0 or rotation
                    local localPosition, size, worldSize = findPlacement(plot, identifier, useRotation)

                    if localPosition then
                        if not place(plot, identifier, localPosition, useRotation) then
                            reserve(localPosition, worldSize)
                        end
                        task.wait(Options.PlaceDelay.Value)
                    else
                        clearReserved()
                        task.wait(1)
                    end
                end
            else
                task.wait(0.5)
            end
        else
            task.wait(0.5)
        end
    end
end)

local UpgradeGroup = Tabs.Build:AddLeftGroupbox("Auto Upgrade")

UpgradeGroup:AddToggle("AutoUpgrade", { Text = "Auto Upgrade", Default = false })
UpgradeGroup:AddToggle("UpgradeAll", { Text = "Upgrade Everything Unlocked", Default = true })
UpgradeGroup:AddDropdown("UpgradeBuildings", {
    Text = "Buildings",
    Values = {},
    Multi = true,
    Default = {},
})
UpgradeGroup:AddButton({
    Text = "Refresh Upgradable",
    Func = function()
        local values = {}
        for identifier in client:getAll().UnlockedBuildings do
            local config = BuildingsUtility.GetConfig(identifier)
            if config and not BuildingsUtility.HasTrait(identifier, "PercentBest") then
                table.insert(values, identifier)
            end
        end
        table.sort(values)
        Options.UpgradeBuildings:SetValues(values)
        Library:Notify(string.format("Found %d upgradable buildings", #values))
    end,
})
UpgradeGroup:AddSlider("UpgradeMaxLevel", {
    Text = "Max Level",
    Default = 64,
    Min = 2,
    Max = 64,
    Rounding = 0,
})
UpgradeGroup:AddSlider("UpgradeKeepMoney", {
    Text = "Keep Money",
    Default = 0,
    Min = 0,
    Max = 1000000,
    Rounding = 0,
})
UpgradeGroup:AddSlider("UpgradeDelay", {
    Text = "Upgrade Delay",
    Default = 0.2,
    Min = 0.05,
    Max = 3,
    Rounding = 2,
    Suffix = "s",
})
local UpgradeStatus = UpgradeGroup:AddLabel("Idle", true)

local function getUpgradePrice(identifier, level)
    local config = BuildingsUtility.GetConfig(identifier)
    if not config or type(config.UpgradePrice) ~= "function" then
        return nil
    end
    local ok, price = pcall(config.UpgradePrice, level)
    if ok and type(price) == "number" then
        return price
    end
    return nil
end

local function getUpgradeTargets()
    local targets = {}

    if Toggles.UpgradeAll.Value then
        for identifier in client:getAll().UnlockedBuildings do
            table.insert(targets, identifier)
        end
    else
        for identifier, selected in Options.UpgradeBuildings.Value do
            if selected then
                table.insert(targets, identifier)
            end
        end
    end

    table.sort(targets)
    return targets
end

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoUpgrade.Value then
            local upgraded = 0

            for _, identifier in getUpgradeTargets() do
                if Library.Unloaded or not Toggles.AutoUpgrade.Value then
                    break
                end

                local config = BuildingsUtility.GetConfig(identifier)
                if config and not BuildingsUtility.HasTrait(identifier, "PercentBest") then
                    local ceiling = math.min(Options.UpgradeMaxLevel.Value, BuildingsUtility.GetMaxLevel(identifier))

                    while not Library.Unloaded and Toggles.AutoUpgrade.Value do
                        local level = BuildingsUtility.GetLevel(LocalPlayer, identifier)
                        if level >= ceiling then
                            break
                        end

                        local price = getUpgradePrice(identifier, level + 1)
                        if not price or client:get("Money") - Options.UpgradeKeepMoney.Value < price then
                            break
                        end

                        UpgradeStatus:SetText(string.format("Upgrading %s to %d", identifier, level + 1))
                        local ok, result = pcall(netInvoke, Net.UpgradeBuilding, 8, identifier)
                        if not ok or not result then
                            break
                        end

                        upgraded = upgraded + 1
                        task.wait(Options.UpgradeDelay.Value)
                    end
                end
            end

            if upgraded > 0 then
                UpgradeStatus:SetText(string.format("Upgraded %d times", upgraded))
            else
                UpgradeStatus:SetText("Nothing affordable")
            end
            task.wait(1)
        else
            task.wait(0.5)
        end
    end
end)

local CraftGroup = Tabs.Craft:AddLeftGroupbox("Auto Craft")

CraftGroup:AddToggle("AutoCraft", { Text = "Auto Craft", Default = false })
CraftGroup:AddDropdown("CraftRecipes", {
    Text = "Recipes",
    Values = {},
    Multi = true,
    Default = {},
})
CraftGroup:AddButton({
    Text = "Refresh Recipes",
    Func = function()
        local values = {}
        for _, recipe in RecipesUtility.GetUnlockedRecipes(LocalPlayer) do
            table.insert(values, recipe.Identifier)
        end
        table.sort(values)
        Options.CraftRecipes:SetValues(values)
        Library:Notify(string.format("Found %d unlocked recipes", #values))
    end,
})

local CraftOptions = Tabs.Craft:AddRightGroupbox("Craft Rules")

CraftOptions:AddSlider("CraftKeep", {
    Text = "Keep In Inventory",
    Default = 0,
    Min = 0,
    Max = 50,
    Rounding = 0,
})
CraftOptions:AddDropdown("CraftMaxRarity", {
    Text = "Never Consume Above",
    Values = RARITY_ORDER,
    Default = "Lunatic",
})
CraftOptions:AddSlider("CraftDelay", {
    Text = "Craft Delay",
    Default = 1,
    Min = 0.2,
    Max = 10,
    Rounding = 1,
    Suffix = "s",
})
local CraftStatus = CraftOptions:AddLabel("Idle", true)

local function buildCraftState(recipe, counts)
    local state = {}
    local maxRarity = RARITY_INDEX[Options.CraftMaxRarity.Value] or #RARITY_ORDER

    for index, ingredient in recipe.Ingredients do
        if ingredient.Relic then
            return nil, "recipe needs a relic"
        end

        local slot = {}
        local remaining = ingredient.Quantity

        for identifier, owned in counts do
            if remaining <= 0 then
                break
            end
            local building = BuildingsUtility.MakeBuildingFromIdentifier(identifier)
            local config = BuildingsUtility.GetConfig(identifier)
            if config
                and (RARITY_INDEX[config.Rarity] or 1) <= maxRarity
                and RecipesUtility.DoesBuildingMatchIngredient(building, ingredient) then
                local usable = math.min(remaining, owned - Options.CraftKeep.Value)
                if usable > 0 then
                    slot[identifier] = usable
                    counts[identifier] = owned - usable
                    remaining = remaining - usable
                end
            end
        end

        if remaining > 0 then
            return nil, "missing ingredients"
        end
        state[index] = slot
    end

    return state
end

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoCraft.Value then
            for identifier, selected in Options.CraftRecipes.Value do
                if Library.Unloaded or not Toggles.AutoCraft.Value then
                    break
                end
                if selected then
                    local recipe = RecipesUtility.GetConfig(identifier)
                    if recipe then
                        local state, reason = buildCraftState(recipe, getOwnedCounts())
                        if state then
                            CraftStatus:SetText("Crafting " .. identifier)
                            pcall(function()
                                netInvoke(Net.Craft, 8, identifier, state)
                            end)
                            task.wait(Options.CraftDelay.Value)
                        else
                            CraftStatus:SetText(identifier .. ": " .. reason)
                        end
                    end
                end
            end
            task.wait(Options.CraftDelay.Value)
        else
            task.wait(0.5)
        end
    end
end)

local StealGroup = Tabs.Steal:AddLeftGroupbox("Target")

StealGroup:AddDropdown("StealTarget", {
    Text = "Player",
    Values = {},
    Default = nil,
    AllowNull = true,
})
StealGroup:AddButton({
    Text = "Refresh Players",
    Func = function()
        local values = {}
        for _, player in Players:GetPlayers() do
            if player ~= LocalPlayer and GameModule.GetPlayerPlot(player) then
                table.insert(values, player.Name)
            end
        end
        table.sort(values)
        Options.StealTarget:SetValues(values)
        Library:Notify(string.format("Found %d bases", #values))
    end,
})

local StealOptions = Tabs.Steal:AddRightGroupbox("Copy Base")

StealOptions:AddToggle("StealClearFirst", { Text = "Clear My Plot First", Default = true })
StealOptions:AddToggle("StealSubstituteNormal", { Text = "Use Any Owned Variant If Missing", Default = true })
StealOptions:AddSlider("StealDelay", {
    Text = "Place Delay",
    Default = 0.2,
    Min = 0.05,
    Max = 3,
    Rounding = 2,
    Suffix = "s",
})
local StealStatus = StealOptions:AddLabel("Idle", true)

local function readBase(plot)
    local folder = getPlacementFolder(plot)
    local origin = SharedPlacementModule.GetOrigin(plot)
    local entries = {}
    local required = {}
    local skipped = 0

    if not folder then
        return entries, required, skipped
    end

    for _, model in folder:GetChildren() do
        local config = getConfigFromModel(model)
        if config then
            local relative = origin:Inverse() * model:GetPivot()
            local _, yaw = relative:ToOrientation()
            local rotation = math.round(math.deg(yaw) / 90) * 90 % 360
            table.insert(entries, {
                Identifier = config.Identifier,
                Position = relative.Position,
                Rotation = rotation,
            })
            required[config.Identifier] = (required[config.Identifier] or 0) + 1
        else
            skipped = skipped + 1
        end
    end

    return entries, required, skipped
end

local function getAvailableCounts(includePlaced)
    local counts = getOwnedCounts()
    if not includePlaced then
        return counts
    end
    local plot = getMyPlot()
    if not plot then
        return counts
    end
    local _, placed = readBase(plot)
    for identifier, amount in placed do
        counts[identifier] = (counts[identifier] or 0) + amount
    end
    return counts
end

local function getVariantIdentifiers(identifier)
    local building = BuildingsUtility.MakeBuildingFromIdentifier(identifier)
    local variants = {}
    for _, mutation in MUTATION_ORDER do
        if mutation ~= building.Mutation then
            local config = BuildingsUtility.GetConfig({ Name = building.Name, Mutation = mutation })
            if config and config.Identifier ~= identifier then
                table.insert(variants, config.Identifier)
            end
        end
    end
    return variants
end

local function resolveBase(entries, substitute, includePlaced)
    local pool = getAvailableCounts(includePlaced)
    if substitute == nil then
        substitute = Toggles.StealSubstituteNormal.Value
    end
    local resolved = {}
    local pending = {}
    local substituted = {}
    local shortage = {}

    for _, entry in entries do
        local identifier = entry.Identifier
        if (pool[identifier] or 0) > 0 then
            pool[identifier] = pool[identifier] - 1
            table.insert(resolved, entry)
        else
            table.insert(pending, entry)
        end
    end

    for _, entry in pending do
        local identifier = entry.Identifier
        local replacement = nil

        if substitute then
            for _, variant in getVariantIdentifiers(identifier) do
                if (pool[variant] or 0) > 0 then
                    replacement = variant
                    break
                end
            end
        end

        if replacement then
            pool[replacement] = pool[replacement] - 1
            substituted[identifier] = (substituted[identifier] or 0) + 1
            table.insert(resolved, {
                Identifier = replacement,
                Position = entry.Position,
                Rotation = entry.Rotation,
            })
        else
            shortage[identifier] = (shortage[identifier] or 0) + 1
        end
    end

    return resolved, shortage, substituted
end

local function getMaterialReport(required, shortage, substituted, includePlaced)
    local counts = getAvailableCounts(includePlaced)
    local rows = {}

    for identifier, amount in required do
        table.insert(rows, {
            Identifier = identifier,
            Required = amount,
            Owned = counts[identifier] or 0,
            Short = shortage[identifier] or 0,
            Substituted = substituted[identifier] or 0,
        })
    end

    table.sort(rows, function(a, b)
        if (a.Short > 0) ~= (b.Short > 0) then
            return a.Short > 0
        end
        return a.Identifier < b.Identifier
    end)

    local lines = {}
    for _, row in rows do
        if row.Short > 0 then
            table.insert(lines, string.format(
                "<font color=\"rgb(255,70,70)\">[-] %s %d/%d</font>",
                row.Identifier, row.Owned, row.Required))
        elseif row.Substituted > 0 then
            table.insert(lines, string.format(
                "<font color=\"rgb(255,190,60)\">[~] %s %d/%d (%d swapped)</font>",
                row.Identifier, row.Owned, row.Required, row.Substituted))
        else
            table.insert(lines, string.format(
                "<font color=\"rgb(90,220,120)\">[+] %s %d/%d</font>",
                row.Identifier, row.Owned, row.Required))
        end
    end

    return table.concat(lines, "\n")
end

local function getTargetPlot()
    local name = Options.StealTarget.Value
    if not name or name == "" then
        return nil, "no target selected"
    end
    local player = Players:FindFirstChild(name)
    if not player then
        return nil, "player left"
    end
    local plot = GameModule.GetPlayerPlot(player)
    if not plot then
        return nil, "player has no plot"
    end
    return plot
end

StealOptions:AddButton({
    Text = "Check Materials",
    Func = function()
        local plot, reason = getTargetPlot()
        if not plot then
            StealStatus:SetText(reason)
            return
        end
        local includePlaced = Toggles.StealClearFirst.Value
        local entries, required, skipped = readBase(plot)
        local resolved, shortage, substituted = resolveBase(entries, nil, includePlaced)
        local types = 0
        for _ in required do
            types = types + 1
        end

        local shortTypes = 0
        for _ in shortage do
            shortTypes = shortTypes + 1
        end

        local swapped = 0
        for _, amount in substituted do
            swapped = swapped + amount
        end

        local header = shortTypes == 0
            and string.format("<font color=\"rgb(90,220,120)\">Ready: %d buildings, %d types</font>", #resolved, types)
            or string.format("<font color=\"rgb(255,70,70)\">Missing %d of %d types</font>", shortTypes, types)

        if swapped > 0 then
            header = header .. string.format(
                "\n<font color=\"rgb(255,190,60)\">%d placed as other variants</font>", swapped)
        end

        if skipped > 0 then
            header = header .. string.format(
                "\n<font color=\"rgb(255,190,60)\">%d models not recognised, they will be left out</font>", skipped)
        end

        local limit = SharedPlacementModule.GetPlacementLimit(LocalPlayer)
        if #resolved > limit then
            header = header .. string.format(
                "\n<font color=\"rgb(255,70,70)\">Your placement limit is %d, only the first %d will fit</font>",
                limit, limit)
        end

        StealStatus:SetText(header .. "\n" .. getMaterialReport(required, shortage, substituted, includePlaced))
    end,
})

local function placeEntries(myPlot, resolved, status, placeDelay)
    local limit = SharedPlacementModule.GetPlacementLimit(LocalPlayer)
    local placed = 0
    local failed = 0

    for index, entry in resolved do
        if Library.Unloaded then
            break
        end
        if placementCount(myPlot) >= limit then
            status:SetText(string.format("Placement limit of %d reached", limit))
            break
        end
        status:SetText(string.format("Placing %d/%d", index, #resolved))
        if place(myPlot, entry.Identifier, entry.Position, entry.Rotation) then
            placed = placed + 1
        else
            failed = failed + 1
        end
        task.wait(placeDelay)
    end

    return placed, failed
end

local stealing = false

StealOptions:AddButton({
    Text = "Steal Base",
    Func = function()
        if stealing then
            return
        end
        stealing = true

        task.spawn(function()
            local targetPlot, reason = getTargetPlot()
            if not targetPlot then
                StealStatus:SetText(reason)
                stealing = false
                return
            end

            local myPlot = getMyPlot()
            if not myPlot then
                StealStatus:SetText("no plot of your own")
                stealing = false
                return
            end

            local entries, required, skipped = readBase(targetPlot)
            local preview, shortage, substituted = resolveBase(entries, nil, Toggles.StealClearFirst.Value)

            if next(shortage) then
                StealStatus:SetText(getMaterialReport(
                    required, shortage, substituted, Toggles.StealClearFirst.Value))
                stealing = false
                return
            end

            if Toggles.StealClearFirst.Value then
                netFire(Net.ClearPlot, true)
                task.wait(1)
            end

            local resolved = resolveBase(entries)
            if #resolved < #preview then
                StealStatus:SetText("plot did not clear in time, try again")
                stealing = false
                return
            end

            local placed, failed = placeEntries(myPlot, resolved, StealStatus, Options.StealDelay.Value)

            local swapped = 0
            for _, amount in substituted do
                swapped = swapped + amount
            end

            local summary = string.format(
                "Copied %d of %d buildings (%d as other variants)", placed, #entries, swapped)
            if failed > 0 then
                summary = summary .. string.format(
                    "\n<font color=\"rgb(255,70,70)\">%d were rejected by the game</font>", failed)
            end
            if skipped > 0 then
                summary = summary .. string.format(
                    "\n<font color=\"rgb(255,190,60)\">%d models were not recognised</font>", skipped)
            end

            StealStatus:SetText(summary)
            stealing = false
        end)
    end,
})

local LAYOUT_FOLDER = "OuroborosHub/build-a-base-rng/layouts"

local LayoutGroup = Tabs.Build:AddRightGroupbox("Layouts")

LayoutGroup:AddInput("LayoutName", {
    Text = "Name",
    Default = "",
    Placeholder = "layout name",
})
LayoutGroup:AddDropdown("LayoutFile", {
    Text = "Saved Layouts",
    Values = {},
    Default = nil,
    AllowNull = true,
})
LayoutGroup:AddToggle("LayoutClearFirst", { Text = "Clear My Plot First", Default = true })
LayoutGroup:AddToggle("LayoutSubstitute", { Text = "Use Any Owned Variant If Missing", Default = true })
LayoutGroup:AddSlider("LayoutDelay", {
    Text = "Place Delay",
    Default = 0.2,
    Min = 0.05,
    Max = 3,
    Rounding = 2,
    Suffix = "s",
})
local LayoutStatus = LayoutGroup:AddLabel("Idle", true)

local function ensureLayoutFolder()
    local path = ""
    for segment in LAYOUT_FOLDER:gmatch("[^/]+") do
        path = path == "" and segment or (path .. "/" .. segment)
        if not isfolder(path) then
            makefolder(path)
        end
    end
end

local function layoutPath(name)
    return LAYOUT_FOLDER .. "/" .. name .. ".json"
end

local function refreshLayouts()
    ensureLayoutFolder()
    local values = {}
    for _, file in listfiles(LAYOUT_FOLDER) do
        local name = file:match("([^/\\]+)%.json$")
        if name then
            table.insert(values, name)
        end
    end
    table.sort(values)
    Options.LayoutFile:SetValues(values)
    return values
end

LayoutGroup:AddButton({
    Text = "Save Current Base",
    Func = function()
        local name = Options.LayoutName.Value
        if not name or name:gsub("%s", "") == "" then
            LayoutStatus:SetText("enter a name first")
            return
        end
        local plot = getMyPlot()
        if not plot then
            LayoutStatus:SetText("no plot of your own")
            return
        end

        local entries = readBase(plot)
        local data = {}
        for _, entry in entries do
            table.insert(data, {
                Identifier = entry.Identifier,
                X = entry.Position.X,
                Y = entry.Position.Y,
                Z = entry.Position.Z,
                Rotation = entry.Rotation,
            })
        end

        ensureLayoutFolder()
        writefile(layoutPath(name), HttpService:JSONEncode(data))
        refreshLayouts()
        Options.LayoutFile:SetValue(name)
        LayoutStatus:SetText(string.format("Saved %d buildings as %s", #data, name))
    end,
})

LayoutGroup:AddButton({
    Text = "Refresh Layouts",
    Func = function()
        local values = refreshLayouts()
        Library:Notify(string.format("Found %d saved layouts", #values))
    end,
})

local function readLayout(name)
    local path = layoutPath(name)
    if not isfile(path) then
        return nil, "layout file is gone"
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok or type(data) ~= "table" then
        return nil, "layout file is corrupt"
    end

    local entries = {}
    local required = {}
    for _, row in data do
        table.insert(entries, {
            Identifier = row.Identifier,
            Position = Vector3.new(row.X, row.Y, row.Z),
            Rotation = row.Rotation,
        })
        required[row.Identifier] = (required[row.Identifier] or 0) + 1
    end
    return entries, required
end

LayoutGroup:AddButton({
    Text = "Check Layout Materials",
    Func = function()
        local name = Options.LayoutFile.Value
        if not name or name == "" then
            LayoutStatus:SetText("no layout selected")
            return
        end

        local entries, required = readLayout(name)
        if not entries then
            LayoutStatus:SetText(required)
            return
        end

        local includePlaced = Toggles.LayoutClearFirst.Value
        local resolved, shortage, substituted = resolveBase(
            entries, Toggles.LayoutSubstitute.Value, includePlaced)
        LayoutStatus:SetText(string.format("%d of %d placeable\n", #resolved, #entries)
            .. getMaterialReport(required, shortage, substituted, includePlaced))
    end,
})

local buildingLayout = false

LayoutGroup:AddButton({
    Text = "Build Layout",
    Func = function()
        if buildingLayout then
            return
        end
        buildingLayout = true

        task.spawn(function()
            local name = Options.LayoutFile.Value
            if not name or name == "" then
                LayoutStatus:SetText("no layout selected")
                buildingLayout = false
                return
            end

            local entries, required = readLayout(name)
            if not entries then
                LayoutStatus:SetText(required)
                buildingLayout = false
                return
            end

            local myPlot = getMyPlot()
            if not myPlot then
                LayoutStatus:SetText("no plot of your own")
                buildingLayout = false
                return
            end

            local _, shortage, substituted = resolveBase(
                entries, Toggles.LayoutSubstitute.Value, Toggles.LayoutClearFirst.Value)

            if Toggles.LayoutClearFirst.Value then
                netFire(Net.ClearPlot, true)
                task.wait(1)
            end

            local resolved = resolveBase(entries, Toggles.LayoutSubstitute.Value)
            local placed = placeEntries(myPlot, resolved, LayoutStatus, Options.LayoutDelay.Value)

            local missing = #entries - placed
            if missing > 0 then
                LayoutStatus:SetText(string.format("Built %d, missing %d\n", placed, missing)
                    .. getMaterialReport(required, shortage, substituted, false))
            else
                LayoutStatus:SetText(string.format("Built %d buildings from %s", placed, name))
            end
            buildingLayout = false
        end)
    end,
})

LayoutGroup:AddButton({
    Text = "Delete Layout",
    Func = function()
        local name = Options.LayoutFile.Value
        if not name or name == "" then
            LayoutStatus:SetText("no layout selected")
            return
        end
        if isfile(layoutPath(name)) then
            delfile(layoutPath(name))
        end
        refreshLayouts()
        LayoutStatus:SetText("Deleted " .. name)
    end,
})

pcall(refreshLayouts)

local PerfGroup = Tabs.Settings:AddRightGroupbox("Performance")

local hiddenParts = {}
local hiddenEffects = {}

local function hideInstance(instance)
    if instance:IsA("BasePart") then
        if hiddenParts[instance] == nil then
            hiddenParts[instance] = { instance.Transparency, instance.CastShadow }
        end
        instance.Transparency = 1
        instance.CastShadow = false
    elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam")
        or instance:IsA("Smoke") or instance:IsA("Fire") or instance:IsA("Sparkles")
        or instance:IsA("Light") then
        if hiddenEffects[instance] == nil then
            hiddenEffects[instance] = instance.Enabled
        end
        instance.Enabled = false
    end
end

local function restoreParts()
    for part, state in hiddenParts do
        if part.Parent then
            part.Transparency = state[1]
            part.CastShadow = state[2]
        end
    end
    table.clear(hiddenParts)
end

local function restoreEffects()
    for effect, enabled in hiddenEffects do
        if effect.Parent then
            effect.Enabled = enabled
        end
    end
    table.clear(hiddenEffects)
end

PerfGroup:AddToggle("HideOtherPlots", {
    Text = "Hide Other Plots",
    Default = false,
    Callback = function(value)
        if not value then
            restoreParts()
        end
    end,
})
PerfGroup:AddToggle("NoParticles", {
    Text = "Disable Particles And Effects",
    Default = false,
    Callback = function(value)
        if not value then
            restoreEffects()
        end
    end,
})
PerfGroup:AddToggle("LowGraphics", {
    Text = "Low Graphics",
    Default = false,
    Callback = function(value)
        pcall(function()
            Lighting.GlobalShadows = not value
            if value then
                Lighting.Technology = Enum.Technology.Compatibility
            end
            settings().Rendering.QualityLevel = value
                and Enum.QualityLevel.Level01
                or Enum.QualityLevel.Automatic
            workspace.Terrain.WaterWaveSize = value and 0 or 0.15
            workspace.Terrain.WaterReflectance = value and 0 or 1
            workspace.Terrain.Decoration = not value
        end)
    end,
})
PerfGroup:AddToggle("NoRender", {
    Text = "Disable 3D Rendering",
    Default = false,
    Callback = function(value)
        pcall(function()
            RunService:Set3dRenderingEnabled(not value)
        end)
    end,
})
PerfGroup:AddSlider("FpsCap", {
    Text = "FPS Cap",
    Default = 240,
    Min = 15,
    Max = 240,
    Rounding = 0,
    Callback = function(value)
        pcall(function()
            setfpscap(value)
        end)
    end,
})

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.HideOtherPlots.Value then
            local plots = workspace:FindFirstChild("Plots")
            local myPlot = getMyPlot()
            if plots then
                for _, plot in plots:GetChildren() do
                    if plot ~= myPlot then
                        for _, instance in plot:GetDescendants() do
                            hideInstance(instance)
                        end
                    end
                end
            end
        end

        if Toggles.NoParticles.Value then
            for _, instance in workspace:GetDescendants() do
                if not instance:IsA("BasePart") then
                    hideInstance(instance)
                end
            end
        end
        task.wait(2)
    end
end)

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu")

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

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Menu keybind",
})

MenuGroup:AddButton("Unload", function()
    Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

Library:OnUnload(function()
    antiAfkBeganConnection:Disconnect()
    antiAfkChangedConnection:Disconnect()
    restoreParts()
    restoreEffects()
    pcall(function()
        RunService:Set3dRenderingEnabled(true)
    end)
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("OuroborosHub")
SaveManager:SetFolder("OuroborosHub/build-a-base-rng")
ThemeManager:SaveDefault("Mint")
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()
SaveManager:LoadAutoloadConfig()
