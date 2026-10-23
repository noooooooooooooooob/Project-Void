# 픽셀 아트(유닛 스프라이트·전투 칸 타일·아이템 아이콘·투사체)를 코드로 그려 Art/gen/ 에 PNG 로 저장한다.
# 실행: Godot --headless --path <프로젝트> --script res://tools/generate_art.gd
# 다시 실행하면 같은 그림을 덮어쓴다 (모든 난수는 시드 고정).
# 배경은 tools/process_backgrounds.gd, 캐릭터 일러스트는 tools/key_portraits.gd 가 만든다 (이 스크립트는 건드리지 않는다).
extends SceneTree

const OUT: String = "res://Art/gen"

## 사람형 유닛 사양.
const HUMANS: Dictionary = {
	"hangyeol": {"skin": "#f0d6c4", "hair": "#1d1b22", "hair_style": "short", "coat": "#2b3350", "coat_dark": "#1c2238", "accent": "#8a8f9a", "pants": "#22232c", "eye": "#8b5cd6", "weapon": "sword", "scarf_tail": true},
	"hongyeon": {"skin": "#f4e1d8", "hair": "#7a1420", "hair_style": "fox", "coat": "#1c1418", "coat_dark": "#0f0a0d", "accent": "#b0142a", "pants": "#1c1418", "eye": "#d01c2c", "weapon": "claws", "small": true, "blush": true},
	"doyun": {"skin": "#e2c0a4", "hair": "#4a3324", "hair_style": "helmet", "helmet": "#6a707c", "coat": "#5d6470", "coat_dark": "#3e434d", "accent": "#d0782c", "pants": "#2c2a28", "eye": "#2a1d14", "weapon": "greatsword"},
	"mira": {"skin": "#f1d3bd", "hair": "#d8b75a", "hair_style": "pony", "coat": "#3e5a46", "coat_dark": "#2a3d30", "accent": "#c9c3a8", "pants": "#2f2b25", "eye": "#3b6a3f", "weapon": "gun"},
	"baekjun": {"skin": "#ead2c0", "hair": "#d9dbe2", "hair_style": "short", "coat": "#2c5c62", "coat_dark": "#1c3d42", "accent": "#a8e0d8", "pants": "#1f2a2c", "eye": "#24464c", "weapon": "staff"},
}
## 괴물 종류.
const MONSTERS: Array[String] = ["rat", "hound", "leech", "husk", "brute", "crown", "hand"]
## 아이템 아이콘.
const ICONS: Dictionary = {
	"weapon": "#b0142a", "armor": "#5d6470", "accessory": "#c9a24a", "card": "#7a4cc2", "gold": "#e0b552", "heart": "#d0303a",
}


func _initialize() -> void:
	var started: int = Time.get_ticks_msec()
	_units()
	_tiles()
	_effects()
	_icons()
	print("art generated in %d ms -> %s" % [Time.get_ticks_msec() - started, OUT])
	quit()


func _spec(raw: Dictionary) -> Dictionary:
	var spec: Dictionary = {}
	for key in raw:
		var value: Variant = raw[key]
		spec[key] = Color.html(value) if value is String and (value as String).begins_with("#") else value
	return spec


## 유닛 프레임 크기 (64×64 로 그리고 그대로 저장).
const UNIT_FRAME: int = 64


func _units() -> void:
	for id in HUMANS:
		var spec: Dictionary = _spec(HUMANS[id])
		var renderer := ShadeRenderer.new()
		FigureBuilder.register_human(renderer, spec)
		var idle: Array[Image] = []
		for bob in [0, 0, 1, 1]:
			idle.append(_render_human(renderer, spec, {"bob": bob}))
		var attack: Array[Image] = []
		for f in [{"arm": 1, "lean": -1}, {"arm": 2, "lean": 2}, {"arm": 2, "lean": 3, "flash": true}, {"arm": 0, "lean": 1}]:
			attack.append(_render_human(renderer, spec, f))
		var hit: Array[Image] = []
		for f in [{"arm": 3, "lean": -3}, {"arm": 3, "lean": -2}, {"arm": 0, "lean": -1}]:
			hit.append(_render_human(renderer, spec, f))
		_write_unit(id, idle, attack, hit)
	for kind in MONSTERS:
		var renderer := ShadeRenderer.new()
		FigureBuilder.register_void(renderer)
		if kind == "husk":
			FigureBuilder.register_human(renderer, {"skin": Color(0.55, 0.56, 0.62), "hair": Color(0.18, 0.18, 0.22), "coat": Color(0.3, 0.3, 0.35), "accent": Color(0.22, 0.16, 0.3), "pants": Color(0.2, 0.2, 0.24)})
		var idle: Array[Image] = []
		for p in 4:
			idle.append(_render_monster(renderer, kind, "idle", p))
		var attack: Array[Image] = []
		for p in 3:
			attack.append(_render_monster(renderer, kind, "attack", p))
		var hit: Array[Image] = []
		for p in 2:
			hit.append(_render_monster(renderer, kind, "hit", p))
		_write_unit(kind, idle, attack, hit)


func _render_human(renderer: ShadeRenderer, spec: Dictionary, frame: Dictionary) -> Image:
	return _finish(renderer, FigureBuilder.human(spec, frame))


func _render_monster(renderer: ShadeRenderer, kind: String, mode: String, phase: int) -> Image:
	var img: Image = _finish(renderer, FigureBuilder.monster(kind, mode, phase))
	if mode == "hit":
		_flash(img, Color(1.0, 0.9, 0.9), 0.3 if phase == 0 else 0.12)
	return img


func _finish(renderer: ShadeRenderer, built: Dictionary) -> Image:
	var img: Image = renderer.render_pixel(built["shapes"], UNIT_FRAME, UNIT_FRAME)
	for d in built["details"]:
		var x: int = d[0]
		var y: int = d[1]
		if x >= 0 and y >= 0 and x < UNIT_FRAME and y < UNIT_FRAME and img.get_pixel(x, y).a > 0.0:
			img.set_pixel(x, y, d[2])
	return img


func _flash(img: Image, tint: Color, amount: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.0:
				var m: Color = c.lerp(tint, amount)
				m.a = c.a
				img.set_pixel(x, y, m)


func _write_unit(id: String, idle: Array[Image], attack: Array[Image], hit: Array[Image]) -> void:
	DirAccess.make_dir_recursive_absolute("%s/units" % OUT)
	idle[0].save_png("%s/units/%s.png" % [OUT, id])
	_sheet(idle).save_png("%s/units/%s_idle.png" % [OUT, id])
	_sheet(attack).save_png("%s/units/%s_attack.png" % [OUT, id])
	_sheet(hit).save_png("%s/units/%s_hit.png" % [OUT, id])


func _sheet(frames: Array[Image]) -> Image:
	var sheet := Image.create(UNIT_FRAME * frames.size(), UNIT_FRAME, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, UNIT_FRAME, UNIT_FRAME), Vector2i(i * UNIT_FRAME, 0))
	return sheet


func _tiles() -> void:
	ScenePainter.tile_texture(false).save("%s/tiles/ally.png" % OUT)
	ScenePainter.tile_texture(true).save("%s/tiles/enemy.png" % OUT)


func _effects() -> void:
	# 화살(원거리 투사체).
	var arrow := PixelCanvas.new(16, 5)
	arrow.hline(0, 12, 2, Color(0.85, 0.8, 0.7))
	arrow.polygon(PackedVector2Array([Vector2(11, 0), Vector2(16, 2.5), Vector2(11, 5)]), Color(0.75, 0.78, 0.85))
	arrow.px(0, 1, Color(0.7, 0.2, 0.2))
	arrow.px(0, 3, Color(0.7, 0.2, 0.2))
	arrow.save("%s/effects/arrow.png" % OUT, 2)
	# 그림이 없는 유닛용 실루엣.
	var renderer := ShadeRenderer.new()
	var spec: Dictionary = {"skin": Color(0.3, 0.3, 0.36), "hair": Color(0.2, 0.2, 0.26), "coat": Color(0.24, 0.24, 0.3), "accent": Color(0.3, 0.3, 0.36), "eye": Color(0.9, 0.9, 0.95), "weapon": "none"}
	FigureBuilder.register_human(renderer, spec)
	_render_human(renderer, spec, {}).save_png("%s/effects/placeholder_unit.png" % OUT)


func _icons() -> void:
	for kind in ICONS:
		ScenePainter.icon(kind, Color.html(ICONS[kind])).save("%s/icons/%s.png" % [OUT, kind], 2)
