class_name GunData
extends Resource

## 총 데이터 리소스
## 탄창 규칙 · 리로드 방식 · 패시브를 정의하는 빌드 아키타입.
## 직접 대미지를 주지 않고, 총알이 어떻게 작동하는지의 규칙을 결정한다.
## .tres 파일로 인스턴스를 만들어 resources/guns/ 에 저장한다.

@export_group("기본 정보")
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("탄창 규칙")
## 탄창 크기 — 한 번에 장전 가능한 최대 총알 수
@export_range(1, 12) var magazine_capacity: int = 6
## 약실 탑재 여부 — 1발 약실 추가 적재 기능 지원 여부
@export var has_chamber: bool = false
## 탄창 구조 (0: LIFO 등 기존 호환용)
@export var magazine_structure: int = 0

@export_group("리로드")
## 리로드 턴 수 — 리로드에 소모되는 턴 (이 동안 적이 전진)
@export_range(1, 3) var reload_turns: int = 1

@export_group("파츠 슬롯")
## 일반 파츠 장착 가능한 최대 슬롯 개수
@export_range(1, 5) var parts_capacity: int = 3
## 총기에 고정되어 해제할 수 없는 고유 내장 파츠
@export var default_part: PartData

@export_group("패시브 효과")
## 모든 총알의 DMG에 가산되는 보너스
@export_range(-3, 5) var passive_dmg_bonus: int = 0
## 모든 총알의 PEN에 가산되는 보너스
@export_range(-3, 5) var passive_pen_bonus: int = 0
## 모든 총알의 넉백에 가산되는 보너스
@export_range(-1, 3) var passive_knockback_bonus: int = 0
## 모든 총알의 명중에 가산되는 보너스
@export_range(-3, 5) var passive_acc_bonus: int = 0
## 전투 중 탄창에서 보여질 예고창의 크기
@export_range(0, 4) var preview_window_size: int = 2
