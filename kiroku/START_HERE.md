# Da qui

## Missione

- Trasformare il combat di Kingdom Hearts II Final Mix in un sistema fluido e orientato alle combo Musou.
- Il focus attivo è Sora; Roxas è una baseline conclusa e archiviata.

## Stato corrente

- Working copy canonica: `C:\Users\jok\Documents\KH_mod\openkh\mods\kh2\Jok98\KH2-JokCombat`; contiene tutto il delta Sora e Kiroku, mentre la vecchia repository ChatGPT è pulita.
- OpenKH installa un MSET Roxas, tre moduli runtime e due probe diagnostici tramite `mod.yml`.
- Roxas Dual-Wield, Oathkeeper + Oblivion, Combo Master e le motion importate sono la baseline chiusa.
- `KH2JokCombat_Movement.lua` assegna a Sora le cinque growth MAX usando gli slot nativi `Save+0x25CE`–`Save+0x25D6`.
- `KH2JokCombat_ComboMaster.lua` è ora il Sora Combo Core: garantisce ed equipaggia Combo Master x1, Combo Plus x2 e Air Combo Plus x2.
- Il log corrente conferma Growth MAX e nucleo combo `1 + 2 + 2`; la T-pose rimane nel costume KH1 perché sette slot Growth del suo MSET vanilla sono `DUMM`.
- `P_EX100_KH1F_JokCombat.mset` riempie soltanto quei sette slot con ANB vanilla; manifest e documentazione sono pronti, manca Build/riavvio e test gameplay.

## Prossima azione

- Eseguire Build dalla clone OpenKH canonica, verificare l'asset live e riavviare il gioco: F1 non ricarica MSET.
- Provare Square neutro/con direzione, secondo salto e Glide nel costume KH1; ripetere nel costume KH2 prima di iniziare il moveset Sora.

## Vincoli rigidi

- Non riaprire il workstream Roxas salvo regressione esplicita.
- Preferire PTYA, MSET, ANB e ATKP nativi alla ricostruzione Lua del combat.
- Ogni write deve verificare identità, valore precedente e valore scritto; valori estranei devono fallire chiusi.
- Il flag `Save+0x1CEA & 0x01` separa Sora da Roxas per le scritture legate al personaggio.
- Growth e support ability risiedono nella save RAM e diventano persistenti se la partita viene salvata.
- `openkh/mod/kh2` è output generato: il Build successivo sovrascrive ogni copia manuale.
- Non dichiarare validato il gameplay senza feedback o log prodotti dal gioco.

## Leggi solo se serve

- `STATE.md` per stato e domande aperte.
- `ARCHITECTURE.md` prima di cambiare runtime, asset o integrazione OpenKH.
- `DECISIONS.md` e `CONSTRAINTS.md` prima di cambiare direzione o ownership.
- `WORK.md` per attività e condizioni di completamento.
- `RISKS.md` prima delle write/deployment e `IDEAS.md` per direzioni future o scartate.
