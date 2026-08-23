# Da qui

## Missione

- Trasformare il combat di Kingdom Hearts II Final Mix in un sistema fluido e orientato alle combo Musou.
- Il focus attivo è Sora; Roxas è una baseline conclusa e archiviata.

## Stato corrente

- Working copy canonica: `C:\Users\jok\Documents\KH_mod\openkh\mods\kh2\Jok98\KH2-JokCombat`; contiene tutto il delta Sora e Kiroku, mentre la vecchia repository ChatGPT è pulita.
- `KH2JokCombat_Movement.lua` mantiene High Jump, Quick Run, Dodge Roll, Aerial Dodge e Glide equipaggiate a MAX negli slot nativi `Save+0x25CE`–`Save+0x25D6`; non rimuove più il bit ON a quattro growth dopo F1/load.
- `KH2JokCombat_ComboMaster.lua` è ora il Sora Combat Core: garantisce tutte le 25 Action Ability, ne equipaggia 19 e mantiene le sei Auto presenti ma disabilitate; Combo Master x1, Combo Plus x2 e Air Combo Plus x2 restano attivi.
- `KH2JokCombat_Forms.lua` sblocca tutte le Form, massimizza le cinque progressioni normali, garantisce innate e ricompense vanilla, porta Drive a 9/9 e mantiene gli AP live di Sora a 255; le Auto Form restano disabilitate.
- `KH2JokCombat_Keyblades.lua` garantisce le 23 Keyblade standard di Sora senza duplicare quelle equipaggiate; Ultima Weapon e le armi debug/dummy restano escluse.
- Il test gameplay ha confermato che importare sette ANB da `P_EX100.mset` nel MSET KH1 non risolve la T-pose su Square e secondo salto; l'esperimento è stato rimosso dal pacchetto.

## Prossima azione

- Eseguire Build dalla clone OpenKH canonica e F1 in forma base Sora.
- Nel menu verificare che tutte e cinque le growth siano MAX e ON, quindi premere di nuovo F1 e controllare che Quick Run, Dodge Roll, Aerial Dodge e Glide restino ON.
- Verificare inoltre tutte le Form, Drive 9/9, AP 255, livelli 7, innate, ricompense e le 23 Keyblade standard; Ultima Weapon non deve essere aggiunta e le sei Auto devono restare OFF.

## Vincoli rigidi

- Non riaprire il workstream Roxas salvo regressione esplicita.
- Preferire PTYA, MSET, ANB e ATKP nativi alla ricostruzione Lua del combat.
- Ogni write deve verificare identità, valore precedente e valore scritto; valori estranei devono fallire chiusi.
- Il flag `Save+0x1CEA & 0x01` separa Sora da Roxas per le scritture legate al personaggio.
- Livelli e stato equipaggiato di growth/support ability risiedono nella save RAM e diventano persistenti se la partita viene salvata.
- Movement non deve mai rimuovere silenziosamente il bit equipaggiato dalle growth; un eventuale profilo KH1 futuro richiede prima un segnale diretto e verificato del modello attivo.
- I weapon slot delle Form non vengono modificati; controllarli nel probe prima di decidere eventuali default per le Form dual-wield.
- Lo sblocco Keyblade modifica solo i conteggi inventario mancanti; preserva Ultima Weapon e tutti i weapon slot Sora/Form.
- Il target AP usa solo `Slot1+0x18E = 0xFF`: non altera il contatore persistente AP Boost `Save+0x24F8`.
- Auto Valor, Wisdom, Limit, Master, Final e Summon devono restare nella lista senza bit equipaggiato.
- `openkh/mod/kh2` è output generato: il Build successivo sovrascrive ogni copia manuale.
- Non dichiarare validato il gameplay senza feedback o log prodotti dal gioco.

## Leggi solo se serve

- `STATE.md` per stato e domande aperte; `ARCHITECTURE.md`, `DECISIONS.md` e `CONSTRAINTS.md` prima di cambiare runtime o direzione; `WORK.md`, `RISKS.md` e `IDEAS.md` per attività e futuro.
