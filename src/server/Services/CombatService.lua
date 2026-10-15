-- CombatService: armi delle classi, abilità e danno ai nemici.
--
-- Un "nemico" è qualsiasi Model con un Humanoid e il tag "Nemico" (CollectionService).
-- Così lo stesso codice vale per il golem d'allenamento, i mostri dei dungeon e i boss.
-- Il client manda solo il punto mirato: il server decide se e chi viene colpito.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Classi = require(ReplicatedStorage.Shared.Config.Classi)
local Rarita = require(ReplicatedStorage.Shared.Config.Rarita)
local PlayerData = require(script.Parent.PlayerData)
local InventarioService = require(script.Parent.InventarioService)
local Effetti = require(script.Parent.Parent.Combattimento.Effetti)

local Remotes = ReplicatedStorage.Remotes

local TAG_NEMICO = "Nemico"
local DISTANZA_MASSIMA_MIRA = 250

local CombatService = {}

local eventoSconfitto = Instance.new("BindableEvent")
-- Scatta quando un nemico arriva a zero vita: (nemico, giocatoreCheHaDatoIlColpoFinale)
CombatService.Sconfitto = eventoSconfitto.Event

local eventoColpito = Instance.new("BindableEvent")
-- Scatta a ogni colpo di un giocatore su un nemico: (nemico, attaccante)
CombatService.Colpito = eventoColpito.Event
CombatService.TagNemico = TAG_NEMICO

local ultimoUso = {} -- [Player] = os.clock()
local cartellaEffetti

-- Nemici -----------------------------------------------------------------------

local function nemicoDaParte(parte)
	local modello = parte:FindFirstAncestorOfClass("Model")
	while modello do
		if CollectionService:HasTag(modello, TAG_NEMICO) then
			return modello
		end
		modello = modello:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function nemiciNelRaggio(centro, raggio)
	local trovati, visti = {}, {}
	for _, parte in ipairs(Workspace:GetPartBoundsInRadius(centro, raggio)) do
		local nemico = nemicoDaParte(parte)
		if nemico and not visti[nemico] then
			visti[nemico] = true
			table.insert(trovati, nemico)
		end
	end
	return trovati
end

local bonusColpo = {} -- [Player] = moltiplicatore del colpo in corso (es. Velo d'Ombra)

-- Moltiplicatore di danno: arma equipaggiata, Furia e bonus del colpo.
local function moltiplicatoreDanno(player)
	local moltiplicatore = InventarioService.MoltiplicatoreDanno(player)
	local furia = Effetti.Attivo(player, "Furia")
	if furia then
		moltiplicatore *= furia.danno
	end
	local forza = Effetti.Attivo(player, "Forza") -- Pozione di Forza
	if forza then
		moltiplicatore *= forza.valore
	end
	return moltiplicatore * (bonusColpo[player] or 1)
end

local function velocitaClasse(player)
	local dati = PlayerData.Ottieni(player)
	local classe = dati and Classi.Dati[dati.Classe]
	return classe and classe.statistiche.velocita or 16
end

-- Punto unico per fare danno a un GIOCATORE (lo usano nemici, boss e trappole).
-- Qui si applicano scudi, aure e penalità degli effetti attivi.
-- rallenta (facoltativo): { fattore, durata } per i colpi di ghiaccio.
function CombatService.ColpisciGiocatore(humanoid, quantita, rallenta)
	local player = Players:GetPlayerFromCharacter(humanoid.Parent)
	if player then
		local furia = Effetti.Attivo(player, "Furia")
		if furia then
			quantita *= furia.dannoSubito
		end
		local protezione = Effetti.Attivo(player, "Protezione")
		if protezione then
			quantita *= 1 - protezione.riduzione
		end
		local pietra = Effetti.Attivo(player, "Pietra") -- Pozione di Pietra
		if pietra then
			quantita *= 1 - pietra.valore
		end
		local scudo = Effetti.Attivo(player, "Scudo")
		if scudo then
			local assorbito = math.min(scudo.rimanente, quantita)
			scudo.rimanente -= assorbito
			quantita -= assorbito
			if scudo.rimanente <= 0 then
				Effetti.Rimuovi(player, "Scudo")
				Remotes.Notifica:FireClient(player, "La barriera si è infranta!")
			end
		end
	end
	if quantita > 0 then
		humanoid:TakeDamage(quantita)
		if rallenta and player then
			Effetti.Aggiungi(player, "Gelo", rallenta.durata, {}, Color3.fromRGB(150, 220, 255), function()
				if humanoid.Parent then
					humanoid.WalkSpeed = velocitaClasse(player)
				end
			end)
			humanoid.WalkSpeed = velocitaClasse(player) * rallenta.fattore
		end
	end
end

-- Punto unico per fare danno a un nemico: lo useranno anche trappole e alleati.
function CombatService.Danneggia(nemico, quantita, attaccante)
	local humanoid = nemico:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or nemico:GetAttribute("Sconfitto") then
		return
	end
	quantita = math.max(1, math.floor(quantita))

	if attaccante then
		nemico:SetAttribute("UltimoAttaccante", attaccante.UserId)
		Remotes.Danno:FireClient(attaccante, nemico:GetPivot().Position, quantita)
		eventoColpito:Fire(nemico, attaccante)
	end

	-- Il golem d'allenamento non muore mai: quando finisce la vita si ricarica.
	if nemico:GetAttribute("Manichino") then
		if quantita >= humanoid.Health then
			humanoid.Health = humanoid.MaxHealth
			if attaccante then
				Remotes.Notifica:FireClient(attaccante, "Golem abbattuto! Si rigenera...")
			end
		else
			humanoid.Health -= quantita
		end
		return
	end

	-- Impostiamo la vita a mano: TakeDamage oltre lo zero non sempre fa scattare Died.
	humanoid.Health = math.max(0, humanoid.Health - quantita)
	if humanoid.Health <= 0 then
		nemico:SetAttribute("Sconfitto", true)
		eventoSconfitto:Fire(nemico, attaccante)
	end
end

-- Barra della vita sopra ogni nemico (BillboardGui "BarraVita" con TextLabel "TestoVita").
local function collegaBarraVita(nemico)
	local humanoid = nemico:FindFirstChildOfClass("Humanoid") or nemico:WaitForChild("Humanoid", 5)
	local testo = nemico:FindFirstChild("TestoVita", true)
	if not humanoid or not testo then
		return
	end
	local nome = nemico:GetAttribute("NomeVisibile") or nemico.Name
	local function aggiorna()
		testo.Text = string.upper(nome) .. "   " .. math.ceil(humanoid.Health) .. " / " .. humanoid.MaxHealth
	end
	humanoid.HealthChanged:Connect(aggiorna)
	aggiorna()
end

-- Effetti visivi ------------------------------------------------------------------

local function parteEffetto(nome, dimensione, cframe, colore, forma)
	local parte = Instance.new("Part")
	parte.Name = nome
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
	parte.Parent = cartellaEffetti
	return parte
end

local function effettoProiettile(da, a, colore)
	local sfera = parteEffetto("Proiettile", Vector3.new(1.4, 1.4, 1.4), CFrame.new(da), colore, Enum.PartType.Ball)
	local durata = math.clamp((a - da).Magnitude / 110, 0.08, 1)
	TweenService:Create(sfera, TweenInfo.new(durata, Enum.EasingStyle.Linear), { Position = a }):Play()
	Debris:AddItem(sfera, durata + 0.1)
end

local function effettoOnda(centro, raggio, colore)
	local sfera = parteEffetto("Onda", Vector3.new(2, 2, 2), CFrame.new(centro), colore, Enum.PartType.Ball)
	sfera.Transparency = 0.35
	local fine = Vector3.new(raggio * 2, raggio * 2, raggio * 2)
	TweenService:Create(sfera, TweenInfo.new(0.35), { Size = fine, Transparency = 1 }):Play()
	Debris:AddItem(sfera, 0.4)
end

local function effettoFulmine(centro, raggio, colore)
	local colonna = parteEffetto("Fulmine", Vector3.new(1.5, 30, 1.5), CFrame.new(centro + Vector3.new(0, 15, 0)), colore)
	TweenService:Create(colonna, TweenInfo.new(0.3), { Size = Vector3.new(4, 30, 4), Transparency = 1 }):Play()
	Debris:AddItem(colonna, 0.35)
	effettoOnda(centro, raggio, colore)
end

-- Abilità ------------------------------------------------------------------------

local abilita = {}

function abilita.Proiettile(player, radice, mira, dati, classe)
	local direzione = mira - radice.Position
	direzione = direzione.Magnitude > 1 and direzione.Unit or radice.CFrame.LookVector
	local origine = radice.Position + direzione * 2

	local parametri = RaycastParams.new()
	parametri.FilterType = Enum.RaycastFilterType.Exclude
	parametri.FilterDescendantsInstances = { player.Character, cartellaEffetti }
	local risultato = Workspace:Raycast(origine, direzione * dati.portata, parametri)

	local arrivo = risultato and risultato.Position or (origine + direzione * dati.portata)
	effettoProiettile(origine, arrivo, classe.colore)
	local nemico = risultato and nemicoDaParte(risultato.Instance)
	if nemico then
		CombatService.Danneggia(nemico, dati.danno * moltiplicatoreDanno(player), player)
	end
end

function abilita.Area(player, radice, _mira, dati, classe)
	local centro = radice.Position
	effettoOnda(centro, dati.raggio, classe.colore)
	for _, nemico in ipairs(nemiciNelRaggio(centro, dati.raggio)) do
		CombatService.Danneggia(nemico, dati.danno * moltiplicatoreDanno(player), player)
	end
end

function abilita.Scatto(player, radice, _mira, dati, classe)
	-- Lo scatto vero lo fa il client (controlla lui la fisica del personaggio):
	-- il server aspetta che arrivi e colpisce dove si trova.
	task.delay(0.18, function()
		if not radice.Parent then
			return
		end
		local centro = radice.Position + radice.CFrame.LookVector * 3
		effettoOnda(centro, dati.raggio, classe.colore)
		for _, nemico in ipairs(nemiciNelRaggio(centro, dati.raggio)) do
			CombatService.Danneggia(nemico, dati.danno * moltiplicatoreDanno(player), player)
		end
	end)
end

function abilita.AreaRemota(player, radice, mira, dati, classe)
	local offset = mira - radice.Position
	if offset.Magnitude > dati.portata then
		mira = radice.Position + offset.Unit * dati.portata
	end
	effettoFulmine(mira, dati.raggio, classe.colore)
	for _, nemico in ipairs(nemiciNelRaggio(mira, dati.raggio)) do
		CombatService.Danneggia(nemico, dati.danno * moltiplicatoreDanno(player), player)
	end
end

local function usaAbilita(player, mira)
	if typeof(mira) ~= "Vector3" or mira ~= mira then -- mira ~= mira scarta i NaN
		return
	end
	local dati = PlayerData.Ottieni(player)
	local character = player.Character
	local radice = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not dati or not radice or not humanoid or humanoid.Health <= 0 then
		return
	end
	-- Serve avere l'arma della propria classe in mano.
	local arma = character:FindFirstChildOfClass("Tool")
	if not arma or arma:GetAttribute("ArmaClasse") ~= dati.Classe then
		return
	end
	if (mira - radice.Position).Magnitude > DISTANZA_MASSIMA_MIRA then
		return
	end

	local classe = Classi.Dati[dati.Classe]
	local datiAbilita = classe.abilita
	local ora = os.clock()
	local ricarica = datiAbilita.ricarica
	local furia = Effetti.Attivo(player, "Furia")
	if furia then
		ricarica *= furia.ricaricaAttacco
	end
	-- Piccola tolleranza per la latenza di rete.
	if ora - (ultimoUso[player] or 0) < ricarica * 0.9 then
		return
	end
	ultimoUso[player] = ora

	-- Attaccare rompe il Velo d'Ombra, ma questo colpo fa danno moltiplicato.
	local velo = Effetti.Attivo(player, "Velo")
	if velo then
		Effetti.Rimuovi(player, "Velo")
		bonusColpo[player] = velo.colpo
		task.delay(0.6, function()
			bonusColpo[player] = nil
		end)
	end
	abilita[datiAbilita.tipo](player, radice, mira, datiAbilita, classe)
end

-- Armi -----------------------------------------------------------------------------

local function daiArma(player)
	local dati = PlayerData.Ottieni(player)
	local character = player.Character
	local zaino = player:FindFirstChildOfClass("Backpack")
	if not dati or not character or not zaino then
		return
	end

	local eraImpugnata = false
	for _, contenitore in ipairs({ zaino, character }) do
		for _, oggetto in ipairs(contenitore:GetChildren()) do
			if oggetto:IsA("Tool") and oggetto:GetAttribute("ArmaClasse") then
				eraImpugnata = eraImpugnata or contenitore == character
				oggetto:Destroy()
			end
		end
	end

	local classe = Classi.Dati[dati.Classe]
	local arma = Instance.new("Tool")
	arma.Name = classe.armaBase
	arma.ToolTip = classe.abilita.nome
	arma.CanBeDropped = false
	arma:SetAttribute("ArmaClasse", dati.Classe)

	-- L'arma brilla del colore della rarità dell'arma indossata: si nota in Piazza.
	local equipaggiata = InventarioService.Equipaggiato(player, "Arma")
	local rarita = equipaggiata and Rarita.Dati[equipaggiata.rarita]

	local impugnatura = Instance.new("Part")
	impugnatura.Name = "Handle"
	impugnatura.Size = Vector3.new(0.6, 0.6, 3.5)
	impugnatura.Color = rarita and rarita.colore or classe.colore
	impugnatura.Material = Enum.Material.Neon
	impugnatura.CanCollide = false
	impugnatura.Massless = true
	impugnatura.Parent = arma

	arma.Parent = zaino
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if eraImpugnata and humanoid then
		humanoid:EquipTool(arma)
	end
end

function CombatService.Avvia()
	cartellaEffetti = Instance.new("Folder")
	cartellaEffetti.Name = "Effetti"
	cartellaEffetti.Parent = Workspace

	Remotes.UsaAbilita.OnServerEvent:Connect(usaAbilita)

	local function collegaGiocatore(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 5)
			player:WaitForChild("Backpack", 5)
			daiArma(player)
		end)
		if player.Character then
			daiArma(player)
		end
	end
	PlayerData.Caricato:Connect(collegaGiocatore)
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerData.Pronto(player) then
			collegaGiocatore(player)
		end
	end

	-- Ricrea l'arma solo se cambia la classe o l'arma indossata (non a ogni vendita).
	local armaIndossata = {} -- [Player] = id
	PlayerData.Cambiato:Connect(function(player, sezione)
		if sezione == "Classe" then
			daiArma(player)
		elseif sezione == "Inventario" then
			local equipaggiata = InventarioService.Equipaggiato(player, "Arma")
			local id = equipaggiata and equipaggiata.id or false
			if armaIndossata[player] ~= id then
				armaIndossata[player] = id
				daiArma(player)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		ultimoUso[player] = nil
		armaIndossata[player] = nil
		bonusColpo[player] = nil
	end)

	CollectionService:GetInstanceAddedSignal(TAG_NEMICO):Connect(function(nemico)
		task.spawn(collegaBarraVita, nemico)
	end)
	for _, nemico in ipairs(CollectionService:GetTagged(TAG_NEMICO)) do
		task.spawn(collegaBarraVita, nemico)
	end
end

return CombatService
