"""Export the editable Eavesback timeline through LibreSprite; --check is read-only."""
import argparse
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import zlib
from PIL import Image

REPO = Path(__file__).resolve().parent.parent
SOURCE = REPO / 'art_source/monsters/eavesback'
PROJECT = REPO / '새-게임-프로젝트'
DEST = PROJECT / 'assets/art/monster_motion_20261011'


def string(value):
    encoded = value.encode('utf-8')
    return struct.pack('<H', len(encoded)) + encoded


def chunk(kind, data):
    return struct.pack('<IH', len(data) + 6, kind) + data


def initialize(manifest):
    """One-time lossless atlas-cell packaging. Never overwrite an edited timeline.

    Binary layout: https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md
    Creative pixel changes are made in the image tool/editor, not this packer.
    """
    target = SOURCE / manifest['source']
    if target.exists():
        raise ValueError('Timeline exists. Edit it in LibreSprite; refusing to overwrite.')
    image = Image.open(SOURCE / manifest['atlas_source']).convert('RGBA')
    w, h = manifest['cell']
    assert image.size == (w * 2, h * 2)
    layers = chunk(0x2004, struct.pack('<6HB3x', 3, 0, 0, 0, 0, 0, 255) + string('Eavesback'))
    tags = struct.pack('<H8x', len(manifest['clips']))
    for name, spec in manifest['clips'].items():
        tags += struct.pack('<HHB8x3BB', spec['from'], spec['to'], 0, 140, 172, 176, 0) + string(name)
    frames = []
    for i, duration in enumerate(manifest['initial_durations_ms']):
        x, y = i % 2 * w, i // 2 * h
        pixels = image.crop((x, y, x+w, y+h)).tobytes()
        cel = chunk(0x2005, struct.pack('<HhhBH7xHH', 0, 0, 0, 255, 2, w, h) + zlib.compress(pixels))
        chunks = [layers, chunk(0x2018, tags), cel] if i == 0 else [cel]
        payload = b''.join(chunks)
        frames.append(struct.pack('<IHHH2xI', 16+len(payload), 0xF1FA, len(chunks), duration, 0)+payload)
    body = b''.join(frames)
    header = bytearray(128)
    struct.pack_into('<I5HIH', header, 0, 128+len(body), 0xA5E0, len(frames), w, h, 32, 1, 100)
    header[34:36] = b'\x01\x01'
    target.write_bytes(bytes(header)+body)


def export(check):
    manifest = json.loads((SOURCE / 'animation.json').read_text(encoding='utf-8'))
    staging = REPO / 'qa_runtime/monster_export'
    staging.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=staging) as folder:
        sheet, meta = Path(folder)/'sheet.png', Path(folder)/'sheet.json'
        result = subprocess.run([sys.executable, str(REPO/'tools/pixel_editor.py'), '--batch',
            str(SOURCE/manifest['source']), '--sheet-type', 'horizontal', '--sheet', str(sheet),
            '--data', str(meta), '--format', 'json-array', '--list-tags'], capture_output=True, timeout=60)
        if result.returncode or not sheet.exists():
            raise RuntimeError(result.stdout.decode(errors='replace') + result.stderr.decode(errors='replace'))
        info = json.loads(meta.read_text(encoding='utf-8'))
        frames = info['frames']
        tags = {tag['name']: tag for tag in info['meta']['frameTags']}
        assert set(tags) == set(manifest['clips']), 'Required idle/walk/hit/attack tags changed'
        assert len(frames) == len(manifest['anchors']), 'Each timeline frame needs a foot anchor'
        w, h = manifest['cell']
        atlas = Image.open(sheet).convert('RGBA')
        assert atlas.size == (w*len(frames),h)
        bounds = []
        resources = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(frames)+2),
            '[ext_resource type="Texture2D" path="res://assets/art/monster_motion_20261011/eavesback.png" id="1"]']
        for i, frame in enumerate(frames):
            r = frame['frame']
            assert r == {'x': i*w, 'y': 0, 'w': w, 'h': h}, 'No trimmed/reordered frames allowed'
            assert frame['duration'] > 0
            a = manifest['anchors'][i]
            assert 0 < a[0] < w and 0 < a[1] <= h
            pixels = atlas.crop((i*w,0,(i+1)*w,h))
            # Threshold is measurement only: pixel alpha is never modified.
            b = pixels.getchannel('A').point(lambda v: 255 if v >= 128 else 0).getbbox()
            assert b and b[0] > 0 and b[1] > 0 and b[2] < w and b[3] < h, 'Clipped frame'
            assert abs(b[3]-a[1]) <= 2, 'Foot anchor must track visible planted feet'
            bounds.append(b)
            resources += ['[sub_resource type="AtlasTexture" id="Frame%d"]' % i,
                'atlas = ExtResource("1")', 'region = Rect2(%d, 0, %d, %d)' % (i*w,w,h)]
        animations = []
        for name, tag in tags.items():
            assert tag['direction'] == 'forward', 'Unsupported tag direction'
            assert 0 <= tag['from'] <= tag['to'] < len(frames)
            sequence = ['{"duration": %s, "texture": SubResource("Frame%d")}' % (frames[i]['duration'],i)
                        for i in range(tag['from'],tag['to']+1)]
            loop = str(manifest['clips'][name]['loop']).lower()
            animations.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": 1000.0}' % (','.join(sequence),loop,name))
        resources += ['[resource]', 'animations = [%s]' % ',\n'.join(animations)]
        resource_text = '\n\n'.join(resources)+'\n'
        lines = ['extends RefCounted', '# Generated by tools/export_monster_animation.py.',
            'const CELL := Vector2(%d, %d)' % (w,h),
            'const SCALE := %.9f' % manifest['display_scale'], 'const ANCHORS := [']
        lines += ['Vector2(%d,%d),' % tuple(a) for a in manifest['anchors']]
        lines += [']', 'const BOUNDS := [']
        lines += ['Rect2(%d,%d,%d,%d),' % (b[0],b[1],b[2]-b[0],b[3]-b[1]) for b in bounds]
        lines += [']']
        data = '\n'.join(lines)+'\n'
        outputs = {DEST/'eavesback_frames.tres': resource_text,
                   PROJECT/'redesign/eavesback_animation_data.gd': data}
        if check:
            assert Image.open(DEST/'eavesback.png').convert('RGBA').tobytes() == atlas.tobytes(), 'Stale runtime pixels'
            for target,text in outputs.items(): assert target.read_text(encoding='utf-8') == text, 'Stale registration/timing: '+str(target)
        else:
            DEST.mkdir(parents=True, exist_ok=True)
            (DEST/'eavesback.png').write_bytes(sheet.read_bytes())
            for target,text in outputs.items(): target.write_text(text,encoding='utf-8')
        print('MONSTER EXPORT PASS: %d frames / %d tags / durations, foot anchors and RGBA verified' % (len(frames),len(tags)))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--initialize', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.initialize:
        assert not args.check
        initialize(json.loads((SOURCE/'animation.json').read_text(encoding='utf-8')))
    export(args.check)
