# Instalace

## Past č. 1: GOG Galaxy stuby

GOG nabízí u každé hry dvě různá stažení. Ta výchozí dá soubor jako

```
GOG_Galaxy_Magic_CarpetTM_2_The_Netherworlds.exe    490 568 B
GOG_Galaxy_Magic_Carpet_PlusTM.exe                  500 808 B
```

Půl megabajtu na hru z roku 1995 je podezřelé. Uvnitř je jen tohle:

```
InternalName    = GOG Galaxy - Game Installer.exe
FileDescription = Magic Carpet 2: The Netherworlds
```

a jediná zajímavá funkce `URLDownloadToFileW`. Jsou to stahovací stuby pro
klienta GOG Galaxy — hru neobsahují a na Linuxu jsou nepoužitelné.

**Co potřebuješ:** na gog.com → *Account / Games* → hra → **Download** →
rozbalit **„Offline backup game installers"**:

```
setup_magic_carpet_plus_1.0_(28186).exe      92 082 408 B
setup_magic_carpet_2_1.0_(28044).exe        300 567 928 B
```

`setup.sh` tuhle past hlídá a odmítne cokoliv pod 5 MB.

## Rozbalení bez Wine

GOG instalátory jsou InnoSetup, takže je rozbalí `innoextract` nativně:

```bash
innoextract -m -d magic-carpet-2 "setup_magic_carpet_2_1.0_(28044).exe"
```

`-m` znamená „nespouštět skripty instalátoru".

## Past č. 2: adresář `app/`

`innoextract` nechá komponentu `app/` jako samostatný adresář, ale instalátor
ji má nasypat do kořene hry. Bez sloučení chybí:

- Magic Carpet 2 — startovní `CONFIG.DAT` a soubory uložených pozic
  (jsou schované v `__support/save/GAME/NETHERW/`)
- prázdné, ale potřebné adresáře `SAVE`, `LANGUAGE`, `SHOTS`

`setup.sh` to řeší.

## Struktura po rozbalení

```
magic-carpet-plus/
├── CARPET.CD/
│   ├── game.gog       130 MB   CD image (plain ISO9660)
│   ├── SAVE/                   uložené pozice
│   ├── SNDSETUP.INF            SB16 220 5 1 / SB16FM 388
│   └── CP.DAT           2 B    volba Magic Carpet vs. Hidden Worlds
└── DOSBOX/                     windowsový DOSBox, na Linuxu nepoužitelný

magic-carpet-2/
├── game.gog           401 MB   CD image (raw MODE1/2352)
├── game.ins            1198 B  CUE list: 1 datová + 27 audio stop
└── GAME/NETHERW/               zapisovatelná strana (C:)
```

## Hry jsou na CD image

Spustitelné soubory **nejsou na disku** — jsou uvnitř `game.gog`. Proto se
image mountuje, ne rozbaluje:

```
imgmount D "game.ins" -t iso -fs iso     # MC2
mount C "GAME"
```

`game.ins` je CUE list s **27 stopami CD audio** — to je herní hudba. Kdybys
místo mountování image rozbalil jen data, o hudbu přijdeš.

Magic Carpet Plus má prostý ISO obraz bez audio stop:

```
mount C "."
imgmount D "CARPET.CD/game.gog" -t iso -fs iso
```

## Bonus: Hidden Worlds

Kořenový `CARPET.EXE` na CD má jen 11 650 B — je to launcher. Ve stringu má:

```
C:\CARPET.CD\CP.DAT
DOS4GW CARPET %s
DOS4GW HIDDEN %s
DOS4GW SELECT
```

Podle `CP.DAT` spustí buď základní hru (`CARPET`), nebo datadisk
**The Hidden Worlds** (`HIDDEN`). Ten je součástí Magic Carpet Plus.
`./play.sh hidden` ho spustí přímo, `./play.sh setup` otevře `SELECT` na
nastavení zvuku.
