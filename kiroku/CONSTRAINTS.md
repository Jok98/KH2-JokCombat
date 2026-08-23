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
Modificare soltanto bit unlock, Level/AbilityLevel/EXP delle cinque Form livellabili, target innate verificati, ricompense FMLV e barra Drive. Preservare weapon slot, ability extra e campi non documentati; Anti non riceve una progressione inventata e `DriveForms[5]`/Summon resta intatto.

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

### Vincolo: Movement sicuro nel costume KH1

Status: active

Regola:
Prima del possesso vanilla di Valor, lasciare Quick Run, Dodge Roll, Aerial Dodge e Glide nella lista a MAX ma senza bit equipaggiato; soltanto High Jump può restare attivo.

Perché:
Il gameplay ha confermato T-pose su Square e secondo salto nel modello KH1 anche dopo un import MSET staticamente corretto.

## Fuori scope

- Rifinitura del post-landing e delle transizioni armi Roxas.
- Combo A/Y, ATKP e cancel Sora prima della validazione movement e nucleo combo.
- Controllare direttamente il gameplay o dichiarare esiti senza prova dell'utente.

## Modifiche vietate

- Write globali non protette da identità e readiness.
- Offset per versione eseguibile quando `kh2lib` offre un indirizzo compatibile.
- Sostituzioni massicce del player object Sora come scorciatoia per importare un moveset.
