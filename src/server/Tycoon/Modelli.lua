-- Costruisce il modello 3D di ogni oggetto del tycoon a partire dalla sua configurazione.
-- Ogni costruttore riceve (modello, base, definizione) e aggiunge le sue parti.
-- Le parti "funzionali" hanno nomi fissi che TycoonService cerca:
--   Nastro      -> "Nastro", "Raccoglitore"
--   Miniera     -> "Ugello"
--   Raffinatore -> "ZonaRaffinatore"
--   Forziere    -> "PiattaformaForziere" (+ etichetta "TestoForziere")
--   Altare      -> ProximityPrompt "PromptAltare"
--   Portale     -> ProximityPrompt "PromptPortale"

local CollectionService = game:GetService("CollectionService")

local Costruzione = require(script.Parent.Costruzione)
local Tycoon = require(game:GetService("ReplicatedStorage").Shared.Config.Tycoon)

local C = Costruzione.Colori
local Parte = Costruzione.Parte
local NEON = Enum.Material.Neon

local ALTEZZA_NASTRO = 2 -- centro del nastro; la superficie è a 2.5

local Modelli = {}
local costruttori = {}

function costruttori.Nastro(modello, base, def)
	local p = def.posizione
	local lunghezza = def.lunghezza
	local nastro = Parte(modello, "Nastro", base, p + Vector3.new(0, ALTEZZA_NASTRO, 0),
		Vector3.new(lunghezza, 1, 5), C.nastro, Enum.Material.DiamondPlate)
	-- Una parte ancorata con velocità trascina tutto ciò che le sta sopra.
	nastro.AssemblyLinearVelocity = base.RightVector * Tycoon.VelocitaNastro

	for _, lato in ipairs({ -3, 3 }) do
		Parte(modello, "Sponda", base, p + Vector3.new(0, ALTEZZA_NASTRO + 1, lato),
			Vector3.new(lunghezza, 2, 1), C.pietraScura, Enum.Material.Metal)
	end
	for x = -lunghezza / 2 + 3, lunghezza / 2 - 3, 12 do
		Parte(modello, "Gamba", base, p + Vector3.new(x, ALTEZZA_NASTRO / 2 - 0.25, 0),
			Vector3.new(1.5, ALTEZZA_NASTRO - 0.5, 4), C.pietraScura, Enum.Material.Metal)
	end
	-- Fondo del nastro, per non far cadere i minerali dall'inizio.
	Parte(modello, "Fermo", base, p + Vector3.new(-lunghezza / 2 - 0.5, ALTEZZA_NASTRO + 1, 0),
		Vector3.new(1, 3, 7), C.pietraScura, Enum.Material.Metal)

	local fine = p + Vector3.new(lunghezza / 2 + 2.5, 0, 0)
	local raccoglitore = Parte(modello, "Raccoglitore", base, fine + Vector3.new(0, 3, 0),
		Vector3.new(4, 6, 7), C.pietra, Enum.Material.Slate)
	local bocca = Parte(modello, "Bocca", base, fine + Vector3.new(0, 6.1, 0),
		Vector3.new(4, 0.2, 7), C.oro, NEON, { CanCollide = false })
	Costruzione.Luce(bocca, C.oro, 1.2, 12)
	Costruzione.Etichetta(raccoglitore, "RACCOGLITORE", C.oro, Vector2.new(160, 34), 5)
end

function costruttori.Miniera(modello, base, def)
	local p = def.posizione
	for _, lato in ipairs({ -4.5, 4.5 }) do
		Parte(modello, "Colonna", base, p + Vector3.new(0, 5, lato),
			Vector3.new(2, 10, 2), C.pietra, Enum.Material.Slate)
	end
	Parte(modello, "Corpo", base, p + Vector3.new(0, 11, 0),
		Vector3.new(5, 4, 11), C.pietraScura, Enum.Material.Slate)
	local cristallo = Parte(modello, "Cristallo", base, p + Vector3.new(0, 14, 0),
		Vector3.new(2.5, 2.5, 2.5), def.colore, NEON, { CanCollide = false })
	cristallo.CFrame *= CFrame.Angles(math.rad(45), math.rad(45), 0)
	Costruzione.Luce(cristallo, def.colore, 1.2, 12)
	Parte(modello, "Ugello", base, p + Vector3.new(0, 8.5, 0),
		Vector3.new(2, 1, 2), def.colore, NEON, { CanCollide = false })
	Costruzione.Etichetta(modello.Corpo, string.upper(def.nome), def.colore, Vector2.new(170, 34), 4)
end

function costruttori.Raffinatore(modello, base, def)
	local p = def.posizione
	for _, lato in ipairs({ -4, 4 }) do
		Parte(modello, "Colonna", base, p + Vector3.new(0, 4, lato),
			Vector3.new(2, 8, 2), C.pietraScura, Enum.Material.Slate)
	end
	Parte(modello, "Arco", base, p + Vector3.new(0, 8.5, 0),
		Vector3.new(3, 1.5, 10), C.viola, NEON)
	local zona = Parte(modello, "ZonaRaffinatore", base, p + Vector3.new(0, 4.5, 0),
		Vector3.new(2, 3, 5), C.viola, NEON, { CanCollide = false, Transparency = 0.6 })
	Costruzione.Luce(zona, C.viola, 2, 14)
	Costruzione.Etichetta(modello.Arco, "RAFFINATORE x" .. def.moltiplicatore, C.viola, Vector2.new(170, 34), 3)
end

function costruttori.Forziere(modello, base, def)
	local p = def.posizione
	local piattaforma = Parte(modello, "PiattaformaForziere", base, p + Vector3.new(0, 0.25, 0),
		Vector3.new(8, 0.5, 8), C.oro, NEON)
	Parte(modello, "Cassa", base, p + Vector3.new(0, 1.75, 5.5),
		Vector3.new(5, 2.5, 3), C.legno, Enum.Material.Wood)
	Parte(modello, "Coperchio", base, p + Vector3.new(0, 3.25, 5.5),
		Vector3.new(5.2, 0.6, 3.2), C.oro, Enum.Material.Metal)
	local testo = Costruzione.Etichetta(piattaforma, "FORZIERE: 0 Oro", C.oro, Vector2.new(220, 46), 5, true)
	testo.Name = "TestoForziere"
end

function costruttori.Altare(modello, base, def)
	local p = def.posizione
	Parte(modello, "Basamento", base, p + Vector3.new(0, 1, 0),
		Vector3.new(8, 2, 8), C.pietraScura, Enum.Material.Slate)
	local cristallo = Parte(modello, "CristalloClassi", base, p + Vector3.new(0, 5, 0),
		Vector3.new(2.5, 5, 2.5), C.ciano, NEON, { CanCollide = false })
	cristallo.CFrame *= CFrame.Angles(0, math.rad(45), 0)
	Costruzione.Luce(cristallo, C.ciano, 1.5, 16)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PromptAltare"
	prompt.ActionText = "Cambia classe"
	prompt.ObjectText = def.nome
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = cristallo
end

function costruttori.Struttura(modello, base, def)
	local p = def.posizione
	local altezza = 6 + def.essenzaAlSecondo * 2
	Parte(modello, "Basamento", base, p + Vector3.new(0, 1, 0),
		Vector3.new(9, 2, 9), C.pietra, Enum.Material.Slate)
	local colonna = Parte(modello, "Colonna", base, p + Vector3.new(0, 2 + altezza / 2, 0),
		Vector3.new(4, altezza, 4), C.pietraScura, Enum.Material.Slate)
	local sfera = Parte(modello, "Nucleo", base, p + Vector3.new(0, 4 + altezza, 0),
		Vector3.new(4, 4, 4), def.colore, NEON, { CanCollide = false, Shape = Enum.PartType.Ball })
	Costruzione.Luce(sfera, def.colore, 2, 20)
	Costruzione.Etichetta(colonna, string.upper(def.nome) .. "\n+" .. def.essenzaAlSecondo .. " Essenza/s",
		def.colore, Vector2.new(190, 48), altezza / 2 + 6)
end

function costruttori.Mura(modello, base, _def)
	local meta = 48
	local altezza = 6
	local tratti = {
		-- posizione, dimensione: il lato frontale (-Z) ha un'apertura centrale
		{ Vector3.new(0, altezza / 2, meta), Vector3.new(96, altezza, 2) },
		{ Vector3.new(-meta, altezza / 2, 0), Vector3.new(2, altezza, 96) },
		{ Vector3.new(meta, altezza / 2, 0), Vector3.new(2, altezza, 96) },
		{ Vector3.new(-29, altezza / 2, -meta), Vector3.new(38, altezza, 2) },
		{ Vector3.new(29, altezza / 2, -meta), Vector3.new(38, altezza, 2) },
	}
	for _, tratto in ipairs(tratti) do
		Parte(modello, "Muro", base, tratto[1], tratto[2], C.pietra, Enum.Material.Cobblestone)
		Parte(modello, "Runa", base, tratto[1] + Vector3.new(0, altezza / 2 + 0.25, 0),
			Vector3.new(tratto[2].X, 0.5, tratto[2].Z), C.ciano, NEON, { CanCollide = false })
	end
end

function costruttori.Portale(modello, base, def)
	local p = def.posizione
	Parte(modello, "Soglia", base, p + Vector3.new(0, 0.5, 0),
		Vector3.new(16, 1, 5), C.pietraScura, Enum.Material.Slate)
	for _, lato in ipairs({ -6.5, 6.5 }) do
		Parte(modello, "Montante", base, p + Vector3.new(lato, 8, 0),
			Vector3.new(3, 14, 3), C.pietra, Enum.Material.Slate)
	end
	Parte(modello, "Architrave", base, p + Vector3.new(0, 16, 0),
		Vector3.new(16, 2.5, 3), C.pietraScura, Enum.Material.Slate)
	local colore = def.colore or C.viola
	local velo = Parte(modello, "Velo", base, p + Vector3.new(0, 8, 0),
		Vector3.new(10, 13, 0.5), colore, NEON, { CanCollide = false, Transparency = 0.25 })
	Costruzione.Luce(velo, colore, 2.5, 24)
	Costruzione.Etichetta(modello.Architrave, string.upper(def.nome), colore, Vector2.new(220, 40), 3)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PromptPortale"
	prompt.ActionText = "Entra nel dungeon"
	prompt.ObjectText = def.nome
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = velo
end

-- Bersaglio per provare le abilità: è un "Nemico" come gli altri, ma non muore mai.
function costruttori.Manichino(modello, base, def)
	local p = def.posizione
	Parte(modello, "Basamento", base, p + Vector3.new(0, 0.5, 0),
		Vector3.new(8, 1, 8), C.pietraScura, Enum.Material.Slate)
	local corpo = Parte(modello, "HumanoidRootPart", base, p + Vector3.new(0, 5, 0),
		Vector3.new(4, 6, 3), C.pietra, Enum.Material.Slate)
	Parte(modello, "Head", base, p + Vector3.new(0, 9.25, 0),
		Vector3.new(2.5, 2.5, 2.5), C.pietra, Enum.Material.Slate)
	for _, lato in ipairs({ -3, 3 }) do
		Parte(modello, "Braccio", base, p + Vector3.new(lato, 5.5, 0),
			Vector3.new(2, 5, 2), C.pietraScura, Enum.Material.Slate)
	end
	local occhio = Parte(modello, "Occhio", base, p + Vector3.new(0, 9.5, -1.3),
		Vector3.new(1.6, 0.4, 0.2), C.ciano, NEON, { CanCollide = false })
	Costruzione.Luce(occhio, C.ciano, 1, 8)
	modello.PrimaryPart = corpo

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = def.vita
	humanoid.Health = def.vita
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	-- Senza queste due righe un Humanoid senza "collo" muore appena creato.
	humanoid.RequiresNeck = false
	humanoid.EvaluateStateMachine = false
	humanoid.Parent = modello

	local barra = Costruzione.Etichetta(corpo, "", C.bianco, Vector2.new(220, 32), 6)
	barra.Name = "TestoVita"
	barra.Parent.Name = "BarraVita"

	modello:SetAttribute("Manichino", true)
	modello:SetAttribute("NomeVisibile", "Golem")
	CollectionService:AddTag(modello, "Nemico")
end

function Modelli.Costruisci(cartella, base, id, def)
	local costruttore = costruttori[def.tipo]
	assert(costruttore, "Nessun costruttore per il tipo " .. tostring(def.tipo))
	local modello = Instance.new("Model")
	modello.Name = id
	costruttore(modello, base, def)
	modello.Parent = cartella
	return modello
end

-- Pulsante di acquisto: una piastra rotonda con nome e prezzo.
function Modelli.Pulsante(cartella, base, id, def)
	local piastra = Parte(cartella, id, base, def.pulsante + Vector3.new(0, 0.3, 0),
		Vector3.new(0.6, 5, 5), C.verde, NEON, { Shape = Enum.PartType.Cylinder })
	piastra.CFrame = base * CFrame.new(def.pulsante + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local testo = Costruzione.Etichetta(piastra, def.nome .. "\n" .. Tycoon.TestoCosto(def.costo),
		C.bianco, Vector2.new(200, 52), 3.5)
	testo.Name = "TestoPulsante"
	return piastra
end

return Modelli
