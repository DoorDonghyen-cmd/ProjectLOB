"""Launch the project pixel editor, forwarding CLI arguments unchanged."""
from pathlib import Path
import os
import subprocess
import sys


def workspace_root() -> Path:
    for parent in Path(__file__).resolve().parents:
        if (parent / '.tools' / 'libresprite-1.3' / 'libresprite.exe').is_file():
            return parent
    raise FileNotFoundError('Project LibreSprite installation was not found.')


def main() -> int:
    root = workspace_root()
    executable = root / '.tools/libresprite-1.3/libresprite.exe'
    config_dir = root / '.tools/libresprite-user'
    config_dir.mkdir(parents=True, exist_ok=True)
    child_env = os.environ.copy()
    # LibreSprite uses AppData for its preferences even in batch mode.
    child_env['APPDATA'] = str(config_dir)
    args = sys.argv[1:]
    batch = any(arg in ('-b', '--batch', '--version', '--help') for arg in args)
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' and batch else 0
    if batch:
        result = subprocess.run([str(executable), *args], env=child_env,
                                creationflags=flags, capture_output=True)
        sys.stdout.buffer.write(result.stdout)
        sys.stderr.buffer.write(result.stderr)
        return result.returncode
    return subprocess.call([str(executable), *args], env=child_env)


if __name__ == '__main__':
    raise SystemExit(main())
