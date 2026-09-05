# Da qui

## Missione

- Trasformare il combat di KH2 Final Mix in un sistema fluido e Musou, con Sora come focus e Roxas archiviato come baseline.

## Stato corrente

- Working copy canonica: `C:\Users\jok\Documents\KH_mod\openkh\mods\kh2\Jok98\KH2-JokCombat`; eventuali staging esterni non sono sorgenti per OpenKH.
- `KH2JokCombat_Movement.lua` mantiene High Jump, Quick Run, Dodge Roll, Aerial Dodge e Glide equipaggiate a MAX negli slot nativi `Save+0x25CE`–`Save+0x25D6`; non rimuove più il bit ON a quattro growth dopo F1/load.
- `KH2JokCombat_ComboMaster.lua` è il Sora Combat Core: garantisce tutte le 25 Action Ability, mantiene ON i sei carrier Type 0 di Quadrato e Trinity, lascia presenti ma OFF le dodici speciali A Type 1/2/3 e le sei Auto; Combo Master x1, Combo Plus x2 e Air Combo Plus x2 restano attivi.
- `KH2JokCombat_Forms.lua` sblocca tutte le Form, massimizza le cinque progressioni normali, garantisce innate e ricompense vanilla, porta Drive a 9/9 e mantiene gli AP live di Sora a 255; due Lucky Lucky equipaggiate impostano il drop item base a 200% e le Auto Form restano disabilitate.
- `KH2JokCombat_Keyblades.lua` garantisce le 23 Keyblade standard senza duplicazioni e inizializza gli slot vuoti Master/Final con Bond of Flame/Oblivion; slot non vuoti e Ultima restano preservati.
- `KH2JokCombat_GummiCost.lua` mantiene `Save+0x10F0A` al livello `6`, cioè Cost Limit 1200, senza modificare blocchi, missioni o Teeny Ship; valori superiori estranei vengono preservati fail-closed.
- Il test gameplay ha confermato che importare sette ANB da `P_EX100.mset` nel MSET KH1 non risolve la T-pose su Square e secondo salto; l'esperimento è stato rimosso dal pacchetto.
- Il combat usa A/Quadrato come grammatica comune e lascia Y/Triangolo nativo. Guard→A319 funziona da neutrale; dopo A, KH2 seleziona il record 32 ma lo rifiuta a vuoto prima della motion. V5 Guard32 è stata respinta live e ritirata: F1 recupera soltanto un residuo legacy `11/0x01`, poi mantiene l'identità nativa `12/0x12`. Roxas non è trapiantabile direttamente sul rig Sora 229/228; Final è il ponte dual Sora e Anti il carrier Feral nativo.
- M-03C ha chiuso `A300 0x0097/0x025C LATE` a `2 accepted / 2 rejected`. M-03D ha escluso target e sei campi correlati; il solo candidato coerente è il bit 25 del dword `PLAYER+0x120`, che il binario imposta, testa e azzera nel percorso evento. M-03E lo traccia read-only su A300/A301/A302; solo `DISPATCH` resta ON.

## Prossima azione

- Dopo Build/F1, eseguire `A□`, `AA□` e `AAA□` con esiti accettati e rifiutati; copiare `M03E START/BIT25/EXIT`, `RESULT` e `M03D SAMPLE` per stabilire il timing del bit senza scriverlo.

## Vincoli rigidi

- Non riaprire il workstream Roxas salvo regressione esplicita.
- Preferire PTYA, MSET, ANB e ATKP nativi alla ricostruzione Lua del combat.
- Ogni write deve verificare identità, valore precedente e valore scritto; Gummi accetta solo livelli `0..6` e preserva fail-closed valori superiori estranei.
- Il flag `Save+0x1CEA & 0x01` separa Sora da Roxas per le scritture legate al personaggio.
- Livelli e stato equipaggiato di growth/support ability risiedono nella save RAM e diventano persistenti se la partita viene salvata.
- Movement non deve mai rimuovere silenziosamente il bit equipaggiato dalle growth; un eventuale profilo KH1 futuro richiede prima un segnale diretto e verificato del modello attivo.
- Solo gli slot Master/Final a zero ricevono Bond of Flame/Oblivion consumando lo stock quando presente; preservare gli altri slot e non duplicare armi già equipaggiate senza una copia disponibile.
- Il target AP usa solo `Slot1+0x18E = 0xFF`: non altera il contatore persistente AP Boost `Save+0x24F8`.
- Auto Valor/Wisdom/Limit/Master/Final/Summon e le dodici speciali A devono restare nella lista ma OFF; i sei carrier Quadrato Type 0 e Trinity devono restare ON.
- `openkh/mod/kh2` è output generato: il Build successivo sovrascrive ogni copia manuale.
- I nuovi log devono passare da `KH2JokCombat_Log.lua` e non rendere silenziabili `ERROR/WARNING`; il proof può cambiare record 31 soltanto fra A322/A319 e il MotionId dei record 32/34 dentro le whitelist. L'identità record 32 deve restare nativa `12/0x12`; `11/0x01` è accettata solo per recuperare un residuo V5 a F1. Type, flags, score, input, target, dispatcher e Reaction restano fuori ownership.
- Non dichiarare validato il gameplay senza feedback o log prodotti dal gioco.

## Leggi solo se serve

- `TRACKS.md` instrada il combat Sora; `STATE.md` per lo stato globale; `ARCHITECTURE.md`, `DECISIONS.md` e `CONSTRAINTS.md` prima di cambiare runtime o direzione.
