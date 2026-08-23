# KH2-JokCombat — TODO tecnico

## Direzione corrente — Sora

- Il capitolo Roxas è considerato concluso per lo scope del progetto.
- Le sezioni Roxas restano come archivio tecnico e baseline funzionante; non sono più la priorità attiva.
- Il focus corrente è Sora, a partire dall'inizio della sua storia.
- Tutte le growth sono a livello MAX ed equipaggiate negli slot nativi; Movement ripristina High Jump, Quick Run, Dodge Roll, Aerial Dodge e Glide su ON a ogni F1/load. Non esiste un gate automatico del costume: sulle vecchie save con outfit KH1 le quattro growth avanzate restano incompatibili e possono produrre T-pose.
- Combat Core: tutte le 25 Action Ability sono presenti; le 19 azioni operative sono equipaggiate, Auto Valor/Wisdom/Limit/Master/Final/Summon restano OFF e il nucleo Combo Master + Combo Plus `2 + 2` resta attivo.
- Le 23 Keyblade standard di Sora sono disponibili subito; Ultima Weapon, armi debug, Struggle e dummy Form restano escluse. Per eliminare lo stato `? ----`, Master riceve Bond of Flame e Final Oblivion solo quando il relativo weapon slot è zero; ogni scelta nonzero resta preservata.
- Le modifiche future devono usare il flag storia Sora e non riaprire il workstream Roxas salvo regressioni esplicite.

## Obiettivo generale

Trasformare il combat di Kingdom Hearts II Final Mix in un sistema più orientato a combo/stile Musou, sul modello di KH1-JokCombat, con particolare focus su:

- Roxas Dual-Wield come base iniziale.
- Oathkeeper + Oblivion come coppia di Keyblade.
- Combo branching futuro basato principalmente su input A / Y.
- Riutilizzo del combat engine nativo di KH2 quando possibile.
- Lua runtime solo quando serve davvero.
- Modifiche MSET/ANB/PTYA/ATKP native per comportamento, animazioni e hit properties.

---

# Stato attuale

## Completato

### 1. Roxas Dual-Wield runtime
- Identificato `P_EX110`:
  - Object ID `0x005A`
- Identificato `P_EX110_BTLF`:
  - Object ID `0x0323`
- Identificata MEMT entry del prologo:
  - `Index 3`
  - `Player = 0x005A`
- Implementata sostituzione runtime:
  - `0x005A -> 0x0323`
- Dual-Wield confermato funzionante in gameplay.

### 2. Oathkeeper + Oblivion
- Identificata Struggle Wand:
  - `0x01F5`
- Identificata Oblivion:
  - `0x002B`
- Implementata sostituzione runtime:
  - `0x01F5 -> 0x002B`
- Risultato:
  - Oathkeeper + Oblivion funzionanti.

### 3. Combo Master
- Ability:
  - `Combo Master = 0x021B`
  - equipaggiata = `0x821B`
- Modulo runtime separato.
- Combo Master confermato funzionante.

### 4. Fix T-pose wall hang
Problema:
- `P_EX110_BTLF.mset` non conteneva le animazioni necessarie per appendersi.

Identificati:
- Motion 7 = `HANG`
- Motion 8 = `HANG_UP`

Importati dal Roxas normale:
- slot `30` -> `R100`
- slot `34` -> `R101`

Risultato:
- appendimento alla parete funzionante.
- risalita funzionante.
- nessuna necessità di cambiare player object durante HANG.

### 5. Movimento vanilla fuori combattimento
Aggiunti al BTLF:
- slot `2` -> `R000` — idle vanilla
- slot `6` -> `R001` — walk vanilla
- slot `10` -> `R002` — run vanilla

Obiettivo:
- Roxas fuori combattimento usa postura/movement classico senza tenere continuamente le due Keyblade in stance Dual-Wield.

Risultato:
- funziona abbastanza bene.
- le Keyblade però spariscono senza una transizione Dual-Wield corretta.

---

# ARCHIVIO ROXAS — CHIUSO PER SCOPE

## A. Correggere il comportamento post-aerial / post-landing

### Problema osservato

Sequenza reale:

1. Roxas salta senza Keyblade.
2. Durante aerial attack compaiono Oathkeeper + Oblivion.
3. Roxas atterra con entrambe ancora visibili.
4. `LAND / R005` termina.
5. `R005` esegue `Blend to idle`.
6. KH2 passa immediatamente allo stato idle senza arma.
7. Le Keyblade spariscono di colpo.

### Informazioni già confermate

Motion:
- `JUMP` = Motion ID 3
- `FALL` = Motion ID 4
- `LAND` = Motion ID 5
- `LINK_IDLE` = Motion ID 6

`LAND / R005` contiene:
- `STATE: Blend to idle` verso la fine della motion.

La precedente ipotesi:
- usare gli slot fuori battle + weapon `3 / 7 / 11`

non ha risolto il problema.

Questo indica che, al momento del passaggio da LAND a IDLE, KH2 sta probabilmente già considerando Roxas nello stato **no weapon**, anche se le Keyblade sono ancora visibili per alcuni frame.

### Prossimo esperimento

Creare una versione diagnostica del MSET:

- `slot 2 -> S000`
- `slot 3 -> DUMM`
- `slot 27 -> DUMM`

Scopo:
- verificare definitivamente se, dopo LAND, KH2 seleziona davvero lo slot relativo `2`.

Risultato atteso se l'ipotesi è corretta:

`Aerial attack -> LAND -> S000 Dual-Wield stance`

con le Keyblade ancora visibili.

### Dopo la conferma

Non mantenere `S000` permanentemente nello slot 2.

La soluzione finale dovrà distinguere:

- idle normale/esplorazione:
  - `R000`
- breve fase post-attack/post-landing con armi ancora estratte:
  - `S000`

Possibili strade da valutare:
- stato runtime temporaneo;
- modifica del weapon state;
- modifica della transizione LAND;
- motion dedicata;
- logica nativa alternativa tramite MSET/ANB.

---

# TODO PARCHEGGIATO — DA RIPRENDERE PIÙ AVANTI

## B. Animazione Dual-Wield di sparizione/riposo delle Keyblade

### Problema

Quando KH2 torna allo stato senza arma, Oathkeeper e Oblivion spariscono senza una transizione visivamente corretta.

È stato provato:

- `slot 27 <- R010` del Roxas normale.

Risultato:
- viene usata un'animazione pensata per una singola Keyblade;
- il risultato sul Dual-Wield è scorretto/strano.

Questa soluzione è stata scartata.

### Osservazione importante

`P_EX110_BTLF` possiede:

- `slot 24 = S010`
- `slot 27 = DUMM`

`S010` è la transizione Dual-Wield già esistente associata al cambio verso la stance armata / LINK_IDLE.

Visivamente esiste una buona animazione di apparizione delle due Keyblade.

### Idea da conservare: S010 reversed

Creare una nuova motion derivata da `S010`, riprodotta realmente al contrario.

Non tramite:
- FPS negativo;
- flag ipotetico `reverse`.

Ma costruendo una nuova ANB/Motion:

`S010_FORWARD -> trasformazione temporale -> S010_REVERSE`

Per una interpolated motion:

- invertire il tempo delle key:
  - `newTime = FrameEnd - oldTime`
- riordinare le key.
- correggere tangenti/interpolazioni Hermite.
- mantenere coerenti pose iniziale/finale.
- valutare Range Trigger e frame event.

### Obiettivo finale

Entrata in combattimento:

`idle vanilla -> S010 -> Oathkeeper + Oblivion -> S000`

Uscita dal combattimento:

`S000 -> S010_REVERSE -> hide weapons -> R000`

### Punto ancora da risolvere

Invertire la motion scheletrica non garantisce automaticamente la sparizione delle Keyblade.

La visibilità delle armi sembra dipendere anche dallo stato weapon/player e non soltanto dalla motion.

Quindi servirà probabilmente sincronizzare:

1. animazione `S010_REVERSE`;
2. momento in cui KH2 cambia weapon state / nasconde le due armi.

### Stato

**PARCHEGGIATO.**

Non lavorare su questo punto fino a quando il problema post-landing non sarà risolto.

---

# TODO FUTURO — COMBAT SYSTEM

## C. Mappare completamente `P_EX110_BTLF`

Costruire una tabella completa:

- idle
- walk
- run
- jump
- fall
- land
- hang
- hang up
- ground attacks
- aerial attacks
- finishers
- special/reaction animations
- cancel/recovery motions

Per ogni motion registrare:
- Motion ID
- slot MSET
- nome ANB
- stato in battle / out of battle
- weapon / no weapon
- trigger
- durata
- eventuale ATKP associato

---

## D. Mappare PTYA -> Motion -> MSET/ANB -> ATKP

Obiettivo:

capire la pipeline completa di ogni attacco:

`input -> PTYA -> Motion ID -> MSET/ANB -> ATKP`

Serve come base per costruire combo deterministiche invece di sostituire animazioni alla cieca.

---

## E. Definire grammatica combo A / Y

Target stilistico:
- combo Musou;
- chaining facile;
- branching leggibile;
- forte libertà di continuazione;
- ground/air fluidi.

Esempio concettuale:

- `A`
- `A-A`
- `A-A-A`
- `A-A-Y`
- `A-Y`
- `A-Y-Y`
- `Y`
- `Y-Y`
- eventuali launcher / gap closer / finisher.

La grammatica definitiva va progettata solo dopo la mappatura delle motion disponibili.

---

## F. Regolare ATKP

Per ogni ramo combo:
- damage;
- hit reaction;
- knockback;
- revenge value;
- launcher;
- finisher flag;
- aerial behavior;
- stagger;
- crowd-control.

Obiettivo:
- feeling Musou;
- concatenazioni lunghe;
- evitare che i nemici interrompano troppo presto la combo;
- mantenere comunque una logica KH2 coerente.

---

## G. Cancel system

Valutare:
- attack -> attack cancel;
- attack -> jump;
- ground -> aerial;
- aerial -> continuation;
- landing cancel;
- recovery shortening;
- eventuali dodge/reaction cancel.

Da implementare preferibilmente tramite strutture native prima di introdurre Lua runtime.

---

# TODO FUTURO — SORA

## H. Applicare a Sora il movement/combat framework Dual-Wield

Obiettivo futuro:
- mantenere Sora come player object corretto;
- importare/adattare movement/stance/combat feeling del Roxas Dual-Wield;
- evitare sostituzioni complete del player object.

Le problematiche già incontrate con Roxas sono direttamente utili:
- motion mancanti;
- HANG/HANG_UP;
- weapon state;
- idle battle/out-of-battle;
- LINK_IDLE;
- transizioni weapon.

Il sistema finale dovrà essere basato su moveset completi e fallback controllati.

---

# Regole tecniche del progetto

1. Non modificare più campi del necessario.
2. Ogni nuovo MSET deve essere confrontato byte-per-byte con la versione precedente.
3. Ogni nuovo motion slot importato deve avere:
   - source file;
   - source slot;
   - target slot;
   - nome motion;
   - motivazione.
4. Conservare sempre:
   - versione vanilla;
   - ultima versione funzionante;
   - versione sperimentale corrente.
5. Separare:
   - `diagnostics/` — sola osservazione/log;
   - `runtime/` — write Lua;
   - `assets/` — asset nativi modificati.
6. Non introdurre Lua runtime quando una modifica MSET/ANB/PTYA/ATKP può risolvere il problema in modo nativo.
7. Ogni ipotesi deve essere testata con un cambiamento minimo e reversibile.

---

# Priorità corrente — Sora

1. Validare in gameplay Master con Bond of Flame e Final con Oblivion: apertura menu, cambio arma, trasformazione e ritorno non devono causare crash.
2. Validare le cinque growth ability MAX e il nucleo combo Sora completo.
3. Mappare movement, attacchi, finisher e cancel nativi di Sora.
4. Definire la combo architecture A/Y, poi regolare ATKP, cancel e feeling Musou mantenendo il motore nativo.
5. Conservare Roxas come baseline chiusa; riaprirlo solo per regressioni esplicite.
