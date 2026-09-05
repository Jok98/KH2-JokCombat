# Idee

## Idee aperte

- Separare i probe diagnostici dal profilo runtime normale per ridurre log e responsabilità della build.
- Aggiungere un controllo automatico di manifest, sorgenti, hash live e delta BAR/MSET.
- Osservare motion ID, weapon state e cancel window di Sora prima di estendere i branch A/Quadrato.

## Idee differite

- Routing combo A/Quadrato con launcher, gap closer e finisher: riprendere dopo la mappatura completa del moveset Sora.
- Tuning ATKP Musou: riprendere quando i rami combo e le reaction native sono noti.
- Un gate diretto sul modello/costume attivo: valutare se il progetto dovrà tornare a supportare automaticamente le save prima dei vestiti KH2 senza disabilitare le growth nelle save successive.
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

### Rifiutata: Importare le motion standard nel MSET del costume KH1

Motivo:
L'asset sperimentale conservava 993 entry e cambiava soltanto sette slot `DUMM` con gli ANB corrispondenti di `P_EX100`, ma il test gameplay continuava a mostrare T-pose su Square e secondo salto.

Da ricordare:
La correttezza strutturale del BAR non garantisce compatibilità di motion, skeleton e action table fra `P_EX100` e `P_EX100_KH1F`. L'asset è stato rimosso; il runtime corrente privilegia tutte le growth ON e dichiara incompatibile la vecchia save KH1 finché non esiste un gate modello verificato.

## Idee vietate

- Sovrascrivere valori di save inattesi per forzare la compatibilità.
- Espandere il runtime Roxas mentre il focus Sora è attivo senza una regressione esplicita.
