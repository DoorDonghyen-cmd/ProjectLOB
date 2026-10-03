"""Reconcile the active LoB guidance; preserve pre-migration bytes in an archive."""
from pathlib import Path
import argparse
import hashlib
import json

ACTIVE = Path(__file__).resolve().parents[1]
WORKSPACE = ACTIVE.parents[1]
ARCHIVE = ACTIVE / 'docs/archive/guidance-2026-10-02'
CONTEXT = '''# 현재 ProjectLoB 작업 기준

검토일: 2026-10-02. 이 파일은 경로 안내이며 게임 규칙을 복제하지 않는다.

- 활성 저장소: `D:/ProjectLoB/worktrees/core-redesign`
- Godot 프로젝트: `D:/ProjectLoB/worktrees/core-redesign/새-게임-프로젝트/project.godot`
- [현재 방향과 결정 상태](D:/ProjectLoB/worktrees/core-redesign/docs/direction/current.md)
- [게임 설계](D:/ProjectLoB/worktrees/core-redesign/docs/direction/game-design.md)
- [아트·UX 제작 기준](D:/ProjectLoB/worktrees/core-redesign/docs/direction/art-and-ux.md)
- [진행 현황](D:/ProjectLoB/worktrees/core-redesign/.agents/skills/00-project-manager/task_tracker.md)

현재 사용자 지시와 최근 확정한 결정이 이전 문서보다 우선한다. 코드는 현재 동작의 증거이며 바꿀 수 없는 기획이 아니다. 아카이브, 이전 GDD, 과거 테스트 성공 기록은 필요할 때만 읽는다. 다른 프로젝트 작업에는 이 안내를 적용하지 않는다.
'''
RULES = '''# ProjectLoB 작업 기준

LoB 작업은 [.agents/CURRENT_PROJECT.md](.agents/CURRENT_PROJECT.md)에서 활성 프로젝트를 확인한다. `.agents/AGENTS.md`에서 읽은 경우 같은 폴더의 `CURRENT_PROJECT.md`를 사용한다.

- 사용자 최신 지시 → 현행 방향 문서의 결정 상태 → 해당 기능의 설계 순으로 확인한다. 과거 규칙이 현재 목표와 충돌하면 되살리지 않는다.
- 기획의 사용자 확정 사항, 디렉터 결정, 구현 상태, 검증되지 않은 가설을 구분한다.
- UI·아트·규칙 개편을 이미 허용받은 범위는 기획과 검증을 이어서 수행한다. 문서 작성이나 수정 파일 수 때문에 반복 승인을 만들지 않는다.
- 재현 가능한 기존 저장·전투 계산을 활용한다. 변경 전 작업 트리를 확인하고 사용자 변경을 보존한다.
- QA는 격리 저장에서 진행한다. 기능 통과, 시각 확인, 사람의 이해도 검증을 별도로 기록한다.
- APK 생성은 요청받았을 때 수행한다. 커밋·푸시·외부 게시도 세션의 실제 요청 범위를 따른다. 브랜치를 `main`으로 고정하지 않는다.
- 작업 기록은 `docs/history/`에, 현재 결정은 `docs/direction/`에 둔다. 역할 스킬에 날짜별 기록·수치표·세계관 전체를 복제하지 않는다.
- 특정 에셋 제작 도구, 픽셀 해상도, 탄환 각도, 전투 패널 위치를 영구 규칙으로 만들지 않는다. 현재 아트 기준과 실제 판독성으로 결정한다.
'''
SKILLS = {
'00-project-manager': ('LoB 작업 위치와 현재 우선순위를 확인하고 구현·검증 상태를 추적한다. 진행 상황 확인과 다음 작업 선택에 사용한다.', '''현재 작업 위치와 문서는 [현재 프로젝트](../../CURRENT_PROJECT.md)에서 확인한다.

- 활성 작업 폴더의 `task_tracker.md`와 `docs/direction/current.md`를 먼저 확인한다. 다른 체크아웃의 완료 기록을 현재 상태로 간주하지 않는다.
- 사용자 요청을 현재 목표로 삼고, 필요한 작업을 진행 중/검증 완료/사람 확인 필요로 구분한다.
- 구현 완료를 제품 완성이나 재미 검증 완료로 표현하지 않는다.
- 목표가 명확하면 추가 승인 단계 없이 진행한다. 다음 작업은 검증에서 드러난 문제와 사용자 우선순위로 정한다.
- 짧은 최신 현황만 tracker에 유지하고 상세 이력은 `docs/history/`로 연결한다.'''),
'09-creative-director': ('LoB의 현재 핵심 재미, 무기·탄환·파츠 선택과 전체 플레이 흐름을 설계하고 검토한다. 과거 세계관이나 전투 규칙을 고정하지 않는다.', '''[현재 프로젝트](../../CURRENT_PROJECT.md)의 `docs/direction/current.md`와 `game-design.md`를 읽고 사용자 확정 사항과 디렉터 결정을 구분한다.

- 탄환 조합·발사 순서가 결과를 바꾸는가, 파츠가 서로 다른 빌드를 만드는가, 선택의 이득과 대가가 읽히는가를 판단한다.
- 현재 규칙을 유지할 이유와 바꿀 이유를 플레이 사례로 설명한다. 과거 문서에 적혀 있다는 이유만으로 제안을 거부하지 않는다.
- 무작위성은 가능한 결과와 확률을 정직하게 표시하는지 검토한다. 내부 시드로 재현된다는 이유로 플레이어에게 결과가 확정되어 있다고 하지 않는다.
- 확정 전 편집과 확정 후 비용을 구별한다. 특정 장전 자료구조나 서사 결말을 핵심 재미와 동일시하지 않는다.
- 새 세계관·화풍·적 역할은 현행 문서에 디렉터 결정으로 기록한다. 사용자가 직접 확정하지 않은 내용을 사용자 요구로 포장하지 않는다.
- 선택 편향과 반복 전략은 전투·보상·상점 전체에서 살핀다. 자동 승률만으로 재미를 확정하지 않는다.'''),
'08-art-resource-manager': ('LoB의 현행 아트 방향에 맞춰 배경·캐릭터·탄환·파츠·UI를 제작하고 게임 내 판독성과 자산 품질을 검수한다.', '''[현재 프로젝트](../../CURRENT_PROJECT.md)의 `docs/direction/art-and-ux.md`가 현행 기준이다.

- 전술적 역할과 상태가 실제 게임 크기에서 읽히도록 형태·명암·색을 설계한다. 색만으로 역할을 구분하지 않는다.
- 배경은 세계와 분위기를, 적과 물건은 역할을, UI는 결정과 결과를 담당한다. 셋이 동시에 가장 강하게 강조되지 않게 한다.
- 글자·숫자·클릭 영역은 Godot에서 그린다. 생성 이미지에 기능 UI나 수치를 구워 넣지 않는다.
- 비트맵 제작은 사용 가능한 이미지 도구로 진행하고, 공통 아이콘·프레임은 코드나 벡터로 유지할 수 있다. 특정 서비스나 후처리 순서를 강제하지 않는다.
- 결과를 프로젝트 안에 저장하고 용도·생성 프롬프트·도구·파일·검수 상태를 자산 목록에 기록한다. 컨셉 그림과 실제 적용 자산을 구별한다.
- 투명 가장자리, 시각 크기, 폰트 대체, 모바일 비율, 상태 변화와 애니메이션 종료 위치를 실제 렌더로 확인한다.
- 과거 픽셀 화풍·5등신·특정 방향·아웃라인 지시는 현재 기준이 채택한 경우에만 적용한다.'''),
'10-balance-designer': ('LoB 현행 탄환·무기·파츠·압축·적·경제의 선택 가치를 비교하고 수치 변경의 근거와 영향을 검증한다.', '''[현재 프로젝트](../../CURRENT_PROJECT.md)를 확인한 뒤 활성 프로젝트의 `redesign/content.gd`, `model.gd`, `campaign_content.gd`, `campaign.gd`에서 실제 규칙을 읽는다.

- 현재 피해 계산과 턴 단위를 확인한 후 비교한다. 이전 CSV·구경·명중/회피 공식을 가져오지 않는다.
- 무기별 발사/재장전 주기, 파츠 상호작용, 다수 적과 증원, 압축의 공간·자원·위치 비용을 포함한다.
- 평균 피해뿐 아니라 처치선, 선택 가능한 대안, 생존 마진, 장기 자원 소모를 비교한다.
- 강한 효과의 대가는 실제 선택을 바꾸는지 검증한다. 모든 파츠에 일률적으로 패널티를 추가하지 않는다.
- 무작위 표적은 분포와 범위를 사용하고 시드를 바꿔 비교한다. 특정 시드 완주를 일반 균형의 증거로 삼지 않는다.
- 수치의 단일 원본은 현재 콘텐츠 데이터다. 스킬에 특정 숫자나 무기 목록을 복제하지 않는다.'''),
'12-combat-simulator': ('LoB 실제 전투 모델을 사용해 순서·연계·무작위 표적·파츠·증원·예측 정합성과 재현성을 검증한다.', '''[현재 프로젝트](../../CURRENT_PROJECT.md)의 실행 모델과 예측 코드를 사용한다.

- 현재 전투/캠페인 상태와 합법 행동으로 시나리오를 만든다. 옛 피해 공식이나 존재하지 않는 탄환으로 대체 시뮬레이터를 만들지 않는다.
- `model.gd`의 실제 명령과 `forecast.gd`의 예측을 대조한다. 미리보기는 실전 상태와 RNG를 소비하지 않아야 한다.
- 확정 피해와 무작위 표적을 구별한다. 무작위 결과를 하나의 확정 경로처럼 공개하지 않는다.
- 장전 편집·확정, 발사, 재장전, 압축, 처치 연쇄, 증원 투입, 저장 복원을 확인한다.
- 넉백 무한 반복과 지배 전략은 턴 비용·공급·내성·적 구성까지 포함해 판단한다.
- 고정 시드는 회귀 재현에, 여러 시드는 선택 다양성 검증에 사용한다. 기능 결과와 재미 가설을 분리해 보고한다.'''),
'14-localization-text-manager': ('LoB 플레이어 문구·용어·번역과 실제 데이터 구조의 정합성, 한글 글꼴과 작은 화면의 읽기 품질을 확인한다.', '''[현재 프로젝트](../../CURRENT_PROJECT.md)의 현재 콘텐츠와 UI를 확인한다.

- 먼저 텍스트가 실제로 어디에서 오는지 조사한다. 모든 데이터가 CSV이거나 번역 리소스가 이미 완비됐다고 가정하지 않는다.
- 탄환·무기·파츠·상태의 명칭을 전투/상점/보상/상세에서 통일한다. 내부 ID를 플레이어 이름으로 노출하지 않는다.
- 짧은 설명은 효과와 조건을 보존한다. 작은 글씨나 낯선 한 글자 약어로 공간 문제를 해결하지 않는다.
- 기존 CSV나 번역 파일을 변경할 때는 인코딩·이스케이프·키 대응을 검증한다. 쓰지 않는 옛 데이터까지 자동 확장하지 않는다.
- 한글, 숫자, 기호, 여러 줄, 긴 명칭과 폰트 대체를 실제 렌더로 확인한다.'''),
'15-gameplay-qa-lead': ('LoB 현재 빌드의 기능 회귀·버그 재현·저장 안전성·실제 화면 검증을 설계하고 증거를 정리한다.', '''[현재 프로젝트](../../CURRENT_PROJECT.md)에서 빌드와 실행 경로를 확정한다.

- 사용자 저장과 분리된 QA 경로를 사용하고 코드 상태·시드·화면 크기를 기록한다.
- 변경 범위에 맞는 기존 검사를 선택한다. 현재 규칙에서 만든 재생 기록을 사용하며 오래된 입력 경로의 실패는 먼저 기준 차이를 조사한다.
- 기능 결함, 테스트 인프라 실패, 시각 결함, 이해도 가설을 구별한다.
- UI 검사는 장면 존재·버튼 클릭·화면 안 배치에 더해 실제 캡처의 정보 위계·글자 크기·겹침·입력 영역을 확인한다.
- 리뷰 전용 요청에서는 수정하지 않는다. 개발과 검증을 함께 요청받으면 재현·수정·재검증까지 진행할 수 있다.
- 기존 QA 브리지는 실제로 현재 빌드를 지원할 때 사용한다. 자동 에이전트나 팀 구성을 매번 요구하지 않는다.
- 결과에 근거·실패·미검증 범위를 함께 기록한다. 자동 성공 횟수를 UX 완성 점수로 바꾸지 않는다.'''),
'16-gameplay-experience-tester': ('LoB의 공개 화면과 합법 입력으로 선택 이해도·전투 호흡·빌드 다양성을 관찰한다. 기능 검증과 사람의 체감을 구별한다.', '''[현재 프로젝트](../../CURRENT_PROJECT.md)로 빌드 위치만 확인하고 플레이 검토는 공개 화면·공개 규칙으로 진행한다.

- 각 주요 선택에서 보이는 근거, 예상 결과, 실제 결과를 기록한다. 숨은 정보로 플레이어의 이해를 대신하지 않는다.
- 탄환을 고른 이유, 발사 순서의 차이, 파츠의 이득과 대가, 압축을 아낄 이유가 화면에서 드러나는지 본다.
- 전투·맵·보상·상점·장비의 동선을 함께 검토한다. 현재 룰을 옛 순서 방식에 맞춰 평가하지 않는다.
- 코드까지 읽은 리뷰는 블랙박스 또는 독립 테스트라고 부르지 않는다.
- 직접 관찰과 추론, 반복 신호를 구별한다. 자동 플레이는 사람의 피로·재미·첫인상을 확정하지 못한다.
- 고정된 프로필 수를 통과 조건으로 삼지 않는다. 사용 가능한 증거에 맞춰 결론의 범위를 제한한다.'''),
'04-daily-logs': ('LoB 작업의 변경·검증·남은 일을 날짜별 기록으로 남긴다. 지침 파일에 작업 이력을 누적하지 않는다.', '''[현재 프로젝트](../../CURRENT_PROJECT.md)의 `docs/history/daily/YYYY-MM-DD.md`에 기록한다.

- 완료된 변경, 검증 방법과 결과, 아직 확인하지 않은 사항을 짧게 남긴다.
- 같은 날짜에는 기존 기록을 보존하며 추가한다. 게임 수치와 확정 방향은 해당 정본을 링크한다.
- 이 `SKILL.md`에는 일지를 추가하지 않는다. 이전 일지 원문은 `docs/archive/guidance-2026-10-02/`에 보존되어 있다.
- 단순 상담은 필요할 때 결정만 기록한다. 문서 개수를 늘리는 것을 완료 조건으로 삼지 않는다.'''),
'06-history-archive': ('LoB의 이전 설계와 작업 기록을 보존하고 현행 기준과 구분해 찾을 수 있게 정리한다.', '''[현재 프로젝트](../../CURRENT_PROJECT.md)의 `docs/history/`와 `docs/archive/`를 사용한다.

- 현행 방향은 `docs/direction/current.md`, 당시 결과는 날짜별 기록으로 구분한다.
- 폐기·대체된 문서는 적용 버전과 대체 문서를 표시하고 원본을 보존한다. 과거 지침을 현재 요구로 재적용하지 않는다.
- 현재 체크아웃 기준 상대 링크를 우선한다. 다른 컴퓨터의 임시 세션 경로를 새 정본으로 등록하지 않는다.
- 기존 마스터 인덱스는 역사 자료로 유지할 수 있다. 새 작업은 `docs/history/index.md`에서 찾게 한다.'''),
'05-bug-report': ('LoB의 재현 가능한 결함을 현재 빌드와 연결해 기록하고 수정·검증 상태를 추적한다.', '''[현재 프로젝트](../../CURRENT_PROJECT.md)의 QA 보고서와 버그 기록을 확인한다.

- 현상, 재현 경로, 기대/실제 결과, 빌드·시드·화면 크기, 증거를 기록한다.
- 기존 이슈가 있으면 갱신한다. 테스트 도구 문제와 기능 결함, 디자인 가설을 구별한다.
- 상태는 발견 → 수정 중 → 수정됨 → 검증됨으로 구분한다. 코드를 바꿨다고 검증 완료로 표시하지 않는다.
- 수정이 허용된 작업이면 재현 후 수정과 필요한 재검증을 진행한다. 매 결함마다 새로운 승인 절차를 만들지 않는다.'''),
'07-notion-sync': ('사용자가 요청한 LoB 문서를 지정된 Notion 위치에 동기화한다. 로컬 개발만으로 외부 게시를 시작하지 않는다.', '''[현재 프로젝트](../../CURRENT_PROJECT.md)에서 사용자가 요청한 문서를 식별한다.

- 외부 동기화 요청과 대상 페이지가 확인된 범위에서만 작업한다.
- 사용 가능한 Notion 도구의 실제 입력 규격을 확인하고 기존 페이지·서식을 보존하는 갱신을 우선한다.
- 표·목록·체크박스는 가능하면 해당 블록으로 유지한다. 모든 내용을 코드 블록으로 감싸거나 기존 페이지를 일괄 보관하지 않는다.
- 모호한 목적지는 확인하고, 실패하면 로컬 문서를 보존한 채 실제 상태를 보고한다. 페이지 ID나 비밀값을 스킬에 하드코딩하지 않는다.'''),
}

def replace(path, body, label, records):
    if path.exists():
        original = path.read_bytes()
        destination = ARCHIVE / label / path.relative_to(ACTIVE if label == 'core-redesign' else WORKSPACE)
        # Snapshots are references, not discoverable skill entrypoints.
        if destination.name == 'SKILL.md': destination = destination.with_name('skill-snapshot.md')
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.exists(): destination.write_bytes(original)
        records.append({'source': str(path), 'snapshot': str(destination.relative_to(ACTIVE)), 'sha256': hashlib.sha256(original).hexdigest()})
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body.rstrip() + '\n', encoding='utf-8', newline='\n')

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--target', choices=['active','workspace'], required=True)
    args=parser.parse_args()
    base,label=(ACTIVE,'core-redesign') if args.target=='active' else (WORKSPACE,'workspace')
    records=[]
    replace(base/'.agents/CURRENT_PROJECT.md', CONTEXT,label,records)
    replace(base/'AGENTS.md',RULES,label,records)
    replace(base/'.agents/AGENTS.md',RULES,label,records)
    replace(base/'.agents/workflows/work.md', '''---
description: LoB 현행 방향을 확인하고 허용된 범위의 구현·검증·기록을 이어서 수행한다.
---
# 작업 흐름

[현재 프로젝트](../CURRENT_PROJECT.md)를 확인한다. 사용자 요청과 현재 상태를 대조하고, 큰 변경은 간결한 계획을 남긴 뒤 구현한다. 이미 허용된 작업의 계획·코드·검증을 반복 승인 단계로 나누지 않는다.

변경에 맞는 검증을 수행하고 `docs/history/`에 결과와 미검증 항목을 기록한다. APK·외부 게시·커밋·푸시는 실제 요청 범위에 따른다. 작업 종료 자체를 main 푸시 허가로 해석하지 않는다.
''',label,records)
    for name,(description,body) in SKILLS.items():
        replace(base/f'.agents/skills/{name}/SKILL.md',f'---\nname: {name}\ndescription: {description}\n---\n\n# {name}\n\n{body}\n',label,records)
    if args.target=='workspace':
        replace(base/'.agents/skills/00-project-manager/task_tracker.md', '# ProjectLoB 진행 현황 안내\n\n현재 진행 현황은 [활성 개편판 tracker](D:/ProjectLoB/worktrees/core-redesign/.agents/skills/00-project-manager/task_tracker.md)를 읽는다.\n\n이 위치의 이전 내역은 활성 개편판 `docs/archive/guidance-2026-10-02/workspace/`에 원문으로 보존했다.\n',label,records)
        replace(base/'docs/ACTIVE_PROJECT.md',CONTEXT,label,records)
    else:
        replace(base/'.agents/skills/00-project-manager/task_tracker.md', '''# ProjectLoB 현재 작업

기준: 2026-10-02 · `prototype/core-redesign`

## 진행 중

- 사용자 위임에 따른 기획·아트·UX 전면 재검토와 현행 기준 통합.
- 과거 역할 지침을 보관하고 활성 스킬·문서 경로를 통일.
- 산업 그래픽 아트와 읽기 중심 전투 구도를 실제 Godot에 적용하고 검증.

## 유지할 기반

탄환 조합·발사 순서, 무기별 플레이 차이, 파츠 빌드, 압축 자원, 맵·상점·보상·저장. 현재 구현과 새 디렉터 결정은 [방향 문서](../../../docs/direction/current.md)에서 구분한다.

## 확인 필요

- 실제 갤럭시에서 첫 선택 이해도, 터치 크기, 긴 플레이 피로도.
- 새로운 아트 기준의 전체 적 애니메이션·지역별 자산 확장.

## 직전 검증 기록

2026-09-26 전투 UI 전체3730/0·무기390/0·6칸495/0. 이는 당시 기능/화면 검증이며 새 빌드나 사람의 이해도를 보증하지 않는다.

APK는 요청 시 생성한다. 과거 tracker 원문은 `docs/archive/guidance-2026-10-02/core-redesign/`에 보관했다.
''',label,records)
    ARCHIVE.mkdir(parents=True,exist_ok=True)
    manifest=ARCHIVE/f'{label}-manifest.json'
    if not manifest.exists(): manifest.write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'{args.target}: updated {len(SKILLS)} skills; archived {len(records)} existing documents')

if __name__=='__main__': main()
