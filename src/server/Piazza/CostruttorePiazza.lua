-- Costruisce la Piazza al centro del mondo e i ponti verso ogni isola.
-- Il piano della Piazza è alla stessa quota del prato delle isole.
--
-- Parti con nomi fissi usate da PiazzaService:
--   "Offerta_<id>"   piedistalli del Mercante (con ProximityPrompt)
--   "Bacheca"        bacheca delle missioni (con ProximityPrompt e SurfaceGui)
--   "PedanaGilda"    cerchio su cui si raduna il gruppo
--   "VeloGilda"      portale della Gilda (un ProximityPrompt "PromptGilda_<dungeon>" per spedizione)
--   "Incudine"       il Fabbro (ProximityPrompt "PromptFabbro"; serve anche per il controllo distanza)
--   "Pozione_<id>"   piedistalli dell'Alchimista (con ProximityPrompt)

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Costruzione = require(script.Parent.Parent.Tycoon.Costruzione)
local Isole = require(script.Parent.Parent.Tycoon.Isole)
local ConfigPiazza = require(ReplicatedStorage.Shared.Config.Piazza)
local Tycoon = require(ReplicatedStorage.Shared.Config.Tycoon)
local Dungeon = require(ReplicatedStorage.Shared.Config.Dungeon)
local Pozioni = require(ReplicatedStorage.Shared.Config.Pozioni)

local C = Costruzione.Colori
local Parte = Costruzione.Parte
local NEON = Enum.Material.Neon

local LASTRICATO = Color3.fromRGB(196, 190, 176)
local LASTRICATO_SCURO = Color3.fromRGB(150, 142, 128)

local CostruttorePiazza = {}

local function prompt(genitore, nome, azione, oggetto, durata)
	local p = Instance.new("ProximityPrompt")
	p.Name = nome
	p.ActionText = azione
	p.ObjectText = oggetto
	p.HoldDuration = durata or 0.3
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = genitore
	return p
end

-- CFrame di un elemento della Piazza: sull'anello di raggio `raggio`, rivolto verso il centro.
local function suAnello(centro, angolo, raggio)
	local posizione = centro.Position + Vector3.new(math.cos(angolo), 0, math.sin(angolo)) * raggio
	return CFrame.lookAt(posizione, Vector3.new(centro.X, posizione.Y, centro.Z))
end

local function costruisciFontana(modello, base)
	Parte(modello, "Vasca", base, Vector3.new(0, 1, 0), Vector3.new(2, 22, 22), LASTRICATO_SCURO, Enum.Material.Marble,
		{ Shape = Enum.PartType.Cylinder, CFrame = base * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)) })
	Parte(modello, "Acqua", base, Vector3.new(0, 1.6, 0), Vector3.new(1, 19, 19), C.ciano, Enum.Material.Glass,
		{ Shape = Enum.PartType.Cylinder, Transparency = 0.3, CanCollide = false,
			CFrame = base * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(90)) })
	Parte(modello, "Colonna", base, Vector3.new(0, 5, 0), Vector3.new(3, 8, 3), LASTRICATO, Enum.Material.Marble)
	local cristallo = Parte(modello, "CristalloFontana", base, Vector3.new(0, 11, 0), Vector3.new(3.5, 5, 3.5), C.ciano, NEON,
		{ CanCollide = false })
	cristallo.CFrame *= CFrame.Angles(0, math.rad(45), 0)
	Costruzione.Luce(cristallo, C.ciano, 3, 40)
	Costruzione.Etichetta(cristallo, "PIAZZA DEL REGNO", C.bianco, Vector2.new(260, 50), 6)
end

local function costruisciPonti(modello)
	for indice = 1, Isole.Numero do
		local angolo = (indice - 1) / Isole.Numero * math.pi * 2
		local direzione = Vector3.new(math.cos(angolo), 0, math.sin(angolo))
		local inizio = ConfigPiazza.Raggio - 4
		local fine = Isole.RaggioAnello - Isole.Lato / 2 + 2
		local lunghezza = fine - inizio
		local centro = direzione * (inizio + lunghezza / 2) + Vector3.new(0, Isole.Altezza, 0)
		local base = CFrame.lookAt(centro, centro + direzione)
		Parte(modello, "Ponte", base, Vector3.new(0, -0.75, 0), Vector3.new(12, 1.5, lunghezza), C.legno, Enum.Material.WoodPlanks)
		for _, x in ipairs({ -6.5, 6.5 }) do
			Parte(modello, "Parapetto", base, Vector3.new(x, 1, 0), Vector3.new(1, 2, lunghezza), C.legno, Enum.Material.Wood)
		end
	end
end

local function costruisciMercante(modello, base)
	Parte(modello, "Bancone", base, Vector3.new(0, 1.5, 1), Vector3.new(16, 3, 3), C.legno, Enum.Material.Wood)
	for _, x in ipairs({ -7.5, 7.5 }) do
		Parte(modello, "Palo", base, Vector3.new(x, 5, 3), Vector3.new(1, 10, 1), C.legno, Enum.Material.Wood)
	end
	Parte(modello, "Tenda", base, Vector3.new(0, 10.5, 2), Vector3.new(18, 1, 8), Color3.fromRGB(180, 60, 70), Enum.Material.Fabric)
	-- Il mercante: una figura semplice dietro il bancone.
	Parte(modello, "Mercante", base, Vector3.new(0, 4.5, 4), Vector3.new(3, 4, 2), Color3.fromRGB(90, 60, 130), Enum.Material.Fabric)
	local testa = Parte(modello, "TestaMercante", base, Vector3.new(0, 7.5, 4), Vector3.new(2, 2, 2), Color3.fromRGB(240, 200, 160))
	Costruzione.Etichetta(testa, "MERCANTE", C.oro, Vector2.new(180, 36), 3)

	for indice, offerta in ipairs(ConfigPiazza.Offerte) do
		local x = (indice - (#ConfigPiazza.Offerte + 1) / 2) * 9
		local piedistallo = Parte(modello, "Offerta_" .. offerta.id, base, Vector3.new(x, 1.5, -5),
			Vector3.new(3.5, 3, 3.5), LASTRICATO_SCURO, Enum.Material.Marble)
		local cassa = Parte(modello, "Cassa", base, Vector3.new(x, 4, -5), Vector3.new(2.5, 2, 2), offerta.colore, Enum.Material.Wood)
		Costruzione.Luce(cassa, offerta.colore, 1.5, 10)
		Costruzione.Etichetta(piedistallo, offerta.nome .. "\n" .. Tycoon.TestoCosto(offerta.costo), C.bianco, Vector2.new(200, 50), 5)
		prompt(piedistallo, "PromptOfferta", "Compra", offerta.nome, 0.5)
	end
end

local function costruisciBacheca(modello, base)
	for _, x in ipairs({ -5.5, 5.5 }) do
		Parte(modello, "Palo", base, Vector3.new(x, 4.5, 0), Vector3.new(1, 9, 1), C.legno, Enum.Material.Wood)
	end
	local bacheca = Parte(modello, "Bacheca", base, Vector3.new(0, 5.5, 0), Vector3.new(10, 6, 0.6), C.legno, Enum.Material.WoodPlanks)
	prompt(bacheca, "PromptBacheca", "Missione", "Bacheca della Gilda", 0.3)

	local superficie = Instance.new("SurfaceGui")
	superficie.Face = Enum.NormalId.Front
	superficie.CanvasSize = Vector2.new(500, 300)
	superficie.Parent = bacheca
	local testo = Instance.new("TextLabel")
	testo.Size = UDim2.fromScale(1, 1)
	testo.BackgroundColor3 = Color3.fromRGB(235, 220, 180)
	testo.TextColor3 = Color3.fromRGB(60, 40, 30)
	testo.Font = Enum.Font.Fantasy
	testo.TextScaled = true
	testo.Text = "MISSIONI\n\nAvvicinati e premi E\nper ricevere un incarico.\nTorna qui per la ricompensa."
	testo.Parent = superficie
end

local function costruisciGilda(modello, base)
	local pedana = Parte(modello, "PedanaGilda", base, Vector3.new(0, 0.1, -4),
		Vector3.new(0.2, ConfigPiazza.Gilda.raggioPedana * 2, ConfigPiazza.Gilda.raggioPedana * 2), C.viola, NEON,
		{ Shape = Enum.PartType.Cylinder, CanCollide = false, Transparency = 0.4 })
	pedana.CFrame = base * CFrame.new(0, 0.1, -4) * CFrame.Angles(0, 0, math.rad(90))

	for _, x in ipairs({ -6.5, 6.5 }) do
		Parte(modello, "Montante", base, Vector3.new(x, 8, 8), Vector3.new(3, 16, 3), C.pietra, Enum.Material.Slate)
	end
	local architrave = Parte(modello, "Architrave", base, Vector3.new(0, 17, 8), Vector3.new(16, 2.5, 3), C.pietraScura, Enum.Material.Slate)
	local velo = Parte(modello, "VeloGilda", base, Vector3.new(0, 8, 8), Vector3.new(10, 14, 0.5), C.viola, NEON,
		{ CanCollide = false, Transparency = 0.25 })
	Costruzione.Luce(velo, C.viola, 2.5, 26)
	Costruzione.Etichetta(architrave, "PORTALE DELLA GILDA\nRadunatevi sul cerchio (max " .. ConfigPiazza.Gilda.massimoGiocatori .. ")",
		C.viola, Vector2.new(280, 56), 3.5)
	-- Un prompt per ogni dungeon, ognuno con il suo tasto.
	for _, spedizione in ipairs(ConfigPiazza.Gilda.spedizioni) do
		local p = prompt(velo, "PromptGilda_" .. spedizione.dungeon, "Spedizione",
			Dungeon.Elenco[spedizione.dungeon].nome, 1)
		p.KeyboardKeyCode = spedizione.tasto
		p.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	end
end

-- Il Fabbro: forgia, incudine e un prompt che apre l'inventario in modalità Fabbro.
local function costruisciFabbro(modello, base)
	Parte(modello, "Forgia", base, Vector3.new(0, 3, 5), Vector3.new(8, 6, 5), C.pietraScura, Enum.Material.Brick)
	local braci = Parte(modello, "Braci", base, Vector3.new(0, 4, 2.4), Vector3.new(4, 2, 0.4),
		Color3.fromRGB(255, 120, 40), NEON, { CanCollide = false })
	Costruzione.Luce(braci, Color3.fromRGB(255, 120, 40), 3, 20)
	Parte(modello, "Camino", base, Vector3.new(0, 9, 6), Vector3.new(3, 8, 3), C.pietraScura, Enum.Material.Brick)
	Parte(modello, "BaseIncudine", base, Vector3.new(0, 1, -3), Vector3.new(2, 2, 2), C.legno, Enum.Material.Wood)
	local incudine = Parte(modello, "Incudine", base, Vector3.new(0, 2.6, -3), Vector3.new(4, 1.2, 2), C.pietraScura, Enum.Material.Metal)
	Costruzione.Etichetta(incudine, "FABBRO\nMigliora il tuo equipaggiamento", C.oro, Vector2.new(240, 50), 4)
	prompt(incudine, "PromptFabbro", "Migliora equipaggiamento", "Fabbro", 0.3)
end

-- L'Alchimista: un calderone e un piedistallo per ogni pozione.
local function costruisciAlchimista(modello, base)
	local calderone = Parte(modello, "Calderone", base, Vector3.new(0, 1.5, 4), Vector3.new(3, 6, 6), C.pietraScura, Enum.Material.Metal,
		{ Shape = Enum.PartType.Cylinder })
	calderone.CFrame = base * CFrame.new(0, 1.5, 4) * CFrame.Angles(0, 0, math.rad(90))
	local intruglio = Parte(modello, "Intruglio", base, Vector3.new(0, 3.05, 4), Vector3.new(0.2, 5, 5), C.verde, NEON,
		{ Shape = Enum.PartType.Cylinder, CanCollide = false })
	intruglio.CFrame = base * CFrame.new(0, 3.05, 4) * CFrame.Angles(0, 0, math.rad(90))
	Costruzione.Luce(intruglio, C.verde, 2, 16)
	Costruzione.Etichetta(calderone, "ALCHIMISTA", C.verde, Vector2.new(180, 36), 5)

	for indice, id in ipairs(Pozioni.Ordine) do
		local pozione = Pozioni.Dati[id]
		local x = (indice - (#Pozioni.Ordine + 1) / 2) * 7
		local piedistallo = Parte(modello, "Pozione_" .. id, base, Vector3.new(x, 1.5, -3),
			Vector3.new(3, 3, 3), LASTRICATO_SCURO, Enum.Material.Marble)
		local fiala = Parte(modello, "Fiala", base, Vector3.new(x, 3.9, -3), Vector3.new(1.2, 1.8, 1.2), pozione.colore, Enum.Material.Glass,
			{ Transparency = 0.2, CanCollide = false })
		Costruzione.Luce(fiala, pozione.colore, 1.2, 8)
		Costruzione.Etichetta(piedistallo, pozione.nome .. "\n" .. Tycoon.TestoCosto(pozione.costo), C.bianco, Vector2.new(190, 48), 4.5)
		prompt(piedistallo, "PromptPozione", "Compra", pozione.nome, 0.3)
	end
end

local function costruisciStatua(modello, base)
	Parte(modello, "Piedistallo", base, Vector3.new(0, 2, 0), Vector3.new(8, 4, 8), LASTRICATO_SCURO, Enum.Material.Marble)
	Parte(modello, "Statua", base, Vector3.new(0, 8, 0), Vector3.new(3, 8, 2), C.oro, Enum.Material.Metal)
	Parte(modello, "Spada", base, Vector3.new(2.2, 10, 0), Vector3.new(0.5, 7, 0.5), C.bianco, NEON, { CanCollide = false })
	Costruzione.Etichetta(modello:FindFirstChild("Statua"), "L'EROE DEL REGNO", C.oro, Vector2.new(200, 36), 6)
end

function CostruttorePiazza.Genera()
	local vecchia = Workspace:FindFirstChild("Piazza")
	if vecchia then
		vecchia:Destroy()
	end

	local modello = Instance.new("Model")
	modello.Name = "Piazza"
	local centro = CFrame.new(0, Isole.Altezza, 0)

	local pavimento = Parte(modello, "Pavimento", centro, Vector3.new(0, -2, 0),
		Vector3.new(4, ConfigPiazza.Raggio * 2, ConfigPiazza.Raggio * 2), LASTRICATO, Enum.Material.Cobblestone,
		{ Shape = Enum.PartType.Cylinder })
	pavimento.CFrame = centro * CFrame.new(0, -2, 0) * CFrame.Angles(0, 0, math.rad(90))
	modello.PrimaryPart = pavimento

	costruisciFontana(modello, centro)
	costruisciPonti(modello)

	-- I quattro punti d'interesse stanno tra un ponte e l'altro.
	local passo = math.pi * 2 / Isole.Numero
	local costruttori = { costruisciMercante, costruisciBacheca, costruisciGilda, costruisciStatua }
	for indice, costruttore in ipairs(costruttori) do
		local angolo = passo / 2 + (indice - 1) * passo * 2
		costruttore(modello, suAnello(centro, angolo, 62))
	end
	-- Negli spazi liberi tra quelli sopra: Fabbro e Alchimista (ne restano due per il futuro).
	local altri = { costruisciFabbro, costruisciAlchimista }
	for indice, costruttore in ipairs(altri) do
		local angolo = passo / 2 + passo + (indice - 1) * passo * 2
		costruttore(modello, suAnello(centro, angolo, 62))
	end

	-- Lampioni ai lati di ogni ponte.
	for indice = 1, Isole.Numero do
		for _, scarto in ipairs({ -0.12, 0.12 }) do
			local angolo = (indice - 1) * passo + scarto
			local base = suAnello(centro, angolo, ConfigPiazza.Raggio - 6)
			Parte(modello, "Lampione", base, Vector3.new(0, 4, 0), Vector3.new(0.8, 8, 0.8), C.pietraScura, Enum.Material.Metal)
			local luce = Parte(modello, "Lanterna", base, Vector3.new(0, 8.6, 0), Vector3.new(1.4, 1.4, 1.4), C.oro, NEON,
				{ CanCollide = false })
			Costruzione.Luce(luce, C.oro, 1.5, 20)
		end
	end

	modello.Parent = Workspace
	return modello
end

return CostruttorePiazza
