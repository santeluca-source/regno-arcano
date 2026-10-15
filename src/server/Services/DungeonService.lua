-- DungeonService: partite nei dungeon.
--
-- Una "partita" è un'istanza privata di un dungeon (Config/Dungeon.lua -> Elenco)
-- costruita lontano dalle isole.
-- Svolgimento: sala 1 -> sala 2 -> sala 3 -> boss -> forziere + portale di ritorno.
-- Ogni sala ripulita apre la porta successiva. Se un giocatore muore torna sulla
-- sua isola; quando la partita resta vuota viene distrutta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = ReplicatedStorage.Shared.Config
local Dungeon = require(Config.Dungeon)
local Rarita = require(Config.Rarita)
local PlayerData = require(script.Parent.PlayerData)
local CombatService = require(script.Parent.CombatService)
local TycoonService = require(script.Parent.TycoonService)
local InventarioService = require(script.Parent.InventarioService)
local Stanze = require(script.Parent.Parent.Dungeon.Stanze)
local Nemici = require(script.Parent.Parent.Dungeon.Nemici)
local Costruzione = require(script.Parent.Parent.Tycoon.Costruzione)
local Effetti = require(script.Parent.Parent.Combattimento.Effetti)

local Remotes = ReplicatedStorage.Remotes

local ORIGINE_ISTANZE = Vector3.new(3000, 0, 0)
local DISTANZA_ISTANZE = 200
local MASSIMO_ISTANZE = 12
local INTERVALLO_IA = 0.25
local DISTANZA_INSEGUIMENTO = 140

local DungeonService = {}

local eventoCompletato = Instance.new("BindableEvent")
-- Scatta quando il boss viene sconfitto: ({ giocatori presenti }, idDungeon)
DungeonService.Completato = eventoCompletato.Event

local cartellaDungeon
local partite = {} -- [id] = partita
local partitaDi = {} -- [Player] = partita
local slotOccupati = {} -- [numero] = true
local prossimoId = 0
local rng = Random.new()

local function notificaTutti(partita, testo)
	for player in pairs(partita.giocatori) do
		Remotes.Notifica:FireClient(player, testo)
	end
end

local function numeroGiocatori(partita)
	local n = 0
	for _ in pairs(partita.giocatori) do
		n += 1
	end
	return n
end

-- Nemici -------------------------------------------------------------------------

local function generaNemico(partita, tipo, terreno)
	local def = Dungeon.Nemici[tipo]
	local moltiplicatore = 1 + partita.config.vitaPerGiocatoreExtra * (numeroGiocatori(partita) - 1)
	local nemico = Nemici.Crea(partita.cartellaNemici, tipo, def, terreno, math.floor(def.vita * moltiplicatore))
	nemico:SetAttribute("Partita", partita.id)
	local ora = os.clock()
	partita.nemici[nemico] = {
		def = def,
		prossimoAttacco = ora + 1,
		prossimaOnda = ora + (def.onda and def.onda.ogni or 0),
		prossimaPioggia = ora + (def.pioggia and def.pioggia.ogni or 0),
	}
	return nemico
end

local function popolaSala(partita, numero)
	partita.sala = numero
	local zona = partita.mappa:FindFirstChild("Zona" .. numero)
	local sale = partita.config.sale
	if numero <= #sale then
		for tipo, quantita in pairs(sale[numero]) do
			for _ = 1, quantita do
				generaNemico(partita, tipo, Stanze.PuntoCasuale(zona, rng))
			end
		end
	else
		generaNemico(partita, partita.config.boss, zona.CFrame * CFrame.new(0, -0.5, 10))
		notificaTutti(partita, partita.config.annuncioBoss)
	end
end

local function apriPorta(partita, numero)
	local porta = partita.mappa:FindFirstChild("Porta" .. numero)
	if porta then
		porta.CanCollide = false
		TweenService:Create(porta, TweenInfo.new(0.8), { Transparency = 1 }):Play()
		Debris:AddItem(porta, 1)
	end
end

-- Il bersaglio più vicino tra i giocatori vivi della partita.
local function bersaglioPiuVicino(partita, posizione)
	local migliore, radiceMigliore, humanoidMigliore
	local distanzaMigliore = DISTANZA_INSEGUIMENTO
	for player in pairs(partita.giocatori) do
		local character = player.Character
		local radice = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		-- Chi è sotto il Velo d'Ombra non viene visto dai nemici.
		if radice and humanoid and humanoid.Health > 0 and not Effetti.Attivo(player, "Velo") then
			local distanza = (radice.Position - posizione).Magnitude
			if distanza < distanzaMigliore then
				migliore, radiceMigliore, humanoidMigliore, distanzaMigliore = player, radice, humanoid, distanza
			end
		end
	end
	return migliore, radiceMigliore, humanoidMigliore, distanzaMigliore
end

local function parteEffetto(dimensione, cframe, colore, forma)
	local parte = Instance.new("Part")
	parte.Size = dimensione
	parte.CFrame = cframe
	parte.Color = colore
	parte.Material = Enum.Material.Neon
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanTouch = false
	parte.CanQuery = false
	if forma then
		parte.Shape = forma
	end
	parte.Parent = Workspace.Effetti
	return parte
end

local function attaccoMischia(nemico, stato, radiceBersaglio, humanoidBersaglio)
	-- Breve preavviso: il corpo si illumina, così il giocatore può schivare.
	local torso = nemico:FindFirstChild("Torso")
	if torso then
		torso.Material = Enum.Material.Neon
	end
	task.delay(0.4, function()
		if torso and torso.Parent then
			torso.Material = Enum.Material.SmoothPlastic
		end
		local radice = nemico.PrimaryPart
		if not radice or nemico:GetAttribute("Sconfitto") or not radiceBersaglio.Parent then
			return
		end
		if (radiceBersaglio.Position - radice.Position).Magnitude <= stato.def.portata + 3 then
			CombatService.ColpisciGiocatore(humanoidBersaglio, stato.def.danno, stato.def.rallenta)
		end
	end)
end

local function attaccoDistanza(nemico, stato, radiceBersaglio, humanoidBersaglio)
	local da = nemico.Head.Position
	local impatto = radiceBersaglio.Position
	local freccia = parteEffetto(Vector3.new(1.2, 1.2, 1.2), CFrame.new(da), stato.def.colore, Enum.PartType.Ball)
	local durata = math.clamp((impatto - da).Magnitude / 60, 0.2, 0.9)
	TweenService:Create(freccia, TweenInfo.new(durata, Enum.EasingStyle.Linear), { Position = impatto }):Play()
	Debris:AddItem(freccia, durata + 0.05)
	task.delay(durata, function()
		-- Colpisce solo se il giocatore non si è spostato: si può schivare.
		if radiceBersaglio.Parent and (radiceBersaglio.Position - impatto).Magnitude <= 5 then
			CombatService.ColpisciGiocatore(humanoidBersaglio, stato.def.danno, stato.def.rallenta)
		end
	end)
end

-- Cerchio di preavviso a terra; dopo `preavviso` secondi colpisce chi c'è dentro.
local function colpoAdArea(partita, nemico, centro, raggio, danno, preavviso, colore, rallenta)
	local suolo = Vector3.new(centro.X, partita.origine.Y + 0.15, centro.Z)
	local avviso = parteEffetto(Vector3.new(0.3, raggio * 2, raggio * 2),
		CFrame.new(suolo) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 60, 60), Enum.PartType.Cylinder)
	avviso.Transparency = 0.55
	Debris:AddItem(avviso, preavviso)
	task.delay(preavviso, function()
		if nemico:GetAttribute("Sconfitto") then
			return
		end
		local esplosione = parteEffetto(Vector3.new(2, 2, 2), CFrame.new(suolo), colore, Enum.PartType.Ball)
		TweenService:Create(esplosione, TweenInfo.new(0.35), { Size = Vector3.one * raggio * 2, Transparency = 1 }):Play()
		Debris:AddItem(esplosione, 0.4)
		for player in pairs(partita.giocatori) do
			local character = player.Character
			local radice = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if radice and humanoid and ((radice.Position - suolo) * Vector3.new(1, 0, 1)).Magnitude <= raggio then
				CombatService.ColpisciGiocatore(humanoid, danno, rallenta)
			end
		end
	end)
end

local function ondaDelBoss(partita, nemico, stato)
	local onda = stato.def.onda
	colpoAdArea(partita, nemico, nemico.PrimaryPart.Position, onda.raggio, onda.danno, onda.preavviso,
		stato.def.colore, stato.def.rallenta)
end

-- Un cerchio sotto ogni giocatore della partita: bisogna spostarsi in fretta.
local function pioggiaDelBoss(partita, nemico, stato)
	local pioggia = stato.def.pioggia
	for player in pairs(partita.giocatori) do
		local character = player.Character
		local radice = character and character:FindFirstChild("HumanoidRootPart")
		if radice then
			colpoAdArea(partita, nemico, radice.Position, pioggia.raggio, pioggia.danno, pioggia.preavviso,
				Color3.fromRGB(200, 240, 255), stato.def.rallenta)
		end
	end
end

local function aggiornaNemico(partita, nemico, stato, ora)
	local humanoid = nemico:FindFirstChildOfClass("Humanoid")
	local radice = nemico.PrimaryPart
	if not humanoid or not radice or humanoid.Health <= 0 then
		return
	end
	local _, radiceBersaglio, humanoidBersaglio, distanza = bersaglioPiuVicino(partita, radice.Position)
	if not radiceBersaglio then
		humanoid:MoveTo(radice.Position)
		return
	end

	local def = stato.def
	-- Chi attacca a distanza tiene le distanze; chi combatte in mischia si avvicina.
	local distanzaIdeale = def.attacco == "Distanza" and def.portata * 0.6 or def.portata * 0.8
	if distanza > distanzaIdeale then
		humanoid:MoveTo(radiceBersaglio.Position)
	else
		humanoid:MoveTo(radice.Position)
		local guarda = Vector3.new(radiceBersaglio.Position.X, radice.Position.Y, radiceBersaglio.Position.Z)
		if (guarda - radice.Position).Magnitude > 0.5 then
			radice.CFrame = CFrame.lookAt(radice.Position, guarda)
		end
	end

	if distanza <= def.portata and ora >= stato.prossimoAttacco then
		stato.prossimoAttacco = ora + def.ricarica
		if def.attacco == "Distanza" then
			attaccoDistanza(nemico, stato, radiceBersaglio, humanoidBersaglio)
		else
			attaccoMischia(nemico, stato, radiceBersaglio, humanoidBersaglio)
		end
	end
	if def.onda and ora >= stato.prossimaOnda and distanza <= def.onda.raggio * 2 then
		stato.prossimaOnda = ora + def.onda.ogni
		ondaDelBoss(partita, nemico, stato)
	end
	if def.pioggia and ora >= stato.prossimaPioggia then
		stato.prossimaPioggia = ora + def.pioggia.ogni
		pioggiaDelBoss(partita, nemico, stato)
	end
end

-- Fine partita e ricompense -------------------------------------------------------

local function distruggiPartita(partita)
	if partite[partita.id] ~= partita then
		return
	end
	partite[partita.id] = nil
	slotOccupati[partita.slot] = nil
	partita.mappa:Destroy()
end

local function rimuoviGiocatore(player, motivo)
	local partita = partitaDi[player]
	if not partita then
		return
	end
	partitaDi[player] = nil
	partita.giocatori[player] = nil
	local connessione = partita.connessioneMorte[player]
	if connessione then
		connessione:Disconnect()
		partita.connessioneMorte[player] = nil
	end
	if motivo then
		Remotes.Notifica:FireClient(player, motivo)
	end
	if next(partita.giocatori) == nil then
		task.delay(2, distruggiPartita, partita)
	end
end

local function tornaAllIsola(player)
	rimuoviGiocatore(player)
	TycoonService.PortaSullIsola(player)
end

local function creaUscita(partita)
	local config = partita.config
	local punto = partita.mappa.PuntoFinale.CFrame
	local base = punto * CFrame.new(0, -0.1, 0)

	-- Forziere: ogni giocatore può aprirlo una volta.
	local forziere = Costruzione.Parte(partita.mappa, "ForziereFinale", base, Vector3.new(-8, 1.5, 0),
		Vector3.new(5, 3, 3.5), Color3.fromRGB(150, 105, 70), Enum.Material.Wood)
	local coperchio = Costruzione.Parte(partita.mappa, "Coperchio", base, Vector3.new(-8, 3.3, 0),
		Vector3.new(5.2, 0.6, 3.7), Color3.fromRGB(255, 205, 90), Enum.Material.Neon)
	Costruzione.Luce(coperchio, Color3.fromRGB(255, 205, 90), 2, 18)
	local apertiDa = {}
	local promptForziere = Instance.new("ProximityPrompt")
	promptForziere.ActionText = "Apri"
	promptForziere.ObjectText = "Forziere " .. config.provenienza
	promptForziere.HoldDuration = 0.6
	promptForziere.RequiresLineOfSight = false
	promptForziere.Parent = forziere
	promptForziere.Triggered:Connect(function(player)
		if partitaDi[player] ~= partita or apertiDa[player] then
			return
		end
		apertiDa[player] = true
		for valuta, quantita in pairs(config.ricompensaForziere) do
			PlayerData.AggiungiValuta(player, valuta, quantita)
		end
		local oggetto = InventarioService.Genera(InventarioService.SlotCasuale(),
			Rarita.Estrai(config.tabellaForziere, rng), config.provenienza, config.potenza)
		InventarioService.Aggiungi(player, oggetto)
		task.spawn(PlayerData.Salva, player)
	end)

	-- Portale di ritorno all'isola.
	local portale = Costruzione.Parte(partita.mappa, "PortaleRitorno", base, Vector3.new(8, 6, 0),
		Vector3.new(8, 11, 0.6), Color3.fromRGB(74, 225, 255), Enum.Material.Neon, { CanCollide = false, Transparency = 0.2 })
	Costruzione.Luce(portale, Color3.fromRGB(74, 225, 255), 2.5, 22)
	local promptPortale = Instance.new("ProximityPrompt")
	promptPortale.ActionText = "Torna all'isola"
	promptPortale.ObjectText = "Portale di Ritorno"
	promptPortale.HoldDuration = 0.4
	promptPortale.RequiresLineOfSight = false
	promptPortale.Parent = portale
	promptPortale.Triggered:Connect(function(player)
		if partitaDi[player] == partita then
			tornaAllIsola(player)
		end
	end)
end

local function alNemicoSconfitto(nemico, uccisore)
	local partita = partite[nemico:GetAttribute("Partita")]
	local stato = partita and partita.nemici[nemico]
	if not stato then
		return
	end
	partita.nemici[nemico] = nil
	local config = partita.config

	-- Frammenti a tutti i giocatori della partita: in gruppo si guadagna insieme.
	for player in pairs(partita.giocatori) do
		PlayerData.AggiungiValuta(player, "Frammenti", stato.def.frammenti)
	end
	if uccisore and partita.giocatori[uccisore] and rng:NextInteger(1, 100) <= stato.def.probabilitaOggetto then
		local oggetto = InventarioService.Genera(InventarioService.SlotCasuale(),
			Rarita.Estrai(config.tabellaNemici, rng), config.provenienza, config.potenza)
		InventarioService.Aggiungi(uccisore, oggetto)
	end

	-- Il corpo svanisce.
	for _, parte in ipairs(nemico:GetDescendants()) do
		if parte:IsA("BasePart") and parte.Transparency < 1 then
			TweenService:Create(parte, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		end
	end
	Debris:AddItem(nemico, 0.7)

	if next(partita.nemici) ~= nil then
		return
	end
	-- Sala ripulita.
	if partita.sala <= #config.sale then
		apriPorta(partita, partita.sala)
		notificaTutti(partita, partita.sala < #config.sale and "Sala ripulita! La porta si apre..."
			or "Sala ripulita! Qualcosa di enorme si muove oltre la porta...")
		popolaSala(partita, partita.sala + 1)
	else
		notificaTutti(partita, "Hai sconfitto il boss! Apri il forziere.")
		creaUscita(partita)
		local presenti = {}
		for player in pairs(partita.giocatori) do
			table.insert(presenti, player)
		end
		eventoCompletato:Fire(presenti, partita.idDungeon)
	end
end

-- Ingresso -------------------------------------------------------------------------

-- Fa entrare un gruppo di giocatori nel dungeon indicato (id in Dungeon.Elenco).
function DungeonService.Entra(gruppo, idDungeon)
	local config = Dungeon.Elenco[idDungeon]
	if not config then
		warn("[Dungeon] Dungeon sconosciuto: " .. tostring(idDungeon))
		return false
	end
	local slot
	for numero = 1, MASSIMO_ISTANZE do
		if not slotOccupati[numero] then
			slot = numero
			break
		end
	end
	if not slot then
		for _, player in ipairs(gruppo) do
			Remotes.Notifica:FireClient(player, "Tutti i dungeon sono occupati, riprova tra poco.")
		end
		return false
	end
	slotOccupati[slot] = true

	prossimoId += 1
	local origine = CFrame.new(ORIGINE_ISTANZE + Vector3.new(slot * DISTANZA_ISTANZE, 0, 0))
	local partita = {
		id = prossimoId,
		idDungeon = idDungeon,
		config = config,
		slot = slot,
		origine = origine,
		giocatori = {},
		nemici = {},
		sala = 0,
		connessioneMorte = {},
	}
	partita.mappa = Stanze.Costruisci(cartellaDungeon, origine, idDungeon .. "_" .. partita.id, config.tema)
	partita.cartellaNemici = Instance.new("Folder")
	partita.cartellaNemici.Name = "Nemici"
	partita.cartellaNemici.Parent = partita.mappa
	partite[partita.id] = partita

	local arrivo = partita.mappa.Arrivo.CFrame * CFrame.new(0, 3, 0)
	for indice, player in ipairs(gruppo) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not partitaDi[player] then
			partita.giocatori[player] = true
			partitaDi[player] = partita
			character:PivotTo(arrivo * CFrame.new((indice - 1) * 3, 0, 0))
			-- Chi muore torna sulla propria isola (ci pensa TycoonService al respawn).
			partita.connessioneMorte[player] = humanoid.Died:Connect(function()
				rimuoviGiocatore(player, "Sei stato sconfitto: " .. config.nome .. " ha vinto questa volta...")
			end)
		end
	end
	if next(partita.giocatori) == nil then
		distruggiPartita(partita)
		return false
	end

	notificaTutti(partita, config.nome .. ": ripulisci le sale e sconfiggi il boss!")
	popolaSala(partita, 1)
	return true
end

function DungeonService.InDungeon(player)
	return partitaDi[player] ~= nil
end

-- Fa uscire un giocatore dalla sua partita (es. teletrasporto dal menu Viaggi).
-- Non lo sposta: ci pensa chi chiama.
function DungeonService.Esci(player)
	rimuoviGiocatore(player, "Hai lasciato il dungeon.")
end

function DungeonService.Avvia()
	cartellaDungeon = Instance.new("Folder")
	cartellaDungeon.Name = "Dungeon"
	cartellaDungeon.Parent = Workspace

	CombatService.Sconfitto:Connect(alNemicoSconfitto)

	TycoonService.PortaleUsato:Connect(function(player, idDungeon)
		if not DungeonService.InDungeon(player) then
			DungeonService.Entra({ player }, idDungeon)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		rimuoviGiocatore(player)
	end)

	-- Intelligenza dei nemici: un unico ciclo per tutte le partite.
	task.spawn(function()
		while true do
			task.wait(INTERVALLO_IA)
			local ora = os.clock()
			for _, partita in pairs(partite) do
				for nemico, stato in pairs(partita.nemici) do
					aggiornaNemico(partita, nemico, stato, ora)
				end
			end
		end
	end)
end

return DungeonService
