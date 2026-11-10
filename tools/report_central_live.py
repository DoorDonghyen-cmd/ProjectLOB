"""Archive the completed isolated central/full-campaign checks and summarize them."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / 'qa_runtime/central_live'
OUT = ROOT / 'docs/qa/reports/assets/central_live_2026-10-26'
TAGS = ['final_17', 'final_731042', 'final_931104', 'fit_heavy_731042']
NAMES = {'single': '리벳', 'burst': '래칫', 'scatter': '스플린터', 'heavy': '리액터', 'amplifier': '스파이크'}

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def copy(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)

reports = {tag: read(RUNTIME / 'balance' / tag / 'balance.json') for tag in TAGS}
for tag, report in reports.items():
    assert len(report['endpoints']) == (1 if tag.startswith('fit_') else 5), f'Run unfinished: {tag}'
    assert 'CENTRAL LIVE BALANCE COMPLETE' in (RUNTIME / 'balance' / tag / 'stdout.log').read_text(encoding='utf-8'), f'Runner unfinished: {tag}'
ui = read(RUNTIME / 'ui/final_review/visual_qa.json')
rules = read(RUNTIME / 'rules/final_pass/rules.json')
assert ui['failures'] == 0 and rules['failures'] == 0

for tag in TAGS:
    for filename in ['balance.json', 'stdout.log', 'stderr.log']:
        copy(RUNTIME/'balance'/tag/filename, OUT/tag/filename)
for name, source in [('rules', 'rules/final_pass'), ('ui', 'ui/final_review'), ('import', 'import/final')]:
    for file in (RUNTIME/source).iterdir():
        if file.is_file() and file.suffix in ['.png', '.json', '.log']:
            copy(file, OUT/name/file.name)
for name, source in {
    'foundry': 'qa_runtime/foundry_live/rules/stdout.log',
    'garden': 'qa_runtime/garden_live/rules/stdout.log',
    'noble': 'qa_runtime/noble_live/rules/stdout.log',
    'reactor': 'docs/qa/reports/assets/art_cohesion_2026-10-24/rules.log',
    'heat': 'qa_runtime/heat/rules/stdout.log',
    'incendiary': 'qa_runtime/incendiary/rules/stdout.log',
}.items():
    copy(ROOT/source, OUT/'regressions'/f'{name}.log')
for tag in ['expanded_search', 'finite_score', 'tuning', 'tempo', 'roles_final']:
    copy(RUNTIME/'probe'/tag/'balance.json', OUT/'investigation'/f'{tag}.json')
for tag, file in [('matrix_731042','combat_heavy_731042_r1_n802.json'), ('matrix_17','combat_burst_17_r5_n41002.json'), ('final_731042','combat_heavy_731042_r2_n10902.json')]:
    copy(RUNTIME/'balance'/tag/file, OUT/'investigation'/file)

baseline = [r for tag, report in reports.items() if not tag.startswith('fit_') for r in report['endpoints']]
fit = reports['fit_heavy_731042']['endpoints'][0]
battles = [battle for report in reports.values() for battle in report['battles']]
baseline_wins = sum(r['won'] for r in baseline)
checks = sum(r['checks'] for r in reports.values())
failed = [{'tag': tag, 'messages': r['failures']} for tag, r in reports.items() if r['failures']]
rows = []
for gun, name in NAMES.items():
    statuses = []
    for seed in [17, 731042, 931104]:
        run = next(r for r in baseline if r['gun'] == gun and r['seed'] == seed)
        statuses.append('완주' if run['won'] else f"{run['region']}구역 탐색 실패")
    rows.append('| '+name+' | '+' | '.join(statuses)+' |')
table = '\n'.join(rows)
metrics = []
for gun, name in NAMES.items():
    data = [b for b in battles if b['gun'] == gun and b['solved']]
    final = [b for b in data if b['region'] == 5 and b['boss']]
    span = lambda key: f"{min(b[key] for b in final)}~{max(b[key] for b in final)}" if final else '없음'
    metrics.append(f"| {name} | {len(data)} | {min(b['remaining'] for b in data)} | {min(b['margin'] for b in data)}m | {span('turns')} | {span('remaining')} |")
metric_table = '\n'.join(metrics)

files = [ROOT/'새-게임-프로젝트/redesign'/name for name in ['central_guard.gd', 'central_art.gd', 'central_battle_view.gd', 'provisional_balance.gd', 'model.gd', 'campaign_content.gd', 'campaign.gd']]
hashes = {file.relative_to(ROOT).as_posix(): sha(file) for file in files}
summary = {'baseline_wins': baseline_wins, 'baseline_cases': 15, 'alternative_heavy_won': fit['won'], 'campaign_checks': checks, 'campaign_failures': failed, 'attempted_battles': len(battles), 'solved_battles': sum(b['solved'] for b in battles), 'rules': rules, 'ui': ui, 'source_sha256': hashes, 'interpretation': 'Bounded future-RNG search and current-model replay; not human win rate. One first-option acquisition policy may remain unsuccessful.'}
(OUT/'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

report = f'''# 중앙 친위대 B 본편·1~5구역 임시 밸런스 — 2026-10-26

사용자 선택 B 일반4종을 새 등반 편성11에 적용했다. 같은 계열의 친위대장·탑의 지배자 추가 원화와 지휘 행동, 차폐 판독, 개발 메뉴 진입, 마지막 보상·엔딩 연결을 구현했다. 추가 지도자 원화와 세부 수치는 디렉터 임시값이다. [현행 규칙·수치·결정 상태](../../direction/central-enemies.md).

## 실제 화면

![B 일반 친위대와 포격병 · 1008×630](assets/central_live_2026-10-26/ui/artillery_1008.png)

![친위대장 · 1280×900](assets/central_live_2026-10-26/ui/elite_1280.png)

![탑의 지배자 · 최종 편성 · 1008×630](assets/central_live_2026-10-26/ui/boss_1008.png)

![차폐 재지급](assets/central_live_2026-10-26/ui/boss_shield_release.png)

1008×630,1280×900,1440×630에서 일반/정예/보스와 별도 포격 편성, 지휘 전후, 처치 강조, 보상·엔딩을 렌더했다. 최종 {len(ui['captures'])}캡처, {ui['checks']:,}검사 실패0. 대표 화면을 직접 확인해 발 접점·잘림·체력과 몸체 겹침·지휘 문구·작은 화면 실루엣을 검수했다. 보스165→148px 등록으로 HP 겹침을 해소하고, 처치 강조가 나오는 동안 지도자 제목을 숨겨 동일 위치의 문구 충돌을 피했다. 지휘 연출 생략/즉시 모드에서도 최종 표시와 실제 모델이 일치한다.

## 새 게임부터 다섯 구역 연속 검사

기본 난이도0, map3, 편성11, weapon1, 운반 복장으로 시작했다. 정예를 우선하고 연결된 상점/공방을 방문한다. 보상·구매·관문·발사·재장전을 실제 명령으로 실행하고 매 명령 직후 전체 캠페인을 저장/복원했다. 기존 경로를 쓸 때도 새 캠페인에서 현재 모델로 먼저 합법성·승리를 재확인했다. 덱·파츠·코어 레벨을 만들어 넣지 않았다.

기본 획득 정책은 허용된 보상의 첫 항목, 추가 비교는 중복 냉각/지원탄을 제한하는 공개 정보 기반 선택이다. 전투 탐색은 미래 손패와 RNG를 보며 한정된 후보만 탐색하므로 **돌파 가능성 검사이며 사람의 승률이 아니다.**

| 무기 | 시드17 | 시드731042 | 시드931104 |
|---|---|---|---|
{table}

기본 정책은 **{baseline_wins}/15 완주**. 리액터731042의 첫 항목 선택은 소이3·냉각4·대부분 기본탄인 덱으로2구역 관문에서 승리 경로를 찾지 못했다. 이를 숨기지 않고 실패 기록을 보존했다. 같은 시드를 새 게임부터 중복 냉각탄을 피하는 선택으로 재검사한 결과는 **{'완주' if fit['won'] else str(fit['region'])+'구역에서 탐색 실패'}**다. 이 비교는 적 수치나 기존 획득물을 임의로 바꾼 것이 아니다. 약한 덱도 반드시 이기도록 모든 보스를 낮추지는 않았다.

총 {len(battles)}전투 시도 중 {sum(b['solved'] for b in battles)}전투에서 실제 승리 경로를 재생했다. 캠페인 명령·저장 검사는 {checks:,}회이며, 기본 정책 리액터731042의 경로 실패와 완주 실패 두 항목을 별도 실패로 기록한다. 기능 검사 실패0과 이 탐색 실패를 구별한다.

| 무기 | 승리 재생 전투 | 최소 남은 탄 | 최소 생존 거리 | 최종전 적 행동 수 | 최종전 남은 탄 |
|---|---:|---:|---:|---:|---:|
{metric_table}

남은 탄은 전투 사용함에 들어가지 않은 카드 수로, 모두 공격탄이라는 뜻은 아니다. 거리는 각 명령 뒤 살아 있는 적/압력탄 중 최소 거리다. 재장전이 여러 적 행동을 소비하므로 행동 수와 발사 횟수를 혼동하지 않는다. 리액터의 일부 탄약 여유, 래칫의4구역 거리 여유는 작아 사람의 플레이로 이어서 확인한다.

## 비교에서 채택한 조정

- 첫 관문 폐쇄 당직: 편성11에서HP44→32. 장갑5·개방/압력탄 주기·호위를 보존했다. 초기 리액터의 같은 실제 획득 덱에서HP44/36으로 공격탄을 소진하던 사례가HP32에서 통과했다. 낮은 성장의 첫 관문 부담을 줄이는 임시값이다.
- 최종전: 지배자HP80과 지휘3행동은 유지하고 포격병12HP를 중장병18HP로 교체했다. HP만68/72로 낮추거나 거리를4/6m 늘린 비교는 같은 래칫 덱에서 해결하지 못했다. 원거리 요격과 차폐·지휘를 동시에 처리하던 부담을 덜자 원래HP80으로 돌파했다. 최종8기와 유한 호위는 유지한다.
- 2~4구역과 기존 저장1~10은 기존 편성을 유지한다. 새 편성의 수치 원본은 `central_guard.gd`와 `provisional_balance.gd`다.

## 규칙·회귀·저장

| 검사 | 결과 |
|---|---:|
| 중앙 편성·명령·차폐·예측·저장·이전 편성 보존 | {rules['checks']:,} / 실패0 |
| 중앙 실제 UI·입력·연출·엔딩 | {ui['checks']:,} / 실패0 |
| 주조장 규칙 회귀 | 1,408 / 실패0 |
| 정원 규칙 회귀 | 359 / 실패0 |
| 귀족 규칙 회귀 | 893 / 실패0 |
| 리액터 규칙 회귀 | 152 / 실패0 |
| 발열 규칙 회귀 | 917 / 실패0 |
| 소이탄 규칙 회귀 | 1,705 / 실패0 |

중장병의 장갑이 파쇄되어0이 된 뒤 저장 복원이 거부되던 검증기를 수정했다. 중앙 차폐의 주 타격·연쇄·열 파동 판독을 연결하고, 전격의 별도 전이 피해는 기존처럼 HP에 직접 들어가는 규칙을 유지했다. 차단/화상으로 지휘를 늦추거나 취소하는 경우, 명령으로 패배하는 경우, 무작위 사격12시드의 예측 범위와 RNG 불변을 검사했다.

처음 발열 회귀의2실패는 과거 압쇄 화상4를 가정한 fixture가 신규 리액터로 시작하던 테스트 문제였다. 해당 과거 규칙 검사를 weapon0으로 명시한 뒤917검사 통과했다. PowerShell5에서 한글 프로젝트 경로를 잘못 읽던 리액터 검사 실행은 UTF-8을 읽는 `pwsh`로 실행해 통과했다. 최초 스크립트 파싱·UI 실패 로그는 `qa_runtime/central_live/`에 보존했고 최종 규칙/UI/캠페인의 런타임 오류 로그는 별도 보관한다.

Godot4.7 import 완료. 기존 Android build-tools 경로 경고는 남지만 이번 작업은 APK 생성 요청이 아니며 데스크톱 실행·검증을 막지 않았다. 커밋·푸시·APK·외부 게시를 수행하지 않았다.

## 재현과 원본

활성 저장소에서 아래 명령을 사용한다. 저장은 모두 `qa_runtime/central_live/` 아래로 격리된다. `Tag`를 바꾸면 이전 증거를 덮어쓰지 않는다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_central_live_checks.ps1 -Mode rules -Tag verify
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_central_live_checks.ps1 -Mode ui -Tag verify
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_central_live_checks.ps1 -Mode balance -Seeds '17,731042,931104' -Tag verify
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_central_live_checks.ps1 -Mode balance -Seeds 731042 -Guns heavy -Acquisition fit -Tag verify_fit
```

`PLAY.cmd`의 새 등반 또는 개발 메뉴 중앙 일반전/친위대장/탑의 지배자로 확인한다. 개발 미리보기는 실제5구역 진입 덱을 쓰되 후반 방 이동 시 추가 성장을 가정하지 않으며 사용자 저장을 쓰지 않는다.

승인 B PNG4장과 추가 지도자PNG2장 원본 해시를 재확인했다. B의 기존 생성 기록에는 사용자 채택 상태를 별도 추가했으며 A/B 원본과 비교 화면을 보존했다. 추가 원화는 내장 image_gen 제작이고 Python은 알파·발 위치·해시 측정에만 사용했다. [추가 원화 전체 프롬프트·참조·해시](../../../새-게임-프로젝트/assets/art/central_leaders_20261026/provenance.json). 동작은 정지 원화+절차형 이동·피격·사망·지휘 강조이며 신규 키포즈 시트를 만든 것은 아니다.

[기계 판독 요약과 코드 해시](assets/central_live_2026-10-26/summary.json), [기본 정책731042 전체 명령/실패](assets/central_live_2026-10-26/final_731042/balance.json), [리액터 대안 선택 전체 명령](assets/central_live_2026-10-26/fit_heavy_731042/balance.json), [17 전체 명령](assets/central_live_2026-10-26/final_17/balance.json), [931104 전체 명령](assets/central_live_2026-10-26/final_931104/balance.json).

사용자 B 선택은 확정이다. 추가 지도자 외형의 선호, 지휘 예고를 보고 대응하는 이해도, 장기 재미, 실제 Galaxy 터치·성능은 확인 전이다. 모든 빌드·난이도·경로를 검증했다는 의미로 해석하지 않는다.
'''
(ROOT/'docs/qa/reports/central_live_2026-10-26.md').write_text(report, encoding='utf-8')
journal = ROOT/'docs/history/daily/2026-10-26.md'
entry = f'''\n\n## 승인 B 본편 적용과 5구역까지 임시 밸런스

사용자 B 선택·본편 적용·5구역까지 임시 균형 요청을 처리했다. 일반4종 원본을 사용하고 같은 계열의 친위대장·지배자 원화2장을 추가했다. 편성11의 지휘3행동/전진·차폐 교대, 유한 호위, 차폐 판독·개발 진입·엔딩 연결을 구현했다. 첫 관문HP44→32와 최종전 포격 호위→중장병을 비교 후 채택했다. 장갑 파쇄 후 저장 복원 거부를 수정했으며 이전 저장1~10은 보존한다.

최종 규칙 {rules['checks']:,}, 실제 UI {ui['checks']:,}·{len(ui['captures'])}캡처, 관련 회귀5,434검사 실패0. 새 게임5무기×3시드의 기본 획득 정책은 {baseline_wins}/15완주. 리액터731042는2구역 관문 탐색 실패를 보존하고, 중복 냉각탄을 피한 합법 선택으로 새 게임부터 다시 실행해 {'완주했다' if fit['won'] else '추가 탐색 실패를 기록했다'}. 총{len(battles)}전투 시도 중{sum(b['solved'] for b in battles)}승리 재생. 미래 RNG를 보는 탐색이며 사람 승률로 해석하지 않는다.

원화6장 해시 확인, 사용자 저장 격리. 커밋·푸시·APK·외부 게시 없음. 추가 지도자 원화 선호·지휘 이해도·장기 체감·Galaxy 확인은 후속이다. [현행 규칙](../../direction/central-enemies.md) · [실제 화면·전체 결과·실패와 한계](../../qa/reports/central_live_2026-10-26.md).
'''
previous = journal.read_text(encoding='utf-8') if journal.exists() else '# 2026-10-26\n'
if '## 승인 B 본편 적용과 5구역까지 임시 밸런스' not in previous:
    journal.write_text(previous.rstrip()+entry, encoding='utf-8')
print(json.dumps({key: summary[key] for key in ['baseline_wins','baseline_cases','alternative_heavy_won','campaign_checks','attempted_battles','solved_battles']}, ensure_ascii=False))
