# 통합 확인용: 게임을 타이틀부터 1장 완료까지 자동으로 진행한다 (헤드리스).
# 대화는 건너뛰고, 선택지는 첫 번째, 전투는 즉시 승리(황혼의 손은 패배), 문은 첫 번째를 고른다.
# 실행: Godot --headless --path <프로젝트> --script res://tools/autoplay.gd -- [deep]
extends SceneTree

const MAX_FRAMES: int = 60000

var _root: GameRoot
var _frames: int = 0
var _trace: PackedStringArray = []
var _last: String = ""
var _deep: bool = false
var _choice_index: Dictionary = {}
## 실행 전에 있던 저장 내용 (끝나면 되돌린다). 없었으면 빈 문자열.
var _saved_backup: String = ""


func _initialize() -> void:
	_deep = OS.get_cmdline_user_args().has("deep")
	# 플레이어의 저장을 건드리지 않도록 백업해 두었다가 끝나면 되돌린다.
	if FileAccess.file_exists(GameState.SAVE_PATH):
		_saved_backup = FileAccess.get_file_as_string(GameState.SAVE_PATH)
	_root = load("res://Scenes/game_root.tscn").instantiate()
	root.add_child(_root)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > MAX_FRAMES:
		_report("TIMEOUT")
		return true
	if _frames % 2 != 0:
		return false
	# 겹쳐 뜬 선택 창이 먼저.
	for child in _root.get_children():
		if child is ChoiceDialog and not child.is_queued_for_deletion():
			var title: String = (child as ChoiceDialog)._title
			_note("Choice: %s" % title)
			var pick: int = 1 if (_deep and title == "공허 속의 공허") else 0
			(child as ChoiceDialog).chosen.emit(pick)
			return false
		if child is PartyView:
			(child as PartyView).closed.emit()
			return false
	var screen: Node = _root._screen
	if screen == null or not is_instance_valid(screen) or screen.is_queued_for_deletion():
		return false
	if screen is TitleScreen:
		_note("Title")
		(screen as TitleScreen).started.emit()
	elif screen is MainMenu:
		_note("MainMenu")
		(screen as MainMenu).new_game.emit()
	elif screen is DialogueView:
		var view := screen as DialogueView
		var beat: Dictionary = view.current_beat()
		if beat.get("kind", "") == DialogueRunner.CHOICE:
			view._on_choice(0)
		else:
			view._on_skip()
	elif screen is BattleRoot:
		_finish_battle(screen as BattleRoot)
	elif screen is ExpeditionView:
		var ex: Expedition = (screen as ExpeditionView)._ex
		var ids: Array[int] = ex.selectable_ids()
		_note("Map Z%d at %d -> %s" % [ex.floor_index + 1, ex.current_id, ids.map(func(id: int) -> String: return ex.node(id)["type"])])
		(screen as ExpeditionView).node_chosen.emit(ids[0])
	elif screen is RewardView:
		_note("Reward")
		(screen as RewardView).done.emit(0)
	elif screen is ShopView:
		_note("Shop")
		(screen as ShopView).buy_button(0).pressed.emit()
		(screen as ShopView).done.emit()
	elif screen is SupplyView:
		_note("Supply")
		(screen as SupplyView).done.emit(0)
	elif screen is OfficeScreen:
		_note("Office chapter=%d" % _root.game.chapter)
		if _root.game.chapter >= 2:
			_report("CHAPTER 1 CLEARED")
			return true
		(screen as OfficeScreen).request_chosen.emit("ch1")
	return false


func _finish_battle(battle: BattleRoot) -> void:
	if battle.get_meta("autoplay_done", false):
		return
	if battle._state == null or battle._busy:
		return
	battle.set_meta("autoplay_done", true)
	var enemies: PackedStringArray = []
	var hand: bool = false
	for u in battle._state.units:
		if not u.is_ally():
			enemies.append(String(u.data.id))
			hand = hand or u.data.id == &"hand"
	_note("Battle vs %s" % ",".join(enemies))
	# 체력을 조금 깎아 이어짐을 확인할 수 있게 한다.
	for u in battle._state.units:
		if u.is_ally():
			u.hp = maxi(1, u.hp - 5)
	battle.battle_finished.emit(not hand)


func _note(text: String) -> void:
	if text == _last:
		return
	_last = text
	_trace.append(text)


func _report(status: String) -> void:
	print("== %s after %d frames" % [status, _frames])
	for line in _trace:
		print("  ", line)
	if _root.game != null:
		var g: GameState = _root.game
		var decks: PackedStringArray = []
		for i in g.party.member_count():
			decks.append("%s:%d" % [g.party.member_data(i).display_name, g.party.member_data(i).deck.size()])
		print("state: chapter=%d gold=%d lifespan=%d members=%s items=%d journal=%d flags=%s" % [g.chapter, g.gold, g.lifespan, decks, g.party.inventory.size(), g.journal.size(), g.flags.keys()])
	_restore_save()
	quit()


func _restore_save() -> void:
	if _saved_backup.is_empty():
		if FileAccess.file_exists(GameState.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
		return
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	file.store_string(_saved_backup)
