# 경험 리포트 JSON 계약

## 원칙

- `player_view`와 합법 행동만 기록한다. `oracle_state`가 섞이면 리포트를 폐기한다.
- 주요 선택 전에 `expected`, `reason`, `alternatives`를 작성한다.
- 결론보다 `step`, 화면, 선택 ID, 실제 결과를 우선한다.
- 촉감·속도감·피로도는 `human_confirmation`으로 남긴다.

## 최소 예시

```json
{
  "schema_version": 1,
  "session_id": "qa-profile-beginner",
  "commit": "abc1234",
  "scenario_id": "campaign_two_sections",
  "gameplay_seed": 424242,
  "profile": "beginner",
  "start_condition": {"save_fixture": "clean", "gun_id": "revolver"},
  "actions": [
    {
      "step": 3,
      "screen": "reward",
      "action": "choose_reward",
      "choice_id": "credits",
      "category": "reward",
      "expected": "다음 상점에서 선택지가 늘어난다",
      "reason": "보상 카드의 추천 문구를 따랐다",
      "alternatives": [{"choice_id": "bullet", "reason_not_chosen": "효과가 바로 읽히지 않았다"}],
      "accepted": true,
      "player_view": {"screen": "reward"},
      "result": {"accepted": true},
      "tags": [],
      "outcome": {}
    }
  ],
  "observations": []
}
```

## 집계 결과

`QAExperienceMetrics`는 선택 집중도, 리로드·무효 행동 비중, 최소 거리,
과잉 피해, 미사용 전술탄, 파츠·경로 중복률을 따로 내다. 종합 점수는 만들지 않는다.
`QAProfileComparator`는 같은 시작 조건의 네 보고서만 비교하며 동일 행동열은 성공으로
인정하지 않는다. 통합 결론은 `strong_signal`, `hypothesis`, `human_confirmation`만 사용한다.
