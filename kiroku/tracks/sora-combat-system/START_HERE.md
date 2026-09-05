# Da qui — Combat System Sora

## Missione

- Costruire un combat Musou native-first con grammatica A/Quadrato comune e branching leggibile, lasciando Y/Triangolo nativo.
- Integrare tre stance base-looking — Normal, Dual/Roxas e Feral/Anti — più Drive Cancel verso le Form reali.

## Stato corrente

- Architettura e palette R2 sono decisioni adottate; il solo routing gameplay attivo e il proof Normal A/Quadrato, mentre R2/Dual/Feral/Drive Cancel non sono ancora implementati.
- Normal usa il carrier Base; Roxas Dual resta la sorgente meccanica nativa, Final è il ponte dual sul rig Sora e Anti il carrier Feral nativo. Le varianti base-looking restano da provare.
- Drive Cancel è un comando one-shot, non una quarta stance persistente.
- M-01 è completata con evidenza gameplay aggregata: A/Y, R2 esatto `Input+0x04 == 0x09`, quattro D-pad, UI, Base/Wisdom/Valor e assenza di T-pose/crash su Critical.
- `M-02` è completata con la mappa retail `docs/SoraCombat_MovesetMap.md`; `M-03` possiede ora una prima matrice `A/AA/AAA/AAAA + Quadrato`. A e Quadrato fisico restano nativi; il router conta un A durante la catena solo dopo una nuova motion confermata e prepara in anticipo i MotionId dei record PTYA Base 32/34. Il profilo proof usa Upper Slash/Slapshot/Flash Step/Explosion a terra e Spiral/Horizontal Slash/Aerial Dive/Aerial Finish in aria.
- V1/V2/V3/V5 targetless sono respinte. Guard→A319 funziona standalone; V5 ha preparato correttamente il record 32/A310 ma il motore è tornato idle senza avviare la motion. `NormalCombo` mantiene `12/0x12` e recupera soltanto l'esatta firma legacy `11/0x01` al reload.
- M-03C ha chiuso `A300 0x0097/0x025C LATE` a `2 accepted / 2 rejected`. M-03D ha escluso target e sei campi correlati; il solo discriminante coerente è il bit 25 del dword `PLAYER+0x120`, che il binario imposta, testa e azzera nel percorso evento. M-03E lo traccia su A300/A301/A302 senza write; solo `DISPATCH` è ON.
- Motion e ground/air live sono verificati su Steam 1.0.0.10 (`Sora* +0x180`, `+0x740/+0x744/+0x790`); action owner e weapon state live restano `UNKNOWN`.

## Prossima azione

- Dopo Build/F1, eseguire `A□`, `AA□` e `AAA□` includendo esiti accettati e rifiutati; copiare `M03E START/BIT25/EXIT`, `RESULT` e `M03D SAMPLE`. Stabilire il timing del bit 25 senza scriverlo.

## Vincoli rigidi

- Non forzare action Roxas/Anti direttamente sul record Base senza prova delle dipendenze.
- Reaction Command, menu, magie e Limit hanno priorità sul routing personalizzato.
- Preferire record nativi completi; ogni modifica deve essere minima, reversibile e fail-closed.
- Il record 31 può variare soltanto A322/A319; il record 32 mantiene l'identità Upper Slash `12/0x12`, salvo recupero one-shot della firma legacy Guard `11/0x01` a F1. Type, flags, score, input, target, dispatcher state e record aerei restano immutabili.
- Non dichiarare carrier o cancel window validati senza log e prova gameplay.
- Durante M-03 non implementare stance R2, carrier Dual/Feral o Drive Cancel; questi restano nelle milestone successive.

## Leggi solo se serve

- `ROADMAP.md` per l'ordine delle milestone; `WORK.md` per il lavoro corrente.
- `DECISIONS.md` e `RISKS.md` per semantica e fragilità; `STATE.md` per le domande aperte. Usare i file Kiroku globali solo per i vincoli condivisi.
