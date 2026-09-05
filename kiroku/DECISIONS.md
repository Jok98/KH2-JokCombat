# Decisioni

## Decisioni attive

### Decisione: Sora è il focus attivo

Status: active
Area: scope

Decisione:
Considerare il capitolo Roxas concluso per scope e concentrare il lavoro futuro su Sora.

Rationale:
Roxas occupa un capitolo breve e la baseline Dual-Wield è sufficiente per proseguire verso il personaggio principale.

Conseguenze:
- I problemi Roxas noti restano archiviati e non sono TODO attivi.
- Roxas viene riaperto solo per una regressione richiesta esplicitamente.

### Decisione: Tutte le growth MAX restano equipaggiate

Status: active
Area: movement

Decisione:
Mantenere High Jump, Quick Run, Dodge Roll, Aerial Dodge e Glide a livello MAX con il bit equipaggiato attivo a ogni F1/load. Non usare il possesso di Valor né un flag storia non verificato come segnale del costume.

Rationale:
Il profilo KH1 non possedeva alcuna transizione al costume KH2 e quindi disabilitava per sempre quattro growth, anche dopo l'evento dei vestiti. La correzione richiesta è che lo script non trasformi più una misura temporanea in stato permanente.

Conseguenze:
- Le write convergono su `0x8061`, `0x8065`, `0x8237`, `0x8069`, `0x806D` e non rimuovono più il bit `0x8000`.
- Nessuna write viene eseguita durante Roxas.
- Una vecchia save con costume KH1 può ancora andare in T-pose con le quattro growth avanzate; non esiste al momento un gate automatico affidabile.
- Un futuro supporto KH1 condizionale richiede un segnale diretto del modello/outfit e una regressione dedicata.

### Decisione: Tutte le Drive Form e le loro ability subito

Status: active
Area: progression

Decisione:
Sbloccare Valor, Wisdom, Limit, Master, Final e Anti; portare a massimo le cinque progressioni normali, garantire gli array innate vanilla, assegnare a Sora tutte le ricompense vanilla dei livelli Form ed espandere/riempire Drive a 9/9.

Rationale:
Il focus è il combat di Sora e la progressione Form non deve limitare il moveset sperimentabile. I record, gli array innate e le ricompense sono stati verificati direttamente nei dati Final Mix.

Conseguenze:
- I bit Form sono aggiunti con OR, preservando gli altri item di `ItemSet1` e `ItemSet11`.
- Valor, Wisdom, Limit, Master e Final diventano Level 7/AbilityLevel 4/EXP 0; Anti riceve soltanto il bit unlock perché non possiede un record Drive Form nella save.
- Le 24 ability slot per Form preservano extra non riconosciuti e aggiungono/equipaggiano solo target vanilla mancanti.
- Forms non scrive i weapon slot; il modulo Keyblade inizializza separatamente soltanto Master/Final se vuoti, secondo la decisione dedicata agli equipaggiamenti.
- `DriveForms[5]` Final Mix è Summon e resta completamente intatto; le innate Anti sono già dati nativi PLRP, non stato da copiare nella save.
- Le ricompense standard condivise Combo Plus/Air Combo Plus hanno gli stessi target del Combo Core e restano idempotenti in qualunque ordine di caricamento.

### Decisione: Drop item base al 200% tramite Lucky Lucky native

Status: active
Area: drops

Decisione:
Garantire a Sora due copie equipaggiate di Lucky Lucky nella tabella ability standard, senza patchare l'eseguibile né modificare le ability degli altri personaggi.

Rationale:
In Final Mix il moltiplicatore nativo è `1 + (0,5 × copie equipaggiate dai personaggi in battaglia)`: due copie su Sora producono `2,0×` quando non esistono altri bonus. Forms possiede già Lucky Lucky e la tabella standard, quindi mantenere qui il target evita ownership duplicata.

Conseguenze:
- Il modulo aggiunge/equipaggia soltanto la seconda copia mancante e preserva copie estranee.
- Ability o accessori Lucky Lucky aggiuntivi sui personaggi in battaglia possono superare il 200%; non vengono rimossi.
- Le due copie risiedono nella save RAM e possono diventare persistenti se la partita viene salvata.
- Il probe richiede due copie presenti e ON; lo smoke test verifica il target.

### Decisione: Combat native-first

Status: active
Area: architecture

Decisione:
Usare prima PTYA, MSET, ANB e ATKP; introdurre routing Lua solo quando il dato nativo non basta.

Rationale:
Il motore nativo conserva compatibilità con animazioni, hitbox, targeting, danno e transizioni meglio di una ricostruzione parallela.

Conseguenze:
- Le patch Lua devono restare strette e verificabili.
- La grammatica combo A/Quadrato viene progettata dopo la mappatura delle risorse native Sora.

### Decisione: Grammatica A/Quadrato e Form proprietarie del moveset

Status: active
Area: combat architecture

Decisione:
Usare A come catena normale e Quadrato come ramo contestuale in ogni profilo di combattimento. Nel proof Normal corrente, Quadrato da neutrale conserva il selector Guard ma usa A319 Vicinity Break; durante una catena ground il record 32 conserva l'identità Upper Slash nativa e può variare soltanto la motion whitelisted. Y/Triangolo resta interamente nativo per Reaction Command e interazioni. La Form o stance corrente determina il catalogo di azioni; R2 seleziona il profilo o attiva un Drive Cancel.

Rationale:
Quadrato possiede già Guardia e le Action Ability PTYA complete di KH2, quindi riusarlo evita di competere con Reaction e permette al motore nativo di conservare targeting, motion, hitbox e danno. Il test live ha escluso l'aggiunta di tolleranza tramite write input in `_OnFrame`.

Conseguenze:
- Normal usa una profondita virtuale basata sugli A accettati: A1 da neutrale è immediato, A2+ richiede una nuova motion d'attacco. La profondità prepara il dato PTYA ma non può sostituire l'arbitraggio action/cancel del motore.
- Le modifiche dei rami devono avvenire su record PTYA/action completi dello stesso carrier; nessun edge combat viene sintetizzato da Lua.
- Y/Triangolo non viene scritto né intercettato; Reaction Command e interazioni restano native.
- Base, Valor, Wisdom, Limit, Master e Final usano profili distinti con la stessa grammatica; Anti non diventa automaticamente una Form selezionabile.
- Il Drive Cancel usa una vera transizione di Form ed è consentito inizialmente solo da neutrale o da cancel window esplicite.
- Un eventuale aspetto visivo da Sora base per profili Dual o Anti non implica che il loro carrier tecnico debba essere il record Base.

### Decisione respinta: V5 clona l'identità Guard nel record 32 ground

Status: rejected
Area: combat runtime

Decisione:
Non armare più l'identità Guard `Selector=11/Ability=0x01` nel record Base 32.
Mantenere l'identità Upper Slash nativa `12/0x12`; F1 può riconoscere e
ripristinare soltanto l'esatta firma legacy V5 con `Type=0`.

Rationale:
Il gameplay ha mostrato `depth=1`, record 32 con selector/ability Guard e motion
A310 corretti, seguito da `SQUARE_RESULT REJECTED ... RESET_IDLE`. L'identità
targetless del record 31 non trasferisce la sua eleggibilità alla posizione 32:
il rifiuto avviene prima dell'avvio della motion.

Conseguenze:
- Non creare V6 basate su selector, ability, Type, score o nuove posizioni PTYA.
- Il recupero F1 è one-shot e fail-closed; nessuna rotta riattiva `11/0x01`.
- M-03C passa a una sonda pre-edge read-only del dispatcher/action state prima di
  autorizzare qualunque nuova write.

### Decisione: M-03C confronta soltanto contesti pre-edge omogenei

Status: active
Area: diagnostics

Decisione:
Usare il frame precedente all'edge Quadrato e confrontare almeno due
`AFTER_A_ACCEPTED` con due `AFTER_A_REJECTED` soltanto quando motion, slot e
finestra temporale coincidono. Scartare edge che risolvono un trial pendente o
che avvengono con la motion attesa già attiva.

Rationale:
Le 57 differenze M-03B erano state acquisite dopo la dispatch. I log successivi
hanno mescolato A302/A309/A310/A319 e contato due falsi trial, quindi un
confronto per classe larga non può separare causa ed effetto.

Conseguenze:
- `ActionProbe` resta zero-write e usa `ReadArray` per il rolling snapshot.
- `DISPATCH` mostra esiti e bucket; i dettagli frame-per-frame passano a `TRACE`.
- Dopo il gate `2/2`, M-03D raggruppa le differenze byte in campi tipizzati e le correla a `+0x98/+0xA0` senza modificarle.
- Nessuna candidata viene scritta senza una verifica semantica e version-safe.

### Decisione: Palette R2 Normal, Dual, Feral e Drive Cancel

Status: active
Area: combat architecture

Decisione:
Usare R2 come palette di quattro opzioni: Normal con una Keyblade, Dual con due Keyblade e attacchi Roxas, Feral senza Keyblade e attacchi Anti, tutte base-looking, più Drive Cancel verso una vera Drive Form. Le prime tre sono stance persistenti; Drive Cancel è un comando one-shot.

Rationale:
Questa struttura integra identità base, dual-wield, stile ferale e Form native senza ridurre il combat allo spam di A né trapiantare ciecamente le action straniere nello stato Base.

Conseguenze:
- Normal usa il carrier Base; Dual e Feral devono usare carrier tecnici verificati anche se l'aspetto resta Sora base.
- Il primo Drive Cancel viene provato su una sola Form e soltanto da neutrale o cancel window verificata.
- Alla fine della Form si ripristina la stance precedente in uno stato valido.
- Mapping esatto delle direzioni R2, feedback e selezione della Form armata restano dettagli implementativi del track `sora-combat-system`.

### Decisione: AP live di Sora al massimo del campo

Status: active
Area: stats

Decisione:
Mantenere gli AP live di Sora a `0xFF`/255 tramite `Slot1+0x18E`, senza modificare il contatore AP Boost della save.

Rationale:
OpenKH espone nella save solo `ApBoost`, non il totale AP. Il campo live è un byte e la richiesta è il massimo assoluto, quindi 255 è il target corretto; 150 è soltanto il limite scelto dall'interfaccia del Randomizer per Starting AP.

Conseguenze:
- Il target viene applicato soltanto con identità Sora e forma base verificate.
- Una ricostruzione di `Slot1` può azzerare il valore, quindi il modulo lo ripristina in modo idempotente.
- Disabilitare il modulo rimuove la garanzia runtime; nessun AP Boost artificiale resta nella save.
- Ogni valore live inferiore viene portato a 255; nessun valore maggiore è rappresentabile nel campo.

### Decisione: Combat Core completo con profilo A-base

Status: active
Area: combo

Decisione:
Garantire tutte le 25 Action Ability standard di Sora, ma separare disponibilità e selezione nativa. Restano ON i sei carrier Quadrato Type 0 e Trinity Limit; le dodici speciali A Type 1/2/3 e le sei Auto restano presenti ma OFF. Conservare Combo Master x1, Combo Plus x2 e Air Combo Plus x2 equipaggiati.

Rationale:
M-03C ha registrato quattro rifiuti a vuoto partiti da A300, ma su hit KH2 sostituiva A con Flash Step A318 o Vicinity Break A319 e accettava il Quadrato. Disequipaggiare le speciali impedisce questa selezione automatica senza rimuoverle dalla lista; mantenere ON i carrier Type 0 conserva l'ownership fisica dei rami custom.

Conseguenze:
- A deve usare la catena Base `A300/A301/A302` anche in presenza di un bersaglio; la prova gameplay dopo F1 resta obbligatoria.
- Il modulo riusa la tabella standard da 69 slot e non ricostruisce attacchi o combo in Lua.
- Le copie già presenti vengono riusate; si aggiungono solo quelle mancanti e si verifica lo stato ON/OFF dopo ogni write.
- I record PTYA 32/34 conservano l'ability Type 0 ON e possono ricevere il MotionId di una speciale OFF; questo comportamento deve essere validato per ogni ramo.
- Il test con costume KH1 deve coprire ogni motion custom perché alcune motion avanzate potrebbero non essere disponibili nel relativo MSET.
- La progressione vanilla di Action e support combo viene intenzionalmente superata.

### Decisione: Tutte le Keyblade standard tranne Ultima Weapon

Status: active
Area: progression

Decisione:
Garantire subito le 23 Keyblade standard di Sora diverse da Ultima Weapon. Se i weapon slot anticipati sono vuoti, inizializzare Master con Bond of Flame e Final con Oblivion; non includere armi debug, Struggle o dummy Form e non sovrascrivere alcuno slot non vuoto.

Rationale:
Il giocatore deve poter sperimentare liberamente armi e relative ability durante il nuovo workstream Sora, mantenendo Ultima Weapon come eccezione esplicita. Lo sblocco anticipato lasciava Master/Final con weapon `0`, mostrato come `? ----`, e aprire il selettore poteva causare crash; assegnare default validi elimina lo stato nullo. Contare anche le armi equipaggiate e trasferire la copia dallo stock evita duplicazioni dopo F1 o reload.

Conseguenze:
- Solo i target con stock zero e non presenti nei weapon slot Sora/Form ricevono conteggio `1`.
- Master `Save+0x339C == 0` riceve Bond of Flame `0x01F2`; Final `Save+0x33D4 == 0` riceve Oblivion `0x002B`.
- Se il default esiste nello stock, il conteggio diminuisce di uno; se è già equipaggiato altrove senza una copia disponibile, il piano fallisce prima delle write.
- Ogni valore nonzero in Master/Final e tutti gli slot Sora/Valor/Wisdom/Limit restano invariati, quindi una scelta manuale successiva non viene annullata.
- Ultima Weapon viene osservata e preservata, non concessa né rimossa se già posseduta.
- Winner's Proof e Two Become One fanno parte del pool standard; Alpha/Omega Weapon, Struggle Sword/Wand/Hammer, Pureblood e Kingdom Key D restano escluse.
- La progressione vanilla delle 23 Keyblade viene intenzionalmente anticipata e diventa persistente salvando la partita.

### Decisione: Cost Limit Gummi al massimo sicuro 1200

Status: active
Area: gummi

Decisione:
Mantenere il livello Max Allowed Cost a `6`, equivalente a Cost Limit 1200, senza tentare valori 9999 o un bypass illimitato e senza modificare inventario, missioni o Teeny Ship.

Rationale:
Il byte persistente verificato espone il range noto fino a `6`; 1200 è il massimo supportato dai due Cost Converter nativi. Valori superiori sono fuori range e possono generare navi invalide o fallimenti all'avvio missione.

Conseguenze:
- `KH2JokCombat_GummiCost.lua` possiede soltanto `Save+0x10F0A` e ripristina `6` se la progressione vanilla scrive un livello inferiore.
- Ogni valore `>6` viene preservato e causa disattivazione fail-closed fino a F1.
- Il valore diventa persistente salvando la partita; la prova gameplay deve coprire editor, salvataggio blueprint e avvio missione con costo superiore a 600.

### Decisione: Clone OpenKH come working copy canonica

Status: active
Area: workflow

Decisione:
Sviluppare direttamente in `C:\Users\jok\Documents\KH_mod\openkh\mods\kh2\Jok98\KH2-JokCombat`, la repository Git letta da OpenKH Mods Manager.

Rationale:
Il Build ricompone `openkh/mod/kh2` da quella clone e sovrascrive le copie manuali, causando test di script diversi dai sorgenti analizzati.

Conseguenze:
- Uno staging sandbox può essere usato per preparare patch, ma ogni delta effettivo deve essere sincronizzato e hash-verificato nella clone OpenKH.
- Trattare la cartella live come artefatto generato e verificarne gli hash dopo ogni Build.

### Decisione: Log per categoria con un solo focus operativo

Status: active
Area: observability

Decisione:
Usare un solo modulo di logging con flag funzionali. Lasciare sempre visibili
`ERROR` e `WARNING`; abilitare un solo focus operativo alla volta. Durante
M-03C è ON soltanto `DISPATCH`; `COMBAT`, `SYSTEM`, `PROGRESSION`, `GUMMI`,
`PROBE` e `TRACE` restano OFF.

Rationale:
I messaggi di progressione già applicata e i probe rendevano il log F1 quasi
inutilizzabile durante lo sviluppo della combo Base.

Conseguenze:
- Per una diagnosi si abilita soltanto la categoria necessaria e si ricostruisce la mod.
- `TRACE` possiede i dettagli della state machine; `COMBAT` registra il ramo custom utile.
- `DISPATCH` è riservata ad `ActionProbe`; con il flag del proprio gruppo OFF i diagnostici non caricano `kh2lib` né svolgono lavoro per-frame.

## Decisioni sostituite o obsolete

- La proposta di usare Y/Triangolo come ramo combo universale è sostituita da A/Quadrato; Y resta nativo per Reaction Command e interazioni.
- Il profilo KH1 conservativo permanente è sostituito dall'attivazione delle cinque growth MAX: non aveva alcun segnale di transizione e disabilitava quattro ability dopo ogni F1/load anche nel costume KH2.
- Il possesso di Valor come proxy dei vestiti KH2 è obsoleto perché Valor viene ora sbloccato intenzionalmente prima dell'evento vanilla.
- Il post-landing Roxas non è più la priorità corrente; resta documentato solo come archivio tecnico.
