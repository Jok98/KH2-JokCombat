# Vincoli

## Vincoli attivi

### Vincolo: Ownership native-first

Status: active

Regola:
Non ricostruire in Lua un comportamento già gestibile tramite dati o meccanismi nativi KH2.

Perché:
Duplicare il motore crea conflitti con targeting, animazioni, hitbox, danno, finisher e altre mod.

### Vincolo: Scritture specifiche per personaggio

Status: active

Regola:
Ogni write Sora deve verificare il flag storia; ogni write Roxas deve escludere Sora e avere ulteriori guardie di contesto quando disponibili.

Perché:
Twilight Town e Simulated Twilight Town condividono il world ID `0x02`, quindi il solo mondo non identifica il personaggio.

### Vincolo: Valore precedente riconosciuto

Status: active

Regola:
Scrivere solo su valori vuoti, attesi o già posseduti dal modulo e verificare il valore dopo la write.

Perché:
Sovrascrivere dati sconosciuti può corrompere save o confliggere silenziosamente con altre mod.

### Vincolo: Ownership stretta dei record Drive Form

Status: active

Regola:
Nel modulo Forms modificare soltanto bit unlock, Level/AbilityLevel/EXP delle cinque Form livellabili, target innate verificati, ricompense FMLV e barra Drive. Preservare weapon slot, ability extra e campi non documentati; l'unica inizializzazione weapon autorizzata appartiene al modulo Keyblade e riguarda Master/Final esattamente a zero. Anti non riceve una progressione inventata e `DriveForms[5]`/Summon resta intatto.

Perché:
I record da `0x38` byte contengono stato persistente condiviso con equipaggiamento e altre mod. I dati vanilla PLRP/FMLV forniscono target verificabili senza sovrascrivere il resto.

### Vincolo: MSET tracciabile

Status: active

Regola:
Ogni import motion deve registrare sorgente, slot sorgente, slot destinazione, nome e motivazione; confrontare il BAR per entry e contenuto.

Perché:
Un MSET è un asset binario completo e una sostituzione involontaria è difficile da diagnosticare nel gameplay.

### Vincolo: AP senza alterare gli AP Boost persistenti

Status: active

Regola:
Per massimizzare gli AP di Sora usare soltanto il campo live `Slot1+0x18E`, con target `0xFF`; non scrivere `Save+0x24F8`.

Perché:
`Save+0x24F8` conta gli AP Boost applicati e non rappresenta gli AP totali. Portarlo arbitrariamente al limite del byte falsificherebbe la progressione e potrebbe sommarsi ai parametri base.

### Vincolo: Keyblade e default Form senza duplicazioni

Status: active

Regola:
Concedere solo le 23 Keyblade standard richieste che hanno stock zero e non risultano già equipaggiate. Inizializzare Master con Bond of Flame e Final con Oblivion soltanto se il rispettivo slot è zero, consumando una copia dallo stock quando presente. Non scrivere Ultima Weapon, armi debug/dummy, slot non vuoti o gli slot Sora/Valor/Wisdom/Limit.

Perché:
In KH2 un'arma equipaggiata può avere conteggio inventario zero; impostarlo comunque a uno creerebbe una copia aggiuntiva a ogni F1 o reload. Sovrascrivere uno slot non vuoto annullerebbe invece una scelta del giocatore, mentre lasciare Master/Final a zero dopo l'unlock anticipato mantiene lo stato che causa il crash del menu.

### Vincolo: Movement non disabilita le growth

Status: active

Regola:
Movement deve convergere sui cinque valori MAX equipaggiati e non deve rimuovere il bit `0x8000` da High Jump, Quick Run, Dodge Roll, Aerial Dodge o Glide. Un profilo KH1 automatico può essere reintrodotto soltanto con un segnale diretto e verificato del modello attivo.

Perché:
Il precedente fallback “finché non troviamo il costume” era in realtà permanente e disabilitava quattro ability a ogni applicazione dello script. Il rischio T-pose del modello KH1 resta reale ma deve essere gestito esplicitamente, non imponendo OFF anche al costume KH2.

### Vincolo: Auto Action presenti ma disabilitate

Status: active

Regola:
Auto Valor, Auto Wisdom, Auto Limit, Auto Master, Auto Final e Auto Summon devono esistere nella tabella standard ma avere il bit equipaggiato rimosso.

Perché:
Il pool Action deve essere completo senza attivazioni automatiche di Form, Limit o Summon; entrambi i moduli che condividono queste ability devono convergere sullo stesso stato OFF.

## Fuori scope

- Rifinitura del post-landing e delle transizioni armi Roxas.
- Combo A/Y, ATKP e cancel Sora prima della validazione movement e nucleo combo.
- Controllare direttamente il gameplay o dichiarare esiti senza prova dell'utente.

## Modifiche vietate

- Write globali non protette da identità e readiness.
- Offset per versione eseguibile quando `kh2lib` offre un indirizzo compatibile.
- Sostituzioni massicce del player object Sora come scorciatoia per importare un moveset.
