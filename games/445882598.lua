local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local GAME_NAME = "Coach a Fighter!"
local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"
local RSCRIPTS_LINK = "https://rscripts.net/@Ouroboros"

local Comms = ReplicatedStorage:WaitForChild("comms")
local RequestReroll = Comms:WaitForChild("RequestReroll")
local PickFighterOffer = Comms:WaitForChild("PickFighterOffer")
local ShowRerollCards = Comms:WaitForChild("ShowRerollCards")
local ClearRerollCards = Comms:WaitForChild("ClearRerollCards")
local ToggleInstantReveal = Comms:WaitForChild("ToggleInstantReveal")
local StartTrainingStation = Comms:WaitForChild("StartTrainingStation")
local OpenTrainingMenu = Comms:WaitForChild("OpenTrainingMenu")
local OpenSparringMenu = Comms:WaitForChild("OpenSparringMenu")
local RequestOfficialNPCMatch = Comms:WaitForChild("RequestOfficialNPCMatch")
local RequestCurrentFighters = Comms:WaitForChild("RequestCurrentFighters")
local RequestPantsShop = Comms:WaitForChild("RequestPantsShop")
local PurchasePantsShopItem = Comms:WaitForChild("PurchasePantsShopItem")

local LeagueConfig = require(ReplicatedStorage.sharedModules.LeagueConfig)

local repo = "https://raw.githubusercontent.com/joustingmatch/ObsidianUltra/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Toggles = Library.Toggles
local Options = Library.Options

local RARITY_VALUES = { "Random", "Random [Shiny]", "Real", "Real [Shiny]", "Legend", "Legend [Shiny]" }
local STATION_STAT_BY_NAME = {
	["Punching Bag"] = "Power",
	["Bench Press"] = "Power",
	["Pull Ups"] = "Dexterity",
	["Treadmill [AGL]"] = "Agility",
	["Treadmill [STM]"] = "Stamina",
}
local LEAGUE_VALUES = { "Bronze", "Silver", "Gold", "World" }
local NONE_FIGHTER = "None"
local MAX_TRAINING_REPS = 9
local REQUIRED_SPARS = 3

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

local function isOn(name)
	local toggle = Toggles[name]
	return toggle ~= nil and toggle.Value == true
end

local function optionValue(name, fallback)
	local option = Options[name]
	if option == nil then
		return fallback
	end
	return option.Value
end

local function multiSelected(name)
	local value = optionValue(name, {})
	if typeof(value) ~= "table" then
		return {}
	end
	local selected = {}
	for key, on in pairs(value) do
		if on == true then
			selected[key] = true
		elseif typeof(key) == "number" and typeof(on) == "string" then
			selected[on] = true
		end
	end
	return selected
end

local function multiHasAny(name)
	return next(multiSelected(name)) ~= nil
end

local function getRoot()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function teleportTo(cf)
	local root = getRoot()
	if not root or not cf then
		return false
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = cf
	return true
end

local function getHud()
	return LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("HUD")
end

local function getPlot()
	local plots = Workspace:FindFirstChild("Plots")
	local used = plots and plots:FindFirstChild("Used")
	return used and used:FindFirstChild(LocalPlayer.Name)
end

local function getStatsFolder()
	return LocalPlayer:FindFirstChild("Stats")
end

local function getMoney()
	local stats = getStatsFolder()
	local money = stats and stats:FindFirstChild("Money")
	return money and money.Value or 0
end

local function getStatValue(name)
	local stats = getStatsFolder()
	local value = stats and stats:FindFirstChild(name)
	return value and value.Value or 0
end

local function fireGuiButton(button)
	if not button then
		return false
	end
	local fired = false
	if firesignal then
		fired = pcall(firesignal, button.MouseButton1Click)
		if not fired then
			fired = pcall(firesignal, button.Activated)
		end
	end
	if fired then
		return true
	end
	for _, signalName in ipairs({ "MouseButton1Click", "Activated" }) do
		local ok, list = pcall(function()
			return getconnections(button[signalName])
		end)
		if ok then
			for _, connection in ipairs(list) do
				local ran = pcall(function()
					if connection.Fire then
						connection:Fire()
					elseif connection.Function then
						connection.Function()
					end
				end)
				fired = fired or ran
			end
		end
	end
	return fired
end

local function parseNumber(text)
	if typeof(text) == "number" then
		return text
	end
	if typeof(text) ~= "string" then
		return nil
	end
	local value = string.match(text, "(%-?%d+%.?%d*)")
	return value and tonumber(value) or nil
end

local function waitFor(predicate, timeout)
	local deadline = os.clock() + (timeout or 5)
	while os.clock() < deadline do
		local ok, result = pcall(predicate)
		if ok and result then
			return result
		end
		task.wait(0.05)
	end
	return nil
end

local latestRerollToken = nil
local latestOffers = {}
local rerollBusy = false

local function offerRarityLabel(data)
	local category = tostring(data.Category or "Custom")
	local label = "Random"
	if category == "Real" then
		label = "Real"
	elseif category == "Legend" then
		label = "Legend"
	end
	if data.IsShiny == true then
		label = label .. " [Shiny]"
	end
	return label
end

local function readOffer(data, index)
	return {
		index = index,
		name = data.RealName or data.PresetName or "",
		rarity = offerRarityLabel(data),
		shiny = data.IsShiny == true,
		overall = tonumber(data.Overall) or 0,
		power = tonumber(data.Power) or 0,
		agility = tonumber(data.Agility) or 0,
		dexterity = tonumber(data.Dexterity) or 0,
		endurance = tonumber(data.Endurance) or 0,
		reach = tonumber(data.Reach) or 0,
		stamina = tonumber(data.Stamina) or 0,
		trainingCap = tonumber(data.TrainingCap) or 0,
	}
end

ShowRerollCards.OnClientEvent:Connect(function(offers, token)
	latestRerollToken = token
	latestOffers = {}
	if typeof(offers) ~= "table" then
		return
	end
	for index = 1, 3 do
		local data = offers[index]
		if typeof(data) == "table" then
			table.insert(latestOffers, readOffer(data, index))
		end
	end
end)

ClearRerollCards.OnClientEvent:Connect(function()
	latestRerollToken = nil
	latestOffers = {}
end)

local function getRerollMenu()
	local hud = getHud()
	return hud and hud:FindFirstChild("RerollMenu")
end

local function getOfferCards()
	local menu = getRerollMenu()
	if not menu or not menu:FindFirstChild("CardSelector") then
		return {}
	end
	return latestOffers
end

local function freeRerollReady()
	local menu = getRerollMenu()
	local button = menu and menu:FindFirstChild("Reroll")
	local label = button and button:FindFirstChild("TextLabel")
	if not button or not label then
		return false
	end
	local text = string.lower(label.Text)
	if string.find(text, "free", 1, true) then
		return button.Active ~= false and button.Visible ~= false
	end
	return false
end

local function setInstantReveal(enabled)
	local current = LocalPlayer:GetAttribute("InstantReveal") == true
	if current == enabled then
		return
	end
	pcall(function()
		ToggleInstantReveal:FireServer(enabled)
	end)
	pcall(function()
		ToggleInstantReveal:FireServer()
	end)
end

local function offerMeetsStop(offer)
	if not offer then
		return false
	end
	local rarities = multiSelected("StopRarities")
	if next(rarities) ~= nil and not rarities[offer.rarity] then
		return false
	end
	if offer.overall < (optionValue("StopMinOverall", 0) or 0) then
		return false
	end
	if offer.trainingCap < (optionValue("StopMinTrainingCap", 0) or 0) then
		return false
	end
	local checks = {
		Power = offer.power,
		Agility = offer.agility,
		Dexterity = offer.dexterity,
		Endurance = offer.endurance,
		Reach = offer.reach,
		Stamina = offer.stamina,
	}
	for stat, value in pairs(checks) do
		local minimum = optionValue("StopMin" .. stat, 0) or 0
		if minimum > 0 and value < minimum then
			return false
		end
	end
	return true
end

local function chooseOffer(offers)
	local matches = {}
	for _, offer in ipairs(offers) do
		if offerMeetsStop(offer) then
			table.insert(matches, offer)
		end
	end
	if #matches == 0 then
		return nil
	end
	local mode = optionValue("StopPickMode", "Lowest Overall")
	if mode == "First Match" then
		return matches[1]
	end
	table.sort(matches, function(a, b)
		if a.overall == b.overall then
			return a.trainingCap > b.trainingCap
		end
		if mode == "Lowest Overall" then
			return a.overall < b.overall
		end
		return a.overall > b.overall
	end)
	return matches[1]
end

local function pickOffer(offer)
	if not offer then
		return false
	end
	if latestRerollToken == nil then
		return false
	end
	PickFighterOffer:FireServer(offer.index, latestRerollToken)
	latestRerollToken = nil
	latestOffers = {}
	return true
end

local function onOfferPicked(offer)
	Library:Notify(string.format("Stopped on %s [%d OVR] %s", offer.rarity, offer.overall, offer.name))
	if isOn("StopUnloadAfterPick") then
		Toggles.AutoFreeReroll:SetValue(false)
		if Toggles.AutoRealReroll then
			Toggles.AutoRealReroll:SetValue(false)
		end
		if Toggles.AutoLegendReroll then
			Toggles.AutoLegendReroll:SetValue(false)
		end
	end
end

local function requestReroll(kind)
	if LocalPlayer:GetAttribute("RerollRequestPending") == true then
		return false
	end
	if kind == "Casual" then
		if not freeRerollReady() then
			return false
		end
	elseif kind == "Real" then
		if getStatValue("RealRerolls") < 1 then
			return false
		end
	elseif kind == "Legend" then
		if getStatValue("LegendRerolls") < 1 then
			return false
		end
	else
		return false
	end
	RequestReroll:FireServer(kind)
	return true
end

local function getOwnedFighters()
	local ok, result = pcall(function()
		return RequestCurrentFighters:InvokeServer()
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	local folder = LocalPlayer:FindFirstChild("Fighters")
	local fighters = {}
	if not folder then
		return fighters
	end
	for _, child in ipairs(folder:GetChildren()) do
		local entry = { FighterId = child.Name }
		for _, value in ipairs(child:GetChildren()) do
			if value:IsA("ValueBase") then
				entry[value.Name] = value.Value
			end
		end
		table.insert(fighters, entry)
	end
	return fighters
end

local function fighterStat(fighter, key)
	local value = fighter and fighter[key]
	return typeof(value) == "number" and value or 0
end

local function fighterRoom(fighter)
	return math.max(0, fighterStat(fighter, "TrainingCap") - fighterStat(fighter, "Overall"))
end

local function sortFighters(fighters, mode)
	local copy = {}
	for i, fighter in ipairs(fighters) do
		copy[i] = fighter
	end
	table.sort(copy, function(a, b)
		if mode == "Highest Overall" then
			return fighterStat(a, "Overall") > fighterStat(b, "Overall")
		elseif mode == "Most Training Room" then
			local roomA = fighterRoom(a)
			local roomB = fighterRoom(b)
			if roomA == roomB then
				return fighterStat(a, "Overall") < fighterStat(b, "Overall")
			end
			return roomA > roomB
		end
		return fighterStat(a, "Overall") < fighterStat(b, "Overall")
	end)
	return copy
end

local function fighterMeetsLeague(fighter, leagueName)
	local ok, result = pcall(function()
		return LeagueConfig.FighterMeetsLeague(fighter, leagueName)
	end)
	if ok then
		return result == true
	end
	local league = LeagueConfig.Leagues and LeagueConfig.Leagues[leagueName]
	if not league then
		return false
	end
	return fighterStat(fighter, "Overall") >= (league.FighterMinOverall or 0)
end

local function getTrainingStations()
	local plot = getPlot()
	local folder = plot and plot:FindFirstChild("TrainingStations")
	if not folder then
		return {}
	end
	local nameCounts = {}
	local stations = {}
	for index, station in ipairs(folder:GetChildren()) do
		local tp = station:FindFirstChild("TP")
		local prompt = tp and tp:FindFirstChildWhichIsA("ProximityPrompt", true)
		if not tp or not prompt then
			continue
		end
		nameCounts[station.Name] = (nameCounts[station.Name] or 0) + 1
		local count = nameCounts[station.Name]
		local label = station.Name
		local totalSame = 0
		for _, other in ipairs(folder:GetChildren()) do
			if other.Name == station.Name then
				totalSame += 1
			end
		end
		if totalSame > 1 then
			label = string.format("%s #%d", station.Name, count)
		end
		table.insert(stations, {
			index = index,
			key = "Station" .. index,
			model = station,
			name = station.Name,
			label = label,
			tp = tp,
			prompt = prompt,
			stat = STATION_STAT_BY_NAME[station.Name] or "Overall",
			fighterOption = "StationFighter_" .. index,
			repsOption = "StationReps_" .. index,
		})
	end
	return stations
end

local function fighterDropdownLabel(fighter)
	local name = fighter.RealName or fighter.PresetName or "Fighter"
	local overall = fighterStat(fighter, "Overall")
	return string.format("%s [%d] %s", name, overall, fighter.FighterId)
end

local function parseFighterIdFromLabel(label)
	if typeof(label) ~= "string" or label == "" or label == NONE_FIGHTER then
		return nil
	end
	local id = string.match(label, "({[%w%-]+})$")
	return id
end

local function getFighterDropdownValues()
	local values = { NONE_FIGHTER }
	for _, fighter in ipairs(getOwnedFighters()) do
		if fighter.FighterId then
			table.insert(values, fighterDropdownLabel(fighter))
		end
	end
	return values
end

local function choosePveFighter()
	local selected = optionValue("PveFighter", NONE_FIGHTER)
	local fighterId = parseFighterIdFromLabel(selected)
	if not fighterId then
		return nil
	end
	for _, fighter in ipairs(getOwnedFighters()) do
		if fighter.FighterId == fighterId then
			return fighter
		end
	end
	return { FighterId = fighterId }
end

local function getFighterSelector()
	local hud = getHud()
	return hud and hud:FindFirstChild("FighterSelector")
end

local function closeFighterSelector()
	local selector = getFighterSelector()
	if not selector then
		return
	end
	local closeButton = selector:FindFirstChild("Close")
	if closeButton then
		fireGuiButton(closeButton)
	end
	selector.Visible = false
end

local function openStationMenu(station)
	closeFighterSelector()
	teleportTo(station.tp.CFrame * CFrame.new(0, 3, 0))
	task.wait(0.15)
	local token
	local connection = OpenTrainingMenu.OnClientEvent:Connect(function(_, sessionToken)
		token = sessionToken
	end)
	pcall(fireproximityprompt, station.prompt)
	local selector = waitFor(function()
		local fs = getFighterSelector()
		if fs and fs.Visible and fs:FindFirstChild("List") and fs.List:FindFirstChild("FighterCard") then
			return fs
		end
	end, 5)
	connection:Disconnect()
	return selector, token
end

local function findSelectorCard(selector, fighterId)
	local list = selector and selector:FindFirstChild("List")
	if not list then
		return nil
	end
	for _, card in ipairs(list:GetChildren()) do
		if card.Name == "FighterCard" and card:GetAttribute("FighterId") == fighterId then
			return card
		end
	end
	return nil
end

local function selectFighterCard(card)
	if not card then
		return false
	end
	local fired = false
	for _, descendant in ipairs(card:GetDescendants()) do
		if descendant:IsA("GuiButton") then
			fired = fireGuiButton(descendant) or fired
		end
	end
	return fired
end

local function chooseNamedFighter(optionName)
	local selected = optionValue(optionName, NONE_FIGHTER)
	local fighterId = parseFighterIdFromLabel(selected)
	if not fighterId then
		return nil
	end
	for _, fighter in ipairs(getOwnedFighters()) do
		if fighter.FighterId == fighterId then
			return fighter
		end
	end
	return { FighterId = fighterId }
end

local function fighterCompletedSpars(fighter)
	return fighterStat(fighter, "CompletedSpars")
end

local function getSparringPrompt()
	local plot = getPlot()
	local rings = plot and plot:FindFirstChild("BoxingRings")
	local ring = rings and rings:FindFirstChild("BoxingRing")
	local podium = ring and ring:FindFirstChild("Podium")
	local place = podium and podium:FindFirstChild("PlacePart")
	return place and place:FindFirstChildWhichIsA("ProximityPrompt", true), place
end

local function openSparringMenu()
	closeFighterSelector()
	local prompt, place = getSparringPrompt()
	if not prompt or not place then
		return nil
	end
	teleportTo(place.CFrame * CFrame.new(0, 3, 0))
	task.wait(0.15)
	local token
	local connection = OpenSparringMenu.OnClientEvent:Connect(function(_, sessionToken)
		token = sessionToken
	end)
	pcall(fireproximityprompt, prompt)
	local selector = waitFor(function()
		local fs = getFighterSelector()
		if fs and fs.Visible and fs:FindFirstChild("List") and fs.List:FindFirstChild("FighterCard") then
			return fs
		end
	end, 5)
	connection:Disconnect()
	return selector, token
end

local function clickFighterCard(card)
	if not card then
		return false
	end
	local button = card:FindFirstChild("Button")
	if button and getconnections then
		local ok, list = pcall(getconnections, button.MouseButton1Click)
		if ok then
			for _, connection in ipairs(list) do
				if connection.Function then
					local info = debug.getinfo(connection.Function)
					if info and info.nups and info.nups >= 20 then
						if pcall(connection.Function) then
							return true
						end
					end
				end
			end
			for _, connection in ipairs(list) do
				local ran = pcall(function()
					if connection.Fire then
						connection:Fire()
					elseif connection.Function then
						connection.Function()
					end
				end)
				if ran then
					return true
				end
			end
		end
	end
	return selectFighterCard(card)
end

local function getFighterSpars(fighterId)
	if typeof(fighterId) ~= "string" or fighterId == "" then
		return 0
	end
	local ok, result = pcall(function()
		return RequestCurrentFighters:InvokeServer()
	end)
	if ok and typeof(result) == "table" then
		for _, fighter in ipairs(result) do
			if fighter.FighterId == fighterId then
				return fighterCompletedSpars(fighter)
			end
		end
		return 0
	end
	for _, fighter in ipairs(getOwnedFighters()) do
		if fighter.FighterId == fighterId then
			return fighterCompletedSpars(fighter)
		end
	end
	return 0
end

local function startSparForFighter(fighterId)
	if typeof(fighterId) ~= "string" or fighterId == "" then
		return false
	end
	local before = getFighterSpars(fighterId)
	local selector = openSparringMenu()
	if not selector then
		return false
	end
	local card = findSelectorCard(selector, fighterId)
	if not card then
		closeFighterSelector()
		return false
	end
	if not clickFighterCard(card) then
		closeFighterSelector()
		return false
	end
	local deadline = os.clock() + 60
	while os.clock() < deadline do
		if Library.Unloaded then
			return false
		end
		task.wait(1)
		if getFighterSpars(fighterId) > before then
			return true
		end
	end
	return false
end

local function buyBoxerForFighter(fighterId)
	if typeof(fighterId) ~= "string" or fighterId == "" then
		return false
	end
	local ok, shop = pcall(function()
		return RequestPantsShop:InvokeServer()
	end)
	if not ok or typeof(shop) ~= "table" or typeof(shop.Offers) ~= "table" then
		return false
	end
	local refreshId = shop.RefreshId
	if typeof(refreshId) ~= "string" then
		return false
	end
	local money = getMoney()
	local offers = {}
	for _, offer in pairs(shop.Offers) do
		if typeof(offer) == "table" and typeof(offer.PantsName) == "string" then
			table.insert(offers, offer)
		end
	end
	table.sort(offers, function(a, b)
		return (tonumber(a.Price) or 0) < (tonumber(b.Price) or 0)
	end)
	for _, offer in ipairs(offers) do
		local price = tonumber(offer.Price) or 0
		if money >= price then
			local purchased, result = pcall(function()
				return PurchasePantsShopItem:InvokeServer(fighterId, offer.PantsName, refreshId)
			end)
			if purchased and typeof(result) == "table" and result.Success == true then
				return true
			end
			if purchased and typeof(result) == "table" and typeof(result.Message) == "string" then
				if string.find(string.lower(result.Message), "enough money", 1, true) then
					return false
				end
			end
		end
	end
	return false
end

local function setTrainingReps(repSelector, desired)
	desired = math.clamp(math.floor(desired), 1, MAX_TRAINING_REPS)
	local amountLabel = repSelector:FindFirstChild("AmountSelected")
	local addButton = repSelector:FindFirstChild("Add")
	local subButton = repSelector:FindFirstChild("Subtract")
	local current = parseNumber(amountLabel and amountLabel.Text) or 1
	local guard = 0
	while current < desired and addButton and guard < MAX_TRAINING_REPS do
		fireGuiButton(addButton)
		task.wait(0.05)
		current = parseNumber(amountLabel.Text) or current
		guard += 1
	end
	guard = 0
	while current > desired and subButton and guard < MAX_TRAINING_REPS do
		fireGuiButton(subButton)
		task.wait(0.05)
		current = parseNumber(amountLabel.Text) or current
		guard += 1
	end
	local startButton = repSelector:FindFirstChild("Start")
	if startButton and getconnections then
		local ok, list = pcall(getconnections, startButton.MouseButton1Click)
		if ok and list[1] and list[1].Function and setupvalue then
			pcall(setupvalue, list[1].Function, 5, desired)
		end
	end
	return current
end

local function startTrainingFromUi(selector, reps)
	local repSelector = waitFor(function()
		local rep = selector:FindFirstChild("RepSelector")
		if rep and rep.Visible then
			return rep
		end
	end, 4)
	if not repSelector then
		return false
	end
	setTrainingReps(repSelector, reps)
	task.wait(0.05)
	local startButton = repSelector:FindFirstChild("Start")
	return fireGuiButton(startButton)
end

local function assignFighterToStation(station, fighterId, reps)
	if typeof(fighterId) ~= "string" or fighterId == "" then
		return false
	end
	local selector = openStationMenu(station)
	if not selector then
		return false
	end
	local card = findSelectorCard(selector, fighterId)
	if not card then
		closeFighterSelector()
		return false
	end
	selectFighterCard(card)
	local started = startTrainingFromUi(selector, reps or 1)
	if not started then
		closeFighterSelector()
		return false
	end
	task.wait(0.35 + ((reps or 1) * 0.35))
	return true
end

local function getMatchSignup()
	local hud = getHud()
	return hud and hud:FindFirstChild("MatchSignup")
end

local function openMatchSignup()
	local existing = getMatchSignup()
	if existing and existing.Visible then
		return existing
	end
	local hud = getHud()
	local fightButton = hud and (hud:FindFirstChild("FightButton", true) or (hud:FindFirstChild("Right") and hud.Right:FindFirstChild("FightButton")))
	if fightButton then
		fireGuiButton(fightButton)
	end
	return waitFor(function()
		local menu = getMatchSignup()
		if menu and menu.Visible then
			return menu
		end
	end, 5)
end

local function startPveFight()
	if not RequestOfficialNPCMatch or not RequestOfficialNPCMatch.Parent then
		return false
	end
	local league = optionValue("PveLeague", "Bronze")
	local leagueData = LeagueConfig.Leagues and LeagueConfig.Leagues[league]
	if leagueData and getMoney() < (leagueData.MatchPrice or 0) then
		return false
	end
	local fighter = choosePveFighter()
	if not fighter or not fighter.FighterId then
		return false
	end
	if getFighterSpars(fighter.FighterId) < REQUIRED_SPARS then
		return false
	end
	local beforeMoney = getMoney()
	local errMessage
	local notifyConn
	local Notify = Comms:FindFirstChild("Notify")
	if Notify then
		notifyConn = Notify.OnClientEvent:Connect(function(message, _, kind)
			if kind == "Error" or (typeof(message) == "string" and string.find(string.lower(message), "available", 1, true)) then
				errMessage = tostring(message)
			end
		end)
	end
	RequestOfficialNPCMatch:FireServer(fighter.FighterId, league)
	task.wait(0.6)
	if notifyConn then
		notifyConn:Disconnect()
	end
	if errMessage then
		closeFighterSelector()
		local menu = openMatchSignup()
		if not menu then
			return false
		end
		local leagueButton = menu:FindFirstChild(league)
		if not leagueButton then
			return false
		end
		local clickTarget = leagueButton:IsA("GuiButton") and leagueButton or leagueButton:FindFirstChildWhichIsA("GuiButton", true) or leagueButton
		fireGuiButton(clickTarget)
		local selector = waitFor(function()
			local fs = getFighterSelector()
			if fs and fs.Visible and fs:FindFirstChild("List") and fs.List:FindFirstChild("FighterCard") then
				return fs
			end
		end, 5)
		if not selector then
			return false
		end
		local card = findSelectorCard(selector, fighter.FighterId)
		if not card then
			closeFighterSelector()
			return false
		end
		if not clickFighterCard(card) then
			closeFighterSelector()
			return false
		end
	end
	local deadline = os.clock() + 20
	while os.clock() < deadline do
		if Library.Unloaded then
			return false
		end
		task.wait(0.5)
		if getMoney() < beforeMoney then
			return true
		end
		local matchViewer = LocalPlayer.PlayerGui:FindFirstChild("MatchViewer")
		if matchViewer then
			local frame = matchViewer:FindFirstChild("Frame")
			local arena = matchViewer:FindFirstChild("ArenaInformation")
			local winner = matchViewer:FindFirstChild("WinnerFrame")
			if (frame and frame.Visible) or (arena and arena.Visible) or (winner and winner.Visible) then
				return true
			end
		end
	end
	return true
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
	Main = Window:AddTab("Main", "swords"),
	Settings = Window:AddTab("Settings", "settings"),
}

Tabs.Reroll = Tabs.Main:AddSubTab("Reroll", "dices")
Tabs.Training = Tabs.Main:AddSubTab("Training", "activity")
Tabs.Fights = Tabs.Main:AddSubTab("Fights", "swords")

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

for _, Tab in Tabs do
	if Tab ~= Tabs.Main then
		AddDiscordButton(Tab)
	end
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
		local joinScript = string.format(
			'game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s", game:GetService("Players").LocalPlayer)',
			game.PlaceId,
			jobId
		)
		if setclipboard then
			setclipboard(joinScript)
		elseif toclipboard then
			toclipboard(joinScript)
		end
		Library:Notify("Copied join script to clipboard")
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

FeaturesGroup:AddLabel(colored("Auto Reroll", BLUE), true)
FeaturesGroup:AddLabel(colored("Auto Stop Roll", ORANGE), true)
FeaturesGroup:AddLabel(colored("Auto Assign / Training", GREEN), true)
FeaturesGroup:AddLabel(colored("Auto Spar / PVE", GREY), true)
FeaturesGroup:AddLabel(colored("Auto Buy Boxers", ORANGE), true)

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

local RerollGroup = Tabs.Reroll:AddLeftGroupbox("Auto Reroll", "refresh-cw")

RerollGroup:AddToggle("AutoFreeReroll", {
	Text = "Auto Free Reroll",
	Default = false,
})

RerollGroup:AddToggle("AutoRealReroll", {
	Text = "Auto Real Reroll",
	Default = false,
})

RerollGroup:AddToggle("AutoLegendReroll", {
	Text = "Auto Legend Reroll",
	Default = false,
})

RerollGroup:AddToggle("UseInstantReveal", {
	Text = "Instant Reveal",
	Default = true,
})

RerollGroup:AddSlider("RerollDelay", {
	Text = "Reroll Delay",
	Default = 0.35,
	Min = 0.1,
	Max = 3,
	Rounding = 2,
})

local StopGroup = Tabs.Reroll:AddRightGroupbox("Auto Stop Roll", "hand")

StopGroup:AddToggle("AutoStopRoll", {
	Text = "Auto Stop Roll",
	Default = false,
})

StopGroup:AddDropdown("StopRarities", {
	Text = "Rarities",
	Values = RARITY_VALUES,
	Default = { "Real [Shiny]", "Legend [Shiny]" },
	Multi = true,
	AllowNull = true,
})

StopGroup:AddDropdown("StopPickMode", {
	Text = "Pick Mode",
	Values = { "Lowest Overall", "Best Overall", "First Match" },
	Default = "Lowest Overall",
})

StopGroup:AddToggle("StopUnloadAfterPick", {
	Text = "Stop Rerolling After Pick",
	Default = true,
})

StopGroup:AddSlider("StopMinOverall", {
	Text = "Min Overall",
	Default = 0,
	Min = 0,
	Max = 99,
	Rounding = 0,
})

StopGroup:AddSlider("StopMinTrainingCap", {
	Text = "Min Training Cap",
	Default = 0,
	Min = 0,
	Max = 99,
	Rounding = 0,
})

for _, stat in ipairs({ "Power", "Agility", "Dexterity", "Endurance", "Reach", "Stamina" }) do
	StopGroup:AddSlider("StopMin" .. stat, {
		Text = "Min " .. stat,
		Default = 0,
		Min = 0,
		Max = 99,
		Rounding = 0,
	})
end

local TrainingGroup = Tabs.Training:AddLeftGroupbox("Auto Assign", "user-plus")

TrainingGroup:AddToggle("AutoAssignFighters", {
	Text = "Auto Assign Fighters",
	Default = false,
})

TrainingGroup:AddSlider("TrainingDelay", {
	Text = "Assign Delay",
	Default = 0.75,
	Min = 0.2,
	Max = 5,
	Rounding = 2,
})

local TrainingStations = getTrainingStations()
if #TrainingStations == 0 then
	local deadline = os.clock() + 8
	while #TrainingStations == 0 and os.clock() < deadline do
		task.wait(0.25)
		TrainingStations = getTrainingStations()
	end
end

local StationDropdowns = {}
local refreshFighterDropdowns

local function fighterValuesWithoutNone()
	local values = getFighterDropdownValues()
	local withoutNone = {}
	for _, value in ipairs(values) do
		if value ~= NONE_FIGHTER then
			table.insert(withoutNone, value)
		end
	end
	if #withoutNone == 0 then
		return { NONE_FIGHTER }
	end
	table.insert(withoutNone, 1, NONE_FIGHTER)
	return withoutNone
end

TrainingGroup:AddButton({
	Text = "Refresh Fighters",
	Func = function()
		if refreshFighterDropdowns then
			refreshFighterDropdowns()
		end
		Library:Notify("Fighter lists refreshed")
	end,
})

local initialFighterValues = fighterValuesWithoutNone()

for _, station in ipairs(TrainingStations) do
	local stationGroup = Tabs.Training:AddRightGroupbox(station.label, "map-pin")
	local fighterDropdown = stationGroup:AddDropdown(station.fighterOption, {
		Text = "Fighter",
		Values = initialFighterValues,
		Default = NONE_FIGHTER,
		AllowNull = false,
	})
	stationGroup:AddSlider(station.repsOption, {
		Text = "Reps",
		Default = 1,
		Min = 1,
		Max = MAX_TRAINING_REPS,
		Rounding = 0,
	})
	table.insert(StationDropdowns, fighterDropdown)
end

refreshFighterDropdowns = function()
	local values = fighterValuesWithoutNone()
	for _, dropdown in ipairs(StationDropdowns) do
		local current = dropdown.Value
		dropdown:SetValues(values)
		if current and table.find(values, current) then
			dropdown:SetValue(current)
		else
			dropdown:SetValue(NONE_FIGHTER)
		end
	end
	local pveValues = {}
	for _, value in ipairs(values) do
		if value ~= NONE_FIGHTER then
			table.insert(pveValues, value)
		end
	end
	if #pveValues == 0 then
		pveValues = { NONE_FIGHTER }
	end
	for _, name in ipairs({ "PveFighter", "SparFighter", "BoxerFighter" }) do
		local dropdown = Options[name]
		if dropdown then
			local current = dropdown.Value
			dropdown:SetValues(pveValues)
			if current and table.find(pveValues, current) then
				dropdown:SetValue(current)
			elseif pveValues[1] then
				dropdown:SetValue(pveValues[1])
			end
		end
	end
end

local function formatSparStatusText()
	local fighters = getOwnedFighters()
	if #fighters == 0 then
		return colored("No fighters", GREY)
	end
	local lines = {}
	for _, fighter in ipairs(fighters) do
		local name = fighter.RealName or fighter.PresetName or "Fighter"
		local spars = fighterCompletedSpars(fighter)
		local color = spars >= REQUIRED_SPARS and GREEN or ORANGE
		table.insert(lines, field(name, spars .. " / " .. REQUIRED_SPARS, color))
	end
	return table.concat(lines, "<br/>")
end

local FightGroup = Tabs.Fights:AddLeftGroupbox("Auto Spar", "swords")

FightGroup:AddToggle("AutoSpar", {
	Text = "Auto Spar",
	Default = false,
})

FightGroup:AddToggle("SparStopAtThree", {
	Text = "Stop At 3 Spars",
	Default = true,
})

local fightFighterDefaults = {}
for _, value in ipairs(initialFighterValues) do
	if value ~= NONE_FIGHTER then
		table.insert(fightFighterDefaults, value)
	end
end
if #fightFighterDefaults == 0 then
	fightFighterDefaults = { NONE_FIGHTER }
end

FightGroup:AddDropdown("SparFighter", {
	Text = "Fighter",
	Values = fightFighterDefaults,
	Default = fightFighterDefaults[1],
	AllowNull = false,
})

FightGroup:AddSlider("SparDelay", {
	Text = "Spar Delay",
	Default = 2,
	Min = 0.5,
	Max = 15,
	Rounding = 1,
})

local refreshSparStatus

FightGroup:AddButton({
	Text = "Refresh Fighters",
	Func = function()
		if refreshFighterDropdowns then
			refreshFighterDropdowns()
		end
		if refreshSparStatus then
			refreshSparStatus()
		end
		Library:Notify("Fighter lists refreshed")
	end,
})

local PveGroup = Tabs.Fights:AddLeftGroupbox("Auto PVE", "trophy")

PveGroup:AddToggle("AutoPve", {
	Text = "Auto Start PVE",
	Default = false,
})

PveGroup:AddDropdown("PveLeague", {
	Text = "League",
	Values = LEAGUE_VALUES,
	Default = "Bronze",
})

PveGroup:AddDropdown("PveFighter", {
	Text = "Fighter",
	Values = fightFighterDefaults,
	Default = fightFighterDefaults[1],
	AllowNull = false,
})

PveGroup:AddSlider("PveDelay", {
	Text = "Fight Delay",
	Default = 3,
	Min = 1,
	Max = 20,
	Rounding = 1,
})

PveGroup:AddButton({
	Text = "Refresh Fighters",
	Func = function()
		if refreshFighterDropdowns then
			refreshFighterDropdowns()
		end
		if refreshSparStatus then
			refreshSparStatus()
		end
		Library:Notify("Fighter lists refreshed")
	end,
})

local SparStatusGroup = Tabs.Fights:AddRightGroupbox("Spar Status", "activity")

local SparStatusLabel = SparStatusGroup:AddLabel(formatSparStatusText(), true)

refreshSparStatus = function()
	SparStatusLabel:SetText(formatSparStatusText())
end

local ShopGroup = Tabs.Fights:AddRightGroupbox("Money Shop", "shopping-bag")

ShopGroup:AddToggle("AutoBuyBoxers", {
	Text = "Auto Buy Boxers",
	Default = false,
})

ShopGroup:AddDropdown("BoxerFighter", {
	Text = "Fighter",
	Values = fightFighterDefaults,
	Default = fightFighterDefaults[1],
	AllowNull = false,
})

ShopGroup:AddSlider("BoxerDelay", {
	Text = "Buy Delay",
	Default = 2,
	Min = 0.5,
	Max = 15,
	Rounding = 1,
})

ShopGroup:AddButton({
	Text = "Refresh Fighters",
	Func = function()
		if refreshFighterDropdowns then
			refreshFighterDropdowns()
		end
		Library:Notify("Fighter lists refreshed")
	end,
})

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "menu")

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

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("OuroborosHub")
ThemeManager:SaveDefault("Monochrome")
ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("OuroborosHub/coach-a-fighter")
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

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

Library:OnUnload(function()
	antiAfkBeganConnection:Disconnect()
	antiAfkChangedConnection:Disconnect()
end)

task.spawn(function()
	while not Library.Unloaded do
		task.wait(2)
		if isOn("AntiAfk") then
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

task.spawn(function()
	while not Library.Unloaded do
		local delayTime = optionValue("RerollDelay", 0.35) or 0.35
		task.wait(delayTime)
		if not isOn("AutoFreeReroll") and not isOn("AutoRealReroll") and not isOn("AutoLegendReroll") and not isOn("AutoStopRoll") then
			continue
		end
		if rerollBusy then
			continue
		end
		rerollBusy = true
		local ok, err = pcall(function()
			if isOn("UseInstantReveal") then
				setInstantReveal(true)
			end
			if isOn("AutoStopRoll") then
				local choice = chooseOffer(getOfferCards())
				if choice and pickOffer(choice) then
					onOfferPicked(choice)
					task.wait(0.4)
					return
				end
			end
			local rolled = false
			if isOn("AutoFreeReroll") then
				rolled = requestReroll("Casual")
			end
			if not rolled and isOn("AutoRealReroll") then
				rolled = requestReroll("Real")
			end
			if not rolled and isOn("AutoLegendReroll") then
				rolled = requestReroll("Legend")
			end
			if rolled then
				task.wait(0.25)
				if isOn("AutoStopRoll") then
					local choice = chooseOffer(getOfferCards())
					if choice and pickOffer(choice) then
						onOfferPicked(choice)
					end
				end
			end
		end)
		rerollBusy = false
		if not ok then
			warn("[Ouroboros] Reroll loop:", err)
		end
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		local delayTime = optionValue("TrainingDelay", 0.75) or 0.75
		task.wait(delayTime)
		if not isOn("AutoAssignFighters") then
			continue
		end
		local ok, err = pcall(function()
			for _, station in ipairs(TrainingStations) do
				if Library.Unloaded or not isOn("AutoAssignFighters") then
					break
				end
				if not station.model or not station.model.Parent then
					local refreshed = getTrainingStations()
					for _, fresh in ipairs(refreshed) do
						if fresh.index == station.index then
							station.model = fresh.model
							station.tp = fresh.tp
							station.prompt = fresh.prompt
							break
						end
					end
				end
				local fighterLabel = optionValue(station.fighterOption, NONE_FIGHTER)
				local fighterId = parseFighterIdFromLabel(fighterLabel)
				if fighterId then
					local reps = optionValue(station.repsOption, 1) or 1
					assignFighterToStation(station, fighterId, reps)
					task.wait(delayTime)
				end
			end
		end)
		if not ok then
			warn("[Ouroboros] Training loop:", err)
		end
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		task.wait(2)
		if refreshSparStatus then
			pcall(refreshSparStatus)
		end
	end
end)

task.spawn(function()
	local pveBusy = false
	while not Library.Unloaded do
		local delayTime = optionValue("PveDelay", 3) or 3
		task.wait(delayTime)
		if not isOn("AutoPve") or pveBusy then
			continue
		end
		pveBusy = true
		local ok, err = pcall(startPveFight)
		pveBusy = false
		if not ok then
			warn("[Ouroboros] PVE loop:", err)
		end
	end
end)

task.spawn(function()
	local sparBusy = false
	while not Library.Unloaded do
		local delayTime = optionValue("SparDelay", 2) or 2
		task.wait(delayTime)
		if not isOn("AutoSpar") or sparBusy then
			continue
		end
		sparBusy = true
		local ok, err = pcall(function()
			local fighter = chooseNamedFighter("SparFighter")
			if not fighter or not fighter.FighterId then
				return
			end
			local spars = getFighterSpars(fighter.FighterId)
			if isOn("SparStopAtThree") and spars >= REQUIRED_SPARS then
				return
			end
			startSparForFighter(fighter.FighterId)
		end)
		sparBusy = false
		if not ok then
			warn("[Ouroboros] Spar loop:", err)
		end
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		local delayTime = optionValue("BoxerDelay", 2) or 2
		task.wait(delayTime)
		if not isOn("AutoBuyBoxers") then
			continue
		end
		local ok, err = pcall(function()
			local fighter = chooseNamedFighter("BoxerFighter")
			if not fighter or not fighter.FighterId then
				return
			end
			buyBoxerForFighter(fighter.FighterId)
		end)
		if not ok then
			warn("[Ouroboros] Boxer loop:", err)
		end
	end
end)
