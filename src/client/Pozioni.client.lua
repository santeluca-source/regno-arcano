-- Barra delle pozioni in basso a sinistra: un pulsante per pozione, con quantità,
-- tasto (Z / X / C) e ricarica. Il server controlla quantità e ricariche.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Pozioni = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Pozioni"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UsaPozione = Remotes:WaitForChild("UsaPozione")
local PozioneUsata = Remotes:WaitForChild("PozioneUsata")

local player = Players.LocalPlayer

local LATO = 62

local gui = Instance.new("ScreenGui")
gui.Name = "Pozioni"
gui.ResetOnSpawn = false
gui.DisplayOrder = 15
gui.Parent = player:WaitForChild("PlayerGui")

local barra = Instance.new("Frame")
barra.Name = "Barra"
barra.AnchorPoint = Vector2.new(0, 1)
barra.Position = UDim2.new(0, 16, 1, -16)
barra.Size = UDim2.fromOffset(#Pozioni.Ordine * (LATO + 8), LATO)
barra.BackgroundTransparency = 1
barra.Parent = gui

-- Su telefono in basso a sinistra c'è il joystick: la barra va in alto a destra.
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	barra.AnchorPoint = Vector2.new(1, 0)
	barra.Position = UDim2.new(1, -16, 0, 56)
end

local disposizione = Instance.new("UIListLayout")
disposizione.FillDirection = Enum.FillDirection.Horizontal
disposizione.Padding = UDim.new(0, 8)
disposizione.SortOrder = Enum.SortOrder.LayoutOrder
disposizione.Parent = barra

local tastiera = UserInputService.KeyboardEnabled
local slot = {} -- [id] = { bottone, quantita, velo, fine, durata }

local function etichetta(genitore, proprieta)
	local testo = Instance.new("TextLabel")
	testo.BackgroundTransparency = 1
	testo.TextColor3 = Color3.fromRGB(244, 241, 255)
	testo.TextStrokeTransparency = 0.4
	testo.Font = Enum.Font.GothamBold
	testo.ZIndex = 3
	for nome, valore in pairs(proprieta) do
		testo[nome] = valore
	end
	testo.Parent = genitore
	return testo
end

for indice, id in ipairs(Pozioni.Ordine) do
	local def = Pozioni.Dati[id]

	local bottone = Instance.new("TextButton")
	bottone.Name = id
	bottone.LayoutOrder = indice
	bottone.Size = UDim2.fromOffset(LATO, LATO)
	bottone.BackgroundColor3 = Color3.fromRGB(24, 22, 34)
	bottone.Text = ""
	bottone.AutoButtonColor = true
	bottone.ClipsDescendants = true
	bottone.Parent = barra

	local angoli = Instance.new("UICorner")
	angoli.CornerRadius = UDim.new(0, 10)
	angoli.Parent = bottone
	local bordo = Instance.new("UIStroke")
	bordo.Color = def.colore
	bordo.Thickness = 2
	bordo.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bordo.Parent = bottone

	-- La fiala: un cerchio colorato al centro.
	local fiala = Instance.new("Frame")
	fiala.AnchorPoint = Vector2.new(0.5, 0.5)
	fiala.Position = UDim2.fromScale(0.5, 0.5)
	fiala.Size = UDim2.fromOffset(26, 26)
	fiala.BackgroundColor3 = def.colore
	fiala.Parent = bottone
	local tondo = Instance.new("UICorner")
	tondo.CornerRadius = UDim.new(1, 0)
	tondo.Parent = fiala

	local velo = Instance.new("Frame")
	velo.AnchorPoint = Vector2.new(0, 1)
	velo.Position = UDim2.fromScale(0, 1)
	velo.Size = UDim2.fromScale(1, 0)
	velo.BackgroundColor3 = Color3.new(0, 0, 0)
	velo.BackgroundTransparency = 0.35
	velo.BorderSizePixel = 0
	velo.ZIndex = 2
	velo.Parent = bottone

	if tastiera then
		etichetta(bottone, {
			Position = UDim2.fromOffset(5, 3),
			Size = UDim2.fromOffset(16, 16),
			Text = def.tasto.Name,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	local quantita = etichetta(bottone, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -5, 1, -3),
		Size = UDim2.fromOffset(30, 18),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local ricarica = etichetta(bottone, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 18,
		Text = "",
	})

	slot[id] = { bottone = bottone, quantita = quantita, velo = velo, ricarica = ricarica, fine = 0, durata = 1 }

	bottone.Activated:Connect(function()
		UsaPozione:FireServer(id)
	end)
end

local function aggiornaQuantita()
	for id, s in pairs(slot) do
		local numero = player:GetAttribute("Pozione_" .. id) or 0
		s.quantita.Text = "x" .. numero
		s.bottone.BackgroundTransparency = numero > 0 and 0 or 0.5
	end
end

for _, id in ipairs(Pozioni.Ordine) do
	player:GetAttributeChangedSignal("Pozione_" .. id):Connect(aggiornaQuantita)
end
aggiornaQuantita()

UserInputService.InputBegan:Connect(function(input, gestito)
	if gestito then
		return
	end
	for id, def in pairs(Pozioni.Dati) do
		if input.KeyCode == def.tasto then
			UsaPozione:FireServer(id)
		end
	end
end)

PozioneUsata.OnClientEvent:Connect(function(id, ricarica)
	local s = slot[id]
	if s and type(ricarica) == "number" then
		s.durata = math.max(ricarica, 0.1)
		s.fine = os.clock() + ricarica
	end
end)

RunService.RenderStepped:Connect(function()
	local ora = os.clock()
	for _, s in pairs(slot) do
		local rimanente = s.fine - ora
		if rimanente > 0 then
			s.velo.Size = UDim2.fromScale(1, rimanente / s.durata)
			s.ricarica.Text = tostring(math.ceil(rimanente))
		else
			s.velo.Size = UDim2.fromScale(1, 0)
			s.ricarica.Text = ""
		end
	end
end)
