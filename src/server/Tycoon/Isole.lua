-- Genera le isole personali disposte ad anello attorno al centro del mondo.
-- Al centro c'è la Piazza multiplayer; ci si arriva a piedi dai ponti o con il
-- teletrasporto del menu Viaggi.

local Workspace = game:GetService("Workspace")

local Costruzione = require(script.Parent.Costruzione)
local C = Costruzione.Colori

local Isole = {}

Isole.Numero = 8
Isole.Lato = 100 -- l'isola è un quadrato di 100x100 stud
Isole.RaggioAnello = 340 -- distanza dal centro: i ponti verso la Piazza sono lunghi ~200 stud
Isole.Altezza = 4 -- quota del prato

-- Crea (o ricrea) tutte le isole e restituisce la cartella che le contiene.
function Isole.Genera()
	local vecchia = Workspace:FindFirstChild("Isole")
	if vecchia then
		vecchia:Destroy()
	end

	local cartella = Instance.new("Folder")
	cartella.Name = "Isole"
	cartella.Parent = Workspace

	for indice = 1, Isole.Numero do
		local angolo = (indice - 1) / Isole.Numero * math.pi * 2
		local centro = Vector3.new(math.cos(angolo), 0, math.sin(angolo)) * Isole.RaggioAnello
		centro += Vector3.new(0, Isole.Altezza, 0)
		-- Il fronte dell'isola (-Z locale) guarda verso il centro del mondo.
		local base = CFrame.lookAt(centro, Vector3.new(0, Isole.Altezza, 0))

		local isola = Instance.new("Model")
		isola.Name = string.format("Isola%02d", indice)
		isola:SetAttribute("Proprietario", 0)
		isola:SetAttribute("Base", base)
		isola.Parent = cartella

		local lato = Isole.Lato
		local terreno = Costruzione.Parte(isola, "Terreno", base, Vector3.new(0, -3, 0),
			Vector3.new(lato, 4, lato), C.terra, Enum.Material.Ground)
		Costruzione.Parte(isola, "Prato", base, Vector3.new(0, -0.5, 0),
			Vector3.new(lato, 1, lato), C.prato, Enum.Material.Grass)
		isola.PrimaryPart = terreno

		-- Cartello con il nome del proprietario, sul lato rivolto verso la Piazza.
		local palo = Costruzione.Parte(isola, "Cartello", base, Vector3.new(0, 3, -lato / 2 + 3),
			Vector3.new(1, 6, 1), C.legno, Enum.Material.Wood)
		local etichetta = Costruzione.Etichetta(palo, "ISOLA LIBERA", C.bianco, Vector2.new(260, 50), 5, false)
		etichetta.Name = "TestoProprietario"

		for _, nome in ipairs({ "Oggetti", "Pulsanti", "Minerali" }) do
			local sotto = Instance.new("Folder")
			sotto.Name = nome
			sotto.Parent = isola
		end
	end

	return cartella
end

-- Il punto in cui il proprietario compare sulla propria isola.
function Isole.PuntoDiArrivo(isola)
	local base = isola:GetAttribute("Base")
	return base * CFrame.new(0, 3, 30)
end

-- Vero se la posizione (mondo) è sopra l'isola.
function Isole.Contiene(isola, posizione)
	local base = isola:GetAttribute("Base")
	local locale = base:PointToObjectSpace(posizione)
	local meta = Isole.Lato / 2
	return math.abs(locale.X) <= meta and math.abs(locale.Z) <= meta and locale.Y > -5 and locale.Y < 60
end

function Isole.ImpostaProprietario(isola, player)
	isola:SetAttribute("Proprietario", player and player.UserId or 0)
	local etichetta = isola.Cartello.Etichetta.TestoProprietario
	etichetta.Text = player and ("ISOLA DI " .. string.upper(player.DisplayName)) or "ISOLA LIBERA"
end

return Isole
