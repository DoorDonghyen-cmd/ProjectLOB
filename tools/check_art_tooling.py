"""Exercise pixel export and the installed visual QA helpers in an isolated folder."""
from pathlib import Path
import json
import subprocess
import sys

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / 'qa_runtime/art_tooling'
SKILLS = REPO / '.agents/skills'


def run(*args: str) -> subprocess.CompletedProcess:
    result = subprocess.run([sys.executable, *map(str, args)], cwd=REPO,
                            capture_output=True, encoding='utf-8', errors='replace', timeout=30)
    if result.returncode:
        raise RuntimeError(f'{args[0]} failed ({result.returncode}): {result.stdout} {result.stderr}')
    return result


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    # A tiny synthetic fixture verifies round-trip pixels, not art quality.
    pixels = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for y in range(4, 12):
        for x in range(5, 11):
            pixels.putpixel((x, y), (237, 196, 122, 255) if x < 8 else (26, 40, 51, 255))
    fixture = OUT / 'fixture.png'
    pixels.save(fixture)
    run(REPO / 'tools/pixel_editor.py', '--batch', fixture, '--save-as', OUT / 'fixture.ase')
    run(REPO / 'tools/pixel_editor.py', '--batch', OUT / 'fixture.ase',
        '--sheet', OUT / 'sheet.png', '--data', OUT / 'sheet.json', '--format', 'json-array')
    with Image.open(OUT / 'sheet.png') as exported:
        if exported.size != pixels.size or exported.convert('RGBA').tobytes() != pixels.tobytes():
            raise RuntimeError('Sprite export changed the dimensions or RGBA pixels')
    metadata = json.loads((OUT / 'sheet.json').read_text(encoding='utf-8'))
    if len(metadata['frames']) != 1:
        raise RuntimeError('Sprite-sheet JSON frame count is incorrect')
    asset = run(SKILLS / 'create-game-assets/scripts/asset_report.py', OUT / 'sheet.png',
                '--expect-size', '16x16', '--require-alpha', '--max-colors', '4', '--json')
    (OUT / 'asset_report.json').write_text(asset.stdout, encoding='utf-8')
    alpha = run(SKILLS / 'godot-ui-integration/scripts/alpha_audit.py', OUT / 'sheet.png')
    (OUT / 'alpha_report.txt').write_text(alpha.stdout, encoding='utf-8')
    run(SKILLS / 'create-game-assets/scripts/build_preview_sheet.py', fixture,
        '--out', OUT / 'preview.png', '--columns', '1', '--cell-size', '128')
    run(SKILLS / 'godot-ui-integration/scripts/reference_parity_audit.py',
        '--reference', fixture, '--runtime', OUT / 'sheet.png', '--out', OUT / 'parity.png')
    report = {'status': 'passed', 'sprite_round_trip': 'exact RGBA match',
              'metadata_frames': 1, 'checks': ['LibreSprite PNG to ASE to sheet/JSON',
              'dimensions, palette and alpha', 'alpha audit', 'preview sheet', 'reference parity'],
              'scope': 'Tool functionality only; no game visual-quality claim.'}
    (OUT / 'art_tools.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
