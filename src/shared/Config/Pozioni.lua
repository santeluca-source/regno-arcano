-- Pozioni: si comprano dall'Alchimista nella Piazza e si usano in battaglia
-- con i tasti indicati (o toccando i pulsanti sullo schermo).
--
-- tipo:
--   "Cura"     ridà subito `valore` x100 % della vita massima
--   "Effetto"  attiva l'effetto `effetto` per `durata` secondi:
--                Forza  -> danno x `valore`
--                Pietra -> danni subiti ridotti del `valore` x100 %
-- ricarica: secondi prima di poter bere di nuovo la STESSA pozione
-- massimo:  quante se ne possono portare

local Pozioni = {}

Pozioni.Ordine = { "Cura", "Forza", "Pietra" }

Pozioni.Dati = {
	Cura = {
		nome = "Pozione di Cura",
		descrizione = "Ridà metà della vita",
		colore = Color3.fromRGB(235, 70, 90),
		costo = { Oro = 200, Essenza = 50 },
		tipo = "Cura",
		valore = 0.5,
		ricarica = 12,
		massimo = 10,
		tasto = Enum.KeyCode.Z,
	},
	Forza = {
		nome = "Pozione di Forza",
		descrizione = "+30% danno per 30 secondi",
		colore = Color3.fromRGB(255, 150, 50),
		costo = { Oro = 400, Essenza = 150 },
		tipo = "Effetto",
		effetto = "Forza",
		valore = 1.3,
		durata = 30,
		ricarica = 30,
		massimo = 10,
		tasto = Enum.KeyCode.X,
	},
	Pietra = {
		nome = "Pozione di Pietra",
		descrizione = "-25% danni subiti per 30 secondi",
		colore = Color3.fromRGB(150, 160, 190),
		costo = { Oro = 400, Essenza = 150 },
		tipo = "Effetto",
		effetto = "Pietra",
		valore = 0.25,
		durata = 30,
		ricarica = 30,
		massimo = 10,
		tasto = Enum.KeyCode.C,
	},
}

return Pozioni
