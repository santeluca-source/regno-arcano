-- Area esterna e punti di acquisto del tycoon fantasy.
-- Esegui questo file una volta dalla Command Bar di Roblox Studio.

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local existingWorld = Workspace:FindFirstChild("TycoonWorld")
if existingWorld then
	local olderBackup = ServerStorage:FindFirstChild("TycoonWorld_Backup")
	if olderBackup then
		olderBackup.Name = "TycoonWorld_Backup_Previous_" .. os.date("!%Y%m%d_%H%M%S")
	end
	existingWorld.Name = "TycoonWorld_Backup"
	existingWorld.Parent = ServerStorage
end

local world = Instance.new("Folder")
world.Name = "TycoonWorld"
world.Parent = Workspace

local colors = {
	stone = Color3.fromRGB(140, 179, 200),
	trim = Color3.fromRGB(89, 106, 145),
	cyan = Color3.fromRGB(87, 222, 255),
	violet = Color3.fromRGB(180, 137, 255),
	gold = Color3.fromRGB(255, 219, 112),
	red = Color3.fromRGB(255, 127, 112),
	green = Color3.fromRGB(120, 232, 164),
	white = Color3.fromRGB(246, 250, 255),
	grass = Color3.fromRGB(124, 207, 140),
	platform = Color3.fromRGB(220, 235, 225),
}

local baseplate = Workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	baseplate.Color = colors.grass
	baseplate.Material = Enum.Material.Grass
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
	part.Parent = parent or world
	return part
end

local function addSign(adornee, text, color, size, offset, alwaysOnTop)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Etichetta"
	gui.Adornee = adornee
	local dimensions = size or Vector2.new(180, 36)
	gui.Size = UDim2.fromOffset(dimensions.X, dimensions.Y)
	gui.StudsOffset = offset or Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = alwaysOnTop == true
	gui.MaxDistance = 110
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = colors.trim
	label.BackgroundTransparency = 0.15
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

-- Piazza esterna e camminamento tra la sala iniziale e la fortezza.
makePart("Cortile del Tycoon", Vector3.new(136, 1, 122), Vector3.new(0, 0.5, -92), colors.stone, Enum.Material.Slate)
makePart("Sentiero arcano", Vector3.new(18, 0.2, 40), Vector3.new(0, 1.1, -48), colors.trim, Enum.Material.Basalt)
makePart("Soglia della Fortezza", Vector3.new(30, 0.4, 4), Vector3.new(0, 1.35, -66), colors.gold, Enum.Material.Neon)

-- Hub condiviso: tutti i giocatori dello stesso server vedono questa piazza.
local plaza = Instance.new("Model")
plaza.Name = "PiazzaCondivisa"
plaza.Parent = world

makePart("Piattaforma della Gilda", Vector3.new(58, 0.7, 34), Vector3.new(0, 1.2, -43), colors.platform, Enum.Material.SmoothPlastic, plaza)
makePart("Bordo luminoso della Gilda", Vector3.new(58, 0.3, 1), Vector3.new(0, 1.7, -60), colors.gold, Enum.Material.Neon, plaza)
makePart("Bordo luminoso della Gilda", Vector3.new(58, 0.3, 1), Vector3.new(0, 1.7, -26), colors.gold, Enum.Material.Neon, plaza)
makePart("Bordo laterale della Gilda", Vector3.new(1, 0.3, 34), Vector3.new(-28.5, 1.7, -43), colors.cyan, Enum.Material.Neon, plaza)
makePart("Bordo laterale della Gilda", Vector3.new(1, 0.3, 34), Vector3.new(28.5, 1.7, -43), colors.cyan, Enum.Material.Neon, plaza)

local plazaSign = makePart("Insegna Piazza Condivisa", Vector3.new(28, 5, 1), Vector3.new(0, 10, -59), colors.trim, Enum.Material.Basalt, plaza)
addSign(plazaSign, "PIAZZA DELLA GILDA", colors.gold, Vector2.new(250, 44), Vector3.new(0, 3, 0), true)

-- Bacheca: il contratto e i progressi sono individuali anche se la piazza è condivisa.
makePart("Montante bacheca gilda", Vector3.new(1.5, 7, 1.5), Vector3.new(-22, 5, -43), colors.trim, Enum.Material.WoodPlanks, plaza)
local questBoard = makePart("Bacheca contratti", Vector3.new(12, 7, 1), Vector3.new(-22, 9, -43), colors.trim, Enum.Material.WoodPlanks, plaza)
addSign(questBoard, "CONTRATTI DELLA GILDA\n3 nemici nelle Rovine\nRicompensa: 45 Oro · 30 Essenza · 2 Frammenti", colors.gold, Vector2.new(260, 80), Vector3.new(0, 4.5, 0), true)
local questPrompt = Instance.new("ProximityPrompt")
questPrompt.Name = "GuildContractPrompt"
questPrompt.ActionText = "Accetta / riscuoti"
questPrompt.ObjectText = "Bacheca della Gilda"
questPrompt.HoldDuration = 0.3
questPrompt.MaxActivationDistance = 12
questPrompt.RequiresLineOfSight = false
questPrompt:SetAttribute("GuildContract", true)
questPrompt.Parent = questBoard

-- Piccola custode della Gilda, punto di riferimento leggibile nella piazza.
local guildKeeper = Instance.new("Model")
guildKeeper.Name = "Custode della Gilda"
guildKeeper.Parent = plaza
makePart("Veste della Custode", Vector3.new(3, 5, 2.5), Vector3.new(-22, 4.5, -52), colors.violet, Enum.Material.Fabric, guildKeeper)
local keeperHead = makePart("Volto della Custode", Vector3.new(2.5, 2.5, 2.5), Vector3.new(-22, 8, -52), colors.white, Enum.Material.SmoothPlastic, guildKeeper, Enum.PartType.Ball)
local keeperCrystal = makePart("Cristallo della Custode", Vector3.new(1.3, 1.3, 1.3), Vector3.new(-25, 5, -52), colors.cyan, Enum.Material.Neon, guildKeeper, Enum.PartType.Ball)
keeperCrystal.CanCollide = false
local keeperLight = Instance.new("PointLight")
keeperLight.Color = colors.cyan
keeperLight.Brightness = 1
keeperLight.Range = 12
keeperLight.Parent = keeperCrystal
addSign(keeperHead, "ELARA · CUSTODE DELLA GILDA", colors.white, Vector2.new(235, 38), Vector3.new(0, 2.5, 0), true)

-- Il portale è pubblico ma richiede comunque il Portale acquistato nel proprio tycoon.
local hubPortalX, hubPortalZ = 22, -43
makePart("Piedistallo Portale Pubblico", Vector3.new(20, 1.5, 7), Vector3.new(hubPortalX, 2.1, hubPortalZ), colors.trim, Enum.Material.Basalt, plaza)
makePart("Montante Portale Pubblico sinistro", Vector3.new(2.5, 14, 3), Vector3.new(hubPortalX - 6.5, 8.5, hubPortalZ), colors.stone, Enum.Material.Slate, plaza)
makePart("Montante Portale Pubblico destro", Vector3.new(2.5, 14, 3), Vector3.new(hubPortalX + 6.5, 8.5, hubPortalZ), colors.stone, Enum.Material.Slate, plaza)
makePart("Arco Portale Pubblico", Vector3.new(15.5, 2.5, 3), Vector3.new(hubPortalX, 16, hubPortalZ), colors.gold, Enum.Material.Basalt, plaza)
local hubGate = makePart("Velo Portale Pubblico", Vector3.new(10, 11, 0.6), Vector3.new(hubPortalX, 8.5, hubPortalZ), colors.violet, Enum.Material.Neon, plaza)
hubGate.Transparency = 0.22
hubGate.CanCollide = false
local hubGateLight = Instance.new("PointLight")
hubGateLight.Color = colors.violet
hubGateLight.Brightness = 2
hubGateLight.Range = 22
hubGateLight.Parent = hubGate
addSign(hubGate, "ROVINE DIMENTICATE", colors.white, Vector2.new(210, 36), Vector3.new(0, 7, 0), true)
local hubPortalPrompt = Instance.new("ProximityPrompt")
hubPortalPrompt.Name = "HubDungeonPrompt"
hubPortalPrompt.ActionText = "Entra nel dungeon"
hubPortalPrompt.ObjectText = "Portale della Gilda"
hubPortalPrompt.HoldDuration = 0.4
hubPortalPrompt.MaxActivationDistance = 12
hubPortalPrompt.RequiresLineOfSight = false
hubPortalPrompt:SetAttribute("HubDungeon", true)
hubPortalPrompt.Parent = hubGate

-- Fortezza gotica su tre piani, ispirata alla struttura di un tycoon verticale.
local fortress = Instance.new("Model")
fortress.Name = "Fortezza del Crepuscolo"
fortress.Parent = world

local buildingZ = -96
local frontZ = -68
local floors = {
	{ name = "Piano I - Sala delle Classi", y = 1 },
	{ name = "Piano II - Forgia e Laboratorio", y = 19 },
	{ name = "Piano III - Portale dell'Abisso", y = 37 },
}

for floorIndex, floorInfo in ipairs(floors) do
	makePart(floorInfo.name, Vector3.new(82, 2, 54), Vector3.new(0, floorInfo.y, buildingZ), colors.trim, Enum.Material.Basalt, fortress)
	local wallCenterY = floorInfo.y + 9
	makePart("Parete laterale sinistra " .. floorIndex, Vector3.new(2, 16, 54), Vector3.new(-41, wallCenterY, buildingZ), colors.stone, Enum.Material.Slate, fortress)
	makePart("Parete laterale destra " .. floorIndex, Vector3.new(2, 16, 54), Vector3.new(41, wallCenterY, buildingZ), colors.stone, Enum.Material.Slate, fortress)
	makePart("Parete posteriore " .. floorIndex, Vector3.new(82, 16, 2), Vector3.new(0, wallCenterY, -123), colors.stone, Enum.Material.Slate, fortress)

	local paneY = floorInfo.y + 9
	if floorIndex == 1 then
		for _, x in ipairs({ -25, 25 }) do
			local pane = makePart("Vetrata gotica piano terra", Vector3.new(30, 14, 0.6), Vector3.new(x, paneY, frontZ), colors.cyan, Enum.Material.Glass, fortress)
			pane.Transparency = 0.65
		end
		-- Ingresso aperto al centro, incorniciato da pietra scura.
		makePart("Montante portale sinistro", Vector3.new(2, 16, 3), Vector3.new(-10, wallCenterY, frontZ - 0.5), colors.trim, Enum.Material.Basalt, fortress)
		makePart("Montante portale destro", Vector3.new(2, 16, 3), Vector3.new(10, wallCenterY, frontZ - 0.5), colors.trim, Enum.Material.Basalt, fortress)
		makePart("Arco portale della Fortezza", Vector3.new(22, 2, 3), Vector3.new(0, floorInfo.y + 17, frontZ - 0.5), colors.gold, Enum.Material.Basalt, fortress)
	else
		local pane = makePart("Vetrata panoramica piano " .. floorIndex, Vector3.new(78, 14, 0.6), Vector3.new(0, paneY, frontZ), colors.cyan, Enum.Material.Glass, fortress)
		pane.Transparency = 0.65
	end

	for _, x in ipairs({ -40, -20, 0, 20, 40 }) do
		makePart("Costola di facciata " .. floorIndex, Vector3.new(1.2, 16, 1.4), Vector3.new(x, wallCenterY, frontZ - 0.7), colors.trim, Enum.Material.Basalt, fortress)
	end
	makePart("Cornice orizzontale " .. floorIndex, Vector3.new(84, 1.2, 2), Vector3.new(0, floorInfo.y + 17, frontZ - 0.6), colors.trim, Enum.Material.Basalt, fortress)

end

-- Quattro torri angolari e una guglia luminosa danno alla fortezza una sagoma gotica.
for _, x in ipairs({ -36, 36 }) do
	for _, z in ipairs({ -70, -121 }) do
		makePart("Torre angolare", Vector3.new(10, 56, 10), Vector3.new(x, 28, z), colors.trim, Enum.Material.Basalt, fortress)
		makePart("Corona torre", Vector3.new(12, 2, 12), Vector3.new(x, 57, z), colors.gold, Enum.Material.Slate, fortress)
		local spire = makePart("Fiamma della torre", Vector3.new(2.5, 4, 2.5), Vector3.new(x, 60, z), colors.violet, Enum.Material.Neon, fortress, Enum.PartType.Ball)
		spire.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = colors.violet
		light.Brightness = 0.8
		light.Range = 14
		light.Parent = spire
	end
end

makePart("Tetto della Fortezza", Vector3.new(30, 3, 20), Vector3.new(0, 57, buildingZ), colors.trim, Enum.Material.Basalt, fortress)
local crownCrystal = makePart("Cristallo della Guglia", Vector3.new(4, 7, 4), Vector3.new(0, 62, buildingZ), colors.cyan, Enum.Material.Neon, fortress)
crownCrystal.CanCollide = false
local crownLight = Instance.new("PointLight")
crownLight.Color = colors.cyan
crownLight.Brightness = 2
crownLight.Range = 24
crownLight.Parent = crownCrystal
local nameplate = makePart("Targa Fortezza", Vector3.new(22, 3, 1), Vector3.new(0, 18, frontZ - 2), colors.trim, Enum.Material.Basalt, fortress)
addSign(nameplate, "FORTEZZA DEL CREPUSCOLO", colors.gold, Vector2.new(260, 42), Vector3.new(0, 3, 0), true)

for _, x in ipairs({ -27, 27 }) do
	makePart("Stendardo cremisi", Vector3.new(6, 11, 0.5), Vector3.new(x, 28, frontZ - 2), colors.red, Enum.Material.Fabric, fortress)
	local emblem = makePart("Emblema dello stendardo", Vector3.new(1.8, 1.8, 0.4), Vector3.new(x, 29, frontZ - 2.4), colors.gold, Enum.Material.Neon, fortress, Enum.PartType.Ball)
	emblem.CanCollide = false
end

for _, x in ipairs({ -13, 13 }) do
	local flame = makePart("Braciere dell'ingresso", Vector3.new(1.5, 2, 1.5), Vector3.new(x, 7, frontZ - 2), colors.violet, Enum.Material.Neon, fortress, Enum.PartType.Ball)
	flame.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = colors.violet
	light.Brightness = 1.2
	light.Range = 16
	light.Parent = flame
end

-- Sei altari, ciascuno collegato a una classe selezionabile.
local classShrines = {
	{ id = "Arcanista", color = colors.cyan, position = Vector3.new(-25, 2.8, -86) },
	{ id = "Berserker", color = colors.red, position = Vector3.new(0, 2.8, -86) },
	{ id = "Ombra", color = colors.violet, position = Vector3.new(25, 2.8, -86) },
	{ id = "Necromante", color = colors.green, position = Vector3.new(-25, 2.8, -106) },
	{ id = "Paladino", color = colors.gold, position = Vector3.new(0, 2.8, -106) },
	{ id = "Druido", color = colors.white, position = Vector3.new(25, 2.8, -106) },
}

for _, shrine in ipairs(classShrines) do
	local base = makePart("Altare " .. shrine.id, Vector3.new(7, 1.5, 7), shrine.position, colors.trim, Enum.Material.Basalt, fortress)
	local sigil = makePart("Sigillo " .. shrine.id, Vector3.new(2.2, 3.8, 2.2), shrine.position + Vector3.new(0, 2.5, 0), shrine.color, Enum.Material.Neon, fortress, Enum.PartType.Ball)
	sigil.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = shrine.color
	light.Brightness = 1
	light.Range = 12
	light.Parent = sigil
		local labelOffset = shrine.position.Z <= -100 and Vector3.new(0, 8, 0) or Vector3.new(0, 3, 0)
		addSign(base, string.upper(shrine.id), shrine.color, Vector2.new(150, 30), labelOffset)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ClassPrompt"
	prompt.ActionText = "Scegli classe"
	prompt.ObjectText = shrine.id
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ClassId", shrine.id)
	prompt.Parent = base
end

-- Ascensore runico per raggiungere i tre piani.
local elevatorX, elevatorZ = 35, -113
for floorIndex, floorInfo in ipairs(floors) do
	local floorTop = floorInfo.y + 1
	local padPosition = Vector3.new(elevatorX, floorTop + 0.35, elevatorZ)
	local pad = makePart("Ascensore runico piano " .. floorIndex, Vector3.new(0.7, 7, 7), padPosition, colors.violet, Enum.Material.Neon, fortress, Enum.PartType.Cylinder)
	pad.CFrame = CFrame.new(padPosition) * CFrame.Angles(0, 0, math.rad(90))
	pad.CanCollide = true
	local function addLiftPrompt(actionText, targetIndex, requiredUpgrade)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "LiftPrompt"
		prompt.ActionText = actionText
		prompt.ObjectText = "Ascensore runico"
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("DestinationY", floors[targetIndex].y + 5)
		if requiredUpgrade then
			prompt:SetAttribute("RequiredUpgrade", requiredUpgrade)
		end
		prompt.Parent = pad
	end
	if floorIndex > 1 then
		addLiftPrompt("Scendi al piano " .. (floorIndex - 1), floorIndex - 1)
	end
	if floorIndex < #floors then
		local requiredUpgrade = floorIndex == 1 and "Forgia" or "Conduttore"
		addLiftPrompt("Sali al piano " .. (floorIndex + 1), floorIndex + 1, requiredUpgrade)
	end
end

-- Fonte iniziale: produce Essenza appena il server parte.
local sourceBase = makePart("Base Fonte di Essenza", Vector3.new(10, 3, 10), Vector3.new(-30, 2.5, -42), colors.trim, Enum.Material.Basalt)
makePart("Piano Fonte di Essenza", Vector3.new(8, 1, 8), Vector3.new(-30, 4.5, -42), colors.stone, Enum.Material.Slate)
local sourceCrystal = makePart("Cristallo Fonte", Vector3.new(3, 4, 3), Vector3.new(-30, 8, -42), colors.cyan, Enum.Material.Neon)
sourceCrystal.CFrame = CFrame.new(-30, 8, -42) * CFrame.Angles(0, math.rad(45), 0)
sourceCrystal.CanCollide = false

local sourceLight = Instance.new("PointLight")
sourceLight.Color = colors.cyan
sourceLight.Brightness = 1.5
sourceLight.Range = 16
sourceLight.Parent = sourceCrystal

addSign(sourceBase, "FONTE DI ESSENZA", colors.cyan)

-- Prima arena PvE: si raggiunge dal Portale acquistato nella base personale.
local dungeon = Instance.new("Model")
dungeon.Name = "DungeonRovine"
dungeon.Parent = world

local dungeonCenterZ = -370
makePart("Pavimento delle Rovine", Vector3.new(132, 1, 116), Vector3.new(0, 0.5, dungeonCenterZ), colors.platform, Enum.Material.Slate, dungeon)
makePart("Muro Rovine Ovest", Vector3.new(2, 14, 116), Vector3.new(-65, 7.5, dungeonCenterZ), colors.stone, Enum.Material.Slate, dungeon)
makePart("Muro Rovine Est", Vector3.new(2, 14, 116), Vector3.new(65, 7.5, dungeonCenterZ), colors.stone, Enum.Material.Slate, dungeon)
makePart("Muro Rovine Nord", Vector3.new(132, 14, 2), Vector3.new(0, 7.5, -427), colors.stone, Enum.Material.Slate, dungeon)

for _, x in ipairs({ -48, -24, 24, 48 }) do
	makePart("Colonna delle Rovine", Vector3.new(4, 12, 4), Vector3.new(x, 7, -382), colors.trim, Enum.Material.Basalt, dungeon)
	local crystal = makePart("Cristallo delle Rovine", Vector3.new(2.4, 4.5, 2.4), Vector3.new(x, 3.5, -358), colors.cyan, Enum.Material.Neon, dungeon)
	crystal.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = colors.cyan
	light.Brightness = 0.8
	light.Range = 12
	light.Parent = crystal
end

local function makeDungeonEnemy(modelName, displayName, basePosition, health, bodyColor, isBoss)
	local enemy = Instance.new("Model")
	enemy.Name = modelName
	enemy:SetAttribute("TycoonEnemy", true)
	enemy:SetAttribute("DungeonEnemy", true)
	enemy:SetAttribute("IsDungeonBoss", isBoss)
	enemy:SetAttribute("EnemyDisplayName", displayName)
	enemy:SetAttribute("MaxHealth", health)
	enemy:SetAttribute("AttackRange", isBoss and 38 or 30)
	enemy:SetAttribute("AttackDamage", isBoss and 22 or 9)
	enemy:SetAttribute("AttackCooldown", isBoss and 1.7 or 2.5)
	enemy.Parent = dungeon

	local bodySize = isBoss and Vector3.new(9, 11, 8) or Vector3.new(5, 7, 4)
	local headSize = isBoss and Vector3.new(6, 6, 6) or Vector3.new(3.5, 3.5, 3.5)
	local bodyPosition = basePosition + Vector3.new(0, bodySize.Y / 2, 0)
	local headPosition = basePosition + Vector3.new(0, bodySize.Y + headSize.Y / 2 - 0.5, 0)
	local body = makePart("Corpo", bodySize, bodyPosition, bodyColor, Enum.Material.Slate, enemy)
	local head = makePart("Testa", headSize, headPosition, colors.stone, Enum.Material.Slate, enemy, Enum.PartType.Ball)
	local eyeSize = isBoss and 0.7 or 0.45
	for _, side in ipairs({ -1, 1 }) do
		local eye = makePart("Occhio", Vector3.new(eyeSize, eyeSize, 0.3), headPosition + Vector3.new(side * (isBoss and 1.25 or 0.8), 0, -(isBoss and 2.8 or 1.6)), colors.violet, Enum.Material.Neon, enemy)
		eye.CanCollide = false
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = enemy
	enemy.PrimaryPart = body

	local healthGui = Instance.new("BillboardGui")
	healthGui.Name = "BarraVita"
	healthGui.Adornee = head
	healthGui.Size = UDim2.fromOffset(210, 38)
	healthGui.StudsOffset = Vector3.new(0, headSize.Y / 2 + 2, 0)
	healthGui.AlwaysOnTop = true
	healthGui.Parent = head
	local healthLabel = Instance.new("TextLabel")
	healthLabel.Size = UDim2.fromScale(1, 1)
	healthLabel.BackgroundColor3 = colors.trim
	healthLabel.BackgroundTransparency = 0.08
	healthLabel.Text = string.upper(displayName) .. "  " .. health .. " / " .. health
	healthLabel.TextColor3 = isBoss and colors.gold or colors.white
	healthLabel.TextScaled = true
	healthLabel.Font = Enum.Font.GothamBold
	healthLabel.Parent = healthGui

	local aura = makePart("Aura Nemica", Vector3.new(isBoss and 3.5 or 2, isBoss and 3.5 or 2, isBoss and 3.5 or 2), headPosition, isBoss and colors.gold or colors.violet, Enum.Material.Neon, enemy, Enum.PartType.Ball)
	aura.Transparency = 0.45
	aura.CanCollide = false
	local auraLight = Instance.new("PointLight")
	auraLight.Color = aura.Color
	auraLight.Brightness = isBoss and 1.4 or 0.7
	auraLight.Range = isBoss and 20 or 12
	auraLight.Parent = aura
	return enemy
end

makeDungeonEnemy("CustodeRunico_1", "Custode Runico", Vector3.new(-28, 1, -382), 70, colors.violet, false)
makeDungeonEnemy("CustodeRunico_2", "Custode Runico", Vector3.new(0, 1, -392), 70, colors.green, false)
makeDungeonEnemy("CustodeRunico_3", "Custode Runico", Vector3.new(28, 1, -382), 70, colors.red, false)
makeDungeonEnemy("SentinellaAbisso", "Sentinella dell'Abisso", Vector3.new(0, 1, -411), 260, colors.trim, true)

local returnGate = makePart("Portale di Ritorno", Vector3.new(12, 10, 1), Vector3.new(0, 6, -319), colors.cyan, Enum.Material.Neon, dungeon)
returnGate.Transparency = 0.25
returnGate.CanCollide = false
addSign(returnGate, "RITORNA ALLA BASE", colors.white, Vector2.new(220, 40), Vector3.new(0, 7, 0), true)
local returnPrompt = Instance.new("ProximityPrompt")
returnPrompt.Name = "DungeonExitPrompt"
returnPrompt.ActionText = "Torna alla base"
returnPrompt.ObjectText = "Portale di Ritorno"
returnPrompt.HoldDuration = 0.25
returnPrompt.MaxActivationDistance = 12
returnPrompt.RequiresLineOfSight = false
returnPrompt:SetAttribute("DungeonExit", true)
returnPrompt.Parent = returnGate

-- Lotti personali: otto posti permettono a più giocatori di provare il ciclo
-- senza condividere pulsanti, macchine o progressi.
local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "TycoonPlots"
plotsFolder.Parent = world

local plotOrigins = {
	Vector3.new(-145, 0, 20),
	Vector3.new(145, 0, 20),
	Vector3.new(-145, 0, -220),
	Vector3.new(145, 0, -220),
	Vector3.new(-220, 0, -90),
	Vector3.new(220, 0, -90),
	Vector3.new(-220, 0, 170),
	Vector3.new(220, 0, 170),
}

local plotUpgrades = {
	{ id = "Forgia", text = "FORGIA\n25 Essenza", objectText = "Forgia | 25 Essenza", x = -19 },
	{ id = "Conduttore", text = "CONDUTTORE\n35 Oro + 30 Essenza", objectText = "Conduttore | 35 Oro + 30 Essenza", x = 0 },
	{ id = "Portale", text = "PORTALE\n100 Oro + 90 Essenza", objectText = "Portale | 100 Oro + 90 Essenza", x = 19 },
}

for index, origin in ipairs(plotOrigins) do
	local plot = Instance.new("Model")
	plot.Name = string.format("Lotto%02d", index)
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("PlotOrigin", origin)
	plot.Parent = plotsFolder

	makePart("Piattaforma base", Vector3.new(58, 1, 52), origin + Vector3.new(0, 0.5, 0), colors.platform, Enum.Material.SmoothPlastic, plot)
	makePart("Bordo base nord", Vector3.new(58, 1.2, 1), origin + Vector3.new(0, 1.1, -25.5), colors.gold, Enum.Material.Neon, plot)
	makePart("Bordo base sud", Vector3.new(58, 1.2, 1), origin + Vector3.new(0, 1.1, 25.5), colors.gold, Enum.Material.Neon, plot)
	makePart("Bordo base ovest", Vector3.new(1, 1.2, 52), origin + Vector3.new(-28.5, 1.1, 0), colors.gold, Enum.Material.Neon, plot)
	makePart("Bordo base est", Vector3.new(1, 1.2, 52), origin + Vector3.new(28.5, 1.1, 0), colors.gold, Enum.Material.Neon, plot)
	local garden = makePart("Giardino incantato", Vector3.new(50, 0.15, 8), origin + Vector3.new(0, 1.1, -19), colors.grass, Enum.Material.Grass, plot)
	garden.CanCollide = false

	local ownerSign = makePart("Targa proprietario", Vector3.new(12, 1, 1), origin + Vector3.new(0, 7, -23), colors.trim, Enum.Material.SmoothPlastic, plot)
	addSign(ownerSign, "BASE LIBERA", colors.white, Vector2.new(220, 42), Vector3.new(0, 2, 0), true)

	local source = makePart("Fonte personale", Vector3.new(8, 2, 8), origin + Vector3.new(-19, 2, -7), colors.trim, Enum.Material.SmoothPlastic, plot)
	local crystal = makePart("Cristallo fonte personale", Vector3.new(2.5, 4, 2.5), origin + Vector3.new(-19, 5, -7), colors.cyan, Enum.Material.Neon, plot)
	crystal.CFrame = CFrame.new(crystal.Position) * CFrame.Angles(0, math.rad(45), 0)
	crystal.CanCollide = false
	local sourceLight = Instance.new("PointLight")
	sourceLight.Color = colors.cyan
	sourceLight.Brightness = 1.2
	sourceLight.Range = 14
	sourceLight.Parent = crystal
	addSign(source, "FONTE PERSONALE", colors.cyan, Vector2.new(190, 34), Vector3.new(0, 3, 0))

	for _, definition in ipairs(plotUpgrades) do
		local padPosition = origin + Vector3.new(definition.x, 1.6, 14)
		local pad = makePart("Piastra " .. definition.id, Vector3.new(1, 7, 7), padPosition, colors.violet, Enum.Material.Neon, plot, Enum.PartType.Cylinder)
		pad.CFrame = CFrame.new(padPosition) * CFrame.Angles(0, 0, math.rad(90))
		pad:SetAttribute("UpgradeId", definition.id)
		addSign(pad, definition.text, colors.white, Vector2.new(185, 48), Vector3.new(0, 3.5, 0), true)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PurchasePrompt"
		prompt.ActionText = "Acquista"
		prompt.ObjectText = definition.objectText
		prompt.HoldDuration = 0.35
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("UpgradeId", definition.id)
		prompt.Parent = pad
	end
end

-- Golem da addestramento, bersaglio per le abilità delle classi.
local dummy = Instance.new("Model")
dummy.Name = "GolemAddestramento"
dummy:SetAttribute("TycoonEnemy", true)
dummy.Parent = world

local torso = makePart("Corpo", Vector3.new(5, 7, 4), Vector3.new(52, 4.5, -96), colors.red, Enum.Material.Slate, dummy)
local head = makePart("Testa", Vector3.new(3.5, 3.5, 3.5), Vector3.new(52, 9.7, -96), colors.stone, Enum.Material.Slate, dummy, Enum.PartType.Ball)
local eyeLeft = makePart("Occhio sinistro", Vector3.new(0.45, 0.45, 0.3), Vector3.new(51.2, 10, -94.2), colors.violet, Enum.Material.Neon, dummy)
local eyeRight = makePart("Occhio destro", Vector3.new(0.45, 0.45, 0.3), Vector3.new(52.8, 10, -94.2), colors.violet, Enum.Material.Neon, dummy)
eyeLeft.CanCollide = false
eyeRight.CanCollide = false

local humanoid = Instance.new("Humanoid")
humanoid.Name = "Humanoid"
humanoid.MaxHealth = 100
humanoid.Health = 100
humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
humanoid.Parent = dummy
dummy.PrimaryPart = torso

local healthGui = Instance.new("BillboardGui")
healthGui.Name = "BarraVita"
healthGui.Adornee = head
healthGui.Size = UDim2.fromOffset(180, 34)
healthGui.StudsOffset = Vector3.new(0, 3, 0)
healthGui.AlwaysOnTop = true
healthGui.Parent = head

local healthLabel = Instance.new("TextLabel")
healthLabel.Size = UDim2.fromScale(1, 1)
healthLabel.BackgroundColor3 = colors.trim
healthLabel.BackgroundTransparency = 0.1
healthLabel.Text = "GOLEM  100 / 100"
healthLabel.TextColor3 = colors.gold
healthLabel.TextScaled = true
healthLabel.Font = Enum.Font.GothamBold
healthLabel.Parent = healthGui

humanoid.HealthChanged:Connect(function(health)
	healthLabel.Text = "GOLEM  " .. math.ceil(health) .. " / 100"
end)

local golemLight = Instance.new("PointLight")
golemLight.Color = colors.violet
golemLight.Brightness = 0.7
golemLight.Range = 10
golemLight.Parent = head

print("Area tycoon fantasy creata in Workspace.TycoonWorld.")
