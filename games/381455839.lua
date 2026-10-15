local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local GAME_NAME = "Clean Your Keycaps"
local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"
local RSCRIPTS_LINK = "https://rscripts.net/@Ouroboros"

local repo = "https://raw.githubusercontent.com/joustingmatch/ObsidianUltra/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Toggles = Library.Toggles
local Options = Library.Options

local BridgeNet2 = require(ReplicatedStorage.Packages.BridgeNet2)
local KeycapConfig = require(ReplicatedStorage.Shared.Schematics.KeycapConfig)
local CleaningConfig = require(ReplicatedStorage.Shared.Schematics.CleaningConfig)
local CarryConfig = require(ReplicatedStorage.Shared.Schematics.CarryConfig)
local PlacementConfig = require(ReplicatedStorage.Shared.Schematics.PlacementConfig)
local IncomeConfig = require(ReplicatedStorage.Shared.Schematics.IncomeConfig)
local SoapConfig = require(ReplicatedStorage.Shared.Schematics.SoapConfig)
local SpongeConfig = require(ReplicatedStorage.Shared.Schematics.SpongeConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Schematics.UpgradeConfig)
local RebirthConfig = require(ReplicatedStorage.Shared.Schematics.RebirthConfig)
local WorkerConfig = require(ReplicatedStorage.Shared.Schematics.WorkerConfig)

local CleanSessionBridge = BridgeNet2.ReferenceBridge("CleanSession")
local SoapRollBridge = BridgeNet2.ReferenceBridge("SoapRoll")
local SoapDunkBridge = BridgeNet2.ReferenceBridge(SoapConfig.Dunk.Bridge)
local UpgradeBridge = BridgeNet2.ReferenceBridge(UpgradeConfig.Bridge)
local RebirthBridge = BridgeNet2.ReferenceBridge(RebirthConfig.Bridge)
local WorkerBridge = BridgeNet2.ReferenceBridge(WorkerConfig.Bridge)
local SpongeBridge = BridgeNet2.ReferenceBridge("SpongeShop")

local PlacedTag = KeycapConfig.PlacedTag
local CleanableTag = KeycapConfig.CleanableTag
local CleanerAttr = CleaningConfig.Scrub.ClaimAttr
local CarryToolName = CarryConfig.ToolName
local OccupiedAttr = PlacementConfig.OccupiedAttr
local SoapBoothFolder = SoapConfig.Booth.FolderName
local EquippedSpongeAttr = SpongeConfig.EquippedAttr

local UpgradeIds = { "Speed", "Radius", "Soap", "Worker" }

local spongeIndexById = {}
for i, v in ipairs(SpongeConfig.Sponges) do
    spongeIndexById[v.Id] = i
end

local soapNames = {}
for _, soap in ipairs(SoapConfig.Soaps) do
    table.insert(soapNames, soap.DisplayName)
end

local function getPlot()
    local plotName = LocalPlayer:GetAttribute("Plot")
    if plotName then
        local plot = workspace.Map.Plots:FindFirstChild(plotName)
        if plot then
            return plot
        end
    end
    for _, plot in ipairs(workspace.Map.Plots:GetChildren()) do
        if plot:GetAttribute("Owner") == LocalPlayer.UserId then
            return plot
        end
    end
    return nil
end

local lastRolledSoapTier
local soapRollConnection = SoapRollBridge:Connect(function(data)
    local plot = getPlot()
    if plot
        and type(data) == "table"
        and typeof(data.Booth) == "Instance"
        and data.Booth:IsDescendantOf(plot)
        and type(data.Tier) == "number"
    then
        lastRolledSoapTier = data.Tier
    end
end)

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

Tabs.Clean = Tabs.Main:AddSubTab("Cleaning", "droplet")
Tabs.Economy = Tabs.Main:AddSubTab("Economy", "coins")
Tabs.Shop = Tabs.Main:AddSubTab("Shop", "shopping-cart")

local function copyLink(link, notice)
    if setclipboard then
        setclipboard(link)
    elseif toclipboard then
        toclipboard(link)
    end
    Library:Notify(notice)
end

local function copyDiscord()
    copyLink(DISCORD_INVITE, "Copied Discord invite to clipboard")
end

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

for _, Tab in { Tabs.Info, Tabs.Clean, Tabs.Economy, Tabs.Shop, Tabs.Settings } do
    AddDiscordButton(Tab)
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
        copyLink(joinScript, "Copied join script to clipboard")
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
FeaturesGroup:AddLabel(colored("Keycap Automation", BLUE), true)
FeaturesGroup:AddLabel(colored("Auto Roll Soap", BLUE), true)
FeaturesGroup:AddLabel(colored("Auto Shop", ORANGE), true)
FeaturesGroup:AddLabel(colored("Auto Rebirth", GREEN), true)
FeaturesGroup:AddLabel(colored("Auto Workers", GREY), true)

local SocialsGroup = Tabs.Info:AddRightGroupbox("Socials", "link")
SocialsGroup:AddButton({
    Text = "Discord",
    Func = copyDiscord,
})
SocialsGroup:AddButton({
    Text = "Rscripts",
    Func = function()
        copyLink(RSCRIPTS_LINK, "Copied Rscripts profile to clipboard")
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

local CleanGroup = Tabs.Clean:AddLeftGroupbox("Keycaps", "eraser")
CleanGroup:AddToggle("AutoWash", {
    Text = "Auto Wash Keycaps",
    Default = false,
})
CleanGroup:AddSlider("WashRate", {
    Text = "Wash Speed",
    Default = 8,
    Min = 1,
    Max = CleaningConfig.Scrub.MaxTicksPerSecond,
    Rounding = 0,
    Suffix = "/s",
})
CleanGroup:AddToggle("AutoPlace", {
    Text = "Auto Place Keycaps",
    Default = false,
})

local SoapGroup = Tabs.Clean:AddRightGroupbox("Soap", "spray-can")
SoapGroup:AddToggle("AutoRoll", {
    Text = "Auto Roll Soap",
    Default = false,
})
SoapGroup:AddSlider("RollDelay", {
    Text = "Roll Delay",
    Default = 1,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Suffix = "s",
})
SoapGroup:AddToggle("StopOnSoap", {
    Text = "Stop on Selected Soap",
    Default = false,
})
SoapGroup:AddDropdown("SoapTargets", {
    Values = soapNames,
    Default = {},
    Multi = true,
    Text = "Selected Soaps",
})
SoapGroup:AddToggle("AutoDunk", {
    Text = "Auto Dunk Sponge",
    Default = false,
})
SoapGroup:AddSlider("DunkDelay", {
    Text = "Dunk Check Delay",
    Default = 1,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Suffix = "s",
})

local MoneyGroup = Tabs.Economy:AddLeftGroupbox("Money", "coins")
MoneyGroup:AddToggle("AutoCollect", {
    Text = "Auto Collect Money from Keycaps",
    Default = false,
})
MoneyGroup:AddSlider("CollectRate", {
    Text = "Collect Speed",
    Default = 10,
    Min = 1,
    Max = IncomeConfig.CheckRate,
    Rounding = 0,
    Suffix = "/s",
})

local WorkerGroup = Tabs.Economy:AddRightGroupbox("Workers", "users")
WorkerGroup:AddToggle("AutoWorkers", {
    Text = "Auto Hire Workers",
    Default = false,
})

local RebirthGroup = Tabs.Economy:AddLeftGroupbox("Rebirth", "rotate-ccw")
RebirthGroup:AddToggle("AutoRebirth", {
    Text = "Auto Rebirth",
    Default = false,
})

local UpgradeGroup = Tabs.Shop:AddLeftGroupbox("Upgrades", "trending-up")
UpgradeGroup:AddToggle("AutoUpgrades", {
    Text = "Auto Buy Upgrades",
    Default = false,
})
UpgradeGroup:AddDropdown("UpgradeChoices", {
    Values = UpgradeIds,
    Default = { Speed = true },
    Multi = true,
    Text = "Upgrades",
})

local SpongeGroup = Tabs.Shop:AddRightGroupbox("Sponges", "shopping-bag")
SpongeGroup:AddToggle("AutoSponges", {
    Text = "Auto Buy Sponges",
    Default = false,
})

local function money()
    return LocalPlayer:GetAttribute("Money") or 0
end

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoWash.Value then
            local plot = getPlot()
            local character = LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local carried = character and character:FindFirstChild(CarryToolName)
                or LocalPlayer.Backpack:FindFirstChild(CarryToolName)
            if plot and root and not carried then
                for _, cap in ipairs(CollectionService:GetTagged(CleanableTag)) do
                    if cap:IsA("BasePart") and cap:IsDescendantOf(plot) then
                        if cap:GetAttribute(CleanerAttr) ~= LocalPlayer.UserId then
                            root.CFrame = cap.CFrame * CFrame.new(0, 0, 4)
                            task.wait(0.2)
                            pcall(function()
                                CleanSessionBridge:Fire({ Action = "Begin", Cap = cap })
                            end)
                        else
                            pcall(function()
                                CleanSessionBridge:Fire({ Action = "Scrub" })
                            end)
                        end
                        break
                    end
                end
            end
            task.wait(1 / math.max(Options.WashRate.Value, 1))
        else
            task.wait(0.2)
        end
    end
end)

local function getPlacementSpot(plot)
    local placement = plot:FindFirstChild("Placement")
    local references = placement and placement:FindFirstChild("PositionReference")
    local target
    local targetOrder = math.huge
    if references then
        for _, tier in ipairs(references:GetChildren()) do
            if tier:GetAttribute("Unlocked") then
                for _, spot in ipairs(tier:GetChildren()) do
                    local order = spot:GetAttribute("FillOrder") or math.huge
                    if spot:IsA("BasePart") and not spot:GetAttribute(OccupiedAttr) and order < targetOrder then
                        target = spot
                        targetOrder = order
                    end
                end
            end
        end
    end
    return target
end

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoPlace.Value then
            local plot = getPlot()
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local tool = character and character:FindFirstChild(CarryToolName)
                or LocalPlayer.Backpack:FindFirstChild(CarryToolName)
            local spot = plot and getPlacementSpot(plot)
            if tool and humanoid and root and spot then
                if tool.Parent ~= character then
                    humanoid:EquipTool(tool)
                    task.wait(0.1)
                end
                root.CFrame = spot.CFrame * CFrame.new(0, 3, 3)
                task.wait(0.2)
                pcall(function()
                    tool:Activate()
                end)
                task.wait(PlacementConfig.PlaceDebounce)
            end
        end
        task.wait(0.2)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoCollect.Value then
            local plot = getPlot()
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if plot and humanoid and root then
                local footOffset = humanoid.HipHeight + root.Size.Y * 0.5
                for _, cap in ipairs(CollectionService:GetTagged(PlacedTag)) do
                    if not Toggles.AutoCollect.Value or Library.Unloaded then
                        break
                    end
                    if cap:IsA("BasePart") and cap:IsDescendantOf(plot) then
                        root.CFrame = CFrame.new(cap.Position + Vector3.new(0, footOffset, 0)) * root.CFrame.Rotation
                        task.wait(1 / math.max(Options.CollectRate.Value, 1))
                    end
                end
                root.CFrame += Vector3.new(0, IncomeConfig.FootBoxSize.Y + 1, 0)
                task.wait(1 / IncomeConfig.CheckRate)
            end
        else
            task.wait(0.2)
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoRoll.Value then
            local plot = getPlot()
            local booth = plot and plot:FindFirstChild("Booths") and plot.Booths:FindFirstChild(SoapBoothFolder)
            local activeSoap = SoapConfig.Soaps[lastRolledSoapTier or 0]
            local selected = activeSoap and Options.SoapTargets.Value[activeSoap.DisplayName]
            if booth and not (Toggles.StopOnSoap.Value and selected) then
                local button = booth:FindFirstChild(SoapConfig.Booth.ButtonName)
                local press = button and button:FindFirstChild(SoapConfig.Booth.PressName)
                local character = LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if press and root and firetouchinterest then
                    pcall(function()
                        firetouchinterest(root, press, 0)
                        task.wait(0.05)
                        firetouchinterest(root, press, 1)
                    end)
                end
            elseif Toggles.StopOnSoap.Value and selected then
                Toggles.AutoRoll:SetValue(false)
            end
            task.wait(Options.RollDelay.Value)
        else
            task.wait(0.2)
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoDunk.Value then
            local plot = getPlot()
            local booth = plot and plot:FindFirstChild("Booths") and plot.Booths:FindFirstChild(SoapBoothFolder)
            local charges = LocalPlayer:GetAttribute(SoapConfig.Dunk.ChargesAttr) or 0
            local loaded = LocalPlayer:GetAttribute(SoapConfig.Dunk.LoadedAttr) or 0
            local remaining = booth and booth:GetAttribute(SoapConfig.Dunk.RemainAttr)
            local available = booth
                and not booth:GetAttribute(SoapConfig.Dunk.EmptyAttr)
                and type(remaining) == "number"
                and remaining > 0
            if (charges <= 0 or loaded <= 0) and available then
                local reference = booth:FindFirstChild(SoapConfig.Booth.ReferenceName)
                local proximity = reference and reference:FindFirstChild(SoapConfig.Dunk.PromptPartName)
                local character = LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if proximity and root then
                    root.CFrame = proximity.CFrame * CFrame.new(0, 0, 4)
                    task.wait(0.2)
                end
                pcall(function()
                    SoapDunkBridge:Fire({ Booth = booth })
                end)
            end
            task.wait(Options.DunkDelay.Value)
        else
            task.wait(0.2)
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoWorkers.Value then
            local workers = LocalPlayer:GetAttribute(WorkerConfig.WorkersAttr) or 0
            local maxWorkers = LocalPlayer:GetAttribute(WorkerConfig.MaxWorkersAttr) or 0
            if maxWorkers > workers then
                local cost = WorkerConfig.Prices[workers + 1] or WorkerConfig.BaseCost * WorkerConfig.CostGrowth ^ workers
                if money() >= cost then
                    pcall(function()
                        WorkerBridge:Fire({ Action = "Buy" })
                    end)
                end
            end
        end
        task.wait(1)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoRebirth.Value then
            local rebirths = LocalPlayer:GetAttribute(RebirthConfig.RebirthsAttr) or 0
            if rebirths < RebirthConfig.MaxRebirths then
                local have = LocalPlayer:GetAttribute(RebirthConfig.MoneyAttr) or money()
                local need = RebirthConfig.Requirements[rebirths + 1] or math.huge
                if have >= need then
                    pcall(function()
                        RebirthBridge:Fire({})
                    end)
                end
            end
        end
        task.wait(1)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoUpgrades.Value then
            for _, id in ipairs(UpgradeIds) do
                if Options.UpgradeChoices.Value[id] then
                    local cfg = UpgradeConfig.Upgrades[id]
                    if cfg then
                        local level = LocalPlayer:GetAttribute(cfg.Attr) or 0
                        if level < cfg.MaxLevel then
                            local cost = cfg.Prices and cfg.Prices[level + 1] or cfg.BaseCost * cfg.CostGrowth ^ level
                            if money() >= cost then
                                pcall(function()
                                    UpgradeBridge:Fire({ Action = "Buy", Id = id })
                                end)
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)

local lastSpongeBuy = {}
task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoSponges.Value then
            local equipped = LocalPlayer:GetAttribute(EquippedSpongeAttr)
            local equippedIndex = spongeIndexById[equipped] or 1
            local rebirths = LocalPlayer:GetAttribute(RebirthConfig.RebirthsAttr) or 0
            local target
            for i = #SpongeConfig.Sponges, equippedIndex + 1, -1 do
                local sponge = SpongeConfig.Sponges[i]
                local affordable = not sponge.RobuxOnly
                    and (sponge.CashPrice or 0) > 0
                    and money() >= sponge.CashPrice
                    and (sponge.MinRebirth or 0) <= rebirths
                if affordable then
                    target = sponge
                    break
                end
            end
            if target and (os.clock() - (lastSpongeBuy[target.Id] or 0)) > 3 then
                lastSpongeBuy[target.Id] = os.clock()
                pcall(function()
                    SpongeBridge:Fire({ Action = "Buy", Id = target.Id })
                end)
                task.wait(0.3)
                pcall(function()
                    SpongeBridge:Fire({ Action = "Equip", Id = target.Id })
                end)
            end
        end
        task.wait(1)
    end
end)

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "menu")

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

MenuGroup:AddButton("Unload", function()
    Library:Unload()
end)

Tabs.Settings:AddLeftGroupbox("Keybind"):AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Menu keybind",
})

Library.ToggleKeybind = Options.MenuKeybind

Library:OnUnload(function()
    soapRollConnection:Disconnect()
    antiAfkBeganConnection:Disconnect()
    antiAfkChangedConnection:Disconnect()
    print("Unloaded!")
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

ThemeManager:SetFolder("OuroborosHub")
SaveManager:SetFolder("OuroborosHub/clean-your-keycaps")

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SaveDefault("Monochrome")
ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()

SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
