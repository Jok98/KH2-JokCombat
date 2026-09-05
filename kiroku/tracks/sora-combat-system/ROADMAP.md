# Roadmap

## Milestone

### M-01: Baseline osservabile e ownership input

Status: completed

Current gate:
Completata il 2026-08-26 con evidenza aggregata da acquisizioni indipendenti: A/Y, R2 esatto, quattro D-pad, UI, Reaction raw, Base/Wisdom/Valor e prova Critical senza T-pose o crash. La mancata prova Y durante Reaction resta documentata, ma non blocca più M-03 perché la grammatica approvata usa Quadrato e lascia Y interamente nativo.

Objective:
Stabilire come KH2 assegna A, Y e R2 e quali stati combat possiamo osservare senza modificare il gioco.

Scope:
- Preparare una matrice di prove per neutrale, combo, aria, Reaction disponibile, menu e una Drive Form.
- Osservare input edge, player/Form, action o motion corrente, ground/air, weapon state e Reaction quando tecnicamente accessibili.

Expected artifacts:
- `docs/SoraCombat_InputOwnership.md` con matrice e risultati.
- Un probe read-only dedicato in `diagnostics/` oppure estensione isolata di un probe esistente.
- Checklist gameplay ripetibile con save e area di prova annotate.

Dependencies:
- Clone OpenKH canonica, KH2 Lua Library 2.1 e feedback dal gioco reale.

Validation:
- Controllo statico Lua; F1 senza write; log distinti per A, Y e R2 con Reaction assente e presente.
- Statico completato il 2026-08-25: manifest YAML valido e tutti gli smoke test della repository passano con Fengari.
- Acquisizioni del 2026-08-26: A=`0x08000004`, Y=`0x02000400`; quattro cicli R2-only identificano `Input+0x04` come `0x09` held e `0x00` released senza modificare raw32.
- Acquisizioni successive: quattro D-pad distinti con R2 stabile, menu `OpenMenu=0x0A`, Wisdom/Valor e input aerei; conferma utente su Critical senza T-pose/crash. La matrice completa non è stata ripetuta alla lettera e la deviazione è documentata.

Completion criteria:
- Ownership e priorità di A/Y/R2 sono documentate; il probe riproduce gli stessi eventi in due sessioni e non modifica memoria.

Risks:
- Action/motion o input edge potrebbero non essere esposti direttamente e richiedere ricerca su strutture native.

### M-02: Mappa native Base e carrier candidati

Status: completed

Current gate:
Completata il 2026-08-26 come mappa strutturale read-only. Base, Anti e Final hanno catene PTYA → MSET/ANB → motion → ATKP complete; Roxas Dual è stato classificato nativo-only/incompatibile come trapianto diretto per il mismatch 229/228 ossa e `WeaponJoint 14/1`. Final è il ponte dual Sora primario, Master il backup air; la prova meccanica e visuale resta correttamente in M-04.

Objective:
Tracciare i moveset necessari dalla selezione dell'azione fino a motion, hit properties e stato arma.

Scope:
- Mappare catene ground/air e finisher di Sora Base.
- Confrontare Roxas Dual-Wield, Anti e almeno un carrier dual Sora tra Valor, Master o Final.
- Classificare ogni azione come nativa al carrier, portabile con asset verificati o incompatibile.

Expected artifacts:
- `docs/SoraCombat_MovesetMap.md` con pipeline PTYA → motion → MSET/ANB → ATKP, ground/air, weapon e cancel/recovery.
- Elenco motivato dei carrier Dual e Feral candidati.

Dependencies:
- M-01 completata e strumenti OpenKH per ispezionare i dati nativi.

Validation:
- Incrocio fra dati estratti, MSET presenti e log runtime; nessuna assegnazione basata soltanto sul nome dell'ability.
- Estrazione retail per nome con manifest SHA-256; analyzer Python completato su 8 carrier, 118 record PTYA, 78 hitbox esplicite e 2 MSET arma Roxas.
- Bone count motion/modello verificato per ogni action selezionata; nessuna write memoria o modifica asset introdotta.
- `docs/SoraCombat_MovesetMap.md` documenta catene rappresentative, dipendenze weapon/VFX, ambiguità ATKP e limiti della sola prova strutturale.

Completion criteria:
- Base e ogni carrier candidato hanno dipendenze, lacune e almeno una catena d'attacco verificata end-to-end.
- Criterio raggiunto per Base, Anti, Final e confronto Master; Roxas Dual è respinto come candidato diretto con catena nativa e lacuna hit-path esplicitamente tracciate.

Risks:
- Mapping incompleto di VFX o hitbox può far sembrare portabile un attacco che non lo è.

### M-03: Vertical slice A/Quadrato della stance Normal

Status: in_progress

Current gate:
Il proof record 31 ha validato soltanto Square standalone. V1/V2/V3/V5 sono respinte. M-03C ha chiuso il bucket A300 LATE a `2 accepted / 2 rejected`; M-03D ha escluso target e sei campi correlati. Il gate corrente M-03E è ordinare temporalmente il bit 25 di `PLAYER+0x120` su A300/A301/A302, senza write speculative.

Objective:
Provare la grammatica A/Quadrato sul carrier Base senza coinvolgere ancora Dual, Feral o Drive Cancel.

Scope:
- Conservare la catena A nativa.
- Sacrificare temporaneamente la parata ground mantenendo Guard equipaggiata come carrier di Quadrato e cambiando soltanto record 31 A322→A319.
- Usare uno stato virtuale `preA 1..4 / square 0..N / postA 0..4`; ogni contatore avanza solo dopo una nuova motion Base confermata.
- Preparare i MotionId PTYA 31/32/34 fra target Base whitelisted mantenendo l'identità nativa dei record 32/34.
- Conservare i gate vanilla sui record 32/34 mentre M-03E traccia read-only il bit evento candidato dal frame precedente; un Quadrato non osservato non avanza lo stato.
- Conservare Finishing Leap e gli altri Quadrati aggiuntivi come continuazioni native, oltre a Counterguard e Retaliating Slash.
- Lasciare Y/Triangolo interamente nativo e non scrivere il campo input da Lua.

Expected artifacts:
- PTYA Base derivata dal retail con manifest delle sole differenze e tabella source/destination dei record.
- Router runtime con lookup BAR/PTYA strutturale, whitelist pre-write, readback/rollback e reset deterministico.
- Evidenza conclusiva V5 (`SQUARE_RESULT REJECTED`) e recupero one-shot dell'identità nativa dopo F1.
- `ActionProbe` read-only con rolling snapshot `ReadArray`, bucket esatti, `M03D SAMPLE` per A300/A301/A302 e traccia compatta `M03E START/BIT25/EXIT`; nessun campo candidato viene scritto in questa fase.
- Evidenza conclusiva dei tentativi targetless V1/V2/V3, incluso rollback da 68 byte e hijack del carrier prioritario; sorgente sperimentale conservato ma non caricato.
- Matrice dell'albero `A^n □^m A^k` con un ruolo per ogni nodo utile ground/air e assegnazioni tratte soltanto dal carrier Base.
- Test statici e checklist gameplay per quattro prefissi A, secondo/terzo Quadrato, continuazioni A, reset e priorita native.

Dependencies:
- M-02 completata per le azioni Base selezionate.

Validation:
- Senza bersaglio A319 parte da neutrale. M-03C ha chiuso `2/2`; M-03D ha ristretto il candidato al bit 25 di `PLAYER+0x120` e l'analisi statica ne prova set/test/clear nel percorso evento. M-03E deve provarne il timing prima di estendere i percorsi 32/34. Reaction e interazioni non vengono rubate e non compaiono T-pose.

Completion criteria:
- L'albero Base concordato funziona dopo hit, dopo F1 e dopo reload/cambio area; prefisso A, Quadrati, suffisso A e reset risultano distinti nei log e nel gameplay.

Risks:
- Gli edge campionati e le differenze di memoria non provano causalità: A e Quadrato avanzano il percorso soltanto quando compare una motion whitelisted coerente. Carrier 0/1 e varianti V1/V2/V3/V5 restano vietati.

### M-04: Proof-of-concept dei carrier Dual e Feral

Status: pending

Objective:
Dimostrare o falsificare la possibilità di mantenere Sora base-looking usando carrier tecnici compatibili.

Scope:
- Dual: idle, movimento, primo attacco Roxas, due Keyblade, hitbox/danno e ritorno sicuro.
- Feral: idle/movimento, primo attacco Anti, weapon hide, hitbox/danno e ritorno sicuro.
- Separare prima la prova meccanica dalla variante visiva base-looking.

Expected artifacts:
- Due build sperimentali minime e reversibili oppure un rapporto di incompatibilità con alternativa scelta.
- Registro completo di source/target per ogni asset importato.

Dependencies:
- M-02 completata; backup vanilla e ultima build funzionante disponibili.

Validation:
- Prova gameplay di entrata, attacco, atterraggio/neutralizzazione e uscita senza T-pose, armi errate o crash.

Completion criteria:
- Ogni stance ha un carrier validato oppure è stata rifiutata con evidenza e sostituita da una direzione approvata.

Risks:
- Skeleton, weapon bone o transizioni possono richiedere una variante modello dedicata anziché il modello Base diretto.

### M-05: Palette R2 e state machine delle tre stance

Status: pending

Objective:
Rendere selezionabili Normal, Dual e Feral senza corrompere lo stato del player.

Scope:
- Mappare tre direzioni R2, feedback dello stile attivo e persistenza della selezione.
- Consentire switch inizialmente solo da neutrale o finestre esplicitamente autorizzate.
- Ripristinare in modo deterministico modello, armi e profilo dopo ogni cambio.

Expected artifacts:
- State machine Style con guardie di ownership e test delle transizioni ammesse/vietate.
- Mapping controller documentato.

Dependencies:
- M-03 e M-04 completate.

Validation:
- Cicli ripetuti Normal → Dual → Feral → Normal, dopo F1 e cambio area, senza stato arma o Form residuo.

Completion criteria:
- Le tre stance sono selezionabili e recuperano sempre uno stato valido; input nativi prioritari restano invariati.

Risks:
- Uno switch durante recovery, aria o Reaction può lasciare action e carrier disallineati.

### M-06: Drive Cancel verticale verso una Form reale

Status: pending

Objective:
Integrare una prima trasformazione nativa come continuazione offensiva senza trasformarla in una stance falsa.

Scope:
- Usare Valor come primo target salvo evidenza contraria dalla mappa.
- Definire Form armata, costo Drive, cancel window dopo Y e ritorno alla stance precedente.
- Preservare transizione, modello, moveset, armi e durata nativi della Form.

Expected artifacts:
- Un Drive Cancel funzionante e relativo contratto di stato/risorsa.
- Test per gauge insufficiente, target non valido, morte, cambio area e revert.

Dependencies:
- M-05 completata e transizione della Form scelta verificata.

Validation:
- Stance → ramo Y → Drive Cancel → Form reale → revert alla stance precedente in prove ripetute.

Completion criteria:
- Il flusso completo è stabile, consuma la risorsa prevista e fallisce chiuso fuori dalle cancel window.

Risks:
- Il rebuild di `Slot1` durante la trasformazione può invalidare puntatori o stato del router.

### M-07: Profili A/Quadrato completi e integrazione delle Form

Status: pending

Objective:
Estendere la grammatica a terra e in aria a Normal, Dual, Feral e alle cinque Drive Form normali.

Scope:
- Assegnare ruoli distinti a ogni profilo senza renderne uno universalmente superiore.
- Completare rami ground/air, launcher, inseguimenti, crowd control e finisher.
- Mantenere Anti nativa separata dalla stance Feral controllata.

Expected artifacts:
- Matrice finale input/fase/profilo e relative action native.
- Test per ogni profilo e transizione fra terra, aria e Drive.

Dependencies:
- M-06 completata; mosse restanti mappate con lo standard M-02.

Validation:
- Ogni ramo esegue l'azione prevista, conserva targeting/hitbox/VFX e rispetta le ownership native.

Completion criteria:
- Tutti i profili pianificati hanno catene ground/air verificabili e nessun ramo silenzioso o incompatibile.

Risks:
- Troppi rami o ruoli sovrapposti possono ridurre leggibilità e valore della stance Normal.

### M-08: Tuning Musou, regressioni e release

Status: pending

Objective:
Bilanciare danno, controllo e cancellazioni e rendere il sistema distribuibile.

Scope:
- Regolare ATKP, revenge, stagger, knockback, launcher, recovery e costo Drive.
- Testare boss, mob, Reaction, magia, Limit, death/reload, cambio mondo e conflitti con i moduli esistenti.
- Aggiornare documentazione, smoke test e manifest finale.

Expected artifacts:
- Parametri bilanciati, matrice regressioni, build candidata e note di utilizzo.

Dependencies:
- M-07 completata.

Validation:
- Static check, smoke test, Build/hash live e sessioni gameplay rappresentative senza crash o softlock.

Completion criteria:
- Tutte le regressioni critiche passano e il gameplay conferma profondità A/Quadrato, identità delle stance e Drive Cancel stabile.

Risks:
- Tuning prematuro può mascherare errori di ownership; modificare ATKP soltanto dopo la stabilità funzionale.
