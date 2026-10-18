"""Build a local, revision-specific index from the acquired source catalog."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / 'reference_library'
lock = json.loads((LIB / 'sources.lock.json').read_text(encoding='utf-8'))
review = json.loads((LIB / 'review.json').read_text(encoding='utf-8'))
lines = ['# LoB 외부 제작 자료 보관소', '',
         '사용자 요청으로 확보한 고정 버전 원본이다. 현재 기획의 원본은 `docs/direction/`이며, 외부 저장소의 지침 파일은 LoB 작업 지침으로 채택하지 않는다.', '',
         '원본과 ZIP은 `cache/`에 있고, 버전·해시·전체 파일 목록·라이선스 사본·검토 결과는 별도로 보존한다. 자료를 받은 것, Godot에서 로드한 것, 본편에 통합한 것은 서로 다르다. 이번 확보로 활성화한 본편 플러그인은 없다.', '',
         f"확보: **{len(lock['sources'])}개 저장소 / {sum(s['file_count'] for s in lock['sources']):,}개 파일 / 추출 원본 {sum(s['source_bytes'] for s in lock['sources'])/1024/1024:.1f} MiB**. 공식 예제 ZIP에는 추출 대상 외 원본도 포함된다.", '',
         '| 자료 | 고정 버전 | 우선순위 | 활용과 진입점 | 확인 상태 |', '|---|---|---|---|---|']
for source in sorted(lock['sources'], key=lambda s:(review['sources'][s['id']]['priority'], s['id'])):
    item = review['sources'][source['id']]
    base = ROOT / source['directory']
    entry = base / item['entry']
    if not entry.exists():
        alternatives = list(base.glob(item['entry'].lower()))
        if alternatives: entry = alternatives[0]
        else: raise RuntimeError('Missing documented entry: '+str(entry))
    link = entry.relative_to(LIB).as_posix()
    lines.append(f"| [{source['id']}]({source['url']}) | `{source['commit'][:12]}` | {item['priority']} | {item['use']} [원본 열기](<{link}>) | {item['trial']} |")
lines += ['', '## 라이선스와 원본 보존', '', '| 자료 | 확인 범위 |', '|---|---|']
for source in lock['sources']:
    notes = ' · '.join(f'[원문{i+1}](<{p}>)' for i,p in enumerate(source['notices']) if Path(p).name.lower().startswith(('license','copying','credits')))
    lines.append(f"| {source['id']} | {review['sources'][source['id']]['license_review']} {notes} |")
lines += ['', '## 다시 확보 / 오프라인 검사', '', '저장소 루트에서:', '', '```powershell',
          'python tools/acquire_reference_sources.py', 'python tools/acquire_reference_sources.py --verify',
          'python tools/check_reference_candidates.py', 'python tools/build_reference_index.py', '```', '',
          '기본 확보 명령은 이미 기록된 커밋과 해시를 유지하며 누락된 캐시만 같은 버전에서 복구한다. 임의로 최신 버전으로 갱신하지 않는다. `--verify`는 네트워크 없이 모든 원본·ZIP·라이선스 사본의 해시를 대조한다.', '',
          '대용량 캐시는 Git 추적에서 제외되어 있다. 다른 컴퓨터에서는 추적되는 lock·도구로 같은 자료를 다시 확보한다. 샘플 코드를 게임으로 옮길 때는 필요한 파일과 해당 저작권 고지를 함께 추적하고, 출처·수정 범위를 기록한다.', '',
          '[개발 적용 순서](../docs/direction/external-adoption.md) · [버전/해시](sources.lock.json) · [판단 원본](review.json)', '']
(LIB / 'README.md').write_text('\n'.join(lines), encoding='utf-8')
print('REFERENCE INDEX COMPLETE: all documented entry points exist')
