"""Run the pinned PixelOE CPU CLI in its isolated environment."""
from pathlib import Path
import subprocess
import sys


def main() -> int:
    for parent in Path(__file__).resolve().parents:
        executable = parent / '.tools/pixeloe/venv/Scripts/pixeloe.pixelize.exe'
        if executable.is_file():
            return subprocess.call([str(executable), *(sys.argv[1:] or ['--help'])])
    print('PixelOE is not installed. See docs/art/pixel-tools.md.', file=sys.stderr)
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
