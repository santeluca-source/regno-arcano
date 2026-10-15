-- Scambi lato client: avviso di proposta, finestra di scambio e prompt sui giocatori.
-- Il client mostra e chiede soltanto: il server controlla ed esegue ogni scambio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Rarita = require(Config:WaitForChild("Rarita"))
local Equipaggiamento = require(Config:WaitForChild("Equipaggiamento"))
local ConfigPiazza = require(Config:WaitForChild("Piazza"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ScambioEvento = Remotes:WaitForChild("ScambioEvento")
local AzioneScambio = Remotes:WaitForChild("AzioneScambio")
local InventarioAggiornato = Remotes:WaitForChild("InventarioAggiornato")
local OttieniInventario = Remotes:WaitForChild("OttieniInventario")

local player = Players.LocalPlayer

local palette = {
	sfondo = Color3.fromRGB(24, 22, 34),
	pannello = Color3.fromRGB(39, 36, 53),
	pannelloChiaro = Color3.fromRGB(55, 51, 74),
	bordo = Color3.fromRGB(74, 225, 255),
	testo = Color3.fromRGB(244, 241, 255),
	tenue = Color3.fromRGB(183, 178, 202),
	oro = Color3.fromRGB(232, 180, 86),
	verde = Color3.fromRGB(92, 220, 139),
	rosso = Color3.fromRGB(230, 90, 90),
}

local inventario = { oggetti = {}, equipaggiato = {} }
local stato = nil -- ultimo stato della sessione ricevuto dal server

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

local gui = crea("ScreenGui", {
	Name = "Scambi",
	ResetOnSpawn = false,
	DisplayOrder = 25,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Avviso di proposta -------------------------------------------------------------

local avviso = crea("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.fromOffset(320, 96),
	BackgroundColor3 = palette.sfondo,
	Visible = false,
	Parent = gui,
}, {
	angoli(12),
	crea("UIStroke", { Color = palette.bordo, Thickness = 1.5 }),
})
local testoAvviso = crea("TextLabel", {
	Position = UDim2.fromOffset(12, 8),
	Size = UDim2.new(1, -24, 0, 40),
	BackgroundTransparency = 1,
	TextColor3 = palette.testo,
	TextSize = 15,
	Font = Enum.Font.GothamBold,
	TextWrapped = true,
	Parent = avviso,
})
local siAvviso = bottone({
	Position = UDim2.new(0, 12, 1, -42),
	Size = UDim2.new(0.5, -18, 0, 32),
	BackgroundColor3 = palette.verde,
	TextColor3 = palette.sfondo,
	Text = "Accetta",
	Parent = avviso,
})
local noAvviso = bottone({
	Position = UDim2.new(0.5, 6, 1, -42),
	Size = UDim2.new(0.5, -18, 0, 32),
	BackgroundColor3 = palette.rosso,
	TextColor3 = palette.sfondo,
	Text = "Rifiuta",
	Parent = avviso,
})
local idAvviso = 0

siAvviso.Activated:Connect(function()
	avviso.Visible = false
	AzioneScambio:FireServer("Rispondi", true)
end)
noAvviso.Activated:Connect(function()
	avviso.Visible = false
	AzioneScambio:FireServer("Rispondi", false)
end)

-- Finestra di scambio --------------------------------------------------------------

local finestra = crea("Frame", {
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
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundTransparency = 1,
	TextColor3 = palette.testo,
	TextSize = 18,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = finestra,
})

local corpo = crea("Frame", {
	Position = UDim2.fromOffset(0, 32),
	Size = UDim2.new(1, 0, 1, -32 - 82),
	BackgroundTransparency = 1,
	Parent = finestra,
})

local function colonna(nome, intestazione)
	local cornice = crea("Frame", {
		Name = nome,
		BackgroundColor3 = palette.pannello,
		Parent = corpo,
	}, { angoli(10) })
	crea("TextLabel", {
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, 22),
		BackgroundTransparency = 1,
		Text = intestazione,
		TextColor3 = palette.tenue,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Name = "Intestazione",
		Parent = cornice,
	})
	local lista = crea("ScrollingFrame", {
		Name = "Lista",
		Position = UDim2.fromOffset(6, 28),
		Size = UDim2.new(1, -12, 1, -34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = cornice,
	}, {
		crea("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		crea("UIPadding", { PaddingRight = UDim.new(0, 8) }),
	})
	return cornice, lista
end

local colInventario, listaInventario = colonna("Inventario", "I TUOI OGGETTI (clicca per offrire)")
local colMia, listaMia = colonna("Mia", "LA TUA OFFERTA (clicca per togliere)")
local colSua, listaSua = colonna("Sua", "OFFERTA DELL'ALTRO")

-- Oro: casella per la propria offerta, testo per quella dell'altro.
local casellaOro = crea("TextBox", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 6, 1, -6),
	Size = UDim2.new(1, -12, 0, 30),
	BackgroundColor3 = palette.sfondo,
	PlaceholderText = "Oro da offrire",
	Text = "",
	TextColor3 = palette.oro,
	PlaceholderColor3 = palette.tenue,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	ClearTextOnFocus = false,
	Parent = colMia,
}, { angoli(6) })
listaMia.Size = UDim2.new(1, -12, 1, -72)

local oroAltro = crea("TextLabel", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 6, 1, -6),
	Size = UDim2.new(1, -12, 0, 30),
	BackgroundColor3 = palette.sfondo,
	Text = "",
	TextColor3 = palette.oro,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	Parent = colSua,
}, { angoli(6) })
listaSua.Size = UDim2.new(1, -12, 1, -72)

local statoTesto = crea("TextLabel", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -42),
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundTransparency = 1,
	TextColor3 = palette.tenue,
	TextSize = 13,
	Font = Enum.Font.Gotham,
	TextWrapped = true,
	Parent = finestra,
})

local accetta = bottone({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(0.5, -5, 0, 36),
	BackgroundColor3 = palette.verde,
	TextColor3 = palette.sfondo,
	Text = "Accetta lo scambio",
	Parent = finestra,
})
local annulla = bottone({
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, 0, 1, 0),
	Size = UDim2.new(0.5, -5, 0, 36),
	BackgroundColor3 = palette.rosso,
	TextColor3 = palette.sfondo,
	Text = "Annulla",
	Parent = finestra,
})

-- Tre colonne affiancate su schermi larghi; su quelli stretti l'inventario va sopra.
local function adatta()
	local schermo = gui.AbsoluteSize
	local larghezza = math.min(760, schermo.X - 32)
	local altezza = math.min(500, schermo.Y - 80)
	finestra.Size = UDim2.fromOffset(larghezza, altezza)
	if larghezza >= 620 then
		colInventario.Position = UDim2.new()
		colInventario.Size = UDim2.new(1 / 3, -6, 1, 0)
		colMia.Position = UDim2.new(1 / 3, 3, 0, 0)
		colMia.Size = UDim2.new(1 / 3, -6, 1, 0)
		colSua.Position = UDim2.new(2 / 3, 6, 0, 0)
		colSua.Size = UDim2.new(1 / 3, -6, 1, 0)
	else
		colInventario.Position = UDim2.new()
		colInventario.Size = UDim2.new(1, 0, 0.4, -4)
		colMia.Position = UDim2.new(0, 0, 0.4, 4)
		colMia.Size = UDim2.new(0.5, -4, 0.6, -4)
		colSua.Position = UDim2.new(0.5, 4, 0.4, 4)
		colSua.Size = UDim2.new(0.5, -4, 0.6, -4)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(adatta)
adatta()

-- Contenuto ------------------------------------------------------------------------

local function svuota(lista)
	for _, figlio in ipairs(lista:GetChildren()) do
		if figlio:IsA("GuiObject") then
			figlio:Destroy()
		end
	end
end

local function riga(lista, ordine, oggetto, alClic)
	local rarita = Rarita.Dati[oggetto.rarita] or Rarita.Dati.Comune
	local elemento = crea(alClic and "TextButton" or "Frame", {
		LayoutOrder = ordine,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = palette.sfondo,
		Parent = lista,
	}, {
		angoli(6),
		crea("UIStroke", { Color = rarita.colore, Transparency = 0.4 }),
		crea("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
	})
	if alClic then
		elemento.Text = ""
		elemento.AutoButtonColor = true
		elemento.Activated:Connect(alClic)
	end
	crea("TextLabel", {
		Size = UDim2.new(1, -50, 1, 0),
		BackgroundTransparency = 1,
		Text = Equipaggiamento.NomeCompleto(oggetto),
		TextColor3 = rarita.colore,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = elemento,
	})
	crea("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 46, 1, 0),
		BackgroundTransparency = 1,
		Text = "P " .. oggetto.potenza,
		TextColor3 = palette.testo,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = elemento,
	})
end

local function aggiorna()
	if not stato then
		finestra.Visible = false
		return
	end
	finestra.Visible = true
	titolo.Text = "SCAMBIO CON " .. string.upper(stato.altro.nome)
	colSua.Intestazione.Text = "OFFERTA DI " .. string.upper(stato.altro.nome)

	-- I miei oggetti offerti.
	local offerti = {}
	svuota(listaMia)
	for indice, oggetto in ipairs(stato.io.oggetti) do
		offerti[oggetto.id] = true
		riga(listaMia, indice, oggetto, function()
			AzioneScambio:FireServer("Togli", oggetto.id)
		end)
	end
	-- Quelli dell'altro.
	svuota(listaSua)
	for indice, oggetto in ipairs(stato.altro.oggetti) do
		riga(listaSua, indice, oggetto)
	end
	oroAltro.Text = "Oro: " .. stato.altro.oro
	if not casellaOro:IsFocused() then
		casellaOro.Text = stato.io.oro > 0 and tostring(stato.io.oro) or ""
	end

	-- Il mio inventario: niente oggetti indossati o già offerti.
	svuota(listaInventario)
	local disponibili = {}
	for _, oggetto in ipairs(inventario.oggetti) do
		if not offerti[oggetto.id] and inventario.equipaggiato[oggetto.slot] ~= oggetto.id then
			table.insert(disponibili, oggetto)
		end
	end
	table.sort(disponibili, function(a, b)
		return a.potenza > b.potenza
	end)
	for indice, oggetto in ipairs(disponibili) do
		riga(listaInventario, indice, oggetto, function()
			AzioneScambio:FireServer("Aggiungi", oggetto.id)
		end)
	end

	local io = stato.accettato.io and "Tu: ACCETTATO" or "Tu: in attesa"
	local altro = stato.altro.nome .. (stato.accettato.altro and ": ACCETTATO" or ": in attesa")
	statoTesto.Text = io .. "   ·   " .. altro
		.. "\nOgni modifica annulla le accettazioni. Massimo " .. stato.massimoOggetti .. " oggetti a testa."
	statoTesto.TextColor3 = (stato.accettato.io and stato.accettato.altro) and palette.verde or palette.tenue
	accetta.Text = stato.accettato.io and "In attesa dell'altro..." or "Accetta lo scambio"
	accetta.BackgroundTransparency = stato.accettato.io and 0.5 or 0
end

accetta.Activated:Connect(function()
	if stato and not stato.accettato.io then
		AzioneScambio:FireServer("Accetta", stato.versione)
	end
end)
annulla.Activated:Connect(function()
	AzioneScambio:FireServer("Annulla")
end)
casellaOro.FocusLost:Connect(function()
	local quantita = tonumber(casellaOro.Text) or 0
	AzioneScambio:FireServer("Oro", math.max(0, math.floor(quantita)))
end)

ScambioEvento.OnClientEvent:Connect(function(tipo, dati)
	if tipo == "Richiesta" and type(dati) == "table" then
		idAvviso += 1
		local questo = idAvviso
		testoAvviso.Text = tostring(dati.nome) .. " vuole fare uno scambio con te!"
		avviso.Visible = true
		task.delay(tonumber(dati.scadenza) or 20, function()
			if questo == idAvviso then
				avviso.Visible = false
			end
		end)
	elseif tipo == "Stato" and type(dati) == "table" then
		avviso.Visible = false
		stato = dati
		aggiorna()
	elseif tipo == "Chiuso" then
		-- Il motivo arriva anche come notifica dell'HUD.
		stato = nil
		aggiorna()
	end
end)

InventarioAggiornato.OnClientEvent:Connect(function(dati)
	if type(dati) == "table" then
		inventario.oggetti = dati.oggetti or {}
		inventario.equipaggiato = dati.equipaggiato or {}
		if stato then
			aggiorna()
		end
	end
end)
task.spawn(function()
	local dati = OttieniInventario:InvokeServer()
	if type(dati) == "table" then
		inventario.oggetti = dati.oggetti or {}
		inventario.equipaggiato = dati.equipaggiato or {}
	end
end)

-- Con la finestra o l'avviso aperti il cursore torna libero (vedi Visuale.client).
finestra:GetPropertyChangedSignal("Visible"):Connect(function()
	player:SetAttribute("Finestra_Scambio", finestra.Visible)
end)
avviso:GetPropertyChangedSignal("Visible"):Connect(function()
	player:SetAttribute("Finestra_AvvisoScambio", avviso.Visible)
end)

-- Prompt "Proponi scambio": visibile solo nella Piazza e mai sul proprio personaggio.
local function nellaPiazza()
	local character = player.Character
	local radice = character and character:FindFirstChild("HumanoidRootPart")
	if not radice then
		return false
	end
	return (radice.Position * Vector3.new(1, 0, 1)).Magnitude <= ConfigPiazza.Raggio + 5 and radice.Position.Y < 40
end

task.spawn(function()
	while true do
		task.wait(0.4)
		local visibile = nellaPiazza() and stato == nil
		for _, altro in ipairs(Players:GetPlayers()) do
			local character = altro.Character
			local radice = character and character:FindFirstChild("HumanoidRootPart")
			local prompt = radice and radice:FindFirstChild("PromptScambio")
			if prompt then
				prompt.Enabled = altro ~= player and visibile
			end
		end
	end
end)
