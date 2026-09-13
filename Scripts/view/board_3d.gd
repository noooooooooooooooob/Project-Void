class_name Board3D
extends Node3D

signal cell_clicked(team: Unit.Team, cell: Vector2i)

enum TileState { BASE, EMPTY, CURRENT, VALID, INVALID }

const TILE_THICKNESS: float = 0.1
const RAY_LENGTH: float = 100.0
const ALLY_TILE_COLOR := Color(0.36, 0.44, 0.55)
const ENEMY_TILE_COLOR := Color(0.55, 0.38, 0.38)
const CURRENT_EMISSION := Color(1.0, 0.82, 0.3)
const VALID_EMISSION := Color(0.45, 0.85, 0.45)

var layout: BoardLayout
var input_enabled: bool = false

# 키는 Vector3i(team, col, row). 2D 화면 컨트롤러와 같은 규약.
var _tiles: Dictionary = {}
var _tile_states: Dictionary = {}
var _hints: Dictionary = {}
var _views: Dictionary = {}
var _pending_click: Vector2 = Vector2.ZERO
var _has_pending_click: bool = false


func build(state: BattleState, placeholder: Texture2D) -> void:
	layout = BoardLayout.new(state.resolver.ally_grid, state.resolver.enemy_grid)
	_build_side(Unit.Team.ALLY, layout.ally_grid)
	_build_side(Unit.Team.ENEMY, layout.enemy_grid)

	for unit in state.units:
		var view := UnitView.new()
		var texture: Texture2D = unit.data.sprite if unit.data.sprite != null else placeholder
		view.setup(unit, texture)
		view.set_home(layout.cell_position(unit.team, unit.cell))
		_tag(view.pick_body, unit.team, unit.cell)
		add_child(view)
		_views[unit] = view


func sync_from_state(state: BattleState) -> void:
	clear_target_hints()
	for key in _tiles:
		set_tile_state(key.x as Unit.Team, Vector2i(key.y, key.z), TileState.EMPTY)
	for unit in state.units:
		var view: UnitView = _views[unit]
		view.reset_pose()
		view.set_stats(unit.hp, unit.data.max_hp, unit.block)
		view.set_alive(unit.is_alive())
		if unit.is_alive():
			set_tile_state(unit.team, unit.cell, TileState.BASE)
	var actor: Unit = state.current_unit()
	if actor != null and not state.finished and actor.is_alive():
		set_tile_state(actor.team, actor.cell, TileState.CURRENT)


func show_current(unit: Unit) -> void:
	for key in _tile_states:
		if _tile_states[key] == TileState.CURRENT:
			set_tile_state(key.x as Unit.Team, Vector2i(key.y, key.z), TileState.BASE)
	set_tile_state(unit.team, unit.cell, TileState.CURRENT)


func mark_empty(unit: Unit) -> void:
	set_tile_state(unit.team, unit.cell, TileState.EMPTY)


func show_target_hints(hints: Dictionary) -> void:
	clear_target_hints()
	for target in hints:
		var info: Dictionary = hints[target]
		set_tile_state(target.team, target.cell, TileState.VALID if info["valid"] else TileState.INVALID)
		var label: Label3D = hint_label(target.team, target.cell)
		label.text = info["text"]
		label.visible = true


func clear_target_hints() -> void:
	for key in _hints:
		(_hints[key] as Label3D).visible = false
		var current: TileState = _tile_states.get(key, TileState.EMPTY)
		if current == TileState.VALID or current == TileState.INVALID:
			set_tile_state(key.x as Unit.Team, Vector2i(key.y, key.z), TileState.BASE)


func view_for(unit: Unit) -> UnitView:
	return _views.get(unit)


func tile_count() -> int:
	return _tiles.size()


func tile_state(team: Unit.Team, cell: Vector2i) -> TileState:
	return _tile_states[Vector3i(team, cell.x, cell.y)]


func hint_label(team: Unit.Team, cell: Vector2i) -> Label3D:
	return _hints[Vector3i(team, cell.x, cell.y)]


func set_tile_state(team: Unit.Team, cell: Vector2i, new_state: TileState) -> void:
	var key := Vector3i(team, cell.x, cell.y)
	_tile_states[key] = new_state
	var material: StandardMaterial3D = (_tiles[key] as MeshInstance3D).material_override
	var base: Color = ALLY_TILE_COLOR if team == Unit.Team.ALLY else ENEMY_TILE_COLOR
	material.emission_enabled = new_state == TileState.CURRENT or new_state == TileState.VALID
	match new_state:
		TileState.BASE:
			material.albedo_color = base
		TileState.EMPTY:
			material.albedo_color = base.darkened(0.45)
		TileState.CURRENT:
			material.albedo_color = base
			material.emission = CURRENT_EMISSION
			material.emission_energy_multiplier = 0.8
		TileState.VALID:
			material.albedo_color = base
			material.emission = VALID_EMISSION
			material.emission_energy_multiplier = 0.8
		TileState.INVALID:
			material.albedo_color = base.darkened(0.6)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or button.pressed:
		return
	_pending_click = button.position
	_has_pending_click = true
	get_viewport().set_input_as_handled()


# 공간 질의는 물리 스텝 안에서 하는 것이 안전하다.
func _physics_process(_delta: float) -> void:
	if not _has_pending_click:
		return
	_has_pending_click = false
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var from: Vector3 = camera.project_ray_origin(_pending_click)
	var to: Vector3 = from + camera.project_ray_normal(_pending_click) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, UnitView.PICK_LAYER_BIT)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit["collider"]
	cell_clicked.emit(collider.get_meta(&"team"), collider.get_meta(&"cell"))


func _build_side(team: Unit.Team, grid: Vector2i) -> void:
	for row in grid.y:
		for col in grid.x:
			var cell := Vector2i(col, row)
			var key := Vector3i(team, col, row)
			var top: Vector3 = layout.cell_position(team, cell)

			var tile := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(BoardLayout.TILE_SIZE, TILE_THICKNESS, BoardLayout.TILE_SIZE)
			tile.mesh = mesh
			tile.material_override = StandardMaterial3D.new()
			tile.position = top - Vector3(0.0, TILE_THICKNESS / 2.0, 0.0)
			add_child(tile)

			var body := StaticBody3D.new()
			body.collision_layer = UnitView.PICK_LAYER_BIT
			body.collision_mask = 0
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = mesh.size
			shape.shape = box
			body.add_child(shape)
			tile.add_child(body)
			_tag(body, team, cell)

			var hint := Label3D.new()
			hint.font_size = 40
			hint.pixel_size = 0.004
			hint.outline_size = 10
			hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			hint.no_depth_test = true
			hint.render_priority = 2
			hint.outline_render_priority = 1
			hint.position = top + Vector3(0.0, 0.15, BoardLayout.TILE_SIZE / 2.0)
			hint.visible = false
			add_child(hint)

			_tiles[key] = tile
			_hints[key] = hint
			set_tile_state(team, cell, TileState.EMPTY)


func _tag(body: StaticBody3D, team: Unit.Team, cell: Vector2i) -> void:
	body.set_meta(&"team", team)
	body.set_meta(&"cell", cell)
