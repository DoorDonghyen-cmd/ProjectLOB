class_name Magazine
extends RefCounted

## 탄창 — 순서 있는 총알 컨테이너 + 행동 예산
##
## FIFO(큐): 먼저 넣은 탄이 먼저 나감 — 직관적, 기본 총
## LIFO(스택): 마지막에 넣은 탄이 먼저 나감 — 역순 사고, 고급 아키타입
##
## 사용법:
##   var mag = Magazine.new(gun_data)
##   mag.load_bullets([bullet_a, bullet_b, bullet_c])
##   var fired = mag.fire()  # FIFO → bullet_a 반환

var _bullets: Array[BulletData] = []
var _capacity: int
var _has_chamber: bool = false


func _init(gun: GunData) -> void:
	_capacity = gun.magazine_capacity
	_has_chamber = gun.has_chamber


## 총알을 장전한다. 탄창 크기를 초과하면 잘린다. (약실 탑재 시 capacity + 1발까지 장전 지원)
## LIFO 스택 구조이므로, 배열의 끝(pop_back)이 가장 먼저 격발된다.
## bullets의 순서 = 장전 순서 (플레이어가 드래그 앤 드롭한 순서).
func load_bullets(bullets: Array[BulletData]) -> void:
	_bullets.clear()
	var max_load := _capacity + (1 if _has_chamber else 0)
	var count := mini(bullets.size(), max_load)
	for i in range(count):
		_bullets.append(bullets[i])


## 인게임 전투 중 새 탄을 스택 맨 위에 올린다. (LIFO 탑 장전)
func insert_bullet(bullet: BulletData) -> void:
	var max_load := _capacity + (1 if _has_chamber else 0)
	if _bullets.size() < max_load:
		_bullets.append(bullet)


## 한 발 발사. LIFO(스택) 구조이므로 가장 나중에 들어온 탄(배열의 끝)을 꺼내 반환한다.
## 빈 탄창이면 null 반환.
func fire() -> BulletData:
	if _bullets.is_empty():
		return null
	return _bullets.pop_back()


## 빼내기. 스택의 맨 위 탄환을 제거하여 반환한다. (유실 및 적 전진 패널티와 연동)
func unload() -> BulletData:
	if _bullets.is_empty():
		return null
	return _bullets.pop_back()


## 현재 탄창에서 다음에 발사될 탄을 미리 본다 (LIFO이므로 배열의 끝 확인).
func peek() -> BulletData:
	if _bullets.is_empty():
		return null
	return _bullets.back()


## 잔탄 수
func get_remaining() -> int:
	return _bullets.size()


## 탄창이 비었는가
func is_empty() -> bool:
	return _bullets.is_empty()


## 탄창이 꽉 찼는가
func is_full() -> bool:
	var max_load := _capacity + (1 if _has_chamber else 0)
	return _bullets.size() >= max_load


## 탄창 최대 용량
func get_capacity() -> int:
	return _capacity


## 현재 장전된 총알 목록 (복사본 반환)
func get_loaded_bullets() -> Array[BulletData]:
	return _bullets.duplicate()


## 현재 탄의 위치가 탄창의 첫 번째인지 (Opening Shot 판정용)
func is_next_first_shot() -> bool:
	return _bullets.size() == _capacity


## 현재 탄의 위치가 탄창의 마지막인지 (Last Shot 판정용)
func is_next_last_shot() -> bool:
	return _bullets.size() == 1


## 탄창을 비운다 (강제 리로드 등에 사용)
func clear() -> void:
	_bullets.clear()
