#!/usr/bin/env python3
from __future__ import annotations
import argparse
import struct
import sys
from pathlib import Path

MH_MAGIC_64 = 0xFEEDFACF
LC_DYLD_CHAINED_FIXUPS = 0x80000034
DYLD_CHAINED_IMPORT = 1
WEAK_IMPORT_BIT = 1 << 8


def weaken(binary: Path, fragments: list[str]) -> list[str]:
    data = bytearray(binary.read_bytes())
    magic, _, _, _, command_count, _, _, _ = struct.unpack_from("<IiiIIIII", data, 0)
    if magic != MH_MAGIC_64:
        raise SystemExit(f"{binary}: not a thin 64-bit Mach-O file")
    offset = 32
    location = None
    for _ in range(command_count):
        command, size = struct.unpack_from("<II", data, offset)
        if command == LC_DYLD_CHAINED_FIXUPS:
            location = struct.unpack_from("<II", data, offset + 8)
        offset += size
    if location is None:
        raise SystemExit(f"{binary}: no chained fixups to patch")
    base, _ = location
    _, _, imports, symbols, count, imports_format, _ = struct.unpack_from("<7I", data, base)
    if imports_format != DYLD_CHAINED_IMPORT:
        raise SystemExit(f"{binary}: unsupported import format {imports_format}")
    patched = []
    for index in range(count):
        position = base + imports + 4 * index
        word = struct.unpack_from("<I", data, position)[0]
        start = base + symbols + (word >> 9)
        name = bytes(data[start:data.index(b"\0", start)]).decode()
        if any(fragment in name for fragment in fragments) and not word & WEAK_IMPORT_BIT:
            struct.pack_into("<I", data, position, word | WEAK_IMPORT_BIT)
            patched.append(name)
    if patched:
        binary.write_bytes(data)
    return patched


def main() -> int:
    parser = argparse.ArgumentParser(description="Mark matching imported symbols of a Mach-O framework as weak so it still loads on older systems.")
    parser.add_argument("binary", type=Path)
    parser.add_argument("fragments", nargs="+", help="substrings of the symbol names to make weak")
    arguments = parser.parse_args()
    patched = weaken(arguments.binary, arguments.fragments)
    for name in patched:
        print("weak import:", name)
    print(f"{len(patched)} imports made weak in {arguments.binary.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
