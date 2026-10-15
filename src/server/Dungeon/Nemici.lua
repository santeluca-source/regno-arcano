-- Crea i modelli dei nemici: un corpo a blocchi con Humanoid, che cammina grazie a HipHeight.
-- L'intelligenza (inseguire, attaccare) è in DungeonService.

local CollectionService = game:GetService("CollectionService")

local Costruzione = require(script.Parent.Parent.Tycoon.Costruzione)

local Nemici = {}

local function pezzo(modello, nome, dimensione, cframe, colore, materiale)
	local parte = Instance.new("Part")
	parte.Name = nome
	parte.Size = dimensione
	parte.CFrame = cframe
	parte.Color = colore
	parte.Material = materiale or Enum.Material.SmoothPlastic
	parte.CanCollide = false
	parte.Massless = true
	parte.TopSurface = Enum.SurfaceType.Smooth
	parte.BottomSurface = Enum.SurfaceType.Smooth
	parte.Parent = modello
	return parte
end

-- tipo: id in Config.Dungeon.Nemici; terreno: CFrame a livello del pavimento; vita: vita già scalata
-- alleato: true per creare un servitore dei giocatori (occhi verdi, non è un bersaglio)
function Nemici.Crea(genitore, tipo, def, terreno, vita, alleato)
	local s = def.scala
	local altezzaFianchi = 2 * s
	local centro = terreno * CFrame.new(0, altezzaFianchi + s, 0)

	local modello = Instance.new("Model")
	modello.Name = def.nome

	local radice = pezzo(modello, "HumanoidRootPart", Vector3.new(2 * s, 2 * s, s), centro, def.colore)
	radice.Transparency = 1
	radice.CanCollide = true
	radice.Massless = false
	modello.PrimaryPart = radice

	local scuro = def.colore:Lerp(Color3.new(0, 0, 0), 0.35)
	local parti = {
		pezzo(modello, "Torso", Vector3.new(2.4 * s, 2.6 * s, 1.4 * s), centro * CFrame.new(0, 0.3 * s, 0), def.colore),
		pezzo(modello, "Head", Vector3.new(1.6 * s, 1.6 * s, 1.6 * s), centro * CFrame.new(0, 2.5 * s, 0), def.colore),
		pezzo(modello, "Gamba", Vector3.new(0.9 * s, altezzaFianchi, 0.9 * s), centro * CFrame.new(-0.6 * s, -2 * s, 0), scuro),
		pezzo(modello, "Gamba", Vector3.new(0.9 * s, altezzaFianchi, 0.9 * s), centro * CFrame.new(0.6 * s, -2 * s, 0), scuro),
		pezzo(modello, "Braccio", Vector3.new(0.8 * s, 2.2 * s, 0.8 * s), centro * CFrame.new(-1.65 * s, 0.4 * s, 0), scuro),
		pezzo(modello, "Braccio", Vector3.new(0.8 * s, 2.2 * s, 0.8 * s), centro * CFrame.new(1.65 * s, 0.4 * s, 0), scuro),
		pezzo(modello, "Occhi", Vector3.new(1.1 * s, 0.3 * s, 0.1), centro * CFrame.new(0, 2.65 * s, -0.81 * s),
			alleato and Color3.fromRGB(80, 255, 140) or Color3.fromRGB(255, 60, 60), Enum.Material.Neon),
	}
	if def.boss then
		local corona = pezzo(modello, "Corona", Vector3.new(1.8 * s, 0.5 * s, 1.8 * s), centro * CFrame.new(0, 3.55 * s, 0),
			Color3.fromRGB(255, 205, 70), Enum.Material.Neon)
		Costruzione.Luce(corona, Color3.fromRGB(255, 205, 70), 2, 20)
		table.insert(parti, corona)
	end
	for _, parte in ipairs(parti) do
		local saldatura = Instance.new("WeldConstraint")
		saldatura.Part0 = radice
		saldatura.Part1 = parte
		saldatura.Parent = parte
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = altezzaFianchi
	humanoid.WalkSpeed = def.velocita
	humanoid.MaxHealth = vita
	humanoid.Health = vita
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = modello

	local testa = modello.Head
	local coloreBarra = alleato and Color3.fromRGB(120, 255, 160)
		or def.boss and Color3.fromRGB(255, 205, 70) or Color3.fromRGB(255, 120, 120)
	local barra = Costruzione.Etichetta(testa, alleato and string.upper(def.nome) or "", coloreBarra,
		def.boss and Vector2.new(300, 40) or Vector2.new(200, 28), 1.5 * s + 1, def.boss)
	barra.Name = "TestoVita"
	barra.Parent.Name = "BarraVita"

	modello:SetAttribute("Tipo", tipo)
	modello:SetAttribute("NomeVisibile", def.nome)
	if not alleato then
		CollectionService:AddTag(modello, "Nemico")
	end

	modello.Parent = genitore
	-- Il server muove i nemici: nessun client deve poterli controllare.
	radice:SetNetworkOwner(nil)
	return modello
end

return Nemici
