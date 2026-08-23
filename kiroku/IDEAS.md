# Idee

## Idee aperte

- Separare i probe diagnostici dal profilo runtime normale per ridurre log e responsabilità della build.
- Aggiungere un controllo automatico di manifest, sorgenti, hash live e delta BAR/MSET.
- Aggiungere un probe read-only di action, motion e moveset attivo al trigger di Quick Run/Aerial Dodge.
- Verificare le Growth dopo un cambio stanza: la write post-spawn potrebbe aggiornare la save/menu senza ricostruire la cache action/motion del player già caricato.
- Confrontare livello 1 e MAX delle Growth problematiche prima di cambiare progress flags.
- Osservare motion ID, weapon state e cancel window di Sora prima di progettare i branch A/Y.

## Idee differite

- Routing combo A/Y con launcher, gap closer e finisher: riprendere dopo la mappatura completa del moveset Sora.
- Tuning ATKP Musou: riprendere quando i rami combo e le reaction native sono noti.
- Growth ability runtime-only: valutare solo se la persistenza nella save diventa indesiderata; il sistema corrente usa gli slot nativi.
- Transizione inversa `S010` e weapon hide Roxas: archiviata finché Roxas resta chiuso per scope.

## Idee rifiutate

### Rifiutata: Movimento personalizzato Lua al posto delle growth ability

Motivo:
High Jump, Quick Run, Dodge Roll, Aerial Dodge e Glide sono già comportamenti nativi con slot e livelli verificati.

Da ricordare:
Riconsiderare solo per un comportamento che le growth vanilla non possono esprimere.

### Rifiutata: Usare soltanto world `0x02` per identificare Roxas

Motivo:
Lo stesso world ID comprende Twilight Town e Simulated Twilight Town e può quindi includere Sora.

Da ricordare:
Usare il flag storia e guardie aggiuntive specifiche del modulo.

### Rifiutata: Sbloccare tutte le fusioni per correggere la T-pose Growth

Motivo:
Il test mostra già Drive `3/3` e Gauge `100`; Sora base possiede le action Growth nel proprio MSET vanilla e toolchain consolidate consentono growth iniziali senza richiedere le Drive Form.

Da ricordare:
Le fusioni possono essere abilitate in futuro come scelta di progressione, ma non vanno usate come workaround diagnostico senza evidenza di una dipendenza.

## Idee vietate

- Sovrascrivere valori di save inattesi per forzare la compatibilità.
- Espandere il runtime Roxas mentre il focus Sora è attivo senza una regressione esplicita.
