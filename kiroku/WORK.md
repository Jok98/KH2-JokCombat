# Lavoro

## In corso

### Attività: Diagnosticare la T-pose Growth e riallineare il deployment

Status: ongoing

Completamento:
OpenKH Build distribuisce il MSET KH1-costume con le sette motion importate e, dopo riavvio, le cinque growth funzionano senza T-pose o errore LuaBackend sia nel costume KH1 sia nel costume KH2.

Note:
- Il log conferma Movement/Combo Core correnti, cambio stanza e nucleo combo applicato; la cache e il deployment Lua non sono la causa.
- Drive `3/3`, Gauge `100` e le action vanilla presenti escludono lo sblocco di tutte le fusioni come prima correzione ragionevole.
- Il costume KH1 aveva sette slot Growth `DUMM`; l'asset corretto è nel manifest ma richiede Build e riavvio completo perché F1 non ricarica MSET.
- Salvare solo dopo aver accettato la persistenza di growth e support ability.

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
- Modulo Sora Movement esteso a tutte le cinque growth ability MAX con guardia identità e validazione preventiva.
- Modulo Combo Master convertito in Sora Combo Core con target `1 + 2 + 2`, deduplica e verifica post-write.
- Ability Probe limitato a Sora e predisposto a registrare tutte le copie del nucleo combo.
- Identificato il rebuild OpenKH come causa del disallineamento tra repository ChatGPT, clone installata e script live.
- Trasferiti e verificati con SHA-256 tutti i file modificati e Kiroku nella clone OpenKH canonica; la vecchia repository ChatGPT è pulita.
- Creato `P_EX100_KH1F_JokCombat.mset`: sette import ANB vanilla, 993 entry preservate e nessun altro delta logico.
- Hub Kiroku inizializzato con contesto verificato.

## Annullato

- Il lavoro attivo sul post-landing Roxas è chiuso per scope; la ricerca resta in `docs/KH2-JokCombat_TODO.md`.
