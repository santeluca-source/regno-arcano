-- MovimentoService: la parte server della capriola.
-- Il movimento lo fa il client (controlla lui il proprio personaggio); qui diamo
-- l'invulnerabilità ("Schivata") per la durata della capriola, con una ricarica
-- controllata dal server così non si può restare invulnerabili di continuo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Movimento = require(ReplicatedStorage.Shared.Config.Movimento)
local Effetti = require(script.Parent.Parent.Combattimento.Effetti)

local Remotes = ReplicatedStorage.Remotes
local Capriola = Movimento.Capriola

local MovimentoService = {}

local ultimaCapriola = {} -- [Player] = os.clock()

local function capriola(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local ora = os.clock()
	-- La ricarica minima vera è durata + ricarica; teniamo un margine per la rete.
	if ora - (ultimaCapriola[player] or -math.huge) < (Capriola.durata + Capriola.ricarica) * 0.85 then
		return
	end
	ultimaCapriola[player] = ora
	Effetti.Aggiungi(player, "Schivata", Capriola.durata + 0.1, {})
end

function MovimentoService.Avvia()
	Remotes.Capriola.OnServerEvent:Connect(capriola)
	Players.PlayerRemoving:Connect(function(player)
		ultimaCapriola[player] = nil
	end)
end

return MovimentoService
