#!/usr/bin/env bash
#
# Launcher pro Magic Carpet Plus a Magic Carpet 2: The Netherworlds (GOG, DOS)
# Obe hry jsou pro MS-DOS, takze je spousti DOSBox.
#
# Pouziti:  ./play.sh [volby] [cil]
# Bez cile se zobrazi menu.

set -euo pipefail

GAMES="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MCP="$GAMES/magic-carpet-plus"
MC2="$GAMES/magic-carpet-2"

# Vychozi rychlost CPU zvlast pro kazdou hru - obe na to reaguji jinak.
#
# Magic Carpet 1 (1994) vaze rychlost hry na vykon CPU, takze pri 'max' bezi
# nehratelne rychle. 100000 ~ Pentium MMX-166 - hodnota vyladena rucne pres
# Ctrl+F12 ve vyssim rozliseni (namereno 99533, zaokrouhleno).
# Orientacni tabulka: 486DX-33 12000 | 486DX2-66 25000 | Pentium 90 50000
#                     Pentium MMX-166 100000 | Pentium II 300 200000
MCP_CYCLES=100000

# Magic Carpet 2 (1995) uz je na rychlosti CPU nezavisly a v SVGA si vezme,
# co dostane.
MC2_CYCLES=max

FULLSCREEN=1
CYCLES=""
SHADER=""
STRETCH=0
TUNE=0

die() { printf '\033[31mChyba:\033[0m %s\n' "$*" >&2; exit 1; }

# --- vyber emulatoru -------------------------------------------------------
# DOSBOX_BIN=... prebije autodetekci. Preferuje se dosbox-staging.
pick_emulator() {
    if [[ -n "${DOSBOX_BIN:-}" ]]; then
        command -v "$DOSBOX_BIN" >/dev/null || die "DOSBOX_BIN='$DOSBOX_BIN' nenalezen"
        BIN="$DOSBOX_BIN"
    elif command -v dosbox >/dev/null 2>&1 && dosbox --version 2>&1 | grep -qi staging; then
        BIN=dosbox
    elif command -v dosbox-x >/dev/null 2>&1; then
        BIN=dosbox-x
    elif command -v dosbox >/dev/null 2>&1; then
        BIN=dosbox
    else
        die "nenalezen zadny DOSBox. Nainstaluj:  sudo dnf install dosbox-staging"
    fi

    if "$BIN" --version 2>&1 | grep -qi staging; then
        CONF="$GAMES/dosbox-staging.conf"
    else
        CONF="$GAMES/dosbox-x.conf"
    fi
    [[ -f "$CONF" ]] || die "chybi config $CONF"
}

# --- spusteni --------------------------------------------------------------
# run <pracovni_adresar> <prikaz>...
run() {
    local dir=$1; shift
    [[ -d $dir ]] || die "chybi adresar hry: $dir"

    local args=(-conf "$CONF")
    (( FULLSCREEN )) || args+=(-set "sdl fullscreen=false")
    if [[ -n $CYCLES ]]; then
        # staging pouziva cpu_cycles_protected, dosbox-x stare 'cycles'
        if [[ $CONF == *staging* ]]; then
            args+=(-set "cpu cpu_cycles_protected=$CYCLES")
        else
            args+=(-set "cpu cycles=$CYCLES")
        fi
    fi
    [[ -n $SHADER ]] && args+=(-set "render glshader=$SHADER")
    if (( STRETCH )) && [[ $CONF == *staging* ]]; then
        # aspect=stretch dopocita pomer z viewportu => vyplni cele 16:9,
        # ale obraz je deformovany (4:3 roztazene o tretinu do sirky)
        args+=(-set "render aspect=stretch" -set "render viewport=100%")
    fi
    local cmd
    for cmd in "$@"; do args+=(-c "$cmd"); done
    args+=(-c exit)

    if (( TUNE )); then
        cat <<'TIP'

  Ladeni rychlosti CPU
  --------------------
  Bezi v OKNE zamerne: aktualni pocet cyklu je videt v TITULKU okna,
  ktery ve fullscreenu neexistuje. Proto to driv vypadalo, ze klavesy nedelaji nic.

    Ctrl+F12   zrychlit o 20 %      Ctrl+F11   zpomalit o 20 %
    Alt+F12    turbo (drz stisknute)

  Az najdes svoje cislo, uloz ho do MCP_CYCLES / MC2_CYCLES v play.sh.

TIP
    fi
    printf '\033[36m>>\033[0m %s  (%s)\n' "$dir" "$BIN"
    cd "$dir"
    exec "$BIN" "${args[@]}"
}

# Magic Carpet Plus: C: = koren hry (zapisovatelny: SAVE, SNDSETUP.DAT),
# D: = CD image. Koreny CARPET.EXE je launcher, ktery podle CARPET.CD\CP.DAT
# nabidne Magic Carpet nebo datadisk The Hidden Worlds.
mcp_run() {
    : "${CYCLES:=$MCP_CYCLES}"
    run "$MCP" \
        'mount C "."' \
        'imgmount D "CARPET.CD/game.gog" -t iso -fs iso' \
        'D:' "$@"
}

# Magic Carpet 2: D: = CD image (game.ins je CUE se stopami CD audio hudby),
# C: = GAME/ pro ulozene pozice a CONFIG.DAT.
mc2_run() {
    : "${CYCLES:=$MC2_CYCLES}"
    run "$MC2" \
        'imgmount D "game.ins" -t iso -fs iso' \
        'mount C "GAME"' \
        'D:' "$@"
}

usage() {
    cat <<'EOF'
Pouziti: ./play.sh [volby] [cil]

Cile:
  mc          Magic Carpet Plus  (launcher: Magic Carpet / The Hidden Worlds)
  hidden      Magic Carpet: The Hidden Worlds - primo, bez launcheru
  mc2         Magic Carpet 2: The Netherworlds
  setup       Nastaveni zvuku pro Magic Carpet Plus (SELECT.EXE)
  setup2      Nastaveni zvuku pro Magic Carpet 2 (SETSOUND.EXE)
  lang        Smaze volbu jazyka v MC Plus (pri dalsim spusteni se zepta znovu)
  cycles      Vypise aktualni pocet cyklu bezici hry (cte titulek okna ze sway,
              protoze 'default_border pixel' ho na obrazovce nevykresluje)

Volby:
  -w, --windowed   spustit v okne misto fullscreenu
  -c, --cycles N   docasne prebije rychlost CPU: cislo nebo 'max'
                   Vychozi: Magic Carpet 1 = 100000 (~Pentium MMX-166),
                   Magic Carpet 2 = max.
                   486DX-33 12000 | 486DX2-66 25000 | Pentium 90 50000
                   Pentium MMX-166 100000 | Pentium II 300 200000
  -s, --shader S   docasne prebije glshader (jen dosbox-staging), napr.:
                   none, interpolation/sharp, crt-auto
      --stretch    roztahne obraz na celych 16:9 (vyplni 4K panel beze zbytku,
                   ale deformuje - postavy budou o tretinu sirsi).
                   Jen dosbox-staging, na dosbox-x se ignoruje.
      --tune       ladeni rychlosti: spusti v okne, kde je v titulku videt
                   aktualni pocet cyklu (ve fullscreenu titulek neni!)
  -h, --help       tato napoveda

Promenne:
  DOSBOX_BIN       vynuti konkretni emulator, napr. DOSBOX_BIN=dosbox-x ./play.sh mc2

V DOSBoxu:  Ctrl+F11 / Ctrl+F12 = zpomalit / zrychlit CPU (krok 20 %)
            Alt+F12 = turbo, dokud drzis         POZOR: zmenu poznas jen
            podle titulku okna, ktery ve fullscreenu neni - viz --tune
            Alt+Enter = prepnout fullscreen,  Ctrl+F10 = uvolnit mys
EOF
}

menu() {
    echo
    echo "  Magic Carpet - vyber hru"
    echo "  ------------------------"
    echo "   1) Magic Carpet Plus"
    echo "   2) Magic Carpet: The Hidden Worlds"
    echo "   3) Magic Carpet 2: The Netherworlds"
    echo "   4) Nastaveni zvuku - Magic Carpet Plus"
    echo "   5) Nastaveni zvuku - Magic Carpet 2"
    echo "   q) Konec"
    echo
    read -rp "  Volba: " ch
    case $ch in
        1) TARGET=mc ;;  2) TARGET=hidden ;;  3) TARGET=mc2 ;;
        4) TARGET=setup ;; 5) TARGET=setup2 ;;
        q|Q|"") exit 0 ;;
        *) die "neplatna volba: $ch" ;;
    esac
}

# --- parsovani argumentu ---------------------------------------------------
TARGET=""
while (( $# )); do
    case $1 in
        -w|--windowed) FULLSCREEN=0 ;;
        -c|--cycles)   CYCLES=${2:?chybi hodnota pro --cycles}; shift ;;
        -s|--shader)   SHADER=${2:?chybi hodnota pro --shader}; shift ;;
        --stretch)     STRETCH=1 ;;
        --tune)        FULLSCREEN=0; TUNE=1 ;;
        -h|--help)     usage; exit 0 ;;
        -*)            die "neznama volba: $1 (zkus --help)" ;;
        *)             TARGET=$1 ;;
    esac
    shift
done

pick_emulator
[[ -n $TARGET ]] || menu

case $TARGET in
    mc)     mcp_run 'cls' 'CARPET.EXE' ;;
    hidden) mcp_run 'cd \CARPET' 'cls' 'DOS4GW HIDDEN' ;;
    setup)  mcp_run 'cd \CARPET' 'cls' 'DOS4GW SELECT' ;;
    mc2)    mc2_run 'cls' 'NETHERW.EXE' ;;
    setup2) mc2_run 'cls' 'SETSOUND.EXE' ;;
    cycles) # Sway s "default_border pixel" titulky nevykresluje, ale okno je
            # ma. DOSBox bezi pres XWayland, takze identifikator neni v app_id,
            # ale ve window_properties.class - hledame v obou.
            command -v swaymsg >/dev/null || die "swaymsg nenalezen (nejedes ve sway?)"
            swaymsg -t get_tree | python3 -c "
import json, re, sys

def walk(n):
    yield n
    for key in (\"nodes\", \"floating_nodes\"):
        for c in n.get(key, []):
            yield from walk(c)

hits = []
for n in walk(json.load(sys.stdin)):
    ident = (n.get(\"app_id\") or \"\") + ((n.get(\"window_properties\") or {}).get(\"class\") or \"\")
    if \"dosbox\" in ident.lower():
        hits.append(n.get(\"name\") or \"\")

if not hits:
    print(\"  (zadne okno DOSBoxu nebezi)\")
for title in hits:
    m = re.search(r\"([0-9]+) cycles/ms\", title)
    if m:
        print(\"  \" + m.group(1) + \" cyklu/ms   <- \" + title)
    else:
        print(\"  \" + title)
" ;;
    lang)   rm -fv "$MCP/CARPET.CD/LANGUAGE.INF"
            echo "Volba jazyka smazana - hra se zepta pri dalsim spusteni." ;;
    *)      die "neznamy cil: $TARGET (zkus --help)" ;;
esac
