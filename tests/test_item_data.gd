# ItemData(장비 아이템)·ItemPool(아이템 풀) 테스트: 부위 이름, 보너스 요약, 폴더 불러오기, 뽑기.
extends TestCase


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	_test_slot_names()
	# 요약은 0 이 아닌 보너스만.
	_test_summary_lists_only_nonzero_bonuses()
	_test_item_pool_loads_the_item_resources()
	_test_item_pool_roll_is_deterministic()
	# 빈 풀에서 뽑으면 null.
	_test_item_pool_roll_on_empty_pool()
	return results()


# 시드를 고정한 난수 생성기 (뽑기 결과를 재현하기 위해).
func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# 부위마다 화면 이름이 맞다.
func _test_slot_names() -> void:
	check_eq("weapon slot name", ItemData.slot_name(ItemData.Slot.WEAPON), "무기")
	check_eq("armor slot name", ItemData.slot_name(ItemData.Slot.ARMOR), "방어구")
	check_eq("accessory slot name", ItemData.slot_name(ItemData.Slot.ACCESSORY), "장신구")


# 요약은 0 이 아닌 보너스만 부호와 함께, 정해진 순서로 보인다.
func _test_summary_lists_only_nonzero_bonuses() -> void:
	var item := ItemData.new()
	check_eq("an item with no bonuses has an empty summary", item.summary(), "")
	# 체력 +4.
	item.max_hp_bonus = 4
	# 속도 -1.
	item.speed_bonus = -1
	check_eq("summary shows signed non-zero bonuses", item.summary(), "체력 +4 · 속도 -1")
	# SP +1.
	item.max_sp_bonus = 1
	# 공격 +2.
	item.attack_bonus = 2
	# 체력·속도·SP·공격 순서.
	check_eq("summary lists every bonus in a fixed order", item.summary(), "체력 +4 · 속도 -1 · SP +1 · 공격 +2")


# 아이템 폴더에 아이템이 충분히 있고, 이름·id·부위가 제대로 채워져 있다.
func _test_item_pool_loads_the_item_resources() -> void:
	var pool: Array[ItemData] = ItemPool.load_all()
	# 6 개 이상.
	check("the item folder is not empty", pool.size() >= 6)
	# 나온 id 모음.
	var ids: Dictionary = {}
	var slots: Dictionary = {}
	for item in pool:
		check("item %s has a display name" % item.id, item.display_name != "")
		# id 를 모은다.
		ids[item.id] = true
		slots[item.slot] = true
	# id 가 겹치지 않는다.
	check_eq("every item id is unique", ids.size(), pool.size())
	check_eq("every slot has at least one item", slots.size(), 3)


# 같은 시드로 뽑으면 같은 아이템이 나온다.
func _test_item_pool_roll_is_deterministic() -> void:
	var pool: Array[ItemData] = ItemPool.load_all()
	# 시드 9 로 한 번.
	var a: ItemData = ItemPool.roll(_rng(9), pool)
	# 시드 9 로 또 한 번.
	var b: ItemData = ItemPool.roll(_rng(9), pool)
	check("same seed rolls an item", a != null)
	check("same seed rolls the same item", a == b)


# 빈 풀에서 뽑으면 null.
func _test_item_pool_roll_on_empty_pool() -> void:
	var empty: Array[ItemData] = []
	# null 이 나온다.
	check("rolling an empty pool gives null", ItemPool.roll(_rng(1), empty) == null)
