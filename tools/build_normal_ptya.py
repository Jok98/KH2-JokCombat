#!/usr/bin/env python3
"""Build the M-03 complete Sora Base A/Square PTYA profile.

The normal A chains remain engine-owned.  Square keeps Guard from neutral and
uses the native action-selector pipeline during a combo:

* ground branch: Upper Slash selector -> A315 / Explosion;
* finisher follow-up: native A316 / Finishing Leap;
* air branch: Horizontal Slash selector -> A341 / Aerial Spiral.

Guard, Counterguard and Retaliating Slash remain byte-identical.  Every motion
belongs to the same Sora Base carrier and already exists in P_EX100.mset.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
from typing import Any


EXPECTED_INPUT_SHA256 = (
    "cd7bd060e33d603017fa2d296421bd0e5b5417582ef99e82045c552af2971d38"
)
EXPECTED_FILE_SIZE = 15172
PTYA_FILE_TYPE = 2
PTYA_POINTER_COUNT = 70
PTYA_ENTRY_SIZE = 0x44

BASE_GROUP = 1
BASE_RECORD_COUNT = 37
GUARD_RECORD = 31
UPPER_SLASH_RECORD = 32
FINISHING_LEAP_RECORD = 33
HORIZONTAL_SLASH_RECORD = 34
COUNTERGUARD_RECORD = 35
RETALIATING_SLASH_RECORD = 36

UPPER_SLASH_MOTION = 161
EXPLOSION_MOTION = 166
FINISHING_LEAP_MOTION = 167
HORIZONTAL_SLASH_MOTION = 193
AERIAL_SPIRAL_MOTION = 192
COUNTERGUARD_MOTION = 171
RETALIATING_SLASH_MOTION = 172

UPPER_SLASH_ABILITY_SELECTOR = 0x12
FINISHING_LEAP_ABILITY_SELECTOR = 0x5F
HORIZONTAL_SLASH_ABILITY_SELECTOR = 0x63
COUNTERGUARD_ABILITY_SELECTOR = 0x60
RETALIATING_SLASH_ABILITY_SELECTOR = 0x65

EXPECTED_GUARD_SHA256 = (
    "1b5d0e1f39dd74cb9cdb79eac411fc35fbc50460eda974919766eeab0a6ee892"
)
EXPECTED_UPPER_SLASH_SHA256 = (
    "629432f7b91b427ba7c0afb4ae90db40ab6d17b2c95664abb5b564a97d8ce5e8"
)
EXPECTED_FINISHING_LEAP_SHA256 = (
    "1179bdc913be69f9ea0cf217c66cd91dfce020c8db30ae16e17fed689c529743"
)
EXPECTED_HORIZONTAL_SLASH_SHA256 = (
    "5c968892bbb54901cf8d77a285405375fed7de2decdd7103e86ef260359cbbd4"
)
EXPECTED_COUNTERGUARD_SHA256 = (
    "5e3c7bad8947e021014ef48451573223e5ef04fc47de9c592e07be28c76d5d36"
)
EXPECTED_RETALIATING_SLASH_SHA256 = (
    "69fa3992f01dba7b98425bbe986af7838d16110ba2fa295e4b8b8c9b7ca987cc"
)


EXPECTED_RECORDS = {
    GUARD_RECORD: {
        "label": "Guard",
        "sha256": EXPECTED_GUARD_SHA256,
        "fields": {
            "selector_id": 11,
            "selector_type": 0,
            "sub_raw": 0xFF,
            "combo_offset_raw": 0,
            "flags": 0,
            "motion_id": 173,
            "next_motion_id": 0,
            "ability_selector": 0x01,
            "score": 5,
        },
    },
    UPPER_SLASH_RECORD: {
        "label": "Upper Slash",
        "sha256": EXPECTED_UPPER_SLASH_SHA256,
        "fields": {
            "selector_id": 12,
            "selector_type": 0,
            "sub_raw": 0xFF,
            "combo_offset_raw": 0,
            "flags": 0,
            "motion_id": UPPER_SLASH_MOTION,
            "next_motion_id": 0,
            "ability_selector": UPPER_SLASH_ABILITY_SELECTOR,
            "score": 5,
        },
    },
    FINISHING_LEAP_RECORD: {
        "label": "Finishing Leap",
        "sha256": EXPECTED_FINISHING_LEAP_SHA256,
        "fields": {
            "selector_id": 37,
            "selector_type": 0,
            "sub_raw": 0xFF,
            "combo_offset_raw": 1,
            "flags": 4,
            "motion_id": FINISHING_LEAP_MOTION,
            "next_motion_id": 4,
            "ability_selector": FINISHING_LEAP_ABILITY_SELECTOR,
            "score": 5,
        },
    },
    HORIZONTAL_SLASH_RECORD: {
        "label": "Horizontal Slash",
        "sha256": EXPECTED_HORIZONTAL_SLASH_SHA256,
        "fields": {
            "selector_id": 38,
            "selector_type": 0,
            "sub_raw": 0xFF,
            "combo_offset_raw": 0,
            "flags": 1,
            "motion_id": HORIZONTAL_SLASH_MOTION,
            "next_motion_id": 4,
            "ability_selector": HORIZONTAL_SLASH_ABILITY_SELECTOR,
            "score": 5,
        },
    },
    COUNTERGUARD_RECORD: {
        "label": "Counterguard",
        "sha256": EXPECTED_COUNTERGUARD_SHA256,
        "fields": {
            "selector_id": 39,
            "selector_type": 0,
            "sub_raw": 0xFF,
            "combo_offset_raw": 0,
            "flags": 0,
            "motion_id": COUNTERGUARD_MOTION,
            "next_motion_id": 0,
            "ability_selector": COUNTERGUARD_ABILITY_SELECTOR,
            "score": 5,
        },
    },
    RETALIATING_SLASH_RECORD: {
        "label": "Retaliating Slash",
        "sha256": EXPECTED_RETALIATING_SLASH_SHA256,
        "fields": {
            "selector_id": 40,
            "selector_type": 0,
            "sub_raw": 0xFF,
            "combo_offset_raw": 0,
            "flags": 1,
            "motion_id": RETALIATING_SLASH_MOTION,
            "next_motion_id": 4,
            "ability_selector": RETALIATING_SLASH_ABILITY_SELECTOR,
            "score": 5,
        },
    },
}


PATCHES = (
    {
        "record": UPPER_SLASH_RECORD,
        "selector": "Upper Slash / Square ground action",
        "source_motion": {"id": UPPER_SLASH_MOTION, "name": "A310 Upper Slash"},
        "target_motion": {"id": EXPLOSION_MOTION, "name": "A315 Explosion"},
    },
    {
        "record": HORIZONTAL_SLASH_RECORD,
        "selector": "Horizontal Slash / Square air action",
        "source_motion": {
            "id": HORIZONTAL_SLASH_MOTION,
            "name": "A342 Horizontal Slash",
        },
        "target_motion": {
            "id": AERIAL_SPIRAL_MOTION,
            "name": "A341 Aerial Spiral",
        },
    },
)


PRESERVED_RECORDS = (
    GUARD_RECORD,
    FINISHING_LEAP_RECORD,
    COUNTERGUARD_RECORD,
    RETALIATING_SLASH_RECORD,
)


class PtyaValidationError(ValueError):
    """Raised when the source is not the verified retail PTYA layout."""


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def u16(data: bytes | bytearray, offset: int) -> int:
    return struct.unpack_from("<H", data, offset)[0]


def u32(data: bytes | bytearray, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def group_offset(data: bytes | bytearray, group: int) -> int:
    if len(data) != EXPECTED_FILE_SIZE:
        raise PtyaValidationError(
            f"PTYA length mismatch: {len(data)} != {EXPECTED_FILE_SIZE}"
        )
    if u32(data, 0) != PTYA_FILE_TYPE:
        raise PtyaValidationError("Unexpected PTYA file type")
    if u32(data, 4) != PTYA_POINTER_COUNT:
        raise PtyaValidationError("Unexpected PTYA pointer count")
    offset = u32(data, 8 + group * 4)
    if offset == 0 or offset + 4 > len(data):
        raise PtyaValidationError(f"Invalid PTYA group {group} pointer")
    return offset


def record_offset(data: bytes | bytearray, group: int, record: int) -> int:
    offset = group_offset(data, group)
    count = u32(data, offset)
    if group == BASE_GROUP and count != BASE_RECORD_COUNT:
        raise PtyaValidationError(
            f"Base PTYA record count mismatch: {count} != {BASE_RECORD_COUNT}"
        )
    if record >= count:
        raise PtyaValidationError(f"PTYA record {record} exceeds count {count}")
    position = offset + 4 + record * PTYA_ENTRY_SIZE
    if position + PTYA_ENTRY_SIZE > len(data):
        raise PtyaValidationError("PTYA record exceeds file")
    return position


def record_sha256(data: bytes | bytearray, position: int) -> str:
    return sha256(bytes(data[position : position + PTYA_ENTRY_SIZE]))


def describe_record(data: bytes | bytearray, position: int) -> dict[str, int]:
    return {
        "selector_id": data[position],
        "selector_type": data[position + 1],
        "sub_raw": data[position + 2],
        "combo_offset_raw": data[position + 3],
        "flags": u32(data, position + 4),
        "motion_id": u16(data, position + 8),
        "next_motion_id": u16(data, position + 10),
        "ability_selector": u16(data, position + 0x40),
        "score": u16(data, position + 0x42),
    }


def patch_ptya(
    source: bytes, *, require_retail_hash: bool = True
) -> tuple[bytes, dict[str, Any]]:
    input_hash = sha256(source)
    if require_retail_hash and input_hash != EXPECTED_INPUT_SHA256:
        raise PtyaValidationError(
            "Retail PTYA hash mismatch: "
            f"{input_hash} != {EXPECTED_INPUT_SHA256}"
        )

    positions: dict[int, int] = {}
    for record, expected in EXPECTED_RECORDS.items():
        position = record_offset(source, BASE_GROUP, record)
        positions[record] = position
        label = expected["label"]
        if (
            require_retail_hash
            and record_sha256(source, position) != expected["sha256"]
        ):
            raise PtyaValidationError(
                f"{label} record does not match verified retail data"
            )
        actual_fields = describe_record(source, position)
        if actual_fields != expected["fields"]:
            raise PtyaValidationError(
                f"Unexpected {label} fields: {actual_fields}"
            )

    patched = bytearray(source)
    patch_reports: list[dict[str, Any]] = []
    expected_difference_offsets: set[int] = set()
    for patch in PATCHES:
        record = patch["record"]
        position = positions[record]
        before = describe_record(source, position)
        source_motion = patch["source_motion"]["id"]
        target_motion = patch["target_motion"]["id"]
        if before["motion_id"] != source_motion:
            raise PtyaValidationError(
                f"Record {record} motion mismatch: "
                f"{before['motion_id']} != {source_motion}"
            )

        motion_position = position + 8
        original_motion_bytes = bytes(patched[motion_position : motion_position + 2])
        struct.pack_into("<H", patched, motion_position, target_motion)
        target_motion_bytes = bytes(patched[motion_position : motion_position + 2])
        for byte_index, (old, new) in enumerate(
            zip(original_motion_bytes, target_motion_bytes, strict=True)
        ):
            if old != new:
                expected_difference_offsets.add(motion_position + byte_index)

        patch_reports.append(
            {
                "record": record,
                "record_offset": position,
                "selector": patch["selector"],
                "source_motion": patch["source_motion"],
                "target_motion": patch["target_motion"],
                "before": before,
            }
        )

    output = bytes(patched)
    for patch_report in patch_reports:
        patch_report["after"] = describe_record(
            output, patch_report["record_offset"]
        )

    differences = [
        {
            "offset": index,
            "offset_hex": f"0x{index:X}",
            "before": source[index],
            "after": output[index],
        }
        for index in range(len(source))
        if source[index] != output[index]
    ]
    if {difference["offset"] for difference in differences} != (
        expected_difference_offsets
    ):
        raise PtyaValidationError(f"Unexpected PTYA byte diff: {differences}")

    preserved_records: list[dict[str, Any]] = []
    for record in PRESERVED_RECORDS:
        position = positions[record]
        unchanged = (
            source[position : position + PTYA_ENTRY_SIZE]
            == output[position : position + PTYA_ENTRY_SIZE]
        )
        if not unchanged:
            raise PtyaValidationError(
                f"{EXPECTED_RECORDS[record]['label']} record changed unexpectedly"
            )
        preserved_records.append(
            {
                "record": record,
                "label": EXPECTED_RECORDS[record]["label"],
                "offset": position,
                "sha256": record_sha256(output, position),
                "unchanged": True,
            }
        )

    report: dict[str, Any] = {
        "schema": 2,
        "profile": "sora-base-native-a-square",
        "input_sha256": input_hash,
        "output_sha256": sha256(output),
        "file_size": len(output),
        "group": BASE_GROUP,
        "patches": patch_reports,
        "chain": [
            {
                "input": "Square neutral",
                "action": "A322 Guard",
                "ownership": "native, preserved",
            },
            {
                "input": "A ground",
                "action": "native Base ground chain",
                "ownership": "native, preserved",
            },
            {
                "input": "Square after confirmed ground A",
                "action": "A315 Explosion",
                "ownership": "record 32 remap",
            },
            {
                "input": "Square in finisher continuation",
                "action": "A316 Finishing Leap",
                "ownership": "native, preserved",
            },
            {
                "input": "Square while airborne",
                "action": "A341 Aerial Spiral",
                "ownership": "record 34 remap",
            },
            {
                "input": "A after the aerial branch",
                "action": "native Base aerial chain and finisher",
                "ownership": "native, preserved",
            },
        ],
        "byte_differences": differences,
        "preserved_records": preserved_records,
    }
    return output, report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--report", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source = args.input.read_bytes()
    output, report = patch_ptya(source)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(output)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(
            json.dumps(report, indent=2) + "\n", encoding="utf-8"
        )

    patches = ",".join(
        f"r{patch['record']}:"
        f"{patch['source_motion']['id']}->{patch['target_motion']['id']}"
        for patch in report["patches"]
    )
    print(
        "PTYA_OK "
        f"patches={patches} bytes={len(report['byte_differences'])} "
        f"sha256={report['output_sha256']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
