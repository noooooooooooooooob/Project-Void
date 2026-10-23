# 튜토리얼·1장 콘텐츠(카드·유닛·전투방)를 표로 정의해 Resources/content/ 에 .tres 로 저장한다.
# 저장된 .tres 는 에디터 인스펙터에서 그대로 고칠 수 있다 (다시 실행하면 이 표의 값으로 덮어쓴다).
# 실행: Godot --headless --path <프로젝트> --script res://tools/generate_content.gd
extends SceneTree

const OUT: String = "res://Resources/content"

## 카드: id → [이름, SP, 공격 방식, 분류, 범위, 효과들]
## 효과: [종류, %, 고정값, 상태 id, 대상] (뒤쪽은 생략 가능, 대상 기본 AREA)
const CARDS: Dictionary = {
	# --- 한결 (주인공) ---
	"slash": ["베기", 1, "MELEE", "ATTACK", [], [["DAMAGE", 70]]],
	"guard": ["막기", 1, "SELF", "SKILL", [], [["BLOCK", 80, 0, "", "SELF"]]],
	"rift_thrust": ["균열 찌르기", 1, "MELEE", "ATTACK", [], [["DAMAGE", 45], ["STAGGER", 100]]],
	"quick_shot": ["견제 사격", 1, "RANGED", "ATTACK", [], [["DAMAGE", 45]]],
	"heavy_cut": ["내려베기", 2, "MELEE", "ATTACK", [], [["DAMAGE", 140]]],
	"sweep": ["휩쓸기", 2, "MELEE", "ATTACK", [Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1)], [["DAMAGE", 55]]],
	"void_step": ["공허 걸음", 0, "SELF", "SKILL", [], [["BLOCK", 45, 0, "", "SELF"]]],
	"rift_burst": ["균열 폭발", 2, "RANGED", "SPECIAL", [Vector2i(0, 0), Vector2i(1, 0)], [["DAMAGE", 60], ["STAGGER", 120]]],
	"second_wind": ["숨 고르기", 1, "SELF", "SKILL", [], [["HEAL", 60, 0, "", "SELF"]]],
	"cover": ["엄호", 1, "ALLY", "SKILL", [], [["BLOCK", 75]]],
	# --- 홍연 ---
	"blood_claw": ["혈조", 1, "MELEE", "ATTACK", [], [["DAMAGE", 70], ["GAIN_STATUS", 0, 1, "blood_armor", "SELF"]]],
	"bloodletting": ["사혈", 0, "SELF", "SKILL", [], [["HP_COST", 0, 3, "", "SELF"], ["GAIN_STATUS", 0, 2, "blood_armor", "SELF"]]],
	"blood_veil": ["혈막", 1, "SELF", "SKILL", [], [["BLOCK", 80, 0, "", "SELF"], ["GAIN_STATUS", 0, 1, "blood_armor", "SELF"]]],
	"blood_burst": ["혈폭", 2, "MELEE", "SPECIAL", [Vector2i(0, 0), Vector2i(1, 0)], [["BURST", 50, 0, "blood_armor"]]],
	"frenzy": ["광란", 2, "MELEE", "ATTACK", [], [["DAMAGE", 45], ["DAMAGE", 45], ["STAGGER", 50]]],
	"fox_fang": ["여우 이빨", 1, "MELEE", "ATTACK", [], [["DAMAGE", 35], ["STAGGER", 130]]],
	"crimson_feast": ["피의 연회", 1, "MELEE", "ATTACK", [], [["DAMAGE", 60], ["HEAL", 30, 0, "", "SELF"]]],
	"red_fox": ["붉은 여우", 1, "SELF", "SKILL", [], [["GAIN_STATUS", 0, 3, "blood_armor", "SELF"]]],
	"blood_lance": ["혈창", 2, "RANGED", "SPECIAL", [], [["BURST", 35, 0, "blood_armor"]]],
	"drowsy_guard": ["졸린 방어", 1, "SELF", "SKILL", [], [["BLOCK", 120, 0, "", "SELF"]]],
	# --- 선배들 (튜토리얼) ---
	"heavy_slash": ["강타", 2, "MELEE", "ATTACK", [], [["DAMAGE", 120]]],
	"shield_bash": ["방패 치기", 1, "MELEE", "ATTACK", [], [["DAMAGE", 50], ["STAGGER", 80]]],
	"snipe": ["저격", 2, "RANGED", "ATTACK", [], [["DAMAGE", 110]]],
	"volley": ["연사", 2, "RANGED", "ATTACK", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], [["DAMAGE", 35]]],
	"mend": ["치유", 1, "ALLY", "SKILL", [], [["HEAL", 70]]],
	"void_bolt": ["공허탄", 1, "RANGED", "ATTACK", [], [["DAMAGE", 55]]],
	"ward": ["보호막", 1, "ALLY", "SKILL", [], [["BLOCK", 70]]],
	# --- 적 ---
	"rat_bite": ["물어뜯기", 0, "MELEE", "ATTACK", [], [["DAMAGE", 70]]],
	"hound_bite": ["덮치기", 0, "MELEE", "ATTACK", [], [["DAMAGE", 80], ["STAGGER", 40]]],
	"leech_drain": ["흡혈", 0, "MELEE", "ATTACK", [], [["DAMAGE", 60], ["HEAL", 40, 0, "", "SELF"]]],
	"husk_swipe": ["휘두르기", 0, "MELEE", "ATTACK", [], [["DAMAGE", 75]]],
	"husk_guard": ["웅크리기", 0, "SELF", "SKILL", [], [["BLOCK", 80, 0, "", "SELF"]]],
	"brute_slam": ["내리찍기", 0, "MELEE", "ATTACK", [Vector2i(0, 0), Vector2i(1, 0)], [["DAMAGE", 90], ["STAGGER", 40]]],
	"brute_guard": ["기름 갑옷", 0, "SELF", "SKILL", [], [["BLOCK", 100, 0, "", "SELF"]]],
	"brute_rest": ["기름 재생", 0, "SELF", "SKILL", [], [["HEAL", 50, 0, "", "SELF"]]],
	"crown_flood": ["검은 범람", 0, "RANGED", "ATTACK", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], [["DAMAGE", 55], ["STAGGER", 30]]],
	"crown_guard": ["왕관의 벽", 0, "SELF", "SKILL", [], [["BLOCK", 110, 0, "", "SELF"]]],
	"crown_mend": ["핵의 맥동", 0, "SELF", "SKILL", [], [["HEAL", 60, 0, "", "SELF"]]],
	"hand_crush": ["황혼의 손아귀", 0, "RANGED", "SPECIAL", [
		Vector2i(-2, -2), Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2), Vector2i(2, -2),
		Vector2i(-2, -1), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1),
		Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(-2, 1), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(-2, 2), Vector2i(-1, 2), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)], [["DAMAGE", 400]]],
}

## 아군: id → 사양. sprite 는 Art/gen/units/<sprite>*.png
const ALLIES: Dictionary = {
	"hangyeol": {"name": "한결", "hp": 34, "speed": 12, "attack": 10, "defense": 10, "crit": 5, "move": 2, "stagger": 20, "sp": 3,
		"deck": ["slash", "slash", "slash", "guard", "guard", "rift_thrust", "rift_thrust", "quick_shot"]},
	"hongyeon": {"name": "홍연", "hp": 30, "speed": 14, "attack": 12, "defense": 8, "crit": 10, "move": 3, "stagger": 16, "sp": 3,
		"passives": ["blood_armor", "blood_thirst"],
		"deck": ["blood_claw", "blood_claw", "bloodletting", "blood_veil", "blood_veil", "blood_burst", "frenzy", "fox_fang"]},
	"doyun": {"name": "강도윤", "hp": 44, "speed": 9, "attack": 12, "defense": 14, "crit": 5, "move": 1, "stagger": 28, "sp": 3,
		"deck": ["heavy_slash", "heavy_slash", "shield_bash", "shield_bash", "guard", "guard"]},
	"mira": {"name": "서미라", "hp": 26, "speed": 15, "attack": 11, "defense": 7, "crit": 15, "move": 2, "stagger": 16, "sp": 3,
		"deck": ["snipe", "snipe", "quick_shot", "quick_shot", "quick_shot", "volley"]},
	"baekjun": {"name": "백준", "hp": 24, "speed": 11, "attack": 9, "defense": 8, "crit": 5, "move": 2, "stagger": 16, "sp": 3,
		"deck": ["mend", "mend", "void_bolt", "void_bolt", "void_bolt", "ward"]},
}

## 적: id → 사양.
const ENEMIES: Dictionary = {
	"rat": {"name": "공허 쥐", "sprite": "rat", "hp": 16, "speed": 13, "attack": 8, "defense": 6, "move": 2, "stagger": 8, "move_chance": 0.3, "attack_card": "rat_bite"},
	"hound": {"name": "잠식된 들개", "sprite": "hound", "hp": 24, "speed": 15, "attack": 10, "defense": 8, "move": 3, "stagger": 12, "move_chance": 0.25, "attack_card": "hound_bite"},
	"leech": {"name": "공허 거머리", "sprite": "leech", "hp": 22, "speed": 6, "attack": 9, "defense": 8, "move": 1, "stagger": 10, "move_chance": 0.1, "attack_card": "leech_drain"},
	"husk": {"name": "잠든 자", "sprite": "husk", "hp": 30, "speed": 7, "attack": 9, "defense": 10, "move": 1, "stagger": 16, "move_chance": 0.15, "attack_card": "husk_swipe", "defend_card": "husk_guard"},
	"brute": {"name": "검은 기름 거인", "sprite": "brute", "hp": 64, "speed": 6, "attack": 11, "defense": 12, "move": 1, "stagger": 30, "move_chance": 0.0, "attack_card": "brute_slam", "defend_card": "brute_guard", "rest_card": "brute_rest"},
	"crown": {"name": "하수도의 왕관", "sprite": "crown", "hp": 140, "speed": 8, "attack": 12, "defense": 14, "move": 0, "stagger": 45, "move_chance": 0.0, "attack_card": "crown_flood", "defend_card": "crown_guard", "rest_card": "crown_mend"},
	"hand": {"name": "황혼의 손", "sprite": "hand", "hp": 999, "speed": 99, "attack": 10, "defense": 10, "move": 0, "stagger": 999, "move_chance": 0.0, "attack_card": "hand_crush"},
}

## 전투방: id → 배경 그림 이름과 어둡기.
const ROOMS: Dictionary = {
	"factory": {"backdrop": "factory", "dim": 0.3},
	"sewer": {"backdrop": "sewer", "dim": 0.25},
	"twilight": {"backdrop": "twilight", "dim": 0.2},
	"core": {"backdrop": "core", "dim": 0.2},
}

var _cards: Dictionary = {}


func _initialize() -> void:
	for sub in ["cards", "units", "rooms"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [OUT, sub])
	for id in CARDS:
		var path: String = "%s/cards/%s.tres" % [OUT, id]
		_save(_card(id, CARDS[id]), path)
		# 저장한 파일을 다시 불러와 써야 유닛 덱이 카드를 복사하지 않고 파일로 참조한다.
		_cards[id] = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	for id in ALLIES:
		_save(_ally(id, ALLIES[id]), "%s/units/%s.tres" % [OUT, id])
	for id in ENEMIES:
		_save(_enemy(id, ENEMIES[id]), "%s/units/%s.tres" % [OUT, id])
	for id in ROOMS:
		_save(_room(ROOMS[id]), "%s/rooms/%s.tres" % [OUT, id])
	print("content generated: %d cards, %d allies, %d enemies, %d rooms" % [CARDS.size(), ALLIES.size(), ENEMIES.size(), ROOMS.size()])
	quit()


func _save(res: Resource, path: String) -> Resource:
	var err: Error = ResourceSaver.save(res, path, ResourceSaver.FLAG_CHANGE_PATH)
	if err != OK:
		push_error("could not save %s (%s)" % [path, err])
	return res


func _card(id: String, row: Array) -> CardData:
	var card := CardData.new()
	card.id = StringName(id)
	card.display_name = row[0]
	card.sp_cost = row[1]
	card.attack_type = CardData.AttackType[row[2]]
	card.category = CardData.Category[row[3]]
	var area: Array[Vector2i] = []
	for cell in row[4]:
		area.append(cell)
	card.area = area
	var effects: Array[CardEffect] = []
	for e in row[5]:
		var effect := CardEffect.new()
		effect.kind = CardEffect.Kind[e[0]]
		effect.percent = e[1] if e.size() > 1 else 100
		effect.value = e[2] if e.size() > 2 else 0
		effect.status = StringName(e[3]) if e.size() > 3 else &""
		effect.target = CardEffect.Target[e[4]] if e.size() > 4 else CardEffect.Target.AREA
		effects.append(effect)
	card.effects = effects
	return card


func _base(data: UnitData, id: String, spec: Dictionary) -> void:
	data.id = StringName(id)
	data.display_name = spec["name"]
	data.max_hp = spec["hp"]
	data.speed = spec["speed"]
	data.attack = spec["attack"]
	data.defense = spec["defense"]
	data.crit_chance = spec.get("crit", 0)
	data.move = spec.get("move", 2)
	data.stagger = spec.get("stagger", 15)
	var passives: Array[StringName] = []
	for p in spec.get("passives", []):
		passives.append(StringName(p))
	data.passives = passives
	var sprite: String = spec.get("sprite", id)
	data.sprite = load("res://Art/gen/units/%s.png" % sprite)
	data.idle_sheet = load("res://Art/gen/units/%s_idle.png" % sprite)
	data.attack_sheet = load("res://Art/gen/units/%s_attack.png" % sprite)
	data.hit_sheet = load("res://Art/gen/units/%s_hit.png" % sprite)


func _ally(id: String, spec: Dictionary) -> AllyData:
	var data := AllyData.new()
	_base(data, id, spec)
	data.max_sp = spec.get("sp", 3)
	var deck: Array[CardData] = []
	for card_id in spec["deck"]:
		deck.append(_cards[card_id])
	data.deck = deck
	return data


func _enemy(id: String, spec: Dictionary) -> EnemyData:
	var data := EnemyData.new()
	_base(data, id, spec)
	data.move_chance = spec.get("move_chance", 0.2)
	data.attack_card = _cards.get(spec.get("attack_card", ""))
	data.defend_card = _cards.get(spec.get("defend_card", ""))
	data.rest_card = _cards.get(spec.get("rest_card", ""))
	return data


func _room(spec: Dictionary) -> BattleRoomData:
	var room := BattleRoomData.new()
	room.backdrop = load("res://Art/gen/battle/%s.png" % spec["backdrop"])
	room.backdrop_dim = spec["dim"]
	room.ally_tile_texture = load("res://Art/gen/tiles/ally.png")
	room.enemy_tile_texture = load("res://Art/gen/tiles/enemy.png")
	return room
