local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
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
    return {
        GameModule = require(ReplicatedStorage.GameModule),
        Warp = require(ReplicatedStorage.Modules.Core.Warp),
        BuildingsUtility = require(ReplicatedStorage.Modules.Features.Buildings.Utility),
        SharedPlacementModule = require(ReplicatedStorage.Modules.Gameplay.PlacementModule.SharedPlacementModule),
    }
end)

local GameModule = Modules.GameModule
local Warp = Modules.Warp
local BuildingsUtility = Modules.BuildingsUtility
local SharedPlacementModule = Modules.SharedPlacementModule

local Net = asGameScript(function()
    return {
        PlaceBuilding = Warp.Client("PlaceBuilding"),
        ClearPlot = Warp.Client("ClearPlot"),
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

local MUTATION_ORDER = { "Normal", "Shiny", "Galaxy" }

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
    Steal = Window:AddTab("Steal (Beta)", "copy"),
    Bases = Window:AddTab("Saved Bases", "save"),
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

local SCRIPT_FAQ = {
    "What happened to all the features",
    "Some are detected by anticheat, due to this being keyless i can't bother maintaining it.",
    "How is their anticheat",
    "Sucks, it's easily bypassable (developers i own u)",
    "Will u work on this again",
    "Meh ill think abt it i got other games to take care of",
}

local function AddScriptFaq(Tab)
    local ScriptFaqGroup = Tab:AddLeftGroupbox("Script FAQ", "circle-help")
    for _, text in SCRIPT_FAQ do
        ScriptFaqGroup:AddLabel("<font color=\"rgb(90,220,120)\">" .. text .. "</font>", true)
    end
end

for _, Tab in Tabs do
    AddDiscordButton(Tab)
    AddScriptFaq(Tab)
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

local LayoutGroup = Tabs.Bases:AddLeftGroupbox("Layouts")

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

local LayoutOptions = Tabs.Bases:AddRightGroupbox("Build Layout")

LayoutOptions:AddToggle("LayoutClearFirst", { Text = "Clear My Plot First", Default = true })
LayoutOptions:AddToggle("LayoutSubstitute", { Text = "Use Any Owned Variant If Missing", Default = true })
LayoutOptions:AddSlider("LayoutDelay", {
    Text = "Place Delay",
    Default = 0.2,
    Min = 0.05,
    Max = 3,
    Rounding = 2,
    Suffix = "s",
})
local LayoutStatus = LayoutOptions:AddLabel("Idle", true)

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

LayoutOptions:AddButton({
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

LayoutOptions:AddButton({
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

pcall(refreshLayouts)

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
