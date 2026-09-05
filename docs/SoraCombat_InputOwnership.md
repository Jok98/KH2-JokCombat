# Sora Combat — input e ownership (M-01 completata)

## Esito M-01

M-01 dispone di un probe dedicato e strettamente read-only. Il probe registra il campo input raw a 32 bit, riconosce le impronte A/Y e D-pad calibrate sulla configurazione Steam reale e correla gli edge campionati con Reaction, menu/pausa, contesto mondo, player/Form, Drive e loadout Keyblade. R2 non modifica quel raw32: acquisizioni indipendenti confermano `ReadByte(kh2lib.Input+0x04) == 0x09` durante il gameplay e `0x00` dopo il rilascio, anche mentre cambia ciascuna direzione D-pad.

La chiusura usa evidenza aggregata da più reload/processi invece di due esecuzioni identiche dell'intera matrice T-01–T-09. Questa deviazione è esplicita: una pressione Y con `Reaction != 0` non è stata acquisita con la calibrazione finale, quindi il router futuro dovrà fallire chiuso e cedere sempre il controllo al nativo quando una Reaction è esposta.

Lo stato `Action`, la motion corrente, terra/aria e il weapon attachment live restano `UNKNOWN`: KH2 Lua Library 2.1 non espone al momento campi verificati per questi dati e M-01 non usa offset dedotti. I valori `LOADOUT` sono slot persistenti delle Keyblade, non prova dello stato arma live.

## Campo input verificato

Il probe legge `ReadInt(kh2lib.Input)`. L'indirizzo viene scelto dalla KH2 Lua Library per la versione PC rilevata; non viene hard-coded nel mod. La calibrazione controllata del 2026-08-26 dimostra che, con il controller/configurazione dell'utente, un pulsante fisico può occupare contemporaneamente bit bassi e alti. Le vecchie etichette PS2 low16 non vengono quindi più usate per decidere l'ownership.

| Comando JokCombat | Pulsante PS | Impronta osservata | Stato della prova |
| --- | --- | ---: | --- |
| A | Cross | raw32 `0x08000004` | Ripetuta tre volte: press e release coerenti. Il riconoscimento richiede entrambi i bit dell'impronta. |
| Y | Triangle | raw32 `0x02000400` | Ripetuta tre volte: press e release coerenti. Il riconoscimento richiede entrambi i bit dell'impronta. |
| R2 | R2 | `ReadByte(Input+0x04)`: `0x00 ↔ 0x09` | Confermato in più acquisizioni, con tap, hold, D-pad, Base, Wisdom e Valor; uguaglianza esatta e valori estranei fail-closed. |
| D-pad su | Su | raw32 `0x00004010` | Distinto mentre R2 resta `0x09`. |
| D-pad destra | Destra | raw32 `0x00008020` | Distinto mentre R2 resta `0x09`. |
| D-pad giù | Giù | raw32 `0x00010040` | Distinto mentre R2 resta `0x09`. |
| D-pad sinistra | Sinistra | raw32 `0x10000080` | Distinto mentre R2 resta `0x09`. |

Fonti tecniche primarie:

- [KH2 Lua Library](https://github.com/KH2FM-Mods-equations19/KH2-Lua-Library), per gli indirizzi version-aware inclusi `Input`, `React`, `Pause`, `Cntrl`, `BtlTyp` e `CurrentOpenMenu`.
- [KHPCSpeedrunTools — 2fmAutoAttack.lua](https://github.com/Denhonator/KHPCSpeedrunTools/blob/main/2FMMods/scripts/2fmAutoAttack.lua), come evidenza storica di `ReadShort(inputAddress) == 16384`; la calibrazione Steam corrente dimostra che questa mask non descrive il pulsante A dell'utente.
- [KH2 Soft Reset](https://github.com/KH2FM-Mods-equations19/soft-reset/blob/main/2fmSoftReset.lua), per l'uso version-aware dello stesso campo con una combinazione completa; non consente di dedurre R2 isolato.
- [KH2 Auto Save — 2fmAutosave.lua](https://github.com/KH2FM-Mods-equations19/auto-save/blob/main/2fmAutosave.lua), per l'uso version-aware di `ReadInt(kh2lib.Input)`.

## Campi osservabili

| Dato | Origine | Stato M-01 | Significato e limite |
| --- | --- | --- | --- |
| Input raw | `ReadInt(kh2lib.Input)` | verificato in gioco | `raw32`; A=`0x08000004`, Y=`0x02000400`, R2 assente in tre prove controllate. |
| Segnale R2 gameplay | `ReadByte(kh2lib.Input+0x04)` | verificato in gioco | `0x09` held e `0x00` released, stabile con tutte le direzioni D-pad. Il probe usa uguaglianza esatta e non interpreta altri valori. |
| D-pad | `ReadInt(kh2lib.Input)` | verificato in gioco | Quattro impronte raw32 esatte e indipendenti; combinazioni non note restano raw-only. |
| Press/release | differenza fra due frame del probe | derivato, non nativo | Può perdere pressioni più brevi dell'intervallo di campionamento. Nei log è sempre `PROBE_SAMPLED`. |
| Reaction | `kh2lib.React` | verificato in gioco | Osservati `0x001E`, `0x0020` e `0x0037`; manca un edge Y calibrato nello stesso contesto, quindi `Reaction != 0` resta una guardia nativa obbligatoria. |
| Pause/menu/control | `Pause`, `CurrentOpenMenu`, `Cntrl` | verificato in gioco | `OpenMenu=0xFF` in gameplay e `0x0A` nel menu provato; gli input UI cambiano rappresentazione e non autorizzano routing. |
| Battle type | `kh2lib.BtlTyp` | verificato staticamente | Campo raw; non viene interpretato oltre il valore esadecimale. |
| Sora/player/Form | `Save` e `Slot1` | verificato in gioco | Story flag, Base `0x00`, Valor `0x01`, Wisdom `0x02`, party layout e unit character ID. |
| Keyblade loadout | slot Base/Valor/Wisdom/Limit/Master/Final in `Save` | verificato staticamente | Equip persistente; non equivale all'arma live o ai bone attachment. |
| Drive | `Slot1+0x1B0..0x1B2` | già usato dal progetto | Gauge/current/max per correlare una Form reale. |
| Action corrente | — | `UNKNOWN` | Nessun indirizzo version-safe verificato. |
| Motion corrente | — | `UNKNOWN` | Nessun indirizzo version-safe verificato. |
| Terra/aria | — | `UNKNOWN` | Da mappare senza inferirlo soltanto dal salto visivo. |
| Weapon state live | — | `UNKNOWN` | Da distinguere dal loadout persistente. |

## Contratto di ownership risultante

Le etichette descrivono ciò che il probe può classificare. Non autorizzano ancora il router gameplay, ma fissano le guardie native che le milestone successive non possono aggirare:

| Input | Contesto | Etichetta del probe | Regola progettuale |
| --- | --- | --- | --- |
| A | gameplay senza UI | `NATIVE_ATTACK_BASELINE_CANDIDATE` | La catena A deve restare nativa finché una prova non mostra un conflitto. |
| Y | `Reaction != 0` | `NATIVE_REACTION_CANDIDATE` | Reaction nativa ha priorità assoluta; l'assenza del test Y correlato impone un gate fail-closed. |
| Y | pausa o menu | `NATIVE_UI_RESERVED` | Il router futuro deve restare spento. |
| Y | nessuna Reaction/UI | `UNRESOLVED_NO_REACTION` | È il solo contesto candidato per il branching, ma non è ancora autorizzato. |
| R2 | pausa o menu | `NATIVE_UI_RESERVED` | Nessuna palette stance in UI. |
| R2 | gameplay, segnale esatto `0x09` | `CALIBRATED_GAMEPLAY_INPUT_PLUS_04` | L'edge è calibrato; la futura palette resta comunque disabilitata in UI, Reaction e stati non verificati. |

`CurrentOpenMenu=0xFF` significa nessun menu aperto. I valori documentati dalla libreria (`0x01`, `0x03`, `0x05`, `0x07`, `0x08`, `0x0A`) sono invece contesti UI riservati; il primo probe classificava erroneamente `0xFF` come UI e le sue vecchie etichette `NATIVE_UI_RESERVED` non sono valide.

## Acquisizioni gameplay consolidate

Le acquisizioni del 2026-08-25 e 2026-08-26 coprono processi e reload indipendenti:

- A=`0x08000004` e Y=`0x02000400` sono ripetuti nella calibrazione controllata e nella sessione Critical finale;
- R2 produce cicli puliti `0x00↔0x09`, senza repeat durante l'hold, e resta `0x09` con ciascuna delle quattro impronte D-pad;
- Base, Wisdom `0x02` e Valor `0x01` mantengono input distinti;
- `OpenMenu=0x0A` modifica o sopprime le rappresentazioni gameplay: valori adiacenti `0x00/0x01` non vengono accettati come R2;
- Reaction `0x001E`, `0x0020` e `0x0037` sono osservabili, ma nessun log finale contiene Y calibrato nello stesso frame;
- nella sessione Critical `World=0x04 Room=0x09`, salto+A, salto+Y e salto+R2 hanno funzionato normalmente; l'utente non ha osservato T-pose, crash o altri comportamenti anomali;
- gli input `#003–#050` della stessa sessione erano pressioni A separate, non un singolo hold; nessuna conclusione sul repeat fisico di A viene quindi dedotta.

La riga `BASELINE` della sessione Critical non è inclusa nel testo copiato, ma il probe può emettere `INPUT #001` soltanto dopo aver eseguito il ramo che registra la baseline. Lo snapshot iniziale separato conferma inoltre Sora Base, `OpenMenu=0xFF` e il contesto mondo/stanza.

## Matrice M-01 consolidata

| ID | Prova | Evidenza aggregata | Esito M-01 |
| --- | --- | --- | --- |
| T-01 | tap A Base | Impronta e release ripetute in acquisizioni indipendenti | superata |
| T-02 | hold A | Non eseguita: la serie lunga era spam fisico | differita; A resta interamente nativa |
| T-03 | tap Y senza Reaction | Impronta e release ripetute con `Reaction=0` | superata |
| T-04 | Y con Reaction | Reaction non zero osservata, ma senza edge Y calibrato correlato | differita; gate nativo obbligatorio |
| T-05 | tap/hold R2 | Cicli singoli, hold stabile e release pulita | superata |
| T-06 | R2 + quattro direzioni | Quattro raw32 distinti attraverso acquisizioni indipendenti; R2 resta `0x09` | superata per calibrazione aggregata |
| T-07 | salto + A/Y/R2 | Input registrati e comportamento confermato visivamente | superata |
| T-08 | A/Y/R2 in menu | `OpenMenu=0x0A`; nessun input UI autorizza il segnale R2 gameplay | superata |
| T-09 | A/Y/R2 in Drive Form | Wisdom e Valor osservate; Valor contiene tutti e tre gli input calibrati | superata |

## Chiusura M-01 e residui

M-01 è completata per il suo obiettivo diagnostico: A, Y, R2, D-pad, UI, Reaction raw e Form sono sufficientemente osservabili per iniziare la mappa native M-02, e il probe resta senza write. La procedura originaria delle due matrici complete non è stata eseguita alla lettera; l'evidenza equivalente è stata ricostruita da più sessioni indipendenti senza dichiarare prove mancanti come riuscite.

Restano trasferiti alle milestone successive:

- M-02 deve trovare strutture version-safe per Action, motion, ground/air e weapon state live;
- M-03 lascia Y/Triangolo interamente nativo e usa Quadrato per Guardia/Action Ability; la prova Y+Reaction resta necessaria soltanto se un routing Y verrà reintrodotto in futuro. A resta nativa, incluso l'eventuale hold;
- R2 è utilizzabile soltanto con valore esatto `0x09`, `OpenMenu=0xFF`, nessuna pausa/Reaction e ulteriori guardie di stato ancora da definire;
- Limit, magia e stati non cancellabili restano ownership native finché non vengono mappati.
