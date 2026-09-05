#!/usr/bin/env python3
"""Build a read-only KH2 player moveset inventory from extracted PC assets.

The report correlates 00objentry, PTYA, player MSET/ANB motion triggers,
ATKP and MDLX skeleton/collision data. It intentionally does not patch game
data: M-02 uses it to reject blind animation swaps before combat routing.
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import struct
from typing import Any


BAR_MAGIC = b"BAR\x01"
PTYA_ENTRY_SIZE = 0x44
ATKP_ENTRY_SIZE = 0x30
OBJENTRY_SIZE = 0x60


ACTORS = (
    {
        "key": "sora_base",
        "label": "Sora Base",
        "object_id": 84,
        "ptya_group": 1,
        "asset": "P_EX100",
        "has_weapon": True,
    },
    {
        "key": "valor",
        "label": "Valor",
        "object_id": 85,
        "ptya_group": 2,
        "asset": "P_EX100_BTLF",
        "has_weapon": True,
    },
    {
        "key": "wisdom",
        "label": "Wisdom",
        "object_id": 86,
        "ptya_group": 3,
        "asset": "P_EX100_MAGF",
        "has_weapon": True,
    },
    {
        "key": "master",
        "label": "Master",
        "object_id": 87,
        "ptya_group": 4,
        "asset": "P_EX100_TRIF",
        "has_weapon": True,
    },
    {
        "key": "final",
        "label": "Final",
        "object_id": 88,
        "ptya_group": 5,
        "asset": "P_EX100_ULTF",
        "has_weapon": True,
    },
    {
        "key": "anti",
        "label": "Anti",
        "object_id": 89,
        "ptya_group": 6,
        "asset": "P_EX100_HTLF",
        "has_weapon": False,
    },
    {
        "key": "roxas",
        "label": "Roxas",
        "object_id": 90,
        "ptya_group": 9,
        "asset": "P_EX110",
        "has_weapon": True,
    },
    {
        "key": "roxas_dual",
        "label": "Roxas Dual-Wield",
        "object_id": 803,
        "ptya_group": 10,
        "asset": "P_EX110_BTLF",
        "has_weapon": True,
    },
)


WEAPON_ASSETS = (
    {
        "key": "roxas_light_keyblade",
        "label": "Roxas Light Keyblade",
        "asset": "W_EX010_ROXAS_LIGHT",
    },
    {
        "key": "roxas_dark_keyblade",
        "label": "Roxas Dark Keyblade",
        "asset": "W_EX010_ROXAS_DARK",
    },
)


FORM_NAMES = {
    0: "SoraRoxasDefault",
    1: "Valor",
    2: "Wisdom",
    3: "Limit",
    4: "Master",
    5: "Final",
    6: "Anti",
    7: "LionKingSora",
    8: "AtlanticaSora",
    9: "SoraCarpet",
    10: "RoxasDualWield",
    11: "Default",
    12: "CubeCardForm",
}


# PTYA stores the ability's Item.Flag1 selector, not the save/item ID.
ABILITY_BY_PTYA_SUBID = {
    0x12: {"name": "Upper Slash", "item_id": 0x0089, "domain": "ground"},
    0x5A: {"name": "Slapshot", "item_id": 0x0106, "domain": "ground"},
    0x5B: {"name": "Dodge Slash", "item_id": 0x0107, "domain": "ground"},
    0x5C: {"name": "Slide Dash", "item_id": 0x0108, "domain": "ground"},
    0x5D: {"name": "Guard Break", "item_id": 0x0109, "domain": "ground"},
    0x5E: {"name": "Explosion", "item_id": 0x010A, "domain": "ground"},
    0x5F: {
        "name": "Finishing Leap",
        "item_id": 0x010B,
        "domain": "ground_to_air",
    },
    0x60: {"name": "Counterguard", "item_id": 0x010C, "domain": "ground"},
    0x61: {"name": "Aerial Sweep", "item_id": 0x010D, "domain": "air"},
    0x62: {"name": "Aerial Spiral", "item_id": 0x010E, "domain": "air"},
    0x63: {"name": "Horizontal Slash", "item_id": 0x010F, "domain": "air"},
    0x64: {"name": "Aerial Finish", "item_id": 0x0110, "domain": "air"},
    0x65: {"name": "Retaliating Slash", "item_id": 0x0111, "domain": "air"},
    0xB1: {"name": "Flash Step", "item_id": 0x022F, "domain": "ground"},
    0xB2: {"name": "Aerial Dive", "item_id": 0x0230, "domain": "air"},
    0xB3: {"name": "Magnet Burst", "item_id": 0x0231, "domain": "air"},
    0xB4: {"name": "Vicinity Break", "item_id": 0x0232, "domain": "ground"},
}


RANGE_TRIGGER_NAMES = {
    0: "state_grounded",
    1: "state_air",
    3: "state_no_gravity",
    4: "enable_collision",
    5: "disable_collision",
    9: "state_jump_land",
    10: "attack_hitbox",
    11: "allow_combo",
    12: "weapon_trail",
    14: "allow_reaction_command",
    23: "texture_animation",
    27: "cannot_be_hit",
    28: "turn_to_lock",
    33: "attack_hitbox_combo",
    41: "allow_movement",
    42: "keep_momentum_restrict_movement",
    44: "friction_immovable",
    50: "allow_combo_finisher",
}


FRAME_TRIGGER_NAMES = {
    1: "apdx_effect_caster",
    7: "game_effect",
    8: "apdx_sound",
    13: "voice",
    14: "voice",
    22: "weapon_appear",
    29: "weapon_appear_with_effect",
}


ATKP_TYPE_NAMES = {
    0: "normal_attack",
    1: "pierce_armor",
    2: "guard",
    3: "s_guard",
    4: "special",
    5: "cure",
    6: "c_cure",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--assets-root",
        required=True,
        type=Path,
        help="Root produced by extract_pc_assets.py",
    )
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def c_string(data: bytes) -> str:
    return data.split(b"\0", 1)[0].decode("ascii", errors="replace")


def i8(value: int) -> int:
    return value - 0x100 if value >= 0x80 else value


def u16(data: bytes, offset: int) -> int:
    return struct.unpack_from("<H", data, offset)[0]


def i16(data: bytes, offset: int) -> int:
    return struct.unpack_from("<h", data, offset)[0]


def u32(data: bytes, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def i32(data: bytes, offset: int) -> int:
    return struct.unpack_from("<i", data, offset)[0]


def f32(data: bytes, offset: int) -> float:
    return struct.unpack_from("<f", data, offset)[0]


@dataclass(frozen=True)
class BarEntry:
    index: int
    entry_type: int
    duplicate: int
    name: str
    offset: int
    size: int
    payload: bytes


@dataclass(frozen=True)
class BarFile:
    mset_type: int
    entries: tuple[BarEntry, ...]


def parse_bar(data: bytes, label: str) -> BarFile:
    if len(data) < 0x10 or data[:4] != BAR_MAGIC:
        raise ValueError(f"Invalid BAR: {label}")
    count = u32(data, 4)
    header_end = 0x10 + count * 0x10
    if header_end > len(data):
        raise ValueError(f"BAR header exceeds file: {label}")

    entries = []
    for index in range(count):
        position = 0x10 + index * 0x10
        entry_type = u16(data, position)
        duplicate = u16(data, position + 2)
        name = c_string(data[position + 4 : position + 8])
        offset = u32(data, position + 8)
        size = u32(data, position + 12)
        if offset + size > len(data):
            raise ValueError(
                f"BAR entry exceeds file: {label}[{index}] "
                f"offset=0x{offset:X} size=0x{size:X}"
            )
        entries.append(
            BarEntry(
                index=index,
                entry_type=entry_type,
                duplicate=duplicate,
                name=name,
                offset=offset,
                size=size,
                payload=data[offset : offset + size],
            )
        )
    return BarFile(mset_type=i32(data, 12), entries=tuple(entries))


def parse_objentries(data: bytes) -> dict[int, dict[str, Any]]:
    if len(data) < 8:
        raise ValueError("00objentry is truncated")
    version = u32(data, 0)
    count = u32(data, 4)
    expected = 8 + count * OBJENTRY_SIZE
    if expected > len(data):
        raise ValueError("00objentry count exceeds file")

    result: dict[int, dict[str, Any]] = {}
    for index in range(count):
        position = 8 + index * OBJENTRY_SIZE
        object_id = u32(data, position)
        form_id = data[position + 0x57]
        result[object_id] = {
            "index": index,
            "object_id": object_id,
            "object_type": data[position + 4],
            "weapon_joint": data[position + 7],
            "model_name": c_string(data[position + 8 : position + 0x28]),
            "animation_name": c_string(data[position + 0x28 : position + 0x48]),
            "flags": u16(data, position + 0x48),
            "neo_status": u16(data, position + 0x4C),
            "neo_moveset": u16(data, position + 0x4E),
            "form_id": form_id,
            "form": FORM_NAMES.get(form_id, f"unknown_{form_id}"),
        }
    result["_meta"] = {"version": version, "count": count}  # type: ignore[index]
    return result


def parse_ptya_group(data: bytes, group_index: int) -> list[dict[str, Any]]:
    if len(data) < 8 or u32(data, 0) != 2:
        raise ValueError("Unexpected PTYA header")
    pointer_count = u32(data, 4)
    if group_index >= pointer_count:
        raise ValueError(f"PTYA group {group_index} exceeds {pointer_count}")
    group_offset = u32(data, 8 + group_index * 4)
    if group_offset == 0:
        return []
    count = u32(data, group_offset)
    end = group_offset + 4 + count * PTYA_ENTRY_SIZE
    if end > len(data):
        raise ValueError(f"PTYA group {group_index} exceeds file")

    entries = []
    for index in range(count):
        position = group_offset + 4 + index * PTYA_ENTRY_SIZE
        ability_subid = u16(data, position + 0x40)
        entries.append(
            {
                "record_index": index,
                "selector_id": data[position],
                "selector_type": data[position + 1],
                "sub": i8(data[position + 2]),
                "combo_offset": i8(data[position + 3]),
                "flags": u32(data, position + 4),
                "motion_id": u16(data, position + 8),
                "next_motion_id": u16(data, position + 10),
                "jump": f32(data, position + 12),
                "jump_max": f32(data, position + 16),
                "jump_min": f32(data, position + 20),
                "speed_min": f32(data, position + 24),
                "speed_max": f32(data, position + 28),
                "near": f32(data, position + 32),
                "far": f32(data, position + 36),
                "low": f32(data, position + 40),
                "high": f32(data, position + 44),
                "inner_min": f32(data, position + 48),
                "inner_max": f32(data, position + 52),
                "blend_time": f32(data, position + 56),
                "distance_adjust": f32(data, position + 60),
                "ability_subid": ability_subid,
                "ability": ABILITY_BY_PTYA_SUBID.get(ability_subid),
                "score": u16(data, position + 66),
            }
        )
    return entries


def parse_atkp(data: bytes) -> tuple[list[dict[str, Any]], dict[int, list[dict[str, Any]]]]:
    if len(data) < 8 or u32(data, 0) != 6:
        raise ValueError("Unexpected ATKP header")
    count = u32(data, 4)
    expected = 8 + count * ATKP_ENTRY_SIZE
    if expected > len(data):
        raise ValueError("ATKP count exceeds file")

    entries = []
    by_id: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for index in range(count):
        position = 8 + index * ATKP_ENTRY_SIZE
        kind = data[position + 46]
        entry = {
            "index": index,
            "sub_id": u16(data, position),
            "id": u16(data, position + 2),
            "type_id": data[position + 4],
            "type": ATKP_TYPE_NAMES.get(
                data[position + 4], f"unknown_{data[position + 4]}"
            ),
            "critical_adjust": data[position + 5],
            "power": u16(data, position + 6),
            "team": data[position + 8],
            "element": data[position + 9],
            "enemy_reaction": data[position + 10],
            "effect_on_hit": data[position + 11],
            "knockback_1": i16(data, position + 12),
            "knockback_2": i16(data, position + 14),
            "flags": data[position + 18],
            "refact_self": data[position + 19],
            "refact_other": data[position + 20],
            "interval": u16(data, position + 38),
            "drive_drain": data[position + 41],
            "revenge_damage": data[position + 42],
            "combo_group": data[position + 44],
            "kind": kind,
            "combo_finisher": bool(kind & 1),
            "air_combo_finisher": bool(kind & 2),
            "reaction_command": bool(kind & 4),
        }
        entries.append(entry)
        by_id[entry["id"]].append(entry)
    return entries, by_id


def resolve_atkp(
    by_id: dict[int, list[dict[str, Any]]], attack_id: int, neo_status: int
) -> dict[str, Any]:
    matches = by_id.get(attack_id, [])

    # The retail table can repeat byte-identical ID/SubId rows. Preserve every
    # distinct semantic candidate: NeoStatus-to-ATKP SubId dispatch is not
    # established by the published format, so this report never chooses one.
    unique: dict[str, dict[str, Any]] = {}
    for item in matches:
        semantic = {key: value for key, value in item.items() if key != "index"}
        signature = json.dumps(semantic, sort_keys=True)
        unique.setdefault(signature, item)
    entries = list(unique.values())
    candidate_sub_ids = sorted({item["sub_id"] for item in entries})
    neo_status_candidates = [
        item for item in entries if item["sub_id"] == neo_status
    ]
    if not entries:
        resolution = "missing"
    elif len(entries) == 1:
        resolution = "unique_id"
    elif len(candidate_sub_ids) == 1:
        resolution = "ambiguous_rows_same_subid"
    else:
        payloads_without_subid = {
            json.dumps(
                {
                    key: value
                    for key, value in item.items()
                    if key not in ("index", "sub_id")
                },
                sort_keys=True,
            )
            for item in entries
        }
        resolution = (
            "equivalent_subid_candidates"
            if len(payloads_without_subid) == 1
            else "ambiguous_subid_candidates"
        )
    return {
        "attack_id": attack_id,
        "neo_status": neo_status,
        "resolution": resolution,
        "raw_match_count": len(matches),
        "semantic_entry_count": len(entries),
        "candidate_sub_ids": candidate_sub_ids,
        "neo_status_candidate_count": len(neo_status_candidates),
        "neo_status_dispatch_proven": False,
        "entries": entries,
    }


def parse_motion(data: bytes, label: str) -> dict[str, Any]:
    if len(data) < 0xA0:
        raise ValueError(f"Motion is truncated: {label}")
    motion_type = i32(data, 0x90)
    subtype = i32(data, 0x94)
    header = 0xA0
    if motion_type == 0:
        if len(data) < header + 0x98:
            raise ValueError(f"Interpolated motion is truncated: {label}")
        return {
            "type": "interpolated",
            "subtype": subtype,
            "bone_count": u16(data, header),
            "total_bone_count": u16(data, header + 2),
            "total_frame_count": i32(data, header + 4),
            "frame_start": f32(data, header + 0x80),
            "frame_end": f32(data, header + 0x84),
            "frames_per_second": f32(data, header + 0x88),
            "frame_return": f32(data, header + 0x8C),
            "sha256": sha256_bytes(data),
        }
    if motion_type == 1:
        if len(data) < header + 0x50:
            raise ValueError(f"Raw motion is truncated: {label}")
        return {
            "type": "raw",
            "subtype": subtype,
            "bone_count": i32(data, header),
            "frame_count_gfr": i32(data, header + 0x10),
            "total_frame_count": i32(data, header + 0x14),
            "frame_start": f32(data, header + 0x40),
            "frame_end": f32(data, header + 0x44),
            "frames_per_second": f32(data, header + 0x48),
            "frame_return": f32(data, header + 0x4C),
            "sha256": sha256_bytes(data),
        }
    raise ValueError(f"Unknown motion type {motion_type}: {label}")


def parse_motion_triggers(data: bytes, label: str) -> dict[str, Any]:
    if len(data) < 4:
        raise ValueError(f"Motion triggers are truncated: {label}")
    range_count = data[0]
    frame_count = data[1]
    frame_offset = u16(data, 2)
    if frame_offset > len(data):
        raise ValueError(f"Motion frame trigger offset exceeds file: {label}")

    ranges = []
    position = 4
    for index in range(range_count):
        if position + 6 > len(data):
            raise ValueError(f"Range trigger is truncated: {label}[{index}]")
        param_size = data[position + 5]
        end = position + 6 + param_size * 2
        if end > len(data):
            raise ValueError(f"Range trigger params are truncated: {label}[{index}]")
        trigger_id = data[position + 4]
        ranges.append(
            {
                "index": index,
                "start_frame": i16(data, position),
                "end_frame": i16(data, position + 2),
                "trigger_id": trigger_id,
                "trigger": RANGE_TRIGGER_NAMES.get(trigger_id, f"unknown_{trigger_id}"),
                "params": [u16(data, position + 6 + item * 2) for item in range(param_size)],
            }
        )
        position = end
    if position > frame_offset:
        raise ValueError(f"Range triggers overlap frame triggers: {label}")

    frames = []
    position = frame_offset
    for index in range(frame_count):
        if position + 4 > len(data):
            raise ValueError(f"Frame trigger is truncated: {label}[{index}]")
        param_size = data[position + 3]
        end = position + 4 + param_size * 2
        if end > len(data):
            raise ValueError(f"Frame trigger params are truncated: {label}[{index}]")
        trigger_id = data[position + 2]
        frames.append(
            {
                "index": index,
                "frame": i16(data, position),
                "trigger_id": trigger_id,
                "trigger": FRAME_TRIGGER_NAMES.get(trigger_id, f"unknown_{trigger_id}"),
                "params": [u16(data, position + 4 + item * 2) for item in range(param_size)],
            }
        )
        position = end
    return {"range": ranges, "frame": frames, "sha256": sha256_bytes(data)}


def resolve_player_motion_entry(
    mset: BarFile, motion_id: int, has_weapon: bool
) -> tuple[int, BarEntry, list[int]]:
    if mset.mset_type != 1:
        raise ValueError(f"Expected player MSET type 1, got {mset.mset_type}")
    relative = 0 if has_weapon else 1
    fallbacks = {
        0: (0, 1, 3, 2),
        1: (1, 0, 2, 3),
        2: (2, 3, 1, 0),
        3: (3, 2, 0, 1),
    }[relative]
    attempted = []
    for candidate in fallbacks:
        slot = motion_id * 4 + candidate
        attempted.append(slot)
        if slot >= len(mset.entries):
            continue
        entry = mset.entries[slot]
        if entry.size > 0 and entry.name != "DUMM":
            return slot, entry, attempted
    raise ValueError(
        f"Motion {motion_id} has no valid player slot; attempted {attempted}"
    )


def parse_anb(entry: BarEntry, neo_status: int, atkp_by_id: dict[int, list[dict[str, Any]]]) -> dict[str, Any]:
    anb = parse_bar(entry.payload, f"ANB {entry.name}@{entry.index}")
    motion_entries = [item for item in anb.entries if item.entry_type == 9]
    trigger_entries = [item for item in anb.entries if item.entry_type == 16]
    if not motion_entries:
        raise ValueError(f"ANB has no motion entry: {entry.name}@{entry.index}")

    motion = parse_motion(motion_entries[0].payload, entry.name)
    triggers = (
        parse_motion_triggers(trigger_entries[0].payload, entry.name)
        if trigger_entries and trigger_entries[0].size > 0
        else {"range": [], "frame": [], "sha256": None}
    )
    explicit_hitboxes = []
    for trigger in triggers["range"]:
        if trigger["trigger_id"] not in (10, 33) or not trigger["params"]:
            continue
        attack_id = trigger["params"][0]
        explicit_hitboxes.append(
            {
                "start_frame": trigger["start_frame"],
                "end_frame": trigger["end_frame"],
                "collision_group": trigger["params"][1]
                if len(trigger["params"]) > 1
                else None,
                "combo_id": trigger["params"][2]
                if len(trigger["params"]) > 2
                else None,
                "atkp": resolve_atkp(atkp_by_id, attack_id, neo_status),
            }
        )
    return {
        "bar_entry_count": len(anb.entries),
        "sha256": sha256_bytes(entry.payload),
        "motion": motion,
        "triggers": triggers,
        "explicit_hitboxes": explicit_hitboxes,
        "combo_windows": [
            [item["start_frame"], item["end_frame"]]
            for item in triggers["range"]
            if item["trigger_id"] == 11
        ],
        "finisher_windows": [
            [item["start_frame"], item["end_frame"]]
            for item in triggers["range"]
            if item["trigger_id"] == 50
        ],
        "weapon_trail_windows": [
            [item["start_frame"], item["end_frame"]]
            for item in triggers["range"]
            if item["trigger_id"] == 12
        ],
        "effect_casters": [
            item["params"][0]
            for item in triggers["frame"]
            if item["trigger_id"] in (1, 7) and item["params"]
        ],
        "texture_animations": sorted(
            {
                item["params"][0]
                for item in triggers["range"]
                if item["trigger_id"] == 23 and item["params"]
            }
        ),
    }


def parse_weapon_anb(entry: BarEntry) -> dict[str, Any]:
    """Inspect a weapon ANB without treating non-standard triggers as fatal."""
    result: dict[str, Any] = {
        "slot": entry.index,
        "name": entry.name,
        "size": entry.size,
        "sha256": sha256_bytes(entry.payload),
        "motion": None,
        "triggers": None,
        "trigger_parse_error": None,
        "parse_error": None,
    }
    try:
        anb = parse_bar(entry.payload, f"weapon ANB {entry.name}@{entry.index}")
        motion_entries = [item for item in anb.entries if item.entry_type == 9]
        trigger_entries = [item for item in anb.entries if item.entry_type == 16]
        result["bar_entry_count"] = len(anb.entries)
        if not motion_entries:
            raise ValueError("ANB has no motion entry")
        result["motion"] = parse_motion(motion_entries[0].payload, entry.name)
        if trigger_entries and trigger_entries[0].size > 0:
            try:
                result["triggers"] = parse_motion_triggers(
                    trigger_entries[0].payload, entry.name
                )
            except ValueError as error:
                # A few retail weapon trigger payloads are non-standard/padded;
                # record the gap instead of silently inventing a layout.
                result["trigger_parse_error"] = str(error)
        else:
            result["triggers"] = {
                "range": [],
                "frame": [],
                "sha256": None,
            }
    except ValueError as error:
        result["parse_error"] = str(error)
    return result


def build_weapon_report(asset: dict[str, str], original_root: Path) -> dict[str, Any]:
    mset_path = original_root / "obj" / f"{asset['asset']}.mset"
    mdlx_path = original_root / "obj" / f"{asset['asset']}.mdlx"
    missing = [str(path) for path in (mset_path, mdlx_path) if not path.is_file()]
    if missing:
        raise ValueError("Missing weapon assets: " + ", ".join(missing))

    mset_data = mset_path.read_bytes()
    mset = parse_bar(mset_data, str(mset_path))
    model = parse_mdlx(mdlx_path)
    non_dummy = [
        parse_weapon_anb(entry)
        for entry in mset.entries
        if entry.size > 0 and entry.name != "DUMM"
    ]
    mismatched_bones = [
        item
        for item in non_dummy
        if item["motion"] is not None
        and item["motion"]["bone_count"] != model["bone_count"]
    ]
    if mismatched_bones:
        slots = [item["slot"] for item in mismatched_bones]
        raise ValueError(
            f"{asset['label']} motion/model bone mismatch in slots {slots}"
        )

    explicit_hitbox_count = sum(
        1
        for item in non_dummy
        if item["triggers"] is not None
        for trigger in item["triggers"]["range"]
        if trigger["trigger_id"] in (10, 33)
    )
    return {
        "key": asset["key"],
        "label": asset["label"],
        "asset": asset["asset"],
        "model": model,
        "mset": {
            "path": str(mset_path),
            "entry_count": len(mset.entries),
            "mset_type": mset.mset_type,
            "file_length": len(mset_data),
            "file_sha256": sha256_file(mset_path),
        },
        "non_dummy_entry_count": len(non_dummy),
        "explicit_hitbox_count": explicit_hitbox_count,
        "entries": non_dummy,
    }


def parse_mdlx(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    bar = parse_bar(data, str(path))
    models = [item for item in bar.entries if item.entry_type == 4]
    textures = [item for item in bar.entries if item.entry_type == 7]
    collisions = [item for item in bar.entries if item.entry_type == 23]
    if not models:
        raise ValueError(f"MDLX has no model: {path}")
    model = models[0]
    if len(model.payload) < 0xA2:
        raise ValueError(f"MDLX model data is truncated: {path}")

    collision = collisions[0] if collisions else None
    collision_summary = None
    if collision is not None:
        if len(collision.payload) < 0x40:
            collision_summary = {
                "entry_count": None,
                "enabled": None,
                "group_counts": {},
                "attack_group_counts": {},
                "length": len(collision.payload),
                "sha256": sha256_bytes(collision.payload),
                "parse_error": "payload shorter than character collision header",
            }
        else:
            count = u32(collision.payload, 0)
            expected = 0x40 + count * 0x14
            if expected > len(collision.payload):
                raise ValueError(f"MDLX collision count exceeds file: {path}")
            groups = Counter()
            attack_groups = Counter()
            for index in range(count):
                position = 0x40 + index * 0x14
                group = collision.payload[position]
                collision_type = collision.payload[position + 4]
                groups[group] += 1
                if collision_type == 6:
                    attack_groups[group] += 1
            collision_summary = {
                "entry_count": count,
                "enabled": u32(collision.payload, 4),
                "group_counts": dict(sorted(groups.items())),
                "attack_group_counts": dict(sorted(attack_groups.items())),
                "length": len(collision.payload),
                "sha256": sha256_bytes(collision.payload),
                "parse_error": None,
            }

    return {
        "path": str(path),
        "file_length": len(data),
        "file_sha256": sha256_file(path),
        "bar_entry_count": len(bar.entries),
        "bone_count": u16(model.payload, 0xA0),
        "model_length": len(model.payload),
        "model_sha256": sha256_bytes(model.payload),
        "texture_length": sum(len(item.payload) for item in textures),
        "texture_sha256": [sha256_bytes(item.payload) for item in textures],
        "collision": collision_summary,
    }


def classify_action(entry: dict[str, Any]) -> dict[str, Any]:
    ability = entry["ability"]
    if ability:
        domain = ability["domain"]
    elif entry["next_motion_id"] == 0:
        domain = "ground"
    elif entry["next_motion_id"] == 4:
        domain = "air"
    else:
        domain = "transition"
    finisher = bool(entry["flags"] & 4)
    if domain == "ground_to_air":
        role = "ground_to_air_finisher" if finisher else "ground_to_air"
    else:
        role = f"{domain}_{'finisher' if finisher else 'normal'}"
    return {"domain": domain, "finisher": finisher, "role": role}


def build_actor_report(
    actor: dict[str, Any],
    original_root: Path,
    ptya_data: bytes,
    objentries: dict[int, dict[str, Any]],
    atkp_by_id: dict[int, list[dict[str, Any]]],
) -> dict[str, Any]:
    objentry = objentries.get(actor["object_id"])
    if objentry is None:
        raise ValueError(f"Object ID {actor['object_id']} is missing")
    if objentry["neo_moveset"] != actor["ptya_group"]:
        raise ValueError(
            f"{actor['label']} NeoMoveset {objentry['neo_moveset']} != "
            f"PTYA group {actor['ptya_group']}"
        )

    mset_path = original_root / "obj" / f"{actor['asset']}.mset"
    mdlx_path = original_root / "obj" / f"{actor['asset']}.mdlx"
    mset_data = mset_path.read_bytes()
    mset = parse_bar(mset_data, str(mset_path))
    model = parse_mdlx(mdlx_path)
    ptya_entries = parse_ptya_group(ptya_data, actor["ptya_group"])

    actions = []
    for ptya in ptya_entries:
        slot, motion_entry, attempted = resolve_player_motion_entry(
            mset, ptya["motion_id"], actor["has_weapon"]
        )
        anb = parse_anb(motion_entry, objentry["neo_status"], atkp_by_id)
        if anb["motion"]["bone_count"] != model["bone_count"]:
            raise ValueError(
                f"{actor['label']} {motion_entry.name}: motion bones "
                f"{anb['motion']['bone_count']} != model bones {model['bone_count']}"
            )
        actions.append(
            {
                **ptya,
                **classify_action(ptya),
                "requested_slot": ptya["motion_id"] * 4
                + (0 if actor["has_weapon"] else 1),
                "resolved_slot": slot,
                "fallback_slots_attempted": attempted,
                "anb_name": motion_entry.name,
                "anb": anb,
            }
        )

    unique_motions: dict[str, dict[str, Any]] = {}
    for action in actions:
        key = f"{action['resolved_slot']}:{action['anb_name']}"
        motion = unique_motions.setdefault(
            key,
            {
                "slot": action["resolved_slot"],
                "anb_name": action["anb_name"],
                "motion_id": action["motion_id"],
                "roles": set(),
                "selectors": [],
                "ability_names": set(),
                "anb": action["anb"],
            },
        )
        motion["roles"].add(action["role"])
        motion["selectors"].append(
            {
                "record_index": action["record_index"],
                "id": action["selector_id"],
                "type": action["selector_type"],
                "sub": action["sub"],
                "flags": action["flags"],
                "score": action["score"],
            }
        )
        if action["ability"]:
            motion["ability_names"].add(action["ability"]["name"])
    serialized_motions = []
    for motion in unique_motions.values():
        motion["roles"] = sorted(motion["roles"])
        motion["ability_names"] = sorted(motion["ability_names"])
        serialized_motions.append(motion)
    serialized_motions.sort(key=lambda item: item["slot"])

    role_counts = Counter(action["role"] for action in actions)
    return {
        "key": actor["key"],
        "label": actor["label"],
        "object": objentry,
        "ptya_group": actor["ptya_group"],
        "has_weapon_state": actor["has_weapon"],
        "mset": {
            "path": str(mset_path),
            "entry_count": len(mset.entries),
            "mset_type": mset.mset_type,
            "file_length": len(mset_data),
            "file_sha256": sha256_file(mset_path),
        },
        "model": model,
        "ptya_record_count": len(actions),
        "unique_motion_count": len(serialized_motions),
        "role_counts": dict(sorted(role_counts.items())),
        "unique_motions": serialized_motions,
        "actions": actions,
    }


def build_compatibility(carriers: list[dict[str, Any]]) -> list[dict[str, Any]]:
    base = next(item for item in carriers if item["key"] == "sora_base")
    result = []
    for carrier in carriers:
        same_bones = carrier["model"]["bone_count"] == base["model"]["bone_count"]
        same_model = carrier["model"]["model_sha256"] == base["model"]["model_sha256"]
        same_collision = (
            carrier["model"]["collision"]["sha256"]
            == base["model"]["collision"]["sha256"]
        )
        same_weapon_joint = (
            carrier["object"]["weapon_joint"] == base["object"]["weapon_joint"]
        )
        if carrier["key"] == "sora_base":
            structural_class = "native"
        elif same_bones and same_model:
            structural_class = "carrier_asset_candidate"
        else:
            structural_class = "incompatible_direct_motion_swap"
        result.append(
            {
                "key": carrier["key"],
                "label": carrier["label"],
                "structural_class": structural_class,
                "same_model_bone_count_as_base": same_bones,
                "same_model_payload_as_base": same_model,
                "same_collision_payload_as_base": same_collision,
                "same_weapon_joint_as_base": same_weapon_joint,
                "notes": (
                    "Structural only; carrier gameplay and base-looking texture hybrid remain M-04 validation."
                    if structural_class == "carrier_asset_candidate"
                    else "Direct source motion is not structurally safe on the Base model."
                    if structural_class == "incompatible_direct_motion_swap"
                    else "Retail Base path."
                ),
            }
        )
    return result


def main() -> int:
    args = parse_args()
    assets_root = args.assets_root.resolve()
    original_root = assets_root / "original"
    unpacked_battle = assets_root / "unpacked" / "00battle"

    required = {
        "objentry": original_root / "00objentry.bin",
        "ptya": unpacked_battle / "ptya.list",
        "atkp": unpacked_battle / "atkp.list",
    }
    missing = [str(path) for path in required.values() if not path.is_file()]
    if missing:
        raise RuntimeError("Missing extracted inputs: " + ", ".join(missing))

    objentry_data = required["objentry"].read_bytes()
    ptya_data = required["ptya"].read_bytes()
    atkp_data = required["atkp"].read_bytes()
    objentries = parse_objentries(objentry_data)
    atkp_entries, atkp_by_id = parse_atkp(atkp_data)

    carriers = [
        build_actor_report(
            actor,
            original_root,
            ptya_data,
            objentries,
            atkp_by_id,
        )
        for actor in ACTORS
    ]
    weapon_dependencies = [
        build_weapon_report(asset, original_root) for asset in WEAPON_ASSETS
    ]
    report = {
        "schema": 1,
        "read_only": True,
        "assets_root": str(assets_root),
        "source": {
            "00objentry_sha256": sha256_file(required["objentry"]),
            "ptya_sha256": sha256_file(required["ptya"]),
            "atkp_sha256": sha256_file(required["atkp"]),
            "atkp_entry_count": len(atkp_entries),
            "objentry": objentries["_meta"],
        },
        "carriers": carriers,
        "weapon_dependencies": weapon_dependencies,
        "compatibility_against_sora_base": build_compatibility(carriers),
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    action_count = sum(item["ptya_record_count"] for item in carriers)
    explicit_count = sum(
        len(action["anb"]["explicit_hitboxes"])
        for item in carriers
        for action in item["actions"]
    )
    print(
        f"ANALYSIS_OK carriers={len(carriers)} actions={action_count} "
        f"explicit_hitboxes={explicit_count} "
        f"weapon_assets={len(weapon_dependencies)} output={args.output.resolve()}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
