-- Menu dell'inventario: si apre con il tasto I o con il pulsante in alto a destra.
-- Mostra gli oggetti, permette di indossarli, toglierli e venderli per Frammenti.
-- Il client chiede soltanto: ogni azione viene controllata ed eseguita dal server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Rarita = require(Config:WaitForChild("Rarita"))
local Equipaggiamento = require(Config:WaitForChild("Equipaggiamento"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InventarioAggiornato = Remotes:WaitForChild("InventarioAggiornato")
local AzioneInventario = Remotes:WaitForChild("AzioneInventario")
local OttieniInventario = Remotes:WaitForChild("OttieniInventario")

local player = Players.LocalPlayer

local palette = {
	sfondo = Color3.fromRGB(24, 22, 34),
	pannello = Color3.fromRGB(39, 36, 53),
	pannelloChiaro = Color3.fromRGB(55, 51, 74),
	bordo = Color3.fromRGB(177, 72, 255),
	testo = Color3.fromRGB(244, 241, 255),
	tenue = Color3.fromRGB(183, 178, 202),
	oro = Color3.fromRGB(232, 180, 86),
	verde = Color3.fromRGB(92, 220, 139),
	rosso = Color3.fromRGB(230, 90, 90),
}

local stato = {
	oggetti = {},
	equipaggiato = {},
	capienza = Equipaggiamento.Capienza,
	filtro = "Tutti",
	selezionato = nil, -- id
	fabbro = false, -- true se la finestra è stata aperta dall'incudine del Fabbro
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
	proprieta.TextSize = proprieta.TextSize or 13
	proprieta.AutoButtonColor = true
	return crea("TextButton", proprieta, { angoli(7) })
end

-- Struttura della finestra ------------------------------------------------------

local gui = crea("ScreenGui", {
	Name = "Inventario",
	ResetOnSpawn = false,
	DisplayOrder = 20,
	Parent = player:WaitForChild("PlayerGui"),
})

local apri = bottone({
	Name = "ApriInventario",
	-- In basso a destra: in alto a destra c'è la classifica dei giocatori di Roblox.
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -16),
	Size = UDim2.fromOffset(140, 34),
	BackgroundColor3 = palette.bordo,
	TextColor3 = palette.testo,
	Text = "INVENTARIO (I)",
	Parent = gui,
})

-- Su telefono in basso a destra c'è il tasto salto: saliamo a metà schermo.
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	apri.AnchorPoint = Vector2.new(1, 0.5)
	apri.Position = UDim2.new(1, -16, 0.5, 4)
	apri.Text = "INVENTARIO"
end

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

local titolo = crea("TextLabel", {
	Size = UDim2.new(1, -40, 0, 24),
	BackgroundTransparency = 1,
	Text = "INVENTARIO",
	TextColor3 = palette.testo,
	TextSize = 18,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
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

-- Barra con le schede e la vendita rapida.
local barra = crea("Frame", {
	Position = UDim2.fromOffset(0, 32),
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundTransparency = 1,
	Parent = finestra,
}, {
	crea("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local schede = {}
for indice, filtro in ipairs({ "Tutti", "Arma", "Armatura" }) do
	schede[filtro] = bottone({
		LayoutOrder = indice,
		Size = UDim2.fromOffset(90, 30),
		BackgroundColor3 = palette.pannello,
		TextColor3 = palette.testo,
		Text = filtro == "Tutti" and "Tutti" or (filtro == "Arma" and "Armi" or "Armature"),
		Parent = barra,
	})
end

local vendiComuni = bottone({
	LayoutOrder = 10,
	Size = UDim2.fromOffset(150, 30),
	BackgroundColor3 = palette.pannelloChiaro,
	TextColor3 = palette.oro,
	TextSize = 12,
	Text = "Vendi tutti i Comuni",
	Parent = barra,
})

local corpo = crea("Frame", {
	Position = UDim2.fromOffset(0, 70),
	Size = UDim2.new(1, 0, 1, -70),
	BackgroundTransparency = 1,
	Parent = finestra,
})

local lista = crea("ScrollingFrame", {
	Name = "Lista",
	BackgroundColor3 = palette.pannello,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = corpo,
}, {
	angoli(10),
	crea("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
	crea("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 12),
	}),
})

local dettaglio = crea("Frame", {
	Name = "Dettaglio",
	BackgroundColor3 = palette.pannello,
	Parent = corpo,
}, {
	angoli(10),
	crea("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}),
	crea("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local function rigaDettaglio(ordine, dimensione, font)
	return crea("TextLabel", {
		LayoutOrder = ordine,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = palette.testo,
		TextSize = dimensione,
		Font = font or Enum.Font.Gotham,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = dettaglio,
	})
end

local dNome = rigaDettaglio(1, 17, Enum.Font.GothamBold)
local dTipo = rigaDettaglio(2, 13)
local dPotenza = rigaDettaglio(3, 14, Enum.Font.GothamBold)
local dEffetto = rigaDettaglio(4, 14)
local dConfronto = rigaDettaglio(5, 13)

local azioniRiga = crea("Frame", {
	LayoutOrder = 10,
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundTransparency = 1,
	Parent = dettaglio,
}, {
	crea("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local bIndossa = bottone({
	LayoutOrder = 1,
	Size = UDim2.new(0.5, -3, 1, 0),
	BackgroundColor3 = palette.verde,
	TextColor3 = palette.sfondo,
	Text = "Indossa",
	Parent = azioniRiga,
})
local bVendi = bottone({
	LayoutOrder = 2,
	Size = UDim2.new(0.5, -3, 1, 0),
	BackgroundColor3 = palette.oro,
	TextColor3 = palette.sfondo,
	Text = "Vendi",
	Parent = azioniRiga,
})

-- Visibile solo in modalità Fabbro.
local bMigliora = bottone({
	LayoutOrder = 11,
	Size = UDim2.new(1, 0, 0, 38),
	BackgroundColor3 = Color3.fromRGB(255, 120, 40),
	TextColor3 = palette.sfondo,
	TextWrapped = true,
	Text = "Migliora",
	Visible = false,
	Parent = dettaglio,
})

-- Dimensioni: due colonne su schermi larghi, una sopra l'altra su quelli stretti.
local function adatta()
	local schermo = gui.AbsoluteSize
	local larghezza = math.min(680, schermo.X - 32)
	local altezza = math.min(460, schermo.Y - 80)
	finestra.Size = UDim2.fromOffset(larghezza, altezza)
	if larghezza >= 560 then
		lista.Position = UDim2.new()
		lista.Size = UDim2.new(0.56, -6, 1, 0)
		dettaglio.Position = UDim2.new(0.56, 6, 0, 0)
		dettaglio.Size = UDim2.new(0.44, -6, 1, 0)
	else
		lista.Position = UDim2.new()
		lista.Size = UDim2.new(1, 0, 0.5, -6)
		dettaglio.Position = UDim2.new(0, 0, 0.5, 6)
		dettaglio.Size = UDim2.new(1, 0, 0.5, -6)
	end
	vendiComuni.Size = UDim2.fromOffset(larghezza >= 460 and 150 or 110, 30)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(adatta)
adatta()

-- Contenuto -------------------------------------------------------------------------

local function indossato(oggetto)
	return stato.equipaggiato[oggetto.slot] == oggetto.id
end

local function trova(id)
	for _, oggetto in ipairs(stato.oggetti) do
		if oggetto.id == id then
			return oggetto
		end
	end
	return nil
end

local function aggiornaDettaglio()
	local oggetto = stato.selezionato and trova(stato.selezionato)
	if not oggetto then
		dNome.Text = "Seleziona un oggetto"
		dNome.TextColor3 = palette.tenue
		dTipo.Text = "Gli oggetti si trovano nelle Rovine e dal Mercante della Piazza."
		dPotenza.Text, dEffetto.Text, dConfronto.Text = "", "", ""
		azioniRiga.Visible = false
		bMigliora.Visible = false
		return
	end
	local rarita = Rarita.Dati[oggetto.rarita]
	local livello = oggetto.livello or 0
	dNome.Text = Equipaggiamento.NomeCompleto(oggetto)
	dNome.TextColor3 = rarita.colore
	dTipo.Text = rarita.nome .. "  ·  " .. oggetto.slot .. "  ·  Livello " .. livello .. "/" .. Equipaggiamento.LivelloMassimo
	dTipo.TextColor3 = rarita.colore
	dPotenza.Text = "Potenza " .. oggetto.potenza

	bMigliora.Visible = stato.fabbro
	if stato.fabbro then
		local costo = Equipaggiamento.CostoMiglioramento(oggetto)
		if costo then
			local prossima = Equipaggiamento.PotenzaAlLivello(oggetto.potenzaBase or oggetto.potenza, livello + 1)
			bMigliora.Text = string.format("Migliora a +%d (Potenza %d)\n%d Oro + %d Frammenti",
				livello + 1, prossima, costo.Oro, costo.Frammenti)
			bMigliora.AutoButtonColor = true
			bMigliora.BackgroundTransparency = 0
		else
			bMigliora.Text = "Livello massimo raggiunto"
			bMigliora.AutoButtonColor = false
			bMigliora.BackgroundTransparency = 0.5
		end
	end
	dEffetto.Text = Equipaggiamento.TestoEffetto(oggetto.slot, oggetto.potenza)

	local attuale = stato.equipaggiato[oggetto.slot] and trova(stato.equipaggiato[oggetto.slot])
	if indossato(oggetto) then
		dConfronto.Text = "Lo stai indossando."
		dConfronto.TextColor3 = palette.verde
	elseif not attuale then
		dConfronto.Text = "Non indossi nessun oggetto di questo tipo."
		dConfronto.TextColor3 = palette.tenue
	else
		local differenza = oggetto.potenza - attuale.potenza
		dConfronto.Text = (differenza >= 0 and "+" or "") .. differenza .. " Potenza rispetto a quello indossato"
		dConfronto.TextColor3 = differenza > 0 and palette.verde or (differenza < 0 and palette.rosso or palette.tenue)
	end

	azioniRiga.Visible = true
	bIndossa.Text = indossato(oggetto) and "Togli" or "Indossa"
	bIndossa.BackgroundColor3 = indossato(oggetto) and palette.pannelloChiaro or palette.verde
	bIndossa.TextColor3 = indossato(oggetto) and palette.testo or palette.sfondo
	bVendi.Visible = not indossato(oggetto)
	bVendi.Text = "Vendi (+" .. Equipaggiamento.ValoreVendita(oggetto.potenza) .. " Frammenti)"
end

local function aggiornaLista()
	for _, figlio in ipairs(lista:GetChildren()) do
		if figlio:IsA("TextButton") or figlio.Name == "Vuoto" then
			figlio:Destroy()
		end
	end
	titolo.Text = (stato.fabbro and "FABBRO  ·  scegli un oggetto da migliorare   " or "INVENTARIO   ")
		.. #stato.oggetti .. " / " .. stato.capienza
	for filtro, scheda in pairs(schede) do
		scheda.BackgroundColor3 = filtro == stato.filtro and palette.bordo or palette.pannello
	end

	local visibili = {}
	for _, oggetto in ipairs(stato.oggetti) do
		if stato.filtro == "Tutti" or oggetto.slot == stato.filtro then
			table.insert(visibili, oggetto)
		end
	end
	-- Prima quelli indossati, poi dal più forte al più debole.
	table.sort(visibili, function(a, b)
		if indossato(a) ~= indossato(b) then
			return indossato(a)
		end
		return a.potenza > b.potenza
	end)

	if #visibili == 0 then
		crea("TextLabel", {
			Name = "Vuoto",
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Text = "Nessun oggetto. Esplora le Rovine!",
			TextColor3 = palette.tenue,
			TextSize = 14,
			Font = Enum.Font.Gotham,
			Parent = lista,
		})
	end

	for indice, oggetto in ipairs(visibili) do
		local rarita = Rarita.Dati[oggetto.rarita]
		local selezionato = oggetto.id == stato.selezionato
		local riga = crea("TextButton", {
			LayoutOrder = indice,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = selezionato and palette.pannelloChiaro or palette.sfondo,
			Text = "",
			AutoButtonColor = true,
			Parent = lista,
		}, {
			angoli(7),
			crea("UIStroke", { Color = rarita.colore, Thickness = selezionato and 2 or 1, Transparency = selezionato and 0 or 0.5 }),
			crea("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		})
		crea("TextLabel", {
			Size = UDim2.new(1, -70, 1, 0),
			BackgroundTransparency = 1,
			Text = (indossato(oggetto) and "[INDOSSATO]  " or "") .. Equipaggiamento.NomeCompleto(oggetto),
			TextColor3 = rarita.colore,
			TextSize = 13,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = riga,
		})
		crea("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 64, 1, 0),
			BackgroundTransparency = 1,
			Text = "P " .. oggetto.potenza,
			TextColor3 = palette.testo,
			TextSize = 13,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = riga,
		})
		riga.Activated:Connect(function()
			stato.selezionato = oggetto.id
			aggiornaLista()
			aggiornaDettaglio()
		end)
	end
end

local function aggiorna(dati)
	if type(dati) ~= "table" then
		return
	end
	stato.oggetti = dati.oggetti or {}
	stato.equipaggiato = dati.equipaggiato or {}
	stato.capienza = dati.capienza or stato.capienza
	if stato.selezionato and not trova(stato.selezionato) then
		stato.selezionato = nil
	end
	aggiornaLista()
	aggiornaDettaglio()
end

-- Interazioni ----------------------------------------------------------------------

local function mostra(visibile, fabbro)
	finestra.Visible = visibile
	player:SetAttribute("Finestra_Inventario", visibile) -- libera il cursore (Visuale.client)
	stato.fabbro = visibile and fabbro == true
	aggiornaLista()
	aggiornaDettaglio()
end

local function alterna()
	mostra(not finestra.Visible, false)
end

apri.Activated:Connect(alterna)
chiudi.Activated:Connect(function()
	mostra(false)
end)
Remotes:WaitForChild("ApriFabbro").OnClientEvent:Connect(function()
	mostra(true, true)
end)
bMigliora.Activated:Connect(function()
	if stato.selezionato then
		AzioneInventario:FireServer("Migliora", stato.selezionato)
	end
end)
UserInputService.InputBegan:Connect(function(input, gestito)
	if not gestito and input.KeyCode == Enum.KeyCode.I then
		alterna()
	end
end)

for filtro, scheda in pairs(schede) do
	scheda.Activated:Connect(function()
		stato.filtro = filtro
		aggiornaLista()
	end)
end

bIndossa.Activated:Connect(function()
	local oggetto = stato.selezionato and trova(stato.selezionato)
	if oggetto then
		AzioneInventario:FireServer(indossato(oggetto) and "Togli" or "Indossa", oggetto.id)
	end
end)
bVendi.Activated:Connect(function()
	if stato.selezionato then
		AzioneInventario:FireServer("Vendi", stato.selezionato)
	end
end)
vendiComuni.Activated:Connect(function()
	AzioneInventario:FireServer("VendiComuni")
end)

InventarioAggiornato.OnClientEvent:Connect(aggiorna)
aggiorna(OttieniInventario:InvokeServer())
