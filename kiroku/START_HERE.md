# Da qui

## Missione

- Trasformare il combat di Kingdom Hearts II Final Mix in un sistema fluido e orientato alle combo Musou.
- Il focus attivo è Sora; Roxas è una baseline conclusa e archiviata.

## Stato corrente

- Working copy canonica: `C:\Users\jok\Documents\KH_mod\openkh\mods\kh2\Jok98\KH2-JokCombat`; contiene tutto il delta Sora e Kiroku, mentre la vecchia repository ChatGPT è pulita.
- OpenKH installa il solo MSET Roxas, tre moduli runtime e due probe diagnostici tramite `mod.yml`.
- Roxas Dual-Wield, Oathkeeper + Oblivion, Combo Master e le motion importate sono la baseline chiusa.
- `KH2JokCombat_Movement.lua` mantiene le cinque growth a MAX negli slot nativi `Save+0x25CE`–`Save+0x25D6`: nel costume KH1 equipaggia solo High Jump; dopo lo sblocco vanilla di Valor equipaggia anche le altre quattro.
- `KH2JokCombat_ComboMaster.lua` è ora il Sora Combo Core: garantisce ed equipaggia Combo Master x1, Combo Plus x2 e Air Combo Plus x2.
- Il test gameplay ha confermato che importare sette ANB da `P_EX100.mset` nel MSET KH1 non risolve la T-pose su Square e secondo salto; l'esperimento è stato rimosso dal pacchetto.
- Il Sora Combo Core resta indipendente e garantisce Combo Master x1, Combo Plus x2 e Air Combo Plus x2 equipaggiati.

## Prossima azione

- Eseguire Build dalla clone OpenKH canonica e riavviare il gioco, così il vecchio override MSET esce anche dalla build live.
- Con il costume KH1 verificare nel menu High Jump equipaggiato e le altre quattro growth presenti ma disabilitate; poi provare Square, salto e combo.

## Vincoli rigidi

- Non riaprire il workstream Roxas salvo regressione esplicita.
- Preferire PTYA, MSET, ANB e ATKP nativi alla ricostruzione Lua del combat.
- Ogni write deve verificare identità, valore precedente e valore scritto; valori estranei devono fallire chiusi.
- Il flag `Save+0x1CEA & 0x01` separa Sora da Roxas per le scritture legate al personaggio.
- Livelli e stato equipaggiato di growth/support ability risiedono nella save RAM e diventano persistenti se la partita viene salvata.
- `openkh/mod/kh2` è output generato: il Build successivo sovrascrive ogni copia manuale.
- Non dichiarare validato il gameplay senza feedback o log prodotti dal gioco.

## Leggi solo se serve

- `STATE.md` per stato e domande aperte.
- `ARCHITECTURE.md` prima di cambiare runtime, asset o integrazione OpenKH.
- `DECISIONS.md` e `CONSTRAINTS.md` prima di cambiare direzione o ownership.
- `WORK.md` per attività e condizioni di completamento.
- `RISKS.md` prima delle write/deployment e `IDEAS.md` per direzioni future o scartate.
