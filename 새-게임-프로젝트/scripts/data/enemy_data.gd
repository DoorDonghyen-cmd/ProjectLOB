class_name EnemyData
extends Resource

## 적 데이터 리소스
## 인카운터에서 등장하는 적의 기본 스탯 템플릿.
## 런타임에서는 EnemyInstance가 이 데이터를 복사하여 가변 상태를 관리한다.
## .tres 파일로 인스턴스를 만들어 resources/enemies/ 에 저장한다.

@export_group("기본 정보")
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var sprite_sheet: Texture2D
## 아키타입 — 속도↔방어 역상관 축 위의 위치
@export var archetype: Enums.EnemyArchetype = Enums.EnemyArchetype.RUSHER

@export_group("전투 스탯")
## 체력 (HP) — 0이 되면 처치
@export_range(1, 50) var max_hp: int = 10
## 방어 (DEF) — 관통 게이트 임계값
@export_range(0, 10) var defense: int = 1
## 회피임계값 (EVA) — 이 수치 이상의 ACC가 필요
@export_range(0, 8) var evasion: int = 3

@export_group("이동")
## 이동속도 (SPD) — 턴당 전진 칸 수
@export_range(1, 5) var speed: int = 1
## 시작 거리 — 인카운터 시작 시 플레이어와의 거리
@export_range(3, 20) var start_distance: int = 10
## 넉백 저항 — 피격 시 넉백되는 거리를 N칸 만큼 감소시킨다.
@export_range(0, 3) var knockback_resistance: int = 0
