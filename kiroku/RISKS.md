# Rischi

## Rischi aperti

### Rischio: Attacchi Roxas o Anti forzati sullo stato tecnico Base

Condizione:
La stance Dual o Feral richiama direttamente action o motion Roxas/Anti mentre il player resta `P_EX100` base con MSET, skeleton e weapon state originali.

Impatto:
Possibili T-pose, secondo Keyblade assente o agganciato male, weapon hide errato, VFX/hitbox/danno mancanti, transizioni invalide o crash.

Mitigazione:
Separare aspetto visivo e carrier tecnico: provare un profilo dual-wield e uno Anti realmente compatibili, costruendo se necessario varianti base-looking per i loro skeleton. Mappare PTYA, MSET/ANB, ATKP, weapon bone e ritorno a Base prima di abilitare la stance; fallire chiuso se una dipendenza non è verificata.

### Rischio: Drop oltre il 200% con Lucky Lucky aggiuntive

Condizione:
Sora, Donald, Goofy o un altro personaggio attivo possiede ulteriori Lucky Lucky tramite ability o accessori oltre alle due garantite dal modulo.

Impatto:
La formula nativa somma tutte le copie equipaggiate in battaglia e il moltiplicatore item supera `2,0×`.

Mitigazione:
Trattare il 200% come baseline garantita da Sora e non come cap distruttivo; per una prova esatta, disabilitare temporaneamente gli altri bonus Lucky Lucky senza farli rimuovere dal runtime.

### Rischio: Valori Gummi oltre il massimo sicuro

Condizione:
Il limite costo viene forzato oltre il livello documentato `6`/1200 oppure un altro mod lascia un valore superiore in `Save+0x10F0A`.

Impatto:
Il Gummi editor può accettare un progetto che il motore non riesce a validare correttamente, con fallimento o distruzione immediata della nave all'avvio missione.

Mitigazione:
Non implementare 9999 né patch live non verificate: convergere soltanto su `6`, preservare ogni valore estraneo `>6` e testare un blueprint tra 601 e 1200 prima di salvare definitivamente.

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

### Rischio: motion speciali OFF non accettate dal carrier Quadrato

Condizione:
Il motore richiede anche il bit equipaggiato della speciale corrispondente alla motion, oppure il costume KH1 non contiene una motion avanzata richiamata dal carrier Type 0.

Impatto:
Il ramo Quadrato può essere rifiutato, produrre T-pose, bloccarsi o usare una transizione errata, anche se A resta correttamente su A300.

Mitigazione:
Mantenere ON i sei carrier Type 0 e cambiare soltanto MotionId whitelisted. Dopo F1 provare prima A300 su hit/miss, poi ogni ramo Quadrato uno alla volta senza salvare; non importare motion in massa e non dichiarare valida una tecnica dalla sola animazione.

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

### Rischio: PTYA live o profondita virtuale divergono dal motore

Condizione:
Un altro mod altera i record Base 31/32/34, il selector Guard conserva semantica difensiva con A319 oppure un edge A campionato non viene realmente accettato nella cancel window.

Impatto:
Il router potrebbe scegliere la famiglia Quadrato sbagliata o sovrascrivere dati non propri.

Mitigazione:
Verificare struttura e campi immutabili prima della prima write, accettare record 31 soltanto in A322/A319 e mantenere record 32 su `12/0x12`; `11/0x01` è soltanto una firma legacy da recuperare a F1. Validare motion, hitbox/danno e recovery separatamente; A2+ avanza solo dopo una diversa motion Base entro 30 frame. Un valore estraneo disabilita il modulo senza write.

### Rischio: Candidate dispatcher correlate ma non causali

Condizione:
Gli snapshot M-03B hanno evidenziato 57 byte stabili fra Quadrato neutrale e `A□`, ma erano acquisiti dopo la dispatch e rappresentavano motion, transform, timer o altri effetti della decisione. Campioni con motion diverse e edge mentre A310 era già attiva hanno inoltre prodotto falsi confronti.

Impatto:
Una patch prematura può corrompere lo stato action, rubare input nativi o produrre crash pur passando un test mock.

Mitigazione:
M-03C resta read-only, conserva il frame precedente con `ReadArray`, esclude risoluzioni duplicate/motion già attive e ha chiuso `2/2` nello stesso bucket. M-03D ha ristretto il candidato al bit 25 di `PLAYER+0x120`; M-03E ne osserva soltanto le transizioni su A300/A301/A302. Nessuna candidata diventa scrivibile senza identità version-safe, semantica verificata, timing, rollback e test gameplay dedicato.

### Rischio: Mancanza di test Lua automatico

Condizione:
Non è disponibile localmente un interprete equivalente a LuaBackend.

Impatto:
Errori sintattici o differenze runtime emergono solo al caricamento F1.

Mitigazione:
Eseguire gli smoke Fengari per sintassi, state machine e fail-closed; verificare comunque la console LuaBackend e il gameplay reale perché il mock non prova dispatch, hitbox o recovery.

## Rischi accettati

- Le cinque growth ability a livello MAX e ON alterano intenzionalmente la progressione Sora; sulle vecchie save con costume KH1 le quattro growth avanzate possono produrre T-pose.
- Il nucleo combo `1 + 2 + 2` altera intenzionalmente la progressione delle support ability Sora.
- Tutte le 25 Action Ability vengono anticipate; le sei Auto restano intenzionalmente disabilitate.
- Tutte le Form, le innate e le ricompense di livello alterano intenzionalmente la progressione; Drive viene portato e riempito a 9/9.
- Le 23 Keyblade standard diverse da Ultima Weapon e i default Bond of Flame/Oblivion per Master/Final vengono anticipati e persistono nella save; eventuali ricompense vanilla successive possono aggiungere copie.
- Il Cost Limit Gummi viene anticipato al massimo sicuro 1200 e persiste salvando; il limite nativo di progressione viene intenzionalmente superato, ma non il range supportato.
- L'MSET Roxas resta nel pacchetto come baseline chiusa anche durante il lavoro Sora.

## Rischi chiusi

- Il budget AP insufficiente alle ricompense Form è coperto dal target live 255; `Save+0x24F8` resta intatto.
- La possibile copia Combo Master già inserita dal vecchio runtime viene rilevata, riusata ed equipaggiata senza duplicarla.
- L'ipotesi che l'import delle motion standard rendesse sicure le growth nel costume KH1 è stata falsificata dal gameplay; asset e manifest entry sono stati rimossi.
- Lo sblocco delle Drive Form non è una correzione della T-pose: resta una funzione di progressione separata, mentre il problema segue le growth base equipaggiate.
- L'uso di Valor anticipato come proxy del costume è chiuso: Movement non legge quel bit e non applica un profilo outfit condizionale non verificato.
- V5 Guard32 è respinta: il motore ha letto selector/ability e A310 corretti nel record 32 ma ha restituito `RESET_IDLE` senza avviare la motion; F1 conserva soltanto il recupero della firma legacy.
