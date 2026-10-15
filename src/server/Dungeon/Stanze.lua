-- Costruisce la mappa di un dungeon: un ingresso, tre sale e la sala del boss in fila.
-- Tutte le posizioni sono relative al CFrame di origine dell'istanza (+Z = avanti).
-- Colori e materiali arrivano dal `tema` del dungeon (Config/Dungeon.lua).
--
-- Parti con nomi fissi usate da DungeonService:
--   "Arrivo"            dove compaiono i giocatori
--   "Zona1".."Zona4"    area di spawn dei nemici di ogni sala (la 4 è il boss)
--   "Porta1".."Porta3"  barriere che si aprono quando la sala precedente è ripulita
--   "PuntoFinale"       dove appaiono forziere e portale di ritorno

local Costruzione = require(script.Parent.Parent.Tycoon.Costruzione)

local Parte = Costruzione.Parte
local SUPPORTO = Color3.fromRGB(88, 84, 104)
local ALTEZZA_MURI = 18
local LARGHEZZA_PASSAGGIO = 12

local Stanze = {}

-- Ogni sala: centro lungo Z, larghezza (X) e profondità (Z).
local SALE = {
	{ nome = "Ingresso", z = 15, larghezza = 30, profondita = 30 },
	{ nome = "Zona1", z = 70, larghezza = 60, profondita = 60 },
	{ nome = "Zona2", z = 140, larghezza = 60, profondita = 60 },
	{ nome = "Zona3", z = 210, larghezza = 60, profondita = 60 },
	{ nome = "Zona4", z = 290, larghezza = 80, profondita = 80 },
}

local function muro(modello, base, centro, dimensione, tema)
	Parte(modello, "Muro", base, centro, dimensione, tema.muri, tema.materialeMuri)
end

-- Muro orizzontale (lungo X) con un'apertura centrale opzionale.
local function muroConApertura(modello, base, z, larghezza, apertura, tema)
	local y = ALTEZZA_MURI / 2
	if not apertura then
		muro(modello, base, Vector3.new(0, y, z), Vector3.new(larghezza, ALTEZZA_MURI, 2), tema)
		return
	end
	local lato = (larghezza - LARGHEZZA_PASSAGGIO) / 2
	local x = LARGHEZZA_PASSAGGIO / 2 + lato / 2
	muro(modello, base, Vector3.new(-x, y, z), Vector3.new(lato, ALTEZZA_MURI, 2), tema)
	muro(modello, base, Vector3.new(x, y, z), Vector3.new(lato, ALTEZZA_MURI, 2), tema)
end

local function torcia(modello, base, posizione, tema)
	Parte(modello, "Supporto", base, posizione, Vector3.new(0.6, 1.5, 0.6), SUPPORTO, Enum.Material.Metal)
	local fiamma = Parte(modello, "Fiamma", base, posizione + Vector3.new(0, 1.2, 0),
		Vector3.new(0.9, 0.9, 0.9), tema.luce, Enum.Material.Neon, { CanCollide = false })
	Costruzione.Luce(fiamma, tema.luce, 2, 22)
end

function Stanze.Costruisci(genitore, base, nome, tema)
	local modello = Instance.new("Model")
	modello.Name = nome

	-- Pavimento unico lungo tutto il dungeon.
	local fine = SALE[#SALE].z + SALE[#SALE].profondita / 2
	Parte(modello, "Pavimento", base, Vector3.new(0, -1, fine / 2),
		Vector3.new(84, 2, fine), tema.pavimento, tema.materialePavimento)

	for indice, sala in ipairs(SALE) do
		local inizio = sala.z - sala.profondita / 2
		local termine = sala.z + sala.profondita / 2
		local metaX = sala.larghezza / 2

		-- Muri laterali
		muro(modello, base, Vector3.new(-metaX - 1, ALTEZZA_MURI / 2, sala.z), Vector3.new(2, ALTEZZA_MURI, sala.profondita), tema)
		muro(modello, base, Vector3.new(metaX + 1, ALTEZZA_MURI / 2, sala.z), Vector3.new(2, ALTEZZA_MURI, sala.profondita), tema)
		-- Muro di ingresso (chiuso solo per la prima sala) e di uscita (chiuso solo per l'ultima)
		muroConApertura(modello, base, inizio - 1, sala.larghezza + 4, indice > 1, tema)
		muroConApertura(modello, base, termine + 1, sala.larghezza + 4, indice < #SALE, tema)

		-- Zona di spawn invisibile (margine di 8 stud dai muri)
		if indice > 1 then
			Parte(modello, sala.nome, base, Vector3.new(0, 1, sala.z),
				Vector3.new(sala.larghezza - 16, 1, sala.profondita - 16), tema.muri, nil,
				{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		end

		for _, x in ipairs({ -metaX + 0.8, metaX - 0.8 }) do
			for _, z in ipairs({ inizio + 6, termine - 6 }) do
				torcia(modello, base, Vector3.new(x, 7, z), tema)
			end
		end

		-- Corridoio verso la sala successiva, con la porta a metà.
		local prossima = SALE[indice + 1]
		if prossima then
			local corridoioInizio = termine + 2
			local corridoioFine = prossima.z - prossima.profondita / 2 - 2
			local lunghezza = corridoioFine - corridoioInizio
			local centroZ = (corridoioInizio + corridoioFine) / 2
			for _, x in ipairs({ -LARGHEZZA_PASSAGGIO / 2 - 1, LARGHEZZA_PASSAGGIO / 2 + 1 }) do
				muro(modello, base, Vector3.new(x, ALTEZZA_MURI / 2, centroZ), Vector3.new(2, ALTEZZA_MURI, lunghezza + 4), tema)
			end
			if indice > 1 then
				local porta = Parte(modello, "Porta" .. (indice - 1), base, Vector3.new(0, ALTEZZA_MURI / 2, centroZ),
					Vector3.new(LARGHEZZA_PASSAGGIO, ALTEZZA_MURI, 1), tema.porta, Enum.Material.ForceField)
				Costruzione.Luce(porta, tema.porta, 1.5, 14)
			end
		end
	end

	local primaSala = SALE[1]
	Parte(modello, "Arrivo", base, Vector3.new(0, 0.1, primaSala.z - 6), Vector3.new(6, 0.2, 6),
		Color3.fromRGB(177, 72, 255), Enum.Material.Neon, { CanCollide = false })
	local ultima = SALE[#SALE]
	Parte(modello, "PuntoFinale", base, Vector3.new(0, 0.1, ultima.z + ultima.profondita / 2 - 18), Vector3.new(1, 0.2, 1),
		tema.muri, nil, { Transparency = 1, CanCollide = false, CanQuery = false })

	modello.Parent = genitore
	return modello
end

-- Un punto casuale (a terra) dentro una zona di spawn.
function Stanze.PuntoCasuale(zona, rng)
	local meta = zona.Size / 2
	local locale = Vector3.new(rng:NextNumber(-meta.X, meta.X), -zona.Size.Y / 2, rng:NextNumber(-meta.Z, meta.Z))
	return zona.CFrame * CFrame.new(locale)
end

Stanze.NumeroSale = #SALE - 1 -- sale con nemici, boss compreso

return Stanze
