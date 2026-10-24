## 게임 콘텐츠(.tres) 를 id 로 불러오는 한 곳. 폴더 경로를 여기서만 안다.
## 콘텐츠는 tools/generate_content.gd 가 만들고, 장비는 Resources/items/ 에 있다.
class_name Content
extends RefCounted

const UNIT_DIR: String = "res://Resources/content/units"
const CARD_DIR: String = "res://Resources/content/cards"
const ROOM_DIR: String = "res://Resources/content/rooms"
const ITEM_DIR: String = "res://Resources/items"


static func unit(id: String) -> UnitData:
	return _load(UNIT_DIR, id) as UnitData


static func card(id: String) -> CardData:
	return _load(CARD_DIR, id) as CardData


static func room(id: String) -> BattleRoomData:
	return _load(ROOM_DIR, id) as BattleRoomData


static func item(id: String) -> ItemData:
	return _load(ITEM_DIR, id) as ItemData


## id 의 유닛을 cell 에 세운 배치.
static func placement(unit_id: String, cell: Vector2i) -> UnitPlacement:
	return placement_of(unit(unit_id), cell)


static func placement_of(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var p := UnitPlacement.new()
	p.unit_data = data
	p.cell = cell
	return p


## 없는 id 면 오류를 남기고 null.
static func _load(dir: String, id: String) -> Resource:
	var path: String = "%s/%s.tres" % [dir, id]
	if not ResourceLoader.exists(path):
		push_error("content not found: %s" % path)
		return null
	return load(path)
