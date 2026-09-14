# Board3D(3D 보드) 테스트: 타일·유닛 화면 만들기, 상태 동기화, 차례 강조, 사거리 힌트, 빈 칸 표시.
# 보드를 트리에 붙이지 않으므로 클릭 광선은 검사하지 않는다.
extends TestCase

# 아군 데이터 스크립트.
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
# 적 데이터 스크립트.
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
# 배치 데이터 스크립트.
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
# 전투 구성 스크립트.
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 타일과 유닛 화면 생성.
	_test_build_creates_tiles_and_views()
	# 규칙 상태로 타일 상태 맞추기.
	_test_sync_sets_tile_states()
	# 차례 강조 옮기기.
	_test_show_current_moves_highlight()
	# 사거리 힌트 보이기·지우기.
	_test_target_hints()
	# 빈 칸 표시.
	_test_mark_empty()
	# 결과를 돌려준다.
	return results()


# 폭 10, 높이 height 인 빈 텍스처 (서로 다른 텍스처를 구분하기 위해 높이를 바꿔 쓴다).
func _texture(height: int) -> Texture2D:
	# 빈 이미지로 텍스처를 만든다.
	return ImageTexture.create_from_image(Image.create(10, height, false, Image.FORMAT_RGBA8))


# 데이터와 칸으로 배치 한 줄을 만든다.
func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	# 배치 리소스.
	var placement: UnitPlacement = PlacementScript.new()
	# 유닛 데이터.
	placement.unit_data = data
	# 칸.
	placement.cell = cell
	# 돌려준다.
	return placement


# id 만 정한 느린 적 데이터 (그림 없음).
func _enemy(id: StringName) -> EnemyData:
	# 적 데이터.
	var data: EnemyData = EnemyDataScript.new()
	# id.
	data.id = id
	# 이름.
	data.display_name = String(id)
	# 최대 체력.
	data.max_hp = 20
	# 아군보다 느리게.
	data.speed = 1
	# 돌려준다.
	return data


# 아군 3x3 에 a(0,1). 적군 2x2 에 e1(0,0), e2(1,0).
# ally_sprite 를 주면 아군 데이터에 그림으로 넣는다.
func _state(ally_sprite: Texture2D = null) -> BattleState:
	# 아군 데이터.
	var ally: AllyData = AllyDataScript.new()
	# id.
	ally.id = &"a"
	# 이름.
	ally.display_name = "a"
	# 최대 체력.
	ally.max_hp = 30
	# 적보다 빠르게.
	ally.speed = 10
	# 그림 (없으면 null).
	ally.sprite = ally_sprite

	# 전투 구성.
	var encounter: EncounterData = EncounterScript.new()
	# 아군 격자 3×3.
	encounter.ally_grid = Vector2i(3, 3)
	# 적군 격자 2×2.
	encounter.enemy_grid = Vector2i(2, 2)
	# 아군 배치.
	var allies: Array[UnitPlacement] = [_placement(ally, Vector2i(0, 1))]
	# 적 배치: e1 앞줄, e2 뒷줄 (같은 0 행).
	var enemies: Array[UnitPlacement] = [
		_placement(_enemy(&"e1"), Vector2i(0, 0)),
		_placement(_enemy(&"e2"), Vector2i(1, 0)),
	]
	# 아군 배치 넣기.
	encounter.ally_units = allies
	# 적 배치 넣기.
	encounter.enemy_units = enemies
	# 난수 생성기.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = 5
	# 전투 상태를 만든다.
	return BattleState.new(encounter, rng)


# id 로 전투 속 유닛을 찾는다.
func _unit(state: BattleState, id: StringName) -> Unit:
	# 모든 유닛 중.
	for unit in state.units:
		# id 가 같으면.
		if unit.data.id == id:
			# 그 유닛.
			return unit
	# 못 찾음.
	return null


# 타일이 칸마다 하나씩(9 + 4 = 13) 생기고, 유닛 화면이 제 칸에 놓이며, 자기 그림이 없을 때만 임시 그림을 쓰는지.
func _test_build_creates_tiles_and_views() -> void:
	# 아군 전용 그림 (높이 40).
	var own_sprite: Texture2D = _texture(40)
	# 임시 그림 (높이 20).
	var placeholder: Texture2D = _texture(20)
	# 아군에게만 그림이 있는 전투.
	var state: BattleState = _state(own_sprite)
	# 보드.
	var board := Board3D.new()
	# 만든다.
	board.build(state, placeholder)
	# 아군 유닛.
	var ally: Unit = _unit(state, &"a")
	# 적 유닛.
	var foe: Unit = _unit(state, &"e1")

	# 타일 13 개.
	check_eq("one tile per cell on both sides", board.tile_count(), 13)
	# 아군 화면이 (0,1) 칸 위치에.
	check("view placed on its cell", board.view_for(ally).position.is_equal_approx(board.layout.cell_position(Unit.Team.ALLY, Vector2i(0, 1))))
	# 아군은 자기 그림.
	check("unit sprite wins over placeholder", board.view_for(ally).sprite.texture == own_sprite)
	# 적은 임시 그림.
	check("placeholder when no sprite", board.view_for(foe).sprite.texture == placeholder)
	# 지운다.
	board.free()


# 동기화 후 차례 유닛 칸은 CURRENT, 유닛이 선 칸은 BASE, 빈 칸은 EMPTY 이고, 쓰러지면 EMPTY·숨김이 되는지.
func _test_sync_sets_tile_states() -> void:
	# 전투.
	var state: BattleState = _state()
	# 보드.
	var board := Board3D.new()
	# 만든다.
	board.build(state, _texture(20))
	# 시작 (아군 차례).
	state.start_battle()
	# 적 e1.
	var foe: Unit = _unit(state, &"e1")

	# 동기화.
	board.sync_from_state(state)
	# 아군 칸은 강조.
	check_eq("current actor tile", board.tile_state(Unit.Team.ALLY, Vector2i(0, 1)), Board3D.TileState.CURRENT)
	# 적이 선 칸은 기본.
	check_eq("occupied enemy tile", board.tile_state(Unit.Team.ENEMY, Vector2i(0, 0)), Board3D.TileState.BASE)
	# 아무도 없는 칸은 빈 칸.
	check_eq("empty tile", board.tile_state(Unit.Team.ALLY, Vector2i(2, 2)), Board3D.TileState.EMPTY)

	# e1 을 쓰러뜨린다.
	foe.take_damage(999)
	# 다시 동기화.
	board.sync_from_state(state)
	# e1 칸은 빈 칸.
	check_eq("dead unit's tile is empty", board.tile_state(Unit.Team.ENEMY, Vector2i(0, 0)), Board3D.TileState.EMPTY)
	# e1 화면은 숨김.
	check("dead unit's view hidden", not board.view_for(foe).visible)
	# 지운다.
	board.free()


# show_current 로 강조를 적 칸으로 옮기면 이전 아군 칸은 기본으로 돌아가는지.
func _test_show_current_moves_highlight() -> void:
	# 전투.
	var state: BattleState = _state()
	# 보드.
	var board := Board3D.new()
	# 만든다.
	board.build(state, _texture(20))
	# 시작.
	state.start_battle()
	# 동기화 (아군 칸 강조).
	board.sync_from_state(state)

	# e1 으로 강조를 옮긴다.
	board.show_current(_unit(state, &"e1"))
	# e1 칸 강조.
	check_eq("new current tile", board.tile_state(Unit.Team.ENEMY, Vector2i(0, 0)), Board3D.TileState.CURRENT)
	# 아군 칸은 기본으로.
	check_eq("previous current tile back to base", board.tile_state(Unit.Team.ALLY, Vector2i(0, 1)), Board3D.TileState.BASE)
	# 지운다.
	board.free()


# 힌트를 주면 유효/무효 타일 상태와 글자가 보이고, 지우면 기본 상태·숨김으로 돌아가는지.
func _test_target_hints() -> void:
	# 전투.
	var state: BattleState = _state()
	# 보드.
	var board := Board3D.new()
	# 만든다.
	board.build(state, _texture(20))
	# 시작.
	state.start_battle()
	# 동기화.
	board.sync_from_state(state)
	# 칠 수 있는 적.
	var near: Unit = _unit(state, &"e1")
	# 막힌 적.
	var far: Unit = _unit(state, &"e2")

	# 두 적에 대한 힌트를 보여 준다.
	board.show_target_hints({
		near: {"valid": true, "text": "✓ 거리 1"},
		far: {"valid": false, "text": "막힘"},
	})
	# e1 칸 유효.
	check_eq("valid target tile", board.tile_state(Unit.Team.ENEMY, Vector2i(0, 0)), Board3D.TileState.VALID)
	# e2 칸 무효.
	check_eq("invalid target tile", board.tile_state(Unit.Team.ENEMY, Vector2i(1, 0)), Board3D.TileState.INVALID)
	# e2 칸 글자.
	check_eq("hint text", board.hint_label(Unit.Team.ENEMY, Vector2i(1, 0)).text, "막힘")
	# e1 칸 글자 보임.
	check("hint shown", board.hint_label(Unit.Team.ENEMY, Vector2i(0, 0)).visible)

	# 힌트를 지운다.
	board.clear_target_hints()
	# 기본으로 돌아왔다.
	check_eq("cleared tile back to base", board.tile_state(Unit.Team.ENEMY, Vector2i(0, 0)), Board3D.TileState.BASE)
	# 글자 숨김.
	check("hint hidden", not board.hint_label(Unit.Team.ENEMY, Vector2i(0, 0)).visible)
	# 지운다.
	board.free()


# mark_empty 가 유닛 칸을 빈 칸으로 바꾸는지.
func _test_mark_empty() -> void:
	# 전투.
	var state: BattleState = _state()
	# 보드.
	var board := Board3D.new()
	# 만든다.
	board.build(state, _texture(20))
	# 동기화 (e2 칸은 기본).
	board.sync_from_state(state)

	# e2 칸을 빈 칸으로.
	board.mark_empty(_unit(state, &"e2"))
	# 빈 칸.
	check_eq("marked tile is empty", board.tile_state(Unit.Team.ENEMY, Vector2i(1, 0)), Board3D.TileState.EMPTY)
	# 지운다.
	board.free()
