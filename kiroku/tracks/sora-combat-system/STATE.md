# Stato

## Scopo del track

Definire e realizzare il combat system di Sora: grammatica A/Quadrato, tre stance base-looking, selezione R2 e Drive Cancel, mantenendo le ownership native KH2.

## Stato corrente

- Il router ricontrolla `Btl0Pointer` prima di usare indirizzi PTYA; cambio/unload azzerano cache e input pendenti senza write nella vecchia RAM. Nuova discovery, firme e baseline sono coperte da regressioni mock, separate dalla prova gameplay.
- `M-01` e `M-02` sono completate; `M-03` è nella fase M-03E di validazione temporale read-only del bit 25 di `PLAYER+0x120`, prima di estendere l'albero Base `A^n □^m A^k`.
- A/Quadrato è la grammatica adottata: A resta nativa e Y/Triangolo resta nativo. Nel proof ground, Guard resta equipaggiata come ownership di Quadrato ma il record 31 esegue A319 Vicinity Break al posto della parata. Palette R2 e separazione fra aspetto visivo e carrier tecnico sono invariati. Nessun input combat viene sintetizzato in `_OnFrame`.
- `KH2JokCombat_NormalCombo.lua` risolve la PTYA dal `Btl0Pointer`, valida BAR/header/lunghezza/gruppo e sei record, cambia/rilegge record 31 fra A322/A319 e i MotionId 32/34 fra profili whitelisted. Il record 32 resta `12/0x12`; F1 recupera soltanto una firma V5 legacy completa. Il gameplay conferma A319 standalone; hitbox/danno non sono ancora esplicitamente validati.
- V5 ha armato record 32 con Guard `11/0x01` e A310 corretti, ma `A□` a vuoto ha prodotto `SQUARE_RESULT REJECTED ... RESET_IDLE`. M-03C conferma quattro rifiuti su quattro nel bucket Base `A300 0x0097/0x025C LATE` (age 17–24); su hit, invece, KH2 ha selezionato A318 `0x00A9/0x02A4` o A319 `0x00AA/0x02A8` e il Quadrato è stato accettato. Il confronto non era omogeneo ma identifica la selezione delle speciali A come variabile concreta.
- Il Combat Core applica il profilo A-base: tutte le Action restano presenti, i sei carrier Type 0 di Quadrato e Trinity sono ON, le dodici speciali A Type 1/2/3 e le sei Auto sono OFF, e i supporti combo restano ON. Hit e miss sono partiti da A300 nello stesso bucket LATE, chiuso a `2/2`; i due hit hanno avviato A310, confermando il carrier con speciale OFF.
- M-03D ha escluso `+0x98/+0xA0`, `+0x18C`, `+0x5B8`, `+0x900`, `+0xBF8`, `+0xC04` e `+0xC90` come permessi binari: sono nulli in entrambi gli esiti, variano fra rifiuti o si sovrappongono. Resta coerente `+0x123 == 0x02`, cioè il bit 25 del dword packed `PLAYER+0x120`. Nell'eseguibile Steam hash-verificato più handler lo impostano, il percorso di elaborazione evento lo testa e poi lo azzera. M-03E ne traccia `START/BIT25/EXIT` su A300/A301/A302 senza write; il nome semantico resta provvisorio.
- A=`0x08000004`, Quadrato=`0x04000200` e Y=`0x02000400` sono impronte raw32 verificate. R2 usa esattamente `Input+0x04 == 0x09`; D-pad usa UP=`0x00004010`, RIGHT=`0x00008020`, DOWN=`0x00010040`, LEFT=`0x10000080`. Reaction, UI, Limit, magia e stati non verificati precedono ogni routing futuro.
- M-02 ha scelto Final come ponte dual sul rig Sora e Master come backup air; gli attacchi Roxas esatti restano sul carrier nativo finché non esiste un retarget/hybrid validato. Anti è il carrier Feral nativo candidato, con collisione propria da preservare.

## Scope

- In scope: input routing, action/motion map, PTYA, MSET/ANB, ATKP, weapon state, stance state machine, Drive Cancel, tuning e regressioni combat.
- Out of scope: progressione generale, Gummi, drop, nuovi sblocchi e riapertura del gameplay Roxas; Roxas è soltanto una sorgente tecnica per Dual.

## Verificato di recente

- Steam 1.0.0.10 usa `CurrentOpenMenu=0xFF` durante gameplay senza menu; il primo probe lo classificava erroneamente come UI. La correzione usa `openMenu ~= 0xFF` e registra `ReadInt(kh2lib.Input)` separando low16/high16.
- La calibrazione controllata del 2026-08-26 ha prodotto A=`0x08000004` tre volte e Y=`0x02000400` tre volte; tre pressioni R2 non hanno modificato alcun bit raw32. Le vecchie etichette PS2 low16 sono quindi invalide per questa configurazione.
- Il log R2-only ha mostrato `Input+0x04` in `0x00→0x09` ai frame 283/468/658/763 e in `0x09→0x00` ai frame 399/595/721/781. Gli offset `+0x0C/+0x14/+0x1C`, distanziati di otto byte, sono copie ritardate/parziali e non vengono usati come stato corrente.
- Il probe legge direttamente `Input+0x04`, riconosce solo il valore esatto `0x09` e fallisce chiuso sugli altri valori. R2 resta stabile con tutti e quattro i D-pad; in UI `OpenMenu=0x0A` la rappresentazione cambia e non viene accettata come segnale gameplay.
- Le acquisizioni aggregate mostrano Base, Wisdom e Valor, Reaction raw `0x001E/0x0020/0x0037`, input in salto riusciti e nessuna T-pose/crash su Critical. Manca un edge Y calibrato mentre Reaction è non zero: M-03 deve verificarlo prima di qualsiasi branch e nel frattempo il nativo ha priorità assoluta.
- `diagnostics/KH2JokCombat_CombatProbe.lua` osserva input, edge campionati, Reaction, UI, Form/player, Drive e loadout senza alcuna write; lo smoke test copre A/Y/Quadrato, R2 diretto, hold senza repeat, le quattro impronte D-pad, valore estraneo fail-closed e re-baseline. Dopo il rollback del router la regressione canonica comprende sei smoke test.
- `docs/SoraCombat_InputOwnership.md` contiene l'evidenza consolidata M-01, la deviazione dalla matrice originaria e i gate trasferiti a M-02/M-03.
- Roxas Dual-Wield usa il player object nativo `0x0323` e il relativo MSET; il cambio completo del carrier ha già preservato due Keyblade in gameplay.
- Il semplice import di motion fra modelli non garantisce compatibilità: il precedente esperimento KH1 ha mantenuto la T-pose.
- Master e Final richiedono weapon state validi; slot nulli hanno già causato crash nel menu.
- Gli asset retail mostrano 228 ossa e lo stesso payload modello per Base/Valor/Wisdom/Master/Final/Anti; Roxas e Roxas Dual ne hanno 229, `WeaponJoint 14` invece di `1` e un payload modello diverso. Lo swap diretto delle motion `Sxxx` su Sora è quindi respinto.
- PTYA retail espone famiglie ground/air complete per Final; Master espone soltanto air/hover nel gruppo analizzato. `F302`/`F331`, `E303`, `D334` ed Explosion `A315` hanno catene esplicite fino ad ATKP.
- I due MSET arma Roxas hanno motion a 12 ossa e trigger suono/VFX, ma nessun range trigger hitbox 10/33: il danno standard Dual resta una dipendenza del carrier/engine nativo.
- Il parser non assume che `NeoStatus` selezioni `ATKP.SubId`: conserva tutte le righe candidate e usa come prove complete soltanto ID semanticamente univoci.
- Il log Mods Manager della build fallita riportava `File not found: ...\openkh\data\kh2\00battle.bin Skipping`; `patch-package-map.txt` citava l'output ma `mod/kh2/kh2_first/original/00battle.bin` non era stato generato. La cache base OpenKH è stata riparata con il retail hash-verificato; non considerare valida una nuova prova se il warning ricompare.
- Nel processo live del 2026-08-27 `Btl0Pointer` ha risolto un BAR da 20 subfile e una sola PTYA valida a `0x7FF72BE370A0`; record 32/34 contenevano gia i fallback 166/192. L'indirizzo assoluto non viene hardcodato: il runtime lo ricalcola a ogni F1/processo.
- Il confronto di tutti i 15 gruppi PTYA unici retail mostra `Combo Offset=1` soltanto sui record equivalenti a Finishing Leap e zero sugli altri; non viene trattato come selettore della profondita A.
- Il confronto live targetless/hit non espone un bit di permesso PLAYER: i soli cambiamenti ripetuti sono puntatori del bersaglio e un byte del `MaxBBOX`, quindi non vengono scritti o falsificati.

## Domande aperte

- Il bit 25 di `PLAYER+0x120` nasce dopo il contatto, resta vivo fino all'edge di Quadrato e viene consumato dalla dispatch nello stesso ordine su A300/A301/A302?
- Quali motion Base compatibili assegnare ai nodi di secondo/terzo Quadrato e alle continuazioni A, mantenendo distinguibili terra e aria?
- Quale campo version-safe espone l'action owner e il weapon state live? Motion e ground/air sono ora verificati, ma gli edge restano campionati e la prima A da neutrale e l'unico caso preparato immediatamente.
- R2 possiede già una funzione nativa da preservare e come scegliamo la Form armata?
- Il carrier Roxas nativo può ricevere un visual Sora dedicato, oppure serve retargettare le motion sul donor Final?
- Una variante texture Base sul carrier Anti preserva collisioni corporee, weapon-hide e transizioni senza regressioni?

## Punti da sorvegliare

- Non confondere compatibilità dell'animazione con correttezza di hitbox, VFX, danno e weapon attachment.
- Gli switch non devono interrompere Reaction, Limit, magia, menu o stati non cancellabili.
- Normal deve conservare un ruolo utile rispetto a Dual e Feral.
- M-03 non introduce Dual/Feral/R2: A, Quadrato fisico e Y restano nativi; oltre ai MotionId PTYA Base 31/32/34 non esiste ownership aggiuntiva. La firma Guard32 legacy è solo recuperabile, mai armata.
