-- MissioniService: incarichi presi alla Bacheca della Piazza.
-- Un giocatore ha al massimo una missione alla volta, salvata in PlayerData.Missione:
--   { id = "Cacciatore", progresso = 7 }
-- Il progresso arriva dagli eventi degli altri servizi (nemici sconfitti, dungeon
-- completati, oro incassato): così le missioni legano tra loro i pilastri del gioco.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local ConfigPiazza = require(Config.Piazza)
local Tycoon = require(Config.Tycoon)
local PlayerData = require(script.Parent.PlayerData)
local CombatService = require(script.Parent.CombatService)
local DungeonService = require(script.Parent.DungeonService)
local TycoonService = require(script.Parent.TycoonService)

local Remotes = ReplicatedStorage.Remotes

local MissioniService = {}

local idMissioni = {}
for id in pairs(ConfigPiazza.Missioni) do
	table.insert(idMissioni, id)
end
table.sort(idMissioni)

local rng = Random.new()

local function missioneDi(player)
	local dati = PlayerData.Ottieni(player)
	local missione = dati and dati.Missione
	if missione and ConfigPiazza.Missioni[missione.id] then
		return missione, ConfigPiazza.Missioni[missione.id]
	end
	return nil
end

-- Testo per l'HUD.
local function rispecchia(player)
	local missione, def = missioneDi(player)
	if not missione then
		player:SetAttribute("Missione", "Nessuna: visita la Bacheca nella Piazza")
	elseif missione.progresso >= def.obiettivo then
		player:SetAttribute("Missione", def.nome .. ": completata! Torna alla Bacheca")
	else
		player:SetAttribute("Missione", def.nome .. ": " .. def.descrizione .. " (" .. missione.progresso .. "/" .. def.obiettivo .. ")")
	end
end

local function avanza(player, tipo, quantita, filtro)
	local missione, def = missioneDi(player)
	if not missione or def.tipo ~= tipo or missione.progresso >= def.obiettivo then
		return
	end
	-- Missioni con un bersaglio preciso: un tipo di nemico o un dungeon.
	local richiesto = def.nemico or def.dungeon
	if richiesto and richiesto ~= filtro then
		return
	end
	PlayerData.Modifica(player, "Missione", function(dati)
		dati.Missione.progresso = math.min(def.obiettivo, dati.Missione.progresso + quantita)
	end)
	rispecchia(player)
	if missione.progresso >= def.obiettivo then
		Remotes.Notifica:FireClient(player, "Missione " .. def.nome .. " completata! Torna alla Bacheca.")
	end
end

-- Chiamata da PiazzaService quando un giocatore usa la Bacheca.
function MissioniService.Bacheca(player)
	if not PlayerData.Pronto(player) then
		return
	end
	local missione, def = missioneDi(player)

	if missione and missione.progresso >= def.obiettivo then
		for valuta, quantita in pairs(def.ricompensa) do
			PlayerData.AggiungiValuta(player, valuta, quantita)
		end
		PlayerData.Modifica(player, "Missione", function(dati)
			dati.Missione = nil
			dati.UltimaMissione = def.nome
		end)
		rispecchia(player)
		Remotes.Notifica:FireClient(player, "Ricompensa: " .. Tycoon.TestoCosto(def.ricompensa) .. "!")
		task.spawn(PlayerData.Salva, player)
		return
	end

	if missione then
		Remotes.Notifica:FireClient(player, def.descrizione .. " (" .. missione.progresso .. "/" .. def.obiettivo .. ")")
		return
	end

	-- Nuova missione tra quelle possibili, se si può diversa dall'ultima completata.
	local dati = PlayerData.Ottieni(player)
	local possibili = {}
	for _, id in ipairs(idMissioni) do
		local requisito = ConfigPiazza.Missioni[id].richiede
		if not requisito or dati.Tycoon.Acquisti[requisito] then
			table.insert(possibili, id)
		end
	end
	local scelte = {}
	for _, id in ipairs(possibili) do
		if ConfigPiazza.Missioni[id].nome ~= dati.UltimaMissione then
			table.insert(scelte, id)
		end
	end
	if #scelte == 0 then
		scelte = possibili
	end
	local id = scelte[rng:NextInteger(1, #scelte)]
	PlayerData.Modifica(player, "Missione", function(d)
		d.Missione = { id = id, progresso = 0 }
	end)
	rispecchia(player)
	Remotes.Notifica:FireClient(player, "Nuova missione: " .. ConfigPiazza.Missioni[id].descrizione)
end

function MissioniService.Avvia()
	CombatService.Sconfitto:Connect(function(nemico, uccisore)
		if uccisore and not nemico:GetAttribute("Manichino") then
			avanza(uccisore, "Nemici", 1)
			avanza(uccisore, "NemicoTipo", 1, nemico:GetAttribute("Tipo"))
		end
	end)
	DungeonService.Completato:Connect(function(giocatori, idDungeon)
		for _, player in ipairs(giocatori) do
			avanza(player, "Dungeon", 1, idDungeon)
		end
	end)
	TycoonService.Incassato:Connect(function(player, quantita)
		avanza(player, "Incasso", quantita)
	end)

	PlayerData.Caricato:Connect(rispecchia)
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerData.Pronto(player) then
			rispecchia(player)
		end
	end
end

return MissioniService
