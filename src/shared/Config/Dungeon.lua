-- Dungeon, nemici e ricompense.
-- Ogni partita è un'istanza separata: chi entra dal proprio portale (o dalla Gilda
-- nella Piazza con il suo gruppo) ottiene una copia del dungeon tutta per sé.
-- Per aggiungere un dungeon: nuovi nemici qui sotto, una voce in Dungeon.Elenco
-- e un portale in Config/Tycoon.lua con `dungeon = "<id>"`.

local Dungeon = {}

-- Nemici -------------------------------------------------------------------------
--   attacco   "Mischia" (colpo ravvicinato) o "Distanza" (proiettile)
--   portata   distanza a cui il nemico può attaccare
--   frammenti dati a OGNI giocatore della partita quando il nemico viene sconfitto
--   probabilitaOggetto  % che chi dà il colpo finale trovi un oggetto
--   rallenta  (facoltativo) i suoi colpi rallentano: { fattore = velocità x, durata = secondi }
--   onda      (boss) colpisce il terreno attorno a sé dopo un cerchio rosso di preavviso
--   pioggia   (boss) fa cadere colpi sulla posizione di ogni giocatore, con preavviso

Dungeon.Nemici = {
	-- Rovine Dimenticate
	Scheletro = {
		nome = "Scheletro", vita = 90, danno = 10, velocita = 13,
		attacco = "Mischia", portata = 5, ricarica = 1.3, scala = 1,
		colore = Color3.fromRGB(225, 220, 200), frammenti = 1, probabilitaOggetto = 8,
	},
	Arciere = {
		nome = "Arciere Spettrale", vita = 60, danno = 8, velocita = 10,
		attacco = "Distanza", portata = 40, ricarica = 2.2, scala = 0.9,
		colore = Color3.fromRGB(120, 200, 255), frammenti = 1, probabilitaOggetto = 8,
	},
	Guardiano = {
		nome = "Guardiano di Pietra", vita = 220, danno = 18, velocita = 9,
		attacco = "Mischia", portata = 7, ricarica = 2, scala = 1.5,
		colore = Color3.fromRGB(130, 130, 150), frammenti = 3, probabilitaOggetto = 15,
	},
	ReDelleRovine = {
		nome = "Re delle Rovine", vita = 1400, danno = 22, velocita = 11,
		attacco = "Mischia", portata = 9, ricarica = 1.6, scala = 2.4,
		colore = Color3.fromRGB(255, 190, 70), frammenti = 8, probabilitaOggetto = 0,
		boss = true,
		onda = { ogni = 7, raggio = 16, danno = 28, preavviso = 1.3 },
	},

	-- Cripta di Ghiaccio
	LupoGlaciale = {
		nome = "Lupo Glaciale", vita = 110, danno = 14, velocita = 22,
		attacco = "Mischia", portata = 5, ricarica = 1, scala = 0.85,
		colore = Color3.fromRGB(190, 215, 235), frammenti = 2, probabilitaOggetto = 10,
	},
	SpettroGhiaccio = {
		nome = "Spettro di Ghiaccio", vita = 90, danno = 12, velocita = 10,
		attacco = "Distanza", portata = 42, ricarica = 2.4, scala = 1,
		colore = Color3.fromRGB(150, 220, 255), frammenti = 2, probabilitaOggetto = 10,
		rallenta = { fattore = 0.55, durata = 2.5 },
	},
	GolemBrina = {
		nome = "Golem di Brina", vita = 420, danno = 26, velocita = 8,
		attacco = "Mischia", portata = 8, ricarica = 2.2, scala = 1.7,
		colore = Color3.fromRGB(200, 230, 245), frammenti = 5, probabilitaOggetto = 18,
	},
	ReginaGhiacci = {
		nome = "Regina dei Ghiacci", vita = 2600, danno = 30, velocita = 12,
		attacco = "Mischia", portata = 9, ricarica = 1.5, scala = 2.5,
		colore = Color3.fromRGB(120, 200, 255), frammenti = 15, probabilitaOggetto = 0,
		boss = true,
		rallenta = { fattore = 0.6, durata = 2 },
		onda = { ogni = 8, raggio = 16, danno = 34, preavviso = 1.2 },
		pioggia = { ogni = 11, raggio = 8, danno = 30, preavviso = 1.4 },
	},
}

-- Dungeon ------------------------------------------------------------------------
--   sale             nemici di ogni sala; ogni sala si apre quando quella prima è ripulita
--   vitaPerGiocatoreExtra  +% vita dei nemici per ogni giocatore in più nel gruppo
--   tabellaNemici / tabellaForziere   tabelle di rarità (Config/Rarita.lua)
--   potenza          moltiplicatore della potenza degli oggetti trovati qui
--   tema             colori e materiali della mappa

Dungeon.Ordine = { "Rovine", "Cripta" }

Dungeon.Elenco = {
	Rovine = {
		nome = "Rovine Dimenticate",
		sale = {
			{ Scheletro = 3 },
			{ Scheletro = 3, Arciere = 2 },
			{ Guardiano = 1, Arciere = 2, Scheletro = 2 },
		},
		boss = "ReDelleRovine",
		annuncioBoss = "Il Re delle Rovine si è risvegliato!",
		vitaPerGiocatoreExtra = 0.6,
		ricompensaForziere = { Oro = 250, Frammenti = 6 },
		tabellaNemici = "Nemico",
		tabellaForziere = "Boss",
		potenza = 1,
		provenienza = "delle Rovine",
		tema = {
			muri = Color3.fromRGB(58, 56, 72), materialeMuri = Enum.Material.Cobblestone,
			pavimento = Color3.fromRGB(88, 84, 104), materialePavimento = Enum.Material.Slate,
			luce = Color3.fromRGB(255, 150, 60), porta = Color3.fromRGB(230, 60, 70),
		},
	},
	Cripta = {
		nome = "Cripta di Ghiaccio",
		sale = {
			{ LupoGlaciale = 3, SpettroGhiaccio = 1 },
			{ LupoGlaciale = 2, SpettroGhiaccio = 3 },
			{ GolemBrina = 2, SpettroGhiaccio = 2, LupoGlaciale = 2 },
		},
		boss = "ReginaGhiacci",
		annuncioBoss = "La Regina dei Ghiacci ti ha visto arrivare...",
		vitaPerGiocatoreExtra = 0.6,
		ricompensaForziere = { Oro = 900, Frammenti = 18 },
		tabellaNemici = "NemicoCripta",
		tabellaForziere = "BossCripta",
		potenza = 1.3,
		provenienza = "della Cripta",
		tema = {
			muri = Color3.fromRGB(150, 190, 215), materialeMuri = Enum.Material.Ice,
			pavimento = Color3.fromRGB(215, 235, 245), materialePavimento = Enum.Material.Glacier,
			luce = Color3.fromRGB(120, 210, 255), porta = Color3.fromRGB(80, 160, 255),
		},
	},
}

return Dungeon
