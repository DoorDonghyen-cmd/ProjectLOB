class_name Enums

## 게임 전체에서 공유되는 열거형 정의.
## 사용법: Enums.BulletEffect.ARMOR_SHRED

## ── 총기 및 탄환 클래스 규격 ──
enum WeaponClass {
	PISTOL,        ## 권총 (9mm)
	SMG,           ## 기관단총 (.45ACP)
	RIFLE,         ## 소총 (5.56mm)
	DMR,           ## 지정사수 (.762mm)
	SHOTGUN,       ## 샷건 (12Gauge)
	UNIVERSAL,     ## 범용/교차구경
}

## 플레이어가 학습하는 최상위 탄종은 이 3계열뿐이다.
## WeaponClass는 세이브·리소스 호환을 위해 5종을 유지하고, 전투 문법은 이 계열로 합친다.
enum AmmoFamily {
	LIGHT,         ## 경량탄 — 동일 적 유효 적중 3회 집중
	RIFLE,         ## 소총탄 — 후열 직선 관통
	SHOTGUN,       ## 산탄 — 근거리 거리 군집 확산
	UNIVERSAL,     ## 총기 문맥이 없는 공용 데이터
}

## 같은 탄종 안에서 총기에 고정된 기술 규격의 단계.
## 드래프트나 컨버전으로 교체하는 아이템 등급이 아니다.
enum AmmoGrade {
	STANDARD,
	ENHANCED,
	UNIVERSAL,
}

## ── 발사 방식 (커밋 단위) ──
## 정본: docs/gdd/21_fire_mode.md
## ⚠️ 총기 고유 속성이다. 파츠로 변경 불가, 전투 중 전환 불가.
enum FireMode {
	SINGLE,     ## 1발씩. 매 턴 판단·수정 가능
	FULL_AUTO,  ## 탄창 전체를 1턴에. 전량 커밋, 중간 수정 불가
}

## ── 총알 순서 의존 효과 ──
enum BulletEffect {
	NONE,          ## 효과 없음
	ARMOR_SHRED,   ## 피격 후 적 방어 감소
	COMBO,         ## 직전 탄 명중 시 대미지 보너스
	LAST_SHOT,     ## 탄창 마지막 탄일 때 대미지 배율
	OPENING_SHOT,  ## 탄창 첫 탄일 때 넉백 보너스
	CALIBER_DIFF,  ## 직전 탄과 역할이 다를 때 대미지 추가 보너스 (직렬화 값 5 유지)
	PIERCE,        ## 공유 트랙 일렬 다수 적 관통 다중타
	## ── 셋업 계열 (정본: docs/gdd/22_ammo_expansion.md §22.2) ──
	## ⚠️ 아래 둘은 **유효 적중(양 게이트 통과) 시에만** 발동하고 **다음 1발**에만 적용된다.
	##    파쇄(ARMOR_SHRED)는 **명중만으로** 발동하는데, 이 비대칭은 의도된 것이다 —
	##    파쇄가 유효 적중을 요구하면 관통 게이트를 여는 제 역할을 못 하게 된다.
	BUFF_ACC,      ## 다음 탄 ACC +N
	BUFF_PEN,      ## 다음 탄 PEN +N
	DEBUFF_EVA,    ## 명중한 적 EVA 영구 -N
	BUFF_MAG_ACC,  ## 유효 적중 시 탄창 잔여 전부 ACC +N
	BUFF_MAG_PEN,  ## 유효 적중 시 탄창 잔여 전부 PEN +N
	BUFF_DMG,      ## 유효 적중 시 다음 1발 DMG +N
}

## ── 적 아키타입 ──
enum EnemyArchetype {
	RUSHER,    ## 돌격병 — 빠르고 방어 낮음
	TANK,      ## 중장갑 — 느리고 방어 높음
	DODGER,    ## 회피형 — 중간 속도, 높은 회피
	CASTER,    ## 술사형 — 전진하지 않고 원거리 차징 공격
	ABSORBER,  ## 스택 스펀지 — 유효 격발 횟수로 처치 (3회)
	SCRAMBLER, ## 태세 전환병 — 3발 주기 자물쇠 교체
	BOSS_TANK_DODGE,    ## 보스: 디렉터 강 — 방패↔회피 태세 전환
	BOSS_CASTER_SPONGE, ## 보스: 세라프 프로토콜 — 배리어+차징+호위
	BOSS_SCRAMBLER,     ## 보스: 실험체 Ω — 3단 태세 순환(방패→회피→돌격)
	BOSS_FINAL,         ## 최종 보스: L.O.B 코어 — 2페이즈(배리어→태세+차징)
}

## ── 적 전투 중 태세 (Stance) ──
enum EnemyStance {
	NONE,            ## 기본 태세 (상태 변화 없음)
	IRON_SHIELD,     ## 물리 장갑 태세 — 방어 높음, 속도 느림
	ACTIVE_DODGER,   ## 회피 돌격 태세 — 회피 높음, 속도 빠름
	RUSH_CHARGE,     ## 돌격 태세 — 초고속 전진, 넉백 필수 (실험체 Ω 전용)
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
	CONVERSION_PISTOL, ## 경량탄(9mm) 컨버전 킷
	CONVERSION_SMG,    ## 강화 경량탄(.45ACP) 컨버전 킷
	CONVERSION_RIFLE,  ## 소총탄(5.56mm) 컨버전 킷
	CONVERSION_DMR,    ## 강화 소총탄(7.62mm) 컨버전 킷
	CONVERSION_SHOTGUN,## 산탄(12게이지) 컨버전 킷
}
