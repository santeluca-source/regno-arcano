-- PiazzaService: la zona condivisa al centro del mondo.
--   Mercante  -> casse con oggetti casuali in cambio di Oro o Frammenti
--   Bacheca   -> missioni (la logica è in MissioniService)
--   Gilda     -> spedizioni di gruppo nei dungeon
--   Fabbro    -> apre l'inventario per migliorare gli oggetti (logica in InventarioService)
--   Alchimista-> vende pozioni (logica in PozioniService)
--   Targhette -> sopra ogni giocatore: nome, classe e arma indossata, per mettersi in mostra

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local ConfigPiazza = require(Config.Piazza)
local Classi = require(Config.Classi)
local Rarita = require(Config.Rarita)
local Tycoon = require(Config.Tycoon)
local PlayerData = require(script.Parent.PlayerData)
local InventarioService = require(script.Parent.InventarioService)
local DungeonService = require(script.Parent.DungeonService)
local MissioniService = require(script.Parent.MissioniService)
local PozioniService = require(script.Parent.PozioniService)
local Pozioni = require(Config.Pozioni)
local CostruttorePiazza = require(script.Parent.Parent.Piazza.CostruttorePiazza)

local Remotes = ReplicatedStorage.Remotes

local PiazzaService = {}

local piazza
local rng = Random.new()
local ultimoAcquisto = {} -- [Player] = os.clock()

local function notifica(player, testo)
	Remotes.Notifica:FireClient(player, testo)
end

-- Mercante -------------------------------------------------------------------------

local function compra(player, offerta)
	local ora = os.clock()
	if ora - (ultimoAcquisto[player] or 0) < 1 then
		return
	end
	ultimoAcquisto[player] = ora
	if not PlayerData.Spendi(player, offerta.costo) then
		notifica(player, "Ti servono " .. Tycoon.TestoCosto(offerta.costo) .. " per la " .. offerta.nome)
		return
	end
	local oggetto = InventarioService.Genera(InventarioService.SlotCasuale(), Rarita.Estrai(offerta.tabella, rng), "del Mercante")
	InventarioService.Aggiungi(player, oggetto)
	task.spawn(PlayerData.Salva, player)
end

-- Gilda ---------------------------------------------------------------------------

local function avviaSpedizione(capo, spedizione)
	local dati = PlayerData.Ottieni(capo)
	if not dati then
		return
	end
	local requisito = spedizione.richiede
	if not dati.Tycoon.Acquisti[requisito] then
		notifica(capo, "Per guidare una spedizione devi costruire il " .. Tycoon.Oggetti[requisito].nome .. " sulla tua isola.")
		return
	end
	if DungeonService.InDungeon(capo) then
		return
	end

	-- Il gruppo: il capo più chi sta sul cerchio, fino al massimo.
	local pedana = piazza.PedanaGilda
	local gruppo = { capo }
	for _, player in ipairs(Players:GetPlayers()) do
		if #gruppo >= ConfigPiazza.Gilda.massimoGiocatori then
			break
		end
		local character = player.Character
		local radice = character and character:FindFirstChild("HumanoidRootPart")
		if player ~= capo and radice and not DungeonService.InDungeon(player) then
			local distanza = (radice.Position - pedana.Position) * Vector3.new(1, 0, 1)
			if distanza.Magnitude <= ConfigPiazza.Gilda.raggioPedana then
				table.insert(gruppo, player)
			end
		end
	end

	if #gruppo > 1 then
		local nomi = {}
		for _, player in ipairs(gruppo) do
			table.insert(nomi, player.DisplayName)
		end
		for _, player in ipairs(gruppo) do
			notifica(player, "Spedizione in partenza: " .. table.concat(nomi, ", "))
		end
	end
	DungeonService.Entra(gruppo, spedizione.dungeon)
end

-- Targhette -------------------------------------------------------------------------

local function aggiornaTarghetta(player)
	local character = player.Character
	local testa = character and character:FindFirstChild("Head")
	local targhetta = testa and testa:FindFirstChild("Targhetta")
	if not targhetta then
		return
	end
	local classe = Classi.Dati[player:GetAttribute("Classe") or ""]
	local rarita = Rarita.Dati[player:GetAttribute("ArmaRarita") or ""]

	targhetta.Nome.Text = player.DisplayName
	targhetta.Classe.Text = classe and string.upper(player:GetAttribute("Classe")) or ""
	targhetta.Classe.TextColor3 = classe and classe.colore or Color3.new(1, 1, 1)
	targhetta.Arma.Text = rarita and ("Arma " .. rarita.nomeF) or ""
	targhetta.Arma.TextColor3 = rarita and rarita.colore or Color3.new(1, 1, 1)
end

local function creaTarghetta(player, character)
	local testa = character:WaitForChild("Head", 5)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not testa or not humanoid then
		return
	end
	-- Nascondiamo il nome standard: lo mostra già la targhetta.
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Targhetta"
	billboard.Size = UDim2.fromOffset(200, 54)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.MaxDistance = 80

	local righe = {
		{ "Nome", 20, Enum.Font.GothamBold },
		{ "Classe", 15, Enum.Font.GothamBold },
		{ "Arma", 14, Enum.Font.Gotham },
	}
	local y = 0
	for _, riga in ipairs(righe) do
		local testo = Instance.new("TextLabel")
		testo.Name = riga[1]
		testo.Position = UDim2.fromOffset(0, y)
		testo.Size = UDim2.new(1, 0, 0, riga[2])
		testo.BackgroundTransparency = 1
		testo.TextColor3 = Color3.new(1, 1, 1)
		testo.TextStrokeTransparency = 0.4
		testo.TextScaled = true
		testo.Font = riga[3]
		testo.Text = ""
		testo.Parent = billboard
		y += riga[2] + 2
	end
	billboard.Parent = testa
	aggiornaTarghetta(player)
end

local function collegaTarghette(player)
	player.CharacterAdded:Connect(function(character)
		creaTarghetta(player, character)
	end)
	if player.Character then
		task.spawn(creaTarghetta, player, player.Character)
	end
	for _, attributo in ipairs({ "Classe", "ArmaRarita" }) do
		player:GetAttributeChangedSignal(attributo):Connect(function()
			aggiornaTarghetta(player)
		end)
	end
end

-- Avvio ------------------------------------------------------------------------------

function PiazzaService.Avvia()
	piazza = CostruttorePiazza.Genera()

	for _, offerta in ipairs(ConfigPiazza.Offerte) do
		local piedistallo = piazza:FindFirstChild("Offerta_" .. offerta.id)
		piedistallo.PromptOfferta.Triggered:Connect(function(player)
			compra(player, offerta)
		end)
	end
	piazza.Bacheca.PromptBacheca.Triggered:Connect(MissioniService.Bacheca)

	-- Fabbro: apre l'inventario del giocatore in modalità Fabbro.
	piazza.Incudine.PromptFabbro.Triggered:Connect(function(player)
		Remotes.ApriFabbro:FireClient(player)
	end)
	-- Alchimista: un piedistallo per ogni pozione.
	for _, id in ipairs(Pozioni.Ordine) do
		piazza["Pozione_" .. id].PromptPozione.Triggered:Connect(function(player)
			PozioniService.Compra(player, id)
		end)
	end
	for _, spedizione in ipairs(ConfigPiazza.Gilda.spedizioni) do
		piazza.VeloGilda["PromptGilda_" .. spedizione.dungeon].Triggered:Connect(function(capo)
			avviaSpedizione(capo, spedizione)
		end)
	end

	Players.PlayerAdded:Connect(collegaTarghette)
	for _, player in ipairs(Players:GetPlayers()) do
		collegaTarghette(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ultimoAcquisto[player] = nil
	end)
end

return PiazzaService
