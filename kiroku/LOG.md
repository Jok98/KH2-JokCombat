# Registro

## Aggiornamenti

- 2026-08-23: inizializzato il hub, archiviato Roxas, preparati Movement/Combo Core e corretto il MSET KH1-costume importando sette motion Growth vanilla mancanti.
- 2026-08-23: test MSET KH1 fallito in gameplay; override rimosso e introdotto allora il profilo con solo High Jump equipaggiato, poi sostituito dopo aver verificato che non possedeva alcuna transizione outfit.
- 2026-08-23: merge precedente verificato via GitHub e `main` aggiornato; aggiunto Sora Forms con tutte le Form, innate PLRP, ricompense FMLV e Drive 9/9. Valor rimosso come proxy outfit; smoke test Forms e Movement passati.
- 2026-08-23: AP live di Sora portati a 255 e ripristinati dopo i reload, senza modificare gli AP Boost persistenti; probe e smoke test estesi.
- 2026-08-23: Combat Core esteso alle 25 Action Sora; 19 azioni operative ON, sei Auto presenti/OFF e support combo invariati, con probe e smoke test dedicati.
- 2026-08-23: aggiunto lo sblocco delle 23 Keyblade standard con Ultima Weapon esclusa, deduplica rispetto ai weapon slot Sora/Form e probe/smoke test dedicati.
- 2026-08-23: corretto Movement: il fallback KH1 non aveva alcuna transizione e disabilitava quattro growth dopo ogni F1; ora tutte e cinque convergono su MAX/ON, con regressione dedicata al reload di Quick Run e rischio KH1 esplicito.
- 2026-08-23: corretti gli slot nulli delle Form anticipate: Master riceve Bond of Flame e Final Oblivion solo da zero, con trasferimento dello stock, preservazione delle scelte manuali e regressioni anti-duplicazione.
