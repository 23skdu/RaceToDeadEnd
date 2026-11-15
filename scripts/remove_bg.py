#!/usr/bin/env python3
"""Make background pixels transparent in enemy sprite PNGs."""

import os
import sys

try:
    from PIL import Image
except ImportError:
    Image = None

DEFAULT_FILES = [
    "assets/sprites/enemies/drone.png",
    "assets/sprites/enemies/rotor.png",
    "assets/sprites/enemies/scav.png",
]


def make_transparent(filename: str) -> bool:
    if Image is None:
        raise RuntimeError("Pillow is required for remove_bg.py (run 'make deps-python')")
    if not os.path.exists(filename):
        print(f"Not found: {filename}")
        return False
    with Image.open(filename) as opened:
        img = opened.convert("RGBA")
        data = img.get_flattened_data() if hasattr(img, "get_flattened_data") else img.getdata()
        bg_color = data[0]

        new_data = []
        for item in data:
            if (
                abs(item[0] - bg_color[0]) < 10
                and abs(item[1] - bg_color[1]) < 10
                and abs(item[2] - bg_color[2]) < 10
            ):
                new_data.append((255, 255, 255, 0))
            else:
                new_data.append(item)

        img.putdata(new_data)
        img.save(filename, "PNG")
    print(f"Processed {filename}")
    return True


def main(argv: list[str] | None = None) -> int:
    targets = list(argv) if argv else DEFAULT_FILES
    ok = True
    for f in targets:
        if not make_transparent(f):
            ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
