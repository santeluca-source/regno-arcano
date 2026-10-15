-- Le sei classi del Regno Arcano.
-- Ogni classe cambia sia il combattimento (dungeon) sia la base (bonus di produzione),
-- così il cambio classe ha senso in tutti e due i pilastri del gioco.
-- Condiviso tra server e client: il client lo usa solo per mostrare le informazioni.

local Classi = {}

Classi.Ordine = { "Arcanista", "Berserker", "Ombra", "Necromante", "Paladino", "Druido" }

-- Tipi di abilità (gestiti da server/Services/CombatService.lua):
--   Proiettile  colpisce il primo nemico in linea retta verso il punto mirato (portata)
--   Area        colpisce tutti i nemici attorno al giocatore (raggio)
--   Scatto      il giocatore scatta in avanti e colpisce dove arriva (raggio)
--   AreaRemota  colpisce un'area nel punto mirato, entro una distanza massima (portata, raggio)
--
-- Abilità speciali, tasto Q (gestite da server/Services/AbilitaService.lua):
--   Scudo   assorbe danni fino a `assorbe` per `durata` secondi
--   Furia   danno x`danno`, ricarica attacco x`ricaricaAttacco`, ma danni subiti x`dannoSubito`
--   Velo    quasi invisibile, i nemici ti ignorano; il colpo successivo fa danno x`colpo`
--   Evoca   evoca un alleato (`servitore`) che combatte per `durata` secondi
--   Aura    tu e gli alleati nel `raggio` subite il `riduzione` x100 % di danni in meno
--   Cura    cura tu e gli alleati nel `raggio` del `cura` x100 % della vita massima
Classi.Predefinita = "Arcanista"

Classi.Dati = {
	Arcanista = {
		ruolo = "Mago a distanza",
		descrizione = "Colpisce da lontano con dardi di energia pura.",
		colore = Color3.fromRGB(74, 225, 255),
		armaBase = "Bastone",
		statistiche = { vita = 90, velocita = 16 },
		abilita = { nome = "Dardo Arcano", tipo = "Proiettile", danno = 25, portata = 120, ricarica = 0.8 },
		speciale = { nome = "Barriera Arcana", tipo = "Scudo", ricarica = 15, durata = 6, assorbe = 60,
			descrizione = "Uno scudo che assorbe 60 danni" },
		bonusBase = { Oro = 1, Essenza = 1.5 },
	},
	Berserker = {
		ruolo = "Combattente in mischia",
		descrizione = "Tanta vita e colpi ad area da vicino.",
		colore = Color3.fromRGB(255, 127, 112),
		armaBase = "Ascia",
		statistiche = { vita = 140, velocita = 16 },
		abilita = { nome = "Ondata d'Urto", tipo = "Area", danno = 35, raggio = 10, ricarica = 1.0 },
		speciale = { nome = "Furia", tipo = "Furia", ricarica = 18, durata = 6, danno = 1.5, ricaricaAttacco = 0.5,
			dannoSubito = 1.25, descrizione = "Attacchi più forti e veloci, ma più fragile" },
		bonusBase = { Oro = 1.5, Essenza = 1 },
	},
	Ombra = {
		ruolo = "Assassino mobile",
		descrizione = "Scatta tra i nemici, veloce ma fragile.",
		colore = Color3.fromRGB(177, 72, 255),
		armaBase = "Lame",
		statistiche = { vita = 85, velocita = 20 },
		abilita = { nome = "Scatto d'Ombra", tipo = "Scatto", danno = 30, raggio = 7, ricarica = 0.9 },
		speciale = { nome = "Velo d'Ombra", tipo = "Velo", ricarica = 16, durata = 5, colpo = 3,
			descrizione = "Invisibile ai nemici; il prossimo colpo fa danno triplo" },
		bonusBase = { Oro = 1.25, Essenza = 1.25 },
	},
	Necromante = {
		ruolo = "Incantatore oscuro",
		descrizione = "Proiettili pesanti, più lenti ma più dannosi.",
		colore = Color3.fromRGB(120, 232, 164),
		armaBase = "Grimorio",
		statistiche = { vita = 95, velocita = 15 },
		abilita = { nome = "Lancia d'Ossa", tipo = "Proiettile", danno = 32, portata = 100, ricarica = 1.1 },
		speciale = { nome = "Servitore d'Ossa", tipo = "Evoca", ricarica = 20, durata = 15,
			descrizione = "Evoca uno scheletro che combatte per te",
			servitore = { nome = "Servitore d'Ossa", scala = 0.9, colore = Color3.fromRGB(170, 240, 190),
				velocita = 17, danno = 14, portata = 6, ricarica = 1 } },
		bonusBase = { Oro = 1.1, Essenza = 1.4 },
	},
	Paladino = {
		ruolo = "Difensore sacro",
		descrizione = "Resistente, colpisce tutto ciò che lo circonda.",
		colore = Color3.fromRGB(232, 180, 86),
		armaBase = "Martello",
		statistiche = { vita = 160, velocita = 14 },
		abilita = { nome = "Nova Sacra", tipo = "Area", danno = 28, raggio = 12, ricarica = 1.2 },
		speciale = { nome = "Aura Sacra", tipo = "Aura", ricarica = 20, durata = 8, raggio = 20, riduzione = 0.4,
			descrizione = "Tu e gli alleati vicini subite il 40% di danni in meno" },
		bonusBase = { Oro = 1.35, Essenza = 1 },
	},
	Druido = {
		ruolo = "Controllo della natura",
		descrizione = "Evoca tempeste a media distanza su gruppi di nemici.",
		colore = Color3.fromRGB(205, 235, 255),
		armaBase = "Ramo Runico",
		statistiche = { vita = 105, velocita = 16 },
		abilita = { nome = "Tempesta", tipo = "AreaRemota", danno = 26, raggio = 12, portata = 45, ricarica = 1.1 },
		speciale = { nome = "Rigenerazione", tipo = "Cura", ricarica = 18, raggio = 20, cura = 0.35,
			descrizione = "Cura te e gli alleati vicini del 35% della vita" },
		bonusBase = { Oro = 1.15, Essenza = 1.3 },
	},
}

function Classi.Esiste(nome)
	return Classi.Dati[nome] ~= nil
end

return Classi
