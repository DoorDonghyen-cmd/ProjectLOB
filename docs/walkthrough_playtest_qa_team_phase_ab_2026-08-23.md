# 전용 플레이 QA 팀 Phase A~B 워크스루

> 완료일: 2026-08-23
> 세션 ID: `codex0823-qa-team`
> 범위: 직원 역할 계약 + 고정 전투 상태/행동 브리지 MVP

## 1. 구현 결과

### 프로젝트 전용 직원 2명

- `15-gameplay-qa-lead`
  - 기능 플레이 QA, 재현, 심각도 판정, 독립 결과 통합을 담당한다.
  - 테스트 중 코드 수정 금지, QA 전용 사용자 데이터, 기능/재미/인프라 결과 분리를 고정했다.
  - QA 차터, 통합 리포트, 중요도·통합 계약을 재사용 리소스로 제공한다.
- `16-gameplay-experience-tester`
  - 플레이어 공개 정보만 사용하는 블랙박스 재미·UX 검증을 담당한다.
  - 초심자·공격형·보수형·실험형 프로필과 행동 증거 기반 재미 루브릭을 제공한다.
  - 소스·오라클·기존 결론을 보지 않고 예상 → 선택 → 실제 결과를 기록한다.

두 스킬은 `SKILL.md`, `agents/openai.yaml`, 필요한 `references/`와 `assets/`만 갖는
점진적 공개 구조로 작성했다. 공식 `skill-creator` Python 초기화기는 현재 환경에 실행 가능한
Python이 없어 사용할 수 없었고, 동일 스캐폴드를 직접 생성한 뒤 명명·frontmatter·metadata·
default prompt·TODO 부재를 정적 검사했다.

## 2. QA 브리지 MVP

새 `scripts/qa/` 모듈은 기존 전투를 복제하지 않고 실제 `CombatManager`를 호출한다.

- `qa_session_manifest.gd`: session, commit, dirty 여부, mode, scenario 계약
- `qa_state_serializer.gd`: 플레이어 공개 상태와 내부 오라클 상태 분리
- `qa_action_executor.gd`: 합법 행동 산출과 장전·확정·격발·리로드·빼내기·이젝트 실행
- `qa_bridge.gd`: 단계 번호 검증, JSON 입출력, 상태/행동/result 이력 저장
- `qa_session_runner.gd`: `state_NNNN.json`을 내보내고 `command_NNNN.json`을 기다리는 실제 폴링 실행기

지원하는 고정 전투 흐름은 다음과 같다.

```text
manifest → state_0000
  → action_0000(load) → result_0000 → state_0001
  → action_0001(load) → result_0001 → state_0002
  → action_0002(confirm_load) → state_0003
  → action_0003(fire) → state_0004
  → action_0004(fire) → state_0005(won)
```

단계 번호가 다르거나 보유하지 않은 탄환을 요청하면 행동을 거절하고 단계와 전투 상태를
변경하지 않는다. 플레이어 상태는 총기의 예고 슬롯 수만큼만 탄창을 공개하며,
오라클 상태는 전체 장전 순서와 역순 격발 순서를 별도로 기록한다.

## 3. 검증

`suite_qa_bridge.gd`가 다음 계약을 실제 전투로 검증한다.

- 필수 manifest 검증과 JSON 생성
- 잘못된 미래/과거 단계 행동 거절
- 미보유 탄환 장전 거절
- 장전 대기 순서와 LIFO 격발 순서
- 공개 상태 1발/은폐 1발과 오라클 전체 2발 분리
- 고화력탄 6 피해 → 표준탄 3 피해로 HP 9 적 처치
- 종료 상태의 합법 행동 없음
- 저장된 최종 JSON 재파싱
- 합법 장전/장전 취소를 반복하는 20단계 상태·행동 왕복

전체 Godot 회귀 결과:

- 통과: **3,471**
- 실패: **0**
- 기존 경보: **3**
- 전 스크립트 컴파일 및 전 씬 로드 성공

## 4. 남은 범위

이번 단계는 고정 전투의 의미 단위 행동까지다. 아직 다음 기능은 구현하지 않았다.

- 실제 메인 → 구역 선택 → 준비실 → 맵 → 전투 → 보상 → 상점 UI 흐름
- Viewport 체크포인트 이미지 캡처
- 게임플레이 RNG와 FX RNG 분리
- 1~2구역 및 35층 전체 런
- 여러 독립 테스터의 실제 전방 검증과 통합 리포트 생성

다음 단계는 Phase C의 실제 씬/UI 체크포인트 연결이다.
