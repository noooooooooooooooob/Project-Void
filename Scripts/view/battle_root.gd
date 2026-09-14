## 전투 씬(battle_3d.tscn)의 루트 스크립트. 규칙·기록·보드·HUD·재생을 이어 붙이는 조립 담당.
## 플레이어 입력(카드 선택, 칸 클릭, 드래그 놓기, 차례 종료)을 받아 규칙을 부르고,
## 그 결과로 쌓인 이벤트를 재생한 뒤 화면을 실제 상태와 다시 맞춘다.
# class_name 이 없다: 씬에만 붙어 쓰이고 다른 스크립트가 이 타입을 직접 참조하지 않는다.
# Node3D: 3D 씬의 루트 노드.
extends Node3D

## 유닛 그림이 없을 때 쓰는 임시 실루엣 그림.
const PLACEHOLDER_SPRITE: Texture2D = preload("res://Resources/sprites/placeholder_unit.png")
## 카메라가 내려다보는 각도 (도). 0 이면 수평, 90 이면 바로 위.
const CAMERA_PITCH_DEG: float = 44.0
## 카메라 세로 시야각 (도).
const CAMERA_FOV_DEG: float = 40.0
## 보드 둘레 여백 배율. 클수록 카메라가 멀어져 보드가 작게 보인다.
const CAMERA_MARGIN: float = 1.8
# 아래쪽 HUD 에 보드가 가리지 않게 바라보는 점을 카메라 쪽으로 당긴다.
## 카메라가 바라보는 점을 보드 중심에서 옮기는 양.
const CAMERA_TARGET_OFFSET := Vector3(0.0, 0.0, 0.6)

## 이 씬에서 치를 전투 구성 (인스펙터에서 skirmish.tres 등을 넣는다).
@export var encounter: EncounterData

## 전투 규칙 상태.
var _state: BattleState
## 규칙 신호를 이벤트로 쌓는 기록기.
var _recorder: BattleEventRecorder
## 손패에서 고른 카드 번호. -1 이면 고르지 않음.
var _selected_card: int = -1
## 규칙 호출·재생 중이면 true (그동안 입력을 막는다).
var _busy: bool = false
# 드래그로 놓은 카드의 판정 결과를 기다리는 중. 빗나가거나 무효면 클릭과 달리 선택을 해제한다.
## 드래그로 놓은 위치의 칸 판정을 기다리는 중이면 true.
var _awaiting_drop: bool = false

# @onready: _ready 직전에 값을 채운다. %이름 은 씬 안에서 "고유 이름"으로 표시한 노드를 찾는다.
## 전투를 비추는 카메라.
@onready var _camera: Camera3D = %Camera
## 타일·유닛 보드.
@onready var _board: Board3D = %Board
## 화면 위 HUD (손패, 더미, 로그, SP, 차례 종료 버튼).
@onready var _hud: BattleHud = %Hud
## 이벤트 재생기.
@onready var _playback: BattlePlayback = %Playback


## 씬이 준비되면 전투를 만들고 각 부분을 연결한 뒤 전투를 시작한다.
func _ready() -> void:
	# 난수 생성기를 만든다.
	var rng := RandomNumberGenerator.new()
	# 실행할 때마다 다른 시드를 쓴다 (매 판 덱 순서가 달라진다).
	rng.randomize()
	# 전투 규칙 상태를 만든다.
	_state = BattleState.new(encounter, rng)
	# 규칙 신호를 기록하기 시작한다 (start_battle 보다 먼저 연결해야 첫 신호를 놓치지 않는다).
	_recorder = BattleEventRecorder.new(_state)

	# 타일과 유닛 화면 객체를 만든다.
	_board.build(_state, PLACEHOLDER_SPRITE)
	# 타일 색·유닛 표시를 현재 상태로 맞춘다.
	_board.sync_from_state(_state)
	# 재생기에 보드를 넘긴다.
	_playback.board = _board
	# 재생기에 HUD 를 넘긴다.
	_playback.hud = _hud

	# 칸 클릭 → 카드 사용 시도.
	_board.cell_clicked.connect(_on_cell_clicked)
	# 빈 곳 클릭/놓기 → 드래그 취소 처리.
	_board.pick_missed.connect(_on_pick_missed)
	# 카드 선택 → 사거리 힌트.
	_hud.card_selected.connect(_on_card_selected)
	# 카드 드래그 놓기 → 놓은 위치 판정.
	_hud.card_dropped.connect(_on_card_dropped)
	# 차례 종료 버튼.
	_hud.end_turn_pressed.connect(_on_end_turn_pressed)
	# 창 크기가 바뀌면 카메라 거리를 다시 계산한다.
	get_viewport().size_changed.connect(_frame_camera)
	# 처음 한 번 카메라를 맞춘다.
	_frame_camera()

	# 전투를 시작한다 (첫 아군 차례까지 진행하고 그 연출을 재생).
	_run(_state.start_battle)


# 규칙은 action 안에서 동기로 끝나고, 화면은 기록된 이벤트를 재생한 뒤 실제 상태로 한 번 더 맞춘다.
## 규칙 호출 하나를 "잠금 → 호출 → 재생 → 동기화 → 잠금 해제" 순서로 실행한다.
func _run(action: Callable) -> void:
	# 입력을 막는다.
	_set_busy(true)
	# 규칙 함수를 부른다 (그동안 난 신호가 기록기에 쌓인다).
	action.call()
	# 쌓인 이벤트를 꺼내 재생이 끝날 때까지 기다린다.
	await _playback.play(_recorder.take_events())
	# 보드를 실제 규칙 상태와 맞춘다.
	_board.sync_from_state(_state)
	# HUD 를 실제 규칙 상태와 맞춘다.
	_hud.sync_from_state(_state, _selected_card)
	# 전투가 끝났으면 계속 잠그고, 아니면 입력을 푼다.
	_set_busy(_state.finished)


## 입력 잠금 상태를 바꾸고 보드·HUD 에 알린다.
func _set_busy(busy: bool) -> void:
	# 상태를 기억한다.
	_busy = busy
	# 잠글 때는 진행 중이던 선택과 드래그 판정 대기를 없앤다.
	if busy:
		# 드래그 판정 대기를 끈다.
		_awaiting_drop = false
		# 카드 선택과 힌트를 지운다.
		_clear_selection()
	# 보드 클릭을 켜거나 끈다.
	_board.input_enabled = not busy
	# 손패·버튼 입력을 켜거나 끈다.
	_hud.set_interactive(not busy)


## 손패에서 카드를 골랐거나(index ≥ 0) 선택을 풀었다(-1).
func _on_card_selected(index: int) -> void:
	# 잠겨 있으면 무시한다.
	if _busy:
		return
	# 고른 카드 번호를 기억한다.
	_selected_card = index
	# 대상 칸마다 사거리 힌트를 새로 보여 준다.
	_refresh_target_hints()


## 카드를 끌어다 화면 위치에 놓았다. 그 위치의 칸을 판정하도록 보드에 요청한다.
func _on_card_dropped(index: int, screen_position: Vector2) -> void:
	# 잠겨 있으면 무시한다.
	if _busy:
		return
	# 끌던 카드를 선택된 카드로 삼는다.
	_selected_card = index
	# 힌트를 그 카드 기준으로 갱신한다.
	_refresh_target_hints()
	# 이제부터 오는 판정 결과는 드래그에서 온 것이다.
	_awaiting_drop = true
	# 놓은 위치를 클릭처럼 판정해 달라고 한다 (결과는 cell_clicked 또는 pick_missed 로 온다).
	_board.request_pick(screen_position)


## 클릭·놓기가 아무 칸에도 맞지 않았다.
func _on_pick_missed() -> void:
	# 일반 클릭의 빗나감이면 선택을 유지한다 (다른 대상을 다시 누를 수 있게).
	if not _awaiting_drop:
		return
	# 드래그 판정 대기를 끝낸다.
	_awaiting_drop = false
	# 드래그를 빈 곳에 놓았으면 취소로 보고 선택을 푼다.
	_clear_selection()


## 칸을 클릭했다(또는 드래그로 놓았다). 선택한 카드를 그 칸의 적에게 쓰려고 시도한다.
func _on_cell_clicked(team: Unit.Team, cell: Vector2i) -> void:
	# 이 판정이 드래그 놓기에서 왔는지 기억해 둔다.
	var from_drop: bool = _awaiting_drop
	# 판정 대기는 여기서 끝난다.
	_awaiting_drop = false
	# 잠겨 있거나 고른 카드가 없으면 할 일이 없다.
	if _busy or _selected_card < 0:
		return
	# 지금 차례인 유닛.
	var actor: Unit = _state.current_unit()
	# 적 칸이면 그 칸에 살아 있는 적을 찾는다 (아군 칸은 대상이 아니다).
	var target: Unit = _unit_at(team, cell) if team == Unit.Team.ENEMY else null
	# 차례 유닛이 없거나, 대상이 없거나, 선택 번호가 손패 범위를 벗어나면 사용하지 않는다.
	if actor == null or target == null or _selected_card >= actor.hand.size():
		# 드래그였다면 카드를 손패로 돌려보낸다(선택 해제).
		if from_drop:
			_clear_selection()
		return
	# 사용하려는 카드.
	var card: CardData = actor.hand[_selected_card]
	# 클릭은 선택을 유지한 채 다른 대상을 고를 수 있게 규칙 호출 전에 거르고, 드래그는 손패로 돌려보낸다.
	if not _state.resolver.is_valid_target(actor, target, card.attack_type, card.attack_range, _state.units):
		# 로그로 알린다.
		_hud.append_log("사용할 수 없는 대상")
		# 드래그였다면 선택을 푼다.
		if from_drop:
			_clear_selection()
		return
	# 잠금이 선택을 지우기 전에 카드 번호를 따로 복사해 둔다.
	var card_index: int = _selected_card
	# 손패 화면에 곧 사라질 카드 위치를 알려 준다 (같은 카드가 여러 장일 때 정확한 장을 빼기 위해).
	_hud.set_pending_play(card_index)
	# 카드 사용을 실행한다. 규칙이 거절하면(예상 밖 상황) 로그를 남긴다.
	_run(func() -> void:
		if not _state.play_card(card_index, target):
			_hud.append_log("사용할 수 없는 대상"))


## 차례 종료 버튼을 눌렀다.
func _on_end_turn_pressed() -> void:
	# 잠겨 있으면 무시한다.
	if _busy:
		return
	# 차례를 끝내고 다음 아군 차례까지 진행·재생한다.
	_run(_state.end_turn)


## 카드 선택과 사거리 힌트를 지운다.
func _clear_selection() -> void:
	# 선택 없음으로.
	_selected_card = -1
	# 보드의 힌트 표시를 지운다.
	_board.clear_target_hints()


## 고른 카드 기준으로 살아 있는 적마다 칠 수 있는지와 이유를 계산해 보드에 보여 준다.
func _refresh_target_hints() -> void:
	# 지금 차례인 유닛.
	var actor: Unit = _state.current_unit()
	# 고른 카드가 없거나, 차례 유닛이 아군이 아니거나, 번호가 범위 밖이면 힌트를 지운다.
	if _selected_card < 0 or actor == null or not actor.is_ally() or _selected_card >= actor.hand.size():
		_board.clear_target_hints()
		return
	# 고른 카드.
	var card: CardData = actor.hand[_selected_card]
	# 적 유닛 → 힌트 정보.
	var hints: Dictionary = {}
	# 살아 있는 적마다.
	for target in _state.living_units(Unit.Team.ENEMY):
		# 규칙과 같은 함수로 칠 수 있는지 판정한다.
		var valid: bool = _state.resolver.is_valid_target(actor, target, card.attack_type, card.attack_range, _state.units)
		# 판정 결과와 표시할 문장을 담는다.
		hints[target] = {"valid": valid, "text": _hint_text(_state.resolver.reach(actor, target), card.attack_range, valid)}
	# 보드에 보여 준다.
	_board.show_target_hints(hints)


# 칠 수 있는지는 is_valid_target 이 정하고, 여기서는 못 치는 이유만 고른다.
# 살아 있는 적만 넘어오므로 사거리 안인데 무효라면 근접 블로킹뿐이다.
## 힌트 글자를 만든다: 칠 수 있으면 "✓ 거리 N", 사거리 밖이면 "거리 N", 그 외는 "막힘".
func _hint_text(distance: int, attack_range: int, valid: bool) -> String:
	# 칠 수 있으면 체크 표시와 거리.
	if valid:
		return "✓ 거리 %d" % distance
	# 사거리보다 멀면 거리만 보여 준다.
	if distance > attack_range:
		return "거리 %d" % distance
	# 남은 이유는 근접 막힘.
	return "막힘"


## 편과 칸 좌표에 살아 있는 유닛을 찾는다. 없으면 null.
func _unit_at(team: Unit.Team, cell: Vector2i) -> Unit:
	# 모든 유닛을 확인한다.
	for unit in _state.units:
		# 같은 편, 같은 칸, 살아 있음이면 그 유닛이다.
		if unit.team == team and unit.cell == cell and unit.is_alive():
			return unit
	# 못 찾았다.
	return null


## 보드 전체가 화면에 들어오도록 카메라 위치·각도·시야각을 정한다.
func _frame_camera() -> void:
	# 보드 크기 계산기.
	var layout: BoardLayout = _board.layout
	# 현재 화면 크기.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	# 가로세로 비율 (세로가 0 이면 1 로 막는다).
	var aspect: float = viewport_size.x / maxf(viewport_size.y, 1.0)
	# 보드 폭·깊이가 모두 들어오는 카메라 거리.
	var distance: float = BoardLayout.camera_distance(layout.width(), layout.depth(), CAMERA_FOV_DEG, aspect, CAMERA_MARGIN)
	# 바라볼 점 = 보드 중심 + HUD 를 피하기 위한 보정.
	var target: Vector3 = layout.center() + CAMERA_TARGET_OFFSET
	# 내려다보는 각도를 라디안으로.
	var pitch: float = deg_to_rad(CAMERA_PITCH_DEG)
	# 시야각을 적용한다.
	_camera.fov = CAMERA_FOV_DEG
	# 바라볼 점에서 뒤(+z)·위(+y)로 distance 만큼 떨어진 곳에 카메라를 둔다.
	_camera.position = target + Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
	# 바라볼 점을 향하게 회전시킨다.
	_camera.look_at(target, Vector3.UP)
