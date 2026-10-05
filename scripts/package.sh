#!/usr/bin/env bash
# Build the KDE Store upload: dist/<id>-<version>.plasmoid (a zip of the package).
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
id=$(python3 -c 'import json; print(json.load(open("metadata.json"))["KPlugin"]["Id"])')
version=$(python3 -c 'import json; print(json.load(open("metadata.json"))["KPlugin"]["Version"])')
out="dist/$id-$version.plasmoid"
mkdir -p dist
rm -f "$out"
# Include new package files before they are committed, but exclude ignored files.
git ls-files --cached --others --exclude-standard -- metadata.json contents LICENSE | zip -q -X "$out" -@
echo "$out ($(du -h "$out" | cut -f1))"
