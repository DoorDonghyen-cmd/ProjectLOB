"""Retire old game assumptions in supporting role references, keeping originals."""
import argparse
import hashlib
import json
from pathlib import Path

ACTIVE = Path(__file__).resolve().parents[1]
WORKSPACE = ACTIVE.parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--target', choices=['active', 'workspace'], required=True)
    args = parser.parse_args()
    base = ACTIVE if args.target == 'active' else WORKSPACE
    archive = ACTIVE / 'docs/archive/guidance-2026-10-02' / (args.target + '-references')
    records = []
    changes = {
        'fun-rubric.md': [
            ('같은 탄 조합도 LIFO 순서가 결과를 바꾸는가', '같은 탄 조합도 발사 순서에 따라 결과가 바뀌는가'),
            ('- `강한 신호`: 세 프로필 이상에서 동일 방향', '- `반복 관찰`: 비교 가능한 여러 상황에서 같은 현상. 같은 구현의 자동 프로필 수만으로 독립적인 사람의 평가가 되지는 않는다.'),
        ],
        'player-profiles.md': [
            ('명중, 관통, 거리 제어, 생존 확정성을', '장갑 대응, 거리 제어, 생존 확정성을'),
            ('명중 게이트 통과 → 관통 게이트 통과 → 최소 거리 보전', '충돌 위험 회피 → 장갑·배리어 대응 → 최소 거리 보전'),
        ],
        'experience-report-schema.md': [
            ('"gun_id": "revolver"', '"gun_id": "single"'),
            ('`QAExperienceMetrics`는', '과거 QA 브리지의 `QAExperienceMetrics`는'),
            ('## 집계 결과', '## 과거 브리지와 현행 적용\n\n아래 클래스 이름은 과거 브리지 계약의 참고다. 현행 redesign 입력과 상태를 지원하는지 확인한 뒤 사용한다. 일반 리뷰에 JSON 계약이나 네 프로필 실행을 강제하지 않는다.\n\n## 집계 결과'),
        ],
    }
    for name, replacements in changes.items():
        relative = Path('.agents/skills/16-gameplay-experience-tester/references') / name
        path = base / relative
        if not path.exists():
            continue
        original = path.read_bytes()
        text = original.decode('utf-8').replace('\r\n', '\n').replace('\r', '')
        for old, new in replacements:
            text = text.replace(old, new)
        if text.encode('utf-8') == original:
            continue
        snapshot = archive / relative
        snapshot.parent.mkdir(parents=True, exist_ok=True)
        if not snapshot.exists():
            snapshot.write_bytes(original)
        records.append({'source': str(path), 'snapshot': str(snapshot.relative_to(ACTIVE)), 'sha256': hashlib.sha256(snapshot.read_bytes()).hexdigest()})
        path.write_text(text, encoding='utf-8', newline='\n')
    if records:
        manifest = archive / 'manifest.json'
        manifest.write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'{args.target}: refreshed {len(records)} supporting references')


if __name__ == '__main__':
    main()
