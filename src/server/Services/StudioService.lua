-- Comandi chat per provare il gioco più in fretta. Funzionano SOLO in Roblox Studio:
-- nel gioco pubblicato questo servizio non fa nulla.
--
--   /risorse   +50000 Oro, +15000 Essenza, +200 Frammenti
--   /oggetti   8 oggetti casuali nell'inventario
--   /centro    elenca gli oggetti estranei nella zona della Piazza (Output + notifica)
--   /pulisci   rimuove quegli oggetti per la partita in corso
--   /script    elenca gli script del place che non fanno parte del progetto
--   /reset     cancella i progressi (dati di sessione: si salvano all'uscita!)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent.PlayerData)
local InventarioService = require(script.Parent.InventarioService)
local Rarita = require(ReplicatedStorage.Shared.Config.Rarita)

local StudioService = {}

local comandi = {}

function comandi.risorse(player)
	PlayerData.AggiungiValuta(player, "Oro", 50000)
	PlayerData.AggiungiValuta(player, "Essenza", 15000)
	PlayerData.AggiungiValuta(player, "Frammenti", 200)
	return "Test: risorse aggiunte."
end

function comandi.oggetti(player)
	local rng = Random.new()
	for _ = 1, 8 do
		local tabella = rng:NextInteger(1, 2) == 1 and "Nemico" or "Boss"
		local oggetto = InventarioService.Genera(InventarioService.SlotCasuale(), Rarita.Estrai(tabella, rng), "di Prova")
		InventarioService.Aggiungi(player, oggetto)
	end
	return "Test: 8 oggetti aggiunti. Premi X per l'inventario."
end

function comandi.reset(player)
	PlayerData.Modifica(player, "Valute", function(dati)
		dati.Valute.Oro = 50
		dati.Valute.Essenza = 25
		dati.Valute.Frammenti = 0
		dati.Tycoon.Acquisti = {}
		dati.Tycoon.Forziere = 0
		dati.Inventario = {}
		dati.Equipaggiato = {}
		dati.Missione = nil
		dati.UltimaMissione = nil
		dati.Pozioni = {}
		dati.Tutorial = 1
	end)
	return "Test: progressi azzerati. Esci e rientra per ricostruire l'isola."
end

-- Diagnosi: cosa c'è al centro del mondo (dove sta la Piazza) che NON è stato
-- creato dal nostro codice? Elenca il percorso di ogni oggetto trovato, nell'Output
-- e come notifica sullo schermo. Il pavimento base del place (Baseplate) e i punti
-- di spawn sono normali e vengono ignorati.
local CARTELLE_NOSTRE = { "Piazza", "Isole", "Dungeon", "Effetti", "Alleati", "EffettiMovimento" }

local function ignorato(contenitore)
	return contenitore.Name == "Baseplate" or contenitore:IsA("SpawnLocation") or contenitore:IsA("Terrain")
end

-- Restituisce le righe di testo e gli oggetti trovati (per /pulisci).
local function oggettiEstraneiAlCentro()
	local Workspace = game:GetService("Workspace")
	local nostre = {}
	for _, nome in ipairs(CARTELLE_NOSTRE) do
		local cartella = Workspace:FindFirstChild(nome)
		if cartella then
			table.insert(nostre, cartella)
		end
	end
	local parametri = OverlapParams.new()
	parametri.FilterType = Enum.RaycastFilterType.Exclude
	parametri.FilterDescendantsInstances = nostre

	-- Raggruppiamo per "contenitore" diretto nel Workspace, per un elenco corto.
	local trovati, ordine = {}, {}
	local area = Workspace:GetPartBoundsInBox(CFrame.new(0, 30, 0), Vector3.new(190, 80, 190), parametri)
	for _, parte in ipairs(area) do
		local contenitore = parte
		while contenitore.Parent and contenitore.Parent ~= Workspace do
			contenitore = contenitore.Parent
		end
		local isPersonaggio = contenitore:IsA("Model") and Players:GetPlayerFromCharacter(contenitore)
		if not isPersonaggio and not ignorato(contenitore) then
			if not trovati[contenitore] then
				trovati[contenitore] = 0
				table.insert(ordine, contenitore)
			end
			trovati[contenitore] += 1
		end
	end

	local righe = {}
	for _, contenitore in ipairs(ordine) do
		table.insert(righe, string.format("%s (%s, %d parti)", contenitore:GetFullName(), contenitore.ClassName, trovati[contenitore]))
	end
	return righe, ordine
end

-- Stampa nell'Output e, se c'è qualcosa, lo mostra a tutti i giocatori come notifica.
local function stampaDiagnosi()
	local righe = oggettiEstraneiAlCentro()
	if #righe == 0 then
		print("[Regno Arcano] Diagnosi centro: nessun oggetto estraneo nella Piazza.")
		return 0
	end
	warn("[Regno Arcano] Diagnosi centro: oggetti NON creati dal nostro codice nella zona della Piazza:")
	for _, riga in ipairs(righe) do
		warn("   - " .. riga)
	end
	local testo = "Oggetto estraneo nella Piazza: " .. righe[1]
		.. (#righe > 1 and (" (+" .. (#righe - 1) .. " altri, vedi Output)") or "")
	for _, player in ipairs(Players:GetPlayers()) do
		ReplicatedStorage.Remotes.Notifica:FireClient(player, testo)
	end
	return #righe
end

-- Diagnosi: script nel place che NON fanno parte del nostro progetto Rojo
-- (esclusi quelli standard che Roblox aggiunge da solo).
-- Un vecchio script dimenticato può ricreare oggetti del prototipo a ogni avvio.
local SERVIZI_DA_CONTROLLARE = {
	"Workspace", "ServerScriptService", "ServerStorage", "ReplicatedStorage", "ReplicatedFirst",
	"StarterGui", "StarterPack", "StarterPlayer", "Lighting", "SoundService",
}

local function scriptEstranei()
	local starterPlayer = game:GetService("StarterPlayer")
	local candidati = {
		-- I nostri, sincronizzati da Rojo.
		{ game:GetService("ServerScriptService"), "Server" },
		{ game:GetService("ReplicatedStorage"), "Shared" },
		{ starterPlayer.StarterPlayerScripts, "Client" },
		-- Quelli che Roblox inserisce da solo (telecamera, controlli, suoni dei passi).
		{ starterPlayer, "PlayerModule" },
		{ starterPlayer.StarterPlayerScripts, "PlayerModule" },
		{ starterPlayer.StarterPlayerScripts, "RbxCharacterSounds" },
	}
	local nostri = {}
	for _, candidato in ipairs(candidati) do
		local radice = candidato[1]:FindFirstChild(candidato[2])
		if radice then
			table.insert(nostri, radice)
		end
	end

	local function eNostro(oggetto)
		for _, radice in ipairs(nostri) do
			if oggetto == radice or oggetto:IsDescendantOf(radice) then
				return true
			end
		end
		-- Gli script dei personaggi (Animate, Health...) sono di Roblox.
		local modello = oggetto:FindFirstAncestorOfClass("Model")
		return modello ~= nil and Players:GetPlayerFromCharacter(modello) ~= nil
	end

	local trovati = {}
	for _, nomeServizio in ipairs(SERVIZI_DA_CONTROLLARE) do
		pcall(function()
			for _, oggetto in ipairs(game:GetService(nomeServizio):GetDescendants()) do
				if oggetto:IsA("LuaSourceContainer") and not eNostro(oggetto) then
					table.insert(trovati, oggetto:GetFullName() .. " (" .. oggetto.ClassName .. ")")
				end
			end
		end)
	end
	return trovati
end

local function stampaScriptEstranei()
	local trovati = scriptEstranei()
	if #trovati == 0 then
		print("[Regno Arcano] Nessuno script estraneo nel place.")
		return
	end
	warn("[Regno Arcano] Script nel place che NON fanno parte del progetto (controlla ed elimina quelli vecchi):")
	for _, riga in ipairs(trovati) do
		warn("   - " .. riga)
	end
	-- L'elenco completo appare anche in un pannello sullo schermo (il testo si può copiare).
	for _, player in ipairs(Players:GetPlayers()) do
		ReplicatedStorage.Remotes.Diagnosi:FireClient(player,
			#trovati .. " script nel place che NON fanno parte del progetto", trovati)
	end
end

function comandi.script()
	stampaScriptEstranei()
	return "Elenco degli script estranei aperto sullo schermo."
end

function comandi.centro()
	local numero = stampaDiagnosi()
	return numero == 0 and "Nessun oggetto estraneo al centro."
		or (numero .. " oggetti estranei al centro: guarda la finestra Output.")
end

-- Toglie per questa partita gli oggetti estranei trovati al centro.
function comandi.pulisci()
	local righe, oggetti = oggettiEstraneiAlCentro()
	for _, oggetto in ipairs(oggetti) do
		oggetto:Destroy()
	end
	for _, riga in ipairs(righe) do
		warn("[Regno Arcano] /pulisci ha rimosso: " .. riga)
	end
	return #oggetti == 0 and "Niente da pulire al centro."
		or (#oggetti .. " oggetti rimossi per questa partita (elencati nell'Output).")
end

function StudioService.Avvia()
	if not RunService:IsStudio() then
		return
	end
	-- Due controlli: subito dopo l'avvio e più tardi, nel caso qualcosa compaia in ritardo.
	task.delay(5, stampaDiagnosi)
	task.delay(30, stampaDiagnosi)
	task.delay(8, stampaScriptEstranei)
	local function esegui(player, nome)
		local comando = comandi[nome]
		if comando and PlayerData.Pronto(player) then
			ReplicatedStorage.Remotes.Notifica:FireClient(player, comando(player))
		end
	end

	local TextChatService = game:GetService("TextChatService")
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		-- Chat moderna: i comandi vanno registrati come TextChatCommand.
		for nome in pairs(comandi) do
			local comando = Instance.new("TextChatCommand")
			comando.Name = "Test_" .. nome
			comando.PrimaryAlias = "/" .. nome
			comando.Parent = TextChatService
			comando.Triggered:Connect(function(sorgente)
				local player = Players:GetPlayerByUserId(sorgente.UserId)
				if player then
					esegui(player, nome)
				end
			end)
		end
	else
		local function collega(player)
			player.Chatted:Connect(function(messaggio)
				esegui(player, string.lower(messaggio):match("^/(%a+)"))
			end)
		end
		Players.PlayerAdded:Connect(collega)
		for _, player in ipairs(Players:GetPlayers()) do
			collega(player)
		end
	end
	print("[Regno Arcano] Comandi di test attivi: /risorse, /oggetti, /reset, /centro, /pulisci, /script")
end

return StudioService
