-- Sala dell'Arcanista: generatore della stanza iniziale del tycoon.
-- In Roblox Studio: incolla nella Command Bar in basso e premi Invio.

local Workspace = game:GetService("Workspace")

local existingRoom = Workspace:FindFirstChild("SalaArcanista")
if existingRoom then
	existingRoom:Destroy()
end

local room = Instance.new("Model")
room.Name = "SalaArcanista"
room.Parent = Workspace

local colors = {
	stone = Color3.fromRGB(48, 49, 62),
	wall = Color3.fromRGB(60, 59, 73),
	trim = Color3.fromRGB(31, 30, 42),
	violet = Color3.fromRGB(177, 72, 255),
	cyan = Color3.fromRGB(74, 225, 255),
	gold = Color3.fromRGB(226, 174, 91),
}

local function makePart(name, size, position, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent or room
	return part
end

-- Sala aperta sopra per mantenere visibile il tycoon dall'alto.
makePart("Pavimento", Vector3.new(72, 2, 56), Vector3.new(0, 0, 0), colors.stone, Enum.Material.Slate)

-- Pareti: apertura centrale di 16 stud sul lato d'ingresso.
makePart("Parete nord", Vector3.new(72, 24, 2), Vector3.new(0, 13, 28), colors.wall, Enum.Material.Slate)
makePart("Parete ovest", Vector3.new(2, 24, 56), Vector3.new(-36, 13, 0), colors.wall, Enum.Material.Slate)
makePart("Parete est", Vector3.new(2, 24, 56), Vector3.new(36, 13, 0), colors.wall, Enum.Material.Slate)
makePart("Ingresso sinistro", Vector3.new(28, 24, 2), Vector3.new(-22, 13, -28), colors.wall, Enum.Material.Slate)
makePart("Ingresso destro", Vector3.new(28, 24, 2), Vector3.new(22, 13, -28), colors.wall, Enum.Material.Slate)
makePart("Architrave ingresso", Vector3.new(16, 6, 2), Vector3.new(0, 22, -28), colors.wall, Enum.Material.Slate)

-- Cornice scura intorno all'ingresso.
makePart("Montante ingresso sinistro", Vector3.new(2, 18, 2.6), Vector3.new(-8.8, 10, -27.6), colors.trim, Enum.Material.Basalt)
makePart("Montante ingresso destro", Vector3.new(2, 18, 2.6), Vector3.new(8.8, 10, -27.6), colors.trim, Enum.Material.Basalt)
makePart("Cornice superiore ingresso", Vector3.new(19.5, 2, 2.6), Vector3.new(0, 20, -27.6), colors.trim, Enum.Material.Basalt)

-- Battiscopa interni.
makePart("Battiscopa nord", Vector3.new(68, 1.2, 0.7), Vector3.new(0, 1.7, 26.7), colors.trim, Enum.Material.Basalt)
makePart("Battiscopa ovest", Vector3.new(0.7, 1.2, 52), Vector3.new(-34.7, 1.7, 0), colors.trim, Enum.Material.Basalt)
makePart("Battiscopa est", Vector3.new(0.7, 1.2, 52), Vector3.new(34.7, 1.7, 0), colors.trim, Enum.Material.Basalt)

-- Quattro pilastri agli angoli.
for _, x in ipairs({-29, 29}) do
	for _, z in ipairs({-21, 21}) do
		makePart("Piede pilastro", Vector3.new(5, 1.5, 5), Vector3.new(x, 1.75, z), colors.trim, Enum.Material.Basalt)
		makePart("Pilastro", Vector3.new(3.4, 14, 3.4), Vector3.new(x, 9, z), colors.wall, Enum.Material.Slate)
		makePart("Capitello pilastro", Vector3.new(4.6, 1.2, 4.6), Vector3.new(x, 16.6, z), colors.trim, Enum.Material.Basalt)
	end
end

-- Rune luminose disposte in cerchio sul pavimento.
for index = 0, 11 do
	local angle = math.rad(index * 30)
	local radius = 10
	local x = math.cos(angle) * radius
	local z = math.sin(angle) * radius
	local rune = makePart(
		"Runa " .. (index + 1),
		Vector3.new(4.2, 0.18, 0.8),
		Vector3.new(x, 1.12, z),
		(index % 2 == 0) and colors.cyan or colors.violet,
		Enum.Material.Neon
	)
	rune.CFrame = CFrame.new(x, 1.12, z) * CFrame.Angles(0, angle + math.rad(90), 0)
end

-- Altare delle Classi sul fondo della sala.
makePart("Base altare", Vector3.new(14, 3, 8), Vector3.new(0, 2.5, 16), colors.trim, Enum.Material.Basalt)
makePart("Piano altare", Vector3.new(11, 1, 6), Vector3.new(0, 4.5, 16), colors.wall, Enum.Material.Slate)
makePart("Incisione altare", Vector3.new(7, 0.18, 3.5), Vector3.new(0, 5.1, 16), colors.violet, Enum.Material.Neon)

local crystal = makePart("Cristallo arcano", Vector3.new(3.4, 5.2, 3.4), Vector3.new(0, 9, 16), colors.cyan, Enum.Material.Neon)
crystal.CFrame = CFrame.new(0, 9, 16) * CFrame.Angles(0, math.rad(45), 0)
crystal.CanCollide = false

local crystalLight = Instance.new("PointLight")
crystalLight.Color = colors.cyan
crystalLight.Brightness = 2
crystalLight.Range = 18
crystalLight.Parent = crystal

-- Targhetta leggibile dall'interno.
local sign = makePart("Targa altare", Vector3.new(17, 4, 0.8), Vector3.new(0, 17.5, 26.5), colors.trim, Enum.Material.Basalt)
local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Name = "Scritta"
surfaceGui.Face = Enum.NormalId.Front
surfaceGui.PixelsPerStud = 40
surfaceGui.Parent = sign

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "ALTARE DELLE CLASSI"
label.TextColor3 = colors.cyan
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Parent = surfaceGui

-- Bracieri arcani sulle pareti laterali.
for _, x in ipairs({-34.3, 34.3}) do
	for _, z in ipairs({-7, 8}) do
		local brazier = makePart("Braciere arcano", Vector3.new(1.3, 3, 1.3), Vector3.new(x, 7, z), colors.trim, Enum.Material.Basalt)
		local flame = makePart("Fiamma magica", Vector3.new(1.1, 1.1, 1.1), Vector3.new(x, 9.2, z), colors.violet, Enum.Material.Neon)
		flame.Shape = Enum.PartType.Ball
		flame.CanCollide = false

		local light = Instance.new("PointLight")
		light.Color = colors.violet
		light.Brightness = 1.2
		light.Range = 14
		light.Parent = flame
	end
end

-- Punto di comparsa provvisorio vicino all'ingresso.
local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn Sala Arcanista"
spawn.Size = Vector3.new(6, 1, 6)
spawn.Position = Vector3.new(0, 1.6, -19)
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Parent = room

print("Sala dell'Arcanista creata in Workspace.")
