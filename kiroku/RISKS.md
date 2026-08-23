# Rischi

## Rischi aperti

### Rischio: Persistenza delle ability Sora

Condizione:
La partita viene salvata dopo l'applicazione del profilo growth o del nucleo combo.

Impatto:
Livelli MAX e stato equipaggiato diventano permanenti in quella save.

Mitigazione:
Usare una save di prova o backup e salvare solo se il risultato è desiderato.

### Rischio: Growth attive nel costume KH1

Condizione:
Il modulo viene applicato su una save in cui Sora indossa ancora il costume KH1.

Impatto:
Square o il secondo salto possono tornare a produrre T-pose.

Mitigazione:
Non usare né salvare il profilo all-growth su una vecchia save KH1. Se quel tratto dovrà essere supportato di nuovo, introdurre prima un segnale diretto del modello attivo e testare entrambi i rami; non usare Valor o un flag storia ipotetico.

### Rischio: Action avanzate nel MSET del costume KH1

Condizione:
Una delle Action Ability sbloccate richiama una motion non disponibile o incompatibile in `P_EX100_KH1F.mset`.

Impatto:
L'attacco può produrre T-pose, blocco temporaneo o una transizione errata, come già osservato con alcune growth.

Mitigazione:
Provare le 19 Action operative una per volta dopo Build/F1, senza salvare finché il set non è validato. Non importare motion in massa: isolare prima l'Action e lo slot nativo responsabile.

### Rischio: Persistenza e ricompense Keyblade successive

Condizione:
La partita viene salvata dopo lo sblocco oppure una ricompensa vanilla concede più tardi una Keyblade già anticipata.

Impatto:
Le 23 armi e i default Master/Final restano nella save; una ricompensa successiva può aumentare il relativo stock oltre una copia.

Mitigazione:
Usare una save di prova o backup. Il runtime non aumenta conteggi già positivi e considera possedute le armi equipaggiate, quindi non crea duplicati autonomamente dopo F1 o reload.

### Rischio: Form anticipate durante il costume KH1

Condizione:
Il giocatore usa Valor, Wisdom, Limit, Master, Final o Anti prima dell'evento dei vestiti KH2.

Impatto:
Modello, motion, weapon slot o transizioni potrebbero dipendere da stato di progressione non ancora validato in gameplay.

Mitigazione:
Forms usa bit e record nativi, preserva i weapon slot e garantisce gli array innate vanilla; Keyblades inizializza soltanto Master/Final a zero. Verificare ogni trasformazione e ritorno con una save di prova prima di salvare.

### Rischio: Default weapon Form anticipati non ancora validati in gioco

Condizione:
Dopo l'unlock anticipato, il modulo inizializza Master con Bond of Flame e Final con Oblivion prima dell'evento vanilla.

Impatto:
Il menu dovrebbe evitare lo stato nullo che causava crash, ma trasformazione, cambio manuale e persistenza dei due loadout richiedono ancora conferma gameplay.

Mitigazione:
Scrivere soltanto slot zero, consumare la copia in stock quando presente, preservare qualunque scelta nonzero e fallire prima delle write se il default è già equipaggiato altrove senza stock. Il probe riporta `READY`, `EMPTY` o `CUSTOM`; testare menu e trasformazioni prima di salvare.

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

- Le cinque growth ability a livello MAX e ON alterano intenzionalmente la progressione Sora; sulle vecchie save con costume KH1 le quattro growth avanzate possono produrre T-pose.
- Il nucleo combo `1 + 2 + 2` altera intenzionalmente la progressione delle support ability Sora.
- Tutte le 25 Action Ability vengono anticipate; le sei Auto restano intenzionalmente disabilitate.
- Tutte le Form, le innate e le ricompense di livello alterano intenzionalmente la progressione; Drive viene portato e riempito a 9/9.
- Le 23 Keyblade standard diverse da Ultima Weapon e i default Bond of Flame/Oblivion per Master/Final vengono anticipati e persistono nella save; eventuali ricompense vanilla successive possono aggiungere copie.
- L'MSET Roxas resta nel pacchetto come baseline chiusa anche durante il lavoro Sora.

## Rischi chiusi

- Il budget AP insufficiente alle ricompense Form è coperto dal target live 255; `Save+0x24F8` resta intatto.
- La possibile copia Combo Master già inserita dal vecchio runtime viene rilevata, riusata ed equipaggiata senza duplicarla.
- L'ipotesi che l'import delle motion standard rendesse sicure le growth nel costume KH1 è stata falsificata dal gameplay; asset e manifest entry sono stati rimossi.
- Lo sblocco delle Drive Form non è una correzione della T-pose: resta una funzione di progressione separata, mentre il problema segue le growth base equipaggiate.
- L'uso di Valor anticipato come proxy del costume è chiuso: Movement non legge quel bit e non applica un profilo outfit condizionale non verificato.
