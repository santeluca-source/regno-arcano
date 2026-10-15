-- ScambiService: scambi di oggetti e Oro tra due giocatori nella Piazza.
--
-- Svolgimento:
--   1. A tiene premuto "Proponi scambio" su B (solo nella Piazza)
--   2. B accetta la proposta -> si apre una sessione di scambio per entrambi
--   3. ognuno aggiunge/toglie oggetti e Oro alla propria offerta
--   4. lo scambio avviene quando ENTRAMBI accettano la stessa versione dell'offerta
--
-- Protezioni contro le truffe:
--   - ogni modifica crea una nuova "versione" e annulla le accettazioni
--   - "Accetta" vale solo per la versione che il giocatore ha visto
--   - prima di scambiare il server ricontrolla oggetti, Oro e spazio nell'inventario
--   - gli oggetti vengono spostati tutti insieme, senza pause in mezzo

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local ConfigPiazza = require(Config.Piazza)
local Equipaggiamento = require(Config.Equipaggiamento)
local PlayerData = require(script.Parent.PlayerData)
local DungeonService = require(script.Parent.DungeonService)
local Isole = require(script.Parent.Parent.Tycoon.Isole)

local Remotes = ReplicatedStorage.Remotes
local Regole = ConfigPiazza.Scambi

local ScambiService = {}

local richieste = {} -- [destinatario] = { da = Player, scadenza = os.clock() }
local ultimaRichiesta = {} -- [Player] = os.clock()
local sessioni = {} -- [Player] = sessione (la stessa tabella per entrambi)

local function notifica(player, testo)
	Remotes.Notifica:FireClient(player, testo)
end

local function nellaPiazza(player)
	local character = player.Character
	local radice = character and character:FindFirstChild("HumanoidRootPart")
	if not radice or DungeonService.InDungeon(player) then
		return false
	end
	local orizzontale = radice.Position * Vector3.new(1, 0, 1)
	return orizzontale.Magnitude <= ConfigPiazza.Raggio + 5 and math.abs(radice.Position.Y - Isole.Altezza) < 30
end

local function trova(dati, id)
	for indice, oggetto in ipairs(dati.Inventario) do
		if oggetto.id == id then
			return oggetto, indice
		end
	end
	return nil
end

local function altroDi(sessione, player)
	return sessione.a == player and sessione.b or sessione.a
end

-- Invio dello stato ------------------------------------------------------------

local function descriviOfferta(player, offerta)
	local dati = PlayerData.Ottieni(player)
	local oggetti = {}
	for _, id in ipairs(offerta.oggetti) do
		local oggetto = dati and trova(dati, id)
		if oggetto then
			table.insert(oggetti, oggetto)
		end
	end
	return { oggetti = oggetti, oro = offerta.oro }
end

local function inviaStato(sessione)
	for _, player in ipairs({ sessione.a, sessione.b }) do
		local altro = altroDi(sessione, player)
		local mia = descriviOfferta(player, sessione.offerte[player])
		local sua = descriviOfferta(altro, sessione.offerte[altro])
		sua.nome = altro.DisplayName
		Remotes.ScambioEvento:FireClient(player, "Stato", {
			versione = sessione.versione,
			io = mia,
			altro = sua,
			accettato = { io = sessione.accettato[player] == true, altro = sessione.accettato[altro] == true },
			massimoOggetti = Regole.massimoOggetti,
		})
	end
end

-- Ogni modifica: nuova versione, accettazioni annullate.
local function modificata(sessione)
	sessione.versione += 1
	sessione.accettato = {}
	inviaStato(sessione)
end

local function chiudi(sessione, motivo)
	for _, player in ipairs({ sessione.a, sessione.b }) do
		if sessioni[player] == sessione then
			sessioni[player] = nil
			if player.Parent then
				Remotes.ScambioEvento:FireClient(player, "Chiuso", motivo)
				notifica(player, motivo)
			end
		end
	end
end

-- Controlli e scambio ----------------------------------------------------------

-- Restituisce nil se tutto è valido, altrimenti il motivo del problema.
local function problema(sessione)
	for _, player in ipairs({ sessione.a, sessione.b }) do
		local dati = PlayerData.Ottieni(player)
		if not dati then
			return "dati non disponibili"
		end
		local offerta = sessione.offerte[player]
		for _, id in ipairs(offerta.oggetti) do
			local oggetto = trova(dati, id)
			if not oggetto then
				return player.DisplayName .. " non ha più un oggetto offerto"
			end
			if dati.Equipaggiato[oggetto.slot] == id then
				return player.DisplayName .. " sta indossando un oggetto offerto"
			end
		end
		if dati.Valute.Oro < offerta.oro then
			return player.DisplayName .. " non ha abbastanza Oro"
		end
		-- Spazio: inventario attuale - quello che dà + quello che riceve.
		local altro = altroDi(sessione, player)
		local dopo = #dati.Inventario - #offerta.oggetti + #sessione.offerte[altro].oggetti
		if dopo > Equipaggiamento.Capienza then
			return "l'inventario di " .. player.DisplayName .. " sarebbe troppo pieno"
		end
	end
	return nil
end

local function estrai(dati, ids)
	local presi = {}
	for _, id in ipairs(ids) do
		local oggetto, indice = trova(dati, id)
		table.remove(dati.Inventario, indice)
		table.insert(presi, oggetto)
	end
	return presi
end

local function esegui(sessione)
	local motivo = problema(sessione)
	if motivo then
		chiudi(sessione, "Scambio annullato: " .. motivo .. ".")
		return
	end
	local a, b = sessione.a, sessione.b
	local offertaA, offertaB = sessione.offerte[a], sessione.offerte[b]
	sessione.inEsecuzione = true

	-- Tutto in sequenza, senza attese: nessun altro codice può intromettersi a metà.
	local daA, daB
	PlayerData.Modifica(a, "Inventario", function(dati)
		daA = estrai(dati, offertaA.oggetti)
	end)
	PlayerData.Modifica(b, "Inventario", function(dati)
		daB = estrai(dati, offertaB.oggetti)
	end)
	PlayerData.Modifica(a, "Inventario", function(dati)
		for _, oggetto in ipairs(daB) do
			table.insert(dati.Inventario, oggetto)
		end
	end)
	PlayerData.Modifica(b, "Inventario", function(dati)
		for _, oggetto in ipairs(daA) do
			table.insert(dati.Inventario, oggetto)
		end
	end)
	if offertaA.oro > 0 then
		PlayerData.Spendi(a, { Oro = offertaA.oro })
		PlayerData.AggiungiValuta(b, "Oro", offertaA.oro)
	end
	if offertaB.oro > 0 then
		PlayerData.Spendi(b, { Oro = offertaB.oro })
		PlayerData.AggiungiValuta(a, "Oro", offertaB.oro)
	end

	print(string.format("[Scambi] %s -> %s: %d oggetti + %d Oro | %s -> %s: %d oggetti + %d Oro",
		a.Name, b.Name, #daA, offertaA.oro, b.Name, a.Name, #daB, offertaB.oro))
	chiudi(sessione, "Scambio completato!")
	task.spawn(PlayerData.Salva, a)
	task.spawn(PlayerData.Salva, b)
end

-- Proposte -----------------------------------------------------------------------

local function apriSessione(a, b)
	local sessione = {
		a = a,
		b = b,
		offerte = { [a] = { oggetti = {}, oro = 0 }, [b] = { oggetti = {}, oro = 0 } },
		accettato = {},
		versione = 1,
	}
	sessioni[a] = sessione
	sessioni[b] = sessione
	inviaStato(sessione)
end

local function proponi(da, a)
	if da == a or not PlayerData.Pronto(da) or not PlayerData.Pronto(a) then
		return
	end
	local ora = os.clock()
	if ora - (ultimaRichiesta[da] or -math.huge) < Regole.attesaTraRichieste then
		return
	end
	ultimaRichiesta[da] = ora
	if not nellaPiazza(da) or not nellaPiazza(a) then
		notifica(da, "Gli scambi si fanno nella Piazza.")
		return
	end
	if sessioni[da] or sessioni[a] then
		notifica(da, a.DisplayName .. " sta già scambiando.")
		return
	end
	local esistente = richieste[a]
	if esistente and esistente.scadenza > ora then
		notifica(da, a.DisplayName .. " sta già valutando un'altra proposta.")
		return
	end
	richieste[a] = { da = da, scadenza = ora + Regole.scadenzaRichiesta }
	Remotes.ScambioEvento:FireClient(a, "Richiesta", { nome = da.DisplayName, scadenza = Regole.scadenzaRichiesta })
	notifica(da, "Proposta di scambio inviata a " .. a.DisplayName .. ".")
end

local function rispondi(player, accetta)
	local richiesta = richieste[player]
	richieste[player] = nil
	if not richiesta or richiesta.scadenza < os.clock() or not richiesta.da.Parent then
		return
	end
	local da = richiesta.da
	if not accetta then
		notifica(da, player.DisplayName .. " ha rifiutato lo scambio.")
		return
	end
	if sessioni[da] or sessioni[player] or not nellaPiazza(da) or not nellaPiazza(player) then
		notifica(player, "Lo scambio non è più possibile.")
		return
	end
	apriSessione(da, player)
end

-- Azioni dentro la sessione ----------------------------------------------------------

local azioni = {}

function azioni.Aggiungi(player, sessione, id)
	if type(id) ~= "string" then
		return
	end
	local offerta = sessione.offerte[player]
	if #offerta.oggetti >= Regole.massimoOggetti or table.find(offerta.oggetti, id) then
		return
	end
	local dati = PlayerData.Ottieni(player)
	local oggetto = dati and trova(dati, id)
	if not oggetto then
		return
	end
	if dati.Equipaggiato[oggetto.slot] == id then
		notifica(player, "Togliti l'oggetto prima di scambiarlo.")
		return
	end
	table.insert(offerta.oggetti, id)
	modificata(sessione)
end

function azioni.Togli(player, sessione, id)
	local offerta = sessione.offerte[player]
	local indice = type(id) == "string" and table.find(offerta.oggetti, id)
	if indice then
		table.remove(offerta.oggetti, indice)
		modificata(sessione)
	end
end

function azioni.Oro(player, sessione, quantita)
	if type(quantita) ~= "number" or quantita ~= quantita then
		return
	end
	quantita = math.clamp(math.floor(quantita), 0, PlayerData.Valuta(player, "Oro"))
	if quantita ~= sessione.offerte[player].oro then
		sessione.offerte[player].oro = quantita
		modificata(sessione)
	end
end

function azioni.Accetta(player, sessione, versione)
	-- Si accetta solo l'offerta che si è vista: se nel frattempo è cambiata, non vale.
	if versione ~= sessione.versione then
		return
	end
	sessione.accettato[player] = true
	if sessione.accettato[sessione.a] and sessione.accettato[sessione.b] then
		esegui(sessione)
	else
		inviaStato(sessione)
	end
end

function azioni.Annulla(player, sessione)
	chiudi(sessione, player.DisplayName .. " ha annullato lo scambio.")
end

local function suAzione(player, nome, valore)
	if type(nome) ~= "string" then
		return
	end
	if nome == "Rispondi" then
		rispondi(player, valore == true)
		return
	end
	local sessione = sessioni[player]
	if sessione and azioni[nome] then
		azioni[nome](player, sessione, valore)
	end
end

-- Prompt "Proponi scambio" sopra ogni personaggio.
local function aggiungiPrompt(player, character)
	local radice = character:WaitForChild("HumanoidRootPart", 5)
	if not radice then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PromptScambio"
	prompt.ActionText = "Proponi scambio"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.T
	-- Il client lo nasconde (solo per sé) fuori dalla Piazza e sul proprio personaggio;
	-- il server comunque ricontrolla tutto in `proponi`.
	prompt.Parent = radice
	prompt.Triggered:Connect(function(chi)
		proponi(chi, player)
	end)
end

function ScambiService.Avvia()
	Remotes.AzioneScambio.OnServerEvent:Connect(suAzione)

	-- Se l'inventario cambia durante uno scambio (vendita, Fabbro, oggetto indossato...),
	-- togliamo dall'offerta ciò che non è più valido e annulliamo le accettazioni.
	PlayerData.Cambiato:Connect(function(player, sezione)
		local sessione = sessioni[player]
		if sezione ~= "Inventario" or not sessione or sessione.inEsecuzione then
			return
		end
		local dati = PlayerData.Ottieni(player)
		local offerta = sessione.offerte[player]
		for indice = #offerta.oggetti, 1, -1 do
			local id = offerta.oggetti[indice]
			local oggetto = dati and trova(dati, id)
			if not oggetto or dati.Equipaggiato[oggetto.slot] == id then
				table.remove(offerta.oggetti, indice)
			end
		end
		modificata(sessione)
	end)

	local function collega(player)
		player.CharacterAdded:Connect(function(character)
			aggiungiPrompt(player, character)
		end)
		if player.Character then
			task.spawn(aggiungiPrompt, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(collega)
	for _, player in ipairs(Players:GetPlayers()) do
		collega(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local sessione = sessioni[player]
		if sessione then
			chiudi(sessione, player.DisplayName .. " è uscito dal gioco.")
		end
		richieste[player] = nil
		ultimaRichiesta[player] = nil
	end)

	-- Uno scambio aperto si chiude se uno dei due muore o entra in un dungeon.
	task.spawn(function()
		while true do
			task.wait(1)
			for player, sessione in pairs(sessioni) do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if not humanoid or humanoid.Health <= 0 or DungeonService.InDungeon(player) then
					chiudi(sessione, "Scambio annullato.")
				end
			end
		end
	end)
end

return ScambiService
