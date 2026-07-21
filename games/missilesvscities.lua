local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = Shared:WaitForChild("Net")
local Config = require(Shared:WaitForChild("Config"))
local PlayerState = require(Shared:WaitForChild("Framework"):WaitForChild("PlayerState"))
local Prompts = require(Net:WaitForChild("Prompts"))
local Targeting = require(Net:WaitForChild("Targeting"))
local Missiles = require(Net:WaitForChild("Missiles"))
local Jets = require(Net:WaitForChild("Jets"))
local Orbital = require(Net:WaitForChild("Orbital"))
local Naval = require(Net:WaitForChild("Naval"))
local Combat = require(Net:WaitForChild("Combat"))

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

local UPGRADE_TYPES = {
	"Houses",
	"Downtown",
	"Farms",
	"Warehouses",
	"Nuclear Reactors",
	"Solar Field",
	"Wind Farm",
	"Datacenters",
	"Oil Refinery",
	"Seaport",
	"Missile Silos",
	"Anti-Air",
	"Hangars",
	"Gold Mines",
	"Barrage Arrays",
	"Space Center",
	"Naval Dock",
	"Navy Ships",
}

local DISTRICT_UPGRADE_TYPES = {
	district_houses = "Houses",
	district_downtown = "Downtown",
	district_farm = "Farms",
	district_warehouses = "Warehouses",
	district_nuclear_reactors = "Nuclear Reactors",
	district_solar_field = "Solar Field",
	district_wind_farm = "Wind Farm",
	district_datacenters = "Datacenters",
	district_oil_refinery = "Oil Refinery",
	district_seaport = "Seaport",
	district_silos = "Missile Silos",
	district_military_airport = "Hangars",
	district_space_center = "Space Center",
	district_naval_dock = "Naval Dock",
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

local function upgrade_allowed(category)
	local option = Options.UpgradeSelection
	local selected = option and option.Value
	if typeof(selected) ~= "table" or not next(selected) then
		return true
	end
	return selected[category] == true
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
	pcall(function()
		firetouchinterest(root, part, 0)
		task.wait()
		firetouchinterest(root, part, 1)
	end)
	pcall(function()
		firesignal(part.Touched, root)
	end)
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

local function button_upgrade_type(cap, plot)
	local current = cap.Parent
	while current and current ~= plot do
		local category = DISTRICT_UPGRADE_TYPES[current.Name]
		if category then
			return category
		end
		if current.Name == "island_gold" then
			return "Gold Mines"
		end
		if current.Name == "island_barrage" then
			return "Barrage Arrays"
		end
		if current.Name == "expand_wind_farm" then
			return "Wind Farm"
		end
		current = current.Parent
	end
	return nil
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
			local category = button_upgrade_type(cap, plot)
			if model:FindFirstChild("base") and cap.Color == Color3.fromRGB(0, 255, 0) and category and upgrade_allowed(category) then
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

local function selected_target()
	local wanted = Options.TargetPlayer.Value
	if not wanted or wanted == "Auto Priority" or wanted == "Random" then
		return nil
	end

	for _, entry in enemy_plots() do
		if entry.owner == wanted then
			return entry.plot
		end
	end

	return nil
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

local function prompt_records()
	local list = {}
	for _, record in PlayerState.Prompts() do
		list[#list + 1] = record
	end
	return list
end

local function silo_anchors()
	local plot = get_plot()
	local list = {}
	if not plot then
		return list
	end

	for _, record in prompt_records() do
		if record.kind == "silo" and record.anchor and record.anchor:IsDescendantOf(plot) then
			list[#list + 1] = record.anchor
		end
	end

	return list
end

local suppressed = {}

local function native_listeners(packet)
	local snapshot = suppressed[packet]
	if not snapshot then
		snapshot = table.clone(packet.getListeners())
		suppressed[packet] = snapshot
	end
	return snapshot
end

local function set_packet_native(packet, enabled)
	local snapshot = native_listeners(packet)
	local live = packet.getListeners()

	for _, listener in snapshot do
		local index = table.find(live, listener)
		if enabled and not index then
			table.insert(live, listener)
		elseif not enabled and index then
			table.remove(live, index)
		end
	end
end

for _, packet in { Targeting.enter, Targeting.enterJet, Jets.launched, Jets.duelBegin, Jets.duelTurn } do
	native_listeners(packet)
end

local function set_native_targeting(enabled)
	set_packet_native(Targeting.enter, enabled)
end

local function set_native_jet_targeting(enabled)
	set_packet_native(Targeting.enterJet, enabled)
end

local function set_native_air_fight(enabled)
	set_packet_native(Jets.launched, enabled)
	set_packet_native(Jets.duelBegin, enabled)
	set_packet_native(Jets.duelTurn, enabled)
end

local TARGETING_TOGGLES = {
	"AutoAttack",
	"AutoBarrage",
	"AutoEMP",
	"AutoRailGun",
	"AutoBlowUpSilo",
	"AutoOrbital",
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

Targeting.enter.listen(function()
	targeting_open = true
end)

Targeting.enterJet.listen(function(data)
	jet_targeting_open = true
	jet_targeting_data = data
end)

local function fire_targeted_prompt(anchor, action, plot)
	if targeting_busy then
		return
	end

	targeting_busy = true
	targeting_open = false
	Prompts.action.send({ anchor = anchor, action = action })

	local deadline = os.clock() + 3
	while not targeting_open and os.clock() < deadline do
		task.wait(0.1)
	end

	if targeting_open then
		targeting_open = false
		Missiles.fire.send({ target = aim_position(plot) })
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

	for _, record in prompt_records() do
		if Library.Unloaded or not Toggles.AutoBarrage.Value then
			return
		end

		if
			record.kind == "barrage"
			and record.anchor
			and record.anchor:IsDescendantOf(plot)
			and typeof(record.state) == "table"
			and record.state.fire_ready
		then
			local target = pick_target()
			if target then
				fire_targeted_prompt(record.anchor, "fire", target)
			end
		end
	end
end

local function special_weapon_attack(toggle_name, prompt_kind, title_text, explicit_target)
	local plot = get_plot()
	if not plot then
		return
	end

	for _, record in prompt_records() do
		if Library.Unloaded or not toggle_enabled(toggle_name) then
			return
		end

		local info = record.state
		local title = typeof(info) == "table" and tostring(info.title or ""):lower() or ""
		if
			record.kind == prompt_kind
			and record.anchor
			and record.anchor:IsDescendantOf(plot)
			and typeof(info) == "table"
			and info.fire_ready
			and (not title_text or title:find(title_text, 1, true))
		then
			local target = explicit_target and selected_target() or pick_target()
			if target then
				fire_targeted_prompt(record.anchor, "fire", target)
			end
		end
	end
end

local orbital_launch_cooldown = 0
local orbital_busy_until = 0

local function orbital_attack()
	local target = selected_target()
	if not target then
		return
	end

	local plot = get_plot()
	if not plot then
		return
	end

	for _, record in prompt_records() do
		if Library.Unloaded or not Toggles.AutoOrbital.Value then
			return
		end

		local info = record.state
		if
			record.kind == "orbital"
			and record.anchor
			and record.anchor:IsDescendantOf(plot)
			and typeof(info) == "table"
		then
			if not info.launched then
				if os.clock() >= orbital_launch_cooldown then
					orbital_launch_cooldown = os.clock() + 5
					Prompts.action.send({ anchor = record.anchor, action = "fire" })
				end
				return
			end

			if not info.fire_ready or os.clock() < orbital_busy_until then
				return
			end

			local duration = math.max(1, tonumber(Config.orbital.window_seconds) or 30)
			local rate = math.max(0.05, tonumber(Config.orbital.aim_rate) or 0.1)
			orbital_busy_until = os.clock() + duration
			Orbital.strike.send({ name = target.Name })

			task.spawn(function()
				while
					not Library.Unloaded
					and Toggles.AutoOrbital.Value
					and os.clock() < orbital_busy_until
				do
					local current = selected_target()
					if current ~= target then
						break
					end
					Orbital.aim.send({ pos = aim_position(current) })
					task.wait(rate)
				end
			end)
			return
		end
	end
end

local counter_target = nil
local counter_deadline = 0

local function note_attacker(name)
	if Library.Unloaded or not Toggles.AutoCounter.Value then
		return
	end
	if typeof(name) ~= "string" or name == "" or name == LocalPlayer.Name then
		return
	end
	if not Players:FindFirstChild(name) then
		return
	end

	counter_target = name
	counter_deadline = os.clock() + (tonumber(Options.CounterDuration.Value) or 30)
end

Combat.revengeOffer.listen(function(data)
	note_attacker(typeof(data) == "table" and data.attackerName or nil)
end)

Combat.clip.listen(function(data)
	note_attacker(typeof(data) == "table" and data.name or nil)
end)

Jets.defendOffer.listen(function(data)
	note_attacker(typeof(data) == "table" and data.attackerName or nil)
end)

Naval.alertAttack.listen(function(data)
	note_attacker(typeof(data) == "table" and data.attacker or nil)
end)

Naval.alertLost.listen(function(data)
	note_attacker(typeof(data) == "table" and data.attacker or nil)
end)

Missiles.launched.listen(function(data)
	local shooter = typeof(data) == "table" and data.shooter or nil
	if typeof(shooter) == "Instance" and shooter:IsA("Player") then
		note_attacker(shooter.Name)
	end
end)

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

	local maximum = math.max(1, math.floor(tonumber(data and data.maxTargets) or 1))
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

	for _, record in prompt_records() do
		if Library.Unloaded or not Toggles.AutoScramble.Value then
			return
		end

		local info = record.state
		if
			record.kind == "jet"
			and record.anchor
			and record.anchor:IsDescendantOf(plot)
			and typeof(info) == "table"
			and info.scramble_ready
			and not info.scramble_flying
			and not info.scramble_knocked
		then
			local target = selected_target()
			if not target then
				return
			end

			jet_targeting_open = false
			jet_targeting_data = nil
			Prompts.action.send({ anchor = record.anchor, action = "scramble" })

			local deadline = os.clock() + 3
			while not jet_targeting_open and os.clock() < deadline do
				task.wait(0.1)
			end

			if jet_targeting_open then
				jet_targeting_open = false
				Jets.fire.send({ positions = jet_strike_positions(target, jet_targeting_data) })
				task.wait(Options.ScrambleDelay.Value)
			end
		end
	end
end

local active_duel = 0

Jets.launched.listen(function(data)
	if not auto_air_enabled() or typeof(data) ~= "table" or typeof(data.sortieId) ~= "number" then
		return
	end

	Jets.result.send({
		sortieId = data.sortieId,
		dotsHit = math.max(0, math.floor(tonumber(data.dotsTotal) or 0)),
		bombHit = true,
	})
end)

Jets.defendOffer.listen(function(data)
	if auto_air_enabled() and typeof(data) == "table" and typeof(data.duelId) == "number" then
		Jets.defendRespond.send({ duelId = data.duelId, accept = true })
	end
end)

Jets.duelBegin.listen(function(data)
	if auto_air_enabled() and typeof(data) == "table" then
		active_duel = data.duelId or active_duel
	end
end)

Jets.duelTurn.listen(function(data)
	if not auto_air_enabled() or typeof(data) ~= "table" or typeof(data.turn) ~= "number" then
		return
	end

	local response = {
		duelId = data.duelId or active_duel,
		turn = data.turn,
	}
	if data.role == "shooter" then
		response.linedUp = true
	else
		response.dodges = data.dodgeDots or Config.jets.duel.evader_dodge_dots
	end
	Jets.duelTurnReport.send(response)
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

	for _, record in prompt_records() do
		if Library.Unloaded or not Toggles.AutoHangars.Value then
			return
		end

		if record.kind == "jet" and record.anchor and record.anchor:IsDescendantOf(plot) then
			local info = record.state
			if typeof(info) == "table" and info.up_affordable and affordable(info.up_cost or 0) then
				Prompts.action.send({ anchor = record.anchor, action = "upgrade" })
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

local PROMPT_UPGRADE_TYPES = {
	silo = "Missile Silos",
	aa = "Anti-Air",
	jet = "Hangars",
	mine = "Gold Mines",
	barrage = "Barrage Arrays",
}

local function upgrade_resources()
	local plot = get_plot()
	if not plot then
		return
	end

	for _, record in prompt_records() do
		if Library.Unloaded or not Toggles.AutoUpgrade.Value then
			return
		end

		local info = record.state
		local category = PROMPT_UPGRADE_TYPES[record.kind]
		if
			UPGRADEABLE_PROMPTS[record.kind]
			and upgrade_allowed(category)
			and record.anchor
			and record.anchor:IsDescendantOf(plot)
			and typeof(info) == "table"
			and info.up_affordable
			and (info.up_cost or -1) >= 0
			and affordable(info.up_cost or 0)
		then
			Prompts.action.send({ anchor = record.anchor, action = "upgrade" })
			task.wait(0.25)
		end
	end
end

local function operate_mines(island_name, toggle)
	local plot = get_plot()
	if not plot then
		return
	end

	for _, record in prompt_records() do
		if Library.Unloaded or not toggle.Value then
			return
		end

		if
			record.kind == "mine"
			and record.anchor
			and record.anchor:IsDescendantOf(plot)
			and record.anchor:GetFullName():find(island_name, 1, true)
			and typeof(record.state) == "table"
			and record.state.mine_state ~= "mining"
		then
			Prompts.action.send({ anchor = record.anchor, action = "operate" })
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

local function apply_naval_sync(data)
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
end

local pending_naval = nil

Naval.sync.listen(function(data)
	if typeof(data) ~= "table" or typeof(data.fleet) ~= "table" then
		return
	end

	pending_naval = data
end)

task.spawn(function()
	while task.wait(0.1) do
		if Library.Unloaded then
			break
		end
		local data = pending_naval
		if data then
			pending_naval = nil
			pcall(apply_naval_sync, data)
		end
	end
end)

local function sync_naval()
	local serial = naval_sync_serial
	Naval.requestSync.send()
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

		local cost = ship.upgradeCost or 0
		if
			not ship.maxed
			and ship.upgradeAfford
			and rarity_allowed(ship.rarity)
			and (ship.level or 1) < Options.MaxShipLevel.Value
			and affordable(cost)
		then
			Naval.upgradeShip.send({ shipId = ship.id })
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

		Naval.roll.send({ crate = key, currency = "gems" })
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
			and (ship.readyIn or 0) <= 0
			and rarity_allowed(ship.rarity)
			and (ship.level or 1) >= Options.MinDeployLevel.Value
		then
			local option = Options["NavyShip" .. index .. "Island"]
			local island = pick_island(option and option.Value or "Auto")
			if island then
				Naval.deploy.send({ shipId = ship.id, slot = island.slot })
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
	Text = "Auto Upgrade Everything",
	Default = false,
})

FarmGroup:AddDropdown("UpgradeSelection", {
	Values = UPGRADE_TYPES,
	Multi = true,
	AllowNull = true,
	Default = {},
	Text = "Upgrade Types (none = all)",
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

AttackGroup:AddToggle("AutoOrbital", {
	Text = "Auto Orbital Cannon",
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
		Naval.requestSync.send()
	end,
})

Naval.requestSync.send()

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
			pcall(special_weapon_attack, "AutoEMP", "strike", "emp", true)
		end
		if Toggles.AutoRailGun.Value then
			pcall(special_weapon_attack, "AutoRailGun", "strike", "rail", true)
		end
		if Toggles.AutoOrbital.Value then
			pcall(orbital_attack)
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
		if Toggles.AutoUpgrade.Value and upgrade_allowed("Navy Ships") then
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
