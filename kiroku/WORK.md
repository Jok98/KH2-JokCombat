# Lavoro

## In corso

### Attività: Ridurre e categorizzare i log runtime

Status: ongoing

Completamento:
Dopo Build e F1, il profilo M-03C mostra soltanto errori, avvisi e righe
`DISPATCH`; i flag centrali riattivano singolarmente le altre categorie. Con
`PROBE = false` i quattro diagnostici storici restano inerti e con
`DISPATCH = false` anche `ActionProbe` non carica `kh2lib` né lavora per-frame.

Note:
- La suite comprende 12 smoke Lua, 3 test Python, manifest e hash PTYA; `pnpm test` usa dipendenze bloccate nel repository. Le fix di settembre richiedono una nuova Build prima della prova live.
- M-03D ha ristretto il candidato al bit 25 di `PLAYER+0x120`; M-03E lo traccia su A300/A301/A302 con sole righe `START/BIT25/EXIT` e nessuna write.

### Attività: Portare il drop item base al 200%

Status: ongoing

Completamento:
Dopo OpenKH Build e F1, l'Ability Probe mostra Lucky Lucky `x2`, entrambe ON, e il runtime non altera le ability degli altri personaggi; senza ulteriori Lucky Lucky in battaglia il moltiplicatore item è `2,0×`.

Note:
- `KH2JokCombat_Forms.lua` possiede già Lucky Lucky nella tabella standard e ora ne garantisce due copie equipaggiate.
- La formula nativa Final Mix è `1 + (0,5 × copie equipaggiate dai personaggi in battaglia)`; bonus aggiuntivi possono superare il 200% e vengono preservati.
- Probe e smoke test sono allineati sul target `x2`; la validazione gameplay resta separata.

### Attività: Portare il Cost Limit Gummi al massimo sicuro

Status: ongoing

Completamento:
Dopo OpenKH Build e F1, il Gummi Garage mostra Cost Limit 1200, permette di salvare un progetto con costo oltre 600 e la missione parte senza invalidare il progetto; inventario blocchi, missioni e Teeny Ship restano invariati.

Note:
- `KH2JokCombat_GummiCost.lua` possiede soltanto `Save+0x10F0A` e porta i livelli noti `0..5` al target `6`.
- Il modulo verifica identità Sora e stato caricato senza dipendere da `Slot1`, rilegge prima/dopo la write e preserva fail-closed valori `>6`.
- Un controllo read-only della save Steam corrente ha trovato `Save+0x10F0A == 0`, coerente con il limite 600 osservato.
- Smoke test Fengari passato: prima applicazione, idempotenza, riparazione di una riscrittura vanilla, nuova save, guardia Roxas, valore estraneo e write fallita/F1.

### Attività: Sbloccare le Keyblade standard di Sora

Status: ongoing

Completamento:
Dopo OpenKH Build e F1, il menu mostra tutte le 23 Keyblade standard richieste, Master usa Bond of Flame e Final usa Oblivion quando i rispettivi slot erano vuoti; aprire/cambiare entrambi non causa crash, Ultima non viene aggiunta e nessuna arma viene duplicata o sostituita.

Note:
- `KH2JokCombat_Keyblades.lua` pianifica insieme inventario e due default: scrive Master/Final solo da zero e preserva ogni slot non vuoto.
- Bond of Flame/Oblivion vengono trasferite dallo stock allo slot quando la copia esiste; un conflitto senza copia disponibile fallisce prima della prima write.
- Il pool esclude esplicitamente Ultima Weapon, armi Struggle, Alpha/Omega Weapon, Pureblood e Kingdom Key D.
- Smoke test Fengari: 23 target, default Master/Final, consumo stock, scelta manuale preservata, conflitto senza duplicazione, idempotenza, riparazione dopo load, guardia Roxas e verifica fallita.

### Attività: Sbloccare tutte le Action Ability Sora

Status: ongoing

Completamento:
Dopo F1, il menu mostra tutte le 25 Action Ability; A usa A300 sia a vuoto sia su bersaglio, mentre i sei carrier Quadrato e Trinity restano operativi. Le dodici speciali A e le sei Auto risultano presenti ma OFF senza T-pose o attivazioni involontarie.

Note:
- Il file storico `KH2JokCombat_ComboMaster.lua` ora possiede Action e support combo nella tabella standard da 69 slot.
- Combo Master x1, Combo Plus x2 e Air Combo Plus x2 restano equipaggiati.
- I log live precedenti hanno separato `A300` a vuoto `0/4` da hit accettati partiti su A318/A319; il profilo A-base elimina la selezione contestuale che impediva un confronto omogeneo.
- Il piano è transazionale: capacità e valori vengono letti prima della prima write; ability estranee restano intatte.
- Smoke test Lupa: profilo A-base con 31 write verificate, riparazione dopo load, idempotenza e capacità insufficiente fail-closed senza write parziali.

### Attività: Sbloccare e massimizzare tutte le Drive Form

Status: ongoing

Completamento:
Dopo OpenKH Build e F1, il menu mostra Valor, Wisdom, Limit, Master, Final e Anti; le cinque Form normali sono Level 7 con innate complete, Drive è 9/9, le ricompense standard sono equipaggiate e ogni trasformazione/rientro funziona nel costume KH1.

Note:
- `ItemSet1` riceve soltanto la mask `0x76`; `ItemSet11` riceve soltanto `0x08`.
- I record Level/AbilityLevel/EXP e gli array da 24 slot seguono il layout OpenKH Final Mix; gli array target derivano da `00battle.bin/plrp` 129–133.
- Anti viene soltanto sbloccata: il record `DriveForms[5]`/`0x340C` appartiene a Summon ed è protetto da una regressione smoke dedicata.
- Le ricompense standard derivano da `00battle.bin/fmlv`; le copie Combo Plus/Air Combo Plus coincidono con il Combo Core.
- Barra persistente e live vengono portate a `9/9`, con percentuale live `100`; gli AP live vengono portati al massimo byte 255 senza toccare `Save+0x24F8`.
- Smoke test Fengari: inizializzazione da record vuoti, extra e Summon preservati, AP idempotenti/ripristinati dopo rebuild di `Slot1` e caso fail-closed senza write parziali.

### Attività: Ripristinare tutte le growth MAX equipaggiate

Status: ongoing

Completamento:
Dopo OpenKH Build e F1, High Jump, Quick Run, Dodge Roll, Aerial Dodge e Glide risultano MAX e ON; un secondo F1 non ne disabilita nessuna e il movement funziona nel costume KH2 senza T-pose.

Note:
- Il test dell'MSET ricostruito è fallito in gameplay nonostante il delta BAR staticamente corretto; l'override KH1 è stato rimosso.
- La causa della disattivazione era una write esplicita del vecchio fallback: non esisteva alcun ramo che passasse dal profilo KH1 al profilo KH2.
- Il runtime non usa Valor come proxy del costume perché le Form sono sbloccate subito e non usa offset storia non verificati.
- Scrive sempre `0x8061`, `0x8065`, `0x8237`, `0x8069`, `0x806D` e verifica ogni valore.
- Smoke test: cinque write da valori OFF/low level, seconda frame idempotente e regressione F1 che riattiva Quick Run invece di lasciarla disabilitata.
- Per rimuovere un vecchio override MSET dalla build live serve Build più riavvio completo; per i soli script aggiornati basta Build e F1.

## TODO

- Il combat system Sora è gestito dal track attivo `tracks/sora-combat-system/`; milestone, attività e criteri di completamento non vengono duplicati qui.

## Bloccato

- Nessun blocco tecnico; il checkpoint corrente richiede una prova manuale nel gioco.

## Fatto

- Corrette invalidazione della cache PTYA e transazioni Keyblade con rollback verificato; regressioni dedicate a relocation/unload, errori dopo write e valori estranei. Runner e lockfile rendono riproducibili i controlli senza dipendere da `%TEMP%`.
- Repository aggiornata a `222bbf1` prima del nuovo lavoro.
- MSET Roxas confrontato con il vanilla: cinque sole entry modificate.
- Modulo Sora Movement dotato di guardia identità, validazione preventiva e verifica post-write; il target corrente è all-growth MAX/ON.
- Modulo Combo Master convertito in Sora Combo Core con target `1 + 2 + 2`, deduplica e verifica post-write.
- Ability Probe limitato a Sora e predisposto a registrare tutte le copie del nucleo combo.
- Identificato il rebuild OpenKH come causa del disallineamento tra repository ChatGPT, clone installata e script live.
- La clone OpenKH è la sorgente effettiva; la copia ChatGPT può contenere staging e non rappresenta lo stato Git da pubblicare.
- Creato e testato `P_EX100_KH1F_JokCombat.mset`: sette import ANB vanilla e nessun altro delta logico, ma T-pose invariata; esperimento poi rimosso.
- Hub Kiroku inizializzato con contesto verificato.
- Verificato il merge della PR precedente e aggiornato `main` alla merge commit `cca034c`.
- Aggiunto `KH2JokCombat_Forms.lua` con unlock nativi, Level 7, innate PLRP, ricompense FMLV, Drive 9/9, guardie fail-closed e verifica post-write.
- Esteso l'Ability Probe con bit Form, progressione, weapon slot, 24 ability slot e stato Drive.
- Portati gli AP live di Sora a 255 nel modulo Forms, preservando il contatore AP Boost persistente.
- Esteso inizialmente il Combat Core alle 25 Action Ability con 19 azioni operative ON; il profilo è stato poi sostituito da A-base con carrier Quadrato/Trinity ON e speciali A/Auto OFF.

## Annullato

- Il lavoro attivo sul post-landing Roxas è chiuso per scope; la ricerca resta in `docs/KH2-JokCombat_TODO.md`.
