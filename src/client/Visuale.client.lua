-- Visuale: terza persona fissa (niente zoom né prima persona) e, con mouse e
-- tastiera, bloccata come lo "shift lock": cursore nascosto, telecamera sopra la
-- spalla, il personaggio guarda dove guarda la telecamera; con l'arma in mano
-- compare il mirino al centro.
--
-- Il cursore torna libero:
--   - tenendo premuto il tasto `tastoCursore` (Alt)
--   - quando è aperta una finestra: ogni finestra imposta sul giocatore un
--     attributo "Finestra_<nome>" = true mentre è visibile
-- Su telefono il blocco non serve: resta la visuale normale (sempre a distanza fissa).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Movimento = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Movimento"))
local Visuale = Movimento.Visuale

local player = Players.LocalPlayer

player.CameraMode = Enum.CameraMode.Classic
player.CameraMinZoomDistance = Visuale.distanza
player.CameraMaxZoomDistance = Visuale.distanza

local soloTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
if not Visuale.bloccata or soloTouch then
	return
end

-- Mirino al centro dello schermo.
local gui = Instance.new("ScreenGui")
gui.Name = "Mirino"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 4
gui.Parent = player:WaitForChild("PlayerGui")

local mirino = Instance.new("Frame")
mirino.AnchorPoint = Vector2.new(0.5, 0.5)
mirino.Position = UDim2.fromScale(0.5, 0.5)
mirino.Size = UDim2.fromOffset(22, 22)
mirino.BackgroundTransparency = 1
mirino.Parent = gui
for _, dimensione in ipairs({ Vector2.new(2, 22), Vector2.new(22, 2) }) do
	local barra = Instance.new("Frame")
	barra.AnchorPoint = Vector2.new(0.5, 0.5)
	barra.Position = UDim2.fromScale(0.5, 0.5)
	barra.Size = UDim2.fromOffset(dimensione.X, dimensione.Y)
	barra.BackgroundColor3 = Color3.new(1, 1, 1)
	barra.BackgroundTransparency = 0.25
	barra.BorderSizePixel = 0
	barra.Parent = mirino
	local bordo = Instance.new("UIStroke")
	bordo.Color = Color3.new(0, 0, 0)
	bordo.Transparency = 0.5
	bordo.Parent = barra
end

-- I riquadri "Tieni premuto E" dei ProximityPrompt sono anche pulsanti cliccabili:
-- con il mouse bloccato al centro, quando il centro dello schermo ci passa sopra
-- Roblox crede che si stia puntando un pulsante e smette di girare la telecamera.
-- Su computer li rendiamo non cliccabili (solo per noi): si usa comunque il tasto.
local ProximityPromptService = game:GetService("ProximityPromptService")
ProximityPromptService.PromptShown:Connect(function(prompt)
	prompt.ClickablePrompt = false
end)

local function finestraAperta()
	for nome, valore in pairs(player:GetAttributes()) do
		if valore == true and nome:sub(1, 9) == "Finestra_" then
			return true
		end
	end
	return false
end

local eraBloccata = false

-- Dopo la telecamera di Roblox: così il nostro blocco del mouse ha l'ultima parola.
RunService:BindToRenderStep("VisualeBloccata", Enum.RenderPriority.Camera.Value + 1, function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local radice = character and character:FindFirstChild("HumanoidRootPart")
	local libero = UserInputService:IsKeyDown(Visuale.tastoCursore) or finestraAperta()

	-- Il mirino si vede solo con l'arma della classe in mano.
	local arma = character and character:FindFirstChildOfClass("Tool")
	mirino.Visible = not libero and arma ~= nil and arma:GetAttribute("ArmaClasse") ~= nil
	if libero then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		if eraBloccata and humanoid then
			humanoid.AutoRotate = true
		end
		eraBloccata = false
		return
	end

	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	eraBloccata = true
	if not humanoid or not radice or humanoid.Health <= 0 then
		return
	end
	humanoid.CameraOffset = Visuale.spalla
	humanoid.AutoRotate = false

	-- Il personaggio guarda dove guarda la telecamera (tranne durante lo scatto,
	-- che ha la sua direzione).
	if character:GetAttribute("ScattoProgresso") then
		return
	end
	local camera = Workspace.CurrentCamera
	local avanti = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	if avanti.Magnitude > 0.01 then
		radice.CFrame = CFrame.lookAt(radice.Position, radice.Position + avanti.Unit)
	end
end)
