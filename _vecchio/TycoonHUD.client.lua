-- HUD del tycoon fantasy: risorse, classe attiva e suggerimenti.
-- Inserisci questo LocalScript in StarterPlayer > StarterPlayerScripts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local leaderstats = player:WaitForChild("leaderstats")
local gold = leaderstats:WaitForChild("Oro")
local essence = leaderstats:WaitForChild("Essenza")
local fragments = leaderstats:WaitForChild("Frammenti")
local power = leaderstats:WaitForChild("Potenza")
local weapon = leaderstats:WaitForChild("Arma")
local classStat = leaderstats:WaitForChild("Classe")
local classChangeEvent = ReplicatedStorage:WaitForChild("RequestClassChange")
local contractUpdateEvent = ReplicatedStorage:WaitForChild("GuildContractUpdate")

local oldGui = playerGui:FindFirstChild("TycoonHUD")
if oldGui then
	oldGui:Destroy()
end

local palette = {
	background = Color3.fromRGB(24, 22, 34),
	panel = Color3.fromRGB(39, 36, 53),
	cyan = Color3.fromRGB(74, 225, 255),
	violet = Color3.fromRGB(177, 72, 255),
	gold = Color3.fromRGB(232, 180, 86),
	white = Color3.fromRGB(244, 241, 255),
	muted = Color3.fromRGB(183, 178, 202),
}

local gui = Instance.new("ScreenGui")
gui.Name = "TycoonHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 10
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Pannello"
root.AnchorPoint = Vector2.new(0, 0)
root.Position = UDim2.fromOffset(18, 18)
root.Size = UDim2.fromOffset(360, 160)
root.BackgroundColor3 = palette.background
root.BackgroundTransparency = 0.08
root.BorderSizePixel = 0
root.Parent = gui

local rootCorner = Instance.new("UICorner")
rootCorner.CornerRadius = UDim.new(0, 14)
rootCorner.Parent = root

local outline = Instance.new("UIStroke")
outline.Color = palette.violet
outline.Thickness = 1.5
outline.Transparency = 0.2
outline.Parent = root

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 9)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = root

local title = Instance.new("TextLabel")
title.Name = "Titolo"
title.Size = UDim2.new(1, -108, 0, 22)
title.BackgroundTransparency = 1
title.Text = "TYCOON ARCANO"
title.TextColor3 = palette.white
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = root

local classToggle = Instance.new("TextButton")
classToggle.Name = "CambiaClasse"
classToggle.Position = UDim2.new(1, -100, 0, 0)
classToggle.Size = UDim2.fromOffset(100, 24)
classToggle.BackgroundColor3 = palette.gold
classToggle.BorderSizePixel = 0
classToggle.Text = "CAMBIA CLASSE"
classToggle.TextColor3 = palette.background
classToggle.TextSize = 11
classToggle.Font = Enum.Font.GothamBold
classToggle.AutoButtonColor = true
classToggle.Parent = root

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 7)
toggleCorner.Parent = classToggle

local resources = Instance.new("Frame")
resources.Name = "Risorse"
resources.Position = UDim2.fromOffset(0, 28)
resources.Size = UDim2.new(1, 0, 0, 34)
resources.BackgroundTransparency = 1
resources.Parent = root

local resourceLayout = Instance.new("UIListLayout")
resourceLayout.FillDirection = Enum.FillDirection.Horizontal
resourceLayout.Padding = UDim.new(0, 8)
resourceLayout.SortOrder = Enum.SortOrder.LayoutOrder
resourceLayout.Parent = resources

local function makeResource(name, color)
	local card = Instance.new("Frame")
	card.Name = name
	card.Size = UDim2.new(0.5, -4, 1, 0)
	card.BackgroundColor3 = palette.panel
	card.BorderSizePixel = 0
	card.Parent = resources

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local label = Instance.new("TextLabel")
	label.Name = "Valore"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextSize = 16
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = card
	return label
end

local goldLabel = makeResource("Oro", palette.gold)
local essenceLabel = makeResource("Essenza", palette.cyan)

local classLabel = Instance.new("TextLabel")
classLabel.Name = "Classe"
classLabel.Position = UDim2.fromOffset(0, 69)
classLabel.Size = UDim2.new(1, 0, 0, 20)
classLabel.BackgroundTransparency = 1
classLabel.TextColor3 = palette.violet
classLabel.TextSize = 12
classLabel.TextTruncate = Enum.TextTruncate.AtEnd
classLabel.Font = Enum.Font.GothamBold
classLabel.TextXAlignment = Enum.TextXAlignment.Left
classLabel.Parent = root

local hints = Instance.new("TextLabel")
hints.Name = "Comandi"
hints.Position = UDim2.fromOffset(0, 91)
hints.Size = UDim2.new(1, 0, 0, 17)
hints.BackgroundTransparency = 1
hints.Text = "Catalizzatore: usa abilità  -  Altari: scegli classe"
hints.TextColor3 = palette.muted
hints.TextSize = 11
hints.Font = Enum.Font.Gotham
hints.TextXAlignment = Enum.TextXAlignment.Left
hints.TextTruncate = Enum.TextTruncate.AtEnd
hints.Parent = root

local lootLabel = Instance.new("TextLabel")
lootLabel.Name = "Bottino"
lootLabel.Position = UDim2.fromOffset(0, 109)
lootLabel.Size = UDim2.new(1, 0, 0, 17)
lootLabel.BackgroundTransparency = 1
lootLabel.TextColor3 = palette.gold
lootLabel.TextSize = 10
lootLabel.Font = Enum.Font.GothamBold
lootLabel.TextXAlignment = Enum.TextXAlignment.Left
lootLabel.TextTruncate = Enum.TextTruncate.AtEnd
lootLabel.Parent = root

local contractLabel = Instance.new("TextLabel")
contractLabel.Name = "Contratto"
contractLabel.Position = UDim2.fromOffset(0, 128)
contractLabel.Size = UDim2.new(1, 0, 0, 18)
contractLabel.BackgroundTransparency = 1
contractLabel.Text = "Gilda: visita la piazza per accettare un contratto"
contractLabel.TextColor3 = palette.cyan
contractLabel.TextSize = 10
contractLabel.Font = Enum.Font.GothamBold
contractLabel.TextXAlignment = Enum.TextXAlignment.Left
contractLabel.TextTruncate = Enum.TextTruncate.AtEnd
contractLabel.Parent = root

local classMenu = Instance.new("Frame")
classMenu.Name = "MenuClassi"
classMenu.Position = UDim2.fromOffset(18, 186)
classMenu.Size = UDim2.fromOffset(360, 132)
classMenu.BackgroundColor3 = palette.background
classMenu.BackgroundTransparency = 0.05
classMenu.BorderSizePixel = 0
classMenu.Visible = false
classMenu.Parent = gui

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 12)
menuCorner.Parent = classMenu

local menuOutline = Instance.new("UIStroke")
menuOutline.Color = palette.gold
menuOutline.Thickness = 1.25
menuOutline.Transparency = 0.15
menuOutline.Parent = classMenu

local menuTitle = Instance.new("TextLabel")
menuTitle.Name = "TitoloMenu"
menuTitle.Position = UDim2.fromOffset(10, 5)
menuTitle.Size = UDim2.new(1, -20, 0, 21)
menuTitle.BackgroundTransparency = 1
menuTitle.Text = "SCEGLI LA TUA CLASSE"
menuTitle.TextColor3 = palette.white
menuTitle.TextSize = 13
menuTitle.Font = Enum.Font.GothamBold
menuTitle.TextXAlignment = Enum.TextXAlignment.Left
menuTitle.Parent = classMenu

local classTips = {
	Arcanista = "Dardo arcano · +50% Essenza",
	Berserker = "Ondata d'urto · +50% Oro",
	Ombra = "Scatto d'ombra · +25% produzione",
	Necromante = "Lancia d'ossa · +40% Essenza",
	Paladino = "Nova sacra · +35% Oro",
	Druido = "Tempesta · +30% Essenza",
}

local classColors = {
	Arcanista = palette.cyan,
	Berserker = Color3.fromRGB(255, 127, 112),
	Ombra = palette.violet,
	Necromante = Color3.fromRGB(120, 232, 164),
	Paladino = palette.gold,
	Druido = Color3.fromRGB(205, 235, 255),
}

local classOrder = { "Arcanista", "Berserker", "Ombra", "Necromante", "Paladino", "Druido" }
for index, className in ipairs(classOrder) do
	local column = (index - 1) % 2
	local row = math.floor((index - 1) / 2)
	local button = Instance.new("TextButton")
	button.Name = "Classe_" .. className
	button.Position = UDim2.fromOffset(8 + column * 172, 31 + row * 32)
	button.Size = UDim2.fromOffset(168, 27)
	button.BackgroundColor3 = palette.panel
	button.BorderSizePixel = 0
	button.Text = className .. " · " .. classTips[className]:match("· (.+)$")
	button.TextColor3 = classColors[className]
	button.TextSize = 11
	button.Font = Enum.Font.GothamBold
	button.TextTruncate = Enum.TextTruncate.AtEnd
	button.AutoButtonColor = true
	button.Parent = classMenu

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 7)
	buttonCorner.Parent = button

	local buttonOutline = Instance.new("UIStroke")
	buttonOutline.Color = classColors[className]
	buttonOutline.Thickness = 1
	buttonOutline.Transparency = 0.35
	buttonOutline.Parent = button

	button.Activated:Connect(function()
		classChangeEvent:FireServer(className)
		classMenu.Visible = false
	end)
end

classToggle.Activated:Connect(function()
	classMenu.Visible = not classMenu.Visible
end)

contractUpdateEvent.OnClientEvent:Connect(function(message)
	if typeof(message) == "string" then
		contractLabel.Text = "Gilda: " .. message
	end
end)

local function refresh()
	goldLabel.Text = "ORO    " .. tostring(gold.Value)
	essenceLabel.Text = "ESSENZA    " .. tostring(essence.Value)
	lootLabel.Text = "ARMA: " .. weapon.Value .. "  ·  POTENZA " .. power.Value .. "  ·  RUNE " .. fragments.Value
	local activeClass = classStat.Value
	classLabel.Text = "CLASSE: " .. string.upper(activeClass) .. "  ·  " .. (classTips[activeClass] or "")
end

gold:GetPropertyChangedSignal("Value"):Connect(refresh)
essence:GetPropertyChangedSignal("Value"):Connect(refresh)
fragments:GetPropertyChangedSignal("Value"):Connect(refresh)
power:GetPropertyChangedSignal("Value"):Connect(refresh)
weapon:GetPropertyChangedSignal("Value"):Connect(refresh)
classStat:GetPropertyChangedSignal("Value"):Connect(refresh)
refresh()

