# Rischi

## Rischi aperti

### Rischio: Persistenza delle ability Sora

Condizione:
La partita viene salvata dopo l'applicazione di growth MAX e nucleo combo.

Impatto:
La progressione vanilla di movement e support ability viene modificata permanentemente in quella save.

Mitigazione:
Usare una save di prova o backup e salvare solo se il risultato è desiderato.

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
Il rischio si è materializzato nel test precedente, ma i sorgenti Sora sono ora nella clone OpenKH canonica. La cartella live resta da rigenerare con Build e verificare prima del prossimo test.

### Rischio: Diagnosticare la T-pose alterando la progressione

Condizione:
Si sbloccano tutte le Drive Form o si forza la barra Drive prima di identificare la motion fallita.

Impatto:
La save cambia in modo ampio senza risolvere necessariamente la causa e rende meno leggibile il test.

Mitigazione:
Prima usare un probe read-only su action/motion e un test controllato Growth livello 1; modificare Drive/Form solo se emerge una dipendenza concreta.

### Rischio: Mancanza di test Lua automatico

Condizione:
Non è disponibile localmente un interprete equivalente a LuaBackend.

Impatto:
Errori sintattici o differenze runtime emergono solo al caricamento F1.

Mitigazione:
Eseguire controlli statici, mantenere codice semplice e verificare la console LuaBackend prima di salvare.

### Rischio: Compatibilità motion sul costume KH1

Condizione:
Le ANB Growth di `P_EX100` vengono eseguite dal modello `P_EX100_KH1F`.

Impatto:
Una differenza di skeleton o trigger potrebbe produrre animazioni errate anche dopo aver riempito gli slot.

Mitigazione:
Gli import occupano gli stessi indici riservati e `A180` è già condiviso byte-per-byte fra i due MSET; il BAR delta è limitato a sette entry. Validare in gameplay dopo Build e riavvio prima di considerare chiuso il rischio.

## Rischi accettati

- Le cinque growth ability MAX alterano intenzionalmente la progressione Sora perché questa è la funzione richiesta.
- Il nucleo combo `1 + 2 + 2` altera intenzionalmente la progressione delle support ability Sora.
- L'MSET Roxas resta nel pacchetto come baseline chiusa anche durante il lavoro Sora.

## Rischi chiusi

- La possibile copia Combo Master già inserita dal vecchio runtime viene rilevata, riusata ed equipaggiata senza duplicarla.
