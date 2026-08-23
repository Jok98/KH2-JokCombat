# Lavoro

## In corso

### Attività: Sbloccare tutte le Action Ability Sora

Status: ongoing

Completamento:
Dopo OpenKH Build e F1, il menu mostra tutte le 25 Action Ability; le 19 azioni operative, inclusa Trinity Limit, funzionano nel costume KH1, mentre Auto Valor/Wisdom/Limit/Master/Final/Summon restano presenti ma disabilitate senza T-pose o attivazioni involontarie.

Note:
- Il file storico `KH2JokCombat_ComboMaster.lua` ora possiede Action e support combo nella tabella standard da 69 slot.
- Combo Master x1, Combo Plus x2 e Air Combo Plus x2 restano equipaggiati.
- Il piano è transazionale: capacità e valori vengono letti prima della prima write; ability estranee restano intatte.
- Smoke test Lupa: 30 write verificate, riparazione dopo load, idempotenza e capacità insufficiente fail-closed senza write parziali.

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

### Attività: Rendere sicuro il movement nel costume KH1

Status: ongoing

Completamento:
Dopo OpenKH Build e riavvio, il costume KH1 usa il MSET vanilla, High Jump MAX è equipaggiato, le altre quattro growth MAX sono visibili ma disabilitate e Square/salto non producono T-pose; il nucleo combo resta attivo.

Note:
- Il test dell'MSET ricostruito è fallito in gameplay nonostante il delta BAR staticamente corretto; l'override KH1 è stato rimosso.
- Il runtime non usa più Valor come proxy del costume perché le Form sono sbloccate subito.
- Scrive sempre `0x8061`, `0x0065`, `0x0237`, `0x0069`, `0x006D` finché non esiste un segnale diretto e verificato del costume KH2.
- Action Ability e support combo non dipendono dal profilo movement; le growth base problematiche restano comunque OFF.
- Smoke test Fengari: cinque write attese anche con tutti i bit Form presenti, poi seconda frame idempotente.
- Per rimuovere un vecchio override MSET dalla build live serve Build più riavvio completo; per i soli script aggiornati basta Build e F1.

## TODO

### Attività: Mappare il moveset nativo Sora

Status: todo
Completion:
Esiste una tabella verificata di attacchi ground/air, finisher, cancel e relative catene PTYA → motion → MSET/ANB → ATKP.

### Attività: Definire la grammatica combo A/Y

Status: todo
Completion:
I rami A/Y hanno input, transizioni, comportamento ground/air e condizioni di finisher documentati e verificabili.

## Bloccato

- Nessun blocco tecnico; il checkpoint corrente richiede una prova manuale nel gioco.

## Fatto

- Repository aggiornata a `222bbf1` prima del nuovo lavoro.
- MSET Roxas confrontato con il vanilla: cinque sole entry modificate.
- Modulo Sora Movement esteso a profili KH1/KH2 con guardia identità, validazione preventiva e verifica post-write.
- Modulo Combo Master convertito in Sora Combo Core con target `1 + 2 + 2`, deduplica e verifica post-write.
- Ability Probe limitato a Sora e predisposto a registrare tutte le copie del nucleo combo.
- Identificato il rebuild OpenKH come causa del disallineamento tra repository ChatGPT, clone installata e script live.
- Trasferiti e verificati con SHA-256 tutti i file modificati e Kiroku nella clone OpenKH canonica; la vecchia repository ChatGPT è pulita.
- Creato e testato `P_EX100_KH1F_JokCombat.mset`: sette import ANB vanilla e nessun altro delta logico, ma T-pose invariata; esperimento poi rimosso.
- Hub Kiroku inizializzato con contesto verificato.
- Verificato il merge della PR precedente e aggiornato `main` alla merge commit `cca034c`.
- Aggiunto `KH2JokCombat_Forms.lua` con unlock nativi, Level 7, innate PLRP, ricompense FMLV, Drive 9/9, guardie fail-closed e verifica post-write.
- Esteso l'Ability Probe con bit Form, progressione, weapon slot, 24 ability slot e stato Drive.
- Portati gli AP live di Sora a 255 nel modulo Forms, preservando il contatore AP Boost persistente.
- Esteso il Combat Core alle 25 Action Ability con 19 azioni operative ON, sei Auto OFF e probe/test dedicati.

## Annullato

- Il lavoro attivo sul post-landing Roxas è chiuso per scope; la ricerca resta in `docs/KH2-JokCombat_TODO.md`.
