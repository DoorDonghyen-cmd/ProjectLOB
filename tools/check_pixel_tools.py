"""Exercise real pixel conversion and FX sheet export away from game assets/saves."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / 'qa_runtime/pixel_tools_20261105'


def run(*args):
    result = subprocess.run(list(map(str, args)), cwd=REPO, capture_output=True,
                            encoding='utf-8', errors='replace', timeout=120)
    if result.returncode:
        raise RuntimeError(f'{args[0]}: {result.stdout}\n{result.stderr}')
    return result.stdout.strip()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    lock = json.loads((REPO / 'tools/art_tooling.lock.json').read_text(encoding='utf-8'))
    for name in ['pixeloe', 'pixelfx']:
        spec = lock['sources'][name]
        assert run('git', '-C', spec['local_source'], 'rev-parse', 'HEAD') == spec['commit'], name
        assert not run('git', '-C', spec['local_source'], 'diff', '--name-only'), name
        for relative, digest in spec['notice_sha256'].items():
            assert hashlib.sha256((REPO / relative).read_bytes()).hexdigest() == digest, relative
    python = Path(lock['sources']['pixeloe']['environment']) / 'Scripts/python.exe'
    requirements = lock['sources']['pixeloe']
    assert hashlib.sha256((REPO / requirements['requirements']).read_bytes()).hexdigest() == requirements['requirements_sha256']
    run(python, '-m', 'pip', 'check')
    fixture = Image.new('RGB', (256, 192), '#27221f')
    draw = ImageDraw.Draw(fixture)
    draw.rectangle((28, 36, 210, 154), fill='#746755', outline='#c6ae7a', width=3)
    draw.ellipse((76, 48, 162, 134), fill='#a85632', outline='#e2d6b5', width=2)
    draw.line((14, 170, 240, 20), fill='#e6ba62', width=3)
    source = OUT / 'fixture.png'
    target = OUT / 'pixeloe.png'
    fixture.save(source)
    original = hashlib.sha256(source.read_bytes()).hexdigest()
    run(sys.executable, REPO / 'tools/pixeloe_tool.py', source, '-O', target,
        '-S', '64', '48', '-P', '4', '--colors', '16', '--no_upscale')
    with Image.open(target) as output:
        assert output.size == (64, 48), output.size
        assert len(output.getcolors(64 * 48) or []) > 1, 'Blank PixelOE output'
    assert original == hashlib.sha256(source.read_bytes()).hexdigest(), 'Changed input'
    effects = ['impacts/bullet-impact', 'fire/torch']
    export = OUT / 'pixelfx'
    run('node', REPO / 'tools/pixelfx.mjs', 'render', *effects, '--sheet', '--out', export)
    checks = run('node', REPO / 'tools/pixelfx.mjs', 'check', *effects)
    sheets = {}
    for effect in effects:
        name = effect.split('/')[1]
        base = export / effect / name
        data = json.loads(base.with_suffix('.json').read_text(encoding='utf-8'))
        frames = data['frames']
        with Image.open(base.with_suffix('.png')) as sheet:
            assert sheet.mode == 'RGBA', sheet.mode
            lo, hi = sheet.getchannel('A').getextrema()
            assert lo == 0 and hi > 0, 'Missing transparency or pixels'
            for item in frames.values() if isinstance(frames, dict) else frames:
                frame = item['frame']
                assert 0 <= frame['x'] and 0 <= frame['y']
                assert 0 < frame['w'] and 0 < frame['h']
                assert frame['x'] + frame['w'] <= sheet.width
                assert frame['y'] + frame['h'] <= sheet.height
                assert item['duration'] > 0
        assert len(frames) > 1
        sheets[effect] = len(frames)
    report = {'status': 'passed', 'pixeloe': {'output_size': [64, 48],
              'input_preserved': True, 'backend': 'legacy CPU CLI'},
              'pixelfx_frames': sheets, 'upstream_checks': checks,
              'scope': 'Local tooling only. GPU, Godot integration and art quality not established.'}
    (OUT / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False))


if __name__ == '__main__':
    main()
