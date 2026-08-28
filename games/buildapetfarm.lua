local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

if getgenv then
    getgenv().gethui = function()
        return LocalPlayer:WaitForChild("PlayerGui")
    end
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local State = require(Shared:WaitForChild("State"))

local SEED_ID_ATTR = State.Seed.Id
local TOOL_GUID_ATTR = State.Tool.Guid
local GRID_PURCHASABLE_ATTR = State.Grid.Purchasable
local TREE_GROUND_PILE_ATTR = State.TreeClicker.GroundPile
local TREE_LOCAL_VISUAL_ATTR = State.TreeClicker.LocalVisual
local TREE_SLOT_INDEX_ATTR = State.TreeClicker.SlotIndex
local FOOD_ID_ATTR = State.Food.Id
local FEED_CLASS_ATTR = State.Feed.Class

local function getRemote(name)
    return Remotes:FindFirstChild(name)
end

local AutoRollRemote = getRemote("AutoRollRequest")
local PlaceFeedMachine = getRemote("PlaceFeedMachine")
local TreeClicker = getRemote("TreeClickerRequest")
local RollLuckUpgrade = getRemote("RollLuckUpgradeRequest")
local RollDropAreaUpgrade = getRemote("RollDropAreaUpgradeRequest")
local RebirthRemote = getRemote("RebirthRequest")
local GearPurchase = getRemote("GearShopPurchaseRequest")
local CosmeticPurchase = getRemote("CosmeticShopPurchaseRequest")
local CrateRollPurchaseRequest = getRemote("CrateRollPurchaseRequest")
local CrateRollEffect = getRemote("CrateRollEffect")
local PromptInteract = getRemote("PromptInteract")

local RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythical", "Secret" }
local GEAR_IDS = { "JamBarrel", "UpgradedJamBarrel", "GoldenJamBarrel" }
local COSMETIC_IDS = { "Path", "GrassPath", "TikiTorch", "Arch", "Fountain", "Golden Fountain" }
local SEED_IDS = {
    "PineappleSeed", "PumpkinSeed", "PurpleShroomSeed", "WatermelonSeed", "GlowshroomSeed",
    "CornSeed", "CabbageSeed", "MushroomSeed", "PotatoSeed",
    "AppleTreeSeed", "CherryTreeSeed", "OrangeTreeSeed", "BananaTreeSeed", "FigTreeSeed",
    "PlumTreeSeed", "GoldenAppleTreeSeed", "CactusSeed", "BloodOrangeTreeSeed",
    "DurianTreeSeed", "DragonfruitTreeSeed",
}
local UPGRADE_NAMES = { "Roll Luck", "Roll Drop Area" }

local nonceCounter = 0
local function nextNonce()
    nonceCounter = nonceCounter + 1
    return nonceCounter
end

local function selectedSet(value)
    local set = {}
    if type(value) == "table" then
        for name, state in pairs(value) do
            if state then
                set[name] = true
            end
        end
    end
    return set
end

local cachedPlot = nil
local function getPlot()
    if cachedPlot and cachedPlot.Parent then
        return cachedPlot
    end
    cachedPlot = nil
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        return nil
    end
    for _, plot in ipairs(plots:GetChildren()) do
        if plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            cachedPlot = plot
            return plot
        end
    end
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil
    end
    local best, bestDist
    for _, plot in ipairs(plots:GetChildren()) do
        local part = plot:FindFirstChildWhichIsA("BasePart", true)
        if part then
            local dist = (part.Position - root.Position).Magnitude
            if not bestDist or dist < bestDist then
                bestDist = dist
                best = plot
            end
        end
    end
    cachedPlot = best
    return best
end

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

pcall(function()
    Library.ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end)

local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Toggles = Library.Toggles
local Options = Library.Options

local DISCORD_LINK = "https://discord.gg/ehKVq7pf7v"

local function copyDiscord()
    if setclipboard then
        setclipboard(DISCORD_LINK)
    elseif toclipboard then
        toclipboard(DISCORD_LINK)
    end
    Library:Notify("Copied Discord invite to clipboard")
end

local selectedRarities = {}
local selectedUpgrades = {}
local selectedSeeds = {}
local selectedGears = {}
local selectedCosmetics = {}
local petMoneyThresholds = {}
local movementBusy = false

local function petKey(pet)
    return tostring(pet:GetAttribute("PetID") or pet:GetAttribute("PetIndex") or pet:GetDebugId())
end

local function beginMovement()
    if movementBusy then
        return false
    end
    movementBusy = true
    return true
end

local function endMovement()
    movementBusy = false
end

local function selectedRarityArray()
    local array = {}
    for _, rarity in ipairs(RARITIES) do
        if selectedRarities[rarity] then
            array[#array + 1] = rarity
        end
    end
    if #array == 0 then
        for _, rarity in ipairs(RARITIES) do
            array[#array + 1] = rarity
        end
    end
    return array
end

local function sendAutoRoll(action)
    if not AutoRollRemote then
        return
    end
    pcall(function()
        AutoRollRemote:FireServer({
            action = action,
            autoPurchase = Toggles.RollAutoPurchase.Value == true,
            selectedRarities = selectedRarityArray(),
        })
    end)
end

local purchasedOfferIds = {}

if CrateRollEffect and CrateRollPurchaseRequest then
    CrateRollEffect.OnClientEvent:Connect(function(data)
        if type(data) ~= "table" then return end
        if not Toggles.AutoRoll or not Toggles.AutoRoll.Value then return end
        
        if data.action == "showOffers" and type(data.offers) == "table" then
            if data.ownerUserId ~= LocalPlayer.UserId then return end
            
            for _, offer in ipairs(data.offers) do
                if type(offer) == "table" and offer.offerId then
                    local rarity = offer.rarity
                    local shouldPurchase = false
                    
                    if Toggles.RollAutoPurchase and Toggles.RollAutoPurchase.Value then
                        if next(selectedRarities) == nil or selectedRarities[rarity] then
                            shouldPurchase = true
                        end
                    end
                    
                    if shouldPurchase then
                        if not purchasedOfferIds[offer.offerId] then
                            purchasedOfferIds[offer.offerId] = true
                            pcall(function()
                                CrateRollPurchaseRequest:FireServer(offer.offerId)
                            end)
                            task.delay(10, function()
                                purchasedOfferIds[offer.offerId] = nil
                            end)
                        end
                    end
                end
            end
        end
    end)
end

local function refreshAutoRoll()
    if Toggles.AutoRoll.Value then
        sendAutoRoll("settings")
    end
end

local function firePromptsByTheme(theme, filter, tpToPrompts)
    local plot = getPlot()
    if not plot then
        return
    end
    
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local oldCFrame = hrp and hrp.CFrame
    local didTeleport = false

    local prompts = {}
    for _, descendant in ipairs(plot:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") and descendant.Name == "__LocalPrompt_" .. theme then
            table.insert(prompts, descendant)
        end
    end

    for _, descendant in ipairs(prompts) do
        if Library.Unloaded then
            break
        end
        if descendant:IsDescendantOf(workspace) and descendant.Parent then
            local part = descendant.Parent
            if part:IsA("Attachment") then
                part = part.Parent
            end
            if not filter or (part and filter(part, descendant)) then
                if tpToPrompts and hrp and part and part:IsA("BasePart") then
                    local dist = (hrp.Position - part.Position).Magnitude
                    if dist > descendant.MaxActivationDistance then
                        hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)
                        hrp.AssemblyLinearVelocity = Vector3.new()
                        task.wait(0.1)
                        didTeleport = true
                    end
                end
                
                if descendant:IsDescendantOf(workspace) then
                    pcall(fireproximityprompt, descendant)
                    task.wait(0.08)
                end
            end
        end
    end

    if didTeleport and hrp and oldCFrame then
        hrp.CFrame = oldCFrame
        hrp.AssemblyLinearVelocity = Vector3.new()
        task.wait(0.1)
    end
end

local function seedTools(includeAll)
    local tools = {}
    local containers = { LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }
    for _, container in ipairs(containers) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool") then
                    local seedId = item:GetAttribute(SEED_ID_ATTR)
                    if type(seedId) == "string" and seedId ~= "" then
                        if includeAll or selectedSeeds[seedId] then
                            tools[#tools + 1] = item
                        end
                    end
                end
            end
        end
    end
    return tools
end

local function unlockedGridParts(plot)
    local parts = {}
    for _, folderName in ipairs({ "StarterArea", "GridAreas" }) do
        local folder = plot:FindFirstChild(folderName)
        if folder then
            for _, part in ipairs(folder:GetChildren()) do
                if part:IsA("BasePart") and part:GetAttribute("GridUnlocked") == true then
                    parts[#parts + 1] = part
                end
            end
        end
    end
    return parts
end

local function plantCFrames(plot, parts)
    local positions = {}
    for _, model in ipairs(plot:GetChildren()) do
        if model:IsA("Model") and model:GetAttribute(FEED_CLASS_ATTR) ~= nil then
            local ok, cframe = pcall(function()
                return (model:GetBoundingBox())
            end)
            if ok and cframe then
                positions[#positions + 1] = cframe.Position
            end
        end
    end
    local cframes = {}
    for _, part in ipairs(parts) do
        for _, x in ipairs({ -5, 0, 5 }) do
            for _, z in ipairs({ -5, 0, 5 }) do
                local cframe = part.CFrame * CFrame.new(x, part.Size.Y / 2 + 1.5, z)
                local available = true
                for _, position in ipairs(positions) do
                    if Vector2.new(cframe.Position.X - position.X, cframe.Position.Z - position.Z).Magnitude < 4.5 then
                        available = false
                        break
                    end
                end
                if available then
                    cframes[#cframes + 1] = cframe
                end
            end
        end
    end
    return cframes
end

local function doPlant(includeAll)
    if not PlaceFeedMachine then
        return
    end
    local plot = getPlot()
    if not plot then
        return
    end
    local tools = seedTools(includeAll)
    if #tools == 0 then
        return
    end
    local parts = unlockedGridParts(plot)
    if #parts == 0 then
        return
    end
    local cframes = plantCFrames(plot, parts)
    if #cframes == 0 then
        return
    end
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
    if not humanoid then
        return
    end
    local cframeIndex = 1
    for _, tool in ipairs(tools) do
        if Library.Unloaded or not (Toggles.AutoPlant.Value or Toggles.AutoPlantAll.Value) then
            return
        end
        local guid = tool:GetAttribute(TOOL_GUID_ATTR)
        if type(guid) == "string" and guid ~= "" then
            pcall(function()
                humanoid:EquipTool(tool)
            end)
            task.wait(0.1)
            while tool.Parent and cframes[cframeIndex] do
                if Library.Unloaded or not (Toggles.AutoPlant.Value or Toggles.AutoPlantAll.Value) then
                    return
                end
                local cframe = cframes[cframeIndex]
                cframeIndex = cframeIndex + 1
                pcall(function()
                    PlaceFeedMachine:FireServer(nextNonce(), cframe, guid)
                end)
                task.wait(0.3)
            end
            pcall(function()
                if tool.Parent == character then
                    humanoid:UnequipTools()
                end
            end)
            task.wait(Options.PlantDelay.Value or 0.5)
        end
    end
end

local function doCollectPetMoney()
    local plot = getPlot()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not plot or not root then
        return
    end
    if not beginMovement() then
        return
    end
    local oldCFrame = root.CFrame
    local moved = false
    for _, pet in ipairs(plot:GetChildren()) do
        if Library.Unloaded or not Toggles.AutoCollectPetMoney.Value then
            break
        end
        if pet:IsA("Model") and pet:GetAttribute("PetIndex") ~= nil
            and (tonumber(pet:GetAttribute("Money")) or 0) >= (petMoneyThresholds[petKey(pet)] or 1000) then
            root.CFrame = pet:GetPivot() + Vector3.new(0, 2, 0)
            root.AssemblyLinearVelocity = Vector3.new()
            task.wait(0.2)
            moved = true
        end
    end
    if moved and root.Parent then
        root.CFrame = oldCFrame
        root.AssemblyLinearVelocity = Vector3.new()
    end
    endMovement()
end

local function treeModels(plot)
    local trees = {}
    for _, model in ipairs(plot:GetChildren()) do
        if model:IsA("Model") then
            if model:FindFirstChild("LeafShake", true) or string.find(model.Name, "Tree") then
                trees[#trees + 1] = model
            end
        end
    end
    return trees
end

local function doShake()
    if not TreeClicker then
        return
    end
    local plot = getPlot()
    if not plot then
        return
    end
    local shakes = math.floor(tonumber(Options.ShakeCount.Value) or 3)
    for _, tree in ipairs(treeModels(plot)) do
        if Library.Unloaded or not Toggles.AutoShake.Value then
            return
        end
        for _ = 1, shakes do
            if Library.Unloaded or not Toggles.AutoShake.Value then
                return
            end
            pcall(function()
                TreeClicker:FireServer(tree)
            end)
            task.wait(0.05)
        end
    end
end

local function doHarvest()
    local plot = getPlot()
    if not plot or not PromptInteract then
        return
    end
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root and not beginMovement() then
        return
    end
    local oldCFrame = root and root.CFrame
    local moved = false

    local function collect(action, target)
        if root then
            root.CFrame = target.CFrame + Vector3.new(0, 3, 0)
            root.AssemblyLinearVelocity = Vector3.new()
            task.wait(0.1)
            moved = true
        end
        pcall(function()
            PromptInteract:FireServer(action, target, false)
        end)
        task.wait(0.15)
    end

    for _, descendant in ipairs(plot:GetDescendants()) do
        if Library.Unloaded then
            break
        end
        if Toggles.HarvestPatches.Value
            and descendant:IsA("ProximityPrompt")
            and descendant.Name == "__LocalPrompt_PatchHarvest"
            and descendant.Parent
            and descendant.Parent:IsA("Attachment")
            and descendant.Parent.Parent
            and descendant.Parent.Parent:IsA("BasePart") then
            collect("PatchHarvest", descendant.Parent.Parent)
        elseif Toggles.HarvestTreeGround.Value
            and descendant:IsA("BasePart")
            and descendant:GetAttribute(TREE_GROUND_PILE_ATTR) == true
            and descendant:GetAttribute(TREE_LOCAL_VISUAL_ATTR) ~= true
            and descendant:GetAttribute(TREE_SLOT_INDEX_ATTR) ~= nil
            and descendant:GetAttribute(FOOD_ID_ATTR) ~= nil then
            collect("TreeGroundPickup", descendant)
        end
    end

    if moved and root and oldCFrame then
        root.CFrame = oldCFrame
        root.AssemblyLinearVelocity = Vector3.new()
    end
    if root then
        endMovement()
    end
end

local function doFeed()
    firePromptsByTheme("PetFeed")
end

local function doUpgrades()
    for _, name in ipairs(UPGRADE_NAMES) do
        if Library.Unloaded or not Toggles.AutoUpgrade.Value then
            return
        end
        if selectedUpgrades[name] then
            if name == "Roll Luck" and RollLuckUpgrade then
                pcall(function()
                    RollLuckUpgrade:FireServer(nextNonce())
                end)
            elseif name == "Roll Drop Area" and RollDropAreaUpgrade then
                pcall(function()
                    RollDropAreaUpgrade:FireServer(nextNonce())
                end)
            end
            task.wait(0.15)
        end
    end
end

local function doRebirth()
    if RebirthRemote then
        pcall(function()
            RebirthRemote:FireServer(nextNonce())
        end)
    end
end

local function doBuyGears()
    if not GearPurchase then
        return
    end
    for _, id in ipairs(GEAR_IDS) do
        if Library.Unloaded or not Toggles.AutoBuyGears.Value then
            return
        end
        if selectedGears[id] then
            pcall(function()
                GearPurchase:FireServer(nextNonce(), id)
            end)
            task.wait(0.15)
        end
    end
end

local function doBuyCosmetics()
    if not CosmeticPurchase then
        return
    end
    for _, id in ipairs(COSMETIC_IDS) do
        if Library.Unloaded or not Toggles.AutoBuyCosmetics.Value then
            return
        end
        if selectedCosmetics[id] then
            pcall(function()
                CosmeticPurchase:FireServer(nextNonce(), id)
            end)
            task.wait(0.15)
        end
    end
end

local function doExpand()
    local plot = getPlot()
    if not plot or not PromptInteract then
        return
    end
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root and not beginMovement() then
        return
    end
    local oldCFrame = root and root.CFrame
    local moved = false
    for _, part in ipairs(plot:GetDescendants()) do
        if Library.Unloaded or not Toggles.AutoExpand.Value then
            break
        end
        if part:IsA("BasePart") and part:GetAttribute(GRID_PURCHASABLE_ATTR) == true then
            if root then
                root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
                root.AssemblyLinearVelocity = Vector3.new()
                task.wait(0.1)
                moved = true
            end
            pcall(function()
                PromptInteract:FireServer("GridPartUnlock", part, false)
            end)
            task.wait(0.15)
        end
    end
    if moved and root and oldCFrame then
        root.CFrame = oldCFrame
        root.AssemblyLinearVelocity = Vector3.new()
    end
    if root then
        endMovement()
    end
end

local function moveToRollButton()
    local plot = getPlot()
    if not plot then
        return nil
    end

    local prompt
    for _, descendant in ipairs(plot:GetDescendants()) do
        if descendant.Name == "__LocalPrompt_CrateRoll" and descendant:IsA("ProximityPrompt") then
            prompt = descendant
            break
        end
    end

    local button = prompt and prompt.Parent and prompt.Parent.Parent
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root and not beginMovement() then
        return nil
    end
    if button and button:IsA("BasePart") and root then
        if (root.Position - button.Position).Magnitude > 6 then
            root.CFrame = button.CFrame + Vector3.new(0, 3, 0)
            root.AssemblyLinearVelocity = Vector3.new()
            task.wait(0.15)
        end
    end
    if root then
        endMovement()
    end
    return prompt
end

local function doManualAutoRoll()
    local prompt = moveToRollButton()
    if prompt and prompt.Parent then
        pcall(fireproximityprompt, prompt)
    end
end

local Window = Library:CreateWindow({
    Title = "Build a Pet Farm",
    Footer = "Ouroboros Hub",
    Size = UDim2.fromOffset(940, 660),
    ShowCustomCursor = false,
})

Library.ShowCustomCursor = false

local Tabs = {
    Farm = Window:AddTab("Farm", "sprout"),
    Roll = Window:AddTab("Roll", "dices"),
    Shop = Window:AddTab("Shop", "shopping-cart"),
    Settings = Window:AddTab("Settings", "settings"),
}

local function AddDiscordButton(Tab)
    Tab:AddLeftGroupbox("Discord"):AddButton({
        Text = "Join Discord For Dupe",
        Func = copyDiscord,
    })
end

for _, Tab in Tabs do
    AddDiscordButton(Tab)
end

local PlantGroup = Tabs.Farm:AddLeftGroupbox("Auto Plant", "shovel")

PlantGroup:AddToggle("AutoPlant", {
    Text = "Auto Plant",
    Default = false,
})

PlantGroup:AddToggle("AutoPlantAll", {
    Text = "Auto Plant All",
    Default = false,
})

PlantGroup:AddDropdown("PlantSeeds", {
    Text = "Seeds To Plant",
    Values = SEED_IDS,
    Default = {},
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        selectedSeeds = selectedSet(value)
    end,
})

PlantGroup:AddSlider("PlantDelay", {
    Text = "Plant Delay",
    Default = 0.5,
    Min = 0.2,
    Max = 5,
    Rounding = 1,
})

PlantGroup:AddSlider("PlantLoopDelay", {
    Text = "Loop Delay",
    Default = 1,
    Min = 0.5,
    Max = 10,
    Rounding = 1,
})

local ShakeGroup = Tabs.Farm:AddLeftGroupbox("Auto Shake Trees", "wind")

ShakeGroup:AddToggle("AutoShake", {
    Text = "Auto Shake Trees",
    Default = false,
})

ShakeGroup:AddSlider("ShakeCount", {
    Text = "Shakes Per Tree",
    Default = 3,
    Min = 1,
    Max = 20,
    Rounding = 0,
})

ShakeGroup:AddSlider("ShakeDelay", {
    Text = "Loop Delay",
    Default = 0.5,
    Min = 0.2,
    Max = 10,
    Rounding = 1,
})

local HarvestGroup = Tabs.Farm:AddRightGroupbox("Auto Harvest", "hand")

HarvestGroup:AddToggle("HarvestPatches", {
    Text = "Harvest Patches",
    Default = false,
})

HarvestGroup:AddToggle("HarvestTreeGround", {
    Text = "Collect Tree Fruit",
    Default = false,
})

HarvestGroup:AddSlider("HarvestDelay", {
    Text = "Loop Delay",
    Default = 0.5,
    Min = 0.2,
    Max = 10,
    Rounding = 1,
})

local FeedGroup = Tabs.Farm:AddRightGroupbox("Auto Feed", "bone")

FeedGroup:AddToggle("AutoFeed", {
    Text = "Auto Feed Pets",
    Default = false,
})

FeedGroup:AddSlider("FeedDelay", {
    Text = "Loop Delay",
    Default = 0.5,
    Min = 0.2,
    Max = 10,
    Rounding = 1,
})

local PetMoneyGroup = Tabs.Farm:AddRightGroupbox("Pet Money", "coins")

PetMoneyGroup:AddToggle("AutoCollectPetMoney", {
    Text = "Auto Collect Money From Pets",
    Default = false,
})

PetMoneyGroup:AddSlider("PetMoneyDelay", {
    Text = "Loop Delay",
    Default = 2,
    Min = 0.5,
    Max = 15,
    Rounding = 1,
})

local petMoneySliderIds = {}
local petAddedConnection

local function addPetMoneySlider(pet)
    if not pet:IsA("Model") or pet:GetAttribute("PetIndex") == nil then
        return
    end
    local key = petKey(pet)
    if petMoneySliderIds[key] then
        return
    end
    petMoneySliderIds[key] = true
    petMoneyThresholds[key] = petMoneyThresholds[key] or 1000
    local nickname = pet:GetAttribute("PetNickname")
    local name = type(nickname) == "string" and nickname ~= "" and (pet.Name .. " (" .. nickname .. ")") or pet.Name
    PetMoneyGroup:AddSlider("PetMoneyThreshold_" .. key, {
        Text = name .. " - Collect at This Amount",
        Default = petMoneyThresholds[key],
        Min = 0,
        Max = 1000000,
        Rounding = 0,
        Callback = function(value)
            petMoneyThresholds[key] = tonumber(value) or 1000
        end,
    })
end

local petPlot = getPlot()
if petPlot then
    for _, pet in ipairs(petPlot:GetChildren()) do
        addPetMoneySlider(pet)
    end
    petAddedConnection = petPlot.ChildAdded:Connect(addPetMoneySlider)
end

local ExpandGroup = Tabs.Farm:AddRightGroupbox("Auto Expand", "maximize")

ExpandGroup:AddToggle("AutoExpand", {
    Text = "Auto Expand Farm",
    Default = false,
})

ExpandGroup:AddSlider("ExpandDelay", {
    Text = "Loop Delay",
    Default = 2,
    Min = 0.5,
    Max = 15,
    Rounding = 1,
})

local RollGroup = Tabs.Roll:AddLeftGroupbox("Auto Roll", "dices")

RollGroup:AddToggle("AutoRoll", {
    Text = "Auto Roll",
    Default = false,
    Callback = function(state)
        if state then
            task.spawn(function()
                moveToRollButton()
                if Toggles.AutoRoll.Value then
                    sendAutoRoll("start")
                end
            end)
        else
            sendAutoRoll("stop")
        end
    end,
})

RollGroup:AddToggle("RollAutoPurchase", {
    Text = "Auto Purchase Rolled",
    Default = false,
    Callback = refreshAutoRoll,
})

RollGroup:AddDropdown("RollRarities", {
    Text = "Rarities To Keep",
    Values = RARITIES,
    Default = {},
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        selectedRarities = selectedSet(value)
        refreshAutoRoll()
    end,
})

local UpgradeGroup = Tabs.Roll:AddRightGroupbox("Auto Upgrades", "trending-up")

UpgradeGroup:AddToggle("AutoUpgrade", {
    Text = "Auto Upgrade",
    Default = false,
})

UpgradeGroup:AddDropdown("Upgrades", {
    Text = "Upgrades To Buy",
    Values = UPGRADE_NAMES,
    Default = {},
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        selectedUpgrades = selectedSet(value)
    end,
})

UpgradeGroup:AddSlider("UpgradeDelay", {
    Text = "Loop Delay",
    Default = 1,
    Min = 0.3,
    Max = 10,
    Rounding = 1,
})

local RebirthGroup = Tabs.Roll:AddRightGroupbox("Auto Rebirth", "rotate-ccw")

RebirthGroup:AddToggle("AutoRebirth", {
    Text = "Auto Rebirth",
    Default = false,
})

RebirthGroup:AddSlider("RebirthDelay", {
    Text = "Loop Delay",
    Default = 2,
    Min = 0.5,
    Max = 15,
    Rounding = 1,
})

local GearGroup = Tabs.Shop:AddLeftGroupbox("Auto Buy Gears", "wrench")

GearGroup:AddToggle("AutoBuyGears", {
    Text = "Auto Buy Gears",
    Default = false,
})

GearGroup:AddDropdown("Gears", {
    Text = "Gears To Buy",
    Values = GEAR_IDS,
    Default = {},
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        selectedGears = selectedSet(value)
    end,
})

GearGroup:AddSlider("GearDelay", {
    Text = "Loop Delay",
    Default = 2,
    Min = 0.5,
    Max = 15,
    Rounding = 1,
})

local CosmeticGroup = Tabs.Shop:AddRightGroupbox("Auto Buy Cosmetics", "palette")

CosmeticGroup:AddToggle("AutoBuyCosmetics", {
    Text = "Auto Buy Cosmetics",
    Default = false,
})

CosmeticGroup:AddDropdown("Cosmetics", {
    Text = "Cosmetics To Buy",
    Values = COSMETIC_IDS,
    Default = {},
    Multi = true,
    AllowNull = true,
    Searchable = true,
    Callback = function(value)
        selectedCosmetics = selectedSet(value)
    end,
})

CosmeticGroup:AddSlider("CosmeticDelay", {
    Text = "Loop Delay",
    Default = 2,
    Min = 0.5,
    Max = 15,
    Rounding = 1,
})

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddLabel("UI Keybind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "UI Keybind",
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

Library:OnUnload(function()
    if Toggles.AutoRoll.Value then
        sendAutoRoll("stop")
    end
    if antiAfkConnection then
        antiAfkConnection:Disconnect()
        antiAfkConnection = nil
    end
    if petAddedConnection then
        petAddedConnection:Disconnect()
        petAddedConnection = nil
    end
    print("Build a Pet Farm unloaded")
end)

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("OuroborosHub")
ThemeManager:SaveDefault("Mint")

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("OuroborosHub/BuildAPetFarm")
SaveManager:BuildConfigSection(Tabs.Settings)

ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()

SaveManager:LoadAutoloadConfig()

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoPlant.Value or Toggles.AutoPlantAll.Value then
            doPlant(Toggles.AutoPlantAll.Value)
        end
        task.wait(Options.PlantLoopDelay.Value or 1)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoShake.Value then
            doShake()
        end
        task.wait(Options.ShakeDelay.Value or 0.5)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.HarvestPatches.Value or Toggles.HarvestTreeGround.Value then
            doHarvest()
        end
        task.wait(Options.HarvestDelay.Value or 0.5)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoFeed.Value then
            doFeed()
        end
        task.wait(Options.FeedDelay.Value or 0.5)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoCollectPetMoney.Value then
            doCollectPetMoney()
        end
        task.wait(Options.PetMoneyDelay.Value or 2)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoExpand.Value then
            doExpand()
        end
        task.wait(Options.ExpandDelay.Value or 2)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoUpgrade.Value then
            doUpgrades()
        end
        task.wait(Options.UpgradeDelay.Value or 1)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoRebirth.Value then
            doRebirth()
        end
        task.wait(Options.RebirthDelay.Value or 2)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoBuyGears.Value then
            doBuyGears()
        end
        task.wait(Options.GearDelay.Value or 2)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoBuyCosmetics.Value then
            doBuyCosmetics()
        end
        task.wait(Options.CosmeticDelay.Value or 2)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoRoll and Toggles.AutoRoll.Value then
            doManualAutoRoll()
        end
        task.wait(1.5)
    end
end)

Library:Notify("Build a Pet Farm loaded")
