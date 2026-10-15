--[[
    Ouroboros Hub - The Veil (placeId 125503525638054)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local PLACE_ID = 125503525638054

----------------------------------------------------------------------
-- Library
----------------------------------------------------------------------

local repo = "https://raw.githubusercontent.com/joustingmatch/ObsidianUltra/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

----------------------------------------------------------------------
-- Game constants (measured, see memory: project_theveil_attack_surface)
----------------------------------------------------------------------

local INTERACT_RANGE = 5          -- server accepted 5 studs, rejected 92
local ARRIVE_EPSILON = 4          -- how close we consider "arrived"

local ALLY_TEAMS = {
    PlayerTeam = true,            -- friendly NPCs such as Runner
    TrainingDummyTeam = true,     -- training dummies, no loot
}

local TRINKET_NAMES = {
    ["Ring"] = true,
    ["Old Ring"] = true,
    ["Amulet"] = true,
    ["Old Amulet"] = true,
    ["Goblet"] = true,
}

local RARITIES = { "Common", "Uncommon", "Rare", "Elite", "Legendary" }

-- Never sell or trash these no matter what the rarity filter says.
local PROTECTED_ITEMS = {
    ["Bag"] = true,
    ["Lantern"] = true,
}

local MERCHANT_NAME = "Clement, Merchant"

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

local State = {
    moveMode = "Teleport",
    tweenSpeed = 220,
    actionDelay = 0.15,
    busy = {},          -- per feature reentrancy guards
    espObjects = {},
    running = true,
    orbitAngle = 0,
    farmTarget = nil,        -- BasePart we are currently fighting, for the facing loop
    autoRotateSaved = nil,
    travelling = false,      -- true while a feature is moving us, drives auto noclip
    travelUntil = 0,
}

local function remotes()
    return ReplicatedStorage:FindFirstChild("Remotes")
end

local function getRemote(name)
    local folder = remotes()
    return folder and folder:FindFirstChild(name)
end

----------------------------------------------------------------------
-- Character helpers
----------------------------------------------------------------------

local function getCharacter()
    local char = LocalPlayer.Character
    if not char or not char.Parent then
        return nil
    end
    return char
end

local function getRoot()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function isAlive()
    local hum = getHumanoid()
    return hum ~= nil and hum.Health > 0
end

local function inMenu()
    return LocalPlayer:GetAttribute("InMainMenu") == true
end

-- Features must never run while the character is gone or we sit in the menu.
local function canAct()
    return State.running and not inMenu() and isAlive() and getRoot() ~= nil
end

----------------------------------------------------------------------
-- Team logic
----------------------------------------------------------------------

local function teamOf(model)
    local team = model and model:FindFirstChild("Team")
    return team and team.Value or nil
end

local function myTeam()
    local char = getCharacter()
    return teamOf(char)
end

-- A mob is farmable only if it is not on an allied team.
local function isHostileMob(model)
    local team = teamOf(model)
    if not team then
        return false
    end
    return not ALLY_TEAMS[team]
end

-- Party members share the exact same Team string. Never target them.
local function isFriendlyPlayer(player)
    if player == LocalPlayer then
        return true
    end
    local mine = myTeam()
    local theirs = teamOf(player.Character)
    if mine and theirs and mine == theirs then
        return true
    end
    return false
end

----------------------------------------------------------------------
-- World helpers
----------------------------------------------------------------------

local function partOf(instance)
    if not instance then
        return nil
    end
    if instance:IsA("BasePart") then
        return instance
    end
    if instance:IsA("Model") then
        return instance.PrimaryPart
            or instance:FindFirstChild("HumanoidRootPart")
            or instance:FindFirstChild("Handle")
            or instance:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

local function positionOf(instance)
    local part = partOf(instance)
    return part and part.Position or nil
end

local function distanceTo(instance)
    local root = getRoot()
    local pos = positionOf(instance)
    if not root or not pos then
        return math.huge
    end
    return (root.Position - pos).Magnitude
end

local function isInteractable(model, argument)
    if not model or not model.Parent then
        return false
    end
    if not model:FindFirstChild("IsInteractable") then
        return false
    end
    local arg = model:FindFirstChild("Argument")
    if not arg or not arg:IsA("StringValue") then
        return false
    end
    if argument and arg.Value ~= argument then
        return false
    end
    return true
end

local function dropsFolder()
    return Workspace:FindFirstChild("Drops")
end

local function monstersFolder()
    return Workspace:FindFirstChild("Monsters")
end

local function rarityOfDrop(model)
    return model:GetAttribute("Rarity") or "Common"
end

local function rarityOfItem(tool)
    local r = tool:FindFirstChild("Rarity")
    return (r and r.Value) or "Common"
end

----------------------------------------------------------------------
-- Movement. Teleport or tween, both write CFrame directly.
----------------------------------------------------------------------

local function freezeFall(root)
    root.AssemblyLinearVelocity = Vector3.zero
end

----------------------------------------------------------------------
-- Noclip. Roblox resets CanCollide, so it has to be reasserted each step.
-- Originals are remembered so turning it off does not leave you falling
-- through the map.
----------------------------------------------------------------------

local collisionOriginals = {}
local noclipActive = false

local function applyNoclip()
    local char = getCharacter()
    if not char then
        return
    end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if collisionOriginals[part] == nil then
                collisionOriginals[part] = part.CanCollide
            end
            if part.CanCollide then
                part.CanCollide = false
            end
        end
    end
    noclipActive = true
end

local function clearNoclip()
    if not noclipActive then
        return
    end
    for part, original in pairs(collisionOriginals) do
        if part and part.Parent then
            pcall(function()
                part.CanCollide = original
            end)
        end
    end
    table.clear(collisionOriginals)
    noclipActive = false
end

-- Mark that a feature is actively moving us. Auto noclip keys off this.
local function markTravelling(seconds)
    State.travelling = true
    State.travelUntil = os.clock() + (seconds or 0.4)
end

RunService.Stepped:Connect(function()
    if not State.running or Library.Unloaded then
        clearNoclip()
        return
    end
    if State.travelling and os.clock() > State.travelUntil then
        State.travelling = false
    end

    local manual = Toggles.NoClip and Toggles.NoClip.Value
    local auto = (Toggles.AutoNoclip == nil or Toggles.AutoNoclip.Value) and State.travelling

    if manual or auto then
        applyNoclip()
    else
        clearNoclip()
    end
end)

-- Returns true if we arrived.
local function moveTo(targetPos, timeout)
    local root = getRoot()
    if not root or not targetPos then
        return false
    end

    -- Stand slightly above and beside the target so we do not clip inside it.
    local dest = targetPos + Vector3.new(0, 3, 0)

    if State.moveMode == "Teleport" then
        markTravelling(0.5)
        root.CFrame = CFrame.new(dest)
        freezeFall(root)
        task.wait(0.12)
        return true
    end

    -- Tween: step along the line at a fixed studs per second.
    local deadline = os.clock() + (timeout or 8)
    while os.clock() < deadline do
        markTravelling(0.4)
        if not canAct() then
            return false
        end
        root = getRoot()
        if not root then
            return false
        end

        local delta = dest - root.Position
        local dist = delta.Magnitude
        if dist <= ARRIVE_EPSILON then
            freezeFall(root)
            return true
        end

        local step = math.min(dist, State.tweenSpeed * RunService.Heartbeat:Wait())
        root.CFrame = CFrame.new(root.Position + delta.Unit * step)
        freezeFall(root)
    end
    return false
end

-- Move until within the server's interact range of an instance.
local function approach(instance, range)
    range = range or INTERACT_RANGE
    local pos = positionOf(instance)
    if not pos then
        return false
    end
    if distanceTo(instance) <= range then
        return true
    end
    moveTo(pos, 8)
    return distanceTo(instance) <= (range + 3)
end

----------------------------------------------------------------------
-- Interaction
----------------------------------------------------------------------

local function fireInteract(argument, instance)
    local ev = getRemote("InteractPromptEvent")
    if not ev then
        return false
    end
    local ok = pcall(function()
        ev:FireServer(argument, instance)
    end)
    return ok
end

-- Go to the thing, interact, confirm the server consumed it.
local function collect(model, argument)
    if not isInteractable(model, argument) then
        return false
    end
    if not approach(model) then
        return false
    end
    if not isInteractable(model, argument) then
        return false
    end
    fireInteract(argument, model)
    task.wait(State.actionDelay)
    -- Server strips IsInteractable (chests) or destroys the model (drops).
    return (not model.Parent) or (not model:FindFirstChild("IsInteractable"))
end

----------------------------------------------------------------------
-- Target gathering
----------------------------------------------------------------------

local function gatherDrops(trinketsOnly, maxDistance)
    local folder = dropsFolder()
    local out = {}
    if not folder then
        return out
    end
    local root = getRoot()
    if not root then
        return out
    end
    for _, model in ipairs(folder:GetChildren()) do
        if isInteractable(model, "PickupDrop") then
            if (not trinketsOnly) or TRINKET_NAMES[model.Name] then
                local pos = positionOf(model)
                if pos then
                    local d = (root.Position - pos).Magnitude
                    if not maxDistance or d <= maxDistance then
                        out[#out + 1] = { model = model, dist = d }
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        return a.dist < b.dist
    end)
    return out
end

local function gatherChests()
    local systems = Workspace:FindFirstChild("Systems")
    local out = {}
    if not systems then
        return out
    end
    local root = getRoot()
    if not root then
        return out
    end
    for _, inst in ipairs(systems:GetDescendants()) do
        if isInteractable(inst, "OpenChest") then
            local pos = positionOf(inst)
            if pos then
                out[#out + 1] = { model = inst, dist = (root.Position - pos).Magnitude }
            end
        end
    end
    table.sort(out, function(a, b)
        return a.dist < b.dist
    end)
    return out
end

local function gatherHostiles(maxDistance)
    local folder = monstersFolder()
    local out = {}
    if not folder then
        return out
    end
    local root = getRoot()
    if not root then
        return out
    end
    for _, model in ipairs(folder:GetChildren()) do
        if isHostileMob(model) then
            local hum = model:FindFirstChildOfClass("Humanoid") -- named "Enemy", not "Humanoid"
            local part = model:FindFirstChild("HumanoidRootPart")
            if hum and part and hum.Health > 0 then
                local d = (root.Position - part.Position).Magnitude
                if not maxDistance or d <= maxDistance then
                    out[#out + 1] = { model = model, humanoid = hum, root = part, dist = d, hp = hum.Health }
                end
            end
        end
    end
    -- Lowest health first so we actually finish kills instead of spreading damage.
    table.sort(out, function(a, b)
        if math.abs(a.dist - b.dist) > 60 then
            return a.dist < b.dist
        end
        return a.hp < b.hp
    end)
    return out
end

----------------------------------------------------------------------
-- Feature loops
----------------------------------------------------------------------

local function runLoop(name, toggleName, interval, fn)
    task.spawn(function()
        while State.running do
            local toggle = Toggles[toggleName]
            if toggle and toggle.Value and canAct() and not State.busy[name] then
                State.busy[name] = true
                local ok, err = pcall(fn)
                State.busy[name] = false
                if not ok then
                    warn("[Ouroboros] " .. name .. ": " .. tostring(err))
                end
            end
            task.wait(interval)
        end
    end)
end

-- Auto Trinket: only Ring / Old Ring / Amulet / Old Amulet / Goblet.
runLoop("AutoTrinket", "AutoTrinket", 0.1, function()
    local list = gatherDrops(true, Options.TrinketRadius and Options.TrinketRadius.Value or nil)
    local target = list[1]
    if target then
        collect(target.model, "PickupDrop")
    end
end)

-- Auto Pickup All: every drop, trinket or not.
runLoop("AutoPickup", "AutoPickup", 0.1, function()
    local list = gatherDrops(false, Options.PickupRadius and Options.PickupRadius.Value or nil)
    local target = list[1]
    if target then
        collect(target.model, "PickupDrop")
    end
end)

-- Auto Chests. Opening spawns loot on the ground nearby, so sweep it after.
runLoop("AutoChest", "AutoChest", 0.25, function()
    local list = gatherChests()
    local target = list[1]
    if not target then
        return
    end
    if collect(target.model, "OpenChest") then
        if Toggles.ChestLootSweep and Toggles.ChestLootSweep.Value then
            task.wait(0.35)
            for _, entry in ipairs(gatherDrops(false, 30)) do
                if not canAct() then
                    return
                end
                collect(entry.model, "PickupDrop")
            end
        end
    end
end)

-- A weapon is any Tool whose IsSword BoolValue is true.
local function isWeapon(tool)
    local flag = tool:FindFirstChild("IsSword")
    return flag ~= nil and flag.Value == true
end

-- Rank weapons by SellPrice as a power proxy, since that tracks rarity here.
local function bestWeapon()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not backpack then
        return nil
    end
    local best, bestScore
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and isWeapon(tool) then
            local price = tool:FindFirstChild("SellPrice")
            local score = (price and price.Value) or 0
            if not bestScore or score > bestScore then
                best, bestScore = tool, score
            end
        end
    end
    return best
end

local warnedNoWeapon = false

local function ensureWeapon()
    local char = getCharacter()
    if not char then
        return nil
    end

    local held = char:FindFirstChildOfClass("Tool")
    if held and isWeapon(held) then
        return held
    end
    if not (Toggles.FarmAutoEquip and Toggles.FarmAutoEquip.Value) then
        return held
    end

    local pick = bestWeapon()
    if not pick then
        if not warnedNoWeapon then
            warnedNoWeapon = true
            Library:Notify("No weapon in your bag to equip", 5)
        end
        return held
    end
    warnedNoWeapon = false

    local hum = getHumanoid()
    if hum then
        pcall(function()
            hum:EquipTool(pick)
        end)
    end
    return char:FindFirstChildOfClass("Tool")
end

-- Where the script wants to sit relative to the mob.
local function farmDesiredPosition(targetPos)
    local mode = Options.FarmPosition and Options.FarmPosition.Value or "Orbit"
    local height = Options.FarmHeight and Options.FarmHeight.Value or 8
    local depth = Options.FarmDepth and Options.FarmDepth.Value or 8
    local radius = Options.FarmOrbitRadius and Options.FarmOrbitRadius.Value or 8

    if mode == "Hover" then
        return targetPos + Vector3.new(0, height, 0)
    elseif mode == "Under" then
        return targetPos - Vector3.new(0, depth, 0)
    elseif mode == "Orbit" then
        local speed = Options.FarmOrbitSpeed and Options.FarmOrbitSpeed.Value or 120
        State.orbitAngle = (State.orbitAngle + math.rad(speed) * 0.05) % (math.pi * 2)
        return targetPos + Vector3.new(
            math.cos(State.orbitAngle) * radius,
            height,
            math.sin(State.orbitAngle) * radius
        )
    end
    -- Direct: stand next to it at the configured reach.
    local root = getRoot()
    if not root then
        return targetPos
    end
    local away = (root.Position - targetPos)
    local flat = Vector3.new(away.X, 0, away.Z)
    if flat.Magnitude < 0.1 then
        flat = Vector3.new(1, 0, 0)
    end
    return targetPos + flat.Unit * (Options.FarmReach and Options.FarmReach.Value or 6)
end

-- Auto Farm. Hold a chosen position relative to the mob and swing.
runLoop("AutoFarm", "AutoFarm", 0.05, function()
    local list = gatherHostiles(Options.FarmRadius and Options.FarmRadius.Value or nil)
    local target = list[1]
    if not target then
        return
    end

    local tool = ensureWeapon()
    if not tool or not isWeapon(tool) then
        return
    end

    local root = getRoot()
    if not root then
        return
    end

    -- Hand the target to the facing loop so it can aim every frame, not every tick.
    State.farmTarget = target.root

    local targetPos = target.root.Position
    local desired = farmDesiredPosition(targetPos)

    -- Reposition. Snap when far away, glide when already in position.
    -- Keep the existing rotation: CFrame.new() alone would wipe our facing every tick.
    local gap = (root.Position - desired).Magnitude
    if gap > 0.5 then
        markTravelling(0.4)
        local rot = root.CFrame - root.CFrame.Position
        local nextPos
        if Toggles.FarmSmooth and Toggles.FarmSmooth.Value then
            local speed = Options.FarmMoveSpeed and Options.FarmMoveSpeed.Value or 120
            local step = math.min(gap, speed * 0.05)
            nextPos = root.Position + (desired - root.Position).Unit * step
        else
            nextPos = desired
        end
        root.CFrame = CFrame.new(nextPos) * rot
    end

    freezeFall(root)

    pcall(function()
        tool:Activate()
    end)
end)

----------------------------------------------------------------------
-- Facing. Runs every frame so the character actually looks at the mob
-- instead of snapping back to whatever direction the Humanoid wants.
----------------------------------------------------------------------

local function setAutoRotate(enabled)
    local hum = getHumanoid()
    if not hum then
        return
    end
    if State.autoRotateSaved == nil then
        State.autoRotateSaved = hum.AutoRotate
    end
    hum.AutoRotate = enabled
end

local function restoreAutoRotate()
    local hum = getHumanoid()
    if hum and State.autoRotateSaved ~= nil then
        hum.AutoRotate = State.autoRotateSaved
    end
    State.autoRotateSaved = nil
end

local facingConnection
facingConnection = RunService.RenderStepped:Connect(function()
    if not State.running or Library.Unloaded then
        if facingConnection then
            facingConnection:Disconnect()
        end
        return
    end

    local farmOn = Toggles.AutoFarm and Toggles.AutoFarm.Value
    local targetPart = State.farmTarget

    if not farmOn or not targetPart or not targetPart.Parent or not canAct() then
        if State.autoRotateSaved ~= nil then
            restoreAutoRotate()
        end
        State.farmTarget = nil
        return
    end

    local root = getRoot()
    if not root then
        return
    end

    local targetPos = targetPart.Position

    -- AutoRotate would overwrite our rotation every frame, so hold it off while farming.
    if Toggles.FarmFaceTarget and Toggles.FarmFaceTarget.Value then
        setAutoRotate(false)

        local lookPos = targetPos
        if not (Toggles.FarmTiltToTarget and Toggles.FarmTiltToTarget.Value) then
            -- Keep the body upright. A Humanoid pitched at the floor looks broken.
            lookPos = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
        end
        if (lookPos - root.Position).Magnitude > 0.05 then
            root.CFrame = CFrame.lookAt(root.Position, lookPos)
        end
    elseif State.autoRotateSaved ~= nil then
        restoreAutoRotate()
    end

    -- Point the camera at the mob too, so you are watching the fight.
    if Toggles.FarmCameraLock and Toggles.FarmCameraLock.Value then
        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
    end
end)

----------------------------------------------------------------------
-- Auto Sell
----------------------------------------------------------------------

local function selectedRarities()
    local picked = Options.SellRarities and Options.SellRarities.Value or {}
    local any = false
    for _, v in pairs(picked) do
        if v then
            any = true
            break
        end
    end
    if not any then
        return nil
    end
    return picked
end

-- Every item Tool carries these markers. This is the only reliable way to tell
-- vendor junk apart from your actual gear.
--   CannotBeDropped (Folder) -> quest / core item, never sell
--   IsSword (BoolValue)      -> weapon
--   IsOutfit (Folder)        -> armor
--   IsAccessory (Folder)     -> accessory
-- Note: IsTrinket is true even on armour, so it is useless as a junk signal.
local function itemCategory(tool)
    if tool:FindFirstChild("CannotBeDropped") then
        return "protected"
    end
    local isSword = tool:FindFirstChild("IsSword")
    if isSword and isSword.Value == true then
        return "weapon"
    end
    -- Potions carry IsPotion. Without this case they fall through to "trinket"
    -- and a Common rarity filter happily sells your healing and buff potions.
    if tool:FindFirstChild("IsPotion") then
        return "potion"
    end
    if tool:FindFirstChild("IsOutfit") then
        return "outfit"
    end
    if tool:FindFirstChild("IsAccessory") then
        return "accessory"
    end
    return "trinket"
end

local function categoryAllowed(category)
    if category == "protected" then
        return false
    end
    if category == "weapon" then
        return Toggles.SellWeapons and Toggles.SellWeapons.Value or false
    end
    if category == "outfit" then
        return Toggles.SellOutfits and Toggles.SellOutfits.Value or false
    end
    if category == "accessory" then
        return Toggles.SellAccessories and Toggles.SellAccessories.Value or false
    end
    if category == "potion" then
        return Toggles.SellPotions and Toggles.SellPotions.Value or false
    end
    return Toggles.SellTrinkets == nil or Toggles.SellTrinkets.Value
end

local function sellableItems()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not backpack then
        return {}
    end
    local wanted = selectedRarities()
    if not wanted then
        return {}
    end

    -- Never sell what is currently in your hands.
    local char = getCharacter()
    local equipped = char and char:FindFirstChildOfClass("Tool")

    local out = {}
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool ~= equipped and not PROTECTED_ITEMS[tool.Name] then
            local price = tool:FindFirstChild("SellPrice")
            if price and price.Value and price.Value > 0 then
                if wanted[rarityOfItem(tool)] and categoryAllowed(itemCategory(tool)) then
                    -- Enhanced items are almost always worth keeping.
                    local enh = tool:GetAttribute("Enhancements")
                    local isEnhanced = type(enh) == "string" and enh ~= ""
                    if (not isEnhanced) or (Toggles.SellEnhanced and Toggles.SellEnhanced.Value) then
                        out[#out + 1] = tool
                    end
                end
            end
        end
    end
    return out
end

local function findMerchant()
    local npcs = Workspace:FindFirstChild("NPCs")
    return npcs and npcs:FindFirstChild(MERCHANT_NAME) or nil
end

local function doSell()
    local items = sellableItems()
    if #items == 0 then
        return false, "Nothing matches your rarity filter"
    end

    local merchant = findMerchant()
    if not merchant then
        return false, "Cannot find the merchant here"
    end

    local ev = getRemote("SellItemsEvent")
    if not ev then
        return false, "Sell remote missing"
    end

    local root = getRoot()
    if not root then
        return false, "No character"
    end
    local returnTo = root.Position

    -- Selling is server range gated on the merchant, so we have to go there.
    if not approach(merchant, INTERACT_RANGE) then
        return false, "Could not get to the merchant"
    end
    task.wait(0.25)

    local ok = pcall(function()
        ev:FireServer(items)
    end)
    task.wait(0.6)

    if Toggles.SellReturn and Toggles.SellReturn.Value then
        moveTo(returnTo, 8)
    end

    if not ok then
        return false, "Sell failed"
    end
    return true, ("Sold %d items"):format(#items)
end

runLoop("AutoSell", "AutoSell", 3, function()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not backpack then
        return
    end
    local threshold = Options.SellThreshold and Options.SellThreshold.Value or 10
    if #sellableItems() < threshold then
        return
    end
    local ok, msg = doSell()
    Library:Notify("Auto Sell: " .. tostring(msg), 3)
end)

----------------------------------------------------------------------
-- Fullbright
----------------------------------------------------------------------

local lightingBackup = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    ClockTime = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
}

local function applyFullbright(on)
    if on then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e6
        Lighting.FogStart = 1e6
    else
        for k, v in pairs(lightingBackup) do
            pcall(function()
                Lighting[k] = v
            end)
        end
    end
end

task.spawn(function()
    while State.running do
        if Toggles.Fullbright and Toggles.Fullbright.Value then
            -- The game restyles Lighting by area, so keep reasserting it.
            applyFullbright(true)
        end
        task.wait(0.5)
    end
end)

----------------------------------------------------------------------
-- ESP
----------------------------------------------------------------------

local EspPool = {}

local function newEspEntry()
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Visible = false

    local name = Drawing.new("Text")
    name.Size = 13
    name.Center = true
    name.Outline = true
    name.Visible = false

    local dist = Drawing.new("Text")
    dist.Size = 12
    dist.Center = true
    dist.Outline = true
    dist.Visible = false

    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Visible = false

    return { box = box, name = name, dist = dist, tracer = tracer }
end

local function getEspEntry(i)
    if not EspPool[i] then
        EspPool[i] = newEspEntry()
    end
    return EspPool[i]
end

local function hideEspFrom(i)
    for j = i, #EspPool do
        local e = EspPool[j]
        e.box.Visible = false
        e.name.Visible = false
        e.dist.Visible = false
        e.tracer.Visible = false
    end
end

local function destroyEsp()
    for _, e in ipairs(EspPool) do
        pcall(function()
            e.box:Remove()
            e.name:Remove()
            e.dist:Remove()
            e.tracer:Remove()
        end)
    end
    table.clear(EspPool)
end

-- Project a model's bounding box onto the screen.
local function screenBox(model)
    local ok, cf, size = pcall(function()
        return model:GetBoundingBox()
    end)
    if not ok or not cf then
        local part = partOf(model)
        if not part then
            return nil
        end
        cf, size = part.CFrame, part.Size
    end

    local half = size * 0.5
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local onScreen = false

    for x = -1, 1, 2 do
        for y = -1, 1, 2 do
            for z = -1, 1, 2 do
                local corner = cf * CFrame.new(half.X * x, half.Y * y, half.Z * z)
                local sp, vis = Camera:WorldToViewportPoint(corner.Position)
                if vis then
                    onScreen = true
                end
                if sp.Z > 0 then
                    minX = math.min(minX, sp.X)
                    minY = math.min(minY, sp.Y)
                    maxX = math.max(maxX, sp.X)
                    maxY = math.max(maxY, sp.Y)
                end
            end
        end
    end

    if not onScreen or minX == math.huge then
        return nil
    end
    return minX, minY, maxX, maxY
end

local function espCategoryTargets()
    local out = {}
    local root = getRoot()
    if not root then
        return out
    end
    local maxDist = Options.EspDistance and Options.EspDistance.Value or 1500

    if Toggles.EspPlayers and Toggles.EspPlayers.Value then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                -- Team check: never draw party members as targets.
                local skip = Toggles.EspIgnoreTeam and Toggles.EspIgnoreTeam.Value and isFriendlyPlayer(plr)
                local part = plr.Character:FindFirstChild("HumanoidRootPart")
                if not skip and part then
                    local d = (root.Position - part.Position).Magnitude
                    if d <= maxDist then
                        out[#out + 1] = {
                            model = plr.Character,
                            label = plr.Name,
                            dist = d,
                            color = Options.EspPlayerColor and Options.EspPlayerColor.Value or Color3.fromRGB(255, 90, 90),
                        }
                    end
                end
            end
        end
    end

    if Toggles.EspMobs and Toggles.EspMobs.Value then
        local folder = monstersFolder()
        if folder then
            for _, m in ipairs(folder:GetChildren()) do
                if isHostileMob(m) then
                    local part = m:FindFirstChild("HumanoidRootPart")
                    local hum = m:FindFirstChildOfClass("Humanoid")
                    if part and hum and hum.Health > 0 then
                        local d = (root.Position - part.Position).Magnitude
                        if d <= maxDist then
                            out[#out + 1] = {
                                model = m,
                                label = ("%s [%d]"):format(m.Name, math.floor(hum.Health)),
                                dist = d,
                                color = Options.EspMobColor and Options.EspMobColor.Value or Color3.fromRGB(255, 170, 60),
                            }
                        end
                    end
                end
            end
        end
    end

    if Toggles.EspDrops and Toggles.EspDrops.Value then
        local folder = dropsFolder()
        if folder then
            local trinketOnly = Toggles.EspTrinketsOnly and Toggles.EspTrinketsOnly.Value
            for _, m in ipairs(folder:GetChildren()) do
                if isInteractable(m, "PickupDrop") and ((not trinketOnly) or TRINKET_NAMES[m.Name]) then
                    local pos = positionOf(m)
                    if pos then
                        local d = (root.Position - pos).Magnitude
                        if d <= maxDist then
                            out[#out + 1] = {
                                model = m,
                                label = ("%s (%s)"):format(m.Name, tostring(rarityOfDrop(m))),
                                dist = d,
                                color = Options.EspDropColor and Options.EspDropColor.Value or Color3.fromRGB(120, 255, 160),
                            }
                        end
                    end
                end
            end
        end
    end

    if Toggles.EspChests and Toggles.EspChests.Value then
        for _, entry in ipairs(gatherChests()) do
            if entry.dist <= maxDist then
                out[#out + 1] = {
                    model = entry.model,
                    label = "Chest",
                    dist = entry.dist,
                    color = Options.EspChestColor and Options.EspChestColor.Value or Color3.fromRGB(255, 235, 120),
                }
            end
        end
    end

    table.sort(out, function(a, b)
        return a.dist < b.dist
    end)

    local cap = Options.EspMaxObjects and Options.EspMaxObjects.Value or 120
    while #out > cap do
        table.remove(out)
    end
    return out
end

local espConnection
espConnection = RunService.RenderStepped:Connect(function()
    if not State.running or Library.Unloaded then
        hideEspFrom(1)
        if espConnection then
            espConnection:Disconnect()
        end
        return
    end
    if not Toggles.EspMaster or not Toggles.EspMaster.Value or not canAct() then
        hideEspFrom(1)
        return
    end

    local targets = espCategoryTargets()
    local i = 0
    for _, t in ipairs(targets) do
        local minX, minY, maxX, maxY = screenBox(t.model)
        if minX then
            i = i + 1
            local e = getEspEntry(i)
            local w, h = maxX - minX, maxY - minY

            if Toggles.EspBox and Toggles.EspBox.Value then
                e.box.Position = Vector2.new(minX, minY)
                e.box.Size = Vector2.new(w, h)
                e.box.Color = t.color
                e.box.Visible = true
            else
                e.box.Visible = false
            end

            if Toggles.EspName and Toggles.EspName.Value then
                e.name.Text = t.label
                e.name.Position = Vector2.new(minX + w * 0.5, minY - 15)
                e.name.Color = t.color
                e.name.Visible = true
            else
                e.name.Visible = false
            end

            if Toggles.EspDistanceText and Toggles.EspDistanceText.Value then
                e.dist.Text = ("%d studs"):format(math.floor(t.dist))
                e.dist.Position = Vector2.new(minX + w * 0.5, maxY + 2)
                e.dist.Color = t.color
                e.dist.Visible = true
            else
                e.dist.Visible = false
            end

            if Toggles.EspTracer and Toggles.EspTracer.Value then
                e.tracer.From = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y)
                e.tracer.To = Vector2.new(minX + w * 0.5, maxY)
                e.tracer.Color = t.color
                e.tracer.Visible = true
            else
                e.tracer.Visible = false
            end
        end
    end
    hideEspFrom(i + 1)
end)

----------------------------------------------------------------------
-- Drop webhook
----------------------------------------------------------------------

local HttpService = game:GetService("HttpService")

local RARITY_COLORS = {
    Common = 10197915,
    Uncommon = 4910432,
    Rare = 3717626,
    Elite = 11033582,
    Legendary = 16497700,
}

local RARITY_RANK = { Common = 1, Uncommon = 2, Rare = 3, Elite = 4, Legendary = 5 }

local webhookQueue = {}
local webhookSeen = {}

local function httpPost(url, body)
    local fn = (syn and syn.request) or http_request or request or (http and http.request)
    if type(fn) ~= "function" then
        return false, "This executor has no http request function"
    end
    local ok, res = pcall(fn, {
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = body,
    })
    if not ok then
        return false, tostring(res)
    end
    local code = res and (res.StatusCode or res.Status or res.status_code) or 0
    if code >= 200 and code < 300 then
        return true, tostring(code)
    end
    return false, tostring(code)
end

local function webhookUrl()
    local u = Options.WebhookUrl and Options.WebhookUrl.Value or ""
    if type(u) ~= "string" or not u:match("^https?://") then
        return nil
    end
    return u
end

local function webhookWantsRarity(rarity)
    local picked = Options.WebhookRarities and Options.WebhookRarities.Value or {}
    return picked[rarity] == true
end

local function sendWebhook(payload)
    local url = webhookUrl()
    if not url then
        return false, "No webhook url set"
    end
    local ok, body = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not ok then
        return false, "Could not encode payload"
    end
    return httpPost(url, body)
end

-- Batch drops so a burst of spawns does not spam the webhook.
local function flushWebhookQueue()
    if #webhookQueue == 0 then
        return
    end
    local batch = webhookQueue
    webhookQueue = {}

    table.sort(batch, function(a, b)
        local ra, rb = RARITY_RANK[a.rarity] or 0, RARITY_RANK[b.rarity] or 0
        if ra ~= rb then
            return ra > rb
        end
        return a.dist < b.dist
    end)

    local lines, best, bestRank = {}, "Common", 0
    for i, e in ipairs(batch) do
        if i <= 20 then
            lines[#lines + 1] = ("`%s`  %s  %d studs"):format(e.rarity, e.name, math.floor(e.dist))
        end
        local rank = RARITY_RANK[e.rarity] or 0
        if rank > bestRank then
            bestRank, best = rank, e.rarity
        end
    end
    if #batch > 20 then
        lines[#lines + 1] = ("and %d more"):format(#batch - 20)
    end

    sendWebhook({
        username = "Ouroboros",
        embeds = { {
            title = (#batch == 1) and "Drop spotted" or ("%d drops spotted"):format(#batch),
            description = table.concat(lines, "\n"),
            color = RARITY_COLORS[best] or RARITY_COLORS.Common,
            footer = { text = "Ouroboros | The Veil" },
        } },
    })
end

local function watchDropsForWebhook()
    local folder = dropsFolder()
    if not folder then
        return
    end
    folder.ChildAdded:Connect(function(model)
        if not (Toggles.DropWebhook and Toggles.DropWebhook.Value) then
            return
        end
        if webhookSeen[model] then
            return
        end
        webhookSeen[model] = true
        -- the Rarity attribute is not always set on the same frame it spawns
        task.delay(0.35, function()
            if not model.Parent then
                return
            end
            local rarity = model:GetAttribute("Rarity") or "Common"
            if not webhookWantsRarity(rarity) then
                return
            end
            local root = getRoot()
            local pos = positionOf(model)
            local dist = (root and pos) and (root.Position - pos).Magnitude or 0
            local limit = Options.WebhookRadius and Options.WebhookRadius.Value or 0
            if limit > 0 and dist > limit then
                return
            end
            webhookQueue[#webhookQueue + 1] = { name = model.Name, rarity = rarity, dist = dist }
        end)
    end)
end

task.spawn(function()
    watchDropsForWebhook()
    while State.running do
        task.wait(Options.WebhookInterval and Options.WebhookInterval.Value or 4)
        if Toggles.DropWebhook and Toggles.DropWebhook.Value then
            pcall(flushWebhookQueue)
        else
            webhookQueue = {}
        end
    end
end)

----------------------------------------------------------------------
-- UI
----------------------------------------------------------------------

local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")

local GAME_NAME = "The Veil"
local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"
local RSCRIPTS_LINK = "https://rscripts.net/@Ouroboros"
local WEBSITE_LINK = "https://ouroboros-hub-rbx.web.app/"

local function copyText(text, message)
    if setclipboard then
        setclipboard(text)
    elseif toclipboard then
        toclipboard(text)
    end
    Library:Notify(message)
end

local function copyDiscord()
    copyText(DISCORD_INVITE, "Copied Discord invite to clipboard")
end

local Window = Library:CreateWindow({
    Title = "Ouroboros",
    Font = Enum.Font.BuilderSans,
    Footer = {
        { Text = DISCORD_INVITE, Copyable = true },
        "|",
        GAME_NAME,
    },
    Icon = 78539693571783,
    NotifySide = "Right",
    ShowCustomCursor = false,
    CornerRadius = 0,
    SidebarCompacted = true,
    TabSwipeFrom = "bottom",
    Animations = {
        TabSwitch = true,
    },
})

Window:SetGlow(true, {
    Color = Color3.fromRGB(242, 154, 196),
    Radius = 24,
    Transparency = 0.3,
})

local Tabs = {
    Info = Window:AddTab("Info", "info"),
    Main = Window:AddTab("Main", "swords"),
    Items = Window:AddTab("Items", "package"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Misc = Window:AddTab("Misc", "settings-2"),
    Player = Window:AddTab("Player", "person-standing"),
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

for name, Tab in Tabs do
    if name ~= "Info" then
        AddDiscordButton(Tab)
    end
end

----------------------------------------------------------------------
-- Info tab
----------------------------------------------------------------------

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
local RED = "#e05a5a"

local function detectSupport()
    local flags = {
        hookfunction ~= nil,
        hookmetamethod ~= nil,
        getrawmetatable ~= nil,
        setrawmetatable ~= nil,
        getgc ~= nil,
        getgenv ~= nil,
        getreg ~= nil,
        getconnections ~= nil,
        firesignal ~= nil,
        getcallbackvalue ~= nil,
        setclipboard ~= nil,
        getcustomasset ~= nil,
        getnamecallmethod ~= nil,
        isexecutorclosure ~= nil,
        fireproximityprompt ~= nil,
        firetouchinterest ~= nil,
        WebSocket ~= nil,
        readfile ~= nil,
        writefile ~= nil,
        (request or http_request) ~= nil,
        (debug and debug.getupvalues) ~= nil,
        (debug and debug.setupvalue) ~= nil,
    }

    local available = 0
    for _, ok in ipairs(flags) do
        if ok then available += 1 end
    end

    local ratio = available / #flags
    if ratio >= 0.9 then
        return colored("Full Support", GREEN)
    elseif ratio >= 0.6 then
        return colored("Half Support", ORANGE)
    else
        return colored("Low Support", RED)
    end
end

local function setupInfoTab()
    local executorName = "Unknown"
    pcall(function()
        if identifyexecutor then
            local name, version = identifyexecutor()
            if type(name) == "string" and name ~= "" then
                executorName = type(version) == "string" and version ~= "" and (name .. " " .. version) or name
            end
        end
    end)

    local supportText = detectSupport()

    local sessionStart = os.clock()
    local function sessionElapsed()
        local elapsed = math.floor(os.clock() - sessionStart)
        if elapsed < 60 then return elapsed .. "s"
        elseif elapsed < 3600 then return string.format("%dm %ds", elapsed // 60, elapsed % 60)
        else return string.format("%dh %dm", elapsed // 3600, (elapsed % 3600) // 60) end
    end

    local UserGroup = Tabs.Info:AddLeftGroupbox("User", "circle-user")
    UserGroup:AddPlayerInfo("InfoUserCard", {
        Player = LocalPlayer,
        Title = "User",
        HeaderIcon = "user",
        Collapsible = false,
    })
    UserGroup:AddLabel(field("User", LocalPlayer.DisplayName .. " @" .. LocalPlayer.Name, GREEN), true)
    UserGroup:AddLabel(field("UserId", tostring(LocalPlayer.UserId), BLUE), true)
    UserGroup:AddLabel(field("Executor", executorName .. "  " .. supportText, GREEN), true)
    UserGroup:AddDivider()
    local SessionLabel = UserGroup:AddLabel(field("Session", sessionElapsed(), ORANGE), true)
    UserGroup:AddDivider()
    UserGroup:AddButton({ Text = "Copy Username", Func = function() copyText(LocalPlayer.Name, "Copied username") end })
    UserGroup:AddButton({
        Text = "Copy Profile Link",
        Func = function()
            copyText("https://www.roblox.com/users/" .. tostring(LocalPlayer.UserId) .. "/profile", "Copied profile link")
        end,
    })

    local SessionGroup = Tabs.Info:AddRightGroupbox("Session", "signal")
    SessionGroup:AddDivider("Server")
    SessionGroup:AddLabel(field("Game", GAME_NAME, BLUE), true)
    local PlayersLabel = SessionGroup:AddLabel(field("Players", "0/0", GREEN), true)
    local jobId = tostring(game.JobId)
    local shortJobId = #jobId > 18 and (string.sub(jobId, 1, 18) .. "...") or jobId
    SessionGroup:AddLabel(field("Job", shortJobId, GREY), true)
    local PingLabel = SessionGroup:AddLabel(field("Ping", "0 ms", ORANGE), true)
    SessionGroup:AddDivider()
    SessionGroup:AddButton({ Text = "Rejoin Server", Func = function() TeleportService:Teleport(PLACE_ID, LocalPlayer) end })
    SessionGroup:AddButton({ Text = "Copy Job ID", Func = function() copyText(jobId, "Copied Job ID") end })

    task.spawn(function()
        while true do
            task.wait(1)
            if Library.Unloaded then break end
            SessionLabel:SetText(field("Session", sessionElapsed(), ORANGE))
            PlayersLabel:SetText(field("Players", #Players:GetPlayers() .. "/" .. tostring(Players.MaxPlayers), GREEN))
            local ok, ping = pcall(function()
                return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            PingLabel:SetText(field("Ping", ok and (ping .. " ms") or "n/a", ORANGE))
        end
    end)

    local SocialsGroup = Tabs.Info:AddRightGroupbox("Socials", "link")
    SocialsGroup:AddButton({ Text = "Discord", Func = copyDiscord })
    SocialsGroup:AddButton({
        Text = "Rscripts",
        Func = function() copyText(RSCRIPTS_LINK, "Copied Rscripts profile to clipboard") end,
    })
    SocialsGroup:AddButton({ Text = "Website", Func = function() copyText(WEBSITE_LINK, "Copied website link") end })
end

setupInfoTab()

----------------------------------------------------------------------
-- Main tab
----------------------------------------------------------------------

local FarmBox = Tabs.Main:AddLeftGroupbox("Auto Farm", "swords")

FarmBox:AddToggle("AutoFarm", { Text = "Auto Farm NPCs", Default = false })
FarmBox:AddToggle("FarmAutoEquip", { Text = "Auto Equip Weapon", Default = true })
FarmBox:AddToggle("FarmFaceTarget", { Text = "Look At Target", Default = true })
FarmBox:AddToggle("FarmTiltToTarget", { Text = "Tilt Body Vertically", Default = false })
FarmBox:AddToggle("FarmCameraLock", { Text = "Camera Follows Target", Default = false })
FarmBox:AddSlider("FarmRadius", {
    Text = "Search Radius",
    Default = 2000,
    Min = 100,
    Max = 5000,
    Rounding = 0,
    Suffix = " studs",
})

local PosBox = Tabs.Main:AddRightGroupbox("Farm Positioning", "move")

PosBox:AddDropdown("FarmPosition", {
    Text = "Position Mode",
    Values = { "Orbit", "Hover", "Under", "Direct" },
    Default = 1,
    Multi = false,
})

PosBox:AddDivider("Orbit")

PosBox:AddSlider("FarmOrbitRadius", {
    Text = "Orbit Radius",
    Default = 5,
    Min = 2,
    Max = 40,
    Rounding = 0,
    Suffix = " studs",
})

PosBox:AddSlider("FarmOrbitSpeed", {
    Text = "Orbit Speed",
    Default = 120,
    Min = 10,
    Max = 720,
    Rounding = 0,
    Suffix = " deg/s",
})

PosBox:AddDivider("Offsets")

PosBox:AddSlider("FarmHeight", {
    Text = "Hover Height",
    Default = 4,
    Min = 0,
    Max = 60,
    Rounding = 0,
    Suffix = " studs",
})

PosBox:AddSlider("FarmDepth", {
    Text = "Under Depth",
    Default = 8,
    Min = 0,
    Max = 60,
    Rounding = 0,
    Suffix = " studs",
})

PosBox:AddSlider("FarmReach", {
    Text = "Direct Reach",
    Default = 6,
    Min = 2,
    Max = 30,
    Rounding = 0,
    Suffix = " studs",
})

PosBox:AddDivider("Repositioning")

PosBox:AddToggle("FarmSmooth", { Text = "Smooth Repositioning", Default = true })

PosBox:AddSlider("FarmMoveSpeed", {
    Text = "Reposition Speed",
    Default = 120,
    Min = 20,
    Max = 800,
    Rounding = 0,
    Suffix = " studs/s",
})

local ChestBox = Tabs.Main:AddLeftGroupbox("Chests", "box")

ChestBox:AddToggle("AutoChest", { Text = "Auto Open Chests", Default = false })
ChestBox:AddToggle("ChestLootSweep", { Text = "Grab Chest Loot", Default = true })

----------------------------------------------------------------------
-- Items tab
----------------------------------------------------------------------

local PickupBox = Tabs.Items:AddLeftGroupbox("Pickup", "hand")

PickupBox:AddToggle("AutoTrinket", { Text = "Auto Trinket Teleport", Default = false })
PickupBox:AddSlider("TrinketRadius", {
    Text = "Trinket Radius",
    Default = 3000,
    Min = 100,
    Max = 6000,
    Rounding = 0,
    Suffix = " studs",
})

PickupBox:AddDivider("Pickup All")

PickupBox:AddToggle("AutoPickup", { Text = "Auto Pickup All", Default = false })
PickupBox:AddSlider("PickupRadius", {
    Text = "Pickup Radius",
    Default = 3000,
    Min = 100,
    Max = 6000,
    Rounding = 0,
    Suffix = " studs",
})

local SellBox = Tabs.Items:AddLeftGroupbox("Auto Sell", "coins")

SellBox:AddToggle("AutoSell", { Text = "Auto Sell", Default = false })

SellBox:AddDropdown("SellRarities", {
    Text = "Rarities To Sell",
    Values = RARITIES,
    Default = { "Common" },
    Multi = true,
})

SellBox:AddDivider("Categories")

SellBox:AddToggle("SellTrinkets", { Text = "Trinkets And Junk", Default = true })
SellBox:AddToggle("SellWeapons", { Text = "Weapons", Default = false })
SellBox:AddToggle("SellOutfits", { Text = "Outfits And Armor", Default = false })
SellBox:AddToggle("SellAccessories", { Text = "Accessories", Default = false })
SellBox:AddToggle("SellPotions", { Text = "Potions", Default = false })
SellBox:AddToggle("SellEnhanced", { Text = "Also Sell Enhanced", Default = false })

SellBox:AddDivider("Behaviour")

SellBox:AddSlider("SellThreshold", {
    Text = "Sell When N Items Match",
    Default = 10,
    Min = 1,
    Max = 60,
    Rounding = 0,
})

SellBox:AddToggle("SellReturn", { Text = "Return After Selling", Default = true })

SellBox:AddButton({
    Text = "Sell Now",
    Func = function()
        task.spawn(function()
            local ok, msg = doSell()
            Library:Notify("Sell: " .. tostring(msg), 4)
        end)
    end,
})

local HookBox = Tabs.Items:AddRightGroupbox("Drop Webhook", "bell")

HookBox:AddToggle("DropWebhook", { Text = "Drop Webhook", Default = false })

HookBox:AddInput("WebhookUrl", {
    Text = "Webhook URL",
    Default = "",
    Placeholder = "https://discord.com/api/webhooks/...",
    Numeric = false,
    Finished = true,
})

HookBox:AddDropdown("WebhookRarities", {
    Text = "Rarities To Post",
    Values = RARITIES,
    Default = { "Rare", "Elite", "Legendary" },
    Multi = true,
})

HookBox:AddSlider("WebhookRadius", {
    Text = "Only Within",
    Default = 0,
    Min = 0,
    Max = 5000,
    Rounding = 0,
    Suffix = " studs",
})

HookBox:AddSlider("WebhookInterval", {
    Text = "Batch Every",
    Default = 4,
    Min = 1,
    Max = 30,
    Rounding = 0,
    Suffix = "s",
})

HookBox:AddButton({
    Text = "Send Test Webhook",
    Func = function()
        task.spawn(function()
            local ok, info = sendWebhook({
                username = "Ouroboros",
                embeds = { {
                    title = "Test",
                    description = "Webhook is working",
                    color = RARITY_COLORS.Legendary,
                    footer = { text = "Ouroboros | The Veil" },
                } },
            })
            Library:Notify(ok and "Webhook sent" or ("Webhook failed: " .. tostring(info)), 4)
        end)
    end,
})

----------------------------------------------------------------------
-- Visuals tab
----------------------------------------------------------------------

local EspBox = Tabs.Visuals:AddLeftGroupbox("ESP", "eye")

EspBox:AddToggle("EspMaster", { Text = "Enable ESP", Default = false })

EspBox:AddDivider("Drawings")

EspBox:AddToggle("EspBox", { Text = "Boxes", Default = true })
EspBox:AddToggle("EspName", { Text = "Names", Default = true })
EspBox:AddToggle("EspDistanceText", { Text = "Distance", Default = true })
EspBox:AddToggle("EspTracer", { Text = "Tracers", Default = false })

EspBox:AddDivider("Limits")

EspBox:AddSlider("EspDistance", {
    Text = "Max Distance",
    Default = 1500,
    Min = 100,
    Max = 6000,
    Rounding = 0,
    Suffix = " studs",
})

EspBox:AddSlider("EspMaxObjects", {
    Text = "Max Drawn",
    Default = 120,
    Min = 10,
    Max = 400,
    Rounding = 0,
})

local EspCatBox = Tabs.Visuals:AddRightGroupbox("ESP Targets", "list")

EspCatBox:AddToggle("EspPlayers", { Text = "Players", Default = false })
    :AddColorPicker("EspPlayerColor", { Default = Color3.fromRGB(255, 90, 90), Title = "Player color" })
EspCatBox:AddToggle("EspIgnoreTeam", { Text = "Hide Party Members", Default = true })
EspCatBox:AddToggle("EspMobs", { Text = "Mobs", Default = false })
    :AddColorPicker("EspMobColor", { Default = Color3.fromRGB(255, 170, 60), Title = "Mob color" })
EspCatBox:AddToggle("EspDrops", { Text = "Items And Accessories", Default = false })
    :AddColorPicker("EspDropColor", { Default = Color3.fromRGB(120, 255, 160), Title = "Item color" })
EspCatBox:AddToggle("EspTrinketsOnly", { Text = "Only Trinkets", Default = false })
EspCatBox:AddToggle("EspChests", { Text = "Chests", Default = false })
    :AddColorPicker("EspChestColor", { Default = Color3.fromRGB(255, 235, 120), Title = "Chest color" })

local LightBox = Tabs.Visuals:AddLeftGroupbox("World", "sun")

LightBox:AddToggle("Fullbright", {
    Text = "Fullbright",
    Default = true,
    Callback = function(v)
        applyFullbright(v)
    end,
})

----------------------------------------------------------------------
-- Misc tab
----------------------------------------------------------------------

local MoveBox = Tabs.Misc:AddLeftGroupbox("Movement", "move")

MoveBox:AddDropdown("MoveMode", {
    Text = "Travel Mode",
    Values = { "Teleport", "Tween" },
    Default = 1,
    Multi = false,
    Callback = function(v)
        State.moveMode = v
    end,
})

MoveBox:AddSlider("TweenSpeed", {
    Text = "Tween Speed",
    Default = 220,
    Min = 40,
    Max = 800,
    Rounding = 0,
    Suffix = " studs/s",
    Callback = function(v)
        State.tweenSpeed = v
    end,
})

MoveBox:AddSlider("ActionDelay", {
    Text = "Action Delay",
    Default = 0.15,
    Min = 0.05,
    Max = 1,
    Rounding = 2,
    Suffix = "s",
    Callback = function(v)
        State.actionDelay = v
    end,
})

MoveBox:AddToggle("AutoNoclip", { Text = "Auto Noclip", Default = true })

local ServerBox = Tabs.Misc:AddRightGroupbox("Server", "server")

ServerBox:AddButton({
    Text = "Rejoin",
    Func = function()
        TeleportService:Teleport(PLACE_ID, LocalPlayer)
    end,
})

ServerBox:AddButton({
    Text = "Server Hop",
    Func = function()
        local ok, err = pcall(function()
            TeleportService:Teleport(PLACE_ID, LocalPlayer)
        end)
        if not ok then
            Library:Notify("Hop failed: " .. tostring(err), 4)
        end
    end,
})

----------------------------------------------------------------------
-- Player tab
----------------------------------------------------------------------

local instantPromptConnection

local function setupPlayerTab()
    local MovementGroup = Tabs.Player:AddLeftGroupbox("Movement", "footprints")
    MovementGroup:AddToggle("WalkSpeedEnabled", { Text = "WalkSpeed", Default = false })
    MovementGroup:AddSlider("WalkSpeed", {
        Text = "WalkSpeed Amount",
        Default = 32, Min = 16, Max = 250, Rounding = 0,
    })
    MovementGroup:AddToggle("InfJump", { Text = "Infinite Jump", Default = false })
    MovementGroup:AddToggle("NoClip", { Text = "NoClip", Default = false })
    MovementGroup:AddToggle("InstantProximityPrompt", { Text = "Instant ProximityPrompt", Default = false })

    local FlyGroup = Tabs.Player:AddRightGroupbox("Fly", "feather")
    FlyGroup:AddToggle("Fly", { Text = "Fly", Default = false })
    FlyGroup:AddSlider("FlySpeed", {
        Text = "Fly Speed",
        Default = 60, Min = 10, Max = 400, Rounding = 0,
    })

    UserInputService.JumpRequest:Connect(function()
        if Library.Unloaded then return end
        if Toggles.InfJump and Toggles.InfJump.Value then
            local humanoid = getHumanoid()
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end)

    RunService.RenderStepped:Connect(function(dt)
        if Library.Unloaded then return end
        if Toggles.WalkSpeedEnabled and Toggles.WalkSpeedEnabled.Value then
            local humanoid = getHumanoid()
            if humanoid then humanoid.WalkSpeed = Options.WalkSpeed.Value end
        end
        if Toggles.Fly and Toggles.Fly.Value then
            local root = getRoot()
            local humanoid = getHumanoid()
            if root and humanoid then
                humanoid.PlatformStand = true
                local direction = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction - Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction - Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction = direction + Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then direction = direction - Vector3.new(0, 1, 0) end
                root.AssemblyLinearVelocity = Vector3.zero
                if direction.Magnitude > 0 then
                    root.CFrame = root.CFrame + direction.Unit * Options.FlySpeed.Value * dt
                end
            end
        end
    end)

    Toggles.Fly:OnChanged(function()
        if not Toggles.Fly.Value then
            local humanoid = getHumanoid()
            if humanoid then humanoid.PlatformStand = false end
        end
    end)

    Toggles.WalkSpeedEnabled:OnChanged(function()
        if not Toggles.WalkSpeedEnabled.Value then
            local humanoid = getHumanoid()
            if humanoid then humanoid.WalkSpeed = 16 end
        end
    end)

    local function applyInstantPrompt(prompt)
        if not prompt:IsA("ProximityPrompt") then return end
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 50
        prompt.RequiresLineOfSight = false
    end

    Toggles.InstantProximityPrompt:OnChanged(function()
        if Toggles.InstantProximityPrompt.Value then
            for _, prompt in ipairs(Workspace:GetDescendants()) do
                pcall(applyInstantPrompt, prompt)
            end
            instantPromptConnection = Workspace.DescendantAdded:Connect(function(descendant)
                if Toggles.InstantProximityPrompt.Value then
                    pcall(applyInstantPrompt, descendant)
                end
            end)
        elseif instantPromptConnection then
            instantPromptConnection:Disconnect()
            instantPromptConnection = nil
        end
    end)
end

setupPlayerTab()

----------------------------------------------------------------------
-- Settings tab
----------------------------------------------------------------------

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "logs")

local antiAfkIdledConnection
local fpsBoostConnection

local function applyAntiGameplayPause(enabled)
    pcall(function()
        GuiService:SetGameplayPausedNotificationEnabled(not enabled)
    end)
    pcall(function()
        local notification = CoreGui:FindFirstChild("RobloxNetworkPauseNotification")
        if notification then notification.Enabled = not enabled end
    end)
    if not enabled then return end
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(LocalPlayer, "GameplayPaused", false)
        else
            LocalPlayer.GameplayPaused = false
        end
    end)
end

local function setupMenuGroup()
    local antiAfkTriggerCount = 0
    local antiAfkLastPulse = tick()

    MenuGroup:AddToggle("AntiAfk", { Text = "Anti-AFK", Default = true })

    local antiAfkStat = MenuGroup:AddLabel("AFK triggers: 0")

    local function antiAfkTap()
        local camera = Workspace.CurrentCamera
        if not camera then return end
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0), camera.CFrame)
        antiAfkTriggerCount = antiAfkTriggerCount + 1
        antiAfkLastPulse = tick()
        pcall(function() antiAfkStat:SetText("AFK triggers: " .. antiAfkTriggerCount) end)
    end

    antiAfkIdledConnection = LocalPlayer.Idled:Connect(function()
        if Toggles.AntiAfk.Value then
            pcall(antiAfkTap)
        end
    end)

    task.spawn(function()
        while not Library.Unloaded do
            task.wait(2)
            if Toggles.AntiAfk.Value and tick() - antiAfkLastPulse >= 60 then
                pcall(antiAfkTap)
            end
        end
    end)

    MenuGroup:AddToggle("AntiGameplayPause", { Text = "No Gameplay Paused", Default = true })
    MenuGroup:AddToggle("AutoReconnect", { Text = "Auto Reconnect on Kick", Default = false })
    MenuGroup:AddToggle("Disable3D", { Text = "Disable 3D Rendering", Default = false })
    MenuGroup:AddToggle("FpsBoost", { Text = "FPS Boost", Default = false })
    MenuGroup:AddToggle("HideUiOnStart", { Text = "Hide UI On Start", Default = false })

    Toggles.AntiGameplayPause:OnChanged(function()
        applyAntiGameplayPause(Toggles.AntiGameplayPause.Value)
    end)

    task.spawn(function()
        while not Library.Unloaded do
            task.wait(1)
            if Toggles.AntiGameplayPause.Value then
                applyAntiGameplayPause(true)
            end
        end
    end)

    local reconnecting = false

    local function rejoin()
        if reconnecting then return end
        reconnecting = true
        local placeId, jobId = game.PlaceId, game.JobId
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
        end)
        if not ok then
            pcall(function() TeleportService:Teleport(placeId, LocalPlayer) end)
        end
    end

    task.spawn(function()
        local overlay = CoreGui:WaitForChild("RobloxPromptGui", 30)
        overlay = overlay and overlay:WaitForChild("promptOverlay", 30)
        if not overlay then return end
        overlay.ChildAdded:Connect(function(child)
            if Library.Unloaded then return end
            if Toggles.AutoReconnect.Value and child.Name == "ErrorPrompt" then
                rejoin()
            end
        end)
    end)

    TeleportService.TeleportInitFailed:Connect(function()
        if Toggles.AutoReconnect.Value then
            reconnecting = false
            rejoin()
        end
    end)

    Toggles.Disable3D:OnChanged(function()
        pcall(function()
            RunService:Set3dRenderingEnabled(not Toggles.Disable3D.Value)
        end)
    end)

    local strippedClasses = {
        ParticleEmitter = true, Trail = true, Smoke = true, Fire = true,
        Sparkles = true, Explosion = true, Beam = true,
    }

    local function stripEffect(instance)
        if strippedClasses[instance.ClassName] then
            pcall(function() instance.Enabled = false end)
        end
    end

    Toggles.FpsBoost:OnChanged(function()
        if Toggles.FpsBoost.Value then
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
            pcall(function() Lighting.GlobalShadows = false end)
            pcall(function() Lighting.FogEnd = 9e9 end)
            for _, instance in ipairs(Workspace:GetDescendants()) do
                pcall(stripEffect, instance)
            end
            fpsBoostConnection = Workspace.DescendantAdded:Connect(function(instance)
                if Toggles.FpsBoost.Value then
                    pcall(stripEffect, instance)
                end
            end)
        else
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
            pcall(function() Lighting.GlobalShadows = true end)
            if fpsBoostConnection then
                fpsBoostConnection:Disconnect()
                fpsBoostConnection = nil
            end
        end
    end)

    Library.ToggleKeybind = Options.MenuKeybind
    MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
        Default = "RightShift",
        NoUI = true,
        Text = "Menu keybind",
    })
end

setupMenuGroup()

local ScriptGroup = Tabs.Settings:AddLeftGroupbox("Script", "terminal")
ScriptGroup:AddButton({
    Text = "Unload Script",
    Func = function()
        Library:Unload()
    end,
})

----------------------------------------------------------------------
-- Theme and config
----------------------------------------------------------------------

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("OuroborosHub")
ThemeManager:SaveDefault("Evil Hello Kitty")
ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind", "SaveManager_ImportSource" })
SaveManager:SetFolder("OuroborosHub/TheVeil")
local ConfigurationBox = SaveManager:BuildConfigSection(Tabs.Settings)

local function setupConfigTransfer()
    local function configElement(objectType, index)
        local holder = objectType == "Toggle" and Toggles or Options
        local element = holder[index]
        return type(element) == "table" and element.Type == objectType and element or nil
    end

    local function encodeConfigObject(index, element)
        local elementType = element.Type
        if elementType == "Toggle" then
            return { idx = index, type = "Toggle", value = element.Value == true }
        elseif elementType == "Slider" then
            return { idx = index, type = "Slider", value = tostring(element.Value) }
        elseif elementType == "Dropdown" then
            return { idx = index, type = "Dropdown", multi = element.Multi == true, value = element.Value }
        elseif elementType == "Input" then
            return { idx = index, type = "Input", text = tostring(element.Value or "") }
        elseif elementType == "ColorPicker" then
            return {
                idx = index,
                type = "ColorPicker",
                value = element.Value:ToHex(),
                transparency = element.Transparency,
            }
        elseif elementType == "KeyPicker" then
            return {
                idx = index,
                type = "KeyPicker",
                mode = element.Mode,
                key = element.Value,
                modifiers = element.Modifiers,
                toggled = element.Toggled,
            }
        end
        return nil
    end

    local function buildConfigPayload()
        local objects = {}
        for _, holder in ipairs({ Toggles, Options }) do
            for index, element in pairs(holder) do
                if type(element) == "table"
                    and type(element.Type) == "string"
                    and not SaveManager.Ignore[index]
                then
                    local encoded = encodeConfigObject(index, element)
                    if encoded then
                        objects[#objects + 1] = encoded
                    end
                end
            end
        end
        table.sort(objects, function(a, b)
            if a.type ~= b.type then return a.type < b.type end
            return a.idx < b.idx
        end)
        return { objects = objects }
    end

    local function applyConfigObject(object)
        if type(object) ~= "table"
            or type(object.idx) ~= "string"
            or type(object.type) ~= "string"
            or SaveManager.Ignore[object.idx]
        then
            return false
        end
        local element = configElement(object.type, object.idx)
        if not element then return false end
        local applied = pcall(function()
            if object.type == "Input" then
                if type(object.text) ~= "string" then return end
                element:SetValue(object.text)
            elseif object.type == "ColorPicker" then
                element:SetValueRGB(Color3.fromHex(object.value), object.transparency)
            elseif object.type == "KeyPicker" then
                element:SetValue({ object.key, object.mode, object.modifiers })
                if object.mode == "Toggle" and object.toggled ~= nil then
                    element.Toggled = object.toggled
                    element:Update()
                end
            else
                element:SetValue(object.value)
            end
        end)
        return applied
    end

    ConfigurationBox:AddDivider()
    ConfigurationBox:AddInput("SaveManager_ImportSource", {
        Text = "Paste exported config here",
        Finished = true,
        AllowEmpty = true,
    })
    ConfigurationBox:AddButton("Export Config to Clipboard", function()
        local encodeSuccess, encoded = pcall(HttpService.JSONEncode, HttpService, buildConfigPayload())
        if not encodeSuccess then
            Library:Notify("Failed to encode the config")
            return
        end
        local writeClipboard = setclipboard or toclipboard
        if type(writeClipboard) ~= "function" or not pcall(writeClipboard, encoded) then
            Library:Notify("Your executor does not support copying to the clipboard")
            return
        end
        Library:Notify("Config copied to clipboard", 6)
    end)
    ConfigurationBox:AddButton("Import Config from Clipboard Text", function()
        local source = tostring(Options.SaveManager_ImportSource.Value or ""):match("^%s*(.-)%s*$")
        if source == "" then
            Library:Notify("Paste an exported config into the box first")
            return
        end
        local decodeSuccess, decoded = pcall(HttpService.JSONDecode, HttpService, source)
        if not decodeSuccess or type(decoded) ~= "table" or type(decoded.objects) ~= "table" then
            Library:Notify("That is not a valid exported config")
            return
        end
        local applied = 0
        for _, object in ipairs(decoded.objects) do
            if applyConfigObject(object) then applied += 1 end
        end
        if applied == 0 then
            Library:Notify("No settings in that config matched this script")
            return
        end
        Options.SaveManager_ImportSource:SetValue("")
        Library:Notify(("Imported %d setting%s"):format(applied, applied == 1 and "" or "s"), 6)
    end)
end

setupConfigTransfer()

SaveManager:LoadAutoloadConfig()

----------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------

Library:OnUnload(function()
    State.running = false
    destroyEsp()
    applyFullbright(false)
    clearNoclip()
    applyAntiGameplayPause(false)
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
    if antiAfkIdledConnection then antiAfkIdledConnection:Disconnect() end
    if fpsBoostConnection then fpsBoostConnection:Disconnect() end
    if instantPromptConnection then instantPromptConnection:Disconnect() end
    local hum = getHumanoid()
    if hum and State.autoRotateSaved ~= nil then
        hum.AutoRotate = State.autoRotateSaved
    elseif hum then
        hum.AutoRotate = true
    end
    Library.Unloaded = true
end)

if Toggles.HideUiOnStart.Value then
    Library:Toggle(false)
end

Library:Notify("Ouroboros Hub loaded", 5)
