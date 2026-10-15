-- InventarioService: oggetti trovati nei dungeon ed equipaggiamento.
--
-- Un oggetto è una tabella salvata in PlayerData.Inventario:
--   { id = "GUID", slot = "Arma" | "Armatura", rarita = "Raro", potenza = 16, nome = "Arma Rara delle Rovine" }
-- Equipaggiato[slot] contiene l'id dell'oggetto indossato.
-- Gli effetti (danno, vita, valore di vendita) sono in Config/Equipaggiamento.lua.
--
-- Un oggetto migliore di quello indossato viene messo addosso in automatico;
-- dal menu dell'inventario (tasto I) il giocatore può poi scegliere e vendere.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage.Shared.Config
local Rarita = require(Config.Rarita)
local Equipaggiamento = require(Config.Equipaggiamento)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage.Remotes

local InventarioService = {}

InventarioService.Slot = Equipaggiamento.Slot

local rng = Random.new()
local ultimaAzione = {} -- [Player] = os.clock()

local function notifica(player, testo)
	Remotes.Notifica:FireClient(player, testo)
end

-- moltiplicatore: potenza extra legata a dove si trova l'oggetto (es. Cripta x1.3)
function InventarioService.Genera(slot, raritaId, provenienza, moltiplicatore)
	local rarita = Rarita.Dati[raritaId]
	local base = Equipaggiamento.PotenzaBase * rarita.potenza * (moltiplicatore or 1)
	local potenza = math.floor(base * rng:NextNumber(0.9, 1.15) + 0.5)
	return {
		id = HttpService:GenerateGUID(false),
		slot = slot,
		rarita = raritaId,
		potenza = potenza,
		nome = slot .. " " .. rarita.nomeF .. " " .. (provenienza or "delle Rovine"),
	}
end

function InventarioService.SlotCasuale()
	return InventarioService.Slot[rng:NextInteger(1, #InventarioService.Slot)]
end

local function trova(dati, id)
	for indice, oggetto in ipairs(dati.Inventario) do
		if oggetto.id == id then
			return oggetto, indice
		end
	end
	return nil
end

-- L'oggetto indossato in uno slot, oppure nil.
function InventarioService.Equipaggiato(player, slot)
	local dati = PlayerData.Ottieni(player)
	local id = dati and dati.Equipaggiato[slot]
	return id and trova(dati, id) or nil
end

function InventarioService.Potenza(player, slot)
	local oggetto = InventarioService.Equipaggiato(player, slot)
	return oggetto and oggetto.potenza or 0
end

function InventarioService.MoltiplicatoreDanno(player)
	return Equipaggiamento.MoltiplicatoreDanno(InventarioService.Potenza(player, "Arma"))
end

function InventarioService.VitaBonus(player)
	return Equipaggiamento.VitaBonus(InventarioService.Potenza(player, "Armatura"))
end

-- Sincronizzazione col client ----------------------------------------------------

-- Attributi per l'HUD e le targhette.
local function rispecchia(player)
	for _, slot in ipairs(InventarioService.Slot) do
		local oggetto = InventarioService.Equipaggiato(player, slot)
		player:SetAttribute(slot, oggetto and (Equipaggiamento.NomeCompleto(oggetto) .. "  ·  Potenza " .. oggetto.potenza) or "Nessuna")
		player:SetAttribute(slot .. "Rarita", oggetto and oggetto.rarita or "")
	end
end

-- Lista completa per il menu dell'inventario.
local function istantanea(player)
	local dati = PlayerData.Ottieni(player)
	if not dati then
		return nil
	end
	return {
		oggetti = dati.Inventario,
		equipaggiato = dati.Equipaggiato,
		capienza = Equipaggiamento.Capienza,
	}
end

local function invia(player)
	rispecchia(player)
	local dati = istantanea(player)
	if dati then
		Remotes.InventarioAggiornato:FireClient(player, dati)
	end
end

-- Aggiungere oggetti ------------------------------------------------------------

-- Aggiunge un oggetto e lo indossa se è migliore. Restituisce true se indossato.
function InventarioService.Aggiungi(player, oggetto)
	local dati = PlayerData.Ottieni(player)
	if not dati then
		return false
	end
	local migliore = oggetto.potenza > InventarioService.Potenza(player, oggetto.slot)

	if #dati.Inventario >= Equipaggiamento.Capienza and not migliore then
		local frammenti = Equipaggiamento.ValoreVendita(oggetto.potenza)
		PlayerData.AggiungiValuta(player, "Frammenti", frammenti)
		notifica(player, "Inventario pieno: " .. oggetto.nome .. " venduto per " .. frammenti .. " Frammenti")
		return false
	end

	PlayerData.Modifica(player, "Inventario", function(d)
		if #d.Inventario >= Equipaggiamento.Capienza then
			-- Si fa spazio togliendo l'oggetto più debole non indossato.
			local peggiore
			for indice, esistente in ipairs(d.Inventario) do
				local indossato = d.Equipaggiato[esistente.slot] == esistente.id
				if not indossato and (not peggiore or esistente.potenza < d.Inventario[peggiore].potenza) then
					peggiore = indice
				end
			end
			if peggiore then
				table.remove(d.Inventario, peggiore)
			end
		end
		table.insert(d.Inventario, oggetto)
		if migliore then
			d.Equipaggiato[oggetto.slot] = oggetto.id
		end
	end)

	local testo = "Hai trovato: " .. oggetto.nome .. " (Potenza " .. oggetto.potenza .. ")"
	notifica(player, migliore and (testo .. " — indossato!") or testo)
	return migliore
end

-- Azioni dal menu -----------------------------------------------------------------

local azioni = {}

function azioni.Indossa(player, dati, id)
	local oggetto = trova(dati, id)
	if not oggetto or dati.Equipaggiato[oggetto.slot] == id then
		return
	end
	PlayerData.Modifica(player, "Inventario", function(d)
		d.Equipaggiato[oggetto.slot] = id
	end)
end

function azioni.Togli(player, dati, id)
	local oggetto = trova(dati, id)
	if not oggetto or dati.Equipaggiato[oggetto.slot] ~= id then
		return
	end
	PlayerData.Modifica(player, "Inventario", function(d)
		d.Equipaggiato[oggetto.slot] = nil
	end)
end

function azioni.Vendi(player, dati, id)
	local oggetto, indice = trova(dati, id)
	if not oggetto then
		return
	end
	if dati.Equipaggiato[oggetto.slot] == id then
		notifica(player, "Togliti l'oggetto prima di venderlo.")
		return
	end
	local frammenti = Equipaggiamento.ValoreVendita(oggetto.potenza)
	PlayerData.Modifica(player, "Inventario", function(d)
		table.remove(d.Inventario, indice)
	end)
	PlayerData.AggiungiValuta(player, "Frammenti", frammenti)
	notifica(player, oggetto.nome .. " venduto: +" .. frammenti .. " Frammenti")
end

function azioni.VendiComuni(player, dati)
	local frammenti, venduti = 0, 0
	PlayerData.Modifica(player, "Inventario", function(d)
		for indice = #d.Inventario, 1, -1 do
			local oggetto = d.Inventario[indice]
			if oggetto.rarita == "Comune" and d.Equipaggiato[oggetto.slot] ~= oggetto.id then
				frammenti += Equipaggiamento.ValoreVendita(oggetto.potenza)
				venduti += 1
				table.remove(d.Inventario, indice)
			end
		end
	end)
	if venduti == 0 then
		notifica(player, "Nessun oggetto Comune da vendere.")
		return
	end
	PlayerData.AggiungiValuta(player, "Frammenti", frammenti)
	notifica(player, venduti .. " oggetti Comuni venduti: +" .. frammenti .. " Frammenti")
end

-- Il Fabbro: bisogna essere vicino all'incudine nella Piazza.
local function vicinoAlFabbro(player)
	local piazza = Workspace:FindFirstChild("Piazza")
	local incudine = piazza and piazza:FindFirstChild("Incudine")
	local character = player.Character
	local radice = character and character:FindFirstChild("HumanoidRootPart")
	return incudine ~= nil and radice ~= nil
		and (radice.Position - incudine.Position).Magnitude <= Equipaggiamento.DistanzaFabbro
end

function azioni.Migliora(player, dati, id)
	local oggetto = trova(dati, id)
	if not oggetto then
		return
	end
	if not vicinoAlFabbro(player) then
		notifica(player, "Porta l'oggetto al Fabbro nella Piazza per migliorarlo.")
		return
	end
	local costo = Equipaggiamento.CostoMiglioramento(oggetto)
	if not costo then
		notifica(player, "Questo oggetto è già al livello massimo!")
		return
	end
	if not PlayerData.Spendi(player, costo) then
		notifica(player, "Il Fabbro chiede " .. costo.Oro .. " Oro e " .. costo.Frammenti .. " Frammenti.")
		return
	end
	PlayerData.Modifica(player, "Inventario", function()
		-- La potenza di partenza resta salvata: ogni livello aggiunge una parte di quella.
		oggetto.potenzaBase = oggetto.potenzaBase or oggetto.potenza
		oggetto.livello = (oggetto.livello or 0) + 1
		oggetto.potenza = Equipaggiamento.PotenzaAlLivello(oggetto.potenzaBase, oggetto.livello)
	end)
	notifica(player, "Il Fabbro ha forgiato: " .. Equipaggiamento.NomeCompleto(oggetto) .. " (Potenza " .. oggetto.potenza .. ")")
	task.spawn(PlayerData.Salva, player)
end

local function suAzione(player, nome, id)
	-- Mai fidarsi del client: controlliamo tipi, frequenza ed esistenza dell'oggetto.
	if type(nome) ~= "string" or not azioni[nome] or (id ~= nil and type(id) ~= "string") then
		return
	end
	local ora = os.clock()
	if ora - (ultimaAzione[player] or 0) < 0.2 then
		return
	end
	ultimaAzione[player] = ora
	local dati = PlayerData.Ottieni(player)
	if dati then
		azioni[nome](player, dati, id)
	end
end

function InventarioService.Avvia()
	Remotes.AzioneInventario.OnServerEvent:Connect(suAzione)
	Remotes.OttieniInventario.OnServerInvoke = istantanea

	PlayerData.Caricato:Connect(invia)
	PlayerData.Cambiato:Connect(function(player, sezione)
		if sezione == "Inventario" then
			invia(player)
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerData.Pronto(player) then
			invia(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		ultimaAzione[player] = nil
	end)
end

return InventarioService
