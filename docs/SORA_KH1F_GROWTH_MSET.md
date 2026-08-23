# Sora KH1 costume: Growth motion import

## Scopo

Il costume iniziale di Sora usa `obj/P_EX100_KH1F.mset`. Il BAR vanilla conserva gli slot Growth, ma sette entry sono `DUMM`; equipaggiare subito Dodge Roll, Aerial Dodge, High Jump e Glide può quindi avviare un'azione senza motion e mostrare la T-pose.

`assets/obj/P_EX100_KH1F_JokCombat.mset` parte dal file vanilla KH1-costume e importa soltanto le motion mancanti dal `P_EX100.mset` vanilla della stessa versione PC.

## Provenienza

- Gioco: Steam `1.0.0.10`, archivio `Image/dt/kh2_sixth.pkg`.
- Sorgente destinazione: `obj/P_EX100_KH1F.mset`, SHA-256 `A576E868288C8D32EB35CC2BF99FF4137BFE22CE23C177A9105A9A76899FB1D7`.
- Sorgente motion: `obj/P_EX100.mset`, SHA-256 `A99E71894444E1089430D8BDF94150392D65724BA7FD9610E53947EE7DA1E62A`.
- Output: `P_EX100_KH1F_JokCombat.mset`, SHA-256 `4F50B98C6B956FC61C97F144D5ABC06EDD6B91472ACE7311AE8C497744A35EAC`.

## Delta BAR verificato

| Entry | Prima | Dopo | Sorgente |
| ---: | --- | --- | --- |
| 810 | `DUMM`, link 1 | `A160`, link 0 | `P_EX100` entry 810 |
| 814 | `DUMM`, link 1 | `A150`, link 0 | `P_EX100` entry 814 |
| 818 | `DUMM`, link 1 | `A151`, link 0 | `P_EX100` entry 818 |
| 822 | `DUMM`, link 1 | `A170`, link 0 | `P_EX100` entry 822 |
| 826 | `DUMM`, link 1 | `A171`, link 0 | `P_EX100` entry 826 |
| 830 | `DUMM`, link 1 | `A172`, link 0 | `P_EX100` entry 830 |
| 834 | `DUMM`, link 1 | `A173`, link 0 | `P_EX100` entry 834 |

Il conteggio resta 993 entry. Ogni ANB importato coincide byte-per-byte con la entry sorgente; tutte le altre 986 entry coincidono logicamente con il KH1F vanilla. `A180`, già presente per Quick Run, resta invariato e coincide già con quello di `P_EX100` (SHA-256 `6997EAA899A8D37AA8A8D97BD7D6447AE3F37EA8593720D4EF14C70AF25D54C7`).

## Validazione gameplay richiesta

Dopo OpenKH Build è necessario riavviare il gioco: F1 ricarica Lua, non il MSET del player. Con il costume KH1 verificare Square neutro, Square con direzione, secondo salto e Glide; poi ripetere dopo aver ottenuto il costume KH2 per escludere regressioni sul moveset standard.
