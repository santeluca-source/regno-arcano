-- Regole dell'equipaggiamento, condivise tra server (che le applica) e client
-- (che le mostra nel menu dell'inventario): così i numeri coincidono sempre.

local Equipaggiamento = {}

Equipaggiamento.Slot = { "Arma", "Armatura" }
Equipaggiamento.Capienza = 60
Equipaggiamento.PotenzaBase = 10

-- Arma: il danno viene moltiplicato per questo valore.
function Equipaggiamento.MoltiplicatoreDanno(potenza)
	return 1 + potenza / 20
end

-- Armatura: vita massima in più.
function Equipaggiamento.VitaBonus(potenza)
	return potenza * 4
end

-- Frammenti ottenuti vendendo l'oggetto.
function Equipaggiamento.ValoreVendita(potenza)
	return math.max(1, math.floor(potenza * 0.2))
end

-- Fabbro -------------------------------------------------------------------------
-- Ogni livello (+1 ... +10) aggiunge il 12% della potenza di partenza dell'oggetto.
-- Il miglioramento riesce sempre; il costo cresce col livello e con la rarità.

Equipaggiamento.LivelloMassimo = 10
Equipaggiamento.BonusPerLivello = 0.12
Equipaggiamento.DistanzaFabbro = 16 -- bisogna stare vicino all'incudine

local FATTORE_RARITA = { Comune = 1, NonComune = 1.5, Raro = 2, Epico = 3, Leggendario = 4 }

function Equipaggiamento.PotenzaAlLivello(potenzaBase, livello)
	return math.floor(potenzaBase * (1 + Equipaggiamento.BonusPerLivello * livello) + 0.5)
end

-- Costo per passare al livello successivo, oppure nil se l'oggetto è già al massimo.
function Equipaggiamento.CostoMiglioramento(oggetto)
	local livello = oggetto.livello or 0
	if livello >= Equipaggiamento.LivelloMassimo then
		return nil
	end
	local prossimo = livello + 1
	local fattore = FATTORE_RARITA[oggetto.rarita] or 1
	return {
		Oro = 400 * prossimo,
		Frammenti = math.ceil(3 * prossimo * fattore),
	}
end

-- Nome con il livello, es. "Arma Rara delle Rovine +3".
function Equipaggiamento.NomeCompleto(oggetto)
	local livello = oggetto.livello or 0
	return livello > 0 and (oggetto.nome .. " +" .. livello) or oggetto.nome
end

-- Descrizione breve dell'effetto, es. "+80% danno" o "+64 vita".
function Equipaggiamento.TestoEffetto(slot, potenza)
	if slot == "Arma" then
		return "+" .. math.floor((Equipaggiamento.MoltiplicatoreDanno(potenza) - 1) * 100 + 0.5) .. "% danno"
	end
	return "+" .. Equipaggiamento.VitaBonus(potenza) .. " vita"
end

return Equipaggiamento
