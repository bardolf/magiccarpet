# Obraz a displej

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
(`crt/`, `interpolation/`, `scaler/`). `crt-auto` vybírá variantu podle
rozlišení — na 4K sáhne po `crt/vga-4k.glsl`.

## Frame pacing na 60Hz panelu

Klasické VGA režimy běží na **70 Hz**. Na 60Hz displeji z toho vzniká
nerovnoměrné frame pacing, které vypadá jako sekání i při plné rychlosti hry.

Zvyšování cyklů to **nespraví** — je to problém zobrazení, ne emulace.
`vsync = auto` to většinou zvládne; když ne, zkus `vsync = off` (za cenu
možného tearingu).
