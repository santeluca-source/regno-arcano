-- ViaggiService: il menu Viaggi (tasto M).
--   - teletrasporto alla Piazza o alla propria isola (Base), anche da dentro un dungeon
--   - ingresso diretto in un dungeon già sbloccato (serve il suo portale sull'isola)
-- Il client chiede, il server controlla requisiti e attese tra un viaggio e l'altro.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Dungeon = require(Config.Dungeon)
local Tycoon = require(Config.Tycoon)
local PlayerData = require(script.Parent.PlayerData)
local TycoonService = require(script.Parent.TycoonService)
local DungeonService = require(script.Parent.DungeonService)
local Isole = require(script.Parent.Parent.Tycoon.Isole)

local Remotes = ReplicatedStorage.Remotes

local ATTESA_TRA_VIAGGI = 3

local ViaggiService = {}

local ultimoViaggio = {} -- [Player] = os.clock()
local rng = Random.new()

local function notifica(player, testo)
	Remotes.Notifica:FireClient(player, testo)
end

local function haPortale(player, config)
	local dati = PlayerData.Ottieni(player)
	return dati ~= nil and dati.Tycoon.Acquisti[config.portale] == true
end

-- Un punto libero nella Piazza, attorno alla fontana, rivolto verso il centro.
local function puntoNellaPiazza()
	local angolo = rng:NextNumber(0, math.pi * 2)
	local raggio = rng:NextNumber(20, 30)
	local posizione = Vector3.new(math.cos(angolo) * raggio, Isole.Altezza + 3, math.sin(angolo) * raggio)
	return CFrame.lookAt(posizione, Vector3.new(0, posizione.Y, 0))
end

-- Elenco per il menu: tutti i dungeon, con lo stato di sblocco di questo giocatore.
local function elenco(player)
	local risultato = {}
	for _, id in ipairs(Dungeon.Ordine) do
		local config = Dungeon.Elenco[id]
		local portale = Tycoon.Oggetti[config.portale]
		table.insert(risultato, {
			id = id,
			nome = config.nome,
			descrizione = config.descrizione,
			difficolta = config.difficolta,
			colore = config.colore,
			boss = Dungeon.Nemici[config.boss].nome,
			sbloccato = haPortale(player, config),
			requisito = portale and ("Costruisci il " .. portale.nome .. " sulla tua isola") or "",
		})
	end
	return risultato
end

local destinazioni = {}

function destinazioni.Piazza(player, character)
	if DungeonService.InDungeon(player) then
		DungeonService.Esci(player)
	end
	character:PivotTo(puntoNellaPiazza())
	return true
end

function destinazioni.Base(player)
	if DungeonService.InDungeon(player) then
		DungeonService.Esci(player)
	end
	TycoonService.PortaSullIsola(player)
	return true
end

function destinazioni.Dungeon(player, _character, id)
	local config = type(id) == "string" and Dungeon.Elenco[id]
	if not config then
		return false
	end
	if DungeonService.InDungeon(player) then
		notifica(player, "Sei già in un dungeon: torna prima alla Base o alla Piazza.")
		return false
	end
	if not haPortale(player, config) then
		notifica(player, "Per entrare devi prima costruire il " .. Tycoon.Oggetti[config.portale].nome .. ".")
		return false
	end
	return DungeonService.Entra({ player }, id)
end

local function viaggia(player, tipo, id)
	local destinazione = type(tipo) == "string" and destinazioni[tipo]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not destinazione or not humanoid or humanoid.Health <= 0 or not PlayerData.Pronto(player) then
		return
	end
	local ora = os.clock()
	local attesa = ATTESA_TRA_VIAGGI - (ora - (ultimoViaggio[player] or -math.huge))
	if attesa > 0 then
		notifica(player, string.format("Aspetta ancora %d secondi prima di viaggiare.", math.ceil(attesa)))
		return
	end
	if destinazione(player, character, id) then
		ultimoViaggio[player] = ora
	end
end

function ViaggiService.Avvia()
	Remotes.Viaggia.OnServerEvent:Connect(viaggia)
	Remotes.ElencoDungeon.OnServerInvoke = elenco
	Players.PlayerRemoving:Connect(function(player)
		ultimoViaggio[player] = nil
	end)
end

return ViaggiService
