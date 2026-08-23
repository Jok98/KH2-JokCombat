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

| Abilità | Slot save | ID livelli | Valore MAX equipaggiato |
| --- | --- | --- | --- |
| High Jump | `0x25CE` | `0x005E`–`0x0061` | `0x8061` |
| Quick Run | `0x25D0` | `0x0062`–`0x0065` | `0x8065` |
| Dodge Roll | `0x25D2` | `0x0234`–`0x0237` | `0x8237` |
| Aerial Dodge | `0x25D4` | `0x0066`–`0x0069` | `0x8069` |
| Glide | `0x25D6` | `0x006A`–`0x006D` | `0x806D` |

Il bit `0x8000` indica equipaggiata; `0x0FFF` estrae l'ID. Il modulo ispeziona tutti e cinque gli slot prima della prima write, accetta solo vuoto o un livello della famiglia attesa, quindi scrive e rilegge ogni valore.

Il costume iniziale KH1 usa `P_EX100_KH1F.mset`, dove sette slot Growth vanilla sono `DUMM`. L'asset JokCombat importa da `P_EX100.mset` le entry `A160`, `A150`, `A151`, `A170`–`A173` negli stessi indici 810, 814, 818, 822, 826, 830 e 834; `A180` era già identico e non viene modificato. La provenienza completa è in `docs/SORA_KH1F_GROWTH_MSET.md`.

## Nucleo combo Sora

| Abilità | ID | Copie target | Valore equipaggiato |
| --- | --- | --- | --- |
| Combo Master | `0x021B` | 1 | `0x821B` |
| Combo Plus | `0x00A2` | 2 | `0x80A2` |
| Air Combo Plus | `0x00A3` | 2 | `0x80A3` |

Il modulo scansiona i 69 slot standard da `Save+0x2544`, registra copie esistenti e slot vuoti, verifica la capacità prima della prima write, aggiunge soltanto le copie mancanti ed equipaggia ogni copia corrispondente. Non rimuove copie extra e non sovrascrive abilità estranee.

L'Ability Probe è read-only, usa la stessa guardia Sora e stampa ogni match della tabella standard, quindi due righe per ciascuna famiglia Combo Plus sono il risultato atteso.

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
