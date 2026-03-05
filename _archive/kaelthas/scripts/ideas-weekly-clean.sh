#!/bin/bash
set -euo pipefail

# ideas-weekly-clean.sh
# Usage:
#   bash scripts/ideas-weekly-clean.sh [--dry-run] [MAX_DAYS]

DRY_RUN=0
MAX_DAYS=7

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    '' ) ;;
    *)
      if [[ "$arg" =~ ^[0-9]+$ ]]; then
        MAX_DAYS="$arg"
      else
        echo "ERROR: unknown argument: $arg" >&2
        echo "Usage: $0 [--dry-run] [MAX_DAYS]" >&2
        exit 2
      fi
      ;;
  esac
done

if ! [[ "$MAX_DAYS" =~ ^[0-9]+$ ]] || [ "$MAX_DAYS" -lt 1 ] || [ "$MAX_DAYS" -gt 365 ]; then
  echo "ERROR: MAX_DAYS must be an integer in range 1..365" >&2
  exit 2
fi

# preflight dependencies
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required but not found in PATH" >&2
  exit 2
fi
if ! command -v flock >/dev/null 2>&1; then
  echo "ERROR: flock is required but not found in PATH" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="$(cd "${SCRIPT_DIR}/.." && pwd)"
IDEAS_FILE="${WS}/ideas/IDEAS.md"
ARCHIVE_DIR="${WS}/memory/archive/ideas-pruned"
SNAPSHOT_DIR="${ARCHIVE_DIR}/pre-clean"
LOCK_FILE="/tmp/kaelthas-ideas-weekly-clean.lock"

mkdir -p "$ARCHIVE_DIR" "$SNAPSHOT_DIR"

# Protect against concurrent runs/manual edits during cleanup.
exec 9>"$LOCK_FILE"
flock -x 9

python3 - "$IDEAS_FILE" "$ARCHIVE_DIR" "$SNAPSHOT_DIR" "$MAX_DAYS" "$DRY_RUN" <<'PY'
from __future__ import annotations

import datetime as dt
import os
import re
import sys
import tempfile
from pathlib import Path

ideas_path = Path(sys.argv[1])
archive_dir = Path(sys.argv[2])
snapshot_dir = Path(sys.argv[3])
max_days = int(sys.argv[4])
dry_run = bool(int(sys.argv[5]))

if not ideas_path.exists():
    print(f"ERROR: ideas file not found: {ideas_path}")
    raise SystemExit(1)

today = dt.datetime.now(dt.timezone.utc).date()
text = ideas_path.read_text(encoding="utf-8")
lines = text.splitlines(keepends=True)

section = None
in_new_ideas = False
found_new_ideas_header = False
in_html_comment = False

blocks = []
unexpected_lines = []

i = 0
while i < len(lines):
    line = lines[i]

    if "<!--" in line:
        in_html_comment = True
    if in_html_comment:
        if "-->" in line:
            in_html_comment = False
        i += 1
        continue

    if line.startswith("## ideas-"):
        section = line.strip().replace("## ", "")
        in_new_ideas = False
        i += 1
        continue

    if line.startswith("## Новые идеи"):
        in_new_ideas = True
        found_new_ideas_header = True
        i += 1
        continue

    if line.startswith("## ") and not line.startswith("## Новые идеи"):
        in_new_ideas = False
        i += 1
        continue

    if in_new_ideas and line.startswith("- **Тема:**"):
        start = i
        j = i + 1
        while j < len(lines):
            l2 = lines[j]
            if l2.startswith("- **Тема:**"):
                break
            if l2.startswith("## "):
                break
            if l2.startswith("# "):
                break
            j += 1
        block_text = "".join(lines[start:j])
        blocks.append((start, j, section, block_text))
        i = j
        continue

    if in_new_ideas:
        s = line.strip()
        if s and s not in {"---"}:
            unexpected_lines.append((section or "unknown", line.rstrip()))

    i += 1

if not found_new_ideas_header:
    print("ERROR: format check failed - no '## Новые идеи' section found. Aborting.")
    raise SystemExit(1)

if unexpected_lines:
    print("ERROR: format check failed - unexpected non-empty lines in 'Новые идеи' section. Aborting.")
    print(f"UNEXPECTED_LINES={len(unexpected_lines)}")
    raise SystemExit(1)

remove_ranges = []
removed_by_section: dict[str, list[str]] = {}
invalid_date_blocks = []

for start, end, sec, block in blocks:
    m = re.search(r"_Дата добавления:_\s*(\d{4}-\d{2}-\d{2})", block)
    if not m:
        invalid_date_blocks.append((sec or "unknown", block))
        continue
    try:
        d = dt.date.fromisoformat(m.group(1))
    except ValueError:
        invalid_date_blocks.append((sec or "unknown", block))
        continue

    age = (today - d).days
    if age > max_days:
        remove_ranges.append((start, end))
        removed_by_section.setdefault(sec or "unknown", []).append(block.rstrip())

if invalid_date_blocks:
    print("ERROR: format check failed - found idea blocks with missing/invalid '_Дата добавления:_ YYYY-MM-DD'. Aborting.")
    print(f"INVALID_BLOCKS={len(invalid_date_blocks)}")
    raise SystemExit(1)

if not remove_ranges:
    print("NO_CHANGES")
    raise SystemExit(0)

count = sum(len(v) for v in removed_by_section.values())
stamp_day = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")
stamp_ts = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H%M%SZ")
archive_path = archive_dir / f"ideas-pruned-{stamp_day}.md"
snapshot_path = snapshot_dir / f"ideas-{stamp_ts}.md"

print(f"PRUNED={count}")
print(f"ARCHIVE={archive_path}")
print(f"SNAPSHOT={snapshot_path}")
print(f"DRY_RUN={1 if dry_run else 0}")

if dry_run:
    raise SystemExit(0)

# snapshot before mutation
snapshot_path.write_text(text, encoding="utf-8")

keep = [True] * len(lines)
for s, e in remove_ranges:
    for k in range(s, e):
        keep[k] = False

new_lines = [ln for idx, ln in enumerate(lines) if keep[idx]]
new_text = "".join(new_lines)
new_text = re.sub(r"\n{4,}", "\n\n\n", new_text)

# atomic write for IDEAS.md
fd, tmp_name = tempfile.mkstemp(prefix=".ideas.", suffix=".tmp", dir=str(ideas_path.parent))
os.close(fd)
Path(tmp_name).write_text(new_text, encoding="utf-8")
os.replace(tmp_name, ideas_path)

chunks = []
chunks.append(f"# Pruned ideas ({stamp_day})\n\n")
chunks.append(f"Правило: удалены идеи из блока 'Новые идеи' старше {max_days} дней.\n\n")
for sec, entries in removed_by_section.items():
    chunks.append(f"## {sec}\n\n")
    for entry in entries:
        chunks.append(entry + "\n\n")

# atomic append/write for archive file
if archive_path.exists():
    archive_text = archive_path.read_text(encoding="utf-8") + "\n" + "".join(chunks)
else:
    archive_text = "".join(chunks)

fd2, tmp_arc = tempfile.mkstemp(prefix=".ideas-archive.", suffix=".tmp", dir=str(archive_path.parent))
os.close(fd2)
Path(tmp_arc).write_text(archive_text, encoding="utf-8")
os.replace(tmp_arc, archive_path)
PY
