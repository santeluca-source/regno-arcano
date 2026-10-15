-- Pannello di diagnosi (arriva solo dai comandi di test di Studio, vedi StudioService).
-- Mostra un elenco in una casella di testo selezionabile: Ctrl+A e Ctrl+C per copiarlo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Diagnosi = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Diagnosi")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Diagnosi"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local finestra = Instance.new("Frame")
finestra.AnchorPoint = Vector2.new(0.5, 0.5)
finestra.Position = UDim2.fromScale(0.5, 0.5)
finestra.Size = UDim2.new(0.8, 0, 0.75, 0)
finestra.BackgroundColor3 = Color3.fromRGB(24, 22, 34)
finestra.Parent = gui
local angoli = Instance.new("UICorner")
angoli.CornerRadius = UDim.new(0, 12)
angoli.Parent = finestra
local margini = Instance.new("UIPadding")
for _, lato in ipairs({ "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" }) do
	margini[lato] = UDim.new(0, 12)
end
margini.Parent = finestra

local titolo = Instance.new("TextLabel")
titolo.Size = UDim2.new(1, -40, 0, 24)
titolo.BackgroundTransparency = 1
titolo.TextColor3 = Color3.fromRGB(232, 180, 86)
titolo.TextSize = 16
titolo.Font = Enum.Font.GothamBold
titolo.TextXAlignment = Enum.TextXAlignment.Left
titolo.Parent = finestra

local chiudi = Instance.new("TextButton")
chiudi.AnchorPoint = Vector2.new(1, 0)
chiudi.Position = UDim2.fromScale(1, 0)
chiudi.Size = UDim2.fromOffset(28, 28)
chiudi.BackgroundColor3 = Color3.fromRGB(55, 51, 74)
chiudi.TextColor3 = Color3.new(1, 1, 1)
chiudi.Text = "X"
chiudi.Font = Enum.Font.GothamBold
chiudi.TextSize = 14
chiudi.Parent = finestra

local aiuto = Instance.new("TextLabel")
aiuto.Position = UDim2.fromOffset(0, 26)
aiuto.Size = UDim2.new(1, 0, 0, 18)
aiuto.BackgroundTransparency = 1
aiuto.TextColor3 = Color3.fromRGB(183, 178, 202)
aiuto.TextSize = 12
aiuto.Font = Enum.Font.Gotham
aiuto.TextXAlignment = Enum.TextXAlignment.Left
aiuto.Text = "Clicca nel testo, poi Ctrl+A e Ctrl+C per copiarlo."
aiuto.Parent = finestra

local scorrimento = Instance.new("ScrollingFrame")
scorrimento.Position = UDim2.fromOffset(0, 50)
scorrimento.Size = UDim2.new(1, 0, 1, -50)
scorrimento.BackgroundColor3 = Color3.fromRGB(39, 36, 53)
scorrimento.BorderSizePixel = 0
scorrimento.ScrollBarThickness = 6
scorrimento.AutomaticCanvasSize = Enum.AutomaticSize.Y
scorrimento.CanvasSize = UDim2.new()
scorrimento.Parent = finestra

local testo = Instance.new("TextBox")
testo.Size = UDim2.new(1, -12, 0, 0)
testo.AutomaticSize = Enum.AutomaticSize.Y
testo.BackgroundTransparency = 1
testo.TextColor3 = Color3.fromRGB(244, 241, 255)
testo.TextSize = 13
testo.Font = Enum.Font.Code
testo.TextXAlignment = Enum.TextXAlignment.Left
testo.TextYAlignment = Enum.TextYAlignment.Top
testo.TextWrapped = true
testo.MultiLine = true
testo.ClearTextOnFocus = false
testo.TextEditable = false
testo.Parent = scorrimento

local function mostra(visibile)
	gui.Enabled = visibile
	player:SetAttribute("Finestra_Diagnosi", visibile) -- libera il cursore (Visuale.client)
end

chiudi.Activated:Connect(function()
	mostra(false)
end)

Diagnosi.OnClientEvent:Connect(function(intestazione, righe)
	if type(intestazione) ~= "string" or type(righe) ~= "table" then
		return
	end
	titolo.Text = intestazione
	testo.Text = table.concat(righe, "\n")
	mostra(true)
end)
