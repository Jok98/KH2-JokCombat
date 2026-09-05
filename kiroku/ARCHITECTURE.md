# Architettura

## Flussi principali

1. OpenKH legge `mod.yml` dalla clone installata `C:\Users\jok\Documents\KH_mod\openkh\mods\kh2\Jok98\KH2-JokCombat` e copia asset e script nel pacchetto KH2 composto.
2. LuaBackend carica gli script dalla cartella assoluta `C:\Users\jok\Documents\KH_mod\openkh\mod\kh2\scripts`.
3. Ogni script richiede `kh2lib`, versione minima 2, e rifiuta versioni di gioco non riconosciute.
4. I probe leggono e registrano stato; i moduli runtime modificano solo campi esplicitamente posseduti.
5. Gli asset MSET sostituiscono file nativi completi e devono essere confrontati per entry e contenuto.

## Confini

- `diagnostics/`: osservazione e log, nessuna write di memoria.
- `runtime/`: write Lua con guardie, verifica post-write e comportamento idempotente.
- `assets/`: MSET e futuri ANB/PTYA/ATKP modificati in modo nativo.
- `docs/`: ricerca tecnica e backlog storico.
- `kiroku/`: verità corrente, decisioni, vincoli, rischi e handoff.

## Movimento Sora

| Abilità | Slot save | Stato target |
| --- | --- | --- |
| High Jump | `0x25CE` | `0x8061` attiva |
| Quick Run | `0x25D0` | `0x8065` attiva |
| Dodge Roll | `0x25D2` | `0x8237` attiva |
| Aerial Dodge | `0x25D4` | `0x8069` attiva |
| Glide | `0x25D6` | `0x806D` attiva |

Il bit `0x8000` indica equipaggiata; `0x0FFF` estrae l'ID. Il modulo ispeziona tutti e cinque gli slot prima della prima write, accetta solo vuoto o un livello della famiglia attesa, quindi scrive e rilegge ogni valore.

Movement non prova a inferire il costume dal possesso di Valor o da un offset storia non verificato: applica sempre i cinque target MAX equipaggiati. Questo elimina la write che lasciava quattro growth OFF dopo ogni F1/load. Se in futuro servirà supportare automaticamente anche il costume KH1, il gate dovrà leggere un segnale diretto e verificato del modello/outfit; fino ad allora il rischio KH1 resta dichiarato invece di disabilitare silenziosamente le ability.

Il pacchetto non sostituisce più `P_EX100_KH1F.mset`: l'import di sette motion da `P_EX100.mset`, pur corretto a livello BAR, ha mantenuto la T-pose nel test gameplay ed è stato rimosso.

## Drive Form Sora

| Form | Bit unlock | Record save | Stato target | Prima ability | Default arma se vuoto |
| --- | --- | --- | --- | --- | --- |
| Valor | `ItemSet1 0x02` | `0x32F4` | Level 7, AbilityLevel 4 | High Jump MAX `0x8061` | preservato |
| Wisdom | `ItemSet1 0x04` | `0x332C` | Level 7, AbilityLevel 4 | Quick Run MAX `0x8065` | preservato |
| Limit | `ItemSet11 0x08` | `0x3364` | Level 7, AbilityLevel 4 | Dodge Roll MAX `0x8237` | preservato |
| Master | `ItemSet1 0x40` | `0x339C` | Level 7, AbilityLevel 4 | Aerial Dodge MAX `0x8069` | Bond of Flame `0x01F2` |
| Final | `ItemSet1 0x10` | `0x33D4` | Level 7, AbilityLevel 4 | Glide MAX `0x806D` | Oblivion `0x002B` |
| Anti | `ItemSet1 0x20` | nessuno | solo unlock; innate PLRP native | nessuna write record | nessuno |

Ogni record Final Mix è lungo `0x38` byte: weapon `+0`, Level `+2`, AbilityLevel `+3`, EXP `+4`, 24 ability short da `+8`. Forms valida Level/AbilityLevel/EXP e il primo slot growth prima della prima write; poi riusa/equipaggia le innate esistenti, aggiunge soltanto quelle mancanti e non scrive il campo weapon. Il modulo Keyblade possiede separatamente l'inizializzazione minima dei soli weapon slot Master/Final a zero. I target dei cinque record derivano dalle righe PLRP vanilla 129–133. La riga 134 descrive Anti, ma OpenKH conferma che `DriveForms[5]` è Summon: `0x340C` non viene quindi toccato.

I bit vengono aggiunti con OR: `Save+0x36C0 |= 0x76` e `Save+0x36CA |= 0x08`, senza rimuovere item estranei. Drive persistente usa `Save+0x3529/0x352A`; lo stato live usa `Slot1+0x1B0..0x1B2`. Il target è percentuale `100`, corrente `9`, massimo `9`, applicato solo con Sora in forma base.

Le ricompense FMLV inserite nella tabella standard sono Auto Valor/Wisdom/Limit/Master/Final, Combo Plus x2, MP Rage, MP Haste, Draw, Lucky Lucky x2, Air Combo Plus x2 e Form Boost x2. Le cinque Auto Form vengono conservate senza bit equipaggiato; le altre ricompense sono attive. Le due Lucky Lucky usano la formula nativa Final Mix `1 + (0,5 × copie equipaggiate)` per portare il drop item base a `2,0×`; copie aggiuntive sui personaggi in battaglia continuano a sommarsi normalmente. Il modulo controlla prima la capacità dei 69 slot, preserva abilità estranee e verifica ogni target dopo le write.

## AP Sora

Gli AP disponibili nel personaggio live risiedono nel byte `Slot1+0x18E`; `Save+0x24F8` è invece soltanto il numero persistente di AP Boost applicati. `KH2JokCombat_Forms.lua` scrive e verifica `0xFF`/255 quando Sora è pronto in forma base e lo ripristina dopo ogni ricostruzione di `Slot1`. Il target è il massimo assoluto rappresentabile dal campo; il contatore AP Boost della save non viene modificato.

L'Ability Probe registra sia AP live sia AP Boost applicati, restando read-only. Gli AP non vengono resi persistenti nella save: dipendono intenzionalmente dal modulo attivo, mentre Form, ability e Drive continuano a seguire la loro ownership persistente esistente.

## Inventario Keyblade Sora

OpenKH descrive `InventoryCount` come 320 byte da `Save+0x3580`. `KH2JokCombat_Keyblades.lua` possiede i 23 conteggi delle Keyblade standard di Sora diverse da Ultima Weapon e l'inizializzazione condizionale dei due weapon slot dual-wield anticipati: Master `Save+0x339C` e Final `Save+0x33D4`.

Prima di scrivere, il modulo legge il weapon slot base `Save+0x24F0` e i cinque slot secondari Form `Save+0x32F4`, `0x332C`, `0x3364`, `0x339C`, `0x33D4`. Se Master è zero pianifica Bond of Flame `0x01F2`; se Final è zero pianifica Oblivion `0x002B`. Quando una copia è nello stock, il conteggio viene decrementato mentre l'arma passa nello slot; se la stessa arma è già equipaggiata altrove e non esiste stock, il piano fallisce prima della prima write invece di duplicarla.

Dopo i default, una Keyblade con stock maggiore di zero o presente in uno dei sei slot è posseduta; solo un target ancora assente riceve conteggio `1`. Slot Master/Final non vuoti sono scelte del giocatore e restano invariati, così come Sora, Valor, Wisdom e Limit. Questo rende idempotenti F1/reload e consente al giocatore di cambiare successivamente i due default.

Ogni tentativo di write Keyblade entra nel journal prima di chiamare il backend. Se una write o verifica fallisce, il modulo ripristina in ordine inverso i valori ancora uguali al target scritto e verifica il rollback; non sovrascrive valori estranei. Un rollback incompleto viene segnalato con gli indirizzi interessati e il modulo resta disabilitato fino a F1. Questo copre anche eccezioni sollevate dopo una write già eseguita.

Ultima Weapon (`ID 0x01F4`, `Save+0x368F`) viene letta soltanto per verificarne la preservazione. Alpha/Omega Weapon, Struggle Sword/Wand/Hammer, Pureblood e Kingdom Key D non appartengono al pool standard richiesto. Nessun altro weapon slot viene scritto.

## Cost Limit Gummi

`KH2JokCombat_GummiCost.lua` possiede un solo byte persistente, `Save+0x10F0A`, che rappresenta il livello del limite costo del Gummi editor. Accetta il range documentato `0..6` e converge su `6`, equivalente a Cost Limit 1200; non modifica inventario dei blocchi, progressione missioni, costo già usato né limite Teeny Ship.

Il modulo non richiede `Slot1`, perché nel Gummi Garage non esiste un attore Sora live: verifica invece una save Sora caricata tramite `Save+0x1CEA & 0x01` e `Now` valido. Rilegge il byte immediatamente prima e dopo ogni write, ripara eventuali riscritture vanilla inferiori e, davanti a un valore superiore a `6`, preserva lo stato estraneo e si disabilita fino a F1. Il target non viene elevato oltre 1200 perché i valori fuori range possono produrre progetti invalidi all'avvio missione.

## Combat Core Sora

`KH2JokCombat_ComboMaster.lua` mantiene il nome file storico ma possiede l'intero pool Action standard di Sora e il nucleo combo. Gli ID derivano dalla lista Final Mix usata dal Randomizer:

| Stato | Target |
| --- | --- |
| ON — carrier Quadrato `Type 0` | Guard, Upper Slash, Horizontal Slash, Finishing Leap, Retaliating Slash e Counterguard |
| ON — comando | Trinity Limit |
| OFF ma presenti — speciali A `Type 1/2/3` | Slapshot, Dodge Slash, Flash Step, Slide Dash, Vicinity Break, Guard Break, Explosion, Aerial Sweep, Aerial Dive, Aerial Spiral, Aerial Finish e Magnet Burst |
| OFF ma presenti — Auto | Auto Valor, Wisdom, Limit, Master, Final e Summon |
| ON — combo support | Combo Master x1, Combo Plus x2 e Air Combo Plus x2 |

Il modulo scansiona i 69 slot da `Save+0x2544`, verifica la capacità prima della prima write, riusa le copie esistenti e aggiunge soltanto quelle mancanti. Il bit `0x8000` separa disponibilità e selezione: resta ON sui sei carrier Quadrato, Trinity e supporti; viene rimosso dalle dodici speciali che KH2 può scegliere automaticamente su A e dalle sei Auto. Le motion delle speciali restano disponibili per il remap MotionId dei carrier Type 0. Abilità estranee e copie extra non target restano intatte.

L'Ability Probe è read-only e riporta per ogni target quantità presente, quantità equipaggiata, stato atteso ON/OFF e slot occupati.

## Combat system pianificato

Il routing previsto separa la grammatica degli input dal proprietario del moveset:

`input A/Quadrato → arbitraggio ownership → ground/air e fase combo → profilo corrente → record d'azione nativo completo`

- A mantiene la catena normale; nel proof Normal Quadrato neutrale usa selector Guard con A319 Vicinity Break. Dopo A, Quadrato conserva la posizione e l'identità nativa Upper Slash del record 32; V5 Guard32 è respinta. Y/Triangolo resta nativo per Reaction Command e interazioni.
- Normal mantiene una profondita virtuale `1..4`: il primo A da neutrale prepara A1; A2+ avanza soltanto quando il motore mostra una nuova motion Base; A dopo Quadrato conserva il conteggio. Neutrale, timeout, UI e cambio Form azzerano lo stato.
- `KH2JokCombat_NormalCombo.lua` risolve la PTYA caricata dal `Btl0Pointer` e varia i MotionId Base 31/32/34. Il record 32 deve avere identità Upper Slash `12/0x12`; l'esatta firma legacy Guard `11/0x01` è ammessa solo come stato da recuperare a F1. Depth zero e contesti nativi ripristinano i fallback A315/A341; nessun indirizzo heap è hardcoded.
- Prima di usare la cache PTYA, il router rilegge `Btl0Pointer`: cambio o unload scartano indirizzi, profondità e input pendenti senza scrivere nella vecchia tabella. Ogni nuovo BAR passa di nuovo le firme e la baseline; un tasto già tenuto non diventa un nuovo edge.
- V1/V2 nella posizione offensiva non superano il gate hit/target; V3 negli slot 0/1 può rubare A; V5 nella posizione 32 viene letta ma rifiutata prima della motion. `KH2JokCombat_ActionProbe.lua` osserva quindi il confine dispatcher/cancel/hit-confirm senza write: M-03C confronta rolling snapshot pre-edge con motion/slot/finestra identici, mentre M-03D raggruppa le candidate in campi tipizzati e le correla ai target pointer in una riga per trial.
- Ogni Form reale mantiene modello, MSET/ANB, PTYA, ATKP, weapon state ed effetti propri; la grammatica A/Quadrato resta comune.
- R2 espone Normal, Dual e Feral come stance persistenti e Drive Cancel come transizione one-shot verso una vera Form; ogni switch deve rispettare finestre di cancellazione esplicite.
- L'aspetto visivo e il carrier tecnico sono separabili: una futura stance con aspetto di Sora base può usare sotto il cofano uno stato dual-wield o Anti compatibile, se asset e transizioni vengono verificati. Non si forza per default `P_EX100` a eseguire motion straniere.
- L'ordine minimo di ownership è menu/interazioni, Reaction Command, continuazioni native di Limit/magia, selezione R2, ramo Quadrato risolto dalla PTYA del carrier. `_OnFrame` non sintetizza input combat.

## Mappa carrier Sora

M-02 usa la pipeline retail `Objentry → NeoMoveset/PTYA → MotionId × 4 → MSET/ANB → trigger → ATKP/weapon/VFX`. `tools/analyze_movesets.py` verifica il fallback dei quattro slot player, il bone count motion/modello e conserva tutte le righe ATKP candidate senza assumere una dispatch `NeoStatus → SubId`.

| Ruolo | Carrier meccanico | Ponte/visual | Vincolo strutturale |
| --- | --- | --- | --- |
| Normal | `P_EX100` | Base nativa | 228 ossa, joint arma 1 |
| Dual esatto | `P_EX110_BTLF` | Final primario, Master backup | Roxas 229 ossa/joint 14: motion `Sxxx` non importabili direttamente |
| Feral | `P_EX100_HTLF` | futura texture Base | 228 ossa come Base, ma collisione Anti propria da preservare |

Final è preferita a Master come ponte dual perché il gruppo PTYA retail possiede famiglie ground e air complete; Master è air/hover. I due MSET arma Roxas contengono motion a 12 ossa e trigger suono/VFX, ma nessun trigger hitbox 10/33: le catene standard restano possedute dal carrier nativo.

La mappa dettagliata, le catene end-to-end e le lacune sono in `docs/SoraCombat_MovesetMap.md`. M-03 usa soltanto Base; Dual/Feral e varianti base-looking appartengono a M-04 o successive.

## Pattern da preservare

- Native-first: mantenere input, targeting, movimento, collisioni, hitbox, danno e transizioni del motore quando possibile.
- Fail-closed: firme, puntatori o valori inattesi devono impedire la modifica.
- Minimo cambiamento: una responsabilità per modulo e nessuna write estranea allo scopo.
- Verifica: rileggere ogni write e separare errore transitorio da violazione definitiva.

## Integrazioni

- OpenKH Mods Manager compone `Jok98/KH2-JokCombat` con `KH2FM-Mods-equations19/KH2-Lua-Library`.
- Gli editor del Launcher OpenKH sono strumenti preferenziali quando il formato è supportato: Mset/Mset Motion Editor per animazioni, Mdlx Editor per modelli, Map/Place Editor per ambienti e System/Object Editor per dati di sistema e oggetti. Usarli per ispezione e modifiche native verificabili; mantenere Lua per runtime state e routing che gli editor non coprono.
- La clone installata è la working copy canonica; `openkh/mod/kh2` è output di build e non una sorgente durevole.
- `LuaBackend.toml` punta alla cartella OpenKH live, non direttamente a questa repository.
- Ogni Build può sovrascrivere copie manuali nella cartella live, quindi il flusso corretto è modifica clone → Build → confronto hash → F1/test.
- La validazione finale richiede F1 e feedback/log dal gameplay reale.

## Logging

`runtime/KH2JokCombat_Log.lua` è un modulo `io_packages` condiviso. Espone i
flag `SYSTEM`, `COMBAT`, `DISPATCH`, `PROGRESSION`, `GUMMI`, `PROBE` e `TRACE`;
`ERROR` e `WARNING` bypassano sempre i flag. Il profilo diagnostico corrente
lascia ON soltanto `DISPATCH`.

Gli script emettono il formato `[Modulo][CATEGORIA] messaggio`. I quattro probe
storici controllano `PROBE`; `ActionProbe` controlla `DISPATCH`. Se il proprio
flag è OFF non caricano `kh2lib` né entrano nel lavoro per-frame. `NormalCombo`
usa `COMBAT` per il ramo richiesto e `TRACE` per depth, pending, cancel e reset.
