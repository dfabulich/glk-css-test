#!/usr/bin/env python3
"""Add font resources to an existing Blorb file.

cBlorb/inblorb know nothing about fonts, so build.sh packages the game as
usual and then runs this to append them:

  - one chunk per font resource, with resource usage 'Font' in the resource
    index. The chunk type is 'TTF '; the chunk body is the TrueType font
    file, unchanged.
  - one 'FDes' (font description) chunk giving the CSS family name, weight
    and style each font is offered under:

        4 bytes   'FDes'
        4 bytes   chunk length
        4 bytes   number of entries
        entries, each:
            4 bytes   resource number of the 'Font' resource
            2 bytes   weight (CSS numeric, 1-1000; 400 normal, 700 bold)
            2 bytes   style (0 normal, 1 italic, 2 oblique)
            4 bytes   length of the family name
            n bytes   family name, UTF-8

A variable font may be described more than once, giving one entry per
instance: repeat --font with the same NUMBER and PATH.

Usage:
  add_blorb_fonts.py IN.gblorb OUT.gblorb \\
      --font NUMBER PATH FAMILY WEIGHT STYLE [--font ...]

STYLE is normal, italic or oblique.  IN and OUT may be the same file.
"""

import argparse
import struct
import sys

STYLES = {"normal": 0, "italic": 1, "oblique": 2}


def chunk(chunk_id, body):
    data = chunk_id + struct.pack(">I", len(body)) + body
    if len(body) % 2:
        data += b"\0"
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("infile")
    parser.add_argument("outfile")
    parser.add_argument("--font", nargs=5, action="append", required=True,
                        metavar=("NUMBER", "PATH", "FAMILY", "WEIGHT", "STYLE"))
    args = parser.parse_args()

    with open(args.infile, "rb") as f:
        blorb = f.read()

    if blorb[0:4] != b"FORM" or blorb[8:12] != b"IFRS":
        sys.exit(f"{args.infile}: not a Blorb file")
    if blorb[12:16] != b"RIdx":
        sys.exit(f"{args.infile}: resource index is not the first chunk")

    ridx_len = struct.unpack(">I", blorb[16:20])[0]
    count = struct.unpack(">I", blorb[20:24])[0]
    entries = [struct.unpack(">4sII", blorb[24 + i * 12:36 + i * 12]) for i in range(count)]
    rest = blorb[20 + ridx_len + (ridx_len % 2):]

    fonts = {}  # resource number -> (path, data)
    descriptors = []
    for number, path, family, weight, style in args.font:
        number, weight = int(number), int(weight)
        if style not in STYLES:
            sys.exit(f"style must be one of {', '.join(STYLES)}, got {style!r}")
        if not 1 <= weight <= 1000:
            sys.exit(f"weight must be 1-1000, got {weight}")
        if not path.lower().endswith(".ttf"):
            sys.exit(f"{path}: expected a .ttf file")
        if number in fonts:
            if fonts[number][0] != path:
                sys.exit(f"Font resource {number} given two different files")
        else:
            if any(usage == b"Font" and n == number for usage, n, _ in entries):
                sys.exit(f"{args.infile} already has Font resource {number}")
            with open(path, "rb") as f:
                fonts[number] = (path, f.read())
        descriptors.append((number, family, weight, STYLES[style]))

    # The index grows by 12 bytes per font, which moves every chunk after it.
    shift = 12 * len(fonts)
    new_count = count + len(fonts)
    header_len = 12 + 8 + 4 + 12 * new_count
    offset = header_len + len(rest)

    new_entries = [(usage, number, start + shift) for usage, number, start in entries]
    font_chunks = b""
    for number, (_path, data) in fonts.items():
        new_entries.append((b"Font", number, offset + len(font_chunks)))
        font_chunks += chunk(b"TTF ", data)

    fdes = struct.pack(">I", len(descriptors))
    for number, family, weight, style in descriptors:
        name = family.encode("utf-8")
        fdes += struct.pack(">IHHI", number, weight, style, len(name)) + name

    ridx = struct.pack(">I", new_count) + b"".join(
        struct.pack(">4sII", usage, number, start) for usage, number, start in new_entries)
    body = b"IFRS" + chunk(b"RIdx", ridx) + rest + font_chunks + chunk(b"FDes", fdes)

    with open(args.outfile, "wb") as f:
        f.write(b"FORM" + struct.pack(">I", len(body)) + body)


if __name__ == "__main__":
    main()
