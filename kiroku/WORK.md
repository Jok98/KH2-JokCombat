# Lavoro

## In corso

### Attività: Rendere sicuro il movement nel costume KH1

Status: ongoing

Completamento:
Dopo OpenKH Build e riavvio, il costume KH1 usa il MSET vanilla, High Jump MAX è equipaggiato, le altre quattro growth MAX sono visibili ma disabilitate e Square/salto non producono T-pose; il nucleo combo resta attivo.

Note:
- Il test dell'MSET ricostruito è fallito in gameplay nonostante il delta BAR staticamente corretto; l'override KH1 è stato rimosso.
- Il runtime usa il possesso di Valor (`Save+0x36C0 & 0x02`) come proxy dell'evento vanilla dei vestiti KH2.
- Prima di Valor scrive `0x8061`, `0x0065`, `0x0237`, `0x0069`, `0x006D`; dopo Valor aggiunge il bit equipaggiato alle altre quattro.
- Combo Master e i Combo Plus ground/air non dipendono dal profilo movement e restano attivi.
- Serve Build più riavvio completo; F1 da solo non scarica il vecchio MSET.

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

## Annullato

- Il lavoro attivo sul post-landing Roxas è chiuso per scope; la ricerca resta in `docs/KH2-JokCombat_TODO.md`.
