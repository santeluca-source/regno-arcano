-- Corsa (Shift tenuto) e capriola (Ctrl), con una barra di resistenza.
-- Su telefono e controller compaiono pulsanti dedicati.

local Movimento = {}

Movimento.Corsa = {
	moltiplicatore = 1.5, -- velocità mentre si corre
	consumo = 15, -- resistenza al secondo
}

Movimento.Capriola = {
	costo = 30, -- resistenza
	durata = 0.4, -- secondi
	distanza = 16, -- stud percorsi
	ricarica = 0.8, -- secondi tra due capriole
	-- Per tutta la durata della capriola non si subiscono danni.
}

Movimento.Resistenza = {
	massimo = 100,
	recupero = 25, -- al secondo
	ritardoRecupero = 0.8, -- secondi di pausa prima che ricominci a salire
}

return Movimento
