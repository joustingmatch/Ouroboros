local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("remotes")
local prompt_action = remotes:WaitForChild("prompt_action")
local naval_action = remotes:WaitForChild("naval_action")
local naval_sync = remotes:WaitForChild("naval_sync")
local fire_missile = remotes:WaitForChild("fire_missile")
local enter_targeting = remotes:WaitForChild("enter_targeting")
local fire_jet = remotes:WaitForChild("fire_jet")
local enter_jet_targeting = remotes:WaitForChild("enter_jet_targeting")
local jet_launched = remotes:WaitForChild("jet_launched")
local jet_result = remotes:WaitForChild("jet_result")
local jet_defend_offer = remotes:WaitForChild("jet_defend_offer")
local jet_defend_respond = remotes:WaitForChild("jet_defend_respond")
local jet_duel_begin = remotes:WaitForChild("jet_duel_begin")
local jet_duel_event = remotes:WaitForChild("jet_duel_event")
local jet_duel_turn = remotes:WaitForChild("jet_duel_turn")
local state = require(ReplicatedStorage:WaitForChild("state"))
local configs = require(ReplicatedStorage:WaitForChild("configs"))

local DISTRICTS = {
	"district_silos",
	"district_military_airport",
	"district_nuclear_reactors",
	"district_datacenters",
	"district_naval_dock",
	"district_space_center",
	"district_oil_refinery",
	"district_seaport",
	"district_warehouses",
	"district_solar_field",
	"district_wind_farm",
	"district_downtown",
	"district_farm",
	"district_houses",
}

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

local DISCORD_INVITE = "https://discord.gg/ehKVq7pf7v"

local function toggle_enabled(name)
	local toggle = Toggles[name]
	return toggle and toggle.Value == true
end

local function get_plot()
	local plots = workspace:FindFirstChild("map") and workspace.map:FindFirstChild("plots")
	if not plots then
		return nil
	end

	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("owner_name") == LocalPlayer.Name then
			return plot
		end
	end

	return nil
end

local function get_root()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function teleport_to(position)
	local root = get_root()
	if root and typeof(position) == "Vector3" then
		root.CFrame = CFrame.new(position + Vector3.new(0, 6, 0))
	end
end

local function touch(root, part)
	firetouchinterest(root, part, 0)
	task.wait()
	firetouchinterest(root, part, 1)
end

local function collect_money()
	local plot = get_plot()
	local root = get_root()
	if not plot or not root then
		return
	end

	for _, part in plot:GetDescendants() do
		if part.Name == "collector" and part:IsA("BasePart") and part.CanTouch then
			touch(root, part)
		end
	end
end

local function press_buttons()
	local plot = get_plot()
	local root = get_root()
	if not plot or not root then
		return
	end

	for _, cap in plot:GetDescendants() do
		if cap.Name == "cap" and cap:IsA("BasePart") and cap.CanTouch and cap.Transparency == 0 then
			local model = cap.Parent
			if model:FindFirstChild("base") and cap.Color.G > 0.5 and cap.Color.R < 0.5 then
				touch(root, cap)
			end
		end
	end
end

local function enemy_plots()
	local plots = workspace:FindFirstChild("map") and workspace.map:FindFirstChild("plots")
	if not plots then
		return {}
	end

	local list = {}
	for _, plot in plots:GetChildren() do
		local owner = plot:GetAttribute("owner_name")
		if typeof(owner) == "string" and owner ~= "" and owner ~= LocalPlayer.Name then
			list[#list + 1] = { plot = plot, owner = owner }
		end
	end

	return list
end

local function district_resources(district)
	local list = {}
	local seen = {}

	for _, child in district:GetDescendants() do
		if child:IsA("Model") and CollectionService:HasTag(child, "building") then
			seen[child] = true
			list[#list + 1] = child
		end
	end

	for _, child in district:GetChildren() do
		if child:IsA("Model") and not seen[child] then
			local name = child.Name
			if
				name:match("^silo_structure_%d+$")
				or name:match("^hangar_structure_%d+$")
				or name == "launch_pad"
				or name == "command_center"
				or name == "heavy_battery"
				or name == "orbital_console"
				or name == "space_shuttle"
			then
				list[#list + 1] = child
			end
		end
	end

	return list
end

local function district_priority(plot)
	local wanted = Options.TargetDistrict.Value
	if wanted and wanted ~= "Most Important" and wanted ~= "Random" then
		local district = plot:FindFirstChild(wanted)
		return district and #district_resources(district) > 0 and 1 or nil
	end

	for index, name in DISTRICTS do
		local district = plot:FindFirstChild(name)
		if district and #district_resources(district) > 0 then
			return index
		end
	end

	return nil
end

local function pick_target()
	local list = enemy_plots()
	if #list == 0 then
		return nil
	end

	local wanted = Options.TargetPlayer.Value
	if wanted and wanted ~= "Auto Priority" and wanted ~= "Random" then
		for _, entry in list do
			if entry.owner == wanted then
				return entry.plot
			end
		end
		if Toggles.StrictTarget.Value then
			return nil
		end
	end

	local best
	local best_priority
	for _, entry in list do
		local priority = district_priority(entry.plot)
		if priority and (not best_priority or priority < best_priority) then
			best = entry.plot
			best_priority = priority
		end
	end

	return best
end

local function pick_district(plot)
	local wanted = Options.TargetDistrict.Value
	if wanted and wanted ~= "Most Important" and wanted ~= "Random" then
		return plot:FindFirstChild(wanted)
	end

	for _, name in DISTRICTS do
		local district = plot:FindFirstChild(name)
		if district and #district_resources(district) > 0 then
			return district
		end
	end

	return nil
end

local function aim_position(plot)
	local district = pick_district(plot)
	if not district then
		return plot:GetPivot().Position
	end

	local resources = district_resources(district)
	local best_building
	local best_size = 0
	for _, child in resources do
		local size = child:GetExtentsSize().Magnitude
		if size > best_size then
			best_size = size
			best_building = child
		end
	end

	if best_building then
		return best_building:GetPivot().Position
	end

	return district:GetPivot().Position
end

local function silo_anchors()
	local plot = get_plot()
	local list = {}
	if not plot then
		return list
	end

	for _, prompt in state.prompts() do
		if prompt.kind == "silo" and prompt.anchor and prompt.anchor:IsDescendantOf(plot) then
			list[#list + 1] = prompt.anchor
		end
	end

	return list
end

local native_targeting = {}
local native_jet_targeting = {}
local native_jet_launched = {}
local native_jet_duel_begin = {}
local native_jet_duel_event = {}

pcall(function()
	native_targeting = getconnections(enter_targeting.OnClientEvent)
	native_jet_targeting = getconnections(enter_jet_targeting.OnClientEvent)
	native_jet_launched = getconnections(jet_launched.OnClientEvent)
	native_jet_duel_begin = getconnections(jet_duel_begin.OnClientEvent)
	native_jet_duel_event = getconnections(jet_duel_event.OnClientEvent)
end)

local function set_connections(list, enabled)
	for _, connection in list do
		pcall(function()
			if enabled then
				connection:Enable()
			else
				connection:Disable()
			end
		end)
	end
end

local function set_native_targeting(enabled)
	set_connections(native_targeting, enabled)
end

local function set_native_jet_targeting(enabled)
	set_connections(native_jet_targeting, enabled)
end

local function set_native_air_fight(enabled)
	set_connections(native_jet_launched, enabled)
	set_connections(native_jet_duel_begin, enabled)
	set_connections(native_jet_duel_event, enabled)
end

local TARGETING_TOGGLES = {
	"AutoAttack",
	"AutoBarrage",
	"AutoEMP",
	"AutoRailGun",
	"AutoBlowUpSilo",
}

local function sync_native_targeting()
	for _, name in TARGETING_TOGGLES do
		if toggle_enabled(name) then
			set_native_targeting(false)
			return
		end
	end
	set_native_targeting(true)
end

local function auto_air_enabled()
	return toggle_enabled("AutoScramble") or toggle_enabled("AutoAirFight") or toggle_enabled("AutoMiniObby")
end

local function sync_native_air_fight()
	set_native_air_fight(not auto_air_enabled())
end

local targeting_open = false
local jet_targeting_open = false
local jet_targeting_data = nil
local targeting_busy = false

enter_targeting.OnClientEvent:Connect(function()
	targeting_open = true
end)

enter_jet_targeting.OnClientEvent:Connect(function(data)
	jet_targeting_open = true
	jet_targeting_data = data
end)

local function fire_targeted_prompt(anchor, action, plot)
	if targeting_busy then
		return
	end

	targeting_busy = true
	targeting_open = false
	prompt_action:FireServer(anchor, action)

	local deadline = os.clock() + 3
	while not targeting_open and os.clock() < deadline do
		task.wait(0.1)
	end

	if targeting_open then
		targeting_open = false
		fire_missile:FireServer(aim_position(plot))
		task.wait(Options.AttackDelay.Value)
	end
	targeting_busy = false
end

local function attack()
	local anchors = silo_anchors()
	if #anchors == 0 then
		return
	end

	for _, anchor in anchors do
		if Library.Unloaded or not Toggles.AutoAttack.Value then
			return
		end

		local plot = pick_target()
		if not plot then
			return
		end

		fire_targeted_prompt(anchor, "shoot", plot)
	end
end

local function barrage_attack()
	local plot = get_plot()
	if not plot then
		return
	end

	for _, prompt in state.prompts() do
		if Library.Unloaded or not Toggles.AutoBarrage.Value then
			return
		end

		if
			prompt.kind == "barrage"
			and prompt.anchor
			and prompt.anchor:IsDescendantOf(plot)
			and typeof(prompt.state) == "table"
			and prompt.state.fire_ready
		then
			local target = pick_target()
			if target then
				fire_targeted_prompt(prompt.anchor, "fire", target)
			end
		end
	end
end

local function special_weapon_attack(toggle_name, prompt_kind, title_text)
	local plot = get_plot()
	if not plot then
		return
	end

	for _, prompt in state.prompts() do
		if Library.Unloaded or not toggle_enabled(toggle_name) then
			return
		end

		local info = prompt.state
		local title = typeof(info) == "table" and tostring(info.title or ""):lower() or ""
		if
			prompt.kind == prompt_kind
			and prompt.anchor
			and prompt.anchor:IsDescendantOf(plot)
			and typeof(info) == "table"
			and info.fire_ready
			and (not title_text or title:find(title_text, 1, true))
		then
			local target = pick_target()
			if target then
				fire_targeted_prompt(prompt.anchor, "fire", target)
			end
		end
	end
end

local counter_target = nil
local counter_deadline = 0

local function find_player_name(value, depth)
	if depth > 5 then
		return nil
	end

	local kind = typeof(value)
	if kind == "string" then
		if value ~= LocalPlayer.Name and Players:FindFirstChild(value) then
			return value
		end
	elseif kind == "Instance" and value:IsA("Player") then
		if value ~= LocalPlayer then
			return value.Name
		end
	elseif kind == "table" then
		for _, inner in value do
			local found = find_player_name(inner, depth + 1)
			if found then
				return found
			end
		end
	end

	return nil
end

local combat_signals = {
	"revenge_offer",
	"jet_defend_offer",
	"naval_contested",
	"naval_strike",
	"combat_alert",
	"missile_impact",
}

for _, signal in combat_signals do
	local event = remotes:FindFirstChild(signal)
	if event and event:IsA("RemoteEvent") then
		event.OnClientEvent:Connect(function(...)
			if Library.Unloaded or not Toggles.AutoCounter.Value then
				return
			end

			local attacker = find_player_name({ ... }, 0)
			if attacker then
				counter_target = attacker
				counter_deadline = os.clock() + (tonumber(Options.CounterDuration.Value) or 30)
			end
		end)
	end
end

local function counter_attack()
	if not counter_target or os.clock() > counter_deadline then
		return
	end

	local plot
	for _, entry in enemy_plots() do
		if entry.owner == counter_target then
			plot = entry.plot
			break
		end
	end

	if not plot then
		return
	end

	local anchors = silo_anchors()
	for _, anchor in anchors do
		if Library.Unloaded or not Toggles.AutoCounter.Value then
			return
		end
		if os.clock() > counter_deadline then
			return
		end

		fire_targeted_prompt(anchor, "shoot", plot)
	end
end

local function jet_strike_positions(target, data)
	local positions = {}
	local wanted = target:GetAttribute("owner_name")
	local selected

	if typeof(data) == "table" and typeof(data.plots) == "table" then
		for _, entry in data.plots do
			if typeof(entry) == "table" and entry.city == wanted then
				selected = entry
				break
			end
		end

		if not selected then
			local target_position = target:GetPivot().Position
			local distance
			for _, entry in data.plots do
				if typeof(entry) == "table" and typeof(entry.center) == "Vector3" then
					local current = (entry.center - target_position).Magnitude
					if not distance or current < distance then
						distance = current
						selected = entry
					end
				end
			end
		end
	end

	local maximum = math.max(1, math.floor(tonumber(data and data.max_targets) or 1))
	for _, silo in selected and selected.silos or {} do
		if typeof(silo) == "table" and typeof(silo.pos) == "Vector3" then
			positions[#positions + 1] = silo.pos
			if #positions >= maximum then
				break
			end
		end
	end

	if #positions == 0 then
		positions[1] = aim_position(target)
	end

	return positions
end

local function scramble_jets()
	local plot = get_plot()
	if not plot then
		return
	end

	for _, prompt in state.prompts() do
		if Library.Unloaded or not Toggles.AutoScramble.Value then
			return
		end

		local info = prompt.state
		if
			prompt.kind == "jet"
			and prompt.anchor
			and prompt.anchor:IsDescendantOf(plot)
			and typeof(info) == "table"
			and info.scramble_ready
			and not info.scramble_flying
			and not info.scramble_knocked
		then
			local target = pick_target()
			if not target then
				return
			end

			jet_targeting_open = false
			jet_targeting_data = nil
			prompt_action:FireServer(prompt.anchor, "scramble")

			local deadline = os.clock() + 3
			while not jet_targeting_open and os.clock() < deadline do
				task.wait(0.1)
			end

			if jet_targeting_open then
				jet_targeting_open = false
				fire_jet:FireServer({ positions = jet_strike_positions(target, jet_targeting_data) })
				task.wait(Options.ScrambleDelay.Value)
			end
		end
	end
end

local active_duel = nil

jet_launched.OnClientEvent:Connect(function(data)
	if not auto_air_enabled() or typeof(data) ~= "table" or typeof(data.sortie_id) ~= "number" then
		return
	end

	jet_result:FireServer({
		sortie_id = data.sortie_id,
		dots_hit = math.max(0, math.floor(tonumber(data.dots_total) or 0)),
		bomb_hit = true,
	})
end)

jet_defend_offer.OnClientEvent:Connect(function(data)
	if auto_air_enabled() and typeof(data) == "table" and typeof(data.duel_id) == "number" then
		jet_defend_respond:FireServer({ accept = true, duel_id = data.duel_id })
	end
end)

jet_duel_begin.OnClientEvent:Connect(function(data)
	if auto_air_enabled() and typeof(data) == "table" then
		active_duel = data.duel_id
	end
end)

jet_duel_event.OnClientEvent:Connect(function(data)
	if not auto_air_enabled() or typeof(data) ~= "table" or typeof(data.turn) ~= "number" then
		return
	end

	local response = {
		duel_id = data.duel_id or active_duel,
		turn = data.turn,
	}
	if data.role == "shooter" then
		response.lined_up = true
	else
		response.dodges = configs.jets.duel.evader_dodge_dots
	end
	jet_duel_turn:FireServer(response)
end)

local function cash()
	local currency = LocalPlayer:FindFirstChild("currency")
	local value = currency and currency:FindFirstChild("Cash")
	return value and value.Value or 0
end

local function reserve()
	return tonumber(Options.CashReserve.Value) or 0
end

local function affordable(cost)
	local limit = tonumber(Options.MaxUpgradeCost.Value) or 0
	if limit > 0 and cost > limit then
		return false
	end

	return cash() - cost >= reserve()
end

local function upgrade_hangars()
	local plot = get_plot()
	if not plot then
		return
	end

	for _, prompt in state.prompts() do
		if Library.Unloaded or not Toggles.AutoHangars.Value then
			return
		end

		if prompt.kind == "jet" and prompt.anchor and prompt.anchor:IsDescendantOf(plot) then
			local info = prompt.state
			if typeof(info) == "table" and info.up_affordable and affordable(info.up_cost or 0) then
				prompt_action:FireServer(prompt.anchor, "upgrade")
				task.wait(0.4)
			end
		end
	end
end

local UPGRADEABLE_PROMPTS = {
	silo = true,
	aa = true,
	jet = true,
	mine = true,
	barrage = true,
}

local function upgrade_resources()
	local plot = get_plot()
	if not plot then
		return
	end

	for _, prompt in state.prompts() do
		if Library.Unloaded or not Toggles.AutoUpgrade.Value then
			return
		end

		local info = prompt.state
		if
			UPGRADEABLE_PROMPTS[prompt.kind]
			and prompt.anchor
			and prompt.anchor:IsDescendantOf(plot)
			and typeof(info) == "table"
			and info.up_affordable
			and (info.up_cost or -1) >= 0
			and affordable(info.up_cost or 0)
		then
			prompt_action:FireServer(prompt.anchor, "upgrade")
			task.wait(0.25)
		end
	end
end

local function operate_mines(island_name, toggle)
	local plot = get_plot()
	if not plot then
		return
	end

	for _, prompt in state.prompts() do
		if Library.Unloaded or not toggle.Value then
			return
		end

		if
			prompt.kind == "mine"
			and prompt.anchor
			and prompt.anchor:IsDescendantOf(plot)
			and prompt.anchor:GetFullName():find(island_name, 1, true)
			and typeof(prompt.state) == "table"
			and prompt.state.mine_state ~= "mining"
		then
			prompt_action:FireServer(prompt.anchor, "operate")
			task.wait(0.2)
		end
	end
end

local fleet = {}
local islands = {}
local crates = {}
local rarities = {}
local island_names = {}
local naval_sync_serial = 0

naval_sync.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" or typeof(data.fleet) ~= "table" then
		return
	end

	fleet = data.fleet
	islands = typeof(data.islands) == "table" and data.islands or {}
	crates = typeof(data.crates) == "table" and data.crates or {}
	naval_sync_serial = naval_sync_serial + 1

	local seen, values = {}, {}
	for _, ship in fleet do
		if ship.rarity and not seen[ship.rarity] then
			seen[ship.rarity] = true
			values[#values + 1] = ship.rarity
		end
	end

	table.sort(values)
	if table.concat(values, ",") ~= table.concat(rarities, ",") then
		rarities = values
		Options.ShipRarities:SetValues(values)
	end

	local names = {}
	for _, island in islands do
		if typeof(island.name) == "string" and island.name ~= "" then
			names[#names + 1] = island.name
		end
	end

	table.sort(names)
	if table.concat(names, ",") ~= table.concat(island_names, ",") then
		island_names = names
		Options.DeployIsland:SetValues(names)

		if not table.find(names, Options.DeployIsland.Value) then
			Options.DeployIsland:SetValue(names[1])
		end

		local assignment_values = { "Auto" }
		for _, name in names do
			assignment_values[#assignment_values + 1] = name
		end
		for index = 1, 4 do
			local option = Options["NavyShip" .. index .. "Island"]
			if option then
				local current = option.Value
				option:SetValues(assignment_values)
				if not table.find(assignment_values, current) then
					option:SetValue("Auto")
				end
			end
		end
	end
end)

local function sync_naval()
	local serial = naval_sync_serial
	naval_action:FireServer("sync")
	local deadline = os.clock() + 3
	while naval_sync_serial == serial and os.clock() < deadline do
		task.wait(0.1)
	end
end

local function rarity_allowed(rarity)
	local picked = Options.ShipRarities.Value
	if typeof(picked) ~= "table" or not next(picked) then
		return true
	end

	return picked[rarity] == true
end

local function upgrade_ships()
	sync_naval()

	for _, ship in fleet do
		if Library.Unloaded or not Toggles.AutoShips.Value then
			return
		end

		local cost = ship.upgrade_cost or 0
		if
			not ship.maxed
			and ship.upgrade_afford
			and rarity_allowed(ship.rarity)
			and (ship.level or 1) < Options.MaxShipLevel.Value
			and affordable(cost)
		then
			naval_action:FireServer("upgrade_ship", ship.id)
			task.wait(0.4)
		end
	end
end

local function gems()
	local currency = LocalPlayer:FindFirstChild("currency")
	local value = currency and currency:FindFirstChild("Gems")
	return value and value.Value or 0
end

local function buy_crates()
	sync_naval()

	local key = Options.CrateType.Value
	local crate = crates[key]
	if typeof(crate) ~= "table" or not crate.gems then
		return
	end

	local keep = tonumber(Options.GemReserve.Value) or 0
	while gems() - crate.gems >= keep do
		if Library.Unloaded or not Toggles.AutoCrates.Value then
			return
		end

		naval_action:FireServer("roll", key, "gems")
		task.wait(1)
	end
end

local function pick_island(assignment)
	if assignment and assignment ~= "Auto" then
		for _, island in islands do
			if island.name == assignment then
				return island.mine == true and nil or island
			end
		end
		return nil
	end

	local mode = Options.DeployMode.Value
	local best

	for _, island in islands do
		local owned = island.mine == true
		local enemy = island.controller ~= nil and not owned

		if not (owned and Toggles.SkipOwnedIslands.Value) then
			if mode == "Specific Island" then
				if island.name == Options.DeployIsland.Value then
					return island
				end
			elseif mode == "Empty Islands" then
				if island.controller == nil then
					return island
				end
			elseif mode == "Enemy Islands" then
				if enemy and (not best or (island.rate or 0) > (best.rate or 0)) then
					best = island
				end
			elseif not best or (island.rate or 0) > (best.rate or 0) then
				best = island
			end
		end
	end

	return best
end

local function deploy_ships()
	sync_naval()

	local ordered = {}
	local active = 0
	for _, ship in fleet do
		ordered[#ordered + 1] = ship
		if ship.deployed then
			active = active + 1
		end
	end
	table.sort(ordered, function(left, right)
		return (left.id or 0) < (right.id or 0)
	end)

	for index, ship in ordered do
		if Library.Unloaded or not Toggles.AutoDeploy.Value then
			return
		end
		if index > 4 or active >= 4 then
			return
		end

		if
			not ship.deployed
			and not ship.repairing
			and (ship.ready_in or 0) <= 0
			and rarity_allowed(ship.rarity)
			and (ship.level or 1) >= Options.MinDeployLevel.Value
		then
			local option = Options["NavyShip" .. index .. "Island"]
			local island = pick_island(option and option.Value or "Auto")
			if island then
				naval_action:FireServer("deploy", ship.id, island.slot)
				ship.deployed = island.slot
				active = active + 1
				task.wait(0.4)
			end
		end
	end
end

local Window = Library:CreateWindow({
	Title = "Ouroboros Hub",
	Footer = DISCORD_INVITE .. " | Missiles vs Cities",
	Icon = 18657887261,
	NotifySide = "Right",
	ShowCustomCursor = false,
	Size = UDim2.fromOffset(880, 700),
})

local Tabs = {
	Main = Window:AddTab("Main", "rocket"),
	Settings = Window:AddTab("Settings", "settings"),
}

local function AddDiscordButton(Tab)
	Tab:AddLeftGroupbox("Discord", nil, true, false, true):AddButton({
		Text = "Join Discord For Dupe",
		Func = function()
			setclipboard(DISCORD_INVITE)
			Library:Notify("Copied Discord invite to clipboard")
		end,
	})
end

for _, Tab in Tabs do
	AddDiscordButton(Tab)
end

local FarmGroup = Tabs.Main:AddLeftGroupbox("Farm", "banknote")

FarmGroup:AddToggle("AutoCollect", {
	Text = "Auto Collect Money",
	Default = false,
})

FarmGroup:AddToggle("AutoUpgrade", {
	Text = "Auto Upgrade Resources",
	Default = false,
})

FarmGroup:AddToggle("AutoGoldCarts", {
	Text = "Auto Gold Cart Send / Claim",
	Default = false,
})

FarmGroup:AddToggle("AutoGemCarts", {
	Text = "Auto Gem Cart Send / Claim",
	Default = false,
})

local AttackGroup = Tabs.Main:AddRightGroupbox("Attack", "rocket")

AttackGroup:AddToggle("AutoAttack", {
	Text = "Auto Attack",
	Default = false,
	Callback = sync_native_targeting,
})

AttackGroup:AddDropdown("TargetPlayer", {
	Values = { "Auto Priority" },
	Default = 1,
	Text = "Target",
})

AttackGroup:AddToggle("StrictTarget", {
	Text = "Only Attack Target",
	Default = false,
})

local district_values = { "Most Important" }
for _, name in DISTRICTS do
	district_values[#district_values + 1] = name
end

AttackGroup:AddDropdown("TargetDistrict", {
	Values = district_values,
	Default = 1,
	Text = "District",
})

AttackGroup:AddSlider("AttackDelay", {
	Text = "Delay Between Missiles",
	Default = 1,
	Min = 0.5,
	Max = 10,
	Rounding = 1,
	Suffix = "s",
})

AttackGroup:AddToggle("AutoCounter", {
	Text = "Auto Counter-Attack",
	Default = false,
})

AttackGroup:AddToggle("AutoBarrage", {
	Text = "Auto Barrage Array",
	Default = false,
	Callback = sync_native_targeting,
})

AttackGroup:AddToggle("AutoEMP", {
	Text = "Auto EMP Attack",
	Default = false,
	Callback = sync_native_targeting,
})

AttackGroup:AddToggle("AutoRailGun", {
	Text = "Auto Rail Gun Attack",
	Default = false,
	Callback = sync_native_targeting,
})

AttackGroup:AddToggle("AutoBlowUpSilo", {
	Text = "Auto Blow Up Silo",
	Default = false,
	Callback = sync_native_targeting,
})

AttackGroup:AddSlider("CounterDuration", {
	Text = "Counter Duration",
	Default = 30,
	Min = 5,
	Max = 120,
	Rounding = 0,
	Suffix = "s",
})

local last_targets = ""

local function refresh_targets()
	local values = { "Auto Priority" }
	for _, entry in enemy_plots() do
		values[#values + 1] = entry.owner
	end

	local key = table.concat(values, ",")
	if key == last_targets then
		return
	end

	last_targets = key
	local current = Options.TargetPlayer.Value
	Options.TargetPlayer:SetValues(values)
	if not table.find(values, current) then
		Options.TargetPlayer:SetValue("Auto Priority")
	end
end

AttackGroup:AddToggle("AutoScramble", {
	Text = "Auto Scramble Jets",
	Default = false,
	Callback = function()
		set_native_jet_targeting(not toggle_enabled("AutoScramble"))
		sync_native_air_fight()
	end,
})

AttackGroup:AddToggle("AutoAirFight", {
	Text = "Auto Air Fight",
	Default = false,
	Callback = sync_native_air_fight,
})

AttackGroup:AddToggle("AutoMiniObby", {
	Text = "Auto Mini-Obby",
	Default = false,
	Callback = sync_native_air_fight,
})

AttackGroup:AddSlider("ScrambleDelay", {
	Text = "Delay Between Jets",
	Default = 2,
	Min = 0.5,
	Max = 10,
	Rounding = 1,
	Suffix = "s",
})

AttackGroup:AddButton({
	Text = "Refresh Targets",
	Func = refresh_targets,
})

refresh_targets()

local TeleportGroup = Tabs.Main:AddLeftGroupbox("Teleport", "move")

TeleportGroup:AddButton({
	Text = "Teleport To Target",
	Func = function()
		local wanted = Options.TargetPlayer.Value
		if wanted and wanted ~= "Auto Priority" and wanted ~= "Random" then
			local player = Players:FindFirstChild(wanted)
			local character = player and player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				teleport_to(root.Position)
				return
			end

			for _, entry in enemy_plots() do
				if entry.owner == wanted then
					teleport_to(entry.plot:GetPivot().Position)
					return
				end
			end
		end

		Library:Notify("No target selected")
	end,
})

TeleportGroup:AddButton({
	Text = "Back Home",
	Func = function()
		local plot = get_plot()
		if plot then
			teleport_to(plot:GetPivot().Position)
		end
	end,
})

local UpgradeGroup = Tabs.Main:AddLeftGroupbox("Upgrades", "arrow-up")

UpgradeGroup:AddToggle("AutoHangars", {
	Text = "Auto Upgrade Hangars",
	Default = false,
})

UpgradeGroup:AddToggle("AutoShips", {
	Text = "Auto Upgrade Ships",
	Default = false,
})

UpgradeGroup:AddDropdown("ShipRarities", {
	Values = {},
	Multi = true,
	Text = "Ship Rarities",
})

UpgradeGroup:AddSlider("MaxShipLevel", {
	Text = "Max Ship Level",
	Default = 100,
	Min = 1,
	Max = 100,
	Rounding = 0,
})

UpgradeGroup:AddInput("MaxUpgradeCost", {
	Text = "Max Upgrade Cost",
	Default = "0",
	Numeric = true,
	Finished = true,
})

UpgradeGroup:AddInput("CashReserve", {
	Text = "Keep Cash",
	Default = "0",
	Numeric = true,
	Finished = true,
})

local NavyGroup = Tabs.Main:AddRightGroupbox("Navy", "ship")

NavyGroup:AddToggle("AutoDeploy", {
	Text = "Auto Deploy Ships",
	Default = false,
})

NavyGroup:AddDropdown("DeployMode", {
	Values = { "Highest Gem Rate", "Empty Islands", "Enemy Islands", "Specific Island" },
	Default = 1,
	Text = "Deploy Mode",
})

NavyGroup:AddDropdown("DeployIsland", {
	Values = {},
	AllowNull = true,
	Text = "Island",
})

for index = 1, 4 do
	NavyGroup:AddDropdown("NavyShip" .. index .. "Island", {
		Values = { "Auto" },
		Default = 1,
		Text = "Ship " .. index .. " Fixed Island",
	})
end

NavyGroup:AddButton({
	Text = "Refresh Islands",
	Func = function()
		naval_action:FireServer("sync")
	end,
})

naval_action:FireServer("sync")

NavyGroup:AddToggle("SkipOwnedIslands", {
	Text = "Skip Islands I Hold",
	Default = true,
})

NavyGroup:AddSlider("MinDeployLevel", {
	Text = "Min Ship Level",
	Default = 1,
	Min = 1,
	Max = 100,
	Rounding = 0,
})

NavyGroup:AddToggle("AutoCrates", {
	Text = "Auto Buy Naval Crates",
	Default = false,
})

NavyGroup:AddDropdown("CrateType", {
	Values = { "wooden", "iron", "gold" },
	Default = 1,
	Text = "Crate",
})

NavyGroup:AddInput("GemReserve", {
	Text = "Keep Gems",
	Default = "0",
	Numeric = true,
	Finished = true,
})

Tabs.Settings:AddLeftGroupbox("Anti-AFK"):AddToggle("AntiAFK", {
	Text = "Anti-AFK",
	Default = true,
})

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu")

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
	Default = "RightShift",
	NoUI = true,
	Text = "Menu keybind",
})

MenuGroup:AddButton("Unload", function()
	Library:Unload()
end)

local antiAfkBeganConnection
local antiAfkChangedConnection

Library:OnUnload(function()
	set_native_targeting(true)
	set_native_jet_targeting(true)
	set_native_air_fight(true)
	antiAfkBeganConnection:Disconnect()
	antiAfkChangedConnection:Disconnect()
end)

Library.ToggleKeybind = Options.MenuKeybind

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

antiAfkBeganConnection = UserInputService.InputBegan:Connect(function()
	antiAfkLastInput = tick()
end)

antiAfkChangedConnection = UserInputService.InputChanged:Connect(function(input)
	local inputType = input.UserInputType
	if inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Gamepad1 then
		antiAfkLastInput = tick()
	end
end)

task.spawn(function()
	while not Library.Unloaded do
		task.wait(2)
		if Library.Unloaded then
			break
		end
		if toggle_enabled("AntiAFK") then
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
	while task.wait(0.5) do
		if Library.Unloaded then
			break
		end
		if Toggles.AutoCollect.Value then
			pcall(collect_money)
		end
	end
end)

task.spawn(function()
	while task.wait(1) do
		if Library.Unloaded then
			break
		end
		if Toggles.AutoUpgrade.Value then
			pcall(press_buttons)
			pcall(upgrade_resources)
		end
		if Toggles.AutoGoldCarts.Value then
			pcall(operate_mines, "island_gold", Toggles.AutoGoldCarts)
		end
		if Toggles.AutoGemCarts.Value then
			pcall(operate_mines, "island_gem", Toggles.AutoGemCarts)
		end
	end
end)

task.spawn(function()
	while task.wait(0.5) do
		if Library.Unloaded then
			break
		end
		if Toggles.AutoAttack.Value then
			pcall(attack)
		end
		if Toggles.AutoBarrage.Value then
			pcall(barrage_attack)
		end
		if Toggles.AutoEMP.Value then
			pcall(special_weapon_attack, "AutoEMP", "strike", "emp")
		end
		if Toggles.AutoRailGun.Value then
			pcall(special_weapon_attack, "AutoRailGun", "strike", "rail")
		end
		if Toggles.AutoBlowUpSilo.Value then
			pcall(special_weapon_attack, "AutoBlowUpSilo", "nuke")
		end
		if Toggles.AutoScramble.Value then
			pcall(scramble_jets)
		end
		if Toggles.AutoCounter.Value then
			pcall(counter_attack)
		end
	end
end)

task.spawn(function()
	while task.wait(5) do
		if Library.Unloaded then
			break
		end
		refresh_targets()
	end
end)

task.spawn(function()
	while task.wait(2) do
		if Library.Unloaded then
			break
		end
		if Toggles.AutoHangars.Value then
			pcall(upgrade_hangars)
		end
		if Toggles.AutoShips.Value then
			pcall(upgrade_ships)
		end
		if Toggles.AutoDeploy.Value then
			pcall(deploy_ships)
		end
		if Toggles.AutoCrates.Value then
			pcall(buy_crates)
		end
	end
end)

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("OuroborosHub")
ThemeManager:SaveDefault("Mint")
ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("OuroborosHub/missiles-vs-cities")
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
