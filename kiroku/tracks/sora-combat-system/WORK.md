# Lavoro

## In corso

### Attività: Costruire l'albero combo Base `A^n □^m A^k`

Status: in_progress
Completion:
Il proof Guard→Vicinity supera neutral Square, hitbox/danno e A-miss→Quadrato; poi i quattro prefissi A, i Quadrati successivi e le continuazioni A producono nodi distinti senza avanzare su input rifiutati.

Note:
- Seconda prova F1: pulse su A312 frame 58 e A319 frame 32 senza branch; Quadrato fisico → A310. `_OnFrame` è troppo tardo per questa dispatch.
- `KH2JokCombat_NormalRouter.lua`, relativo smoke e manifest entry sono rimossi dalla repo canonica e dal runtime live; il probe read-only resta.
- OpenKH non espone `ptya` fra i `listpatch`, ma supporta la copia del subfile `ptya` dentro `00battle.bin` con `binarc`; un esempio pubblico usa esattamente questo formato.
- `tools/build_normal_ptya.py` continua a produrre il fallback statico con A322/A315/A341 e identità Upper Slash nativa sul 32. A runtime `NormalCombo` cambia record 31 A322→A319 e i soli MotionId 32/34 whitelisted; la firma V5 `11/0x01` viene soltanto recuperata a F1. Finishing Leap, Counterguard e Retaliating Slash restano byte-identici.
- Unit test Python 3/3, sei smoke Lua, YAML e round-trip OpenKH BAR superati; tutti i 20 subfile estratti corrispondono al progetto sorgente e la PTYA risultante ha SHA-256 `B3029F6D8CCE48B6EE40EA9F6CD7460BB7F24F013642931905617259FF8B7C68`.
- Il test utente ha ancora registrato A310 Upper Slash: non era un fallimento del record, perché `OpenKh.Tools.ModsManager.log` mostrava che `00battle.bin` veniva saltato per base estratta mancante. Installata in `openkh/data/kh2/00battle.bin` la base retail verificata SHA-256 `1968DE0B23E8883A133982C755AC2A6C97FA9514A92F287F537D1EB0D8D3B200`.
- `KH2JokCombat_NormalCombo.lua` risolve la PTYA live senza indirizzo heap hardcoded, verifica i sei record, varia i MotionId 31/32/34 fra valori Base whitelisted e richiede sul 32 l'identità nativa `12/0x12`. L'esatta coppia Guard legacy è ammessa soltanto per ripristinarla. Record 31 usa A319; le profondita 2+ attendono una nuova motion per confermare l'A.
- Il proof profile usa ground A310/A311/A318/A315 e air A341/A342/A345/A343; i Quadrati extra restano follow-up nativi fino alla validazione delle prime celle.
- Smoke dedicato `KH2JokCombat_NormalCombo_Smoke.lua` passato; nessun carrier Dual/Feral, palette R2 o Drive Cancel entra nello slice.
- Il proof live ha avviato A319 senza target solo standalone. `A□` a vuoto non parte: il log passa da `depth=0 owner=GUARD_CARRIER` a `depth=1 ... A310 owner=NATIVE_DISPATCH`, dimostrando che dopo A KH2 usa record 32 e mantiene il gate hit-confirm. Hitbox/danno A319 restano non dichiarati.
- `KH2JokCombat_TargetlessProbe.lua` ha raccolto tre casi a vuoto rifiutati e tre casi con nemico accettati. I cambiamenti ricorrenti non sono un gate sicuro: `+0x0098/+0x00A0` contengono puntatori valorizzati con il bersaglio e `+0x0297` appartiene al `MaxBBOX` del modello.
- Il log live ha respinto la V1: due `A□` a vuoto validamente armati con il solo `Type=3` hanno prodotto `REJECTED`; entrambi i rollback `3→0` sono riusciti. Il tentativo `AA` era sotto `Reaction=0x001E` e non aveva armato la prova, ma il requisito targetless era già fallito.
- Il log live ha respinto anche la V2: cinque `A□` a vuoto con `Reaction=0x0000` sono stati armati `Type=3 + Ability=0`, hanno prodotto cinque `REJECTED` e hanno sempre ripristinato la baseline.
- Il log live ha respinto la V3: il primo `A□` con `Reaction=0x0000` ha prodotto `RESULT #001 REJECTED` e rollback; una prova successiva ha fatto partire A310 Upper Slash sull'A prima di Quadrato, attivando `HIJACK_BEFORE_SQUARE` e un secondo rollback. L'esperimento è escluso dal manifest/runtime; il sorgente e lo smoke restano come prova storica.
- La V5 ha preparato posizione 32, identità Guard e A310 corretti, ma il live test ha prodotto `SQUARE_RESULT REJECTED ... RESET_IDLE`. V5 è ritirata e non viene più armata; lo smoke copre il recupero F1 di RAM legacy e conferma che una nuova rotta conserva `12/0x12`.
- M-03B ha raccolto 3 neutral accepted contro 2 after-A rejected e 57 differenze stabili, ma gli snapshot erano post-dispatch. Nei log hit/miss, `#009/#011` erano accettazioni da motion diverse, `#010` una rejection da A319, `#012` un duplicato della risoluzione `#011` e `#013` partiva con A310 già attiva: `stable=0` non era un confronto valido.
- M-03C aggiorna `ActionProbe`: quattro `ReadArray` conservano il frame precedente; i campioni sono separati per motion, slot e finestra `EARLY/MID/LATE`; edge di risoluzione e motion già attiva non creano trial. Il live test ha raccolto quattro `RESET_IDLE` omogenei su `A300 0x0097/0x025C LATE` (age 17–24), mentre i casi hit accettati partivano da A318/A319 e non appartenevano allo stesso bucket.
- Implementato il profilo A-base nel Combat Core: 25 Action presenti, sei carrier Quadrato + Trinity ON, dodici speciali A + sei Auto OFF e supporti combo ON. Il live test ha chiuso lo stesso bucket A300 LATE a `2 accepted / 2 rejected`; i casi hit avviano A310 con la speciale OFF.
- M-03D ha eliminato target pointer e sei campi correlati come permessi binari. `+0x123` è il bit 25 del dword packed `PLAYER+0x120`: l'eseguibile Steam hash-verificato contiene setter, un test nel consumer dell'evento e clear dopo il consumo. M-03E estende i sample ad A300/A301/A302 e registra soltanto ingresso, transizioni e uscita del bit; resta zero-write.

## TODO

### Attività: Produrre e validare il profilo PTYA Base completo

Status: completed
Completion:
Il tool genera una PTYA da hash retail, cambia soltanto i due MotionId previsti, produce un diff riproducibile e il pack/unpack OpenKH conserva tutti i subfile.

### Attività: Raccogliere il confronto targetless/hit del probe M-03

Status: completed
Completion:
I log separano casi rifiutati a vuoto e accettati con nemico; tutti i candidati ripetibili sono classificati come puntatori target o bounding box e vengono esclusi dalle write.

### Attività: Validare il candidato PTYA `Type=3` da solo

Status: completed
Completion:
Respinto: due `A□` a vuoto hanno prodotto `REJECTED`; il rollback `Type=0` è riuscito senza stato residuo.

### Attività: Validare il candidato PTYA `Type=3 + Ability=0`

Status: completed
Completion:
Respinto: cinque `A□` a vuoto con `Reaction=0x0000` hanno prodotto `REJECTED`; script caricato, write e rollback erano corretti, quindi Type/Ability sui record Square non bastano.

### Attività: Validare V3 con shadow carrier PTYA 0/1

Status: completed
Completion:
Respinto: `A□` targetless è rimasto bloccato e il carrier prioritario ha poi sostituito un A con Upper Slash prima di Quadrato. L'auto-reject e i due rollback hanno funzionato, quindi non è rimasto stato PTYA residuo.

## Bloccato

- Nessun blocco esterno: il prossimo checkpoint è una prova M-03E read-only che ordini temporalmente bit 25, contatto e Quadrato su A300/A301/A302; finché non è chiusa, l'albero non riceve write speculative.

## Fatto

- Cache PTYA invalidata al cambio/unload del BAR, nuova baseline senza edge da tasti tenuti e blocco su replacement invalido o errore di lettura; regressioni mock aggiunte allo smoke NormalCombo.
- Completata M-02 con estrazione retail a hash, analyzer read-only e `docs/SoraCombat_MovesetMap.md`: 8 carrier, 118 record PTYA, 78 hitbox esplicite e due MSET arma Roxas correlati.
- Verificato il mismatch Roxas/Sora (229/228 ossa, joint 14/1), scelto Final come donor dual Sora primario e Master come backup air; Anti resta carrier Feral nativo con collisione propria.
- Tracciate end-to-end Explosion `A315`, Anti `F302`/`F331`, Final `E303` e Master `D334`; preservata come lacuna la hit-path implicita delle catene Roxas Dual standard.
- Completata M-01 tramite evidenza aggregata da più reload/processi: A/Y/R2 e quattro D-pad calibrati, UI e Base/Wisdom/Valor osservate, input aerei riusciti su Critical senza T-pose/crash; la mancata correlazione Y+Reaction resta documentata per un eventuale routing Y futuro ma non blocca A/Quadrato.
- Definita la baseline read-only con campo input version-aware, campi osservabili e protocollo a due sessioni.
- Aggiunto `KH2JokCombat_CombatProbe.lua`: registra edge campionati e contesto senza scritture e mantiene action/motion/ground-air/weapon live come `UNKNOWN`.
- Corretto il sentinel `CurrentOpenMenu=0xFF`, aggiunta acquisizione raw32/high16 e ridotto il rumore dei context log dopo la prima prova gameplay.
- Calibrati A/Y sulle impronte raw32 Steam reali; localizzato R2 a `Input+0x04 == 0x09` e sostituito lo scanner largo con lettura diretta read-only, uguaglianza esatta e fallback fail-closed.
- Aggiunti matrice T-01–T-09, smoke test anti-write e asset OpenKH; manifest e tutti gli smoke test risultano validi.
- Adottata grammatica A/Quadrato: Guardia e Action Ability native su Quadrato, Y/Triangolo interamente nativo; palette R2 Normal/Dual/Feral più Drive Cancel e separazione fra aspetto e carrier restano invariati.
- Creato il track con roadmap M-01–M-08; M-01 e M-02 sono completate e M-03 è la prossima milestone.

## Annullato

- Nessuna attività annullata.
