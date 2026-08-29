# Ladění výkonu

## Každá hra potřebuje jinou rychlost CPU

Tohle je nejdůležitější poznatek celého projektu:

| hra | cyklů | proč |
|---|---|---|
| Magic Carpet 1 / Hidden Worlds | **100000** | rychlost hry je svázaná s výkonem CPU |
| Magic Carpet 2 | **max** | na rychlosti CPU nezávislý |

Magic Carpet z roku 1994 váže tempo hry přímo na počet cyklů. Při `max` na
moderním procesoru běží nehratelně rychle. Dvojka z roku 1995 to už má
ošetřené a v SVGA si vezme, co dostane.

Hodnoty jsou v `play.sh` jako `MCP_CYCLES` a `MC2_CYCLES`. Skript je vždy
předává DOSBoxu přes `-set`, takže hodnota v `.conf` je jen fallback pro ruční
`dosbox -conf ...`.

## Orientační tabulka

Z dokumentace dosbox-staging:

```
8088 (4.77 MHz)     300      486DX/2-66        25000
286-8               700      Pentium 90        50000
286-12             1500      Pentium MMX-166  100000
386SX-20           3000      Pentium II 300   200000
386DX-33           6000
386DX-40           8000
486DX-33          12000
```

GOG dodává konfiguraci s `cycles=auto`, což u obou her skončí na 60000
(≈ Pentium 90). To byl u dvojky ve vyšším rozlišení přesně ten pocit
„slabého počítače".

## Přejmenované klíče v dosbox-staging 0.82

Konfigurace od GOG jsou psané pro DOSBox 0.74 a část klíčů už neplatí:

| DOSBox 0.74 / dosbox-x | dosbox-staging 0.82 |
|---|---|
| `cycles` | `cpu_cycles` (real mode) + `cpu_cycles_protected` (protected mode) |
| `scaler` | `glshader` |
| `output=overlay` | `output=opengl` |
| `sensitivity` v `[sdl]` | `mouse_sensitivity` v `[mouse]` |

Proto jsou v repozitáři dva configy. `play.sh` si vybírá podle toho, jakou
binárku najde, a `--cycles` posílá na správný klíč.

**Obě hry jsou DOS4GW**, tedy protected mode — platí pro ně
`cpu_cycles_protected`, nikoliv `cpu_cycles`. Na DOS promptu proto uvidíš
`3000 cycles/ms` (hodnota pro real mode) a svoje číslo až po spuštění hry.

## core = dynamic

Dokumentace dosbox-staging o dynamickém jádru píše: *„a necessity for
demanding DOS programs (e.g., 3D SVGA games)"* — což je přesně Magic Carpet.
`core = auto` by ho pro protected mode zvolilo taky, ale je nastavené
explicitně.

## Ladění za běhu

```bash
./play.sh --tune mc        # spustí v okně, kde jde přečíst aktuální hodnota
./play.sh -c 50000 mc      # jednorázově vyzkoušet konkrétní číslo
```

- **Ctrl+F12** zrychlit o 20 %
- **Ctrl+F11** zpomalit o 20 %
- **Alt+F12** turbo, dokud držíš

Krok je nastavený přes `cycleup` / `cycledown` na 20 %. Výchozích 10/20 je
nesymetrických a příliš jemných na ladění.

Aktuální hodnotu vypíše `./play.sh cycles` — proč to nejde přečíst z obrazovky
je v [klavesy-a-sway.md](klavesy-a-sway.md).

## Co cykly nespraví

U jedničky jsou framerate a rychlost hry svázané, takže vyšší rozlišení ten
kompromis zhoršuje: co přidáš na plynulost, se projeví i na tempu.

Trhání při plné rychlosti může mít jinou příčinu — klasické VGA režimy běží na
**70 Hz** a na 60Hz panelu z toho vzniká nerovnoměrné frame pacing. Zvyšováním
cyklů se to nespraví; pomůže `vsync = off`.
