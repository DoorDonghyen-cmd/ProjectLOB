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

