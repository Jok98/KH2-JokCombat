#!/usr/bin/env python3
"""Read-only inspector for a running KH2 PC process.

The tool never requests write access.  It resolves the Sora and command-element
globals produced by ``scan_runtime_signatures.py`` and can compare a bounded
slice of Sora's live object across samples while reverse-engineering state
fields for the combat router.
"""

from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
import struct
import time
from collections import defaultdict


PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_VM_READ = 0x0010


def parse_int(value: str) -> int:
    return int(value, 0)


class ProcessReader:
    def __init__(self, pid: int) -> None:
        access = PROCESS_QUERY_INFORMATION | PROCESS_VM_READ
        self.handle = ctypes.windll.kernel32.OpenProcess(access, False, pid)
        if not self.handle:
            raise ctypes.WinError()

    def close(self) -> None:
        if self.handle:
            ctypes.windll.kernel32.CloseHandle(self.handle)
            self.handle = None

    def read(self, address: int, size: int) -> bytes:
        buffer = ctypes.create_string_buffer(size)
        read_size = ctypes.c_size_t()
        ok = ctypes.windll.kernel32.ReadProcessMemory(
            self.handle,
            ctypes.c_void_p(address),
            buffer,
            size,
            ctypes.byref(read_size),
        )
        if not ok or read_size.value != size:
            raise ctypes.WinError()
        return buffer.raw

    def u8(self, address: int) -> int:
        return self.read(address, 1)[0]

    def u16(self, address: int) -> int:
        return struct.unpack("<H", self.read(address, 2))[0]

    def u32(self, address: int) -> int:
        return struct.unpack("<I", self.read(address, 4))[0]

    def u64(self, address: int) -> int:
        return struct.unpack("<Q", self.read(address, 8))[0]

    def __enter__(self) -> "ProcessReader":
        return self

    def __exit__(self, *_args: object) -> None:
        self.close()


def format_changes(before: bytes, after: bytes, start: int) -> list[str]:
    changes: list[str] = []
    for offset in range(0, min(len(before), len(after)), 4):
        old = before[offset : offset + 4]
        new = after[offset : offset + 4]
        if old != new:
            old_value = int.from_bytes(old, "little")
            new_value = int.from_bytes(new, "little")
            changes.append(
                f"+0x{start + offset:04X}: 0x{old_value:08X} -> 0x{new_value:08X}"
            )
    return changes


def format_watch(values: dict[int, int]) -> str:
    return " ".join(
        f"+0x{offset:04X}=0x{value:08X}"
        for offset, value in values.items()
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pid", required=True, type=int)
    parser.add_argument("--base", required=True, type=parse_int)
    parser.add_argument("--sora-rva", default=0x02AE9A28, type=parse_int)
    parser.add_argument("--command-elem-rva", default=0x02A161E8, type=parse_int)
    parser.add_argument("--input-rva", default=0x00BF31A0, type=parse_int)
    parser.add_argument("--reaction-rva", default=0x02A11162, type=parse_int)
    parser.add_argument("--start", default=0, type=parse_int)
    parser.add_argument("--length", default=0x1000, type=parse_int)
    parser.add_argument("--samples", default=1, type=int)
    parser.add_argument("--delay", default=1.0, type=float)
    parser.add_argument("--warmup", default=0.0, type=float)
    parser.add_argument("--aggregate", action="store_true")
    parser.add_argument(
        "--timeline",
        action="store_true",
        help="print correlated input/reaction/Sora-field changes",
    )
    parser.add_argument(
        "--watch-offset",
        action="append",
        default=[],
        type=parse_int,
        help="Sora-relative dword to include in --timeline (repeatable)",
    )
    parser.add_argument("--max-changes", default=250, type=int)
    args = parser.parse_args()

    if args.length <= 0 or args.length > 0x10000:
        parser.error("--length must be between 1 and 0x10000")
    if args.samples <= 0 or args.samples > 1200:
        parser.error("--samples must be between 1 and 1200")

    default_watch_offsets = (
        0x0124,
        0x0180,
        0x0184,
        0x018C,
        0x0190,
        0x0194,
        0x01A8,
        0x01B0,
        0x0368,
        0x0740,
        0x0744,
        0x0780,
        0x0790,
        0x08E8,
        0x0E64,
    )
    watch_offsets = tuple(dict.fromkeys(args.watch_offset or default_watch_offsets))

    with ProcessReader(args.pid) as reader:
        sora_global = args.base + args.sora_rva
        command_global = args.base + args.command_elem_rva
        input_address = args.base + args.input_rva
        reaction_address = args.base + args.reaction_rva
        sora = reader.u64(sora_global)
        command_elem = reader.u64(command_global)
        auto_attack = command_elem + 0x0A if command_elem else 0

        print(f"base=0x{args.base:016X}")
        print(f"sora_global=0x{sora_global:016X} sora=0x{sora:016X}")
        print(
            f"command_global=0x{command_global:016X} "
            f"command_elem=0x{command_elem:016X} auto_attack=0x{auto_attack:016X}"
        )
        print(
            f"input=0x{input_address:016X} "
            f"reaction=0x{reaction_address:016X}"
        )
        if auto_attack:
            print(f"auto_attack_value=0x{reader.u8(auto_attack):02X}")
        if not sora:
            raise RuntimeError("Sora pointer is null; load a controllable gameplay area")

        if args.warmup > 0:
            print(f"warmup={args.warmup:.2f}s")
            time.sleep(args.warmup)

        previous = reader.read(sora + args.start, args.length)
        previous_input = reader.u32(input_address)
        previous_reaction = reader.u16(reaction_address)
        previous_watch = {
            offset: reader.u32(sora + offset) for offset in watch_offsets
        }
        aggregate: dict[int, set[tuple[int, int]]] = defaultdict(set)
        aggregate_counts: dict[int, int] = defaultdict(int)
        print(
            f"sample=1 object=0x{sora:016X} range=+0x{args.start:X}.."
            f"+0x{args.start + args.length - 1:X}"
        )
        started = time.perf_counter()
        if args.timeline:
            print(
                f"t=0.000 sample=1 input=0x{previous_input:08X} "
                f"reaction=0x{previous_reaction:04X} "
                f"{format_watch(previous_watch)}"
            )
        for sample in range(2, args.samples + 1):
            time.sleep(args.delay)
            current_sora = reader.u64(sora_global)
            if current_sora != sora:
                print(
                    f"sample={sample} SORA_REBUILT old=0x{sora:016X} "
                    f"new=0x{current_sora:016X}"
                )
                sora = current_sora
                previous = reader.read(sora + args.start, args.length)
                previous_watch = {
                    offset: reader.u32(sora + offset) for offset in watch_offsets
                }
                continue
            current = reader.read(sora + args.start, args.length)
            current_input = reader.u32(input_address)
            current_reaction = reader.u16(reaction_address)
            current_watch = {
                offset: reader.u32(sora + offset) for offset in watch_offsets
            }
            changes = format_changes(previous, current, args.start)
            if args.timeline and (
                current_input != previous_input
                or current_reaction != previous_reaction
                or current_watch != previous_watch
            ):
                print(
                    f"t={time.perf_counter() - started:.3f} sample={sample} "
                    f"input=0x{current_input:08X} "
                    f"reaction=0x{current_reaction:04X} "
                    f"{format_watch(current_watch)}"
                )
            if args.aggregate:
                for offset in range(0, min(len(previous), len(current)), 4):
                    old = previous[offset : offset + 4]
                    new = current[offset : offset + 4]
                    if old != new:
                        absolute_offset = args.start + offset
                        old_value = int.from_bytes(old, "little")
                        new_value = int.from_bytes(new, "little")
                        aggregate[absolute_offset].add((old_value, new_value))
                        aggregate_counts[absolute_offset] += 1
            else:
                print(f"sample={sample} changed_dwords={len(changes)}")
                for change in changes:
                    print(change)
            previous = current
            previous_input = current_input
            previous_reaction = current_reaction
            previous_watch = current_watch

        if args.aggregate:
            ranked = sorted(
                aggregate,
                key=lambda offset: (-aggregate_counts[offset], offset),
            )
            print(f"aggregate_changed_dwords={len(ranked)}")
            for offset in ranked[: args.max_changes]:
                transitions = sorted(aggregate[offset])
                preview = ", ".join(
                    f"0x{old:08X}->0x{new:08X}"
                    for old, new in transitions[:8]
                )
                if len(transitions) > 8:
                    preview += f", ... ({len(transitions)} transitions)"
                print(
                    f"+0x{offset:04X}: changes={aggregate_counts[offset]} "
                    f"{preview}"
                )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
