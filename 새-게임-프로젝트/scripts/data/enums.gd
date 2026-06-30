class_name Enums

## 게임 전체에서 공유되는 열거형 정의.
## 사용법: Enums.BulletEffect.ARMOR_SHRED

## ── 총알 구경 규격 ──
enum Caliber {
	CAL_9MM,       ## 9mm 기본형
	CAL_556,       ## 5.56mm 전술형
	CAL_762,       ## 7.62mm 중화력형
}

## ── 총알 순서 의존 효과 ──
enum BulletEffect {
	NONE,          ## 효과 없음
	ARMOR_SHRED,   ## 피격 후 적 방어 감소
	COMBO,         ## 직전 탄 명중 시 대미지 보너스
	LAST_SHOT,     ## 탄창 마지막 탄일 때 대미지 배율
	OPENING_SHOT,  ## 탄창 첫 탄일 때 넉백 보너스
	CALIBER_DIFF,  ## 직전 탄과 구경이 다를 때 대미지 추가 보너스
	PIERCE,        ## 공유 트랙 일렬 다수 적 관통 다중타
}

## ── 적 아키타입 ──
enum EnemyArchetype {
	RUSHER,  ## 돌격병 — 빠르고 방어 낮음
	TANK,    ## 중장갑 — 느리고 방어 높음
	DODGER,  ## 회피형 — 중간 속도, 높은 회피
	CASTER,  ## 술사형 — 전진하지 않고 원거리 차징 공격
}

## ── 적 전투 중 태세 (Stance) ──
enum EnemyStance {
	NONE,            ## 기본 태세 (상태 변화 없음)
	IRON_SHIELD,     ## 물리 장갑 태세 — 방어 높음, 속도 느림
	ACTIVE_DODGER,   ## 회피 돌격 태세 — 회피 높음, 속도 빠름
}

## ── 총기 파츠 고유 ID ──
enum PartID {
	NONE,
	DEEP_LOADER,       ## 딥로더
	RHYTHM_CHAMBER,    ## 리듬 챔버
	INTERRUPTER,       ## 인터럽터
	UNDERFLOW,         ## 언더플로우
	CHASER,            ## 체이서
	POINT_BLANK,       ## 포인트블랭크
	LONG_SHOT,         ## 롱샷
	EXECUTIONER,       ## 처형자
	RECOIL_PUSH,       ## 리코일 푸시
	HIGH_PRECISION,    ## 고정밀 총열
	ARMOR_PIERCING,    ## 철갑 총열
	SHRED_MUZZLE,      ## 파쇄 총구
	VERSATILE_CHAMBER, ## 만능 약실
	TARGET_INDICATOR,  ## 표적 지시기
	CHAIN_ACC,         ## 연동 조준
	STANCE_FORESIGHT,  ## 태세 예지
	STANCE_LOCK,       ## 태세 고정
	INERTIA_FIRE,      ## 관성 격발
	SCOPE,             ## 스코프
	BLIND_FIRE,        ## 블라인드파이어
	QUICK_LOAD,        ## 퀵로드
	SPREAD_SHOT,       ## 확산 격발 장치 (샷건 고유)
	MARKSMAN_SCOPE,    ## 저격경 (Marksman 고유)
}

