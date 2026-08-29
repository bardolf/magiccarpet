# Zvuk a hudba

## Shrnutí

| hra | výchozí hudba | dá se vylepšit? |
|---|---|---|
| Magic Carpet 1 / Hidden Worlds | SB16 **FM** (OPL syntéza) | **ano** — General MIDI je znatelný upgrade |
| Magic Carpet 2 | **CD audio** (27 stop) | spíš ne, nahrané audio syntéza nepřekoná |

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

Config sám nestačí — hra si musí General MIDI vybrat ve svém setupu:

```bash
./play.sh setup      # Magic Carpet 1  (SELECT.EXE)
./play.sh setup2     # Magic Carpet 2  (SETSOUND.EXE)
```

U jedničky přepni music z *Soundblaster 16 fm* na *General midi*.

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
