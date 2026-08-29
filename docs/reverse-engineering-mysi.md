# Obrácení osy Y myši

Magic Carpet ovládá let „letecky" — myš dolů = pohled nahoru. Hry nemají
žádnou volbu na obrácení.

## Co nefunguje: DOSBox sensitivity

Nabízí se konfigurace DOSBoxu:

```ini
[mouse]
mouse_sensitivity = 100,-100   # záporná hodnota obrací osu
```

**Ale obrací osu globálně** — tedy i kurzor v menu, ve výběru kouzel a na
mapě. Pro let to řeší, pro ovládání hry rozbíjí. Proto se v tomhle repozitáři
nepoužívá.

## Ověření, že opravdu není nastavení

Options panel (klávesa **D**) je celý v `DATA/ETEXT.DAT` na CD:

```
Pause game / Abandon level / Continue game once dead...
Toggle sound / music / process speed / Brightness correction
Toggle reflections / sky / shadows / map and icons / light sources
Alter screen size / Toggle help / Toggle flight assistance
```

Žádná invertace. Command-line přepínače (`-harddrive`, `-music2`, `-vio`,
`-vfx1`, `-detectoff`) taky nic. PDF manuály jsou skenované obrázky s nulovým
textem, ale `ETEXT.DAT` je autoritativní.

## Řešení: binární patch

V obou hrách je v obsluze myši jediná instrukce `neg` nad osou Y.

### Magic Carpet 1 (CARPET.EXE)

```asm
2b01a:  0f bf 15 92 ad 00 00   movsx edx, WORD PTR ds:0xad92   ; myš Y
2b021:  c1 e2 07               shl   edx, 0x7                  ; ×128
2b024:  81 ea 00 64 00 00      sub   edx, 0x6400               ; −25600 = 200×128
2b02a:  b9 c8 00 00 00         mov   ecx, 0xc8                 ; 200 = low-res větev
2b02f:  f7 da                  neg   edx                       ; <<< PATCH
2b031:  89 c3                  mov   ebx, eax
2b038:  f7 f9                  idiv  ecx
2b03c:  eb 3e                  jmp   0x2b07c                   ; → společný ořez

2b03e:  0f bf 05 90 ad 00 00   movsx eax, WORD PTR ds:0xad90   ; myš X
2b045:  c1 e0 07               shl   eax, 0x7
2b048:  8d 90 00 60 ff ff      lea   edx, [eax-0xa000]         ; −40960 = 320×128
2b04e:  bb 40 01 00 00         mov   ebx, 0x140                ; 320 = šířka
...
2b064:  b9 f0 00 00 00         mov   ecx, 0xf0                 ; 240 = hi-res větev
2b07a:  f7 d9                  neg   ecx                       ; <<< PATCH

2b07c:  83 fb 81               cmp   ebx, -127                 ; společný ořez
2b07f:  ...                    cmp   ebx, 127
```

Proč je jisté, že jde o tenhle kód:

- `ds:0xad90` a `ds:0xad92` jsou dvě **sousední** 16bitové proměnné — X a Y myši
- X se dělí `0x140` = 320, Y se dělí `0xc8` = 200 (jedna větev) nebo
  `0xf0` = 240 (druhá větev)
- **negaci dostane jen Y**, X ne
- obě větve končí ořezem na ±127 — analogový rozsah letového ovládání

Dělitele 200 a 240 **nejsou rozlišení**, ale poloviční výšky souřadnicového
prostoru UI pro oba režimy (viz [obraz-a-displej.md](obraz-a-displej.md) —
skutečná rozlišení jsou 320×200 a 640×480). Pro identifikaci větví to ale
stačí: každý režim má svou a v obou je právě jedna negace osy Y.

Menu kurzor pracuje s absolutní pozicí, ne s deltou oříznutou na ±127, takže
tímhle kódem neprochází. Patch se proto projeví jen za letu.

### Magic Carpet 2 (NETHERW.EXE)

Stejná konstrukce, jen jinak poskládaná optimalizátorem:

```asm
3b8a5:  sub   edx, 0x6400      ; −25600 = 200×128 → střed
3b8ab:  mov   ebx, eax
3b8ad:  neg   edx              ; <<< PATCH (low-res)
3b8af:  mov   ecx, 0xc8        ; 200 = low-res větev
3b8bd:  jmp   0x3b8f5

3b8df:  lea   edx, [eax-0x7800]; −30720 = 240×128 → střed
3b8e5:  mov   ecx, 0xf0        ; 240 = hi-res větev
3b8f3:  neg   ecx              ; <<< PATCH (hi-res)

3b8f5:  cmp   ebx, -127        ; společný ořez
```

## Offsety

`neg edx` (`f7 da`) i `neg ecx` (`f7 d9`) se nahradí dvěma NOPy (`90 90`).
Instrukce je 2 bajty, NOP 1 bajt — zarovnání zůstane v pořádku.

| soubor | low-res | hi-res | MD5 |
|---|---|---|---|
| `CARPET.EXE` | `0x2b02f` | `0x2b07a` | `0763e103ed4935276050a0690f464850` |
| `HIDDEN.EXE` | `0x2b22f` | `0x2b27a` | `22ba3fb0df2d9f89c9fb31fe5dbcd638` |
| `NETHERW.EXE` | `0x3b8ad` | `0x3b8f3` | `ce911718f58f5376ea939ae48c945fec` |

**Pozor na chybu v internetových zdrojích:** [GOG fórum](https://www.gog.com/forum/magic_carpet_series/inverted_mouse_controls)
uvádí pro `CARPET.EXE` hi-res offset `0x2b27a`, což je ve skutečnosti hodnota
z `HIDDEN.EXE`. Správně je `0x2b07a`.

Offsety pro `NETHERW.EXE` uváděné na internetu (`0x9f2ad` / `0x9f1f3`) navíc
neodpovídají pozicím v souboru — jsou to nejspíš paměťové adresy. Skutečné
souborové offsety jsou v tabulce výše.

### Křížová kontrola

Skok z low-res větve míří vždy přesně na `neg_offset + 2`, tedy za hi-res
negaci na společný ořez:

| soubor | `jmp` cíl | hi-res `neg` |
|---|---|---|
| `CARPET.EXE` | `0x2b07c` | `0x2b07a` |
| `HIDDEN.EXE` | `0x2b27c` | `0x2b27a` |
| `NETHERW.EXE` | `0x3b8f5` | `0x3b8f3` |

Obě bajtové sekvence jsou v každém souboru **unikátní**, takže je lze najít
i vyhledáním vzoru bez znalosti offsetu.

## Patchování uvnitř CD image

Binárky jsou uvnitř `game.gog`, který musí zůstat namountovaný kvůli datům
a CD hudbě. Nelze je tedy rozbalit a patchovat na disku — mění se přímo image.

`mouse-invert.py` proto umí číst ISO9660 a mapovat offset v souboru na
fyzický offset v obrazu:

```python
# plain ISO:        sektor 2048 B
# raw MODE1/2352:   sektor 2352 B, užitečná data od offsetu 16
phys = (lba + file_off // 2048) * sec + off + file_off % 2048
```

Raw sektory mají EDC/ECC, které po zápisu přestanou sedět — DOSBoxu to nevadí,
čte jen 2048B datovou část.

## Použití

```bash
./mouse-invert.py status     # stav všech tří her
./mouse-invert.py on         # obrátit
./mouse-invert.py off        # vrátit
./mouse-invert.py on carpet  # jen jednu hru
```

Nástroj před zápisem ověřuje **okolní bajty** jako podpis (5 bajtů před a za),
ne celofilový MD5 — ten po zapatchování přestane sedět a znemožnil by druhý
průchod. Odmítne zapisovat, když okolí nesouhlasí.

Zásah je 2 bajty na místo, 4 bajty na hru. Plně vratný: po `off` se 130MB
image shoduje s originálem bajt po bajtu (ověřeno MD5 celého souboru).

## Co zůstalo nevyřešené

Hry mají vlastní **silnou akceleraci myši** zabudovanou v kódu. Z DOSBoxu se
s ní nedá nic dělat; šla by hledat ve stejné oblasti kódu.
