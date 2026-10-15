-- Menu Viaggi (tasto M o pulsante): teletrasporto alla Piazza o alla propria Base,
-- e l'elenco di tutti i dungeon con il pulsante per entrarci.
-- I dungeon non ancora sbloccati mostrano cosa serve per sbloccarli.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Viaggia = Remotes:WaitForChild("Viaggia")
local ElencoDungeon = Remotes:WaitForChild("ElencoDungeon")

local player = Players.LocalPlayer

local palette = {
	sfondo = Color3.fromRGB(24, 22, 34),
	pannello = Color3.fromRGB(39, 36, 53),
	pannelloChiaro = Color3.fromRGB(55, 51, 74),
	bordo = Color3.fromRGB(92, 220, 139),
	testo = Color3.fromRGB(244, 241, 255),
	tenue = Color3.fromRGB(183, 178, 202),
	oro = Color3.fromRGB(232, 180, 86),
	verde = Color3.fromRGB(92, 220, 139),
	ciano = Color3.fromRGB(74, 225, 255),
}

local function crea(classe, proprieta, figli)
	local istanza = Instance.new(classe)
	for nome, valore in pairs(proprieta) do
		istanza[nome] = valore
	end
	for _, figlio in ipairs(figli or {}) do
		figlio.Parent = istanza
	end
	return istanza
end

local function angoli(raggio)
	return crea("UICorner", { CornerRadius = UDim.new(0, raggio) })
end

local function bottone(proprieta)
	proprieta.Font = proprieta.Font or Enum.Font.GothamBold
	proprieta.TextSize = proprieta.TextSize or 14
	proprieta.AutoButtonColor = true
	return crea("TextButton", proprieta, { angoli(8) })
end

local function etichetta(proprieta)
	proprieta.BackgroundTransparency = 1
	proprieta.Font = proprieta.Font or Enum.Font.Gotham
	proprieta.TextColor3 = proprieta.TextColor3 or palette.testo
	proprieta.TextXAlignment = proprieta.TextXAlignment or Enum.TextXAlignment.Left
	return crea("TextLabel", proprieta)
end

local gui = crea("ScreenGui", {
	Name = "Viaggi",
	ResetOnSpawn = false,
	DisplayOrder = 22,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Pulsante per aprire il menu: sopra l'abilità speciale (a destra).
local soloTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local apri = bottone({
	Name = "ApriViaggi",
	AnchorPoint = soloTouch and Vector2.new(1, 0.5) or Vector2.new(1, 1),
	Position = soloTouch and UDim2.new(1, -16, 0.5, -100) or UDim2.new(1, -16, 1, -128),
	Size = UDim2.fromOffset(140, 34),
	BackgroundColor3 = Color3.fromRGB(40, 140, 90),
	TextColor3 = palette.testo,
	Text = soloTouch and "VIAGGI" or "VIAGGI (M)",
	Parent = gui,
})

local finestra = crea("Frame", {
	Name = "Finestra",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = palette.sfondo,
	Visible = false,
	Parent = gui,
}, {
	angoli(14),
	crea("UIStroke", { Color = palette.bordo, Thickness = 1.5, Transparency = 0.2 }),
	crea("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}),
})

etichetta({
	Size = UDim2.new(1, -40, 0, 24),
	Text = "VIAGGI",
	TextSize = 18,
	Font = Enum.Font.GothamBold,
	Parent = finestra,
})
local chiudi = bottone({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = palette.pannelloChiaro,
	TextColor3 = palette.testo,
	Text = "X",
	Parent = finestra,
})

-- Teletrasporti --------------------------------------------------------------------

etichetta({
	Position = UDim2.fromOffset(0, 34),
	Size = UDim2.new(1, 0, 0, 18),
	Text = "TELETRASPORTO",
	TextColor3 = palette.tenue,
	TextSize = 13,
	Font = Enum.Font.GothamBold,
	Parent = finestra,
})
local riga = crea("Frame", {
	Position = UDim2.fromOffset(0, 56),
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundTransparency = 1,
	Parent = finestra,
})
local vaiPiazza = bottone({
	Size = UDim2.new(0.5, -5, 1, 0),
	BackgroundColor3 = palette.oro,
	TextColor3 = palette.sfondo,
	Text = "Piazza del Regno",
	Parent = riga,
})
local vaiBase = bottone({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0.5, -5, 1, 0),
	BackgroundColor3 = palette.ciano,
	TextColor3 = palette.sfondo,
	Text = "La mia Base",
	Parent = riga,
})

-- Dungeon ----------------------------------------------------------------------------

etichetta({
	Position = UDim2.fromOffset(0, 110),
	Size = UDim2.new(1, 0, 0, 18),
	Text = "DUNGEON  (da solo; in gruppo usa il Portale della Gilda nella Piazza)",
	TextColor3 = palette.tenue,
	TextSize = 13,
	Font = Enum.Font.GothamBold,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Parent = finestra,
})
local lista = crea("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 132),
	Size = UDim2.new(1, 0, 1, -132),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = finestra,
}, {
	crea("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	crea("UIPadding", { PaddingRight = UDim.new(0, 8) }),
})

local function adatta()
	local schermo = gui.AbsoluteSize
	finestra.Size = UDim2.fromOffset(math.min(560, schermo.X - 32), math.min(470, schermo.Y - 80))
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(adatta)
adatta()

local function mostra(visibile)
	finestra.Visible = visibile
	player:SetAttribute("Finestra_Viaggi", visibile) -- libera il cursore (Visuale.client)
end

local function viaggia(tipo, id)
	Viaggia:FireServer(tipo, id)
	mostra(false)
end

local function scheda(ordine, dungeon)
	local card = crea("Frame", {
		LayoutOrder = ordine,
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = palette.pannello,
		Parent = lista,
	}, {
		angoli(10),
		crea("UIStroke", { Color = dungeon.colore, Transparency = dungeon.sbloccato and 0.2 or 0.7 }),
	})
	crea("Frame", {
		Size = UDim2.new(0, 6, 1, 0),
		BackgroundColor3 = dungeon.colore,
		BorderSizePixel = 0,
		Parent = card,
	}, { angoli(3) })
	etichetta({
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -150, 0, 22),
		Text = string.upper(dungeon.nome) .. "   ·   " .. dungeon.difficolta,
		TextColor3 = dungeon.colore,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	etichetta({
		Position = UDim2.fromOffset(16, 32),
		Size = UDim2.new(1, -150, 0, 34),
		Text = dungeon.descrizione .. "\nBoss: " .. dungeon.boss,
		TextColor3 = palette.tenue,
		TextSize = 12,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	if dungeon.sbloccato then
		local entra = bottone({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(120, 40),
			BackgroundColor3 = palette.verde,
			TextColor3 = palette.sfondo,
			Text = "Entra",
			Parent = card,
		})
		entra.Activated:Connect(function()
			viaggia("Dungeon", dungeon.id)
		end)
	else
		etichetta({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(130, 60),
			Text = "BLOCCATO\n" .. dungeon.requisito,
			TextColor3 = palette.tenue,
			TextSize = 11,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = card,
		})
	end
end

local function aggiornaElenco()
	for _, figlio in ipairs(lista:GetChildren()) do
		if figlio:IsA("Frame") then
			figlio:Destroy()
		end
	end
	local ok, dungeon = pcall(function()
		return ElencoDungeon:InvokeServer()
	end)
	if ok and type(dungeon) == "table" then
		for indice, voce in ipairs(dungeon) do
			scheda(indice, voce)
		end
	end
end

local function alterna()
	local visibile = not finestra.Visible
	mostra(visibile)
	if visibile then
		task.spawn(aggiornaElenco)
	end
end

apri.Activated:Connect(alterna)
chiudi.Activated:Connect(function()
	mostra(false)
end)
vaiPiazza.Activated:Connect(function()
	viaggia("Piazza")
end)
vaiBase.Activated:Connect(function()
	viaggia("Base")
end)
UserInputService.InputBegan:Connect(function(input, gestito)
	if not gestito and input.KeyCode == Enum.KeyCode.M then
		alterna()
	end
end)
