# 화면 확인용 캡처: 주요 화면을 차례로 띄워 PNG 로 저장한다 (창 모드로 실행해야 그림이 나온다).
# 실행: Godot --path <프로젝트> --script res://tools/screenshots.gd -- <출력 폴더>
extends SceneTree

var _out: String
var _steps: Array[Callable] = []
var _current: Node
var _wait: int = 0
var _index: int = -1
var _name: String = ""
var _game: GameState
var _ex: Expedition


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1920, 1080)
	_game = GameState.new()
	_game.add_member("hangyeol")
	_game.add_member("hongyeon")
	_game.chapter = 1
	_game.add_gold(240)
	_game.add_journal("사무소를 맡다", "첫 의뢰에서 선배들을 모두 잃었다.")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	_ex = Expedition.new(ChapterData.CHAPTER1, _game, rng)
	_steps = [
		func() -> Node: return _named("title", TitleScreen.new(), 20),
		func() -> Node: return _named("dialogue", _dialogue(), 60),
		func() -> Node: return _named("office", OfficeScreen.new(_game), 20),
		func() -> Node: return _named("expedition", ExpeditionView.new(_ex), 20),
		func() -> Node: return _named("expedition_mid", _mid_map(), 20),
		func() -> Node: return _named("shop", ShopView.new(_ex, _ex.shop_stock()), 20),
		func() -> Node: return _named("battle", _battle(), 240),
		func() -> Node: return _named("reward", RewardView.new(_ex.battle_reward(ExpeditionNode.battle(ChapterData.ELITE, ["brute"])), _game), 20),
		func() -> Node: return _named("party", _party(), 20),
	]


func _named(n: String, node: Node, frames: int) -> Node:
	_name = n
	_wait = frames
	return node


func _dialogue() -> Node:
	var view := DialogueView.new()
	var runner := DialogueRunner.from_script("tutorial_escape")
	# 혈귀와 홍연이 함께 서 있는 장면까지 넘긴다.
	view.ready.connect(func() -> void:
		view.play(runner)
		while not (runner.portraits.has("left") and runner.portraits.has("right")) and not runner.finished:
			view._next()
		view._text.visible_characters = -1
		view._typing = false)
	return view


## 두 칸 진행한 지도 (지나온 길과 열린 길이 보이게).
func _mid_map() -> Node:
	for k in 2:
		var n: ExpeditionNode = _ex.pick(_ex.selectable_ids()[0])
		if n.is_battle():
			_ex.resolve_battle_win(n, [28, 22])
		else:
			_ex.resolve_simple(n)
	return ExpeditionView.new(_ex)


func _battle() -> Node:
	var battle: BattleRoot = load("res://Scenes/battle_3d.tscn").instantiate()
	battle.encounter = _ex.encounter_for(ExpeditionNode.battle(ChapterData.BATTLE, ["husk", "hound", "rat"]))
	return battle


func _party() -> Node:
	var view := PartyView.new()
	view.theme = UiTheme.get_theme()
	view.ready.connect(func() -> void: view.bind(_game.party))
	return view


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		if _wait == 0 and _current != null:
			var img: Image = root.get_texture().get_image()
			img.save_png("%s/%s.png" % [_out, _name])
			print("saved ", _name)
		return false
	if _current != null:
		_current.queue_free()
		_current = null
	_index += 1
	if _index >= _steps.size():
		quit()
		return true
	_current = _steps[_index].call()
	root.add_child(_current)
	return false
