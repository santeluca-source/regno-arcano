-- Effetti temporanei sui giocatori (Scudo, Furia, Velo, Protezione...).
-- Ogni effetto ha un nome, una durata e una tabella di dati che gli altri moduli
-- leggono con Effetti.Attivo(player, nome). Un bagliore colorato (Highlight)
-- mostra a tutti che l'effetto è attivo.

local Players = game:GetService("Players")

local Effetti = {}

local attivi = {} -- [Player] = { [nome] = voce }

function Effetti.Rimuovi(player, nome)
	local delGiocatore = attivi[player]
	local voce = delGiocatore and delGiocatore[nome]
	if not voce then
		return
	end
	delGiocatore[nome] = nil
	player:SetAttribute("Effetto" .. nome, nil)
	if voce.bagliore then
		voce.bagliore:Destroy()
	end
	if voce.alFine then
		task.spawn(voce.alFine)
	end
end

-- dati: tabella libera; colore: colore del bagliore (facoltativo); alFine: funzione chiamata alla fine
function Effetti.Aggiungi(player, nome, durata, dati, colore, alFine)
	Effetti.Rimuovi(player, nome)
	local voce = { dati = dati or {}, alFine = alFine }
	local character = player.Character
	if colore and character then
		local bagliore = Instance.new("Highlight")
		bagliore.Name = "Effetto_" .. nome
		bagliore.FillColor = colore
		bagliore.FillTransparency = 0.65
		bagliore.OutlineColor = colore
		bagliore.DepthMode = Enum.HighlightDepthMode.Occluded
		bagliore.Parent = character
		voce.bagliore = bagliore
	end
	attivi[player] = attivi[player] or {}
	attivi[player][nome] = voce
	-- Il client lo legge per mostrare l'effetto (es. ricarica più rapida con la Furia).
	player:SetAttribute("Effetto" .. nome, true)
	task.delay(durata, function()
		if attivi[player] and attivi[player][nome] == voce then
			Effetti.Rimuovi(player, nome)
		end
	end)
	return voce.dati
end

-- I dati dell'effetto se è attivo, altrimenti nil.
function Effetti.Attivo(player, nome)
	local delGiocatore = attivi[player]
	local voce = delGiocatore and delGiocatore[nome]
	return voce and voce.dati
end

function Effetti.Pulisci(player)
	local delGiocatore = attivi[player]
	if not delGiocatore then
		return
	end
	for nome in pairs(delGiocatore) do
		Effetti.Rimuovi(player, nome)
	end
	attivi[player] = nil
end

-- Gli effetti finiscono quando il personaggio muore o il giocatore esce.
local function collega(player)
	player.CharacterRemoving:Connect(function()
		Effetti.Pulisci(player)
	end)
end
Players.PlayerAdded:Connect(collega)
for _, player in ipairs(Players:GetPlayers()) do
	collega(player)
end
Players.PlayerRemoving:Connect(Effetti.Pulisci)

return Effetti
