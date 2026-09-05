# Rischi

## Rischi aperti

### Rischio: Y ruba Reaction o interazioni native

Condizione:
Il router interpreta Y prima che KH2 risolva Reaction, menu, magia o continuazioni Limit.

Impatto:
Comandi contestuali mancanti, branch involontari o softlock di sequenze native.

Mitigazione:
M-01 ha verificato il campo Reaction ma non un edge Y correlato. M-03 elimina il conflitto lasciando Y/Triangolo interamente nativo; se un routing Y verrà reintrodotto in futuro, `Reaction != 0`, menu, pausa e stati non verificati dovranno spegnerlo e servirà una prova reale.

### Rischio: il remap PTYA combina campi incompatibili

Condizione:
La patch cambia soltanto MotionId oppure copia un record da un carrier diverso lasciando selector, Type, flags, recovery, ability o score incoerenti.

Impatto:
Action errata, branch non raggiungibile, T-pose, hitbox mancanti o recovery bloccata.

Mitigazione:
Nel primo slice usare soltanto motion del gruppo Base/P_EX100. Il fallback statico resta hash-verificato; il runtime valida BAR/header/lunghezza, sei record e whitelist, varia i MotionId 31/32/34 e mantiene il 32 su `12/0x12`. `11/0x01` è ammessa soltanto come firma legacy da ripristinare a F1. Ogni write viene riletta; recovery, hitbox e follow-up restano gate gameplay.

### Rischio: Guard carrier esegue una motion offensiva con semantica difensiva

Condizione:
Il selector Guard accetta A319 ma conserva proprietà di parata o perde le hitbox di Vicinity Break.

Impatto:
Quadrato può mostrare l'animazione senza danno, attaccare e parare insieme, o funzionare soltanto da neutrale senza risolvere `A□` targetless.

Mitigazione:
Validare separatamente motion targetless e hitbox/danno/recovery. Non promuovere il carrier nell'albero finché questi gate gameplay non passano; F1 può sempre ripristinare A322.

### Rischio: speciale OFF rende ineleggibile la motion custom

Condizione:
Il bit equipaggiato della speciale `Type 1/2/3` è richiesto anche quando un carrier Quadrato `Type 0` usa il suo MotionId.

Impatto:
A resta correttamente Base, ma `A□` o un altro nodo custom viene rifiutato prima della motion.

Mitigazione:
Lasciare ON i carrier Upper Slash/Horizontal Slash e validare dopo F1 una sola motion ground e una air. Se fallisce, isolare una speciale per volta; non riattivare in massa il set che ha già dimostrato di sostituire A su hit.

### Rischio: profondita virtuale anticipata da un A non accettato

Condizione:
Il callback campiona l'edge fisico A prima che KH2 decida se consumarlo nella cancel window.

Impatto:
Il Quadrato successivo potrebbe aprire la famiglia sbagliata rispetto agli attacchi realmente eseguiti.

Mitigazione:
Solo A1 da neutrale viene preparato immediatamente. A2+ resta pending e avanza soltanto quando il player passa a una diversa motion Base d'attacco entro 30 frame; neutrale, timeout, UI e contesti non validi cancellano lo stato.

### Rischio: una candidata dispatcher correlata viene trattata come causa

Condizione:
Il confronto M-03B ha isolato 57 byte stabili fra Quadrato neutrale e `A□`, ma erano motion, transform, timer o altre conseguenze post-dispatch. Il confronto hit/miss successivo ha inoltre mescolato motion diverse e contato edge mentre A310 era già attiva.

Impatto:
Una patch prematura può rubare A, Guardia o Reaction, corrompere lo stato action oppure causare crash.

Mitigazione:
V1/V2/V3/V5 non devono essere riproposte. M-03C resta read-only e ha chiuso il bucket omogeneo a `2/2`; M-03D tipizza le candidate e confronta hit, whiff libero e whiff in lock-on senza write. Nessuna candidata viene scritta senza firma version-safe, semantica verificata, rollback e gate gameplay dedicato.

### Rischio: R2 confligge con funzioni native

Condizione:
La palette intercetta R2 o le direzioni mentre il gioco usa già lo stesso input in un altro stato.

Impatto:
Selezioni accidentali, command menu alterato o stance switch durante uno stato non valido.

Mitigazione:
Usare solo l'edge esatto `Input+0x04 == 0x09`, riconoscere i quattro raw32 D-pad calibrati e disabilitare la palette in UI, Reaction e contesti non verificati; ogni altro valore fallisce chiuso.

### Rischio: Variante base-looking perde dipendenze del carrier

Condizione:
Dual o Feral sostituisce modello, texture, collisione, attachment o weapon state senza preservare le dipendenze native mappate.

Impatto:
T-pose, armi mal posizionate, hitbox/VFX mancanti o crash.

Mitigazione:
Provare prima Roxas Dual e Anti con asset nativi, poi un solo attacco e una sola variante visiva. Anti conserva la collisione propria; Roxas non riceve motion Sora né cede motion `Sxxx` senza retarget verificato.

### Rischio: Hit-path standard e ATKP duplicati vengono interpretati per ipotesi

Condizione:
Il router o un asset portato assume che l'ID del trigger scelga sempre SubId 0/NeoStatus, oppure che una motion senza trigger 10/33 contenga già tutto il danno necessario.

Impatto:
Colpi senza danno, effetti errati, hitbox duplicate o proprietà prese da una riga ATKP sbagliata.

Mitigazione:
Conservare tutte le candidate ATKP, usare come prove complete soltanto ID univoci e lasciare le catene A/Roxas standard al carrier nativo finché la dispatch engine non è verificata.

### Rischio: Switch lascia stato residuo

Condizione:
La stance o la Form cambia durante aria, recovery, danno, morte, cambio area o rebuild di `Slot1`.

Impatto:
Player object, motion, weapon state e profilo logico possono divergere.

Mitigazione:
Consentire inizialmente solo neutrale/cancel window verificate e implementare recovery deterministico verso Normal.

### Rischio: Normal diventa inutile

Condizione:
Dual e Feral mantengono tutta l'utilità di Normal oltre ai loro vantaggi offensivi.

Impatto:
La palette perde significato e il combat converge su una sola stance dominante.

Mitigazione:
Riservare a Normal difesa, magia e controllo più affidabili; bilanciare Dual/Feral solo dopo stabilità funzionale.

## Rischi accettati

- Le prime build sperimentali possono usare l'aspetto nativo del carrier: la coerenza base-looking viene affrontata solo dopo la prova meccanica.

## Rischi chiusi

- Lo swap diretto delle motion Roxas su `P_EX100` non è più un'incertezza: è respinto dal mismatch 229/228 ossa e `WeaponJoint 14/1` misurato sugli asset retail.
- Il buffer Quadrato tramite write input in `_OnFrame` è respinto: pulse osservati alle finestre A312/A319 non sono stati consumati, mentre lo stesso input fisico ha prodotto A310.
- V5 Guard32 è respinta: posizione, identità e A310 erano corrette ma `A□` è tornato idle senza avviare la motion; il runtime conserva soltanto il recupero F1 della firma legacy.
