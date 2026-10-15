-- Corsa (Shift tenuto), scatto (Ctrl) e doppio salto, con una barra di resistenza.
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

Movimento.DoppioSalto = {
	altezza = 9, -- stud del secondo salto
	costo = 15, -- resistenza
	durataPosa = 0.4, -- secondi della posa raccolta in aria
}

-- Visuale: terza persona fissa, bloccata come lo "shift lock" (cursore nascosto,
-- il personaggio guarda dove guarda la telecamera, mirino al centro).
-- Tenendo premuto `tastoCursore`, o con una finestra aperta, il cursore torna libero.
-- Durante la corsa la visuale si allarga (effetto "anime").
Movimento.Visuale = {
	bloccata = true,
	spalla = Vector3.new(1.75, 0.4, 0), -- telecamera un po' a destra e in alto, sopra la spalla
	tastoCursore = Enum.KeyCode.LeftAlt,
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
