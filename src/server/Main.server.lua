-- Avvio del server del Regno Arcano.
-- Ogni pilastro del gioco è un servizio in Services/: qui li avviamo in ordine.
-- PlayerData va sempre per primo, perché tutti gli altri dipendono dai dati.

local Services = script.Parent.Services

-- Resti del vecchio prototipo: si sovrappongono alla Piazza e alle isole (la
-- SalaArcanista sta proprio al centro del mondo) o creano dati doppi.
-- Li togliamo a ogni avvio, ma vanno eliminati anche da Studio per sparire davvero.
local residui = {
	{ game:GetService("Workspace"), "TycoonWorld" },
	{ game:GetService("Workspace"), "SalaArcanista" },
	{ game:GetService("ServerScriptService"), "TycoonCore" },
	{ game:GetService("StarterPlayer").StarterPlayerScripts, "TycoonHUD" },
}
local trovati = {}
for _, residuo in ipairs(residui) do
	local trovato = residuo[1]:FindFirstChild(residuo[2])
	if trovato then
		table.insert(trovati, trovato:GetFullName())
		trovato:Destroy()
	end
end
if #trovati > 0 then
	warn("[Regno Arcano] Rimossi per questa partita i resti del vecchio prototipo. "
		.. "Eliminali anche da Studio (fuori dal Play): " .. table.concat(trovati, ", "))
else
	print("[Regno Arcano] Nessun resto del vecchio prototipo: tutto pulito.")
end

local ordine = {
	"PlayerData",
	"InventarioService",
	"TycoonService",
	"ClassService",
	"CombatService",
	"AbilitaService",
	"PozioniService",
	"DungeonService",
	"MissioniService",
	"TutorialService",
	"PiazzaService",
	"ScambiService",
	"StudioService", -- comandi di test, solo in Studio
}

for _, nome in ipairs(ordine) do
	local servizio = require(Services[nome])
	servizio.Avvia()
end

print("[Regno Arcano] Server avviato.")
