# Pády Magic Carpet 2 a co proti nim zkusit

Dvojka ve vyšším rozlišení (640×480, klávesa **R**) spadne po 5–20 minutách
hraní. Tenhle dokument říká, co přesně se při tom děje, a nabízí čtyři nastavení,
kterými se to dá zkusit posunout.

---

## Co se stalo — z coredumpu, ne z odhadu

Když DOSBox při pádu hry skončí sám, systemd po něm uloží coredump. Kdykoli
později se z něj dá vytáhnout hláška, kterou DOSBox naposledy vypsal:

```bash
./play.sh crash
```

Z pádu 29. 8. 2026 (dosbox-staging 0.82.2, `./play.sh mc2`, tedy `core=dynamic`
a `cpu_cycles_protected=max`):

```
ABORT: INT:Gate Selector points to illegal descriptor with type 0x0

#6  E_Exit
#7  CPU_Interrupt
#8  DynRunException
```

Přeloženo: uvnitř hry vznikla **výjimka procesoru** (v chráněném režimu, takže
GPF nebo page fault). DOSBox ji chtěl předat obslužné rutině podle IDT, ale
selektor toho vektoru ukazuje na **prázdný deskriptor** (typ 0). Obsluha výjimky
je tím sama nepoužitelná, pokračovat není kam, a DOSBox zavolá `abort()`.

Dvě věci z toho plynou:

- Pád **není** v grafice ani ve zvuku. Je na úrovni procesoru a paměti.
- Ve chvíli pádu už byl rozhozený stav — deskriptorové tabulky DOS4GW jsou
  vynulované. Buď je hra přepsala něčím, co zapsala mimo své pole, nebo
  dynamické jádro vyhodilo výjimku, kterou by skutečný procesor nevyhodil.

Rámeček `DynRunException` je důležitý: ta cesta patří **dynamickému
rekompilátoru**. Proto je první páka právě jádro CPU.

---

## Druhý nález: hra čte z adres, které neexistují

Log z běhu 31. 8. 18:28 (`./play.sh --log`) ukázal tohle:

```
Illegal read from f630539e, CS:IP      160:  1da137
Illegal read from f63053e4, CS:IP      160:  1d94a4
... 1000×
```

`./play.sh loginfo` to shrne. Z toho běhu:

| co | kolik |
|---|---|
| hlášek `Illegal read` | 1000 za **2,4 sekundy** |
| různých adres | **11**, všechny v rozsahu `f630539e`–`f63053e7` |
| různých míst v kódu hry | **8**, ve třech rutinách (`1d949a`, `1da137`, `1e58e8`) |

Přeloženo: hra asi **420× za sekundu** čte přes ukazatel, který míří mimo
veškerou emulovanou paměť (`0xf63053xx` ≈ 4,1 GB, stroj má 31 MB). Pořád ten
samý ukazatel, pořád z těch samých tří rutin. DOSBox na takové čtení vrátí
`0xff` a běží dál — hra tedy dostává smetí a počítá s ním.

**Číslo 1000 je strop výpisu DOSBoxu**, ne konec problému. Po tisící hlášce
přestane hlásit a mlčky vrací `0xff` dál. V logu to vypadá, že to po 2,4 s
skončilo; ve skutečnosti to jelo celou hru.

Tohle je věrohodný mechanismus těch pádů: smetí se hromadí ve stavu hry, až
z něj vznikne adresa nebo index, který shodí i to ostatní. Sedí to i s časovým
rozptylem 5–20 minut — není to jedna konkrétní událost, ale nastřádání.

### Kontrolní běh: rozhodnuto, s rozlišením to nesouvisí

Druhý běh (31. 8. 19:04) jel v **původní konfiguraci** — `dynamic`, `max`,
`memsize=16`, EMS zapnuté, tedy přesně to, s čím se hrálo předtím — a časová
osa vypadá takhle:

```
19:04:20  320x200
19:04:23  640x480
19:04:34  320x200
19:04:47  ... 1000× Illegal read (19:04:47 - 19:04:49)
19:06:35  640x480
```

Ta smršť přišla **ve 320×200**, ne ve VESA režimu. Z toho plyne:

- **Není to způsobené `--safe`** ani jádrem `normal` — děje se to i s původním
  nastavením.
- **Není to vázané na 640×480.** V obou bězích to začalo zhruba **25 sekund po
  načtení levelu**, bez ohledu na to, v jakém režimu se zrovna bylo.

Zajímavé je porovnání obou běhů:

| | běh 1 (`memsize=31`) | běh 2 (`memsize=16`) |
|---|---|---|
| adresy | `f6305`**39e**…`f6305`**3e7** | `f5364`**39e**…`f5364`**3e7** |
| míst v kódu | 8 | 5 |

**Spodní offsety jsou v obou bězích identické** (`39e, 39f, 3a0, 3a1, 3d3,
3e2–3e7`), liší se jen báze. Hra tedy pokaždé sahá na stejná políčka stejné
struktury; mění se jen adresa, na kterou ten ukazatel omylem míří. Adresy
v kódu se mezi běhy posunuly zhruba o 0x60000, což odpovídá jinému místu
načtení programu při jiném `memsize` — jsou to tytéž tři rutiny.

### Co to tedy znamená pro pády

Míň, než to na první pohled vypadalo. Když se tohle děje **v každém běhu,
včetně té konfigurace, se kterou se normálně hrálo**, a hra i tak vydrží 5–20
minut, pak samotné čtení mimo paměť hru neshazuje. DOSBox vrátí `0xff` —
a mimochodem skutečný hardware by na nezmapované adrese vrátil to samé, takže
takhle se hra chovala i v roce 1995.

Zůstává to jako možný **přispěvatel** (hra si do svého stavu tahá smetí), ne
jako prokázaná příčina. Hypotéza „chyba je ve VESA cestě, obejít ji přes
`vesa_nolfb`" tímhle padá — v 320×200 se to děje stejně.

### Anatomie pádu: 31. 8. 19:16

První pád zachycený s `--log` (`--safe`, tedy `dynamic`, 200000 cyklů,
`memsize=31`, bez EMS). Vydržel **5 minut 29 sekund**, celou dobu v 640×480.
`./play.sh loginfo` z něj vytáhne tohle:

```
Illegal read:  1000    19:11:18 - 19:11:20    f630539e…f63053e7
                                              1d9490, 1da131, 1da141, 1e58d3, 1e5992

Illegal write:   56    19:16:29 - 19:16:29    22369e3c…22369e3f, 22369ebc…22369ebf
                                              226d8e, 226dbf

Konec behu:
   DYNX86:Can't run code in this page!
   ABORT: Illegal descriptor type 0x0 for int 6
```

Ta dvě čtení a zápisy je potřeba **striktně oddělovat**:

- **Čtení** je ten známý šum. Naběhl 18 s po startu, za dvě sekundy vyčerpal
  strop výpisu a pak jel mlčky dál. Ve všech konfiguracích, v obou rozlišeních.
- **Zápisy se objevily jen a pouze v okamžiku pádu** — 56 hlášek v jediné
  milisekundě, ani jedna za předchozích pět a půl minuty. Jsou to čtyřbajtové
  zápisy na dvě adresy 0x80 od sebe, z jedné rutiny (`226d8e` a `226dbf` jsou
  0x31 bajtů od sebe). Tohle je ten okamžik, kdy se to zlomilo.

Pak už jen:

1. `DYNX86: Can't run code in this page!` — hra skočila mimo svůj kód,
   dynamické jádro tam neumí nic spustit a předá to jádru `normal`.
2. To narazí na neplatnou instrukci → výjimka **int 6** (invalid opcode).
3. Deskriptor pro int 6 je typu 0, tedy prázdný — DOS/4GW pro invalid opcode
   žádnou obsluhu nemá. DOSBox nemá kam pokračovat a končí přes `abort()`.

Stack trace z toho pádu ukazuje `SHELL_Init → DOS_Shell::InputCommand →
device_CON::Read`, tedy DOS prompt. Hra tou dobou už byla po smrti a shell si
sáhl na BIOS klávesnici — a rozbitý stav procesoru shodil i jeho, 146 ms po
těch zápisech.

**Mimochodem tím se vysvětluje pád v 18:52, po kterém nebyl žádný coredump:**
tehdy to běželo bez `--log`, takže se závěrečným `-c exit`. Ten se vykonal
dřív, než shell stihl sáhnout na klávesnici a spadnout — DOSBox skončil
„čistě" a nic po sobě nenechal.

DOS/4GW svoji hlášku (`fatal error (2001): exception …`) nestihl vypsat —
v paměti z coredumpu po ní není stopa a textová obrazovka na 0xB8000 je prázdná.

### Co z toho plyne

**Hra ztratí kontrolu — skočí do smetí.** To žádné nastavení DOSBoxu neopraví;
emulátor jen věrně provede, co mu program řekne. Ty čtyři páky můžou posunout,
_jak často_ se to stane (mění rozložení paměti, a tím i to, kam divoké
ukazatele míří), ale příčinu neodstraní.

Za pozornost stojí, že `memsize=31` tenhle běh neudržel ani šest minut, zatímco
s výchozími 16 MB to bylo 5–20. Jeden vzorek nic nedokazuje, ale je to důvod
zkusit `--safe --mem 16` a porovnat.

---

## Čtyři páky

| páka | přepínač | proč právě tahle |
|---|---|---|
| jádro CPU | `--core normal` | *Jen diagnosticky, ne na hraní — viz níž.* Pád jde přes `DynRunException`, tedy přes dynamický rekompilátor. Jádro `normal` tuhle cestu nepoužívá a chráněný režim emuluje přesněji. |
| rychlost CPU | `-c 120000` | `max` znamená „ber, co hostitel unese" — počet cyklů se přitom pořád mění a emulovaný procesor je násobně rychlejší než cokoliv z roku 1995. Pokud hra někde přetéká nebo jí protéká paměť, s `max` na to dojde tím dřív. Pevné číslo je předvídatelné. S jádrem `normal` je pevná hodnota potřeba tak jako tak — to jádro dá hostiteli 3–5× víc práce, takže z `max` nic nevytáhne. |
| RAM | `--mem 31` | V binárce dvojky jsou hlášky `CANT ALLOC CARPET MEMORY.`, `CANT ALLOC RESERVE MEMORY.` a `NOT ENOUGH MEMORY FOR SOUNDS` — hra má pevné alokace a hlásí, když se nevejde. Vyšší rozlišení znamená větší buffery. GOG i staging dávají 16 MB; nad 31 MB staging sám varuje, že to většině DOSových her nesvědčí. |
| EMS | `--noems` | DOS4GW jede na XMS/DPMI, EMS nepotřebuje. Vypnutím se zjednoduší paměťová mapa pod 1 MB (mizí EMS okno v UMB). |

```bash
./play.sh --safe mc2
```

`--safe` zapne **tři z nich** — pevné cykly, `memsize=31` a vypnuté EMS.
Jádro `normal` v něm schválně není, protože se na hraní neosvědčilo (níž).
Předvolba se dá přebít tím, že páku uvedeš zvlášť: `./play.sh --safe --mem 16 mc2`.

### Proč jádro `normal` odpadlo

DOSBox to sám napsal do logu:

```
CPU: Setting fixed 120000 cycles. Try setting 'core = dynamic' for increased
performance if you need more than 20000 cycles.
```

Jádro `normal` je stavěné zhruba do 20000 cyklů/ms; dvojka v 640×480 potřebuje
násobně víc. Nad tou hranicí se emulátor dostane za reálný čas a **začne
praskat zvuk** — přesně to se stalo. Jako nástroj na rozhodnutí „chyba
rekompilátoru vs. chyba hry" pořád stojí za jeden krátký běh, ale s nízkými
cykly a bez ambice u toho hrát:

```bash
./play.sh --core normal -c 20000 --log mc2
```

**Daň:** pevné cykly místo `max` můžou znamenat méně FPS. Dolaď je
**Ctrl+F12** na to, co jsi měl s `max`, a zapiš si číslo do `MC2_SAFE_CYCLES`
v `play.sh`.

---

## Jak zkoušet, aby z toho něco bylo

Pád přijde po 5–20 minutách, takže jediné použitelné kritérium je „vydrželo to
výrazně dýl než dosud". Počítej s tím, že jedno kolo je půl hodiny hraní.

1. **Nejdřív všechno naráz**, ať je vidět, jestli vůbec některá páka zabírá:

   ```bash
   ./play.sh --safe --log mc2
   ```

2. **Když je klid**, ubírej po jedné, dokud se pády nevrátí — tím se najde ta,
   která to opravdu drží:

   | co zkoušet | příkaz |
   |---|---|
   | jen pevné cykly | `./play.sh -c 120000 --log mc2` |
   | jen jádro `normal` (jen diagnostika) | `./play.sh --core normal -c 20000 --log mc2` |
   | jen víc paměti | `./play.sh --mem 31 --log mc2` |
   | jen bez EMS | `./play.sh --noems --log mc2` |

3. **Když ani `--safe` nepomůže**, pády nejsou v těchhle čtyřech věcech — viz
   další sekce.

### `--log`

```bash
./play.sh --log mc2
```

Dělá dvě věci:

- výpis DOSBoxu jde do `logs/RRRRMMDD-HHMMSS-mc2.log`, takže hláška `ABORT:`
  zůstane i bez coredumpu,
- **nepřidává** závěrečné `exit`, takže když hra spadne na DOS prompt, okno tam
  zůstane stát a je vidět, co vypsal DOS4GW. Bez `--log` to probleskne spolu
  s oknem.

---

## Trhaný zvuk s jádrem `normal`

Když s `--core normal` začne praskat a sekat zvuk (a předtím byl v pořádku),
**není to chyba zvuku**. Je to měření: znamená to, že jádro `normal` nestíhá
dodávat požadovaný počet cyklů. DOSBox se tím dostane za reálný čas, mixer
nedostane vzorky včas a je to slyšet. Emulace běží v **jednom vlákně**, takže
je jedno, kolik má hostitel jader.

Řešení je najít číslo, které jádro `normal` na tomhle stroji utáhne:

```bash
./play.sh --core normal --tune mc2
```

Běží v okně, v titulku je vidět počet cyklů, **Ctrl+F11** ubírá po 20 %. Uber,
dokud zvuk nezčistí.

Rychlejší varianta, která to najde sama:

```bash
./play.sh --core normal --set "cpu cpu_throttle=true" mc2
```

`cpu_throttle` DOSBoxu dovolí cykly sám snižovat, dokud hostitel nestíhá —
místo trhaného zvuku dostaneš nižší framerate a čistý zvuk. Kolik si nakonec
vzal, vypíše `./play.sh cycles` z druhého terminálu. Pro samotné hraní ho pak
nech vypnutý: měnící se počet cyklů je přesně ta věc, kterou se u `max`
snažíme odstranit.

**Když ani nejnižší snesitelné číslo nedá hratelný framerate** — a to je
u dvojky v 640×480 to, co se stalo — je jádro `normal` na tuhle hru prostě moc
drahé. Na hraní tedy `dynamic`; `normal` si nech na jeden krátký diagnostický
běh podle sekce [Proč jádro `normal` odpadlo](#proč-jádro-normal-odpadlo).

### Nastavení mixeru

Na `[mixer]` v `dosbox-staging.conf` je nezávisle na tomhle nastaveno:

```
rate      = 48000    # shodně s hostitelem (PipeWire jede 48 kHz), GOG měl 44100
blocksize = 1024     # kvantum PipeWire, staging má jinak 512
prebuffer = 50       # staging má jinak 20 ms
```

Většího bloku a delšího předběhu se týká jen odolnost proti výkyvům v plánování
úloh na hostiteli — **trhání z nestíhajícího jádra CPU to nespraví**, na to je
jedině méně cyklů. Kdyby to bylo potřeba přitáhnout ještě víc:

```bash
./play.sh --set "mixer prebuffer=100" --set "mixer blocksize=2048" mc2
```

---

## Když čtyři páky nestačí

Přepínač `--set` pošle DOSBoxu jakékoli nastavení, takže na další zkoušení není
třeba nic editovat:

```bash
./play.sh --set "dosbox machine=vesa_nolfb" mc2   # VESA bez lineárního framebufferu
./play.sh --set "dosbox vmemsize=2" mc2           # dobové 2 MB videopaměti místo 4
./play.sh --set "dosbox speed_mods=false" mc2     # vypne výkonnostní zkratky stagingu
```

- **`machine=vesa_nolfb`** schová lineární framebuffer, takže hra do videopaměti
  zapisuje po bankách. Je to jiná cesta v kódu hry — pokud je chyba v její práci
  s LFB, tohle ji obejde. Zaplatí se za to výkonem. Kontrolní běh 31. 8. tuhle
  stopu ale oslabil: `Illegal read` se dějí i ve 320×200, takže SVGA cesta v tom
  nemusí hrát roli. Pořád stojí za zkoušku, protože pády samotné se zatím
  hlásily jen z 640×480.
- **`voodoo = off`** je od 31. 8. rovnou v `dosbox-staging.conf`. Staging jinak
  emuluje 3dfx Voodoo (`VOODOO: Initialized with 4 MB of RAM, 16 threads`
  v logu), což je u her z let 1994/1995 karta, kterou nikdy nemohly vidět.
- **Zvuk**: `./play.sh setup2` přepne zvukový driver dvojky. Když pády zmizí po
  vypnutí zvuku, je problém v AIL driveru, ne v procesoru. Kde se výběr ukládá,
  je v [zvuk-a-hudba.md](zvuk-a-hudba.md).
- **Jiný emulátor — momentálně nejlepší zbylý pokus.** dosbox-x má vlastní
  rekompilátor, vlastní implementaci chráněného režimu i DPMI. Jediná cesta,
  jak rozhodnout „chyba hry vs. chyba dynamického jádra dosbox-staging", protože
  jádro `normal` je na hraní moc pomalé.

  ```bash
  DOSBOX_BIN=dosbox-x ./play.sh mc2
  ```

  Nainstalovaný je (2026.08.02 z copr `rob72/DOSBox-X`, tedy o dva roky novější
  než dosbox-staging 0.82.2 ve Fedoře). Použije se `dosbox-x.conf`, který nezná
  shadery ani MIDI sekce — obraz bude jiný a rozlišení se ladí zvlášť.

---

## Zkouška s dosbox-x

```bash
DOSBOX_BIN=dosbox-x ./play.sh --log mc2
```

Ověřeno, že to projde: CD image se namountuje správně
(`CDROM: Image loaded No. of data tracks=1, audio tracks=27`), takže hudba
z CD hraje, a všechny páky (`--safe`, `--mem`, `--noems`, `--core`, `-c`) mají
v dosbox-x stejné názvy klíčů.

Co se liší:

- Použije se **`dosbox-x.conf`**, ne staging config. Nezná shadery, takže obraz
  bude jiný — ostřejší, bez CRT filtru. Mixer je srovnaný na 48 kHz stejně jako
  u stagingu a Voodoo je vypnuté.
- **`./play.sh cycles` nefunguje** — čte titulek okna ve formátu stagingu.
  dosbox-x umí `-showcycles`, ale `play.sh` to nepředává.
- dosbox-x ukazuje nahoře **menu lištu** a má vlastní klávesové zkratky.
- V logu se objeví `Memory I/O complexity optimization enabled`. Kdyby se obraz
  kreslil divně, vypíná se to přes
  `--set "dosbox memory io optimization=false"`.

Diagnostika funguje pro oba emulátory — hlášky se jmenují stejně
(`Illegal read from …`, `DYNX86:Can't run code in this page!`,
`Illegal descriptor type …`), takže `./play.sh loginfo` i `./play.sh crash`
z toho přečtou totéž. `crash` si navíc hledá coredump podle jména procesu, takže
ho je potřeba spustit se stejnou proměnnou:

```bash
DOSBOX_BIN=dosbox-x ./play.sh crash
```

### Výsledek: dosbox-x říká totéž, jen jinými slovy

Běh 31. 8. 19:29 vydržel **1 minutu 23 sekund** — zdaleka nejhorší ze všech
pokusů. Konec vypadal takhle:

```
CPU_Exception: Exception 13 already in progress, triggering double fault instead
CPU_Exception: Double fault already in progress == Triple Fault. Resetting CPU.
E_Exit: Triple fault reset call unexpectedly returned
```

**Exception 13 je #GP, general protection fault.** Hra ho vyvolá, obsluha
selže a vyvolá další → double fault → triple fault → procesor se resetuje.
dosbox-x pak umře na vlastní resetovací cestě.

To je **tentýž děj, který hlásil dosbox-staging**, jen ho každý emulátor
popisuje po svém:

| | staging 0.82.2 | dosbox-x 2026.08.02 |
|---|---|---|
| co hlásí | `Illegal descriptor type 0x0 for int 6` | `Exception 13 → double → triple fault` |
| jak umře | `abort()` z `E_Exit` | reset CPU, pak `E_Exit` |
| jak dlouho vydržel | 5 min 29 s | **1 min 23 s** |

**Tím je otázka „chyba hry, nebo chyba emulátoru" zodpovězená: je to hra.** Dvě
nezávislé implementace procesoru, DPMI i chráněného režimu se shodnou na tom,
že program spadne do výjimky, na kterou nemá obsluhu. Žádné nastavení
emulátoru to neopraví.

dosbox-x se navíc pro tuhle hru neosvědčil ani výkonem té výdrže, takže
**zůstat u dosbox-staging.**

### Co ještě dosbox-x prozradil

V jeho logu je vidět, co hra dělá při startu — samo o sobě to nic neznamená,
hra si oklepává hardware, ale je to hezký pohled dovnitř:

```
ERROR INT10:Function 6F00 not supported        hledá Video7 SVGA BIOS
ERROR INT10:Function 5F00 not supported        hledá Ahead/Everex SVGA BIOS
ERROR BIOS:INT15:Unknown call ax=BFDE / BF01   nějaká detekce přes INT 15h
ERROR CPU:Illegal Unhandled Interrupt Called 5C  NetBIOS - hra hledá síť
ERROR MOUSE:Unhandled videomode 69 on reset    ovladač myši nezná režim 69h
```

To NetBIOS volání sedí s tím, že GOG přibalil `GAME/netbios.exe` pro hru po
síti. Poslední „normální" řádka před pádem byla
`CDROM: Tried to play zero sectors, skipping` — požadavek na přehrání nulové
délky CD stopy. Nejspíš náhoda, ale je to jediná levná věc, která se dá ještě
zkusit: vypnout hudbu přes `./play.sh setup2` a podívat se, jestli to vydrží
dýl.

---

## Co k tomu říká fórum GOG

Vlákno [Magic Carpet 2 crashes in hires
mode](https://www.gog.com/forum/magic_carpet_series/magic_carpet_2_crashes_in_hires_mode/page1).
Co z něj plyne:

**Potvrzuje to náš kontrolní běh.** Jeden z diskutujících: *„The problem also
happens in certain levels in the lower res."* Takže ani na fóru to není vázané
na rozlišení — hi-res to jen zhoršuje.

**Dva nápady, které jsme nezkusili:**

| nápad z fóra | jak to udělat u nás |
|---|---|
| `cputype = pentium_slow`, protože hra je optimalizovaná na Pentium | `./play.sh --cputype pentium mc2` |
| *„reducing the memory available to the game fixes that to a degree"* | `./play.sh --mem 8 mc2` |

To druhé jde **proti tomu, co jsem původně zkusil.** Vycházel jsem z hlášek
`CANT ALLOC CARPET MEMORY.` v binárce a paměť hře přidal na 31 MB — a ten běh
vydržel nejmíň ze všech (5:29). Fórum i ten jediný vzorek ukazují opačný směr,
takže `--mem 31` už není součástí `--safe`; z profilu zbylo jen vypnuté EMS
a pevné cykly.

**Pozor na `pentium_slow`**: to je název z DOSBoxu 0.74. dosbox-staging 0.82 ho
sice přijme, ale odpoví
`Setting 'cputype = pentium_slow' is deprecated, falling back to the alternate:
'cputype = pentium'`. Správně se to u nás jmenuje `pentium` a znamená to
„486 plus Pentium CPUID, chování Pentium CR registrů a instrukce RDTSC".

**Co už máme:** `cycles = fixed 128000` z fóra je stará syntaxe pro totéž, co
dělá `--safe` (`cpu_cycles_protected = 200000` je pevná hodnota už ze své
podstaty). `core = normal` jsme vyzkoušeli a je moc pomalé.

**Co ještě fórum říká o tom, kdy to padá:** nejvíc v **podzemních levelech**
a v přeplněných mapách (finální souboj s čarodějem, bonusový podzemní level).
Praktický důsledek: na tyhle úrovně se vyplatí přepnout klávesou **R** do
320×200. A že hra byla *„rushed to completion and released with many bugs
including a fatal bug"*, bez existující neoficiální opravy.

### Naměřeno

`./play.sh logs` vypíše tabulku všech běhů z `--log`. Zatím:

```
  zacatek        vydrzelo  nastaveni                          konec
  19:11:00           5:29  cyk 200000 ems false mem 31        ABORT: Illegal descriptor type 0x0 for int 6
  19:29:37           1:23  (dosbox-x)                         E_Exit: Triple fault reset call unexpectedly
  19:40:42          30:16  cpu pentium cyk 200000 ems false   ABORT: INT:Gate Selector points to illegal…
```

Plus dřívější pozorování bez logu: s původním nastavením 5–20 minut.

**`cputype = pentium` dalo 30 minut 16 sekund — nejdelší běh ze všech**, a to
i proti tomu, co hra zvládala předtím. Ten běh se lišil ještě ve dvou věcech:

- **žádný `Illegal write`** — ani jeden, zatímco pád v 19:16 jich měl 56
  v jediné milisekundě,
- jiná hláška na konci: `illegal descriptor with type 0x13` místo `0x0`.
  Typ 0x13 je platný **datový** deskriptor (expand-up, read/write, accessed) —
  brána přerušení tedy míří na datový segment místo na kódový. Předtím mířila
  na prázdný deskriptor. Obojí je rozbité, ale jinak.

Proto je `cputype = pentium` od té chvíle součástí `--safe`. Kromě naměřeného
výsledku je i věcně správnější: `auto` znamená „386_fast plus 486 CPUID
a chování 486 registrů CR", takže se hra z roku 1995 dívá na 486. `pentium`
přidá Pentium CPUID, chování Pentium CR registrů a instrukci RDTSC.

**Ale je to jeden vzorek.** Rozptyl je u téhle hry obrovský (5 až 20 minut se
stejným nastavením), takže jeden dlouhý běh nic nedokazuje. Než se z toho udělá
závěr, chce to **tenhle přesný příkaz zopakovat dvakrát třikrát**:

```bash
./play.sh --safe --log mc2
```

(Hledal jsem v `NETHERW.EXE`, jestli hra opravdu používá RDTSC nebo CPUID, aby
z hypotézy bylo vysvětlení. Hledání bajtových vzorů `0F 31` a `0F A2` je
v megabajtové binárce neprůkazné — tolik náhodných shod tam vyjde i ve
statistickém šumu. Takže zatím jen hypotéza.)

### Další na řadě

```bash
./play.sh --safe --mem 8 --log mc2                # ubrat paměť podle fóra
```

---

## Co se tím nespraví

Magic Carpet 2 padala i na dobovém hardwaru; je to její povaha, ne artefakt
emulace. Log z 31. 8. to potvrzuje: hra skočí do smetí, emulátor jen věrně
provede, co dostal. Takže nezávisle na nastavení: **ukládej často.** Hra má osm
slotů (`SAVE1.GAM` … `SAVE8.GAM` v `magic-carpet-2/GAME/NETHERW/SAVE/`).

Dobrá zpráva je, že dvojka si stav levelu odkládá i sama: soubory
`SLEV1/2.DAT`, `SMAP1/2.DAT` a `SVER1/2.DAT` ve stejném adresáři se za hry
střídavě přepisují, takže pád nemusí znamenat ztrátu celého sezení.

## Kde to zapsat natrvalo

Až se najde kombinace, která drží:

- rychlost CPU → `MC2_CYCLES` (a `MC2_SAFE_CYCLES`) na začátku `play.sh`
- `core`, `memsize`, `ems` → `dosbox-staging.conf`

Pak už není `--safe` potřeba.
