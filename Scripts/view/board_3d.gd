## 2.5D 전투 보드: 양쪽 격자 타일, 유닛 화면 객체(UnitView), 타일 위 사거리 힌트 글자를 만들고 관리한다.
## 마우스 클릭을 3D 광선으로 바꿔 어떤 칸이 눌렸는지 알려 준다 (cell_clicked / pick_missed).
## 규칙 상태는 바꾸지 않는다 — BattleRoot 가 신호를 받아 규칙을 호출한다.
class_name Board3D
# Node3D: 3D 공간에 위치를 가지는 노드.
extends Node3D

## 칸을 클릭했다 (타일이나 그 칸의 유닛을 눌렀을 때). team 은 그 칸의 편, cell 은 칸 좌표.
signal cell_clicked(team: Unit.Team, cell: Vector2i)
## 클릭(또는 request_pick)했지만 아무 칸도 맞지 않았다.
signal pick_missed

## 타일 모습 상태.
## BASE 유닛이 있는 기본, EMPTY 빈 칸(어둡게), CURRENT 지금 차례(노란 빛), VALID 칠 수 있음(초록 빛), INVALID 칠 수 없음(더 어둡게),
## MOVABLE 이동할 수 있는 빈 칸(파란 빛).
enum TileState { BASE, EMPTY, CURRENT, VALID, INVALID, MOVABLE }

## 타일 두께.
const TILE_THICKNESS: float = 0.1
## 클릭 광선의 최대 길이.
const RAY_LENGTH: float = 100.0
## 아군 타일 기본 색.
const ALLY_TILE_COLOR := Color(0.36, 0.44, 0.55)
## 적군 타일 기본 색.
const ENEMY_TILE_COLOR := Color(0.55, 0.38, 0.38)
## 지금 차례 타일이 내는 빛 색.
const CURRENT_EMISSION := Color(1.0, 0.82, 0.3)
## 칠 수 있는 대상 타일이 내는 빛 색.
const VALID_EMISSION := Color(0.45, 0.85, 0.45)
## 이동할 수 있는 타일이 내는 빛 색.
const MOVE_EMISSION := Color(0.45, 0.65, 1.0)

## 칸 좌표 ↔ 3D 위치 계산기 (build 에서 만든다).
var layout: BoardLayout
## false 면 마우스 클릭을 무시한다 (연출 재생 중 잠금).
var input_enabled: bool = false

# 키는 Vector3i(team, col, row).
## 칸별 타일 메시.
var _tiles: Dictionary = {}
## 칸별 현재 타일 상태 (TileState).
var _tile_states: Dictionary = {}
## 칸별 힌트 글자 (Label3D).
var _hints: Dictionary = {}
## 규칙 유닛(Unit) → 화면 객체(UnitView).
var _views: Dictionary = {}
## 다음 물리 스텝에서 판정할 화면 좌표.
var _pending_click: Vector2 = Vector2.ZERO
## 판정 대기 중인 클릭이 있으면 true.
var _has_pending_click: bool = false


## 전투 상태를 보고 타일과 유닛 화면 객체를 모두 만든다 (전투 시작 시 한 번).
func build(state: BattleState, placeholder: Texture2D) -> void:
	# 규칙의 격자 크기로 위치 계산기를 만든다.
	layout = BoardLayout.new(state.resolver.ally_grid, state.resolver.enemy_grid)
	# 아군 쪽 타일을 만든다.
	_build_side(Unit.Team.ALLY, layout.ally_grid)
	# 적군 쪽 타일을 만든다.
	_build_side(Unit.Team.ENEMY, layout.enemy_grid)

	# 유닛마다 화면 객체를 만든다.
	for unit in state.units:
		# 새 유닛 화면 객체.
		var view := UnitView.new()
		# 유닛 그림이 없으면 임시 그림을 쓴다.
		var texture: Texture2D = unit.data.sprite if unit.data.sprite != null else placeholder
		# 스프라이트·체력 바 등 자식을 만든다.
		view.setup(unit, texture)
		# 유닛이 선 칸 위치로 옮기고 그 위치를 원래 자리로 기억한다.
		view.set_home(layout.cell_position(unit.team, unit.cell))
		# 유닛 클릭 몸체에 편과 칸 정보를 붙인다 (유닛을 눌러도 칸 클릭으로 처리됨).
		_tag(view.pick_body, unit.team, unit.cell)
		# 보드의 자식으로 붙인다.
		add_child(view)
		# 나중에 찾을 수 있게 사전에 넣는다.
		_views[unit] = view


## 연출과 상관없이 규칙 상태 그대로 보드를 맞춘다 (재생이 끝난 뒤 어긋남 보정용).
func sync_from_state(state: BattleState) -> void:
	# 남아 있는 사거리 힌트를 지운다.
	clear_target_hints()
	# 우선 모든 타일을 빈 칸으로 만든다.
	for key in _tiles:
		# 키 Vector3i(team, col, row) 를 편과 칸 좌표로 풀어 넘긴다.
		set_tile_state(key.x as Unit.Team, Vector2i(key.y, key.z), TileState.EMPTY)
	# 유닛마다 표시를 규칙 값으로 맞춘다.
	for unit in state.units:
		# 그 유닛의 화면 객체.
		var view: UnitView = _views[unit]
		# 규칙의 현재 칸 위치를 원래 자리로 삼는다 (이동 연출이 어긋나도 실제 상태로 맞춘다).
		view.set_home(layout.cell_position(unit.team, unit.cell))
		# 클릭 칸 정보도 현재 칸으로 다시 붙인다.
		_tag(view.pick_body, unit.team, unit.cell)
		# 끊긴 연출 자세를 되돌린다.
		view.reset_pose()
		# 체력·방어도를 규칙 값으로.
		view.set_stats(unit.hp, unit.data.max_hp, unit.block)
		# 생존 여부에 맞춰 보이기·클릭 판정을 켠다/끈다.
		view.set_alive(unit.is_alive())
		# 살아 있는 유닛의 칸은 기본 타일로 되돌린다.
		if unit.is_alive():
			set_tile_state(unit.team, unit.cell, TileState.BASE)
	# 지금 차례인 유닛.
	var actor: Unit = state.current_unit()
	# 전투가 진행 중이고 차례인 유닛이 살아 있으면 그 칸을 강조한다.
	if actor != null and not state.finished and actor.is_alive():
		set_tile_state(actor.team, actor.cell, TileState.CURRENT)


## 지금 차례 강조를 이 유닛의 칸으로 옮긴다.
func show_current(unit: Unit) -> void:
	# 기존에 강조된 칸을 찾는다.
	for key in _tile_states:
		# 강조 상태인 칸이면 기본으로 되돌린다.
		if _tile_states[key] == TileState.CURRENT:
			set_tile_state(key.x as Unit.Team, Vector2i(key.y, key.z), TileState.BASE)
	# 새 유닛의 칸을 강조한다.
	set_tile_state(unit.team, unit.cell, TileState.CURRENT)


## 유닛이 쓰러진 칸을 빈 칸 모습으로 바꾼다.
func mark_empty(unit: Unit) -> void:
	# 그 칸을 EMPTY 로.
	set_tile_state(unit.team, unit.cell, TileState.EMPTY)


## 카드를 골랐을 때 대상 후보 칸마다 칠 수 있는지 색과 글자로 보여 준다.
## hints: Unit → {"valid": bool, "text": String} (BattleRoot 가 만들어 준다).
func show_target_hints(hints: Dictionary) -> void:
	# 이전 힌트를 먼저 지운다.
	clear_target_hints()
	# 대상 후보마다.
	for target in hints:
		# 그 후보의 힌트 정보.
		var info: Dictionary = hints[target]
		# 칠 수 있으면 초록 빛, 없으면 어둡게.
		set_tile_state(target.team, target.cell, TileState.VALID if info["valid"] else TileState.INVALID)
		# 그 칸의 힌트 글자.
		var label: Label3D = hint_label(target.team, target.cell)
		# "✓ 거리 2", "거리 4", "막힘" 같은 문장을 넣는다.
		label.text = info["text"]
		# 보이게 한다.
		label.visible = true


## 사거리 힌트(글자와 초록/어두운 타일)와 이동 힌트(파란 타일)를 모두 지운다.
func clear_target_hints() -> void:
	# 모든 칸의 힌트를 확인한다.
	for key in _hints:
		# 글자를 숨긴다.
		(_hints[key] as Label3D).visible = false
		# 그 칸의 현재 타일 상태 (없으면 EMPTY 로 본다).
		var current: TileState = _tile_states.get(key, TileState.EMPTY)
		# 사거리 힌트 때문에 바뀐 상태였으면 기본으로 되돌린다 (강조·빈 칸은 그대로).
		if current == TileState.VALID or current == TileState.INVALID:
			set_tile_state(key.x as Unit.Team, Vector2i(key.y, key.z), TileState.BASE)
		# 이동 힌트는 유닛이 없는 칸이므로 빈 칸으로 되돌린다.
		elif current == TileState.MOVABLE:
			set_tile_state(key.x as Unit.Team, Vector2i(key.y, key.z), TileState.EMPTY)


## 이동할 수 있는 칸들을 파란 빛으로 표시한다 (이전 힌트는 먼저 지운다).
func show_move_hints(team: Unit.Team, cells: Array[Vector2i]) -> void:
	# 이전 힌트를 지운다.
	clear_target_hints()
	# 칸마다.
	for cell in cells:
		# 이동 가능 상태로 칠한다.
		set_tile_state(team, cell, TileState.MOVABLE)


## 유닛 화면을 from_cell 에서 to_cell 로 옮긴다. 타일 강조와 클릭 칸 정보도 함께 옮긴다.
## animate 가 true 면 미끄러짐이 끝날 때까지 await 할 수 있다.
func move_view(unit: Unit, from_cell: Vector2i, to_cell: Vector2i, animate: bool) -> void:
	# 원래 칸은 빈 칸으로.
	set_tile_state(unit.team, from_cell, TileState.EMPTY)
	# 새 칸은 지금 차례 강조로 (이동은 자기 차례에만 일어난다).
	set_tile_state(unit.team, to_cell, TileState.CURRENT)
	# 유닛 화면.
	var view: UnitView = view_for(unit)
	# 클릭하면 새 칸으로 판정되게 칸 정보를 바꾼다.
	_tag(view.pick_body, unit.team, to_cell)
	# 새 칸의 3D 위치.
	var target: Vector3 = layout.cell_position(unit.team, to_cell)
	# 연출이 있으면 미끄러진다.
	if animate:
		await view.slide_to(target)
	# 없으면 즉시 옮긴다.
	else:
		view.set_home(target)


## 규칙 유닛에 대응하는 화면 객체를 찾는다. 없으면 null.
func view_for(unit: Unit) -> UnitView:
	# 사전에서 꺼낸다.
	return _views.get(unit)


## 만든 타일 수 (테스트용).
func tile_count() -> int:
	# 타일 사전의 크기.
	return _tiles.size()


## 칸의 현재 타일 상태를 돌려준다.
func tile_state(team: Unit.Team, cell: Vector2i) -> TileState:
	# (편, 열, 행) 키로 찾는다.
	return _tile_states[Vector3i(team, cell.x, cell.y)]


## 칸의 힌트 글자 노드를 돌려준다.
func hint_label(team: Unit.Team, cell: Vector2i) -> Label3D:
	# (편, 열, 행) 키로 찾는다.
	return _hints[Vector3i(team, cell.x, cell.y)]


## 칸의 타일 상태를 바꾸고 재질 색·빛을 그에 맞게 칠한다.
func set_tile_state(team: Unit.Team, cell: Vector2i, new_state: TileState) -> void:
	# 사전 키를 만든다.
	var key := Vector3i(team, cell.x, cell.y)
	# 새 상태를 기억한다.
	_tile_states[key] = new_state
	# 타일마다 따로 만든 재질을 꺼낸다 (공유 재질이 아니라 한 칸만 바뀐다).
	var material: StandardMaterial3D = (_tiles[key] as MeshInstance3D).material_override
	# 편에 따른 기본 색.
	var base: Color = ALLY_TILE_COLOR if team == Unit.Team.ALLY else ENEMY_TILE_COLOR
	# 강조·유효·이동 가능 상태일 때만 스스로 빛나게 한다.
	material.emission_enabled = new_state == TileState.CURRENT or new_state == TileState.VALID or new_state == TileState.MOVABLE
	# 상태별로 색을 정한다.
	match new_state:
		# 기본: 편 색 그대로.
		TileState.BASE:
			material.albedo_color = base
		# 빈 칸: 45% 어둡게.
		TileState.EMPTY:
			material.albedo_color = base.darkened(0.45)
		# 지금 차례: 편 색 + 노란 빛.
		TileState.CURRENT:
			# 바탕은 편 색.
			material.albedo_color = base
			# 빛 색을 노랗게.
			material.emission = CURRENT_EMISSION
			# 빛 세기.
			material.emission_energy_multiplier = 0.8
		# 칠 수 있음: 편 색 + 초록 빛.
		TileState.VALID:
			# 바탕은 편 색.
			material.albedo_color = base
			# 빛 색을 초록으로.
			material.emission = VALID_EMISSION
			# 빛 세기.
			material.emission_energy_multiplier = 0.8
		# 칠 수 없음: 60% 어둡게.
		TileState.INVALID:
			material.albedo_color = base.darkened(0.6)
		# 이동 가능: 편 색 + 파란 빛.
		TileState.MOVABLE:
			# 바탕은 편 색.
			material.albedo_color = base
			# 빛 색을 파랗게.
			material.emission = MOVE_EMISSION
			# 빛 세기.
			material.emission_energy_multiplier = 0.6


# 드래그로 놓은 카드처럼 마우스 이벤트가 보드에 오지 않는 경우에도 같은 판정 경로를 쓴다.
## 화면 좌표 하나를 다음 물리 스텝에서 클릭처럼 판정하도록 예약한다.
func request_pick(screen_position: Vector2) -> void:
	# 판정할 좌표를 기억한다.
	_pending_click = screen_position
	# 대기 표시를 켠다.
	_has_pending_click = true


## GUI 가 처리하지 않고 넘긴 입력을 받는다. 왼쪽 버튼을 뗄 때 클릭으로 예약한다.
func _unhandled_input(event: InputEvent) -> void:
	# 잠겨 있으면 무시한다.
	if not input_enabled:
		return
	# 마우스 버튼 이벤트로 형 변환한다 (아니면 null).
	var button := event as InputEventMouseButton
	# 마우스 버튼이 아니거나, 왼쪽 버튼이 아니거나, 누르는 순간이면 무시한다 (떼는 순간만 클릭).
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or button.pressed:
		return
	# 클릭 위치를 기억한다.
	_pending_click = button.position
	# 대기 표시를 켠다.
	_has_pending_click = true
	# 이 입력을 처리했다고 알려 다른 노드로 더 전달되지 않게 한다.
	get_viewport().set_input_as_handled()


# 공간 질의는 물리 스텝 안에서 하는 것이 안전하다.
## 예약된 클릭이 있으면 카메라에서 광선을 쏴 맞은 칸을 찾아 신호를 낸다.
func _physics_process(_delta: float) -> void:
	# 대기 중인 클릭이 없으면 할 일이 없다.
	if not _has_pending_click:
		return
	# 한 번만 처리하도록 대기 표시를 끈다.
	_has_pending_click = false
	# 현재 화면을 비추는 3D 카메라.
	var camera: Camera3D = get_viewport().get_camera_3d()
	# 카메라가 없으면 광선을 쏠 수 없으므로 빗나감으로 처리한다.
	if camera == null:
		pick_missed.emit()
		return
	# 화면 좌표에 해당하는 광선의 시작점 (카메라 위치).
	var from: Vector3 = camera.project_ray_origin(_pending_click)
	# 광선 방향으로 RAY_LENGTH 만큼 간 끝점.
	var to: Vector3 = from + camera.project_ray_normal(_pending_click) * RAY_LENGTH
	# 클릭 판정 레이어만 맞히는 광선 질의를 만든다.
	var query := PhysicsRayQueryParameters3D.create(from, to, UnitView.PICK_LAYER_BIT)
	# 물리 공간에 광선을 쏴서 가장 먼저 맞은 물체를 얻는다.
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	# 아무것도 안 맞았으면 빗나감.
	if hit.is_empty():
		pick_missed.emit()
		return
	# 맞은 물리 몸체.
	var collider: Object = hit["collider"]
	# 몸체에 붙여 둔 편·칸 정보로 칸 클릭 신호를 낸다.
	cell_clicked.emit(collider.get_meta(&"team"), collider.get_meta(&"cell"))


## 한 편의 격자 타일, 타일 클릭 몸체, 힌트 글자를 칸마다 만든다.
func _build_side(team: Unit.Team, grid: Vector2i) -> void:
	# 행마다.
	for row in grid.y:
		# 열마다.
		for col in grid.x:
			# 칸 좌표.
			var cell := Vector2i(col, row)
			# 사전 키.
			var key := Vector3i(team, col, row)
			# 칸 중심의 바닥 위치 (타일 윗면 높이 0).
			var top: Vector3 = layout.cell_position(team, cell)

			# --- 타일 메시 ---
			# 메시 노드를 만든다.
			var tile := MeshInstance3D.new()
			# 납작한 상자 메시.
			var mesh := BoxMesh.new()
			# 가로·세로 TILE_SIZE, 두께 TILE_THICKNESS.
			mesh.size = Vector3(BoardLayout.TILE_SIZE, TILE_THICKNESS, BoardLayout.TILE_SIZE)
			# 메시를 넣는다.
			tile.mesh = mesh
			# 칸마다 따로 색을 바꿀 수 있게 새 재질을 만든다.
			tile.material_override = StandardMaterial3D.new()
			# 윗면이 높이 0 에 오도록 두께 절반만큼 내린다.
			tile.position = top - Vector3(0.0, TILE_THICKNESS / 2.0, 0.0)
			# 보드에 붙인다.
			add_child(tile)

			# --- 타일 클릭 몸체 ---
			# 움직이지 않는 물리 몸체.
			var body := StaticBody3D.new()
			# 클릭 판정 레이어에 올린다.
			body.collision_layer = UnitView.PICK_LAYER_BIT
			# 다른 물체와 부딪히지 않는다.
			body.collision_mask = 0
			# 충돌 모양 노드.
			var shape := CollisionShape3D.new()
			# 타일과 같은 크기의 상자.
			var box := BoxShape3D.new()
			# 메시 크기를 그대로 쓴다.
			box.size = mesh.size
			# 모양을 넣는다.
			shape.shape = box
			# 모양을 몸체에 붙인다.
			body.add_child(shape)
			# 몸체를 타일에 붙인다 (타일 위치를 따라간다).
			tile.add_child(body)
			# 몸체에 편·칸 정보를 붙인다.
			_tag(body, team, cell)

			# --- 힌트 글자 ---
			# 3D 글자 노드를 만든다.
			var hint := Label3D.new()
			# 글꼴 크기.
			hint.font_size = 40
			# 픽셀 하나의 3D 크기.
			hint.pixel_size = 0.004
			# 외곽선 두께.
			hint.outline_size = 10
			# 항상 카메라를 향한다.
			hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			# 가려지지 않고 항상 위에 그린다.
			hint.no_depth_test = true
			# 체력 바보다 위에 그린다.
			hint.render_priority = 2
			# 외곽선은 글자보다 먼저.
			hint.outline_render_priority = 1
			# 유닛 머리 위(이름보다 위)에 놓아 앞줄 유닛의 클릭을 가리지 않게 한다.
			hint.position = top + Vector3(0.0, UnitView.OVERHEAD_Y + 0.6, 0.0)
			# 처음에는 숨긴다.
			hint.visible = false
			# 보드에 붙인다.
			add_child(hint)

			# 타일을 사전에 넣는다.
			_tiles[key] = tile
			# 힌트 글자를 사전에 넣는다.
			_hints[key] = hint
			# 처음에는 빈 칸 모습으로 칠한다 (유닛이 있으면 sync_from_state 가 바꾼다).
			set_tile_state(team, cell, TileState.EMPTY)


## 물리 몸체에 편·칸 정보를 메타데이터로 붙인다 (광선이 맞으면 이 정보로 칸을 알아낸다).
func _tag(body: StaticBody3D, team: Unit.Team, cell: Vector2i) -> void:
	# 편.
	body.set_meta(&"team", team)
	# 칸 좌표.
	body.set_meta(&"cell", cell)
