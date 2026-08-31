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

# Rychlost pro --safe. Smyslem je jen nahradit 'max' pevnym cislem, aby se
# pocet cyklu za behu nemenil - ne hru zpomalit. Dvojka rychlost hry na CPU
# nevaze, takze cislo urcuje jen plynulost: lad Ctrl+F12, dokud nejsi na tom,
# co jsi mel s 'max', a zapis si ho sem.
MC2_SAFE_CYCLES=200000

LOGDIR="$GAMES/logs"

FULLSCREEN=1
CYCLES=""
SHADER=""
STRETCH=0
TUNE=0
SAFE=0
LOG=0
CORE=""
CPUTYPE=""
MEM=""
EMS=""
EXTRA=()

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

    # Paky proti padum, viz docs/pady-a-stabilita.md. Nazvy klicu jsou ze
    # staging; dosbox-x ma 'core' a 'memsize' stejne, 'ems' taky.
    [[ -n $CORE ]] && args+=(-set "cpu core=$CORE")
    [[ -n $CPUTYPE ]] && args+=(-set "cpu cputype=$CPUTYPE")
    [[ -n $MEM  ]] && args+=(-set "dosbox memsize=$MEM")
    [[ -n $EMS  ]] && args+=(-set "dos ems=$EMS")
    (( ${#EXTRA[@]} )) && args+=("${EXTRA[@]}")

    local cmd
    for cmd in "$@"; do args+=(-c "$cmd"); done
    # Zaverecne 'exit' ukonci DOSBox, jakmile hra skonci. S --log se zamerne
    # nepridava: kdyz hra padne, zustane na DOS promptu videt hlaska DOS4GW,
    # ktera by jinak probliknula spolu s oknem.
    (( LOG )) || args+=(-c exit)

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
    (( LOG )) || exec "$BIN" "${args[@]}"

    # S --log nejde exec - vypis musi projit pres tee do souboru.
    mkdir -p "$LOGDIR"
    local log="$LOGDIR/$(date +%Y%m%d-%H%M%S)-${TARGET:-dosbox}.log"
    local rc=0
    "$BIN" "${args[@]}" 2>&1 | tee "$log" || rc=$?
    printf '\033[36m<<\033[0m konec (kod %d), log: %s\n' "$rc" "$log"
    grep -aE 'ABORT:|ERROR:' "$log" | tail -5 || true
    exit "$rc"
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
  crash       Vypise hlasku z posledniho padu DOSBoxu ze systemoveho coredumpu
  loginfo     Shrne nejnovejsi log z --log: rezimy obrazu, cteni mimo pamet,
              chybove hlasky
  logs        Tabulka vsech behu z --log: cim se lisily a jak dlouho vydrzely

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

  Proti padum (podrobne v docs/pady-a-stabilita.md):
      --safe       rezim pro stabilitu: cputype=pentium, bez EMS a u dvojky
                   pevne cykly misto 'max'
      --core C     jadro CPU: normal | dynamic | simple | auto. 'normal' je
                   diagnosticky (s nizkymi cykly), na hrani je moc pomale.
      --cputype C  typ CPU: auto | 386 | 486 | pentium | pentium_mmx.
                   Na foru GOG se u dvojky doporucuje 'pentium_slow', coz je
                   stary nazev - staging ho mapuje na 'pentium'.
      --mem N      memsize v MB (vychozi 16, staging nedoporucuje nad 31)
      --noems      vypne EMS - DOS4GW ho nepotrebuje
      --log        vypis DOSBoxu do logs/ a po skonceni hry necha okno na DOS
                   promptu, aby byla videt pripadna hlaska DOS4GW
      --set "S K=V"  jakekoli dalsi nastaveni DOSBoxu, lze opakovat, napr.
                   --set "dosbox machine=vesa_nolfb"
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
        --safe)        SAFE=1 ;;
        --log)         LOG=1 ;;
        --core)        CORE=${2:?chybi hodnota pro --core}; shift ;;
        --cputype)     CPUTYPE=${2:?chybi hodnota pro --cputype}; shift ;;
        --mem)         MEM=${2:?chybi hodnota pro --mem}; shift ;;
        --noems)       EMS=false ;;
        --set)         EXTRA+=(-set "${2:?chybi hodnota pro --set}"); shift ;;
        -h|--help)     usage; exit 0 ;;
        -*)            die "neznama volba: $1 (zkus --help)" ;;
        *)             TARGET=$1 ;;
    esac
    shift
done

# --safe je jen predvolba jednotlivych pak vys - kazda z nich se da prebit tim,
# ze ji uvedes zvlast (napr. --safe --mem 16).
#
# Jadro 'normal' tu ZAMERNE neni: DOSBox sam v logu hlasi, ze nad 20000 cyklu
# patri 'dynamic', a dvojka v 640x480 potrebuje nasobne vic - vysledkem je
# trhany zvuk. Zustava jako diagnosticky prepinac '--core normal' (s nizkymi
# cykly), ne jako nastaveni na hrani.
#
# memsize tu taky NENI. Puvodne to bylo 31 MB, ale ten beh vydrzel nejmin ze
# vsech (5:29) a na foru GOG se naopak pise, ze pomaha pameti hre UBRAT. Je to
# tedy samostatny pokus '--mem 8', ne soucast profilu.
# Viz docs/pady-a-stabilita.md
if (( SAFE )); then
    EMS=${EMS:-false}
    CPUTYPE=${CPUTYPE:-pentium}
    MC2_CYCLES=$MC2_SAFE_CYCLES
fi

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
    crash|loginfo)
            # Fatalni hlasky obou emulatoru. staging: 'ABORT:', dosbox-x:
            # 'E_Exit:' plus kaskada CPU_Exception -> double fault -> triple fault.
            FATAL="ABORT:|E_Exit|Triple fault|Double fault|CPU_Exception"
            FATAL="$FATAL|DYNX86|DYNREC|Can't run code|Illegal descriptor|Gate Selector"
            ;;&
    crash)  # Kdyz DOSBox pri padu hry sam skonci pres abort(), systemd ulozi
            # coredump. Metadata a zasobnik vytahneme z nej, plny text hlasky
            # radeji z logu (--log) - v coredumpu ji loguru necha zkracenou
            # ("ABORT: Illegal") a domyslet ji z retezcu v binarce vede na
            # falesne shody.
            #
            # POZOR: nikde tady nesmi byt 'grep -m1' za rourou - grep po nalezeni
            # skonci, roura dostane SIGPIPE a 'set -o pipefail' pak cely prikaz
            # vyhodnoti jako chybu. Prvni radek se proto bere 'sed -n 1p'.
            command -v coredumpctl >/dev/null || die "coredumpctl nenalezen"
            # coredumpctl hleda podle jmena procesu, ktere se u dosbox-x lisi
            COMM=$(basename "${DOSBOX_BIN:-dosbox}")
            # coredumpctl vypisuje zasobniky VSECH vlaken (u DOSBoxu jich jsou
            # desitky - mixer, pipewire, mesa, gomp). Zajima nas jen to prvni,
            # tedy to, ktere spadlo.
            INFO=$(coredumpctl info -1 "$COMM" 2>/dev/null | awk '
                /Timestamp:|Signal:|Command Line:/ { print; next }
                /Stack trace of thread/            { t++; next }
                t == 1 && /^ +#[0-9]/              { print }') || INFO=""
            if [[ -n $INFO ]]; then
                printf '%s\n' "$INFO"
            else
                echo "  (zadny coredump procesu '$COMM')"
            fi
            echo
            LAST=$(ls -1t "$LOGDIR"/*.log 2>/dev/null | sed -n 1p) || LAST=""
            MSG=""
            if [[ -n $LAST ]]; then
                MSG=$(grep -aE "$FATAL" "$LAST" | tail -3 |
                      sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:.]+ \| //; s/^LOG: //') || MSG=""
            fi
            if [[ -n $MSG ]]; then
                echo "  Hlaska z logu $(basename "$LAST"):"
                printf '%s\n' "$MSG" | sed 's/^/   /'
            else
                echo "  Hlaska pred padem (ctu coredump, chvilku to trva):"
                MSG=$(coredumpctl dump "$COMM" 2>/dev/null |
                      strings -n 6 | grep -aoE 'ABORT: .*' | tail -1) || MSG=""
                if [[ -n $MSG ]]; then
                    echo "   $MSG"
                    echo "   (loguru ji v coredumpu zkracuje - cely text da"
                    echo "    './play.sh loginfo', kdyz hru spustis s --log)"
                else
                    echo "   (nic k nalezeni - spust hru s --log)"
                fi
            fi
            echo
            echo "  Co s tim dal: docs/pady-a-stabilita.md" ;;
    loginfo) # Shrnuti logu z --log.
            #
            # "Illegal read"  = cteni z adresy, ktera v emulovane pameti neni.
            #                   U dvojky je to trvaly sum od prvni minuty, ve
            #                   vsech konfiguracich - samo o sobe to nic neznaci.
            # "Illegal write" = zapis mimo pamet. Ten se u dvojky objevil jen
            #                   v okamziku padu, takze tohle je ta zajimava vec.
            #
            # DOSBox vypise nejvys 1000 hlasek kazdeho druhu a pak uz jen mlci.
            LAST=$(ls -1t "$LOGDIR"/*.log 2>/dev/null | sed -n 1p)
            [[ -n ${LAST:-} ]] || die "v $LOGDIR nejsou zadne logy - spust hru s --log"
            printf '\033[36m>>\033[0m %s\n\n' "$LAST"
            # staging pise cely prikaz do logu, dosbox-x jen nazev configu
            sed -n 's/.*| arguments: /  spusteno: /p;s/^LOG: CONFIG: Loaded config file: /  config:   /p' \
                "$LAST" | sed -n 1p

            # Jak dlouho beh vydrzel - jmeno souboru je zacatek, mtime konec.
            # To je hlavni cislo, ktere se mezi pokusy porovnava.
            STAMP=$(basename "$LAST" | sed -E \
                's/^([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2}).*/\1-\2-\3 \4:\5:\6/')
            T0=$(date -d "$STAMP" +%s 2>/dev/null) || T0=""
            T1=$(stat -c %Y "$LAST")
            [[ -n $T0 ]] && printf '  vydrzelo: %d min %d s\n' \
                $(( (T1-T0)/60 )) $(( (T1-T0)%60 ))
            echo
            echo "  Rezimy obrazu:"
            grep -oE 'DISPLAY: (VGA|VESA) [0-9]+x[0-9]+' "$LAST" |
                sort | uniq -c | sed 's/^/   /' || echo "   (dosbox-x je neloguje)"

            for KIND in read write; do
                N=$(grep -c "Illegal $KIND" "$LAST" || true)
                echo
                if (( N == 0 )); then
                    echo "  Illegal $KIND: zadny"
                    continue
                fi
                echo "  Illegal $KIND: $N$( (( N >= 1000 )) && printf ' (strop vypisu - realne vic)')"
                # dosbox-staging pise ke kazde radce cas, dosbox-x ne
                TA=$(grep "Illegal $KIND" "$LAST" | sed -n 1p |
                     grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}' | sed -n 1p) || TA=""
                TB=$(grep "Illegal $KIND" "$LAST" | tail -1 |
                     grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}' | sed -n 1p) || TB=""
                [[ -n $TA ]] && echo "    kdy:    $TA - $TB"
                echo -n "    adresy: "
                grep -oE "Illegal $KIND (from|to) [0-9a-f]+" "$LAST" | awk '{print $4}' |
                    sort -u | tr '\n' ' ' | fold -s -w 60 | sed '2,$s/^/            /'
                echo
                echo "    mista v kodu hry (CS:IP):"
                grep "Illegal $KIND" "$LAST" | grep -oE 'CS:IP +[0-9a-f]+: +[0-9a-f]+' |
                    awk '{print $2 $3}' | sort | uniq -c | sort -rn | sed 's/^/     /'
            done

            echo
            # dosbox-x hlasi i spoustu necekanych volani BIOSu - sam o sobe
            # to nic neznamena, hra si oklepava hardware.
            if grep -qa "ERROR" "$LAST"; then
                echo
                echo "  Hlaseni emulatoru (dosbox-x):"
                grep -oaE "ERROR [A-Za-z0-9]+:.*" "$LAST" | sed -E 's/[0-9a-fx]{4,}/../g' |
                    sort | uniq -c | sort -rn | head -8 | sed 's/^/   /'
            fi

            echo
            if grep -qaE "$FATAL" "$LAST"; then
                echo "  Konec behu:"
                grep -aE "$FATAL" "$LAST" |
                    sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:.]+ \| //; s/^LOG: //' |
                    uniq | tail -5 | sed 's/^/   /'
            else
                echo "  Beh skoncil bez fatalni hlasky (ukoncen rucne, nebo hra vypadla do DOSu)."
            fi ;;
    logs)   # Porovnani vsech behu. Jedine cislo, ktere u padu neco znamena,
            # je 'vydrzelo' - jednotlive vzorky se hodne rozptyluji, takze
            # jeden dlouhy beh jeste nic nedokazuje.
            shopt -s nullglob
            FILES=("$LOGDIR"/*.log)
            shopt -u nullglob
            (( ${#FILES[@]} )) || die "v $LOGDIR nejsou zadne logy - spust hru s --log"
            printf '  %-14s %8s  %-34s %s\n' zacatek vydrzelo nastaveni konec
            printf '  %-14s %8s  %-34s %s\n' -------- -------- --------- -----
            for F in "${FILES[@]}"; do
                B=$(basename "$F")
                STAMP=$(sed -E 's/^([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2}).*/\1-\2-\3 \4:\5:\6/' <<<"$B")
                T0=$(date -d "$STAMP" +%s 2>/dev/null) || T0=""
                DUR="?"
                [[ -n $T0 ]] && DUR=$(printf '%d:%02d' $(( ($(stat -c %Y "$F")-T0)/60 )) \
                                                       $(( ($(stat -c %Y "$F")-T0)%60 )))
                # z prikazove radky vytahnout jen to, cim se behy lisi
                CFG=$(grep -oaE "(cpu_cycles_protected|core|cputype|memsize|ems)=[a-z0-9_]+" "$F" |
                      sed -e 's/cpu_cycles_protected=/cyk /' -e 's/cputype=/cpu /' \
                          -e 's/memsize=/mem /' -e 's/core=/jadro /' -e 's/ems=/ems /' |
                      sort -u | tr '\n' ' ') || CFG=""
                # dosbox-x prikazovou radku do logu nepise, pozna se podle configu
                [[ -z $CFG ]] && grep -qa 'dosbox-x.conf' "$F" && CFG="(dosbox-x)"
                END=$(grep -aoE "ABORT: .*|E_Exit: .*|Triple Fault" "$F" |
                      tail -1 | cut -c1-46) || END=""
                [[ -z $END ]] && END="(bez padu)"
                printf '  %-14s %8s  %-34s %s\n' "${B:9:2}:${B:11:2}:${B:13:2}" "$DUR" "${CFG:0:34}" "$END"
            done ;;
    lang)   rm -fv "$MCP/CARPET.CD/LANGUAGE.INF"
            echo "Volba jazyka smazana - hra se zepta pri dalsim spusteni." ;;
    *)      die "neznamy cil: $TARGET (zkus --help)" ;;
esac
