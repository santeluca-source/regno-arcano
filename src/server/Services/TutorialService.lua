-- TutorialService: la guida passo passo per i nuovi giocatori (Config/Tutorial.lua).
-- Il passo attuale è salvato in PlayerData.Tutorial (numero; oltre l'ultimo = finito)
-- e mostrato al client con l'attributo "Tutorial".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Tutorial = require(Config.Tutorial)
local ConfigPiazza = require(Config.Piazza)
local Tycoon = require(Config.Tycoon)
local PlayerData = require(script.Parent.PlayerData)
local TycoonService = require(script.Parent.TycoonService)
local CombatService = require(script.Parent.CombatService)
local AbilitaService = require(script.Parent.AbilitaService)
local DungeonService = require(script.Parent.DungeonService)

local Remotes = ReplicatedStorage.Remotes
local Passi = Tutorial.Passi

local TutorialService = {}

local function passoAttuale(player)
	local dati = PlayerData.Ottieni(player)
	local numero = dati and dati.Tutorial
	return numero, numero and Passi[numero]
end

local function rispecchia(player)
	local numero, passo = passoAttuale(player)
	player:SetAttribute("Tutorial", passo and ("Passo " .. numero .. "/" .. #Passi .. ":  " .. passo.testo) or nil)
end

-- Avanza se l'evento corrisponde al passo attuale.
local function evento(player, nome, dettaglio)
	local numero, passo = passoAttuale(player)
	if not passo or passo.evento ~= nome then
		return
	end
	local richiesto = passo.oggetto or passo.dungeon
	if richiesto and richiesto ~= dettaglio then
		return
	end
	for valuta, quantita in pairs(passo.ricompensa) do
		PlayerData.AggiungiValuta(player, valuta, quantita)
	end
	PlayerData.Modifica(player, "Tutorial", function(dati)
		dati.Tutorial = numero + 1
	end)
	rispecchia(player)
	local fine = numero + 1 > #Passi
	Remotes.Notifica:FireClient(player, (fine and "Guida completata! " or "Passo completato! ")
		.. "+" .. Tycoon.TestoCosto(passo.ricompensa))
	-- Alcuni passi potrebbero essere già fatti (es. oggetto comprato prima): controlliamo subito.
	local _, prossimo = passoAttuale(player)
	local dati = PlayerData.Ottieni(player)
	if prossimo and prossimo.evento == "Acquisto" and dati.Tycoon.Acquisti[prossimo.oggetto] then
		evento(player, "Acquisto", prossimo.oggetto)
	end
end

-- Al caricamento: i giocatori esperti saltano la guida; gli altri saltano i passi
-- di costruzione già fatti.
local function alCaricamento(player)
	local dati = PlayerData.Ottieni(player)
	if not dati then
		return
	end
	if dati.Tycoon.Acquisti[Tutorial.SaltaSePossiede] and dati.Tutorial <= #Passi then
		PlayerData.Modifica(player, "Tutorial", function(d)
			d.Tutorial = #Passi + 1
		end)
	end
	rispecchia(player)
	local _, passo = passoAttuale(player)
	if passo and passo.evento == "Acquisto" and dati.Tycoon.Acquisti[passo.oggetto] then
		evento(player, "Acquisto", passo.oggetto)
	end
end

local function nellaPiazza(player)
	local character = player.Character
	local radice = character and character:FindFirstChild("HumanoidRootPart")
	return radice ~= nil and (radice.Position * Vector3.new(1, 0, 1)).Magnitude <= ConfigPiazza.Raggio
		and radice.Position.Y < 40
end

function TutorialService.Avvia()
	TycoonService.Acquistato:Connect(function(player, id)
		evento(player, "Acquisto", id)
	end)
	TycoonService.Incassato:Connect(function(player)
		evento(player, "Incasso")
	end)
	CombatService.Colpito:Connect(function(nemico, attaccante)
		if nemico:GetAttribute("Manichino") then
			evento(attaccante, "ColpoGolem")
		end
	end)
	AbilitaService.Usata:Connect(function(player)
		evento(player, "Speciale")
	end)
	DungeonService.Completato:Connect(function(giocatori, idDungeon)
		for _, player in ipairs(giocatori) do
			evento(player, "Dungeon", idDungeon)
		end
	end)

	PlayerData.Caricato:Connect(alCaricamento)
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerData.Pronto(player) then
			alCaricamento(player)
		end
	end

	-- Il passo "Piazza" si controlla guardando dove si trova il giocatore.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local _, passo = passoAttuale(player)
				if passo and passo.evento == "Piazza" and nellaPiazza(player) then
					evento(player, "Piazza")
				end
			end
		end
	end)
end

return TutorialService
