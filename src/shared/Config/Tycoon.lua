-- Tutto ciò che si può costruire sulla propria isola.
-- Le posizioni sono LOCALI all'isola: X verso destra, Z verso il retro (il fronte
-- con -Z guarda verso il centro del mondo, dove sorgerà la Piazza), Y = 0 è il prato.
--
-- Campi comuni:
--   nome      testo mostrato al giocatore
--   tipo      quale costruttore usare (vedi server/Tycoon/Modelli.lua)
--   costo     { Valuta = quantità }, vuoto = gratuito
--   richiede  lista di id che devono essere già posseduti
--   posizione dove sorge l'oggetto
--   pulsante  dove appare il pulsante di acquisto (assente se gratuito)
--   ordine    per mostrare i pulsanti in sequenza logica

local Tycoon = {}

-- Ogni quanto i minerali sul nastro vengono rimossi se bloccati (secondi).
Tycoon.DurataMinerale = 25
Tycoon.MassimoMineraliPerIsola = 80
Tycoon.VelocitaNastro = 9

Tycoon.Oggetti = {
	-- Fondamenta: date gratis a tutti alla prima visita.
	Nastro = {
		nome = "Nastro Trasportatore",
		tipo = "Nastro",
		ordine = 0,
		costo = {},
		richiede = {},
		posizione = Vector3.new(-10, 0, 0),
		lunghezza = 52,
	},
	Forziere = {
		nome = "Forziere",
		tipo = "Forziere",
		ordine = 0,
		costo = {},
		richiede = {},
		posizione = Vector3.new(30, 0, 0),
	},
	Altare = {
		nome = "Altare delle Classi",
		tipo = "Altare",
		ordine = 0,
		costo = {},
		richiede = {},
		posizione = Vector3.new(-38, 0, 32),
	},
	Golem = {
		nome = "Golem d'Allenamento",
		tipo = "Manichino",
		ordine = 0,
		costo = {},
		richiede = {},
		posizione = Vector3.new(22, 0, 34),
		vita = 500,
	},

	-- Miniere: fanno cadere minerali sul nastro.
	Miniera1 = {
		nome = "Miniera di Rame",
		tipo = "Miniera",
		ordine = 1,
		costo = { Oro = 25 },
		richiede = { "Nastro" },
		posizione = Vector3.new(-32, 0, 0),
		pulsante = Vector3.new(-32, 0, 11),
		valore = 2,
		intervallo = 2,
		colore = Color3.fromRGB(205, 127, 70),
	},
	Miniera2 = {
		nome = "Miniera d'Argento",
		tipo = "Miniera",
		ordine = 2,
		costo = { Oro = 120 },
		richiede = { "Miniera1" },
		posizione = Vector3.new(-24, 0, 0),
		pulsante = Vector3.new(-24, 0, 11),
		valore = 5,
		intervallo = 2,
		colore = Color3.fromRGB(210, 215, 225),
	},
	Pozzo = {
		nome = "Pozzo di Essenza",
		tipo = "Struttura",
		ordine = 3,
		costo = { Oro = 200 },
		richiede = { "Miniera1" },
		posizione = Vector3.new(-24, 0, -24),
		pulsante = Vector3.new(-24, 0, -13),
		essenzaAlSecondo = 1,
		colore = Color3.fromRGB(74, 225, 255),
	},
	Miniera3 = {
		nome = "Miniera d'Oro",
		tipo = "Miniera",
		ordine = 4,
		costo = { Oro = 450 },
		richiede = { "Miniera2" },
		posizione = Vector3.new(-16, 0, 0),
		pulsante = Vector3.new(-16, 0, 11),
		valore = 12,
		intervallo = 2,
		colore = Color3.fromRGB(255, 205, 70),
	},
	Raffinatore = {
		nome = "Raffinatore Arcano",
		tipo = "Raffinatore",
		ordine = 5,
		costo = { Oro = 600, Essenza = 100 },
		richiede = { "Miniera2", "Pozzo" },
		posizione = Vector3.new(8, 0, 0),
		pulsante = Vector3.new(8, 0, 11),
		moltiplicatore = 2,
	},
	Torre = {
		nome = "Torre Arcana",
		tipo = "Struttura",
		ordine = 6,
		costo = { Oro = 900, Essenza = 150 },
		richiede = { "Pozzo" },
		posizione = Vector3.new(-6, 0, -24),
		pulsante = Vector3.new(-6, 0, -13),
		essenzaAlSecondo = 3,
		colore = Color3.fromRGB(177, 72, 255),
	},
	Mura = {
		nome = "Mura Incantate",
		tipo = "Mura",
		ordine = 7,
		costo = { Oro = 1200 },
		richiede = { "Miniera3" },
		posizione = Vector3.new(0, 0, 0),
		pulsante = Vector3.new(30, 0, 24),
	},
	Miniera4 = {
		nome = "Miniera di Mithril",
		tipo = "Miniera",
		ordine = 8,
		costo = { Oro = 1800, Essenza = 300 },
		richiede = { "Miniera3" },
		posizione = Vector3.new(-8, 0, 0),
		pulsante = Vector3.new(-8, 0, 11),
		valore = 30,
		intervallo = 2.5,
		colore = Color3.fromRGB(140, 235, 230),
	},
	Portale = {
		nome = "Portale delle Rovine",
		tipo = "Portale",
		ordine = 9,
		costo = { Oro = 3000, Essenza = 800 },
		richiede = { "Torre", "Miniera3" },
		posizione = Vector3.new(34, 0, -30),
		pulsante = Vector3.new(34, 0, -17),
		dungeon = "Rovine",
		colore = Color3.fromRGB(177, 72, 255),
	},

	-- Collegamento con i dungeon: costano Frammenti, che si trovano solo lì.
	Cristallo = {
		nome = "Cristallo Antico",
		tipo = "Struttura",
		ordine = 10,
		costo = { Oro = 5000, Essenza = 1500, Frammenti = 10 },
		richiede = { "Portale", "Torre" },
		posizione = Vector3.new(12, 0, -24),
		pulsante = Vector3.new(12, 0, -13),
		essenzaAlSecondo = 8,
		colore = Color3.fromRGB(120, 232, 164),
	},
	Miniera5 = {
		nome = "Forgia Runica",
		tipo = "Miniera",
		ordine = 11,
		costo = { Oro = 8000, Frammenti = 25 },
		richiede = { "Portale", "Miniera4" },
		posizione = Vector3.new(0, 0, 0),
		pulsante = Vector3.new(0, 0, 11),
		valore = 90,
		intervallo = 3,
		colore = Color3.fromRGB(255, 90, 160),
	},
	PortaleCripta = {
		nome = "Portale della Cripta",
		tipo = "Portale",
		ordine = 12,
		costo = { Oro = 15000, Essenza = 4000, Frammenti = 40 },
		richiede = { "Cristallo", "Miniera5" },
		posizione = Vector3.new(-38, 0, -36),
		pulsante = Vector3.new(-40, 0, -22),
		dungeon = "Cripta",
		colore = Color3.fromRGB(120, 210, 255),
	},
}

function Tycoon.Gratuito(id)
	local oggetto = Tycoon.Oggetti[id]
	return oggetto ~= nil and next(oggetto.costo) == nil
end

-- Testo del prezzo, es. "600 Oro + 100 Essenza"
function Tycoon.TestoCosto(costo)
	local ordineValute = { "Oro", "Essenza", "Frammenti" }
	local pezzi = {}
	for _, valuta in ipairs(ordineValute) do
		if costo[valuta] then
			table.insert(pezzi, costo[valuta] .. " " .. valuta)
		end
	end
	return #pezzi > 0 and table.concat(pezzi, " + ") or "Gratis"
end

return Tycoon
