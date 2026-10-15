-- Corsa (Shift tenuto) e scatto (Ctrl), con una barra di resistenza.
-- Su telefono e controller compaiono pulsanti dedicati.

local Movimento = {}

Movimento.Corsa = {
	moltiplicatore = 1.5, -- velocità mentre si corre
	consumo = 15, -- resistenza al secondo
}

Movimento.Scatto = {
	costo = 30, -- resistenza
	durata = 0.25, -- secondi
	distanza = 18, -- stud percorsi (meno se c'è un muro)
	ricarica = 0.8, -- secondi tra due scatti
	intervalloImmagini = 0.045, -- ogni quanto lascia un'immagine residua
	durataImmagini = 0.35, -- quanto ci mette un'immagine residua a svanire
	-- Per tutta la durata dello scatto non si subiscono danni.
}

-- Visuale: terza persona fissa; durante la corsa si allarga (effetto "anime").
Movimento.Visuale = {
	distanza = 13, -- stud tra telecamera e personaggio (non si può zoomare)
	campoVisivo = 70,
	campoVisivoCorsa = 84,
	colpoScatto = 10, -- quanto si allarga la visuale per un istante allo scatto
	lineeVelocita = 18, -- linee di velocità ai bordi dello schermo durante la corsa
}

Movimento.Resistenza = {
	massimo = 100,
	recupero = 25, -- al secondo
	ritardoRecupero = 0.8, -- secondi di pausa prima che ricominci a salire
}

return Movimento
