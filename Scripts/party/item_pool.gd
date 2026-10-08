## Resources/items/ 의 아이템을 불러오고 무작위로 뽑는 도구 (획득 보상용).
class_name ItemPool
extends RefCounted

const ITEM_DIR: String = "res://Resources/items"


## 폴더 안의 모든 ItemData 를 파일 이름순으로 불러온다. 파일 이름순이라 같은 시드면 같은 결과가 나온다.
static func load_all() -> Array[ItemData]:
	var items: Array[ItemData] = []
	var dir := DirAccess.open(ITEM_DIR)
	if dir == null:
		return items
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var item: Resource = load("%s/%s" % [ITEM_DIR, file_name])
		if item is ItemData:
			items.append(item)
	return items


## 풀에서 하나를 중복 허용으로 뽑는다. 풀이 비어 있으면 null.
static func roll(rng: RandomNumberGenerator, pool: Array[ItemData]) -> ItemData:
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]
