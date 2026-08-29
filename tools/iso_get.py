import sys, struct, os

path, want, out = sys.argv[1], sys.argv[2].upper(), sys.argv[3]
raw = len(sys.argv) > 4 and sys.argv[4] == "raw"
SEC, OFF = (2352, 16) if raw else (2048, 0)
f = open(path, "rb")

def sector(n):
    f.seek(n * SEC + OFF)
    return f.read(2048)

pvd = sector(16)
assert pvd[1:6] == b"CD001"
root = pvd[156:190]

def find(lba, size, prefix=""):
    data = b"".join(sector(lba + i) for i in range((size + 2047) // 2048))
    p = 0
    while p < len(data):
        ln = data[p]
        if ln == 0:
            p = (p // 2048 + 1) * 2048
            if p >= len(data): break
            continue
        rec = data[p:p+ln]
        e_lba  = struct.unpack("<I", rec[2:6])[0]
        e_size = struct.unpack("<I", rec[10:14])[0]
        flags, nlen = rec[25], rec[32]
        name = rec[33:33+nlen].decode("ascii", "replace")
        if name not in ("\x00", "\x01"):
            full = prefix + name.split(";")[0]
            if flags & 2:
                r = find(e_lba, e_size, full + "/")
                if r: return r
            elif full.upper() == want:
                return e_lba, e_size
        p += ln
    return None

hit = find(struct.unpack("<I", root[2:6])[0], struct.unpack("<I", root[10:14])[0])
if not hit:
    sys.exit(f"nenalezeno: {want}")
lba, size = hit
buf = b"".join(sector(lba + i) for i in range((size + 2047) // 2048))[:size]
open(out, "wb").write(buf)
print(f"{want}: {size} B -> {out}")
