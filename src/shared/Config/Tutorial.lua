-- Guida per i nuovi giocatori: una serie di passi mostrati in basso sullo schermo.
-- Ogni passo si completa quando succede il suo `evento` (vedi TutorialService)
-- e dà una piccola ricompensa. Chi ha già costruito il Portale salta la guida.
--
-- evento:
--   "Acquisto"   costruire l'oggetto `oggetto` sull'isola
--   "Incasso"    incassare il Forziere
--   "ColpoGolem" colpire il Golem d'Allenamento
--   "Speciale"   usare l'abilità speciale (Q)
--   "Piazza"     raggiungere la Piazza
--   "Dungeon"    completare il dungeon `dungeon`

local Tutorial = {}

Tutorial.Passi = {
	{
		testo = "Cammina sul pulsante verde «Miniera di Rame» per costruire la tua prima miniera.",
		evento = "Acquisto", oggetto = "Miniera1",
		ricompensa = { Oro = 30 },
	},
	{
		testo = "Il nastro porta l'oro nel Forziere: camminaci sopra per incassarlo.",
		evento = "Incasso",
		ricompensa = { Oro = 50 },
	},
	{
		testo = "Prendi l'arma (tasto 1) e colpisci il Golem d'Allenamento sulla tua isola.",
		evento = "ColpoGolem",
		ricompensa = { Essenza = 20 },
	},
	{
		testo = "Usa la tua abilità speciale: tasto Q o il pulsante in basso a destra.",
		evento = "Speciale",
		ricompensa = { Essenza = 30 },
	},
	{
		testo = "Raggiungi la Piazza: premi M (menu Viaggi) e scegli «Piazza», oppure attraversa il ponte.",
		evento = "Piazza",
		ricompensa = { Oro = 150 },
	},
	{
		testo = "Continua a costruire sull'isola fino al Portale delle Rovine.",
		evento = "Acquisto", oggetto = "Portale",
		ricompensa = { Frammenti = 5 },
	},
	{
		testo = "Entra nelle Rovine Dimenticate (dal portale o dal menu Viaggi, tasto M) e completale!",
		evento = "Dungeon", dungeon = "Rovine",
		ricompensa = { Oro = 1000, Frammenti = 10 },
	},
}

-- Chi possiede già questo oggetto è un giocatore esperto: niente guida.
Tutorial.SaltaSePossiede = "Portale"

return Tutorial
