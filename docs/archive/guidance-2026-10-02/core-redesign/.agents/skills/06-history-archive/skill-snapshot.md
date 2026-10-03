---
name: 06-history-archive
description: 과거 세션에서 생성된 walkthrough.md 및 implementation_plan.md 파일들을 중앙 마스터 인덱스(walkthrough_master.md / implementation_plan_master.md)에 기록하고 관리하는 스킬. 사용자 세션 종료 시나 작업 정리 시 활용한다.
---

# 📚 History Archive (문서 아카이빙 및 히스토리 관리) 스킬

## 1. 목적 (Purpose)
단기 세션(Conversation)이 반복되면서 생성되는 수많은 `walkthrough.md` 및 `implementation_plan.md` 문서들이 흩어지는 것을 방지하고, 에이전트와 유저가 과거 작업 내역을 한눈에 파악할 수 있도록 중앙 인덱스를 통해 관리합니다.

## 2. 관리 대상 마스터 문서
본 스킬 폴더 내에는 다음 두 가지 마스터 인덱스 문서가 존재합니다:
- **[Walkthrough Master (검증 아카이브)](file:///D:/ProjectLoB/.agents/skills/06-history-archive/walkthrough_master.md)**: 모든 완성된 기능/검증 요약본(`walkthrough.md`)을 로깅합니다.
- **[Implementation Plan Master (설계 아카이브)](file:///D:/ProjectLoB/.agents/skills/06-history-archive/implementation_plan_master.md)**: 모든 기술 구현 계획서(`implementation_plan.md`)를 로깅합니다.

## 3. 핵심 규칙 (Agent Instructions)
기능 개발이나 세션을 마무리하고 유저가 **"정리해 줘"** 또는 **"히스토리 업데이트해 줘"**와 같이 이야기할 때 반드시 다음 스텝을 따릅니다:

1. **아티팩트 획득**: 현재 세션(`brain/UUID/`)에서 생성된 최종 `walkthrough.md`나 `implementation_plan.md`의 **절대 경로**를 획득합니다.
2. **마스터 인덱스 수정**: `06-history-archive` 폴더에 있는 해당 마스터 문서(`walkthrough_master.md` 또는 `implementation_plan_master.md`)에 마크다운 파일 내용 검색/편집 툴(`view_file`, `multi_replace_file_content`)을 활용해 접근합니다.
3. **새로운 내역 추가**: 표의 최하단에 새로운 행(Row)을 포맷에 맞추어 기입하고, 맨 하단 `참조 링크` 영역에 절대 경로를 추가합니다.

### 📝 표 기입 포맷 예시
| 주제 | 관련 세션 | 주요 내용 | 원본 링크 |
| :--- | :--- | :--- | :--- |
| **[주제 명]** | `[현재 세션 UUID 앞 8자리]` | 방금 달성한 가장 핵심적인 기능 1~2줄 요약 | `[walkthrough][N]` |

## 4. 유의 사항
- 히스토리가 누락되지 않도록 매 작업의 큰 단위(`Phase`나 `Option` 종료 단위)마다 스스로 갱신을 제안하거나 자동 갱신해야 합니다.
- 스킬 추가 및 버그 수정 등 코어한 설계/기획 문서도 전부 이 아카이브 체계에 통일시킵니다.
