local function _ls(src, name)
    local ok, fn = pcall(loadstring, src, name)
    if not ok or not fn then ok, fn = pcall(loadstring, src) end
    return fn
end

local _core = _ls([[local Shared = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local Env = getgenv and getgenv() or _G
if Env.OuroborosEvomonCleanup then
    pcall(Env.OuroborosEvomonCleanup)
end

local LoadToken = {}
Env.OuroborosEvomonLoadToken = LoadToken

local function isStaleLoad()
    return Env.OuroborosEvomonLoadToken ~= LoadToken
end

Shared.Players = Players
Shared.ReplicatedStorage = ReplicatedStorage
Shared.RunService = RunService
Shared.TeleportService = TeleportService
Shared.UserInputService = UserInputService
Shared.VirtualUser = VirtualUser
Shared.Workspace = Workspace
Shared.CoreGui = CoreGui
Shared.LocalPlayer = LocalPlayer
Shared.Env = Env

Shared.DISCORD_LINK = "https://discord.gg/ehKVq7pf7v"
Shared.WINDOW_IMAGE = "rbxassetid://18657887261"

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

local function httpGet(url)
    local ok, src = pcall(game.HttpGet, game, url)
    if ok and type(src) == "string" and #src > 0 then return src end
    ok, src = pcall(function() return game:HttpGetAsync(url) end)
    if ok and type(src) == "string" and #src > 0 then return src end
    if httpRequest then
        local res
        ok, res = pcall(httpRequest, { Url = url, Method = "GET" })
        if ok and type(res) == "table" then
            local body = res.Body or res.body
            if type(body) == "string" and #body > 0 then return body end
        end
    end
end

local function loadAddon(url)
    local src = httpGet(url)
    if type(src) == "string" and #src > 200 then
        local fn = loadstring(src)
        if fn then
            local ran, mod = pcall(fn)
            if ran then return mod end
        end
    end
end

local Library = loadAddon(repo .. "Library.lua")
if not Library then
    warn("Evomon: failed to load Obsidian library (HTTP fetch or compile failed). Check your executor's HttpGet/request support.")
    return nil
end

if isStaleLoad() then
    warn("Evomon: aborted duplicate load (a newer instance started).")
    return nil
end

Shared.Library = Library
Shared.ThemeManager = loadAddon(repo .. "addons/ThemeManager.lua")
Shared.SaveManager = loadAddon(repo .. "addons/SaveManager.lua")
Shared.Options = Library.Options
Shared.Toggles = Library.Toggles

Shared.Running = true
Shared.SuppressNotify = false
Shared.UnloadCallbacks = {}
Shared.LeaderPetMap = {}

local Remote = ReplicatedStorage:WaitForChild("Remote")
local BattleRemote = Remote:WaitForChild("Battle")
Shared.Remote = Remote
Shared.ReqEnterPetBattle = BattleRemote:WaitForChild("ReqEnterPetBattle")
Shared.ReqAutoBattle = BattleRemote:WaitForChild("ReqAutoBattle")
Shared.ReqGetAllCreatures = Remote:WaitForChild("Creature"):WaitForChild("ReqGetAllCreatures")
Shared.OperateBattle = ReplicatedStorage:WaitForChild("Bindable"):WaitForChild("Battle"):WaitForChild("OperateBattle")
Shared.ClientBattleAnimationComplete = ReplicatedStorage.Bindable.Battle:WaitForChild("ClientBattleAnimationComplete")
Shared.ReqApplyOnlineReward = Remote:WaitForChild("OnlineReward"):WaitForChild("ReqApplyOnlineReward")
Shared.ReqClaimExploreReward = Remote:WaitForChild("Chest"):WaitForChild("ReqClaimExploreReward")
Shared.ReqCompleteTask = Remote:WaitForChild("Task"):WaitForChild("ReqCompleteTask")
Shared.ReqClaimActiveReward = Remote.Task:WaitForChild("ReqClaimActiveReward")

Shared.AreaConfig = require(ReplicatedStorage.Config:WaitForChild("AreaConfig"))
Shared.IslandConfig = require(ReplicatedStorage.Config:WaitForChild("IslandConfig"))
Shared.PetConfig = require(ReplicatedStorage.Config:WaitForChild("PetConfig"))
Shared.ErrorCode = require(ReplicatedStorage.Core.Tools:WaitForChild("ErrorCode"))
Shared.BattleConst = require(ReplicatedStorage.Script.Battle.Basic:WaitForChild("BattleConst"))
Shared.PetConst = require(ReplicatedStorage.Script.Pet.Basic:WaitForChild("PetConst"))
Shared.BattleService = require(ReplicatedStorage.Script.Battle:WaitForChild("BattleService"))
Shared.BattleDataGetModule = require(ReplicatedStorage.Script.MainBattleWindow:WaitForChild("BattleDataGetModule"))
Shared.GetBallDataModule = require(ReplicatedStorage.Script.HatchEgg:WaitForChild("GetBallDataModule"))
Shared.ConfigDataManager = require(ReplicatedStorage.Core.Config:WaitForChild("ConfigDataManager"))
Shared.ConfigConst = require(ReplicatedStorage.Core.Config:WaitForChild("ConfigConst"))
Shared.UIManager = require(ReplicatedStorage.Core.UI:WaitForChild("UIManager"))
Shared.ControllerManager = require(ReplicatedStorage.Core.Controller:WaitForChild("ControllerManager"))
Shared.MailService = require(ReplicatedStorage.Script.Mail:WaitForChild("MailService"))
Shared.PetManualService = require(ReplicatedStorage.Script.PetManual:WaitForChild("PetManualService"))
Shared.DailyRewardService = require(ReplicatedStorage.Script.DailyReward:WaitForChild("DailyRewardService"))
Shared.BattlePassService = require(ReplicatedStorage.Script.BattlePass:WaitForChild("BattlePassService"))
Shared.PlayerLevelRewardService = require(ReplicatedStorage.Script.PlayerLevelReward:WaitForChild("PlayerLevelRewardService"))
Shared.TaskService = require(ReplicatedStorage.Script.Task:WaitForChild("TaskService"))
Shared.TaskConst = require(ReplicatedStorage.Script.Task.Basic:WaitForChild("TaskConst"))
Shared.ChestService = require(ReplicatedStorage.Script.Chest:WaitForChild("ChestService"))
Shared.ChestConst = require(ReplicatedStorage.Script.Chest.Basic:WaitForChild("ChestConst"))
Shared.PubStorage = require(ReplicatedStorage.SceneStorage:WaitForChild("PubStorage"))
Shared.BagService = require(ReplicatedStorage.Script.Bag:WaitForChild("BagService"))
Shared.PetStorage = require(ReplicatedStorage.Storage:WaitForChild("PetStorage"))
Shared.PetGroupStorage = require(ReplicatedStorage.Storage:WaitForChild("PetGroupStorage"))
Shared.PetComm = require(ReplicatedStorage.Script.Pet:WaitForChild("PetComm"))
Shared.PetService = require(ReplicatedStorage.Script.Pet:WaitForChild("PetService"))
Shared.PetGroupService = require(ReplicatedStorage.Script.PetGroup:WaitForChild("PetGroupService"))
Shared.SummonMonsterService = require(ReplicatedStorage.Script.SummonMonster:WaitForChild("SummonMonsterService"))
Shared.AttrConst = require(ReplicatedStorage.Script.Attr.Basic:WaitForChild("AttrConst"))
Shared.OnlineRewardStorage = require(ReplicatedStorage.Storage:WaitForChild("OnlineRewardStorage"))
Shared.DungeonService = require(ReplicatedStorage.Script.Dungeon:WaitForChild("DungeonService"))
Shared.TowerDungeonService = require(ReplicatedStorage.Script.Dungeon:WaitForChild("TowerDungeonService"))
Shared.DungeonModule = require(ReplicatedStorage.Script.Dungeon:WaitForChild("DungeonModule"))
Shared.ManyWorldsService = require(ReplicatedStorage.Script.ManyWorlds:WaitForChild("ManyWorldsService"))
Shared.TravelingMerchantService = require(ReplicatedStorage.Script.TravelingMerchant:WaitForChild("TravelingMerchantService"))
Shared.ShopService = require(ReplicatedStorage.Script.Shop:WaitForChild("ShopService"))
Shared.CommShopConst = require(ReplicatedStorage.Script.CommShop.Basic:WaitForChild("CommShopConst"))
Shared.DungeonConfig = require(ReplicatedStorage.Config:WaitForChild("DungeonConfig"))
Shared.NpcConfig = require(ReplicatedStorage.Config:WaitForChild("NpcConfig"))
Shared.TalkConfig = require(ReplicatedStorage.Config:WaitForChild("TalkConfig"))
Shared.RefreshService = require(ReplicatedStorage.Script.RefreshSystem:WaitForChild("RefreshService"))
Shared.MainBattleWindowController = require(ReplicatedStorage.Controller:WaitForChild("MainBattleWindowController"))

local PetConfig = Shared.PetConfig
local IslandConfig = Shared.IslandConfig
local AreaConfig = Shared.AreaConfig
local ErrorCode = Shared.ErrorCode
local BattleService = Shared.BattleService
local GetBallDataModule = Shared.GetBallDataModule
local PetStorage = Shared.PetStorage
local PetComm = Shared.PetComm

Shared.BALL_VALUES = { "Common", "Advanced", "King", "Prismatic" }
Shared.SKIP_BALL_VALUES = { "Skip", "Common", "Advanced", "King", "Prismatic" }
Shared.BALL_IDS = {
    Common = 2000015,
    Advanced = 2000016,
    King = 2000017,
    Prismatic = 2000018,
}
Shared.POTION_VALUES = { "Small HP Potion", "Medium HP Potion", "Large HP Potion" }
Shared.POTION_IDS = {
    ["Small HP Potion"] = 2000001,
    ["Medium HP Potion"] = 2000002,
    ["Large HP Potion"] = 2000003,
}
Shared.LEVEL_CONDITION_VALUES = { "Equal to (=)", "Less than or Equal to (<=)", "Greater than or Equal to (>=)", "Max Level" }
Shared.SWAP_SLOT_VALUES = { "Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5" }
Shared.SWAP_TO_VALUES = { "Shiny", "Exclude Shiny", "Prismatic", "Exclude Prismatic", "SSS Talent" }
Shared.PET_TRAIT_CATEGORY_VALUES = { "Shiny", "Prismatic", "SSS", "Shiny Prismatic", "SSS and Shiny", "SSS Prismatic", "SSS Shiny Prismatic" }
Shared.UNLOCK_CATEGORY_VALUES = { "Shiny", "Prismatic", "SSS", "Shiny Prismatic", "SSS and Shiny", "SSS Prismatic", "SSS Shiny Prismatic", "Talent below SSS" }

local State = {
    Island = nil,
    Mob = nil,
    AutoFarm = false,
    AutoBattle = false,
    AutoCatch = false,
    SkipCatchAnimation = true,
    ShinyBall = "King",
    PrismaticBall = "Prismatic",
    NormalBall = "Skip",
    BossBall = "Skip",
    ShinyPrismaticFarm = false,
    PityBall = "Common",
    ComboBall = "King",
    AutoHeal = false,
    HealPotion = "Medium HP Potion",
    HealPercent = 50,
    AutoClaimMail = false,
    AutoClaimPetManual = false,
    AutoClaimOnlineReward = false,
    AutoClaimDaily = false,
    AutoClaimBattlePass = false,
    AutoClaimLevelRewards = false,
    AutoClaimQuests = false,
    AutoClaimAchievements = false,
    AutoDismissPopups = false,
    CollectChests = false,
    AutoGuardChests = false,
    GuardChestDelay = 10,
    AntiAfk = true,
    SummonBoss = nil,
    AutoSummonFight = false,
    LeaderPet = nil,
    AutoRelease = false,
    ReleaseSpecies = nil,
    ReleaseOnlyWhenFull = false,
    ReleaseKeepFreeSlots = 5,
    ExcludeSpecial = true,
    AutoReleaseLevels = false,
    ReleaseLevelOnlyWhenFull = false,
    ReleaseLevelKeepFreeSlots = 5,
    ReleaseLevelCondition = "Less than or Equal to (<=)",
    ReleaseLevelValue = 1,
    ReleaseLevelExclude = {},
    AutoSwap = false,
    SwapSlots = {},
    SwapToFilters = {},
    SwapLevelCondition = "Greater than or Equal to (>=)",
    SwapLevel = "Max",
    AutoUnlock = false,
    UnlockCategories = {},
    AutoLock = false,
    LockCategories = {},
    AutoFavorite = false,
    FavoriteCategories = {},
    AutoEvolve = false,
    EvolveFavoritedOnly = false,
    AutoTower = false,
    TowerStartFloor = 1,
    TowerStopFloor = 0,
    AutoDailyChallenge = false,
    DailyChallenge = nil,
    AutoEquipChallenge = false,
    EquipChallenge = nil,
    AutoBossFarm = false,
    BypassBossCD = false,
    SelectedBosses = {},
    WalkSpeedEnabled = false,
    WalkSpeedValue = 16,
    JumpPowerEnabled = false,
    JumpPowerValue = 50,
    InfiniteJump = false,
    Noclip = false,
    GravityEnabled = false,
    GravityValue = 196.2,
    SavedPosition = nil,
    AutoReconnect = false,
    AutoExecute = false,
    AutoServerHop = false,
    ServerHopInterval = 300,
    ServerHopMode = "Random",
    ServerHopMinPlayers = 1,
    Disable3DRendering = false,
    Unlock2xSpeed = false,
    AutoSpeedUpBattle = false,
    BattleSpeed = 1,
    EnableCustomAutoBattle = false,
    AutoSwitchDead = true,
    CustomSkillOrders = {},
    SelectedSwitchTeam = nil,
    CustomTeams = {},
    SelectedCustomTeam = nil,
    CustomTeamTargetGroup = nil,
    AutoCustomTeam = false,
    TeleportIsland = nil,
    TeleportNpc = nil,
    TeleportWorld = nil,
    MerchantGood = nil,
    MerchantItems = {},
    MerchantAutoBuy = false,
    ShopAutoBuyCoins = false,
    ShopItemsCoins = {},
    ShopAutoBuyExchange = false,
    ShopItemsExchange = {},
    ShopAutoBuyRaid = false,
    ShopItemsRaid = {},
    ShopBuyDelay = 3,
    SuitKeepNames = {},
    SuitKeepRarities = {},
    SuitSpinType = "Spin (Coins)",
    SuitRerollSlot = nil,
    AutoSpinSuit = false,
    HatchEgg = nil,
    HatchRareEgg = nil,
    HatchBall = nil,
    HatchRareBall = nil,
    AutoHatch = false,
    HatchAllEggs = false,
    CustomHud = false,
    WebhookEnabled = false,
    WebhookUrl = "",
    WebhookTalents = {},
    WebhookRares = {},
}
Shared.State = State

-- [2x Speed Hooks]
pcall(function()
    local PassPrivilegeService = require(ReplicatedStorage.Script.PassPrivilege.PassPrivilegeService)
    if not Env._OuroborosSpeedHooked then
        Env._OuroborosSpeedHooked = true
        local old = PassPrivilegeService.isPrivilegeActivated
        PassPrivilegeService.isPrivilegeActivated = function(...)
            local args = {...}
            for _, v in ipairs(args) do
                if v == 18 and State.Unlock2xSpeed then
                    return ErrorCode.SUCCEEDED, true
                end
            end
            return old(...)
        end
    end
end)

pcall(function()
    local MainBattleWindowController = require(ReplicatedStorage.Controller.MainBattleWindowController)
    if not Env._OuroborosAutoSpeedHooked then
        Env._OuroborosAutoSpeedHooked = true
        local old_get = MainBattleWindowController.getBattlePlaybackSpeed
        MainBattleWindowController.getBattlePlaybackSpeed = function(...)
            if type(State.BattleSpeed) == "number" and State.BattleSpeed > 1 then return State.BattleSpeed end
            if State.AutoSpeedUpBattle then return 2 end
            return old_get(...)
        end
        local old_enabled = MainBattleWindowController.isBattleSpeedEnabled
        MainBattleWindowController.isBattleSpeedEnabled = function(...)
            if type(State.BattleSpeed) == "number" and State.BattleSpeed > 1 then return true end
            if State.AutoSpeedUpBattle then return true end
            return old_enabled(...)
        end
    end
end)

local function petName(id)
    local data = PetConfig[id]
    return type(data) == "table" and (data.name or tostring(id)) or tostring(id)
end
Shared.PetName = petName

local function cleanAreaName(tile)
    local name = tostring(tile):gsub("^World%d+", ""):gsub("MonsterSubArea%d+", ""):gsub("MonsterArea%d+", ""):gsub("Area%d+", " Area")
    name = name:gsub("(%l)(%u)", "%1 %2"):gsub("^%s+", ""):gsub("%s+$", "")
    return name ~= "" and name or tostring(tile)
end

local function islandInfo(tile, area)
    local world, island = tostring(tile):match("^(World%d+)Island(%d+)")
    if world and island then
        local assetName = world .. "Island" .. island
        for _, data in pairs(IslandConfig) do
            if type(data) == "table" and data.assetName == assetName then
                return data.displayName or assetName, tonumber(data.id) or math.huge
            end
        end
    end
    local range = type(area) == "table" and area.monsterLevelRange
    return cleanAreaName(tile), type(range) == "table" and tonumber(range[1]) or tonumber(area.id) or math.huge
end

local Islands, IslandByName, MobsByIsland = {}, {}, {}

for areaId, area in pairs(AreaConfig) do
    if type(area) == "table" and type(area.monsterPool) == "table" and type(area.areaTileName) == "table" then
        local label, order = islandInfo(area.areaTileName[1] or areaId, area)
        local item = IslandByName[label]
        if not item then
            item = { label = label, order = order, areaIds = {}, mobs = {}, mobSet = {} }
            table.insert(Islands, label)
            IslandByName[label] = item
        elseif order < item.order then
            item.order = order
        end
        item.areaIds[areaId] = true
        for _, entry in ipairs(area.monsterPool) do
            local petId = type(entry) == "table" and entry[1] or entry
            local name = petName(petId)
            item.mobSet[name] = petId
        end
    end
end

for label, item in pairs(IslandByName) do
    item.mobs = {}
    for name in pairs(item.mobSet) do
        table.insert(item.mobs, name)
    end
    table.sort(item.mobs)
    MobsByIsland[label] = item.mobs
end

table.sort(Islands, function(a, b)
    local left = IslandByName[a]
    local right = IslandByName[b]
    if left.order == right.order then return a < b end
    return left.order < right.order
end)
State.Island = Islands[1]
State.Mob = "All"

Shared.Islands = Islands
Shared.IslandByName = IslandByName
Shared.MobsByIsland = MobsByIsland

local function getRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end
Shared.GetRoot = getRoot

local function getCurrentBattle()
    local ok, battle = pcall(BattleService.getCurrentBattle)
    return ok and battle or nil
end
Shared.GetCurrentBattle = getCurrentBattle

local function getCreatures()
    local ok, creatures = pcall(function()
        return Shared.ReqGetAllCreatures:InvokeServer()
    end)
    return ok and type(creatures) == "table" and creatures or {}
end
Shared.GetCreatures = getCreatures

local function getTargetCreature()
    local island = IslandByName[State.Island]
    if not island then return nil end
    local selected = State.Mob
    local selectAll, wanted = false, nil
    if type(selected) == "table" then
        for name, on in pairs(selected) do
            if on then
                if name == "All" then selectAll = true end
                wanted = wanted or {}
                wanted[name] = true
            end
        end
        if not wanted then selectAll = true end
    elseif type(selected) == "string" and selected ~= "" and selected ~= "All" then
        wanted = { [selected] = true }
    else
        selectAll = true
    end
    local best, bestDist
    local root = getRoot()
    local rootPos = root and root.Position
    for _, creature in pairs(getCreatures()) do
        if type(creature) == "table" and creature.type == 3 and creature.aliveState == 1 and creature.isCombating ~= true and island.areaIds[creature.areaId] then
            local name = petName(creature.configId)
            if selectAll or (wanted and wanted[name]) then
                local pos = typeof(creature.pos) == "CFrame" and creature.pos.Position or nil
                local dist = rootPos and pos and (rootPos - pos).Magnitude or 0
                if not best or dist < bestDist then
                    best = creature
                    bestDist = dist
                end
            end
        end
    end
    return best
end
Shared.GetTargetCreature = getTargetCreature

local function moveToCreature(creature)
    local root = getRoot()
    if root and typeof(creature.pos) == "CFrame" then
        root.CFrame = creature.pos * CFrame.new(0, 4, 5)
    end
end
Shared.MoveToCreature = moveToCreature

local lastAutoWant = nil
local function turnAutoBattle(on)
    local want = (on and not State.EnableCustomAutoBattle) and true or false
    pcall(function()
        Shared.ReqAutoBattle:InvokeServer(want)
    end)
    if want ~= lastAutoWant then
        lastAutoWant = want
        pcall(function()
            Shared.MainBattleWindowController.commitAutoBattleLocalState(want)
        end)
    end
end
Shared.TurnAutoBattle = turnAutoBattle

local function getBattleData()
    local battle = getCurrentBattle()
    if not battle then return nil end
    return battle.status and battle or battle.battleDataCache or battle.data or battle.battle
end
Shared.GetBattleData = getBattleData

local function getAvailableBallId(name)
    local wanted = Shared.BALL_IDS[name]
    if not wanted then return nil end
    for _, ball in ipairs(GetBallDataModule.getBallInfoList()) do
        if type(ball) == "table" and ball.itemId == wanted and ((ball.num or 0) > 0 or ball.isInfinite == true) then
            return wanted
        end
    end
end
Shared.GetAvailableBallId = getAvailableBallId

local function getBestBall(name)
    local preferred = getAvailableBallId(name)
    if preferred then return preferred end
    local best
    for _, ball in ipairs(GetBallDataModule.getBallInfoList()) do
        if type(ball) == "table" and type(ball.itemId) == "number" and ((ball.num or 0) > 0 or ball.isInfinite == true) then
            if not best or ball.itemId > best.itemId then
                best = ball
            end
        end
    end
    return best and best.itemId or nil
end
Shared.GetBestBall = getBestBall

local function buildPetEntries()
    local labels, byLabel = {}, {}
    for uid, entry in pairs(PetStorage.getPetList()) do
        if type(entry) == "table" then
            local length = 4
            local label
            repeat
                label = string.format("%s Lv%s [%s]", petName(entry.configId), tostring(entry.level or "?"), tostring(uid):sub(1, length))
                length = length + 1
            until not byLabel[label] or length > 12
            byLabel[label] = uid
            table.insert(labels, label)
        end
    end
    table.sort(labels)
    return labels, byLabel
end
Shared.BuildPetEntries = buildPetEntries

local function buildSpeciesList()
    local seen, list = {}, { "All" }
    for _, entry in pairs(PetStorage.getPetList()) do
        if type(entry) == "table" then
            local name = petName(entry.configId)
            if not seen[name] then
                seen[name] = true
                table.insert(list, name)
            end
        end
    end
    table.sort(list, function(a, b)
        if a == "All" then return true end
        if b == "All" then return false end
        return a < b
    end)
    return list
end
Shared.BuildSpeciesList = buildSpeciesList

local function refreshPetDropdowns()
    local labels, byLabel = buildPetEntries()
    Shared.LeaderPetMap = byLabel
    if Shared.Options.LeaderPet then
        Shared.Options.LeaderPet:SetValues(labels)
    end
    if Shared.Options.ReleaseSpecies then
        Shared.Options.ReleaseSpecies:SetValues(buildSpeciesList())
    end
end
Shared.RefreshPetDropdowns = refreshPetDropdowns

local function teleportToCFrame(cf)
    local root = getRoot()
    if root and typeof(cf) == "CFrame" then
        root.CFrame = cf
        return true
    end
    return false
end
Shared.TeleportToCFrame = teleportToCFrame

local function teleportToIslandName(name)
    local scene = Workspace:FindFirstChild("Scene")
    local islandFolder = scene and scene:FindFirstChild("Island")
    if not islandFolder then return false end
    local assetName
    for _, data in pairs(IslandConfig) do
        if type(data) == "table" and data.displayName == name then
            assetName = data.assetName
            break
        end
    end
    if not assetName then return false end
    local model = islandFolder:FindFirstChild(assetName)
    if not model then return false end
    local target = model:FindFirstChild("DistanceCalcPoint") or model
    local pivot = target:IsA("BasePart") and target.CFrame or (target.GetPivot and target:GetPivot())
    if pivot then
        return teleportToCFrame(pivot * CFrame.new(0, 5, 6))
    end
    return false
end
Shared.TeleportToIslandName = teleportToIslandName

local function notifyToggle(name, value)
    if Shared.SuppressNotify then return end
    Library:Notify(string.format("%s %s.", name, value and "enabled" or "disabled"), 3)
end
Shared.NotifyToggle = notifyToggle

local function isSpecialPet(entry)
    return PetComm.isShinyPet(entry.configId) == true or PetComm.isPetColorful(entry) == true or entry.talentId == 5 or entry.loved == true
end
Shared.IsSpecialPet = isSpecialPet

if isStaleLoad() then
    warn("Evomon: aborted duplicate load (a newer instance started).")
    Shared.Running = false
    return nil
end

local cleaningUp = false

Env.OuroborosEvomonCleanup = function()
    if cleaningUp then return end
    cleaningUp = true
    Shared.Running = false
    turnAutoBattle(false)
    for _, callback in ipairs(Shared.UnloadCallbacks) do
        pcall(callback)
    end
    if Library and not Library.Unloaded then
        pcall(function()
            Library:Unload()
        end)
    end
    cleaningUp = false
end

return Shared
]], "Evomon.core")
local _window = _ls([[local Shared = ...

local Library = Shared.Library
local State = Shared.State

local Window = Library:CreateWindow({
    Title = "Evomon",
    Footer = "Ouroboros Hub",
    Icon = Shared.WINDOW_IMAGE,
    Size = UDim2.fromOffset(920, 680),
    AutoShow = true,
    Center = true,
    Resizable = true,
    CornerRadius = 0,
    NotifySide = "Right",
    ShowCustomCursor = false,
    ToggleKeybind = Enum.KeyCode.RightControl,
    ShowMobileButtons = true,
    MobileButtonsSide = "Left",
    EnableSidebarResize = true,
    EnableCompacting = true,
})

local Tabs = {
    Farm = Window:AddTab("Farm", "tractor"),
    Teleport = Window:AddTab("Teleport", "map-pinned"),
    Shop = Window:AddTab("Shop", "shopping-cart"),
    Hatching = Window:AddTab("Hatching", "egg"),
    Modes = Window:AddTab("Modes", "swords"),
    Pets = Window:AddTab("Pets", "cat"),
    Data = Window:AddTab("Data", "database"),
    Combat = Window:AddTab("Combat Config", "crosshair"),
    Player = Window:AddTab("Player", "user"),
    Settings = Window:AddTab("Settings", "settings"),
}

Shared.Window = Window
Shared.Tabs = Tabs

local function addDiscordButton(box)
    box:AddButton({
        Text = "Join Discord for Dupes/Keyless Scripts",
        Tooltip = "Copies the invite link to your clipboard.",
        Func = function()
            if setclipboard then setclipboard(Shared.DISCORD_LINK) end
            Library:Notify("Discord invite copied.", 4)
        end,
    })
end
Shared.AddDiscordButton = addDiscordButton

local function mobValues()
    local values = { "All" }
    for _, name in ipairs(Shared.MobsByIsland[State.Island] or {}) do
        table.insert(values, name)
    end
    return values
end
Shared.MobValues = mobValues
]], "Evomon.window")
local _farm = _ls([[local Shared = ...

local Library = Shared.Library
local Options = Shared.Options
local Tabs = Shared.Tabs
local State = Shared.State
local ErrorCode = Shared.ErrorCode
local BattleConst = Shared.BattleConst
local BattleService = Shared.BattleService
local BattleDataGetModule = Shared.BattleDataGetModule
local ConfigDataManager = Shared.ConfigDataManager
local ConfigConst = Shared.ConfigConst
local PetComm = Shared.PetComm
local PetStorage = Shared.PetStorage
local PetService = Shared.PetService
local BagService = Shared.BagService
local AttrConst = Shared.AttrConst
local SummonMonsterService = Shared.SummonMonsterService
local DungeonService = Shared.DungeonService
local TowerDungeonService = Shared.TowerDungeonService
local DungeonModule = Shared.DungeonModule
local DungeonConfig = Shared.DungeonConfig
local NpcConfig = Shared.NpcConfig
local TalkConfig = Shared.TalkConfig
local RefreshService = Shared.RefreshService
local OperateBattle = Shared.OperateBattle
local ClientBattleAnimationComplete = Shared.ClientBattleAnimationComplete
local ReqEnterPetBattle = Shared.ReqEnterPetBattle
local petName = Shared.PetName
local getRoot = Shared.GetRoot
local getCurrentBattle = Shared.GetCurrentBattle
local getCreatures = Shared.GetCreatures
local getTargetCreature = Shared.GetTargetCreature
local moveToCreature = Shared.MoveToCreature
local turnAutoBattle = Shared.TurnAutoBattle
local getBattleData = Shared.GetBattleData
local getBestBall = Shared.GetBestBall
local notifyToggle = Shared.NotifyToggle

local function getSourcePos(data)
    local trainer = BattleDataGetModule.getLocalPlayerTrainerAndCamp(data).trainer
    return trainer and type(trainer.posList) == "table" and tonumber(trainer.posList[1]) or nil
end

local function completeBattleAnimation(data)
    if not data or not data.uid then return end
    pcall(function()
        ClientBattleAnimationComplete:Fire(data.round, tostring(data.uid))
    end)
    pcall(function()
        BattleService.sendAnimationComplete(data.round, tostring(data.uid))
    end)
end

local function skipCatchAnimation(data)
    if not State.SkipCatchAnimation then return end
    completeBattleAnimation(data)
end

local function getCatchFlags(info, data)
    local colorId, patternId = info.colorId, info.patternId
    local prismatic = type(colorId) == "number" and colorId > 0 and type(patternId) == "number" and patternId > 0
    local shiny = PetComm.isShinyPet(info.configId) == true
    local boss = data.type == BattleConst.BATTLE_TYPE.PVE_BOSS
    return shiny, prismatic, boss
end

local function autoCatch()
    local data = getBattleData()
    if not data or data.status ~= BattleConst.BATTLE_STATUS.CATCH_PET then return end
    local info = BattleDataGetModule.getLocalPlayerCatchPetInfo(data)
    if type(info) ~= "table" or type(info.pos) ~= "number" then return end
    local sourcePos = getSourcePos(data)
    if not sourcePos then return end
    local choice
    local shiny, prismatic, boss = getCatchFlags(info, data)
    if State.ShinyPrismaticFarm then
        if shiny then
            choice = State.ComboBall
        elseif prismatic then
            choice = "Skip"
        else
            choice = State.PityBall
        end
    elseif prismatic then
        choice = State.PrismaticBall
    elseif shiny then
        choice = State.ShinyBall
    elseif boss then
        choice = State.BossBall
    else
        choice = State.NormalBall
    end
    if choice == "Skip" then
        local result = OperateBattle:Invoke({ actionType = BattleConst.ACTION_TYPE.GIVE_UP_CATCH })
        if result == ErrorCode.ANIMATION_NOT_COMPLETE then
            completeBattleAnimation(data)
        else
            skipCatchAnimation(data)
        end
        return
    end
    local result = OperateBattle:Invoke({
        actionType = BattleConst.ACTION_TYPE.CATCH_PET,
        sourcePos = sourcePos,
        targetPos = info.pos,
        itemId = getBestBall(choice),
    })
    if result == ErrorCode.CATCH_PET_SUCCESS or result == ErrorCode.CATCH_PET_FAILED then
        skipCatchAnimation(data)
    elseif result == ErrorCode.ANIMATION_NOT_COMPLETE then
        completeBattleAnimation(data)
    end
end

local function autoHeal()
    local uid = PetStorage.getMainPet()
    local pets = PetStorage.getPetList()
    local pet = type(pets) == "table" and pets[uid]
    if type(pet) ~= "table" or type(pet.hp) ~= "number" then return end
    local code, maxHp = PetComm.getPetAttrValue(pet, AttrConst.ATTR.HP_BASE_VALUE)
    if code ~= ErrorCode.SUCCEEDED or type(maxHp) ~= "number" or maxHp <= 0 then return end
    local itemId = Shared.POTION_IDS[State.HealPotion]
    if itemId and pet.hp / maxHp * 100 <= State.HealPercent and BagService.getItemNumById(itemId) > 0 then
        pcall(BagService.reqUseItem, itemId, 1)
    end
end

local HttpService = game:GetService("HttpService")
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

local TALENT_NAME_BY_ID = { [1] = "C", [2] = "B", [3] = "A", [4] = "S", [5] = "SSS", [6] = "D" }

local function sendWebhook(embed)
    if type(State.WebhookUrl) ~= "string" or State.WebhookUrl == "" then
        Library:Notify("Set a Discord webhook URL first.", 4)
        return
    end
    if not httpRequest then
        Library:Notify("This executor has no HTTP request function.", 4)
        return
    end
    local body = HttpService:JSONEncode({ username = "Ouroboros Hub", embeds = { embed } })
    task.spawn(function()
        pcall(httpRequest, {
            Url = State.WebhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body,
        })
    end)
end

local function webhookMatches(entry)
    local talents = State.WebhookTalents
    local rares = State.WebhookRares
    local talentName = TALENT_NAME_BY_ID[entry.talentId]
    if type(talents) == "table" and talentName and talents[talentName] then return true end
    if type(rares) == "table" then
        if rares["Shiny"] and PetComm.isShinyPet(entry.configId) == true then return true end
        if rares["Prismatic"] and PetComm.isPetColorful(entry) == true then return true end
    end
    return false
end

local function notifyCaughtPet(entry)
    local shiny = PetComm.isShinyPet(entry.configId) == true
    local prismatic = PetComm.isPetColorful(entry) == true
    local traits = {}
    if shiny then table.insert(traits, "Shiny") end
    if prismatic then table.insert(traits, "Prismatic") end
    sendWebhook({
        title = "Pet Caught",
        color = 0x2ECC71,
        fields = {
            { name = "Pet", value = petName(entry.configId), inline = true },
            { name = "Talent", value = TALENT_NAME_BY_ID[entry.talentId] or "?", inline = true },
            { name = "Level", value = tostring(entry.level or "?"), inline = true },
            { name = "Traits", value = #traits > 0 and table.concat(traits, ", ") or "None", inline = true },
        },
    })
end

local webhookKnownPets = nil

task.spawn(function()
    while Shared.Running do
        if State.WebhookEnabled then
            local ok, pets = pcall(PetStorage.getPetList)
            if ok and type(pets) == "table" then
                if webhookKnownPets == nil then
                    webhookKnownPets = {}
                    for uid in pairs(pets) do
                        webhookKnownPets[uid] = true
                    end
                else
                    for uid, entry in pairs(pets) do
                        if not webhookKnownPets[uid] then
                            webhookKnownPets[uid] = true
                            if type(entry) == "table" and webhookMatches(entry) then
                                notifyCaughtPet(entry)
                            end
                        end
                    end
                end
            end
        else
            webhookKnownPets = nil
        end
        task.wait(2)
    end
end)

local SummonNpcByGroup = {}
for npcId, cfg in pairs(ConfigDataManager.getTable(ConfigConst.ConfigName.NPC) or {}) do
    if type(cfg) == "table" and type(cfg.monsterSummonId) == "number" then
        SummonNpcByGroup[cfg.monsterSummonId] = npcId
    end
end

local BossList, BossByLabel = {}, {}
for enemyId, cfg in pairs(ConfigDataManager.getTable(ConfigConst.ConfigName.SUMMON_ENEMY_PET) or {}) do
    if type(cfg) == "table" then
        local npcId = SummonNpcByGroup[cfg.monsterSummonId]
        if npcId then
            local label = string.format("%s (Lv%s)", petName(cfg.spawnPet), tostring(cfg.level))
            if not BossByLabel[label] then
                table.insert(BossList, label)
            end
            BossByLabel[label] = { npcId = npcId, enemyId = cfg.id or enemyId, spawnPet = cfg.spawnPet, spawnNpcId = cfg.spawnNpcId, monsterSummonId = cfg.monsterSummonId }
        end
    end
end
table.sort(BossList)

local DailyChallengeMap, EquipChallengeMap = {}, {}

local function buildChallengeLists()
    local daily, equipment = {}, {}
    DailyChallengeMap, EquipChallengeMap = {}, {}
    for id, dungeon in pairs(DungeonConfig) do
        if type(id) == "number" and type(dungeon) == "table" and type(dungeon.name) == "string" and type(dungeon.infoIds) == "table" and type(dungeon.infoIds[1]) == "table" then
            local info = ConfigDataManager.getConfig(ConfigConst.ConfigName.DUNGEON_INFO, dungeon.infoIds[1][2])
            local dungeonType = type(info) == "table" and info.type or nil
            if dungeonType == 4 or dungeonType == 5 or dungeonType == 6 then
                local label = string.format("%s - %s [Lv%s] #%d", dungeon.name, tostring(dungeon.subName or "?"), tostring(dungeon.level or "?"), id)
                if dungeonType == 4 then
                    table.insert(equipment, { label = label, id = id })
                    EquipChallengeMap[label] = id
                else
                    table.insert(daily, { label = label, id = id })
                    DailyChallengeMap[label] = id
                end
            end
        end
    end
    local function byId(a, b) return a.id < b.id end
    table.sort(daily, byId)
    table.sort(equipment, byId)
    local dailyLabels, equipLabels = {}, {}
    for _, entry in ipairs(daily) do table.insert(dailyLabels, entry.label) end
    for _, entry in ipairs(equipment) do table.insert(equipLabels, entry.label) end
    return dailyLabels, equipLabels
end

local lastUnavailableNotify = 0

local function notifyUnavailable(what)
    if os.clock() - lastUnavailableNotify > 20 then
        lastUnavailableNotify = os.clock()
        Library:Notify(what .. " is not available in this world. Travel to a world that has it.", 5)
    end
end

local ChallengeIdleTicks = 0

local function runChallengeStep(dungeonId)
    if not DungeonModule.isValidDungeon(dungeonId) then
        notifyUnavailable("This challenge")
        task.wait(5)
        return
    end
    if getCurrentBattle() then
        ChallengeIdleTicks = 0
        turnAutoBattle(true)
        return
    end
    if TowerDungeonService.getCurrentRuntimeState().isInTower == true then return end
    if DungeonService.getCurrentDungeonInstance() then
        ChallengeIdleTicks = ChallengeIdleTicks + 1
        if ChallengeIdleTicks >= 20 then
            ChallengeIdleTicks = 0
            pcall(DungeonService.tryExitDungeon)
            task.wait(2)
        end
    else
        ChallengeIdleTicks = 0
        pcall(DungeonService.applyEnterDungeon, dungeonId, nil)
        task.wait(3)
    end
end

local function findTalkBattleId(startId)
    local visited = {}
    local queue = { startId }
    while #queue > 0 do
        local id = table.remove(queue, 1)
        if not visited[id] then
            visited[id] = true
            local talk = TalkConfig[id]
            if type(talk) == "table" then
                if type(talk.battleId) == "number" then return talk.battleId end
                for _, nextId in ipairs(talk.nextTalkIds or {}) do
                    table.insert(queue, nextId)
                end
            end
        end
    end
end

local OverworldBossList, OverworldBossByName = {}, {}
for npcId, npc in pairs(NpcConfig) do
    if type(npc) == "table" and npc.isBoss == 1 and type(npc.npcName) == "string" then
        local dialogueId = type(npc.npcInitialDialogueId) == "table" and npc.npcInitialDialogueId[1] or nil
        local battleId = dialogueId and findTalkBattleId(dialogueId) or nil
        if battleId and not OverworldBossByName[npc.npcName] then
            table.insert(OverworldBossList, npc.npcName)
            OverworldBossByName[npc.npcName] = { npcId = npcId, battleId = battleId, bossType = npc.bossType }
        end
    end
end
table.sort(OverworldBossList)

local function bossOnCooldown(npcId)
    local ok, list = pcall(RefreshService.getBossRefreshInfoList)
    if not ok or type(list) ~= "table" then return false end
    local now = workspace:GetServerTimeNow()
    for _, info in ipairs(list) do
        if type(info) == "table" and info.npcId == npcId and type(info.refreshTime) == "number" and info.refreshTime > now then
            return true
        end
    end
    return false
end

local function findOverworldBoss()
    local wanted = {}
    local any = false
    local firstBoss
    for name, enabled in pairs(State.SelectedBosses) do
        local boss = enabled and OverworldBossByName[name]
        if boss and (State.BypassBossCD or not bossOnCooldown(boss.npcId)) then
            wanted[boss.npcId] = boss
            any = true
            if not firstBoss then firstBoss = boss end
        end
    end
    if not any then return nil end
    local best, bestDist
    local root = getRoot()
    local rootPos = root and root.Position
    for _, creature in pairs(getCreatures()) do
        if type(creature) == "table" and creature.type == 5 and creature.aliveState == 1 and creature.isCombating ~= true and wanted[creature.configId] then
            local pos = typeof(creature.pos) == "CFrame" and creature.pos.Position or nil
            local dist = rootPos and pos and (rootPos - pos).Magnitude or 0
            if not best or dist < bestDist then
                best = creature
                bestDist = dist
            end
        end
    end
    if best then
        return best, wanted[best.configId]
    elseif State.BypassBossCD then
        return nil, firstBoss
    end
    return nil, nil
end

local function findSummonedBoss(boss)
    local userId = Shared.LocalPlayer.UserId
    for _, creature in pairs(getCreatures()) do
        if type(creature) == "table" and creature.aliveState == 1 and creature.isCombating ~= true and tonumber(creature.configId) == boss.spawnNpcId then
            if creature.owner == nil or tonumber(creature.owner) == userId then
                return creature
            end
        end
    end
end

local function enterCreatureBattle(uid)
    if not uid then return end
    local id = tostring(uid)
    local ok = pcall(BattleService.enterPetBattle, id)
    if not ok then
        ReqEnterPetBattle:FireServer(id)
    end
end

task.spawn(function()
    while Shared.Running do
        if State.AutoBattle and getCurrentBattle() then
            turnAutoBattle(true)
        end
        task.wait(2)
    end
end)

task.spawn(function()
    while Shared.Running do
        if State.AutoCatch or State.ShinyPrismaticFarm then
            pcall(autoCatch)
        end
        task.wait(0.35)
    end
end)

task.spawn(function()
    while Shared.Running do
        if State.AutoHeal then
            pcall(autoHeal)
        end
        task.wait(2)
    end
end)

task.spawn(function()
    while Shared.Running do
        if State.AutoFarm and not getCurrentBattle() then
            local creature = getTargetCreature()
            if creature and creature.uid then
                ReqEnterPetBattle:FireServer(tostring(creature.uid))
            end
        end
        task.wait(0.7)
    end
end)

task.spawn(function()
    while Shared.Running do
        if State.AutoSummonFight and State.SummonBoss then
            local boss = BossByLabel[State.SummonBoss]
            if boss then
                if getCurrentBattle() then
                    turnAutoBattle(true)
                else
                    local target = findSummonedBoss(boss)
                    if target and target.uid then
                        moveToCreature(target)
                        task.wait(0.1)
                        enterCreatureBattle(target.uid)
                        task.wait(0.2)
                    else
                        pcall(SummonMonsterService.manualSummon, boss.npcId, boss.enemyId)
                        task.wait(1.5)
                    end
                end
            end
        end
        task.wait(0.2)
    end
end)

task.spawn(function()
    while Shared.Running do
        if State.AutoTower then
            local rt = TowerDungeonService.getCurrentRuntimeState()
            if State.TowerStopFloor > 0 and rt.isInTower == true and (tonumber(rt.currentLayer) or 0) >= State.TowerStopFloor then
                pcall(TowerDungeonService.requestExitTower)
                State.AutoTower = false
                Shared.SuppressNotify = true
                if Shared.Toggles.AutoTower then Shared.Toggles.AutoTower:SetValue(false) end
                Shared.SuppressNotify = false
                if Shared.TeleportToIslandName then Shared.TeleportToIslandName("Verdant Valley") end
                Library:Notify(string.format("Auto Tower: reached floor %s, leaving the tower.", tostring(rt.currentLayer)), 5)
            elseif getCurrentBattle() then
                turnAutoBattle(true)
            elseif rt.isInTower ~= true then
                local dungeonId = TowerDungeonService.getDungeonIdByLayer(State.TowerStartFloor)
                if dungeonId and DungeonModule.isValidDungeon(dungeonId) then
                    if Shared.TeleportToIslandName then Shared.TeleportToIslandName("Maincity") end
                    task.wait(0.5)
                    pcall(TowerDungeonService.startTowerDungeonFlow, State.TowerStartFloor)
                    task.wait(3)
                else
                    notifyUnavailable("The Tower")
                    task.wait(5)
                end
            elseif rt.isTransitioning ~= true and TowerDungeonService.canEnterBattleNow() == true then
                pcall(TowerDungeonService.requestEnterBattle)
                task.wait(2)
            end
        end
        task.wait(1)
    end
end)

task.spawn(function()
    while Shared.Running do
        if State.AutoBossFarm then
            if getCurrentBattle() then
                turnAutoBattle(true)
            else
                local _, boss = findOverworldBoss()
                if boss then
                    if boss.bossType == 2 then
                        BattleService.enterNpcBattle(boss.npcId, boss.battleId)
                    else
                        BattleService.enterActualNpcBattle(boss.npcId, boss.battleId, PetStorage.getMainPet())
                    end
                    task.wait(2)
                end
            end
        end
        task.wait(1)
    end
end)

task.spawn(function()
    while Shared.Running do
        if State.AutoDailyChallenge and State.DailyChallenge and DailyChallengeMap[State.DailyChallenge] then
            runChallengeStep(DailyChallengeMap[State.DailyChallenge])
        elseif State.AutoEquipChallenge and State.EquipChallenge and EquipChallengeMap[State.EquipChallenge] then
            runChallengeStep(EquipChallengeMap[State.EquipChallenge])
        end
        task.wait(1)
    end
end)

local MainTabbox = Tabs.Farm:AddLeftTabbox("Main")
local FarmBox = MainTabbox:AddTab("Main", "swords")
local WebhookBox = MainTabbox:AddTab("Webhook", "webhook")
local CatchBox = Tabs.Farm:AddRightGroupbox("Auto Catch", "circle-dot")
local ShinyPrismaticBox = Tabs.Farm:AddRightGroupbox("Shiny + Prismatic", "sparkles")
local AutoBossBox = Tabs.Farm:AddLeftGroupbox("Auto Boss (Overworld)", "skull")
local HealBox = Tabs.Farm:AddLeftGroupbox("Auto Heal", "heart-pulse")

Shared.AddDiscordButton(FarmBox)

FarmBox:AddToggle("AutoFarm", {
    Text = "Auto Farm",
    Tooltip = "Moves between selected mobs and starts farming them automatically.",
    Default = false,
    Callback = function(value)
        State.AutoFarm = value
        notifyToggle("Auto Farm", value)
    end,
})

FarmBox:AddToggle("AutoBattle", {
    Text = "Auto Battle",
    Tooltip = "Controls the in-game auto battle state while a battle is active.",
    Default = false,
    Callback = function(value)
        State.AutoBattle = value
        turnAutoBattle(value)
        notifyToggle("Auto Battle", value)
    end,
})

FarmBox:AddToggle("Unlock2xSpeed", {
    Text = "Unlock 2x Speed",
    Tooltip = "Temporarily requests the 2x battle speed unlock while this is enabled.",
    Default = false,
    Callback = function(value)
        State.Unlock2xSpeed = value
        if value then
            Library:Notify("Unlocked 2x speed", 3)
        else
            Library:Notify("Reverted 2x speed", 3)
        end
    end,
})

FarmBox:AddToggle("AutoSpeedUpBattle", {
    Text = "Auto Speed Up Battle",
    Tooltip = "Automatically requests faster battle speed after battles start.",
    Default = false,
    Callback = function(value)
        State.AutoSpeedUpBattle = value
        notifyToggle("Auto Speed Up Battle", value)
    end,
})

FarmBox:AddSlider("BattleSpeed", {
    Text = "Battle Speed",
    Tooltip = "Multiplies battle animation playback speed. 1x uses the game's normal speed.",
    Default = State.BattleSpeed,
    Min = 1,
    Max = 50,
    Rounding = 0,
    Suffix = "x",
    Callback = function(value)
        State.BattleSpeed = value
    end,
})

WebhookBox:AddToggle("WebhookEnabled", {
    Text = "Enable Webhook",
    Tooltip = "Sends a Discord message when a newly obtained pet matches Notify Talent or Notify Rare.",
    Default = false,
    Callback = function(value)
        State.WebhookEnabled = value
        notifyToggle("Webhook", value)
    end,
})

WebhookBox:AddInput("WebhookUrl", {
    Text = "Discord Webhook URL",
    Tooltip = "Discord webhook URL messages are sent to.",
    Default = "",
    Placeholder = "https://discord.com/api/webhooks/...",
    Finished = true,
    Callback = function(value)
        State.WebhookUrl = tostring(value or "")
    end,
})

WebhookBox:AddButton({
    Text = "Test Webhook",
    Tooltip = "Sends a test message to the configured webhook URL.",
    Func = function()
        sendWebhook({
            title = "Test Webhook",
            description = "Ouroboros Hub webhook is working.",
            color = 0x2ECC71,
        })
        Library:Notify("Test webhook sent.", 3)
    end,
})

WebhookBox:AddDropdown("WebhookTalents", {
    Text = "Notify Talent",
    Tooltip = "Sends a webhook message when you obtain a pet with one of these talents.",
    Values = { "C", "B", "A", "S", "SSS" },
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.WebhookTalents = value
    end,
})

WebhookBox:AddDropdown("WebhookRares", {
    Text = "Notify Rare",
    Tooltip = "Sends a webhook message when you obtain a shiny or prismatic pet.",
    Values = { "Shiny", "Prismatic" },
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.WebhookRares = value
    end,
})

CatchBox:AddToggle("AutoCatch", {
    Text = "Auto Catch",
    Tooltip = "Automatically catches encounters using the ball rules below. Set a ball to Skip to ignore that type.",
    Default = false,
    Callback = function(value)
        State.AutoCatch = value
        notifyToggle("Auto Catch", value)
    end,
})

CatchBox:AddToggle("SkipCatchAnimation", {
    Text = "Skip Catch Animation",
    Tooltip = "Skips the catch animation after catch attempts when supported.",
    Default = true,
    Callback = function(value)
        State.SkipCatchAnimation = value
    end,
})

CatchBox:AddDropdown("ShinyBall", {
    Text = "Shiny",
    Tooltip = "Ball used for shiny encounters.",
    Values = Shared.BALL_VALUES,
    Default = State.ShinyBall,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.ShinyBall = value
    end,
})

CatchBox:AddDropdown("PrismaticBall", {
    Text = "Prismatic",
    Tooltip = "Ball used for prismatic encounters.",
    Values = Shared.BALL_VALUES,
    Default = State.PrismaticBall,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.PrismaticBall = value
    end,
})

CatchBox:AddDropdown("NormalBall", {
    Text = "Normal",
    Tooltip = "Ball used for normal encounters. Choose Skip to avoid catching normal pets.",
    Values = Shared.SKIP_BALL_VALUES,
    Default = State.NormalBall,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.NormalBall = value
    end,
})

CatchBox:AddDropdown("BossBall", {
    Text = "Boss",
    Tooltip = "Ball used for boss encounters. Choose Skip to avoid catching bosses.",
    Values = Shared.SKIP_BALL_VALUES,
    Default = State.BossBall,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.BossBall = value
    end,
})

ShinyPrismaticBox:AddToggle("ShinyPrismaticFarm", {
    Text = "Combo Hunt",
    Tooltip = "Focuses catching around shiny/prismatic pity and combo targets.",
    Default = false,
    Callback = function(value)
        State.ShinyPrismaticFarm = value
        notifyToggle("Combo Hunt", value)
    end,
})

ShinyPrismaticBox:AddDropdown("PityBall", {
    Text = "Pity Builder Ball",
    Tooltip = "Ball used while building pity toward shiny/prismatic chances.",
    Values = Shared.BALL_VALUES,
    Default = State.PityBall,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.PityBall = value
    end,
})

ShinyPrismaticBox:AddDropdown("ComboBall", {
    Text = "Combo Catch Ball",
    Tooltip = "Ball used when the shiny/prismatic combo target appears.",
    Values = Shared.BALL_VALUES,
    Default = State.ComboBall,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.ComboBall = value
    end,
})

FarmBox:AddDropdown("IslandSelect", {
    Text = "Islands to Farm",
    Tooltip = "Changing island refreshes the mob list and resets mob selection to All.",
    Values = Shared.Islands,
    Default = State.Island,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.Island = value
        Options.MobSelect:SetValues(Shared.MobValues())
        Options.MobSelect:SetValue({ All = true })
    end,
})

FarmBox:AddDropdown("MobSelect", {
    Text = "Mobs",
    Tooltip = "Select one or more mobs. All farms every mob found for the selected island.",
    Values = Shared.MobValues(),
    Default = { "All" },
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.Mob = value
    end,
})

HealBox:AddToggle("AutoHeal", {
    Text = "Auto Heal",
    Tooltip = "Uses the selected potion when your HP falls below the chosen percent.",
    Default = false,
    Callback = function(value)
        State.AutoHeal = value
        notifyToggle("Auto Heal", value)
    end,
})

HealBox:AddDropdown("HealPotion", {
    Text = "HP Potion",
    Tooltip = "Potion type Auto Heal will use.",
    Values = Shared.POTION_VALUES,
    Default = State.HealPotion,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.HealPotion = value
    end,
})

HealBox:AddSlider("HealPercent", {
    Text = "Heal Below HP%",
    Tooltip = "Auto Heal triggers when HP is below this percentage.",
    Default = State.HealPercent,
    Min = 5,
    Max = 95,
    Rounding = 0,
    Suffix = "%",
    Callback = function(value)
        State.HealPercent = value
    end,
})

local TowerBox = Tabs.Modes:AddLeftGroupbox("Auto Tower", "building-2")
local DailyBox = Tabs.Modes:AddLeftGroupbox("Daily Challenge (EXP / Evolution)", "calendar-check")
local EquipBox = Tabs.Modes:AddRightGroupbox("Equipment Challenge", "shield")

TowerBox:AddToggle("AutoTower", {
    Text = "Auto Tower",
    Tooltip = "Automatically runs tower battles starting from the selected floor.",
    Default = false,
    Callback = function(value)
        State.AutoTower = value
        notifyToggle("Auto Tower", value)
    end,
})

TowerBox:AddInput("TowerStartFloor", {
    Text = "Start Floor",
    Tooltip = "Minimum tower floor to start from. Values below 1 are clamped to 1.",
    Default = "1",
    Numeric = true,
    Finished = true,
    Callback = function(value)
        State.TowerStartFloor = math.max(math.floor(tonumber(value) or 1), 1)
    end,
})

TowerBox:AddInput("TowerStopFloor", {
    Text = "Auto Leave At Floor (0 = off)",
    Tooltip = "When your tower floor reaches this number, Auto Tower leaves the tower and turns off. Set 0 to disable.",
    Default = "0",
    Numeric = true,
    Finished = true,
    Callback = function(value)
        State.TowerStopFloor = math.max(math.floor(tonumber(value) or 0), 0)
    end,
})

local DailyChallengeLabels, EquipChallengeLabels = buildChallengeLists()

DailyBox:AddToggle("AutoDailyChallenge", {
    Text = "Auto Daily Challenge",
    Tooltip = "Automatically enters and battles the selected daily challenge.",
    Default = false,
    Callback = function(value)
        State.AutoDailyChallenge = value
        notifyToggle("Auto Daily Challenge", value)
    end,
})

DailyBox:AddDropdown("DailyChallenge", {
    Text = "Challenge",
    Tooltip = "Daily EXP or evolution challenge to run.",
    Values = DailyChallengeLabels,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.DailyChallenge = value
    end,
})

DailyBox:AddButton({
    Text = "Refresh List",
    Tooltip = "Rebuilds the daily and equipment challenge lists from current game data.",
    Func = function()
        local daily, equipment = buildChallengeLists()
        Options.DailyChallenge:SetValues(daily)
        Options.EquipChallenge:SetValues(equipment)
        Library:Notify("Challenge lists refreshed.", 3)
    end,
})

EquipBox:AddToggle("AutoEquipChallenge", {
    Text = "Auto Equipment Challenge",
    Tooltip = "Automatically enters and battles the selected equipment challenge.",
    Default = false,
    Callback = function(value)
        State.AutoEquipChallenge = value
        notifyToggle("Auto Equipment Challenge", value)
    end,
})

EquipBox:AddDropdown("EquipChallenge", {
    Text = "Zone",
    Tooltip = "Equipment challenge zone to run.",
    Values = EquipChallengeLabels,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.EquipChallenge = value
    end,
})

EquipBox:AddButton({
    Text = "Refresh List",
    Tooltip = "Rebuilds the daily and equipment challenge lists from current game data.",
    Func = function()
        local daily, equipment = buildChallengeLists()
        Options.DailyChallenge:SetValues(daily)
        Options.EquipChallenge:SetValues(equipment)
        Library:Notify("Challenge lists refreshed.", 3)
    end,
})

AutoBossBox:AddToggle("AutoBossFarm", {
    Text = "Auto Boss Farm",
    Tooltip = "Finds selected overworld bosses and starts their battles automatically.",
    Default = false,
    Callback = function(value)
        State.AutoBossFarm = value
        notifyToggle("Auto Boss Farm", value)
    end,
})

AutoBossBox:AddToggle("BypassBossCD", {
    Text = "Bypass CD",
    Tooltip = "Attempts to bypass boss cooldown where the game allows it.",
    Default = false,
    Callback = function(value)
        State.BypassBossCD = value
        notifyToggle("Bypass Boss CD", value)
    end,
})

AutoBossBox:AddDropdown("SelectedBosses", {
    Text = "Bosses (empty = none)",
    Tooltip = "Select bosses for Auto Boss Farm. Empty means no boss will be targeted.",
    Values = OverworldBossList,
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.SelectedBosses = value
    end,
})

local BossBox = Tabs.Farm:AddLeftGroupbox("Boss Summon", "flame")

BossBox:AddDropdown("SummonBoss", {
    Text = "Boss to summon",
    Tooltip = "Boss used by Auto Summon and Battle.",
    Values = BossList,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.SummonBoss = value
    end,
})

BossBox:AddToggle("AutoSummonFight", {
    Text = "Auto Summon and Battle",
    Tooltip = "Summons the selected boss and starts the fight automatically.",
    Default = false,
    Callback = function(value)
        State.AutoSummonFight = value
        notifyToggle("Auto Summon and Battle", value)
    end,
})

do
    local leaderLabels, leaderByLabel = Shared.BuildPetEntries()
    Shared.LeaderPetMap = leaderByLabel

    BossBox:AddDropdown("LeaderPet", {
        Text = "Lead pet",
        Tooltip = "Sets this pet as main pet for boss summons and release protection.",
        Values = leaderLabels,
        AllowNull = true,
        Searchable = true,
        Callback = function(value)
            local uid = Shared.LeaderPetMap[value]
            State.LeaderPet = uid
            if uid then
                pcall(PetService.reqSetMainPet, uid)
                Library:Notify("Lead pet set.", 3)
            end
        end,
    })
end

BossBox:AddButton({
    Text = "Reload Pets",
    Tooltip = "Refreshes pet dropdowns after catching, releasing, or changing teams.",
    Func = function()
        Shared.RefreshPetDropdowns()
        Library:Notify("Pet lists refreshed.", 3)
    end,
})
]], "Evomon.farm")
local _claims = _ls([[local Shared = ...

local Library = Shared.Library
local Tabs = Shared.Tabs
local State = Shared.State
local Env = Shared.Env
local LocalPlayer = Shared.LocalPlayer
local ErrorCode = Shared.ErrorCode
local ConfigDataManager = Shared.ConfigDataManager
local ConfigConst = Shared.ConfigConst
local UIManager = Shared.UIManager
local MailService = Shared.MailService
local PetManualService = Shared.PetManualService
local DailyRewardService = Shared.DailyRewardService
local BattlePassService = Shared.BattlePassService
local PlayerLevelRewardService = Shared.PlayerLevelRewardService
local TaskService = Shared.TaskService
local TaskConst = Shared.TaskConst
local ChestService = Shared.ChestService
local ChestConst = Shared.ChestConst
local PubStorage = Shared.PubStorage
local OnlineRewardStorage = Shared.OnlineRewardStorage
local ReqApplyOnlineReward = Shared.ReqApplyOnlineReward
local ReqClaimExploreReward = Shared.ReqClaimExploreReward
local ReqEnterPetBattle = Shared.ReqEnterPetBattle
local ReqCompleteTask = Shared.ReqCompleteTask
local ReqClaimActiveReward = Shared.ReqClaimActiveReward
local getRoot = Shared.GetRoot
local getCurrentBattle = Shared.GetCurrentBattle
local turnAutoBattle = Shared.TurnAutoBattle

local function claimMail()
    local ok, count = pcall(MailService.getCanClaimRewardCount)
    if ok and type(count) == "number" and count > 0 then
        pcall(MailService.reqClaimAllMailReward)
    end
end

local function claimPetManual()
    pcall(PetManualService.applyClaimAllRewards)
end

local function getEvents()
    return ConfigDataManager.getTable(ConfigConst.ConfigName.EVENTS) or {}
end

local function claimOnlineRewards()
    for eventId, event in pairs(getEvents()) do
        if type(event) == "table" and event.type == 3 and type(event.rewards) == "table" then
            local ok, _, onlineTime = pcall(OnlineRewardStorage.getCurrentOnlineTime, eventId)
            if ok and type(onlineTime) == "number" then
                for index, reward in ipairs(event.rewards) do
                    local _, code, state = pcall(OnlineRewardStorage.getOnlineRewardState, eventId, index)
                    if code == ErrorCode.SUCCEEDED and state ~= 1 and type(reward) == "table" and onlineTime >= (reward[2] or math.huge) then
                        pcall(function()
                            ReqApplyOnlineReward:InvokeServer(eventId, index)
                        end)
                    end
                end
            end
        end
    end
end

local function claimDailyRewards()
    for eventId, event in pairs(getEvents()) do
        if type(event) == "table" and event.type == 1 and type(event.rewards) == "table" then
            local _, initCode, initialized = pcall(DailyRewardService.getDailyRewardIsInit, eventId)
            if initCode == ErrorCode.SUCCEEDED and initialized then
                for index in ipairs(event.rewards) do
                    local ok, code = pcall(DailyRewardService.canClaimDailyReward, eventId, index)
                    if ok and code == ErrorCode.SUCCEEDED then
                        pcall(DailyRewardService.claimDailyReward, eventId, index)
                    end
                end
            end
        end
    end
end

local function claimBattlePass()
    local ok, code, season = pcall(BattlePassService.getSeasonData)
    if ok and code == ErrorCode.SUCCEEDED and type(season) == "table" then
        local _, passCode, passId = pcall(BattlePassService.resolveSeasonPassId, season)
        if passCode == ErrorCode.SUCCEEDED and type(passId) == "number" then
            pcall(BattlePassService.reqClaimBattlePassReward, passId)
        end
    end
end

local function claimLevelRewards()
    pcall(function()
        if PlayerLevelRewardService.canClaimAnyReward() then
            PlayerLevelRewardService.applyClaimPlayerLevelReward()
        end
    end)
end

local function claimTasks(achievements)
    local data = TaskService.getTaskModuleData()
    if type(data) ~= "table" or type(data.taskList) ~= "table" then return end
    local TaskConfig = ConfigDataManager.getTable(ConfigConst.ConfigName.TASK) or {}
    local GoalStorage
    pcall(function() GoalStorage = require(game:GetService("ReplicatedStorage").Storage.GoalStorage) end)
    local goalData = GoalStorage and GoalStorage:getGoalModuleData()

    for taskId, task in pairs(data.taskList) do
        if TaskService.isTaskClaimable(task, goalData) then
            local taskCfg = TaskConfig[taskId]
            if type(taskCfg) == "table" then
                local isAchievement = taskCfg.type == TaskConst.TaskType.ACHIEVEMENT
                if isAchievement == achievements then
                    pcall(function()
                        ReqCompleteTask:InvokeServer(taskId)
                    end)
                end
            end
        end
    end
end

local function claimActiveRewards()
    for index = TaskService.getActiveClaimIndex() + 1, 12 do
        pcall(function()
            ReqClaimActiveReward:InvokeServer()
        end)
        task.wait(0.05)
    end
end

local POPUP_NAME_PATTERNS = { "RewardTip", "RewardClaim", "Obtain", "Notify", "CatchTip", "Congrat" }

local function dismissPopups()
    local ok, list = pcall(UIManager.getOpenedUIWindowList)
    if not ok or type(list) ~= "table" then return end
    for _, window in pairs(list) do
        if type(window) == "table" and type(window.name) == "string" and type(window.enumId) == "number" then
            for _, pattern in ipairs(POPUP_NAME_PATTERNS) do
                if window.name:find(pattern) then
                    pcall(UIManager.close, window.enumId)
                    break
                end
            end
        end
    end
end

local function claimAll()
    claimMail()
    claimPetManual()
    claimOnlineRewards()
    claimDailyRewards()
    claimBattlePass()
    claimLevelRewards()
    claimTasks(false)
    claimTasks(true)
    claimActiveRewards()
    dismissPopups()
end

local function collectChests(force)
    local folder = workspace:WaitForChild("RuntimeCache"):WaitForChild("RuntimeCacheClient"):WaitForChild("Chest")
    if not folder then return end
    local root = getRoot()
    if not root then return end
    local chests = {}
    for _, chest in ipairs(folder:GetChildren()) do
        local ok, pivot = pcall(function()
            return chest:GetPivot()
        end)
        if ok and type(chest.Name) == "string" then
            table.insert(chests, {
                uid = chest.Name,
                pivot = pivot,
                distance = (root.Position - pivot.Position).Magnitude,
            })
        end
    end
    table.sort(chests, function(a, b)
        return a.distance < b.distance
    end)
    for _, chest in ipairs(chests) do
        if not force and (not Shared.Running or not State.CollectChests) then break end
        local character = LocalPlayer.Character
        if character then
            character:PivotTo(chest.pivot * CFrame.new(0, 4, 5))
        else
            root.CFrame = chest.pivot * CFrame.new(0, 4, 5)
        end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        task.wait(0.75)
        pcall(function()
            ReqClaimExploreReward:InvokeServer(chest.uid)
        end)
        task.wait(0.35)
    end
end

Env.OuroborosEvomonCollectChests = function()
    collectChests(true)
end

local lastGuardChestAttempt = {}

local function getGuardMonsterUid(chestUid)
    local pub = PubStorage.getPubByUid(chestUid)
    if not pub then return nil end
    local guardUid = pub:get(ChestConst.FIELD_NAME.GUARD_MONSTER_UID)
    return guardUid and tostring(guardUid) or nil
end

local function collectGuardedChests(force)
    if getCurrentBattle() then
        turnAutoBattle(true)
        return
    end

    local folder = workspace:WaitForChild("RuntimeCache"):WaitForChild("RuntimeCacheClient"):WaitForChild("Chest")
    if not folder then return end
    local root = getRoot()
    if not root then return end
    local chests = {}
    for _, chest in ipairs(folder:GetChildren()) do
        local uid = chest.Name
        if type(uid) == "string" and ChestService.isChestChallengeable(uid) then
            local guardUid = getGuardMonsterUid(uid)
            local ok, pivot = pcall(function()
                return chest:GetPivot()
            end)
            if ok and guardUid then
                table.insert(chests, {
                    uid = uid,
                    guardUid = guardUid,
                    pivot = pivot,
                    distance = (root.Position - pivot.Position).Magnitude,
                })
            end
        end
    end
    table.sort(chests, function(a, b)
        return a.distance < b.distance
    end)

    local now = os.clock()
    for _, chest in ipairs(chests) do
        if not force and (not Shared.Running or not State.AutoGuardChests) then break end
        if (lastGuardChestAttempt[chest.uid] or 0) + (tonumber(State.GuardChestDelay) or 10) <= now then
            local character = LocalPlayer.Character
            if character then
                character:PivotTo(chest.pivot * CFrame.new(0, 4, 5))
            else
                root.CFrame = chest.pivot * CFrame.new(0, 4, 5)
            end
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            task.wait(0.4)
            lastGuardChestAttempt[chest.uid] = os.clock()
            ReqEnterPetBattle:FireServer(tostring(chest.guardUid))
            for _ = 1, 10 do
                if getCurrentBattle() then break end
                task.wait(0.5)
            end
            if getCurrentBattle() then
                turnAutoBattle(true)
                return
            end
        end
    end
end

task.spawn(function()
    while Shared.Running do
        if State.AutoClaimMail then claimMail() end
        if State.AutoClaimPetManual then claimPetManual() end
        if State.AutoClaimOnlineReward then claimOnlineRewards() end
        if State.AutoClaimDaily then claimDailyRewards() end
        if State.AutoClaimBattlePass then claimBattlePass() end
        if State.AutoClaimLevelRewards then claimLevelRewards() end
        if State.AutoClaimQuests then claimTasks(false) claimActiveRewards() end
        if State.AutoClaimAchievements then claimTasks(true) end
        if State.AutoDismissPopups then dismissPopups() end
        if State.CollectChests then collectChests() end
        if State.AutoGuardChests then collectGuardedChests() end
        task.wait(5)
    end
end)

local ExtraBox = Tabs.Farm:AddRightGroupbox("Extra", "gift")

ExtraBox:AddToggle("AutoClaimMail", {
    Text = "Auto Claim Mail",
    Tooltip = "Claims available mailbox rewards during the claim loop.",
    Default = false,
    Callback = function(value)
        State.AutoClaimMail = value
    end,
})

ExtraBox:AddToggle("AutoClaimPetManual", {
    Text = "Auto Claim Pet Manual",
    Tooltip = "Claims available pet manual rewards during the claim loop.",
    Default = false,
    Callback = function(value)
        State.AutoClaimPetManual = value
    end,
})

ExtraBox:AddToggle("AutoClaimOnlineReward", {
    Text = "Auto Claim Online Reward",
    Tooltip = "Claims timed online rewards when they become available.",
    Default = false,
    Callback = function(value)
        State.AutoClaimOnlineReward = value
    end,
})

ExtraBox:AddToggle("AutoClaimDaily", {
    Text = "Auto Claim Daily",
    Tooltip = "Claims daily rewards when available.",
    Default = false,
    Callback = function(value)
        State.AutoClaimDaily = value
    end,
})

ExtraBox:AddToggle("AutoClaimBattlePass", {
    Text = "Auto Claim Battle Pass",
    Tooltip = "Claims battle pass rewards when available.",
    Default = false,
    Callback = function(value)
        State.AutoClaimBattlePass = value
    end,
})

ExtraBox:AddToggle("AutoClaimLevelRewards", {
    Text = "Auto Claim Level Rewards",
    Tooltip = "Claims level-up rewards when available.",
    Default = false,
    Callback = function(value)
        State.AutoClaimLevelRewards = value
    end,
})

ExtraBox:AddToggle("AutoClaimQuests", {
    Text = "Auto Claim Quests",
    Tooltip = "Claims completed quest rewards when available.",
    Default = false,
    Callback = function(value)
        State.AutoClaimQuests = value
    end,
})

ExtraBox:AddToggle("AutoClaimAchievements", {
    Text = "Auto Claim Achievements",
    Tooltip = "Claims completed achievement rewards when available.",
    Default = false,
    Callback = function(value)
        State.AutoClaimAchievements = value
    end,
})

ExtraBox:AddToggle("AutoDismissPopups", {
    Text = "Auto Dismiss Popups",
    Tooltip = "Closes common reward and result popups automatically.",
    Default = false,
    Callback = function(value)
        State.AutoDismissPopups = value
    end,
})

ExtraBox:AddToggle("CollectChests", {
    Text = "Collect Chests",
    Tooltip = "Continuously collects available world chests while enabled.",
    Default = false,
    Callback = function(value)
        State.CollectChests = value
        Shared.NotifyToggle("Collect Chests", value)
        if value then
            task.spawn(collectChests)
        end
    end,
})

ExtraBox:AddToggle("AutoGuardChests", {
    Text = "Auto Chest (Guard)",
    Tooltip = "Finds guarded chests, starts the guard battle with auto battle on; the chest opens automatically on win.",
    Default = false,
    Callback = function(value)
        State.AutoGuardChests = value
        Shared.NotifyToggle("Auto Chest (Guard)", value)
        if value then
            task.spawn(collectGuardedChests)
        end
    end,
})

ExtraBox:AddSlider("GuardChestDelay", {
    Text = "Guard Chest Delay",
    Tooltip = "Seconds to wait before re-attempting the same guard chest, so it does not teleport away before hitting the guard.",
    Default = State.GuardChestDelay,
    Min = 10,
    Max = 180,
    Rounding = 0,
    Suffix = "s",
    Callback = function(value)
        State.GuardChestDelay = value
    end,
})

ExtraBox:AddButton({
    Text = "Collect Chests Now",
    Tooltip = "Runs one immediate chest collection pass.",
    Func = function()
        task.spawn(Env.OuroborosEvomonCollectChests)
        Library:Notify("Collecting available chests.", 3)
    end,
})

ExtraBox:AddButton({
    Text = "Claim All Now",
    Tooltip = "Runs one immediate pass for all supported reward claims.",
    Func = function()
        claimAll()
        Library:Notify("Claim pass finished.", 3)
    end,
})
]], "Evomon.claims")
local _combat = _ls([[local Shared = ...

local ReplicatedStorage = Shared.ReplicatedStorage
local Library = Shared.Library
local Options = Shared.Options
local UserInputService = Shared.UserInputService
local Tabs = Shared.Tabs
local State = Shared.State
local PetConfig = Shared.PetConfig
local PetStorage = Shared.PetStorage
local PetGroupStorage = Shared.PetGroupStorage
local PetGroupService = Shared.PetGroupService
local petName = Shared.PetName
local getCurrentBattle = Shared.GetCurrentBattle
local getBattleData = Shared.GetBattleData
local turnAutoBattle = Shared.TurnAutoBattle
local notifyToggle = Shared.NotifyToggle

local CustomSkillOrderIndexes = {}

local SkillRotationsHttp = game:GetService("HttpService")
local SKILL_ROTATIONS_FOLDER = "OuroborosHub/Evomon"
local SKILL_ROTATIONS_FILE = SKILL_ROTATIONS_FOLDER .. "/skill_rotations.json"

local function ensureSkillRotationsFolder()
    if not (makefolder and isfolder) then return end
    if not isfolder("OuroborosHub") then pcall(makefolder, "OuroborosHub") end
    if not isfolder(SKILL_ROTATIONS_FOLDER) then pcall(makefolder, SKILL_ROTATIONS_FOLDER) end
end

local function saveSkillRotations()
    if not writefile then return end
    ensureSkillRotationsFolder()
    local data = {}
    for configId, order in pairs(State.CustomSkillOrders) do
        if type(order) == "table" and #order > 0 then
            data[tostring(configId)] = order
        end
    end
    pcall(function() writefile(SKILL_ROTATIONS_FILE, SkillRotationsHttp:JSONEncode(data)) end)
end

local function loadSkillRotations()
    if not (isfile and readfile and isfile(SKILL_ROTATIONS_FILE)) then return end
    local ok, decoded = pcall(function() return SkillRotationsHttp:JSONDecode(readfile(SKILL_ROTATIONS_FILE)) end)
    if not (ok and type(decoded) == "table") then return end
    for key, order in pairs(decoded) do
        local configId = tonumber(key)
        if configId and type(order) == "table" then
            local clone = {}
            for _, token in ipairs(order) do
                if type(token) == "string" then table.insert(clone, token) end
            end
            if #clone > 0 then
                State.CustomSkillOrders[configId] = clone
            end
        end
    end
end

loadSkillRotations()

local CC = {
    SkillConfig = require(ReplicatedStorage.Config:WaitForChild("SkillConfig")),
    SkillPoolConfig = require(ReplicatedStorage.Config:WaitForChild("SkillPoolConfig")),
    Controller = require(ReplicatedStorage.Controller:WaitForChild("MainBattleWindowController")),
    BattleData = require(ReplicatedStorage.Script:WaitForChild("MainBattleWindow"):WaitForChild("BattleDataGetModule")),
    DEFAULT_ORDER = { "1" },
}

function CC.skillBySlot(selfPet, slot)
    local skills = selfPet.skills
    local s = type(skills) == "table" and slot and skills[slot]
    return type(s) == "table" and s.type == 1 and s or nil
end

function CC.ultimateSkill(selfPet)
    local skills = selfPet.skills
    if type(skills) ~= "table" then return nil end
    for _, s in ipairs(skills) do
        if type(s) == "table" and s.type == 2 then return s end
    end
    return nil
end

function CC.isSkillUsable(s)
    if type(s) ~= "table" then return false end
    if s.lock == true then return false end
    if s.type == 2 then return true end
    if type(s.pp) == "number" then return s.pp > 0 end
    return true
end

function CC.fireSlot(slot)
    return select(1, pcall(CC.Controller.triggerNormalSkillBySlotIndex, slot))
end

function CC.fireUltimate()
    return select(1, pcall(CC.Controller.triggerUltimateSkill))
end

function CC.ultimateNameForPet(entry)
    local petCfg = PetConfig[entry.configId]
    local poolId = type(petCfg) == "table" and petCfg.skillPoolId
    local pool = poolId and CC.SkillPoolConfig[poolId]
    if type(pool) ~= "table" or type(pool.chargeSkillList) ~= "table" then return nil end
    local level = tonumber(entry.level) or 1
    local bestId, bestReq
    for _, pair in ipairs(pool.chargeSkillList) do
        local sid, req = pair[1], pair[2]
        if type(sid) == "number" and type(req) == "number" then
            if req <= level and (not bestReq or req >= bestReq) then
                bestReq = req
                bestId = sid
            elseif not bestId then
                bestId = sid
            end
        end
    end
    local cfg = bestId and CC.SkillConfig[bestId]
    return type(cfg) == "table" and cfg.name or nil
end

function CC.tokenDisplay(entry, token)
    if token == "Ultimate" then
        local name = CC.ultimateNameForPet(entry)
        return name and ("Ult: " .. name) or "Ultimate"
    end
    local slot = tonumber(token)
    local s = slot and type(entry.skillList) == "table" and entry.skillList[slot]
    local cfg = type(s) == "table" and CC.SkillConfig[s.configId]
    return type(cfg) == "table" and cfg.name or ("Skill " .. tostring(token))
end

function CC.petSkillButtons(entry)
    local buttons = {}
    local skillList = type(entry.skillList) == "table" and entry.skillList or {}
    for i = 1, 3 do
        local s = skillList[i]
        if type(s) == "table" and s.configId then
            local cfg = CC.SkillConfig[s.configId]
            local name = type(cfg) == "table" and cfg.name or ("Skill " .. i)
            table.insert(buttons, { token = tostring(i), name = name })
        end
    end
    table.insert(buttons, { token = "Ultimate", name = CC.ultimateNameForPet(entry) or "Ultimate" })
    return buttons
end

function CC.handleCustomAutoBattle()
    if not State.EnableCustomAutoBattle then return end
    if not CC.Controller.getCanOperate() then return end
    local data = getBattleData()
    if not data then return end
    local selfPet = CC.Controller.getLocalCurrentSelfPet(data)
    if type(selfPet) ~= "table" or type(selfPet.skills) ~= "table" then return end

    local uid = tostring(selfPet.uid)
    local order = State.CustomSkillOrders[selfPet.configId]
    if type(order) ~= "table" or #order == 0 then order = CC.DEFAULT_ORDER end
    if not CustomSkillOrderIndexes[uid] then CustomSkillOrderIndexes[uid] = 1 end

    local function tryToken(token)
        if token == "Ultimate" then
            if CC.isSkillUsable(CC.ultimateSkill(selfPet)) then return CC.fireUltimate() end
        else
            local slot = tonumber(token)
            if slot and CC.isSkillUsable(CC.skillBySlot(selfPet, slot)) then return CC.fireSlot(slot) end
        end
        return false
    end

    local count = #order
    for _ = 1, count do
        local idx = CustomSkillOrderIndexes[uid]
        local token = order[idx] or order[1]
        CustomSkillOrderIndexes[uid] = (idx % count) + 1
        if tryToken(token) then return end
    end

    for slot = 1, 3 do
        if CC.isSkillUsable(CC.skillBySlot(selfPet, slot)) and CC.fireSlot(slot) then return end
    end
    if CC.isSkillUsable(CC.ultimateSkill(selfPet)) then CC.fireUltimate() end
end

task.spawn(function()
    while Shared.Running do
        if State.EnableCustomAutoBattle and getCurrentBattle() then
            pcall(CC.handleCustomAutoBattle)
        end
        task.wait(0.3)
    end
end)

local function buildTeamDropdown()
    local pg = PetGroupStorage.getPetGroup()
    local list = {}
    if type(pg) == "table" and type(pg.petGroupList) == "table" then
        for i, _ in pairs(pg.petGroupList) do
            table.insert(list, "Team " .. i)
        end
    end
    return list
end

local Editor = {}

do
    local COLOR_BG = Color3.fromRGB(15, 15, 17)
    local COLOR_PANEL = Color3.fromRGB(21, 21, 24)
    local COLOR_ELEMENT = Color3.fromRGB(30, 30, 34)
    local COLOR_STROKE = Color3.fromRGB(45, 45, 52)
    local COLOR_TEXT = Color3.fromRGB(230, 230, 235)
    local COLOR_DIM = Color3.fromRGB(140, 140, 150)
    local COLOR_ACCENT = Color3.fromRGB(94, 224, 165)
    local COLOR_DANGER = Color3.fromRGB(224, 94, 94)
    local FONT_TITLE = Enum.Font.GothamBold
    local FONT_BODY = Enum.Font.GothamMedium
    local FONT_MONO = Enum.Font.Code

    local MIN_WIDTH, MIN_HEIGHT = 430, 300

    Editor.selectedUid = nil

    local gui = Instance.new("ScreenGui")
    gui.Name = "OuroborosRotationEditor"
    gui.ResetOnSpawn = false
    gui.Enabled = false
    gui.DisplayOrder = 2147483000
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

    local function petColor(configId, selected)
        local hue = ((tonumber(configId) or 0) * 0.6180339887) % 1
        if selected then
            return Color3.fromHSV(hue, 0.5, 0.95)
        end
        return Color3.fromHSV(hue, 0.4, 0.62)
    end

    local window = Instance.new("Frame")
    window.Size = UDim2.fromOffset(560, 360)
    window.Position = UDim2.new(0.5, -280, 0.5, -180)
    window.BackgroundColor3 = COLOR_BG
    window.BorderSizePixel = 0
    window.Parent = gui

    local windowStroke = Instance.new("UIStroke")
    windowStroke.Color = COLOR_STROKE
    windowStroke.Thickness = 1
    windowStroke.Parent = window

    local function makeLabel(parent, text, size, color, alignment, font)
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Font = font or FONT_BODY
        label.Text = text
        label.TextSize = size
        label.TextColor3 = color
        label.TextXAlignment = alignment or Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Parent = parent
        return label
    end

    local function makeButton(parent, text, textColor, font)
        local button = Instance.new("TextButton")
        button.BackgroundColor3 = COLOR_ELEMENT
        button.BorderSizePixel = 0
        button.AutoButtonColor = true
        button.Font = font or FONT_BODY
        button.Text = text
        button.TextSize = 12
        button.TextColor3 = textColor or COLOR_TEXT
        button.TextTruncate = Enum.TextTruncate.AtEnd
        button.Parent = parent
        return button
    end

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 34)
    header.BackgroundColor3 = COLOR_PANEL
    header.BorderSizePixel = 0
    header.Parent = window

    local title = makeLabel(header, "Skill Rotation", 13, COLOR_TEXT, nil, FONT_TITLE)
    title.Size = UDim2.new(1, -160, 1, 0)
    title.Position = UDim2.fromOffset(12, 0)

    local refreshButton = makeButton(header, "REFRESH", COLOR_DIM, FONT_TITLE)
    refreshButton.TextSize = 11
    refreshButton.Size = UDim2.fromOffset(72, 24)
    refreshButton.Position = UDim2.new(1, -112, 0, 5)

    local closeButton = makeButton(header, "X", COLOR_DIM, FONT_TITLE)
    closeButton.Size = UDim2.fromOffset(30, 24)
    closeButton.Position = UDim2.new(1, -35, 0, 5)

    local teamPanel = Instance.new("Frame")
    teamPanel.Size = UDim2.new(0, 185, 1, -50)
    teamPanel.Position = UDim2.fromOffset(8, 42)
    teamPanel.BackgroundColor3 = COLOR_PANEL
    teamPanel.BorderSizePixel = 0
    teamPanel.Parent = window

    local teamTitle = makeLabel(teamPanel, "PETS", 10, COLOR_DIM, nil, FONT_TITLE)
    teamTitle.Size = UDim2.new(1, -16, 0, 24)
    teamTitle.Position = UDim2.fromOffset(8, 0)

    local teamList = Instance.new("ScrollingFrame")
    teamList.Size = UDim2.new(1, -16, 1, -66)
    teamList.Position = UDim2.fromOffset(8, 26)
    teamList.BackgroundTransparency = 1
    teamList.BorderSizePixel = 0
    teamList.ScrollBarThickness = 3
    teamList.ScrollBarImageColor3 = COLOR_STROKE
    teamList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    teamList.CanvasSize = UDim2.new(0, 0, 0, 0)
    teamList.Parent = teamPanel

    local teamLayout = Instance.new("UIListLayout")
    teamLayout.FillDirection = Enum.FillDirection.Vertical
    teamLayout.SortOrder = Enum.SortOrder.LayoutOrder
    teamLayout.Padding = UDim.new(0, 4)
    teamLayout.Parent = teamList

    local clearAllButton = makeButton(teamPanel, "CLEAR ALL", COLOR_DANGER, FONT_TITLE)
    clearAllButton.TextSize = 11
    clearAllButton.Size = UDim2.new(1, -16, 0, 28)
    clearAllButton.Position = UDim2.new(0, 8, 1, -36)

    local editPanel = Instance.new("Frame")
    editPanel.Size = UDim2.new(1, -209, 1, -50)
    editPanel.Position = UDim2.fromOffset(201, 42)
    editPanel.BackgroundColor3 = COLOR_PANEL
    editPanel.BorderSizePixel = 0
    editPanel.Parent = window

    local petTitle = makeLabel(editPanel, "SELECT A PET", 14, COLOR_TEXT, nil, FONT_TITLE)
    petTitle.Size = UDim2.new(1, -16, 0, 24)
    petTitle.Position = UDim2.fromOffset(8, 2)

    local skillsTitle = makeLabel(editPanel, "SKILLS", 10, COLOR_DIM, nil, FONT_TITLE)
    skillsTitle.Size = UDim2.new(1, -16, 0, 18)
    skillsTitle.Position = UDim2.fromOffset(8, 28)

    local skillsRow = Instance.new("Frame")
    skillsRow.Size = UDim2.new(1, -16, 0, 64)
    skillsRow.Position = UDim2.fromOffset(8, 46)
    skillsRow.BackgroundTransparency = 1
    skillsRow.Parent = editPanel

    local skillsGrid = Instance.new("UIGridLayout")
    skillsGrid.CellSize = UDim2.new(0.5, -4, 0, 29)
    skillsGrid.CellPadding = UDim2.fromOffset(6, 6)
    skillsGrid.SortOrder = Enum.SortOrder.LayoutOrder
    skillsGrid.Parent = skillsRow

    local sequenceTitle = makeLabel(editPanel, "SEQUENCE", 10, COLOR_DIM, nil, FONT_TITLE)
    sequenceTitle.Size = UDim2.new(1, -16, 0, 18)
    sequenceTitle.Position = UDim2.fromOffset(8, 112)

    local sequenceScroll = Instance.new("ScrollingFrame")
    sequenceScroll.Size = UDim2.new(1, -16, 1, -172)
    sequenceScroll.Position = UDim2.fromOffset(8, 130)
    sequenceScroll.BackgroundColor3 = COLOR_BG
    sequenceScroll.BorderSizePixel = 0
    sequenceScroll.ScrollBarThickness = 3
    sequenceScroll.ScrollBarImageColor3 = COLOR_STROKE
    sequenceScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sequenceScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    sequenceScroll.Parent = editPanel

    local sequencePadding = Instance.new("UIPadding")
    sequencePadding.PaddingTop = UDim.new(0, 6)
    sequencePadding.PaddingLeft = UDim.new(0, 6)
    sequencePadding.PaddingRight = UDim.new(0, 6)
    sequencePadding.PaddingBottom = UDim.new(0, 6)
    sequencePadding.Parent = sequenceScroll

    local sequenceGrid = Instance.new("UIGridLayout")
    sequenceGrid.CellSize = UDim2.fromOffset(110, 26)
    sequenceGrid.CellPadding = UDim2.fromOffset(5, 5)
    sequenceGrid.SortOrder = Enum.SortOrder.LayoutOrder
    sequenceGrid.Parent = sequenceScroll

    local clearPetButton = makeButton(editPanel, "CLEAR PET", COLOR_DANGER, FONT_TITLE)
    clearPetButton.TextSize = 11
    clearPetButton.Size = UDim2.fromOffset(100, 28)
    clearPetButton.Position = UDim2.new(0, 8, 1, -36)

    local HINT_TEXT = "tap a skill to add \u{00B7} tap a step to remove"

    local statusLabel = makeLabel(editPanel, HINT_TEXT, 10, COLOR_DIM, Enum.TextXAlignment.Right)
    statusLabel.Size = UDim2.new(1, -132, 0, 28)
    statusLabel.Position = UDim2.new(0, 116, 1, -36)

    local statusToken = 0
    local function flashStatus(text, color)
        statusToken = statusToken + 1
        local token = statusToken
        statusLabel.Text = text
        statusLabel.TextColor3 = color or COLOR_ACCENT
        task.delay(2, function()
            if statusToken == token then
                statusLabel.Text = HINT_TEXT
                statusLabel.TextColor3 = COLOR_DIM
            end
        end)
    end

    local function clearChildren(container)
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("GuiObject") then child:Destroy() end
        end
    end

    local function selectedEntry()
        local entry = Editor.selectedUid and PetStorage.getPetList()[Editor.selectedUid]
        return type(entry) == "table" and entry or nil
    end

    local rebuildAll

    local function mutateRotation(mutator)
        local entry = selectedEntry()
        if not entry then
            flashStatus("select a pet first", COLOR_DANGER)
            return
        end
        local order = State.CustomSkillOrders[entry.configId]
        if type(order) ~= "table" then
            order = {}
            State.CustomSkillOrders[entry.configId] = order
        end
        mutator(order)
        if #order == 0 then State.CustomSkillOrders[entry.configId] = nil end
        CustomSkillOrderIndexes = {}
        saveSkillRotations()
        flashStatus("saved")
        rebuildAll()
    end

    local function rebuildSequence()
        clearChildren(sequenceScroll)
        local entry = selectedEntry()
        if not entry then return end
        local order = State.CustomSkillOrders[entry.configId]
        if type(order) ~= "table" then return end
        for i, token in ipairs(order) do
            local chip = makeButton(sequenceScroll, string.format("%02d %s", i, CC.tokenDisplay(entry, token)), nil, FONT_MONO)
            chip.TextSize = 11
            chip.LayoutOrder = i
            chip.MouseButton1Click:Connect(function()
                mutateRotation(function(o) table.remove(o, i) end)
            end)
        end
    end

    local function rebuildSkills()
        clearChildren(skillsRow)
        local entry = selectedEntry()
        if not entry then
            petTitle.Text = "SELECT A PET"
            petTitle.TextColor3 = COLOR_DIM
            return
        end
        petTitle.Text = string.format("%s  Lv%s", petName(entry.configId), tostring(entry.level or "?"))
        petTitle.TextColor3 = petColor(entry.configId, true)
        local counts = {}
        local order = State.CustomSkillOrders[entry.configId]
        if type(order) == "table" then
            for _, token in ipairs(order) do
                counts[token] = (counts[token] or 0) + 1
            end
        end
        for layoutOrder, info in ipairs(CC.petSkillButtons(entry)) do
            local tag = info.token == "Ultimate" and "ULT" or ("S" .. info.token)
            local button = makeButton(skillsRow, "")
            button.Text = ""
            button.LayoutOrder = layoutOrder

            local name = makeLabel(button, tag .. "  " .. info.name, 12, COLOR_TEXT)
            name.Size = UDim2.new(1, -36, 1, 0)
            name.Position = UDim2.fromOffset(8, 0)

            local used = counts[info.token] or 0
            local badge = makeLabel(button, used > 0 and ("\u{00D7}" .. used) or "", 10, COLOR_ACCENT, Enum.TextXAlignment.Right, FONT_MONO)
            badge.Size = UDim2.new(0, 26, 1, 0)
            badge.Position = UDim2.new(1, -32, 0, 0)

            button.MouseButton1Click:Connect(function()
                mutateRotation(function(o) table.insert(o, info.token) end)
            end)
        end
    end

    local function listPets()
        local pets, seen = {}, {}
        local pg = PetGroupStorage.getPetGroup()
        if type(pg) == "table" and type(pg.petGroupList) == "table" then
            local team = pg.petGroupList[pg.currentGroupId or pg.currentPetGroupIndex]
            if type(team) == "table" and type(team.petUuids) == "table" then
                for i = 1, 5 do
                    local uid = team.petUuids[i]
                    local entry = uid and PetStorage.getPetList()[uid]
                    if type(entry) == "table" and not seen[uid] then
                        seen[uid] = true
                        table.insert(pets, { uid = uid, entry = entry, equipped = true })
                    end
                end
            end
        end
        local favorites = {}
        for uid, entry in pairs(PetStorage.getPetList()) do
            if type(entry) == "table" and entry.loved == true and not seen[uid] then
                table.insert(favorites, { uid = uid, entry = entry, equipped = false })
            end
        end
        table.sort(favorites, function(a, b)
            local nameA, nameB = petName(a.entry.configId), petName(b.entry.configId)
            if nameA == nameB then return (tonumber(a.entry.level) or 0) > (tonumber(b.entry.level) or 0) end
            return nameA < nameB
        end)
        for _, pet in ipairs(favorites) do
            table.insert(pets, pet)
        end
        return pets
    end

    local function rebuildTeam()
        clearChildren(teamList)
        local pets = listPets()
        if #pets == 0 then
            local empty = makeLabel(teamList, "no pets found", 11, COLOR_DIM)
            empty.Size = UDim2.new(1, 0, 0, 20)
            return
        end
        local found = false
        for _, pet in ipairs(pets) do
            if pet.uid == Editor.selectedUid then found = true break end
        end
        if not found then
            Editor.selectedUid = pets[1].uid
        end

        local layoutOrder = 0
        local function addDivider(text)
            layoutOrder = layoutOrder + 1
            local divider = makeLabel(teamList, text, 9, COLOR_DIM, nil, FONT_TITLE)
            divider.Size = UDim2.new(1, -6, 0, 18)
            divider.LayoutOrder = layoutOrder
        end

        local lastEquipped = nil
        for _, pet in ipairs(pets) do
            if pet.equipped ~= lastEquipped then
                lastEquipped = pet.equipped
                addDivider(pet.equipped and "EQUIPPED" or "FAVORITES")
            end

            local selected = pet.uid == Editor.selectedUid
            local order = State.CustomSkillOrders[pet.entry.configId]
            local steps = type(order) == "table" and #order or 0
            layoutOrder = layoutOrder + 1
            local row = makeButton(teamList, "")
            row.Size = UDim2.new(1, -6, 0, 30)
            row.LayoutOrder = layoutOrder
            row.Text = ""

            local marker = Instance.new("Frame")
            marker.Size = UDim2.new(0, 2, 1, 0)
            marker.BackgroundColor3 = petColor(pet.entry.configId, true)
            marker.BorderSizePixel = 0
            marker.Visible = selected
            marker.Parent = row

            local swatch = Instance.new("Frame")
            swatch.Size = UDim2.fromOffset(8, 8)
            swatch.Position = UDim2.new(0, 9, 0.5, -4)
            swatch.BackgroundColor3 = petColor(pet.entry.configId, selected)
            swatch.BorderSizePixel = 0
            swatch.Parent = row

            local name = makeLabel(row, string.format("%s Lv%s", petName(pet.entry.configId), tostring(pet.entry.level or "?")), 12, selected and COLOR_TEXT or COLOR_DIM)
            name.Size = UDim2.new(1, -56, 1, 0)
            name.Position = UDim2.fromOffset(23, 0)

            local count = makeLabel(row, steps > 0 and tostring(steps) or "-", 11, steps > 0 and COLOR_ACCENT or COLOR_DIM, Enum.TextXAlignment.Right, FONT_MONO)
            count.Size = UDim2.new(0, 24, 1, 0)
            count.Position = UDim2.new(1, -30, 0, 0)

            row.MouseButton1Click:Connect(function()
                Editor.selectedUid = pet.uid
                rebuildAll()
            end)
        end
    end

    rebuildAll = function()
        rebuildTeam()
        rebuildSkills()
        rebuildSequence()
    end

    refreshButton.MouseButton1Click:Connect(rebuildAll)

    clearPetButton.MouseButton1Click:Connect(function()
        mutateRotation(function(o) table.clear(o) end)
    end)

    local clearAllArmed = false
    clearAllButton.MouseButton1Click:Connect(function()
        if not clearAllArmed then
            clearAllArmed = true
            clearAllButton.Text = "CONFIRM?"
            task.delay(3, function()
                clearAllArmed = false
                clearAllButton.Text = "CLEAR ALL"
            end)
            return
        end
        clearAllArmed = false
        clearAllButton.Text = "CLEAR ALL"
        State.CustomSkillOrders = {}
        CustomSkillOrderIndexes = {}
        saveSkillRotations()
        flashStatus("cleared all")
        rebuildAll()
    end)

    local resizeHandle = makeButton(window, "\u{25E2}", COLOR_DIM, FONT_MONO)
    resizeHandle.BackgroundTransparency = 1
    resizeHandle.TextSize = 14
    resizeHandle.Size = UDim2.fromOffset(26, 26)
    resizeHandle.Position = UDim2.new(1, -26, 1, -26)

    local function maxWindowSize()
        local viewport = gui.AbsoluteSize
        return math.max(MIN_WIDTH, viewport.X - 12), math.max(MIN_HEIGHT, viewport.Y - 12)
    end

    local function clampToViewport()
        local viewport = gui.AbsoluteSize
        if viewport.X <= 0 or viewport.Y <= 0 then return end
        local maxWidth = math.max(200, viewport.X - 8)
        local maxHeight = math.max(160, viewport.Y - 8)
        local width = math.clamp(window.AbsoluteSize.X, math.min(MIN_WIDTH, maxWidth), maxWidth)
        local height = math.clamp(window.AbsoluteSize.Y, math.min(MIN_HEIGHT, maxHeight), maxHeight)
        window.Size = UDim2.fromOffset(width, height)
        local x = math.clamp(window.AbsolutePosition.X, 4, math.max(4, viewport.X - width - 4))
        local y = math.clamp(window.AbsolutePosition.Y, 4, math.max(4, viewport.Y - height - 4))
        window.Position = UDim2.fromOffset(x, y)
    end

    local dragConnections = {}
    local dragging, dragStart, startPosition = false, nil, nil
    local resizing, resizeStart, startSize = false, nil, nil

    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = window.Position
        end
    end)
    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            resizeStart = input.Position
            startSize = window.AbsoluteSize
        end
    end)
    table.insert(dragConnections, UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if resizing then
            local delta = input.Position - resizeStart
            local maxWidth, maxHeight = maxWindowSize()
            window.Size = UDim2.fromOffset(
                math.clamp(startSize.X + delta.X, MIN_WIDTH, maxWidth),
                math.clamp(startSize.Y + delta.Y, MIN_HEIGHT, maxHeight)
            )
        elseif dragging then
            local delta = input.Position - dragStart
            window.Position = UDim2.new(
                startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
            )
        end
    end))
    table.insert(dragConnections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if resizing then
                resizing = false
                clampToViewport()
            end
        end
    end))

    closeButton.MouseButton1Click:Connect(function()
        gui.Enabled = false
    end)

    Editor.setVisible = function(visible)
        gui.Enabled = visible
        if visible then
            clampToViewport()
            rebuildAll()
        end
    end

    Editor.refresh = function()
        if gui.Enabled then rebuildAll() end
    end

    table.insert(Shared.UnloadCallbacks, function()
        for _, connection in ipairs(dragConnections) do
            connection:Disconnect()
        end
        table.clear(dragConnections)
        gui:Destroy()
    end)
end

local CustomCombatBox = Tabs.Combat:AddLeftGroupbox("Skill Rotation")

CustomCombatBox:AddButton({
    Text = "Configure Skill Rotation",
    Tooltip = "Opens the skill rotation editor window.",
    Func = function()
        Editor.setVisible(true)
    end,
})

local TeamSwitchBox = Tabs.Combat:AddLeftGroupbox("Switch Team")
TeamSwitchBox:AddDropdown("CombatSwitchTeam", {
    Text = "Team",
    Tooltip = "Team to switch to when pressing Switch Now.",
    Values = buildTeamDropdown(),
    AllowNull = true,
    Callback = function(value)
        State.SelectedSwitchTeam = value
    end,
})
TeamSwitchBox:AddButton({
    Text = "Switch Now",
    Tooltip = "Switches the active pet group to the selected team.",
    Func = function()
        if not State.SelectedSwitchTeam then return end
        local idx = tonumber(State.SelectedSwitchTeam:match("%d+"))
        if idx then
            pcall(PetGroupService.reqSwitchCurrentPetGroup, idx)
            task.wait(0.5)
            Editor.refresh()
            Library:Notify("Switched to Team " .. idx, 3)
        end
    end,
})

local CombatAutoBox = Tabs.Combat:AddRightGroupbox("Custom Auto Battle")
CombatAutoBox:AddToggle("EnableCustomAutoBattle", {
    Text = "Enable Custom Auto Battle",
    Tooltip = "Uses saved skill rotations while Auto Battle is active.",
    Default = false,
    Callback = function(value)
        State.EnableCustomAutoBattle = value
        turnAutoBattle(State.AutoBattle)
        notifyToggle("Custom Auto Battle", value)
    end,
})

CombatAutoBox:AddToggle("AutoSwitchDead", {
    Text = "Auto Switch Dead Pet",
    Tooltip = "Automatically sends out your next alive pet when your active pet dies (useful if Auto Battle is off).",
    Default = true,
    Callback = function(value)
        State.AutoSwitchDead = value
    end,
})

task.spawn(function()
    while Shared.Running do
        if State.AutoSwitchDead and getCurrentBattle() then
            if CC.Controller.hasForceSwitchPendingSlots and CC.Controller.hasForceSwitchPendingSlots() then
                local pos = CC.Controller.getForceSwitchCurrentPos and CC.Controller.getForceSwitchCurrentPos()
                local data = getBattleData()
                if pos and data then
                    local list = CC.BattleData.buildSelfBattlePetListForSwitch(data)
                    if type(list) == "table" then
                        for _, entry in ipairs(list) do
                            if type(entry) == "table" and entry.uid and CC.BattleData.isAliveBattlePet(entry) then
                                pcall(CC.Controller.applySwitchPet, tostring(entry.uid), pos, true)
                                break
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)

local CUSTOM_TEAM_COUNT = 10
local CUSTOM_TEAMS_FILE = "OuroborosEvomonCustomTeams.json"
local HttpService = game:GetService("HttpService")
local FixedPetMap = {}

local function buildFavoritedEntries()
    local labels = {}
    FixedPetMap = {}
    for uid, entry in pairs(PetStorage.getPetList()) do
        if type(entry) == "table" and entry.loved == true then
            local length = 5
            local label
            repeat
                label = string.format("%s Lv%s [%s]", petName(entry.configId), tostring(entry.level or "?"), tostring(uid):sub(1, length))
                length = length + 1
            until not FixedPetMap[label] or length > 12
            FixedPetMap[label] = uid
            table.insert(labels, label)
        end
    end
    table.sort(labels)
    return labels
end

for i = 1, CUSTOM_TEAM_COUNT do
    local preset = State.CustomTeams[i]
    if type(preset) ~= "table" then
        preset = {}
        State.CustomTeams[i] = preset
    end
    if type(preset.slots) ~= "table" then preset.slots = {} end
    if type(preset.name) ~= "string" or preset.name == "" then preset.name = "Custom Team " .. i end
end

local function saveCustomTeams()
    if not writefile then return end
    local data = {}
    for i = 1, CUSTOM_TEAM_COUNT do
        local preset = State.CustomTeams[i]
        local slots = {}
        for slot = 1, 5 do
            if preset.slots[slot] then slots[tostring(slot)] = preset.slots[slot] end
        end
        data[tostring(i)] = { name = preset.name, slots = slots }
    end
    pcall(function() writefile(CUSTOM_TEAMS_FILE, HttpService:JSONEncode(data)) end)
end

local function loadCustomTeams()
    if not (isfile and readfile and isfile(CUSTOM_TEAMS_FILE)) then return end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(CUSTOM_TEAMS_FILE)) end)
    if not (ok and type(decoded) == "table") then return end
    for i = 1, CUSTOM_TEAM_COUNT do
        local saved = decoded[tostring(i)]
        if type(saved) == "table" then
            local preset = State.CustomTeams[i]
            if type(saved.name) == "string" and saved.name ~= "" then preset.name = saved.name end
            if type(saved.slots) == "table" then
                for slot = 1, 5 do
                    local value = saved.slots[tostring(slot)]
                    preset.slots[slot] = type(value) == "string" and value or nil
                end
            end
        end
    end
end

loadCustomTeams()

local function presetLabel(i)
    return i .. ". " .. State.CustomTeams[i].name
end

local function presetLabels()
    local labels = {}
    for i = 1, CUSTOM_TEAM_COUNT do labels[i] = presetLabel(i) end
    return labels
end

local function selectedPresetIndex()
    local idx = State.SelectedCustomTeam and tonumber(tostring(State.SelectedCustomTeam):match("^(%d+)%."))
    return (idx and State.CustomTeams[idx]) and idx or nil
end

local function buildPresetUuids(preset)
    local uuids, seen = {}, {}
    for slot = 1, 5 do
        local label = preset.slots[slot]
        local uid = label and FixedPetMap[label]
        if uid and not seen[uid] then
            seen[uid] = true
            table.insert(uuids, uid)
        end
    end
    return uuids
end

local function applyPreset(preset)
    local groupId = State.CustomTeamTargetGroup and tonumber(tostring(State.CustomTeamTargetGroup):match("%d+"))
    if not groupId then return false, "Pick a game team to load into." end
    local uuids = buildPresetUuids(preset)
    if #uuids == 0 then return false, "This custom team has no pets." end
    local pg = PetGroupStorage.getPetGroup()
    local group = type(pg) == "table" and type(pg.petGroupList) == "table" and pg.petGroupList[groupId]
    local current = type(group) == "table" and type(group.petUuids) == "table" and group.petUuids or {}
    local matches = #current == #uuids
    if matches then
        for i = 1, #uuids do
            if current[i] ~= uuids[i] then matches = false break end
        end
    end
    if not matches then
        pcall(PetGroupService.reqSetPetGroup, groupId, uuids)
    end
    if PetGroupService.getCurrentGroupId() ~= groupId then
        pcall(PetGroupService.reqSwitchCurrentPetGroup, groupId)
    end
    return true
end

task.spawn(function()
    while Shared.Running do
        if State.AutoCustomTeam then
            local idx = selectedPresetIndex()
            if idx then pcall(applyPreset, State.CustomTeams[idx]) end
        end
        task.wait(3)
    end
end)

local CustomTeamBox = Tabs.Combat:AddRightGroupbox("Custom Teams")

CustomTeamBox:AddDropdown("CustomTeamTargetGroup", {
    Text = "Load Into Game Team",
    Tooltip = "Which of the game's teams a custom team is written into when applied.",
    Values = buildTeamDropdown(),
    AllowNull = true,
    Callback = function(value)
        State.CustomTeamTargetGroup = value
    end,
})

local refreshingSlots = false

local function refreshSlotDropdowns()
    local idx = selectedPresetIndex()
    local preset = idx and State.CustomTeams[idx]
    refreshingSlots = true
    for slot = 1, 5 do
        local option = Options["CustomSlot" .. slot]
        if option then pcall(option.SetValue, option, preset and preset.slots[slot] or nil) end
    end
    refreshingSlots = false
end

CustomTeamBox:AddDropdown("SelectedCustomTeam", {
    Text = "Custom Team",
    Tooltip = "The custom team you are editing and applying.",
    Values = presetLabels(),
    Default = presetLabel(1),
    AllowNull = true,
    Callback = function(value)
        State.SelectedCustomTeam = value
        refreshSlotDropdowns()
        if State.AutoCustomTeam then
            local idx = selectedPresetIndex()
            if idx then task.spawn(applyPreset, State.CustomTeams[idx]) end
        end
    end,
})

CustomTeamBox:AddInput("CustomTeamName", {
    Text = "Rename Selected",
    Tooltip = "Renames the selected custom team.",
    Default = "",
    Finished = true,
    Callback = function(value)
        local idx = selectedPresetIndex()
        if not idx or type(value) ~= "string" or value == "" then return end
        State.CustomTeams[idx].name = value
        saveCustomTeams()
        local labels = presetLabels()
        Options.SelectedCustomTeam:SetValues(labels)
        State.SelectedCustomTeam = presetLabel(idx)
        Options.SelectedCustomTeam:SetValue(State.SelectedCustomTeam)
    end,
})

for slot = 1, 5 do
    CustomTeamBox:AddDropdown("CustomSlot" .. slot, {
        Text = "Slot " .. slot,
        Tooltip = "Favorited pet placed in this slot of the selected custom team. Leave blank to skip it.",
        Values = buildFavoritedEntries(),
        AllowNull = true,
        Searchable = true,
        Callback = function(value)
            if refreshingSlots then return end
            local idx = selectedPresetIndex()
            if not idx then return end
            State.CustomTeams[idx].slots[slot] = value
            saveCustomTeams()
        end,
    })
end

CustomTeamBox:AddButton({
    Text = "Refresh Favorited",
    Tooltip = "Rebuilds the favorited pet list in every slot dropdown.",
    Func = function()
        local entries = buildFavoritedEntries()
        for slot = 1, 5 do
            local option = Options["CustomSlot" .. slot]
            if option then option:SetValues(entries) end
        end
        refreshSlotDropdowns()
        Library:Notify("Favorited pet list refreshed.", 3)
    end,
})

CustomTeamBox:AddButton({
    Text = "Apply Selected Team",
    Tooltip = "Writes the selected custom team into the chosen game team and switches to it.",
    Func = function()
        local idx = selectedPresetIndex()
        local ok, err = idx and applyPreset(State.CustomTeams[idx])
        Library:Notify(ok and "Custom team applied." or ("Custom team: " .. (err or "pick a custom team first.")), 3)
    end,
})

CustomTeamBox:AddToggle("AutoCustomTeam", {
    Text = "Auto Apply Selected",
    Tooltip = "Keeps the game team set to the selected custom team and stays switched to it, so it never drifts.",
    Default = false,
    Callback = function(value)
        State.AutoCustomTeam = value
        notifyToggle("Auto Custom Team", value)
    end,
})

State.CustomTeamTargetGroup = State.CustomTeamTargetGroup or (buildTeamDropdown()[1])
Options.CustomTeamTargetGroup:SetValue(State.CustomTeamTargetGroup)
State.SelectedCustomTeam = State.SelectedCustomTeam or presetLabel(1)
Options.SelectedCustomTeam:SetValue(State.SelectedCustomTeam)
]], "Evomon.combat")
local _pets = _ls([[local Shared = ...

local Library = Shared.Library
local Tabs = Shared.Tabs
local State = Shared.State
local ErrorCode = Shared.ErrorCode
local PetConfig = Shared.PetConfig
local PetStorage = Shared.PetStorage
local PetGroupStorage = Shared.PetGroupStorage
local PetComm = Shared.PetComm
local PetService = Shared.PetService
local PetGroupService = Shared.PetGroupService
local isSpecialPet = Shared.IsSpecialPet
local petName = Shared.PetName
local notifyToggle = Shared.NotifyToggle

local function getGroupedUids()
    local grouped = {}
    local pg = PetGroupStorage.getPetGroup()
    if type(pg) == "table" and type(pg.petGroupList) == "table" then
        for _, group in pairs(pg.petGroupList) do
            if type(group) == "table" and type(group.petUuids) == "table" then
                for _, uid in pairs(group.petUuids) do
                    grouped[uid] = true
                end
            end
        end
    end
    return grouped
end

local function isReleasablePet(uid, entry, grouped, mainUid)
    if entry.locked == true then return false end
    if grouped[uid] or uid == mainUid or uid == State.LeaderPet then return false end
    local cfg = PetConfig[entry.configId]
    if type(cfg) == "table" and (cfg.isCanRelease == false or cfg.isCanRelease == 0) then return false end
    if State.ExcludeSpecial and isSpecialPet(entry) then return false end
    return true
end

local function collectReleasable()
    local species = State.ReleaseSpecies
    local result = {}

    local releaseAll = false
    local wanted = {}

    if type(species) == "string" then
        if species == "" then return result end
        if species == "All" then releaseAll = true end
        wanted[species] = true
    elseif type(species) == "table" and next(species) ~= nil then
        for spec, isSelected in pairs(species) do
            if isSelected then
                if spec == "All" then releaseAll = true end
                wanted[spec] = true
            end
        end
    else
        return result
    end

    local grouped = getGroupedUids()
    local mainUid = PetStorage.getMainPet()

    for uid, entry in pairs(PetStorage.getPetList()) do
        if type(entry) == "table" then
            local pName = petName(entry.configId)
            if (releaseAll or wanted[pName]) and isReleasablePet(uid, entry, grouped, mainUid) then
                table.insert(result, uid)
            end
        end
    end
    return result
end

local function petInventoryCount()
    local count = 0
    for _, entry in pairs(PetStorage.getPetList()) do
        if type(entry) == "table" then
            count += 1
        end
    end
    return count
end

local function getPetInventoryLimit()
    local ok, limit = pcall(PetService.getPetStorageMaxCount)
    if ok and type(limit) == "number" and limit > 0 then
        return limit
    end

    local okData, data = pcall(PetStorage.getPlayerPetData)
    if okData and type(data) == "table" then
        local okComm, code, maxCount = pcall(PetComm.getMaxPetCount, data)
        if okComm and code == ErrorCode.SUCCEEDED and type(maxCount) == "number" and maxCount > 0 then
            return maxCount
        end
    end

    return nil
end

local function shouldRunInventoryRelease(onlyWhenFull, keepFreeSlots)
    if not onlyWhenFull then return true end
    local limit = getPetInventoryLimit()
    if not limit then return false end
    local keepFree = math.max(tonumber(keepFreeSlots) or 0, 0)
    return petInventoryCount() >= math.max(limit - keepFree, 1)
end

local function releaseNow()
    local uids = collectReleasable()
    local batch = {}
    for _, uid in ipairs(uids) do
        table.insert(batch, uid)
        if #batch >= 25 then
            pcall(PetService.reqRemovePets, batch)
            batch = {}
            task.wait(0.2)
        end
    end
    if #batch > 0 then
        pcall(PetService.reqRemovePets, batch)
    end
    return #uids
end

local function evolveAll()
    local count = 0
    for uid, entry in pairs(PetStorage.getPetList()) do
        if not Shared.Running or Library.Unloaded then break end
        if type(entry) == "table" and (not State.EvolveFavoritedOnly or entry.loved == true) then
            local ok, code, data = pcall(PetGroupService.getPetEvolveDataByPetUid, uid)
            if ok and code == ErrorCode.SUCCEEDED and type(data) == "table" and data.canEvolve == true and data.isMaxEvolve ~= true and (data.allMaterialEnough == true or data.canSupplementEvolve == true) and type(data.evolutionaryId) == "number" then
                pcall(PetService.reqPetEvolve, uid, data.evolutionaryId)
                count = count + 1
                task.wait(0.2)
            end
        end
    end
    return count
end

local function releaseBatch(uids)
    local batch = {}
    for _, uid in ipairs(uids) do
        table.insert(batch, uid)
        if #batch >= 25 then
            pcall(PetService.reqRemovePets, batch)
            batch = {}
            task.wait(0.2)
        end
    end
    if #batch > 0 then
        pcall(PetService.reqRemovePets, batch)
    end
    return #uids
end

local function collectReleasableByLevel()
    local condition = State.ReleaseLevelCondition
    local targetLevel = State.ReleaseLevelValue
    local result = {}
    if condition ~= "Max Level" and type(targetLevel) ~= "number" then return result end

    local grouped = getGroupedUids()
    local mainUid = PetStorage.getMainPet()

    for uid, entry in pairs(PetStorage.getPetList()) do
        if type(entry) == "table" and type(entry.level) == "number" then
            local matches = false
            if condition == "Equal to (=)" then
                matches = entry.level == targetLevel
            elseif condition == "Less than or Equal to (<=)" then
                matches = entry.level <= targetLevel
            elseif condition == "Greater than or Equal to (>=)" then
                matches = entry.level >= targetLevel
            elseif condition == "Max Level" then
                local ok, code, stats = pcall(PetGroupService.getPetStatsDataByPetUid, uid)
                if ok and code == ErrorCode.SUCCEEDED and type(stats) == "table" and type(stats.level) == "number" and type(stats.maxLevel) == "number" then
                    matches = stats.level >= stats.maxLevel
                end
            end

            if matches and isReleasablePet(uid, entry, grouped, mainUid) then
                local ex = State.ReleaseLevelExclude
                local excluded = type(ex) == "table" and (
                    (ex["Hearted"] and entry.loved == true)
                    or (ex["Shiny"] and PetComm.isShinyPet(entry.configId) == true)
                    or (ex["Prismatic"] and PetComm.isPetColorful(entry) == true)
                    or (ex["SSS"] and entry.talentId == 5)
                )
                if not excluded then
                    table.insert(result, uid)
                end
            end
        end
    end
    return result
end

local function shouldSwapOut(uid)
    local ok, code, stats = pcall(PetGroupService.getPetStatsDataByPetUid, uid)
    if not (ok and code == ErrorCode.SUCCEEDED and type(stats) == "table" and type(stats.level) == "number") then return false end

    if State.SwapLevel == "Max" then
        return type(stats.maxLevel) == "number" and stats.level >= stats.maxLevel
    else
        local target = tonumber(State.SwapLevel)
        if not target then return false end
        local cond = State.SwapLevelCondition
        if cond == "Equal to (=)" then
            return stats.level == target
        elseif cond == "Less than or Equal to (<=)" then
            return stats.level <= target
        else
            return stats.level >= target
        end
    end
end

local function matchesSwapTo(entry)
    local filters = State.SwapToFilters
    if type(filters) ~= "table" or next(filters) == nil then return true end
    local shiny = PetComm.isShinyPet(entry.configId) == true
    local prismatic = PetComm.isPetColorful(entry) == true
    if filters["Shiny"] and not shiny then return false end
    if filters["Exclude Shiny"] and shiny then return false end
    if filters["Prismatic"] and not prismatic then return false end
    if filters["Exclude Prismatic"] and prismatic then return false end
    if filters["SSS Talent"] and entry.talentId ~= 5 then return false end
    return true
end

local function autoSwap()
    local slots = State.SwapSlots
    if type(slots) ~= "table" or next(slots) == nil then return end

    local groupId = PetGroupService.getCurrentGroupId()
    local _, group = PetGroupService.getCurrentPetGroup()
    if type(group) ~= "table" or type(group.petUuids) ~= "table" then return end

    local petUuids, inGroup = {}, {}
    for slot, uid in pairs(group.petUuids) do
        petUuids[slot] = uid
        inGroup[uid] = true
    end

    local slotsToReplace = {}
    for label, isEnabled in pairs(slots) do
        if isEnabled then
            local slot = tonumber(tostring(label):match("%d+"))
            local uid = slot and petUuids[slot]
            if uid and shouldSwapOut(uid) then
                table.insert(slotsToReplace, slot)
            end
        end
    end

    if #slotsToReplace == 0 then return end

    local grouped = getGroupedUids()
    local candidates = {}
    for candidate, entry in pairs(PetStorage.getPetList()) do
        if type(entry) == "table" and not grouped[candidate] and not inGroup[candidate] and matchesSwapTo(entry) then
            table.insert(candidates, { uid = candidate, level = entry.level or 0 })
        end
    end

    table.sort(candidates, function(a, b) return a.level < b.level end)

    local changed = false
    local candIdx = 1

    for _, slot in ipairs(slotsToReplace) do
        local oldUid = petUuids[slot]
        local replacement = nil

        while candIdx <= #candidates do
            local cand = candidates[candIdx]
            candIdx = candIdx + 1
            if not shouldSwapOut(cand.uid) then
                replacement = cand.uid
                break
            end
        end

        if replacement then
            inGroup[oldUid] = nil
            inGroup[replacement] = true
            petUuids[slot] = replacement
            changed = true
        end
    end

    if changed then
        pcall(PetGroupService.reqSetPetGroup, groupId, petUuids)
    end
end

local function getPetTraits(entry)
    return PetComm.isShinyPet(entry.configId) == true, PetComm.isPetColorful(entry) == true, entry.talentId == 5
end

local function petMatchesTraitCategory(categories, shiny, prismatic, sss)
    return (categories["Shiny"] and shiny)
        or (categories["Prismatic"] and prismatic)
        or (categories["SSS"] and sss)
        or (categories["Shiny Prismatic"] and shiny and prismatic)
        or (categories["SSS and Shiny"] and sss and shiny)
        or (categories["SSS Prismatic"] and sss and prismatic)
        or (categories["SSS Shiny Prismatic"] and sss and shiny and prismatic)
end

local function petMatchesExactCategory(categories, entry)
    local shiny, prismatic, sss = getPetTraits(entry)
    return (categories["Shiny"] and shiny and not prismatic and not sss)
        or (categories["Prismatic"] and prismatic and not shiny and not sss)
        or (categories["SSS"] and sss and not shiny and not prismatic)
        or (categories["Shiny Prismatic"] and shiny and prismatic and not sss)
        or (categories["SSS and Shiny"] and sss and shiny and not prismatic)
        or (categories["SSS Prismatic"] and sss and prismatic and not shiny)
        or (categories["SSS Shiny Prismatic"] and sss and shiny and prismatic)
        or (categories["Talent below SSS"] and not sss and not shiny and not prismatic)
end

local function autoUnlock()
    local categories = State.UnlockCategories
    if type(categories) ~= "table" or next(categories) == nil then return 0 end
    local changed = 0
    for uid, entry in pairs(PetStorage.getPetList()) do
        if type(entry) == "table" and entry.locked == true and petMatchesExactCategory(categories, entry) then
            pcall(PetService.reqSetPetLocked, uid, false)
            changed += 1
        end
    end
    return changed
end

local function autoLock()
    local categories = State.LockCategories
    if type(categories) ~= "table" or next(categories) == nil then return 0 end
    local changed = 0
    for uid, entry in pairs(PetStorage.getPetList()) do
        if type(entry) == "table" and entry.locked ~= true and petMatchesExactCategory(categories, entry) then
            pcall(PetService.reqSetPetLocked, uid, true)
            changed += 1
        end
    end
    return changed
end

local function autoFavorite()
    local categories = State.FavoriteCategories
    if type(categories) ~= "table" or next(categories) == nil then return 0 end
    local changed = 0
    for uid, entry in pairs(PetStorage.getPetList()) do
        if type(entry) == "table" and entry.loved ~= true then
            local shiny, prismatic, sss = getPetTraits(entry)
            if petMatchesTraitCategory(categories, shiny, prismatic, sss) then
                pcall(PetService.reqSetPetLoved, uid, true)
                changed += 1
            end
        end
    end
    return changed
end

task.spawn(function()
    while Shared.Running do
        if State.AutoRelease and shouldRunInventoryRelease(State.ReleaseOnlyWhenFull, State.ReleaseKeepFreeSlots) then
            local ok, n = pcall(releaseNow)
            if ok and type(n) == "number" and n > 0 then
                Library:Notify(string.format("Auto Release: freed %d pet(s).", n), 3)
            end
        end
        task.wait(5)
    end
end)

task.spawn(function()
    while Shared.Running do
        if State.AutoEvolve then
            pcall(evolveAll)
        end
        task.wait(6)
    end
end)

task.spawn(function()
    while Shared.Running do
        if State.AutoReleaseLevels and shouldRunInventoryRelease(State.ReleaseLevelOnlyWhenFull, State.ReleaseLevelKeepFreeSlots) then
            local ok, n = pcall(function()
                return releaseBatch(collectReleasableByLevel())
            end)
            if ok and type(n) == "number" and n > 0 then
                Library:Notify(string.format("Auto Release by Level: freed %d pet(s).", n), 3)
            end
        end
        task.wait(5)
    end
end)

task.spawn(function()
    while Shared.Running do
        if State.AutoSwap then
            pcall(autoSwap)
        end
        task.wait(3)
    end
end)

task.spawn(function()
    while Shared.Running do
        if State.AutoUnlock then
            local ok, n = pcall(autoUnlock)
            if ok and type(n) == "number" and n > 0 then
                Library:Notify(string.format("Auto Unlock: unlocked %d pet(s).", n), 3)
            end
        end
        task.wait(5)
    end
end)

task.spawn(function()
    while Shared.Running do
        if State.AutoLock then
            local ok, n = pcall(autoLock)
            if ok and type(n) == "number" and n > 0 then
                Library:Notify(string.format("Auto Lock: locked %d pet(s).", n), 3)
            end
        end
        task.wait(5)
    end
end)

task.spawn(function()
    while Shared.Running do
        if State.AutoFavorite then
            local ok, n = pcall(autoFavorite)
            if ok and type(n) == "number" and n > 0 then
                Library:Notify(string.format("Auto Favorite: favorited %d pet(s).", n), 3)
            end
        end
        task.wait(5)
    end
end)

local ReleaseBox = Tabs.Pets:AddLeftGroupbox("Release", "trash-2")
local EvolveBox = Tabs.Pets:AddRightGroupbox("Evolve", "trending-up")

ReleaseBox:AddToggle("AutoRelease", {
    Text = "Release Automatically",
    Tooltip = "Every 5 seconds releases pets matching Species to release. Locked, equipped, lead, and protected pets are kept.",
    Risky = true,
    Default = false,
    Callback = function(value)
        State.AutoRelease = value
        notifyToggle("Auto Release", value)
    end,
})

ReleaseBox:AddDropdown("ReleaseSpecies", {
    Text = "Species to release (blank = off)",
    Tooltip = "Select species for Auto Release. All releases every eligible species; blank disables species release.",
    Values = Shared.BuildSpeciesList(),
    AllowNull = true,
    Multi = true,
    Searchable = true,
    Callback = function(value)
        State.ReleaseSpecies = value
    end,
})

ReleaseBox:AddToggle("ReleaseOnlyWhenFull", {
    Text = "Release Only When Full",
    Tooltip = "Auto Release runs only when pet count reaches detected inventory cap minus Keep Free Slots.",
    Default = false,
    Callback = function(value)
        State.ReleaseOnlyWhenFull = value
        notifyToggle("Auto Release Full Gate", value)
    end,
})

ReleaseBox:AddInput("ReleaseKeepFreeSlots", {
    Text = "Keep Free Slots",
    Tooltip = "Auto Release starts this many slots before full.",
    Default = tostring(State.ReleaseKeepFreeSlots),
    Numeric = true,
    Finished = true,
    Callback = function(value)
        State.ReleaseKeepFreeSlots = math.max(math.floor(tonumber(value) or 0), 0)
    end,
})

ReleaseBox:AddToggle("ExcludeSpecial", {
    Text = "Protect Favorited, SSS, Shiny & Prismatic",
    Tooltip = "On: never releases favorited/SSS/shiny/prismatic pets. Turn OFF to allow releasing them (locked pets are always kept).",
    Default = true,
    Callback = function(value)
        State.ExcludeSpecial = value
    end,
})

ReleaseBox:AddButton({
    Text = "Release Matches",
    Tooltip = "Immediately releases currently eligible pets from Species to release.",
    Risky = true,
    Func = function()
        task.spawn(function()
            local count = releaseNow()
            Library:Notify(string.format("Released %d pet(s).", count), 4)
        end)
    end,
})

EvolveBox:AddToggle("AutoEvolve", {
    Text = "Auto Evolve Eligible",
    Tooltip = "Automatically evolves pets that meet the game's evolution requirements.",
    Default = false,
    Callback = function(value)
        State.AutoEvolve = value
        notifyToggle("Auto Evolve", value)
    end,
})

EvolveBox:AddToggle("EvolveFavoritedOnly", {
    Text = "Only Evolve Favorited",
    Tooltip = "Restricts Auto Evolve and Evolve Now to favorited (hearted) pets only.",
    Default = false,
    Callback = function(value)
        State.EvolveFavoritedOnly = value
        notifyToggle("Evolve Favorited Only", value)
    end,
})

EvolveBox:AddButton({
    Text = "Evolve Eligible Now",
    Tooltip = "Runs one immediate evolve pass for currently eligible pets.",
    Func = function()
        task.spawn(evolveAll)
        Library:Notify("Evolving eligible pets.", 3)
    end,
})

local LevelReleaseBox = Tabs.Pets:AddLeftGroupbox("Release by Level", "layers")
local SwapBox = Tabs.Pets:AddRightGroupbox("Auto Swap", "repeat")
local UnlockBox = Tabs.Pets:AddRightGroupbox("Auto Unlock", "lock-open")
local LockBox = Tabs.Pets:AddRightGroupbox("Auto Lock", "lock")
local FavoriteBox = Tabs.Pets:AddRightGroupbox("Auto Favorite", "star")

LevelReleaseBox:AddToggle("AutoReleaseLevels", {
    Text = "Auto Release by Level",
    Tooltip = "Every 5 seconds releases pets whose level matches the condition. Locked, equipped, lead, and excluded pets are kept.",
    Risky = true,
    Default = false,
    Callback = function(value)
        State.AutoReleaseLevels = value
        notifyToggle("Auto Release by Level", value)
    end,
})

LevelReleaseBox:AddToggle("ReleaseLevelOnlyWhenFull", {
    Text = "Release Only When Full",
    Tooltip = "Auto Release by Level runs only when pet count reaches detected inventory cap minus Keep Free Slots.",
    Default = false,
    Callback = function(value)
        State.ReleaseLevelOnlyWhenFull = value
        notifyToggle("Release by Level Full Gate", value)
    end,
})

LevelReleaseBox:AddInput("ReleaseLevelKeepFreeSlots", {
    Text = "Keep Free Slots",
    Tooltip = "Auto Release by Level starts this many slots before full, helping catch loops avoid breaking.",
    Default = tostring(State.ReleaseLevelKeepFreeSlots),
    Numeric = true,
    Finished = true,
    Callback = function(value)
        State.ReleaseLevelKeepFreeSlots = math.max(math.floor(tonumber(value) or 0), 0)
    end,
})

LevelReleaseBox:AddDropdown("ReleaseLevelCondition", {
    Text = "Condition",
    Tooltip = "Level comparison used by Auto Release by Level.",
    Values = Shared.LEVEL_CONDITION_VALUES,
    Default = State.ReleaseLevelCondition,
    AllowNull = true,
    Callback = function(value)
        State.ReleaseLevelCondition = value
    end,
})

LevelReleaseBox:AddInput("ReleaseLevelValue", {
    Text = "Level",
    Tooltip = "Target level used with numeric conditions. Ignored when Condition is Max Level.",
    Default = tostring(State.ReleaseLevelValue),
    Numeric = true,
    Finished = true,
    Callback = function(value)
        State.ReleaseLevelValue = tonumber(value) or 1
    end,
})

LevelReleaseBox:AddDropdown("ReleaseLevelExclude", {
    Text = "Exclude",
    Tooltip = "Pets with these traits are protected from level-based release.",
    Values = { "SSS", "Shiny", "Prismatic", "Hearted" },
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.ReleaseLevelExclude = value
    end,
})

LevelReleaseBox:AddButton({
    Text = "Release Matches Now",
    Tooltip = "Immediately releases pets matching the level rule and exclusions.",
    Risky = true,
    Func = function()
        task.spawn(function()
            local count = releaseBatch(collectReleasableByLevel())
            Library:Notify(string.format("Released %d pet(s).", count), 4)
        end)
    end,
})

SwapBox:AddToggle("AutoSwap", {
    Text = "Auto Swap Pets",
    Tooltip = "Replaces selected team slots when their current pets match the level rule.",
    Default = false,
    Callback = function(value)
        State.AutoSwap = value
        notifyToggle("Auto Swap", value)
    end,
})

SwapBox:AddDropdown("SwapSlots", {
    Text = "Slots",
    Tooltip = "Team slots Auto Swap is allowed to replace.",
    Values = Shared.SWAP_SLOT_VALUES,
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.SwapSlots = value
    end,
})

SwapBox:AddDropdown("SwapToFilters", {
    Text = "Swap To",
    Tooltip = "Filters replacement pets. Exclude options reject pets with that trait.",
    Values = Shared.SWAP_TO_VALUES,
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.SwapToFilters = value
    end,
})

SwapBox:AddDropdown("SwapLevelCondition", {
    Text = "Condition",
    Tooltip = "Level comparison used to decide when a team slot should be swapped.",
    Values = Shared.LEVEL_CONDITION_VALUES,
    Default = State.SwapLevelCondition,
    AllowNull = true,
    Callback = function(value)
        State.SwapLevelCondition = value
    end,
})

SwapBox:AddInput("SwapLevel", {
    Text = "Swap Level ('Max' or number)",
    Tooltip = "Use Max to swap only max-level pets, or enter a number for the selected condition.",
    Default = State.SwapLevel,
    Numeric = false,
    Finished = true,
    Callback = function(value)
        local lower = tostring(value):lower()
        if lower == "max" or lower == "" then
            State.SwapLevel = "Max"
        else
            State.SwapLevel = tostring(tonumber(value) or "Max")
        end
    end,
})

UnlockBox:AddToggle("AutoUnlock", {
    Text = "Auto Unlock Pets",
    Tooltip = "Every 5 seconds unlocks locked pets matching the exact selected categories.",
    Risky = true,
    Default = false,
    Callback = function(value)
        State.AutoUnlock = value
        notifyToggle("Auto Unlock", value)
    end,
})

UnlockBox:AddDropdown("UnlockCategories", {
    Text = "Categories",
    Tooltip = "Categories are exact. Use combo options for SSS shiny/prismatic pets.",
    Values = Shared.UNLOCK_CATEGORY_VALUES,
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.UnlockCategories = value
    end,
})

UnlockBox:AddButton({
    Text = "Unlock Now",
    Tooltip = "Immediately unlocks locked pets matching the exact selected categories.",
    Risky = true,
    Func = function()
        task.spawn(function()
            local count = autoUnlock()
            Library:Notify(string.format("Unlocked %d pet(s).", count), 4)
        end)
    end,
})

LockBox:AddToggle("AutoLock", {
    Text = "Auto Lock Pets",
    Tooltip = "Every 5 seconds locks unlocked pets matching the exact selected categories.",
    Default = false,
    Callback = function(value)
        State.AutoLock = value
        notifyToggle("Auto Lock", value)
    end,
})

LockBox:AddDropdown("LockCategories", {
    Text = "Categories",
    Tooltip = "Categories are exact. Use combo options for SSS shiny/prismatic pets.",
    Values = Shared.UNLOCK_CATEGORY_VALUES,
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.LockCategories = value
    end,
})

LockBox:AddButton({
    Text = "Lock Now",
    Tooltip = "Immediately locks unlocked pets matching the exact selected categories.",
    Func = function()
        task.spawn(function()
            local count = autoLock()
            Library:Notify(string.format("Locked %d pet(s).", count), 4)
        end)
    end,
})

FavoriteBox:AddToggle("AutoFavorite", {
    Text = "Auto Favorite Pets",
    Tooltip = "Every 5 seconds favorites pets matching the selected categories.",
    Default = false,
    Callback = function(value)
        State.AutoFavorite = value
        notifyToggle("Auto Favorite", value)
    end,
})

FavoriteBox:AddDropdown("FavoriteCategories", {
    Text = "Categories",
    Tooltip = "Categories are inclusive. For example, SSS also favorites SSS shiny and SSS prismatic pets.",
    Values = Shared.PET_TRAIT_CATEGORY_VALUES,
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.FavoriteCategories = value
    end,
})

FavoriteBox:AddButton({
    Text = "Favorite Now",
    Tooltip = "Immediately favorites pets matching the selected categories.",
    Func = function()
        task.spawn(function()
            local count = autoFavorite()
            Library:Notify(string.format("Favorited %d pet(s).", count), 4)
        end)
    end,
})
]], "Evomon.pets")
local _data = _ls([[local Shared = ...

local Library = Shared.Library
local Tabs = Shared.Tabs
local State = Shared.State
local CoreGui = Shared.CoreGui
local UserInputService = Shared.UserInputService
local PetStorage = Shared.PetStorage
local PetComm = Shared.PetComm
local PetService = Shared.PetService
local GetBallDataModule = Shared.GetBallDataModule
local petName = Shared.PetName
local notifyToggle = Shared.NotifyToggle

local function getTargetFilter()
    local selected = State.Mob
    local selectAll, wanted = false, nil
    if type(selected) == "table" then
        for name, on in pairs(selected) do
            if on then
                if name == "All" then selectAll = true end
                wanted = wanted or {}
                wanted[name] = true
            end
        end
        if not wanted then selectAll = true end
    elseif type(selected) == "string" and selected ~= "" and selected ~= "All" then
        wanted = { [selected] = true }
    else
        selectAll = true
    end
    return selectAll, wanted
end

local function targetLabel(selectAll, wanted)
    if selectAll then return "All" end
    local names = {}
    for name in pairs(wanted) do
        if name ~= "All" then table.insert(names, name) end
    end
    table.sort(names)
    if #names == 0 then return "All" end
    return table.concat(names, ", ")
end

local function collectStats()
    local owned = { total = 0, shiny = 0, prismatic = 0, shinyPrismatic = 0, sss = 0, loved = 0, locked = 0, species = 0 }
    local target = { total = 0, shiny = 0, prismatic = 0, shinyPrismatic = 0, sss = 0 }
    local speciesSeen = {}
    local selectAll, wanted = getTargetFilter()
    for _, entry in pairs(PetStorage.getPetList()) do
        if type(entry) == "table" then
            local shiny = PetComm.isShinyPet(entry.configId) == true
            local prismatic = PetComm.isPetColorful(entry) == true
            local sss = entry.talentId == 5
            local name = petName(entry.configId)
            owned.total += 1
            if shiny then owned.shiny += 1 end
            if prismatic then owned.prismatic += 1 end
            if shiny and prismatic then owned.shinyPrismatic += 1 end
            if sss then owned.sss += 1 end
            if entry.loved == true then owned.loved += 1 end
            if entry.locked == true then owned.locked += 1 end
            if not speciesSeen[name] then
                speciesSeen[name] = true
                owned.species += 1
            end
            if selectAll or (wanted and wanted[name]) then
                target.total += 1
                if shiny then target.shiny += 1 end
                if prismatic then target.prismatic += 1 end
                if shiny and prismatic then target.shinyPrismatic += 1 end
                if sss then target.sss += 1 end
            end
        end
    end
    return owned, target, targetLabel(selectAll, wanted)
end

local function getStorageLimit()
    local ok, limit = pcall(PetService.getPetStorageMaxCount)
    if ok and type(limit) == "number" and limit > 0 then
        return limit
    end
    return nil
end

local function getBallCounts()
    local counts = {}
    local ok, balls = pcall(GetBallDataModule.getBallInfoList)
    if ok and type(balls) == "table" then
        for _, ball in ipairs(balls) do
            if type(ball) == "table" and type(ball.itemId) == "number" then
                counts[ball.itemId] = ball.isInfinite == true and "Inf" or tostring(ball.num or 0)
            end
        end
    end
    return counts
end

local OwnedBox = Tabs.Data:AddLeftGroupbox("Owned Pets", "database")
local TargetBox = Tabs.Data:AddLeftGroupbox("Target Species", "crosshair")
local InventoryBox = Tabs.Data:AddRightGroupbox("Inventory", "package")
local HudBox = Tabs.Data:AddRightGroupbox("Custom HUD", "monitor")

local OwnedTotalLabel = OwnedBox:AddLabel("Owned Pets: ...")
local OwnedShinyLabel = OwnedBox:AddLabel("Owned Shiny Pets: ...")
local OwnedPrismaticLabel = OwnedBox:AddLabel("Owned Prismatic Pets: ...")
local OwnedShinyPrismaticLabel = OwnedBox:AddLabel("Owned Prismatic + Shiny Pets: ...")
local OwnedSssLabel = OwnedBox:AddLabel("Owned SSS Pets: ...")
local OwnedLovedLabel = OwnedBox:AddLabel("Favorited Pets: ...")
local OwnedLockedLabel = OwnedBox:AddLabel("Locked Pets: ...")
local OwnedSpeciesLabel = OwnedBox:AddLabel("Unique Species: ...")

local TargetNameLabel = TargetBox:AddLabel({ Text = "Targeting: ...", DoesWrap = true })
local TargetTotalLabel = TargetBox:AddLabel("Owned: ...")
local TargetShinyLabel = TargetBox:AddLabel("Shiny: ...")
local TargetPrismaticLabel = TargetBox:AddLabel("Prismatic: ...")
local TargetShinyPrismaticLabel = TargetBox:AddLabel("Prismatic + Shiny: ...")
local TargetSssLabel = TargetBox:AddLabel("SSS: ...")

local StorageLabel = InventoryBox:AddLabel("Pet Storage: ...")
local BallLabels = {}
for _, ballName in ipairs(Shared.BALL_VALUES) do
    BallLabels[ballName] = InventoryBox:AddLabel(string.format("%s Balls: ...", ballName))
end

local hudGui, hudRows, hudTargetTitle
local hudDragConnection

local function makeHudRow(parent, order)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 16)
    row.LayoutOrder = order
    row.Parent = parent

    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, -44, 1, 0)
    nameLabel.Font = Enum.Font.Code
    nameLabel.TextSize = 13
    nameLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = row

    local valueLabel = Instance.new("TextLabel")
    valueLabel.BackgroundTransparency = 1
    valueLabel.Position = UDim2.new(1, -44, 0, 0)
    valueLabel.Size = UDim2.new(0, 44, 1, 0)
    valueLabel.Font = Enum.Font.Code
    valueLabel.TextSize = 13
    valueLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = row

    return nameLabel, valueLabel
end

local function buildHud()
    if hudGui then return end

    hudGui = Instance.new("ScreenGui")
    hudGui.Name = "OuroborosEvomonHud"
    hudGui.ResetOnSpawn = false
    hudGui.DisplayOrder = 999
    hudGui.Parent = (gethui and gethui()) or CoreGui

    local frame = Instance.new("Frame")
    frame.Name = "Panel"
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Position = UDim2.new(0, 16, 0, 220)
    frame.Size = UDim2.new(0, 196, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.Active = true
    frame.Parent = hudGui

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1
    stroke.Parent = frame

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 2)
    layout.Parent = frame

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 16)
    title.LayoutOrder = 1
    title.Font = Enum.Font.Code
    title.TextSize = 13
    title.TextColor3 = Color3.fromRGB(235, 235, 235)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "EVOMON"
    title.Parent = frame

    hudRows = {}
    local rowDefs = {
        { "ownedTotal", "Pets" },
        { "ownedShiny", "Shiny" },
        { "ownedPrismatic", "Prismatic" },
        { "ownedShinyPrismatic", "Pris + Shiny" },
        { "ownedSss", "SSS" },
        { "storage", "Storage" },
        { "targetTotal", "Owned" },
        { "targetShiny", "Shiny" },
        { "targetPrismatic", "Prismatic" },
        { "targetShinyPrismatic", "Pris + Shiny" },
        { "targetSss", "SSS" },
    }
    for i, def in ipairs(rowDefs) do
        if i == 7 then
            hudTargetTitle = Instance.new("TextLabel")
            hudTargetTitle.BackgroundTransparency = 1
            hudTargetTitle.Size = UDim2.new(1, 0, 0, 16)
            hudTargetTitle.LayoutOrder = 1 + i
            hudTargetTitle.Font = Enum.Font.Code
            hudTargetTitle.TextSize = 13
            hudTargetTitle.TextColor3 = Color3.fromRGB(235, 235, 235)
            hudTargetTitle.TextXAlignment = Enum.TextXAlignment.Left
            hudTargetTitle.TextTruncate = Enum.TextTruncate.AtEnd
            hudTargetTitle.Text = "TARGET: ALL"
            hudTargetTitle.Parent = frame
        end
        local nameLabel, valueLabel = makeHudRow(frame, i + (i >= 7 and 2 or 1))
        nameLabel.Text = def[2]
        hudRows[def[1]].."]]"..[[ = valueLabel
    end

    local dragging, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    hudDragConnection = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function destroyHud()
    if hudDragConnection then
        hudDragConnection:Disconnect()
        hudDragConnection = nil
    end
    if hudGui then
        hudGui:Destroy()
        hudGui = nil
        hudRows = nil
        hudTargetTitle = nil
    end
end

local function refreshStats()
    local ok, owned, target, name = pcall(collectStats)
    if not ok then return end

    OwnedTotalLabel:SetText(string.format("Owned Pets: %d", owned.total))
    OwnedShinyLabel:SetText(string.format("Owned Shiny Pets: %d", owned.shiny))
    OwnedPrismaticLabel:SetText(string.format("Owned Prismatic Pets: %d", owned.prismatic))
    OwnedShinyPrismaticLabel:SetText(string.format("Owned Prismatic + Shiny Pets: %d", owned.shinyPrismatic))
    OwnedSssLabel:SetText(string.format("Owned SSS Pets: %d", owned.sss))
    OwnedLovedLabel:SetText(string.format("Favorited Pets: %d", owned.loved))
    OwnedLockedLabel:SetText(string.format("Locked Pets: %d", owned.locked))
    OwnedSpeciesLabel:SetText(string.format("Unique Species: %d", owned.species))

    TargetNameLabel:SetText(string.format("Targeting: %s", name))
    TargetTotalLabel:SetText(string.format("Owned: %d", target.total))
    TargetShinyLabel:SetText(string.format("Shiny: %d", target.shiny))
    TargetPrismaticLabel:SetText(string.format("Prismatic: %d", target.prismatic))
    TargetShinyPrismaticLabel:SetText(string.format("Prismatic + Shiny: %d", target.shinyPrismatic))
    TargetSssLabel:SetText(string.format("SSS: %d", target.sss))

    local limit = getStorageLimit()
    local storageText = limit and string.format("%d/%d", owned.total, limit) or tostring(owned.total)
    StorageLabel:SetText(string.format("Pet Storage: %s", storageText))

    local ballCounts = getBallCounts()
    for ballName, label in pairs(BallLabels) do
        label:SetText(string.format("%s Balls: %s", ballName, ballCounts[Shared.BALL_IDS[ballName]].."]]"..[[ or "0"))
    end

    if hudRows then
        hudRows.ownedTotal.Text = tostring(owned.total)
        hudRows.ownedShiny.Text = tostring(owned.shiny)
        hudRows.ownedPrismatic.Text = tostring(owned.prismatic)
        hudRows.ownedShinyPrismatic.Text = tostring(owned.shinyPrismatic)
        hudRows.ownedSss.Text = tostring(owned.sss)
        hudRows.storage.Text = storageText
        hudRows.targetTotal.Text = tostring(target.total)
        hudRows.targetShiny.Text = tostring(target.shiny)
        hudRows.targetPrismatic.Text = tostring(target.prismatic)
        hudRows.targetShinyPrismatic.Text = tostring(target.shinyPrismatic)
        hudRows.targetSss.Text = tostring(target.sss)
        hudTargetTitle.Text = string.format("TARGET: %s", name:upper())
    end
end

local HudToggle = HudBox:AddToggle("CustomHud", {
    Text = "Custom HUD",
    Tooltip = "Shows a minimal on-screen panel with owned and target species counts, visible while the menu is closed.",
    Default = false,
    Callback = function(value)
        State.CustomHud = value
        if value then
            buildHud()
            refreshStats()
        else
            destroyHud()
        end
        notifyToggle("Custom HUD", value)
    end,
})

HudToggle:AddKeyPicker("CustomHudKey", {
    Default = "None",
    Text = "Custom HUD",
    Mode = "Toggle",
    SyncToggleState = true,
})

task.spawn(function()
    while Shared.Running do
        if Library.Unloaded then break end
        refreshStats()
        task.wait(2)
    end
end)

table.insert(Shared.UnloadCallbacks, destroyHud)
]], "Evomon.data")
local _teleport = _ls([[local Shared = ...

local Library = Shared.Library
local Options = Shared.Options
local Tabs = Shared.Tabs
local State = Shared.State
local Workspace = Shared.Workspace
local ErrorCode = Shared.ErrorCode
local IslandConfig = Shared.IslandConfig
local NpcConfig = Shared.NpcConfig
local ManyWorldsService = Shared.ManyWorldsService
local TravelingMerchantService = Shared.TravelingMerchantService
local ShopService = Shared.ShopService
local CommShopConst = Shared.CommShopConst
local ControllerManager = Shared.ControllerManager
local getRoot = Shared.GetRoot
local teleportToCFrame = Shared.TeleportToCFrame

local Teleport = (function()
local Teleport = {}
local TeleportIslands, TeleportIslandMap, TeleportNpcs, TeleportNpcMap, TeleportWorlds, TeleportWorldMap, MerchantGoods, MerchantGoodMap = {}, {}, {}, {}, {}, {}, {}, {}

local function insertSortedUnique(list, map, label, data)
    if type(label) ~= "string" or label == "" then return end
    if map[label] then return end
    map[label] = data
    table.insert(list, label)
end

local function restoreThreadIdentity()
    local setIdentity = setthreadidentity or set_thread_identity or (syn and syn.set_thread_identity)
    if setIdentity then pcall(setIdentity, 8) end
end

local function getIslandFolder()
    local scene = Workspace:FindFirstChild("Scene")
    return scene and scene:FindFirstChild("Island")
end

local function getCreatureCache()
    local cache = Workspace:FindFirstChild("RuntimeCache")
    cache = cache and cache:FindFirstChild("RuntimeCacheServer")
    return cache and cache:FindFirstChild("CreatureModelCache")
end

local function getInstancePivot(instance)
    if not instance then return nil end
    if instance:IsA("BasePart") then return instance.CFrame end
    local ok, pivot = pcall(instance.GetPivot, instance)
    if ok and typeof(pivot) == "CFrame" then return pivot end
    local part = instance:FindFirstChildWhichIsA("BasePart", true)
    return part and part.CFrame or nil
end

local function teleportNearPivot(pivot)
    if typeof(pivot) ~= "CFrame" then return false end
    return teleportToCFrame(pivot * CFrame.new(0, 5, 6))
end

local function refreshTeleportIslands()
    TeleportIslands, TeleportIslandMap = {}, {}
    local folder = getIslandFolder()
    if not folder then return TeleportIslands end
    local entries = {}
    for islandId, island in pairs(IslandConfig) do
        if type(island) == "table" and type(island.assetName) == "string" then
            local model = folder:FindFirstChild(island.assetName)
            if model then
                table.insert(entries, { id = tonumber(islandId) or math.huge, label = island.displayName or island.name or island.assetName, model = model })
            end
        end
    end
    table.sort(entries, function(a, b) return a.id < b.id end)
    for _, entry in ipairs(entries) do
        insertSortedUnique(TeleportIslands, TeleportIslandMap, entry.label, entry)
    end
    if not TeleportIslandMap[State.TeleportIsland] then
        State.TeleportIsland = TeleportIslands[1]
    end
    Teleport.Islands = TeleportIslands
    return TeleportIslands
end

local function refreshTeleportNpcs()
    TeleportNpcs, TeleportNpcMap = {}, {}
    local cache = getCreatureCache()
    if not cache then return TeleportNpcs end
    local entries = {}
    for _, holder in ipairs(cache:GetChildren()) do
        local npcId = tonumber(holder:GetAttribute("configId"))
        local model = holder:FindFirstChildOfClass("Model")
        if npcId and model and model.Name:match("^Npc%d+$") then
            local pivot = getInstancePivot(model)
            if pivot and pivot.Position.Magnitude > 1 then
                local npc = NpcConfig[npcId] or NpcConfig[tostring(npcId)]
                local name = type(npc) == "table" and (npc.npcName or npc.name) or nil
                table.insert(entries, { id = npcId, name = name or ("Npc" .. npcId), model = model, holder = holder })
            end
        end
    end
    table.sort(entries, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    local counts = {}
    for _, entry in ipairs(entries) do
        counts[entry.name] = (counts[entry.name] or 0) + 1
    end
    local seen = {}
    for _, entry in ipairs(entries) do
        local label = entry.name
        if counts[label] > 1 then
            seen[label] = (seen[label] or 0) + 1
            label = label .. " #" .. seen[label]
        end
        insertSortedUnique(TeleportNpcs, TeleportNpcMap, label, entry)
    end
    if not TeleportNpcMap[State.TeleportNpc] then
        State.TeleportNpc = TeleportNpcs[1]
    end
    Teleport.Npcs = TeleportNpcs
    return TeleportNpcs
end

local function refreshTeleportWorlds()
    TeleportWorlds, TeleportWorldMap = {}, {}
    local ok, code, worlds = pcall(ManyWorldsService.getWorldItemDataList)
    restoreThreadIdentity()
    if ok and code == ErrorCode.SUCCEEDED and type(worlds) == "table" then
        for index, world in ipairs(worlds) do
            if type(world) == "table" and type(world.worldId) == "number" then
                local label = type(world.worldName) == "string" and world.worldName or ("World" .. tostring(world.worldIndex or index))
                if world.worldId == game.PlaceId then
                    label = label .. " [Current]"
                elseif world.isUnlocked == false then
                    label = label .. " [Locked]"
                end
                insertSortedUnique(TeleportWorlds, TeleportWorldMap, label, { sceneId = world.worldId, locked = world.isUnlocked == false })
            end
        end
    end
    if not TeleportWorldMap[State.TeleportWorld] then
        State.TeleportWorld = TeleportWorlds[1]
    end
    Teleport.Worlds = TeleportWorlds
    return TeleportWorlds
end

local function teleportSelectedIsland()
    local item = TeleportIslandMap[State.TeleportIsland]
    if not item then return false end
    local model = item.model
    if not (model and model.Parent) then
        refreshTeleportIslands()
        item = TeleportIslandMap[State.TeleportIsland]
        model = item and item.model
    end
    if not model then return false end
    local target = model:FindFirstChild("DistanceCalcPoint") or model
    return teleportNearPivot(getInstancePivot(target))
end

local function teleportSelectedNpc()
    local item = TeleportNpcMap[State.TeleportNpc]
    if not item then return false end
    local model = item.model
    if not (model and model.Parent) then
        local cache = getCreatureCache()
        if cache then
            for _, holder in ipairs(cache:GetChildren()) do
                if tonumber(holder:GetAttribute("configId")) == item.id then
                    local candidate = holder:FindFirstChildOfClass("Model")
                    if candidate then
                        model = candidate
                        item.model = candidate
                        break
                    end
                end
            end
        end
    end
    if not (model and model.Parent) then return false end
    return teleportNearPivot(getInstancePivot(model))
end

local function switchSelectedWorld()
    local item = TeleportWorldMap[State.TeleportWorld]
    if not item then return false end
    if item.sceneId == game.PlaceId then return false end
    if item.locked then
        pcall(ManyWorldsService.applyUnlockScene, item.sceneId)
    end
    local ok, code = pcall(ManyWorldsService.applyTeleport, item.sceneId)
    restoreThreadIdentity()
    return ok and code == ErrorCode.SUCCEEDED
end

local function enterTradingHall()
    local ok, code = pcall(ManyWorldsService.applyEnterTradingHall)
    restoreThreadIdentity()
    return ok and code == ErrorCode.SUCCEEDED
end

local function exitTradingHall()
    local ok, code = pcall(ManyWorldsService.applyExitTradingHall)
    restoreThreadIdentity()
    return ok and code == ErrorCode.SUCCEEDED
end

local function findTravelingMerchant()
    local root = getRoot()
    local origin = root and root.Position
    local best, bestDistance
    local cache = getCreatureCache()
    if cache then
        for _, holder in ipairs(cache:GetChildren()) do
            local npcId = tonumber(holder:GetAttribute("configId"))
            local npc = npcId and (NpcConfig[npcId] or NpcConfig[tostring(npcId)])
            local name = type(npc) == "table" and tostring(npc.npcName or "") or ""
            if name:lower() == "traveling merchant" then
                local pivot = getInstancePivot(holder:FindFirstChildOfClass("Model"))
                if pivot then
                    local distance = origin and (pivot.Position - origin).Magnitude or 0
                    if not best or distance < bestDistance then
                        best, bestDistance = pivot, distance
                    end
                end
            end
        end
    end
    return best
end

local function teleportToMerchant()
    return teleportNearPivot(findTravelingMerchant())
end

local function runWithThreadIdentity(identity, callback)
    local setIdentity = setthreadidentity or set_thread_identity or (syn and syn.set_thread_identity)
    local getIdentity = getthreadidentity or get_thread_identity or (syn and syn.get_thread_identity)
    if not setIdentity then return pcall(callback) end
    local current = getIdentity and getIdentity() or nil
    setIdentity(identity)
    local ok, result = pcall(callback)
    if current then
        pcall(setIdentity, current)
    end
    return ok, result
end

local function openMerchantShop()
    local controller = ControllerManager.getController("CommShopController")
    if not controller or type(controller.openWindow) ~= "function" then return false end
    local ok, code = runWithThreadIdentity(2, function()
        return controller.openWindow(CommShopConst.SHOP_TYPE_TRAVELING_MERCHANT)
    end)
    return ok and code == ErrorCode.SUCCEEDED
end

local function refreshMerchantGoods()
    MerchantGoods, MerchantGoodMap = {}, {}
    local ok, code, rows = pcall(TravelingMerchantService.getCurrentGoodsRows)
    restoreThreadIdentity()
    if ok and code == ErrorCode.SUCCEEDED and type(rows) == "table" then
        for _, row in ipairs(rows) do
            if type(row) == "table" and type(row.goodsId) == "number" then
                local nameCode, name = ShopService.getGoodsName(row.goodsId)
                local label = nameCode == ErrorCode.SUCCEEDED and type(name) == "string" and name or ("Goods #" .. tostring(row.goodsId))
                insertSortedUnique(MerchantGoods, MerchantGoodMap, label, { id = row.goodsId, data = row })
            end
        end
    end
    table.sort(MerchantGoods)
    if not MerchantGoodMap[State.MerchantGood] then
        State.MerchantGood = MerchantGoods[1]
    end
    Teleport.Goods = MerchantGoods
    return MerchantGoods
end

local function buySelectedMerchantGood()
    local good = MerchantGoodMap[State.MerchantGood]
    if not good then return false end
    local ok, code = pcall(ShopService.applyPurchaseGoods, good.id, 1)
    restoreThreadIdentity()
    return ok and code == ErrorCode.SUCCEEDED
end

local function buyMerchantItems()
    local selected = State.MerchantItems
    if type(selected) ~= "table" then return 0 end
    local any = false
    for _, on in pairs(selected) do
        if on then any = true break end
    end
    if not any then return 0 end
    refreshMerchantGoods()
    openMerchantShop()
    local bought = 0
    for label, on in pairs(selected) do
        if on then
            local good = MerchantGoodMap[label]
            if good then
                for _ = 1, 50 do
                    local ok, code = pcall(ShopService.applyPurchaseGoods, good.id, 1)
                    if not (ok and code == ErrorCode.SUCCEEDED) then break end
                    bought = bought + 1
                end
                restoreThreadIdentity()
            end
        end
    end
    return bought
end

Teleport.RefreshIslands = refreshTeleportIslands
Teleport.RefreshNpcs = refreshTeleportNpcs
Teleport.RefreshWorlds = refreshTeleportWorlds
Teleport.RefreshGoods = refreshMerchantGoods
Teleport.Island = teleportSelectedIsland
Teleport.Npc = teleportSelectedNpc
Teleport.World = switchSelectedWorld
Teleport.EnterTradingHall = enterTradingHall
Teleport.ExitTradingHall = exitTradingHall
Teleport.Merchant = teleportToMerchant
Teleport.Shop = openMerchantShop
Teleport.Buy = buySelectedMerchantGood
Teleport.BuyItems = buyMerchantItems
return Teleport
end)()

task.spawn(function()
    while Shared.Running do
        if State.MerchantAutoBuy then
            pcall(Teleport.BuyItems)
        end
        task.wait(5)
    end
end)

local IslandTeleportBox = Tabs.Teleport:AddLeftGroupbox("Islands", "map")
local WorldTeleportBox = Tabs.Teleport:AddLeftGroupbox("Worlds", "globe-2")
local NpcTeleportBox = Tabs.Teleport:AddRightGroupbox("NPC Teleport", "user-round")
local MerchantTeleportBox = Tabs.Teleport:AddRightGroupbox("Traveling Merchant", "store")

Teleport.RefreshIslands()
Teleport.RefreshNpcs()
Teleport.RefreshWorlds()
Teleport.RefreshGoods()

IslandTeleportBox:AddDropdown("TeleportIsland", {
    Text = "Island",
    Values = Teleport.Islands,
    Default = State.TeleportIsland,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.TeleportIsland = value
    end,
})

IslandTeleportBox:AddButton({
    Text = "Refresh",
    Func = function()
        Options.TeleportIsland:SetValues(Teleport.RefreshIslands())
        Options.TeleportIsland:SetValue(State.TeleportIsland)
        Library:Notify("Island list refreshed.", 3)
    end,
})

IslandTeleportBox:AddButton({
    Text = "Teleport",
    Func = function()
        if Teleport.Island() then
            Library:Notify("Teleported to island.", 3)
        else
            Library:Notify("Island location not found in this world.", 4)
        end
    end,
})

NpcTeleportBox:AddDropdown("TeleportNpc", {
    Text = "NPC",
    Values = Teleport.Npcs,
    Default = State.TeleportNpc,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.TeleportNpc = value
    end,
})

NpcTeleportBox:AddButton({
    Text = "Refresh",
    Func = function()
        Options.TeleportNpc:SetValues(Teleport.RefreshNpcs())
        Options.TeleportNpc:SetValue(State.TeleportNpc)
        Library:Notify("NPC list refreshed.", 3)
    end,
})

NpcTeleportBox:AddButton({
    Text = "Teleport",
    Func = function()
        if Teleport.Npc() then
            Library:Notify("Teleported to NPC.", 3)
        else
            Library:Notify("NPC location not found in this world.", 4)
        end
    end,
})

WorldTeleportBox:AddDropdown("TeleportWorld", {
    Text = "World",
    Values = Teleport.Worlds,
    Default = State.TeleportWorld,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.TeleportWorld = value
    end,
})

WorldTeleportBox:AddButton({
    Text = "Refresh",
    Func = function()
        Options.TeleportWorld:SetValues(Teleport.RefreshWorlds())
        Options.TeleportWorld:SetValue(State.TeleportWorld)
        Library:Notify("World list refreshed.", 3)
    end,
})

WorldTeleportBox:AddButton({
    Text = "Travel to World",
    Func = function()
        if Teleport.World() then
            Library:Notify("World travel requested.", 3)
        else
            Library:Notify("World travel failed (already here or locked).", 4)
        end
    end,
})

WorldTeleportBox:AddButton({
    Text = "Enter Trading Hall",
    Func = function()
        if Teleport.EnterTradingHall() then
            Library:Notify("Trading Hall entry requested.", 3)
        else
            Library:Notify("Trading Hall entry failed.", 4)
        end
    end,
})

WorldTeleportBox:AddButton({
    Text = "Exit Trading Hall",
    Func = function()
        if Teleport.ExitTradingHall() then
            Library:Notify("Trading Hall exit requested.", 3)
        else
            Library:Notify("Trading Hall exit failed.", 4)
        end
    end,
})

MerchantTeleportBox:AddButton({
    Text = "Teleport to Merchant",
    Func = function()
        if Teleport.Merchant() then
            Library:Notify("Teleported to merchant.", 3)
        else
            Library:Notify("Traveling merchant not found.", 4)
        end
    end,
})

MerchantTeleportBox:AddButton({
    Text = "Open Shop",
    Func = function()
        if Teleport.Shop() then
            Library:Notify("Merchant shop requested.", 3)
        else
            Library:Notify("Merchant shop method not found.", 4)
        end
    end,
})

MerchantTeleportBox:AddDropdown("MerchantGood", {
    Text = "Goods",
    Values = Teleport.Goods,
    Default = State.MerchantGood,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.MerchantGood = value
    end,
})

MerchantTeleportBox:AddButton({
    Text = "Refresh",
    Func = function()
        local goods = Teleport.RefreshGoods()
        Options.MerchantGood:SetValues(goods)
        Options.MerchantGood:SetValue(State.MerchantGood)
        Options.MerchantItems:SetValues(goods)
        Library:Notify("Merchant goods refreshed.", 3)
    end,
})

MerchantTeleportBox:AddButton({
    Text = "Buy",
    Func = function()
        if Teleport.Buy() then
            Library:Notify("Merchant buy requested.", 3)
        else
            Library:Notify("Merchant buy method not found.", 4)
        end
    end,
})

MerchantTeleportBox:AddDropdown("MerchantItems", {
    Text = "Auto Buy Goods",
    Values = Teleport.Goods,
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.MerchantItems = value
    end,
})

MerchantTeleportBox:AddToggle("MerchantAutoBuy", {
    Text = "Auto Buy Selected",
    Tooltip = "Opens the merchant shop and buys every ticked good each pass while you can afford it.",
    Default = false,
    Callback = function(value)
        State.MerchantAutoBuy = value
        Shared.NotifyToggle("Merchant Auto Buy", value)
    end,
})

MerchantTeleportBox:AddButton({
    Text = "Buy Selected Now",
    Func = function()
        task.spawn(function()
            local n = Teleport.BuyItems()
            Library:Notify(string.format("Merchant: bought %d item(s).", n or 0), 3)
        end)
    end,
})
]], "Evomon.teleport")
local _shop = _ls([[local Shared = ...

local ReplicatedStorage = Shared.ReplicatedStorage
local Library = Shared.Library
local Options = Shared.Options
local Toggles = Shared.Toggles
local Tabs = Shared.Tabs
local State = Shared.State
local ErrorCode = Shared.ErrorCode
local CommShopConst = Shared.CommShopConst
local GetBallDataModule = Shared.GetBallDataModule
local notifyToggle = Shared.NotifyToggle

local CommShopService = require(ReplicatedStorage.Script.CommShop:WaitForChild("CommShopService"))
local ItemConfig = require(ReplicatedStorage.Config:WaitForChild("ItemConfig"))
local ProfessionService = require(ReplicatedStorage.Script.Profession:WaitForChild("ProfessionService"))
local ItemConst = require(ReplicatedStorage.Script.Item.Basic:WaitForChild("ItemConst"))
local HatchEggService = require(ReplicatedStorage.Script.HatchEgg:WaitForChild("HatchEggService"))
local EggStorage = require(ReplicatedStorage.Storage:WaitForChild("EggStorage"))
local EggComm = require(ReplicatedStorage.Script.Egg:WaitForChild("EggComm"))

local ShopCurrencyNameByIcon = {}
for _, cfg in pairs(ItemConfig) do
    if type(cfg) == "table" and type(cfg.icon) == "string" and type(cfg.name) == "string" then
        ShopCurrencyNameByIcon[cfg.icon] = cfg.name
    end
end

local ShopDefs = {
    Coins = { shopType = CommShopConst.SHOP_TYPE_GOLD, itemsKey = "ShopItemsCoins", labels = {}, byLabel = {} },
    Exchange = { shopType = CommShopConst.SHOP_TYPE_SUMMON_EXCHANGE, itemsKey = "ShopItemsExchange", labels = {}, byLabel = {} },
    Raid = { shopType = CommShopConst.SHOP_TYPE_SEASON, itemsKey = "ShopItemsRaid", labels = {}, byLabel = {} },
}

local function restoreShopThreadIdentity()
    local setIdentity = setthreadidentity or set_thread_identity or (syn and syn.set_thread_identity)
    if setIdentity then pcall(setIdentity, 8) end
end

local function shopRowStock(row)
    if row.isUnlimitedStock == true then return math.huge, "unlimited" end
    local current, max = tostring(row.displayStockText or ""):match("(%d+)%s*/%s*(%d+)")
    if current then return tonumber(current), "stock " .. max end
    return 0, "stock ?"
end

local function refreshShopRows(shop)
    local labels, byLabel = {}, {}
    local ok, data = pcall(CommShopService.getMainWindowData, shop.shopType)
    restoreShopThreadIdentity()
    if ok and type(data) == "table" and type(data.goodsScrollList) == "table" then
        for _, row in ipairs(data.goodsScrollList) do
            if type(row) == "table" and type(row.goodsId) == "number" then
                local currency = ShopCurrencyNameByIcon[row.currencyIcon] or "?"
                local _, stockLabel = shopRowStock(row)
                local label = string.format("%s · %s %s [%s]", tostring(row.name), tostring(row.priceText), currency, stockLabel)
                if not byLabel[label] then
                    table.insert(labels, label)
                    byLabel[label] = row
                end
            end
        end
    end
    shop.labels, shop.byLabel = labels, byLabel
    return labels
end

local function shopAutoBuyPass(shop)
    refreshShopRows(shop)
    local selected = State[shop.itemsKey]
    if type(selected) ~= "table" then return end
    for label, on in pairs(selected) do
        if on then
            local row = shop.byLabel[label]
            if row and row.isPurchaseLocked ~= true and row.isCurrencyEnough == true then
                local stock = shopRowStock(row)
                if stock > 0 then
                    pcall(CommShopService.applyPurchase, row.goodsId, 1, shop.shopType)
                    restoreShopThreadIdentity()
                end
            end
        end
    end
end

task.spawn(function()
    while Shared.Running do
        if State.ShopAutoBuyCoins then pcall(shopAutoBuyPass, ShopDefs.Coins) end
        if State.ShopAutoBuyExchange then pcall(shopAutoBuyPass, ShopDefs.Exchange) end
        if State.ShopAutoBuyRaid then pcall(shopAutoBuyPass, ShopDefs.Raid) end
        task.wait(math.max(tonumber(State.ShopBuyDelay) or 3, 1))
    end
end)

local SUIT_SPIN_TYPE_VALUES = { "Spin (Coins)", "Spin (Normal Spin)", "Lucky Spin" }
local SUIT_SPIN_GOODS = {
    ["Spin (Coins)"] = 1,
    ["Spin (Normal Spin)"] = 2,
    ["Lucky Spin"] = 3,
}
local SuitSlotMap = {}

local function suitLabel(professionId)
    local info = type(professionId) == "number" and ProfessionService.getProfessionInfo(professionId)
    if type(info) ~= "table" then return nil end
    return string.format("%s [%s]", tostring(info.name), ProfessionService.getQualityDisplayName(info.quality)), info
end

local function buildSuitNameValues()
    local values, rarities, raritySet = {}, {}, {}
    for id, cfg in pairs(ItemConfig) do
        if type(cfg) == "table" and cfg.itemType == ItemConst.ItemType.PROFESSION then
            local label, info = suitLabel(id)
            if label then
                table.insert(values, label)
                local rarity = ProfessionService.getQualityDisplayName(info.quality)
                if not raritySet[rarity] then
                    raritySet[rarity] = info.quality
                    table.insert(rarities, rarity)
                end
            end
        end
    end
    table.sort(values)
    table.sort(rarities, function(a, b) return raritySet[a] < raritySet[b] end)
    return values, rarities
end

local function refreshSuitSlots()
    local labels = {}
    SuitSlotMap = {}
    local code, data = ProfessionService.getLocalProfessionData()
    restoreShopThreadIdentity()
    if code == ErrorCode.SUCCEEDED and type(data) == "table" and type(data.slotList) == "table" then
        local slotIds = {}
        for slotId in pairs(data.slotList) do
            table.insert(slotIds, slotId)
        end
        table.sort(slotIds)
        for _, slotId in ipairs(slotIds) do
            local slot = data.slotList[slotId]
            if type(slot) == "table" and slot.isUnlock == true then
                local label = "Slot " .. slotId .. " - " .. (suitLabel(slot.professionId) or "Empty")
                if data.equipmentSlotId == slotId then
                    label = label .. " \u{2B50}"
                end
                table.insert(labels, label)
                SuitSlotMap[label] = slotId
            end
        end
    end
    return labels
end

local function suitMatchesKeep(professionId)
    local label, info = suitLabel(professionId)
    if not label then return false end
    local names, rarities = State.SuitKeepNames, State.SuitKeepRarities
    if type(names) == "table" and names[label] then return true end
    if type(rarities) == "table" and rarities[ProfessionService.getQualityDisplayName(info.quality)] then return true end
    return false
end

local function suitKeepSelected()
    for _, selected in ipairs({ State.SuitKeepNames, State.SuitKeepRarities }) do
        if type(selected) == "table" then
            for _, on in pairs(selected) do
                if on then return true end
            end
        end
    end
    return false
end

local function suitSpinOnce()
    local slotId = SuitSlotMap[State.SuitRerollSlot]
    if not slotId then return false, "Select an unlocked reroll slot first." end
    local goodsId = SUIT_SPIN_GOODS[State.SuitSpinType]
    if not goodsId then return false, "Select a spin type first." end
    local cost = ProfessionService.getDrawCostDataByGoodsId(goodsId)
    restoreShopThreadIdentity()
    if type(cost) == "table" and (cost.ownCount or 0) < (cost.costCount or 0) then
        return false, "Not enough currency for " .. tostring(State.SuitSpinType) .. "."
    end
    local code = ProfessionService.requestDrawProfession(slotId, goodsId)
    restoreShopThreadIdentity()
    if code ~= ErrorCode.SUCCEEDED then
        return false, "Spin failed (code " .. tostring(code) .. ")."
    end
    return true
end

local function stopAutoSpin(message)
    State.AutoSpinSuit = false
    if Toggles.AutoSpinSuit and Toggles.AutoSpinSuit.Value == true then
        Shared.SuppressNotify = true
        Toggles.AutoSpinSuit:SetValue(false)
        Shared.SuppressNotify = false
    end
    if message then Library:Notify(message, 5) end
end

task.spawn(function()
    while Shared.Running do
        if State.AutoSpinSuit then
            if not suitKeepSelected() then
                stopAutoSpin("Auto Spin: pick at least one Keep Suit Name or Keep Rarity.")
            else
                local slotId = SuitSlotMap[State.SuitRerollSlot]
                local _, slot = slotId and ProfessionService.getLocalSlotData(slotId)
                restoreShopThreadIdentity()
                if slotId and type(slot) == "table" and suitMatchesKeep(slot.professionId) then
                    stopAutoSpin("Auto Spin: got " .. (suitLabel(slot.professionId) or "a matching suit") .. ".")
                else
                    local ok, err = suitSpinOnce()
                    if not ok then
                        stopAutoSpin("Auto Spin: " .. (err or "stopped."))
                    end
                end
            end
        end
        task.wait(0.8)
    end
end)

local HatchBallsByLabel = {}

local function refreshHatchWindowData()
    local code, data = HatchEggService.getWindowData()
    restoreShopThreadIdentity()
    if code == ErrorCode.SUCCEEDED and type(data) == "table" then
        return data
    end
    return nil
end

local function refreshHatchEggs()
    local labels, seen = {}, {}
    local data = refreshHatchWindowData()
    if data and type(data.bagEggList) == "table" then
        for _, egg in ipairs(data.bagEggList) do
            if type(egg) == "table" and type(egg.name) == "string" and not seen[egg.name] then
                seen[egg.name] = true
                table.insert(labels, egg.name)
            end
        end
        table.sort(labels)
    end
    return labels
end

local function refreshHatchBalls()
    local labels = {}
    HatchBallsByLabel = {}
    local data = refreshHatchWindowData()
    if data and type(data.ballList) == "table" then
        for _, ball in ipairs(data.ballList) do
            if type(ball) == "table" and type(ball.ballId) == "number" and type(ball.name) == "string" then
                local label = ball.isInfinite == true and (ball.name .. " (\u{221E})") or ball.name
                if not HatchBallsByLabel[label] then
                    HatchBallsByLabel[label] = ball.ballId
                    table.insert(labels, label)
                end
            end
        end
    end
    return labels
end

local function hatchBallAvailable(ballId)
    for _, ball in ipairs(GetBallDataModule.getBallInfoList()) do
        if type(ball) == "table" and ball.itemId == ballId and (ball.isInfinite == true or (ball.num or 0) > 0) then
            return true
        end
    end
    return false
end

local function findBagEgg(data, name)
    if type(name) ~= "string" or name == "" then return nil end
    for _, egg in ipairs(data.bagEggList or {}) do
        if type(egg) == "table" and egg.name == name and type(egg.itemUid) == "string" and egg.itemUid ~= "" then
            return egg
        end
    end
end

local function findAnyBagEgg(data)
    for _, egg in ipairs(data.bagEggList or {}) do
        if type(egg) == "table" and type(egg.itemUid) == "string" and egg.itemUid ~= "" then
            return egg
        end
    end
end

local function autoHatchPass()
    local eggData = EggStorage.getPlayerEggData()
    if type(eggData) ~= "table" then return end
    local eggList = type(eggData.eggList) == "table" and eggData.eggList or {}
    local slotCount = tonumber(eggData.maxEggCount) or 3
    local data = refreshHatchWindowData()
    if not data then return end
    for slot = 1, slotCount do
        local entry = eggList[slot]
        if type(entry) == "table" then
            if EggComm.isEggHatching(entry) ~= true then
                local cfg = ItemConfig[entry.eggItemId]
                local isRare = type(cfg) == "table" and cfg.name == State.HatchRareEgg
                local ballId = HatchBallsByLabel[isRare and State.HatchRareBall or State.HatchBall]
                if ballId and hatchBallAvailable(ballId) then
                    HatchEggService.reqHatchEgg(slot, ballId)
                    restoreShopThreadIdentity()
                    task.wait(0.5)
                end
            end
        else
            local egg = findBagEgg(data, State.HatchRareEgg) or findBagEgg(data, State.HatchEgg)
            if not egg and State.HatchAllEggs then egg = findAnyBagEgg(data) end
            if egg then
                if HatchEggService.reqPlaceEgg(slot, egg.itemUid) == ErrorCode.SUCCEEDED then
                    task.wait(0.3)
                    data = refreshHatchWindowData()
                    if not data then return end
                else
                    restoreShopThreadIdentity()
                end
            end
        end
    end
end

task.spawn(function()
    while Shared.Running do
        if State.AutoHatch then pcall(autoHatchPass) end
        task.wait(2)
    end
end)

local ShopCoinsBox = Tabs.Shop:AddLeftGroupbox("Coins Shop", "coins")
local ShopExchangeBox = Tabs.Shop:AddLeftGroupbox("Exchange", "arrow-left-right")
local ShopRaidBox = Tabs.Shop:AddRightGroupbox("Raid Shop", "gem")

ShopCoinsBox:AddToggle("ShopAutoBuyCoins", {
    Text = "Auto Buy",
    Tooltip = "Auto-buys the ticked items whenever they're in stock and you can afford them.",
    Default = false,
    Callback = function(value)
        State.ShopAutoBuyCoins = value
        notifyToggle("Coins Shop Auto Buy", value)
    end,
})

ShopCoinsBox:AddDropdown("ShopItemsCoins", {
    Text = "Items",
    Tooltip = "Coins Shop items Auto Buy will purchase.",
    Values = refreshShopRows(ShopDefs.Coins),
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.ShopItemsCoins = value
    end,
})

ShopCoinsBox:AddButton({
    Text = "Refresh",
    Tooltip = "Rebuilds the Coins Shop item list from current shop data.",
    Func = function()
        Options.ShopItemsCoins:SetValues(refreshShopRows(ShopDefs.Coins))
        Library:Notify("Coins Shop items refreshed.", 3)
    end,
})

ShopCoinsBox:AddSlider("ShopBuyDelay", {
    Text = "Buy Delay",
    Tooltip = "Seconds between auto-buy passes (unlimited items buy 1 each pass).",
    Default = State.ShopBuyDelay,
    Min = 1,
    Max = 30,
    Rounding = 0,
    Suffix = "s",
    Callback = function(value)
        State.ShopBuyDelay = value
    end,
})

ShopExchangeBox:AddToggle("ShopAutoBuyExchange", {
    Text = "Auto Buy",
    Tooltip = "Auto-buys the ticked items whenever they're in stock and you can afford them.",
    Default = false,
    Callback = function(value)
        State.ShopAutoBuyExchange = value
        notifyToggle("Exchange Auto Buy", value)
    end,
})

ShopExchangeBox:AddDropdown("ShopItemsExchange", {
    Text = "Items",
    Tooltip = "Exchange items Auto Buy will purchase.",
    Values = refreshShopRows(ShopDefs.Exchange),
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.ShopItemsExchange = value
    end,
})

ShopExchangeBox:AddButton({
    Text = "Refresh",
    Tooltip = "Rebuilds the Exchange item list from current shop data.",
    Func = function()
        Options.ShopItemsExchange:SetValues(refreshShopRows(ShopDefs.Exchange))
        Library:Notify("Exchange items refreshed.", 3)
    end,
})

ShopRaidBox:AddToggle("ShopAutoBuyRaid", {
    Text = "Auto Buy",
    Tooltip = "Auto-buys the ticked items whenever they're in stock and you can afford them.",
    Default = false,
    Callback = function(value)
        State.ShopAutoBuyRaid = value
        notifyToggle("Raid Shop Auto Buy", value)
    end,
})

ShopRaidBox:AddDropdown("ShopItemsRaid", {
    Text = "Items",
    Tooltip = "Raid Shop items Auto Buy will purchase.",
    Values = refreshShopRows(ShopDefs.Raid),
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.ShopItemsRaid = value
    end,
})

ShopRaidBox:AddButton({
    Text = "Refresh",
    Tooltip = "Rebuilds the Raid Shop item list from current shop data.",
    Func = function()
        Options.ShopItemsRaid:SetValues(refreshShopRows(ShopDefs.Raid))
        Library:Notify("Raid Shop items refreshed.", 3)
    end,
})

local SuitBox = Tabs.Shop:AddRightGroupbox("Suit", "shirt")

do
    local SuitNameValues, SuitRarityValues = buildSuitNameValues()

    SuitBox:AddDropdown("SuitKeepNames", {
        Text = "Keep Suit Name",
        Tooltip = "Stop when you land one of these suits. Also stops if Keep Rarity hits.",
        Values = SuitNameValues,
        Multi = true,
        AllowNull = true,
        Searchable = true,
        Callback = function(value)
            State.SuitKeepNames = value
        end,
    })

    SuitBox:AddDropdown("SuitKeepRarities", {
        Text = "Keep Rarity",
        Tooltip = "Stop when you land one of these rarities. Leave both lists empty and it won't spin at all.",
        Values = SuitRarityValues,
        Multi = true,
        AllowNull = true,
        Searchable = true,
        Callback = function(value)
            State.SuitKeepRarities = value
        end,
    })
end

SuitBox:AddDropdown("SuitSpinType", {
    Text = "Spin Type",
    Tooltip = "What to pay for each roll, coins or spin tokens.",
    Values = SUIT_SPIN_TYPE_VALUES,
    Default = State.SuitSpinType,
    AllowNull = true,
    Callback = function(value)
        State.SuitSpinType = value
    end,
})

SuitBox:AddDropdown("SuitRerollSlot", {
    Text = "Reroll Slot",
    Tooltip = "Slot that gets rerolled. Shows what's in it now, \u{2B50} = the one you have equipped. Spinning replaces whatever is in there.",
    Values = refreshSuitSlots(),
    AllowNull = true,
    Callback = function(value)
        State.SuitRerollSlot = value
    end,
})

SuitBox:AddButton({
    Text = "Refresh",
    Tooltip = "Reload the slot list after spinning or equipping in-game.",
    Func = function()
        Options.SuitRerollSlot:SetValues(refreshSuitSlots())
        Library:Notify("Suit slots refreshed.", 3)
    end,
})

SuitBox:AddToggle("AutoSpinSuit", {
    Text = "Auto Spin",
    Tooltip = "Spins until a suit matches your Keep lists, then shuts off. Also shuts off if you run dry on coins/tokens.",
    Default = false,
    Callback = function(value)
        State.AutoSpinSuit = value
        notifyToggle("Auto Spin", value)
    end,
})

SuitBox:AddButton({
    Text = "Spin Once",
    Tooltip = "One roll on the selected slot, nothing else.",
    Func = function()
        task.spawn(function()
            local slotId = SuitSlotMap[State.SuitRerollSlot]
            local ok, err = suitSpinOnce()
            if ok then
                task.wait(0.6)
                local _, slot = slotId and ProfessionService.getLocalSlotData(slotId)
                restoreShopThreadIdentity()
                local label = type(slot) == "table" and suitLabel(slot.professionId)
                Library:Notify("Spin result: " .. (label or "unknown") .. ".", 4)
                Options.SuitRerollSlot:SetValues(refreshSuitSlots())
                for newLabel, mappedSlot in pairs(SuitSlotMap) do
                    if mappedSlot == slotId then
                        Options.SuitRerollSlot:SetValue(newLabel)
                        break
                    end
                end
            else
                Library:Notify(err or "Spin failed.", 4)
            end
        end)
    end,
})

local HatchBox = Tabs.Hatching:AddLeftGroupbox("Hatching", "egg")

HatchBox:AddDropdown("HatchEgg", {
    Text = "Egg",
    Tooltip = "Egg from your bag that Auto Hatch keeps placing in free hatcher slots.",
    Values = refreshHatchEggs(),
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.HatchEgg = value
    end,
})

HatchBox:AddDropdown("HatchRareEgg", {
    Text = "Rare Egg",
    Tooltip = "Also auto-hatch this egg when you have one (e.g. a Shiny egg). Placed before the normal egg.",
    Values = refreshHatchEggs(),
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        State.HatchRareEgg = value
    end,
})

HatchBox:AddButton({
    Text = "Refresh",
    Tooltip = "Reload the egg and ball lists from your bag.",
    Func = function()
        Options.HatchEgg:SetValues(refreshHatchEggs())
        Options.HatchRareEgg:SetValues(refreshHatchEggs())
        Options.HatchBall:SetValues(refreshHatchBalls())
        Options.HatchRareBall:SetValues(refreshHatchBalls())
        Library:Notify("Hatching lists refreshed.", 3)
    end,
})

HatchBox:AddDropdown("HatchBall", {
    Text = "Hatch Ball",
    Tooltip = "Ball used to open eggs once they finish incubating.",
    Values = refreshHatchBalls(),
    AllowNull = true,
    Callback = function(value)
        State.HatchBall = value
    end,
})

HatchBox:AddDropdown("HatchRareBall", {
    Text = "Rare Hatch Ball",
    Tooltip = "Ball used to open the rare egg.",
    Values = refreshHatchBalls(),
    AllowNull = true,
    Callback = function(value)
        State.HatchRareBall = value
    end,
})

HatchBox:AddToggle("HatchAllEggs", {
    Text = "Hatch All Available Eggs",
    Tooltip = "Places any egg from your bag into free slots, opened with the Hatch Ball, instead of only the selected egg.",
    Default = false,
    Callback = function(value)
        State.HatchAllEggs = value
        notifyToggle("Hatch All Eggs", value)
    end,
})

HatchBox:AddToggle("AutoHatch", {
    Text = "Auto Hatch",
    Tooltip = "Places the selected eggs into free slots and opens them with your chosen balls when they're done.",
    Default = false,
    Callback = function(value)
        State.AutoHatch = value
        notifyToggle("Auto Hatch", value)
    end,
})
]], "Evomon.shop")
local _player = _ls([[local Shared = ...

local Library = Shared.Library
local Options = Shared.Options
local Toggles = Shared.Toggles
local Tabs = Shared.Tabs
local State = Shared.State
local LocalPlayer = Shared.LocalPlayer
local Workspace = Shared.Workspace
local RunService = Shared.RunService
local UserInputService = Shared.UserInputService
local CoreGui = Shared.CoreGui
local TeleportService = Shared.TeleportService
local getTargetCreature = Shared.GetTargetCreature
local moveToCreature = Shared.MoveToCreature
local teleportToCFrame = Shared.TeleportToCFrame
local notifyToggle = Shared.NotifyToggle

local MovementConnections = {}
local DefaultGravity = Workspace.Gravity
local ReconnectQueued = false
local DisableRenderingGui = nil
local AUTO_EXECUTE_SCRIPT = 'if not game:IsLoaded() then game.Loaded:Wait() end local env = (getgenv and getgenv()) or _G if env.OuroborosAutoExecuted == game.JobId then return end env.OuroborosAutoExecuted = game.JobId task.wait(3) loadstring(game:HttpGet("https://raw.githubusercontent.com/joustingmatch/Ouroboros/main/loader.lua"))()'

local function getHumanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end
Shared.GetHumanoid = getHumanoid

local function applyWalkSpeed()
    local humanoid = getHumanoid()
    if humanoid then
        humanoid.WalkSpeed = State.WalkSpeedEnabled and State.WalkSpeedValue or 16
    end
end

local function applyJumpPower()
    local humanoid = getHumanoid()
    if humanoid then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = State.JumpPowerEnabled and State.JumpPowerValue or 50
    end
end

local function applyGravity()
    Workspace.Gravity = State.GravityEnabled and State.GravityValue or DefaultGravity
end

local function apply3DRendering()
    pcall(function()
        RunService:Set3dRenderingEnabled(not State.Disable3DRendering)
    end)

    if State.Disable3DRendering then
        if DisableRenderingGui then return end
        DisableRenderingGui = Instance.new("ScreenGui")
        DisableRenderingGui.Name = "OuroborosDisable3DRendering"
        DisableRenderingGui.IgnoreGuiInset = true
        DisableRenderingGui.ResetOnSpawn = false
        DisableRenderingGui.DisplayOrder = 2147483647

        local frame = Instance.new("Frame")
        frame.Name = "BlackScreen"
        frame.BackgroundColor3 = Color3.new(0, 0, 0)
        frame.BorderSizePixel = 0
        frame.Size = UDim2.fromScale(1, 1)
        frame.Parent = DisableRenderingGui

        pcall(function()
            DisableRenderingGui.Parent = CoreGui
        end)
    elseif DisableRenderingGui then
        DisableRenderingGui:Destroy()
        DisableRenderingGui = nil
    end
end

local function reconnectCurrentServer()
    pcall(function()
        if game.JobId and game.JobId ~= "" then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        else
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end
    end)
end

local HttpService = game:GetService("HttpService")

local function queueTeleportScript(script)
    local queueTeleport = (syn and syn.queue_on_teleport)
        or queue_on_teleport
        or (fluxus and fluxus.queue_on_teleport)
        or queueonteleport
    if not queueTeleport then return false end
    queueTeleport(script)
    return true
end

local function buildAutoExecuteScript()
    return AUTO_EXECUTE_SCRIPT
end

local function applyAutoExecute()
    if not State.AutoExecute then
        return queueTeleportScript("")
    end

    if not queueTeleportScript(buildAutoExecuteScript()) then
        return false, "queue_on_teleport is not supported by your executor."
    end
    return true
end

local function fetchAvailableServers()
    local servers, cursor = {}, nil
    for _ = 1, 5 do
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
        if cursor then url = url .. "&cursor=" .. cursor end
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if not ok then break end
        local decodedOk, decoded = pcall(function() return HttpService:JSONDecode(body) end)
        if not (decodedOk and type(decoded) == "table" and type(decoded.data) == "table") then break end
        local minPlayers = math.max(tonumber(State.ServerHopMinPlayers) or 1, 0)
        for _, server in ipairs(decoded.data) do
            if type(server) == "table"
                and type(server.id) == "string"
                and server.id ~= game.JobId
                and type(server.playing) == "number"
                and type(server.maxPlayers) == "number"
                and server.playing < server.maxPlayers
                and server.playing >= minPlayers then
                table.insert(servers, server)
            end
        end
        cursor = decoded.nextPageCursor
        if type(cursor) ~= "string" then break end
    end
    return servers
end

local function pickServer(servers)
    if #servers == 0 then return nil end
    local mode = State.ServerHopMode
    if mode == "Least Populated" then
        table.sort(servers, function(a, b) return a.playing < b.playing end)
        return servers[1]
    elseif mode == "Most Populated" then
        table.sort(servers, function(a, b) return a.playing > b.playing end)
        return servers[1]
    end
    return servers[math.random(1, #servers)]
end

local function serverHop()
    if State.AutoExecute then pcall(applyAutoExecute) end
    local target = pickServer(fetchAvailableServers())
    if not target then
        return false, "No other servers available to hop to."
    end
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, target.id, LocalPlayer)
    end)
    if not ok then
        return false, "Server hop teleport failed."
    end
    return true
end

task.spawn(function()
    local elapsed = 0
    while Shared.Running do
        task.wait(1)
        if State.AutoServerHop then
            elapsed = elapsed + 1
            if elapsed >= math.max(tonumber(State.ServerHopInterval) or 300, 30) then
                elapsed = 0
                pcall(serverHop)
            end
        else
            elapsed = 0
        end
    end
end)

local function restoreCharacterCollision()
    local character = LocalPlayer.Character
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end
end

local function saveCurrentPosition()
    local root = Shared.GetRoot()
    if root then
        State.SavedPosition = root.CFrame
        return true
    end
    return false
end

local function resetCharacter()
    local humanoid = getHumanoid()
    if humanoid then
        humanoid.Health = 0
        return true
    end
    return false
end

local function setMovementValues(walkEnabled, walkValue, jumpEnabled, jumpValue, gravityEnabled, gravityValue)
    State.WalkSpeedEnabled = walkEnabled
    State.WalkSpeedValue = walkValue
    State.JumpPowerEnabled = jumpEnabled
    State.JumpPowerValue = jumpValue
    State.GravityEnabled = gravityEnabled
    State.GravityValue = gravityValue
    Shared.SuppressNotify = true
    if Toggles.WalkSpeedEnabled then Toggles.WalkSpeedEnabled:SetValue(walkEnabled) end
    if Options.WalkSpeedValue then Options.WalkSpeedValue:SetValue(walkValue) end
    if Toggles.JumpPowerEnabled then Toggles.JumpPowerEnabled:SetValue(jumpEnabled) end
    if Options.JumpPowerValue then Options.JumpPowerValue:SetValue(jumpValue) end
    if Toggles.GravityEnabled then Toggles.GravityEnabled:SetValue(gravityEnabled) end
    if Options.GravityValue then Options.GravityValue:SetValue(gravityValue) end
    Shared.SuppressNotify = false
    applyWalkSpeed()
    applyJumpPower()
    applyGravity()
end

table.insert(MovementConnections, LocalPlayer.CharacterAdded:Connect(function(character)
    character:WaitForChild("Humanoid", 10)
    task.wait(0.5)
    if State.WalkSpeedEnabled then applyWalkSpeed() end
    if State.JumpPowerEnabled then applyJumpPower() end
    if State.GravityEnabled then applyGravity() end
end))

table.insert(MovementConnections, CoreGui.DescendantAdded:Connect(function(instance)
    if not State.AutoReconnect or ReconnectQueued then return end
    local ok, name = pcall(function() return instance.Name end)
    if not ok or name ~= "ErrorPrompt" then return end
    ReconnectQueued = true
    Library:Notify("Disconnect detected. Reconnecting in 5 seconds.", 5)
    task.delay(5, function()
        if State.AutoReconnect then
            reconnectCurrentServer()
        end
        ReconnectQueued = false
    end)
end))

table.insert(MovementConnections, UserInputService.JumpRequest:Connect(function()
    if State.InfiniteJump then
        local humanoid = getHumanoid()
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end))

table.insert(MovementConnections, RunService.Stepped:Connect(function()
    if State.Noclip then
        local character = LocalPlayer.Character
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end))

table.insert(Shared.UnloadCallbacks, function()
    for _, connection in ipairs(MovementConnections) do
        connection:Disconnect()
    end
    table.clear(MovementConnections)
    State.WalkSpeedEnabled = false
    State.JumpPowerEnabled = false
    State.Noclip = false
    State.GravityEnabled = false
    State.Disable3DRendering = false
    applyWalkSpeed()
    applyJumpPower()
    applyGravity()
    apply3DRendering()
    restoreCharacterCollision()
end)

local Lighting = game:GetService("Lighting")
local PerformanceEntries = {}

local function makePerformanceEntry(classSet, property, disabledValue, onEnable, onDisable)
    local entry = {
        active = false,
        connection = nil,
        originals = setmetatable({}, { __mode = "k" }),
    }

    local function affect(instance)
        if classSet[instance.ClassName] then
            if entry.originals[instance] == nil then
                entry.originals[instance] = instance[property]
            end
            pcall(function()
                instance[property] = disabledValue
            end)
        end
    end

    entry.set = function(value)
        if value then
            if entry.active then return end
            entry.active = true
            for _, instance in ipairs(Workspace:GetDescendants()) do
                affect(instance)
            end
            entry.connection = Workspace.DescendantAdded:Connect(affect)
            if onEnable then onEnable() end
        else
            if not entry.active then return end
            entry.active = false
            if entry.connection then
                entry.connection:Disconnect()
                entry.connection = nil
            end
            for instance, original in pairs(entry.originals) do
                pcall(function()
                    instance[property] = original
                end)
            end
            entry.originals = setmetatable({}, { __mode = "k" })
            if onDisable then onDisable() end
        end
    end

    table.insert(PerformanceEntries, entry)
    return entry
end

local DisableParticles = makePerformanceEntry({
    ParticleEmitter = true,
    Trail = true,
    Beam = true,
}, "Enabled", false)

local SavedGlobalShadows = Lighting.GlobalShadows
local DisableLights = makePerformanceEntry({
    PointLight = true,
    SpotLight = true,
    SurfaceLight = true,
}, "Enabled", false, function()
    SavedGlobalShadows = Lighting.GlobalShadows
    Lighting.GlobalShadows = false
end, function()
    Lighting.GlobalShadows = SavedGlobalShadows
end)

local DisableTextures = makePerformanceEntry({
    Decal = true,
    Texture = true,
}, "Transparency", 1)

local MuteSounds = makePerformanceEntry({
    Sound = true,
}, "Volume", 0)

local LowGraphics = (function()
    local entry = { active = false, connection = nil, originals = setmetatable({}, { __mode = "k" }) }
    local savedQuality, savedGlobalShadows
    local UserGameSettings = UserSettings():GetService("UserGameSettings")

    local function strip(instance)
        if instance:IsA("MeshPart") then
            if entry.originals[instance] == nil then
                entry.originals[instance] = { instance.Material, instance.Reflectance, instance.CastShadow, instance.TextureID }
            end
            instance.Material = Enum.Material.SmoothPlastic
            instance.Reflectance = 0
            instance.CastShadow = false
            instance.TextureID = ""
        elseif instance:IsA("BasePart") then
            if entry.originals[instance] == nil then
                entry.originals[instance] = { instance.Material, instance.Reflectance, instance.CastShadow }
            end
            instance.Material = Enum.Material.SmoothPlastic
            instance.Reflectance = 0
            instance.CastShadow = false
        end
    end

    entry.set = function(value)
        if value then
            if entry.active then return end
            entry.active = true
            pcall(function()
                savedQuality = settings().Rendering.QualityLevel
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            end)
            pcall(function()
                UserGameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
            end)
            savedGlobalShadows = Lighting.GlobalShadows
            Lighting.GlobalShadows = false
            for _, instance in ipairs(Workspace:GetDescendants()) do
                pcall(strip, instance)
            end
            entry.connection = Workspace.DescendantAdded:Connect(function(instance)
                if entry.active then pcall(strip, instance) end
            end)
        else
            if not entry.active then return end
            entry.active = false
            if entry.connection then
                entry.connection:Disconnect()
                entry.connection = nil
            end
            pcall(function()
                if savedQuality ~= nil then settings().Rendering.QualityLevel = savedQuality end
            end)
            if savedGlobalShadows ~= nil then Lighting.GlobalShadows = savedGlobalShadows end
            for instance, original in pairs(entry.originals) do
                pcall(function()
                    instance.Material = original[1]
                    instance.Reflectance = original[2]
                    instance.CastShadow = original[3]
                    if original[4] ~= nil then instance.TextureID = original[4] end
                end)
            end
            entry.originals = setmetatable({}, { __mode = "k" })
        end
    end

    table.insert(PerformanceEntries, entry)
    return entry
end)()

table.insert(Shared.UnloadCallbacks, function()
    for _, entry in ipairs(PerformanceEntries) do
        entry.set(false)
    end
    table.clear(PerformanceEntries)
end)

local MovementBox = Tabs.Player:AddLeftGroupbox("Movement", "person-standing")
local ServerHopBox = Tabs.Player:AddLeftGroupbox("Server Hop", "server")
local PlayerUtilityBox = Tabs.Player:AddRightGroupbox("Utility", "map-pinned")
local PerformanceBox = Tabs.Player:AddRightGroupbox("Performance", "gauge")

MovementBox:AddToggle("WalkSpeedEnabled", {
    Text = "Walk Speed",
    Tooltip = "Applies the selected walk speed to your character.",
    Default = false,
    Callback = function(value)
        State.WalkSpeedEnabled = value
        applyWalkSpeed()
        notifyToggle("Walk Speed", value)
    end,
})

MovementBox:AddSlider("WalkSpeedValue", {
    Text = "Walk Speed Value",
    Tooltip = "Walk speed used while Walk Speed is enabled.",
    Default = State.WalkSpeedValue,
    Min = 16,
    Max = 200,
    Rounding = 0,
    Callback = function(value)
        State.WalkSpeedValue = value
        applyWalkSpeed()
    end,
})

MovementBox:AddToggle("JumpPowerEnabled", {
    Text = "Jump Power",
    Tooltip = "Applies the selected jump power to your character.",
    Default = false,
    Callback = function(value)
        State.JumpPowerEnabled = value
        applyJumpPower()
        notifyToggle("Jump Power", value)
    end,
})

MovementBox:AddSlider("JumpPowerValue", {
    Text = "Jump Power Value",
    Tooltip = "Jump power used while Jump Power is enabled.",
    Default = State.JumpPowerValue,
    Min = 50,
    Max = 350,
    Rounding = 0,
    Callback = function(value)
        State.JumpPowerValue = value
        applyJumpPower()
    end,
})

MovementBox:AddToggle("InfiniteJump", {
    Text = "Infinite Jump",
    Tooltip = "Allows repeated jumps while airborne.",
    Default = false,
    Callback = function(value)
        State.InfiniteJump = value
        notifyToggle("Infinite Jump", value)
    end,
})

MovementBox:AddToggle("Noclip", {
    Text = "Noclip",
    Tooltip = "Disables character collision while enabled.",
    Default = false,
    Callback = function(value)
        State.Noclip = value
        notifyToggle("Noclip", value)
        if not value then
            restoreCharacterCollision()
        end
    end,
})

MovementBox:AddToggle("GravityEnabled", {
    Text = "Custom Gravity",
    Tooltip = "Applies the selected workspace gravity while enabled.",
    Default = false,
    Callback = function(value)
        State.GravityEnabled = value
        applyGravity()
        notifyToggle("Custom Gravity", value)
    end,
})

MovementBox:AddSlider("GravityValue", {
    Text = "Gravity Value",
    Tooltip = "Lower values make jumps floatier; default Roblox gravity is 196.2.",
    Default = State.GravityValue,
    Min = 20,
    Max = 300,
    Rounding = 1,
    Callback = function(value)
        State.GravityValue = value
        applyGravity()
    end,
})

PlayerUtilityBox:AddButton({
    Text = "Reapply Movement",
    Tooltip = "Reapplies walk speed, jump power, gravity, and collision settings to the current character.",
    Func = function()
        applyWalkSpeed()
        applyJumpPower()
        applyGravity()
        if not State.Noclip then restoreCharacterCollision() end
        Library:Notify("Player movement settings reapplied.", 3)
    end,
})

PlayerUtilityBox:AddButton({
    Text = "Preset: Default",
    Tooltip = "Restores normal walk speed, jump power, and gravity values.",
    Func = function()
        setMovementValues(false, 16, false, 50, false, DefaultGravity)
        Library:Notify("Default movement preset applied.", 3)
    end,
})

PlayerUtilityBox:AddButton({
    Text = "Preset: Fast Farm",
    Tooltip = "Applies faster walking and higher jump without changing gravity.",
    Func = function()
        setMovementValues(true, 80, true, 100, false, DefaultGravity)
        Library:Notify("Fast farm preset applied.", 3)
    end,
})

PlayerUtilityBox:AddButton({
    Text = "Preset: Floaty",
    Tooltip = "Applies fast movement with low gravity for easier map traversal.",
    Func = function()
        setMovementValues(true, 70, true, 120, true, 80)
        Library:Notify("Floaty movement preset applied.", 3)
    end,
})

PlayerUtilityBox:AddButton({
    Text = "Save Position",
    Tooltip = "Stores your current position for Teleport Saved.",
    Func = function()
        if saveCurrentPosition() then
            Library:Notify("Position saved.", 3)
        else
            Library:Notify("Could not save position.", 3)
        end
    end,
})

PlayerUtilityBox:AddButton({
    Text = "Teleport Saved",
    Tooltip = "Teleports back to the last saved position.",
    Func = function()
        if teleportToCFrame(State.SavedPosition) then
            Library:Notify("Teleported to saved position.", 3)
        else
            Library:Notify("No saved position yet.", 3)
        end
    end,
})

PlayerUtilityBox:AddButton({
    Text = "Teleport Selected Mob",
    Tooltip = "Teleports near the closest alive mob matching the Farm tab island and mob filters.",
    Func = function()
        local creature = getTargetCreature()
        if creature then
            moveToCreature(creature)
            Library:Notify("Teleported to selected mob.", 3)
        else
            Library:Notify("No matching mob found.", 3)
        end
    end,
})

PlayerUtilityBox:AddButton({
    Text = "Reset Character",
    Tooltip = "Respawns your character by setting humanoid health to 0.",
    Risky = true,
    Func = function()
        if resetCharacter() then
            Library:Notify("Character reset requested.", 3)
        else
            Library:Notify("No character humanoid found.", 3)
        end
    end,
})

PlayerUtilityBox:AddToggle("AutoReconnect", {
    Text = "Auto Reconnect",
    Tooltip = "When Roblox shows a disconnect prompt, waits 5 seconds then rejoins the current server.",
    Default = false,
    Callback = function(value)
        State.AutoReconnect = value
        notifyToggle("Auto Reconnect", value)
    end,
})

PlayerUtilityBox:AddToggle("AutoExecute", {
    Text = "Auto Execute",
    Tooltip = "Queues the Ouroboros loader to run again after server hops or reconnects.",
    Default = false,
    Callback = function(value)
        State.AutoExecute = value
        if not value then
            queueTeleportScript("")
            notifyToggle("Auto Execute", false)
            return
        end

        local ok, err = applyAutoExecute()
        if ok then
            notifyToggle("Auto Execute", true)
        else
            Library:Notify(err or "Auto Execute could not be queued.", 4)
            if Toggles.AutoExecute and Toggles.AutoExecute.Value == true then
                Shared.SuppressNotify = true
                Toggles.AutoExecute:SetValue(false)
                Shared.SuppressNotify = false
            end
        end
    end,
})

PlayerUtilityBox:AddToggle("Disable3DRendering", {
    Text = "Disable 3D Rendering",
    Tooltip = "Turns off the 3D world renderer and covers the screen with black for lower resource usage.",
    Default = false,
    Callback = function(value)
        State.Disable3DRendering = value
        apply3DRendering()
        notifyToggle("3D Rendering", not value)
    end,
})

PlayerUtilityBox:AddButton({
    Text = "Reconnect Now",
    Tooltip = "Immediately rejoins the current server.",
    Func = function()
        Library:Notify("Reconnecting to current server.", 3)
        reconnectCurrentServer()
    end,
})

PerformanceBox:AddToggle("DisableParticles", {
    Text = "Disable Particles",
    Tooltip = "Turns off particle emitters, trails, and beams. Restores them when disabled.",
    Default = false,
    Callback = function(value)
        DisableParticles.set(value)
        notifyToggle("Disable Particles", value)
    end,
})

PerformanceBox:AddToggle("DisableLights", {
    Text = "Disable Lights & Shadows",
    Tooltip = "Turns off dynamic lights and global shadows. Restores them when disabled.",
    Default = false,
    Callback = function(value)
        DisableLights.set(value)
        notifyToggle("Disable Lights & Shadows", value)
    end,
})

PerformanceBox:AddToggle("DisableTextures", {
    Text = "Disable Textures & Decals",
    Tooltip = "Hides decals and surface textures. Restores them when disabled.",
    Default = false,
    Callback = function(value)
        DisableTextures.set(value)
        notifyToggle("Disable Textures & Decals", value)
    end,
})

PerformanceBox:AddToggle("MuteSounds", {
    Text = "Mute Game Sounds",
    Tooltip = "Silences all game sounds and music. Restores volumes when disabled.",
    Default = false,
    Callback = function(value)
        MuteSounds.set(value)
        notifyToggle("Mute Game Sounds", value)
    end,
})

PerformanceBox:AddToggle("LowGraphics", {
    Text = "Low Graphics",
    Tooltip = "Forces lowest render quality, flattens part materials, and removes shadows for maximum performance. Restores when disabled.",
    Default = false,
    Callback = function(value)
        LowGraphics.set(value)
        notifyToggle("Low Graphics", value)
    end,
})

PerformanceBox:AddInput("FPSCap", {
    Text = "FPS Cap",
    Tooltip = "Caps the game's framerate. Requires an executor that supports setfpscap.",
    Numeric = true,
    Default = "60",
    Finished = true,
    Callback = function(value)
        if not setfpscap then
            Library:Notify("Your executor does not support setfpscap.", 4)
            return
        end
        local cap = tonumber(value)
        if cap then
            pcall(setfpscap, math.floor(cap))
        end
    end,
})

ServerHopBox:AddDropdown("ServerHopMode", {
    Text = "Target Server",
    Tooltip = "Random picks any server with space. Least/Most Populated sorts by current players.",
    Values = { "Random", "Least Populated", "Most Populated" },
    Default = State.ServerHopMode,
    AllowNull = false,
    Callback = function(value)
        State.ServerHopMode = value
    end,
})

ServerHopBox:AddSlider("ServerHopMinPlayers", {
    Text = "Minimum Players",
    Tooltip = "Skip servers below this player count. Set to 0 to allow empty servers.",
    Default = State.ServerHopMinPlayers,
    Min = 0,
    Max = 30,
    Rounding = 0,
    Callback = function(value)
        State.ServerHopMinPlayers = value
    end,
})

ServerHopBox:AddSlider("ServerHopInterval", {
    Text = "Auto Hop Interval",
    Tooltip = "Seconds between hops while Auto Server Hop is on.",
    Default = State.ServerHopInterval,
    Min = 30,
    Max = 1800,
    Rounding = 0,
    Suffix = "s",
    Callback = function(value)
        State.ServerHopInterval = value
    end,
})

ServerHopBox:AddToggle("AutoServerHop", {
    Text = "Auto Server Hop",
    Tooltip = "Automatically hops to a new server on the interval below. Enable Auto Execute to re-run the script after hopping.",
    Default = false,
    Callback = function(value)
        State.AutoServerHop = value
        notifyToggle("Auto Server Hop", value)
    end,
})

ServerHopBox:AddButton({
    Text = "Server Hop Now",
    Tooltip = "Immediately hops to a new server matching the settings above.",
    Func = function()
        Library:Notify("Finding a server to hop to.", 3)
        task.spawn(function()
            local ok, err = serverHop()
            if not ok then
                Library:Notify(err or "Server hop failed.", 4)
            end
        end)
    end,
})
]], "Evomon.player")
local _settings = _ls([[local Shared = ...

local Library = Shared.Library
local Options = Shared.Options
local Toggles = Shared.Toggles
local Tabs = Shared.Tabs
local State = Shared.State
local Env = Shared.Env
local LocalPlayer = Shared.LocalPlayer
local VirtualUser = Shared.VirtualUser
local ThemeManager = Shared.ThemeManager
local SaveManager = Shared.SaveManager
local notifyToggle = Shared.NotifyToggle

local SettingsBox = Tabs.Settings:AddLeftGroupbox("Settings", "settings")
local MenuBox = Tabs.Settings:AddRightGroupbox("Interface", "monitor")

Shared.AddDiscordButton(SettingsBox)

local function antiAfk()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end

local antiAfkConnection

task.spawn(function()
    while Shared.Running do
        if State.AntiAfk then antiAfk() end
        task.wait(60)
    end
end)

SettingsBox:AddToggle("AntiAfk", {
    Text = "Anti-AFK",
    Tooltip = "Periodically sends idle input to reduce AFK kicks.",
    Default = true,
    Callback = function(value)
        State.AntiAfk = value
        if value and not antiAfkConnection then
            antiAfkConnection = LocalPlayer.Idled:Connect(antiAfk)
        elseif not value and antiAfkConnection then
            antiAfkConnection:Disconnect()
            antiAfkConnection = nil
        end
        notifyToggle("Anti-AFK", value)
    end,
})

antiAfkConnection = LocalPlayer.Idled:Connect(antiAfk)

table.insert(Shared.UnloadCallbacks, function()
    if antiAfkConnection then
        antiAfkConnection:Disconnect()
        antiAfkConnection = nil
    end
end)

MenuBox:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind", {
    Default = "RightControl",
    NoUI = true,
    Text = "Menu Keybind",
})
Library.ToggleKeybind = Options.MenuKeybind

MenuBox:AddToggle("KeybindMenuOpen", {
    Text = "Open Keybind Menu",
    Tooltip = "Shows or hides the keybind menu overlay.",
    Default = Library.KeybindFrame.Visible,
    Callback = function(value)
        Library.KeybindFrame.Visible = value
    end,
})

MenuBox:AddDropdown("NotificationSide", {
    Values = { "Left", "Right" },
    Default = "Right",
    Text = "Notification Side",
    Tooltip = "Screen side used for new notifications.",
    AllowNull = true,
    Callback = function(value)
        if value then Library:SetNotifySide(value) end
    end,
})

MenuBox:AddDropdown("DPIScale", {
    Values = { "75%", "100%", "125%", "150%" },
    Default = "100%",
    Text = "DPI Scale",
    Tooltip = "Scales the UI size.",
    AllowNull = true,
    Callback = function(value)
        if value then Library:SetDPIScale(tonumber(value:gsub("%%", ""))) end
    end,
})

MenuBox:AddButton({
    Text = "Unload",
    Tooltip = "Stops this script UI and cleanup handlers.",
    Func = function()
        Library:Unload()
    end,
})

Library:AddDraggableImageButton({
    Icon = Shared.WINDOW_IMAGE,
    Size = UDim2.fromOffset(44, 44),
    Position = UDim2.new(0, 16, 0.5, -22),
    Callback = function()
        Library:Toggle()
    end,
})

if ThemeManager then
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder("OuroborosHub")
    ThemeManager:SaveDefault("Mint")
    ThemeManager:ApplyToTab(Tabs.Settings)
    ThemeManager:LoadDefault()
end

if SaveManager then
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind", "LeaderPet" })
    SaveManager:SetFolder("OuroborosHub/Evomon")
    SaveManager:BuildConfigSection(Tabs.Settings)
    SaveManager:LoadAutoloadConfig()

    do
        local AutoState = "setting_" .. LocalPlayer.Name

        pcall(function()
            SaveManager:Load(AutoState)
        end)
        pcall(function()
            if not (isfile and isfile("OuroborosHub/Evomon/settings/" .. AutoState .. ".json")) then
                SaveManager:Load("autosave")
            end
        end)

        local saveQueued = false
        local function persist()
            if saveQueued then
                return
            end
            saveQueued = true
            task.delay(0.5, function()
                saveQueued = false
                pcall(function()
                    SaveManager:Save(AutoState)
                end)
            end)
        end

        for _, toggle in pairs(Toggles) do
            if type(toggle) == "table" and toggle.OnChanged then
                local oldFunc = toggle.Changed
                toggle:OnChanged(function(...)
                    persist()
                    if oldFunc then
                        oldFunc(...)
                    end
                end)
            end
        end
        for _, option in pairs(Options) do
            if type(option) == "table" and option.OnChanged then
                local oldFunc = option.Changed
                option:OnChanged(function(...)
                    persist()
                    if oldFunc then
                        oldFunc(...)
                    end
                end)
            end
        end

        persist()
    end
end

Library:OnUnload(function()
    Env.OuroborosEvomonCleanup()
end)
]], "Evomon.settings")

local Shared = _core()
if not Shared then error("Evomon: core.luau failed") end
_window(Shared)
_farm(Shared)
_claims(Shared)
_combat(Shared)
_pets(Shared)
_data(Shared)
_teleport(Shared)
_shop(Shared)
_player(Shared)
_settings(Shared)
