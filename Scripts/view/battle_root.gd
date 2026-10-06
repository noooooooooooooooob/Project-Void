## 전투 씬(battle_3d.tscn)의 루트 스크립트. 규칙·기록·보드·HUD·재생을 이어 붙이는 조립 담당.
## 플레이어 입력(카드 선택, 이동 버튼, 칸 클릭 — 카드 사용 또는 이동, 드래그 놓기, 차례 종료)을 받아 규칙을 부르고,
## 그 결과로 쌓인 이벤트를 재생한 뒤 화면을 실제 상태와 다시 맞춘다.
# class_name 이 필요하다: 맵 화면(game_root.gd)이 전투 씬을 이 타입으로 들고 있다.
# Node3D: 3D 씬의 루트 노드.
class_name BattleRoot
extends Node3D

## 전투가 끝났을 때 맵 쪽에 알리는 신호. 아군이 이겼으면 true.
signal battle_finished(ally_won: bool)

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
## 전투 효과음 묶음.
const BATTLE_SOUNDS: BattleSounds = preload("res://Resources/audio/battle_sounds.tres")
## 원거리 화살 그림.
const ARROW_TEXTURE: Texture2D = preload("res://Art/effects/arrow.png")

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
# 카드와 함께 켜 두지 않는다: 카드를 고르면 꺼지고, 이동 버튼을 켜면 고르던 카드가 풀린다.
## 이동 버튼으로 켠 이동 모드. true 일 때만 아군 칸 클릭이 이동이 된다.
var _move_mode: bool = false
## 끝난 전투에서 아군이 이겼는지 (전투가 끝나야 뜻이 있다).
var _ally_won: bool = false
## 카메라 타격 연출 (기본 구도 위에 푸시인·흔들림, 히트스톱·슬로모션).
var _camera_fx: BattleCamera

# @onready: _ready 직전에 값을 채운다. %이름 은 씬 안에서 "고유 이름"으로 표시한 노드를 찾는다.
## 전투를 비추는 카메라.
@onready var _camera: Camera3D = %Camera
## 타일·유닛 보드.
@onready var _board: Board3D = %Board
## 화면 위 HUD (손패, 더미, 로그, SP, 이동·차례 종료 버튼).
@onready var _hud: BattleHud = %Hud
## 이벤트 재생기.
@onready var _playback: BattlePlayback = %Playback
## 배경(하늘)을 담당하는 월드 환경.
@onready var _environment: WorldEnvironment = %Environment


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
	# 결과만 기억해 둔다. 맵은 battle_finished 를 받자마자 이 씬을 지우므로, 신호는 결정타 연출 재생이 끝난 뒤 _run 이 낸다.
	_state.battle_ended.connect(func(ally_won: bool) -> void: _ally_won = ally_won)

	# 인카운터에 배경 이미지가 있으면 기본 단색 대신 그 이미지를 하늘로 쓴다.
	_apply_background(encounter.background)

	# 타일과 유닛 화면 객체를 만든다.
	_board.build(_state, PLACEHOLDER_SPRITE)
	# 타일 색·유닛 표시를 현재 상태로 맞춘다.
	_board.sync_from_state(_state)
	# 재생기에 보드를 넘긴다.
	_playback.board = _board
	# 재생기에 HUD 를 넘긴다.
	_playback.hud = _hud
	# 카메라 연출을 만들어 카메라를 맡긴다.
	_camera_fx = BattleCamera.new()
	_camera_fx.camera = _camera
	add_child(_camera_fx)
	# 효과음 재생기.
	var battle_audio := BattleAudio.new()
	battle_audio.sounds = BATTLE_SOUNDS
	add_child(battle_audio)
	# 화면 펄스 (HUD 아래 층).
	var pulse := ScreenPulse.new()
	add_child(pulse)
	# 재생기에 연출 부품을 넘긴다.
	_playback.camera_fx = _camera_fx
	_playback.audio = battle_audio
	_playback.screen_fx = pulse
	_playback.projectile_texture = ARROW_TEXTURE

	# 칸 클릭 → 카드 사용, 또는 이동 모드면 아군 칸으로 이동 시도.
	_board.cell_clicked.connect(_on_cell_clicked)
	# 빈 곳 클릭/놓기 → 드래그 취소 처리.
	_board.pick_missed.connect(_on_pick_missed)
	# 커서가 가리키는 칸이 바뀜 → 카드를 골랐으면 그 칸 기준 범위 미리보기.
	_board.cell_hovered.connect(_on_cell_hovered)
	# 커서가 칸을 벗어남 → 기본 사거리 힌트로 되돌림.
	_board.hover_cleared.connect(_on_hover_cleared)
	# 카드 선택·해제 → 힌트 갱신 (선택이면 사거리, 해제면 지움).
	_hud.card_selected.connect(_on_card_selected)
	# 카드 드래그 놓기 → 놓은 위치 판정.
	_hud.card_dropped.connect(_on_card_dropped)
	# 카드를 끄는 동안 커서 이동 → 보드가 그 위치로 커서 판정을 하게 알려 준다 (드래그 중엔 보드가 직접 마우스 이동을 못 받는다).
	_hud.card_drag_moved.connect(_on_card_drag_moved)
	# 차례 종료 버튼.
	_hud.end_turn_pressed.connect(_on_end_turn_pressed)
	# 이동 버튼 → 이동 모드를 켜고 끈다.
	_hud.move_mode_toggled.connect(_on_move_mode_toggled)
	# 창 크기가 바뀌면 카메라 거리를 다시 계산한다.
	get_viewport().size_changed.connect(_frame_camera)
	# 처음 한 번 카메라를 맞춘다.
	_frame_camera()

	# 전투를 시작한다 (첫 아군 차례까지 진행하고 그 연출을 재생).
	_run(_state.start_battle)


## 배경 이미지가 있으면 하늘을 그 이미지로 바꾼다. 없으면 씬 기본 단색 배경을 그대로 둔다.
func _apply_background(texture: Texture2D) -> void:
	if texture == null:
		return
	var env: Environment = _environment.environment.duplicate()
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = texture
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	_environment.environment = env


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
	# 규칙이 바뀌어 더는 이동할 수 없으면(SP 를 다 썼거나 갈 칸이 막혔다) 이동 모드를 끈다.
	if _move_mode and _movable_cells_now().is_empty():
		_move_mode = false
	# 잠금이 풀린 상태에 맞는 힌트(이동 가능 칸 등)를 보여 준다.
	_refresh_hints()
	# 전투가 끝났으면 마지막 연출까지 다 보여 준 지금 맵에 알린다.
	if _state.finished:
		battle_finished.emit(_ally_won)


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
	# 고른 카드 번호를 기억한다 (골랐으면 이동 모드가 꺼진다).
	_select_card(index)
	# 선택 상태에 맞는 힌트를 새로 보여 준다 (카드면 사거리, 이동 모드면 이동 가능 칸).
	_refresh_hints()


## 카드를 끌어다 화면 위치에 놓았다. 그 위치의 칸을 판정하도록 보드에 요청한다.
func _on_card_dropped(index: int, screen_position: Vector2) -> void:
	# 잠겨 있으면 무시한다.
	if _busy:
		return
	# 끌던 카드를 선택된 카드로 삼는다 (이동 모드가 꺼진다).
	_select_card(index)
	# 힌트를 그 카드 기준으로 갱신한다.
	_refresh_hints()
	# 이제부터 오는 판정 결과는 드래그에서 온 것이다.
	_awaiting_drop = true
	# 놓은 위치를 클릭처럼 판정해 달라고 한다 (결과는 cell_clicked 또는 pick_missed 로 온다).
	_board.request_pick(screen_position)


## 카드를 끄는 동안 커서가 움직였다. 보드에 위치를 넘겨 다음 물리 스텝에 그 칸으로 커서 판정을 하게 한다.
func _on_card_drag_moved(screen_position: Vector2) -> void:
	_board.update_pointer(screen_position)


## 클릭·놓기가 아무 칸에도 맞지 않았다.
func _on_pick_missed() -> void:
	# 일반 클릭의 빗나감이면 선택을 유지한다 (다른 대상을 다시 누를 수 있게).
	if not _awaiting_drop:
		return
	# 드래그 판정 대기를 끝낸다.
	_awaiting_drop = false
	# 드래그를 빈 곳에 놓았으면 취소로 보고 선택을 푼다.
	_clear_selection()


## 칸을 클릭했다(또는 드래그로 놓았다). 카드를 골랐으면 그 칸에 쓰고(적 칸이면 유닛이 없어도 광역·관통로 카드로
## 범위 안의 다른 유닛을 맞힐 수 있다), 이동 모드면 그 아군 칸으로 이동을 시도한다.
func _on_cell_clicked(team: Unit.Team, cell: Vector2i) -> void:
	# 이 판정이 드래그 놓기에서 왔는지 기억해 둔다.
	var from_drop: bool = _awaiting_drop
	# 판정 대기는 여기서 끝난다.
	_awaiting_drop = false
	# 잠겨 있으면 할 일이 없다.
	if _busy:
		return
	# 고른 카드가 없으면 이동을 시도한다.
	if _selected_card < 0:
		# 이동 모드에서, 드래그가 아닌 아군 칸 클릭만 이동으로 본다.
		if _move_mode and not from_drop and team == Unit.Team.ALLY:
			_try_move(cell)
		return
	# 지금 차례인 유닛.
	var actor: Unit = _state.current_unit()
	# 차례 유닛이 없거나, 아군 칸을 눌렀거나(카드는 적 칸만 겨냥한다), 선택 번호가 손패 범위를 벗어나면 쓰지 않는다.
	if actor == null or team != Unit.Team.ENEMY or _selected_card >= actor.hand.size():
		# 드래그였다면 카드를 손패로 돌려보낸다(선택 해제).
		if from_drop:
			_clear_selection()
		return
	# 사용하려는 카드.
	var card: CardData = actor.hand[_selected_card]
	# 클릭은 선택을 유지한 채 다른 칸을 다시 고를 수 있게 규칙 호출 전에 거르고, 드래그는 손패로 돌려보낸다.
	if not _state.resolver.is_valid_cell(actor, team, cell, card.attack_type, card.attack_range, _state.units):
		# 로그로 알린다.
		_hud.append_log("사용할 수 없는 위치")
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
		if not _state.play_card(card_index, team, cell):
			_hud.append_log("사용할 수 없는 위치"))


## 차례 종료 버튼을 눌렀다.
func _on_end_turn_pressed() -> void:
	# 잠겨 있으면 무시한다.
	if _busy:
		return
	# 차례가 넘어가므로 이동 모드를 끈다 (다음 아군이 켜진 채로 시작하지 않게).
	_move_mode = false
	# 차례를 끝내고 다음 아군 차례까지 진행·재생한다.
	_run(_state.end_turn)


## 이동 버튼을 켜거나 껐다. 켜면 고르던 카드를 놓는다 (이동과 카드는 함께 쓰지 않는다).
func _on_move_mode_toggled(on: bool) -> void:
	# 잠겨 있으면 무시한다 (버튼도 함께 잠기지만 안전장치). 버튼 눌림은 지금 모드로 되돌린다.
	if _busy:
		_hud.set_move_mode(_move_mode)
		return
	# 모드를 기억한다.
	_move_mode = on
	# 켰으면 고르던 카드를 놓는다 (힌트 갱신까지 함께 한다).
	if on:
		_clear_selection()
		return
	# 바뀐 상태에 맞는 힌트를 보여 준다.
	_refresh_hints()


## 고른 카드 번호를 기억한다. 카드를 골랐으면 이동 모드를 끈다 (둘은 함께 쓰지 않는다).
func _select_card(index: int) -> void:
	# 번호를 기억한다.
	_selected_card = index
	# 선택을 푼 것이면 이동 모드는 그대로 둔다.
	if index < 0:
		return
	# 이동 모드를 끈다.
	_move_mode = false
	# 이동 버튼 눌림도 함께 푼다.
	_hud.set_move_mode(false)


## 지금 차례 아군을 cell 로 이동시킨다. 이동할 수 없는 칸이면 무시한다.
func _try_move(cell: Vector2i) -> void:
	# 지금 갈 수 있는 칸이 아니면 무시한다 (힌트로 보여 준 칸과 같은 판정을 쓴다).
	if not _movable_cells_now().has(cell):
		return
	# 이동을 실행하고 재생한다. 규칙이 거절하면(예상 밖 상황) 로그를 남긴다.
	_run(func() -> void:
		if not _state.move_unit(cell):
			_hud.append_log("이동할 수 없는 칸"))


## 지금 차례 유닛이 갈 수 있는 칸. "지금 이동할 수 있는가"의 유일한 판정이라 힌트·버튼·클릭이 모두 이 결과를 쓴다.
## 잠겨 있거나, 전투가 끝났거나, 아군 차례가 아니거나, 쓰러졌거나, SP 가 없으면 빈 배열.
func _movable_cells_now() -> Array[Vector2i]:
	# 갈 칸이 없을 때 돌려줄 빈 배열 (돌려주는 타입이 정해져 있어 따로 만든다).
	var none: Array[Vector2i] = []
	# 지금 차례인 유닛.
	var actor: Unit = _state.current_unit()
	# 하나라도 어긋나면 이동할 수 없다.
	if _busy or _state.finished or actor == null or not actor.is_ally() or not actor.is_alive() or actor.sp < 1:
		return none
	# 규칙에게 갈 칸을 묻는다.
	return _state.resolver.movable_cells(actor, _state.units)


# 이 함수는 화면만 바꾼다: _move_mode 를 여기서 끄지 않으므로 연출 중(_busy)에도 모드가 그대로 살아 있다.
## 지금 상황에 맞는 힌트를 보드에 보여 주고, 이동 버튼 활성화·눌림을 맞춘다.
## 카드 선택 중이면 사거리 힌트, 이동 모드면 이동 가능 칸, 그 외에는 지운다.
func _refresh_hints() -> void:
	# 갈 수 있는 칸.
	var cells: Array[Vector2i] = _movable_cells_now()
	# 갈 칸이 하나라도 있어야 이동 버튼을 쓸 수 있다.
	var can_move: bool = not cells.is_empty()
	# 이동 버튼 활성화를 알린다 (쓸 수 없으면 HUD 가 눌림도 푼다).
	_hud.set_move_available(can_move)
	# 눌림은 지금 쓸 수 있을 때만 켠다 (연출 중에 눌림+비활성으로 남지 않게).
	_hud.set_move_mode(_move_mode and can_move)
	# 카드를 골랐으면 사거리 힌트. 커서가 이미 적 칸을 가리키고 있으면 그 칸 기준 범위 미리보기까지 함께 보여 준다.
	if _selected_card >= 0:
		var hover: Dictionary = _board.hover_state()
		if hover.get("has", false):
			_apply_hover_preview(hover["team"], hover["cell"])
		else:
			_refresh_target_hints()
		return
	# 이동 모드가 아니거나 보여 줄 칸이 없으면 힌트를 지운다.
	if not _move_mode or not can_move:
		_board.clear_target_hints()
		return
	# 이동할 수 있는 칸을 표시한다 (칸이 있다는 것은 차례 유닛이 있다는 뜻이라 여기서는 null 이 아니다).
	_board.show_move_hints(_state.current_unit().team, cells)


## 카드 선택을 지우고 힌트를 다시 정한다 (이동 모드면 이동 가능 칸, 그 외에는 없음).
func _clear_selection() -> void:
	# 선택 없음으로.
	_selected_card = -1
	# 손패에서 들려 있던 카드도 내린다 (이미 내려 있으면 아무 일도 하지 않는다).
	_hud.clear_card_selection()
	# 선택이 없는 상태의 힌트로 바꾼다.
	_refresh_hints()


## 커서가 새 칸을 가리키게 됐다. 카드를 고른 상태에서 적이 선 칸이면 그 칸 기준 범위 모양을 덧그린다.
func _on_cell_hovered(team: Unit.Team, cell: Vector2i) -> void:
	_apply_hover_preview(team, cell)


## 커서가 어떤 칸도 가리키지 않게 됐다. 기본 사거리 힌트로 되돌린다.
func _on_hover_cleared() -> void:
	_refresh_target_hints()


## 커서가 가리키는 칸에 맞춰 힌트를 다시 그린다. 카드를 고른 상태에서 적 칸을 가리키면(유닛이 있든 없든) 카드의
## 범위 모양이 거기서 맞힐 칸들을 하양(칠 수 있음)/주황(사거리 밖·막힘) 으로 덧그려 기본 사거리 힌트 위에 겹쳐 보여 준다.
func _apply_hover_preview(team: Unit.Team, cell: Vector2i) -> void:
	# 기본 힌트를 먼저 다시 그린다 (이전 커서가 남긴 범위 미리보기를 지운다).
	_refresh_target_hints()
	# 카드를 고르지 않았으면 힌트 자체가 없으니 더 할 일이 없다.
	if _selected_card < 0:
		return
	# 대상은 적 칸에서만 고를 수 있다.
	if team != Unit.Team.ENEMY:
		return
	# 지금 차례인 유닛.
	var actor: Unit = _state.current_unit()
	# 차례 유닛이 없거나 아군이 아니거나 선택 번호가 손패 범위 밖이면 힌트를 만들 수 없다.
	if actor == null or not actor.is_ally() or _selected_card >= actor.hand.size():
		return
	# 고른 카드.
	var card: CardData = actor.hand[_selected_card]
	# 커서가 가리키는 칸을 겨냥했다고 보고, 카드의 범위 모양이 덮는 칸들을 모두 구한다 (유닛 유무와 상관없이).
	var cells: Array[Vector2i] = _state.resolver.shape_cells(cell, card.shape, _state.resolver.enemy_grid)
	# 칸 → 힌트 정보.
	var hits: Dictionary = {}
	# 범위 안의 칸마다.
	for shape_cell in cells:
		# 사거리·막힘까지 따진 실제 유효 여부 (기본 힌트와 같은 판정).
		var valid: bool = _state.resolver.is_valid_cell(actor, team, shape_cell, card.attack_type, card.attack_range, _state.units)
		# 판정 결과와 표시할 문장.
		hits[shape_cell] = {"valid": valid, "text": _hint_text(_state.resolver.reach_cell(actor, team, shape_cell), card.attack_range, valid)}
	# 보드에 덧그린다.
	_board.show_shape_preview(team, hits)


## 고른 카드 기준으로 적 격자의 모든 칸(유닛이 있든 없든)에 칠 수 있는지와 이유를 계산해 보드에 보여 준다.
func _refresh_target_hints() -> void:
	# 지금 차례인 유닛.
	var actor: Unit = _state.current_unit()
	# 고른 카드가 없거나, 차례 유닛이 아군이 아니거나, 번호가 범위 밖이면 힌트를 지운다.
	if _selected_card < 0 or actor == null or not actor.is_ally() or _selected_card >= actor.hand.size():
		_board.clear_target_hints()
		return
	# 고른 카드.
	var card: CardData = actor.hand[_selected_card]
	# 적 격자 크기.
	var grid: Vector2i = _state.resolver.enemy_grid
	# 칸 → 힌트 정보.
	var hints: Dictionary = {}
	# 적 격자의 모든 칸마다 (유닛이 없는 칸도 광역·관통로 카드의 겨냥 지점이 될 수 있다).
	for row in grid.y:
		for col in grid.x:
			# 이번 칸.
			var cell := Vector2i(col, row)
			# 규칙과 같은 함수로 칠 수 있는지 판정한다.
			var valid: bool = _state.resolver.is_valid_cell(actor, Unit.Team.ENEMY, cell, card.attack_type, card.attack_range, _state.units)
			# 판정 결과와 표시할 문장을 담는다.
			hints[cell] = {"valid": valid, "text": _hint_text(_state.resolver.reach_cell(actor, Unit.Team.ENEMY, cell), card.attack_range, valid)}
	# 보드에 보여 준다.
	_board.show_target_hints(Unit.Team.ENEMY, hints)


# 칠 수 있는지는 is_valid_cell 이 정하고, 여기서는 못 치는 이유만 고른다.
## 힌트 글자를 만든다: 칠 수 있으면 "✓ 거리 N", 사거리 밖이면 "거리 N", 그 외(근접 막힘)는 "막힘".
func _hint_text(distance: int, attack_range: int, valid: bool) -> String:
	# 칠 수 있으면 체크 표시와 거리.
	if valid:
		return "✓ 거리 %d" % distance
	# 사거리보다 멀면 거리만 보여 준다.
	if distance > attack_range:
		return "거리 %d" % distance
	# 남은 이유는 근접 막힘.
	return "막힘"


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
	# 바라볼 점에서 뒤(+z)·위(+y)로 distance 만큼 떨어진 곳.
	var camera_position: Vector3 = target + Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
	# 그 자리에서 바라볼 점을 보는 회전.
	var view := Transform3D(Basis.IDENTITY, camera_position).looking_at(target, Vector3.UP)
	# 연출이 이 구도 위에 오프셋을 더한다.
	_camera_fx.set_base(view.origin, view.basis)
