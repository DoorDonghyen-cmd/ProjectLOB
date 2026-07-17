#!/usr/bin/env bash
# Last on Board · 헤드리스 테스트 러너 (Linux/macOS/CI)
# 사용법:  GODOT=/path/to/godot ./tests/run.sh   (없으면 PATH의 'godot' 사용)
set -euo pipefail

GODOT="${GODOT:-godot}"
PROJ="$(cd "$(dirname "$0")/.." && pwd)"

echo "Godot:   $GODOT"
echo "Project: $PROJ"
exec "$GODOT" --headless --path "$PROJ" --script res://tests/run_all.gd
