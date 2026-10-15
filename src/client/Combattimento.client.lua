-- Combattimento lato client: usa l'abilità dell'arma verso il punto mirato
-- e mostra i numeri del danno. Le decisioni vere le prende il server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Classi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Classi"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UsaAbilita = Remotes:WaitForChild("UsaAbilita")
local Danno = Remotes:WaitForChild("Danno")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local armiCollegate = setmetatable({}, { __mode = "k" })
local ultimoUso = 0

local function scatto(character)
	local radice = character:FindFirstChild("HumanoidRootPart")
	if radice then
		local avanti = radice.CFrame.LookVector * Vector3.new(1, 0, 1)
		radice.AssemblyLinearVelocity = avanti.Unit * 85 + Vector3.new(0, 8, 0)
	end
end

local function collegaArma(arma)
	if not arma:IsA("Tool") or armiCollegate[arma] or not arma:GetAttribute("ArmaClasse") then
		return
	end
	armiCollegate[arma] = true
	arma.Activated:Connect(function()
		local classe = Classi.Dati[arma:GetAttribute("ArmaClasse")]
		local character = player.Character
		if not classe or not character then
			return
		end
		-- Ricarica anche sul client, per non inviare richieste inutili al server.
		local ora = os.clock()
		local ricarica = classe.abilita.ricarica
		if player:GetAttribute("EffettoFuria") and classe.speciale.ricaricaAttacco then
			ricarica *= classe.speciale.ricaricaAttacco
		end
		if ora - ultimoUso < ricarica then
			return
		end
		ultimoUso = ora
		if classe.abilita.tipo == "Scatto" then
			scatto(character)
		end
		UsaAbilita:FireServer(mouse.Hit.Position)
	end)
end

local function osserva(contenitore)
	for _, oggetto in ipairs(contenitore:GetChildren()) do
		collegaArma(oggetto)
	end
	contenitore.ChildAdded:Connect(collegaArma)
end

player.CharacterAdded:Connect(osserva)
if player.Character then
	osserva(player.Character)
end
osserva(player:WaitForChild("Backpack"))
player.ChildAdded:Connect(function(figlio)
	if figlio:IsA("Backpack") then
		osserva(figlio)
	end
end)

-- Numeri del danno che salgono e svaniscono sopra il bersaglio.
Danno.OnClientEvent:Connect(function(posizione, quantita)
	if typeof(posizione) ~= "Vector3" or type(quantita) ~= "number" then
		return
	end
	local ancora = Instance.new("Part")
	ancora.Anchored = true
	ancora.CanCollide = false
	ancora.CanQuery = false
	ancora.CanTouch = false
	ancora.Transparency = 1
	ancora.Size = Vector3.new(0.2, 0.2, 0.2)
	ancora.Position = posizione + Vector3.new(math.random(-15, 15) / 10, 3, math.random(-15, 15) / 10)
	ancora.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(90, 40)
	billboard.AlwaysOnTop = true
	billboard.Parent = ancora

	local testo = Instance.new("TextLabel")
	testo.Size = UDim2.fromScale(1, 1)
	testo.BackgroundTransparency = 1
	testo.Text = tostring(quantita)
	testo.TextColor3 = Color3.fromRGB(255, 220, 90)
	testo.TextStrokeTransparency = 0.3
	testo.TextScaled = true
	testo.Font = Enum.Font.GothamBlack
	testo.Parent = billboard

	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ancora, info, { Position = ancora.Position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(testo, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.85, function()
		ancora:Destroy()
	end)
end)
