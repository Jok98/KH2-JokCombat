#!/usr/bin/env python3
"""Extract a small, named KH2 PC asset set through the installed OpenKH tool.

The Steam/Epic HED index stores MD5(path), PKG offset and lengths but exposes no
single-file extraction option. This helper builds one temporary subset HED per
source package, hard-links the matching PKG, and delegates decryption and
decompression to OpenKh.Command.IdxImg. It never modifies the game archives.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile


HED_ENTRY = struct.Struct("<16sqii")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--game-dir", required=True, type=Path)
    parser.add_argument("--openkh-tool", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("asset", nargs="+")
    return parser.parse_args()


def normalized_asset_name(value: str) -> str:
    return value.replace("\\", "/").lstrip("/")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def locate_entries(game_dir: Path, assets: list[str]) -> dict[str, dict]:
    wanted = {
        hashlib.md5(name.encode("utf-8")).digest(): name
        for name in assets
    }
    located: dict[str, dict] = {}

    for hed_path in sorted((game_dir / "Image").rglob("*.hed")):
        data = hed_path.read_bytes()
        if len(data) % HED_ENTRY.size != 0:
            raise RuntimeError(f"HED length is not aligned: {hed_path}")

        for position in range(0, len(data), HED_ENTRY.size):
            blob = data[position : position + HED_ENTRY.size]
            md5, offset, data_length, actual_length = HED_ENTRY.unpack(blob)
            name = wanted.get(md5)
            if name is None:
                continue
            if name in located:
                raise RuntimeError(f"Duplicate HED entry for {name}")
            located[name] = {
                "hed": hed_path,
                "blob": blob,
                "offset": offset,
                "data_length": data_length,
                "actual_length": actual_length,
            }

    missing = sorted(set(assets) - set(located))
    if missing:
        raise RuntimeError("Assets not present in HED indices: " + ", ".join(missing))
    return located


def extract_grouped(
    tool: Path,
    output: Path,
    located: dict[str, dict],
) -> None:
    groups: dict[Path, list[dict]] = {}
    for item in located.values():
        groups.setdefault(item["hed"], []).append(item)

    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="kh2jokcombat-hed-", dir=output) as raw_stage:
        stage = Path(raw_stage)
        for hed_path, entries in sorted(groups.items(), key=lambda pair: str(pair[0])):
            subset_hed = stage / hed_path.name
            subset_pkg = subset_hed.with_suffix(".pkg")
            source_pkg = hed_path.with_suffix(".pkg")
            subset_hed.write_bytes(b"".join(item["blob"] for item in entries))
            os.link(source_pkg, subset_pkg)
            subprocess.run(
                [str(tool), "hed", "extract", str(subset_hed), "-o", str(output)],
                check=True,
            )


def main() -> int:
    args = parse_args()
    assets = list(dict.fromkeys(normalized_asset_name(item) for item in args.asset))
    game_dir = args.game_dir.resolve()
    tool = args.openkh_tool.resolve()
    output = args.output.resolve()

    if not (game_dir / "Image").is_dir():
        raise RuntimeError(f"Missing game Image directory: {game_dir}")
    if not tool.is_file():
        raise RuntimeError(f"Missing OpenKH extraction tool: {tool}")

    located = locate_entries(game_dir, assets)
    extract_grouped(tool, output, located)

    manifest = []
    for name in assets:
        extracted = output / "original" / Path(name)
        if not extracted.is_file():
            raise RuntimeError(f"OpenKH did not produce {extracted}")
        entry = located[name]
        manifest.append(
            {
                "asset": name,
                "source_hed": str(entry["hed"]),
                "offset": entry["offset"],
                "data_length": entry["data_length"],
                "actual_length": entry["actual_length"],
                "extracted_length": extracted.stat().st_size,
                "sha256": sha256(extracted),
            }
        )

    manifest_path = output / "extraction-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"EXTRACT_OK assets={len(manifest)} manifest={manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
