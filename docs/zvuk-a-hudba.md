# Zvuk a hudba

## Shrnutí

| hra | výchozí hudba | MIDI driver | dá se vylepšit? |
|---|---|---|---|
| Magic Carpet 1 / Hidden Worlds | SB16 **FM** (OPL syntéza) | `SB16FM` | **ano** — General MIDI je znatelný upgrade |
| Magic Carpet 2 | **CD audio** (27 stop) | `SBPRO2.MDI` (OPL) | ne — nahrané audio syntéza nepřekoná |

Nastavení dvojky jsme záměrně nechali beze změny.

## Co hry podporují

Ověřeno přímo v binárkách a v souborech na CD.

**Magic Carpet 1** — v `CARPET.EXE` jsou názvy zvukových zařízení:

```
General midi        Roland mt32       GRAVIS            SBAWE32
Adlib gold          Soundblaster fm   Pro audio spectrum 8
```

Aktuální nastavení je v `CARPET.CD/SNDSETUP.INF`:

```
SOUNDFX = SB16 220 5 1
MUSIC = SB16FM 388 0 0
```

`SB16FM` je OPL FM syntéza — tam je prostor ke zlepšení.

**Magic Carpet 2** používá Miles/AIL s XMIDI a má na CD kompletní sadu ovladačů:

```
MPU401.MDI    General MIDI          ULTRA.MDI     Gravis Ultrasound
MT32MPU.MDI   Roland MT-32          SBAWE32.MDI   Sound Blaster AWE32
ADLIB.MDI, OPL3.MDI, SBLASTER.MDI, PAS.MDI, SNDSCAPE.MDI, TANDY.MDI ...
BULLFROG.SBK  vlastní soundfont banka pro AWE32
```

Dvojka má ale hudbu na **27 CD audio stopách** (proto se image mountuje jako
CUE přes `game.ins`). To je nahrané audio a General MIDI by pro ni byl spíš
krok zpět. V `README.TXT` je i přepínač:

```
-music2      Use alternative (Magic Carpet 1) music.
```

## Kde je uložený výběr ovladače

**Magic Carpet 2** — Miles AIL si volbu pamatuje ve dvou souborech
v `GAME/NETHERW/SOUND/`:

`MDI.INI` (hudba):

```ini
DEVICE      Creative Labs Sound Blaster(TM) 16
DRIVER      SBPRO2.MDI
IO_ADDR     220h
```

`DIG.INI` (zvukové efekty):

```ini
DEVICE      Creative Labs Sound Blaster 16 or AWE32
DRIVER      SB16.DIG
IO_ADDR     220h
```

Ovladače jsou i na lokálním disku (`GAME/NETHERW/SOUND/`), nejen na CD — to
dělá `NWSETUP.BAT` při instalaci.

**Magic Carpet 1** — v `CARPET.CD/SNDSETUP.INF` (a binárně v `SNDSETUP.DAT`):

```
SOUNDFX = SB16 220 5 1
MUSIC = SB16FM 388 0 0
```

## Proč FluidSynth neovlivní dvojku

Sekce `[midi]` a `[fluidsynth]` v configu jsou **společné pro obě hry**, ale
na Magic Carpet 2 prakticky nemají vliv:

`SBPRO2.MDI` posílá hudbu na **OPL čip Sound Blasteru**, ne na MPU-401. Do
FluidSynthu se tím pádem nic nedostane — ten dostává jen to, co jde přes
emulované MPU-401 rozhraní.

Kdybys chtěl dvojku na FluidSynth přepnout, musel bys v `./play.sh setup2`
zvolit `MPU401.MDI`. **Ale nemá to smysl** — hlavní hudba dvojky jsou CD audio
stopy, které jedou úplně mimo MIDI. Nastavení `SBPRO2.MDI` + `SB16.DIG` je
funkční a CD hudba hraje nezávisle na něm.

Reálný přínos má General MIDI **jen u jedničky**, která CD audio nemá a jede
na `SB16FM`, tedy taky na FM syntéze.

## General MIDI přes FluidSynth

**dosbox-staging má FluidSynth zabudovaný** — žádný MIDI démon na hostiteli
není potřeba. (Rady typu „spusť si na systému GM driver" se týkají starého
DOSBoxu 0.74.)

V `dosbox-staging.conf` je nastaveno:

```ini
[midi]
mididevice = fluidsynth

[fluidsynth]
soundfont = /usr/share/soundfonts/FluidR3_GM.sf2
```

Soundfont je z balíčku `fluid-soundfont-gm`. Ověření, že to naběhlo:

```
FSYNTH: Using SoundFont '/usr/share/soundfonts/FluidR3_GM.sf2'
MIDI: Opened device: fluidsynth
```

### Přepnout hru na General MIDI

Config sám nestačí — hra si musí General MIDI vybrat ve svém setupu.
**Dělej to jen u jedničky**, u dvojky to nemá smysl (viz výše):

```bash
./play.sh setup      # Magic Carpet 1 (SELECT.EXE)
```

Tam přepni music z *Soundblaster 16 fm* na *General midi*.

Setup dvojky je `./play.sh setup2` (SETSOUND.EXE), ale ten je spíš na řešení
problémů se zvukem než na vylepšování hudby.

### Lepší soundfont

Hudba té doby se skládala na **Roland SC-55**, takže soundfont podle něj zní
věrněji než obecný `FluidR3_GM`. Stačí přepsat cestu v `[fluidsynth]`.

## Roland MT-32

dosbox-staging umí i skutečnou emulaci MT-32 (sekce `[mt32]`, přes `mt32emu`,
který se instaluje jako závislost). Obě hry MT-32 podporují. Potřebuje ale
originální ROM soubory, které nejsou volně šiřitelné — proto to tenhle
repozitář nenastavuje.

```ini
[mt32]
model  = auto
romdir =        # sem cesta k ROM
```

## Gravis Ultrasound

Obě hry GUS podporují (`ULTRA.MDI` / `ULTRA.DIG` u dvojky, `GRAVIS`
v binárce jedničky) a dosbox-staging má sekci `[gus]`. GUS byl proti FM
syntéze znatelně lepší, ale chce to nainstalovat GUS patche do `C:\ULTRASND`,
což je práce navíc. V tomhle repozitáři nastavené není.
