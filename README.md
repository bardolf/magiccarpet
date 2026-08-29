# Magic Carpet na Fedoře

Zprovoznění **Magic Carpet Plus** (1994, včetně datadisku *The Hidden Worlds*)
a **Magic Carpet 2: The Netherworlds** (1995) z GOG.com na moderním Linuxu —
spouštěcí skripty, vyladěné konfigurace DOSBoxu a patch na obrácení osy Y myši.

Testováno na Fedoře 44, sway/Wayland, Ryzen 9 5900X + RX 6600, 4K displej.

## Nejdůležitější zjištění

**Obě hry jsou MS-DOS, ne Windows.** Wine ani Proton pro ně nedávají smysl —
patří sem DOSBox. GOG je prodává zabalené s DOSBoxem právě proto.

**GOG Galaxy instalátory jsou k ničemu.** Soubory typu
`GOG_Galaxy_Magic_CarpetTM_2_The_Netherworlds.exe` (~490 KB) jsou jen stahovací
stuby pro klienta Galaxy — hru neobsahují. Potřebuješ *offline backup game
installers* z webu GOG (~92 MB a ~300 MB).

**Wine není potřeba ani na instalaci.** GOG instalátory jsou InnoSetup a rozbalí
je nativně `innoextract`.

## Rychlý start

```bash
sudo dnf install innoextract dosbox-staging   # na Fedoře je binárka /usr/bin/dosbox

git clone git@github.com:bardolf/magiccarpet.git
cd magiccarpet
./setup.sh ~/Downloads/setup_magic_carpet_plus_*.exe ~/Downloads/setup_magic_carpet_2_*.exe

./play.sh          # menu
./play.sh mc2      # rovnou Magic Carpet 2
```

## Obsah

| soubor | co dělá |
|---|---|
| `setup.sh` | rozbalí GOG instalátory a srovná adresářovou strukturu |
| `play.sh` | launcher — výběr hry, mounty, ladicí přepínače |
| `mouse-invert.py` | binární patch: obrácení osy Y myši (jen za letu, ne v menu) |
| `dosbox-staging.conf` | konfigurace pro dosbox-staging 0.82+ |
| `dosbox-x.conf` | totéž ve staré syntaxi pro dosbox-x |
| `tools/iso_ls.py` | výpis obsahu ISO9660 včetně raw obrazů MODE1/2352 |
| `tools/iso_get.py` | extrakce jednoho souboru z ISO |

## Dokumentace

- [Instalace](docs/instalace.md) — od GOG stubu k rozbalené hře, struktura CD image
- [Ladění výkonu](docs/ladeni-vykonu.md) — cykly CPU, proč každá hra potřebuje jinou hodnotu
- [Obraz a displej](docs/obraz-a-displej.md) — černé pruhy, integer scaling, 4K, shadery
- [Klávesy a sway](docs/klavesy-a-sway.md) — proč není vidět titulek okna a jak ho přečíst
- [Reverse engineering myši](docs/reverse-engineering-mysi.md) — celá analýza patche

## Herní data

V repozitáři **nejsou a nebudou** — jsou autorsky chráněná. Kup si hry na
[GOG.com](https://www.gog.com/) a stáhni offline instalátory.

## Licence

Skripty a dokumentace jsou volně k použití. Nevztahuje se to na herní data,
která zůstávají majetkem držitelů práv (Bullfrog / EA).
