# Klávesy a sway

## „Ctrl+F11 / F12 mi nefunguje"

Klávesy fungují. Není jen vidět výsledek.

DOSBox zobrazuje aktuální počet cyklů **v titulku okna**:

```
DOS4GW.EXE - 99533 cycles/ms
```

Řídí to volba `titlebar` v sekci `[sdl]`, která má mimo jiné podhodnotu
`cycles`: *„If set to 'on' (default), show CPU cycles setting."* Pozor na
záměnu — není to klíč `cycles` ze sekce `[cpu]`, ten se ve stagingu jmenuje
`cpu_cycles` / `cpu_cycles_protected`.

Dvě věci to můžou schovat:

1. **Fullscreen** — titulek neexistuje.
2. **sway s `default_border pixel`** — kreslí jen tenký rámeček bez textu
   titulku. Takže ho neuvidíš ani v okenním režimu.

Druhý případ je zrádnější, protože přepnutí do okna nepomůže.

## Jak hodnotu přečíst

```bash
./play.sh cycles
```

Čte titulek přímo ze stromu compositoru přes `swaymsg -t get_tree`, takže na
vykreslený titulek vůbec nespoléhá.

```
  99533 cyklu/ms   <- DOS4GW.EXE - 99533 cycles/ms
```

## Past: DOSBox běží pod XWayland

Při hledání okna ve stromu sway **nestačí `app_id`** — DOSBox jede přes
XWayland, kde je `app_id` prázdné a identifikátor sedí ve
`window_properties.class`:

```
app_id=None   class='org.dosbox-staging.dosbox-staging'   shell='xwayland'
app_id=None   class='dosbox-x'                            shell='xwayland'
```

Hledat se tedy musí v obojím.

## Krok ladění

Výchozí `cycleup = 10` znamená +10 % na stisk — z 100000 je to +10000, ale
z nižších hodnot už je krok sotva znatelný. V configu je nastaveno symetrických 20 % oběma směry:

```ini
cycleup   = 20
cycledown = 20
```

Hodnoty pod 100 se berou jako procenta.

## Přehled kláves

| klávesa | funkce |
|---|---|
| Ctrl+F12 / Ctrl+F11 | zrychlit / zpomalit CPU o 20 % |
| Alt+F12 | turbo, dokud držíš |
| Alt+Enter | přepnout fullscreen |
| Ctrl+F10 | uvolnit myš |

Ověřeno, že sway na F11/F12 žádné vlastní bindingy nemá — kolize to nebyla.
