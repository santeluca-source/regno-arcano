# Regno Arcano

Tycoon fantasy con dungeon, piazza multiplayer e sei classi.
Il codice vive in `src/` e viene sincronizzato in Roblox Studio con **Rojo**.

## Struttura

```
src/
  shared/Config/          -> ReplicatedStorage.Shared.Config (numeri e regole, condivisi)
    Classi.lua              le 6 classi: statistiche, attacco, abilità Q, bonus all'isola
    Valute.lua              Oro, Essenza, Frammenti
    Rarita.lua              rarità del loot e tabelle di drop
    Tycoon.lua              tutto ciò che si costruisce sull'isola (prezzi, posizioni)
    Dungeon.lua             nemici e dungeon (Rovine, Cripta)
    Equipaggiamento.lua     effetti degli oggetti, vendita, Fabbro
    Pozioni.lua             pozioni dell'Alchimista
    Piazza.lua              Mercante, missioni, Gilda, scambi
    Tutorial.lua            passi della guida per i nuovi giocatori
  server/                 -> ServerScriptService.Server
    Main.server.lua         avvia i servizi in ordine
    Services/               un servizio per ogni parte del gioco
      PlayerData.lua          profilo + salvataggio (il collante di tutto)
      ...
    Tycoon/ Dungeon/ Piazza/ Combattimento/   costruzione dei modelli ed effetti
  client/                 -> StarterPlayer.StarterPlayerScripts.Client
    HUD, Combattimento, Speciale, Pozioni, Inventario, Scambi
_vecchio/                 prototipo precedente (solo come riferimento)
```

Regola d'oro: **solo il server modifica i dati, e solo passando da `PlayerData`**.
Il client vede i dati tramite gli Attributi del Player e chiede le azioni con i RemoteEvent;
il server controlla sempre tutto.

## Collegare Rojo

1. `rojo serve` dalla cartella del progetto
2. In Studio: scheda Plugins → Rojo → **Connect**

Modifica il codice in `src/`, non in Studio: Rojo sovrascrive gli script sincronizzati.

## Comandi di test (solo in Studio)

In chat: `/risorse` (tante valute), `/oggetti` (8 oggetti), `/reset` (azzera i progressi),
`/centro` (elenca oggetti estranei nella Piazza). Nel gioco pubblicato non funzionano.

## Prima di pubblicare

Su Roblox (Studio → Home → **Game Settings**, o dalla pagina Creator Dashboard):

- [ ] **Places → Max Players = 8**: ci sono 8 isole, il nono giocatore non ne avrebbe una.
- [ ] **Security → Enable Studio Access to API Services**: serve solo per provare i salvataggi in Studio.
- [ ] Nel place, elimina eventuali resti del vecchio prototipo (all'avvio l'Output dice se ce ne sono)
      e le copie `TycoonWorld_Backup...` in ServerStorage.
- [ ] Prova con più giocatori: scheda **Test → Clients and Servers**, 2-3 giocatori
      (scambi, spedizioni della Gilda, Piazza).
- [ ] Prova su telefono: scheda **Test → Device** (emulatore) per controllare i pulsanti.
- [ ] Compila il **questionario sulla maturità** (Creator Dashboard → Audience → Questionnaire):
      Roblox lo richiede prima di rendere pubblico il gioco.
- [ ] Icona, miniature, descrizione e genere (Creator Dashboard → Configure).
- [ ] Prima un test chiuso: rendi il gioco pubblico solo agli amici, poi a tutti.

Da **non** cambiare dopo la pubblicazione: il nome del DataStore in `PlayerData.lua`
(`RegnoArcano_Giocatori_v3`), altrimenti tutti i giocatori perdono i progressi.

### Protezioni già presenti

- Blocco di sessione: un solo server alla volta usa i dati di un giocatore.
- Salvataggi ravvicinati raggruppati, per restare nei limiti di Roblox.
- Se la lettura dei dati fallisce, si gioca senza salvare (niente sovrascritture di dati buoni).
- Tutte le azioni dei client (acquisti, attacchi, scambi, Fabbro...) sono controllate dal server.

### Limiti noti

- Uno scambio salva i due giocatori uno dopo l'altro: se il server cadesse esattamente in mezzo,
  un oggetto potrebbe duplicarsi o perdersi. Molto raro.
- 8 giocatori per server (uno per isola).

## Roadmap

- [x] 1. Fondamenta: struttura, dati, salvataggio, classi, HUD
- [x] 2. Tycoon: isola personale, miniere, nastro, raffinatore, forziere, strutture d'Essenza
- [x] 3. Combattimento: armi e abilità delle classi, golem d'allenamento
- [x] 4. Primo dungeon: Rovine Dimenticate, boss, loot a rarità
- [x] 5. Piazza: ponti, Mercante, Bacheca missioni, Portale della Gilda, targhette
- [x] 6. Espansione
  - [x] Menu dell'inventario (tasto I)
  - [x] Secondo dungeon: Cripta di Ghiaccio
  - [x] Abilità speciali (tasto Q)
  - [x] Pozioni (Alchimista, tasti Z/X/C) e Fabbro (+1 ... +10)
  - [x] Scambi tra giocatori (tasto T nella Piazza)
  - [x] Pubblicazione: blocco di sessione, salvataggi raggruppati, tutorial, pulsanti per telefono
