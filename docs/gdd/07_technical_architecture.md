# 🔫 Last on Board — 07. 기술 아키텍처 (Technical Architecture)

> **문서 경로**: `docs/gdd/07_technical_architecture.md`  
> **상위 문서**: [마스터 GDD](file:///d:/ProjectLoB/docs/game_design_document.md)

---

## 7. 기술 아키텍처 (Godot 4.x)

### 7.1 프로젝트 구조

```
새-게임-프로젝트/
├── scenes/                    # 씬 파일 (.tscn)
│   ├── combat/                # 전투 씬 (거리 트랙, 인카운터)
│   ├── ui/                    # UI 씬 (장전 화면, HUD)
│   └── main/                  # 메인 씬 (메뉴, 런 맵)
├── scripts/                   # GDScript 파일
│   ├── core/                  # 핵심 로직 (씬 비의존)
│   │   ├── damage_calculator.gd   # 결정론적 대미지 계산
│   │   └── magazine.gd            # 탄창 컨테이너
│   ├── data/                  # Resource 클래스 정의
│   │   ├── enums.gd               # 공유 열거형
│   │   ├── bullet_data.gd         # 총알 스키마
│   │   ├── gun_data.gd            # 총 스키마
│   │   └── enemy_data.gd          # 적 스키마
│   └── ui/                    # UI 스크립트
├── resources/                 # 리소스 인스턴스 (.tres)
│   ├── bullets/               # 총알 데이터
│   ├── guns/                  # 총 데이터
│   └── enemies/               # 적 데이터
├── assets/                    # 에셋
│   ├── sprites/
│   ├── audio/
│   └── fonts/
└── project.godot
```

### 7.2 데이터 레이어 (Resource 클래스)

Godot의 `Resource` 시스템을 활용하여 게임 데이터를 코드와 분리한다. 에디터 인스펙터에서 직접 편집 가능하므로 기획 이터레이션이 빠르다.

#### BulletData (`scripts/data/bullet_data.gd`)

```gdscript
class_name BulletData extends Resource

# 기본 스탯
@export var damage: int       # DMG — 기본 피해량
@export var accuracy: int     # ACC — 명중 임계값
@export var penetration: int  # PEN — 방어 무시

# 거리 제어
@export var knockback: int    # 넉백 칸 수
@export var slow: int         # 둔화량

# 순서 의존 효과
@export var effect_type: Enums.BulletEffect
@export var effect_value: int
```

#### GunData (`scripts/data/gun_data.gd`)

```gdscript
class_name GunData extends Resource

@export var magazine_capacity: int          # 탄창 크기
@export var reload_turns: int               # 리로드 턴 수
@export var has_chamber: bool               # 약실 유무 (+1발 선제사격 지원)
@export var passive_dmg_bonus: int          # 전탄 DMG 가산
@export var passive_pen_bonus: int          # 전탄 PEN 가산
@export var passive_knockback_bonus: int    # 전탄 넉백 가산
```

#### EnemyData (`scripts/data/enemy_data.gd`)

```gdscript
class_name EnemyData extends Resource

@export var max_hp: int         # HP
@export var defense: int        # DEF
@export var pen_resist: int     # PRES
@export var evasion: int        # EVA (0~8)
@export var speed: int          # SPD (턴당 전진)
@export var start_distance: int # 시작 거리
@export var archetype: Enums.EnemyArchetype
```

#### 공유 열거형 (`scripts/data/enums.gd`)

```gdscript
class_name Enums

enum BulletEffect { NONE, ARMOR_SHRED, COMBO, LAST_SHOT, OPENING_SHOT }
enum EnemyArchetype { RUSHER, TANK, DODGER }
```

### 7.3 핵심 로직 레이어

씬(Scene)에 의존하지 않는 순수 로직 클래스. 유닛 테스트 용이.

#### DamageCalculator (`scripts/core/damage_calculator.gd`)

정적 함수만으로 구성. GDD §3.2의 대미지 공식을 1:1 구현.

```gdscript
# 명중 판정: ACC ≥ EVA (결정론적)
static func check_hit(bullet, enemy_evasion) -> bool

# 대미지: DMG + max(PEN - PRES, 0) - DEF
static func calculate_damage(bullet, enemy_def, enemy_pres, gun) -> int

# 디버그용 계산 과정 문자열
static func damage_breakdown(bullet, enemy_def, enemy_pres, gun) -> String
```

#### Magazine (`scripts/core/magazine.gd`)

`RefCounted` 기반 순서 컨테이너. LIFO(스택) 구조로 작동하며, 나중에 들어온 탄환이 먼저 격발(pop_back)된다.

```gdscript
func load_bullets(bullets: Array[BulletData])  # 장전 (스택 push)
func fire() -> BulletData                      # 격발 (스택 pop_back)
func unload() -> BulletData                    # 빼내기 (스택 pop_back 및 버린 카드 유실, 적 1칸 전진)
func peek() -> BulletData                      # 다음 탄 미리보기
func is_next_first_shot() -> bool              # Opening Shot 판정
func is_next_last_shot() -> bool               # Last Shot 판정
```

### 7.4 시그널 플로우 (전투 이벤트 — 향후 구현)

프로토타입에서 구현할 CombatManager의 시그널 설계:

```
CombatManager (Node)
 │
 ├── signal combat_scene_started(enemy: EnemyData)
 ├── signal loading_phase_started(magazine: Magazine)
 ├── signal bullet_fired(bullet: BulletData, hit: bool, damage: int)
 ├── signal enemy_damaged(remaining_hp: int)
 ├── signal enemy_moved(new_distance: int)
 ├── signal enemy_knocked_back(distance: int)
 ├── signal reload_started(turns: int)
 ├── signal reload_finished()
 ├── signal result_phase_started()
 └── signal player_died()
```

> 💬 **코멘트**: 시그널 기반 아키텍처는 UI와 로직을 완전히 분리합니다. CombatManager가 이벤트를 발행하면, UI 노드들이 시그널을 구독하여 각자 연출합니다. 이 구조 덕분에 "로직은 그대로 두고 UI만 교체"하는 이터레이션이 가능합니다.

### 7.5 노드 트리 (전투 씬 — 향후 구현)

```
CombatScene (Node2D)
 ├── CombatManager (Node)          # 전투 루프 오케스트레이터
 ├── DistanceTrack (Node2D)        # 거리 트랙 시각화
 │   ├── PlayerMarker (Sprite2D)   # 플레이어 위치 (고정)
 │   └── EnemyMarker (Sprite2D)    # 적 위치 (이동)
 ├── MagazineUI (Control)          # 탄창 상태 표시
 │   └── BulletSlots (HBoxContainer)
 ├── EnemyInfoUI (Control)         # 적 스탯 표시
 └── ActionButtons (Control)       # 발사/리로드 버튼
```

### 7.6 샘플 데이터 (현재 생성 완료)

| 카테고리 | 파일 | 핵심 수치 및 전술 테마 |
|---|---|---|
| **총알** | `basic_bullet.tres` | JHP 탄환: DMG 3 / ACC 5 / PEN 0 — 기준선 |
| | `armor_piercing.tres` | FMJ 탄환: DMG 2 / ACC 5 / PEN 3 / Armor Shred -2 |
| | `knockback_slug.tres` | 슬러그/고무탄: DMG 1 / ACC 4 / 넉백 2칸 |
| | *`emp_bullet.tres` (예정)* | EMP 탄환: DMG 1 / ACC 6 / PEN 0 / 적 EVA 및 PRES 일시 감소 |
| **총** | `revolver.tres` | 6발 스택 / 리로드 1턴 / 약실 없음 — 기본 |
| | `shotgun.tres` | 2발 스택 / 넉백+1 패시브 — 거리 제어 |
| **적** | `rusher.tres` | 폭동 돌격병: SPD 3 / DEF 1 / HP 8 — 시간 압박 |
| | `tank.tres` | 진압 방패병: SPD 1 / DEF 5 / PRES 2 / HP 15 — 관통 퍼즐 |
| | `dodger.tres` | 나노 침투병: SPD 2 / EVA 6 / HP 6 — ACC 요구 |
