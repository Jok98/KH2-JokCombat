# Logging KH2 JokCombat

La configurazione unica è in `runtime/KH2JokCombat_Log.lua`. Modificare i
booleani della tabella `FLAGS`, eseguire **Build** in OpenKH e poi premere F1.

Default corrente:

| Categoria | Default | Contenuto |
| --- | --- | --- |
| `ERROR` | sempre ON | errori che disabilitano o impediscono un modulo |
| `WARNING` | sempre ON | condizioni anomale recuperabili |
| `SYSTEM` | OFF | avvio moduli, discovery PTYA/MEMT e riepiloghi |
| `COMBAT` | OFF | ramo custom realmente richiesto con Quadrato |
| `DISPATCH` | ON | probe M-03C/M-03D sul dispatcher action/command |
| `PROGRESSION` | OFF | growth, ability, Form, AP e Keyblade |
| `GUMMI` | OFF | stato del Cost Limit Gummi |
| `PROBE` | OFF | snapshot read-only e ownership input |
| `TRACE` | OFF | depth A, pending/cancel/reset e dettagli state-machine |

Esempi pratici:

- ricerca M-03C/M-03D corrente: lasciare solo `DISPATCH = true`;
- sviluppo normale combo: usare solo `COMBAT = true` e spegnere `DISPATCH`;
- diagnosi di un ramo: abilitare anche `TRACE`;
- controllo inventario/Form/growth: abilitare `PROGRESSION`;
- cattura input o memoria: abilitare `PROBE` solo per il test necessario;
- controllo inizializzazione e indirizzi: abilitare `SYSTEM`.

Quando `PROBE` è OFF, Ability, Combat, Roxas e Targetless Probe terminano già
in `_OnInit`: non producono log e non eseguono letture per-frame. I prefissi
seguono il formato `[Modulo][CATEGORIA] messaggio` per rendere filtrabile il
console log. `ActionProbe` usa invece il flag dedicato `DISPATCH`, così la sua
ricerca può restare attiva senza riaccendere gli altri quattro probe.
