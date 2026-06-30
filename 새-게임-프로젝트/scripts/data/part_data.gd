class_name PartData
extends Resource

## 총기 장착 파츠 데이터 리소스
## 개별 파츠의 비주얼 정보 및 작동 층위 분류를 규정합니다.

@export_group("기본 정보")
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("분류")
## 파츠 식별용 고유 ID
@export var part_id: Enums.PartID = Enums.PartID.NONE
## 파츠의 작동 층위 (1: LIFO 스택, 2: 거리 제어, 3: 스탯 매칭, 4: 태세 제어, 5: 시스템 변조)
@export_range(1, 5) var tier: int = 1
