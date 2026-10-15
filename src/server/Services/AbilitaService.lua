-- AbilitaService: la seconda abilità di ogni classe (tasto Q).
-- I numeri di ogni abilità sono in Config/Classi.lua (campo `speciale`).
-- Gli effetti che durano nel tempo (Scudo, Furia, Velo, Protezione) passano dal
-- modulo Effetti e vengono applicati da CombatService quando si dà o si subisce danno.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Classi = require(ReplicatedStorage.Shared.Config.Classi)
local PlayerData = require(script.Parent.PlayerData)
local CombatService = require(script.Parent.CombatService)
local Effetti = require(script.Parent.Parent.Combattimento.Effetti)
local Nemici = require(script.Parent.Parent.Dungeon.Nemici)

local Remotes = ReplicatedStorage.Remotes

local INTERVALLO_SERVITORI = 0.25
local DISTANZA_RICERCA_SERVITORE = 80

local AbilitaService = {}

local eventoUsata = Instance.new("BindableEvent")
-- Scatta quando un giocatore usa la sua abilità speciale: (player, idClasse)
AbilitaService.Usata = eventoUsata.Event

local ultimoSpeciale = {} -- [Player] = os.clock()
local servitori = {} -- [Player] = { modello, fine, prossimoAttacco, def }
local cartellaAlleati

local function notifica(player, testo)
	Remotes.Notifica:FireClient(player, testo)
end

local function onda(centro, raggio, colore)
	local sfera = Instance.new("Part")
	sfera.Shape = Enum.PartType.Ball
	sfera.Size = Vector3.new(2, 2, 2)
	sfera.CFrame = CFrame.new(centro)
	sfera.Color = colore
	sfera.Material = Enum.Material.Neon
	sfera.Transparency = 0.4
	sfera.Anchored = true
	sfera.CanCollide = false
	sfera.CanTouch = false
	sfera.CanQuery = false
	sfera.Parent = Workspace.Effetti
	TweenService:Create(sfera, TweenInfo.new(0.5), { Size = Vector3.one * raggio * 2, Transparency = 1 }):Play()
	Debris:AddItem(sfera, 0.55)
end

-- Giocatori vivi entro un raggio (compreso chi usa l'abilità).
local function giocatoriVicini(centro, raggio)
	local vicini = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local radice = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if radice and humanoid and humanoid.Health > 0 and (radice.Position - centro).Magnitude <= raggio then
			table.insert(vicini, { player = player, humanoid = humanoid })
		end
	end
	return vicini
end

-- Servitori ---------------------------------------------------------------------

local function rimuoviServitore(player)
	local servitore = servitori[player]
	servitori[player] = nil
	if servitore and servitore.modello.Parent then
		servitore.modello:Destroy()
	end
end

local function nemicoPiuVicino(posizione)
	local migliore, distanzaMigliore = nil, DISTANZA_RICERCA_SERVITORE
	for _, nemico in ipairs(CollectionService:GetTagged(CombatService.TagNemico)) do
		local humanoid = nemico:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not nemico:GetAttribute("Sconfitto") and nemico:IsDescendantOf(Workspace) then
			local distanza = (nemico:GetPivot().Position - posizione).Magnitude
			if distanza < distanzaMigliore then
				migliore, distanzaMigliore = nemico, distanza
			end
		end
	end
	return migliore, distanzaMigliore
end

local function aggiornaServitore(player, servitore, ora)
	local modello = servitore.modello
	local humanoid = modello:FindFirstChildOfClass("Humanoid")
	local radice = modello.PrimaryPart
	if ora >= servitore.fine or not humanoid or not radice or not modello.Parent then
		rimuoviServitore(player)
		return
	end
	local def = servitore.def
	local bersaglio, distanza = nemicoPiuVicino(radice.Position)
	if bersaglio then
		if distanza > def.portata * 0.8 then
			humanoid:MoveTo(bersaglio:GetPivot().Position)
		else
			humanoid:MoveTo(radice.Position)
		end
		if distanza <= def.portata + 2 and ora >= servitore.prossimoAttacco then
			servitore.prossimoAttacco = ora + def.ricarica
			onda(bersaglio:GetPivot().Position, 3, def.colore)
			CombatService.Danneggia(bersaglio, def.danno, player)
		end
		return
	end
	-- Nessun nemico: segue il padrone.
	local character = player.Character
	local radicePadrone = character and character:FindFirstChild("HumanoidRootPart")
	if radicePadrone and (radicePadrone.Position - radice.Position).Magnitude > 8 then
		humanoid:MoveTo(radicePadrone.Position)
	end
end

-- Le sei abilità -----------------------------------------------------------------

local speciali = {}

function speciali.Scudo(player, _character, def, classe)
	Effetti.Aggiungi(player, "Scudo", def.durata, { rimanente = def.assorbe }, classe.colore)
end

function speciali.Furia(player, _character, def, classe)
	Effetti.Aggiungi(player, "Furia", def.durata,
		{ danno = def.danno, ricaricaAttacco = def.ricaricaAttacco, dannoSubito = def.dannoSubito }, classe.colore)
end

function speciali.Velo(player, character, def)
	-- Il personaggio diventa quasi trasparente per tutti.
	local originali = {}
	for _, parte in ipairs(character:GetDescendants()) do
		if (parte:IsA("BasePart") or parte:IsA("Decal")) and parte.Transparency < 1 then
			originali[parte] = parte.Transparency
			parte.Transparency = 0.85
		end
	end
	Effetti.Aggiungi(player, "Velo", def.durata, { colpo = def.colpo }, nil, function()
		for parte, trasparenza in pairs(originali) do
			if parte.Parent then
				parte.Transparency = trasparenza
			end
		end
	end)
end

function speciali.Evoca(player, character, def)
	rimuoviServitore(player)
	local radice = character.HumanoidRootPart
	local terreno = CFrame.new(radice.Position + radice.CFrame.RightVector * 4 - Vector3.new(0, 3, 0))
	local modello = Nemici.Crea(cartellaAlleati, "Servitore", def.servitore, terreno, 100, true)
	onda(radice.Position, 6, def.servitore.colore)
	servitori[player] = {
		modello = modello,
		fine = os.clock() + def.durata,
		prossimoAttacco = 0,
		def = def.servitore,
	}
end

function speciali.Aura(player, character, def, classe)
	local centro = character.HumanoidRootPart.Position
	onda(centro, def.raggio, classe.colore)
	for _, vicino in ipairs(giocatoriVicini(centro, def.raggio)) do
		Effetti.Aggiungi(vicino.player, "Protezione", def.durata, { riduzione = def.riduzione }, classe.colore)
		if vicino.player ~= player then
			notifica(vicino.player, player.DisplayName .. " ti protegge con l'Aura Sacra!")
		end
	end
end

function speciali.Cura(player, character, def)
	local centro = character.HumanoidRootPart.Position
	onda(centro, def.raggio, Color3.fromRGB(92, 220, 139))
	for _, vicino in ipairs(giocatoriVicini(centro, def.raggio)) do
		local humanoid = vicino.humanoid
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * def.cura)
		if vicino.player ~= player then
			notifica(vicino.player, player.DisplayName .. " ti ha curato!")
		end
	end
end

local function usaSpeciale(player)
	local dati = PlayerData.Ottieni(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not dati or not humanoid or humanoid.Health <= 0 or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	local classe = Classi.Dati[dati.Classe]
	local def = classe.speciale
	local ora = os.clock()
	if ora - (ultimoSpeciale[player] or -math.huge) < def.ricarica * 0.95 then
		return
	end
	ultimoSpeciale[player] = ora
	speciali[def.tipo](player, character, def, classe)
	Remotes.SpecialeUsato:FireClient(player, def.nome, def.ricarica)
	eventoUsata:Fire(player, dati.Classe)
end

function AbilitaService.Avvia()
	cartellaAlleati = Instance.new("Folder")
	cartellaAlleati.Name = "Alleati"
	cartellaAlleati.Parent = Workspace

	Remotes.UsaSpeciale.OnServerEvent:Connect(usaSpeciale)

	-- Cambiare classe azzera la ricarica: ogni classe ha la sua abilità.
	PlayerData.Cambiato:Connect(function(player, sezione)
		if sezione == "Classe" then
			ultimoSpeciale[player] = nil
			rimuoviServitore(player)
		end
	end)

	local function collega(player)
		player.CharacterRemoving:Connect(function()
			rimuoviServitore(player)
		end)
	end
	Players.PlayerAdded:Connect(collega)
	for _, player in ipairs(Players:GetPlayers()) do
		collega(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		rimuoviServitore(player)
		ultimoSpeciale[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(INTERVALLO_SERVITORI)
			local ora = os.clock()
			for player, servitore in pairs(servitori) do
				aggiornaServitore(player, servitore, ora)
			end
		end
	end)
end

return AbilitaService
