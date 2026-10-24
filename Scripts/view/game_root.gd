## 메인 씬의 뿌리이자 게임 흐름 진행자.
## 타이틀 → 메인 메뉴 → (새 게임) 프롤로그·튜토리얼 → 사무소 ⇄ 원정(의뢰) → 정화·에필로그.
## 화면은 한 번에 하나만 띄우고(_show), 대화·선택·전투는 await 로 결과를 기다리는 순서대로 적는다.
class_name GameRoot
extends Node

## 전투 화면이 끝났음을 알리는 내부 신호 (이기고 짐·도망을 하나로 모은다).
signal _battle_result(result: BattleResult)

## 전투 한 번의 결과.
class BattleResult:
	var won: bool = false
	var fled: bool = false
	## 아군 순서대로 남은 체력.
	var hp: Array = []

	func _init(p_won: bool, p_fled: bool) -> void:
		won = p_won
		fled = p_fled


const BattleScene: PackedScene = preload("res://Scenes/battle_3d.tscn")
## 승리·패배 배너를 보여 주는 시간.
const BANNER_HOLD: float = 1.1

## 튜토리얼 전투의 선배 셋과 주인공 배치.
const TUTORIAL_ALLIES: Array = [["doyun", Vector2i(0, 1)], ["hangyeol", Vector2i(0, 0)], ["baekjun", Vector2i(1, 1)], ["mira", Vector2i(1, 2)]]
## 튜토리얼 안내.
const TUTORIAL_TIPS_1: Array[String] = [
	"전투는 속도가 빠른 순서로 한 명씩 차례를 가집니다. 위쪽 막대에서 순서를 볼 수 있습니다.",
	"내 차례가 되면 카드 4장을 뽑습니다. 카드를 끌어 적에게 놓거나, 눌러서 고른 뒤 적을 누르면 사용합니다. 카드마다 SP 가 들고, SP 는 차례마다 다시 찹니다.",
	"근접 카드는 같은 줄(행)의 가장 앞에 있는 적만 칠 수 있습니다. 줄이 다르면 '이동' 버튼을 켜고 칸을 눌러 움직이세요. 이동은 SP 대신 이동력을 씁니다.",
	"할 일을 다 했으면 '차례 종료'. 적을 모두 쓰러뜨리면 승리합니다.",
]
const TUTORIAL_TIPS_2: Array[String] = [
	"유닛 머리 위의 보라색 줄이 흐트러짐 게이지입니다. 맞을 때마다 줄어들고, 방어도로 막아도 줄어듭니다.",
	"게이지가 0 이 되면 적은 '기절', 아군은 '탈진'해서 다음 차례를 쉽니다. 균열 찌르기·방패 치기처럼 흐트러짐을 크게 깎는 카드를 노리세요.",
	"백준의 치유·보호막은 아군을 눌러서 씁니다.",
]
const HAND_TIPS: Array[String] = ["...저건 이길 수 있는 상대가 아니다."]
## 정화 때 고르는 신의 힘.
const PURIFY_GOLD: int = 150
const GODS: Array = [
	{"text": "북부의 신", "desc": "증기와 질서 · 자금 +150"},
	{"text": "동부의 신", "desc": "기와 생명 · 장비 1개"},
	{"text": "서부의 신", "desc": "힘과 투쟁 · 카드 1장"},
]

var game: GameState
var _rng := RandomNumberGenerator.new()
var _screen: Node


func _ready() -> void:
	_rng.randomize()
	_show_title()


## 지금 띄워 둔 화면 (자동 진행·테스트용).
func current_screen() -> Node:
	return _screen


# ---------------- 화면 전환 ----------------

func _show(screen: Node) -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
	_screen = screen
	if screen != null:
		add_child(screen)


func _show_title() -> void:
	var title := TitleScreen.new()
	_show(title)
	await title.started
	_show_main_menu()


func _show_main_menu() -> void:
	var menu := MainMenu.new()
	_show(menu)
	menu.new_game.connect(_new_game, CONNECT_ONE_SHOT)
	menu.continue_game.connect(_continue_game, CONNECT_ONE_SHOT)
	menu.quit_game.connect(func() -> void: get_tree().quit())


func _continue_game() -> void:
	game = GameState.load_from_disk()
	if game == null:
		_new_game()
		return
	_show_office()


func _show_office() -> void:
	var office := OfficeScreen.new(game)
	_show(office)
	office.request_chosen.connect(_on_request_chosen, CONNECT_ONE_SHOT)
	office.party_requested.connect(func() -> void:
		await _open_party()
		if is_instance_valid(office):
			office.refresh())
	office.main_menu_requested.connect(func() -> void:
		game.save_to_disk()
		_show_main_menu(), CONNECT_ONE_SHOT)


func _on_request_chosen(request_id: String) -> void:
	await _run_expedition(ChapterData.get_request(request_id))
	game.save_to_disk()
	_show_office()


# ---------------- 공용 도우미 ----------------

## 대본 하나를 보여 주고 끝날 때까지 기다린다. ex 가 있으면 원정 효과(회복 등)도 처리한다.
## 빈 id 면 아무것도 하지 않는다.
func _play_story(script_id: String, ex: Expedition = null) -> String:
	if script_id.is_empty():
		return ""
	var runner: DialogueRunner = DialogueRunner.from_script(script_id, game.flags)
	runner.effect_handler = _apply_effect.bind(ex)
	var view := DialogueView.new()
	_show(view)
	view.play(runner)
	return await view.finished


## 가운데 선택 창을 띄우고 고른 번호를 돌려준다.
func _ask(title: String, body: String, options: Array, background: Texture2D = null, accent: Color = UiTheme.LAVENDER) -> int:
	var dialog := ChoiceDialog.new(title, body, options, background, accent)
	add_child(dialog)
	var index: int = await dialog.chosen
	dialog.queue_free()
	return index


## 전투를 띄우고 결과를 기다린다.
func _battle(encounter: EncounterData, allow_flee: bool, tips: Array[String] = []) -> BattleResult:
	var battle: BattleRoot = BattleScene.instantiate()
	battle.encounter = encounter
	battle.allow_flee = allow_flee
	battle.tips = tips
	battle.battle_finished.connect(func(won: bool) -> void: _battle_result.emit(BattleResult.new(won, false)), CONNECT_ONE_SHOT)
	battle.battle_fled.connect(func() -> void: _battle_result.emit(BattleResult.new(false, true)), CONNECT_ONE_SHOT)
	_show(battle)
	var result: BattleResult = await _battle_result
	result.hp = battle.ally_hp()
	if not result.fled:
		await get_tree().create_timer(BANNER_HOLD).timeout
	return result


## 사원 명부·창고를 겹쳐 띄우고 닫을 때까지 기다린다.
func _open_party() -> void:
	var view := PartyView.new()
	view.theme = UiTheme.get_theme()
	add_child(view)
	view.bind(game.party)
	await view.closed
	view.queue_free()


## 대본의 @effect 처리. 알림 문구를 돌려준다 (알릴 것이 없으면 빈 문자열).
func _apply_effect(effect: Dictionary, ex: Expedition) -> String:
	var args: Array = effect.get("args", [])
	var first: String = args[0] if args.size() > 0 else ""
	match effect["type"]:
		"gold":
			var amount: int = int(first)
			if ex != null:
				ex.add_gold(amount)
			else:
				game.add_gold(amount)
			return "자금 +%d" % amount
		"item":
			return _gift_item(first)
		"heal":
			if ex != null:
				ex.heal_party(float(first) / 100.0)
			return "파티 체력 %s%% 회복" % first
		"damage":
			if ex != null:
				ex.heal_party(-float(first) / 100.0)
			return "파티 체력 -%s%%" % first
		"card":
			return _gift_card()
		"lifespan":
			game.spend_lifespan(-int(first))
			return "소장 수명 %+d년" % int(first)
		"join":
			if game.add_member(first):
				return "%s 이(가) 사무소에 합류했다" % StoryCast.display_name(first)
			return ""
		"journal":
			var parts: PackedStringArray = " ".join(args).split("|", true, 1)
			game.add_journal(parts[0], parts[1] if parts.size() > 1 else "")
			return "일지 기록: %s" % parts[0]
	push_error("unknown effect: %s" % effect)
	return ""


## 장비 하나를 가방에 넣는다. item_id 가 비었거나 "random" 이면 무작위.
func _gift_item(item_id: String = "random") -> String:
	var item: ItemData = ItemPool.roll(_rng, ItemPool.load_all()) if item_id.is_empty() or item_id == "random" else Content.item(item_id)
	if item == null:
		return ""
	game.party.add_item(item)
	return "장비 획득: %s  (%s)" % [item.display_name, item.summary()]


## 무작위 파티원의 덱에 그 파티원의 보상 카드 한 장을 넣는다.
func _gift_card() -> String:
	var offers: Array[CardOffer] = Expedition.reward_cards(game, _rng, 1)
	if offers.is_empty():
		return ""
	game.add_card(offers[0].member, offers[0].card)
	return "%s 의 덱에 「%s」 추가" % [game.party.member_data(offers[0].member).display_name, offers[0].card.display_name]


# ---------------- 새 게임: 프롤로그 · 튜토리얼 ----------------

func _new_game() -> void:
	game = GameState.new()
	game.add_member("hangyeol")
	await _play_story("prologue")
	await _tutorial_battle(["rat", "rat"], "factory", TUTORIAL_TIPS_1)
	await _play_story("tutorial_mid")
	await _tutorial_battle(["husk", "rat"], "factory", TUTORIAL_TIPS_2)
	await _play_story("tutorial_deeper")
	# 이길 수 없는 연출 전투: 결과와 상관없이 이야기가 이어진다.
	await _battle(_tutorial_encounter(["hand"], "twilight"), false, HAND_TIPS)
	await _play_story("tutorial_escape")
	game.chapter = 1
	game.save_to_disk()
	_show_office()


## 선배들과 함께하는 튜토리얼 전투. 지면 다시 싸운다 (안내는 처음 한 번만).
func _tutorial_battle(enemies: Array[String], room: String, tips: Array[String]) -> void:
	var no_tips: Array[String] = []
	var first: bool = true
	while not (await _battle(_tutorial_encounter(enemies, room), false, tips if first else no_tips)).won:
		first = false
		await _ask("쓰러졌다", "선배들이 일으켜 세워 준다. 다시 해 보자.", ["다시 싸운다"])


func _tutorial_encounter(enemies: Array[String], room: String) -> EncounterData:
	var allies: Array[UnitPlacement] = []
	for entry in TUTORIAL_ALLIES:
		allies.append(Content.placement(entry[0], entry[1]))
	return Expedition.build_encounter(allies, enemies, room)


# ---------------- 원정 ----------------

func _run_expedition(request: Dictionary) -> void:
	var ex := Expedition.new(request, game, _rng)
	await _play_story(ex.script_id("briefing"))
	var intros_shown: Dictionary = {}
	while not ex.finished:
		if ex.needs_void_choice():
			await _choose_void_depth(ex)
		if ex.current_id < 0 and not intros_shown.has(ex.floor_index):
			intros_shown[ex.floor_index] = true
			await _play_story(ex.floor_intro_id(), ex)
		var node: ExpeditionNode = ex.pick(await _choose_node(ex))
		if node == null:
			continue
		await _visit(ex, node)
	await _finish_expedition(ex)


## 지도를 띄우고 고른 노드 id 를 기다린다.
func _choose_node(ex: Expedition) -> int:
	var view := ExpeditionView.new(ex)
	_show(view)
	view.party_requested.connect(func() -> void:
		await _open_party()
		if is_instance_valid(view):
			view.refresh())
	return await view.node_chosen


func _choose_void_depth(ex: Expedition) -> void:
	await _play_story(ex.script_id("void_choice"), ex)
	var body: String = "황혼층으로 내려가면 남은 구역의 적이 강해지지만(체력·공격 ×%.2f) 자금 보상이 %.1f 배가 되고 장비를 더 자주 얻습니다." % [Expedition.DEEP_ENEMY_SCALE, Expedition.DEEP_GOLD_SCALE]
	var deeper: int = await _ask("공허 속의 공허", body, ["원래 길로 간다", "황혼층으로 내려간다"], UiTheme.bg("twilight"), UiTheme.DANGER)
	ex.choose_deep(deeper == 1)


## 고른 노드를 처리한다.
func _visit(ex: Expedition, node: ExpeditionNode) -> void:
	match node.type:
		ChapterData.BATTLE, ChapterData.ELITE, ChapterData.BOSS:
			await _expedition_battle(ex, node)
		ChapterData.EVENT:
			await _play_story("events/%s" % node.event, ex)
			ex.resolve_simple(node)
		ChapterData.REST:
			ex.resolve_rest(node)
			await _ask("휴식", "물기 없는 구석을 찾아 숨을 고르고 상처를 감쌌다.\n모두 최대 체력의 %d%% 를 회복했다." % roundi(Expedition.REST_HEAL * 100), ["계속"], UiTheme.bg("void"))
		ChapterData.SUPPLY:
			var items: Array[ItemData] = ex.supply_choices()
			var supply := SupplyView.new(items)
			_show(supply)
			var pick: int = await supply.done
			if pick >= 0:
				game.party.add_item(items[pick])
			ex.resolve_simple(node)
		ChapterData.SHOP:
			var shop := ShopView.new(ex, ex.shop_stock())
			_show(shop)
			await shop.done
			ex.resolve_simple(node)


func _expedition_battle(ex: Expedition, node: ExpeditionNode) -> void:
	if node.type == ChapterData.BOSS:
		await _play_story(ex.script_id("boss"), ex)
	var result: BattleResult = await _battle(ex.encounter_for(node), true)
	if result.fled:
		# 도망치면 같은 지도로 돌아온다 (진행 없음).
		return
	if result.won:
		await _claim_reward(ex, node)
		ex.resolve_battle_win(node, result.hp)
		return
	var options: Array = [{"text": "되살아난다", "desc": "소장 수명 -1년, 전원 체력 회복", "disabled": game.lifespan <= 0}, {"text": "철수한다", "desc": "원정을 포기하고 사무소로"}]
	var pick: int = await _ask("의식이 가라앉는다…", "검은 기름이 발목까지 차오른다.\n남은 소장 수명: %d년" % game.lifespan, options, UiTheme.bg("void"), UiTheme.DANGER)
	if pick == 0:
		game.spend_lifespan(1)
		ex.revive()
	else:
		ex.retreat()


## 보상을 주고 카드 한 장을 고르게 한다.
func _claim_reward(ex: Expedition, node: ExpeditionNode) -> void:
	var reward: BattleReward = ex.battle_reward(node)
	ex.add_gold(reward.gold)
	if reward.item != null:
		game.party.add_item(reward.item)
	var view := RewardView.new(reward, game, "핵의 수호자 격파" if node.type == ChapterData.BOSS else "전투 승리")
	_show(view)
	var choice: int = await view.done
	if choice >= 0:
		game.add_card(reward.cards[choice].member, reward.cards[choice].card)


func _finish_expedition(ex: Expedition) -> void:
	if ex.outcome != "clear":
		await _ask("철수", "핵을 두고 물러났다. 다음에 다시 도전할 수 있다.\n이번 원정에서 번 자금: %d" % ex.gold_earned, ["사무소로"], UiTheme.bg("sewer_gate"))
		return
	if not ex.is_story():
		await _ask("의뢰 완료", "잔재를 모두 치웠다.\n이번 원정에서 번 자금: %d" % ex.gold_earned, ["사무소로"], UiTheme.bg("sewer_gate"))
		return
	await _play_story(ex.script_id("purify"), ex)
	var god: int = await _ask("정화", "핵을 땅에 내려놓고, 신의 이름을 부른다.\n어느 신의 힘을 빌릴까?", GODS, UiTheme.bg("core_room"), UiTheme.TEAL)
	var bonus: String = ""
	match god:
		0:
			game.add_gold(PURIFY_GOLD)
			bonus = "자금 +%d" % PURIFY_GOLD
		1:
			bonus = _gift_item()
		2:
			bonus = _gift_card()
	await _ask("정화 완료", "청록빛이 하늘로 솟구치고, 균열이 안쪽으로 접혀 사라졌다.\n%s" % bonus, ["사무소로"], UiTheme.bg("core_room"), UiTheme.TEAL)
	await _play_story(ex.script_id("epilogue"))
	game.chapter = maxi(game.chapter, int(ex.request.get("unlocks_chapter", game.chapter)))
