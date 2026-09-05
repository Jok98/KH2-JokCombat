# M-02 — Mappa moveset nativi e carrier Sora

## Esito

M-02 è completata come analisi strutturale read-only. La mappa non introduce routing, non scrive memoria e non modifica asset di gioco.

Le conclusioni operative sono:

- **Normal** resta sul carrier nativo `P_EX100`.
- **Dual/Roxas** deve partire da una prova meccanica sul carrier nativo `P_EX110_BTLF`: le sue motion hanno 229 ossa e non possono essere trapiantate direttamente sui carrier Sora da 228 ossa.
- **Final** è il miglior ponte dual sullo scheletro Sora: possiede famiglie native ground e air complete e condivide modello, joint arma e collisione con Base. Non rende però automaticamente compatibili le motion Roxas.
- **Master** resta un ponte secondario, soprattutto air/hover: il suo gruppo PTYA analizzato non espone una famiglia ground indipendente.
- **Feral/Anti** può usare Anti come carrier tecnico nativo: modello e motion hanno 228 ossa come Base, ma la collisione Anti è diversa e deve essere preservata.
- Nessuna variante “Sora base-looking” viene dichiarata gameplay-safe prima della prova M-04.

## Fonti e riproducibilità

L'analisi usa gli asset retail Steam 1.0.0.10 estratti per nome dai file HED/PKG tramite l'installazione OpenKH locale. `tools/extract_pc_assets.py` crea indici HED temporanei, delega decompressione e decifratura a OpenKH e registra lunghezze e SHA-256; non modifica gli archivi del gioco. `tools/analyze_movesets.py` correla i file estratti e produce un report JSON read-only.

Input principali verificati:

| Asset | SHA-256 |
| --- | --- |
| `00battle.bin` | `1968de0b23e8883a133982c755ac2a6c97fa9514a92f287f537d1eb0d8d3b200` |
| `00objentry.bin` | `bdff8d46bdb71512792c3bdf352b8c7e1ca8c9aa1ab3c481f0f50f7259ad93a5` |
| `P_EX100.mset` | `a99e71894444e1089430d8bdf94150392d65724ba7fd9610e53947ee7da1e62a` |
| `P_EX110_BTLF.mset` | `4e3690faabbe4a4b26d9e1404f0312769039e848c0500f387ca4d98701bd2dbe` |
| `P_EX100_HTLF.mset` | `4ec59b6b8525c3c922723925f4082330b221a69324dd896abe05f9e1516e7b09` |
| `P_EX100_ULTF.mset` | `21d7374a47996c0fcef907b20637da9575d02106749ea1a084c969b2e902c30f` |

Il report finale valida 8 carrier, 118 record PTYA, 78 trigger hitbox espliciti e i 2 MSET arma Roxas. Gli output di estrazione e il JSON restano temporanei perché sono riproducibili e contengono copie di asset retail; nella repository restano soltanto strumenti e risultati derivati.

## Semantica della pipeline

La pipeline osservata è:

`00objentry → NeoMoveset → gruppo PTYA → MotionId × 4 → slot MSET → ANB motion/trigger → ATKP e dipendenze weapon/VFX`

- `00objentry` fornisce modello, animation set, `WeaponJoint`, `NeoStatus` e `NeoMoveset`; il formato è documentato da [OpenKH Objentry](https://openkh.dev/kh2/file/type/00objentry.html).
- PTYA contiene selettore, flags, `Motion`, `NextMotion`, selector ability e score; ATKP contiene proprietà del colpo. Entrambi sono descritti in [OpenKH 00battle](https://openkh.dev/kh2/file/type/00battle.html).
- Per i player, `MotionId × 4` individua il gruppo di slot battle/out-of-battle e weapon/no-weapon. Il fallback fra i quattro slot e il caso tutto `DUMM` che restituisce `-1` sono documentati in [OpenKH MSET](https://openkh.dev/kh2/file/anb/mset.html). È il motivo tecnico per cui una motion assente può produrre T-pose.
- Ogni ANB è un BAR con motion type 9 e, quando presente, trigger type 16. Il layout dei trigger è documentato in [OpenKH ANB](https://openkh.dev/kh2/file/anb/anb.html); il contenitore è descritto in [OpenKH BAR](https://openkh.dev/kh2/file/type/bar.html).
- I trigger range `10` e `33` espongono un ID ATKP; `11` apre una continuazione combo; `50` una continuazione finisher; `12` gestisce il trail arma; i frame trigger `1`/`7` richiamano effetti.
- Il bone count viene letto dal payload motion secondo [OpenKH Motion](https://openkh.dev/kh2/file/anb/motion.html) e dal modello secondo [OpenKH MDLX](https://openkh.dev/kh2/file/type/mdlx.html).

Il campo PTYA chiamato qui `ability_subid` è il selettore `Item.Flag1`, non l'ID ability della save. Per Base sono stati correlati, fra gli altri, `0x5E = Explosion`, `0x5D = Guard Break`, `0x5F = Finishing Leap`, `0x61 = Aerial Sweep` e `0x64 = Aerial Finish`.

## Identità e compatibilità strutturale

| Carrier | Object | NeoStatus / NeoMoveset | WeaponJoint | Ossa | Collisioni | Esito diretto verso Base |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Sora Base `P_EX100` | 84 | 1 / 1 | 1 | 228 | 36 | nativo |
| Valor `P_EX100_BTLF` | 85 | 1 / 2 | 1 | 228 | 36 | compatibile come asset Sora, ma single-Keyblade |
| Wisdom `P_EX100_MAGF` | 86 | 1 / 3 | 1 | 228 | 36 | compatibile come asset Sora, non candidato Dual |
| Master `P_EX100_TRIF` | 87 | 1 / 4 | 1 | 228 | 36 | candidato dual secondario, air/hover |
| Final `P_EX100_ULTF` | 88 | 1 / 5 | 1 | 228 | 36 | candidato dual Sora primario |
| Anti `P_EX100_HTLF` | 89 | 1 / 6 | 1 | 228 | 34 | candidato Feral; preservare collisione Anti |
| Roxas `P_EX110` | 90 | 14 / 9 | 14 | 229 | 17 | incompatibile come swap diretto |
| Roxas Dual `P_EX110_BTLF` | 803 | 14 / 10 | 14 | 229 | 17 | incompatibile come swap diretto |

Base, Valor, Wisdom, Master, Final e Anti hanno lo stesso payload modello type 4:

`e3b31407111f20c60356590840cf264aab3400d428031b4aa80e5533bea2df9c`

Base, Valor, Wisdom, Master e Final condividono anche la stessa collisione. Anti condivide rig e modello, ma ha una collisione diversa con 34 record e gruppi d'attacco corporei: sostituirla con la collisione Base eliminerebbe una dipendenza del moveset Feral.

Roxas e Roxas Dual condividono invece un modello da 229 ossa e `WeaponJoint 14`; il loro payload modello è:

`00cf3904bad948ee4016300af7ef2b12ad7afa50591501fad1b85b38b70b5160`

La differenza 229/228 e il joint 14/1 rendono non sicuro importare `S300`, `S303`, `S332` o altre motion Roxas direttamente in `P_EX100`, Final o Master. Per ottenere davvero “attacchi Roxas con Sora” servirà mantenere il carrier Roxas oppure retargettare/rifare motion, attachment e dipendenze: un semplice rename/import ANB è rifiutato.

## Famiglie PTYA native

La classificazione usa `NextMotion = 0` come recovery ground, `NextMotion = 4` come recovery air e il flag `0x04` come famiglia finisher. I conteggi sono record PTYA; più record possono puntare alla stessa motion.

| Carrier | Ground normali | Ground finisher | Air normali | Air finisher | Motion rappresentative |
| --- | ---: | ---: | ---: | ---: | --- |
| Base | 16 | 5 | 10 | 5 | `A300–A304`, `A310–A319`, `A322`, `A330–A346` |
| Roxas Dual | 4 | 1 | 4 | 1 | `S300`, `S302`, `S303`, `S330–S332` |
| Anti | 5 | 2 | 4 | 2 | `F300–F304`, `F310–F311`, `F330–F333` |
| Final | 4 | 2 | 4 | 2 | `E300–E303`, `E330–E332` |
| Master | 0 | 0 | 12 | 4 | `D330–D334` |

Per Base, le motion standard `A300/A301/A302` sono ground normal e `A303/A304` finisher; `A330/A331` sono air normal e `A332/A333` finisher. Le Action Ability aggiungono `A310–A319`, `A322` e `A340–A346`.

Master non viene scartata in assoluto: il risultato significa soltanto che il gruppo PTYA 4 retail selezionato non offre una catena ground autonoma. Per una stance universale Final è quindi una base più completa.

## Catene rappresentative verificate

### Base — Explosion `A315`

Catena completa:

1. Object 84 seleziona `NeoMoveset 1`.
2. PTYA record 4/7 usa selector ability `0x5E` (`Explosion`), flag finisher `0x04`, `MotionId 166`, `NextMotion 0`.
3. `166 × 4 = slot 664`, risolto direttamente in `A315` senza fallback.
4. La motion è interpolata, 228 ossa, frame `0–44` a 30 fps.
5. L'ANB apre la finestra finisher `60–72`, richiama gli effect caster `44–48` e definisce tre hitbox esplicite:

| Frame | Gruppo | ATKP | Proprietà univoche |
| --- | ---: | ---: | --- |
| 32–57 | 19 | 911 | SubId 0, Pierce Armor, power 25, combo finisher |
| 57–64 | 19 | 912 | SubId 0, Pierce Armor, power 150, reaction 11, revenge 24, combo finisher |
| 32–64 | 6 | 124 | SubId 0, S-Guard |

Questa è una sorgente Base end-to-end valida per M-03. La catena normale `A300` è nativa, usa slot 604, 228 ossa e apre `allow_combo` da frame 23; il suo danno arma non è espresso da un trigger ATKP esplicito nell'ANB player, quindi M-03 deve lasciare A al motore nativo.

### Anti — ground `F302` e air `F331`

`F302` fornisce una catena Feral completa e non ambigua:

1. Object 89 seleziona PTYA 6; record 4 usa `MotionId 153`, `NextMotion 0`.
2. Anti è no-weapon: lo slot richiesto 613 è `DUMM`; il fallback nativo risolve slot 612, `F302`.
3. Motion e modello hanno entrambi 228 ossa.
4. Hitbox ATKP: 458 frame 18–27 power 50; 534 frame 40–49 power 50; 460 frame 63–73 power 100/revenge 24. Tutti gli ID hanno una sola riga semantica, SubId 0.
5. Le finestre combo sono 27–63 e 73–fine.

La catena air `F331` è anch'essa completa: slot 724, quattro hitbox univoche ATKP 549/550/551/552 e finestre combo 45–54 e 62–fine. Anti è quindi un carrier meccanico Feral valido da provare in M-04; l'aspetto Base resta separato.

### Final — ponte dual Sora `E303`

PTYA 5 usa `MotionId 154` sia come finisher ground sia come finisher air; slot 616 risolve `E303`. La motion ha 228 ossa, frame `0–280` a 120 fps e finestra finisher 96–124.

| Frame | Gruppo | ATKP | Proprietà univoche |
| --- | ---: | ---: | --- |
| 52–82 | 2 | 1456 | SubId 0, Pierce Armor, power 50, reaction 17, air-finisher |
| 112–124 | 19 | 1737 | SubId 0, Pierce Armor, power 100, reaction 11, revenge 20, air-finisher |

Final possiede inoltre `E300/E301` ground normal, `E302/E303` ground finisher, `E330/E331` air normal ed `E303/E332` air finisher. È il ponte Sora più completo, ma le sue action restano action Final, non attacchi Roxas convertiti.

### Master — confronto air `D334`

PTYA 4 usa `MotionId 184`, `NextMotion 4`; slot 736 risolve `D334`. La motion da 228 ossa espone ATKP 1100 frame 20–210, power 10, e 1101 frame 210–218, power 150/revenge 28, con finestra finisher da 238 a fine. La catena è completa, ma appartiene alla famiglia air/hover: Master resta un donor secondario.

### Roxas Dual — catena nativa e lacuna di portabilità

La selezione nativa è verificata:

- PTYA 10 record 3 → `MotionId 151` → slot 604 → `S300`, combo da frame 40.
- PTYA 10 record 1 → `MotionId 154` → slot 616 → `S303`, finisher 64–104.
- PTYA 10 record 5 → `MotionId 183`/`NextMotion 4` → slot 732 → `S332`, finisher 52–84.

Le tre motion hanno 229 ossa. Nessuna espone trigger range 10/33 nell'ANB player. Sono state quindi ispezionate anche le due armi native:

| Asset arma | Ossa | MSET | Entry non `DUMM` | Hitbox 10/33 esplicite |
| --- | ---: | ---: | ---: | ---: |
| `W_EX010_ROXAS_LIGHT` | 12 | type 0, 169 slot | 10 | 0 |
| `W_EX010_ROXAS_DARK` | 12 | type 0, 169 slot | 10 | 0 |

Gli slot arma attivi sono `0`, `152` e `161–168`; contengono motion a 12 ossa e trigger per suoni/effect caster, ma non espongono l'ATKP del colpo standard. Il payload collisione BAR delle due MDLX arma è vuoto e non usa il layout collisione personaggio.

Conclusione: l'intera catena PTYA → motion → combo/finisher → animazione arma è verificata, ma la risoluzione del danno standard resta posseduta dal carrier/engine nativo. Questo è una dipendenza, non un permesso di copiare le ANB. Roxas Dual viene classificato **nativo sul proprio carrier e incompatibile come swap diretto su Sora**.

## ATKP: regola di non-assunzione

Il parametro del trigger indica un ID ATKP, non necessariamente una singola riga. La tabella retail può contenere:

- una sola riga semantica per ID, caso marcato `unique_id`;
- più righe con lo stesso ID e SubId ma proprietà differenti, per esempio ATKP 476 cambia `EffectOnHit`;
- più SubId per lo stesso ID, per esempio ATKP 553.

Non esiste nella documentazione usata una prova che `Objentry.NeoStatus` selezioni direttamente `ATKP.SubId`. Il tool conserva quindi tutte le candidate, registra separatamente un eventuale match NeoStatus come sola osservazione e non sceglie fallback SubId 0. Le catene rappresentative dichiarate complete usano ID univoci.

## Classificazione di portabilità

| Sorgente | Classificazione M-02 | Dipendenze | Lacune residue |
| --- | --- | --- | --- |
| Base | nativa | PTYA 1, `P_EX100.mset`, arma Base, ATKP/VFX nativi | colpi standard arma spesso impliciti |
| Roxas Dual | nativa solo su `P_EX110_BTLF`; incompatibile diretta su Sora | rig 229, joint 14, due MSET arma, stato dual nativo | ATKP standard implicito; visual Sora richiede retarget/hybrid |
| Anti | portabile come carrier tecnico nativo su rig Sora | PTYA 6, collisione Anti, no-weapon fallback, ATKP corporei | texture Base e transizioni da provare in gameplay |
| Final | portabile strutturalmente come donor/carrier Sora dual | PTYA 5, stato due armi, VFX Final | non contiene attacchi Roxas; comportamento fuori Form da provare |
| Master | portabile strutturalmente come donor air | PTYA 4, hover/air state, due armi | manca una famiglia ground PTYA autonoma |
| Valor | asset compatibile ma rifiutato per Dual | rig Sora | carrier single-Keyblade |
| Wisdom | asset compatibile ma fuori obiettivo Dual | rig Sora | semantica ranged/non dual |

“Portabile strutturalmente” significa soltanto che modello e motion condividono il rig retail e che la pipeline dati è completa. Non equivale a validazione gameplay.

## Decisione carrier per M-04

Il proof-of-concept seguirà due livelli separati:

1. **Meccanica nativa**: Roxas Dual per gli attacchi Roxas; Anti per gli attacchi Feral.
2. **Aspetto Sora**: Anti + variante texture Base è il candidato Feral più diretto; per Dual, Final è il donor Sora primario e Master il backup, ma gli attacchi Roxas esatti richiedono un lavoro di retarget/hybrid ancora non dimostrato.

Non si sostituirà `P_EX100` con motion `Sxxx` alla cieca. Se il retarget Roxas fallisce, la scelta di design da riportare all'utente sarà fra Dual con mosse Final/Master su rig Sora oppure Dual Roxas meccanicamente esatto con asset visivo dedicato.

## Lacune aperte

- Il percorso hit/danno dei colpi standard Keyblade di Base/Roxas non è esplicito nei trigger ANB player o nei MSET arma ispezionati.
- La dispatch fra ID ATKP duplicati/SubId non è provata; nessun router deve assumerla.
- Gli ID APDX/VFX e sound package sono inventariati, non renderizzati né trasferiti.
- Action, motion, grounded/air e weapon state live restano da esporre con una firma version-safe; M-02 mappa i dati retail, non nuovi offset RAM.
- Base-looking Dual/Feral, entrata/uscita carrier e recovery richiedono gameplay reale in M-04.

## Gate M-03

M-03 può iniziare perché Base, Anti e il ponte Final hanno catene complete PTYA → MSET/ANB → motion → hitbox/ATKP; Roxas è stato respinto come trapianto diretto con una dipendenza concreta e Master è stato classificato come backup air.

Il vertical slice M-03 resta limitato a Normal/Base:

- A resta interamente nativa. Tutte le tecniche restano sbloccate, ma le dodici
  Action `Type 1/2/3` selezionabili automaticamente da A sono OFF; i sei carrier
  Quadrato `Type 0`, Trinity e i supporti combo restano ON. In questo modo il
  primo A deve usare Base A300 anche su bersaglio.
- Quadrato conserva la dispatch nativa. Il proof targetless ground mantiene selector/ability Guard ma sostituisce a runtime la sua motion A322 con A319 Vicinity Break; il buffer Lua provato sulle finestre `allow_combo` resta respinto perché `_OnFrame` scrive dopo la dispatch utile e KH2 non consuma i pulse.
- Y/Triangolo resta interamente nativo. M-03 prosegue con un remap PTYA/action-level Base minimo e reversibile, senza input sintetici.
- Nessuna stance R2, nessun carrier Dual/Feral e nessun Drive Cancel entrano in M-03.

Il fallback statico conserva record 31 A322 Guard, porta record 32 da 161/A310 a 166/A315 Explosion e usa A341 Aerial Spiral nel record 34. Il router M-03 risolve la PTYA caricata, cambia record 31 esclusivamente fra A322/A319 e prepara i MotionId 32/34 in base a una profondita A confermata da motion, senza sintetizzare input. Matrice, whitelist e checklist sono in `docs/SoraCombat_M03_NormalPtya.md`.
