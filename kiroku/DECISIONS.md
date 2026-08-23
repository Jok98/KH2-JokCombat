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

### Decisione: Tutte le growth ability Sora a MAX

Status: active
Area: movement

Decisione:
Equipaggiare High Jump, Quick Run, Dodge Roll, Aerial Dodge e Glide al livello MAX quando il gameplay Sora è pronto.

Rationale:
È il primo incremento richiesto per rendere immediatamente completo il vocabolario di movimento di Sora.

Conseguenze:
- Le write usano gli slot growth nativi e possono diventare persistenti salvando.
- La progressione vanilla delle growth ability viene intenzionalmente superata.
- Nessuna write viene eseguita durante Roxas.

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

### Decisione: Nucleo combo completo da subito

Status: active
Area: combo

Decisione:
Garantire ed equipaggiare su Sora Combo Master x1, Combo Plus x2 e Air Combo Plus x2, cioè tutte le copie del pool support standard.

Rationale:
Il primo obiettivo combo richiede continuità anche a vuoto e la massima lunghezza nativa sia a terra sia in aria.

Conseguenze:
- Il modulo riusa la tabella abilità standard e non ricostruisce la combo in Lua.
- Le copie già presenti vengono riusate ed equipaggiate; si aggiungono solo quelle mancanti.
- La progressione vanilla di queste support ability viene intenzionalmente superata.

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

- Il post-landing Roxas non è più la priorità corrente; resta documentato solo come archivio tecnico.
