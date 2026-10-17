if not game:IsLoaded() then
	game.Loaded:Wait()
end

local SCRIPT_VERSION = "v0.3"
local GAME_NAME = "Print Mania!"
local GAME_KEY = "PrintMania"
local UI_SOURCE_URL = "https://raw.githubusercontent.com/joustingmatch/OuroFlow/main/Source.luau"
local DISCORD_INVITE = "https://discord.gg/synapsex"
local WEBSITE_LINK = "https://ouroboros-hub-rbx.web.app/"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")
local VirtualUser = game:GetService("VirtualUser")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local hasHttpGet = typeof(game.HttpGet) == "function"
local hasLoadstring = typeof(loadstring) == "function"

local function need(parent, name)
	local child = parent:WaitForChild(name, 20)
	if not child then
		error("missing " .. parent:GetFullName() .. "." .. name, 0)
	end
	return child
end

local Shared = need(ReplicatedStorage, "Shared")
local List = need(Shared, "List")
local HudShopConfig = require(need(List, "HudShopConfig"))
local UpgradeConfig = require(need(List, "UpgradeConfig"))
local GemUpgradeConfig = require(need(List, "GemUpgradeConfig"))
local UC = require(need(need(need(need(LocalPlayer, "PlayerScripts"), "Controllers"), "Game"), "UpgradeController"))
local PrinterGame = need(Workspace, "LocalPrinterGame")
local PapersFolder = need(PrinterGame, "Papers")
local GumMachineConfig = require(need(List, "GumMachineConfig"))
local RemoteEvents = need(ReplicatedStorage, "RemoteEvents")
local GumRollRequest = need(RemoteEvents, GumMachineConfig.ROLL_REMOTE)
local GumRollResult = need(RemoteEvents, GumMachineConfig.ROLL_RESULT_REMOTE)
local ClickChallenge = need(RemoteEvents, "ClickChallenge")
local ClickChallengeHit = need(RemoteEvents, "ClickChallengeHit")

local Labels = {
	Printers = {},
	Upgrades = {},
	ShopId = {},
	Trees = { "Paper Tree", "Gem Tree" },
	Capsules = {},
	CapsuleId = {},
}
for _, item in ipairs(HudShopConfig.Items) do
	if type(item) == "table" and type(item.id) == "string" then
		local label = tostring(item.name or item.id)
		if Labels.ShopId[label] then
			label = label .. " (" .. item.id .. ")"
		end
		Labels.ShopId[label] = item.id
		table.insert(item.category == "items" and Labels.Printers or Labels.Upgrades, label)
	end
end

for _, capsule in pairs(GumMachineConfig.Capsules) do
	if type(capsule) == "table" and type(capsule.id) == "string" then
		local label = tostring(capsule.name or capsule.id)
		table.insert(Labels.Capsules, label)
		Labels.CapsuleId[label] = capsule.id
	end
end
table.sort(Labels.Capsules)

local function createFeatureAPI(namespace)
	assert(type(namespace) == "string" and namespace ~= "", "namespace required")
	assert(type(getgenv) == "function", "getgenv unavailable")
	local env = getgenv()
	assert(type(env) == "table", "getgenv did not return a table")
	local previous = env[namespace]
	if previous ~= nil then
		assert(type(previous) == "table" and type(previous.Unload) == "function", "namespace occupied")
		local ok, err = pcall(previous.Unload)
		if not ok then
			warn("Previous cleanup: " .. tostring(err))
		end
	end

	local API = {
		State = {},
		Unloaded = false,
	}
	local cleanup = {}

	function API.Track(dispose)
		assert(type(dispose) == "function", "cleanup must be callable")
		if API.Unloaded then
			local ok, err = pcall(dispose)
			if not ok then
				warn("Cleanup: " .. tostring(err))
			end
		else
			table.insert(cleanup, dispose)
		end
		return dispose
	end

	function API.Unload()
		if API.Unloaded then
			return
		end
		API.Unloaded = true
		for index = #cleanup, 1, -1 do
			local dispose = table.remove(cleanup, index)
			local ok, err = pcall(dispose)
			if not ok then
				warn("Cleanup: " .. tostring(err))
			end
		end
		table.clear(API.State)
		if env[namespace] == API then
			env[namespace] = nil
		end
	end

	env[namespace] = API
	return API
end

local function attachUI(API, Window)
	assert(type(API) == "table" and type(API.Track) == "function", "FeatureAPI required")
	assert(type(Window) == "table" and type(Window.Destroy) == "function", "UI window required")
	API.Track(function()
		pcall(function()
			Window:Destroy()
		end)
	end)
	local gui = Window.Gui
	if typeof(gui) == "Instance" then
		local destroying = gui.Destroying:Connect(function()
			task.defer(API.Unload)
		end)
		API.Track(function()
			destroying:Disconnect()
		end)
	end
end


local API = createFeatureAPI("Ouroboros_PrintMania")

local Flags = {
	AutoPrint = false,
	AutoCollectPaper = false,
	AutoBuyPrinters = false,
	BuyPrinters = {},
	AutoBuyUpgrades = false,
	BuyUpgrades = {},
	AutoBuySkillTree = false,
	SkillTrees = { ["Paper Tree"] = true },
	AutoRollGum = false,
	HidePapers = false,
	AutoClickBoost = false,
	GumCapsule = nil,
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

local sentPapers = {}

local function stepPrint()
	if UC.IsLoaded() and LocalPlayer:GetAttribute("GumMode") ~= true then
		UC.RequestPrint()
	end
end

local function stepCollectPaper()
	if not UC.IsLoaded() then
		return
	end
	local present = {}
	local fresh = {}
	local now = os.clock()
	for _, part in ipairs(PapersFolder:GetDescendants()) do
		local id = part:GetAttribute("PaperIdentifier")
		if type(id) == "string" then
			present[id] = true
			if not sentPapers[id] or now - sentPapers[id] >= 0.4 then
				sentPapers[id] = now
				table.insert(fresh, id)
			end
		end
	end
	for id in pairs(sentPapers) do
		if not present[id] then
			sentPapers[id] = nil
		end
	end
	if #fresh > 0 then
		UC.ReportCollected(fresh, 1)
	end
end

local function stepBuyShop(selection)
	for label in pairs(selection) do
		if API.Unloaded then
			return
		end
		local id = Labels.ShopId[label]
		if id and UC.GetShopState(id) == "affordable" then
			UC.TryShopPurchase(id)
			task.wait(0.2)
		end
	end
end

local function stepBuyPrinters()
	stepBuyShop(Flags.BuyPrinters)
end

local function stepBuyUpgrades()
	stepBuyShop(Flags.BuyUpgrades)
end

local function stepBuySkillTree()
	if not UC.IsLoaded() then
		return
	end
	if Flags.SkillTrees["Paper Tree"] then
		for _, node in ipairs(UpgradeConfig.Nodes) do
			if API.Unloaded or not Flags.AutoBuySkillTree then
				return
			end
			if UC.GetPurchaseState(node.id) == "affordable" then
				UC.TryPurchase(node.id)
				task.wait(0.2)
			end
		end
	end
	if Flags.SkillTrees["Gem Tree"] then
		for _, node in ipairs(GemUpgradeConfig.Nodes) do
			if API.Unloaded or not Flags.AutoBuySkillTree then
				return
			end
			if UC.GetGemPurchaseState(node.id) == "affordable" then
				UC.TryGemPurchase(node.id)
				task.wait(0.2)
			end
		end
	end
end

local gumRequest = { last = 910000, pending = nil, result = nil }
API.Track((function()
	local connection = GumRollResult.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and payload.requestId == gumRequest.pending then
			gumRequest.result = payload
		end
	end)
	return function()
		connection:Disconnect()
	end
end)())

local function stepRollGum()
	local capsuleId = Flags.GumCapsule and Labels.CapsuleId[Flags.GumCapsule]
	if not capsuleId or not UC.IsLoaded() then
		return
	end
	gumRequest.last += 1
	gumRequest.pending = gumRequest.last
	gumRequest.result = nil
	GumRollRequest:FireServer(capsuleId, 1, gumRequest.pending)
	local started = os.clock()
	while not gumRequest.result and os.clock() - started < 5 and not API.Unloaded do
		task.wait(0.1)
	end
	local result = gumRequest.result
	gumRequest.pending = nil
	if result and result.ok == false then
		task.wait(result.reason == "tooExpensive" and 2 or 1)
	end
end

API.Track((function()
	local connection = ClickChallenge.OnClientEvent:Connect(function(payload)
		if not Flags.AutoClickBoost or type(payload) ~= "table" then
			return
		end
		local id, startAt, endAt = payload.id, payload.startAt, payload.endAt
		if type(id) ~= "number" or type(startAt) ~= "number" or type(endAt) ~= "number" then
			return
		end
		task.spawn(function()
			local delay = startAt - Workspace:GetServerTimeNow() + 0.1
			if delay > 0 then
				task.wait(math.min(delay, 10))
			end
			if API.Unloaded or not Flags.AutoClickBoost or Workspace:GetServerTimeNow() >= endAt then
				return
			end
			ClickChallengeHit:FireServer(id)
		end)
	end)
	return function()
		connection:Disconnect()
	end
end)())

local function setPapersHidden(hidden)
	local value = hidden and 1 or 0
	for _, part in ipairs(PapersFolder:GetDescendants()) do
		if part:IsA("BasePart") then
			if part.LocalTransparencyModifier ~= value then
				part.LocalTransparencyModifier = value
			end
		elseif part:IsA("SurfaceGui") then
			if part.Enabled == hidden then
				part.Enabled = not hidden
			end
		end
	end
end

local function stepHidePapers()
	setPapersHidden(true)
end

API.Track(function()
	setPapersHidden(false)
end)

local function startWorker(name, interval, step)
	task.spawn(function()
		while not API.Unloaded do
			if Flags[name] then
				local ok, err = pcall(step)
				if not ok then
					warn("[" .. GAME_NAME .. "] " .. name .. ": " .. tostring(err))
				end
			end
			task.wait(interval)
		end
	end)
end

local function setFlag(name, value)
	Flags[name] = value == true
	if name == "HidePapers" and not Flags.HidePapers then
		task.defer(setPapersHidden, false)
	end
end

startWorker("AutoPrint", 0.21, stepPrint)
startWorker("AutoCollectPaper", 0.1, stepCollectPaper)
startWorker("AutoBuyPrinters", 1, stepBuyPrinters)
startWorker("AutoBuyUpgrades", 1, stepBuyUpgrades)
startWorker("AutoBuySkillTree", 1, stepBuySkillTree)
startWorker("AutoRollGum", 0.3, stepRollGum)
startWorker("HidePapers", 0.2, stepHidePapers)

local PlayerApi = {}
local walkSnapshots = setmetatable({}, { __mode = "k" })
local noclipSnapshots = setmetatable({}, { __mode = "k" })
local promptSnapshots = setmetatable({}, { __mode = "k" })
local fpsSnapshots = setmetatable({}, { __mode = "k" })
local flyState = {
	connection = nil,
	humanoid = nil,
	priorPlatformStand = nil,
}
local infJumpConnection = nil
local noclipConnection = nil
local promptConnection = nil
local fpsConnection = nil
local reconnectConnections = {}
local renderPrior = nil
local renderCover = nil

function PlayerApi.setWalkSpeedEnabled(value)
	Flags.WalkSpeedEnabled = value == true
	local _, _, humanoid = characterParts()
	if not humanoid then
		return
	end
	if Flags.WalkSpeedEnabled then
		if walkSnapshots[humanoid] == nil then
			walkSnapshots[humanoid] = humanoid.WalkSpeed
		end
		humanoid.WalkSpeed = Flags.WalkSpeed
	elseif walkSnapshots[humanoid] ~= nil then
		humanoid.WalkSpeed = walkSnapshots[humanoid]
		walkSnapshots[humanoid] = nil
	end
end

function PlayerApi.setWalkSpeed(value)
	Flags.WalkSpeed = value
	if Flags.WalkSpeedEnabled then
		local _, _, humanoid = characterParts()
		if humanoid then
			if walkSnapshots[humanoid] == nil then
				walkSnapshots[humanoid] = humanoid.WalkSpeed
			end
			humanoid.WalkSpeed = value
		end
	end
end

function PlayerApi.setInfJump(value)
	Flags.InfJump = value == true
	if infJumpConnection then
		infJumpConnection:Disconnect()
		infJumpConnection = nil
	end
	if not Flags.InfJump then
		return
	end
	infJumpConnection = UserInputService.JumpRequest:Connect(function()
		if API.Unloaded or not Flags.InfJump then
			return
		end
		local _, _, humanoid = characterParts()
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)
	API.Track(function()
		if infJumpConnection then
			infJumpConnection:Disconnect()
			infJumpConnection = nil
		end
	end)
end

local function applyNoclip(character)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			if noclipSnapshots[part] == nil then
				noclipSnapshots[part] = part.CanCollide
			end
			part.CanCollide = false
		end
	end
end

local function restoreNoclip()
	for part, prior in pairs(noclipSnapshots) do
		if part.Parent then
			part.CanCollide = prior
		end
		noclipSnapshots[part] = nil
	end
end

function PlayerApi.setNoClip(value)
	Flags.NoClip = value == true
	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end
	if not Flags.NoClip then
		restoreNoclip()
		return
	end
	local character = LocalPlayer.Character
	if character then
		applyNoclip(character)
	end
	noclipConnection = RunService.Stepped:Connect(function()
		if API.Unloaded or not Flags.NoClip then
			return
		end
		local live = LocalPlayer.Character
		if live then
			applyNoclip(live)
		end
	end)
	API.Track(function()
		if noclipConnection then
			noclipConnection:Disconnect()
			noclipConnection = nil
		end
		restoreNoclip()
	end)
end

local function snapshotPrompt(prompt)
	if promptSnapshots[prompt] == nil then
		promptSnapshots[prompt] = {
			HoldDuration = prompt.HoldDuration,
			MaxActivationDistance = prompt.MaxActivationDistance,
			RequiresLineOfSight = prompt.RequiresLineOfSight,
		}
	end
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 50
	prompt.RequiresLineOfSight = false
end

local function restorePrompts()
	for prompt, prior in pairs(promptSnapshots) do
		if prompt.Parent then
			prompt.HoldDuration = prior.HoldDuration
			prompt.MaxActivationDistance = prior.MaxActivationDistance
			prompt.RequiresLineOfSight = prior.RequiresLineOfSight
		end
		promptSnapshots[prompt] = nil
	end
end

function PlayerApi.setInstantProximityPrompt(value)
	Flags.InstantProximityPrompt = value == true
	if promptConnection then
		promptConnection:Disconnect()
		promptConnection = nil
	end
	if not Flags.InstantProximityPrompt then
		restorePrompts()
		return
	end
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("ProximityPrompt") then
			snapshotPrompt(inst)
		end
	end
	promptConnection = Workspace.DescendantAdded:Connect(function(inst)
		if Flags.InstantProximityPrompt and inst:IsA("ProximityPrompt") then
			snapshotPrompt(inst)
		end
	end)
	API.Track(function()
		if promptConnection then
			promptConnection:Disconnect()
			promptConnection = nil
		end
		restorePrompts()
	end)
end

local function stopFly()
	if flyState.connection then
		flyState.connection:Disconnect()
		flyState.connection = nil
	end
	if flyState.humanoid and flyState.humanoid.Parent and flyState.priorPlatformStand ~= nil then
		flyState.humanoid.PlatformStand = flyState.priorPlatformStand
	end
	flyState.humanoid = nil
	flyState.priorPlatformStand = nil
	local _, root = characterParts()
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

function PlayerApi.setFly(value)
	Flags.Fly = value == true
	stopFly()
	if not Flags.Fly then
		return
	end
	local _, root, humanoid = characterParts()
	if not (root and humanoid) then
		return
	end
	flyState.humanoid = humanoid
	flyState.priorPlatformStand = humanoid.PlatformStand
	humanoid.PlatformStand = true
	flyState.connection = RunService.RenderStepped:Connect(function()
		if API.Unloaded or not Flags.Fly then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		local _, liveRoot, liveHumanoid = characterParts()
		if not (liveRoot and liveHumanoid) then
			return
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local move = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			move += camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			move -= camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			move -= camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			move += camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			move += Vector3.yAxis
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			move -= Vector3.yAxis
		end
		if move.Magnitude > 0 then
			liveRoot.AssemblyLinearVelocity = move.Unit * Flags.FlySpeed
		else
			liveRoot.AssemblyLinearVelocity = Vector3.zero
		end
		liveHumanoid.PlatformStand = true
	end)
	API.Track(stopFly)
end

function PlayerApi.setFlySpeed(value)
	Flags.FlySpeed = value
end

local antiPauseGen = 0

function PlayerApi.setNoGameplayPaused(value)
	Flags.AntiGameplayPause = value == true
	antiPauseGen += 1
	local gen = antiPauseGen
	if not Flags.AntiGameplayPause then
		return
	end
	task.spawn(function()
		while not API.Unloaded and Flags.AntiGameplayPause and gen == antiPauseGen do
			pcall(function()
				GuiService:ClearError()
			end)
			local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
			if playerGui then
				local pause = playerGui:FindFirstChild("GameplayPaused")
				if pause and pause:IsA("GuiObject") then
					pause.Enabled = false
				end
			end
			task.wait(1)
		end
	end)
end

function PlayerApi.setAutoReconnect(value)
	Flags.AutoReconnect = value == true
	for _, conn in ipairs(reconnectConnections) do
		conn:Disconnect()
	end
	table.clear(reconnectConnections)
	if not Flags.AutoReconnect then
		return
	end
	local attemptToken = 0
	local function reconnect()
		if API.Unloaded or not Flags.AutoReconnect then
			return
		end
		attemptToken += 1
		local token = attemptToken
		task.spawn(function()
			task.wait(1.5)
			if API.Unloaded or not Flags.AutoReconnect or token ~= attemptToken then
				return
			end
			pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
			end)
			task.wait(4)
			if API.Unloaded or not Flags.AutoReconnect or token ~= attemptToken then
				return
			end
			pcall(function()
				TeleportService:Teleport(game.PlaceId, LocalPlayer)
			end)
		end)
	end
	table.insert(reconnectConnections, GuiService.ErrorMessageChanged:Connect(function()
		if Flags.AutoReconnect then
			reconnect()
		end
	end))
	table.insert(reconnectConnections, TeleportService.TeleportInitFailed:Connect(function(player)
		if player == LocalPlayer and Flags.AutoReconnect then
			reconnect()
		end
	end))
	API.Track(function()
		for _, conn in ipairs(reconnectConnections) do
			conn:Disconnect()
		end
		table.clear(reconnectConnections)
	end)
end

function PlayerApi.setDisable3D(value)
	Flags.Disable3DRendering = value == true
	if Flags.Disable3DRendering then
		if renderPrior == nil and typeof(RunService.Set3dRenderingEnabled) == "function" then
			renderPrior = true
		end
		pcall(function()
			RunService:Set3dRenderingEnabled(false)
		end)
		if not renderCover then
			local gui = Instance.new("ScreenGui")
			gui.Name = "OuroborosRenderCover"
			gui.IgnoreGuiInset = true
			gui.DisplayOrder = -100
			gui.ResetOnSpawn = false
			local frame = Instance.new("Frame")
			frame.BackgroundColor3 = Color3.new(0, 0, 0)
			frame.Size = UDim2.fromScale(1, 1)
			frame.BorderSizePixel = 0
			frame.Parent = gui
			gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
			renderCover = gui
			API.Track(function()
				if renderCover then
					renderCover:Destroy()
					renderCover = nil
				end
			end)
		end
	else
		pcall(function()
			RunService:Set3dRenderingEnabled(true)
		end)
		if renderCover then
			renderCover:Destroy()
			renderCover = nil
		end
	end
end

local FPS_CLASSES = {
	ParticleEmitter = true,
	Trail = true,
	Beam = true,
	Fire = true,
	Smoke = true,
	Sparkles = true,
}

local function softenEffect(inst)
	if fpsSnapshots[inst] ~= nil then
		return
	end
	if FPS_CLASSES[inst.ClassName] then
		fpsSnapshots[inst] = { kind = "enabled", value = inst.Enabled }
		inst.Enabled = false
	end
end

function PlayerApi.setFpsBoost(value)
	Flags.FpsBoost = value == true
	if fpsConnection then
		fpsConnection:Disconnect()
		fpsConnection = nil
	end
	if not Flags.FpsBoost then
		for inst, prior in pairs(fpsSnapshots) do
			if inst.Parent and prior.kind == "enabled" then
				inst.Enabled = prior.value
			end
			fpsSnapshots[inst] = nil
		end
		if fpsSnapshots.lighting then
			local prior = fpsSnapshots.lighting
			Lighting.GlobalShadows = prior.GlobalShadows
			Lighting.FogEnd = prior.FogEnd
			fpsSnapshots.lighting = nil
		end
		return
	end
	fpsSnapshots.lighting = {
		GlobalShadows = Lighting.GlobalShadows,
		FogEnd = Lighting.FogEnd,
	}
	Lighting.GlobalShadows = false
	Lighting.FogEnd = 1e6
	local scanned = 0
	for _, inst in ipairs(Workspace:GetDescendants()) do
		softenEffect(inst)
		scanned += 1
		if scanned >= 4000 then
			break
		end
	end
	fpsConnection = Workspace.DescendantAdded:Connect(function(inst)
		if Flags.FpsBoost then
			softenEffect(inst)
		end
	end)
	API.Track(function()
		if fpsConnection then
			fpsConnection:Disconnect()
			fpsConnection = nil
		end
	end)
end

local MenuApi = {}
local antiAfkConnection = nil
local antiAfkGen = 0

function MenuApi.setAntiAfk(value)
	Flags.AntiAfk = value == true
	antiAfkGen += 1
	local gen = antiAfkGen
	if antiAfkConnection then
		antiAfkConnection:Disconnect()
		antiAfkConnection = nil
	end
	if not Flags.AntiAfk then
		return
	end
	antiAfkConnection = LocalPlayer.Idled:Connect(function()
		if API.Unloaded or not Flags.AntiAfk then
			return
		end
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end)
	task.spawn(function()
		while not API.Unloaded and Flags.AntiAfk and gen == antiAfkGen do
			task.wait(60)
			if API.Unloaded or not Flags.AntiAfk or gen ~= antiAfkGen then
				break
			end
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
		end
	end)
	API.Track(function()
		if antiAfkConnection then
			antiAfkConnection:Disconnect()
			antiAfkConnection = nil
		end
		antiAfkGen += 1
	end)
end

do
	local characterConn = LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.2)
		if API.Unloaded then
			return
		end
		if Flags.WalkSpeedEnabled then
			PlayerApi.setWalkSpeedEnabled(true)
		end
		if Flags.NoClip then
			PlayerApi.setNoClip(true)
		end
		if Flags.Fly then
			PlayerApi.setFly(true)
		end
	end)
	API.Track(function()
		characterConn:Disconnect()
	end)
end

if not hasHttpGet or not hasLoadstring then
	error("UI load requires HttpGet and loadstring", 0)
end

local okLibrary, Library = pcall(function()
	return loadstring(game:HttpGet(UI_SOURCE_URL))()
end)
if not okLibrary or type(Library) ~= "table" then
	error("failed to load UI library: " .. tostring(Library), 0)
end

Library:LoadFont({ Name = "ValleySans" })
Library:SetDefaultTheme("Rose")

local Window = Library:CreateWindow({
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

attachUI(API, Window)

local Main = Window:CreateTab({ Name = "Main", Icon = "gamepad-2" })
local Player = Window:CreateTab({ Name = "Player", Icon = "user" })
local Settings = Window:CreateTab({ Name = "Settings", Icon = "settings" })

local function selectedOption(option)
	if type(option) == "table" then
		return option[1]
	end
	return option
end

local function readFlag(name, default)
	local entry = Library.Flags and Library.Flags[name]
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

local function toggle(box, name, flag)
	box:CreateToggle({
		Name = name,
		CurrentValue = false,
		Flag = flag,
		Callback = function(value)
			setFlag(flag, value)
		end,
	})
end


local function toSet(option, lookup)
	local set = {}
	if type(option) == "string" then
		option = { option }
	end
	for _, label in pairs(type(option) == "table" and option or {}) do
		local key = lookup and lookup[label] or label
		if key then
			set[key] = true
		end
	end
	return set
end

local function multi(box, name, options, flag, lookup, target, default)
	box:CreateDropdown({
		Name = name,
		Options = options,
		MultipleOptions = true,
		CurrentOption = default or {},
		Flag = flag,
		Callback = function(option)
			Flags[target] = toSet(option, lookup)
		end,
	})
end

local function buildMainTab()
	local FarmBox = Main:AddLeftGroupbox({ Name = "Farm", Icon = "zap" })
	toggle(FarmBox, "Auto Print", "AutoPrint")
	toggle(FarmBox, "Auto Collect Paper", "AutoCollectPaper")
	toggle(FarmBox, "Hide Papers", "HidePapers")
	toggle(FarmBox, "Auto Click Boost Bubble", "AutoClickBoost")

	local TreeBox = Main:AddLeftGroupbox({ Name = "Skill Tree", Icon = "trending-up" })
	multi(TreeBox, "Trees", Labels.Trees, "SkillTreeChoice", nil, "SkillTrees", { "Paper Tree" })
	toggle(TreeBox, "Auto Buy Affordable Nodes", "AutoBuySkillTree")

	local ShopBox = Main:AddRightGroupbox({ Name = "Shop", Icon = "shopping-cart" })
	multi(ShopBox, "Printers", Labels.Printers, "BuyPrintersChoice", nil, "BuyPrinters")
	toggle(ShopBox, "Auto Buy Printers", "AutoBuyPrinters")
	ShopBox:CreateDivider()
	multi(ShopBox, "Upgrades", Labels.Upgrades, "BuyUpgradesChoice", nil, "BuyUpgrades")
	toggle(ShopBox, "Auto Buy Upgrades", "AutoBuyUpgrades")

	local GumBox = Main:AddRightGroupbox({ Name = "Bubblegum Machine", Icon = "gift" })
	GumBox:CreateDropdown({
		Name = "Capsule",
		Options = Labels.Capsules,
		CurrentOption = {},
		Flag = "GumCapsuleChoice",
		Callback = function(option)
			Flags.GumCapsule = selectedOption(option)
		end,
	})
	toggle(GumBox, "Auto Roll Bubblegum Machine", "AutoRollGum")
end

buildMainTab()

local function buildPlayerTab()
	local Movement = Player:AddLeftGroupbox({ Name = "Movement", Icon = "move" })
	Movement:CreateToggle({
		Name = "WalkSpeed",
		CurrentValue = false,
		Flag = "WalkSpeedEnabled",
		Callback = function(value)
			PlayerApi.setWalkSpeedEnabled(value)
		end,
	})
	Movement:CreateSlider({
		Name = "Speed",
		Range = { 16, 250 },
		Increment = 1,
		CurrentValue = 32,
		Flag = "WalkSpeed",
		Callback = function(value)
			PlayerApi.setWalkSpeed(value)
		end,
	})
	Movement:CreateToggle({
		Name = "Infinite Jump",
		CurrentValue = false,
		Flag = "InfJump",
		Callback = function(value)
			PlayerApi.setInfJump(value)
		end,
	})
	Movement:CreateToggle({
		Name = "Noclip",
		CurrentValue = false,
		Flag = "NoClip",
		Callback = function(value)
			PlayerApi.setNoClip(value)
		end,
	})
	Movement:CreateToggle({
		Name = "Instant ProximityPrompt",
		CurrentValue = false,
		Flag = "InstantProximityPrompt",
		Callback = function(value)
			PlayerApi.setInstantProximityPrompt(value)
		end,
	})

	local FlyBox = Player:AddRightGroupbox({ Name = "Fly", Icon = "plane" })
	FlyBox:CreateToggle({
		Name = "Fly",
		CurrentValue = false,
		Flag = "Fly",
		Callback = function(value)
			PlayerApi.setFly(value)
		end,
	})
	FlyBox:CreateSlider({
		Name = "Fly Speed",
		Range = { 10, 400 },
		Increment = 1,
		CurrentValue = 60,
		Flag = "FlySpeed",
		Callback = function(value)
			PlayerApi.setFlySpeed(value)
		end,
	})

	local Client = Player:AddLeftGroupbox({ Name = "Client", Icon = "monitor" })
	Client:CreateToggle({
		Name = "No Gameplay Paused",
		CurrentValue = true,
		Flag = "AntiGameplayPause",
		Callback = function(value)
			PlayerApi.setNoGameplayPaused(value)
		end,
	})
	Client:CreateToggle({
		Name = "Auto Reconnect on Kick",
		CurrentValue = false,
		Flag = "AutoReconnect",
		Callback = function(value)
			PlayerApi.setAutoReconnect(value)
		end,
	})
	Client:CreateToggle({
		Name = "Disable 3D Rendering",
		CurrentValue = false,
		Flag = "Disable3DRendering",
		Callback = function(value)
			PlayerApi.setDisable3D(value)
		end,
	})
	Client:CreateToggle({
		Name = "FPS Boost",
		CurrentValue = false,
		Flag = "FpsBoost",
		Callback = function(value)
			PlayerApi.setFpsBoost(value)
		end,
	})
	Client:CreateToggle({
		Name = "Hide UI On Start",
		CurrentValue = false,
		Flag = "HideUIOnStart",
		Callback = function() end,
	})
end

local function buildSettingsTab()
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
			local selected = if type(option) == "table" then option[1] else option
			Window:SetToggleButtonPlatform(selected == "Mobile & PC" and "Both" or "Mobile")
		end,
	})
	Interface:CreateToggle({
		Name = "Anti AFK",
		CurrentValue = true,
		Flag = "AntiAfk",
		Callback = function(value)
			MenuApi.setAntiAfk(value)
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
					Window:Destroy()
				end,
			})
		end,
	})
	Settings:CreateConfigManager({ Name = "Configs", Side = "Left" })
	Settings:CreateThemeManager({ Name = "Themes", Side = "Right" })
end

buildPlayerTab()
buildSettingsTab()


PlayerApi.setNoGameplayPaused(true)
MenuApi.setAntiAfk(true)

Window:LoadAutoload()

if readFlag("HideUIOnStart", false) == true then
	Window:Toggle(false)
end
