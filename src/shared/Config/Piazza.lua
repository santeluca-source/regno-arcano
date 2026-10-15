-- La Piazza: zona condivisa al centro del mondo, collegata a ogni isola da un ponte.
-- Qui ci sono il Mercante, la Bacheca delle missioni e il Portale della Gilda
-- per entrare nei dungeon in gruppo.

local Piazza = {}

Piazza.Raggio = 90

-- Mercante ---------------------------------------------------------------------
-- Ogni offerta è una cassa che contiene un oggetto casuale (Arma o Armatura)
-- estratto dalla tabella di rarità indicata (vedi Config/Rarita.lua).

Piazza.Offerte = {
	{ id = "CassaComune", nome = "Cassa del Viandante", costo = { Oro = 1500 }, tabella = "Nemico",
		colore = Color3.fromRGB(150, 105, 70) },
	{ id = "CassaRara", nome = "Cassa delle Rovine", costo = { Frammenti = 20 }, tabella = "Boss",
		colore = Color3.fromRGB(177, 72, 255) },
}

-- Missioni ----------------------------------------------------------------------
-- tipo:
--   "Nemici"      sconfiggi N nemici qualsiasi (conta chi dà il colpo finale)
--   "NemicoTipo"  sconfiggi N nemici di un tipo preciso (campo `nemico`)
--   "Dungeon"     completa N volte un dungeon (campo `dungeon`) sconfiggendo il boss
--   "Incasso"     incassa N Oro dal Forziere della tua isola
-- richiede: (facoltativo) la missione viene proposta solo a chi ha costruito
--           quell'oggetto sull'isola, così non chiede cose ancora impossibili.

Piazza.Missioni = {
	Cacciatore = {
		nome = "Cacciatore",
		descrizione = "Sconfiggi 15 nemici nei dungeon",
		tipo = "Nemici",
		richiede = "Portale",
		obiettivo = 15,
		ricompensa = { Oro = 800, Frammenti = 5 },
	},
	Spaccapietre = {
		nome = "Spaccapietre",
		descrizione = "Sconfiggi 3 Guardiani di Pietra",
		tipo = "NemicoTipo",
		nemico = "Guardiano",
		richiede = "Portale",
		obiettivo = 3,
		ricompensa = { Frammenti = 12 },
	},
	Esploratore = {
		nome = "Esploratore",
		descrizione = "Completa le Rovine Dimenticate",
		tipo = "Dungeon",
		dungeon = "Rovine",
		richiede = "Portale",
		obiettivo = 1,
		ricompensa = { Oro = 1500, Frammenti = 10 },
	},
	Rompighiaccio = {
		nome = "Rompighiaccio",
		descrizione = "Completa la Cripta di Ghiaccio",
		tipo = "Dungeon",
		dungeon = "Cripta",
		richiede = "PortaleCripta",
		obiettivo = 1,
		ricompensa = { Oro = 5000, Frammenti = 30 },
	},
	Tesoriere = {
		nome = "Tesoriere",
		descrizione = "Incassa 3000 Oro dal tuo Forziere",
		tipo = "Incasso",
		obiettivo = 3000,
		ricompensa = { Essenza = 400 },
	},
}

-- Portale della Gilda -------------------------------------------------------------

Piazza.Gilda = {
	massimoGiocatori = 4,
	raggioPedana = 10,
	-- Una spedizione per dungeon, ognuna col suo tasto sul portale.
	-- Chi la avvia deve aver costruito il portale corrispondente sulla propria isola;
	-- gli altri possono unirsi anche senza (così i nuovi giocatori vengono aiutati).
	spedizioni = {
		{ dungeon = "Rovine", richiede = "Portale", tasto = Enum.KeyCode.E },
		{ dungeon = "Cripta", richiede = "PortaleCripta", tasto = Enum.KeyCode.F },
	},
}

-- Scambi tra giocatori ----------------------------------------------------------
-- Si propongono solo nella Piazza, avvicinandosi a un altro giocatore.

Piazza.Scambi = {
	massimoOggetti = 8, -- per parte
	scadenzaRichiesta = 20, -- secondi per rispondere a una proposta
	attesaTraRichieste = 3, -- secondi tra due proposte dello stesso giocatore
}

return Piazza
