from __future__ import annotations

import importlib.util
from pathlib import Path
import struct
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "build_normal_ptya", ROOT / "tools" / "build_normal_ptya.py"
)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def action_record(
    selector_id: int,
    motion_id: int,
    ability_selector: int,
    *,
    selector_type: int = 0,
    sub_raw: int = 0xFF,
    combo_offset_raw: int = 0,
    flags: int = 0,
    next_motion_id: int = 0,
    score: int = 5,
) -> bytes:
    data = bytearray(MODULE.PTYA_ENTRY_SIZE)
    data[0] = selector_id
    data[1] = selector_type
    data[2] = sub_raw
    data[3] = combo_offset_raw
    struct.pack_into("<I", data, 4, flags)
    struct.pack_into("<H", data, 8, motion_id)
    struct.pack_into("<H", data, 10, next_motion_id)
    struct.pack_into("<f", data, 0x30, 1.0)
    struct.pack_into("<f", data, 0x34, 1.0)
    struct.pack_into("<H", data, 0x40, ability_selector)
    struct.pack_into("<H", data, 0x42, score)
    return bytes(data)


GUARD_RECORD = action_record(11, 173, 1)
UPPER_SLASH_RECORD = action_record(12, 161, 0x12)
FINISHING_LEAP_RECORD = action_record(
    37, 167, 0x5F, combo_offset_raw=1, flags=4, next_motion_id=4
)
HORIZONTAL_SLASH_RECORD = action_record(
    38, 193, 0x63, flags=1, next_motion_id=4
)
COUNTERGUARD_RECORD = action_record(39, 171, 0x60)
RETALIATING_SLASH_RECORD = action_record(
    40, 172, 0x65, flags=1, next_motion_id=4
)

FIXTURE_RECORDS = {
    MODULE.GUARD_RECORD: GUARD_RECORD,
    MODULE.UPPER_SLASH_RECORD: UPPER_SLASH_RECORD,
    MODULE.FINISHING_LEAP_RECORD: FINISHING_LEAP_RECORD,
    MODULE.HORIZONTAL_SLASH_RECORD: HORIZONTAL_SLASH_RECORD,
    MODULE.COUNTERGUARD_RECORD: COUNTERGUARD_RECORD,
    MODULE.RETALIATING_SLASH_RECORD: RETALIATING_SLASH_RECORD,
}


def fixture() -> bytes:
    data = bytearray(MODULE.EXPECTED_FILE_SIZE)
    struct.pack_into("<II", data, 0, MODULE.PTYA_FILE_TYPE, MODULE.PTYA_POINTER_COUNT)
    group_offset = 0x120
    struct.pack_into("<I", data, 8 + MODULE.BASE_GROUP * 4, group_offset)
    struct.pack_into("<I", data, group_offset, MODULE.BASE_RECORD_COUNT)
    for record, contents in FIXTURE_RECORDS.items():
        offset = group_offset + 4 + record * MODULE.PTYA_ENTRY_SIZE
        data[offset : offset + MODULE.PTYA_ENTRY_SIZE] = contents
    return bytes(data)


class NormalPtyaTests(unittest.TestCase):
    def test_only_two_square_motion_bytes_change(self) -> None:
        source = fixture()
        output, report = MODULE.patch_ptya(source, require_retail_hash=False)

        self.assertEqual(len(output), len(source))
        self.assertEqual(report["schema"], 2)
        self.assertEqual(len(report["patches"]), 2)
        self.assertEqual(
            [patch["before"]["motion_id"] for patch in report["patches"]],
            [MODULE.UPPER_SLASH_MOTION, MODULE.HORIZONTAL_SLASH_MOTION],
        )
        self.assertEqual(
            [patch["after"]["motion_id"] for patch in report["patches"]],
            [MODULE.EXPLOSION_MOTION, MODULE.AERIAL_SPIRAL_MOTION],
        )
        self.assertEqual(
            [difference["offset_hex"] for difference in report["byte_differences"]],
            ["0x9AC", "0xA34"],
        )
        self.assertTrue(
            all(record["unchanged"] for record in report["preserved_records"])
        )

    def test_guard_followup_and_counters_are_preserved(self) -> None:
        source = fixture()
        output, _ = MODULE.patch_ptya(source, require_retail_hash=False)

        for record in MODULE.PRESERVED_RECORDS:
            position = MODULE.record_offset(source, MODULE.BASE_GROUP, record)
            self.assertEqual(
                output[position : position + MODULE.PTYA_ENTRY_SIZE],
                source[position : position + MODULE.PTYA_ENTRY_SIZE],
            )

        aerial_position = MODULE.record_offset(
            output, MODULE.BASE_GROUP, MODULE.HORIZONTAL_SLASH_RECORD
        )
        aerial = MODULE.describe_record(output, aerial_position)
        self.assertEqual(aerial["ability_selector"], 0x63)
        self.assertEqual(aerial["flags"], 1)
        self.assertEqual(aerial["next_motion_id"], 4)

    def test_rejects_an_unknown_source_record(self) -> None:
        source = bytearray(fixture())
        group_offset = struct.unpack_from(
            "<I", source, 8 + MODULE.BASE_GROUP * 4
        )[0]
        action_offset = (
            group_offset
            + 4
            + MODULE.HORIZONTAL_SLASH_RECORD * MODULE.PTYA_ENTRY_SIZE
        )
        source[action_offset + 8] = 0xFF

        with self.assertRaises(MODULE.PtyaValidationError):
            MODULE.patch_ptya(bytes(source), require_retail_hash=False)


if __name__ == "__main__":
    unittest.main()
