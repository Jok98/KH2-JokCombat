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
- Il delta non committato è stato trasferito e verificato; la repository ChatGPT resta pulita e non è più una working copy attiva.
- Trattare la cartella live come artefatto generato e verificarne gli hash dopo ogni Build.

## Decisioni sostituite o obsolete

- Il profilo KH1 conservativo permanente è sostituito dall'attivazione delle cinque growth MAX: non aveva alcun segnale di transizione e disabilitava quattro ability dopo ogni F1/load anche nel costume KH2.
- Il possesso di Valor come proxy dei vestiti KH2 è obsoleto perché Valor viene ora sbloccato intenzionalmente prima dell'evento vanilla.
- Il post-landing Roxas non è più la priorità corrente; resta documentato solo come archivio tecnico.
