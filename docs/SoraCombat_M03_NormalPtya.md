# M-03 — grammatica A/Quadrato di Sora Base

## Contratto corrente

- A resta gestito da KH2: Lua non sintetizza input, hit-confirm, hitbox, danno
  o finisher.
- Le dodici Action Ability offensive che KH2 può scegliere automaticamente su A
  sono sbloccate ma non equipaggiate. A deve quindi restare sulla catena Base
  `A300/A301/A302` sia a vuoto sia su bersaglio.
- Y/Triangolo resta nativo per Reaction Command e interazioni.
- Quadrato neutrale usa il record PTYA 31 di Guard con la motion A319 Vicinity
  Break al posto di A322 Guard. Questo ramo targetless è confermato nel gioco;
  la parata ground non è disponibile mentre il proof è attivo.
- Dopo A, KH2 seleziona il record PTYA 32. La sua identità resta nativa
  `Selector=12 / Ability=0x12`; V5 `11/0x01` è stata respinta e ritirata.
- Il record aereo 34 resta nativo. Nessun target, flag input o stato di
  dispatcher viene scritto.

`NormalCombo` mantiene una profondità virtuale `1..4` basata soltanto su motion
Base d'attacco realmente osservate. Dieci frame di vero neutrale, menu, cambio
Form/personaggio o timeout azzerano la rotta. Questa macchina di stato prepara
la motion PTYA corretta, ma non può rendere eleggibile un'azione che la dispatch
nativa ha rifiutato.

## Prima matrice del profilo

| Profondità A | Quadrato ground | Quadrato air |
| ---: | --- | --- |
| `A□` | A310 Upper Slash | A341 Aerial Spiral |
| `AA□` | A311 Slapshot | A342 Horizontal Slash |
| `AAA□` | A318 Flash Step | A345 Aerial Dive |
| `AAAA□` e oltre | A315 Explosion | A343 Aerial Finish |

Le assegnazioni sono un profilo diagnostico, non il tuning finale. Dopo hit il
motore può già consumare i record offensivi; a vuoto il ramo ground viene
rifiutato prima che A310 inizi.

## Evidenza live accumulata

- Record 31 Guard→A319: Quadrato da neutrale avvia Vicinity Break senza target.
- Record 32 nativo: `A□` a vuoto prepara A310 ma torna idle senza avviarla.
- V1, solo `Type=3`: due prove respinte con rollback riuscito.
- V2, `Type=3 + Ability=0`: cinque prove respinte con rollback riuscito.
- V3, shadow carrier nei record 0/1: un tentativo respinto e un successivo A
  rubato da A310; esperimento escluso dal manifest.
- V5, identità Guard `11/0x01` clonata nella posizione 32: KH2 ha letto il
  record e la motion corretti, poi ha prodotto
  `SQUARE_RESULT REJECTED ... reason=RESET_IDLE`. Copiare l'identità targetless
  nel record offensivo non supera quindi il gate.
- Quattro `A□` a vuoto omogenei sono partiti da Base A300
  `0x0097/0x025C`, finestra `LATE` age 17–24, e sono stati respinti `0/4`.
- I tentativi a contatto sono stati accettati, ma A era già stata sostituita da
  Flash Step A318 `0x00A9/0x02A4` o Vicinity Break A319 `0x00AA/0x02A8`.
  Non erano quindi campioni dello stesso bucket: dimostrano che le Action
  offensive equipaggiate cambiano la dispatch nativa di A in presenza del
  bersaglio. Questa evidenza ha motivato il profilo A-base.
- Dopo F1 con il profilo A-base, il confronto omogeneo
  `A300 0x0097/0x025C LATE` ha raggiunto `2 accepted / 2 rejected`; i casi hit
  hanno avviato A310 `0x00A1/0x0284`. Sono quindi verificati A300 uniforme su
  hit/miss e il carrier A310 con la speciale OFF.
- Il confronto `PRE_EDGE` ha isolato 12 byte. Per allineamento non sono 12 flag:
  corrispondono a circa sette campi logici (`+0x123`, dword `+0x18C`, dword
  `+0x5B8`, dword `+0x900`, blocco `+0xBF8`, int32 `+0xC04`, oggetto
  incorporato `+0xC90`).
- Nei campioni M-03D i target pointer `+0x98/+0xA0` sono rimasti nulli sia nei
  casi accettati sia nei rifiutati. `+0x18C`, `+0x5B8`, `+0x900`, `+0xBF8`,
  `+0xC04` e `+0xC90` cambiano anche fra rifiuti o si sovrappongono fra i due
  esiti: non sono un permesso binario affidabile.
- `+0x123 == 0x02` è invece il bit 25 (`0x02000000`) del dword packed
  `PLAYER+0x120`. Nel confronto A300 è presente nei campioni accettati e
  assente nei rifiutati. La scansione dell'eseguibile mostra più setter, un
  consumer che testa il bit nel percorso di elaborazione dell'evento e diversi
  clear dopo il consumo. Il nome resta provvisorio: prova un flag di
  eleggibilità/evento connesso, non ancora un hit-confirm semanticamente certo.

La V5 è definitivamente ritirata. Al reload, `NormalCombo` riconosce soltanto
come residuo recuperabile l'esatta firma legacy `11/0x01` con `Type=0`, la
ripristina a `12/0x12` e non la riattiva più. Combinazioni parziali o firme
estranee fanno fallire il modulo in modo chiuso.

## Profilo ability A-base

L'analisi della PTYA Base separa due ownership diverse:

| Stato | Ability |
| --- | --- |
| ON — carrier Quadrato `Type 0` | Guard, Upper Slash, Horizontal Slash, Finishing Leap, Counterguard, Retaliating Slash |
| ON — comando | Trinity Limit |
| OFF ma presenti — speciali A `Type 1/2/3` | Slapshot, Dodge Slash, Flash Step, Slide Dash, Vicinity Break, Guard Break, Explosion, Aerial Sweep, Aerial Dive, Aerial Spiral, Aerial Finish, Magnet Burst |
| OFF ma presenti — Auto | Auto Valor, Wisdom, Limit, Master, Final e Summon |
| ON — supporti | Combo Master x1, Combo Plus x2, Air Combo Plus x2 |

Il bit equipaggiato delle dodici speciali controlla la loro selezione nativa su
A; non cancella ability o motion dal gioco. I record 32/34 conservano invece
l'ownership delle ability `Type 0` ancora ON e `NormalCombo` ne cambia soltanto
il MotionId. Il fatto che il carrier possa lanciare anche una motion la cui
speciale omonima è OFF è confermato per A310 dal bucket A300 LATE chiuso a
`2 accepted / 2 rejected`.

## Confine individuato

PTYA decide quale action/motion offrire, ma non l'intera eleggibilità della
continuazione. Il contrasto tra Vicinity Break neutrale accettata e record 32
dopo A rifiutato indica un controllo precedente all'avvio della motion:
dispatcher, stato di cancel/continuation oppure hit-confirm.

Questo spiega la differenza con KH1 JokCombat: lì la continuazione custom aveva
un punto di controllo command/action e una finestra di rilascio sicura. In KH2
le prove fatte finora modificavano dati PTYA o scrivevano input da `_OnFrame`,
dopo che l'arbitraggio utile poteva essere già avvenuto.

## M-03B/M-03C/M-03D/M-03E — Action Dispatcher Probe

M-03B ha confrontato snapshot presi sull'edge fisico di Quadrato. Il primo
campione live ha prodotto 57 differenze stabili fra Quadrato neutrale accettato
e `A□` rifiutato, ma erano già presenti motion, transform e altri effetti
successivi alla dispatch. Il confronto hit/miss seguente ha inoltre mescolato
motion di partenza diverse (`A302`, `A309`, `A310`, `A319`) e ha contato due
falsi tentativi: uno nello stesso frame di una risoluzione accettata e uno con
Upper Slash già attiva. Quei byte non sono quindi candidati causali.

M-03C mantiene `KH2JokCombat_ActionProbe.lua` completamente read-only, ma usa
quattro `ReadArray` per conservare soltanto lo snapshot del frame precedente.
Ogni `AFTER_A` viene separato per:

- motion e slot esatti prima di Quadrato;
- finestra temporale `EARLY` (0–7 frame), `MID` (8–15) o `LATE` (16+);
- esito `ACCEPTED` o `REJECTED` della motion PTYA attesa.

Solo un bucket omogeneo con almeno due campioni per esito produce
`CANDIDATES PRE_EDGE`. Un edge che risolve un trial pendente non ne crea un
secondo; Quadrato con la motion attesa già attiva viene ignorato. I cambi di
stato frame-per-frame sono sotto `TRACE`, mentre `DISPATCH` mostra soltanto
baseline, edge, risultato, bucket e candidate. Nessuna candidata autorizza una
write senza identità, semantica, rollback e prova gameplay separati.

M-03D mantiene lo stesso vincolo zero-write e aggiunge una sola riga
`M03D SAMPLE` per ogni trial A300/A301/A302 con slot nativo. La riga raggruppa
i byte come campi tipizzati, include i target pointer noti `+0x98/+0xA0` ed
espone il dword `+0x120` insieme al suo bit 25. Il test separa:

- hit con A310 accettata;
- whiff senza lock-on;
- whiff con lock-on mantenuto ma bersaglio fuori portata.

Questa matrice ha escluso i target pointer e gli altri sei campi come
discriminanti binari. Gli xref dell'eseguibile Steam hash
`9002B2DE6A1F91A790BD0673DE125D1CF833F7942BFEC827CDCF6BA64D5849ED`
mostrano che il bit 25 di `+0x120` viene impostato da handler evento/collisione,
consultato nel percorso che elabora il record corrente e poi azzerato. Questo
lo rende causalmente più forte delle altre candidate, ma non autorizza ancora
una write.

M-03E aggiunge una traccia temporale compatta: una riga `START` quando Sora
entra in A300/A301/A302, una riga `BIT25` soltanto quando il bit cambia e una
riga `EXIT` solo quando il bit era uno o cambia uscendo dalla motion Base.
L'obiettivo è stabilire se il bit nasce dopo il contatto, quanto resta vivo e
se viene consumato prima/durante la dispatch di Quadrato. La sonda non scrive
input, PTYA o stato PLAYER.

## PTYA live posseduta da NormalCombo

| Record Base | Ruolo | Campi variabili autorizzati |
| ---: | --- | --- |
| 31 | Guard / Vicinity Break targetless ground | MotionId A322↔A319 |
| 32 | Quadrato ground nativo | MotionId fra i quattro target ground |
| 33 | Finishing Leap | nessuno |
| 34 | Quadrato air nativo | MotionId fra i quattro target air |
| 35 | Counterguard | nessuno |
| 36 | Retaliating Slash | nessuno |

Prima della prima write vengono verificati BAR, PTYA, lunghezza `15172`, gruppo
Base e tutti i campi immutabili dei sei record. Ogni MotionId precedente deve
appartenere alla whitelist e ogni write viene riletta. Il fallback statico
mantiene record 31 A322, record 32 Upper Slash e record 34 Aerial Spiral.

`Combo Offset` non viene usato: nei 15 gruppi PTYA retail unici vale uno solo
per le varianti di Finishing Leap e zero altrove, quindi non è un selettore
dimostrato della profondità A.

## Prova gameplay M-03E

1. Premere F1 con gli script sincronizzati, senza salvare finché la prova non è
   conclusa.
2. Nel menu Ability verificare che i sei carrier Quadrato e Trinity siano ON,
   le dodici speciali A e le sei Auto siano OFF, e i cinque supporti combo siano
   ON.
3. Verificare le righe `[ActionProbe][DISPATCH] READ-ONLY M-03C/M-03D/M-03E`
   e `TEST M-03E`; non deve comparire `TARGETLESS COMBO PROOF ARMED`.
4. Premere una sola A a vuoto e una sola A su un nemico: entrambe devono iniziare
   da A300 `0x0097/0x025C`, non da A318/A319 o da un'altra speciale.
5. Eseguire almeno due `A□` accettati e due rifiutati, tornando idle fra i
   tentativi; includere sia contatto sia vuoto se il gioco li produce.
6. Eseguire almeno un `AA□` e un `AAA□` per coprire anche A301 e A302.
7. Copiare soltanto le righe `M03E START/BIT25/EXIT`, `RESULT` e
   `M03D SAMPLE`; `EDGE/BUCKET/CANDIDATES` servono solo in caso di anomalia.
8. Nei campioni controllare `F120=.../bit25=...`: nessun valore verrà scritto
   automaticamente, qualunque sia l'esito.
9. Segnalare immediatamente T-pose, crash, motion errata o input nativo rubato.
