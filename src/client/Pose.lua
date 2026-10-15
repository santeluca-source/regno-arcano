-- Pose costruite via codice: ruotiamo le articolazioni (Motor6D) del personaggio
-- sopra l'animazione normale di Roblox, con un "peso" da 0 a 1 per sfumare.
-- Le pose vanno applicate in RunService.Stepped, cioè dopo che l'Animator ha già
-- aggiornato le articolazioni in quel frame.
--
-- Ci sono due versioni di ogni posa:
--   R15 (avatar moderni): rotazione sull'asse X; per anche e spalle un angolo positivo
--       porta l'arto IN AVANTI, per busto e collo un angolo negativo piega IN AVANTI
--   R6  (avatar classici): rotazione sull'asse Z; il lato sinistro è a specchio, quindi
--       "in avanti" è positivo a destra e negativo a sinistra

local Pose = {}

local rad = math.rad
local A = CFrame.Angles

-- Articolazioni che usiamo per ogni tipo di avatar.
Pose.NomiGiunti = {
	R15 = {
		"Waist", "Neck",
		"LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow",
		"LeftHip", "RightHip", "LeftKnee", "RightKnee",
	},
	R6 = { "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" },
}

Pose.Scatto = {
	-- Scatto: piegato in avanti, braccia indietro, gambe in falcata lunga.
	R15 = {
		Waist = A(rad(-28), 0, 0),
		Neck = A(rad(15), 0, 0),
		LeftShoulder = A(rad(-75), 0, rad(-10)),
		RightShoulder = A(rad(-75), 0, rad(10)),
		LeftElbow = A(rad(-10), 0, 0),
		RightElbow = A(rad(-10), 0, 0),
		LeftHip = A(rad(40), 0, 0),
		RightHip = A(rad(-45), 0, 0),
		LeftKnee = A(rad(-55), 0, 0),
		RightKnee = A(rad(-25), 0, 0),
	},
	R6 = {
		["Right Shoulder"] = A(0, 0, rad(-80)),
		["Left Shoulder"] = A(0, 0, rad(80)),
		["Right Hip"] = A(0, 0, rad(35)),
		["Left Hip"] = A(0, 0, rad(45)),
	},
}

Pose.DoppioSalto = {
	-- Doppio salto: ginocchia raccolte, braccia aperte in alto.
	R15 = {
		Waist = A(rad(-12), 0, 0),
		LeftHip = A(rad(75), 0, 0),
		RightHip = A(rad(55), 0, 0),
		LeftKnee = A(rad(-95), 0, 0),
		RightKnee = A(rad(-85), 0, 0),
		LeftShoulder = A(rad(35), 0, rad(-40)),
		RightShoulder = A(rad(35), 0, rad(40)),
		LeftElbow = A(rad(25), 0, 0),
		RightElbow = A(rad(25), 0, 0),
	},
	R6 = {
		["Right Shoulder"] = A(0, 0, rad(60)),
		["Left Shoulder"] = A(0, 0, rad(-60)),
		["Right Hip"] = A(0, 0, rad(60)),
		["Left Hip"] = A(0, 0, rad(-60)),
	},
}

Pose.CorsaAnime = {
	-- Corsa "anime": busto in avanti, testa alta, braccia tese all'indietro.
	-- Le gambe restano quelle dell'animazione di corsa di Roblox.
	R15 = {
		Waist = A(rad(-32), 0, 0),
		Neck = A(rad(22), 0, 0),
		LeftShoulder = A(rad(-80), 0, rad(-8)),
		RightShoulder = A(rad(-80), 0, rad(8)),
		LeftElbow = A(rad(-8), 0, 0),
		RightElbow = A(rad(-8), 0, 0),
	},
	R6 = {
		["Right Shoulder"] = A(0, 0, rad(-80)),
		["Left Shoulder"] = A(0, 0, rad(80)),
	},
}

-- Un'articolazione può essere un Motor6D (sistema classico) oppure un
-- AnimationConstraint (nuovo sistema "Avatar Joint Upgrade" di Roblox):
-- entrambi hanno la proprietà Transform che usiamo per la posa.
local function eArticolazione(oggetto)
	return oggetto:IsA("Motor6D") or oggetto:IsA("AnimationConstraint")
end

-- Trova le articolazioni di un personaggio.
-- Restituisce: tipo ("R15" | "R6" | nil), tabella [nome] = articolazione, completo (bool)
function Pose.Giunti(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil, {}, false
	end
	local tipo = humanoid.RigType == Enum.HumanoidRigType.R15 and "R15" or "R6"
	local nomi = Pose.NomiGiunti[tipo]
	local trovati, numero = {}, 0
	for _, discendente in ipairs(character:GetDescendants()) do
		if eArticolazione(discendente) and table.find(nomi, discendente.Name) then
			trovati[discendente.Name] = discendente
			numero += 1
		end
	end
	return tipo, trovati, numero >= #nomi
end

-- Per la diagnosi: che tipo di oggetto c'è nel personaggio con i nomi delle articolazioni?
-- Es. "Neck=Motor6D, Waist=AnimationConstraint, LeftHip=(manca)"
function Pose.DescriviGiunti(character, tipo)
	local pezzi = {}
	for _, nome in ipairs(Pose.NomiGiunti[tipo or "R15"]) do
		local classi = {}
		for _, discendente in ipairs(character:GetDescendants()) do
			if discendente.Name == nome then
				table.insert(classi, discendente.ClassName)
			end
		end
		table.insert(pezzi, nome .. "=" .. (#classi > 0 and table.concat(classi, "/") or "(manca)"))
	end
	return table.concat(pezzi, ", ")
end

-- Sfuma la posa sopra l'animazione attuale. peso 0 = nessun effetto, 1 = posa piena.
-- posa è una delle tabelle sopra (con le versioni R15 e R6).
function Pose.Applica(tipo, giunti, posa, peso)
	local versione = tipo and posa[tipo]
	if not versione or peso <= 0 then
		return
	end
	peso = math.min(peso, 1)
	for nome, obiettivo in pairs(versione) do
		local giunto = giunti[nome]
		if giunto and giunto.Parent then
			giunto.Transform = peso >= 1 and obiettivo or giunto.Transform:Lerp(obiettivo, peso)
		end
	end
end

return Pose
