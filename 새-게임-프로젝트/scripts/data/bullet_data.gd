class_name BulletData
extends Resource

## 총알 데이터 리소스
## 드래프트 가능한 카드 단위. DMG/ACC/PEN 기본 스탯 + 부가 효과.
## .tres 파일로 인스턴스를 만들어 resources/bullets/ 에 저장한다.

@export_group("기본 정보")
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
## 시작 덱·기본 보급에서 사용하는 계열 대표 탄환인지 여부
@export var is_basic: bool = false
## v6 탄환 층: basic(기반) / support(보조) / special(조건부 공격) / control(제어)
@export_enum("basic", "support", "special", "control") var family: String = "basic"
## 덱 구성 역할. 표시 문구와 색상은 BulletRoleUI에서 중앙 관리한다.
@export_enum("attack", "link", "control") var role: String = "attack"
## 실제 구경. 기반탄 5종만 구체 구경을 가지며 나머지는 UNIVERSAL이다.
@export var weapon_class: Enums.WeaponClass = Enums.WeaponClass.PISTOL
## 효과 발동 계약을 데이터와 UI가 직접 설명하는 v6 메타데이터.
@export var trigger: String = "none"
@export var scope: String = "none"
@export var condition: String = "none"

@export_group("기본 스탯")
## 대미지 (DMG) — 적에게 가하는 기본 피해량
@export_range(0, 20) var damage: int = 1
## 명중 (ACC) — 적의 EVA 이상이어야 명중 (결정론적 임계값)
@export_range(0, 10) var accuracy: int = 5
## 관통 (PEN) — 적의 PRES를 넘는 만큼 방어 무시
@export_range(0, 10) var penetration: int = 0

@export_group("거리 제어")
## 넉백 — 적을 N칸 뒤로 밀어냄 (거리 회복)
@export_range(0, 5) var knockback: int = 0
## 둔화 — 적의 다음 턴 이동속도를 N만큼 감소
@export_range(0, 3) var slow: int = 0

@export_group("순서 의존 효과")
## 효과 유형 — 장전 순서에 따라 발동하는 특수 효과
@export var effect_type: Enums.BulletEffect = Enums.BulletEffect.NONE
## 효과 수치 — ARMOR_SHRED: 방어 감소량, COMBO: 대미지 보너스, 
## LAST_SHOT: 마지막 발 정액 피해, OPENING_SHOT: 넉백 보너스,
## BUFF_ACC / BUFF_PEN: 다음 1발, DEBUFF_EVA: 적 영구,
## BUFF_MAG_ACC / BUFF_MAG_PEN: 탄창 잔여 전체에 더하는 해당 스탯
@export var effect_value: int = 0
