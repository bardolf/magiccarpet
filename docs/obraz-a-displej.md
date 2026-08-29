# Obraz a displej

## Rozlišení: klávesa R

Obě hry umí dvě rozlišení a přepínají se **klávesou R přímo ve hře**:

| režim | rozlišení | jak je nastaveno |
|---|---|---|
| low-res | **320×200** | VGA mode 13h (`INT 10h, AX=0013h`) |
| hi-res | **640×480** | VBE mód `0x101` přes VESA |

Magic Carpet 2 to má v `README.TXT` doslova:

```
R                       Change screen resolution
```

Magic Carpet 1 klávesu R podporuje taky, ale mlčí o ní — není ani v herních
textech, ani ve vestavěné nápovědě. Je jen v tištěném manuálu:

```
Toggle between normal and hi-res mode: Press R (16 meg only)
```

**V menu ani v Options panelu volba rozlišení není.** Options panel (klávesa
**D**) obsahuje jen `Alter screen size`, což je něco jiného — mění velikost
herního výřezu, ne rozlišení. Na to jsou klávesy `[` a `]`.

### Hi-res vyžaduje VESA

Dobové omezení: hi-res chtěl 16 MB RAM a VESA kompatibilní SVGA kartu.
Z README MC2:

> Hi-Res mode requires 16Mb RAM, VESA compatible driver, SVGA video card
> & monitor.

V DOSBoxu je to splněné — `machine = svga_s3` v configu emuluje S3 Trio
s VESA BIOSem a `memsize = 16` dá 16 MB.

### Dopad na výkon

Hi-res má **4,8× víc pixelů** (307 200 proti 64 000) a jede přes VESA
bank-switching místo lineárního mode 13h. Dokumentace her o náročnosti nic
neříká, ale prakticky to znamená, že po přepnutí na hi-res je potřeba víc
cyklů CPU — viz [ladeni-vykonu.md](ladeni-vykonu.md).

Jediná dobová rada k výkonu je ve vestavěné nápovědě jedničky a týká se
detailů, ne rozlišení:

```
If you are experiencing slowness, try Pressing F5,F6,F7.
```

(odrazy / obloha / stíny)

## Černé pruhy ze všech čtyř stran

Příznak: ve fullscreenu je obraz obklopený černou nahoře, dole i po stranách.

Příčina je řetězec výchozích hodnot dosbox-staging:

```
glshader = crt-auto            → adaptivní CRT shader
integer_scaling = auto         → při CRT shaderu se zapne 'vertical'
```

`integer_scaling = vertical` zaokrouhlí svislé zvětšení na celý násobek.
Pro hru 640×480 na 4K displeji (3840×2160):

```
480 × 4 = 1920  (víc se do 2160 nevejde)  → 120 px pruh nahoře i dole
při 4:3 pak šířka 2560                    → 640 px pruh vlevo i vpravo
```

Dokumentace to i přiznává: *„There might be padding (black areas) around the
image with 'integer_scaling' enabled."*

**Řešení:** `integer_scaling = off`

```
640×480 na 3840×2160:
integer_scaling = vertical  →  2560 × 1920, pruhy ze 4 stran
integer_scaling = off       →  2880 × 2160, pruhy jen po stranách
aspect = stretch, viewport = 100%  →  3840 × 2160, bez pruhů, ale deformace
```

## Postranní pruhy nezmizí

Hry jsou 4:3, moderní panely 16:9. Postranní pruhy jsou matematická nutnost —
jediný způsob, jak je odstranit, je obraz deformovat:

```bash
./play.sh --stretch mc2
```

Vyplní panel beze zbytku, ale obraz bude o třetinu širší, než má být.

## Kompromis s CRT shaderem

Integer scaling se u CRT shaderů zapíná záměrně — dokumentace ho označuje za
*„recommended setting for CRT shaders to avoid uneven scanlines and
interference artifacts"*. Vypnutím se tedy jde proti doporučení.

Pokud se objeví nerovnoměrné scanline nebo moaré, řešením je vypnout shader:

```bash
./play.sh -s none mc2                    # bez shaderu
./play.sh -s interpolation/sharp mc2     # ostré škálování bez CRT efektu
```

Dostupné shadery jsou v `/usr/share/dosbox-staging/glshaders/`
(`crt/`, `interpolation/`, `scaler/`, `misc/`). `crt-auto` vybírá variantu podle
rozlišení — na 4K sáhne po `crt/vga-4k.glsl`.

## Frame pacing na 60Hz panelu

Klasické VGA režimy běží na **70 Hz**. Na 60Hz displeji z toho vzniká
nerovnoměrné frame pacing, které vypadá jako sekání i při plné rychlosti hry.

Zvyšování cyklů to **nespraví** — je to problém zobrazení, ne emulace.

Klíč `vsync` v configech tohoto repozitáře **není nastavený**, takže platí
výchozí `auto`, které si s tím většinou poradí. Když ne, přidej si do
`dosbox-staging.conf` do sekce `[sdl]`:

```ini
vsync = off     # za cenu možného tearingu
```
