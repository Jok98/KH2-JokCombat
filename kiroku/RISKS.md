# Rischi

## Rischi aperti

### Rischio: Persistenza delle ability Sora

Condizione:
La partita viene salvata dopo l'applicazione del profilo growth o del nucleo combo.

Impatto:
Livelli MAX e stato equipaggiato/disabilitato diventano permanenti in quella save.

Mitigazione:
Usare una save di prova o backup e salvare solo se il risultato è desiderato.

### Rischio: Riattivazione manuale nel costume KH1

Condizione:
Il giocatore equipaggia dal menu Quick Run, Dodge Roll, Aerial Dodge o Glide prima dei vestiti KH2.

Impatto:
Square o il secondo salto possono tornare a produrre T-pose.

Mitigazione:
Il runtime le lascia visibili a MAX ma disabilitate; non equipaggiarle manualmente finché Sora usa il costume KH1.

### Rischio: Form anticipate durante il costume KH1

Condizione:
Il giocatore usa Valor, Wisdom, Limit, Master, Final o Anti prima dell'evento dei vestiti KH2.

Impatto:
Modello, motion, weapon slot o transizioni potrebbero dipendere da stato di progressione non ancora validato in gameplay.

Mitigazione:
Il modulo usa bit e record nativi, preserva i weapon slot e garantisce gli array innate vanilla. Verificare ogni trasformazione e ritorno con una save di prova prima di salvare.

### Rischio: AP inferiore alle ricompense Form equipaggiate

Condizione:
Le ricompense Auto Form/support dei livelli massimi vengono equipaggiate su un Sora iniziale con pochi AP.

Impatto:
Il menu può mostrare AP usati oltre il budget vanilla, anche se i flag ability sono presenti.

Mitigazione:
Non modificare statistiche AP fuori scope. Il probe elenca tutte le copie equipaggiate; rivalutare solo se il gioco le disattiva o mostra un comportamento incoerente.

### Rischio: Weapon slot Form non inizializzati

Condizione:
Una Form appena sbloccata possiede `Weapon=0` perché l'evento vanilla non è ancora avvenuto.

Impatto:
Le Form dual-wield potrebbero presentarsi senza un secondo Keyblade o richiedere equipaggiamento manuale.

Mitigazione:
Non assegnare armi non possedute. L'Ability Probe registra il weapon slot di ogni Form per decidere su dati reali dopo il primo test.

### Rischio: Conflitto con altri mod della tabella ability

Condizione:
Un'altra mod riempie o modifica i 69 slot standard da `Save+0x2544` durante la preparazione del Sora Combo Core.

Impatto:
Le copie combo potrebbero non essere inseribili o la tabella potrebbe cambiare tra lettura e write.

Mitigazione:
Il modulo conta prima gli slot liberi, riusa le copie esistenti, ricontrolla ogni valore prima della write e si disabilita fino a F1 su incoerenze.

### Rischio: Conflitto con altri mod growth

Condizione:
Un'altra mod usa gli slot `Save+0x25CE`–`Save+0x25D6` con valori non vanilla.

Impatto:
Applicare la patch potrebbe distruggere stato esterno o produrre comportamento incoerente.

Mitigazione:
Il modulo valida tutti gli slot prima di scrivere e si disabilita fino a F1 su valori estranei.

### Rischio: Build live diversa dal sorgente

Condizione:
La repository ChatGPT o la cartella live viene modificata senza aggiornare la clone Git installata da cui OpenKH esegue Build.

Impatto:
Il test in gioco usa una versione diversa da quella analizzata.

Mitigazione:
Lavorare nella clone OpenKH canonica, lasciare che Mods Manager componga la cartella live e confrontare SHA-256 prima della prova gameplay.

Stato corrente:
I sorgenti sono nella clone OpenKH canonica. La cartella live deve essere rigenerata per eliminare il vecchio override KH1 prima del prossimo test.

### Rischio: Mancanza di test Lua automatico

Condizione:
Non è disponibile localmente un interprete equivalente a LuaBackend.

Impatto:
Errori sintattici o differenze runtime emergono solo al caricamento F1.

Mitigazione:
Eseguire controlli statici, mantenere codice semplice e verificare la console LuaBackend prima di salvare.

## Rischi accettati

- Le cinque growth ability a livello MAX alterano intenzionalmente la progressione Sora; nel costume KH1 solo High Jump è equipaggiato.
- Il nucleo combo `1 + 2 + 2` altera intenzionalmente la progressione delle support ability Sora.
- Tutte le Form, le innate e le ricompense di livello alterano intenzionalmente la progressione; Drive viene portato e riempito a 9/9.
- L'MSET Roxas resta nel pacchetto come baseline chiusa anche durante il lavoro Sora.

## Rischi chiusi

- La possibile copia Combo Master già inserita dal vecchio runtime viene rilevata, riusata ed equipaggiata senza duplicarla.
- L'ipotesi che l'import delle motion standard rendesse sicure le growth nel costume KH1 è stata falsificata dal gameplay; asset e manifest entry sono stati rimossi.
- Lo sblocco delle Drive Form non è una correzione della T-pose: resta una funzione di progressione separata, mentre il problema segue le growth base equipaggiate.
- Il rischio che Valor anticipato riattivi le growth base incompatibili è chiuso: Movement non legge più il bit Valor.
