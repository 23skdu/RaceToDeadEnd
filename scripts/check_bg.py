#!/usr/bin/env python3
"""Inspect and verify alpha transparency on enemy sprite PNG assets."""

from pathlib import Path
import struct
import sys
import zlib

try:
    from PIL import Image
except ImportError:
    Image = None

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SPRITE_DIR = ROOT / "assets" / "sprites" / "enemies"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _paeth_predictor(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def _unfilter_scanline(
    filter_type: int, raw: bytes, prev: bytearray, bpp: int
) -> bytearray:
    row = bytearray(raw)
    n = len(row)
    if filter_type == 0:
        return row
    if filter_type == 1:
        for i in range(bpp, n):
            row[i] = (row[i] + row[i - bpp]) & 0xFF
        return row
    if filter_type == 2:
        for i in range(n):
            row[i] = (row[i] + prev[i]) & 0xFF
        return row
    if filter_type == 3:
        for i in range(n):
            left = row[i - bpp] if i >= bpp else 0
            row[i] = (row[i] + ((left + prev[i]) >> 1)) & 0xFF
        return row
    if filter_type == 4:
        for i in range(n):
            left = row[i - bpp] if i >= bpp else 0
            up = prev[i]
            up_left = prev[i - bpp] if i >= bpp else 0
            row[i] = (row[i] + _paeth_predictor(left, up, up_left)) & 0xFF
        return row
    raise ValueError(f"Unsupported PNG filter type: {filter_type}")


def _decode_png_rgba_stdlib(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"Not a valid PNG file: {path}")

    pos = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = interlace = 0
    ihdr_seen = False
    idat_chunks: list[bytes] = []
    palette: bytes = b""
    trns: bytes = b""

    while pos + 8 <= len(data):
        length, chunk_type = struct.unpack(">I4s", data[pos : pos + 8])
        pos += 8
        chunk_data = data[pos : pos + length]
        pos += length + 4  # skip chunk data + CRC

        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, comp, filt, interlace = struct.unpack(
                ">IIBBBBB", chunk_data
            )
            if comp != 0 or filt != 0:
                raise ValueError(f"Unsupported PNG compression/filter in {path}")
            if interlace != 0:
                raise ValueError(
                    f"Interlaced PNG {path} requires Pillow (run 'make deps-python')"
                )
            ihdr_seen = True
        elif chunk_type == b"PLTE":
            palette = chunk_data
        elif chunk_type == b"tRNS":
            trns = chunk_data
        elif chunk_type == b"IDAT":
            idat_chunks.append(chunk_data)
        elif chunk_type == b"IEND":
            break

    if not ihdr_seen or width <= 0 or height <= 0:
        raise ValueError(f"Missing or invalid IHDR in {path}")

    channels_by_type = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}
    if color_type not in channels_by_type:
        raise ValueError(f"Unsupported PNG color type {color_type} in {path}")
    if bit_depth not in (8, 16) or (color_type == 3 and bit_depth != 8):
        raise ValueError(
            f"PNG bit depth {bit_depth} (type {color_type}) in {path} requires Pillow"
        )

    channels = channels_by_type[color_type]
    bytes_per_sample = bit_depth // 8
    bpp = channels * bytes_per_sample
    stride = width * bpp
    raw = zlib.decompress(b"".join(idat_chunks))
    expected_len = height * (1 + stride)
    if len(raw) < expected_len:
        raise ValueError(f"Truncated PNG image data in {path}")

    rgba = bytearray(width * height * 4)
    prev = bytearray(stride)
    step = bytes_per_sample

    if color_type == 3:
        palette_rgba = [
            (
                palette[i * 3],
                palette[i * 3 + 1],
                palette[i * 3 + 2],
                trns[i] if i < len(trns) else 255,
            )
            for i in range(len(palette) // 3)
        ]
    elif color_type == 0 and len(trns) >= 2:
        trans_gray = struct.unpack(">H", trns[:2])[0] >> (bit_depth - 8)
    else:
        trans_gray = None

    if color_type == 2 and len(trns) >= 6:
        r_t, g_t, b_t = struct.unpack(">HHH", trns[:6])
        shift = bit_depth - 8
        trans_rgb = (r_t >> shift, g_t >> shift, b_t >> shift)
    else:
        trans_rgb = None

    for y in range(height):
        offset = y * (1 + stride)
        filter_type = raw[offset]
        row = _unfilter_scanline(
            filter_type, raw[offset + 1 : offset + 1 + stride], prev, bpp
        )
        prev = row
        out_base = y * width * 4

        if color_type == 6 and bit_depth == 8:
            rgba[out_base : out_base + width * 4] = row
        elif color_type == 6 and bit_depth == 16:
            for x in range(width):
                s = x * 8
                d = out_base + x * 4
                rgba[d] = row[s]
                rgba[d + 1] = row[s + 2]
                rgba[d + 2] = row[s + 4]
                rgba[d + 3] = row[s + 6]
        elif color_type == 2:
            for x in range(width):
                s = x * 3 * step
                d = out_base + x * 4
                r, g, b = row[s], row[s + step], row[s + 2 * step]
                a = 0 if trans_rgb == (r, g, b) else 255
                rgba[d : d + 4] = bytes((r, g, b, a))
        elif color_type == 4:
            for x in range(width):
                s = x * 2 * step
                d = out_base + x * 4
                v, a = row[s], row[s + step]
                rgba[d : d + 4] = bytes((v, v, v, a))
        elif color_type == 0:
            for x in range(width):
                v = row[x * step]
                d = out_base + x * 4
                a = 0 if trans_gray == v else 255
                rgba[d : d + 4] = bytes((v, v, v, a))
        elif color_type == 3:
            for x in range(width):
                d = out_base + x * 4
                r, g, b, a = palette_rgba[row[x]]
                rgba[d : d + 4] = bytes((r, g, b, a))

    return width, height, bytes(rgba)


def read_png_rgba(path: Path) -> tuple[int, int, bytes]:
    if Image is not None:
        with Image.open(path) as img:
            rgba = img.convert("RGBA")
            return rgba.width, rgba.height, rgba.tobytes()
    return _decode_png_rgba_stdlib(path)


def _display_path(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def check_sprite(path: Path) -> bool:
    if not path.is_file():
        print(f"ERROR: Missing asset file: {_display_path(path)}")
        return False

    w, h, rgba = read_png_rgba(path)
    total = w * h
    if total == 0:
        print(f"ERROR: Empty image: {_display_path(path)}")
        return False

    corner_offsets = (0, (w - 1) * 4, (h - 1) * w * 4, (total - 1) * 4)
    corners = [tuple(rgba[o : o + 4]) for o in corner_offsets]
    non_trans = total - rgba[3::4].count(0)

    label = _display_path(path)
    print(f"{label} corners: {corners}")
    print(f"Non-transparent: {non_trans}/{total}")

    ok = True
    if any(c[3] != 0 for c in corners):
        print(f"ERROR: {label} has non-transparent corner pixel(s): {corners}")
        ok = False
    if non_trans == 0:
        print(f"ERROR: {label} is completely transparent")
        ok = False
    return ok


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if args:
        targets = [Path(a) for a in args]
    else:
        targets = sorted(DEFAULT_SPRITE_DIR.glob("*.png"))

    if not targets:
        print(f"ERROR: No PNG assets found in {_display_path(DEFAULT_SPRITE_DIR)}")
        return 1

    all_ok = True
    for target in targets:
        if not check_sprite(target):
            all_ok = False

    if not all_ok:
        return 1
    print(f"Asset check passed: {len(targets)} sprite(s) verified.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
