if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local NAMESPACE = "OuroborosRaceForEggs"

local function hubGetHui()
	return CoreGui
end

if getgenv then
	getgenv().gethui = hubGetHui
end
pcall(function()
	gethui = hubGetHui
end)

local function createFeatureAPI(namespace)
	assert(type(namespace) == "string" and namespace ~= "", "A namespace is required")
	assert(type(getgenv) == "function", "getgenv is unavailable")
	local env = getgenv()
	assert(type(env) == "table", "getgenv did not return a table")
	local previous = env[namespace]
	if previous ~= nil then
		assert(type(previous) == "table" and type(previous.Unload) == "function", "Namespace is occupied")
		previous.Unload()
		assert(env[namespace] == nil, "Previous instance did not release its namespace")
	end

	local API = { State = {}, Unloaded = false }
	local cleanup = {}

	function API.Track(dispose)
		assert(type(dispose) == "function", "Cleanup must be callable")
		if API.Unloaded then
			dispose()
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
		local failures = {}
		for index = #cleanup, 1, -1 do
			local dispose = table.remove(cleanup, index)
			local ok, err = pcall(dispose)
			if not ok then
				table.insert(failures, tostring(err))
			end
		end
		table.clear(API.State)
		if #failures > 0 then
			error("Cleanup incomplete: " .. table.concat(failures, "; "), 0)
		end
		if env[namespace] == API then
			env[namespace] = nil
		end
	end

	env[namespace] = API
	return API
end

local function attachUI(API, Library)
	assert(type(API) == "table" and type(API.Track) == "function", "FeatureAPI required")
	assert(type(Library) == "table" and type(Library.OnUnload) == "function", "UI library required")
	assert(type(Library.Unload) == "function", "UI unload required")
	API.Track(function()
		if not Library.Unloaded then
			Library:Unload()
		end
	end)
	Library:OnUnload(function()
		API.Unload()
	end)
end

local API = createFeatureAPI(NAMESPACE)

local function cref(instance)
	if typeof(cloneref) == "function" and typeof(instance) == "Instance" then
		return cloneref(instance)
	end
	return instance
end

local function callable(fn)
	return type(fn) == "function"
end

local function alive()
	return not API.Unloaded
end

local RS = cref(ReplicatedStorage)
local WS = cref(Workspace)

local KNIT_PACKAGE = "sleitnick_knit@1.7.0"

local State = API.State
State.Notifications = {}
State.Status = "Idle"

local function notify(message, seconds)
	if not alive() then
		return
	end
	table.insert(State.Notifications, { text = tostring(message), time = seconds or 5 })
	if #State.Notifications > 12 then
		table.remove(State.Notifications, 1)
	end
end

local function setStatus(text)
	State.Status = tostring(text)
end

-- Knit remotes ---------------------------------------------------------------

-- Every server call in this game lives under the Knit service tree as
-- Services.<ServiceName>.RF.<Name> for RemoteFunctions and .RE.<Name> for
-- RemoteEvents, so one resolver covers the whole game surface.
local function knitServices()
	local packages = RS:FindFirstChild("Packages")
	local index = packages and packages:FindFirstChild("_Index")
	local knitPackage = index and index:FindFirstChild(KNIT_PACKAGE)
	local knit = knitPackage and knitPackage:FindFirstChild("knit")
	return knit and knit:FindFirstChild("Services") or nil
end

local function knitRemote(serviceName, kind, remoteName)
	local services = knitServices()
	local service = services and services:FindFirstChild(serviceName)
	local folder = service and service:FindFirstChild(kind)
	local remote = folder and folder:FindFirstChild(remoteName)
	if not remote then
		return nil
	end
	if kind == "RF" and remote:IsA("RemoteFunction") then
		return remote
	end
	if kind == "RE" and remote:IsA("RemoteEvent") then
		return remote
	end
	return nil
end

-- Calling the method directly instead of through the instance keeps the call
-- identical while staying independent of any metatable hooks.
local function invoke(serviceName, remoteName, ...)
	local remote = knitRemote(serviceName, "RF", remoteName)
	if not remote then
		return false
	end
	local arguments = table.pack(...)
	local results = table.pack(pcall(function()
		return remote.InvokeServer(remote, table.unpack(arguments, 1, arguments.n))
	end))
	if not results[1] then
		return false
	end
	return true, table.unpack(results, 2, results.n)
end

-- Configuration --------------------------------------------------------------

local configCache = {}

local function configModule(name)
	local cached = configCache[name]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end
	local folder = RS:FindFirstChild("Configs")
	local module = folder and folder:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		configCache[name] = false
		return nil
	end
	local ok, result = pcall(require, module)
	if not ok or type(result) ~= "table" then
		configCache[name] = false
		return nil
	end
	configCache[name] = result
	return result
end

local function trainTools()
	local config = configModule("TrainToolConfig")
	local tools = config and config.TRAIN_TOOLS
	return type(tools) == "table" and tools or nil
end

local function playerSkins()
	return configModule("PlayerSkinConfig")
end

local function brainrots()
	local config = configModule("BrainrotsConfig")
	local entries = config and config.CONFIG
	return type(entries) == "table" and entries or nil
end

local function mutations()
	return configModule("MutationConfig")
end

local function sizes()
	local config = configModule("SizeConfig")
	local entries = config and config.SIZES
	return type(entries) == "table" and entries or nil
end

local function playtimeRewards()
	return configModule("PlaytimeRewardConfig")
end

local function seasonPassLevels()
	local config = configModule("SeasonPassConfig")
	local pass = config and config.Pass
	return type(pass) == "table" and pass or nil
end

local function rebirthTiers()
	local config = configModule("RebirthConfig")
	local tiers = config and config.REBIRTH
	return type(tiers) == "table" and tiers or nil
end

local function sortedIds(source, label)
	local list = {}
	if type(source) ~= "table" then
		return list
	end
	for key, entry in pairs(source) do
		if type(entry) == "table" then
			local id = type(entry.id) == "string" and entry.id or (type(key) == "string" and key or nil)
			if id then
				local text = label and type(entry.name) == "string" and entry.name or id
				table.insert(list, text)
			end
		end
	end
	table.sort(list)
	return list
end

-- brainrot display name -> brainrot id
local brainrotNameCache = nil

local function brainrotNames()
	if brainrotNameCache then
		return brainrotNameCache
	end
	local entries = brainrots()
	local map = {}
	if entries then
		for key, entry in pairs(entries) do
			if type(entry) == "table" then
				local id = type(entry.id) == "string" and entry.id or (type(key) == "string" and key or nil)
				if id then
					map[type(entry.name) == "string" and entry.name or id] = id
				end
			end
		end
	end
	brainrotNameCache = map
	return map
end

local function brainrotNameList()
	local names = {}
	for name in pairs(brainrotNames()) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

local function brainrotRarities()
	local entries = brainrots()
	local seen = {}
	local list = {}
	if entries then
		for _, entry in pairs(entries) do
			if type(entry) == "table" and type(entry.rarity) == "string" and not seen[entry.rarity] then
				seen[entry.rarity] = true
				table.insert(list, entry.rarity)
			end
		end
	end
	table.sort(list)
	return list
end

-- Client controllers ----------------------------------------------------------

local controllerCache = {}

local function playerController(name)
	local cached = controllerCache[name]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end
	local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
	if not scripts then
		return nil
	end
	for _, instance in ipairs(scripts:GetDescendants()) do
		if instance.Name == name and instance:IsA("ModuleScript") then
			local ok, result = pcall(require, instance)
			if ok and type(result) == "table" then
				controllerCache[name] = result
				return result
			end
			controllerCache[name] = false
			return nil
		end
	end
	return nil
end

-- Player data ------------------------------------------------------------------

local replicaCache = nil

-- The client keeps one PlayerDataReplica for the local player and the game UI
-- reads the same table, so it is the only reliable source for cash, inventory
-- and claim state. The registry is the first upvalue of ReplicaClient.FromId.
local function playerData()
	if type(replicaCache) == "table" and type(replicaCache.Data) == "table" then
		return replicaCache.Data
	end
	replicaCache = nil
	if not callable(debug and debug.getupvalue) then
		return nil
	end
	local module = RS:FindFirstChild("ReplicaClient")
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, client = pcall(require, module)
	if not ok or type(client) ~= "table" or not callable(client.FromId) then
		return nil
	end
	local resolved = pcall(function()
		local registry = debug.getupvalue(client.FromId, 1)
		if type(registry) ~= "table" then
			return
		end
		for _, replica in pairs(registry) do
			if type(replica) == "table" and type(replica.Data) == "table" then
				local tags = replica.Tags
				if type(tags) == "table" and tags.UserId == LocalPlayer.UserId then
					replicaCache = replica
					break
				end
			end
		end
	end)
	if not resolved or type(replicaCache) ~= "table" then
		return nil
	end
	return replicaCache.Data
end

local function currencyValue(name)
	local data = playerData()
	local currencies = data and data.Currencies
	if type(currencies) == "table" then
		return tonumber(currencies[name]) or 0
	end
	local stats = LocalPlayer:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild(name)
	return value and tonumber(value.Value) or 0
end

local function currentCash()
	return currencyValue("Cash")
end

local function currentSpeed()
	local data = playerData()
	if data and tonumber(data.Speed) then
		return tonumber(data.Speed)
	end
	local stats = LocalPlayer:FindFirstChild("leaderstats")
	local speed = stats and stats:FindFirstChild("Speed")
	return speed and tonumber(speed.Value) or 0
end

local function currentRebirth()
	local data = playerData()
	return data and tonumber(data.Rebirth) or 0
end

local function inventoryItems()
	local data = playerData()
	local inventory = data and data.Inventory
	local items = {}
	if type(inventory) ~= "table" then
		return items
	end
	for id, item in pairs(inventory) do
		if type(item) == "table" and type(id) == "string" then
			table.insert(items, {
				id = id,
				itemType = type(item.itemType) == "string" and item.itemType or nil,
				inner = type(item.innerEntity) == "table" and item.innerEntity or {},
			})
		end
	end
	return items
end

local function dataMap(field)
	local data = playerData()
	local map = data and data[field]
	return type(map) == "table" and map or nil
end

-- Actions -------------------------------------------------------------------

local function raceOnce()
	local controller = playerController("AutorunController")
	if not controller or not callable(controller.Start) then
		setStatus("Autorun controller unavailable")
		return
	end
	if LocalPlayer:GetAttribute("AutoRun") == true then
		setStatus(LocalPlayer:GetAttribute("IsRacing") == true and "Racing" or "Waiting for the next race")
		return
	end
	local ok = pcall(function()
		controller:Start()
	end)
	if ok then
		setStatus("Auto race armed")
	end
end

local function stopRace()
	local controller = playerController("AutorunController")
	if controller and callable(controller.Stop) then
		pcall(function()
			controller:Stop()
		end)
	end
end

local function tapOnce()
	if LocalPlayer:GetAttribute("IsRacing") ~= true then
		return
	end
	local controller = playerController("RunningController")
	if not controller or not callable(controller.Tapped) then
		return
	end
	pcall(function()
		controller:Tapped()
	end)
end

local function trainOnce()
	local ok, success, gain = invoke("TrainingService", "Train")
	if ok and success then
		setStatus(string.format("Trained +%s speed", tostring(tonumber(gain) or 0)))
	end
end

local function claimBonus(...)
	local arguments = table.pack(...)
	local ok, success
	if arguments.n > 0 then
		ok, success = invoke("TrainingService", "ClaimBonus", table.unpack(arguments, 1, arguments.n))
	else
		ok, success = invoke("TrainingService", "ClaimBonus")
	end
	if ok and success then
		setStatus("Claimed a 2x training bonus")
		return true
	end
	return false
end

local function plotSurface()
	local ok, plot = invoke("PlotService", "GetPlayerPlot")
	if not ok or typeof(plot) ~= "Instance" then
		return nil
	end
	local surface = plot:FindFirstChild("PlotSurface")
	if surface and surface:IsA("BasePart") then
		return surface
	end
	return nil
end

-- The place remotes take a world CFrame, so a pass walks a margin-inset grid
-- across the plot surface and moves to the next cell whenever the server
-- refuses the current one.
local function surfaceCells(surface)
	local cells = {}
	local halfX = math.max(0, surface.Size.X / 2 - 3)
	local halfZ = math.max(0, surface.Size.Z / 2 - 3)
	local top = surface.Position.Y + surface.Size.Y / 2 + 1
	local step = 6
	local x = -halfX
	while x <= halfX do
		local z = -halfZ
		while z <= halfZ do
			table.insert(cells, CFrame.new(surface.Position.X + x, top, surface.Position.Z + z))
			z += step
		end
		x += step
	end
	return cells
end

local function placeItems(itemType, serviceName, remoteName, controller)
	local surface = plotSurface()
	if not surface then
		setStatus("Waiting for your plot")
		return
	end
	local cells = surfaceCells(surface)
	if #cells == 0 then
		return
	end
	local cursor = 1
	for _, item in ipairs(inventoryItems()) do
		if not alive() or controller.stopped then
			return
		end
		if item.itemType == itemType then
			local placed = false
			while cursor <= #cells and not placed do
				local ok, success = invoke(serviceName, remoteName, item.id, cells[cursor])
				if ok and success then
					placed = true
					setStatus("Placed " .. string.lower(itemType))
				else
					cursor += 1
				end
			end
			if not placed then
				setStatus("No free space left on your plot")
				return
			end
			task.wait(0.2)
		end
	end
end

local PlaceEggController = { interval = 2 }

local function placeEggsOnce()
	placeItems("Egg", "EggService", "PlaceEgg", PlaceEggController)
end

local function hatchOnce()
	local now = os.time()
	local hatched = 0
	for _, model in ipairs(CollectionService:GetTagged("PlacedEgg")) do
		if not alive() then
			return
		end
		if model:GetAttribute("OwnerId") == LocalPlayer.UserId then
			local eggId = model:GetAttribute("EggId")
			local startTime = tonumber(model:GetAttribute("StartTime"))
			local duration = tonumber(model:GetAttribute("Duration"))
			if type(eggId) == "string" and startTime and duration and now >= startTime + duration then
				local ok, success = invoke("EggService", "HatchEgg", eggId)
				if ok and success then
					hatched += 1
					task.wait(0.2)
				end
			end
		end
	end
	if hatched > 0 then
		setStatus(string.format("Hatched %d egg%s", hatched, hatched == 1 and "" or "s"))
	end
end

local RebirthController = { interval = 10 }

local function rebirthOnce()
	local tiers = rebirthTiers()
	if tiers then
		local tier = tiers[currentRebirth() + 1]
		local cost = type(tier) == "table" and type(tier.Cost) == "table" and tonumber(tier.Cost.Cash) or nil
		if cost and currentCash() < cost then
			setStatus(string.format("Need %s cash to rebirth", tostring(cost)))
			return
		end
	end
	local ok, success = invoke("RebirthService", "Rebirth")
	if ok and success then
		setStatus("Rebirthed")
	end
end

local function playtimeOnce()
	local config = playtimeRewards()
	if not config then
		return
	end
	local data = playerData()
	local played = data and tonumber(data.TimePlayed) or 0
	local claimed = 0
	for index, entry in pairs(config) do
		if not alive() then
			return
		end
		if type(index) == "number" and type(entry) == "table" then
			local required = tonumber(entry.time)
			if required and played >= required then
				local ok, success = invoke("PlaytimeRewardService", "ClaimGift", index)
				if ok and success then
					claimed += 1
					task.wait(0.2)
				end
			end
		end
	end
	if claimed > 0 then
		setStatus(string.format("Claimed %d playtime reward%s", claimed, claimed == 1 and "" or "s"))
	end
end

local function eventPassOnce()
	local levels = seasonPassLevels()
	if not levels then
		return
	end
	local pass = dataMap("SeasonPass")
	local free = type(pass) == "table" and type(pass.Free) == "table" and pass.Free or {}
	local paid = type(pass) == "table" and type(pass.Paid) == "table" and pass.Paid or {}
	local claimed = 0
	for level, entry in pairs(levels) do
		if not alive() then
			return
		end
		if type(level) == "number" and type(entry) == "table" then
			if not free[level] then
				local ok, success = invoke("SeasonPassService", "ClaimPassReward", "Free", level)
				if ok and success ~= false then
					claimed += 1
					task.wait(0.15)
				end
			end
			if not paid[level] then
				invoke("SeasonPassService", "ClaimPassReward", "Paid", level)
				task.wait(0.15)
			end
		end
	end
	if claimed > 0 then
		setStatus("Claimed event pass rewards")
	end
end

local function equipBestOnce()
	local ok, success = invoke("AnimalService", "EquipBest")
	if ok and success then
		setStatus("Equipped your best pets")
	end
end

local SellController = {
	interval = 5,
	brainrots = {},
	rarities = {},
	mutations = {},
	sizes = {},
	sellEggs = false,
}

local function setCount(set)
	local count = 0
	for _ in pairs(set) do
		count += 1
	end
	return count
end

local function sellMatches(inner)
	local brainrotType = type(inner.brainrotType) == "string" and inner.brainrotType or nil
	if not brainrotType then
		return false
	end
	if setCount(SellController.brainrots) > 0 and not SellController.brainrots[brainrotType] then
		return false
	end
	if setCount(SellController.rarities) > 0 then
		local entries = brainrots()
		local entry = entries and entries[brainrotType]
		local rarity = type(entry) == "table" and entry.rarity or nil
		if not rarity or not SellController.rarities[rarity] then
			return false
		end
	end
	if setCount(SellController.mutations) > 0 then
		local mutation = type(inner.mutation) == "string" and inner.mutation or nil
		if not mutation or not SellController.mutations[mutation] then
			return false
		end
	end
	if setCount(SellController.sizes) > 0 then
		local size = type(inner.size) == "string" and inner.size or nil
		if not size or not SellController.sizes[size] then
			return false
		end
	end
	return true
end

local function sellOnce()
	local batch = {}
	local eggs = {}
	for _, item in ipairs(inventoryItems()) do
		if item.itemType == "Brainrot" then
			if sellMatches(item.inner) then
				table.insert(batch, item.id)
			end
		elseif item.itemType == "Egg" and SellController.sellEggs then
			table.insert(eggs, item.id)
		end
	end
	if #batch > 0 then
		local ok = invoke("InventoryService", "SellBrainrots", batch)
		if ok then
			setStatus(string.format("Sold %d brainrot%s", #batch, #batch == 1 and "" or "s"))
		end
	end
	for _, id in ipairs(eggs) do
		if not alive() or SellController.stopped then
			return
		end
		invoke("InventoryService", "SellEgg", id)
		task.wait(0.15)
	end
	if #eggs > 0 then
		setStatus(string.format("Sold %d egg%s", #eggs, #eggs == 1 and "" or "s"))
	end
end

local WeightController = { interval = 5, allowed = {}, maxCost = 0 }
local DiceController = { interval = 5, allowed = {}, maxCost = 0 }

local function cheapestPurchase(source, owned, allowed, maxCost, cash)
	local best = nil
	if type(source) ~= "table" then
		return nil
	end
	for key, entry in pairs(source) do
		if type(entry) == "table" then
			local id = type(entry.id) == "string" and entry.id or (type(key) == "string" and key or nil)
			local cost = tonumber(entry.cost)
			local label = type(entry.name) == "string" and entry.name or id
			if id and cost and not (owned and owned[id]) then
				local wanted = setCount(allowed) == 0 or allowed[label] == true or allowed[id] == true
				if wanted and (maxCost <= 0 or cost <= maxCost) and cost <= cash then
					if not best or cost < best.cost then
						best = { id = id, cost = cost, name = label }
					end
				end
			end
		end
	end
	return best
end

local function buyWeightOnce()
	local tools = trainTools()
	if not tools then
		return
	end
	local owned = dataMap("OwnedTrainTools") or {}
	local pick = cheapestPurchase(tools, owned, WeightController.allowed, WeightController.maxCost, currentCash())
	if pick then
		invoke("TrainingService", "BuyTrainTool", pick.id)
		task.wait(0.4)
		owned = dataMap("OwnedTrainTools") or owned
		setStatus(owned[pick.id] and ("Bought " .. pick.name) or ("Could not buy " .. pick.name))
	end
	local data = playerData()
	local equipped = data and data.EquippedTrainTool
	local best = nil
	for id in pairs(owned) do
		local entry = tools[id]
		local gain = type(entry) == "table" and tonumber(entry.gainPerTrain) or nil
		if gain and (not best or gain > best.gain) then
			best = { id = id, gain = gain, name = type(entry.name) == "string" and entry.name or id }
		end
	end
	if best and equipped ~= best.id then
		local ok = invoke("TrainingService", "EquipTrainTool", best.id)
		if ok then
			setStatus("Equipped " .. best.name)
		end
	end
end

local function buyDiceOnce()
	local skins = playerSkins()
	if not skins then
		return
	end
	local owned = dataMap("OwnedSkins") or {}
	local pick = cheapestPurchase(skins, owned, DiceController.allowed, DiceController.maxCost, currentCash())
	if pick then
		invoke("SkinService", "BuySkin", pick.id)
		task.wait(0.4)
		owned = dataMap("OwnedSkins") or owned
		setStatus(owned[pick.id] and ("Bought " .. pick.name) or ("Could not buy " .. pick.name))
	end
	local data = playerData()
	local equipped = data and data.EquippedPlayerSkin
	local best = nil
	for id in pairs(owned) do
		local entry = skins[id]
		local luck = type(entry) == "table" and tonumber(entry.luck) or nil
		if luck and (not best or luck > best.luck) then
			best = { id = id, luck = luck, name = type(entry.name) == "string" and entry.name or id }
		end
	end
	if best and equipped ~= best.id then
		local ok = invoke("SkinService", "EquipSkin", best.id)
		if ok then
			setStatus("Equipped " .. best.name)
		end
	end
end

local DailyController = { interval = 60, includeVip = false }

local function dailyOnce()
	local daily = dataMap("DailyReward")
	local last = daily and tonumber(daily.LastClaimedDay) or 0
	local day = last + 1
	if day > 7 or day < 1 then
		day = 1
	end
	local ok, success = invoke("DailyRewardService", "ClaimReward", day)
	if ok and success then
		setStatus("Claimed daily reward " .. tostring(day))
	end
	if DailyController.includeVip then
		invoke("DailyRewardService", "ClaimVIPReward", day)
	end
end

local function teleportToBase()
	local ok = invoke("PlotService", "TeleportToPlot")
	if ok then
		notify("Teleported to your base")
	else
		notify("Could not reach the plot service")
	end
end

-- Controllers ----------------------------------------------------------------

local RaceController = { interval = 5 }
local TapController = { interval = 0.2 }
local TrainController = { interval = 0.3 }
local BonusController = { interval = 5 }
local HatchController = { interval = 3 }
local PlaytimeController = { interval = 30 }
local EventPassController = { interval = 30 }
local EquipBestController = { interval = 10 }

local function startLoop(controller, body)
	controller.generation = (controller.generation or 0) + 1
	controller.stopped = false
	local generation = controller.generation
	task.spawn(function()
		while alive() and not controller.stopped and controller.generation == generation do
			local ok, err = pcall(body)
			if not ok then
				warn("[Ouroboros] loop error: " .. tostring(err))
			end
			if not alive() or controller.stopped or controller.generation ~= generation then
				break
			end
			task.wait(controller.interval)
		end
	end)
end

local function stopLoop(controller)
	controller.stopped = true
	controller.generation = (controller.generation or 0) + 1
end

local function selectionSet(values)
	local set = {}
	if type(values) == "table" then
		for key, value in pairs(values) do
			if value == true and type(key) == "string" then
				set[key] = true
			elseif type(value) == "string" then
				set[value] = true
			end
		end
	end
	return set
end

local function mappedSet(values, map)
	local set = {}
	for name in pairs(selectionSet(values)) do
		local id = map and map[name] or name
		set[id] = true
	end
	return set
end

-- Auto race must survive a respawn: the game clears its own autorun state with
-- the character, so the toggle re-arms the controller on every new character.
local raceConnection = nil

function RaceController.SetEnabled(value)
	if raceConnection then
		raceConnection:Disconnect()
		raceConnection = nil
	end
	if value then
		raceConnection = LocalPlayer.CharacterAdded:Connect(function()
			task.wait(3)
			if alive() and not RaceController.stopped then
				raceOnce()
			end
		end)
		startLoop(RaceController, raceOnce)
	else
		stopLoop(RaceController)
		stopRace()
		setStatus("Auto race off")
	end
end

function TapController.SetEnabled(value)
	if value then
		startLoop(TapController, tapOnce)
	else
		stopLoop(TapController)
	end
end

function TapController.SetDelay(value)
	TapController.interval = math.max(0.05, tonumber(value) or 0.2)
end

function TrainController.SetEnabled(value)
	if value then
		startLoop(TrainController, trainOnce)
	else
		stopLoop(TrainController)
	end
end

function TrainController.SetDelay(value)
	TrainController.interval = math.max(0.1, tonumber(value) or 0.3)
end

local bonusConnection = nil

function BonusController.SetEnabled(value)
	if bonusConnection then
		bonusConnection:Disconnect()
		bonusConnection = nil
	end
	if value then
		local remote = knitRemote("TrainingService", "RE", "SpawnBonus")
		if remote then
			bonusConnection = remote.OnClientEvent:Connect(function(...)
				if alive() and not BonusController.stopped then
					claimBonus(...)
				end
			end)
		end
		startLoop(BonusController, function()
			claimBonus()
		end)
	else
		stopLoop(BonusController)
	end
end

function BonusController.SetDelay(value)
	BonusController.interval = math.max(1, tonumber(value) or 5)
end

function PlaceEggController.SetEnabled(value)
	if value then
		startLoop(PlaceEggController, placeEggsOnce)
	else
		stopLoop(PlaceEggController)
	end
end

function PlaceEggController.SetDelay(value)
	PlaceEggController.interval = math.max(0.5, tonumber(value) or 2)
end

function HatchController.SetEnabled(value)
	if value then
		startLoop(HatchController, hatchOnce)
	else
		stopLoop(HatchController)
	end
end

function HatchController.SetDelay(value)
	HatchController.interval = math.max(0.5, tonumber(value) or 3)
end

function RebirthController.SetEnabled(value)
	if value then
		startLoop(RebirthController, rebirthOnce)
	else
		stopLoop(RebirthController)
	end
end

function RebirthController.SetDelay(value)
	RebirthController.interval = math.max(1, tonumber(value) or 10)
end

function PlaytimeController.SetEnabled(value)
	if value then
		startLoop(PlaytimeController, playtimeOnce)
	else
		stopLoop(PlaytimeController)
	end
end

function EventPassController.SetEnabled(value)
	if value then
		startLoop(EventPassController, eventPassOnce)
	else
		stopLoop(EventPassController)
	end
end

function EquipBestController.SetEnabled(value)
	if value then
		startLoop(EquipBestController, equipBestOnce)
	else
		stopLoop(EquipBestController)
	end
end

function EquipBestController.SetDelay(value)
	EquipBestController.interval = math.max(1, tonumber(value) or 10)
end

function SellController.SetEnabled(value)
	if value then
		startLoop(SellController, sellOnce)
	else
		stopLoop(SellController)
	end
end

function SellController.SetDelay(value)
	SellController.interval = math.max(1, tonumber(value) or 5)
end

function SellController.SetBrainrots(values)
	SellController.brainrots = mappedSet(values, brainrotNames())
end

function SellController.SetRarities(values)
	SellController.rarities = selectionSet(values)
end

function SellController.SetMutations(values)
	SellController.mutations = selectionSet(values)
end

function SellController.SetSizes(values)
	SellController.sizes = selectionSet(values)
end

function SellController.SetSellEggs(value)
	SellController.sellEggs = value == true
end

function WeightController.SetEnabled(value)
	if value then
		startLoop(WeightController, buyWeightOnce)
	else
		stopLoop(WeightController)
	end
end

function WeightController.SetDelay(value)
	WeightController.interval = math.max(1, tonumber(value) or 5)
end

function WeightController.SetAllowed(values)
	WeightController.allowed = selectionSet(values)
end

function WeightController.SetMaxCost(value)
	WeightController.maxCost = math.max(0, tonumber(value) or 0)
end

function DiceController.SetEnabled(value)
	if value then
		startLoop(DiceController, buyDiceOnce)
	else
		stopLoop(DiceController)
	end
end

function DiceController.SetDelay(value)
	DiceController.interval = math.max(1, tonumber(value) or 5)
end

function DiceController.SetAllowed(values)
	DiceController.allowed = selectionSet(values)
end

function DiceController.SetMaxCost(value)
	DiceController.maxCost = math.max(0, tonumber(value) or 0)
end

function DailyController.SetEnabled(value)
	if value then
		startLoop(DailyController, dailyOnce)
	else
		stopLoop(DailyController)
	end
end

function DailyController.SetIncludeVip(value)
	DailyController.includeVip = value == true
end

API.Track(function()
	stopLoop(RaceController)
	stopLoop(TapController)
	stopLoop(TrainController)
	stopLoop(BonusController)
	stopLoop(PlaceEggController)
	stopLoop(HatchController)
	stopLoop(RebirthController)
	stopLoop(PlaytimeController)
	stopLoop(EventPassController)
	stopLoop(EquipBestController)
	stopLoop(SellController)
	stopLoop(WeightController)
	stopLoop(DiceController)
	stopLoop(DailyController)
	if raceConnection then
		raceConnection:Disconnect()
		raceConnection = nil
	end
	if bonusConnection then
		bonusConnection:Disconnect()
		bonusConnection = nil
	end
end)

-- Requiring a game ModuleScript strips Instance creation from the calling
-- thread, so the catalogs and client controllers are read on a throwaway thread
-- before the UI is built and only the cached tables are touched afterwards.
local function prewarmGameModules()
	local done = false
	task.spawn(function()
		pcall(trainTools)
		pcall(playerSkins)
		pcall(brainrots)
		pcall(mutations)
		pcall(sizes)
		pcall(playtimeRewards)
		pcall(seasonPassLevels)
		pcall(rebirthTiers)
		pcall(brainrotNames)
		pcall(playerData)
		pcall(playerController, "AutorunController")
		pcall(playerController, "RunningController")
		done = true
	end)
	local deadline = os.clock() + 8
	while not done and os.clock() < deadline do
		task.wait(0.05)
	end
end

-- Interface ----------------------------------------------------------------

local function setupInterface()
	local GAME_NAME = "Race for Eggs"
	local SCRIPT_VERSION = "v0.1"
	local DISCORD_INVITE = "https://discord.gg/synapsex"
	local RSCRIPTS_LINK = "https://rscripts.net/@Ouroboros"
	local WEBSITE_LINK = "https://ouroboros-hub-rbx.web.app/"
	local repo = "https://raw.githubusercontent.com/joustingmatch/ObsidianUltra/main/"
	local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
	local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
	local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
	local Toggles = Library.Toggles
	local Options = Library.Options
	attachUI(API, Library)
	local BRAINROT_VALUES = brainrotNameList()
	local RARITY_VALUES = brainrotRarities()
	local MUTATION_VALUES = sortedIds(mutations(), false)
	local SIZE_VALUES = sortedIds(sizes(), false)
	local WEIGHT_VALUES = sortedIds(trainTools(), true)
	local SKIN_VALUES = sortedIds(playerSkins(), true)
	local function copyText(text, message)
		local writer = callable(setclipboard) and setclipboard or (callable(toclipboard) and toclipboard or nil)
		if not writer then
			Library:Notify("Clipboard is unavailable")
			return
		end
		local ok = pcall(writer, text)
		if ok then
			Library:Notify(message)
		else
			Library:Notify("Failed to copy")
		end
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
			"|",
			SCRIPT_VERSION,
		},
		Icon = 78539693571783,
		NotifySide = "Right",
		ShowCustomCursor = false,
		CornerRadius = 0,
		SidebarCompacted = true,
		TabSwipeFrom = "bottom",
		Animations = { TabSwitch = true },
	})
	Window:SetGlow(false)
	local Tabs = {
		Info = Window:AddTab("Info", "info"),
		Main = Window:AddTab("Main", "gamepad-2"),
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
	local function setupMainTab()
		local RaceGroup = Tabs.Main:AddLeftGroupbox("Racing", "flag")
		local StatusLabel = RaceGroup:AddLabel(State.Status, true)
		RaceGroup:AddDivider()
		RaceGroup:AddToggle("AutoRace", {
			Text = "Auto Race",
			Default = false,
			Tooltip = "Arms the game's own autorun so you join every race that opens. Races open on a server timer, so idle gaps are normal.",
			Callback = function(value)
				RaceController.SetEnabled(value)
			end,
		})
		RaceGroup:AddToggle("AutoTap", {
			Text = "Auto Tap",
			Default = false,
			Tooltip = "Taps for you while a race is running.",
			Callback = function(value)
				TapController.SetEnabled(value)
			end,
		})
		RaceGroup:AddSlider("TapDelay", {
			Text = "Tap Delay",
			Default = 0.2,
			Min = 0.05,
			Max = 2,
			Rounding = 2,
			Suffix = "s",
			Callback = function(value)
				TapController.SetDelay(value)
			end,
		})
		RaceGroup:AddDivider("Training")
		RaceGroup:AddToggle("AutoTrain", {
			Text = "Auto Train",
			Default = false,
			Tooltip = "Swings your dumbbell to raise Speed.",
			Callback = function(value)
				TrainController.SetEnabled(value)
			end,
		})
		RaceGroup:AddSlider("TrainDelay", {
			Text = "Train Delay",
			Default = 0.3,
			Min = 0.1,
			Max = 5,
			Rounding = 2,
			Suffix = "s",
			Callback = function(value)
				TrainController.SetDelay(value)
			end,
		})
		RaceGroup:AddToggle("AutoBonus", {
			Text = "Auto 2x Bonus",
			Default = false,
			Tooltip = "Claims the 2x training bonus the moment it spawns.",
			Callback = function(value)
				BonusController.SetEnabled(value)
			end,
		})
		RaceGroup:AddSlider("BonusDelay", {
			Text = "Bonus Check Delay",
			Default = 5,
			Min = 1,
			Max = 60,
			Rounding = 1,
			Suffix = "s",
			Callback = function(value)
				BonusController.SetDelay(value)
			end,
		})
		RaceGroup:AddDivider("Rebirth")
		RaceGroup:AddToggle("AutoRebirth", {
			Text = "Auto Rebirth",
			Default = false,
			Tooltip = "Rebirths as soon as you can pay the next tier's cash cost.",
			Callback = function(value)
				RebirthController.SetEnabled(value)
			end,
		})
		RaceGroup:AddSlider("RebirthDelay", {
			Text = "Rebirth Delay",
			Default = 10,
			Min = 1,
			Max = 120,
			Rounding = 1,
			Suffix = "s",
			Callback = function(value)
				RebirthController.SetDelay(value)
			end,
		})
		local PlotGroup = Tabs.Main:AddLeftGroupbox("Plot", "layout-grid")
		PlotGroup:AddToggle("AutoPlaceEggs", {
			Text = "Auto Place Eggs",
			Default = false,
			Tooltip = "Drops every egg in your inventory onto a free spot on your plot.",
			Callback = function(value)
				PlaceEggController.SetEnabled(value)
			end,
		})
		PlotGroup:AddSlider("PlaceEggDelay", {
			Text = "Place Delay",
			Default = 2,
			Min = 0.5,
			Max = 30,
			Rounding = 1,
			Suffix = "s",
			Callback = function(value)
				PlaceEggController.SetDelay(value)
			end,
		})
		PlotGroup:AddToggle("AutoHatchEggs", {
			Text = "Auto Hatch Eggs",
			Default = false,
			Tooltip = "Hatches your placed eggs the second their timer runs out.",
			Callback = function(value)
				HatchController.SetEnabled(value)
			end,
		})
		PlotGroup:AddSlider("HatchDelay", {
			Text = "Hatch Delay",
			Default = 3,
			Min = 0.5,
			Max = 30,
			Rounding = 1,
			Suffix = "s",
			Callback = function(value)
				HatchController.SetDelay(value)
			end,
		})
		PlotGroup:AddDivider("Pets")
		PlotGroup:AddToggle("AutoEquipBest", {
			Text = "Auto Equip Best Pet",
			Default = false,
			Tooltip = "Keeps your highest earning brainrots placed on the plot.",
			Callback = function(value)
				EquipBestController.SetEnabled(value)
			end,
		})
		PlotGroup:AddSlider("EquipBestDelay", {
			Text = "Equip Delay",
			Default = 10,
			Min = 1,
			Max = 120,
			Rounding = 1,
			Suffix = "s",
			Callback = function(value)
				EquipBestController.SetDelay(value)
			end,
		})
		local SellGroup = Tabs.Main:AddRightGroupbox("Selling", "coins")
		SellGroup:AddToggle("AutoSell", {
			Text = "Auto Sell",
			Default = false,
			Tooltip = "Sells the inventory brainrots that match the filters below. Placed brainrots are never touched.",
			Callback = function(value)
				SellController.SetEnabled(value)
			end,
		})
		SellGroup:AddDropdown("SellBrainrots", {
			Text = "Sell Brainrots",
			Values = BRAINROT_VALUES,
			Default = {},
			Multi = true,
			AllowNull = true,
			Tooltip = "Leave everything unticked to ignore this filter.",
			Callback = function(value)
				SellController.SetBrainrots(value)
			end,
		})
		SellGroup:AddDropdown("SellRarities", {
			Text = "Sell Rarities",
			Values = RARITY_VALUES,
			Default = {},
			Multi = true,
			AllowNull = true,
			Tooltip = "Leave everything unticked to ignore this filter.",
			Callback = function(value)
				SellController.SetRarities(value)
			end,
		})
		SellGroup:AddDropdown("SellMutations", {
			Text = "Sell Mutations",
			Values = MUTATION_VALUES,
			Default = {},
			Multi = true,
			AllowNull = true,
			Tooltip = "Leave everything unticked to ignore this filter.",
			Callback = function(value)
				SellController.SetMutations(value)
			end,
		})
		SellGroup:AddDropdown("SellSizes", {
			Text = "Sell Sizes",
			Values = SIZE_VALUES,
			Default = {},
			Multi = true,
			AllowNull = true,
			Tooltip = "Leave everything unticked to ignore this filter.",
			Callback = function(value)
				SellController.SetSizes(value)
			end,
		})
		SellGroup:AddToggle("SellEggsToo", {
			Text = "Sell Eggs Too",
			Default = false,
			Tooltip = "Also sells every egg sitting in your inventory.",
			Callback = function(value)
				SellController.SetSellEggs(value)
			end,
		})
		SellGroup:AddSlider("SellDelay", {
			Text = "Sell Delay",
			Default = 5,
			Min = 1,
			Max = 60,
			Rounding = 1,
			Suffix = "s",
			Callback = function(value)
				SellController.SetDelay(value)
			end,
		})
		local ShopGroup = Tabs.Main:AddRightGroupbox("Shop", "shopping-cart")
		ShopGroup:AddToggle("AutoBuyWeights", {
			Text = "Auto Buy Weights",
			Default = false,
			Tooltip = "Buys the cheapest dumbbell you can afford, then equips the strongest one you own.",
			Callback = function(value)
				WeightController.SetEnabled(value)
			end,
		})
		ShopGroup:AddDropdown("WeightList", {
			Text = "Weights",
			Values = WEIGHT_VALUES,
			Default = {},
			Multi = true,
			AllowNull = true,
			Tooltip = "Leave everything unticked to buy any dumbbell.",
			Callback = function(value)
				WeightController.SetAllowed(value)
			end,
		})
		ShopGroup:AddSlider("WeightMaxCost", {
			Text = "Max Weight Cost",
			Default = 0,
			Min = 0,
			Max = 1000000000,
			Rounding = 0,
			Tooltip = "Skips dumbbells above this price. 0 removes the limit.",
			Callback = function(value)
				WeightController.SetMaxCost(value)
			end,
		})
		ShopGroup:AddSlider("WeightDelay", {
			Text = "Buy Weight Delay",
			Default = 5,
			Min = 1,
			Max = 60,
			Rounding = 1,
			Suffix = "s",
			Callback = function(value)
				WeightController.SetDelay(value)
			end,
		})
		ShopGroup:AddDivider("Dice")
		ShopGroup:AddToggle("AutoBuyDice", {
			Text = "Auto Buy Dice",
			Default = false,
			Tooltip = "Buys the cheapest player skin you can afford, then equips the luckiest one you own.",
			Callback = function(value)
				DiceController.SetEnabled(value)
			end,
		})
		ShopGroup:AddDropdown("DiceList", {
			Text = "Dice",
			Values = SKIN_VALUES,
			Default = {},
			Multi = true,
			AllowNull = true,
			Tooltip = "Leave everything unticked to buy any skin.",
			Callback = function(value)
				DiceController.SetAllowed(value)
			end,
		})
		ShopGroup:AddSlider("DiceMaxCost", {
			Text = "Max Dice Cost",
			Default = 0,
			Min = 0,
			Max = 1000000000,
			Rounding = 0,
			Tooltip = "Skips skins above this price. 0 removes the limit.",
			Callback = function(value)
				DiceController.SetMaxCost(value)
			end,
		})
		ShopGroup:AddSlider("DiceDelay", {
			Text = "Buy Dice Delay",
			Default = 5,
			Min = 1,
			Max = 60,
			Rounding = 1,
			Suffix = "s",
			Callback = function(value)
				DiceController.SetDelay(value)
			end,
		})
		local RewardGroup = Tabs.Main:AddRightGroupbox("Rewards", "gift")
		RewardGroup:AddToggle("AutoPlaytime", {
			Text = "Auto Claim Playtime Rewards",
			Default = false,
			Callback = function(value)
				PlaytimeController.SetEnabled(value)
			end,
		})
		RewardGroup:AddToggle("AutoEventPass", {
			Text = "Auto Claim Event Pass",
			Default = false,
			Tooltip = "Claims every free season pass tier you have reached, and the paid tiers you own.",
			Callback = function(value)
				EventPassController.SetEnabled(value)
			end,
		})
		RewardGroup:AddToggle("AutoDaily", {
			Text = "Auto Claim Daily Rewards",
			Default = false,
			Callback = function(value)
				DailyController.SetEnabled(value)
			end,
		})
		RewardGroup:AddToggle("DailyIncludeVip", {
			Text = "Include VIP Reward",
			Default = false,
			Tooltip = "Also tries the VIP half of the daily reward. It needs the matching gamepass.",
			Callback = function(value)
				DailyController.SetIncludeVip(value)
			end,
		})
		local TeleportGroup = Tabs.Main:AddRightGroupbox("Teleport", "map-pin")
		TeleportGroup:AddButton({
			Text = "Teleport To Base",
			Func = teleportToBase,
		})
		local pump = task.spawn(function()
			while not Library.Unloaded do
				pcall(function()
					local inventory = #inventoryItems()
					local racing = LocalPlayer:GetAttribute("IsRacing") == true and "racing" or "idle"
					local summary = string.format(
						"Cash %d  |  Speed %d  |  Rebirth %d  |  %s  |  Bag %d",
						math.floor(currentCash()),
						math.floor(currentSpeed()),
						currentRebirth(),
						racing,
						inventory
					)
					StatusLabel:SetText(summary .. "  |  " .. tostring(State.Status))
				end)
				while State.Notifications and #State.Notifications > 0 do
					local entry = table.remove(State.Notifications, 1)
					pcall(function()
						Library:Notify(entry.text, entry.time)
					end)
				end
				task.wait(0.3)
			end
		end)
		API.Track(function()
			if coroutine.status(pump) ~= "dead" then
				pcall(task.cancel, pump)
			end
		end)
	end
	setupMainTab()
	local function setupInfoTab()
		local function escapeText(text)
			return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;"))
		end
		local function colored(text, color)
			return string.format('<font color="%s">%s</font>', color, escapeText(text))
		end
		local function field(key, value, color)
			return string.format("<b>%s</b> %s %s", key, colored("-", "#5a6070"), colored(value, color))
		end
		local GREEN = "#7fd47f"
		local BLUE = "#6ec1ff"
		local ORANGE = "#e8a34d"
		local GREY = "#8b93a3"
		local missing = {}
		if not knitServices() then
			table.insert(missing, "every server action")
		end
		if not playerController("AutorunController") then
			table.insert(missing, "auto race")
		end
		if not playerController("RunningController") then
			table.insert(missing, "auto tap")
		end
		if not callable(debug and debug.getupvalue) or not playerData() then
			table.insert(missing, "cash, inventory and claim state")
		end
		if not brainrots() then
			table.insert(missing, "sell filters")
		end
		if not trainTools() then
			table.insert(missing, "buying weights")
		end
		if not playerSkins() then
			table.insert(missing, "buying dice")
		end
		if not callable(setclipboard) and not callable(toclipboard) then
			table.insert(missing, "clipboard copies")
		end
		local supportText = #missing == 0 and "ready" or ("limited: " .. table.concat(missing, ", "))
		local executorName = "Unknown"
		pcall(function()
			if callable(identifyexecutor) then
				local name, version = identifyexecutor()
				if type(name) == "string" and name ~= "" then
					executorName = type(version) == "string" and version ~= "" and (name .. " " .. version) or name
				end
			end
		end)
		local sessionStart = os.clock()
		local function sessionElapsed()
			local elapsed = math.floor(os.clock() - sessionStart)
			if elapsed < 60 then
				return elapsed .. "s"
			elseif elapsed < 3600 then
				return string.format("%dm %ds", elapsed // 60, elapsed % 60)
			end
			return string.format("%dh %dm", elapsed // 3600, (elapsed % 3600) // 60)
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
		UserGroup:AddButton({
			Text = "Copy Username",
			Func = function()
				copyText(LocalPlayer.Name, "Copied username")
			end,
		})
		UserGroup:AddButton({
			Text = "Copy Profile Link",
			Func = function()
				copyText("https://www.roblox.com/users/" .. tostring(LocalPlayer.UserId) .. "/profile", "Copied profile link")
			end,
		})
		local SessionGroup = Tabs.Info:AddRightGroupbox("Session", "signal")
		SessionGroup:AddLabel(field("Game", GAME_NAME, BLUE), true)
		local PlayersLabel = SessionGroup:AddLabel(field("Players", "0/0", GREEN), true)
		local jobId = tostring(game.JobId)
		local shortJobId = #jobId > 18 and (string.sub(jobId, 1, 18) .. "...") or jobId
		SessionGroup:AddLabel(field("Job", shortJobId, GREY), true)
		local PingLabel = SessionGroup:AddLabel(field("Ping", "0 ms", ORANGE), true)
		SessionGroup:AddDivider()
		SessionGroup:AddButton({
			Text = "Rejoin Place",
			Func = function()
				TeleportService:Teleport(game.PlaceId, LocalPlayer)
			end,
		})
		SessionGroup:AddButton({
			Text = "Copy Job ID",
			Func = function()
				copyText(jobId, "Copied Job ID")
			end,
		})
		local statsTask = task.spawn(function()
			while true do
				task.wait(1)
				if Library.Unloaded then
					break
				end
				SessionLabel:SetText(field("Session", sessionElapsed(), ORANGE))
				PlayersLabel:SetText(field("Players", #Players:GetPlayers() .. "/" .. tostring(Players.MaxPlayers), GREEN))
				local ok, ping = pcall(function()
					return math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
				end)
				PingLabel:SetText(field("Ping", ok and (ping .. " ms") or "n/a", ORANGE))
			end
		end)
		API.Track(function()
			if coroutine.status(statsTask) ~= "dead" then
				task.cancel(statsTask)
			end
		end)
		local SocialsGroup = Tabs.Info:AddRightGroupbox("Socials", "link")
		SocialsGroup:AddButton({ Text = "Discord", Func = copyDiscord })
		SocialsGroup:AddButton({
			Text = "Rscripts",
			Func = function()
				copyText(RSCRIPTS_LINK, "Copied Rscripts profile")
			end,
		})
		SocialsGroup:AddButton({
			Text = "Website",
			Func = function()
				copyText(WEBSITE_LINK, "Copied website link")
			end,
		})
	end
	setupInfoTab()
	local function setupPlayerTab()
		local MovementGroup = Tabs.Player:AddLeftGroupbox("Movement", "footprints")
		MovementGroup:AddToggle("WalkSpeedEnabled", { Text = "WalkSpeed", Default = false })
		MovementGroup:AddSlider("WalkSpeed", {
			Text = "WalkSpeed Amount",
			Default = 32,
			Min = 16,
			Max = 250,
			Rounding = 0,
		})
		MovementGroup:AddToggle("InfJump", { Text = "Infinite Jump", Default = false })
		MovementGroup:AddToggle("NoClip", { Text = "NoClip", Default = false })
		MovementGroup:AddToggle("InstantProximityPrompt", { Text = "Instant ProximityPrompt", Default = false })
		local FlyGroup = Tabs.Player:AddRightGroupbox("Fly", "feather")
		FlyGroup:AddToggle("Fly", { Text = "Fly", Default = false })
		FlyGroup:AddSlider("FlySpeed", {
			Text = "Fly Speed",
			Default = 60,
			Min = 10,
			Max = 400,
			Rounding = 0,
		})
		local connections = {}
		local collisions = {}
		local speeds = {}
		local platforms = {}
		local promptDefaults = {}
		local function restoreCollisions()
			for part, value in collisions do
				if part.Parent then
					part.CanCollide = value
				end
			end
			table.clear(collisions)
		end
		local function restoreSpeeds()
			for humanoid, value in speeds do
				if humanoid.Parent then
					humanoid.WalkSpeed = value
				end
			end
			table.clear(speeds)
		end
		local function restoreFlight()
			for humanoid, value in platforms do
				if humanoid.Parent then
					humanoid.PlatformStand = value
				end
			end
			table.clear(platforms)
		end
		local function applyPrompt(prompt)
			if not prompt:IsA("ProximityPrompt") then
				return
			end
			if promptDefaults[prompt] == nil then
				promptDefaults[prompt] = {
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
			for prompt, values in promptDefaults do
				if prompt.Parent then
					prompt.HoldDuration = values.HoldDuration
					prompt.MaxActivationDistance = values.MaxActivationDistance
					prompt.RequiresLineOfSight = values.RequiresLineOfSight
				end
			end
			table.clear(promptDefaults)
		end
		Toggles.Fly:OnChanged(function()
			if not Toggles.Fly.Value then
				restoreFlight()
			end
		end)
		Toggles.WalkSpeedEnabled:OnChanged(function()
			if not Toggles.WalkSpeedEnabled.Value then
				restoreSpeeds()
			end
		end)
		Toggles.NoClip:OnChanged(function()
			if not Toggles.NoClip.Value then
				restoreCollisions()
			end
		end)
		Toggles.InstantProximityPrompt:OnChanged(function()
			if Toggles.InstantProximityPrompt.Value then
				for _, prompt in Workspace:QueryDescendants("ProximityPrompt") do
					pcall(applyPrompt, prompt)
				end
			else
				restorePrompts()
			end
		end)
		table.insert(connections, Workspace.DescendantAdded:Connect(function(instance)
			if Toggles.InstantProximityPrompt.Value then
				applyPrompt(instance)
			end
		end))
		table.insert(connections, RunService.Stepped:Connect(function()
			if Library.Unloaded then
				return
			end
			local character = LocalPlayer.Character
			if Toggles.NoClip.Value and character then
				for _, part in character:QueryDescendants("BasePart") do
					if collisions[part] == nil then
						collisions[part] = part.CanCollide
					end
					part.CanCollide = false
				end
			end
		end))
		table.insert(connections, UserInputService.JumpRequest:Connect(function()
			if Library.Unloaded then
				return
			end
			local character = LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if Toggles.InfJump.Value and humanoid then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end))
		table.insert(connections, RunService.RenderStepped:Connect(function(dt)
			if Library.Unloaded then
				return
			end
			local character = LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local camera = Workspace.CurrentCamera
			if Toggles.WalkSpeedEnabled.Value and humanoid then
				if speeds[humanoid] == nil then
					speeds[humanoid] = humanoid.WalkSpeed
				end
				humanoid.WalkSpeed = Options.WalkSpeed.Value
			end
			if Toggles.Fly.Value and root and humanoid and camera then
				if platforms[humanoid] == nil then
					platforms[humanoid] = humanoid.PlatformStand
				end
				humanoid.PlatformStand = true
				local direction = Vector3.zero
				if not UserInputService:GetFocusedTextBox() then
					if UserInputService:IsKeyDown(Enum.KeyCode.W) then
						direction += camera.CFrame.LookVector
					end
					if UserInputService:IsKeyDown(Enum.KeyCode.S) then
						direction -= camera.CFrame.LookVector
					end
					if UserInputService:IsKeyDown(Enum.KeyCode.A) then
						direction -= camera.CFrame.RightVector
					end
					if UserInputService:IsKeyDown(Enum.KeyCode.D) then
						direction += camera.CFrame.RightVector
					end
					if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
						direction += Vector3.new(0, 1, 0)
					end
					if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
						direction -= Vector3.new(0, 1, 0)
					end
				end
				root.AssemblyLinearVelocity = Vector3.zero
				if direction.Magnitude > 0 then
					root.CFrame += direction.Unit * Options.FlySpeed.Value * dt
				end
			end
		end))
		API.Track(function()
			for _, connection in connections do
				connection:Disconnect()
			end
			restoreCollisions()
			restoreSpeeds()
			restoreFlight()
			restorePrompts()
		end)
	end
	setupPlayerTab()
	local function setupSettings()
		local connections = {}
		local effects = {}
		local renderDefaults
		local reconnecting = false
		local reconnectToken = 0
		local triggers = 0
		local lastPulse = os.clock()
		local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "logs")
		MenuGroup:AddToggle("AntiAfk", { Text = "Anti-AFK", Default = true })
		local AfkLabel = MenuGroup:AddLabel("AFK triggers: 0")
		local function pulse()
			local camera = Workspace.CurrentCamera
			if not camera or not callable(VirtualUser.CaptureController) or not callable(VirtualUser.ClickButton2) then
				return false
			end
			local ok = pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new(0, 0), camera.CFrame)
			end)
			if not ok then
				return false
			end
			triggers += 1
			lastPulse = os.clock()
			pcall(function()
				AfkLabel:SetText("AFK triggers: " .. triggers)
			end)
			return true
		end
		local function applyPause(enabled)
			pcall(function()
				GuiService:SetGameplayPausedNotificationEnabled(not enabled)
			end)
			pcall(function()
				local notification = CoreGui:FindFirstChild("RobloxNetworkPauseNotification")
				if notification then
					notification.Enabled = not enabled
				end
			end)
			if not enabled then
				return
			end
			pcall(function()
				if sethiddenproperty then
					sethiddenproperty(LocalPlayer, "GameplayPaused", false)
				else
					LocalPlayer.GameplayPaused = false
				end
			end)
		end
		local function stripEffect(instance)
			if instance.ClassName == "ParticleEmitter" or instance.ClassName == "Trail" or instance.ClassName == "Smoke" or instance.ClassName == "Fire" or instance.ClassName == "Sparkles" or instance.ClassName == "Explosion" or instance.ClassName == "Beam" then
				if effects[instance] == nil then
					effects[instance] = instance.Enabled
				end
				pcall(function()
					instance.Enabled = false
				end)
			end
		end
		local function restoreEffects()
			for instance, value in effects do
				if instance.Parent then
					pcall(function()
						instance.Enabled = value
					end)
				end
			end
			table.clear(effects)
			if renderDefaults then
				pcall(function()
					settings().Rendering.QualityLevel = renderDefaults.Quality
				end)
				Lighting.GlobalShadows = renderDefaults.Shadows
				Lighting.FogEnd = renderDefaults.Fog
				renderDefaults = nil
			end
		end
		MenuGroup:AddToggle("AntiGameplayPause", { Text = "No Gameplay Paused", Default = true })
		MenuGroup:AddToggle("AutoReconnect", { Text = "Auto Reconnect on Kick", Default = false })
		MenuGroup:AddToggle("Disable3D", {
			Text = "Disable 3D Rendering",
			Default = false,
			Callback = function(value)
				pcall(function()
					RunService:Set3dRenderingEnabled(not value)
				end)
			end,
		})
		MenuGroup:AddToggle("FpsBoost", {
			Text = "FPS Boost",
			Default = false,
			Callback = function(value)
				if value then
					if not renderDefaults then
						renderDefaults = {
							Quality = settings().Rendering.QualityLevel,
							Shadows = Lighting.GlobalShadows,
							Fog = Lighting.FogEnd,
						}
					end
					pcall(function()
						settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
					end)
					Lighting.GlobalShadows = false
					Lighting.FogEnd = 9e9
					for _, instance in Workspace:QueryDescendants("ParticleEmitter,Trail,Smoke,Fire,Sparkles,Beam") do
						pcall(stripEffect, instance)
					end
				else
					restoreEffects()
				end
			end,
		})
		MenuGroup:AddToggle("HideUiOnStart", { Text = "Hide UI On Start", Default = false })
		MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
			Default = "RightShift",
			NoUI = true,
			Text = "Menu keybind",
		})
		Library.ToggleKeybind = Options.MenuKeybind
		applyPause(true)
		local ScriptGroup = Tabs.Settings:AddLeftGroupbox("Script", "terminal")
		ScriptGroup:AddButton({
			Text = "Unload Script",
			Func = function()
				Library:Unload()
			end,
		})
		Toggles.AntiGameplayPause:OnChanged(function()
			applyPause(Toggles.AntiGameplayPause.Value)
		end)
		if Toggles.AntiGameplayPause.Value then
			applyPause(true)
		end
		table.insert(connections, LocalPlayer.Idled:Connect(function()
			if Toggles.AntiAfk.Value and not Library.Unloaded then
				pulse()
			end
		end))
		table.insert(connections, Workspace.DescendantAdded:Connect(function(instance)
			if Toggles.FpsBoost.Value then
				stripEffect(instance)
			end
		end))
		local function rejoin(fresh)
			if reconnecting or Library.Unloaded or not Toggles.AutoReconnect.Value then
				return
			end
			reconnecting = true
			local token = reconnectToken
			local ok = pcall(function()
				if fresh then
					TeleportService:Teleport(game.PlaceId, LocalPlayer)
				else
					TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
				end
			end)
			if not ok then
				reconnecting = false
				if not fresh and token == reconnectToken then
					task.delay(1.5, function()
						if token == reconnectToken then
							rejoin(true)
						end
					end)
				end
			end
		end
		table.insert(connections, TeleportService.TeleportInitFailed:Connect(function(player)
			if player == LocalPlayer and reconnecting then
				reconnecting = false
				local token = reconnectToken
				task.delay(3, function()
					if token == reconnectToken then
						rejoin(true)
					end
				end)
			end
		end))
		task.spawn(function()
			local promptGui = CoreGui:WaitForChild("RobloxPromptGui", 30)
			local overlay = promptGui and promptGui:WaitForChild("promptOverlay", 30)
			if Library.Unloaded or not overlay then
				return
			end
			table.insert(connections, overlay.ChildAdded:Connect(function(child)
				if child.Name == "ErrorPrompt" then
					rejoin(false)
				end
			end))
		end)
		local menuTask = task.spawn(function()
			while not Library.Unloaded do
				if Toggles.AntiGameplayPause.Value then
					applyPause(true)
				end
				if Toggles.AntiAfk.Value and os.clock() - lastPulse >= 60 then
					pulse()
				end
				task.wait(1)
			end
		end)
		API.Track(function()
			reconnectToken += 1
			for _, connection in connections do
				connection:Disconnect()
			end
			pcall(task.cancel, menuTask)
			applyPause(false)
			restoreEffects()
			pcall(function()
				RunService:Set3dRenderingEnabled(true)
			end)
		end)
	end
	setupSettings()
	local function setupConfigExport()
		ThemeManager:SetLibrary(Library)
		ThemeManager:SetFolder("OuroborosHub")
		ThemeManager:SaveDefault("Evil Hello Kitty")
		ThemeManager:ApplyToTab(Tabs.Settings)
		SaveManager:SetLibrary(Library)
		SaveManager:IgnoreThemeSettings()
		SaveManager:SetIgnoreIndexes({ "MenuKeybind", "SaveManager_ImportSource" })
		SaveManager:SetFolder("OuroborosHub/RaceForEggs")
		local ConfigurationBox = SaveManager:BuildConfigSection(Tabs.Settings)
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
					if type(element) == "table" and type(element.Type) == "string" and not SaveManager.Ignore[index] then
						local encoded = encodeConfigObject(index, element)
						if encoded then
							objects[#objects + 1] = encoded
						end
					end
				end
			end
			table.sort(objects, function(a, b)
				if a.type ~= b.type then
					return a.type < b.type
				end
				return a.idx < b.idx
			end)
			return { objects = objects }
		end
		local function applyConfigObject(object)
			if type(object) ~= "table" or type(object.idx) ~= "string" or type(object.type) ~= "string" or SaveManager.Ignore[object.idx] then
				return false
			end
			local element = configElement(object.type, object.idx)
			if not element then
				return false
			end
			local applied = pcall(function()
				if object.type == "Input" then
					if type(object.text) ~= "string" then
						return
					end
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
			if encodeSuccess then
				local writeClipboard = callable(setclipboard) and setclipboard or (callable(toclipboard) and toclipboard or nil)
				if type(writeClipboard) == "function" and pcall(writeClipboard, encoded) then
					Library:Notify("Config copied to clipboard", 6)
					return
				end
				Library:Notify("Your executor does not support copying to the clipboard")
				return
			end
			Library:Notify("Failed to encode the config")
		end)
		ConfigurationBox:AddButton("Import Config from Clipboard Text", function()
			local source = tostring(Options.SaveManager_ImportSource.Value or ""):match("^%s*(.-)%s*$")
			if source == "" then
				Library:Notify("Paste an exported config into the box first")
				return
			end
			if #source > 262144 then
				Library:Notify("That config is too large")
				return
			end
			local decodeSuccess, decoded = pcall(HttpService.JSONDecode, HttpService, source)
			if not decodeSuccess or type(decoded) ~= "table" or type(decoded.objects) ~= "table" then
				Library:Notify("That is not a valid exported config")
				return
			end
			if #decoded.objects > 2048 then
				Library:Notify("That config has too many records")
				return
			end
			local applied = 0
			for _, object in ipairs(decoded.objects) do
				if applyConfigObject(object) then
					applied += 1
				end
			end
			if applied == 0 then
				Library:Notify("No settings in that config matched this script")
				return
			end
			Options.SaveManager_ImportSource:SetValue("")
			Library:Notify(("Imported %d setting%s"):format(applied, applied == 1 and "" or "s"), 6)
		end)
		ThemeManager:LoadDefault()
		SaveManager:LoadAutoloadConfig()
		if Options.TapDelay then
			TapController.SetDelay(Options.TapDelay.Value)
		end
		if Options.TrainDelay then
			TrainController.SetDelay(Options.TrainDelay.Value)
		end
		if Options.BonusDelay then
			BonusController.SetDelay(Options.BonusDelay.Value)
		end
		if Options.PlaceEggDelay then
			PlaceEggController.SetDelay(Options.PlaceEggDelay.Value)
		end
		if Options.HatchDelay then
			HatchController.SetDelay(Options.HatchDelay.Value)
		end
		if Options.RebirthDelay then
			RebirthController.SetDelay(Options.RebirthDelay.Value)
		end
		if Options.EquipBestDelay then
			EquipBestController.SetDelay(Options.EquipBestDelay.Value)
		end
		if Options.SellDelay then
			SellController.SetDelay(Options.SellDelay.Value)
		end
		if Options.SellBrainrots then
			SellController.SetBrainrots(Options.SellBrainrots.Value)
		end
		if Options.SellRarities then
			SellController.SetRarities(Options.SellRarities.Value)
		end
		if Options.SellMutations then
			SellController.SetMutations(Options.SellMutations.Value)
		end
		if Options.SellSizes then
			SellController.SetSizes(Options.SellSizes.Value)
		end
		if Toggles.SellEggsToo then
			SellController.SetSellEggs(Toggles.SellEggsToo.Value)
		end
		if Options.WeightDelay then
			WeightController.SetDelay(Options.WeightDelay.Value)
		end
		if Options.WeightList then
			WeightController.SetAllowed(Options.WeightList.Value)
		end
		if Options.WeightMaxCost then
			WeightController.SetMaxCost(Options.WeightMaxCost.Value)
		end
		if Options.DiceDelay then
			DiceController.SetDelay(Options.DiceDelay.Value)
		end
		if Options.DiceList then
			DiceController.SetAllowed(Options.DiceList.Value)
		end
		if Options.DiceMaxCost then
			DiceController.SetMaxCost(Options.DiceMaxCost.Value)
		end
		if Toggles.DailyIncludeVip then
			DailyController.SetIncludeVip(Toggles.DailyIncludeVip.Value)
		end
		if Toggles.AutoRace then
			RaceController.SetEnabled(Toggles.AutoRace.Value)
		end
		if Toggles.AutoTap then
			TapController.SetEnabled(Toggles.AutoTap.Value)
		end
		if Toggles.AutoTrain then
			TrainController.SetEnabled(Toggles.AutoTrain.Value)
		end
		if Toggles.AutoBonus then
			BonusController.SetEnabled(Toggles.AutoBonus.Value)
		end
		if Toggles.AutoPlaceEggs then
			PlaceEggController.SetEnabled(Toggles.AutoPlaceEggs.Value)
		end
		if Toggles.AutoHatchEggs then
			HatchController.SetEnabled(Toggles.AutoHatchEggs.Value)
		end
		if Toggles.AutoRebirth then
			RebirthController.SetEnabled(Toggles.AutoRebirth.Value)
		end
		if Toggles.AutoEquipBest then
			EquipBestController.SetEnabled(Toggles.AutoEquipBest.Value)
		end
		if Toggles.AutoSell then
			SellController.SetEnabled(Toggles.AutoSell.Value)
		end
		if Toggles.AutoBuyWeights then
			WeightController.SetEnabled(Toggles.AutoBuyWeights.Value)
		end
		if Toggles.AutoBuyDice then
			DiceController.SetEnabled(Toggles.AutoBuyDice.Value)
		end
		if Toggles.AutoPlaytime then
			PlaytimeController.SetEnabled(Toggles.AutoPlaytime.Value)
		end
		if Toggles.AutoEventPass then
			EventPassController.SetEnabled(Toggles.AutoEventPass.Value)
		end
		if Toggles.AutoDaily then
			DailyController.SetEnabled(Toggles.AutoDaily.Value)
		end
		if Toggles.HideUiOnStart.Value then
			Library:Toggle(false)
		end
	end
	setupConfigExport()
end

prewarmGameModules()
setupInterface()
