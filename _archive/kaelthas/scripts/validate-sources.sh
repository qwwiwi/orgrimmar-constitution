#!/bin/bash
set -euo pipefail

WS="/home/openclaw/.openclaw/workspaces/kaelthas"
SOURCES_DIR="${WS}/sources"

python3 - "$SOURCES_DIR" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
files = sorted(root.rglob("*.md"))
if not files:
    print("NO_SOURCE_FILES")
    raise SystemExit(0)

name_re = re.compile(r"^\d{4}-\d{2}-\d{2}-[a-z0-9-]+\.md$")
errors = []

for p in files:
    rel = p.relative_to(root)
    txt = p.read_text(encoding="utf-8")
    lines = txt.splitlines()

    if not name_re.match(p.name):
        errors.append(f"{rel}: invalid filename")

    if len(lines) < 6:
        errors.append(f"{rel}: file too short")
        continue

    if not lines[0].startswith("# source-"):
        errors.append(f"{rel}: missing '# source-' header")

    if not any(l.startswith("type:") for l in lines[:8]):
        errors.append(f"{rel}: missing type:")

    url_line = next((l for l in lines[:10] if l.startswith("url:")), None)
    if not url_line:
        errors.append(f"{rel}: missing url:")
    else:
        u = url_line.replace("url:", "", 1).strip()
        if not (u.startswith("http://") or u.startswith("https://")):
            errors.append(f"{rel}: url must start with http/https")

    tags_line = next((l for l in lines[:10] if l.startswith("tags:")), None)
    if not tags_line:
        errors.append(f"{rel}: missing tags:")
    else:
        if "[" not in tags_line or "]" not in tags_line:
            errors.append(f"{rel}: tags must be list format [a, b]")

    if "---" not in lines[:12]:
        errors.append(f"{rel}: missing frontmatter separator ---")

if errors:
    print("VALIDATION_FAILED")
    for e in errors:
        print("-", e)
    raise SystemExit(1)

print(f"VALIDATION_OK files={len(files)}")
PY
