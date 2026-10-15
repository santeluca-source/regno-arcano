-- Piccoli aiuti per costruire geometria dal codice.
-- Tutte le posizioni sono relative a un CFrame di riferimento (l'isola).

local Costruzione = {}

Costruzione.Colori = {
	prato = Color3.fromRGB(124, 207, 140),
	terra = Color3.fromRGB(122, 92, 70),
	pietra = Color3.fromRGB(140, 150, 170),
	pietraScura = Color3.fromRGB(70, 72, 92),
	legno = Color3.fromRGB(150, 105, 70),
	oro = Color3.fromRGB(255, 205, 90),
	ciano = Color3.fromRGB(74, 225, 255),
	viola = Color3.fromRGB(177, 72, 255),
	bianco = Color3.fromRGB(246, 250, 255),
	nastro = Color3.fromRGB(45, 45, 55),
	verde = Color3.fromRGB(92, 220, 139),
	rosso = Color3.fromRGB(230, 80, 80),
}

-- base: CFrame dell'isola; locale: Vector3 relativo; opzioni: tabella di proprietà extra
function Costruzione.Parte(genitore, nome, base, locale, dimensione, colore, materiale, opzioni)
	local parte = Instance.new("Part")
	parte.Name = nome
	parte.Anchored = true
	parte.Size = dimensione
	parte.CFrame = base * CFrame.new(locale)
	parte.Color = colore
	parte.Material = materiale or Enum.Material.SmoothPlastic
	parte.TopSurface = Enum.SurfaceType.Smooth
	parte.BottomSurface = Enum.SurfaceType.Smooth
	if opzioni then
		for proprieta, valore in pairs(opzioni) do
			parte[proprieta] = valore
		end
	end
	parte.Parent = genitore
	return parte
end

function Costruzione.Luce(parte, colore, luminosita, raggio)
	local luce = Instance.new("PointLight")
	luce.Color = colore
	luce.Brightness = luminosita or 1.5
	luce.Range = raggio or 14
	luce.Parent = parte
	return luce
end

-- Cartello fluttuante sopra una parte. Restituisce la TextLabel per aggiornarla.
function Costruzione.Etichetta(parte, testo, colore, dimensione, altezza, sempreVisibile)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Etichetta"
	billboard.Size = UDim2.fromOffset((dimensione or Vector2.new(200, 50)).X, (dimensione or Vector2.new(200, 50)).Y)
	billboard.StudsOffset = Vector3.new(0, altezza or 4, 0)
	billboard.AlwaysOnTop = sempreVisibile == true
	billboard.MaxDistance = 90
	billboard.Parent = parte

	local testoLabel = Instance.new("TextLabel")
	testoLabel.Size = UDim2.fromScale(1, 1)
	testoLabel.BackgroundColor3 = Color3.fromRGB(24, 22, 34)
	testoLabel.BackgroundTransparency = 0.2
	testoLabel.Text = testo
	testoLabel.TextColor3 = colore or Costruzione.Colori.bianco
	testoLabel.TextScaled = true
	testoLabel.Font = Enum.Font.GothamBold
	testoLabel.Parent = billboard

	local angoli = Instance.new("UICorner")
	angoli.CornerRadius = UDim.new(0, 8)
	angoli.Parent = testoLabel

	local margini = Instance.new("UIPadding")
	margini.PaddingLeft = UDim.new(0, 6)
	margini.PaddingRight = UDim.new(0, 6)
	margini.Parent = testoLabel

	return testoLabel
end

return Costruzione
