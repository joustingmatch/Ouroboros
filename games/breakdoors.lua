local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local GAME_NAME = "Break Door"
local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"
local RSCRIPTS_LINK = "https://rscripts.net/@Ouroboros"

local Knit = require(ReplicatedStorage:WaitForChild("CommonComponents"):WaitForChild("Packages"):WaitForChild("Knit"))
local ClientCommParameterValidation = require(ReplicatedStorage.CommonComponents.Tool.ClientCommParameterValidation)
local CfgParameterValidationType = require(ReplicatedStorage.CommonConfig.BaseConfig.CfgParameterValidationType)
local CfgPlot = require(ReplicatedStorage.CommonConfig.Plot.CfgPlot)
local CfgLaboratory = require(ReplicatedStorage.CommonConfig.Laboratory.CfgLaboratory)

Knit.OnStart():await()

local PlotController = Knit.GetController("PlotController")
local PlotService = Knit.GetService("PlotService")
local AirdropService = Knit.GetService("AirdropService")
local RoomController = Knit.GetController("RoomController")
local RoundManagerController = Knit.GetController("RoundManagerController")
local SkillController = Knit.GetController("SkillController")
local HunterAttributeService = Knit.GetService("HunterAttributeService")
local HunterService = Knit.GetService("HunterService")
local TaskService = Knit.GetService("TaskService")
local HumanClassService = Knit.GetService("HumanClassService")
local HunterInventoryService = Knit.GetService("HunterInventoryService")
local LaboratoryService = Knit.GetService("LaboratoryService")

local HUNTER_STAT_KEYS = { "Attack", "HP", "Lucky" }
local hunterAttackActive = false

local RESEARCH_NAMES = {}
local RESEARCH_BY_NAME = {}
do
	for _, key in ipairs(CfgLaboratory.OrderedProjectKeys or {}) do
		local project = CfgLaboratory.GetProject(key)
		if type(project) == "table" and project.Enabled ~= false then
			local label = tostring(project.DisplayName or key)
			if not RESEARCH_BY_NAME[label] then
				RESEARCH_NAMES[#RESEARCH_NAMES + 1] = label
				RESEARCH_BY_NAME[label] = {
					ProjectKey = key,
					LineKey = project.LineKey,
					SlotType = project.SlotType,
				}
			end
		end
	end
end

local RESEARCH_LINE_NAMES = {}
local RESEARCH_LINE_BY_NAME = {}
do
	for _, key in ipairs(CfgLaboratory.OrderedLineKeys or {}) do
		local line = CfgLaboratory.GetLine(key)
		if type(line) == "table" and line.Enabled ~= false then
			local label = tostring(line.DisplayName or key)
			if not RESEARCH_LINE_BY_NAME[label] then
				RESEARCH_LINE_NAMES[#RESEARCH_LINE_NAMES + 1] = label
				RESEARCH_LINE_BY_NAME[label] = key
			end
		end
	end
end

local repo = "https://raw.githubusercontent.com/joustingmatch/ObsidianUltra/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
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

local LTC_ADDRESS = "LSZPqKSsD1x6QXea2H8JS17nXMLnmtew3w"
local BTC_ADDRESS = "bc1qwc9exvcn3ykjqnsa0t9gakuccr494ljjuuqj99"
local ETH_ADDRESS = "0xaE95A405D007a6F858E5d35714111B075fEFb40a"
local USDT_ADDRESS = "0xaE95A405D007a6F858E5d35714111B075fEFb40a"
local SOL_ADDRESS = "Hq5jPHKDKjyHhccc6UULcbYTK6aKBBbTDmHNRXGKBKGp"
local PAYPAL_LINK = "https://paypal.me/TheTruckerGOD"
local VENMO_LINK = "https://venmo.com/u/miserablemusic"

local LTC = "#345d9d"
local BTC = "#f7931a"
local ETH = "#627eea"
local USDT = "#26a17b"
local SOL = "#14f195"
local PAYPAL = "#0070ba"
local VENMO = "#008cff"

local SURVIVOR_COLOR = Color3.fromRGB(80, 160, 255)
local HUNTER_COLOR = Color3.fromRGB(255, 105, 180)

local function isOn(name)
	if Library.Unloaded then
		return false
	end
	local toggle = Toggles[name]
	return type(toggle) == "table" and toggle.Value == true
end

local function getHumanoid()
	local character = LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHead(model)
	if not model then
		return nil
	end
	return model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
end

local function isAliveCharacter(character)
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil and root ~= nil and humanoid.Health > 0
end

local function serializePositiveInteger(value)
	return ClientCommParameterValidation:SerializeVariable(CfgParameterValidationType.PositiveInteger, value)
end

local function getTmpl(tmplId)
	if tmplId == nil then
		return nil
	end
	return CfgPlot.TmplInfo[tmplId] or CfgPlot.TmplInfo[tostring(tmplId)]
end

local function getLogicType(tmplId)
	local tmpl = getTmpl(tmplId)
	return tmpl and tmpl.LogicType or nil
end

local function getMyTeam()
	local ok, team = pcall(function()
		return RoundManagerController:GetMyTeam()
	end)
	if ok then
		return team
	end
	return nil
end

local function getTeamKeyForPlayer(player)
	local ok, key = pcall(function()
		return RoundManagerController:GetTeamKeyForPlayer(player.UserId)
	end)
	if ok and type(key) == "string" then
		return key
	end
	local character = player.Character
	if character then
		local group = character:GetAttribute("_CollisionGroup")
		if group == "HunterPlayer" then
			return "Team_2"
		elseif group == "HumanPlayer" then
			return "Team_1"
		end
	end
	return nil
end

local function isHumanTeam()
	return getMyTeam() == "Team_1"
end

local function isHunterTeam()
	return getMyTeam() == "Team_2"
end

local function getHunterAttackRange()
	local ok, snap = pcall(function()
		return HunterService:GetHunterSnapshot():expect()
	end)
	if ok and type(snap) == "table" then
		local range = tonumber(snap.AttackRange)
		if range and range > 0 then
			return range
		end
	end
	return 2
end

local function getAllDoorPlots()
	local ok, plots = pcall(function()
		return PlotController:GetAllPlots()
	end)
	if not ok or type(plots) ~= "table" then
		return {}
	end
	local doors = {}
	for _, plot in pairs(plots) do
		if type(plot) == "table"
			and plot.Destroyed ~= true
			and getLogicType(plot.TmplId) == "Door"
			and typeof(plot.CFrame) == "CFrame"
		then
			doors[#doors + 1] = plot
		end
	end
	return doors
end

local function getDoorWorldCFrame(plot)
	if type(plot) ~= "table" or type(plot.UniqueId) ~= "number" then
		return nil
	end
	local ok, part = pcall(function()
		return PlotController:GetPlotPart(plot.UniqueId)
	end)
	if ok and part and part:IsA("BasePart") then
		return part.CFrame
	end
	if typeof(plot.CFrame) == "CFrame" then
		return plot.CFrame
	end
	return nil
end

local function getNearestDoorCFrame(fromPos)
	local bestCf = nil
	local bestDist = math.huge
	for _, plot in ipairs(getAllDoorPlots()) do
		local cf = getDoorWorldCFrame(plot)
		if cf then
			local dist = (cf.Position - fromPos).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestCf = cf
			end
		end
	end
	return bestCf, bestDist
end

local function getNearestSurvivorRoot(fromPos)
	local bestRoot = nil
	local bestDist = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and getTeamKeyForPlayer(player) == "Team_1" then
			local character = player.Character
			if isAliveCharacter(character) then
				local root = character:FindFirstChild("HumanoidRootPart")
				if root then
					local dist = (root.Position - fromPos).Magnitude
					if dist < bestDist then
						bestDist = dist
						bestRoot = root
					end
				end
			end
		end
	end
	return bestRoot, bestDist
end

local function ensureHunterAutoAttack(enabled)
	pcall(function()
		SkillController:SetAutoNormalAttackEnabled(enabled == true)
	end)
	if enabled then
		if not hunterAttackActive then
			hunterAttackActive = true
			pcall(function()
				SkillController:BeginNormalAttack()
			end)
		else
			pcall(function()
				SkillController:_TryUseNormalAttack()
			end)
		end
	elseif hunterAttackActive then
		hunterAttackActive = false
		pcall(function()
			SkillController:EndNormalAttack()
		end)
	end
end

local function getLocalPlots()
	local ok, plots = pcall(function()
		return PlotController:GetLocalPlayerPlots()
	end)
	if ok and type(plots) == "table" then
		return plots
	end
	return {}
end

local function getPlotsByLogic(logicType)
	local matched = {}
	for _, plot in pairs(getLocalPlots()) do
		if type(plot) == "table" and getLogicType(plot.TmplId) == logicType then
			matched[#matched + 1] = plot
		end
	end
	return matched
end

local cachedSafeRoomCFrame = nil

local function getLocalRoomInfo()
	local ok, room = pcall(function()
		return RoomController:GetLocalPlayerRoom()
	end)
	if ok and type(room) == "table" and type(room.RoomId) == "number" then
		return room
	end
	return nil
end

local function getRoomModel()
	local room = getLocalRoomInfo()
	if not room then
		return nil, nil
	end
	local folder = Workspace:FindFirstChild("RoomFolder")
	if not folder then
		return nil, room
	end
	local model = folder:FindFirstChild("Room_" .. tostring(room.RoomId))
	return model, room
end

local function getSafeRoomCFrame()
	local model = getRoomModel()
	if model then
		local part = model:FindFirstChild("Center") or model:FindFirstChild("SpawnPoint")
		if part and part:IsA("BasePart") then
			cachedSafeRoomCFrame = part.CFrame + Vector3.new(0, 3, 0)
			return cachedSafeRoomCFrame
		end
	end

	local sum = Vector3.zero
	local count = 0
	local doorCf = nil
	for _, plot in pairs(getLocalPlots()) do
		if type(plot) == "table" and typeof(plot.CFrame) == "CFrame" then
			sum += plot.CFrame.Position
			count += 1
			if getLogicType(plot.TmplId) == "Door" then
				doorCf = plot.CFrame
			end
		end
	end
	if doorCf then
		cachedSafeRoomCFrame = doorCf + Vector3.new(0, 5, 0)
		return cachedSafeRoomCFrame
	end
	if count > 0 then
		cachedSafeRoomCFrame = CFrame.new(sum / count + Vector3.new(0, 5, 0))
		return cachedSafeRoomCFrame
	end

	return cachedSafeRoomCFrame
end

local function teleportToCFrame(target)
	local character = LocalPlayer.Character
	local root = getRoot()
	if not character or not root or typeof(target) ~= "CFrame" then
		return false
	end
	if character.PivotTo then
		character:PivotTo(target)
	else
		root.CFrame = target
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

local function moveHunterToTarget(targetPos, standDistance)
	local root = getRoot()
	local character = LocalPlayer.Character
	if not root or not character or typeof(targetPos) ~= "Vector3" then
		return false
	end
	local offset = standDistance or 1.5
	local flat = Vector3.new(targetPos.X - root.Position.X, 0, targetPos.Z - root.Position.Z)
	local dir = flat.Magnitude > 0.05 and flat.Unit or root.CFrame.LookVector
	local dest = CFrame.new(targetPos - dir * offset + Vector3.new(0, 3, 0), targetPos)
	return teleportToCFrame(dest)
end

local function runHunterCombat()
	if not isHunterTeam() then
		if hunterAttackActive then
			ensureHunterAutoAttack(false)
		end
		return
	end

	local breakDoors = isOn("AutoBreakDoors")
	local killPeople = isOn("AutoKillSurvivors")
	if not breakDoors and not killPeople then
		ensureHunterAutoAttack(false)
		return
	end

	local root = getRoot()
	if not root then
		return
	end

	local range = getHunterAttackRange()
	local approach = math.max(1.2, range * 0.75)
	local chosenPos = nil

	if killPeople then
		local survivorRoot = getNearestSurvivorRoot(root.Position)
		if survivorRoot then
			chosenPos = survivorRoot.Position
		end
	end

	if chosenPos == nil and breakDoors then
		local doorCf = getNearestDoorCFrame(root.Position)
		if doorCf then
			chosenPos = doorCf.Position
		end
	end

	if chosenPos == nil then
		ensureHunterAutoAttack(true)
		return
	end

	local dist = (root.Position - chosenPos).Magnitude
	if dist > range + 0.75 then
		moveHunterToTarget(chosenPos, approach)
	end
	ensureHunterAutoAttack(true)
end

local function runHunterUpgrades()
	if not isHunterTeam() or not isOn("AutoHunterUpgradeAll") then
		return
	end
	for _, statKey in ipairs(HUNTER_STAT_KEYS) do
		pcall(function()
			HunterAttributeService:Upgrade(statKey):expect()
		end)
		task.wait(0.05)
	end
end

local function claimDailyTasks()
	local ok, result = pcall(function()
		return TaskService:GetDayTaskSnapshot():expect()
	end)
	if not ok or type(result) ~= "table" or result.Success ~= true then
		return
	end
	local snapshot = result.Snapshot
	local tasks = snapshot and snapshot.Tasks
	if type(tasks) ~= "table" then
		return
	end
	for _, taskInfo in ipairs(tasks) do
		if type(taskInfo) == "table"
			and taskInfo.Completed == true
			and taskInfo.Claimed ~= true
			and taskInfo.TaskId ~= nil
		then
			pcall(function()
				TaskService:ClaimDayTask(taskInfo.TaskId):expect()
			end)
			task.wait(0.1)
		end
	end
end

local function unlockClasses()
	local okHunter, hunterInv = pcall(function()
		return HunterInventoryService:GetHunterInventory():expect()
	end)
	if okHunter and type(hunterInv) == "table" then
		local owned = hunterInv.OwnedHunters or {}
		local catalog = hunterInv.Catalog
		if type(catalog) == "table" then
			for _, entry in ipairs(catalog) do
				if type(entry) == "table"
					and type(entry.TmplId) == "string"
					and entry.UnlockKind == "Value"
					and owned[entry.TmplId] ~= true
				then
					pcall(function()
						HunterInventoryService:BuyHunter(entry.TmplId):expect()
					end)
					task.wait(0.1)
				end
			end
		end
		local classProgress = hunterInv.ClassProgress or {}
		local hunterClassCfg = require(ReplicatedStorage.CommonConfig.Hunter.CfgHunterClass)
		local ordered = hunterClassCfg.GetOrderedClasses and hunterClassCfg.GetOrderedClasses() or {}
		for _, classInfo in ipairs(ordered) do
			local classId = type(classInfo) == "table" and tostring(classInfo.ClassId or "") or nil
			if classId and classId ~= "" and classProgress[classId] == nil then
				pcall(function()
					HunterInventoryService:UnlockHunterClass(classId):expect()
				end)
				task.wait(0.05)
			end
		end
	end

	local okHuman, humanInv = pcall(function()
		return HumanClassService:GetHumanClassInventory():expect()
	end)
	if okHuman and type(humanInv) == "table" then
		local owned = humanInv.OwnedClasses or {}
		local catalog = humanInv.Catalog
		if type(catalog) == "table" then
			for _, entry in ipairs(catalog) do
				if type(entry) == "table"
					and type(entry.ClassId) == "string"
					and entry.Enabled == true
					and owned[entry.ClassId] ~= true
					and entry.UnlockKind ~= "Disabled"
					and entry.UnlockKind ~= "Default"
				then
					pcall(function()
						HumanClassService:UnlockHumanClass(entry.ClassId):expect()
					end)
					task.wait(0.1)
				end
			end
		end
	end
end

local function runLobbyFeatures()
	if isOn("AutoClaimDailyTasks") then
		claimDailyTasks()
	end
	if isOn("AutoUnlockClasses") then
		unlockClasses()
	end
end

local function unlockPlot(uniqueId)
	local ok, result = pcall(function()
		local serialized = serializePositiveInteger(uniqueId)
		return PlotService:Unlock(serialized):expect()
	end)
	return ok and result == true
end

local function upgradePlot(uniqueId)
	local ok, result = pcall(function()
		local serialized = serializePositiveInteger(uniqueId)
		return PlotService:Upgrade(serialized):expect()
	end)
	return ok and result == true
end

local function unlockOrUpgradeByLogic(logicType)
	for _, plot in ipairs(getPlotsByLogic(logicType)) do
		local uniqueId = plot.UniqueId
		if type(uniqueId) ~= "number" then
			continue
		end
		if plot.Unlocked ~= true then
			unlockPlot(uniqueId)
		else
			local tmpl = getTmpl(plot.TmplId)
			if tmpl and tmpl.NextUpdatePlotTmplId then
				upgradePlot(uniqueId)
			end
		end
	end
end

local function getLaboratoryPlot()
	local plots = getPlotsByLogic("Laboratory")
	return plots[1]
end

local function getLaboratoryUniqueId()
	local plot = getLaboratoryPlot()
	if plot and type(plot.UniqueId) == "number" then
		return plot.UniqueId
	end
	return nil
end

local function goToLaboratory(force)
	local plot = getLaboratoryPlot()
	if not plot or typeof(plot.CFrame) ~= "CFrame" then
		return false
	end
	local root = getRoot()
	if not root then
		return false
	end
	local target = plot.CFrame + Vector3.new(0, 3, 0)
	if force or (root.Position - target.Position).Magnitude > 10 then
		return teleportToCFrame(target)
	end
	return true
end

local function ensureLaboratoryUnlocked()
	for _, plot in ipairs(getPlotsByLogic("Laboratory")) do
		if plot.Unlocked ~= true and type(plot.UniqueId) == "number" then
			goToLaboratory(true)
			unlockPlot(plot.UniqueId)
		end
	end
end

local function getGuideRoomId()
	local ok, roomId = pcall(function()
		return RoomController:GetLocalRoomGuideReservation()
	end)
	if ok and type(roomId) == "number" then
		return roomId
	end
	return nil
end

local function getRoomModelById(roomId)
	if type(roomId) ~= "number" then
		return nil
	end
	local ok, model = pcall(function()
		return RoomController:GetRoomModel(roomId)
	end)
	if ok and model then
		return model
	end
	local folder = Workspace:FindFirstChild("RoomFolder")
	if not folder then
		return nil
	end
	return folder:FindFirstChild("Room_" .. tostring(roomId))
end

local function getRoomCFrame(roomId)
	local model = getRoomModelById(roomId)
	if not model then
		return nil
	end
	local part = model:FindFirstChild("Center") or model:FindFirstChild("SpawnPoint")
	if part and part:IsA("BasePart") then
		return part.CFrame + Vector3.new(0, 3, 0)
	end
	if model:IsA("Model") then
		return model:GetPivot() + Vector3.new(0, 3, 0)
	end
	return nil
end

local function getUnlockTargetRoomId()
	local room = getLocalRoomInfo()
	if room and room.Status == "Occupied" and type(room.RoomId) == "number" then
		return nil
	end
	local guideId = getGuideRoomId()
	if guideId then
		return guideId
	end
	local ok, empties = pcall(function()
		return RoomController:GetEmptyRooms()
	end)
	if ok and type(empties) == "table" then
		for _, empty in ipairs(empties) do
			if type(empty) == "table" and type(empty.RoomId) == "number" then
				return empty.RoomId
			end
		end
	end
	return nil
end

local function runAutoUnlockBase()
	if not isOn("AutoUnlockBase") or not isHumanTeam() then
		return false
	end
	local room = getLocalRoomInfo()
	if room and room.Status == "Occupied" then
		return false
	end
	local roomId = getUnlockTargetRoomId()
	if not roomId then
		return false
	end
	local target = getRoomCFrame(roomId)
	if typeof(target) == "CFrame" then
		teleportToCFrame(target)
		task.wait(0.15)
	end
	pcall(function()
		RoomController:OccupyRoom(roomId)
	end)
	return true
end

local function getSelectedResearchList()
	local option = Options.ResearchProject
	if type(option) ~= "table" then
		return {}
	end
	local value = option.Value
	local selected = {}
	if type(value) == "table" then
		for name, enabled in pairs(value) do
			if enabled and RESEARCH_BY_NAME[name] then
				selected[#selected + 1] = RESEARCH_BY_NAME[name]
			end
		end
	elseif type(value) == "string" and value ~= "" and RESEARCH_BY_NAME[value] then
		selected[1] = RESEARCH_BY_NAME[value]
	end
	return selected
end

local function getSelectedResearchFieldKey()
	local option = Options.ResearchField
	if type(option) ~= "table" then
		return nil
	end
	local name = tostring(option.Value or "")
	return RESEARCH_LINE_BY_NAME[name]
end

local function isResearchInProgress(projects, projectKey)
	if type(projects) ~= "table" or type(projectKey) ~= "string" then
		return false
	end
	local info = projects[projectKey] or projects[tostring(projectKey)]
	if type(info) ~= "table" then
		return false
	end
	local status = info.Status or info.ProjectStatus or info.State
	return status == "IN_PROGRESS" or status == CfgLaboratory.ProjectStatus.InProgress
end

local function runAutoChooseResearchField()
	if not isOn("AutoChooseResearchField") or not isHumanTeam() then
		return
	end
	local lineKey = getSelectedResearchFieldKey()
	if type(lineKey) ~= "string" or lineKey == "" then
		return
	end
	ensureLaboratoryUnlocked()
	local uniqueId = getLaboratoryUniqueId()
	if type(uniqueId) ~= "number" then
		return
	end
	goToLaboratory(false)
	pcall(function()
		LaboratoryService:SelectResearchLine(lineKey, uniqueId):expect()
	end)
end

local function runAutoResearch()
	if not isOn("AutoResearchLab") or not isHumanTeam() then
		return
	end
	local selectedList = getSelectedResearchList()
	if #selectedList == 0 then
		return
	end

	ensureLaboratoryUnlocked()
	local uniqueId = getLaboratoryUniqueId()
	if type(uniqueId) ~= "number" then
		return
	end
	goToLaboratory(false)

	local okState, state = pcall(function()
		return LaboratoryService:RequestState(uniqueId):expect()
	end)
	local projects = nil
	if okState and type(state) == "table" and state.Success == true then
		local data = state.Data or state
		projects = data.Projects or data.ProjectStates or data.projects
	end

	for _, selected in ipairs(selectedList) do
		if type(selected.ProjectKey) ~= "string" then
			continue
		end
		if isResearchInProgress(projects, selected.ProjectKey) then
			continue
		end
		if type(selected.LineKey) == "string" and selected.LineKey ~= "" then
			pcall(function()
				LaboratoryService:SelectResearchLine(selected.LineKey, uniqueId):expect()
			end)
		end
		pcall(function()
			LaboratoryService:StartResearch(selected.ProjectKey, uniqueId):expect()
		end)
		task.wait(0.1)
	end
end

local function healDoor()
	local doors = getPlotsByLogic("Door")
	local door = doors[1]
	if not door or type(door.UniqueId) ~= "number" then
		return
	end
	local okCd, cd = pcall(function()
		return PlotService:GetRepairCooldownState():expect()
	end)
	if okCd and type(cd) == "table" and type(cd.Own) == "table" then
		local remaining = tonumber(cd.Own.remaining) or 0
		if remaining > 0.05 then
			return
		end
	end
	local serialized = serializePositiveInteger(door.UniqueId)
	pcall(function()
		PlotService:StartRepair(serialized):expect()
	end)
end

local function goToSafeRoom(force)
	local target = getSafeRoomCFrame()
	if typeof(target) ~= "CFrame" then
		return false
	end
	local root = getRoot()
	if not root then
		return false
	end
	if force or (root.Position - target.Position).Magnitude > 6 then
		return teleportToCFrame(target)
	end
	return true
end

local function getAirdropBoxes()
	local folder = Workspace:FindFirstChild("AirdropFolder")
	if not folder then
		return {}
	end
	local boxes = {}
	local seen = {}
	local function consider(inst)
		if seen[inst] then
			return
		end
		local boxId = inst:GetAttribute("BoxId")
		if boxId == nil then
			boxId = inst:GetAttribute("UniqueId")
		end
		if boxId == nil then
			return
		end
		seen[inst] = true
		boxes[#boxes + 1] = {
			Instance = inst,
			BoxId = boxId,
		}
	end
	for _, child in ipairs(folder:GetChildren()) do
		consider(child)
		for _, desc in ipairs(child:GetDescendants()) do
			if desc:GetAttribute("BoxId") ~= nil then
				consider(desc:FindFirstAncestorOfClass("Model") or child)
				break
			end
		end
	end
	return boxes
end

local function lootAirdropBox(box)
	local inst = box.Instance
	local pivot = inst:IsA("Model") and inst:GetPivot() or (inst:IsA("BasePart") and inst.CFrame)
	if pivot then
		local root = getRoot()
		if root and (root.Position - pivot.Position).Magnitude > 12 then
			teleportToCFrame(pivot + Vector3.new(0, 3, 0))
			task.wait(0.15)
		end
	end
	pcall(function()
		AirdropService:LootBox(box.BoxId):expect()
	end)
end

local function collectAirdrops()
	local boxes = getAirdropBoxes()
	if #boxes == 0 then
		return false
	end
	for _, box in ipairs(boxes) do
		if Library.Unloaded or not isOn("AutoCollectAirdrops") then
			break
		end
		lootAirdropBox(box)
		task.wait(0.2)
	end
	return true
end

local function canUseSafeRoom()
	return getLocalRoomInfo() ~= nil or isHumanTeam() or cachedSafeRoomCFrame ~= nil
end

local function runSafeRoomOrAirdrop()
	if runAutoUnlockBase() then
		return
	end

	local collectOn = isOn("AutoCollectAirdrops")
	local safeOn = isOn("AutoSafeRoom")
	if not collectOn and not safeOn then
		return
	end

	if collectOn then
		local hadBoxes = collectAirdrops()
		if hadBoxes then
			if #getAirdropBoxes() == 0 and canUseSafeRoom() then
				goToSafeRoom(true)
			end
			return
		end
	end

	if safeOn and canUseSafeRoom() then
		goToSafeRoom(false)
	end
end

local espFolder = Instance.new("Folder")
espFolder.Name = "OuroborosBreakDoorESP"
espFolder.Parent = LocalPlayer:WaitForChild("PlayerGui")

local espObjects = {}

local function removeEsp(model)
	local entry = espObjects[model]
	if not entry then
		return
	end
	if entry.Highlight then
		entry.Highlight:Destroy()
	end
	if entry.Billboard then
		entry.Billboard:Destroy()
	end
	espObjects[model] = nil
end

local function updateEsp(model, color, text)
	local head = getHead(model)
	if not head then
		removeEsp(model)
		return
	end

	local entry = espObjects[model]
	if not entry then
		local highlight = Instance.new("Highlight")
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillTransparency = 0.65
		highlight.OutlineTransparency = 0
		highlight.Parent = espFolder

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(180, 20)
		billboard.StudsOffset = Vector3.new(0, 2.6, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = espFolder

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextStrokeTransparency = 0.35
		label.Parent = billboard

		entry = {
			Highlight = highlight,
			Billboard = billboard,
			Label = label,
		}
		espObjects[model] = entry
	end

	entry.Highlight.Adornee = model
	entry.Highlight.FillColor = color
	entry.Highlight.OutlineColor = color
	entry.Billboard.Adornee = head
	entry.Label.TextColor3 = color
	entry.Label.Text = text
end

local function clearEsp()
	for model in pairs(espObjects) do
		removeEsp(model)
	end
end

local function refreshEsp()
	if Library.Unloaded or not isOn("PlayerESP") then
		clearEsp()
		return
	end

	local alive = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and isAliveCharacter(player.Character) then
			local model = player.Character
			alive[model] = true
			local teamKey = getTeamKeyForPlayer(player)
			local color = teamKey == "Team_2" and HUNTER_COLOR or SURVIVOR_COLOR
			local tag = teamKey == "Team_2" and ("[Hunter] " .. player.Name) or ("[Survivor] " .. player.Name)
			updateEsp(model, color, tag)
		end
	end

	for model in pairs(espObjects) do
		if not alive[model] then
			removeEsp(model)
		end
	end
end

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
	Main = Window:AddTab("Main", "door-open"),
	Player = Window:AddTab("Player", "person-standing"),
	Settings = Window:AddTab("Settings", "settings"),
}

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
		copyText(joinScript, "Copied join script to clipboard")
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
FeaturesGroup:AddLabel(colored("Automation", BLUE), true)
FeaturesGroup:AddLabel(colored("Hunter", ORANGE), true)
FeaturesGroup:AddLabel(colored("Lobby", GREEN), true)
FeaturesGroup:AddLabel(colored("ESP", BLUE), true)
FeaturesGroup:AddLabel(colored("Player Utilities", GREY), true)

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

local AdGroup = Tabs.Info:AddLeftGroupbox("Ouroboros Hub", "sparkles")
AdGroup:AddLabel("Every script in the hub is keyless. No key systems, no checkpoints, no linkvertise.", true)
AdGroup:AddLabel("The Discord has ready made configs, dupe methods, giveaways, and early access to new scripts.", true)
AdGroup:AddLabel("Requests get taken seriously. A lot of what is in this script started as a Discord message.", true)
AdGroup:AddButton({
	Text = "Copy Discord Invite",
	Func = copyDiscord,
})

local DonationsGroup = Tabs.Info:AddRightGroupbox("Donations", "heart")
DonationsGroup:AddLabel(colored("All donations are optional but appreciated.", ORANGE), true)
DonationsGroup:AddLabel(colored("If you donate you get a special role, just PING after you donate.", GREEN), true)
DonationsGroup:AddDivider()
DonationsGroup:AddLabel(colored("LTC / Litecoin", LTC), true)
DonationsGroup:AddButton({
	Text = "Copy Litecoin Address",
	Func = function()
		copyText(LTC_ADDRESS, "Copied Litecoin address")
	end,
})
DonationsGroup:AddLabel(colored("BTC / Bitcoin", BTC), true)
DonationsGroup:AddButton({
	Text = "Copy Bitcoin Address",
	Func = function()
		copyText(BTC_ADDRESS, "Copied Bitcoin address")
	end,
})
DonationsGroup:AddLabel(colored("ETH / Ethereum", ETH), true)
DonationsGroup:AddButton({
	Text = "Copy Ethereum Address",
	Func = function()
		copyText(ETH_ADDRESS, "Copied Ethereum address")
	end,
})
DonationsGroup:AddLabel(colored("USDT", USDT), true)
DonationsGroup:AddButton({
	Text = "Copy USDT Address",
	Func = function()
		copyText(USDT_ADDRESS, "Copied USDT address")
	end,
})
DonationsGroup:AddLabel(colored("Solana", SOL), true)
DonationsGroup:AddButton({
	Text = "Copy Solana Address",
	Func = function()
		copyText(SOL_ADDRESS, "Copied Solana address")
	end,
})
DonationsGroup:AddLabel(colored("PayPal", PAYPAL), true)
DonationsGroup:AddButton({
	Text = "Copy PayPal Link",
	Func = function()
		copyText(PAYPAL_LINK, "Copied PayPal link")
	end,
})
DonationsGroup:AddLabel(colored("Venmo", VENMO), true)
DonationsGroup:AddButton({
	Text = "Copy Venmo Link",
	Func = function()
		copyText(VENMO_LINK, "Copied Venmo link")
	end,
})
DonationsGroup:AddDivider()
DonationsGroup:AddLabel(colored("Don't have any of the listed currencies but still wanna donate?", GREY), true)
DonationsGroup:AddLabel(colored("DM me and we'll work something out.", BLUE), true)

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

for _, Tab in pairs(Tabs) do
	if Tab ~= Tabs.Info then
		AddDiscordButton(Tab)
	end
end

local AutoGroup = Tabs.Main:AddLeftGroupbox("Automation", "bot")
AutoGroup:AddToggle("AutoUnlockBase", {
	Text = "Auto Unlock Base",
	Default = false,
})
AutoGroup:AddToggle("AutoSafeRoom", {
	Text = "Auto Safe Room",
	Default = false,
})
AutoGroup:AddToggle("AutoUpgradeDoor", {
	Text = "Auto Upgrade Door",
	Default = false,
})
AutoGroup:AddToggle("AutoBank", {
	Text = "Auto Unlock/Upgrade Bank",
	Default = false,
})
AutoGroup:AddToggle("AutoGuard", {
	Text = "Auto Unlock/Upgrade Guard",
	Default = false,
})
AutoGroup:AddToggle("AutoHealDoor", {
	Text = "Auto Heal Door",
	Default = false,
})
AutoGroup:AddToggle("AutoGoldMachine", {
	Text = "Auto Unlock/Upgrade Gold Machine",
	Default = false,
})
AutoGroup:AddToggle("AutoDecomposer", {
	Text = "Auto Unlock/Upgrade Decomposer",
	Default = false,
})
AutoGroup:AddToggle("AutoCollectAirdrops", {
	Text = "Auto Collect Airdrops",
	Default = false,
})
AutoGroup:AddToggle("AutoResearchLab", {
	Text = "Auto Research Lab",
	Default = false,
})
AutoGroup:AddToggle("AutoChooseResearchField", {
	Text = "Auto Choose Research Field",
	Default = false,
})
AutoGroup:AddDropdown("ResearchField", {
	Text = "Research Field",
	Values = #RESEARCH_LINE_NAMES > 0 and RESEARCH_LINE_NAMES or { "Armory Tech" },
	Default = (#RESEARCH_LINE_NAMES > 0 and RESEARCH_LINE_NAMES[1]) or "Armory Tech",
})
AutoGroup:AddDropdown("ResearchProject", {
	Text = "Research Project",
	Values = #RESEARCH_NAMES > 0 and RESEARCH_NAMES or { "Armory Research" },
	Default = {},
	Multi = true,
	AllowNull = true,
	Searchable = true,
})

local EspGroup = Tabs.Main:AddRightGroupbox("ESP", "eye")
EspGroup:AddToggle("PlayerESP", {
	Text = "Survivor/Hunter ESP",
	Default = false,
})

local HunterGroup = Tabs.Main:AddRightGroupbox("Hunter", "skull")
HunterGroup:AddToggle("AutoBreakDoors", {
	Text = "Auto Break Doors",
	Default = false,
})
HunterGroup:AddToggle("AutoKillSurvivors", {
	Text = "Auto Kill Survivors",
	Default = false,
})
HunterGroup:AddToggle("AutoHunterUpgradeAll", {
	Text = "Auto Upgrade All",
	Default = false,
})

local LobbyGroup = Tabs.Main:AddLeftGroupbox("Lobby", "house")
LobbyGroup:AddToggle("AutoClaimDailyTasks", {
	Text = "Auto Claim Daily Tasks",
	Default = false,
})
LobbyGroup:AddToggle("AutoUnlockClasses", {
	Text = "Auto Unlock Classes",
	Default = false,
})

Toggles.PlayerESP:OnChanged(function()
	if not Toggles.PlayerESP.Value then
		clearEsp()
	else
		refreshEsp()
	end
end)

local MovementGroup = Tabs.Player:AddLeftGroupbox("Movement", "footprints")
MovementGroup:AddToggle("WalkSpeedEnabled", {
	Text = "WalkSpeed",
	Default = false,
})
MovementGroup:AddSlider("WalkSpeed", {
	Text = "WalkSpeed Amount",
	Default = 32,
	Min = 16,
	Max = 250,
	Rounding = 0,
})
MovementGroup:AddToggle("InfJump", {
	Text = "Infinite Jump",
	Default = false,
})
MovementGroup:AddToggle("NoClip", {
	Text = "NoClip",
	Default = false,
})
MovementGroup:AddToggle("AntiGameplayPause", {
	Text = "No Gameplay Paused",
	Default = true,
})

local FlyGroup = Tabs.Player:AddRightGroupbox("Fly", "feather")
FlyGroup:AddToggle("Fly", {
	Text = "Fly",
	Default = false,
})
FlyGroup:AddSlider("FlySpeed", {
	Text = "Fly Speed",
	Default = 60,
	Min = 10,
	Max = 400,
	Rounding = 0,
})

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu")
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
	Default = "RightShift",
	NoUI = true,
	Text = "Menu keybind",
})
Library.ToggleKeybind = Options.MenuKeybind

MenuGroup:AddToggle("AntiAfk", {
	Text = "Anti-AFK",
	Default = true,
})

MenuGroup:AddButton({
	Text = "Unload",
	Func = function()
		Library:Unload()
	end,
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
	local camera = Workspace.CurrentCamera
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

RunService.Stepped:Connect(function()
	if Library.Unloaded then
		return
	end
	if Toggles.NoClip and Toggles.NoClip.Value then
		local character = LocalPlayer.Character
		if character then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end
	end
end)

UserInputService.JumpRequest:Connect(function()
	if Library.Unloaded then
		return
	end
	if Toggles.InfJump and Toggles.InfJump.Value then
		local humanoid = getHumanoid()
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end)

local Camera = Workspace.CurrentCamera

RunService.RenderStepped:Connect(function(dt)
	if Library.Unloaded then
		return
	end

	if Toggles.WalkSpeedEnabled and Toggles.WalkSpeedEnabled.Value then
		local humanoid = getHumanoid()
		if humanoid then
			humanoid.WalkSpeed = Options.WalkSpeed.Value
		end
	end

	if Toggles.Fly and Toggles.Fly.Value then
		local root = getRoot()
		local humanoid = getHumanoid()
		if root and humanoid then
			humanoid.PlatformStand = true
			local direction = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				direction = direction + Camera.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				direction = direction - Camera.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				direction = direction - Camera.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				direction = direction + Camera.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				direction = direction + Vector3.new(0, 1, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				direction = direction - Vector3.new(0, 1, 0)
			end
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
		if humanoid then
			humanoid.PlatformStand = false
		end
	end
end)

Toggles.WalkSpeedEnabled:OnChanged(function()
	if not Toggles.WalkSpeedEnabled.Value then
		local humanoid = getHumanoid()
		if humanoid then
			humanoid.WalkSpeed = 16
		end
	end
end)

local function applyAntiGameplayPause(enabled)
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

task.spawn(function()
	while not Library.Unloaded do
		task.wait(0.35)
		pcall(runSafeRoomOrAirdrop)
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		task.wait(1.25)
		pcall(runAutoChooseResearchField)
		pcall(runAutoResearch)
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		task.wait(1.1)
		if not isHumanTeam() then
			continue
		end
		pcall(runAutoUnlockBase)
		if isOn("AutoUpgradeDoor") then
			pcall(unlockOrUpgradeByLogic, "Door")
		end
		if isOn("AutoBank") then
			pcall(unlockOrUpgradeByLogic, "CashMachine")
		end
		if isOn("AutoGuard") then
			pcall(unlockOrUpgradeByLogic, "Turrent")
		end
		if isOn("AutoGoldMachine") then
			pcall(unlockOrUpgradeByLogic, "GearMachine")
		end
		if isOn("AutoDecomposer") then
			pcall(unlockOrUpgradeByLogic, "DecomposerMachine")
		end
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		task.wait(0.35)
		if isOn("AutoHealDoor") and isHumanTeam() then
			pcall(healDoor)
		end
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		task.wait(0.2)
		if isOn("PlayerESP") then
			pcall(refreshEsp)
		end
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		task.wait(0.2)
		pcall(runHunterCombat)
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		task.wait(0.6)
		pcall(runHunterUpgrades)
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		task.wait(2)
		pcall(runLobbyFeatures)
	end
end)

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("OuroborosHub")
ThemeManager:SaveDefault("Monochrome")
ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind", "SaveManager_ImportSource" })
SaveManager:SetFolder("OuroborosHub/BreakDoor")
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
		if a.type ~= b.type then
			return a.type < b.type
		end
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

SaveManager:LoadAutoloadConfig()

Library:OnUnload(function()
	ensureHunterAutoAttack(false)
	clearEsp()
	if espFolder then
		espFolder:Destroy()
	end
	if antiAfkBeganConnection then
		antiAfkBeganConnection:Disconnect()
	end
	if antiAfkChangedConnection then
		antiAfkChangedConnection:Disconnect()
	end
	applyAntiGameplayPause(false)
	local humanoid = getHumanoid()
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.WalkSpeed = 16
	end
end)
