# Decisioni

## Decisioni attive

### Decisione: Tre stance persistenti e un comando Drive

Status: active
Area: input architecture

Decisione:
La palette R2 contiene Normal, Dual e Feral come stance persistenti e Drive Cancel come azione one-shot verso una vera Drive Form.

Rationale:
Le tre stance definiscono il moveset base del giocatore; Drive Cancel cambia temporaneamente Form e non deve comportarsi come una quarta stance fittizia.

Conseguenze:
- Il target Drive deve essere armato o selezionato con un contratto ancora da definire.
- Al revert si ripristina la stance precedente in uno stato neutrale valido.

### Decisione: Aspetto Base separato dal carrier tecnico

Status: active
Area: player state

Decisione:
Normal, Dual e Feral mostrano Sora base, ma soltanto Normal è obbligata a usare il carrier Base; Dual e Feral possono usare stati tecnici compatibili e asset base-looking dedicati.

Rationale:
Forzare motion Roxas o Anti su `P_EX100` ignora skeleton, weapon bone, PTYA, ATKP, VFX e transizioni e ripete il failure mode delle T-pose.

Conseguenze:
- Prima si valida il carrier con il suo asset nativo, poi la variante visiva.
- Un carrier non dimostrabile viene rifiutato o sostituito, non forzato tramite write arbitrarie.

### Decisione: Mappatura e probe precedono il router

Status: active
Area: workflow

Decisione:
M-01 e M-02 restano read-only; nessun routing A/Y, stance o Drive Cancel viene implementato prima di ownership input e pipeline native verificate.

Rationale:
Le decisioni di routing dipendono da Reaction, motion, weapon state e cancel window che oggi non sono ancora mappati.

Conseguenze:
- Il primo deliverable è documentazione più probe, non un cambio gameplay.
- Ogni milestone successiva usa criteri di completamento basati su log e test reali.

### Decisione: Roxas nativo per la meccanica, Final come ponte sul rig Sora

Status: active
Area: carrier architecture

Decisione:
Gli attacchi Roxas esatti vengono provati prima sul carrier nativo `P_EX110_BTLF`; Final è il donor/carrier Sora dual primario e Master il backup air, ma nessuna motion `Sxxx` viene importata direttamente su un modello Sora.

Rationale:
Roxas/Roxas Dual hanno 229 ossa e `WeaponJoint 14`; tutti i carrier Sora analizzati ne hanno 228 e `WeaponJoint 1`. Final condivide il rig Sora e possiede famiglie PTYA ground/air complete, mentre Master è air/hover nel gruppo retail analizzato.

Conseguenze:
- M-04 separa la prova meccanica Roxas dalla variante visiva Sora.
- Un eventuale Dual basato su Final usa action Final finché un retarget Roxas non è dimostrato.
- Lo swap ANB Roxas → `P_EX100` è classificato incompatibile e non viene tentato alla cieca.

### Decisione: Anti conserva collisione e hit-path native

Status: active
Area: carrier architecture

Decisione:
Feral parte dal carrier Anti nativo; una futura variante Base può sostituire soltanto elementi visivi verificati e non la collisione Anti o il fallback no-weapon.

Rationale:
Anti condivide modello e rig da 228 ossa con Base, ma usa 34 record collisione propri e hitbox corporee ATKP esplicite. `F302` e `F331` sono catene complete e non ambigue.

Conseguenze:
- Weapon hide, collisione, ATKP e recovery Anti restano di proprietà del carrier.
- La variante texture Base viene affrontata in M-04 dopo l'attacco nativo.

### Decisione: Nessuna inferenza NeoStatus → ATKP SubId

Status: active
Area: data mapping

Decisione:
Il mapper conserva tutte le righe ATKP associate all'ID del trigger e non usa `Objentry.NeoStatus` per sceglierne una senza documentazione del dispatch.

Rationale:
La tabella retail contiene ID ripetuti con lo stesso SubId ma proprietà diverse e ID con più SubId. Scegliere automaticamente NeoStatus o SubId 0 produrrebbe una falsa catena end-to-end.

Conseguenze:
- Le prove complete M-02 usano ID semanticamente univoci.
- I casi ambigui restano lacune esplicite fino a prova del motore.

### Decisione: Chiusura M-01 con evidenza aggregata e gate Reaction

Status: active
Area: validation

Decisione:
M-01 è chiusa usando acquisizioni indipendenti che, nel complesso, coprono A/Y/R2, quattro D-pad, UI, Reaction raw e Base/Wisdom/Valor. Le prove non eseguite — hold A e Y nello stesso istante di una Reaction — non vengono considerate superate. Erano un gate per il precedente piano A/Y; restano obbligatorie soltanto se Y verrà intercettato in futuro.

Rationale:
L'obiettivo di M-01 è rendere osservabili input e priorità senza routing; ripetere due matrici identiche non aggiunge informazione necessaria a M-02, mentre inventare l'esito di T-04 sarebbe scorretto.

Conseguenze:
- A resta interamente nativa, incluso l'hold.
- `Reaction != 0`, menu, pausa e stati non verificati disabilitano ogni ramo personalizzato.
- Se una milestone futura tornerà a intercettare Y, dovrà prima superare la prova Reaction reale; M-03 non è più bloccata perché lascia Y interamente nativo.

### Decisione: M-03 usa Quadrato e preserva Y nativo

Status: active
Area: input architecture

Decisione:
Usare A/Quadrato per la grammatica del vertical slice e per la direzione comune del combat. Y/Triangolo non viene intercettato. Quadrato conserva la dispatch PTYA nativa: nel proof corrente il selector Guard da neutrale usa A319 Vicinity Break, mentre durante una combo restano disponibili le Action Ability del carrier. Nessun branch viene espresso tramite input sintetico.

Rationale:
Quadrato possiede già i selector PTYA di Guard, Upper Slash, Finishing Leap e delle altre Action Ability. Usare quella dispatch conserva Reaction Command, interazioni, targeting, motion, hitbox e danno nel motore nativo.

Conseguenze:
- M-03 non contiene un router input Lua.
- Il profilo PTYA modifica soltanto MotionId Base whitelisted. Il record 32 conserva l'identità nativa `12/0x12`; la firma V5 completa è riconosciuta soltanto per recuperare RAM legacy a F1.
- Il proof sacrifica la parata ground ma preserva selector/ability Guard, Counterguard, Retaliating Slash, Reaction e Y nativo.

### Decisione: profilo A-base separa A dai carrier Quadrato

Status: active
Area: ability ownership

Decisione:
Mantenere tutte le 25 Action Ability disponibili, ma lasciare OFF le dodici speciali `Type 1/2/3` selezionabili automaticamente da A. Restano ON i sei carrier Quadrato `Type 0`, Trinity e i supporti combo.

Rationale:
Quattro `A□` a vuoto sono partiti da A300 e sono stati rifiutati; i casi su hit sono stati accettati ma A era già diventata Flash Step A318 o Vicinity Break A319. Il target modificava quindi la tecnica scelta su A prima del Quadrato. Il profilo A-base rende uniforme la catena A senza cancellare le motion dal gioco.

Conseguenze:
- Dopo F1, una singola A deve partire da A300 sia a vuoto sia su bersaglio.
- Upper Slash e Horizontal Slash restano equipaggiate come ownership dei record PTYA 32/34; `NormalCombo` può ancora assegnare a quei record MotionId di speciali OFF, da verificare live.
- Se una speciale OFF rende la motion ineleggibile anche tramite carrier, non si riattivano tutte le speciali: si isola il requisito minimo con una prova reversibile.
- Lo stato ability può diventare persistente salvando; fino alla validazione usare una save di prova o non salvare.

### Decisione: proof targetless ground usa Guard come carrier di Vicinity Break

Status: active
Area: combat grammar

Decisione:
Mantenere Guard equipaggiata come ownership fisica di Quadrato, ma cambiare a runtime soltanto il MotionId del record Base 31 da `173/A322 Guard` a `170/A319 Vicinity Break`. V1/V2/V3 restano respinte; il nuovo proof non tocca carrier 0/1, input, target, selector, Type, flags, ability, score o record aerei.

Rationale:
Il selector Guard è già accettato a terra senza bersaglio e quindi prova un confine diverso dai record offensivi hit-gated 32/34. Usare una motion Base già presente evita T-pose da carrier estraneo e consente di verificare separatamente dispatch, hitbox e finestra `A□` senza sintetizzare input.

Conseguenze:
- La parata normale non è disponibile mentre il flag del proof è attivo; disattivarlo e premere F1 ripristina A322.
- Il proof record 31 è ground-only. Air Square/Aerial Dodge e record 34 restano separati; dopo A il record 32 resta soggetto al dispatcher offensivo nativo.
- Il gameplay deve verificare tre gate: A319 da neutrale senza target, hitbox/danno/recovery, poi `A□` dopo una A mancata.
- Un successo da neutrale non prova automaticamente il ramo dopo A; un test statico non prova nessuno dei due.
- L'albero finale mantiene stati distinti per prefisso A, Quadrati confermati e suffisso A; ogni avanzamento richiede una motion osservata.

### Decisione respinta: V5 usa l'identità Guard nella posizione record 32

Status: rejected
Area: runtime data

Decisione:
Non cambiare più il record Base 32 dalla coppia Upper Slash
`Selector=12/Ability=0x12` alla coppia Guard `11/0x01`. Conservare `12/0x12`;
riconoscere `11/0x01` con Type zero soltanto come residuo da ripristinare a F1.

Rationale:
Il test live V5 mostra `depth=1`, posizione 32, identità Guard e A310 corretti,
seguiti da `SQUARE_RESULT REJECTED ... RESET_IDLE`. L'eleggibilità targetless
del record 31 non viene trasferita copiandone selector/ability nella posizione
offensiva: il rifiuto avviene prima dell'avvio della motion.

Conseguenze:
- Nessuna nuova rotta arma V5; firme miste o estranee disabilitano il modulo.
- Il recupero F1 rilegge e ripristina `12/0x12` con rollback fail-closed.
- Non creare una V6 PTYA; M-03C passa a osservazione pre-edge action/command read-only.

### Decisione: M-03C confronta soltanto trial pre-edge omogenei

Status: active
Area: diagnostics

Decisione:
Usare `KH2JokCombat_ActionProbe.lua` per conservare lo snapshot del frame prima
dell'edge fisico di Quadrato e confrontare almeno due `AFTER_A_ACCEPTED` con
due `AFTER_A_REJECTED` soltanto nello stesso bucket motion/slot/finestra.
Non scrivere alcuna candidata.

Rationale:
Le 57 differenze M-03B erano conseguenze post-dispatch. Il confronto hit/miss
ha poi mescolato motion diverse e contato `#012` nello stesso frame della
risoluzione `#011` e `#013` con A310 già attiva. Il frame precedente e i bucket
omogenei sono necessari per restringere l'action state o la cancel window.

Conseguenze:
- Il logger usa la categoria dedicata `DISPATCH`; gli altri gruppi sono OFF.
- Quattro `ReadArray` mantengono un solo rolling snapshot player/menu/control/input.
- Gli edge di risoluzione e le motion già attive non creano nuovi campioni.
- Chiuso `2/2`, M-03D raggruppa le candidate per allineamento e le registra con i target pointer in una riga per trial; resta vietata ogni write.
- Una candidata richiede identità semantica e una firma version-safe
  prima che possa essere proposta una patch reversibile.

### Decisione: M-03E valida temporalmente il bit 25 senza scriverlo

Status: active
Area: diagnostics

Decisione:
Trattare `PLAYER+0x120 & 0x02000000` come candidato evento/eleggibilità dal
nome provvisorio. Estendere i sample ad A300/A301/A302 e registrare soltanto
ingresso nella motion Base, transizioni del bit e uscita significativa. Non
scrivere il flag né usarlo ancora per forzare Quadrato.

Rationale:
Nei campioni M-03D target pointer e altri sei campi non separano gli esiti; il
bit 25 è invece coerente. Nell'eseguibile Steam hash-verificato più handler lo
impostano, un consumer di evento lo testa e i rami successivi lo azzerano.
Questa è evidenza causale più forte, ma non dimostra ancora il momento preciso
né autorizza a riprodurre lo stato interno del motore.

Conseguenze:
- `M03D SAMPLE` copre A300, A301 e A302 ed espone `F120/bit25`.
- `M03E START/BIT25/EXIT` resta sotto la sola categoria `DISPATCH`.
- Una futura write richiede ancora timing live, firma version-safe, ownership,
  rollback e un gate gameplay separato.

### Decisione respinta: usare shadow carrier PTYA completi per Quadrato targetless

Status: rejected
Area: runtime data

Decisione:
Non caricare più V3. Il test live ha dimostrato che i carrier 0/1 non rendono affidabile Quadrato targetless e possono intercettare A; il sorgente resta soltanto come artefatto di falsificazione.

Rationale:
Il primo `A□` V3 ha prodotto `REJECTED`; durante una sequenza successiva A310 Upper Slash è partita sull'edge A prima di Quadrato e ha attivato `HIJACK_BEFORE_SQUARE`. I due rollback hanno ripristinato i carrier, ma la priorità degli slot appartiene alla selezione A e non risolve la dispatch Square.

Conseguenze:
- L'entry manifest e la copia live vengono rimosse; i carrier PTYA 0/1 tornano fuori dall'ownership runtime.
- Non creare varianti dei carrier 0/1 modificando Type, Ability, Score, angoli, selector o posizione PTYA.
- Il proof Guard-carrier è l'architettura separata autorizzata; non riabilita V1/V2/V3.

### Decisione: routing PTYA live limitato ai record 31/32/34

Status: active
Area: runtime data

Decisione:
Risolvere `00battle.bin/ptya` dal `Btl0Pointer` a ogni processo. Il record 31 può alternare esclusivamente A322 Guard e A319 Vicinity Break; i record 32/34 preparano i profili ground/air già whitelisted e il 32 mantiene l'identità nativa `12/0x12`. Non hardcodare l'indirizzo heap e non duplicare record usando `Combo Offset`.

Rationale:
Il blocco PTYA live e stato localizzato in modo univoco e il gioco legge gli stessi record usati dal fallback statico. In tutti i 15 gruppi retail unici `Combo Offset` vale uno solo per Finishing Leap e zero altrove, quindi non esiste evidenza che selezioni la profondita A.

Conseguenze:
- Header BAR/PTYA, lunghezza, gruppo Base e sei record vengono verificati prima della prima write; valori esterni alla whitelist disabilitano il modulo.
- Ogni write è riletta e il profilo depth zero ripristina A315/A341; F1 recupera unicamente un'eventuale firma Guard32 legacy. UI, cambio Form, timeout e neutrale azzerano la rotta.
- Il runtime e autorizzato solo su Steam 1.0.0.10 finche un'altra versione non possiede firme e offset propri.

### Decisione: respingere il buffer input in `_OnFrame`

Status: active
Area: runtime input

Decisione:
Non scrivere A, Y o Quadrato nel campo input da `_OnFrame` per avviare action combat. Conservare il probe read-only e spostare M-03 su PTYA/action-level; una futura iniezione richiederebbe un hook pre-dispatch nativo esplicito.

Rationale:
Nel test live i pulse Quadrato sono stati emessi esattamente a Dodge Slash A312 frame 58 e Vicinity Break A319 frame 32, ma entrambe le action sono terminate in neutrale senza branch. Il Quadrato fisico ha invece prodotto Upper Slash A310. Il timing di `_OnFrame` è quindi troppo tardo o viene sovrascritto prima della dispatch.

Conseguenze:
- `KH2JokCombat_NormalRouter.lua`, il suo smoke test e la manifest entry vengono rimossi da repo e runtime live.
- Il test statico del router è classificato come modello mock insufficiente, non come prova della dispatch reale.
- Y/Triangolo e Guardia neutrale restano completamente native.

## Decisioni sostituite o obsolete

- La V3 con shadow carrier PTYA 0/1 è respinta: un `A□` è rimasto hit-gated e un A successivo è stato sostituito da Upper Slash; rollback riuscito.
- La V2 `Type=3 + Ability=0` sui record 32/34 è respinta: cinque `A□` validi sono rimasti hit-gated con rollback corretto.
- La variante che cambiava soltanto `Type 0→3` sui record 32/34 è respinta: due `A□` validi sono rimasti hit-gated; il rollback ha funzionato.
- La V5 Guard32 è respinta: posizione, identità e motion erano corrette ma `A□` è tornato idle senza avviare A310.
- È sostituita la decisione che vietava un Custom Combo Master per Quadrato e considerava previsto il blocco a vuoto.
- È sostituita la parte della decisione M-03 che autorizzava un buffer Quadrato a singolo edge in `_OnFrame`.
- La catena fissa Explosion→Finishing Leap→Aerial Spiral come intero profilo Normal e sostituita dalla matrice a profondita; A315/A341 restano il fallback statico a depth zero.
