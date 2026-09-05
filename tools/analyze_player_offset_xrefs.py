#!/usr/bin/env python3
"""Find x64 code references that cover candidate player-structure offsets."""

from __future__ import annotations

import argparse
import bisect
import hashlib
from collections import defaultdict
from pathlib import Path

import pefile
from capstone import CS_ARCH_X86, CS_MODE_64, CS_OP_MEM, Cs
from capstone.x86_const import X86_REG_RBP, X86_REG_RIP, X86_REG_RSP


DEFAULT_TARGETS = (
    0x0123,
    0x018D,
    0x05B8,
    0x0902,
    0x0BFB,
    0x0C04,
    0x0C93,
    0x0C94,
    0x0C95,
)

PLAYER_ANCHORS = (
    0x0098,
    0x00A0,
    0x0180,
    0x0184,
    0x0740,
    0x0744,
    0x0790,
)


def parse_offset(value: str) -> int:
    return int(value, 0)


def function_ranges(pe: pefile.PE) -> list[tuple[int, int]]:
    image_base = pe.OPTIONAL_HEADER.ImageBase
    entries = getattr(pe, "DIRECTORY_ENTRY_EXCEPTION", ())
    ranges = []

    for entry in entries:
        begin = image_base + entry.struct.BeginAddress
        end = image_base + entry.struct.EndAddress
        if begin < end:
            ranges.append((begin, end))

    return sorted(set(ranges))


def containing_function(
    address: int,
    ranges: list[tuple[int, int]],
    starts: list[int],
) -> tuple[int, int] | None:
    index = bisect.bisect_right(starts, address) - 1
    if index < 0:
        return None

    begin, end = ranges[index]
    return (begin, end) if begin <= address < end else None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("exe", type=Path)
    parser.add_argument(
        "--offset",
        action="append",
        type=parse_offset,
        dest="offsets",
        help="candidate offset; may be repeated (default: M-03C candidates)",
    )
    parser.add_argument("--context", type=int, default=5)
    parser.add_argument("--max-per-offset", type=int, default=20)
    parser.add_argument(
        "--min-anchor-count",
        type=int,
        default=0,
        help="show only functions also covering this many known player fields",
    )
    parser.add_argument(
        "--min-same-base-anchor-count",
        type=int,
        default=0,
        help="require known player fields accessed through the same base register",
    )
    parser.add_argument(
        "--require-same-base-anchor",
        action="append",
        type=parse_offset,
        default=[],
        help="require this known field through the same base register",
    )
    parser.add_argument(
        "--player-global-rva",
        type=parse_offset,
        default=0x02AE9A28,
        help="RVA of the Steam 1.0.0.10 Sora pointer global",
    )
    parser.add_argument(
        "--dump-function-rva",
        action="append",
        type=parse_offset,
        default=[],
        help="dump the exception-table function containing this RVA",
    )
    parser.add_argument(
        "--search-opstr",
        action="append",
        default=[],
        help="print instructions whose rendered operands contain this text",
    )
    args = parser.parse_args()

    exe_path = args.exe.resolve()
    targets = tuple(sorted(set(args.offsets or DEFAULT_TARGETS)))
    pe = pefile.PE(str(exe_path), fast_load=False)
    image_base = pe.OPTIONAL_HEADER.ImageBase
    text_section = next(
        section
        for section in pe.sections
        if section.Name.rstrip(b"\0") == b".text"
    )
    text_start = image_base + text_section.VirtualAddress
    code = text_section.get_data()

    decoder = Cs(CS_ARCH_X86, CS_MODE_64)
    decoder.detail = True
    decoder.skipdata = True
    instructions = list(decoder.disasm(code, text_start))
    address_to_index = {
        instruction.address: index
        for index, instruction in enumerate(instructions)
    }
    ranges = function_ranges(pe)
    range_starts = [begin for begin, _ in ranges]
    references: dict[
        int,
        list[tuple[int, int, int, int, str, tuple[int, int] | None]],
    ] = defaultdict(list)
    anchors_by_function: dict[tuple[int, int], set[int]] = defaultdict(set)
    anchors_by_function_base: dict[
        tuple[tuple[int, int], int], set[int]
    ] = defaultdict(set)
    player_global = image_base + args.player_global_rva
    player_global_references: list[
        tuple[int, tuple[int, int] | None]
    ] = []

    skipped_bases = {X86_REG_RIP, X86_REG_RSP, X86_REG_RBP}

    for instruction in instructions:
        if instruction.id == 0:
            continue

        function = containing_function(
            instruction.address,
            ranges,
            range_starts,
        )
        if function is None:
            continue

        for operand in instruction.operands:
            if operand.type == CS_OP_MEM and operand.mem.base == X86_REG_RIP:
                effective_address = (
                    instruction.address
                    + instruction.size
                    + operand.mem.disp
                )
                if effective_address == player_global:
                    player_global_references.append(
                        (instruction.address, function)
                    )

            if operand.type != CS_OP_MEM or operand.mem.base in skipped_bases:
                continue

            displacement = operand.mem.disp
            width = max(1, operand.size)

            for anchor in PLAYER_ANCHORS:
                if displacement <= anchor < displacement + width:
                    anchors_by_function[function].add(anchor)
                    anchors_by_function_base[
                        (function, operand.mem.base)
                    ].add(anchor)

    for instruction in instructions:
        if instruction.id == 0:
            continue

        function = containing_function(
            instruction.address,
            ranges,
            range_starts,
        )

        for operand in instruction.operands:
            if operand.type != CS_OP_MEM or operand.mem.base in skipped_bases:
                continue

            displacement = operand.mem.disp
            width = max(1, operand.size)

            for target in targets:
                if displacement <= target < displacement + width:
                    base_name = instruction.reg_name(operand.mem.base) or "none"
                    references[target].append(
                        (
                            instruction.address,
                            displacement,
                            width,
                            operand.mem.base,
                            base_name,
                            function,
                        )
                    )

    sha256 = hashlib.sha256(exe_path.read_bytes()).hexdigest().upper()
    print(f"EXE={exe_path}")
    print(f"SHA256={sha256}")
    print(f"IMAGE_BASE=0x{image_base:016X}")
    print(f"TEXT=0x{text_start:016X} size=0x{len(code):X}")
    print(f"FUNCTION_RANGES={len(ranges)} INSTRUCTIONS={len(instructions)}")
    print(
        f"PLAYER_GLOBAL=RVA+0x{args.player_global_rva:X} "
        f"XREFS={len(player_global_references)}"
    )
    for address, function in player_global_references:
        if function is None:
            function_label = "function=UNKNOWN"
        else:
            function_label = (
                f"function=RVA+0x{function[0] - image_base:X}"
                f"..0x{function[1] - image_base:X}"
            )

        print(
            f"  PLAYER_XREF RVA+0x{address - image_base:X} "
            f"{function_label}"
        )
        instruction_index = address_to_index[address]
        first = max(0, instruction_index - args.context)
        last = min(len(instructions), instruction_index + args.context + 1)
        for nearby in instructions[first:last]:
            marker = ">" if nearby.address == address else " "
            print(
                f"   {marker} RVA+0x{nearby.address - image_base:07X}: "
                f"{nearby.mnemonic:<8} {nearby.op_str}"
            )
    print()

    for requested_rva in args.dump_function_rva:
        requested_address = image_base + requested_rva
        function = containing_function(
            requested_address,
            ranges,
            range_starts,
        )
        if function is None:
            print(f"FUNCTION RVA+0x{requested_rva:X}: NOT_FOUND")
            continue

        print(
            f"FUNCTION RVA+0x{function[0] - image_base:X}"
            f"..0x{function[1] - image_base:X}"
        )
        for instruction in instructions:
            if instruction.address < function[0]:
                continue
            if instruction.address >= function[1]:
                break
            print(
                f"  RVA+0x{instruction.address - image_base:07X}: "
                f"{instruction.mnemonic:<8} {instruction.op_str}"
            )
        print()

    for pattern in args.search_opstr:
        normalized = pattern.lower()
        matches = [
            instruction
            for instruction in instructions
            if normalized in instruction.op_str.lower()
        ]
        print(f"SEARCH_OPSTR {pattern!r}: {len(matches)} matches")
        for instruction in matches:
            function = containing_function(
                instruction.address,
                ranges,
                range_starts,
            )
            function_label = "UNKNOWN" if function is None else (
                f"RVA+0x{function[0] - image_base:X}"
                f"..0x{function[1] - image_base:X}"
            )
            print(
                f"  RVA+0x{instruction.address - image_base:07X}: "
                f"{instruction.mnemonic:<8} {instruction.op_str} "
                f"function={function_label}"
            )
        print()

    for target in targets:
        all_target_references = references[target]
        target_references = [
            reference
            for reference in all_target_references
            if len(anchors_by_function.get(reference[5], ()))
                >= args.min_anchor_count
            and len(
                anchors_by_function_base.get(
                    (reference[5], reference[3]), ()
                )
            ) >= args.min_same_base_anchor_count
            and set(args.require_same_base_anchor).issubset(
                anchors_by_function_base.get(
                    (reference[5], reference[3]), ()
                )
            )
        ]
        target_references.sort(
            key=lambda reference: (
                -len(
                    anchors_by_function_base.get(
                        (reference[5], reference[3]), ()
                    )
                ),
                -len(anchors_by_function.get(reference[5], ())),
                reference[0],
            )
        )
        print(
            f"OFFSET 0x{target:04X}: {len(target_references)}/"
            f"{len(all_target_references)} code references "
            f"with >= {args.min_anchor_count} function anchors and >= "
            f"{args.min_same_base_anchor_count} same-base anchors; required="
            f"[{','.join(f'0x{x:X}' for x in args.require_same_base_anchor)}]"
        )

        for address, displacement, width, base_id, base_name, function in target_references[
            : args.max_per_offset
        ]:
            if function is None:
                function_label = "function=UNKNOWN"
                anchor_label = "anchors=[]"
                same_base_label = "same_base=[]"
            else:
                function_label = (
                    f"function=RVA+0x{function[0] - image_base:X}"
                    f"..0x{function[1] - image_base:X}"
                )
                anchor_label = "anchors=[" + ",".join(
                    f"0x{anchor:X}"
                    for anchor in sorted(anchors_by_function[function])
                ) + "]"
                same_base_label = "same_base=[" + ",".join(
                    f"0x{anchor:X}"
                    for anchor in sorted(
                        anchors_by_function_base.get(
                            (function, base_id), ()
                        )
                    )
                ) + "]"

            print(
                f"  XREF RVA+0x{address - image_base:X} "
                f"field=+0x{displacement:X}/{width}B base={base_name} "
                f"{function_label} {anchor_label} {same_base_label}"
            )
            instruction_index = address_to_index[address]
            first = max(0, instruction_index - args.context)
            last = min(len(instructions), instruction_index + args.context + 1)

            for nearby in instructions[first:last]:
                marker = ">" if nearby.address == address else " "
                print(
                    f"   {marker} RVA+0x{nearby.address - image_base:07X}: "
                    f"{nearby.mnemonic:<8} {nearby.op_str}"
                )

        if len(target_references) > args.max_per_offset:
            print(
                f"  ... {len(target_references) - args.max_per_offset} "
                "additional references omitted"
            )
        print()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
