---
name: 14-localization-text-manager
description: 게임 'Last on Board'의 다국어 번역 리소스 정합성 및 CSV 데이터 검증을 수행하며, 번역 키 누락 방지와 CSV 포맷 에러 감지를 담당합니다.
---

# 📝 Localization & Text Manager (LM) - 다국어 번역 및 데이터 검증 매니저

이 스킬은 게임 **Last on Board**에서 확장되는 다양한 스탯 테이블(CSV)과 다국어 번역 파일(`.translation`) 간의 연결 구조를 감수하고, 인게임 텍스트 누락 및 파싱 오류를 미연에 방지하기 위한 규칙 가이드라인입니다.

---

## 📊 1. CSV 데이터 테이블 검증 규격

몬스터, 탄환, 총기 등의 데이터는 모두 `data/` 폴더 내의 CSV 파일로 통합 관리됩니다.

*   **기본 구조 검증**:
    *   `id` 필드가 고유값(Unique Key)인지, 리소스 파일(`.tres`)의 베이스이름(Basename)과 일치하는지 확인합니다.
    *   컬럼 데이터 타입 검증 (예: `max_hp`는 양의 정수, `archetype`은 enums.gd에 정의된 유효 인덱스 범위 내에 있는지).
*   **보스 스탯 규격**:
    *   새 보스 추가 시, `enemy_stats.csv`에 해당 보스의 행이 등록되었는지 확인하고, archetype 컬럼 값이 enums.gd의 보스 인덱스(`6`~`9` 등)와 정확히 일치하는지 대조합니다.

---

## 🔠 2. 다국어 번역 키 정합성 검수

이 게임은 Godot 내장 번역 기능을 활용하기 위해 CSV 데이터의 각 필드와 대응되는 번역 파일(`.translation`)을 구성합니다.

*   **필수 번역 파일**:
    *   `enemy_stats.display.translation` (몬스터 표기명)
    *   `enemy_stats.archetype.translation` (아키타입 설명)
    *   `bullet_stats.display.translation` (탄종 표기명)
    *   `bullet_stats.description.translation` (탄종 상세 효과 설명)
*   **번역 누락 검수 룰**:
    *   데이터 파일(CSV)에 새로운 `id` (예: `boss_director`)가 추가된 경우, 반드시 해당 번역 키들이 관련 `.translation` 번역 리소스에 새 행으로 등록되어 있는지 검증합니다.
    *   번역 키가 누락되었을 때 Godot UI 상에 `ID_KEY` 등의 기괴한 시스템 코드가 그대로 노출되는 현상을 사전에 방지합니다.

---

## 🛠️ 3. 데이터 파싱 오류 예방

*   **텍스트 인코딩**: 모든 CSV 파일은 반드시 **UTF-8 (BOM 없음)** 인코딩으로 저장해야 한글 및 특수기호가 정상 파싱됩니다.
*   **구분자(Comma) 관리**: 표시명이나 설명글 내에 쉼표(`,`)가 들어가는 경우, 파서가 열을 잘못 분리하지 않도록 반드시 해당 텍스트 필드를 큰따옴표(`"..."`)로 감싸주어야 합니다.
    *   *예시*: `boss_omega,실험체 Ω 프로젝트 오메가,...` ➡️ `boss_omega,"실험체 Ω ""프로젝트 오메가""",...` (CSV 이스케이프 룰 준수)
