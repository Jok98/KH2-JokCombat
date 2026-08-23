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

### Decisione: Profilo movement KH1 conservativo indipendente dalle Form

Status: active
Area: movement

Decisione:
Mantenere tutte le growth base a livello MAX, equipaggiare soltanto High Jump e lasciare Quick Run, Dodge Roll, Aerial Dodge e Glide presenti nella lista ma disabilitate. Non usare il possesso di Valor come segnale del costume.

Rationale:
Il costume KH1 va in T-pose su Square e secondo salto con quelle growth attive, e anche l'import controllato delle motion standard nel suo MSET non risolve il problema. High Jump è invece sicuro.

Conseguenze:
- Le write usano gli slot growth nativi, conservano i livelli MAX e modificano soltanto il bit equipaggiato.
- Sbloccare Valor in anticipo non riattiva automaticamente le quattro growth incompatibili.
- Il giocatore può vedere le quattro growth disabilitate nel menu ma non deve equipaggiarle manualmente durante il costume KH1.
- L'attivazione automatica nel costume KH2 resta sospesa finché non viene verificato un segnale diretto del modello/outfit.
- Nessuna write viene eseguita durante Roxas.

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
- I weapon slot Form sono osservati dal probe ma non modificati.
- `DriveForms[5]` Final Mix è Summon e resta completamente intatto; le innate Anti sono già dati nativi PLRP, non stato da copiare nella save.
- Le ricompense standard condivise Combo Plus/Air Combo Plus hanno gli stessi target del Combo Core e restano idempotenti in qualunque ordine di caricamento.

### Decisione: Combat native-first

Status: active
Area: architecture

Decisione:
Usare prima PTYA, MSET, ANB e ATKP; introdurre routing Lua solo quando il dato nativo non basta.

Rationale:
Il motore nativo conserva compatibilità con animazioni, hitbox, targeting, danno e transizioni meglio di una ricostruzione parallela.

Conseguenze:
- Le patch Lua devono restare strette e verificabili.
- La grammatica combo A/Y verrà progettata dopo la mappatura delle risorse native Sora.

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

### Decisione: Combat Core completo da subito

Status: active
Area: combo

Decisione:
Garantire tutte le 25 Action Ability standard di Sora, equipaggiare le 19 azioni operative e mantenere Auto Valor, Wisdom, Limit, Master, Final e Summon presenti ma disabilitate. Conservare inoltre Combo Master x1, Combo Plus x2 e Air Combo Plus x2 equipaggiati.

Rationale:
Il focus è sperimentare subito l'intero moveset nativo di Sora; le Auto non aggiungono mosse e possono attivare Form/Limit involontariamente, mentre il nucleo combo deve mantenere continuità e lunghezza massime.

Conseguenze:
- Il modulo riusa la tabella standard da 69 slot e non ricostruisce attacchi o combo in Lua.
- Le copie già presenti vengono riusate; si aggiungono solo quelle mancanti e si verifica lo stato ON/OFF dopo ogni write.
- Il test con costume KH1 deve coprire ogni Action perché alcune motion avanzate potrebbero non essere disponibili nel relativo MSET.
- La progressione vanilla di Action e support combo viene intenzionalmente superata.

### Decisione: Clone OpenKH come working copy canonica

Status: active
Area: workflow

Decisione:
Sviluppare direttamente in `C:\Users\jok\Documents\KH_mod\openkh\mods\kh2\Jok98\KH2-JokCombat`, la repository Git letta da OpenKH Mods Manager.

Rationale:
Il Build ricompone `openkh/mod/kh2` da quella clone e sovrascrive le copie manuali, causando test di script diversi dai sorgenti analizzati.

Conseguenze:
- Il delta non committato è stato trasferito e verificato; la repository ChatGPT resta pulita e non è più una working copy attiva.
- Trattare la cartella live come artefatto generato e verificarne gli hash dopo ogni Build.

## Decisioni sostituite o obsolete

- L'attivazione immediata di tutte e cinque le growth base MAX è sostituita dal profilo KH1 conservativo dopo la T-pose confermata.
- Il possesso di Valor come proxy dei vestiti KH2 è obsoleto perché Valor viene ora sbloccato intenzionalmente prima dell'evento vanilla.
- Il post-landing Roxas non è più la priorità corrente; resta documentato solo come archivio tecnico.
