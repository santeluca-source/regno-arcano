-- Valute del gioco e da dove arrivano:
--   Oro       -> prodotto dalla base, si spende in edifici e upgrade
--   Essenza   -> prodotta dalla base, serve per strutture magiche e potenziamenti
--   Frammenti -> solo dai dungeon, servono per forgiare e potenziare l'equipaggiamento
-- Così la base spinge verso i dungeon e i dungeon riportano alla base.

local Valute = {}

Valute.Ordine = { "Oro", "Essenza", "Frammenti" }

Valute.Dati = {
	Oro = { colore = Color3.fromRGB(232, 180, 86), iniziale = 50 },
	Essenza = { colore = Color3.fromRGB(74, 225, 255), iniziale = 25 },
	Frammenti = { colore = Color3.fromRGB(177, 72, 255), iniziale = 0 },
}

function Valute.Esiste(nome)
	return Valute.Dati[nome] ~= nil
end

return Valute
