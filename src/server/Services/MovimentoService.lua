-- MovimentoService: la parte server di corsa e scatto.
-- Il movimento lo fa il client (controlla lui il proprio personaggio); qui:
--   - diamo l'invulnerabilità ("Schivata") per la durata dello scatto, con una
--     ricarica controllata dal server così non si può restare invulnerabili di continuo
--   - pubblichiamo sul personaggio gli attributi "Corsa" e "InScatto", così ogni
--     client può animare anche gli ALTRI giocatori (pose e immagini residue)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Movimento = require(ReplicatedStorage.Shared.Config.Movimento)
local Effetti = require(script.Parent.Parent.Combattimento.Effetti)

local Remotes = ReplicatedStorage.Remotes
local Scatto = Movimento.Scatto

local MovimentoService = {}

local ultimoScatto = {} -- [Player] = os.clock()
local ultimoCambioCorsa = {} -- [Player] = os.clock()

local function scatto(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local ora = os.clock()
	-- La ricarica minima vera è durata + ricarica; teniamo un margine per la rete.
	if ora - (ultimoScatto[player] or -math.huge) < (Scatto.durata + Scatto.ricarica) * 0.85 then
		return
	end
	ultimoScatto[player] = ora
	Effetti.Aggiungi(player, "Schivata", Scatto.durata + 0.1, {})
	character:SetAttribute("InScatto", true)
	task.delay(Scatto.durata, function()
		if character.Parent then
			character:SetAttribute("InScatto", false)
		end
	end)
end

local function corsa(player, attiva)
	if type(attiva) ~= "boolean" then
		return
	end
	local ora = os.clock()
	if ora - (ultimoCambioCorsa[player] or -math.huge) < 0.1 then
		return
	end
	ultimoCambioCorsa[player] = ora
	local character = player.Character
	if character then
		character:SetAttribute("Corsa", attiva)
	end
end

function MovimentoService.Avvia()
	Remotes.Scatto.OnServerEvent:Connect(scatto)
	Remotes.Corsa.OnServerEvent:Connect(corsa)
	Players.PlayerRemoving:Connect(function(player)
		ultimoScatto[player] = nil
		ultimoCambioCorsa[player] = nil
	end)
end

return MovimentoService
