#!/usr/bin/env python3
"""
Regenerate codebase_dump.txt in the same format as the existing dump:
  ./FrontDip/MessengerApp/<relative>.swift
  <blank line>
  <file contents — or two blank lines before the next path if the file is empty>

Scans FrontDip/MessengerApp for *.swift by default. Run from repo root (parent of
FrontDip/) or pass --messenger-root explicitly.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


DUMP_PREFIX = "FrontDip/MessengerApp"


def find_messenger_app(start: Path) -> Path:
    for base in [start.resolve(), *start.resolve().parents]:
        candidate = base / "FrontDip" / "MessengerApp"
        if candidate.is_dir():
            return candidate
    raise SystemExit(
        "Could not find FrontDip/MessengerApp. Run from the repo root "
        "(directory that contains FrontDip/) or pass --messenger-root."
    )


def collect_swift_files(root: Path) -> list[Path]:
    files = sorted(
        p for p in root.rglob("*.swift") if p.is_file() and not _is_skipped(p, root)
    )
    return files


def _is_skipped(path: Path, root: Path) -> bool:
    rel = path.relative_to(root)
    parts = set(rel.parts)
    skip_dirs = {
        "DerivedData",
        "build",
        ".build",
        "Pods",
        "Carthage",
        "xcuserdata",
    }
    return bool(parts & skip_dirs)


def dump_path_for(file_path: Path, messenger_root: Path) -> str:
    rel = file_path.relative_to(messenger_root).as_posix()
    return f"./{DUMP_PREFIX}/{rel}"


def build_dump(files: list[Path], messenger_root: Path) -> str:
    parts: list[str] = []
    prev_empty = False

    for i, fp in enumerate(files):
        display = dump_path_for(fp, messenger_root)
        raw = fp.read_text(encoding="utf-8", errors="replace")
        body = raw.replace("\r\n", "\n").replace("\r", "\n")
        # Match legacy dump: exactly one blank line after the path line; strip
        # leading newlines from disk so a file starting with "\nimport ..." does
        # not add an extra blank.
        body = body.lstrip("\n")
        is_empty = len(body) == 0

        if i > 0 and not prev_empty:
            parts.append("\n")
        if is_empty:
            parts.append(f"{display}\n\n\n")
        else:
            if not body.endswith("\n"):
                body += "\n"
            parts.append(f"{display}\n\n{body}")

        prev_empty = is_empty

    text = "".join(parts)
    if not text.endswith("\n"):
        text += "\n"
    return text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--messenger-root",
        type=Path,
        help=f"Path to {DUMP_PREFIX} (default: discover upward from cwd)",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("codebase_dump.txt"),
        help="Output file (default: ./codebase_dump.txt)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print stats only, do not write",
    )
    args = parser.parse_args()

    cwd = Path.cwd()
    messenger_root = (
        args.messenger_root.resolve()
        if args.messenger_root
        else find_messenger_app(cwd)
    )

    if not messenger_root.is_dir():
        print(f"Not a directory: {messenger_root}", file=sys.stderr)
        return 1

    files = collect_swift_files(messenger_root)
    if not files:
        print(f"No .swift files under {messenger_root}", file=sys.stderr)
        return 1

    output_text = build_dump(files, messenger_root)

    out_path = args.output
    if not out_path.is_absolute():
        out_path = (cwd / out_path).resolve()

    print(
        f"MessengerApp root: {messenger_root}\n"
        f"Swift files: {len(files)}\n"
        f"Output: {out_path}",
        file=sys.stderr,
    )

    if args.dry_run:
        return 0

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(output_text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
