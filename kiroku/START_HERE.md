# Da qui

## Missione

- Trasformare il combat di Kingdom Hearts II Final Mix in un sistema fluido e orientato alle combo Musou.
- Il focus attivo è Sora; Roxas è una baseline conclusa e archiviata.

## Stato corrente

- Working copy canonica: `C:\Users\jok\Documents\KH_mod\openkh\mods\kh2\Jok98\KH2-JokCombat`; contiene tutto il delta Sora e Kiroku, mentre la vecchia repository ChatGPT è pulita.
- `KH2JokCombat_Movement.lua` mantiene High Jump, Quick Run, Dodge Roll, Aerial Dodge e Glide equipaggiate a MAX negli slot nativi `Save+0x25CE`–`Save+0x25D6`; non rimuove più il bit ON a quattro growth dopo F1/load.
- `KH2JokCombat_ComboMaster.lua` è ora il Sora Combat Core: garantisce tutte le 25 Action Ability, ne equipaggia 19 e mantiene le sei Auto presenti ma disabilitate; Combo Master x1, Combo Plus x2 e Air Combo Plus x2 restano attivi.
- `KH2JokCombat_Forms.lua` sblocca tutte le Form, massimizza le cinque progressioni normali, garantisce innate e ricompense vanilla, porta Drive a 9/9 e mantiene gli AP live di Sora a 255; le Auto Form restano disabilitate.
- `KH2JokCombat_Keyblades.lua` garantisce le 23 Keyblade standard senza duplicazioni e inizializza gli slot vuoti Master/Final con Bond of Flame/Oblivion; slot non vuoti e Ultima restano preservati.
- `KH2JokCombat_GummiCost.lua` mantiene `Save+0x10F0A` al livello `6`, cioè Cost Limit 1200, senza modificare blocchi, missioni o Teeny Ship; valori superiori estranei vengono preservati fail-closed.
- Il test gameplay ha confermato che importare sette ANB da `P_EX100.mset` nel MSET KH1 non risolve la T-pose su Square e secondo salto; l'esperimento è stato rimosso dal pacchetto.

## Prossima azione

- Eseguire Build dalla clone OpenKH canonica e F1 in forma base Sora.
- Verificare growth MAX/ON anche dopo un secondo F1, Form/Drive/AP/Keyblade/Auto, poi nel Gummi Garage confermare `Cost Limit 1200`, salvare un progetto oltre 600 e avviare una missione.

## Vincoli rigidi

- Non riaprire il workstream Roxas salvo regressione esplicita.
- Preferire PTYA, MSET, ANB e ATKP nativi alla ricostruzione Lua del combat.
- Ogni write deve verificare identità, valore precedente e valore scritto; Gummi accetta solo livelli `0..6` e preserva fail-closed valori superiori estranei.
- Il flag `Save+0x1CEA & 0x01` separa Sora da Roxas per le scritture legate al personaggio.
- Livelli e stato equipaggiato di growth/support ability risiedono nella save RAM e diventano persistenti se la partita viene salvata.
- Movement non deve mai rimuovere silenziosamente il bit equipaggiato dalle growth; un eventuale profilo KH1 futuro richiede prima un segnale diretto e verificato del modello attivo.
- Solo gli slot Master/Final esattamente a zero ricevono i default Bond of Flame/Oblivion; ogni slot non vuoto e gli slot Sora/Valor/Wisdom/Limit restano invariati.
- Assegnare un default consuma una copia dallo stock quando presente; non duplicare una Keyblade già equipaggiata altrove senza una copia disponibile.
- Il target AP usa solo `Slot1+0x18E = 0xFF`: non altera il contatore persistente AP Boost `Save+0x24F8`.
- Auto Valor, Wisdom, Limit, Master, Final e Summon devono restare nella lista senza bit equipaggiato.
- `openkh/mod/kh2` è output generato: il Build successivo sovrascrive ogni copia manuale.
- Non dichiarare validato il gameplay senza feedback o log prodotti dal gioco.

## Leggi solo se serve

- `STATE.md` per stato e domande aperte; `ARCHITECTURE.md`, `DECISIONS.md` e `CONSTRAINTS.md` prima di cambiare runtime o direzione; `WORK.md`, `RISKS.md` e `IDEAS.md` per attività e futuro.
