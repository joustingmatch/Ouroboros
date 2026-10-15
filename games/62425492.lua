local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local function findIn(parent, ...)
    local node = parent
    for _, name in ipairs({ ... }) do
        if not node then return nil end
        node = node:FindFirstChild(name)
    end
    return node
end

local ServiceRegistry
do
    local sr = findIn(ReplicatedStorage, "Modules", "ServiceRegistry")
    if sr then
        local ok, mod = pcall(require, sr)
        if ok then ServiceRegistry = mod end
    end
end

local function getService(name, timeout)
    if not ServiceRegistry then return nil end
    if ServiceRegistry.WaitFor then
        local ok, svc = pcall(function() return ServiceRegistry.WaitFor(name, timeout or 10) end)
        if ok then return svc end
    end
    local ok, svc = pcall(function() return ServiceRegistry.Get(name) end)
    return ok and svc or nil
end

local httpGet = game.HttpGet or game.HttpGetAsync
local function fetch(url)
    return httpGet(game, url)
end

local Library = loadstring(fetch("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local SaveManager = loadstring(fetch("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(fetch("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

local GameStateRemotes = ReplicatedStorage:FindFirstChild("GameStateRemotes")
local WaveRemotes = ReplicatedStorage:FindFirstChild("WaveRemotes")
local UpgradeRemotes = ReplicatedStorage:FindFirstChild("UpgradeRemotes")
local GearRemotes = ReplicatedStorage:FindFirstChild("GearRemotes")

local GearData
do
    local mod = findIn(ReplicatedStorage, "Data", "GearData")
    if mod then
        local ok, m = pcall(require, mod)
        if ok then GearData = m end
    end
end

local function fireRemote(remote, ...)
    if remote then
        pcall(function(...) remote:FireServer(...) end, ...)
    end
end

local AutoReplayEnabled = false
local hasVotedReplay = false

if GameStateRemotes then
    local GameOverStarted = GameStateRemotes:FindFirstChild("GameOverStarted")
    local GameOverEnded = GameStateRemotes:FindFirstChild("GameOverEnded")
    local VotePlayAgain = GameStateRemotes:FindFirstChild("VotePlayAgain")

    if GameOverStarted then
        GameOverStarted.OnClientEvent:Connect(function()
            if AutoReplayEnabled and not hasVotedReplay and VotePlayAgain then
                hasVotedReplay = true
                task.delay(1, function()
                    fireRemote(VotePlayAgain)
                end)
            end
        end)
    end

    if GameOverEnded then
        GameOverEnded.OnClientEvent:Connect(function()
            hasVotedReplay = false
        end)
    end
end

local AutoNextWaveEnabled = false

task.spawn(function()
    local SettingsClient = getService("SettingsClient", 20)
    if SettingsClient then
        task.spawn(function()
            while true do
                if AutoNextWaveEnabled and SettingsClient:Get("AutoVote") ~= true then
                    pcall(function() SettingsClient:Set("AutoVote", true) end)
                elseif not AutoNextWaveEnabled and SettingsClient:Get("AutoVote") == true then
                    pcall(function() SettingsClient:Set("AutoVote", false) end)
                end
                task.wait(1)
            end
        end)
    elseif WaveRemotes then
        local SkipUpdate = WaveRemotes:FindFirstChild("SkipUpdate")
        local SkipVote = WaveRemotes:FindFirstChild("SkipVote")
        if SkipUpdate then
            SkipUpdate.OnClientEvent:Connect(function(data)
                if AutoNextWaveEnabled and data and data.Action == "SpawningComplete" then
                    fireRemote(SkipVote, true)
                end
            end)
        end
    end
end)

local AutoSkipWaveEnabled = false

task.spawn(function()
    local SkipVote = WaveRemotes and WaveRemotes:FindFirstChild("SkipVote")
    local SkipUpdate = WaveRemotes and WaveRemotes:FindFirstChild("SkipUpdate")
    if not SkipVote then return end

    if SkipUpdate then
        SkipUpdate.OnClientEvent:Connect(function(data)
            if AutoSkipWaveEnabled and data
                and (data.Action == "SpawningComplete" or data.Action == "Update") then
                fireRemote(SkipVote, true)
            end
        end)
    end

    while true do
        if AutoSkipWaveEnabled then
            fireRemote(SkipVote, true)
        end
        task.wait(2)
    end
end)

local AutoEquipWeaponEnabled = false

task.spawn(function()
    while true do
        if AutoEquipWeaponEnabled then
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if character and humanoid and not character:FindFirstChildOfClass("Tool") then
                local backpack = LocalPlayer:FindFirstChild("Backpack")
                local tool = backpack and backpack:FindFirstChildOfClass("Tool")
                if tool then
                    pcall(function() humanoid:EquipTool(tool) end)
                end
            end
        end
        task.wait(0.5)
    end
end)

local HideCrosshairEnabled = false

task.spawn(function()
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    while true do
        local gui = PlayerGui:FindFirstChild("CrosshairGui")
        if gui then
            local target = not HideCrosshairEnabled
            if gui.Enabled ~= target then
                gui.Enabled = target
            end
        end
        task.wait(0.25)
    end
end)

local AutoUpgradeHealthEnabled = false
local AutoUpgradeWeaponEnabled = false

task.spawn(function()
    local PurchaseHealthUpgrade = UpgradeRemotes and UpgradeRemotes:FindFirstChild("PurchaseHealthUpgrade")
    local PurchaseWeaponUpgrade = UpgradeRemotes and UpgradeRemotes:FindFirstChild("PurchaseWeaponUpgrade")
    while true do
        if AutoUpgradeHealthEnabled then
            fireRemote(PurchaseHealthUpgrade)
        end
        if AutoUpgradeWeaponEnabled then
            fireRemote(PurchaseWeaponUpgrade)
        end
        task.wait(1)
    end
end)

local AutoUseGearEnabled = false
local SelectedGearNames = {}
local GearPurchase = GearRemotes and GearRemotes:FindFirstChild("GearPurchase")

local GearDisplayToKey = {}
local GearDisplayList = {}

if GearData then
    local ok, names = pcall(function() return GearData.GetAllGearNames() end)
    if ok and names then
        table.sort(names)
        for _, key in ipairs(names) do
            local cfgOk, cfg = pcall(function() return GearData.GetConfig(key) end)
            local display = (cfgOk and cfg and cfg.DisplayName) or key
            GearDisplayToKey[display] = key
            table.insert(GearDisplayList, display)
        end
    end
end

local nextGearFire = {}

task.spawn(function()
    while true do
        if AutoUseGearEnabled and GearPurchase then
            local now = os.clock()
            for _, key in ipairs(SelectedGearNames) do
                if not nextGearFire[key] or now >= nextGearFire[key] then
                    local cooldown = 1
                    if GearData then
                        local ok, cfg = pcall(function() return GearData.GetConfig(key) end)
                        if ok and cfg and cfg.Cooldown then
                            cooldown = cfg.Cooldown
                        end
                    end
                    fireRemote(GearPurchase, key)
                    nextGearFire[key] = now + math.max(cooldown, 0.1)
                end
            end
        end
        task.wait(0.1)
    end
end)

local KillAuraEnabled = false
local KillAuraRadius = 60
local KILL_AURA_TICK = 0.03
local KILL_AURA_MAX_TARGETS = 18

local GunHit = nil
do
    local GunRemotes = ReplicatedStorage:FindFirstChild("GunRemotes")
    if GunRemotes then
        GunHit = GunRemotes:FindFirstChild("GunHit")
    end
end

local function getZombiePosition(record)
    if not record then return nil end
    local model = record.Model
    if not (model and model.Parent) then return nil end
    local pp = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
    return pp and pp.Position or nil
end

local function resolveGunName(gunClient)
    if gunClient and gunClient.EquippedGun then
        return gunClient.EquippedGun.Name
    end
    local character = LocalPlayer.Character
    if character then
        local tool = character:FindFirstChildOfClass("Tool")
        if tool then return tool.Name end
    end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        local tool = backpack:FindFirstChildOfClass("Tool")
        if tool then return tool.Name end
    end
    return "Pistol"
end

local function isAlive(rec)
    return rec and not rec.IsDying and (rec.Health == nil or rec.Health > 0)
end

local function collectTargets(ZombieClient, root, radius, maxTargets)
    local ok, ids = pcall(function()
        return ZombieClient:GetNearbyZombieIds(root.Position, radius)
    end)
    if not ok or not ids then return {} end
    local zombies = ZombieClient.Zombies

    local alive = {}
    for _, id in ipairs(ids) do
        local rec = zombies and zombies[id]
        if isAlive(rec) then
            alive[#alive + 1] = { id = id, hp = rec.Health or math.huge, rec = rec }
        end
    end
    table.sort(alive, function(a, b) return a.hp < b.hp end)

    local out = {}
    for i = 1, math.min(#alive, maxTargets) do
        local pos = getZombiePosition(alive[i].rec)
        if pos then
            out[#out + 1] = { id = alive[i].id, pos = pos }
        end
    end
    return out
end

task.spawn(function()
    local ZombieClient = getService("ZombieClient", 30)
    local GunClient = getService("GunClient", 30)
    while true do
        if KillAuraEnabled and GunHit and ZombieClient then
            local character = LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root then
                local gunName = resolveGunName(GunClient)
                local targets = collectTargets(ZombieClient, root, KillAuraRadius, KILL_AURA_MAX_TARGETS)
                for _, t in ipairs(targets) do
                    pcall(function() GunHit:FireServer(gunName, t.id, t.pos) end)
                end
            end
        end
        task.wait(KILL_AURA_TICK)
    end
end)

local RapidFireEnabled = false
local RapidFireInterval = 0.02

task.spawn(function()
    local GunClient = getService("GunClient", 30)
    local originalRate = setmetatable({}, { __mode = "k" })
    while true do
        local cfg = GunClient and GunClient.EquippedConfig
        if cfg then
            if RapidFireEnabled then
                if originalRate[cfg] == nil then
                    originalRate[cfg] = cfg.FireRate
                end
                if cfg.FireRate ~= RapidFireInterval then
                    cfg.FireRate = RapidFireInterval
                end
            elseif originalRate[cfg] ~= nil then
                cfg.FireRate = originalRate[cfg]
                originalRate[cfg] = nil
            end
        end
        task.wait(0.1)
    end
end)

local Window = Library:CreateWindow{
    Title = `Arena Auto Farm {Library.Version}`,
    SubTitle = "Fluent Renewed",
    TabWidth = 160,
    Size = UDim2.fromOffset(560, 460),
    Resize = true,
    MinSize = Vector2.new(470, 380),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
}

local Tabs = {
    Main = Window:CreateTab{ Title = "Main", Icon = "swords" },
    Gears = Window:CreateTab{ Title = "Gears", Icon = "package" },
    Settings = Window:CreateTab{ Title = "Settings", Icon = "settings" }
}

local Options = Library.Options

local DISCORD_INVITE = "https://discord.gg/f3dJhDgyTq"
local copyToClipboard = setclipboard or toclipboard or set_clipboard or (writeclipboard)

local function addDiscordButton(tab)
    tab:CreateButton{
        Title = "Join Discord for Dupes / Keyless Scripts",
        Description = "Click to copy the invite link to your clipboard",
        Callback = function()
            local ok = false
            if copyToClipboard then
                ok = pcall(copyToClipboard, DISCORD_INVITE)
            end
            Library:Notify{
                Title = "Discord",
                Content = ok and "Invite copied to clipboard!" or "Couldn't copy automatically",
                SubContent = DISCORD_INVITE,
                Duration = 6
            }
        end
    }
end

for _, tab in pairs(Tabs) do
    addDiscordButton(tab)
end

Tabs.Main:CreateToggle("AutoReplay", { Title = "Auto Replay", Default = false })
Options.AutoReplay:OnChanged(function()
    AutoReplayEnabled = Options.AutoReplay.Value
end)

Tabs.Main:CreateToggle("AutoNextWave", { Title = "Auto Next Wave", Default = false })
Options.AutoNextWave:OnChanged(function()
    AutoNextWaveEnabled = Options.AutoNextWave.Value
end)

Tabs.Main:CreateToggle("AutoSkipWave", {
    Title = "Auto Skip Wave",
    Description = "Casts the skip vote as soon as it's available each wave",
    Default = false
})
Options.AutoSkipWave:OnChanged(function()
    AutoSkipWaveEnabled = Options.AutoSkipWave.Value
end)

Tabs.Main:CreateToggle("AutoEquipWeapon", {
    Title = "Auto Equip Weapon",
    Description = "Re-equips your gun if it gets unequipped",
    Default = false
})
Options.AutoEquipWeapon:OnChanged(function()
    AutoEquipWeaponEnabled = Options.AutoEquipWeapon.Value
end)

Tabs.Main:CreateToggle("HideCrosshair", { Title = "Hide Built In Crosshair", Default = false })
Options.HideCrosshair:OnChanged(function()
    HideCrosshairEnabled = Options.HideCrosshair.Value
end)

Tabs.Main:CreateToggle("KillAura", {
    Title = "Kill Aura",
    Description = "Damages zombies around you with your equipped gun",
    Default = false
})
Options.KillAura:OnChanged(function()
    KillAuraEnabled = Options.KillAura.Value
end)

Tabs.Main:CreateToggle("RapidFire", {
    Title = "Rapid Fire",
    Description = "Removes your gun's fire-rate cooldown while held",
    Default = false
})
Options.RapidFire:OnChanged(function()
    RapidFireEnabled = Options.RapidFire.Value
end)

Tabs.Main:CreateSlider("RapidFireInterval", {
    Title = "Rapid Fire Interval",
    Description = "Seconds between shots (lower = faster)",
    Default = 0.02,
    Min = 0.01,
    Max = 0.2,
    Rounding = 2,
    Callback = function(value)
        RapidFireInterval = value
    end
})

Tabs.Main:CreateSlider("KillAuraRadius", {
    Title = "Kill Aura Radius",
    Description = "Range (studs) zombies are hit within",
    Default = 60,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Callback = function(value)
        KillAuraRadius = value
    end
})

Tabs.Main:CreateToggle("AutoUpgradeHealth", { Title = "Auto Upgrade Health", Default = false })
Options.AutoUpgradeHealth:OnChanged(function()
    AutoUpgradeHealthEnabled = Options.AutoUpgradeHealth.Value
end)

Tabs.Main:CreateToggle("AutoUpgradeWeapon", { Title = "Auto Upgrade Weapon", Default = false })
Options.AutoUpgradeWeapon:OnChanged(function()
    AutoUpgradeWeaponEnabled = Options.AutoUpgradeWeapon.Value
end)

Tabs.Gears:CreateToggle("AutoUseGear", { Title = "Auto Use Gear", Default = false })
Options.AutoUseGear:OnChanged(function()
    AutoUseGearEnabled = Options.AutoUseGear.Value
end)

Tabs.Gears:CreateDropdown("GearSelection", {
    Title = "Gears to auto-use",
    Description = "Select which gears should be auto-fired",
    Values = GearDisplayList,
    Multi = true,
    Default = {}
})
Options.GearSelection:OnChanged(function(value)
    local keys = {}
    for display, state in next, value do
        if state and GearDisplayToKey[display] then
            table.insert(keys, GearDisplayToKey[display])
        end
    end
    SelectedGearNames = keys
end)

Tabs.Settings:CreateToggle("AutoHideUI", { Title = "Auto Hide UI on Execute", Default = false })

InterfaceManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()

InterfaceManager:SetFolder("ArenaAutoFarm")
SaveManager:SetFolder("ArenaAutoFarm/config")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

SaveManager:LoadAutoloadConfig()

if Options.AutoHideUI.Value then
    task.defer(function()
        Window:Minimize()
    end)
end

Library:Notify{
    Title = "Arena Auto Farm",
    Content = "Loaded successfully.",
    Duration = 5
}
