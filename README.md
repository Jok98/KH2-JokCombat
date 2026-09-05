# KH2 JokCombat

Prototipo di overhaul combat per Kingdom Hearts II Final Mix, basato su dati e
azioni native del gioco. Il focus attivo è Sora; Roxas resta una baseline chiusa.

Il proof Normal conserva la catena A e usa Quadrato per le diramazioni, lasciando
Y/Triangolo alle Reaction e alle interazioni native. R2, Dual, Feral e Drive Cancel
sono ancora pianificati. Il router Normal e ActionProbe richiedono Steam
1.0.0.10: il passaggio Quadrato dopo A resta in diagnosi M-03E.

## Struttura

- `mod.yml`: manifest OpenKH, asset PTYA/MSET e script da distribuire.
- `runtime/`: combat e progressione con guardie e verifiche delle scritture.
- `diagnostics/`: probe senza scritture; `DISPATCH` è il focus attivo dei log.
- `experiments/`: tentativi respinti, conservati come evidenza ed esclusi dal manifest.
- `tests/` e `tools/`: regressioni, builder e strumenti di analisi.
- [`kiroku/START_HERE.md`](kiroku/START_HERE.md): stato corrente e vincoli del progetto.

## Test locali

Requisiti: Node.js 18+, pnpm e Python 3.10+. Le dipendenze JavaScript sono
bloccate in `pnpm-lock.yaml`; i test Python usano solo la libreria standard.

```powershell
pnpm install --frozen-lockfile --ignore-scripts
pnpm test
```

Se Python non è nel PATH, impostare `PYTHON` al percorso del suo eseguibile.
Il runner accetta anche `python3` e il launcher Windows `py -3`.
Dopo l'installazione è possibile eseguire direttamente `node tools/run_tests.cjs`.

La suite controlla la sintassi dei sorgenti, esegue tutti gli smoke Lua in processi Fengari separati, i test Python,
il controllo delle sorgenti del manifest e degli hash PTYA. Non legge o modifica
un processo di gioco, salvataggi o output OpenKH. Fengari usa interi a 32 bit:
i mock non validano puntatori reali a 64 bit, dispatch, hitbox o recovery.

Le regressioni includono cambio/unload del BAR, baseline senza edge sintetici,
rollback dei trasferimenti Keyblade dopo scritture fallite o eccezioni e
preservazione di valori estranei. Se anche il rollback fallisce, il modulo
segnala gli indirizzi non ripristinati e resta disabilitato fino a F1.

## Build e prova in gioco

OpenKH deve leggere la clone installata della mod, con KH2 Lua Library versione
2 o successiva disponibile a LuaBackend. Eseguire Build in Mods Manager prima
di F1; l'output `openkh/mod/kh2` viene rigenerato e non è la sorgente da modificare.
Un cambio di asset MSET richiede anche il riavvio del gioco.

Il checkpoint corrente è descritto nel
[`track Sora`](kiroku/tracks/sora-combat-system/START_HERE.md): raccogliere
`M03E START/BIT25/EXIT`, `RESULT` e `M03D SAMPLE` su `A□`, `AA□` e `AAA□`,
con esiti accettati e rifiutati. Il bit candidato viene soltanto osservato.

Growth, ability, Form, Keyblade e Gummi alterano la progressione e persistono
salvando la partita. Il costume KH1 conserva il rischio noto di T-pose con
growth avanzate; gli esiti gameplay restano separati dai test automatici.
