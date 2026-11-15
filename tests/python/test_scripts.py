#!/usr/bin/env python3
"""Unit and fuzz tests for Python tooling scripts under scripts/."""

from pathlib import Path
import random
import struct
import sys
import tempfile
import unittest
import zlib

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import check_bg
import check_coverage
import check_deadcode
import remove_bg


def _make_minimal_rgba_png(width: int, height: int, pixels: bytes) -> bytes:
    """Build a minimal valid 8-bit RGBA PNG byte stream using stdlib only."""
    assert len(pixels) == width * height * 4

    def chunk(tag: bytes, payload: bytes) -> bytes:
        crc = zlib.crc32(tag + payload) & 0xFFFFFFFF
        return struct.pack(">I4s", len(payload), tag) + payload + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    raw_rows = bytearray()
    stride = width * 4
    for y in range(height):
        raw_rows.append(0)  # filter type 0
        raw_rows.extend(pixels[y * stride : (y + 1) * stride])
    idat = zlib.compress(bytes(raw_rows))
    return check_bg.PNG_SIGNATURE + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")


class TestPythonScripts(unittest.TestCase):
    def test_check_bg_verifies_enemy_sprites(self) -> None:
        self.assertEqual(check_bg.main([]), 0)

    def test_check_bg_rejects_opaque_corner_and_blank_png(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            opaque_path = Path(tmp) / "opaque.png"
            opaque_pixels = bytes([255, 0, 0, 255] * 4)
            opaque_path.write_bytes(_make_minimal_rgba_png(2, 2, opaque_pixels))
            self.assertFalse(check_bg.check_sprite(opaque_path))

            blank_path = Path(tmp) / "blank.png"
            blank_pixels = bytes([0, 0, 0, 0] * 4)
            blank_path.write_bytes(_make_minimal_rgba_png(2, 2, blank_pixels))
            self.assertFalse(check_bg.check_sprite(blank_path))

            valid_path = Path(tmp) / "valid.png"
            valid_pixels = bytes(
                [0, 0, 0, 0]
                + [0, 0, 0, 0]
                + [0, 0, 0, 0]
                + [0, 0, 0, 0]
            )
            # 3x3 with transparent corners and opaque center
            px = bytearray([0, 0, 0, 0] * 9)
            px[4 * 4 : 4 * 4 + 4] = bytes([10, 200, 30, 255])
            valid_path.write_bytes(_make_minimal_rgba_png(3, 3, bytes(px)))
            self.assertTrue(check_bg.check_sprite(valid_path))

    def test_fuzz_check_bg_stdlib_decoder_rejects_corrupt_bytes(self) -> None:
        rng = random.Random(42)
        with tempfile.TemporaryDirectory() as tmp:
            for i in range(40):
                p = Path(tmp) / f"fuzz_{i}.png"
                payload = bytes(rng.getrandbits(8) for _ in range(rng.randint(0, 128)))
                p.write_bytes(payload)
                with self.assertRaises((ValueError, zlib.error, struct.error)):
                    check_bg._decode_png_rgba_stdlib(p)

    def test_check_coverage_passes_repo(self) -> None:
        self.assertEqual(check_coverage.main(), 0)

    def test_check_deadcode_passes_repo(self) -> None:
        self.assertEqual(check_deadcode.main(), 0)

    def test_remove_bg_module_handles_missing_file_or_pil(self) -> None:
        self.assertGreater(len(remove_bg.DEFAULT_FILES), 0)
        if remove_bg.Image is None:
            with self.assertRaises(RuntimeError):
                remove_bg.make_transparent("nonexistent.png")
        else:
            self.assertFalse(remove_bg.make_transparent("nonexistent_12345.png"))


if __name__ == "__main__":
    unittest.main()
