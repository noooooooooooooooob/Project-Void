class_name UnitView
extends Node3D

const SPRITE_HEIGHT: float = 1.6
const ALLY_TINT := Color(0.55, 0.75, 1.0)
const ENEMY_TINT := Color(1.0, 0.55, 0.5)
const FLASH_COLOR := Color(2.0, 2.0, 2.0)
const OVERHEAD_Y: float = 2.0
const HP_BAR_WIDTH: float = 0.9
const HP_BAR_HEIGHT: float = 0.1
const PICK_LAYER_BIT: int = 2
const LUNGE_DISTANCE: float = 0.4
const ACTION_TIME: float = 0.25
const FLASH_TIME: float = 0.24
const POP_TIME: float = 0.6
const FADE_TIME: float = 0.4

var unit: Unit
var home_position: Vector3 = Vector3.ZERO
var sprite: Sprite3D
var name_label: Label3D
var stat_label: Label3D
var hp_back: MeshInstance3D
var hp_fill: MeshInstance3D
var shadow: MeshInstance3D
var pick_body: StaticBody3D
var pick_shape: CollisionShape3D

var _tint: Color = Color.WHITE
var _sprite_home: Vector3 = Vector3.ZERO
var _hp: int = 0
var _max_hp: int = 1
var _block: int = 0


func setup(p_unit: Unit, texture: Texture2D) -> void:
	unit = p_unit
	_tint = ALLY_TINT if unit.is_ally() else ENEMY_TINT

	sprite = Sprite3D.new()
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.pixel_size = SPRITE_HEIGHT / float(texture.get_height())
	_sprite_home = Vector3(0.0, SPRITE_HEIGHT / 2.0, 0.0)
	sprite.position = _sprite_home
	sprite.modulate = _tint
	add_child(sprite)

	shadow = MeshInstance3D.new()
	var shadow_mesh := PlaneMesh.new()
	shadow_mesh.size = Vector2(0.9, 0.5)
	shadow.mesh = shadow_mesh
	shadow.material_override = _shadow_material()
	shadow.position = Vector3(0.0, 0.01, 0.0)
	add_child(shadow)

	name_label = _make_label(unit.data.display_name, 36)
	name_label.position = Vector3(0.0, OVERHEAD_Y + 0.28, 0.0)
	add_child(name_label)

	hp_back = _make_bar(Color(0.1, 0.1, 0.1, 0.85), 0)
	hp_back.position = Vector3(0.0, OVERHEAD_Y, 0.0)
	add_child(hp_back)
	hp_fill = _make_bar(Color(0.35, 0.85, 0.4), 1)
	hp_fill.position = Vector3(0.0, OVERHEAD_Y, 0.0)
	add_child(hp_fill)

	stat_label = _make_label("", 28)
	stat_label.position = Vector3(0.0, OVERHEAD_Y - 0.18, 0.0)
	add_child(stat_label)

	pick_body = StaticBody3D.new()
	pick_body.collision_layer = PICK_LAYER_BIT
	pick_body.collision_mask = 0
	pick_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, SPRITE_HEIGHT, 0.4)
	pick_shape.shape = box
	pick_shape.position = _sprite_home
	pick_body.add_child(pick_shape)
	add_child(pick_body)

	set_stats(unit.hp, unit.data.max_hp, unit.block)


func set_stats(hp: int, max_hp: int, block: int) -> void:
	_hp = hp
	_max_hp = maxi(max_hp, 1)
	_block = block
	_refresh_stats()


func set_hp(hp: int, max_hp: int) -> void:
	_hp = hp
	_max_hp = maxi(max_hp, 1)
	_refresh_stats()


func set_block(block: int) -> void:
	_block = block
	_refresh_stats()


func set_home(world_position: Vector3) -> void:
	home_position = world_position
	position = world_position


func reset_pose() -> void:
	position = home_position
	sprite.position = _sprite_home
	sprite.modulate = _tint
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD


func set_alive(alive: bool) -> void:
	visible = alive
	pick_shape.disabled = not alive


func lunge_toward(world_target: Vector3) -> void:
	var direction: Vector3 = world_target - home_position
	direction.y = 0.0
	if direction.length() > 0.0:
		direction = direction.normalized()
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", home_position + direction * LUNGE_DISTANCE, ACTION_TIME / 2.0)
	tween.tween_property(self, "position", home_position, ACTION_TIME / 2.0)
	await tween.finished


func hop() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "position", _sprite_home + Vector3(0.0, 0.25, 0.0), ACTION_TIME / 2.0)
	tween.tween_property(sprite, "position", _sprite_home, ACTION_TIME / 2.0)
	await tween.finished


func flash_and_shake() -> void:
	var flash: Tween = create_tween()
	for _i in 2:
		flash.tween_property(sprite, "modulate", FLASH_COLOR, FLASH_TIME / 4.0)
		flash.tween_property(sprite, "modulate", _tint, FLASH_TIME / 4.0)
	var shake: Tween = create_tween()
	for offset in [0.08, -0.08, 0.05, 0.0]:
		shake.tween_property(sprite, "position:x", offset, FLASH_TIME / 4.0)
	await flash.finished


# 기다리지 않는다. 숫자가 떠오르는 동안 다음 연출이 겹쳐도 된다.
func pop_text(text: String, color: Color) -> void:
	var label: Label3D = _make_label(text, 64)
	label.modulate = color
	label.position = Vector3(0.0, OVERHEAD_Y + 0.5, 0.0)
	add_child(label)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.6, POP_TIME)
	tween.tween_property(label, "modulate:a", 0.0, POP_TIME)
	tween.tween_property(label, "outline_modulate:a", 0.0, POP_TIME)
	tween.finished.connect(label.queue_free)


func fade_out() -> void:
	pick_shape.disabled = true
	hp_back.visible = false
	hp_fill.visible = false
	shadow.visible = false
	# alpha scissor 는 반투명 픽셀을 잘라내므로 페이드 동안만 끈다.
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, FADE_TIME)
	tween.tween_property(name_label, "modulate:a", 0.0, FADE_TIME)
	tween.tween_property(stat_label, "modulate:a", 0.0, FADE_TIME)
	await tween.finished
	visible = false


func _refresh_stats() -> void:
	stat_label.text = "%d/%d" % [_hp, _max_hp]
	if _block > 0:
		stat_label.text += "  방%d" % _block
	var ratio: float = clampf(float(_hp) / float(_max_hp), 0.0, 1.0)
	(hp_fill.mesh as QuadMesh).size = Vector2(HP_BAR_WIDTH * ratio, HP_BAR_HEIGHT)
	# 카메라가 좌우로 돌지 않으므로 월드 X 가 화면 가로 방향이다.
	hp_fill.position.x = -HP_BAR_WIDTH * (1.0 - ratio) / 2.0
	hp_fill.visible = ratio > 0.0


func _make_label(text: String, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.004
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	label.outline_render_priority = 1
	return label


func _make_bar(color: Color, priority: int) -> MeshInstance3D:
	var bar := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	bar.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.render_priority = priority
	material.albedo_color = color
	bar.material_override = material
	return bar


func _shadow_material() -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.0, 0.0, 0.0, 0.5))
	gradient.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	return material
