#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable

PHOTO_EXTENSIONS = {
    ".jpg", ".jpeg", ".heic", ".heif", ".png", ".tif", ".tiff",
    ".dng", ".cr2", ".cr3", ".nef", ".arw", ".rw2", ".orf",
}

VIDEO_EXTENSIONS = {
    ".mov", ".mp4", ".m4v", ".avi",
}

EXIF_TAGS = [
    "DateTimeOriginal",
    "SubSecDateTimeOriginal",
    "CreateDate",
    "MediaCreateDate",
    "TrackCreateDate",
]

SORTED_FOLDER_NAME = "sorted"
LOG_DIRECTORY = Path.home() / "Library" / "Logs" / "photos-trieur"


def resolve_exiftool() -> str:
    configured = os.environ.get("EXIFTOOL_BIN")
    if configured:
        candidate = Path(configured).expanduser()
        if candidate.exists() and os.access(candidate, os.X_OK):
            return str(candidate)

    found = shutil.which("exiftool")
    if found:
        return found

    common_paths = [
        Path("/opt/homebrew/bin/exiftool"),
        Path("/usr/local/bin/exiftool"),
        Path("/usr/bin/exiftool"),
    ]
    for candidate in common_paths:
        if candidate.exists() and os.access(candidate, os.X_OK):
            return str(candidate)

    raise RuntimeError("exiftool is required. Install it with: brew install exiftool")


@dataclass
class Decision:
    month: str | None
    reason: str


def valid_year(year: int) -> bool:
    current_year = datetime.now().year
    return 1900 <= year <= current_year + 1


def parse_date_to_month(value: str | None) -> str | None:
    if not value or not isinstance(value, str):
        return None

    match = re.search(r"((?:19|20)\d{2})[:\-]([01]\d)[:\-]([0-3]\d)", value)
    if not match:
        return None

    year, month, day = map(int, match.groups())
    try:
        candidate = datetime(year, month, day)
    except ValueError:
        return None

    if not valid_year(candidate.year):
        return None

    return candidate.strftime("%Y-%m")


def filename_months(path: Path) -> set[str]:
    name = path.name
    months: set[str] = set()
    patterns = [
        r"(?<!\d)((?:19|20)\d{2})[-_ .]?([01]\d)[-_ .]?([0-3]\d)(?!\d)",
        r"(?<!\d)((?:19|20)\d{2})[-_ .]?([01]\d)(?!\d)",
    ]

    for pattern in patterns:
        for match in re.finditer(pattern, name):
            groups = match.groups()
            year = int(groups[0])
            month = int(groups[1])

            if not valid_year(year) or not 1 <= month <= 12:
                continue

            if len(groups) >= 3:
                day = int(groups[2])
                try:
                    datetime(year, month, day)
                except ValueError:
                    continue

            months.add(f"{year:04d}-{month:02d}")

    return months


def choose_month(path: Path, metadata: dict[str, str]) -> Decision:
    metadata_months = []
    for tag in EXIF_TAGS:
        month = parse_date_to_month(metadata.get(tag))
        if month:
            metadata_months.append((tag, month))

    unique_metadata_months = sorted({month for _, month in metadata_months})
    unique_filename_months = sorted(filename_months(path))

    if len(unique_metadata_months) > 1:
        return Decision(None, "metadata_conflict")

    if len(unique_filename_months) > 1:
        return Decision(None, "filename_conflict")

    metadata_month = unique_metadata_months[0] if unique_metadata_months else None
    filename_month = unique_filename_months[0] if unique_filename_months else None

    if metadata_month and filename_month and metadata_month != filename_month:
        return Decision(None, f"metadata_filename_mismatch:{metadata_month}:{filename_month}")

    if metadata_month:
        return Decision(metadata_month, "metadata")

    if filename_month:
        return Decision(filename_month, "filename")

    return Decision(None, "no_reliable_date")


def iter_media_files(source_root: Path, output_root: Path, include_videos: bool) -> Iterable[Path]:
    extensions = PHOTO_EXTENSIONS | (VIDEO_EXTENSIONS if include_videos else set())

    for dirpath, dirnames, filenames in os.walk(source_root):
        current_dir = Path(dirpath)

        if current_dir == output_root or output_root in current_dir.parents:
            continue

        dirnames[:] = [
            name for name in dirnames
            if not name.startswith(".")
            and (current_dir / name) != output_root
        ]

        for filename in filenames:
            if filename.startswith("."):
                continue

            path = current_dir / filename
            if path.is_symlink():
                continue

            if path.suffix.lower() in extensions:
                yield path


def batched(items: list[Path], size: int) -> Iterable[list[Path]]:
    batch: list[Path] = []
    for item in items:
        batch.append(item)
        if len(batch) >= size:
            yield batch
            batch = []
    if batch:
        yield batch


def read_metadata_batch(paths: list[Path]) -> dict[Path, dict[str, str]]:
    exiftool_bin = resolve_exiftool()
    command = [
        exiftool_bin,
        "-json",
        "-api", "LargeFileSupport=1",
        "-charset", "filename=UTF8",
        *[f"-{tag}" for tag in EXIF_TAGS],
        *[str(path) for path in paths],
    ]

    try:
        result = subprocess.run(command, capture_output=True, text=True, check=False)
    except FileNotFoundError as exc:
        raise RuntimeError("exiftool is required. Install it with: brew install exiftool") from exc

    if result.returncode not in (0, 1):
        message = result.stderr.strip() or "exiftool failed"
        raise RuntimeError(message)

    if not result.stdout.strip():
        return {}

    records = json.loads(result.stdout)
    metadata_by_path: dict[Path, dict[str, str]] = {}
    for record in records:
        source_file = record.get("SourceFile")
        if source_file:
            metadata_by_path[Path(source_file)] = record
    return metadata_by_path


def ensure_unique_destination(path: Path) -> Path:
    if not path.exists():
        return path

    stem = path.stem
    suffix = path.suffix
    index = 1
    while True:
        candidate = path.with_name(f"{stem}__dup{index}{suffix}")
        if not candidate.exists():
            return candidate
        index += 1


def default_log_path() -> Path:
    LOG_DIRECTORY.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    return LOG_DIRECTORY / f"photos-trieur-{timestamp}.csv"


def write_log_header(writer: csv.writer, log_path: Path) -> None:
    if log_path.exists() and log_path.stat().st_size > 0:
        return

    writer.writerow([
        "timestamp",
        "mode",
        "status",
        "source",
        "destination",
        "month",
        "reason",
    ])


def process(source_root: Path, destination_parent: Path, apply_changes: bool, include_videos: bool, batch_size: int, log_path: Path, summary_file: Path | None = None) -> dict[str, object]:
    output_root = destination_parent / SORTED_FOLDER_NAME
    files = sorted(iter_media_files(source_root, output_root, include_videos))

    moved_count = 0
    skipped_count = 0
    error_count = 0

    log_path.parent.mkdir(parents=True, exist_ok=True)

    with log_path.open("a", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle, delimiter=";")
        write_log_header(writer, log_path)

        total = len(files)
        print(f"Files found   : {total}")
        print(f"Output folder : {output_root}")
        print(f"Log file      : {log_path}")

        for index, batch in enumerate(batched(files, batch_size), start=1):
            print(f"Batch {index}: {min(index * batch_size, total)}/{total}")
            metadata_by_path = read_metadata_batch(batch)

            for source_path in batch:
                now = datetime.now().isoformat(timespec="seconds")
                decision = choose_month(source_path, metadata_by_path.get(source_path, {}))

                if not decision.month:
                    skipped_count += 1
                    writer.writerow([now, "apply" if apply_changes else "dry-run", "SKIP", str(source_path), "", "", decision.reason])
                    continue

                target_dir = output_root / decision.month
                target_path = ensure_unique_destination(target_dir / source_path.name)

                if apply_changes:
                    try:
                        target_dir.mkdir(parents=True, exist_ok=True)
                        shutil.move(str(source_path), str(target_path))
                        moved_count += 1
                        writer.writerow([now, "apply", "MOVED", str(source_path), str(target_path), decision.month, decision.reason])
                    except Exception as exc:
                        error_count += 1
                        writer.writerow([now, "apply", "ERROR", str(source_path), str(target_path), decision.month, str(exc)])
                else:
                    moved_count += 1
                    writer.writerow([now, "dry-run", "WOULD_MOVE", str(source_path), str(target_path), decision.month, decision.reason])

    summary = {
        "source_root": str(source_root),
        "output_root": str(output_root),
        "log_path": str(log_path),
        "files_found": len(files),
        "movable": moved_count,
        "skipped": skipped_count,
        "errors": error_count,
        "mode": "apply" if apply_changes else "dry-run",
    }

    if summary_file:
        summary_file.parent.mkdir(parents=True, exist_ok=True)
        summary_file.write_text(json.dumps(summary, ensure_ascii=True), encoding="utf-8")

    print(json.dumps(summary, indent=2, ensure_ascii=True))
    return summary


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sort photos into YYYY-MM folders when the date is unambiguous."
    )
    parser.add_argument("source", help="Source folder to scan recursively")
    parser.add_argument("destination", help="Parent folder that will receive the 'sorted' folder")
    parser.add_argument("--apply", action="store_true", help="Move files instead of running a dry-run")
    parser.add_argument("--include-videos", action="store_true", help="Include MOV/MP4/M4V/AVI files")
    parser.add_argument("--batch-size", type=int, default=200, help="Number of files sent to exiftool per batch")
    parser.add_argument("--log-file", help="CSV log path. Defaults to ~/Library/Logs/tri-photos-simple/")
    parser.add_argument("--summary-file", help="Write summary JSON to this file")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source_root = Path(args.source).expanduser().resolve()
    destination_parent = Path(args.destination).expanduser().resolve()
    log_path = Path(args.log_file).expanduser().resolve() if args.log_file else default_log_path()
    summary_file = Path(args.summary_file).expanduser().resolve() if args.summary_file else None

    if not source_root.is_dir():
        print(f"Source folder not found: {source_root}", file=sys.stderr)
        return 2

    if not destination_parent.is_dir():
        print(f"Destination folder not found: {destination_parent}", file=sys.stderr)
        return 2

    try:
        process(
            source_root=source_root,
            destination_parent=destination_parent,
            apply_changes=args.apply,
            include_videos=args.include_videos,
            batch_size=max(1, args.batch_size),
            log_path=log_path,
            summary_file=summary_file,
        )
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
