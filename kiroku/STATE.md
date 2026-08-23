# Stato

## Scopo del progetto

KH2-JokCombat è un overhaul native-first del combat di Kingdom Hearts II Final Mix con chaining semplice, branching leggibile e feeling Musou. Il lavoro attivo riguarda Sora.

## Stato corrente

- Roxas è concluso per scope e resta come baseline tecnica recuperabile dalla cronologia Git.
- Nel costume KH1 il profilo sicuro mantiene tutte le growth a livello MAX ma equipaggia soltanto High Jump; Quick Run, Dodge Roll, Aerial Dodge e Glide restano nella lista disabilitate.
- Valor non è più usato come proxy del costume: tutte le Form vengono sbloccate subito, quindi Movement mantiene sempre il profilo KH1 verificato finché non esiste un segnale diretto del modello attivo.
- `KH2JokCombat_Forms.lua` sblocca Valor, Wisdom, Limit, Master, Final e Anti; porta le cinque Form livellabili a Level 7/AbilityLevel 4, garantisce le innate vanilla, assegna le ricompense FMLV a Sora e riempie la barra Drive a 9/9.
- Il Sora Combo Core resta attivo e indipendente con Combo Master x1, Combo Plus x2 e Air Combo Plus x2 equipaggiati.
- Il test gameplay ha confermato T-pose su Square e secondo salto anche con sette motion standard importate nel MSET KH1; override, asset e manifest entry sono stati rimossi.
- La clone Git OpenKH è la working copy canonica; la repository ChatGPT non è più una sorgente attiva.

## Verificato di recente

- KH2 Lua Library 2.1 documenta `Save+0x36C0` come `ItemSet1` e il bit `0x02` come Valor Form.
- Gli slot growth sono `0x25CE`, `0x25D0`, `0x25D2`, `0x25D4`, `0x25D6`; i livelli MAX non equipaggiati sono rispettivamente `0x0061`, `0x0065`, `0x0237`, `0x0069`, `0x006D`.
- `Save+0x1CEA` bit 0 separa Sora da Roxas per le write runtime.
- OpenKH conferma record Drive Form Final Mix da `0x38` byte con Level, AbilityLevel, EXP e 24 ability; `DriveForms[5]` è Summon, quindi Anti non possiede un record save da modificare.
- Il vanilla `00battle.bin/plrp` conferma gli array innate 129–133 delle cinque Form normali e la riga 134 nativa di Anti.
- Il vanilla `00battle.bin/fmlv` conferma Level 7/AbilityLevel 4 e le ricompense Auto Form, support, Combo Plus/Air Combo Plus e Form Boost usate dal runtime.
- L'MSET Roxas in pacchetto differisce dal vanilla soltanto nelle cinque entry previste `R000`, `R001`, `R002`, `R100`, `R101`.

## Domande aperte

- Dopo Build e F1, il menu Drive mostra tutte e sei le Form, barra 9/9 e le cinque progressioni a livello 7?
- Valor, Wisdom, Limit, Master, Final e Anti trasformano e rientrano correttamente durante il costume KH1?
- Square e secondo salto restano nativi senza T-pose con le quattro growth base problematiche disabilitate?
- Il probe conferma High Jump equipaggiato, le altre quattro growth base disabilitate, innate complete e ricompense standard equipaggiate?
- Dopo la validazione movement, quale famiglia nativa di attacchi Sora conviene mappare per prima?

## Punti da sorvegliare

- Equipaggiare manualmente una delle quattro growth durante il costume KH1 può riprodurre la T-pose.
- Lo sblocco anticipato delle Form nel costume KH1 non è ancora validato in gameplay; il runtime non modifica i weapon slot dei record Form.
- Le support ability ottenute dai livelli Form sono equipaggiate via save e possono superare l'AP disponibile visualizzato.
- Livelli e stato equipaggiato delle ability persistono al salvataggio e possono interagire con altre mod.
- OpenKH ricompone la cartella live dalla clone installata; la rimozione del vecchio MSET richiede Build e riavvio completo.
- La sintassi Lua non dispone ancora di un test automatico locale equivalente a LuaBackend.
