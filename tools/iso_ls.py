import sys, struct

path = sys.argv[1]
raw  = len(sys.argv) > 2 and sys.argv[2] == "raw"
SEC  = 2352 if raw else 2048
OFF  = 16   if raw else 0

f = open(path, "rb")
def sector(n):
    f.seek(n * SEC + OFF)
    return f.read(2048)

# Primary Volume Descriptor @ LBA 16
pvd = sector(16)
assert pvd[1:6] == b"CD001", "neni ISO9660 (%r)" % pvd[1:6]
print("Volume ID:", pvd[40:72].decode("ascii", "replace").strip())

# root directory record je v PVD na offsetu 156, 34 bajtu
root = pvd[156:190]
root_lba  = struct.unpack("<I", root[2:6])[0]
root_size = struct.unpack("<I", root[10:14])[0]

def listdir(lba, size, prefix=""):
    data = b"".join(sector(lba + i) for i in range((size + 2047) // 2048))
    p = 0
    while p < len(data):
        ln = data[p]
        if ln == 0:
            p = (p // 2048 + 1) * 2048          # skoc na dalsi sektor
            if p >= len(data): break
            continue
        rec    = data[p:p+ln]
        e_lba  = struct.unpack("<I", rec[2:6])[0]
        e_size = struct.unpack("<I", rec[10:14])[0]
        flags  = rec[25]
        nlen   = rec[32]
        name   = rec[33:33+nlen].decode("ascii", "replace")
        if name not in ("\x00", "\x01"):
            name = name.split(";")[0]
            if flags & 2:
                print(f"  {prefix}{name}/")
                listdir(e_lba, e_size, prefix + name + "/")
            else:
                print(f"  {prefix}{name}  ({e_size} B)")
        p += ln

listdir(root_lba, root_size)
