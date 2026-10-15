if not game:IsLoaded() then
    game.Loaded:Wait()
end

local SCRIPT_VERSION = "v0.2"
local GAME_NAME = "Rust Blaster"
local GAME_KEY = "RustBlaster"
local DISCORD_INVITE = "https://discord.gg/synapsex"
local WEBSITE_LINK = "https://ouroboros-hub-rbx.web.app/"
local UI_SOURCE_URL = "https://raw.githubusercontent.com/joustingmatch/OuroFlow/main/Source.luau"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local unloaded = false
local connections = {}
local workers = {}
local Library
local Window

local Flags = {
    AutoLaser = false,
    AutoSelectBest = false,
    AutoUpgrades = false,
    UpgradeList = {},
    AutoUnlockItems = false,
    AutoCrates = false,
    CrateList = {},
    AutoRebirth = false,
    AutoRebirthUpgrades = false,
    PerkList = {},
    AutoDaily = false,
    WalkSpeedEnabled = false,
    WalkSpeed = 32,
    InfJump = false,
    NoClip = false,
    InstantProximityPrompt = false,
    Fly = false,
    FlySpeed = 60,
    AntiGameplayPause = true,
    AutoReconnect = false,
    Disable3DRendering = false,
    FpsBoost = false,
    AntiAfk = true,
}

local walkSpeedRestore = {}
local noclipRestore = {}
local promptRestore = {}
local fpsRestore = {}
local flyState = nil
local infJumpConn = nil
local noclipConn = nil
local promptConn = nil
local fpsConn = nil
local antiAfkConn = nil
local antiAfkLast = 0
local reconnectConn = nil
local reconnectFailedConn = nil
local reconnectToken = 0
local gameplayPauseConn = nil
local renderBacking = nil

local Game = {
    cleaned = 0,
    earned = 0,
    upgrades = 0,
    unlocks = 0,
    crates = 0,
    rebirths = 0,
    perks = 0,
}

local RB = ReplicatedStorage:WaitForChild("RB", 20)
local Remotes = RB and RB:WaitForChild("Remotes", 20)
local ConfigModule = RB and RB:WaitForChild("Config", 20)
local okConfig, Config = pcall(require, ConfigModule)
if not Remotes or not okConfig or type(Config) ~= "table" then
    error("[RustBlaster] game modules not found", 0)
end

local function track(conn)
    if conn then
        table.insert(connections, conn)
    end
    return conn
end

local function notify(content, notifyType)
    if Library and type(Library.Notify) == "function" then
        Library:Notify({
            Title = GAME_NAME,
            Content = content,
            Type = notifyType or "Info",
            Duration = 3,
        })
    end
end

local function readFlag(name, default)
    local entry = Library and Library.Flags and Library.Flags[name]
    if entry == nil then
        return default
    end
    if type(entry) == "table" then
        if type(entry.Get) == "function" then
            local ok, value = pcall(entry.Get, entry)
            if ok then
                return value
            end
        end
        if entry.Value ~= nil then
            return entry.Value
        end
        return default
    end
    return entry
end

local function firstOption(option)
    if typeof(option) == "table" then
        return option[1]
    end
    return option
end

local function asList(option)
    local out = {}
    if typeof(option) == "table" then
        for _, v in ipairs(option) do
            table.insert(out, v)
        end
    elseif type(option) == "string" and option ~= "" then
        table.insert(out, option)
    end
    return out
end

local function asSet(list)
    local set = {}
    for _, v in ipairs(list) do
        set[v] = true
    end
    return set
end

local function getRoot()
    local character = LocalPlayer.Character
    if not character then
        return nil, nil
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
        return humanoid, root
    end
    return nil, nil
end

local function startWorker(key, interval, step)
    local token = (workers[key] or 0) + 1
    workers[key] = token
    task.spawn(function()
        while workers[key] == token and not unloaded do
            local ok, err = pcall(step)
            if not ok then
                warn("[" .. GAME_KEY .. "] " .. key .. ": " .. tostring(err))
            end
            task.wait(interval)
        end
    end)
end

local function stopWorker(key)
    workers[key] = (workers[key] or 0) + 1
end

local function setWorker(key, enabled, interval, step)
    if enabled then
        startWorker(key, interval, step)
    else
        stopWorker(key)
    end
end

local function invoke(name, ...)
    local remote = Remotes:FindFirstChild(name)
    if not remote then
        return nil
    end
    local result = table.pack(pcall(remote.InvokeServer, remote, ...))
    if not result[1] then
        warn("[" .. GAME_KEY .. "] " .. name .. ": " .. tostring(result[2]))
        return nil
    end
    return table.unpack(result, 2, result.n)
end

local function getState()
    local state = invoke("GetState")
    if type(state) == "table" then
        return state
    end
    return nil
end

local function getData()
    local state = getState()
    return state and type(state.data) == "table" and state.data or nil
end

local function nameMap(list)
    local names, byName = {}, {}
    for _, def in ipairs(list) do
        if type(def) == "table" and def.id and def.name then
            table.insert(names, def.name)
            byName[def.name] = def
        end
    end
    return names, byName
end

local UPGRADE_NAMES, UPGRADE_BY_NAME = nameMap(Config.Upgrades or {})
local CRATE_NAMES, CRATE_BY_NAME = nameMap(Config.Crates or {})
local PERK_NAMES, PERK_BY_NAME = nameMap(Config.Perks or {})

local laserToken = nil
local laserIdx = nil

local function requiredTiles(idx)
    local ok, value = pcall(Config.RequiredTiles, idx)
    if ok and type(value) == "number" and value > 0 then
        return math.ceil(value)
    end
    return (Config.GRID or 36) ^ 2
end

local function stepLaser()
    if not laserToken then
        local state = getState()
        local item = state and state.item
        if type(item) ~= "table" or not item.token then
            return
        end
        laserToken, laserIdx = item.token, item.idx
    end
    local res = invoke("CompleteItem", laserToken, requiredTiles(laserIdx), 1)
    if type(res) ~= "table" then
        laserToken = nil
        task.wait(1)
        return
    end
    if res.ok then
        Game.cleaned += 1
        Game.earned += tonumber(res.earned) or 0
        local item = res.item
        if type(item) == "table" and item.token then
            laserToken, laserIdx = item.token, item.idx
        else
            laserToken = nil
        end
    elseif tonumber(res.retryIn) then
        task.wait(math.clamp(res.retryIn + 0.15, 0.2, 15))
    else
        laserToken = nil
        task.wait(1)
    end
end

local function stepSelectBest()
    local state = getState()
    local data = state and state.data
    local item = state and state.item
    if type(data) ~= "table" or type(item) ~= "table" then
        return
    end
    local best = tonumber(data.unlocked) or 0
    if best > 0 and (tonumber(item.idx) or 0) < best then
        local res = invoke("SelectItem", best)
        if type(res) == "table" and res.token then
            laserToken, laserIdx = res.token, res.idx
        end
    end
end

local function stepUpgrades()
    if #Flags.UpgradeList == 0 then
        return
    end
    local data = getData()
    if not data then
        return
    end
    local upgrades = data.upgrades or {}
    for _, name in ipairs(Flags.UpgradeList) do
        local def = UPGRADE_BY_NAME[name]
        if def then
            local level = upgrades[def.id] or 0
            local locked3d = def.needs3d and (data.unlocked or 0) < (Config.First3D or math.huge)
            local okCost, cost = pcall(Config.UpgradeCost, def.id, level)
            if not locked3d and level < (def.max or math.huge) and okCost and type(cost) == "number" and (data.cash or 0) >= cost then
                if invoke("BuyUpgrade", def.id) then
                    Game.upgrades += 1
                    return
                end
            end
        end
    end
end

local function stepUnlockItems()
    local data = getData()
    if not data then
        return
    end
    local nextItem = Config.Items[(data.unlocked or 0) + 1]
    if nextItem and nextItem.available and (data.cash or 0) >= (nextItem.cost or math.huge) then
        if invoke("UnlockItem") then
            Game.unlocks += 1
            laserToken = nil
        end
    end
end

local function stepCrates()
    if #Flags.CrateList == 0 then
        return
    end
    local data = getData()
    if not data then
        return
    end
    for _, name in ipairs(Flags.CrateList) do
        local def = CRATE_BY_NAME[name]
        if def then
            local okAvail, available = pcall(Config.CrateAvailable, def)
            local okLock, locked = pcall(Config.CrateLocked, data, def)
            local okWallet, wallet = pcall(Config.CrateWallet, data, def)
            local okCost, cost = pcall(Config.CrateCost, data, def.id, 1)
            if okAvail and available and okLock and not locked and okWallet and okCost and type(wallet) == "number" and type(cost) == "number" and wallet >= cost then
                if invoke("OpenCrate", def.id, 1) then
                    Game.crates += 1
                    return
                end
            end
        end
    end
end

local function stepRebirth()
    local data = getData()
    if not data then
        return
    end
    local okReq, required = pcall(Config.RebirthRequirement, data.rebirths or 0)
    if okReq and type(required) == "number" and (data.unlocked or 0) >= required then
        if invoke("Rebirth") then
            Game.rebirths += 1
            laserToken = nil
            task.wait(2)
        end
    end
end

local function stepRebirthUpgrades()
    if #Flags.PerkList == 0 then
        return
    end
    local data = getData()
    if not data then
        return
    end
    for _, name in ipairs(Flags.PerkList) do
        local def = PERK_BY_NAME[name]
        if def and type(def.cost) == "function" then
            local okLevel, level = pcall(Config.Perk, data, def.id)
            level = okLevel and tonumber(level) or 0
            local okCost, cost = pcall(def.cost, level)
            if level < (def.max or math.huge) and okCost and type(cost) == "number" and (data.rebirthTokens or 0) >= cost then
                if invoke("BuyPerk", def.id) then
                    Game.perks += 1
                    return
                end
            end
        end
    end
end

local function stepDaily()
    local data = getData()
    if not data then
        return
    end
    local growth = data.growth or {}
    local today = math.floor(workspace:GetServerTimeNow() / 86400)
    if (growth.lastDaily or -1) < today then
        invoke("ClaimDaily")
    end
end

local function short(n)
    n = tonumber(n) or 0
    local units = { "", "K", "M", "B", "T", "Qd", "Qn" }
    local i = 1
    while math.abs(n) >= 1000 and i < #units do
        n /= 1000
        i += 1
    end
    if i == 1 then
        return tostring(math.floor(n))
    end
    return string.format("%.2f%s", n, units[i])
end

local function overviewRows()
    return {
        { Text = "Relics Cleaned", Value = tostring(Game.cleaned) },
        { Text = "Cash Earned", Value = short(Game.earned) },
        { Text = "Upgrades Bought", Value = tostring(Game.upgrades) },
        { Text = "Items Unlocked", Value = tostring(Game.unlocks) },
        { Text = "Crates Opened", Value = tostring(Game.crates) },
        { Text = "Rebirths", Value = tostring(Game.rebirths) },
        { Text = "Rebirth Upgrades", Value = tostring(Game.perks) },
    }
end

local function applyWalkSpeed()
    local humanoid = select(1, getRoot())
    if not humanoid then
        return
    end
    if Flags.WalkSpeedEnabled then
        if walkSpeedRestore[humanoid] == nil then
            walkSpeedRestore[humanoid] = humanoid.WalkSpeed
        end
        humanoid.WalkSpeed = Flags.WalkSpeed
    elseif walkSpeedRestore[humanoid] ~= nil then
        humanoid.WalkSpeed = walkSpeedRestore[humanoid]
        walkSpeedRestore[humanoid] = nil
    end
end

local function setWalkSpeedEnabled(value)
    Flags.WalkSpeedEnabled = value == true
    applyWalkSpeed()
end

local function setWalkSpeed(value)
    Flags.WalkSpeed = tonumber(value) or Flags.WalkSpeed
    if Flags.WalkSpeedEnabled then
        applyWalkSpeed()
    end
end

local function setInfJump(value)
    Flags.InfJump = value == true
    if infJumpConn then
        infJumpConn:Disconnect()
        infJumpConn = nil
    end
    if not Flags.InfJump then
        return
    end
    infJumpConn = track(UserInputService.JumpRequest:Connect(function()
        if unloaded or not Flags.InfJump then
            return
        end
        local humanoid = select(1, getRoot())
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end))
end

local function setNoClip(value)
    Flags.NoClip = value == true
    if noclipConn then
        noclipConn:Disconnect()
        noclipConn = nil
    end
    if not Flags.NoClip then
        for part, canCollide in pairs(noclipRestore) do
            if part.Parent then
                part.CanCollide = canCollide
            end
        end
        table.clear(noclipRestore)
        return
    end
    noclipConn = track(RunService.Stepped:Connect(function()
        if unloaded or not Flags.NoClip then
            return
        end
        local character = LocalPlayer.Character
        if not character then
            return
        end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if noclipRestore[part] == nil then
                    noclipRestore[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end
    end))
end

local function snapshotPrompt(prompt)
    if promptRestore[prompt] == nil then
        promptRestore[prompt] = {
            HoldDuration = prompt.HoldDuration,
            MaxActivationDistance = prompt.MaxActivationDistance,
            RequiresLineOfSight = prompt.RequiresLineOfSight,
        }
    end
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 50
    prompt.RequiresLineOfSight = false
end

local function setInstantProximityPrompt(value)
    Flags.InstantProximityPrompt = value == true
    if promptConn then
        promptConn:Disconnect()
        promptConn = nil
    end
    if not Flags.InstantProximityPrompt then
        for prompt, prev in pairs(promptRestore) do
            if prompt.Parent then
                prompt.HoldDuration = prev.HoldDuration
                prompt.MaxActivationDistance = prev.MaxActivationDistance
                prompt.RequiresLineOfSight = prev.RequiresLineOfSight
            end
        end
        table.clear(promptRestore)
        return
    end
    for _, inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("ProximityPrompt") then
            snapshotPrompt(inst)
        end
    end
    promptConn = track(workspace.DescendantAdded:Connect(function(inst)
        if unloaded or not Flags.InstantProximityPrompt then
            return
        end
        if inst:IsA("ProximityPrompt") then
            snapshotPrompt(inst)
        end
    end))
end

local function stopFly()
    if flyState and flyState.conn then
        flyState.conn:Disconnect()
    end
    local humanoid = flyState and flyState.humanoid
    if humanoid and humanoid.Parent and flyState.platformStand ~= nil then
        humanoid.PlatformStand = flyState.platformStand
    end
    flyState = nil
end

local function setFly(value)
    Flags.Fly = value == true
    stopFly()
    if not Flags.Fly then
        return
    end
    local humanoid, root = getRoot()
    if not (humanoid and root) then
        return
    end
    flyState = {
        humanoid = humanoid,
        root = root,
        platformStand = humanoid.PlatformStand,
    }
    humanoid.PlatformStand = true
    flyState.conn = track(RunService.RenderStepped:Connect(function()
        if unloaded or not Flags.Fly then
            return
        end
        if UserInputService:GetFocusedTextBox() then
            return
        end
        local hum, hrp = getRoot()
        if not (hum and hrp) then
            return
        end
        local cam = workspace.CurrentCamera
        if not cam then
            return
        end
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            move += cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            move -= cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            move -= cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            move += cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            move += Vector3.yAxis
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            move -= Vector3.yAxis
        end
        if move.Magnitude > 0 then
            hrp.AssemblyLinearVelocity = move.Unit * Flags.FlySpeed
        else
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
        hum.PlatformStand = true
    end))
end

local function setFlySpeed(value)
    Flags.FlySpeed = tonumber(value) or Flags.FlySpeed
end

local function setNoGameplayPaused(value)
    Flags.AntiGameplayPause = value == true
    if gameplayPauseConn then
        gameplayPauseConn:Disconnect()
        gameplayPauseConn = nil
    end
    if not Flags.AntiGameplayPause then
        return
    end
    pcall(function()
        StarterGui:SetCore("ResetButtonCallback", true)
    end)
    gameplayPauseConn = track(GuiService.MenuOpened:Connect(function()
        if unloaded or not Flags.AntiGameplayPause then
            return
        end
        pcall(function()
            GuiService.SelectedObject = nil
        end)
    end))
end

local function setAutoReconnect(value)
    Flags.AutoReconnect = value == true
    if reconnectConn then
        reconnectConn:Disconnect()
        reconnectConn = nil
    end
    if reconnectFailedConn then
        reconnectFailedConn:Disconnect()
        reconnectFailedConn = nil
    end
    if not Flags.AutoReconnect then
        reconnectToken += 1
        return
    end
    reconnectConn = track(GuiService.ErrorMessageChanged:Connect(function()
        if unloaded or not Flags.AutoReconnect then
            return
        end
        local token = reconnectToken + 1
        reconnectToken = token
        task.delay(1.5, function()
            if unloaded or not Flags.AutoReconnect or reconnectToken ~= token then
                return
            end
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end)
        end)
    end))
    reconnectFailedConn = track(TeleportService.TeleportInitFailed:Connect(function(player)
        if player ~= LocalPlayer or unloaded or not Flags.AutoReconnect then
            return
        end
        task.delay(2, function()
            if unloaded or not Flags.AutoReconnect then
                return
            end
            pcall(function()
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
        end)
    end))
end

local function setDisable3D(value)
    Flags.Disable3DRendering = value == true
    if Flags.Disable3DRendering then
        pcall(function()
            RunService:Set3dRenderingEnabled(false)
        end)
        if not renderBacking then
            local gui = Instance.new("ScreenGui")
            gui.Name = "OuroborosRenderBacking"
            gui.IgnoreGuiInset = true
            gui.DisplayOrder = -100
            gui.ResetOnSpawn = false
            local frame = Instance.new("Frame")
            frame.BackgroundColor3 = Color3.new(0, 0, 0)
            frame.Size = UDim2.fromScale(1, 1)
            frame.BorderSizePixel = 0
            frame.Parent = gui
            gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
            renderBacking = gui
        end
    else
        pcall(function()
            RunService:Set3dRenderingEnabled(true)
        end)
        if renderBacking then
            renderBacking:Destroy()
            renderBacking = nil
        end
    end
end

local function captureFps(inst)
    if fpsRestore[inst] ~= nil then
        return
    end
    local snap = {}
    if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
        snap.Enabled = inst.Enabled
        inst.Enabled = false
    elseif inst:IsA("Explosion") then
        snap.Visible = inst.Visible
        inst.Visible = false
    end
    fpsRestore[inst] = snap
end

local function setFpsBoost(value)
    Flags.FpsBoost = value == true
    if fpsConn then
        fpsConn:Disconnect()
        fpsConn = nil
    end
    if not Flags.FpsBoost then
        for inst, snap in pairs(fpsRestore) do
            if typeof(inst) == "Instance" and inst.Parent then
                for key, prev in pairs(snap) do
                    pcall(function()
                        inst[key] = prev
                    end)
                end
            end
        end
        local light = fpsRestore.Lighting
        if light then
            Lighting.GlobalShadows = light.GlobalShadows
            Lighting.FogEnd = light.FogEnd
        end
        table.clear(fpsRestore)
        return
    end
    if fpsRestore.Lighting == nil then
        fpsRestore.Lighting = {
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd,
        }
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e6
    end
    for _, inst in ipairs(workspace:GetDescendants()) do
        captureFps(inst)
    end
    fpsConn = track(workspace.DescendantAdded:Connect(function(inst)
        if unloaded or not Flags.FpsBoost then
            return
        end
        captureFps(inst)
    end))
end

local function pulseAntiAfk()
    if unloaded or not Flags.AntiAfk then
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then
        return
    end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(), cam.CFrame)
    end)
end

local function setAntiAfk(value)
    Flags.AntiAfk = value == true
    if antiAfkConn then
        antiAfkConn:Disconnect()
        antiAfkConn = nil
    end
    if not Flags.AntiAfk then
        stopWorker("AntiAfk")
        return
    end
    antiAfkLast = os.clock()
    antiAfkConn = track(LocalPlayer.Idled:Connect(function()
        pulseAntiAfk()
    end))
    startWorker("AntiAfk", 1, function()
        if not Flags.AntiAfk then
            return
        end
        if os.clock() - antiAfkLast >= 60 then
            antiAfkLast = os.clock()
            pulseAntiAfk()
        end
    end)
end

local function bindCharacter(character)
    task.defer(function()
        if unloaded then
            return
        end
        applyWalkSpeed()
        if Flags.Fly then
            setFly(true)
        end
    end)
    local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
    if humanoid then
        track(humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if Flags.WalkSpeedEnabled and not unloaded then
                if humanoid.WalkSpeed ~= Flags.WalkSpeed then
                    humanoid.WalkSpeed = Flags.WalkSpeed
                end
            end
        end))
    end
end

local WORKER_STEPS = {
    AutoLaser = { 0.05, stepLaser },
    AutoSelectBest = { 2, stepSelectBest },
    AutoUpgrades = { 0.5, stepUpgrades },
    AutoUnlockItems = { 1, stepUnlockItems },
    AutoCrates = { 0.5, stepCrates },
    AutoRebirth = { 3, stepRebirth },
    AutoRebirthUpgrades = { 1, stepRebirthUpgrades },
    AutoDaily = { 60, stepDaily },
}

local Setters = {}

function Setters.feature(key, value)
    Flags[key] = value == true
    local spec = WORKER_STEPS[key]
    if spec then
        setWorker(key, Flags[key], spec[1], spec[2])
    end
end

local function stopAllFeatures()
    for key in pairs(WORKER_STEPS) do
        Setters.feature(key, false)
    end
    setWalkSpeedEnabled(false)
    setInfJump(false)
    setNoClip(false)
    setInstantProximityPrompt(false)
    setFly(false)
    setNoGameplayPaused(false)
    setAutoReconnect(false)
    setDisable3D(false)
    setFpsBoost(false)
    setAntiAfk(false)
end

local function unloadScript()
    if unloaded then
        return
    end
    local ok, err = pcall(stopAllFeatures)
    if not ok then
        warn("[" .. GAME_KEY .. "] cleanup: " .. tostring(err))
    end
    unloaded = true
    for _, conn in ipairs(connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    table.clear(connections)
    if Window then
        pcall(function()
            Window:Destroy()
        end)
        Window = nil
    end
end


local okLibrary, libraryOrErr = pcall(function()
    local chunk = assert(loadstring(game:HttpGet(UI_SOURCE_URL)))
    if type(setfenv) == "function" and type(getfenv) == "function" then
        local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
        setfenv(chunk, setmetatable({
            gethui = function()
                return PlayerGui
            end,
        }, { __index = getfenv(chunk) }))
    end
    return chunk()
end)
if not okLibrary or type(libraryOrErr) ~= "table" then
    error("failed to load UI library: " .. tostring(libraryOrErr), 0)
end
Library = libraryOrErr

track(LocalPlayer.CharacterAdded:Connect(bindCharacter))
if LocalPlayer.Character then
    bindCharacter(LocalPlayer.Character)
end

Library:LoadFont({ Name = "ValleySans" })
Library:SetDefaultTheme("Rose")

Window = Library:CreateWindow({
    Name = "Ouroboros",
    LoadingSubtitle = SCRIPT_VERSION,
    ToggleUIKeybind = "RightControl",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "Ouroboros/" .. GAME_KEY,
        FileName = "default",
    },
    ToggleButton = { Platform = "Mobile" },
    Home = {
        Title = "Welcome to " .. GAME_NAME .. "!",
        Tier = SCRIPT_VERSION,
        Discord = DISCORD_INVITE,
        Website = WEBSITE_LINK,
        Stats = { "Players", "Session", "FPS", "Ping" },
    },
})

local Main = Window:CreateTab({ Name = "Main", Icon = "house" })
local FarmTab = Main:CreateSubTab({ Name = "Farm", Icon = "zap" })
local ShopTab = Main:CreateSubTab({ Name = "Shop", Icon = "shopping-cart" })
local Player = Window:CreateTab({ Name = "Player", Icon = "user" })
local Settings = Window:CreateTab({ Name = "Settings", Icon = "settings" })

local function featureToggle(box, name, flag)
    box:CreateToggle({
        Name = name,
        CurrentValue = false,
        Flag = flag,
        Callback = function(value)
            Setters.feature(flag, value)
        end,
    })
end

local function multiDropdown(box, name, options, flag)
    box:CreateDropdown({
        Name = name,
        Options = options,
        MultipleOptions = true,
        CurrentOption = {},
        Flag = flag,
        Callback = function(option)
            Flags[flag] = asList(option)
        end,
    })
end

local function setupFarmTab()
    local Overview = FarmTab:AddLeftGroupbox({ Name = "Overview", Icon = "activity" })
    Overview:CreateStatusList({
        Name = "Session",
        MaxRows = 7,
        UpdateRate = 0.5,
        Update = overviewRows,
    })

    local Farm = FarmTab:AddRightGroupbox({ Name = "Laser", Icon = "zap" })
    featureToggle(Farm, "Auto Laser", "AutoLaser")
    featureToggle(Farm, "Auto Select Best Item", "AutoSelectBest")
    featureToggle(Farm, "Auto Claim Daily", "AutoDaily")

    local Rebirth = FarmTab:AddRightGroupbox({ Name = "Rebirth", Icon = "refresh-cw" })
    featureToggle(Rebirth, "Auto Rebirth", "AutoRebirth")
    multiDropdown(Rebirth, "Rebirth Upgrades", PERK_NAMES, "PerkList")
    featureToggle(Rebirth, "Auto Buy Rebirth Upgrades", "AutoRebirthUpgrades")
end

local function setupShopTab()
    local Upgrades = ShopTab:AddLeftGroupbox({ Name = "Upgrades", Icon = "arrow-up" })
    multiDropdown(Upgrades, "Upgrades", UPGRADE_NAMES, "UpgradeList")
    featureToggle(Upgrades, "Auto Buy Upgrades", "AutoUpgrades")
    featureToggle(Upgrades, "Auto Buy Items", "AutoUnlockItems")

    local Crates = ShopTab:AddRightGroupbox({ Name = "Crates", Icon = "package" })
    multiDropdown(Crates, "Crates", CRATE_NAMES, "CrateList")
    featureToggle(Crates, "Auto Buy Crates", "AutoCrates")
end
local function setupPlayerTab()
    local Movement = Player:AddLeftGroupbox({ Name = "Movement", Icon = "move" })
    Movement:CreateToggle({
        Name = "WalkSpeed",
        CurrentValue = false,
        Flag = "WalkSpeedEnabled",
        Callback = function(value)
            setWalkSpeedEnabled(value)
        end,
    })
    Movement:CreateSlider({
        Name = "Speed",
        Range = { 16, 250 },
        Increment = 1,
        CurrentValue = 32,
        Flag = "WalkSpeed",
        Callback = function(value)
            setWalkSpeed(value)
        end,
    })
    Movement:CreateToggle({
        Name = "Infinite Jump",
        CurrentValue = false,
        Flag = "InfJump",
        Callback = function(value)
            setInfJump(value)
        end,
    })
    Movement:CreateToggle({
        Name = "Noclip",
        CurrentValue = false,
        Flag = "NoClip",
        Callback = function(value)
            setNoClip(value)
        end,
    })
    Movement:CreateToggle({
        Name = "Instant ProximityPrompt",
        CurrentValue = false,
        Flag = "InstantProximityPrompt",
        Callback = function(value)
            setInstantProximityPrompt(value)
        end,
    })

    local FlyBox = Player:AddRightGroupbox({ Name = "Fly", Icon = "plane" })
    FlyBox:CreateToggle({
        Name = "Fly",
        CurrentValue = false,
        Flag = "Fly",
        Callback = function(value)
            setFly(value)
        end,
    })
    FlyBox:CreateSlider({
        Name = "Fly Speed",
        Range = { 10, 400 },
        Increment = 1,
        CurrentValue = 60,
        Flag = "FlySpeed",
        Callback = function(value)
            setFlySpeed(value)
        end,
    })

    local Client = Player:AddLeftGroupbox({ Name = "Client", Icon = "monitor" })
    Client:CreateToggle({
        Name = "No Gameplay Paused",
        CurrentValue = true,
        Flag = "AntiGameplayPause",
        Callback = function(value)
            setNoGameplayPaused(value)
        end,
    })
    Client:CreateToggle({
        Name = "Auto Reconnect on Kick",
        CurrentValue = false,
        Flag = "AutoReconnect",
        Callback = function(value)
            setAutoReconnect(value)
        end,
    })
    Client:CreateToggle({
        Name = "Disable 3D Rendering",
        CurrentValue = false,
        Flag = "Disable3DRendering",
        Callback = function(value)
            setDisable3D(value)
        end,
    })
    Client:CreateToggle({
        Name = "FPS Boost",
        CurrentValue = false,
        Flag = "FpsBoost",
        Callback = function(value)
            setFpsBoost(value)
        end,
    })
    Client:CreateToggle({
        Name = "Hide UI On Start",
        CurrentValue = false,
        Flag = "HideUIOnStart",
        Callback = function() end,
    })
end

local function setupSettingsTab()
    local Interface = Settings:AddLeftGroupbox({ Name = "Menu", Icon = "monitor" })
    Interface:CreateKeybind({
        Name = "Toggle UI",
        CurrentKeybind = "RightControl",
        Flag = "ToggleUIKey",
        Callback = function() end,
        OnChanged = function(key)
            Window:SetKeybind(key)
        end,
    })
    Interface:CreateDropdown({
        Name = "Toggle button",
        Options = { "Mobile only", "Mobile & PC" },
        CurrentOption = "Mobile only",
        AllowNone = false,
        Flag = "ToggleButtonPlatform",
        Callback = function(option)
            Window:SetToggleButtonPlatform(firstOption(option) == "Mobile & PC" and "Both" or "Mobile")
        end,
    })
    Interface:CreateToggle({
        Name = "Anti AFK",
        CurrentValue = true,
        Flag = "AntiAfk",
        Callback = function(value)
            setAntiAfk(value)
        end,
    })
    Interface:CreateButton({
        Name = "Unload",
        Icon = "power",
        Callback = function()
            Library:Confirm({
                Title = "Unload?",
                ConfirmText = "Unload",
                Callback = function()
                    unloadScript()
                end,
            })
        end,
    })
    Settings:CreateConfigManager({ Name = "Configs", Side = "Left" })
    Settings:CreateThemeManager({ Name = "Themes", Side = "Right" })
end

setupFarmTab()
setupShopTab()
setupPlayerTab()
setupSettingsTab()

setNoGameplayPaused(true)
setAntiAfk(true)

Window:LoadAutoload()

Flags.UpgradeList = asList(readFlag("UpgradeList", {}))
Flags.CrateList = asList(readFlag("CrateList", {}))
Flags.PerkList = asList(readFlag("PerkList", {}))
for key in pairs(WORKER_STEPS) do
    Setters.feature(key, readFlag(key, false) == true)
end
setWalkSpeed(readFlag("WalkSpeed", Flags.WalkSpeed))
setWalkSpeedEnabled(readFlag("WalkSpeedEnabled", false) == true)
setInfJump(readFlag("InfJump", false) == true)
setNoClip(readFlag("NoClip", false) == true)
setInstantProximityPrompt(readFlag("InstantProximityPrompt", false) == true)
setFlySpeed(readFlag("FlySpeed", Flags.FlySpeed))
setFly(readFlag("Fly", false) == true)
setNoGameplayPaused(readFlag("AntiGameplayPause", true) == true)
setAutoReconnect(readFlag("AutoReconnect", false) == true)
setDisable3D(readFlag("Disable3DRendering", false) == true)
setFpsBoost(readFlag("FpsBoost", false) == true)
setAntiAfk(readFlag("AntiAfk", true) == true)

if readFlag("HideUIOnStart", false) == true then
    Window:Toggle(false)
end
