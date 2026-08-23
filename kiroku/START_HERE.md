# Da qui

## Missione

- Trasformare il combat di Kingdom Hearts II Final Mix in un sistema fluido e orientato alle combo Musou.
- Il focus attivo è Sora; Roxas è una baseline conclusa e archiviata.

## Stato corrente

- Working copy canonica: `C:\Users\jok\Documents\KH_mod\openkh\mods\kh2\Jok98\KH2-JokCombat`; contiene tutto il delta Sora e Kiroku, mentre la vecchia repository ChatGPT è pulita.
- OpenKH installa il solo MSET Roxas, quattro moduli runtime e due probe diagnostici tramite `mod.yml`.
- `KH2JokCombat_Movement.lua` mantiene le cinque growth a MAX negli slot nativi `Save+0x25CE`–`Save+0x25D6`, ma equipaggia solo High Jump finché non viene verificato un segnale diretto del costume KH2.
- `KH2JokCombat_ComboMaster.lua` è ora il Sora Combo Core: garantisce ed equipaggia Combo Master x1, Combo Plus x2 e Air Combo Plus x2.
- `KH2JokCombat_Forms.lua` sblocca tutte le Form, massimizza le cinque progressioni normali, garantisce innate e ricompense vanilla, porta Drive a 9/9 e mantiene gli AP live di Sora a 255; Anti resta correttamente senza livelli.
- Il test gameplay ha confermato che importare sette ANB da `P_EX100.mset` nel MSET KH1 non risolve la T-pose su Square e secondo salto; l'esperimento è stato rimosso dal pacchetto.

## Prossima azione

- Eseguire Build dalla clone OpenKH canonica e F1 in forma base Sora.
- Nel menu verificare tutte le Form, Drive 9/9, AP 255, livelli 7, innate e ricompense; poi provare ogni trasformazione/rientro.
- Con il costume KH1 verificare High Jump equipaggiato e le altre quattro growth base presenti ma disabilitate; poi provare Square, secondo salto e combo.

## Vincoli rigidi

- Non riaprire il workstream Roxas salvo regressione esplicita.
- Preferire PTYA, MSET, ANB e ATKP nativi alla ricostruzione Lua del combat.
- Ogni write deve verificare identità, valore precedente e valore scritto; valori estranei devono fallire chiusi.
- Il flag `Save+0x1CEA & 0x01` separa Sora da Roxas per le scritture legate al personaggio.
- Livelli e stato equipaggiato di growth/support ability risiedono nella save RAM e diventano persistenti se la partita viene salvata.
- I weapon slot delle Form non vengono modificati; controllarli nel probe prima di decidere eventuali default per le Form dual-wield.
- Il target AP usa solo `Slot1+0x18E = 0xFF`: non altera il contatore persistente AP Boost `Save+0x24F8`.
- `openkh/mod/kh2` è output generato: il Build successivo sovrascrive ogni copia manuale.
- Non dichiarare validato il gameplay senza feedback o log prodotti dal gioco.

## Leggi solo se serve

- `STATE.md` per stato e domande aperte.
- `ARCHITECTURE.md` prima di cambiare runtime, asset o integrazione OpenKH.
- `DECISIONS.md` e `CONSTRAINTS.md` prima di cambiare direzione o ownership.
- `WORK.md` per attività/completamento; `RISKS.md` prima delle write/deployment; `IDEAS.md` per direzioni future.
