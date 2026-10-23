# 프로토타입용 그림을 전부 코드로 만들어 Art/gen/ 에 PNG 로 저장한다 (기존 Art/ 의 그림은 쓰지 않는다).
# 실행: Godot --headless --path <프로젝트> --script res://tools/generate_art.gd
# 다시 실행하면 같은 그림을 덮어쓴다 (모든 난수는 시드 고정).
extends SceneTree

const OUT: String = "res://Art/gen"
## 픽셀 프레임 한 칸 크기와 확대 배율 (32px 로 그리고 2 배로 저장 → 64px 프레임).
const FRAME: int = 32
const SCALE: int = 2

## 사람형 유닛 사양.
const HUMANS: Dictionary = {
	"hangyeol": {"skin": "#f0d6c4", "hair": "#1d1b22", "hair_style": "short", "coat": "#2b3350", "coat_dark": "#1c2238", "accent": "#8a8f9a", "pants": "#22232c", "eye": "#8b5cd6", "weapon": "sword"},
	"hongyeon": {"skin": "#f4e1d8", "hair": "#7a1420", "hair_style": "fox", "coat": "#1c1418", "coat_dark": "#0f0a0d", "accent": "#b0142a", "pants": "#1c1418", "eye": "#d01c2c", "weapon": "claws", "small": true},
	"doyun": {"skin": "#e2c0a4", "hair": "#4a3324", "hair_style": "helmet", "helmet": "#6a707c", "coat": "#5d6470", "coat_dark": "#3e434d", "accent": "#d0782c", "pants": "#2c2a28", "eye": "#2a1d14", "weapon": "greatsword"},
	"mira": {"skin": "#f1d3bd", "hair": "#d8b75a", "hair_style": "pony", "coat": "#3e5a46", "coat_dark": "#2a3d30", "accent": "#c9c3a8", "pants": "#2f2b25", "eye": "#3b6a3f", "weapon": "gun"},
	"baekjun": {"skin": "#ead2c0", "hair": "#d9dbe2", "hair_style": "short", "coat": "#2c5c62", "coat_dark": "#1c3d42", "accent": "#a8e0d8", "pants": "#1f2a2c", "eye": "#24464c", "weapon": "staff"},
}
## 괴물 종류.
const MONSTERS: Array[String] = ["rat", "hound", "leech", "husk", "brute", "crown", "hand"]
## 방 테마.
const ROOM_THEMES: Array[String] = ["factory", "sewer", "core", "twilight"]
## 소품.
const PROPS: Array[String] = ["barrel", "crate", "valve", "crystal", "lamp", "growth", "rubble"]
## 대화 배경.
const BACKGROUNDS: Array[String] = ["title", "academy", "office", "sewer_gate", "void", "twilight", "alley_rain", "core_room"]
## 일러스트 사양.
const PORTRAITS: Dictionary = {
	"hangyeol": {"skin": "#f0d6c4", "hair": "#1d1b22", "hair_style": "short", "outfit": "#2b3350", "accent": "#8a8f9a", "eye": "#8b5cd6"},
	"hongyeon": {"skin": "#f6e4dc", "hair": "#7a1420", "hair_style": "fox", "outfit": "#1c1418", "accent": "#3a1820", "eye": "#d01c2c", "small": true, "sleepy": true, "extra": "ribbon"},
	"hyeolgwi": {"skin": "#e4d0c8", "hair": "#8d8a90", "hair_style": "slick", "outfit": "#2a1216", "accent": "#5a0f18", "eye": "#c4141f", "beard": true, "stern": true},
	"doyun": {"skin": "#e2c0a4", "hair": "#4a3324", "hair_style": "short", "outfit": "#5d6470", "accent": "#d0782c", "eye": "#2a1d14", "scar": true, "extra": "armor"},
	"mira": {"skin": "#f1d3bd", "hair": "#d8b75a", "hair_style": "bob", "outfit": "#3e5a46", "accent": "#c9c3a8", "eye": "#3b6a3f", "extra": "goggles"},
	"baekjun": {"skin": "#ead2c0", "hair": "#d9dbe2", "hair_style": "short", "outfit": "#2c5c62", "accent": "#a8e0d8", "eye": "#24464c"},
	"supervisor": {"skin": "#dcb89c", "hair": "#3a3a40", "hair_style": "cap", "outfit": "#4e4a3a", "accent": "#c8a04a", "eye": "#2a2a2a", "beard": true},
	"instructor": {"skin": "#e0c4ae", "hair": "#2b2b2f", "hair_style": "slick", "outfit": "#3a2c4a", "accent": "#c9b48a", "eye": "#3a2f20", "stern": true},
}
const ICONS: Dictionary = {
	"weapon": "#b0142a", "armor": "#5d6470", "accessory": "#c9a24a", "card": "#7a4cc2", "gold": "#e0b552", "heart": "#d0303a",
}


func _initialize() -> void:
	var started: int = Time.get_ticks_msec()
	_units()
	_rooms()
	_props()
	_effects()
	_backgrounds()
	_icons()
	_portraits()
	print("art generated in %d ms -> %s" % [Time.get_ticks_msec() - started, OUT])
	quit()


func _spec(raw: Dictionary) -> Dictionary:
	var spec: Dictionary = {}
	for key in raw:
		var value: Variant = raw[key]
		spec[key] = Color.html(value) if value is String and (value as String).begins_with("#") else value
	return spec


## 프레임 캔버스들을 가로로 이어 붙여 저장한다.
func _save_sheet(frames: Array[PixelCanvas], path: String) -> void:
	var sheet := PixelCanvas.new(FRAME * frames.size(), FRAME)
	for i in frames.size():
		sheet.stamp(frames[i], i * FRAME, 0)
	sheet.save(path, SCALE)


func _units() -> void:
	for id in HUMANS:
		var spec: Dictionary = _spec(HUMANS[id])
		var idle: Array[PixelCanvas] = []
		for bob in [0, 0, 1, 1]:
			var c := PixelCanvas.new(FRAME, FRAME)
			SpritePainter.humanoid(c, spec, {"bob": bob})
			idle.append(c)
		var attack: Array[PixelCanvas] = []
		for f in [{"arm": 1, "lean": -1}, {"arm": 2, "lean": 1}, {"arm": 2, "lean": 2, "flash": true}, {"arm": 0}]:
			var c := PixelCanvas.new(FRAME, FRAME)
			SpritePainter.humanoid(c, spec, f)
			attack.append(c)
		var hit: Array[PixelCanvas] = []
		for f in [{"arm": 3, "lean": -2}, {"arm": 3, "lean": -1}, {"arm": 0}]:
			var c := PixelCanvas.new(FRAME, FRAME)
			SpritePainter.humanoid(c, spec, f)
			hit.append(c)
		_write_unit(id, idle, attack, hit)
	for kind in MONSTERS:
		var idle: Array[PixelCanvas] = []
		for p in 4:
			var c := PixelCanvas.new(FRAME, FRAME)
			SpritePainter.monster(c, kind, "idle", p)
			idle.append(c)
		var attack: Array[PixelCanvas] = []
		for p in 3:
			var c := PixelCanvas.new(FRAME, FRAME)
			SpritePainter.monster(c, kind, "attack", p)
			attack.append(c)
		var hit: Array[PixelCanvas] = []
		for p in 2:
			var c := PixelCanvas.new(FRAME, FRAME)
			SpritePainter.monster(c, kind, "hit", p)
			hit.append(c)
		_write_unit(kind, idle, attack, hit)


func _write_unit(id: String, idle: Array[PixelCanvas], attack: Array[PixelCanvas], hit: Array[PixelCanvas]) -> void:
	idle[0].save("%s/units/%s.png" % [OUT, id], SCALE)
	_save_sheet(idle, "%s/units/%s_idle.png" % [OUT, id])
	_save_sheet(attack, "%s/units/%s_attack.png" % [OUT, id])
	_save_sheet(hit, "%s/units/%s_hit.png" % [OUT, id])


func _rooms() -> void:
	for i in ROOM_THEMES.size():
		var theme: String = ROOM_THEMES[i]
		ScenePainter.floor_texture(theme, 100 + i).save("%s/rooms/%s_floor.png" % [OUT, theme])
		ScenePainter.wall_texture(theme, 200 + i).save("%s/rooms/%s_wall.png" % [OUT, theme])
		ScenePainter.tile_texture(theme, false).save("%s/rooms/%s_tile_ally.png" % [OUT, theme])
		ScenePainter.tile_texture(theme, true).save("%s/rooms/%s_tile_enemy.png" % [OUT, theme])


func _props() -> void:
	for kind in PROPS:
		ScenePainter.prop(kind).save("%s/props/%s.png" % [OUT, kind], SCALE)


func _effects() -> void:
	# 화살(원거리 투사체).
	var arrow := PixelCanvas.new(16, 5)
	arrow.hline(0, 12, 2, Color(0.85, 0.8, 0.7))
	arrow.polygon(PackedVector2Array([Vector2(11, 0), Vector2(16, 2.5), Vector2(11, 5)]), Color(0.75, 0.78, 0.85))
	arrow.px(0, 1, Color(0.7, 0.2, 0.2))
	arrow.px(0, 3, Color(0.7, 0.2, 0.2))
	arrow.save("%s/effects/arrow.png" % OUT, SCALE)
	# 그림이 없는 유닛용 실루엣.
	var silhouette := PixelCanvas.new(FRAME, FRAME)
	SpritePainter.humanoid(silhouette, {"skin": Color(0.3, 0.3, 0.35), "hair": Color(0.2, 0.2, 0.25), "coat": Color(0.25, 0.25, 0.3), "eye": Color(0.9, 0.9, 0.9)}, {})
	silhouette.save("%s/effects/placeholder_unit.png" % OUT, SCALE)


func _backgrounds() -> void:
	for kind in BACKGROUNDS:
		ScenePainter.background(kind).save("%s/bg/%s.png" % [OUT, kind])


func _icons() -> void:
	for kind in ICONS:
		ScenePainter.icon(kind, Color.html(ICONS[kind])).save("%s/icons/%s.png" % [OUT, kind], SCALE)


func _portraits() -> void:
	for id in PORTRAITS:
		var image: Image = ScenePainter.portrait(_spec(PORTRAITS[id]))
		DirAccess.make_dir_recursive_absolute("%s/portraits" % OUT)
		image.save_png("%s/portraits/%s.png" % [OUT, id])
