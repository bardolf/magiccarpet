#!/usr/bin/env bash
#
# Rozbali GOG offline instalatory Magic Carpet Plus / Magic Carpet 2
# a srovna adresarovou strukturu tak, jak ji hry ocekavaji.
#
# Pouziti:  ./setup.sh setup_magic_carpet_plus_*.exe setup_magic_carpet_2_*.exe
#           (staci i jen jeden z nich)

set -euo pipefail

DEST="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

die()  { printf '\033[31mChyba:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[36m>>\033[0m %s\n' "$*"; }

command -v innoextract >/dev/null || die "chybi innoextract (sudo dnf install innoextract)"
(( $# )) || die "zadej cesty ke GOG instalatorum. Viz hlavicku skriptu."

for exe in "$@"; do
    [[ -f $exe ]] || die "neexistuje: $exe"

    size=$(stat -c%s "$exe")
    if (( size < 5*1024*1024 )); then
        die "$(basename "$exe") ma jen $((size/1024)) KB - to je stahovaci stub
     GOG Galaxy, ne instalator hry. Stahni 'offline backup game installer'."
    fi

    case "$(basename "$exe")" in
        *carpet_2*|*carpet2*)  name=magic-carpet-2 ;;
        *carpet_plus*|*plus*)  name=magic-carpet-plus ;;
        *) die "nepoznavam $(basename "$exe") - cekam setup_magic_carpet_plus_* nebo setup_magic_carpet_2_*" ;;
    esac

    info "rozbaluji $(basename "$exe") -> $name/"
    rm -rf "${DEST:?}/$name"
    innoextract -m -d "$DEST/$name" "$exe" >/dev/null

    # innoextract necha 'app/' stranou, ale instalator ho ma nasypat do korene
    # hry. Bez toho chybi MC2 startovni CONFIG.DAT a ulozene pozice.
    info "srovnavam strukturu $name/"
    cd "$DEST/$name"
    if [[ $name == magic-carpet-plus ]]; then
        mkdir -p CARPET.CD/SAVE
    else
        mkdir -p GAME/NETHERW/{SAVE,LANGUAGE,SHOTS}
        [[ -d __support/save/GAME/NETHERW ]] &&
            cp -rn __support/save/GAME/NETHERW/. GAME/NETHERW/
    fi
    cp -n app/goggame-*.ico . 2>/dev/null || true
    rm -rf app
    cd "$DEST"
done

echo
info "hotovo. Spust:  ./play.sh"
