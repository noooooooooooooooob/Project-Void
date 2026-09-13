extends Node3D

const PLACEHOLDER_SPRITE: Texture2D = preload("res://Resources/sprites/placeholder_unit.png")
const CAMERA_PITCH_DEG: float = 44.0
const CAMERA_FOV_DEG: float = 40.0
const CAMERA_MARGIN: float = 1.8
# 아래쪽 HUD 에 보드가 가리지 않게 바라보는 점을 카메라 쪽으로 당긴다.
const CAMERA_TARGET_OFFSET := Vector3(0.0, 0.0, 0.6)

@export var encounter: EncounterData

var _state: BattleState
var _recorder: BattleEventRecorder
var _selected_card: int = -1
var _busy: bool = false

@onready var _camera: Camera3D = %Camera
@onready var _board: Board3D = %Board
@onready var _hud: BattleHud = %Hud
@onready var _playback: BattlePlayback = %Playback


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_state = BattleState.new(encounter, rng)
	_recorder = BattleEventRecorder.new(_state)

	_board.build(_state, PLACEHOLDER_SPRITE)
	_board.sync_from_state(_state)
	_playback.board = _board
	_playback.hud = _hud

	_board.cell_clicked.connect(_on_cell_clicked)
	_hud.card_selected.connect(_on_card_selected)
	_hud.end_turn_pressed.connect(_on_end_turn_pressed)
	get_viewport().size_changed.connect(_frame_camera)
	_frame_camera()

	_run(_state.start_battle)


# 규칙은 action 안에서 동기로 끝나고, 화면은 기록된 이벤트를 재생한 뒤 실제 상태로 한 번 더 맞춘다.
func _run(action: Callable) -> void:
	_set_busy(true)
	action.call()
	await _playback.play(_recorder.take_events())
	_board.sync_from_state(_state)
	_hud.sync_from_state(_state, _selected_card)
	_set_busy(_state.finished)


func _set_busy(busy: bool) -> void:
	_busy = busy
	if busy:
		_selected_card = -1
		_board.clear_target_hints()
	_board.input_enabled = not busy
	_hud.set_interactive(not busy)


func _on_card_selected(index: int) -> void:
	if _busy:
		return
	_selected_card = index
	_refresh_target_hints()


func _on_cell_clicked(team: Unit.Team, cell: Vector2i) -> void:
	if _busy or _selected_card < 0 or team != Unit.Team.ENEMY:
		return
	var actor: Unit = _state.current_unit()
	var target: Unit = _unit_at(team, cell)
	if actor == null or target == null or _selected_card >= actor.hand.size():
		return
	var card: CardData = actor.hand[_selected_card]
	# 선택을 유지한 채 다른 대상을 고를 수 있도록 무효 대상은 규칙 호출 전에 거른다.
	if not _state.resolver.is_valid_target(actor, target, card.attack_type, card.attack_range, _state.units):
		_hud.append_log("사용할 수 없는 대상")
		return
	var card_index: int = _selected_card
	_run(func() -> void: _state.play_card(card_index, target))


func _on_end_turn_pressed() -> void:
	if _busy:
		return
	_run(_state.end_turn)


func _refresh_target_hints() -> void:
	var actor: Unit = _state.current_unit()
	if _selected_card < 0 or actor == null or not actor.is_ally() or _selected_card >= actor.hand.size():
		_board.clear_target_hints()
		return
	var card: CardData = actor.hand[_selected_card]
	var hints: Dictionary = {}
	for target in _state.living_units(Unit.Team.ENEMY):
		var valid: bool = _state.resolver.is_valid_target(actor, target, card.attack_type, card.attack_range, _state.units)
		hints[target] = {"valid": valid, "text": _hint_text(_state.resolver.reach(actor, target), card.attack_range, valid)}
	_board.show_target_hints(hints)


# 칠 수 있는지는 is_valid_target 이 정하고, 여기서는 못 치는 이유만 고른다.
# 살아 있는 적만 넘어오므로 사거리 안인데 무효라면 근접 블로킹뿐이다.
func _hint_text(distance: int, attack_range: int, valid: bool) -> String:
	if valid:
		return "✓ 거리 %d" % distance
	if distance > attack_range:
		return "거리 %d" % distance
	return "막힘"


func _unit_at(team: Unit.Team, cell: Vector2i) -> Unit:
	for unit in _state.units:
		if unit.team == team and unit.cell == cell and unit.is_alive():
			return unit
	return null


func _frame_camera() -> void:
	var layout: BoardLayout = _board.layout
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = viewport_size.x / maxf(viewport_size.y, 1.0)
	var distance: float = BoardLayout.camera_distance(layout.width(), layout.depth(), CAMERA_FOV_DEG, aspect, CAMERA_MARGIN)
	var target: Vector3 = layout.center() + CAMERA_TARGET_OFFSET
	var pitch: float = deg_to_rad(CAMERA_PITCH_DEG)
	_camera.fov = CAMERA_FOV_DEG
	_camera.position = target + Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
	_camera.look_at(target, Vector3.UP)
