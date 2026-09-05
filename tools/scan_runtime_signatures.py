#!/usr/bin/env python3
"""Resolve selected KH2 PC runtime globals from machine-code signatures.

This tool is read-only.  It converts signature matches in the executable from
file offsets to PE RVAs, then resolves RIP-relative operands in the same way as
Re:Fined's ``FetchRelativePointer`` helper.  The resulting RVAs are suitable
for LuaBackend's PC address API and avoid copying offsets from another build.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import struct


@dataclass(frozen=True)
class Section:
    name: str
    virtual_address: int
    virtual_size: int
    raw_offset: int
    raw_size: int


@dataclass(frozen=True)
class Signature:
    name: str
    pattern: bytes
    mask: str
    relative_offset: int
    source: str


SIGNATURES = (
    Signature(
        name="sora_pointer",
        pattern=(
            b"\x48\x89\x5C\x24\x08\x57\x48\x83\xEC\x30\xF3\x0F\x10\x44"
            b"\x24\x68\x41\x8B\xD8\x48\x8B\x44\x24\x60\x48\x8B\xF9\xF3"
            b"\x0F\x11\x44\x24\x28\x48\x89\x44\x24\x20\xE8\x00\x00\x00"
            b"\x00\x33\xC0\x48\x8D\x0D\x00\x00\x00\x00\x48\x89\x87\x08"
            b"\x0E\x00\x00\x48\x89\x87\x10\x0E\x00\x00\xE8\x00\x00\x00"
            b"\x00"
        ),
        mask="x" * 39 + "?" * 4 + "x" * 5 + "?" * 4 + "x" * 15 + "?" * 4,
        relative_offset=0x56,
        source="KH-ReFined ReFined.KH2/include/kingdom/sora.h",
    ),
    Signature(
        name="command_elem_pointer",
        pattern=(
            b"\x40\x53\x48\x83\xEC\x30\x48\x8B\x15\x00\x00\x00\x00\x48"
            b"\x8D\x1D\x00\x00\x00\x00\x48\x63\xC9\x41\xB9\x30\x00\x00"
            b"\x00\x48\x89\x5C\x24\x20\x4C\x63\x42\x04\x48\x83\xC2\x08"
            b"\xFF\x15\x00\x00\x00\x00\x66\x83\x78\x02\x02\x75\x32"
        ),
        mask="x" * 9 + "?" * 4 + "x" * 3 + "?" * 4 + "x" * 24 + "?" * 4 + "x" * 7,
        relative_offset=0x09,
        source="KH-ReFined ReFined.KH2/include/kingdom/command_elem.h",
    ),
)


def parse_sections(data: bytes) -> tuple[int, list[Section]]:
    if data[:2] != b"MZ":
        raise ValueError("not a PE executable: missing MZ header")

    pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe_offset : pe_offset + 4] != b"PE\0\0":
        raise ValueError("not a PE executable: missing PE signature")

    coff_offset = pe_offset + 4
    section_count = struct.unpack_from("<H", data, coff_offset + 2)[0]
    optional_size = struct.unpack_from("<H", data, coff_offset + 16)[0]
    optional_offset = coff_offset + 20
    image_base = struct.unpack_from("<Q", data, optional_offset + 24)[0]
    section_offset = optional_offset + optional_size

    sections: list[Section] = []
    for index in range(section_count):
        offset = section_offset + index * 40
        name = data[offset : offset + 8].split(b"\0", 1)[0].decode("ascii", "replace")
        virtual_size, virtual_address, raw_size, raw_offset = struct.unpack_from(
            "<IIII", data, offset + 8
        )
        sections.append(
            Section(name, virtual_address, virtual_size, raw_offset, raw_size)
        )
    return image_base, sections


def file_offset_to_rva(file_offset: int, sections: list[Section]) -> int:
    for section in sections:
        if section.raw_offset <= file_offset < section.raw_offset + section.raw_size:
            return section.virtual_address + file_offset - section.raw_offset
    raise ValueError(f"file offset 0x{file_offset:X} is outside PE sections")


def find_signature(data: bytes, signature: Signature) -> list[int]:
    if len(signature.pattern) != len(signature.mask):
        raise ValueError(f"invalid mask length for {signature.name}")

    first_fixed = next(index for index, marker in enumerate(signature.mask) if marker == "x")
    needle = bytes((signature.pattern[first_fixed],))
    matches: list[int] = []
    cursor = 0
    limit = len(data) - len(signature.pattern)
    while cursor <= limit:
        candidate = data.find(needle, cursor + first_fixed)
        if candidate < 0:
            break
        start = candidate - first_fixed
        if start >= cursor and all(
            marker != "x" or data[start + index] == signature.pattern[index]
            for index, marker in enumerate(signature.mask)
        ):
            matches.append(start)
        cursor = start + 1
    return matches


def resolve_signature(
    data: bytes, sections: list[Section], signature: Signature
) -> tuple[int, int]:
    matches = find_signature(data, signature)
    if len(matches) != 1:
        raise ValueError(
            f"{signature.name}: expected one match, found {len(matches)}"
        )

    match_offset = matches[0]
    match_rva = file_offset_to_rva(match_offset, sections)
    displacement = struct.unpack_from(
        "<i", data, match_offset + signature.relative_offset
    )[0]
    target_rva = match_rva + signature.relative_offset + 4 + displacement
    return match_rva, target_rva


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("executable", type=Path)
    args = parser.parse_args()

    data = args.executable.read_bytes()
    image_base, sections = parse_sections(data)
    print(f"executable={args.executable}")
    print(f"image_base=0x{image_base:016X}")
    for signature in SIGNATURES:
        match_rva, target_rva = resolve_signature(data, sections, signature)
        print(
            f"{signature.name}: match_rva=0x{match_rva:08X} "
            f"target_rva=0x{target_rva:08X} source={signature.source}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
