# Stato

## Scopo del progetto

KH2-JokCombat è un overhaul native-first del combat di Kingdom Hearts II Final Mix con chaining semplice, branching leggibile e feeling Musou. Il lavoro attivo riguarda Sora.

## Stato corrente

- Roxas è concluso per scope e resta come baseline tecnica recuperabile dalla cronologia Git.
- Le cinque growth MAX e il nucleo combo `1 + 2 + 2` risultano applicati dal runtime Sora corrente; il costume KH1 mostrava T-pose su Square neutro e secondo salto.
- Il log del test mostra Sora base (`SoraFlag=1`, `Form=0`) con Drive `3/3` e Gauge `100`: la barra Drive esiste già e non spiega la T-pose.
- Il costume iniziale usa `P_EX100_KH1F.mset`: rispetto a `P_EX100`, le entry Growth 810, 814, 818, 822, 826, 830 e 834 erano `DUMM`; solo `A180` era già presente.
- `P_EX100_KH1F_JokCombat.mset` importa in quei sette slot le ANB vanilla corrispondenti e non cambia le altre 986 entry; manifest aggiornato, gameplay ancora da validare dopo Build e riavvio.
- La clone Git OpenKH è la working copy canonica e contiene tutto il delta Sora e Kiroku; la vecchia repository ChatGPT è stata ripristinata pulita.

## Verificato di recente

- Il 2026-08-23 `main` è stato aggiornato al commit `222bbf1` prima delle modifiche correnti.
- KH2 Lua Library 2.1 espone indirizzi compatibili per le versioni PC riconosciute e viene richiesta con versione minima 2.
- Garden of Assemblage usa gli slot growth `0x25CE`, `0x25D0`, `0x25D2`, `0x25D4`, `0x25D6` e gli stessi intervalli ID adottati dal progetto.
- KH2Randomizer supporta growth iniziali per Sora indipendentemente dallo sblocco delle Drive Form; OpenKH identifica `P_EX100/A180` come Quick Run.
- `Save+0x1CEA` bit 0 vale 0 per Roxas e 1 per Sora.
- Il pool support standard di Sora contiene Combo Master x1 (`0x021B`), Combo Plus x2 (`0x00A2`) e Air Combo Plus x2 (`0x00A3`).
- L'MSET modificato differisce dal vanilla in cinque entry: `R000`, `R001`, `R002`, `R100`, `R101`.
- Il nuovo MSET KH1-costume conserva 993 entry e differisce dal vanilla soltanto negli slot 810=`A160`, 814=`A150`, 818=`A151`, 822=`A170`, 826=`A171`, 830=`A172`, 834=`A173`.

## Domande aperte

- Le sette motion importate funzionano sul costume KH1 per Square neutro/con direzione, secondo salto e Glide dopo Build e riavvio?
- Il menu e Ability Probe confermano Combo Master x1, Combo Plus x2 e Air Combo Plus x2 dopo la distribuzione del vero Sora Combo Core?
- Dopo la validazione movement, quale famiglia nativa di attacchi Sora conviene mappare per prima?

## Punti da sorvegliare

- Le write growth e combo persistono al salvataggio e possono interagire con altri mod che usano gli stessi slot.
- Il modulo si riabilita dopo title/loading, ma il cambio diretto di save deve essere verificato in gioco.
- OpenKH ricompone la cartella live dalla clone installata: le copie manuali in `openkh/mod/kh2/scripts` vengono sovrascritte al Build successivo.
- La sintassi Lua non dispone ancora di un test automatico locale equivalente a LuaBackend.
