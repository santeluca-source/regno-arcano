-- Anima corsa "anime" e scatto su TUTTI i personaggi visibili.
--   - il proprio personaggio: legge gli attributi locali messi da Movimento.client
--     ("CorsaLocale", "ScattoProgresso"), così la risposta è immediata
--   - gli altri giocatori: legge gli attributi pubblicati dal server ("Corsa", "InScatto")
-- Effetti: scie di vento sulle mani durante la corsa; durante lo scatto immagini
-- residue luminose (del colore della classe) e un anello di vento alla partenza.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Pose = require(script.Parent:WaitForChild("Pose"))
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Movimento = require(Config:WaitForChild("Movimento"))
local Classi = require(Config:WaitForChild("Classi"))

local player = Players.LocalPlayer
local Scatto = Movimento.Scatto

local VELOCITA_SFUMATURA_CORSA = 8 -- quanto in fretta entra/esce la posa (al secondo)
local VELOCITA_SFUMATURA_SCATTO = 10

-- Le immagini residue sono solo effetti visivi locali.
local cartellaEffetti = Instance.new("Folder")
cartellaEffetti.Name = "EffettiMovimento"
cartellaEffetti.Parent = Workspace

-- Stato per personaggio (chiavi deboli: sparisce da solo quando il personaggio viene distrutto).
local stati = setmetatable({}, { __mode = "k" })

-- Curva morbida da 0 a 1: parte piano, accelera, arriva piano.
local function morbido(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function avvicina(valore, obiettivo, passo)
	if valore < obiettivo then
		return math.min(obiettivo, valore + passo)
	end
	return math.max(obiettivo, valore - passo)
end

local function coloreClasse(character)
	local proprietario = Players:GetPlayerFromCharacter(character)
	local classe = proprietario and Classi.Dati[proprietario:GetAttribute("Classe") or ""]
	return classe and classe.colore or Color3.fromRGB(180, 230, 255)
end

-- Effetti --------------------------------------------------------------------------

local function creaScia(mano)
	local alta = Instance.new("Attachment")
	alta.Name = "SciaAlta"
	alta.Position = Vector3.new(0, 0.3, 0)
	alta.Parent = mano
	local bassa = Instance.new("Attachment")
	bassa.Name = "SciaBassa"
	bassa.Position = Vector3.new(0, -0.3, 0)
	bassa.Parent = mano

	local scia = Instance.new("Trail")
	scia.Name = "SciaVento"
	scia.Attachment0 = alta
	scia.Attachment1 = bassa
	scia.Lifetime = 0.22
	scia.MinLength = 0.05
	scia.FaceCamera = true
	scia.LightEmission = 0.6
	scia.Color = ColorSequence.new(Color3.fromRGB(230, 245, 255))
	scia.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	scia.Enabled = false
	scia.Parent = mano
	return scia
end

-- Una copia fantasma del personaggio nella posa attuale, che svanisce.
local function immagineResidua(character, colore)
	for _, parte in ipairs(character:GetDescendants()) do
		if parte:IsA("BasePart") and parte.Name ~= "HumanoidRootPart" and parte.Transparency < 0.9 then
			local copia = parte:Clone()
			if copia then
				-- Teniamo solo la forma (mesh), niente script, giunti, scie o altro.
				for _, figlio in ipairs(copia:GetChildren()) do
					if not figlio:IsA("DataModelMesh") then
						figlio:Destroy()
					end
				end
				copia.Anchored = true
				copia.CanCollide = false
				copia.CanQuery = false
				copia.CanTouch = false
				copia.CastShadow = false
				copia.Massless = true
				copia.Material = Enum.Material.Neon
				copia.Color = colore
				copia.Transparency = 0.45
				if copia:IsA("MeshPart") then
					copia.TextureID = ""
				end
				copia.CFrame = parte.CFrame
				copia.Parent = cartellaEffetti
				TweenService:Create(copia, TweenInfo.new(Scatto.durataImmagini, Enum.EasingStyle.Quad), {
					Transparency = 1,
				}):Play()
				task.delay(Scatto.durataImmagini + 0.05, function()
					copia:Destroy()
				end)
			end
		end
	end
end

-- Anello di vento che si allarga a terra alla partenza dello scatto.
local function anelloDiVento(character, colore)
	local radice = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not radice or not humanoid then
		return
	end
	local suolo = radice.Position - Vector3.new(0, humanoid.HipHeight + radice.Size.Y / 2 - 0.1, 0)
	local anello = Instance.new("Part")
	anello.Shape = Enum.PartType.Cylinder
	anello.Size = Vector3.new(0.2, 2, 2)
	anello.CFrame = CFrame.new(suolo) * CFrame.Angles(0, 0, math.rad(90))
	anello.Material = Enum.Material.Neon
	anello.Color = colore
	anello.Transparency = 0.3
	anello.Anchored = true
	anello.CanCollide = false
	anello.CanQuery = false
	anello.CanTouch = false
	anello.Parent = cartellaEffetti
	TweenService:Create(anello, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, 14, 14),
		Transparency = 1,
	}):Play()
	task.delay(0.4, function()
		anello:Destroy()
	end)
end

-- Stato e aggiornamento ------------------------------------------------------------------

local function statoDi(character)
	local stato = stati[character]
	if not stato then
		stato = {
			pesoCorsa = 0, pesoScatto = 0, inScatto = false, prossimaImmagine = 0,
			giunti = {}, completo = false, prossimaRicerca = 0, scie = {},
		}
		stati[character] = stato
	end
	-- Appena compare, il personaggio non è ancora tutto costruito: cerchiamo le
	-- articolazioni (e le mani per le scie) finché non le troviamo tutte.
	local ora = os.clock()
	if not stato.completo and ora >= stato.prossimaRicerca then
		stato.prossimaRicerca = ora + 0.5
		stato.tipo, stato.giunti, stato.completo = Pose.Giunti(character)
		if #stato.scie == 0 then
			for _, nome in ipairs({ "LeftHand", "RightHand", "Left Arm", "Right Arm" }) do
				local mano = character:FindFirstChild(nome)
				if mano then
					table.insert(stato.scie, creaScia(mano))
				end
			end
		end
		if stato.completo and character == player.Character then
			print(string.format("[Animazioni] Avatar %s: articolazioni trovate, pose attive.", stato.tipo))
		end
	end
	return stato
end

local function aggiorna(character, eMio, dt)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local stato = statoDi(character)
	local ora = os.clock()

	-- Corsa
	local corre = eMio and character:GetAttribute("CorsaLocale") or (not eMio and character:GetAttribute("Corsa"))
	corre = corre == true and humanoid.MoveDirection.Magnitude > 0.1
	stato.pesoCorsa = avvicina(stato.pesoCorsa, corre and 1 or 0, VELOCITA_SFUMATURA_CORSA * dt)

	-- Scatto: per sé seguiamo il progresso esatto, per gli altri una sfumatura.
	local inScatto
	if eMio then
		local t = character:GetAttribute("ScattoProgresso")
		inScatto = t ~= nil
		if t then
			-- La posa entra quasi subito ed esce nell'ultimo 40%.
			stato.pesoScatto = math.min(morbido(t / 0.12), morbido((1 - t) / 0.4))
		else
			stato.pesoScatto = avvicina(stato.pesoScatto, 0, VELOCITA_SFUMATURA_SCATTO * dt)
		end
	else
		inScatto = character:GetAttribute("InScatto") == true
		stato.pesoScatto = avvicina(stato.pesoScatto, inScatto and 1 or 0, VELOCITA_SFUMATURA_SCATTO * dt)
	end

	-- Inizio dello scatto: anello di vento. Durante: immagini residue a intervalli.
	if inScatto and not stato.inScatto then
		anelloDiVento(character, coloreClasse(character))
		stato.prossimaImmagine = ora
	end
	stato.inScatto = inScatto
	if inScatto and ora >= stato.prossimaImmagine then
		stato.prossimaImmagine = ora + Scatto.intervalloImmagini
		immagineResidua(character, coloreClasse(character))
	end

	-- Prima la corsa, poi lo scatto sopra: passando dall'una all'altro si sfumano
	-- insieme invece di scattare. Le curve morbide evitano partenze e arrivi bruschi.
	local pesoScatto = stato.pesoScatto
	if stato.pesoCorsa > 0 then
		Pose.Applica(stato.tipo, stato.giunti, Pose.CorsaAnime, morbido(stato.pesoCorsa) * (1 - pesoScatto))
	end
	if pesoScatto > 0 then
		Pose.Applica(stato.tipo, stato.giunti, Pose.Scatto, pesoScatto)
	end

	local scieAccese = stato.pesoCorsa > 0.6 or inScatto
	for _, scia in ipairs(stato.scie) do
		if scia.Enabled ~= scieAccese then
			scia.Enabled = scieAccese
		end
	end
end

-- Se dopo qualche secondo le articolazioni del proprio personaggio non sono complete,
-- lo scriviamo nell'Output: aiuta a capire perché le pose non si vedono.
player.CharacterAdded:Connect(function(character)
	task.delay(5, function()
		local stato = stati[character]
		if character.Parent and stato and not stato.completo then
			local trovate = 0
			for _ in pairs(stato.giunti) do
				trovate += 1
			end
			warn(string.format("[Animazioni] Avatar %s: trovate solo %d articolazioni su %d, le pose potrebbero non vedersi.",
				tostring(stato.tipo), trovate, #(Pose.NomiGiunti[stato.tipo or "R15"])))
			warn("[Animazioni] Oggetti nel personaggio: " .. Pose.DescriviGiunti(character, stato.tipo))
		end
	end)
end)

-- Stepped arriva dopo l'Animator: le nostre pose si sommano all'animazione di quel frame.
RunService.Stepped:Connect(function(_, dt)
	for _, altro in ipairs(Players:GetPlayers()) do
		local character = altro.Character
		if character then
			aggiorna(character, altro == player, dt)
		end
	end
end)
