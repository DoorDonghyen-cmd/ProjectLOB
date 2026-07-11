extends Resource

## 전술 소모품 데이터 리소스
## 가방에 적재되며 전투 중 즉발적인 혜택을 주는 소모성 물자입니다.

@export var display_name: String = ""
@export_multiline var description: String = ""
@export var price: int = 20
@export var type: String = "heal" # "heal", "shred" 등
@export var icon_text: String = "✚"
