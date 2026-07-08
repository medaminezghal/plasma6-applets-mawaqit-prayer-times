#!/usr/bin/env bash
# Bump version.txt and package/metadata.json together.
#   ./bump.sh 0.4.6
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 X.Y.Z" >&2; exit 1; }
VERSION="$1"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "not x.y.z: $VERSION" >&2; exit 1; }

cd "$(dirname "$0")"
printf '%s\n' "$VERSION" > version.txt

python3 - "$VERSION" <<'PY'
import json, pathlib, sys
p = pathlib.Path("package/metadata.json")
meta = json.loads(p.read_text(encoding="utf-8"))
meta["KPlugin"]["Version"] = sys.argv[1]
p.write_text(json.dumps(meta, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")
PY

git add version.txt package/metadata.json
echo "staged version.txt + package/metadata.json at $VERSION"
