## Resources/items/ 의 아이템을 불러오고 무작위로 뽑는 도구 (획득 보상용).
class_name ItemPool
# RefCounted: 노드가 아닌 가벼운 객체. 정적 함수만 쓰므로 만들 일은 없다.
extends RefCounted

## 아이템 .tres 파일이 들어 있는 폴더.
const ITEM_DIR: String = "res://Resources/items"


## 폴더 안의 모든 ItemData 를 파일 이름순으로 불러온다. 파일 이름순이라 같은 시드면 같은 결과가 나온다.
static func load_all() -> Array[ItemData]:
	# 불러온 아이템 목록.
	var items: Array[ItemData] = []
	# 폴더 안의 파일 이름들. DirAccess.get_files 는 내보낸 빌드에서 "x.tres.remap" 을 돌려주므로 ResourceLoader 로 나열한다.
	var files: PackedStringArray = ResourceLoader.list_directory(ITEM_DIR)
	# 이름순으로 정렬한다 (운영체제마다 나열 순서가 달라도 결과가 같게).
	files.sort()
	# 파일을 하나씩 본다.
	for file_name in files:
		# 리소스 파일이 아니면 건너뛴다 (.import 등).
		if not file_name.ends_with(".tres"):
			continue
		# 파일을 불러온다.
		var item: Resource = load("%s/%s" % [ITEM_DIR, file_name])
		# 아이템 데이터일 때만 목록에 넣는다.
		if item is ItemData:
			items.append(item)
	# 다 모은 목록을 돌려준다.
	return items


## 풀에서 하나를 중복 허용으로 뽑는다. 풀이 비어 있으면 null.
static func roll(rng: RandomNumberGenerator, pool: Array[ItemData]) -> ItemData:
	# 뽑을 것이 없으면 null.
	if pool.is_empty():
		return null
	# 무작위 위치의 아이템을 돌려준다.
	return pool[rng.randi_range(0, pool.size() - 1)]
