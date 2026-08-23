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

| Abilità | Slot save | Costume KH1 | Costume KH2 |
| --- | --- | --- | --- |
| High Jump | `0x25CE` | `0x8061` attiva | `0x8061` attiva |
| Quick Run | `0x25D0` | `0x0065` disabilitata | `0x8065` attiva |
| Dodge Roll | `0x25D2` | `0x0237` disabilitata | `0x8237` attiva |
| Aerial Dodge | `0x25D4` | `0x0069` disabilitata | `0x8069` attiva |
| Glide | `0x25D6` | `0x006D` disabilitata | `0x806D` attiva |

Il bit `0x8000` indica equipaggiata; `0x0FFF` estrae l'ID. Il modulo ispeziona tutti e cinque gli slot prima della prima write, accetta solo vuoto o un livello della famiglia attesa, quindi scrive e rilegge ogni valore.

Il profilo usa `Save+0x36C0 & 0x02` (possesso di Valor) come proxy persistente dell'evento vanilla che assegna i vestiti KH2. In assenza del bit il default è fail-safe: solo High Jump equipaggiato. Il runtime rivaluta il profilo dopo loading/title e quando il bit cambia durante la sessione.

Il pacchetto non sostituisce più `P_EX100_KH1F.mset`: l'import di sette motion da `P_EX100.mset`, pur corretto a livello BAR, ha mantenuto la T-pose nel test gameplay ed è stato rimosso.

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
