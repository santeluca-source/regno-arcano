-- Corsa (Shift tenuto) e capriola (Ctrl), con la barra della resistenza.
-- Su telefono e controller ContextActionService crea i pulsanti da solo.
-- Il movimento lo fa il client; il server dà l'invulnerabilità della capriola.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local Movimento = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Movimento"))
local RemoteCapriola = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Capriola")

local player = Players.LocalPlayer
local Corsa, Capriola, Resistenza = Movimento.Corsa, Movimento.Capriola, Movimento.Resistenza

local stato = {
	resistenza = Resistenza.massimo,
	corsaPremuta = false,
	esausto = false, -- finita la resistenza: niente corsa finché non si ricarica un po'
	inCapriola = false,
	prossimaCapriola = 0,
	ultimoConsumo = 0,
}

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

-- Capriola -------------------------------------------------------------------------

local function capriola()
	local character, humanoid, radice = personaggio()
	local ora = os.clock()
	if not character or stato.inCapriola or ora < stato.prossimaCapriola or stato.resistenza < Capriola.costo then
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

	stato.inCapriola = true
	stato.prossimaCapriola = ora + Capriola.durata + Capriola.ricarica
	consuma(Capriola.costo)
	RemoteCapriola:FireServer()

	-- Ci fermiamo prima di un muro, per non attraversarlo.
	local parametri = RaycastParams.new()
	parametri.FilterType = Enum.RaycastFilterType.Exclude
	parametri.FilterDescendantsInstances = { character }
	local partenza = radice.Position
	local colpo = Workspace:Raycast(partenza, direzione * Capriola.distanza, parametri)
	local distanza = colpo and math.max(0, (colpo.Position - partenza).Magnitude - 2) or Capriola.distanza
	local orientamento = CFrame.lookAt(partenza, partenza + direzione).Rotation

	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	local inizio = os.clock()
	local connessione
	connessione = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - inizio) / Capriola.durata, 0, 1)
		local avanzamento = 1 - (1 - t) ^ 2 -- parte veloce e rallenta
		if not radice.Parent or humanoid.Health <= 0 then
			t = 1
		end
		if t >= 1 then
			connessione:Disconnect()
			if radice.Parent then
				radice.CFrame = CFrame.new(partenza + direzione * distanza) * orientamento
				radice.AssemblyLinearVelocity = direzione * humanoid.WalkSpeed
			end
			humanoid.PlatformStand = false
			humanoid.AutoRotate = true
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
			stato.inCapriola = false
			return
		end
		-- Un giro completo in avanti attorno all'asse orizzontale del personaggio.
		local posizione = partenza + direzione * distanza * avanzamento
		radice.CFrame = CFrame.new(posizione) * orientamento * CFrame.Angles(-math.pi * 2 * t, 0, 0)
		radice.AssemblyLinearVelocity = Vector3.zero
	end)
end

-- Corsa e resistenza -----------------------------------------------------------------

RunService.Heartbeat:Connect(function(passo)
	local _, humanoid = personaggio()
	if not humanoid then
		return
	end
	if stato.esausto and stato.resistenza >= Resistenza.massimo * 0.3 then
		stato.esausto = false
	end
	local inMovimento = humanoid.MoveDirection.Magnitude > 0.1
	local correndo = stato.corsaPremuta and inMovimento and not stato.esausto and not stato.inCapriola

	if correndo then
		consuma(Corsa.consumo * passo)
	elseif os.clock() - stato.ultimoConsumo > Resistenza.ritardoRecupero then
		stato.resistenza = math.min(Resistenza.massimo, stato.resistenza + Resistenza.recupero * passo)
	end

	-- La velocità base la decide il server (classe, ghiaccio...): noi ci mettiamo sopra la corsa.
	local base = humanoid:GetAttribute("VelocitaBase")
	if base then
		humanoid.WalkSpeed = base * (correndo and Corsa.moltiplicatore or 1)
	end
end)

-- Comandi (tastiera, controller e pulsanti su telefono) -------------------------------

ContextActionService:BindAction("Corsa", function(_, statoInput)
	stato.corsaPremuta = statoInput == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("Corsa", "Corri")

ContextActionService:BindAction("Capriola", function(_, statoInput)
	if statoInput == Enum.UserInputState.Begin then
		capriola()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
ContextActionService:SetTitle("Capriola", "Rotola")

-- Barra della resistenza (in basso al centro, solo quando non è piena) ---------------

local gui = Instance.new("ScreenGui")
gui.Name = "Resistenza"
gui.ResetOnSpawn = false
gui.DisplayOrder = 12
gui.Parent = player:WaitForChild("PlayerGui")

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
	stato.inCapriola = false
end)
