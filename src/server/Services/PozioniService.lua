-- PozioniService: comprare e bere pozioni.
-- Le pozioni possedute sono in PlayerData.Pozioni ({ Cura = 3, Forza = 1, ... }) e vengono
-- mostrate al client come attributi "Pozione_<id>". I numeri sono in Config/Pozioni.lua.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Pozioni = require(Config.Pozioni)
local Tycoon = require(Config.Tycoon)
local PlayerData = require(script.Parent.PlayerData)
local Effetti = require(script.Parent.Parent.Combattimento.Effetti)

local Remotes = ReplicatedStorage.Remotes

local PozioniService = {}

local ultimoUso = {} -- [Player] = { [id] = os.clock() }

local function notifica(player, testo)
	Remotes.Notifica:FireClient(player, testo)
end

local function quantita(player, id)
	local dati = PlayerData.Ottieni(player)
	return dati and dati.Pozioni[id] or 0
end

local function rispecchia(player)
	for _, id in ipairs(Pozioni.Ordine) do
		player:SetAttribute("Pozione_" .. id, quantita(player, id))
	end
end

-- Chiamata dalla Piazza quando il giocatore compra all'Alchimista.
function PozioniService.Compra(player, id)
	local def = Pozioni.Dati[id]
	if not def or not PlayerData.Pronto(player) then
		return
	end
	if quantita(player, id) >= def.massimo then
		notifica(player, "Puoi portare al massimo " .. def.massimo .. " " .. def.nome)
		return
	end
	if not PlayerData.Spendi(player, def.costo) then
		notifica(player, "Ti servono " .. Tycoon.TestoCosto(def.costo) .. " per la " .. def.nome)
		return
	end
	PlayerData.Modifica(player, "Pozioni", function(dati)
		dati.Pozioni[id] = (dati.Pozioni[id] or 0) + 1
	end)
	notifica(player, def.nome .. " comprata (" .. quantita(player, id) .. ")")
end

local function bevi(player, id)
	local def = type(id) == "string" and Pozioni.Dati[id]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not def or not humanoid or humanoid.Health <= 0 or quantita(player, id) <= 0 then
		return
	end
	ultimoUso[player] = ultimoUso[player] or {}
	local ora = os.clock()
	if ora - (ultimoUso[player][id] or -math.huge) < def.ricarica * 0.95 then
		return
	end
	ultimoUso[player][id] = ora

	PlayerData.Modifica(player, "Pozioni", function(dati)
		dati.Pozioni[id] -= 1
	end)
	if def.tipo == "Cura" then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * def.valore)
	else
		Effetti.Aggiungi(player, def.effetto, def.durata, { valore = def.valore }, def.colore)
	end
	Remotes.PozioneUsata:FireClient(player, id, def.ricarica)
end

function PozioniService.Avvia()
	Remotes.UsaPozione.OnServerEvent:Connect(bevi)

	PlayerData.Caricato:Connect(rispecchia)
	PlayerData.Cambiato:Connect(function(player, sezione)
		if sezione == "Pozioni" then
			rispecchia(player)
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerData.Pronto(player) then
			rispecchia(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		ultimoUso[player] = nil
	end)
end

return PozioniService
