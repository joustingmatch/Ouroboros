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

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Configs = ReplicatedStorage:WaitForChild("ReplicatedModules"):WaitForChild("Configs")
local WeaponConfig = require(Configs:WaitForChild("WeaponConfig"))
local ShopConfig = require(Configs:WaitForChild("ShopConfig"))

local Swing = Remotes:WaitForChild("Swing", 10)
local PlaceMine = Remotes:WaitForChild("PlaceMine", 10)
local Shop = Remotes:WaitForChild("Shop", 10)
local Quest = Remotes:WaitForChild("Quest", 10)

local GAME_NAME = "Slap to Survive"
local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"
local RSCRIPTS_LINK = "https://rscripts.net/@Ouroboros"

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

pcall(function()
    Library.ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end)

local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Toggles = Library.Toggles
local Options = Library.Options

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

local shopState = { owned = {}, cash = 0, equipped = nil }
local questState = {}
local questsClaimed = 0
local auraAnchor = nil
local lockedMonster = nil
local collisionState = {}
local anchoredRoot = nil
local anchoredState = false

local function isOn(name)
    local toggle = Toggles[name]
    return toggle ~= nil and toggle.Value == true
end

local function getNumber(name, fallback)
    local option = Options[name]
    return option and tonumber(option.Value) or fallback
end

local function getChoice(name, fallback)
    local option = Options[name]
    return option and option.Value or fallback
end

local function getRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isAlive()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0
end

local function getEquippedTool()
    local character = LocalPlayer.Character
    local tool = character and character:FindFirstChildOfClass("Tool")
    if tool and WeaponConfig.DefOf(tool) then
        return tool
    end
    return nil
end

local function requestShop(action, key)
    if not Shop then
        return nil
    end
    local ok, result = pcall(function()
        return Shop:InvokeServer(action, key)
    end)
    if not ok or type(result) ~= "table" then
        return nil
    end
    if type(result.owned) == "table" then
        shopState.owned = result.owned
    end
    if tonumber(result.cash) then
        shopState.cash = tonumber(result.cash)
    end
    if result.equipped then
        shopState.equipped = result.equipped
    end
    return result
end

local function bestOwnedWeapon()
    local best, bestDamage
    for key in shopState.owned do
        local def = WeaponConfig.Tools[key]
        local damage = def and def.damage or 0
        if damage > 0 and (not best or damage > bestDamage) then
            best, bestDamage = key, damage
        end
    end
    return best
end

local function equipBestWeapon()
    local best = bestOwnedWeapon()
    if best and best ~= shopState.equipped then
        requestShop("equip", best)
    end
end

local function nearestMonster(origin, range)
    local monsters = workspace:FindFirstChild("Monsters")
    if not monsters then
        return nil, nil
    end
    local best, bestPart, bestDistance
    for _, model in monsters:GetChildren() do
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
        if humanoid and humanoid.Health > 0 and part then
            local distance = (part.Position - origin).Magnitude
            if distance <= range and (not bestDistance or distance < bestDistance) then
                best, bestPart, bestDistance = model, part, distance
            end
        end
    end
    return best, bestPart, bestDistance
end

local function validMonster(model)
    if not model or not model.Parent then
        return false
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
    return humanoid ~= nil and humanoid.Health > 0 and part ~= nil
end

local function setFarmNoclip(enabled)
    local character = LocalPlayer.Character
    if enabled and character then
        for _, descendant in character:GetDescendants() do
            if descendant:IsA("BasePart") then
                if collisionState[descendant] == nil then
                    collisionState[descendant] = descendant.CanCollide
                end
                descendant.CanCollide = false
            end
        end
        return
    end
    for part, canCollide in collisionState do
        if part and part.Parent then
            part.CanCollide = canCollide
        end
    end
    table.clear(collisionState)
end

local function clearFarmVelocity()
    local character = LocalPlayer.Character
    if not character then
        return
    end
    for _, descendant in character:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.AssemblyLinearVelocity = Vector3.zero
            descendant.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

local function setAntiFling(enabled)
    local root = getRoot()
    if enabled and root then
        if anchoredRoot ~= root then
            if anchoredRoot and anchoredRoot.Parent then
                anchoredRoot.Anchored = anchoredState
            end
            anchoredRoot = root
            anchoredState = root.Anchored
        end
        clearFarmVelocity()
        root.Anchored = true
        return
    end
    if anchoredRoot and anchoredRoot.Parent then
        anchoredRoot.Anchored = anchoredState
    end
    anchoredRoot = nil
    anchoredState = false
end

local function farmCFrame(targetPart)
    local method = getChoice("AuraMethod", "Strafe")
    local distance = getNumber("AuraDistance", 6)
    local height = getNumber("AuraHeight", 5)
    local targetPosition = targetPart.Position
    local position

    if method == "Above" then
        position = targetPosition + Vector3.new(0, height, 0)
    elseif method == "Under" then
        position = targetPosition - Vector3.new(0, height, 0)
    elseif method == "Behind" then
        position = targetPosition - targetPart.CFrame.LookVector * distance + Vector3.new(0, 1.5, 0)
    else
        local angle = os.clock() * getNumber("AuraStrafeSpeed", 4)
        position = targetPosition + Vector3.new(math.cos(angle) * distance, height, math.sin(angle) * distance)
    end

    local upVector = (method == "Above" or method == "Under") and Vector3.new(0, 0, -1) or Vector3.new(0, 1, 0)
    return CFrame.lookAt(position, targetPosition, upVector)
end

local function restoreAnchor()
    local root = getRoot()
    if root and auraAnchor then
        root.CFrame = auraAnchor
    end
    setAntiFling(false)
    auraAnchor = nil
    lockedMonster = nil
    setFarmNoclip(false)
end

local Window = Library:CreateWindow({
    Title = "Ouroboros Hub",
    Footer = DISCORD_INVITE .. " | " .. GAME_NAME,
    Icon = 18657887261,
    NotifySide = "Right",
    ShowCustomCursor = false,
})

local Tabs = {
    Info = Window:AddTab("Info", "info"),
    Combat = Window:AddTab("Combat", "crosshair"),
    Shop = Window:AddTab("Shop", "shopping-bag"),
    Quests = Window:AddTab("Quests", "scroll-text"),
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

for _, Tab in Tabs do
    AddDiscordButton(Tab)
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
        copyText(
            string.format(
                'game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s", game:GetService("Players").LocalPlayer)',
                game.PlaceId,
                jobId
            ),
            "Copied join script to clipboard"
        )
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

local ScriptsGroup = Tabs.Info:AddRightGroupbox("Scripts", "package")

ScriptsGroup:AddLabel(colored("Included in this hub", GREY), true)
ScriptsGroup:AddLabel(colored(GAME_NAME, BLUE), true)

local FeaturesGroup = Tabs.Info:AddRightGroupbox("Features", "list")

FeaturesGroup:AddLabel(colored("Auto Farm: Strafe / Above / Under / Behind", BLUE), true)
FeaturesGroup:AddLabel(colored("Target Lock / Noclip / Anti Knockback / Swing Burst", BLUE), true)
FeaturesGroup:AddLabel(colored("Auto Buy Weapons", ORANGE), true)
FeaturesGroup:AddLabel(colored("Auto Claim Quests", GREEN), true)
FeaturesGroup:AddLabel(colored("Misc Utilities", GREY), true)

local SocialsGroup = Tabs.Info:AddRightGroupbox("Socials", "link")

SocialsGroup:AddButton({
    Text = "Discord",
    Func = copyDiscord,
})

SocialsGroup:AddButton({
    Text = "Rscripts",
    Func = function()
        copyText(RSCRIPTS_LINK, "Copied Rscripts profile to clipboard")
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

local AuraGroup = Tabs.Combat:AddLeftGroupbox("Auto Farm", "crosshair")

AuraGroup:AddToggle("KillAura", {
    Text = "Auto Farm",
    Default = false,
    Callback = function(value)
        if value then
            local root = getRoot()
            auraAnchor = root and root.CFrame or nil
        else
            restoreAnchor()
        end
    end,
})

AuraGroup:AddToggle("AuraEquipBest", {
    Text = "Equip Best Weapon",
    Default = true,
})

AuraGroup:AddToggle("AuraTeleport", {
    Text = "Move To Target",
    Default = true,
})

AuraGroup:AddDropdown("AuraMethod", {
    Text = "Farm Method",
    Values = { "Strafe", "Above", "Under", "Behind" },
    Default = 1,
})

AuraGroup:AddToggle("AuraTargetLock", {
    Text = "Lock Target Until Dead",
    Default = true,
})

AuraGroup:AddToggle("AuraNoclip", {
    Text = "Noclip While Farming",
    Default = true,
})

AuraGroup:AddToggle("AuraAntiKnockback", {
    Text = "Anti Fling / Knockback",
    Default = true,
})

AuraGroup:AddToggle("AuraReturn", {
    Text = "Return To Start Position",
    Default = true,
})

AuraGroup:AddSlider("AuraRange", {
    Text = "Search Range",
    Default = 250,
    Min = 20,
    Max = 1000,
    Rounding = 0,
})

AuraGroup:AddSlider("AuraDistance", {
    Text = "Strafe / Behind Distance",
    Default = 6,
    Min = 2,
    Max = 25,
    Rounding = 1,
})

AuraGroup:AddSlider("AuraHeight", {
    Text = "Vertical Offset",
    Default = 5,
    Min = 2,
    Max = 30,
    Rounding = 1,
})

AuraGroup:AddSlider("AuraStrafeSpeed", {
    Text = "Strafe Speed",
    Default = 4,
    Min = 0.5,
    Max = 15,
    Rounding = 1,
})

AuraGroup:AddSlider("AuraSwingBurst", {
    Text = "Swing Burst",
    Default = 1,
    Min = 1,
    Max = 5,
    Rounding = 0,
})

AuraGroup:AddSlider("AuraDelay", {
    Text = "Attack Delay",
    Default = 0.03,
    Min = 0.01,
    Max = 1,
    Rounding = 3,
})

local AuraInfoGroup = Tabs.Combat:AddRightGroupbox("Weapon", "sword")

local WeaponLabel = AuraInfoGroup:AddLabel(field("Equipped", "None", BLUE), true)
local WeaponStatsLabel = AuraInfoGroup:AddLabel(field("Damage", "0", ORANGE), true)
local MonsterLabel = AuraInfoGroup:AddLabel(field("Monsters alive", "0", GREY), true)

AuraInfoGroup:AddButton({
    Text = "Equip Best Weapon",
    Func = function()
        requestShop("state")
        equipBestWeapon()
    end,
})

local BuyGroup = Tabs.Shop:AddLeftGroupbox("Auto Buy Weapons", "shopping-cart")

BuyGroup:AddToggle("AutoBuyWeapons", {
    Text = "Auto Buy Weapons",
    Default = false,
})

BuyGroup:AddToggle("AutoEquipBought", {
    Text = "Equip Best After Buying",
    Default = true,
})

BuyGroup:AddSlider("BuyDelay", {
    Text = "Loop Delay",
    Default = 2,
    Min = 0.5,
    Max = 30,
    Rounding = 1,
})

local ShopInfoGroup = Tabs.Shop:AddRightGroupbox("Shop", "banknote")

local CashLabel = ShopInfoGroup:AddLabel(field("Cash", "0", GREEN), true)
local NextWeaponLabel = ShopInfoGroup:AddLabel(field("Next weapon", "None", BLUE), true)
local OwnedLabel = ShopInfoGroup:AddLabel(field("Owned weapons", "0", GREY), true)

ShopInfoGroup:AddButton({
    Text = "Refresh Shop State",
    Func = function()
        requestShop("state")
    end,
})

local QuestGroup = Tabs.Quests:AddLeftGroupbox("Auto Claim Quests", "scroll-text")

QuestGroup:AddToggle("AutoClaimQuests", {
    Text = "Auto Claim Quests",
    Default = false,
})

QuestGroup:AddSlider("QuestDelay", {
    Text = "Loop Delay",
    Default = 3,
    Min = 1,
    Max = 60,
    Rounding = 1,
})

local QuestInfoGroup = Tabs.Quests:AddRightGroupbox("Quests", "list-checks")

local ClaimedLabel = QuestInfoGroup:AddLabel(field("Claimed this session", "0", GREEN), true)
local QuestLabels = {}

for slot = 1, 5 do
    QuestLabels[slot] = QuestInfoGroup:AddLabel(field("Quest " .. slot, "Empty", GREY), true)
end

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
    restoreAnchor()
    print("Slap to Survive unloaded")
end)

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("OuroborosHub")
ThemeManager:SaveDefault("Mint")

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("OuroborosHub/SlapToSurvive")
SaveManager:BuildConfigSection(Tabs.Settings)

ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()

SaveManager:LoadAutoloadConfig()

requestShop("state")

task.spawn(function()
    while not Library.Unloaded do
        if isOn("KillAura") and isOn("AuraTeleport") and isAlive() and validMonster(lockedMonster) then
            local root = getRoot()
            local character = LocalPlayer.Character
            local part = lockedMonster:FindFirstChild("HumanoidRootPart") or lockedMonster.PrimaryPart
            if root and character and part then
                setAntiFling(isOn("AuraAntiKnockback"))
                character:PivotTo(farmCFrame(part))
                clearFarmVelocity()
            end
        else
            setAntiFling(false)
        end
        task.wait(0.03)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if isOn("KillAura") and Swing and isAlive() then
            setFarmNoclip(isOn("AuraNoclip"))
            if isOn("AuraEquipBest") then
                equipBestWeapon()
            end
            local root = getRoot()
            local tool = getEquippedTool()
            local def = tool and WeaponConfig.DefOf(tool)
            if root and def then
                if not auraAnchor then
                    auraAnchor = root.CFrame
                end
                if not isOn("AuraTargetLock") or not validMonster(lockedMonster) then
                    lockedMonster = nearestMonster(root.Position, getNumber("AuraRange", 250))
                end
                local model = lockedMonster
                local part = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
                if part then
                    if isOn("AuraTeleport") then
                        setAntiFling(isOn("AuraAntiKnockback"))
                        local character = LocalPlayer.Character
                        if character then
                            character:PivotTo(farmCFrame(part))
                        end
                        clearFarmVelocity()
                    end
                    if def.behavior == "Mine" and PlaceMine then
                        pcall(function()
                            PlaceMine:FireServer(part.Position)
                        end)
                    else
                        local direction = nil
                        if def.behavior == "RayBlast" then
                            local handle = tool:FindFirstChild("Handle")
                            local origin = handle and handle.Position or root.Position
                            local delta = part.Position - origin
                            direction = delta.Magnitude > 0.5 and delta.Unit or nil
                        end
                        local burst = math.max(1, math.floor(getNumber("AuraSwingBurst", 1)))
                        for index = 1, burst do
                            pcall(function()
                                Swing:FireServer(0, direction)
                            end)
                            if index < burst then
                                task.wait(0.005)
                            end
                        end
                    end
                elseif isOn("AuraReturn") and auraAnchor and (root.Position - auraAnchor.Position).Magnitude > 5 then
                    root.CFrame = auraAnchor
                end
            end
        else
            setFarmNoclip(false)
            setAntiFling(false)
        end
        task.wait(getNumber("AuraDelay", 0.03))
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if isOn("AutoBuyWeapons") and Shop then
            local state = requestShop("state")
            if state then
                local key = ShopConfig.NextBuyable(shopState.owned)
                local entry = key and ShopConfig.Weapons[key]
                local price = entry and entry.price or 0
                if key and price > 0 and price <= shopState.cash then
                    local result = requestShop("buy", key)
                    if result and result.bought then
                        Library:Notify("Bought " .. (entry.displayName or key))
                        if isOn("AutoEquipBought") then
                            equipBestWeapon()
                        end
                    end
                end
            end
        end
        task.wait(getNumber("BuyDelay", 2))
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Quest then
            local ok, state = pcall(function()
                return Quest:InvokeServer("state")
            end)
            if ok and type(state) == "table" and type(state.quests) == "table" then
                questState = state.quests
                if isOn("AutoClaimQuests") then
                    for _, quest in questState do
                        if quest.complete and not quest.claimed and quest.id then
                            local claimed = pcall(function()
                                return Quest:InvokeServer("claim", quest.id)
                            end)
                            if claimed then
                                questsClaimed += 1
                                Library:Notify("Claimed quest: " .. tostring(quest.name))
                            end
                        end
                    end
                end
            end
        end
        task.wait(getNumber("QuestDelay", 3))
    end
end)

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

        local tool = getEquippedTool()
        local def = tool and WeaponConfig.DefOf(tool)
        WeaponLabel:SetText(field("Equipped", def and (def.displayName or tool.Name) or "None", BLUE))
        WeaponStatsLabel:SetText(
            field("Damage", def and string.format("%d (range %d)", def.damage or 0, def.range or 0) or "0", ORANGE)
        )

        local monsters = workspace:FindFirstChild("Monsters")
        local alive = 0
        if monsters then
            for _, model in monsters:GetChildren() do
                local humanoid = model:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    alive += 1
                end
            end
        end
        MonsterLabel:SetText(field("Monsters alive", tostring(alive), GREY))

        CashLabel:SetText(field("Cash", string.format("%d", math.floor(shopState.cash)), GREEN))

        local nextKey = ShopConfig.NextBuyable(shopState.owned)
        local nextEntry = nextKey and ShopConfig.Weapons[nextKey]
        NextWeaponLabel:SetText(
            field(
                "Next weapon",
                nextEntry and string.format("%s (%d)", nextEntry.displayName or nextKey, nextEntry.price or 0) or "None",
                BLUE
            )
        )

        local ownedCount = 0
        for _ in shopState.owned do
            ownedCount += 1
        end
        OwnedLabel:SetText(field("Owned weapons", tostring(ownedCount), GREY))

        ClaimedLabel:SetText(field("Claimed this session", tostring(questsClaimed), GREEN))

        for slot = 1, 5 do
            local quest = questState[slot]
            if quest then
                local color = quest.claimed and GREY or (quest.complete and GREEN or ORANGE)
                QuestLabels[slot]:SetText(
                    field(
                        tostring(quest.name),
                        string.format("%d/%d", math.floor(quest.progress or 0), math.floor(quest.target or 0)),
                        color
                    )
                )
            else
                QuestLabels[slot]:SetText(field("Quest " .. slot, "Empty", GREY))
            end
        end
    end
end)

Library:Notify("Slap to Survive loaded")
