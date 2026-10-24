## 전투 보상: 자금·장비 표시 + 카드 3장 중 하나를 골라 그 사원의 덱에 넣는다 (건너뛸 수 있다).
## done(index): 고른 카드 번호, 건너뛰면 -1.
class_name RewardView
extends Control

signal done(index: int)

const CARD_SCALE: float = 1.9

var _reward: BattleReward
var _game: GameState
var _title: String


func _init(reward: BattleReward, game: GameState, title: String = "전투 승리") -> void:
	_reward = reward
	_game = game
	_title = title


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiTheme.backdrop(UiTheme.bg("void"), 0.6))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	center.add_child(col)
	var title := UiTheme.title_label(_title, 52, UiTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var loot: PackedStringArray = ["자금 +%d" % _reward.gold]
	var item: ItemData = _reward.item
	if item != null:
		loot.append("장비 획득: %s (%s)" % [item.display_name, item.summary()])
	var loot_label := UiTheme.label("   ·   ".join(loot), 24, UiTheme.TEXT)
	loot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(loot_label)
	var cards: Array[CardOffer] = _reward.cards
	if not cards.is_empty():
		var hint := UiTheme.label("카드 한 장을 골라 덱에 넣으세요", 20, UiTheme.TEXT_DIM)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(hint)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 48)
		col.add_child(row)
		for i in cards.size():
			row.add_child(_card_choice(cards[i], i))
	var skip := UiTheme.button("건너뛰기" if not cards.is_empty() else "계속", Vector2(240, 56))
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(func() -> void: done.emit(-1))
	col.add_child(skip)


func _card_choice(offer: CardOffer, index: int) -> Control:
	var data: AllyData = _game.party.member_data(offer.member)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	var who := UiTheme.label(data.display_name, 22, UiTheme.LAVENDER)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(who)
	col.add_child(CardView.preview(offer.card, data, CARD_SCALE))
	var pick := UiTheme.button("선택", Vector2(0, 52))
	pick.pressed.connect(func() -> void: done.emit(index))
	col.add_child(pick)
	return col
