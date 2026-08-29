# Magic Carpet na Fedoře

Zprovoznění **Magic Carpet Plus** (1994, včetně datadisku *The Hidden Worlds*)
a **Magic Carpet 2: The Netherworlds** (1995) z GOG.com na moderním Linuxu.

Obě hry jsou pro MS-DOS, takže potřebuješ **DOSBox**. Tenhle repozitář k němu
přidává spouštěcí skripty, vyladěné konfigurace a patch na obrácení osy Y myši.

Testováno na Fedoře 44, sway/Wayland, Ryzen 9 5900X + RX 6600, 4K displej.

---

## TL;DR — jak se dostat do hry

**1. Jednorázová příprava**

```bash
sudo dnf install innoextract dosbox-staging

git clone git@github.com:bardolf/magiccarpet.git
cd magiccarpet
./setup.sh ~/Downloads/setup_magic_carpet_plus_*.exe ~/Downloads/setup_magic_carpet_2_*.exe
./mouse-invert.py on          # otočí osu Y myši (jen za letu, ne v menu)
```

Instalátory musí být ty **offline** z GOG (~92 MB a ~300 MB), ne stubovací
soubory `GOG_Galaxy_*.exe` (~490 KB) — v těch hra není.

**2. Spustit**

```bash
./play.sh mc2       # Magic Carpet 2
./play.sh mc        # Magic Carpet 1 / Hidden Worlds
```

**3. Ve hře**

| krok | jak |
|---|---|
| přepnout rozlišení | klávesa **R** — 320×200 ↔ 640×480 |
| doladit rychlost | **Ctrl+F12** rychleji, **Ctrl+F11** pomaleji (po 20 %) |
| myš | otočená, pokud jsi spustil `mouse-invert.py on` |

Rozlišení **není v menu ani v Options panelu**, jen na klávese R. Položka
`Alter screen size` v Options panelu (klávesa **D**) mění velikost výřezu,
ne rozlišení.

Rychlost lad, dokud není obraz plynulý. Číslo, na kterém skončíš, si ulož —
u jedničky do `MCP_CYCLES` v `play.sh`, u dvojky do `MC2_CYCLES`.

Aktuální hodnotu vypíše `./play.sh cycles` (v titulku okna ji nemusí být vidět,
viz [klavesy-a-sway.md](docs/klavesy-a-sway.md)).

**A hrajeme.**

---

## Obsah

| soubor | co dělá |
|---|---|
| `setup.sh` | rozbalí GOG instalátory a srovná adresářovou strukturu |
| `play.sh` | launcher — výběr hry, mounty, ladicí přepínače |
| `mouse-invert.py` | binární patch: obrácení osy Y myši (jen za letu, ne v menu) |
| `dosbox-staging.conf` | konfigurace pro dosbox-staging 0.82+ |
| `dosbox-x.conf` | starší syntaxe pro dosbox-x (bez shaderů a MIDI sekcí) |
| `tools/iso_ls.py` | výpis obsahu ISO9660 včetně raw obrazů MODE1/2352 |
| `tools/iso_get.py` | extrakce jednoho souboru z ISO |

### play.sh

```
./play.sh                 menu s výběrem
./play.sh mc2             Magic Carpet 2
./play.sh mc              Magic Carpet Plus (launcher: základní hra / Hidden Worlds)
./play.sh hidden          Hidden Worlds přímo
./play.sh setup           nastavení zvuku pro jedničku
./play.sh setup2          nastavení zvuku pro dvojku
./play.sh cycles          vypíše aktuální rychlost CPU běžící hry
./play.sh lang            smaže volbu jazyka v jedničce

  -w, --windowed          spustit v okně
  -c, --cycles N          jednorázově jiná rychlost CPU (číslo nebo max)
  -s, --shader S          jiný glshader (none, interpolation/sharp, crt-auto)
      --stretch           roztáhnout na celých 16:9 (deformuje)
  -h, --help              nápověda

Přepínače -s a --stretch fungují jen s dosbox-staging.
Proměnná DOSBOX_BIN vynutí konkrétní emulátor:  DOSBOX_BIN=dosbox-x ./play.sh mc2
      --tune              ladicí režim v okně
```

## Podrobnosti

- [Instalace](docs/instalace.md) — GOG instalátory, struktura CD image, Hidden Worlds
- [Ladění výkonu](docs/ladeni-vykonu.md) — proč každá hra potřebuje jinou rychlost CPU
- [Obraz a displej](docs/obraz-a-displej.md) — rozlišení, černé pruhy, integer scaling, 4K
- [Zvuk a hudba](docs/zvuk-a-hudba.md) — General MIDI, soundfonty, CD audio, MT-32, GUS
- [Klávesy a sway](docs/klavesy-a-sway.md) — proč není vidět titulek okna a jak ho přečíst
- [Reverse engineering myši](docs/reverse-engineering-mysi.md) — analýza a offsety patche

## Herní data

V repozitáři **nejsou a nebudou** — jsou autorsky chráněná. Kup si hry na
[GOG.com](https://www.gog.com/) a stáhni offline instalátory.

## Licence

Skripty a dokumentace jsou volně k použití. Nevztahuje se to na herní data,
která zůstávají majetkem držitelů práv (Bullfrog / EA).
