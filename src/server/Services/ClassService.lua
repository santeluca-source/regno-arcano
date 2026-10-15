-- ClassService: cambio classe e statistiche del personaggio.
-- La classe è salvata in PlayerData; qui applichiamo i suoi effetti al personaggio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classi = require(ReplicatedStorage.Shared.Config.Classi)
local PlayerData = require(script.Parent.PlayerData)
local TycoonService = require(script.Parent.TycoonService)
local InventarioService = require(script.Parent.InventarioService)

local Remotes = ReplicatedStorage.Remotes
local ATTESA_TRA_CAMBI = 1

local ClassService = {}

local ultimoCambio = {} -- [Player] = os.clock()

local function applicaStatistiche(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local dati = PlayerData.Ottieni(player)
	if not humanoid or not dati then
		return
	end
	local statistiche = Classi.Dati[dati.Classe].statistiche
	local vita = statistiche.vita + InventarioService.VitaBonus(player)
	local percentualeVita = humanoid.MaxHealth > 0 and humanoid.Health / humanoid.MaxHealth or 1
	humanoid.MaxHealth = vita
	humanoid.Health = vita * percentualeVita
	humanoid.WalkSpeed = statistiche.velocita
end

-- Punto unico per cambiare classe: lo usano il menu, gli altari della base, ecc.
function ClassService.Cambia(player, classe)
	local ora = os.clock()
	if ora - (ultimoCambio[player] or 0) < ATTESA_TRA_CAMBI then
		return false
	end
	-- La classe si cambia solo dalla propria isola: è la "casa" del personaggio.
	if not TycoonService.SullaPropriaIsola(player) then
		Remotes.Notifica:FireClient(player, "Torna sulla tua isola per cambiare classe.")
		return false
	end
	if not PlayerData.ImpostaClasse(player, classe) then
		return false
	end
	ultimoCambio[player] = ora
	applicaStatistiche(player)
	Remotes.Notifica:FireClient(player, "Ora sei un " .. classe .. "!")
	return true
end

function ClassService.Avvia()
	Remotes.CambiaClasse.OnServerEvent:Connect(function(player, classe)
		-- Mai fidarsi del client: controlliamo il tipo prima di tutto.
		if type(classe) == "string" then
			ClassService.Cambia(player, classe)
		end
	end)

	local function collegaGiocatore(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 5)
			applicaStatistiche(player)
		end)
		if player.Character then
			applicaStatistiche(player)
		end
	end

	-- Le statistiche si applicano solo quando i dati sono pronti.
	PlayerData.Caricato:Connect(collegaGiocatore)
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerData.Pronto(player) then
			collegaGiocatore(player)
		end
	end

	-- Una nuova armatura cambia la vita massima.
	PlayerData.Cambiato:Connect(function(player, sezione)
		if sezione == "Inventario" then
			applicaStatistiche(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		ultimoCambio[player] = nil
	end)
end

return ClassService
