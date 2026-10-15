-- Velocità di camminata decisa dal server (classe, rallentamenti...).
-- Viene salvata anche nell'attributo "VelocitaBase" dell'Humanoid: il client ci
-- applica sopra la corsa, così la corsa non cancella per sbaglio un rallentamento.

local Velocita = {}

function Velocita.Imposta(humanoid, valore)
	humanoid:SetAttribute("VelocitaBase", valore)
	humanoid.WalkSpeed = valore
end

return Velocita
