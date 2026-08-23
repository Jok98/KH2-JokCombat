# Stato

## Scopo del progetto

KH2-JokCombat è un overhaul native-first del combat di Kingdom Hearts II Final Mix con chaining semplice, branching leggibile e feeling Musou. Il lavoro attivo riguarda Sora.

## Stato corrente

- Roxas è concluso per scope e resta come baseline tecnica recuperabile dalla cronologia Git.
- Nel costume KH1 il profilo sicuro mantiene tutte le growth a livello MAX ma equipaggia soltanto High Jump; Quick Run, Dodge Roll, Aerial Dodge e Glide restano nella lista disabilitate.
- `Save+0x36C0 & 0x02` (possesso di Valor) è il proxy persistente dell'evento vanilla che assegna i vestiti KH2; quando il bit compare, il runtime equipaggia automaticamente tutte e cinque le growth MAX.
- Il Sora Combo Core resta attivo e indipendente con Combo Master x1, Combo Plus x2 e Air Combo Plus x2 equipaggiati.
- Il test gameplay ha confermato T-pose su Square e secondo salto anche con sette motion standard importate nel MSET KH1; override, asset e manifest entry sono stati rimossi.
- La clone Git OpenKH è la working copy canonica; la repository ChatGPT non è più una sorgente attiva.

## Verificato di recente

- KH2 Lua Library 2.1 documenta `Save+0x36C0` come `ItemSet1` e il bit `0x02` come Valor Form.
- Gli slot growth sono `0x25CE`, `0x25D0`, `0x25D2`, `0x25D4`, `0x25D6`; i livelli MAX non equipaggiati sono rispettivamente `0x0061`, `0x0065`, `0x0237`, `0x0069`, `0x006D`.
- `Save+0x1CEA` bit 0 separa Sora da Roxas per le write runtime.
- Il log del test aveva già confermato Drive `3/3`, Gauge `100` e nucleo combo `1 + 2 + 2`; sbloccare tutte le fusioni non era necessario.
- L'MSET Roxas in pacchetto differisce dal vanilla soltanto nelle cinque entry previste `R000`, `R001`, `R002`, `R100`, `R101`.

## Domande aperte

- Dopo Build e riavvio, Square e secondo salto restano nativi senza T-pose con le quattro growth problematiche disabilitate?
- Il menu conferma High Jump equipaggiato, le altre quattro growth visibili ma disabilitate e il nucleo combo ancora equipaggiato?
- Dopo la validazione movement, quale famiglia nativa di attacchi Sora conviene mappare per prima?

## Punti da sorvegliare

- Equipaggiare manualmente una delle quattro growth durante il costume KH1 può riprodurre la T-pose.
- Il gate Valor presuppone la progressione vanilla; una mod che assegna Valor prima dei vestiti KH2 richiederebbe una guardia diversa.
- Livelli e stato equipaggiato delle ability persistono al salvataggio e possono interagire con altre mod.
- OpenKH ricompone la cartella live dalla clone installata; la rimozione del vecchio MSET richiede Build e riavvio completo.
- La sintassi Lua non dispone ancora di un test automatico locale equivalente a LuaBackend.
