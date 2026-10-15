-- TycoonService: isole personali, miniere, nastro, forziere e acquisti.
--
-- Ciclo di gioco:
--   le Miniere fanno cadere minerali sul Nastro -> il Raffinatore ne aumenta il valore
--   -> il Raccoglitore li trasforma in Oro dentro il Forziere -> il giocatore ci cammina
--   sopra per incassare. Le Strutture magiche producono Essenza in automatico.
-- I bonus della classe attiva moltiplicano sia l'Oro raccolto sia l'Essenza.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = ReplicatedStorage.Shared.Config
local Tycoon = require(Config.Tycoon)
local Classi = require(Config.Classi)
local PlayerData = require(script.Parent.PlayerData)
local Isole = require(script.Parent.Parent.Tycoon.Isole)
local Modelli = require(script.Parent.Parent.Tycoon.Modelli)
local Costruzione = require(script.Parent.Parent.Tycoon.Costruzione)

local Remotes = ReplicatedStorage.Remotes

local TycoonService = {}

local eventoPortale = Instance.new("BindableEvent")
-- Scatta quando il proprietario usa un portale della sua isola: (player, idDungeon)
TycoonService.PortaleUsato = eventoPortale.Event

local eventoAcquistato = Instance.new("BindableEvent")
-- Scatta dopo ogni acquisto sull'isola: (player, idOggetto)
TycoonService.Acquistato = eventoAcquistato.Event

local eventoIncassato = Instance.new("BindableEvent")
-- Scatta quando un giocatore incassa il Forziere: (player, quantita)
TycoonService.Incassato = eventoIncassato.Event

local cartellaIsole
local stati = {} -- [Player] = { isola, base, attivo, frazioneEssenza, ultimoTocco = {} }

-- Oggetti ordinati per "ordine": così, ricostruendo, i prerequisiti vengono prima.
local idOrdinati = {}
for id in pairs(Tycoon.Oggetti) do
	table.insert(idOrdinati, id)
end
table.sort(idOrdinati, function(a, b)
	return Tycoon.Oggetti[a].ordine < Tycoon.Oggetti[b].ordine
end)

-- Utilità ----------------------------------------------------------------------

local function giocatoreDaParte(parte)
	local modello = parte:FindFirstAncestorOfClass("Model")
	return modello and Players:GetPlayerFromCharacter(modello)
end

-- Evita che lo stesso tocco scatti decine di volte al secondo.
local function attesaTocco(stato, chiave, secondi)
	local ora = os.clock()
	if ora - (stato.ultimoTocco[chiave] or 0) < secondi then
		return false
	end
	stato.ultimoTocco[chiave] = ora
	return true
end

local function possiede(player, id)
	local dati = PlayerData.Ottieni(player)
	return Tycoon.Gratuito(id) or (dati ~= nil and dati.Tycoon.Acquisti[id] == true)
end

local function disponibile(player, id)
	if possiede(player, id) then
		return false
	end
	for _, richiesto in ipairs(Tycoon.Oggetti[id].richiede) do
		if not possiede(player, richiesto) then
			return false
		end
	end
	return true
end

local function bonusClasse(player, valuta)
	local dati = PlayerData.Ottieni(player)
	local classe = dati and Classi.Dati[dati.Classe]
	return classe and classe.bonusBase[valuta] or 1
end

local function notifica(player, testo)
	Remotes.Notifica:FireClient(player, testo)
end

-- Forziere -------------------------------------------------------------------------

local function aggiornaTestoForziere(player)
	local stato = stati[player]
	local dati = PlayerData.Ottieni(player)
	local modello = stato and stato.isola.Oggetti:FindFirstChild("Forziere")
	if not modello or not dati then
		return
	end
	local testo = modello.PiattaformaForziere.Etichetta.TestoForziere
	testo.Text = "FORZIERE: " .. dati.Tycoon.Forziere .. " Oro"
end

local function depositaNelForziere(player, valore)
	local oro = math.floor(valore * bonusClasse(player, "Oro"))
	PlayerData.Modifica(player, "Forziere", function(dati)
		dati.Tycoon.Forziere += oro
	end)
	aggiornaTestoForziere(player)
end

local function incassaForziere(player)
	local dati = PlayerData.Ottieni(player)
	local quantita = dati and dati.Tycoon.Forziere or 0
	if quantita <= 0 then
		return
	end
	PlayerData.Modifica(player, "Forziere", function(d)
		d.Tycoon.Forziere = 0
	end)
	PlayerData.AggiungiValuta(player, "Oro", quantita)
	aggiornaTestoForziere(player)
	notifica(player, "+" .. quantita .. " Oro")
	eventoIncassato:Fire(player, quantita)
end

-- Produzione -----------------------------------------------------------------------

local function moltiplicatoreRaffinatore(player)
	return possiede(player, "Raffinatore") and Tycoon.Oggetti.Raffinatore.moltiplicatore or 1
end

-- Calcola la produzione stimata e la mostra al client tramite attributi.
local function aggiornaProduzione(player)
	local oro, essenza = 0, 0
	for _, id in ipairs(idOrdinati) do
		local def = Tycoon.Oggetti[id]
		if possiede(player, id) then
			if def.tipo == "Miniera" then
				oro += def.valore / def.intervallo
			elseif def.tipo == "Struttura" then
				essenza += def.essenzaAlSecondo
			end
		end
	end
	oro *= moltiplicatoreRaffinatore(player) * bonusClasse(player, "Oro")
	essenza *= bonusClasse(player, "Essenza")
	player:SetAttribute("OroAlSecondo", math.floor(oro * 10) / 10)
	player:SetAttribute("EssenzaAlSecondo", math.floor(essenza * 10) / 10)
end

local function avviaMiniera(player, modello, def)
	local stato = stati[player]
	local ugello = modello.Ugello
	local cartellaMinerali = stato.isola.Minerali
	task.spawn(function()
		while stato.attivo and modello.Parent do
			task.wait(def.intervallo)
			if not stato.attivo or not modello.Parent then
				break
			end
			if #cartellaMinerali:GetChildren() < Tycoon.MassimoMineraliPerIsola then
				local minerale = Instance.new("Part")
				minerale.Name = "Minerale"
				minerale.Size = Vector3.new(1.3, 1.3, 1.3)
				minerale.Color = def.colore
				minerale.Material = Enum.Material.SmoothPlastic
				minerale.CFrame = ugello.CFrame * CFrame.new(0, -1.5, 0)
				minerale:SetAttribute("Valore", def.valore)
				minerale.Parent = cartellaMinerali
				-- Il server gestisce la fisica: il client non può spostare i minerali.
				minerale:SetNetworkOwner(nil)
				Debris:AddItem(minerale, Tycoon.DurataMinerale)
			end
		end
	end)
end

-- Collega le parti funzionali di un oggetto appena costruito.
local function collegaOggetto(player, id, modello)
	local stato = stati[player]
	local def = Tycoon.Oggetti[id]
	local cartellaMinerali = stato.isola.Minerali

	if def.tipo == "Nastro" then
		modello.Raccoglitore.Touched:Connect(function(parte)
			if parte.Parent == cartellaMinerali and not parte:GetAttribute("Raccolto") then
				parte:SetAttribute("Raccolto", true)
				local valore = parte:GetAttribute("Valore") or 0
				parte:Destroy()
				depositaNelForziere(player, valore)
			end
		end)
	elseif def.tipo == "Miniera" then
		avviaMiniera(player, modello, def)
	elseif def.tipo == "Raffinatore" then
		modello.ZonaRaffinatore.Touched:Connect(function(parte)
			if parte.Parent == cartellaMinerali and not parte:GetAttribute("Raffinato") then
				parte:SetAttribute("Raffinato", true)
				parte:SetAttribute("Valore", (parte:GetAttribute("Valore") or 0) * def.moltiplicatore)
				parte.Material = Enum.Material.Neon
			end
		end)
	elseif def.tipo == "Forziere" then
		modello.PiattaformaForziere.Touched:Connect(function(parte)
			if giocatoreDaParte(parte) == player and attesaTocco(stato, "Forziere", 1) then
				incassaForziere(player)
			end
		end)
		aggiornaTestoForziere(player)
	elseif def.tipo == "Altare" then
		modello:FindFirstChild("PromptAltare", true).Triggered:Connect(function(chi)
			if chi == player then
				Remotes.ApriMenuClassi:FireClient(chi)
			else
				notifica(chi, "Puoi cambiare classe solo dall'altare della tua isola.")
			end
		end)
	elseif def.tipo == "Portale" then
		modello:FindFirstChild("PromptPortale", true).Triggered:Connect(function(chi)
			if chi ~= player then
				notifica(chi, "Questo portale risponde solo al padrone dell'isola.")
				return
			end
			-- DungeonService ascolta questo evento e crea la partita.
			eventoPortale:Fire(chi, def.dungeon)
		end)
	end
end

local function costruisci(player, id)
	local stato = stati[player]
	if stato.isola.Oggetti:FindFirstChild(id) then
		return
	end
	local modello = Modelli.Costruisci(stato.isola.Oggetti, stato.base, id, Tycoon.Oggetti[id])
	collegaOggetto(player, id, modello)
end

-- Pulsanti di acquisto -------------------------------------------------------------

local acquista -- dichiarata più sotto

local function aggiornaPulsanti(player)
	local stato = stati[player]
	if not stato then
		return
	end
	local cartella = stato.isola.Pulsanti
	for _, id in ipairs(idOrdinati) do
		local def = Tycoon.Oggetti[id]
		if def.pulsante then
			local pulsante = cartella:FindFirstChild(id)
			if disponibile(player, id) then
				if not pulsante then
					pulsante = Modelli.Pulsante(cartella, stato.base, id, def)
					pulsante.Touched:Connect(function(parte)
						if giocatoreDaParte(parte) == player and attesaTocco(stato, "Pulsante", 0.5) then
							acquista(player, id)
						end
					end)
				end
				local puo = PlayerData.PuoPermettersi(player, def.costo)
				pulsante.Color = puo and Costruzione.Colori.verde or Costruzione.Colori.rosso
			elseif pulsante then
				pulsante:Destroy()
			end
		end
	end
end

acquista = function(player, id)
	local def = Tycoon.Oggetti[id]
	if not def or not stati[player] or not disponibile(player, id) then
		return false
	end
	if not PlayerData.Spendi(player, def.costo) then
		notifica(player, "Ti servono " .. Tycoon.TestoCosto(def.costo) .. " per " .. def.nome)
		return false
	end
	PlayerData.Modifica(player, "Tycoon", function(dati)
		dati.Tycoon.Acquisti[id] = true
	end)
	costruisci(player, id)
	aggiornaPulsanti(player)
	aggiornaProduzione(player)
	notifica(player, def.nome .. " costruito!")
	eventoAcquistato:Fire(player, id)
	task.spawn(PlayerData.Salva, player)
	return true
end

-- Assegnazione delle isole ---------------------------------------------------------

local function portaSullIsola(player)
	local stato = stati[player]
	local character = player.Character
	if stato and character then
		character:PivotTo(Isole.PuntoDiArrivo(stato.isola))
	end
end

local function assegnaIsola(player)
	for _, isola in ipairs(cartellaIsole:GetChildren()) do
		if isola:GetAttribute("Proprietario") == 0 then
			Isole.ImpostaProprietario(isola, player)
			stati[player] = {
				isola = isola,
				base = isola:GetAttribute("Base"),
				attivo = true,
				frazioneEssenza = 0,
				ultimoTocco = {},
			}
			for _, id in ipairs(idOrdinati) do
				if possiede(player, id) then
					costruisci(player, id)
				end
			end
			aggiornaPulsanti(player)
			aggiornaProduzione(player)
			portaSullIsola(player)
			return
		end
	end
	warn("[Tycoon] Nessuna isola libera per " .. player.Name)
	notifica(player, "Server pieno: nessuna isola libera.")
end

local function liberaIsola(player)
	local stato = stati[player]
	if not stato then
		return
	end
	stato.attivo = false
	stati[player] = nil
	for _, nome in ipairs({ "Oggetti", "Pulsanti", "Minerali" }) do
		stato.isola[nome]:ClearAllChildren()
	end
	Isole.ImpostaProprietario(stato.isola, nil)
end

-- API per gli altri servizi --------------------------------------------------------

function TycoonService.PortaSullIsola(player)
	portaSullIsola(player)
end

function TycoonService.IsolaDi(player)
	local stato = stati[player]
	return stato and stato.isola
end

function TycoonService.SullaPropriaIsola(player)
	local stato = stati[player]
	local character = player.Character
	local radice = character and character:FindFirstChild("HumanoidRootPart")
	return stato ~= nil and radice ~= nil and Isole.Contiene(stato.isola, radice.Position)
end

function TycoonService.Avvia()
	cartellaIsole = Isole.Genera()

	local function collegaGiocatore(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 5)
			task.wait() -- lascia finire lo spawn standard prima di spostarlo
			portaSullIsola(player)
		end)
		assegnaIsola(player)
	end
	PlayerData.Caricato:Connect(collegaGiocatore)
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerData.Pronto(player) then
			collegaGiocatore(player)
		end
	end
	Players.PlayerRemoving:Connect(liberaIsola)

	PlayerData.Cambiato:Connect(function(player, sezione)
		if sezione == "Valute" then
			aggiornaPulsanti(player)
		elseif sezione == "Classe" then
			aggiornaProduzione(player)
		end
	end)

	-- Essenza passiva delle strutture magiche, una volta al secondo.
	task.spawn(function()
		while true do
			task.wait(1)
			for player, stato in pairs(stati) do
				local alSecondo = player:GetAttribute("EssenzaAlSecondo") or 0
				local totale = alSecondo + stato.frazioneEssenza
				local intera = math.floor(totale)
				stato.frazioneEssenza = totale - intera
				if intera > 0 then
					PlayerData.AggiungiValuta(player, "Essenza", intera)
				end
			end
		end
	end)
end

return TycoonService
