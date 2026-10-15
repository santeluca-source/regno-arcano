-- Comandi chat per provare il gioco più in fretta. Funzionano SOLO in Roblox Studio:
-- nel gioco pubblicato questo servizio non fa nulla.
--
--   /risorse   +50000 Oro, +15000 Essenza, +200 Frammenti
--   /oggetti   8 oggetti casuali nell'inventario
--   /centro    elenca nell'Output gli oggetti estranei nella zona della Piazza
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
	return "Test: 8 oggetti aggiunti. Premi I per l'inventario."
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
-- creato dal nostro codice? Stampa nell'Output il percorso di ogni oggetto trovato.
local CARTELLE_NOSTRE = { "Piazza", "Isole", "Dungeon", "Effetti", "Alleati" }

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
		if not isPersonaggio and not parte:IsA("Terrain") then
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
	return righe
end

local function stampaDiagnosi()
	local righe = oggettiEstraneiAlCentro()
	if #righe == 0 then
		print("[Regno Arcano] Diagnosi centro: nessun oggetto estraneo nella Piazza.")
	else
		warn("[Regno Arcano] Diagnosi centro: oggetti NON creati dal nostro codice nella zona della Piazza:")
		for _, riga in ipairs(righe) do
			warn("   - " .. riga)
		end
	end
	return #righe
end

function comandi.centro()
	local numero = stampaDiagnosi()
	return numero == 0 and "Nessun oggetto estraneo al centro."
		or (numero .. " oggetti estranei al centro: guarda la finestra Output.")
end

function StudioService.Avvia()
	if not RunService:IsStudio() then
		return
	end
	task.delay(5, stampaDiagnosi)
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
	print("[Regno Arcano] Comandi di test attivi: /risorse, /oggetti, /reset, /centro")
end

return StudioService
