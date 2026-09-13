extends TestCase

const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


func run() -> Array[Dictionary]:
	_test_build_creates_tiles_and_views()
	_test_sync_sets_tile_states()
	_test_show_current_moves_highlight()
	_test_target_hints()
	_test_mark_empty()
	return results()


func _texture(height: int) -> Texture2D:
	return ImageTexture.create_from_image(Image.create(10, height, false, Image.FORMAT_RGBA8))


func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


func _enemy(id: StringName) -> EnemyData:
	var data: EnemyData = EnemyDataScript.new()
	data.id = id
	data.display_name = String(id)
	data.max_hp = 20
	data.speed = 1
	return data


# 아군 3x3 에 a(0,1). 적군 2x2 에 e1(0,0), e2(1,0).
func _state(ally_sprite: Texture2D = null) -> BattleState:
	var ally: AllyData = AllyDataScript.new()
	ally.id = &"a"
	ally.display_name = "a"
	ally.max_hp = 30
	ally.speed = 10
	ally.sprite = ally_sprite

	var encounter: EncounterData = EncounterScript.new()
	encounter.ally_grid = Vector2i(3, 3)
	encounter.enemy_grid = Vector2i(2, 2)
	var allies: Array[UnitPlacement] = [_placement(ally, Vector2i(0, 1))]
	var enemies: Array[UnitPlacement] = [
		_placement(_enemy(&"e1"), Vector2i(0, 0)),
		_placement(_enemy(&"e2"), Vector2i(1, 0)),
	]
	encounter.ally_units = allies
	encounter.enemy_units = enemies
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	return BattleState.new(encounter, rng)


func _unit(state: BattleState, id: StringName) -> Unit:
	for unit in state.units:
		if unit.data.id == id:
			return unit
	return null


func _test_build_creates_tiles_and_views() -> void:
	var own_sprite: Texture2D = _texture(40)
	var placeholder: Texture2D = _texture(20)
	var state: BattleState = _state(own_sprite)
	var board := Board3D.new()
	board.build(state, placeholder)
	var ally: Unit = _unit(state, &"a")
	var foe: Unit = _unit(state, &"e1")

	check_eq("one tile per cell on both sides", board.tile_count(), 13)
	check("view placed on its cell", board.view_for(ally).position.is_equal_approx(board.layout.cell_position(Unit.Team.ALLY, Vector2i(0, 1))))
	check("unit sprite wins over placeholder", board.view_for(ally).sprite.texture == own_sprite)
	check("placeholder when no sprite", board.view_for(foe).sprite.texture == placeholder)
	board.free()


func _test_sync_sets_tile_states() -> void:
	var state: BattleState = _state()
	var board := Board3D.new()
	board.build(state, _texture(20))
	state.start_battle()
	var foe: Unit = _unit(state, &"e1")

	board.sync_from_state(state)
	check_eq("current actor tile", board.tile_state(Unit.Team.ALLY, Vector2i(0, 1)), Board3D.TileState.CURRENT)
	check_eq("occupied enemy tile", board.tile_state(Unit.Team.ENEMY, Vector2i(0, 0)), Board3D.TileState.BASE)
	check_eq("empty tile", board.tile_state(Unit.Team.ALLY, Vector2i(2, 2)), Board3D.TileState.EMPTY)

	foe.take_damage(999)
	board.sync_from_state(state)
	check_eq("dead unit's tile is empty", board.tile_state(Unit.Team.ENEMY, Vector2i(0, 0)), Board3D.TileState.EMPTY)
	check("dead unit's view hidden", not board.view_for(foe).visible)
	board.free()


func _test_show_current_moves_highlight() -> void:
	var state: BattleState = _state()
	var board := Board3D.new()
	board.build(state, _texture(20))
	state.start_battle()
	board.sync_from_state(state)

	board.show_current(_unit(state, &"e1"))
	check_eq("new current tile", board.tile_state(Unit.Team.ENEMY, Vector2i(0, 0)), Board3D.TileState.CURRENT)
	check_eq("previous current tile back to base", board.tile_state(Unit.Team.ALLY, Vector2i(0, 1)), Board3D.TileState.BASE)
	board.free()


func _test_target_hints() -> void:
	var state: BattleState = _state()
	var board := Board3D.new()
	board.build(state, _texture(20))
	state.start_battle()
	board.sync_from_state(state)
	var near: Unit = _unit(state, &"e1")
	var far: Unit = _unit(state, &"e2")

	board.show_target_hints({
		near: {"valid": true, "text": "✓ 거리 1"},
		far: {"valid": false, "text": "막힘"},
	})
	check_eq("valid target tile", board.tile_state(Unit.Team.ENEMY, Vector2i(0, 0)), Board3D.TileState.VALID)
	check_eq("invalid target tile", board.tile_state(Unit.Team.ENEMY, Vector2i(1, 0)), Board3D.TileState.INVALID)
	check_eq("hint text", board.hint_label(Unit.Team.ENEMY, Vector2i(1, 0)).text, "막힘")
	check("hint shown", board.hint_label(Unit.Team.ENEMY, Vector2i(0, 0)).visible)

	board.clear_target_hints()
	check_eq("cleared tile back to base", board.tile_state(Unit.Team.ENEMY, Vector2i(0, 0)), Board3D.TileState.BASE)
	check("hint hidden", not board.hint_label(Unit.Team.ENEMY, Vector2i(0, 0)).visible)
	board.free()


func _test_mark_empty() -> void:
	var state: BattleState = _state()
	var board := Board3D.new()
	board.build(state, _texture(20))
	board.sync_from_state(state)

	board.mark_empty(_unit(state, &"e2"))
	check_eq("marked tile is empty", board.tile_state(Unit.Team.ENEMY, Vector2i(1, 0)), Board3D.TileState.EMPTY)
	board.free()
