-- Sistema principale del Tycoon Fantasy.
-- Inserisci questo Script in ServerScriptService.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local DataStoreService = game:GetService("DataStoreService")

local playerStore
local legacyPlayerStore
local dataStoreAvailable, storeError = pcall(function()
	playerStore = DataStoreService:GetDataStore("TycoonArcano_PlayerData_v2")
	legacyPlayerStore = DataStoreService:GetDataStore("TycoonArcano_PlayerData_v1")
end)
if not dataStoreAvailable then
	playerStore = nil
	legacyPlayerStore = nil
	warn("DataStore non disponibile: la sessione userà dati temporanei. " .. tostring(storeError))
end

local world = Workspace:WaitForChild("TycoonWorld")
local plotsFolder = world:FindFirstChild("TycoonPlots")
local colors = {
	stone = Color3.fromRGB(46, 44, 57),
	trim = Color3.fromRGB(27, 25, 37),
	cyan = Color3.fromRGB(74, 225, 255),
	violet = Color3.fromRGB(177, 72, 255),
	gold = Color3.fromRGB(232, 180, 86),
	red = Color3.fromRGB(220, 75, 82),
	green = Color3.fromRGB(92, 220, 139),
}

local plotState = {}
local fractionalGains = {}
local lastAbilityUse = {}
local saveInProgress = {}
local dataReady = {}
local dataSaveEnabled = {}
local activeGuildContracts = {}

local golem = world:FindFirstChild("GolemAddestramento")
local golemHumanoid = golem and golem:FindFirstChildOfClass("Humanoid")
local golemHealthLabel = golem and golem:FindFirstChild("BarraVita", true)
if golemHumanoid and golemHealthLabel and golemHealthLabel:IsA("BillboardGui") then
	local healthText = golemHealthLabel:FindFirstChildOfClass("TextLabel")
	if healthText then
		golemHumanoid.HealthChanged:Connect(function(health)
			healthText.Text = "GOLEM  " .. math.ceil(health) .. " / 100"
		end)
	end
	golemHumanoid.Died:Connect(function()
		task.wait(3)
		if golemHumanoid.Parent then
			golemHumanoid.Health = golemHumanoid.MaxHealth
		end
	end)
end

local upgrades = {
	Forgia = {
		name = "Forgia Corrotta",
		prices = { Essenza = 25 },
		production = { Oro = 1 },
	},
	Conduttore = {
		name = "Conduttore Arcano",
		prices = { Oro = 35, Essenza = 30 },
		production = { Essenza = 2 },
		requires = "Forgia",
	},
	Portale = {
		name = "Portale dell'Abisso",
		prices = { Oro = 100, Essenza = 90 },
		production = { Oro = 2, Essenza = 3 },
		requires = "Conduttore",
	},
}

local classOrder = { "Arcanista", "Berserker", "Ombra", "Necromante", "Paladino", "Druido" }
local classChangeEvent = ReplicatedStorage:FindFirstChild("RequestClassChange")
if classChangeEvent and not classChangeEvent:IsA("RemoteEvent") then
	classChangeEvent:Destroy()
	classChangeEvent = nil
end
if not classChangeEvent then
	classChangeEvent = Instance.new("RemoteEvent")
	classChangeEvent.Name = "RequestClassChange"
	classChangeEvent.Parent = ReplicatedStorage
end

local contractUpdateEvent = ReplicatedStorage:FindFirstChild("GuildContractUpdate")
if contractUpdateEvent and not contractUpdateEvent:IsA("RemoteEvent") then
	contractUpdateEvent:Destroy()
	contractUpdateEvent = nil
end
if not contractUpdateEvent then
	contractUpdateEvent = Instance.new("RemoteEvent")
	contractUpdateEvent.Name = "GuildContractUpdate"
	contractUpdateEvent.Parent = ReplicatedStorage
end

local classBonuses = {
	Arcanista = { Oro = 1, Essenza = 1.5, tip = "Dardo arcano - +50% Essenza" },
	Berserker = { Oro = 1.5, Essenza = 1, tip = "Ondata d'urto - +50% Oro" },
	Ombra = { Oro = 1.25, Essenza = 1.25, tip = "Scatto d'ombra - +25% produzione" },
	Necromante = { Oro = 1.1, Essenza = 1.4, tip = "Lancia d'ossa - +40% Essenza" },
	Paladino = { Oro = 1.35, Essenza = 1, tip = "Nova sacra - +35% Oro" },
	Druido = { Oro = 1.15, Essenza = 1.3, tip = "Tempesta - +30% Essenza" },
}

local function getPlayerDataKey(player)
	return "player_" .. tostring(player.UserId)
end

local function loadPlayerData(player, leaderstats)
	if not dataStoreAvailable then
		dataReady[player] = true
		dataSaveEnabled[player] = false
		return
	end

	local success, data = pcall(function()
		return playerStore:GetAsync(getPlayerDataKey(player))
	end)

	if not success then
		warn("Caricamento dati v2 non riuscito per " .. player.Name .. ": " .. tostring(data))
		-- Si può giocare con valori di sessione, ma non sovrascrivere dati illeggibili.
		dataReady[player] = true
		dataSaveEnabled[player] = false
		return
	end

	local canSave = true
	if data == nil then
		local legacySuccess, legacyData = pcall(function()
			return legacyPlayerStore:GetAsync(getPlayerDataKey(player))
		end)
		if legacySuccess then
			data = legacyData
		else
			warn("Lettura dati precedenti non riuscita per " .. player.Name .. ": " .. tostring(legacyData))
			canSave = false
		end
	end
	if not player.Parent then
		return
	end
	dataReady[player] = true
	dataSaveEnabled[player] = canSave
	if type(data) ~= "table" then
		return
	end

	local savedGold = tonumber(data.Oro)
	local savedEssence = tonumber(data.Essenza)
	if savedGold and savedGold >= 0 then
		leaderstats.Oro.Value = math.floor(savedGold)
	end
	if savedEssence and savedEssence >= 0 then
		leaderstats.Essenza.Value = math.floor(savedEssence)
	end
	local savedFragments = tonumber(data.Frammenti)
	local savedPower = tonumber(data.Potenza)
	if savedFragments and savedFragments >= 0 then
		leaderstats.Frammenti.Value = math.floor(savedFragments)
	end
	if savedPower and savedPower >= 0 then
		leaderstats.Potenza.Value = math.floor(savedPower)
	end
	if type(data.Arma) == "string" then
		leaderstats.Arma.Value = string.sub(data.Arma, 1, 80)
	end

	local savedClass = data.Classe
	if table.find(classOrder, savedClass) then
		leaderstats.Classe.Value = savedClass
		player:SetAttribute("Classe", savedClass)
	end

	local state = plotState[player]
	local savedUpgrades = type(data.Upgrades) == "table" and data.Upgrades or {}
	if state then
		for _, upgradeId in ipairs({ "Forgia", "Conduttore", "Portale" }) do
			local upgrade = upgrades[upgradeId]
			if savedUpgrades[upgradeId] == true and (not upgrade.requires or state.ownedUpgrades[upgrade.requires]) then
				state.ownedUpgrades[upgradeId] = true
				for currency, amount in pairs(upgrade.production) do
					state.production[currency] += amount
				end
			end
		end
	end
end

local function savePlayerData(player)
	-- Non salvare valori iniziali se il caricamento o la migrazione sono falliti.
	if not dataReady[player] or not dataSaveEnabled[player] then
		return false
	end
	while saveInProgress[player] do
		task.wait(0.1)
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local gold = leaderstats and leaderstats:FindFirstChild("Oro")
	local essence = leaderstats and leaderstats:FindFirstChild("Essenza")
	local classStat = leaderstats and leaderstats:FindFirstChild("Classe")
	local fragments = leaderstats and leaderstats:FindFirstChild("Frammenti")
	local power = leaderstats and leaderstats:FindFirstChild("Potenza")
	local weapon = leaderstats and leaderstats:FindFirstChild("Arma")
	if not gold or not essence or not classStat or not fragments or not power or not weapon then
		return false
	end
	local state = plotState[player]

	local data = {
		SchemaVersion = 2,
		Oro = gold.Value,
		Essenza = essence.Value,
		Classe = classStat.Value,
		Frammenti = fragments.Value,
		Potenza = power.Value,
		Arma = weapon.Value,
		Upgrades = state and state.ownedUpgrades or {},
	}
	saveInProgress[player] = true
	local success, err = pcall(function()
		playerStore:UpdateAsync(getPlayerDataKey(player), function()
			return data
		end)
	end)
	saveInProgress[player] = nil

	if not success then
		warn("Salvataggio dati non riuscito per " .. player.Name .. ": " .. tostring(err))
	end
	return success
end

local function makePart(name, size, position, color, material, parent, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.Parent = parent
	return part
end

local function addPointLight(parent, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Parent = parent
	return light
end

local function buildMachine(id, plot)
	local origin = plot and plot:GetAttribute("PlotOrigin")
	if typeof(origin) ~= "Vector3" then
		return
	end
	local machineFolder = plot:FindFirstChild("Macchine")
	if not machineFolder then
		machineFolder = Instance.new("Folder")
		machineFolder.Name = "Macchine"
		machineFolder.Parent = plot
	end
	if machineFolder:FindFirstChild("Macchina " .. id) then
		return
	end
	local function point(x, y, z)
		return origin + Vector3.new(x, y, z)
	end

	local model = Instance.new("Model")
	model.Name = "Macchina " .. id
	model.Parent = machineFolder

	if id == "Forgia" then
		makePart("Basamento Forgia", Vector3.new(10, 2, 10), point(-19, 2, -6), colors.trim, Enum.Material.Basalt, model)
		makePart("Focolare", Vector3.new(6, 5, 6), point(-19, 5.5, -6), colors.stone, Enum.Material.Slate, model)
		local flame = makePart("Fiamma della Forgia", Vector3.new(2.6, 3.5, 2.6), point(-19, 10, -6), colors.red, Enum.Material.Neon, model, Enum.PartType.Ball)
		flame.CanCollide = false
		addPointLight(flame, colors.red, 1.8, 18)
	elseif id == "Conduttore" then
		makePart("Basamento Conduttore", Vector3.new(10, 2, 10), point(0, 2, -6), colors.trim, Enum.Material.Basalt, model)
		for _, xOffset in ipairs({ -3.5, 3.5 }) do
			for _, zOffset in ipairs({ -3.5, 3.5 }) do
				makePart("Colonna Conduttore", Vector3.new(1.4, 8, 1.4), point(xOffset, 5, -6 + zOffset), colors.stone, Enum.Material.Slate, model)
			end
		end
		local orb = makePart("Nucleo Conduttore", Vector3.new(3.2, 3.2, 3.2), point(0, 8, -6), colors.cyan, Enum.Material.Neon, model, Enum.PartType.Ball)
		orb.CanCollide = false
		addPointLight(orb, colors.cyan, 1.7, 18)
	elseif id == "Portale" then
		makePart("Soglia Portale", Vector3.new(16, 1.5, 4), point(19, 1.75, -6), colors.trim, Enum.Material.Basalt, model)
		makePart("Montante Portale sinistro", Vector3.new(2.5, 14, 3), point(13, 8, -6), colors.stone, Enum.Material.Slate, model)
		makePart("Montante Portale destro", Vector3.new(2.5, 14, 3), point(25, 8, -6), colors.stone, Enum.Material.Slate, model)
		makePart("Arco Portale", Vector3.new(14.5, 2.5, 3), point(19, 15.5, -6), colors.trim, Enum.Material.Basalt, model)
		local gate = makePart("Velo del Portale", Vector3.new(9, 11, 0.5), point(19, 8, -6), colors.violet, Enum.Material.Neon, model)
		gate.Transparency = 0.25
		gate.CanCollide = false
		addPointLight(gate, colors.violet, 2, 24)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DungeonEnterPrompt"
		prompt.ActionText = "Entra nel dungeon"
		prompt.ObjectText = "Rovine Dimenticate"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("DungeonEnter", true)
		prompt.Parent = gate
	end

	return model
end

local function formatPrice(prices)
	local pieces = {}
	for currency, amount in pairs(prices) do
		table.insert(pieces, tostring(amount) .. " " .. currency)
	end
	table.sort(pieces)
	return table.concat(pieces, " + ")
end

local function setUpgradePadState(plot, id, isOwned)
	if not plot then
		return
	end
	for _, descendant in ipairs(plot:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("UpgradeId") == id then
			descendant.Name = isOwned and ("Acquistato " .. id) or ("Piastra " .. id)
			descendant.Color = isOwned and colors.trim or colors.violet
			descendant.Material = isOwned and Enum.Material.Slate or Enum.Material.Neon
			local prompt = descendant:FindFirstChild("PurchasePrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = not isOwned
			end
		end
	end
end

local function connectPurchasePrompt(prompt)
	local id = prompt:GetAttribute("UpgradeId")
	local upgrade = upgrades[id]
	if not upgrade or prompt:GetAttribute("Connected") then
		return
	end
	prompt:SetAttribute("Connected", true)

	prompt.Triggered:Connect(function(player)
		local plot = prompt:FindFirstAncestorOfClass("Model")
		local state = plotState[player]
		if not dataReady[player] or not state or state.plot ~= plot or plot:GetAttribute("OwnerUserId") ~= player.UserId then
			return
		end
		if state.ownedUpgrades[id] then
			return
		end
		if upgrade.requires and not state.ownedUpgrades[upgrade.requires] then
			warn(upgrade.name .. " richiede prima " .. upgrades[upgrade.requires].name .. ".")
			return
		end

		local stats = player:FindFirstChild("leaderstats")
		if not stats then
			return
		end
		for currency, amount in pairs(upgrade.prices) do
			local stat = stats:FindFirstChild(currency)
			if not stat or stat.Value < amount then
				warn(player.Name .. " non ha abbastanza " .. currency .. " per " .. upgrade.name .. " (costo: " .. formatPrice(upgrade.prices) .. ").")
				return
			end
		end

		for currency, amount in pairs(upgrade.prices) do
			stats[currency].Value -= amount
		end
		state.ownedUpgrades[id] = true
		for currency, amount in pairs(upgrade.production) do
			state.production[currency] += amount
		end

		setUpgradePadState(plot, id, true)
		buildMachine(id, plot)
		task.spawn(savePlayerData, player)
		print(player.Name .. " ha acquistato " .. upgrade.name .. ". Produzione: +" .. formatPrice(upgrade.production) .. " al secondo.")
	end)
end

local function setPlayerClass(player, className)
	if not dataReady[player] then
		return
	end
	if not table.find(classOrder, className) then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	local classStat = stats and stats:FindFirstChild("Classe")
	if not classStat then
		return
	end
	classStat.Value = className
	player:SetAttribute("Classe", className)
	local containers = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then table.insert(containers, backpack) end
	if player.Character then table.insert(containers, player.Character) end
	for _, container in ipairs(containers) do
		local tool = container:FindFirstChild("Catalizzatore")
		if tool and tool:IsA("Tool") then
			tool.ToolTip = classBonuses[className].tip
		end
	end
	print(player.Name .. " ha scelto la classe " .. className .. ".")
end

local lastClassChange = {}
classChangeEvent.OnServerEvent:Connect(function(player, className)
	local now = os.clock()
	if now - (lastClassChange[player] or 0) < 0.5 then
		return
	end
	lastClassChange[player] = now
	setPlayerClass(player, className)
end)

local function connectUtilityPrompt(prompt)
	if prompt:GetAttribute("Connected") then
		return
	end
	local classId = prompt:GetAttribute("ClassId")
	local destinationY = prompt:GetAttribute("DestinationY")
	local dungeonEnter = prompt:GetAttribute("DungeonEnter") == true
	local dungeonExit = prompt:GetAttribute("DungeonExit") == true
	local hubDungeon = prompt:GetAttribute("HubDungeon") == true
	local guildContract = prompt:GetAttribute("GuildContract") == true
	if classId then
		prompt:SetAttribute("Connected", true)
		prompt.Triggered:Connect(function(player)
			setPlayerClass(player, classId)
		end)
	elseif destinationY then
		prompt:SetAttribute("Connected", true)
		prompt.Triggered:Connect(function(player)
			local requiredUpgrade = prompt:GetAttribute("RequiredUpgrade")
			local state = plotState[player]
			if requiredUpgrade and (not state or not state.ownedUpgrades[requiredUpgrade]) then
				warn("Sblocca prima " .. upgrades[requiredUpgrade].name .. " per usare l'ascensore.")
				return
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				root.AssemblyLinearVelocity = Vector3.zero
				root.CFrame = CFrame.new(35, destinationY, -113)
			end
		end)
	elseif guildContract then
		prompt:SetAttribute("Connected", true)
		prompt.Triggered:Connect(function(player)
			local state = plotState[player]
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local promptPart = prompt.Parent
			if not dataReady[player] or not state or not root or not promptPart or not promptPart:IsA("BasePart")
				or (root.Position - promptPart.Position).Magnitude > prompt.MaxActivationDistance + 4 then
				return
			end

			local contract = activeGuildContracts[player]
			if not contract then
				activeGuildContracts[player] = { defeated = 0 }
				contractUpdateEvent:FireClient(player, "Contratto accettato: sconfiggi 3 nemici nelle Rovine (0/3).")
			elseif contract.defeated >= 3 then
				local stats = player:FindFirstChild("leaderstats")
				local gold = stats and stats:FindFirstChild("Oro")
				local essence = stats and stats:FindFirstChild("Essenza")
				local fragments = stats and stats:FindFirstChild("Frammenti")
				if not gold or not essence or not fragments then
					return
				end
				gold.Value += 45
				essence.Value += 30
				fragments.Value += 2
				activeGuildContracts[player] = nil
				contractUpdateEvent:FireClient(player, "Contratto completato: +45 Oro, +30 Essenza, +2 Frammenti!")
				task.spawn(savePlayerData, player)
			else
				contractUpdateEvent:FireClient(player, "Contratto in corso: sconfiggi altri nemici nelle Rovine (" .. contract.defeated .. "/3).")
			end
		end)
	elseif dungeonEnter or dungeonExit or hubDungeon then
		prompt:SetAttribute("Connected", true)
		prompt.Triggered:Connect(function(player)
			local state = plotState[player]
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or not state then
				return
			end
			local promptPart = prompt.Parent
			if not promptPart or not promptPart:IsA("BasePart")
				or (root.Position - promptPart.Position).Magnitude > prompt.MaxActivationDistance + 4 then
				return
			end

			local destination
			if dungeonEnter then
				if not prompt:IsDescendantOf(state.plot)
					or state.plot:GetAttribute("OwnerUserId") ~= player.UserId
					or not state.ownedUpgrades.Portale then
					return
				end
				local lane = (player.UserId % 7) - 3
				destination = Vector3.new(lane * 7, 5, -332)
			elseif hubDungeon then
				if not prompt:IsDescendantOf(world)
					or state.plot:GetAttribute("OwnerUserId") ~= player.UserId
					or not state.ownedUpgrades.Portale then
					warn(player.Name .. " deve sbloccare il Portale nel proprio tycoon per usare quello della Gilda.")
					return
				end
				local lane = (player.UserId % 7) - 3
				destination = Vector3.new(lane * 7, 5, -332)
			else
				local origin = state.plot:GetAttribute("PlotOrigin")
				if typeof(origin) ~= "Vector3" or state.plot:GetAttribute("OwnerUserId") ~= player.UserId then
					return
				end
				destination = origin + Vector3.new(0, 5, 18)
			end
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = CFrame.new(destination)
		end)
	end
end

local function connectWorldPrompt(descendant)
	if not descendant:IsA("ProximityPrompt") then
		return
	end
	if descendant:GetAttribute("UpgradeId") then
		connectPurchasePrompt(descendant)
	else
		connectUtilityPrompt(descendant)
	end
end

for _, descendant in ipairs(world:GetDescendants()) do
	connectWorldPrompt(descendant)
end
world.DescendantAdded:Connect(connectWorldPrompt)

local room = Workspace:FindFirstChild("SalaArcanista")
local classCrystal = room and room:FindFirstChild("Cristallo arcano", true)
if classCrystal then
	local classPrompt = classCrystal:FindFirstChild("ClassPrompt")
	if not classPrompt then
		classPrompt = Instance.new("ProximityPrompt")
		classPrompt.Name = "ClassPrompt"
		classPrompt.ActionText = "Cambia classe"
		classPrompt.ObjectText = "Altare delle Classi"
		classPrompt.HoldDuration = 0.2
		classPrompt.MaxActivationDistance = 12
		classPrompt.RequiresLineOfSight = false
		classPrompt.Parent = classCrystal
	end

	classPrompt.Triggered:Connect(function(player)
		local classStat = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Classe")
		local currentIndex = table.find(classOrder, classStat and classStat.Value) or 1
		setPlayerClass(player, classOrder[currentIndex % #classOrder + 1])
	end)
else
	warn("Non trovo il Cristallo arcano nella SalaArcanista: l'altare delle classi non è stato collegato.")
end

local function getEnemyModel(part)
	local model = part:FindFirstAncestorOfClass("Model")
	if model and model:GetAttribute("TycoonEnemy") then
		return model
	end
	return nil
end

local weaponNames = {
	Arcanista = "Bastone",
	Berserker = "Ascia",
	Ombra = "Lame",
	Necromante = "Grimorio",
	Paladino = "Martello",
	Druido = "Ramo runico",
}

local function awardDungeonLoot(player, enemy)
	if not player or not player.Parent then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	local gold = stats and stats:FindFirstChild("Oro")
	local essence = stats and stats:FindFirstChild("Essenza")
	local fragments = stats and stats:FindFirstChild("Frammenti")
	local power = stats and stats:FindFirstChild("Potenza")
	local weapon = stats and stats:FindFirstChild("Arma")
	if not gold or not essence or not fragments or not power or not weapon then
		return
	end

	local isBoss = enemy:GetAttribute("IsDungeonBoss") == true
	local roll = math.random(1, 100)
	local rarity, powerGain
	if isBoss then
		if roll <= 25 then rarity, powerGain = "Non comune", 2
		elseif roll <= 70 then rarity, powerGain = "Raro", 4
		elseif roll <= 95 then rarity, powerGain = "Epico", 7
		else rarity, powerGain = "Leggendario", 12 end
	else
		if roll <= 55 then rarity, powerGain = "Comune", 1
		elseif roll <= 83 then rarity, powerGain = "Non comune", 2
		elseif roll <= 97 then rarity, powerGain = "Raro", 4
		else rarity, powerGain = "Epico", 7 end
	end

	local className = player:GetAttribute("Classe") or "Arcanista"
	local weaponBase = weaponNames[className] or weaponNames.Arcanista
	weapon.Value = weaponBase .. " " .. rarity .. " delle Rovine"
	power.Value += powerGain
	gold.Value += isBoss and 100 or 18
	essence.Value += isBoss and 75 or 12
	fragments.Value += isBoss and 6 or 1

	local contract = activeGuildContracts[player]
	if contract and contract.defeated < 3 then
		contract.defeated += 1
		if contract.defeated >= 3 then
			contractUpdateEvent:FireClient(player, "Contratto completato! Torna alla bacheca per riscuotere la ricompensa.")
		else
			contractUpdateEvent:FireClient(player, "Progresso contratto: " .. contract.defeated .. "/3 nemici sconfitti.")
		end
	end

	print(player.Name .. " ha ottenuto " .. weapon.Value .. " (Potenza +" .. powerGain .. ").")
	task.spawn(savePlayerData, player)
end

local function registerDungeonEnemy(enemy)
	if not enemy:IsA("Model") or enemy:GetAttribute("DungeonEnemy") ~= true or enemy:GetAttribute("CombatConnected") then
		return
	end
	enemy:SetAttribute("CombatConnected", true)
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local healthGui = enemy:FindFirstChild("BarraVita", true)
	local healthLabel = healthGui and healthGui:FindFirstChildWhichIsA("TextLabel", true)
	local enemyName = enemy:GetAttribute("EnemyDisplayName") or enemy.Name
	local deathHandled = false
	local function handleEnemyDeath()
		if deathHandled then
			return
		end
		deathHandled = true

		if not enemy:GetAttribute("LootClaimed") then
			enemy:SetAttribute("LootClaimed", true)
			local userId = enemy:GetAttribute("LastDamagerUserId")
			local killer = typeof(userId) == "number" and Players:GetPlayerByUserId(userId) or nil
			awardDungeonLoot(killer, enemy)
		end

		local respawnDelay = enemy:GetAttribute("IsDungeonBoss") and 18 or 10
		task.delay(respawnDelay, function()
			if not enemy.Parent then
				return
			end
			local parent = enemy.Parent
			local clone = enemy:Clone()
			clone:SetAttribute("CombatConnected", nil)
			clone:SetAttribute("LootClaimed", false)
			clone:SetAttribute("LastDamagerUserId", nil)
			clone:SetAttribute("DeathHandled", nil)
			clone:SetAttribute("NextAttackAt", 0)
			local oldHumanoid = clone:FindFirstChildOfClass("Humanoid")
			if oldHumanoid then
				oldHumanoid:Destroy()
			end
			local maxHealth = tonumber(clone:GetAttribute("MaxHealth")) or 70
			local freshHumanoid = Instance.new("Humanoid")
			freshHumanoid.Name = "Humanoid"
			freshHumanoid.MaxHealth = maxHealth
			freshHumanoid.Health = maxHealth
			freshHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			freshHumanoid.BreakJointsOnDeath = false
			freshHumanoid.Parent = clone
			clone.Parent = parent
			enemy:Destroy()
			registerDungeonEnemy(clone)
		end)
	end

	if healthLabel then
		healthLabel.Text = string.upper(enemyName) .. "  " .. math.ceil(humanoid.Health) .. " / " .. humanoid.MaxHealth
	end

	humanoid.HealthChanged:Connect(function(health)
		if healthLabel then
			healthLabel.Text = string.upper(enemyName) .. "  " .. math.ceil(health) .. " / " .. humanoid.MaxHealth
		end
		if health <= 0 then
			task.defer(handleEnemyDeath)
		end
	end)
	humanoid.Died:Connect(handleEnemyDeath)
end

local function damageEnemy(model, amount, attacker)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local character = attacker and attacker.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if attacker and (not root or (root.Position - model:GetPivot().Position).Magnitude > 220) then
		return
	end
	local stats = attacker and attacker:FindFirstChild("leaderstats")
	local power = stats and stats:FindFirstChild("Potenza")
	local scaledAmount = math.max(1, math.floor(amount * (1 + ((power and power.Value or 0) * 0.03))))
	if attacker then
		model:SetAttribute("LastDamagerUserId", attacker.UserId)
	end
	-- TakeDamage può lasciare Health sotto zero quando un colpo supera gli HP
	-- rimasti; in quel caso Humanoid.Died non scatta sempre. Limita il danno
	-- agli HP effettivi, preservando il controllo dei ForceField.
	humanoid:TakeDamage(math.min(scaledAmount, humanoid.Health))
end

local function damageEnemiesNear(position, radius, amount, attacker)
	local hitModels = {}
	for _, part in ipairs(Workspace:GetPartBoundsInRadius(position, radius)) do
		local model = getEnemyModel(part)
		if model and not hitModels[model] then
			hitModels[model] = true
			damageEnemy(model, amount, attacker)
		end
	end
end

local dungeon = world:FindFirstChild("DungeonRovine")
if dungeon then
	for _, descendant in ipairs(dungeon:GetChildren()) do
		registerDungeonEnemy(descendant)
	end
else
	warn("DungeonRovine non trovato: riesegui TycoonWorld.lua per creare l'arena PvE.")
end

local function getNearestPlayer(position, maxDistance)
	local nearestPlayer, nearestRoot, nearestHumanoid
	local nearestDistance = maxDistance
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local distance = (root.Position - position).Magnitude
			if distance <= nearestDistance then
				nearestPlayer, nearestRoot, nearestHumanoid = player, root, humanoid
				nearestDistance = distance
			end
		end
	end
	return nearestPlayer, nearestRoot, nearestHumanoid
end

task.spawn(function()
	while true do
		task.wait(0.3)
		if dungeon and dungeon.Parent then
			for _, enemy in ipairs(dungeon:GetChildren()) do
				local humanoid = enemy:IsA("Model") and enemy:FindFirstChildOfClass("Humanoid")
				local root = enemy:IsA("Model") and (enemy.PrimaryPart or enemy:FindFirstChild("Corpo"))
				if enemy:IsA("Model") and enemy:GetAttribute("DungeonEnemy") and humanoid and humanoid.Health > 0 and root then
					local player, targetRoot, targetHumanoid = getNearestPlayer(root.Position, enemy:GetAttribute("AttackRange") or 30)
					local now = os.clock()
					if player and now >= (enemy:GetAttribute("NextAttackAt") or 0) then
						enemy:SetAttribute("NextAttackAt", now + (enemy:GetAttribute("AttackCooldown") or 2.5))
						local impactPosition = targetRoot.Position
						local orb = Instance.new("Part")
						orb.Name = "Proiettile Nemico"
						orb.Shape = Enum.PartType.Ball
						orb.Size = Vector3.new(1.4, 1.4, 1.4)
						orb.Material = Enum.Material.Neon
						orb.Color = enemy:GetAttribute("IsDungeonBoss") and colors.gold or colors.violet
						orb.Anchored = true
						orb.CanCollide = false
						orb.Position = root.Position + Vector3.new(0, 2, 0)
						orb.Parent = Workspace
						TweenService:Create(orb, TweenInfo.new(0.45), { Position = impactPosition }):Play()
						Debris:AddItem(orb, 0.55)
						task.delay(0.45, function()
							if targetRoot.Parent and targetHumanoid.Health > 0 and (targetRoot.Position - impactPosition).Magnitude <= 7 then
								targetHumanoid:TakeDamage(enemy:GetAttribute("AttackDamage") or 9)
							end
						end)
					end
				end
			end
		end
	end
end)

local function castStraightBolt(player, root, character, boltName, color, size, speed, damage)
	local direction = root.CFrame.LookVector
	local origin = root.Position + direction * 3
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }
	rayParams.IgnoreWater = true

	local result = Workspace:Raycast(origin, direction * 120, rayParams)
	local targetPosition = result and result.Position or (origin + direction * 120)
	if result then
		local enemy = getEnemyModel(result.Instance)
		if enemy then
			damageEnemy(enemy, damage, player)
		end
	end

	local bolt = Instance.new("Part")
	bolt.Name = boltName
	bolt.Shape = Enum.PartType.Ball
	bolt.Size = Vector3.new(size, size, size)
	bolt.Material = Enum.Material.Neon
	bolt.Color = color
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.CanTouch = false
	bolt.CFrame = CFrame.new(origin)
	bolt.Parent = Workspace
	addPointLight(bolt, color, 1.2, 10)

	local travelTime = math.clamp((targetPosition - origin).Magnitude / speed, 0.08, 1.2)
	TweenService:Create(
		bolt,
		TweenInfo.new(travelTime, Enum.EasingStyle.Linear),
		{ Position = targetPosition }
	):Play()
	Debris:AddItem(bolt, travelTime + 0.15)
end

local function useCatalyst(player, tool)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or tool.Parent ~= character then
		return
	end

	local now = os.clock()
	if now - (lastAbilityUse[player] or 0) < 0.8 then
		return
	end
	lastAbilityUse[player] = now

	local className = player:GetAttribute("Classe") or "Arcanista"
	local direction = root.CFrame.LookVector

	if className == "Arcanista" then
		castStraightBolt(player, root, character, "Dardo Arcano", colors.cyan, 1.3, 100, 25)
	elseif className == "Berserker" then
		local center = root.Position + direction * 4
		damageEnemiesNear(center, 10, 35, player)
		local wave = Instance.new("Part")
		wave.Name = "Ondata Berserker"
		wave.Shape = Enum.PartType.Ball
		wave.Size = Vector3.new(2, 2, 2)
		wave.CFrame = CFrame.new(center)
		wave.Anchored = true
		wave.CanCollide = false
		wave.Material = Enum.Material.Neon
		wave.Color = colors.red
		wave.Transparency = 0.35
		wave.Parent = Workspace
		TweenService:Create(wave, TweenInfo.new(0.35), { Size = Vector3.new(20, 20, 20), Transparency = 1 }):Play()
		Debris:AddItem(wave, 0.4)
	elseif className == "Necromante" then
		castStraightBolt(player, root, character, "Lancia d'Ossa", colors.green, 1.6, 90, 32)
	elseif className == "Paladino" then
		local center = root.Position
		damageEnemiesNear(center, 12, 28, player)
		local nova = Instance.new("Part")
		nova.Name = "Nova Sacra"
		nova.Shape = Enum.PartType.Ball
		nova.Size = Vector3.new(2, 2, 2)
		nova.CFrame = CFrame.new(center)
		nova.Anchored = true
		nova.CanCollide = false
		nova.Material = Enum.Material.Neon
		nova.Color = colors.gold
		nova.Transparency = 0.3
		nova.Parent = Workspace
		TweenService:Create(nova, TweenInfo.new(0.45), { Size = Vector3.new(24, 24, 24), Transparency = 1 }):Play()
		Debris:AddItem(nova, 0.5)
	elseif className == "Druido" then
		local center = root.Position + direction * 8
		damageEnemiesNear(center, 16, 26, player)
		local lightning = Instance.new("Part")
		lightning.Name = "Tempesta del Druido"
		lightning.Size = Vector3.new(1.6, 26, 1.6)
		lightning.CFrame = CFrame.new(center + Vector3.new(0, 13, 0))
		lightning.Anchored = true
		lightning.CanCollide = false
		lightning.Material = Enum.Material.Neon
		lightning.Color = colors.green
		lightning.Parent = Workspace
		TweenService:Create(lightning, TweenInfo.new(0.25), { Transparency = 1, Size = Vector3.new(4, 26, 4) }):Play()
		Debris:AddItem(lightning, 0.3)
	else
		root.AssemblyLinearVelocity = direction * 82 + Vector3.new(0, 12, 0)
		task.delay(0.15, function()
			if root.Parent then
				damageEnemiesNear(root.Position + direction * 4, 7, 20, player)
			end
		end)
	end
end

local function giveCatalyst(player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	for _, container in ipairs({ backpack, player.Character }) do
		if container then
			local oldTool = container:FindFirstChild("Catalizzatore")
			if oldTool then
				oldTool:Destroy()
			end
		end
	end

	local tool = Instance.new("Tool")
	tool.Name = "Catalizzatore"
	tool.ToolTip = classBonuses[player:GetAttribute("Classe") or "Arcanista"].tip
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.8, 0.8, 3)
	handle.Color = colors.violet
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	tool.Activated:Connect(function()
		useCatalyst(player, tool)
	end)
	tool.Parent = backpack
end

local function setPlotOwnerLabel(plot, text)
	local ownerSign = plot and plot:FindFirstChild("Targa proprietario")
	local label = ownerSign and ownerSign:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		label.Text = text
	end
end

local function claimPlot(player)
	if not plotsFolder then
		warn("TycoonPlots non trovato. Riesegui TycoonWorld.lua in Roblox Studio.")
		return nil
	end
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:IsA("Model") and (plot:GetAttribute("OwnerUserId") or 0) == 0 then
			plot:SetAttribute("OwnerUserId", player.UserId)
			plotState[player] = {
				plot = plot,
				production = { Oro = 0, Essenza = 1 },
				ownedUpgrades = {},
			}
			setPlotOwnerLabel(plot, "BASE DI " .. string.upper(player.DisplayName))
			return plot
		end
	end
	warn("Nessun lotto libero per " .. player.Name .. ". Aumenta i lotti in TycoonWorld.lua.")
	return nil
end

local function restorePlotUpgrades(player)
	local state = plotState[player]
	if not state then
		return
	end
	for _, upgradeId in ipairs({ "Forgia", "Conduttore", "Portale" }) do
		if state.ownedUpgrades[upgradeId] then
			setUpgradePadState(state.plot, upgradeId, true)
			buildMachine(upgradeId, state.plot)
		end
	end
end

local function moveCharacterToPlot(player, character)
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10)
	local state = plotState[player]
	local origin = state and state.plot:GetAttribute("PlotOrigin")
	if root and typeof(origin) == "Vector3" and player.Parent and state.plot:GetAttribute("OwnerUserId") == player.UserId then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(origin + Vector3.new(0, 5, 18))
	end
end

local function releasePlot(player)
	local state = plotState[player]
	local plot = state and state.plot
	if plot and plot.Parent then
		local machines = plot:FindFirstChild("Macchine")
		if machines then
			machines:ClearAllChildren()
		end
		for _, upgradeId in ipairs({ "Forgia", "Conduttore", "Portale" }) do
			setUpgradePadState(plot, upgradeId, false)
		end
		plot:SetAttribute("OwnerUserId", 0)
		setPlotOwnerLabel(plot, "BASE LIBERA")
	end
	plotState[player] = nil
end

local function setupPlayer(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local gold = Instance.new("IntValue")
	gold.Name = "Oro"
	gold.Value = 50
	gold.Parent = leaderstats

	local essence = Instance.new("IntValue")
	essence.Name = "Essenza"
	essence.Value = 25
	essence.Parent = leaderstats

	local fragments = Instance.new("IntValue")
	fragments.Name = "Frammenti"
	fragments.Value = 0
	fragments.Parent = leaderstats

	local power = Instance.new("IntValue")
	power.Name = "Potenza"
	power.Value = 0
	power.Parent = leaderstats

	local weapon = Instance.new("StringValue")
	weapon.Name = "Arma"
	weapon.Value = "Nessuna"
	weapon.Parent = leaderstats

	local classStat = Instance.new("StringValue")
	classStat.Name = "Classe"
	classStat.Value = "Arcanista"
	classStat.Parent = leaderstats
	player:SetAttribute("Classe", "Arcanista")
	fractionalGains[player] = { Oro = 0, Essenza = 0 }
	claimPlot(player)

	local function onCharacterAdded(character)
		task.spawn(function()
			while player.Parent and not dataReady[player] do
				task.wait(0.1)
			end
			if not player.Parent then
				return
			end
			moveCharacterToPlot(player, character)
			task.wait(0.5)
			giveCatalyst(player)
		end)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	loadPlayerData(player, leaderstats)
	if not player.Parent then
		return
	end
	restorePlotUpgrades(player)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player)
	releasePlot(player)
	fractionalGains[player] = nil
	lastAbilityUse[player] = nil
	lastClassChange[player] = nil
	activeGuildContracts[player] = nil
	dataReady[player] = nil
	dataSaveEnabled[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	if not player:FindFirstChild("leaderstats") then
		setupPlayer(player)
	end
end

game:BindToClose(function()
	local remaining = 0
	for _, player in ipairs(Players:GetPlayers()) do
		remaining += 1
		task.spawn(function()
			savePlayerData(player)
			remaining -= 1
		end)
	end

	local startedAt = os.clock()
	while remaining > 0 and os.clock() - startedAt < 25 do
		task.wait(0.1)
	end
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			savePlayerData(player)
			task.wait(0.2)
		end
	end
end)

while true do
	task.wait(1)
	for _, player in ipairs(Players:GetPlayers()) do
		local stats = player:FindFirstChild("leaderstats")
		local fractions = fractionalGains[player]
		local state = plotState[player]
		if stats and fractions and state and dataReady[player] then
			local className = player:GetAttribute("Classe") or "Arcanista"
			local multipliers = classBonuses[className] or classBonuses.Arcanista
			for _, currency in ipairs({ "Oro", "Essenza" }) do
				local stat = stats:FindFirstChild(currency)
				if stat then
					local amount = state.production[currency] * multipliers[currency] + fractions[currency]
					local wholeAmount = math.floor(amount)
					fractions[currency] = amount - wholeAmount
					stat.Value += wholeAmount
				end
			end
		end
	end
end
