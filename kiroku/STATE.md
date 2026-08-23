# Stato

## Scopo del progetto

KH2-JokCombat è un overhaul native-first del combat di Kingdom Hearts II Final Mix con chaining semplice, branching leggibile e feeling Musou. Il lavoro attivo riguarda Sora.

## Stato corrente

- Roxas è concluso per scope e resta come baseline tecnica recuperabile dalla cronologia Git.
- Movement mantiene tutte e cinque le growth a livello MAX e ON; il vecchio profilo conservativo che disabilitava Quick Run, Dodge Roll, Aerial Dodge e Glide a ogni F1/load è stato rimosso.
- Non viene inferito il costume da Valor o da flag storia non verificati. La conseguenza esplicita è che una vecchia save ancora nel costume KH1 può riprodurre la T-pose con le quattro growth avanzate attive.
- `KH2JokCombat_Forms.lua` sblocca Valor, Wisdom, Limit, Master, Final e Anti; porta le cinque Form livellabili a Level 7/AbilityLevel 4, garantisce le innate vanilla, assegna le ricompense FMLV, riempie Drive a 9/9 e mantiene Sora a 255 AP live.
- Il Sora Combat Core garantisce tutte le 25 Action Ability: 19 sono equipaggiate, Auto Valor/Wisdom/Limit/Master/Final/Summon sono presenti ma OFF; Combo Master x1, Combo Plus x2 e Air Combo Plus x2 restano equipaggiati.
- Il modulo Keyblade garantisce le 23 armi standard di Sora diverse da Ultima Weapon; una copia già nello stock o equipaggiata su Sora/Form conta come posseduta e non viene duplicata.
- Il test gameplay ha confermato T-pose su Square e secondo salto anche con sette motion standard importate nel MSET KH1; override, asset e manifest entry sono stati rimossi.
- La clone Git OpenKH è la working copy canonica; la repository ChatGPT non è più una sorgente attiva.

## Verificato di recente

- KH2 Lua Library 2.1 documenta `Save+0x36C0` come `ItemSet1` e il bit `0x02` come Valor Form.
- Gli slot growth sono `0x25CE`, `0x25D0`, `0x25D2`, `0x25D4`, `0x25D6`; i target MAX equipaggiati sono rispettivamente `0x8061`, `0x8065`, `0x8237`, `0x8069`, `0x806D`.
- `Save+0x1CEA` bit 0 separa Sora da Roxas per le write runtime.
- OpenKH conferma record Drive Form Final Mix da `0x38` byte con Level, AbilityLevel, EXP e 24 ability; `DriveForms[5]` è Summon, quindi Anti non possiede un record save da modificare.
- Il vanilla `00battle.bin/plrp` conferma gli array innate 129–133 delle cinque Form normali e la riga 134 nativa di Anti.
- Il vanilla `00battle.bin/fmlv` conferma Level 7/AbilityLevel 4 e le ricompense Auto Form, support, Combo Plus/Air Combo Plus e Form Boost usate dal runtime.
- OpenKH distingue il contatore persistente `ApBoost` dagli AP totali; il runtime KH2 usa il byte `Slot1+0x18E` per gli AP live, quindi `0xFF`/255 è il massimo rappresentabile.
- Il pool Action Final Mix verificato contiene 25 ID standard: 19 azioni operative, cinque Auto Form, Auto Summon e Trinity Limit; tutti risiedono nei 69 slot da `Save+0x2544`.
- OpenKH mappa `InventoryCount` come 320 byte da `Save+0x3580`; la lista Final Mix verificata contiene 24 Keyblade standard, quindi il target richiesto è 23 con Ultima Weapon `0x01F4`/`Save+0x368F` esclusa.
- L'MSET Roxas in pacchetto differisce dal vanilla soltanto nelle cinque entry previste `R000`, `R001`, `R002`, `R100`, `R101`.

## Domande aperte

- Dopo Build e F1, il menu Drive mostra tutte e sei le Form, barra 9/9 e le cinque progressioni a livello 7?
- Valor, Wisdom, Limit, Master, Final e Anti trasformano e rientrano correttamente durante il costume KH1?
- Nel costume KH2, Square, doppio salto, Quick Run, Dodge Roll, Aerial Dodge e Glide funzionano senza T-pose con tutte le growth ON?
- Le 19 Action equipaggiate funzionano con il costume KH1 senza animazioni mancanti, mentre le sei Auto risultano presenti ma OFF?
- Il menu equipaggiamento mostra le 23 Keyblade standard senza aggiungere Ultima Weapon o duplicare Kingdom Key/armi già assegnate alle Form?
- Il probe conferma AP live 255, tutte e cinque le growth equipaggiate, Action complete, innate complete e ricompense standard?
- Dopo la validazione movement, quale famiglia nativa di attacchi Sora conviene mappare per prima?

## Punti da sorvegliare

- Applicare Movement su una save ancora nel costume KH1 equipaggia anche le quattro growth incompatibili e può riprodurre la T-pose; non salvare quel test.
- Le Action Ability avanzate non sono ancora state provate sul MSET del costume KH1 e potrebbero esporre altre motion mancanti.
- Lo sblocco anticipato delle Form nel costume KH1 non è ancora validato in gameplay; il runtime non modifica i weapon slot dei record Form.
- Gli AP a 255 sono runtime e vengono ripristinati quando `Slot1` viene ricostruito; il contatore AP Boost della save resta invariato.
- Livelli e stato equipaggiato delle ability persistono al salvataggio e possono interagire con altre mod.
- I conteggi Keyblade aggiunti risiedono nella save e diventano persistenti se la partita viene salvata; ricompense vanilla successive possono quindi aumentare lo stock.
- OpenKH ricompone la cartella live dalla clone installata; la rimozione del vecchio MSET richiede Build e riavvio completo.
- La sintassi Lua non dispone ancora di un test automatico locale equivalente a LuaBackend.
