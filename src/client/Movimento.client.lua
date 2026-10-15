-- Corsa (Shift tenuto) e scatto (Ctrl), con la barra della resistenza.
-- Su telefono e controller ContextActionService crea i pulsanti da solo.
-- Il movimento lo fa il client; il server dà l'invulnerabilità dello scatto
-- e pubblica lo stato agli altri giocatori. Pose e immagini residue sono in
-- Animazioni.client. Qui ci sono anche gli effetti "anime" della corsa (visuale
-- più ampia, linee di velocità) e la visuale fissa in terza persona.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Movimento = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Movimento"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RemoteScatto = Remotes:WaitForChild("Scatto")
local RemoteCorsa = Remotes:WaitForChild("Corsa")

local player = Players.LocalPlayer
local Corsa, Scatto, Resistenza, Visuale = Movimento.Corsa, Movimento.Scatto, Movimento.Resistenza, Movimento.Visuale

local stato = {
	resistenza = Resistenza.massimo,
	corsaPremuta = false,
	correndo = false,
	esausto = false, -- finita la resistenza: niente corsa finché non si ricarica un po'
	inScatto = false,
	prossimoScatto = 0,
	ultimoConsumo = 0,
}

-- Visuale: sempre terza persona, sempre alla stessa distanza ---------------------

player.CameraMode = Enum.CameraMode.Classic
player.CameraMinZoomDistance = Visuale.distanza
player.CameraMaxZoomDistance = Visuale.distanza

local function personaggio()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local radice = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and radice and humanoid.Health > 0 then
		return character, humanoid, radice
	end
	return nil
end

local function consuma(quantita)
	stato.resistenza = math.max(0, stato.resistenza - quantita)
	stato.ultimoConsumo = os.clock()
	if stato.resistenza <= 0 then
		stato.esausto = true
	end
end

-- Sbuffo di polvere (solo effetto visivo locale).
local function polvere(posizione)
	for _ = 1, 6 do
		local nuvola = Instance.new("Part")
		nuvola.Shape = Enum.PartType.Ball
		nuvola.Size = Vector3.one * 0.8
		nuvola.Color = Color3.fromRGB(210, 200, 185)
		nuvola.Material = Enum.Material.SmoothPlastic
		nuvola.Transparency = 0.3
		nuvola.Anchored = true
		nuvola.CanCollide = false
		nuvola.CanQuery = false
		nuvola.CanTouch = false
		nuvola.CFrame = CFrame.new(posizione)
		nuvola.Parent = Workspace
		local spinta = Vector3.new(math.random(-10, 10), math.random(2, 6), math.random(-10, 10)) / 6
		TweenService:Create(nuvola, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = posizione + spinta,
			Size = Vector3.one * 2.2,
			Transparency = 1,
		}):Play()
		task.delay(0.55, function()
			nuvola:Destroy()
		end)
	end
end

-- Scatto ----------------------------------------------------------------------------

local colpoVisuale = 0 -- allargamento momentaneo della visuale allo scatto

local function scatto()
	local character, humanoid, radice = personaggio()
	local ora = os.clock()
	if not character or stato.inScatto or ora < stato.prossimoScatto or stato.resistenza < Scatto.costo then
		return
	end
	-- Direzione: dove ci si sta muovendo, altrimenti dove si guarda.
	local direzione = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	if direzione.Magnitude < 0.1 then
		direzione = radice.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	if direzione.Magnitude < 0.1 then
		return
	end
	direzione = direzione.Unit

	stato.inScatto = true
	stato.prossimoScatto = ora + Scatto.durata + Scatto.ricarica
	consuma(Scatto.costo)
	RemoteScatto:FireServer()
	colpoVisuale = 1
	polvere(radice.Position - Vector3.new(0, humanoid.HipHeight + radice.Size.Y / 2, 0))

	-- Il personaggio si gira subito nella direzione dello scatto.
	radice.CFrame = CFrame.lookAt(radice.Position, radice.Position + direzione)
	humanoid.AutoRotate = false

	-- La spinta è un vincolo fisico: se c'è un muro ci si ferma contro, senza attraversarlo.
	local attacco = Instance.new("Attachment")
	attacco.Name = "AttaccoScatto"
	attacco.Parent = radice
	local spinta = Instance.new("LinearVelocity")
	spinta.Name = "SpintaScatto"
	spinta.Attachment0 = attacco
	spinta.RelativeTo = Enum.ActuatorRelativeTo.World
	spinta.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	spinta.MaxForce = math.huge
	spinta.VectorVelocity = direzione * (Scatto.distanza / Scatto.durata)
	spinta.Parent = radice

	local inizio = os.clock()
	local connessione
	connessione = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - inizio) / Scatto.durata, 0, 1)
		if not radice.Parent or humanoid.Health <= 0 then
			t = 1
		end
		if t < 1 then
			character:SetAttribute("ScattoProgresso", t) -- letto da Animazioni.client
			return
		end
		connessione:Disconnect()
		spinta:Destroy()
		attacco:Destroy()
		character:SetAttribute("ScattoProgresso", nil)
		if radice.Parent then
			-- Si esce dallo scatto già alla velocità di camminata: niente frenata brusca.
			radice.AssemblyLinearVelocity = direzione * humanoid.WalkSpeed
		end
		humanoid.AutoRotate = true
		stato.inScatto = false
	end)
end

-- Effetti della corsa: visuale più ampia e linee di velocità ------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "Movimento"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local linee = {}
for _ = 1, Visuale.lineeVelocita do
	local linea = Instance.new("Frame")
	linea.AnchorPoint = Vector2.new(0.5, 0.5)
	linea.BackgroundColor3 = Color3.new(1, 1, 1)
	linea.BorderSizePixel = 0
	linea.Visible = false
	linea.Parent = gui
	table.insert(linee, linea)
end

local prossimeLinee = 0
local function aggiornaLinee(intensita)
	local ora = os.clock()
	if ora < prossimeLinee then
		return
	end
	prossimeLinee = ora + 0.05
	local schermo = gui.AbsoluteSize
	local centro = schermo / 2
	for _, linea in ipairs(linee) do
		-- Ogni linea compare a caso sul bordo e punta verso il centro dello schermo.
		local visibile = intensita > 0.05 and math.random() < 0.6 * intensita
		linea.Visible = visibile
		if visibile then
			local angolo = math.random() * math.pi * 2
			local raggio = 0.42 + math.random() * 0.12
			local punto = centro + Vector2.new(math.cos(angolo) * schermo.X, math.sin(angolo) * schermo.Y) * raggio
			linea.Position = UDim2.fromOffset(punto.X, punto.Y)
			linea.Size = UDim2.fromOffset(math.random(70, 170), math.random(1, 3))
			linea.Rotation = math.deg(math.atan2(punto.Y - centro.Y, punto.X - centro.X))
			linea.BackgroundTransparency = 0.25 + math.random() * 0.5
		end
	end
end

-- Corsa e resistenza -----------------------------------------------------------------

local intensitaCorsa = 0

RunService.Heartbeat:Connect(function(passo)
	local character, humanoid = personaggio()
	if not humanoid then
		return
	end
	if stato.esausto and stato.resistenza >= Resistenza.massimo * 0.3 then
		stato.esausto = false
	end
	local inMovimento = humanoid.MoveDirection.Magnitude > 0.1
	local correndo = stato.corsaPremuta and inMovimento and not stato.esausto and not stato.inScatto

	if correndo then
		consuma(Corsa.consumo * passo)
	elseif os.clock() - stato.ultimoConsumo > Resistenza.ritardoRecupero then
		stato.resistenza = math.min(Resistenza.massimo, stato.resistenza + Resistenza.recupero * passo)
	end

	-- Avvisiamo il server solo quando cambia: lui lo mostra agli altri giocatori.
	if correndo ~= stato.correndo then
		stato.correndo = correndo
		character:SetAttribute("CorsaLocale", correndo)
		RemoteCorsa:FireServer(correndo)
	end

	-- La velocità base la decide il server (classe, ghiaccio...): noi ci mettiamo sopra la corsa.
	local base = humanoid:GetAttribute("VelocitaBase")
	if base then
		humanoid.WalkSpeed = base * (correndo and Corsa.moltiplicatore or 1)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local obiettivo = stato.correndo and 1 or 0
	intensitaCorsa += (obiettivo - intensitaCorsa) * math.min(1, dt * 6)
	colpoVisuale = math.max(0, colpoVisuale - dt * 4) -- il "colpo" dello scatto svanisce in 1/4 di secondo
	local camera = Workspace.CurrentCamera
	if camera then
		camera.FieldOfView = Visuale.campoVisivo + (Visuale.campoVisivoCorsa - Visuale.campoVisivo) * intensitaCorsa
			+ Visuale.colpoScatto * colpoVisuale
	end
	aggiornaLinee(intensitaCorsa)
end)

-- Comandi (tastiera, controller e pulsanti su telefono) -------------------------------

ContextActionService:BindAction("Corsa", function(_, statoInput)
	stato.corsaPremuta = statoInput == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("Corsa", "Corri")

ContextActionService:BindAction("Scatto", function(_, statoInput)
	if statoInput == Enum.UserInputState.Begin then
		scatto()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
ContextActionService:SetTitle("Scatto", "Scatto")

-- Barra della resistenza (in basso al centro, solo quando non è piena) ---------------

local cornice = Instance.new("Frame")
cornice.AnchorPoint = Vector2.new(0.5, 1)
cornice.Position = UDim2.new(0.5, 0, 1, -84)
cornice.Size = UDim2.fromOffset(220, 10)
cornice.BackgroundColor3 = Color3.fromRGB(24, 22, 34)
cornice.BackgroundTransparency = 0.2
cornice.Visible = false
cornice.Parent = gui
local angoliCornice = Instance.new("UICorner")
angoliCornice.CornerRadius = UDim.new(1, 0)
angoliCornice.Parent = cornice

local riempimento = Instance.new("Frame")
riempimento.Size = UDim2.fromScale(1, 1)
riempimento.BorderSizePixel = 0
riempimento.Parent = cornice
local angoliRiempimento = Instance.new("UICorner")
angoliRiempimento.CornerRadius = UDim.new(1, 0)
angoliRiempimento.Parent = riempimento

RunService.RenderStepped:Connect(function()
	local frazione = stato.resistenza / Resistenza.massimo
	cornice.Visible = frazione < 0.999
	riempimento.Size = UDim2.fromScale(frazione, 1)
	riempimento.BackgroundColor3 = stato.esausto and Color3.fromRGB(230, 90, 90)
		or frazione < 0.3 and Color3.fromRGB(240, 190, 70)
		or Color3.fromRGB(92, 220, 139)
end)

player.CharacterAdded:Connect(function()
	stato.resistenza = Resistenza.massimo
	stato.esausto = false
	stato.inScatto = false
	stato.correndo = false
	RemoteCorsa:FireServer(false)
end)
