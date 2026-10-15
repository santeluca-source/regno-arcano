-- Pulsante dell'abilità speciale (tasto Q, o tocco su telefono) con la ricarica visibile.
-- Il server decide se l'abilità parte e lo conferma con SpecialeUsato.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Classi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Classi"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UsaSpeciale = Remotes:WaitForChild("UsaSpeciale")
local SpecialeUsato = Remotes:WaitForChild("SpecialeUsato")

local player = Players.LocalPlayer

local fineRicarica = 0
local durataRicarica = 1

local gui = Instance.new("ScreenGui")
gui.Name = "Speciale"
gui.ResetOnSpawn = false
gui.DisplayOrder = 15
gui.Parent = player:WaitForChild("PlayerGui")

-- Sopra al pulsante dell'inventario, in basso a destra.
local bottone = Instance.new("TextButton")
bottone.Name = "Speciale"
bottone.AnchorPoint = Vector2.new(1, 1)
bottone.Position = UDim2.new(1, -16, 1, -60)
bottone.Size = UDim2.fromOffset(140, 58)
bottone.BackgroundColor3 = Color3.fromRGB(24, 22, 34)
bottone.Text = ""
bottone.AutoButtonColor = true
bottone.ClipsDescendants = true
bottone.Parent = gui

-- Su telefono in basso a destra c'è il tasto salto: saliamo a metà schermo.
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	bottone.AnchorPoint = Vector2.new(1, 0.5)
	bottone.Position = UDim2.new(1, -16, 0.5, -44)
end

local angoli = Instance.new("UICorner")
angoli.CornerRadius = UDim.new(0, 10)
angoli.Parent = bottone

local bordo = Instance.new("UIStroke")
bordo.Thickness = 2
bordo.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
bordo.Parent = bottone

-- Il riempimento scuro si ritira man mano che la ricarica avanza.
local velo = Instance.new("Frame")
velo.Name = "Ricarica"
velo.AnchorPoint = Vector2.new(0, 1)
velo.Position = UDim2.fromScale(0, 1)
velo.Size = UDim2.fromScale(1, 0)
velo.BackgroundColor3 = Color3.new(0, 0, 0)
velo.BackgroundTransparency = 0.35
velo.BorderSizePixel = 0
velo.Parent = bottone

local nome = Instance.new("TextLabel")
nome.Position = UDim2.fromOffset(8, 6)
nome.Size = UDim2.new(1, -16, 0, 26)
nome.BackgroundTransparency = 1
nome.TextScaled = true
nome.Font = Enum.Font.GothamBold
nome.TextWrapped = true
nome.ZIndex = 2
nome.Parent = bottone

local stato = Instance.new("TextLabel")
stato.Position = UDim2.new(0, 8, 1, -24)
stato.Size = UDim2.new(1, -16, 0, 18)
stato.BackgroundTransparency = 1
stato.TextColor3 = Color3.fromRGB(244, 241, 255)
stato.TextSize = 13
stato.Font = Enum.Font.Gotham
stato.ZIndex = 2
stato.Parent = bottone

local function datiSpeciale()
	local classe = Classi.Dati[player:GetAttribute("Classe") or ""]
	return classe and classe.speciale, classe
end

local function aggiornaAspetto()
	local speciale, classe = datiSpeciale()
	bottone.Visible = speciale ~= nil
	if speciale then
		nome.Text = speciale.nome
		nome.TextColor3 = classe.colore
		bordo.Color = classe.colore
	end
end

local function usa()
	if os.clock() >= fineRicarica and datiSpeciale() then
		UsaSpeciale:FireServer()
	end
end

bottone.Activated:Connect(usa)
UserInputService.InputBegan:Connect(function(input, gestito)
	if not gestito and input.KeyCode == Enum.KeyCode.Q then
		usa()
	end
end)

SpecialeUsato.OnClientEvent:Connect(function(_nome, ricarica)
	if type(ricarica) == "number" then
		durataRicarica = math.max(ricarica, 0.1)
		fineRicarica = os.clock() + ricarica
	end
end)

player:GetAttributeChangedSignal("Classe"):Connect(function()
	fineRicarica = 0 -- il server azzera la ricarica quando cambi classe
	aggiornaAspetto()
end)
aggiornaAspetto()

RunService.RenderStepped:Connect(function()
	local rimanente = fineRicarica - os.clock()
	if rimanente > 0 then
		velo.Size = UDim2.fromScale(1, rimanente / durataRicarica)
		stato.Text = string.format("%.0f s", math.ceil(rimanente))
	else
		velo.Size = UDim2.fromScale(1, 0)
		stato.Text = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and "Tocca" or "Premi Q"
	end
end)
