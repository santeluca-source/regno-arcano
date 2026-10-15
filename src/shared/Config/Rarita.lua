-- Rarità dell'equipaggiamento trovato nei dungeon.
-- `potenza` è il moltiplicatore applicato alle statistiche base dell'oggetto.
-- `nomeF` è la forma femminile, per i nomi degli oggetti ("Arma Rara").

local Rarita = {}

Rarita.Ordine = { "Comune", "NonComune", "Raro", "Epico", "Leggendario" }

Rarita.Dati = {
	Comune = { nome = "Comune", nomeF = "Comune", colore = Color3.fromRGB(200, 200, 200), potenza = 1.0 },
	NonComune = { nome = "Non comune", nomeF = "Non comune", colore = Color3.fromRGB(92, 220, 139), potenza = 1.25 },
	Raro = { nome = "Raro", nomeF = "Rara", colore = Color3.fromRGB(74, 160, 255), potenza = 1.6 },
	Epico = { nome = "Epico", nomeF = "Epica", colore = Color3.fromRGB(177, 72, 255), potenza = 2.1 },
	Leggendario = { nome = "Leggendario", nomeF = "Leggendaria", colore = Color3.fromRGB(255, 170, 40), potenza = 3.0 },
}

-- Probabilità di drop (somma 100) per tipo di nemico.
Rarita.Tabelle = {
	Nemico = { Comune = 55, NonComune = 28, Raro = 14, Epico = 3, Leggendario = 0 },
	Boss = { Comune = 0, NonComune = 25, Raro = 45, Epico = 25, Leggendario = 5 },
	-- Cripta di Ghiaccio: loot più ricco.
	NemicoCripta = { Comune = 30, NonComune = 35, Raro = 25, Epico = 9, Leggendario = 1 },
	BossCripta = { Comune = 0, NonComune = 10, Raro = 40, Epico = 38, Leggendario = 12 },
}

-- Estrae una rarità dalla tabella indicata. `rng` è opzionale (Random.new()).
function Rarita.Estrai(nomeTabella, rng)
	local tabella = Rarita.Tabelle[nomeTabella]
	assert(tabella, "Tabella rarità sconosciuta: " .. tostring(nomeTabella))
	local tiro = (rng or Random.new()):NextInteger(1, 100)
	local accumulato = 0
	for _, id in ipairs(Rarita.Ordine) do
		accumulato += tabella[id] or 0
		if tiro <= accumulato then
			return id
		end
	end
	return Rarita.Ordine[1]
end

return Rarita
