-- HUD: valute, classe attiva, menu di cambio classe e notifiche.
-- Legge solo gli Attributi del Player impostati dal server (PlayerData).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Classi = require(Config:WaitForChild("Classi"))
local Valute = require(Config:WaitForChild("Valute"))
local Rarita = require(Config:WaitForChild("Rarita"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer

local palette = {
	sfondo = Color3.fromRGB(24, 22, 34),
	pannello = Color3.fromRGB(39, 36, 53),
	bordo = Color3.fromRGB(177, 72, 255),
	testo = Color3.fromRGB(244, 241, 255),
	tenue = Color3.fromRGB(183, 178, 202),
	oro = Color3.fromRGB(232, 180, 86),
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

local gui = crea("ScreenGui", {
	Name = "HUD",
	ResetOnSpawn = false,
	DisplayOrder = 10,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Pannello in alto a sinistra --------------------------------------------------

local pannello = crea("Frame", {
	Name = "Pannello",
	Position = UDim2.fromOffset(16, 16),
	Size = UDim2.fromOffset(300, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = palette.sfondo,
	BackgroundTransparency = 0.08,
	Parent = gui,
}, {
	angoli(12),
	crea("UIStroke", { Color = palette.bordo, Thickness = 1.5, Transparency = 0.25 }),
	crea("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}),
	crea("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})

-- Su telefono lo schermo è piccolo: il pannello si rimpicciolisce.
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	crea("UIScale", { Scale = 0.72, Parent = pannello })
end

crea("TextLabel", {
	Name = "Titolo",
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundTransparency = 1,
	Text = "REGNO ARCANO",
	TextColor3 = palette.testo,
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = pannello,
})

local etichetteValute = {}
for indice, nome in ipairs(Valute.Ordine) do
	etichetteValute[nome] = crea("TextLabel", {
		Name = nome,
		LayoutOrder = 1 + indice,
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = palette.pannello,
		Text = "",
		TextColor3 = Valute.Dati[nome].colore,
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		Parent = pannello,
	}, { angoli(7) })
end

local etichettaProduzione = crea("TextLabel", {
	Name = "Produzione",
	LayoutOrder = 9,
	Size = UDim2.new(1, 0, 0, 16),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = palette.tenue,
	TextSize = 12,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = pannello,
})

local etichettaClasse = crea("TextLabel", {
	Name = "Classe",
	LayoutOrder = 10,
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundTransparency = 1,
	Text = "",
	TextSize = 13,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Parent = pannello,
})

local bottoneClassi = crea("TextButton", {
	Name = "CambiaClasse",
	LayoutOrder = 11,
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundColor3 = palette.oro,
	Text = "CAMBIA CLASSE",
	TextColor3 = palette.sfondo,
	TextSize = 13,
	Font = Enum.Font.GothamBold,
	Parent = pannello,
}, { angoli(7) })

-- Equipaggiamento indossato (colorato per rarità)
local etichetteEquip = {}
for indice, slot in ipairs({ "Arma", "Armatura" }) do
	etichetteEquip[slot] = crea("TextLabel", {
		Name = slot,
		LayoutOrder = 11 + indice,
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = "",
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = pannello,
	})
end

local etichettaMissione = crea("TextLabel", {
	Name = "Missione",
	LayoutOrder = 20,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = Color3.fromRGB(235, 220, 180),
	TextSize = 12,
	Font = Enum.Font.Gotham,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = pannello,
})

-- Menu delle classi ------------------------------------------------------------

local menu = crea("Frame", {
	Name = "MenuClassi",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(520, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = palette.sfondo,
	Visible = false,
	Parent = gui,
}, {
	angoli(14),
	crea("UIStroke", { Color = palette.oro, Thickness = 1.5, Transparency = 0.15 }),
	crea("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}),
	crea("UISizeConstraint", { MaxSize = Vector2.new(520, math.huge) }),
	crea("UIGridLayout", {
		CellSize = UDim2.new(0.5, -5, 0, 74),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

-- Su schermi stretti il menu usa quasi tutta la larghezza.
local function adattaMenu()
	local larghezza = gui.AbsoluteSize.X
	menu.Size = UDim2.fromOffset(math.min(520, larghezza - 32), 0)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(adattaMenu)
adattaMenu()

for indice, nome in ipairs(Classi.Ordine) do
	local dati = Classi.Dati[nome]
	local scheda = crea("TextButton", {
		Name = nome,
		LayoutOrder = indice,
		BackgroundColor3 = palette.pannello,
		Text = "",
		AutoButtonColor = true,
		Parent = menu,
	}, {
		angoli(9),
		crea("UIStroke", { Color = dati.colore, Thickness = 1, Transparency = 0.35 }),
		crea("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	})
	crea("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = string.upper(nome) .. "  ·  " .. dati.ruolo,
		TextColor3 = dati.colore,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = scheda,
	})
	crea("TextLabel", {
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Text = dati.abilita.nome .. " — " .. dati.descrizione,
		TextColor3 = palette.tenue,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = scheda,
	})
	scheda.Activated:Connect(function()
		Remotes.CambiaClasse:FireServer(nome)
		menu.Visible = false
	end)
end

bottoneClassi.Activated:Connect(function()
	menu.Visible = not menu.Visible
end)

-- L'Altare delle Classi sull'isola apre lo stesso menu.
Remotes:WaitForChild("ApriMenuClassi").OnClientEvent:Connect(function()
	menu.Visible = true
end)

-- Notifiche --------------------------------------------------------------------

local notifica = crea("TextLabel", {
	Name = "Notifica",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 24),
	Size = UDim2.fromOffset(0, 36),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = palette.sfondo,
	BackgroundTransparency = 1,
	TextTransparency = 1,
	Text = "",
	TextColor3 = palette.testo,
	TextSize = 15,
	Font = Enum.Font.GothamBold,
	Parent = gui,
}, {
	angoli(10),
	crea("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
})

local idNotifica = 0
Remotes.Notifica.OnClientEvent:Connect(function(messaggio)
	if type(messaggio) ~= "string" then
		return
	end
	idNotifica += 1
	local questo = idNotifica
	notifica.Text = messaggio
	notifica.BackgroundTransparency = 0.1
	notifica.TextTransparency = 0
	task.delay(2.5, function()
		if questo == idNotifica then
			local info = TweenInfo.new(0.4)
			TweenService:Create(notifica, info, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		end
	end)
end)

-- Guida per i nuovi giocatori (in basso al centro, sopra la barra degli strumenti) --

local guida = crea("TextLabel", {
	Name = "Guida",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -100),
	Size = UDim2.fromOffset(0, 0),
	AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundColor3 = palette.sfondo,
	BackgroundTransparency = 0.1,
	Text = "",
	TextColor3 = palette.oro,
	TextSize = 15,
	Font = Enum.Font.GothamBold,
	TextWrapped = true,
	Visible = false,
	Parent = gui,
}, {
	angoli(10),
	crea("UIStroke", { Color = palette.oro, Thickness = 1.5, Transparency = 0.3 }),
	crea("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	}),
	crea("UISizeConstraint", { MaxSize = Vector2.new(520, math.huge) }),
})

local function aggiornaGuida()
	local testo = player:GetAttribute("Tutorial")
	guida.Visible = type(testo) == "string"
	guida.Text = testo or ""
end
player:GetAttributeChangedSignal("Tutorial"):Connect(aggiornaGuida)
aggiornaGuida()

-- Aggiornamento ----------------------------------------------------------------

local function aggiorna()
	for nome, etichetta in pairs(etichetteValute) do
		etichetta.Text = string.upper(nome) .. "   " .. tostring(player:GetAttribute(nome) or 0)
	end
	etichettaProduzione.Text = string.format("Produzione:  +%s Oro/s  ·  +%s Essenza/s",
		tostring(player:GetAttribute("OroAlSecondo") or 0), tostring(player:GetAttribute("EssenzaAlSecondo") or 0))

	local missione = player:GetAttribute("Missione")
	etichettaMissione.Text = missione and ("MISSIONE  " .. missione) or ""

	for slot, etichetta in pairs(etichetteEquip) do
		local rarita = Rarita.Dati[player:GetAttribute(slot .. "Rarita") or ""]
		etichetta.Text = string.upper(slot) .. ": " .. tostring(player:GetAttribute(slot) or "Nessuna")
		etichetta.TextColor3 = rarita and rarita.colore or palette.tenue
	end

	local classe = player:GetAttribute("Classe")
	local dati = classe and Classi.Dati[classe]
	if dati then
		etichettaClasse.Text = "CLASSE: " .. string.upper(classe) .. "  ·  " .. dati.ruolo
		etichettaClasse.TextColor3 = dati.colore
	else
		etichettaClasse.Text = "Caricamento dati..."
		etichettaClasse.TextColor3 = palette.tenue
	end
end

for _, nome in ipairs(Valute.Ordine) do
	player:GetAttributeChangedSignal(nome):Connect(aggiorna)
end
for _, nome in ipairs({ "Classe", "OroAlSecondo", "EssenzaAlSecondo", "Arma", "ArmaRarita", "Armatura", "ArmaturaRarita", "Missione" }) do
	player:GetAttributeChangedSignal(nome):Connect(aggiorna)
end
aggiorna()
