#!/usr/bin/env python3
"""
Obraceni osy Y mysi v Magic Carpet 1 / Hidden Worlds / Magic Carpet 2.

Hry nemaji zadnou volbu na invertaci a DOSBoxi 'mouse_sensitivity = 100,-100'
by obratilo osu globalne, tedy i kurzor v menu. Tenhle nastroj proto meni
primo herni kod: v obou vetvich (low-res / hi-res) je jedina instrukce
'neg' nad Y-souradnici mysi, ktera se nahradi dvema NOPy.

    2b024:  sub   edx,0x6400   ; -25600 = 200*128 -> stred obrazovky
    2b02a:  mov   ecx,0xc8     ; 200 radku = low-res
    2b02f:  neg   edx          ; <<< tohle se nahradi za 90 90
    ...
    2b07c:  cmp   ebx,-127     ; spolecne klampovani na -127..+127

Menu kurzor timhle kodem neprochazi (pouziva absolutni pozici, ne delta
orezanou na +-127), takze se zmena projevi jen za letu.

Binarky jsou uvnitr CD image (game.gog), ktery musi zustat namountovany
kvuli datum a CD hudbe - patchuje se proto primo v image. Kazdy zapis je
jen 2 bajty a je plne vratny.
"""

import argparse
import hashlib
import struct
import sys
from pathlib import Path

GAMES = Path(__file__).resolve().parent

NOP = b"\x90\x90"

# Kazdy zasah je popsan jako (offset, puvodni bajty, bajty pred, bajty za).
# Kontext slouzi jako podpis: overi, ze jsme na spravnem miste ve spravne
# verzi hry, a funguje i po zapatchovani - na rozdil od celofiloveho MD5,
# ktery se zmenou samozrejme prestane sedet.
SPOT = lambda off, orig, before, after: {
    "off": off, "orig": bytes.fromhex(orig),
    "before": bytes.fromhex(before), "after": bytes.fromhex(after),
}

# jmeno -> (image, cesta v ISO, raw sektory?, MD5 nedotcene verze, vetve)
TARGETS = {
    "carpet": (
        GAMES / "magic-carpet-plus/CARPET.CD/game.gog", "CARPET/CARPET.EXE", False,
        "0763e103ed4935276050a0690f464850",
        {"low-res": SPOT(0x2B02F, "f7da", "b9c8000000", "89c389d0c1"),
         "hi-res":  SPOT(0x2B07A, "f7d9", "1ff7f989c1", "83fb817d05")},
    ),
    "hidden": (
        GAMES / "magic-carpet-plus/CARPET.CD/game.gog", "CARPET/HIDDEN.EXE", False,
        "22ba3fb0df2d9f89c9fb31fe5dbcd638",
        {"low-res": SPOT(0x2B22F, "f7da", "b9c8000000", "89c389d0c1"),
         "hi-res":  SPOT(0x2B27A, "f7d9", "1ff7f989c1", "83fb817d05")},
    ),
    "netherw": (
        GAMES / "magic-carpet-2/game.gog", "NETHERW.EXE", True,
        "ce911718f58f5376ea939ae48c945fec",
        {"low-res": SPOT(0x3B8AD, "f7da", "64000089c3", "b9c8000000"),
         "hi-res":  SPOT(0x3B8F3, "f7d9", "1ff7f989c1", "83fb817d05")},
    ),
}


class Iso:
    """Cte ISO9660, vcetne raw obrazu MODE1/2352 (kde ma sektor 2352 B
    a uzitecna data zacinaji na offsetu 16)."""

    def __init__(self, path, raw):
        self.path = Path(path)
        self.sec, self.off = (2352, 16) if raw else (2048, 0)
        self.f = open(self.path, "rb")

    def sector(self, n):
        self.f.seek(n * self.sec + self.off)
        return self.f.read(2048)

    def find(self, want):
        """Vrati (lba, velikost) souboru, nebo None."""
        pvd = self.sector(16)
        if pvd[1:6] != b"CD001":
            raise SystemExit(f"{self.path}: neni ISO9660")
        root = pvd[156:190]
        want = want.upper()

        def walk(lba, size, prefix=""):
            data = b"".join(self.sector(lba + i) for i in range((size + 2047) // 2048))
            p = 0
            while p < len(data):
                ln = data[p]
                if ln == 0:
                    p = (p // 2048 + 1) * 2048
                    if p >= len(data):
                        break
                    continue
                rec = data[p:p + ln]
                e_lba = struct.unpack("<I", rec[2:6])[0]
                e_size = struct.unpack("<I", rec[10:14])[0]
                flags, nlen = rec[25], rec[32]
                name = rec[33:33 + nlen].decode("ascii", "replace")
                if name not in ("\x00", "\x01"):
                    full = prefix + name.split(";")[0]
                    if flags & 2:
                        r = walk(e_lba, e_size, full + "/")
                        if r:
                            return r
                    elif full.upper() == want:
                        return e_lba, e_size
                p += ln
            return None

        return walk(struct.unpack("<I", root[2:6])[0],
                    struct.unpack("<I", root[10:14])[0])

    def phys(self, lba, file_off):
        """Offset bajtu v souboru -> fyzicky offset v image."""
        return (lba + file_off // 2048) * self.sec + self.off + file_off % 2048

    def read_at(self, lba, file_off, n):
        # po bajtech, aby to fungovalo i pres hranici sektoru
        out = bytearray()
        for i in range(n):
            self.f.seek(self.phys(lba, file_off + i))
            out += self.f.read(1)
        return bytes(out)

    def write_at(self, lba, file_off, data):
        with open(self.path, "r+b") as w:
            for i, b in enumerate(data):
                w.seek(self.phys(lba, file_off + i))
                w.write(bytes([b]))
            w.flush()
        # ctecí handle ma stara data v bufferu - znovu otevrit, jinak by
        # kontrola po zapisu cetla predchozi stav
        self.f.close()
        self.f = open(self.path, "rb")

    def extract(self, lba, size):
        return b"".join(self.sector(lba + i)
                        for i in range((size + 2047) // 2048))[:size]


def inspect(name):
    image, inner, raw, _md5, spots = TARGETS[name]   # _md5 uziva az cmd_status
    if not image.exists():
        return None, f"chybi image {image}"
    iso = Iso(image, raw)
    hit = iso.find(inner)
    if not hit:
        return None, f"{inner} nenalezen v {image.name}"
    lba, size = hit

    state = {}
    for branch, sp in spots.items():
        off = sp["off"]
        before = iso.read_at(lba, off - len(sp["before"]), len(sp["before"]))
        after = iso.read_at(lba, off + 2, len(sp["after"]))
        if before != sp["before"] or after != sp["after"]:
            return None, (f"{branch}: okoli na 0x{off:x} nesouhlasi "
                          f"- jina verze hry, nepatchovat "
                          f"(before {before.hex()} / after {after.hex()})")
        cur = iso.read_at(lba, off, 2)
        state[branch] = ("obraceno" if cur == NOP else
                         "puvodni" if cur == sp["orig"] else
                         f"NEZNAME ({cur.hex(' ')})")
    return (iso, lba, spots, state), None


def cmd_status(names):
    for name in names:
        res, err = inspect(name)
        if err:
            print(f"  {name:9} CHYBA: {err}")
            continue
        iso, lba, _, state = res
        summary = ", ".join(f"{b}={s}" for b, s in sorted(state.items()))

        # Kdyz je vse v puvodnim stavu, jde overit i celofilovy MD5 - potvrdi,
        # ze jde presne o tu verzi hry, pro kterou byly offsety zjisteny.
        # Hashuje se jen samotne EXE (~1 MB), ne cely image.
        note = ""
        if all(v == "puvodni" for v in state.values()):
            image, inner, raw, md5, _ = TARGETS[name]
            hit = iso.find(inner)
            got = hashlib.md5(iso.extract(*hit)).hexdigest()
            note = "  [MD5 overeno]" if got == md5 else f"  [POZOR: jiny MD5 {got}]"

        print(f"  {name:9} {summary}{note}")


def apply(names, revert):
    want = "puvodni" if revert else "obraceno"
    for name in names:
        res, err = inspect(name)
        if err:
            print(f"  {name:9} CHYBA: {err}")
            continue
        iso, lba, spots, state = res

        unknown = [b for b, s in state.items() if s.startswith("NEZNAME")]
        if unknown:
            print(f"  {name:9} PRESKOCENO - neocekavane bajty v {unknown} "
                  f"(nepatchovat naslepo)")
            continue

        done = []
        for branch, sp in sorted(spots.items()):
            if state[branch] == want:
                continue
            off = sp["off"]
            expect = sp["orig"] if revert else NOP
            iso.write_at(lba, off, expect)
            got = iso.read_at(lba, off, 2)
            if got != expect:
                print(f"  {name:9} CHYBA zapisu na 0x{off:x}: "
                      f"{got.hex(' ')} != {expect.hex(' ')}")
                return 1
            done.append(branch)

        print(f"  {name:9} {'vraceno' if revert else 'obraceno'}: "
              f"{', '.join(done) if done else 'uz to tak bylo'}")
    return 0


def main():
    ap = argparse.ArgumentParser(
        description="Obraceni osy Y mysi v Magic Carpet (jen za letu, ne v menu).")
    ap.add_argument("action", choices=("status", "on", "off"),
                    help="status = vypis stav, on = obratit, off = vratit")
    ap.add_argument("games", nargs="*", default=None,
                    help=f"ktere hry ({', '.join(TARGETS)}); vychozi vsechny")
    a = ap.parse_args()

    names = a.games or list(TARGETS)
    for n in names:
        if n not in TARGETS:
            sys.exit(f"neznama hra: {n} (znam: {', '.join(TARGETS)})")

    if a.action == "status":
        cmd_status(names)
        return 0
    return apply(names, revert=(a.action == "off"))


if __name__ == "__main__":
    sys.exit(main())
