-- PlayerData: il profilo di ogni giocatore e il suo salvataggio.
-- È il collante tra i pilastri del gioco: tycoon, dungeon, classi e piazza leggono
-- e modificano i dati SOLO passando da qui, così niente si desincronizza.
--
-- Il client non riceve mai il profilo completo: valute e classe vengono rispecchiate
-- come Attributi del Player (replicati in automatico) e in leaderstats.
--
-- Protezioni dei salvataggi:
--   - blocco di sessione: un solo server alla volta può usare i dati di un giocatore
--   - salvataggi ravvicinati raggruppati (limiti di scrittura di Roblox)
--   - se la lettura fallisce si gioca senza salvare, per non sovrascrivere dati buoni

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = ReplicatedStorage.Shared.Config
local Classi = require(Config.Classi)
local Valute = require(Config.Valute)

local NOME_STORE = "RegnoArcano_Giocatori_v3"
local NOME_STORE_VECCHIO = "TycoonArcano_PlayerData_v2"
local VERSIONE_SCHEMA = 3
local INTERVALLO_AUTOSALVATAGGIO = 60
local TENTATIVI = 3
local ATTESA_TRA_SALVATAGGI = 8 -- secondi minimi tra due salvataggi dello stesso giocatore
local SCADENZA_BLOCCO = 180 -- un blocco più vecchio di così è di un server caduto
local TENTATIVI_BLOCCO = 6
local ATTESA_BLOCCO = 5
-- Identifica questo server; in Studio JobId è vuoto, quindi ne inventiamo uno.
local ID_SERVER = game.JobId ~= "" and game.JobId or ("studio_" .. HttpService:GenerateGUID(false))
local IN_STUDIO = game:GetService("RunService"):IsStudio()

local PlayerData = {}

local profili = {} -- [Player] = { dati = table, puoSalvare = bool, uscito = bool }
local salvataggioInCorso = {} -- [Player] = true
local ultimoSalvataggio = {} -- [Player] = os.clock()
local salvataggioProgrammato = {} -- [Player] = true

local eventoCaricato = Instance.new("BindableEvent")
local eventoCambiato = Instance.new("BindableEvent")

-- Scatta quando il profilo di un giocatore è pronto: (player, dati)
PlayerData.Caricato = eventoCaricato.Event
-- Scatta dopo ogni modifica: (player, sezione) dove sezione è "Valute", "Classe", ecc.
PlayerData.Cambiato = eventoCambiato.Event

local store, storeVecchio
local storeDisponibile = pcall(function()
	store = DataStoreService:GetDataStore(NOME_STORE)
	storeVecchio = DataStoreService:GetDataStore(NOME_STORE_VECCHIO)
end)
if not storeDisponibile then
	warn("[PlayerData] DataStore non disponibile: i progressi di questa sessione non verranno salvati.")
end

local function chiave(player)
	return "giocatore_" .. player.UserId
end

local function datiPredefiniti()
	local valute = {}
	for _, nome in ipairs(Valute.Ordine) do
		valute[nome] = Valute.Dati[nome].iniziale
	end
	return {
		Versione = VERSIONE_SCHEMA,
		Valute = valute,
		Classe = Classi.Predefinita,
		Tycoon = {
			Acquisti = {}, -- [idAcquisto] = true
			Forziere = 0, -- Oro raccolto dal nastro ma non ancora incassato
		},
		Inventario = {}, -- lista di oggetti { id, tipo, rarita, ... }
		Equipaggiato = {}, -- [slot] = id dell'oggetto nell'Inventario
		Missione = nil, -- { id, progresso } della missione in corso (MissioniService)
		UltimaMissione = nil, -- nome dell'ultima completata, per non riproporla subito
		Pozioni = {}, -- [idPozione] = quantità (PozioniService)
		Tutorial = 1, -- passo attuale della guida (TutorialService)
	}
end

-- Ripara dati salvati incompleti o vecchi riempiendo i campi mancanti.
local function riconcilia(salvati)
	local dati = datiPredefiniti()
	if type(salvati) ~= "table" then
		return dati
	end
	if type(salvati.Valute) == "table" then
		for _, nome in ipairs(Valute.Ordine) do
			local valore = tonumber(salvati.Valute[nome])
			if valore and valore >= 0 then
				dati.Valute[nome] = math.floor(valore)
			end
		end
	end
	if Classi.Esiste(salvati.Classe) then
		dati.Classe = salvati.Classe
	end
	if type(salvati.Tycoon) == "table" then
		if type(salvati.Tycoon.Acquisti) == "table" then
			dati.Tycoon.Acquisti = salvati.Tycoon.Acquisti
		end
		local forziere = tonumber(salvati.Tycoon.Forziere)
		if forziere and forziere >= 0 then
			dati.Tycoon.Forziere = math.floor(forziere)
		end
	end
	if type(salvati.Inventario) == "table" then
		dati.Inventario = salvati.Inventario
	end
	if type(salvati.Equipaggiato) == "table" then
		dati.Equipaggiato = salvati.Equipaggiato
	end
	local missione = salvati.Missione
	if type(missione) == "table" and type(missione.id) == "string" and tonumber(missione.progresso) then
		dati.Missione = { id = missione.id, progresso = math.max(0, math.floor(tonumber(missione.progresso))) }
	end
	if type(salvati.UltimaMissione) == "string" then
		dati.UltimaMissione = salvati.UltimaMissione
	end
	local tutorial = tonumber(salvati.Tutorial)
	if tutorial and tutorial >= 1 then
		dati.Tutorial = math.floor(tutorial)
	end
	if type(salvati.Pozioni) == "table" then
		for id, numero in pairs(salvati.Pozioni) do
			if type(id) == "string" and tonumber(numero) and tonumber(numero) > 0 then
				dati.Pozioni[id] = math.floor(tonumber(numero))
			end
		end
	end
	return dati
end

-- Converte un salvataggio del vecchio prototipo (v2) nel formato nuovo.
-- Arma e Potenza non vengono importate: il nuovo equipaggiamento è un inventario vero.
local function daVecchioFormato(vecchi)
	local dati = datiPredefiniti()
	for _, nome in ipairs(Valute.Ordine) do
		local valore = tonumber(vecchi[nome])
		if valore and valore >= 0 then
			dati.Valute[nome] = math.floor(valore)
		end
	end
	if Classi.Esiste(vecchi.Classe) then
		dati.Classe = vecchi.Classe
	end
	if type(vecchi.Upgrades) == "table" then
		for id, posseduto in pairs(vecchi.Upgrades) do
			if posseduto == true then
				dati.Tycoon.Acquisti[id] = true
			end
		end
	end
	return dati
end

local function conTentativi(descrizione, funzione)
	local ultimoErrore
	for tentativo = 1, TENTATIVI do
		local ok, risultato = pcall(funzione)
		if ok then
			return true, risultato
		end
		ultimoErrore = risultato
		if tentativo < TENTATIVI then
			task.wait(tentativo)
		end
	end
	warn("[PlayerData] " .. descrizione .. " fallito: " .. tostring(ultimoErrore))
	return false, ultimoErrore
end

-- Copia valute e classe dove il client può vederle.
local function rispecchia(player)
	local profilo = profili[player]
	if not profilo then
		return
	end
	local dati = profilo.dati
	for _, nome in ipairs(Valute.Ordine) do
		player:SetAttribute(nome, dati.Valute[nome])
	end
	player:SetAttribute("Classe", dati.Classe)

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Oro.Value = dati.Valute.Oro
		leaderstats.Classe.Value = dati.Classe
	end
end

local function creaLeaderstats(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local oro = Instance.new("IntValue")
	oro.Name = "Oro"
	oro.Parent = leaderstats

	local classe = Instance.new("StringValue")
	classe.Name = "Classe"
	classe.Parent = leaderstats

	leaderstats.Parent = player
end

local function notificaCambio(player, sezione)
	rispecchia(player)
	eventoCambiato:Fire(player, sezione)
end

-- Blocco di sessione ------------------------------------------------------------
-- Ogni salvataggio contiene `Blocco = { Server, Ora }`: il server che sta usando quei dati.
-- Se un giocatore cambia server in fretta, il nuovo server aspetta che il vecchio
-- abbia salvato e liberato i dati, invece di leggerne una copia vecchia.
-- Un blocco non aggiornato da più di SCADENZA_BLOCCO secondi (server caduto) viene ignorato.

local function bloccoAltrui(salvati)
	local blocco = type(salvati) == "table" and salvati.Blocco
	if type(blocco) ~= "table" or blocco.Server == ID_SERVER then
		return false
	end
	-- In Studio ogni Play è un "server" nuovo: ignoriamo i blocchi lasciati dai test
	-- precedenti, altrimenti dopo uno stop improvviso bisognerebbe aspettare.
	if IN_STUDIO and type(blocco.Server) == "string" and blocco.Server:sub(1, 7) == "studio_" then
		return false
	end
	return os.time() - (tonumber(blocco.Ora) or 0) < SCADENZA_BLOCCO
end

-- Prova a prendere il blocco. Restituisce: esito ("ok" | "bloccato" | "errore"), dati letti
local function prendiBlocco(player)
	local esito, letti = "errore", nil
	local ok = conTentativi("Caricamento di " .. player.Name, function()
		store:UpdateAsync(chiave(player), function(salvati)
			if bloccoAltrui(salvati) then
				esito = "bloccato"
				return nil -- nil = non scrivere nulla
			end
			esito, letti = "ok", salvati
			local nuovi = type(salvati) == "table" and salvati or { Versione = VERSIONE_SCHEMA, Nuovo = true }
			nuovi.Blocco = { Server = ID_SERVER, Ora = os.time() }
			return nuovi
		end)
	end)
	return ok and esito or "errore", letti
end

local function rilasciaBlocco(player)
	pcall(function()
		store:UpdateAsync(chiave(player), function(salvati)
			if type(salvati) ~= "table" or bloccoAltrui(salvati) then
				return nil
			end
			salvati.Blocco = nil
			return salvati
		end)
	end)
end

local function carica(player)
	local dati, puoSalvare = nil, false

	if storeDisponibile then
		local esito, salvati
		for tentativo = 1, TENTATIVI_BLOCCO do
			esito, salvati = prendiBlocco(player)
			if esito ~= "bloccato" or not player.Parent then
				break
			end
			-- Un altro server sta ancora salvando questo giocatore: aspettiamo.
			if tentativo < TENTATIVI_BLOCCO then
				task.wait(ATTESA_BLOCCO)
			end
		end
		if esito == "bloccato" then
			player:Kick("I tuoi progressi sono ancora in uso in un altro server. Riprova tra un paio di minuti.")
			return
		end

		if esito == "ok" and type(salvati) == "table" and not salvati.Nuovo then
			dati, puoSalvare = riconcilia(salvati), true
		elseif esito == "ok" then
			-- Nessun salvataggio nuovo: proviamo a recuperare quello del vecchio prototipo.
			local okVecchio, vecchi = conTentativi("Migrazione di " .. player.Name, function()
				return storeVecchio:GetAsync("player_" .. player.UserId)
			end)
			if okVecchio then
				dati = type(vecchi) == "table" and daVecchioFormato(vecchi) or datiPredefiniti()
				puoSalvare = true
			end
		end
		-- Se la lettura è fallita, si gioca con dati temporanei ma NON si salva:
		-- così non sovrascriviamo un salvataggio che esiste ma non siamo riusciti a leggere.
	end

	if not player.Parent then
		if puoSalvare then
			rilasciaBlocco(player)
		end
		return
	end
	if not dati then
		dati = datiPredefiniti()
		if storeDisponibile then
			warn("[PlayerData] " .. player.Name .. " gioca con dati temporanei (non verranno salvati).")
		end
	end

	profili[player] = { dati = dati, puoSalvare = puoSalvare }
	rispecchia(player)
	player:SetAttribute("DatiPronti", true)
	eventoCaricato:Fire(player, dati)
end

-- Salvataggio vero e proprio. rilascia = true all'uscita: libera il blocco.
local function salvaOra(player, rilascia)
	local profilo = profili[player]
	if not profilo or not profilo.puoSalvare or (profilo.uscito and not rilascia) then
		return false
	end
	while salvataggioInCorso[player] do
		task.wait(0.1)
	end
	salvataggioInCorso[player] = true
	ultimoSalvataggio[player] = os.clock()
	local copia = table.clone(profilo.dati)
	copia.Versione = VERSIONE_SCHEMA
	copia.Blocco = not rilascia and { Server = ID_SERVER, Ora = os.time() } or nil
	local perso = false
	local ok = conTentativi("Salvataggio di " .. player.Name, function()
		store:UpdateAsync(chiave(player), function(salvati)
			if bloccoAltrui(salvati) then
				perso = true -- un altro server ha preso i dati: non sovrascriviamo
				return nil
			end
			return copia
		end)
	end)
	salvataggioInCorso[player] = nil
	if perso then
		profilo.puoSalvare = false
		warn("[PlayerData] Blocco perso per " .. player.Name .. ": salvataggi sospesi.")
		if player.Parent and not rilascia then
			player:Kick("I tuoi progressi sono stati aperti in un altro server. Rientra per continuare.")
		end
	end
	return ok and not perso
end

-- Richiesta di salvataggio "appena possibile": i salvataggi ravvicinati (per esempio
-- tanti acquisti di fila) vengono raggruppati, per restare nei limiti di Roblox.
function PlayerData.Salva(player)
	if salvataggioProgrammato[player] then
		return true
	end
	local attesa = ATTESA_TRA_SALVATAGGI - (os.clock() - (ultimoSalvataggio[player] or -math.huge))
	if attesa > 0 then
		salvataggioProgrammato[player] = true
		task.delay(attesa, function()
			salvataggioProgrammato[player] = nil
			salvaOra(player)
		end)
		return true
	end
	return salvaOra(player)
end

-- Restituisce il profilo (solo lettura!) oppure nil se non è ancora caricato.
-- Per modificare i dati usare le funzioni qui sotto o PlayerData.Modifica.
function PlayerData.Ottieni(player)
	local profilo = profili[player]
	return profilo and profilo.dati
end

function PlayerData.Pronto(player)
	return profili[player] ~= nil
end

function PlayerData.Valuta(player, nome)
	local dati = PlayerData.Ottieni(player)
	return dati and dati.Valute[nome] or 0
end

function PlayerData.AggiungiValuta(player, nome, quantita)
	local dati = PlayerData.Ottieni(player)
	if not dati or not Valute.Esiste(nome) then
		return false
	end
	dati.Valute[nome] = math.max(0, dati.Valute[nome] + math.floor(quantita))
	notificaCambio(player, "Valute")
	return true
end

-- costi: { Oro = 100, Essenza = 20 }
function PlayerData.PuoPermettersi(player, costi)
	local dati = PlayerData.Ottieni(player)
	if not dati then
		return false
	end
	for nome, quantita in pairs(costi) do
		if (dati.Valute[nome] or 0) < quantita then
			return false
		end
	end
	return true
end

-- Toglie tutte le valute insieme, oppure nessuna se non bastano.
function PlayerData.Spendi(player, costi)
	if not PlayerData.PuoPermettersi(player, costi) then
		return false
	end
	local dati = PlayerData.Ottieni(player)
	for nome, quantita in pairs(costi) do
		dati.Valute[nome] -= quantita
	end
	notificaCambio(player, "Valute")
	return true
end

function PlayerData.ImpostaClasse(player, classe)
	local dati = PlayerData.Ottieni(player)
	if not dati or not Classi.Esiste(classe) or dati.Classe == classe then
		return false
	end
	dati.Classe = classe
	notificaCambio(player, "Classe")
	return true
end

-- Modifica generica per sezioni più complesse (Tycoon, Inventario...).
-- Esempio: PlayerData.Modifica(player, "Tycoon", function(dati) dati.Tycoon.Acquisti.Forgia = true end)
function PlayerData.Modifica(player, sezione, funzione)
	local dati = PlayerData.Ottieni(player)
	if not dati then
		return false
	end
	funzione(dati)
	notificaCambio(player, sezione)
	return true
end

local function alUscita(player)
	local profilo = profili[player]
	if profilo then
		profilo.uscito = true -- da qui in poi solo il salvataggio finale
		salvaOra(player, true)
	end
	profili[player] = nil
	ultimoSalvataggio[player] = nil
	salvataggioProgrammato[player] = nil
end

local function preparaGiocatore(player)
	if player:FindFirstChild("leaderstats") then
		return
	end
	creaLeaderstats(player)
	carica(player)
end

function PlayerData.Avvia()
	Players.PlayerAdded:Connect(preparaGiocatore)
	Players.PlayerRemoving:Connect(alUscita)
	-- In Studio il giocatore può entrare prima che questo script parta.
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(preparaGiocatore, player)
	end

	task.spawn(function()
		while true do
			task.wait(INTERVALLO_AUTOSALVATAGGIO)
			-- L'autosalvataggio rinnova anche il blocco di sessione.
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(salvaOra, player)
			end
		end
	end)

	game:BindToClose(function()
		local rimanenti = 0
		for _, player in ipairs(Players:GetPlayers()) do
			rimanenti += 1
			task.spawn(function()
				local profilo = profili[player]
				if profilo then
					profilo.uscito = true
				end
				salvaOra(player, true)
				rimanenti -= 1
			end)
		end
		local inizio = os.clock()
		while rimanenti > 0 and os.clock() - inizio < 25 do
			task.wait(0.1)
		end
	end)
end

return PlayerData
