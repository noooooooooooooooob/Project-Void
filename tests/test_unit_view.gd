extends TestCase

const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")


func run() -> Array[Dictionary]:
	_test_setup_builds_parts()
	_test_stats_text_and_bar()
	_test_partial_updates()
	_test_home_and_alive()
	return results()


func _texture() -> Texture2D:
	return ImageTexture.create_from_image(Image.create(10, 20, false, Image.FORMAT_RGBA8))


func _view(ally: bool) -> UnitView:
	var data: UnitData = AllyDataScript.new() if ally else EnemyDataScript.new()
	data.id = &"tester"
	data.display_name = "테스터"
	data.max_hp = 30
	var team: Unit.Team = Unit.Team.ALLY if ally else Unit.Team.ENEMY
	var view := UnitView.new()
	view.setup(Unit.new(0, data, team, Vector2i(0, 1)), _texture())
	return view


func _test_setup_builds_parts() -> void:
	var texture: Texture2D = _texture()
	var data: AllyData = AllyDataScript.new()
	data.display_name = "테스터"
	data.max_hp = 30
	var view := UnitView.new()
	view.setup(Unit.new(0, data, Unit.Team.ALLY, Vector2i(0, 1)), texture)
	check("sprite uses the given texture", view.sprite.texture == texture)
	check_eq("name label", view.name_label.text, "테스터")
	check("sprite is scaled to the unit height", is_equal_approx(view.sprite.pixel_size, UnitView.SPRITE_HEIGHT / 20.0))
	check_eq("pick body on the board pick layer", view.pick_body.collision_layer, UnitView.PICK_LAYER_BIT)
	check_eq("ally tint", view.sprite.modulate, UnitView.ALLY_TINT)
	view.free()

	var enemy: UnitView = _view(false)
	check_eq("enemy tint", enemy.sprite.modulate, UnitView.ENEMY_TINT)
	enemy.free()


func _test_stats_text_and_bar() -> void:
	var view: UnitView = _view(true)
	view.set_stats(12, 30, 6)
	check_eq("hp and block text", view.stat_label.text, "12/30  방6")
	check("fill width is the hp ratio", is_equal_approx((view.hp_fill.mesh as QuadMesh).size.x, 0.36))
	check("fill is anchored left", is_equal_approx(view.hp_fill.position.x, -0.27))

	view.set_stats(30, 30, 0)
	check_eq("no block text when zero", view.stat_label.text, "30/30")
	check("full bar is centred", is_equal_approx(view.hp_fill.position.x, 0.0))
	view.free()


func _test_partial_updates() -> void:
	var view: UnitView = _view(true)
	view.set_hp(10, 30)
	view.set_block(4)
	check_eq("hp and block update separately", view.stat_label.text, "10/30  방4")
	view.set_hp(0, 30)
	check("empty bar is hidden", not view.hp_fill.visible)
	view.free()


func _test_home_and_alive() -> void:
	var view: UnitView = _view(true)
	view.set_home(Vector3(1.0, 0.0, 2.0))
	check_eq("placed at home", view.position, Vector3(1.0, 0.0, 2.0))
	check_eq("home remembered", view.home_position, Vector3(1.0, 0.0, 2.0))
	view.set_alive(false)
	check("dead view hidden", not view.visible)
	check("dead view not pickable", view.pick_shape.disabled)
	view.free()
