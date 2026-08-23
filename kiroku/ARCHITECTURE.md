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

| Abilità | Slot save | Stato conservativo |
| --- | --- | --- |
| High Jump | `0x25CE` | `0x8061` attiva |
| Quick Run | `0x25D0` | `0x0065` disabilitata |
| Dodge Roll | `0x25D2` | `0x0237` disabilitata |
| Aerial Dodge | `0x25D4` | `0x0069` disabilitata |
| Glide | `0x25D6` | `0x006D` disabilitata |

Il bit `0x8000` indica equipaggiata; `0x0FFF` estrae l'ID. Il modulo ispeziona tutti e cinque gli slot prima della prima write, accetta solo vuoto o un livello della famiglia attesa, quindi scrive e rilegge ogni valore.

Il possesso di Valor non identifica più il costume perché `KH2JokCombat_Forms.lua` lo assegna subito. Movement applica quindi sempre il profilo KH1 già verificato: solo High Jump equipaggiato. Un futuro profilo KH2 richiede un segnale diretto del modello/outfit, non un evento di progressione.

Il pacchetto non sostituisce più `P_EX100_KH1F.mset`: l'import di sette motion da `P_EX100.mset`, pur corretto a livello BAR, ha mantenuto la T-pose nel test gameplay ed è stato rimosso.

## Drive Form Sora

| Form | Bit unlock | Record save | Stato target | Prima ability |
| --- | --- | --- | --- | --- |
| Valor | `ItemSet1 0x02` | `0x32F4` | Level 7, AbilityLevel 4 | High Jump MAX `0x8061` |
| Wisdom | `ItemSet1 0x04` | `0x332C` | Level 7, AbilityLevel 4 | Quick Run MAX `0x8065` |
| Limit | `ItemSet11 0x08` | `0x3364` | Level 7, AbilityLevel 4 | Dodge Roll MAX `0x8237` |
| Master | `ItemSet1 0x40` | `0x339C` | Level 7, AbilityLevel 4 | Aerial Dodge MAX `0x8069` |
| Final | `ItemSet1 0x10` | `0x33D4` | Level 7, AbilityLevel 4 | Glide MAX `0x806D` |
| Anti | `ItemSet1 0x20` | nessuno | solo unlock; innate PLRP native | nessuna write record |

Ogni record Final Mix è lungo `0x38` byte: weapon `+0`, Level `+2`, AbilityLevel `+3`, EXP `+4`, 24 ability short da `+8`. Il modulo valida Level/AbilityLevel/EXP e il primo slot growth prima della prima write; poi riusa/equipaggia le innate esistenti, aggiunge soltanto quelle mancanti e preserva extra e weapon slot. I target dei cinque record derivano dalle righe PLRP vanilla 129–133. La riga 134 descrive Anti, ma OpenKH conferma che `DriveForms[5]` è Summon: `0x340C` non viene quindi toccato.

I bit vengono aggiunti con OR: `Save+0x36C0 |= 0x76` e `Save+0x36CA |= 0x08`, senza rimuovere item estranei. Drive persistente usa `Save+0x3529/0x352A`; lo stato live usa `Slot1+0x1B0..0x1B2`. Il target è percentuale `100`, corrente `9`, massimo `9`, applicato solo con Sora in forma base.

Le ricompense FMLV inserite nella tabella standard sono Auto Valor/Wisdom/Limit/Master/Final, Combo Plus x2, MP Rage, MP Haste, Draw, Lucky Lucky, Air Combo Plus x2 e Form Boost x2. Le cinque Auto Form vengono conservate senza bit equipaggiato; le altre ricompense sono attive. Il modulo controlla prima la capacità dei 69 slot, preserva abilità estranee e verifica ogni target dopo le write.

## AP Sora

Gli AP disponibili nel personaggio live risiedono nel byte `Slot1+0x18E`; `Save+0x24F8` è invece soltanto il numero persistente di AP Boost applicati. `KH2JokCombat_Forms.lua` scrive e verifica `0xFF`/255 quando Sora è pronto in forma base e lo ripristina dopo ogni ricostruzione di `Slot1`. Il target è il massimo assoluto rappresentabile dal campo; il contatore AP Boost della save non viene modificato.

L'Ability Probe registra sia AP live sia AP Boost applicati, restando read-only. Gli AP non vengono resi persistenti nella save: dipendono intenzionalmente dal modulo attivo, mentre Form, ability e Drive continuano a seguire la loro ownership persistente esistente.

## Combat Core Sora

`KH2JokCombat_ComboMaster.lua` mantiene il nome file storico ma possiede l'intero pool Action standard di Sora e il nucleo combo. Gli ID derivano dalla lista Final Mix usata dal Randomizer:

| Gruppo | Target |
| --- | --- |
| Ground/defense | Guard, Upper Slash, Horizontal Slash, Finishing Leap, Retaliating Slash, Slapshot, Dodge Slash, Flash Step, Slide Dash, Vicinity Break, Guard Break, Explosion e Counterguard |
| Air | Aerial Sweep, Aerial Dive, Aerial Spiral, Aerial Finish e Magnet Burst |
| Limit | Trinity Limit |
| Auto | Auto Valor, Wisdom, Limit, Master, Final e Summon presenti ma disabilitate |
| Combo support | Combo Master x1, Combo Plus x2 e Air Combo Plus x2 equipaggiati |

Il modulo scansiona i 69 slot da `Save+0x2544`, verifica la capacità prima della prima write, riusa le copie esistenti e aggiunge soltanto quelle mancanti. Ogni copia target viene portata allo stato richiesto: bit `0x8000` sulle 19 Action operative e sul nucleo combo, bit rimosso sulle sei Auto. Abilità estranee e copie extra non target restano intatte.

L'Ability Probe è read-only e riporta per ogni target quantità presente, quantità equipaggiata, stato atteso ON/OFF e slot occupati.

## Pattern da preservare

- Native-first: mantenere input, targeting, movimento, collisioni, hitbox, danno e transizioni del motore quando possibile.
- Fail-closed: firme, puntatori o valori inattesi devono impedire la modifica.
- Minimo cambiamento: una responsabilità per modulo e nessuna write estranea allo scopo.
- Verifica: rileggere ogni write e separare errore transitorio da violazione definitiva.

## Integrazioni

- OpenKH Mods Manager compone `Jok98/KH2-JokCombat` con `KH2FM-Mods-equations19/KH2-Lua-Library`.
- La clone installata è la working copy canonica; `openkh/mod/kh2` è output di build e non una sorgente durevole.
- `LuaBackend.toml` punta alla cartella OpenKH live, non direttamente a questa repository.
- Ogni Build può sovrascrivere copie manuali nella cartella live, quindi il flusso corretto è modifica clone → Build → confronto hash → F1/test.
- La validazione finale richiede F1 e feedback/log dal gameplay reale.
