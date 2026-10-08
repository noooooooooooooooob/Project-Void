extends TestCase


func run() -> Array[Dictionary]:
	_test_slot_names()
	_test_summary_lists_only_nonzero_bonuses()
	_test_item_pool_loads_the_item_resources()
	_test_item_pool_roll_is_deterministic()
	_test_item_pool_roll_on_empty_pool()
	return results()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_slot_names() -> void:
	check_eq("weapon slot name", ItemData.slot_name(ItemData.Slot.WEAPON), "무기")
	check_eq("armor slot name", ItemData.slot_name(ItemData.Slot.ARMOR), "방어구")
	check_eq("accessory slot name", ItemData.slot_name(ItemData.Slot.ACCESSORY), "장신구")


func _test_summary_lists_only_nonzero_bonuses() -> void:
	var item := ItemData.new()
	check_eq("an item with no bonuses has an empty summary", item.summary(), "")
	item.max_hp_bonus = 4
	item.speed_bonus = -1
	check_eq("summary shows signed non-zero bonuses", item.summary(), "체력 +4 · 속도 -1")
	item.max_sp_bonus = 1
	item.attack_bonus = 2
	check_eq("summary lists every bonus in a fixed order", item.summary(), "체력 +4 · 속도 -1 · SP +1 · 공격 +2")


func _test_item_pool_loads_the_item_resources() -> void:
	var pool: Array[ItemData] = ItemPool.load_all()
	check("the item folder is not empty", pool.size() >= 6)
	var ids: Dictionary = {}
	var slots: Dictionary = {}
	for item in pool:
		check("item %s has a display name" % item.id, item.display_name != "")
		ids[item.id] = true
		slots[item.slot] = true
	check_eq("every item id is unique", ids.size(), pool.size())
	check_eq("every slot has at least one item", slots.size(), 3)


func _test_item_pool_roll_is_deterministic() -> void:
	var pool: Array[ItemData] = ItemPool.load_all()
	var a: ItemData = ItemPool.roll(_rng(9), pool)
	var b: ItemData = ItemPool.roll(_rng(9), pool)
	check("same seed rolls an item", a != null)
	check("same seed rolls the same item", a == b)


func _test_item_pool_roll_on_empty_pool() -> void:
	var empty: Array[ItemData] = []
	check("rolling an empty pool gives null", ItemPool.roll(_rng(1), empty) == null)
