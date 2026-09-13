class_name BattleHud
extends Control

signal card_selected(index: int)
signal card_dropped(index: int, screen_position: Vector2)
signal end_turn_pressed

const CURRENT_TURN_COLOR := Color(1.0, 0.82, 0.3)
const ACTED_COLOR := Color(0.5, 0.5, 0.5)
const RESHUFFLE_GHOSTS_MAX: int = 6
const DISCARD_PILE_NAME: String = "묘지"

@onready var _turn_label: RichTextLabel = %TurnLabel
@onready var _sp_panel: PanelContainer = %SpPanel
@onready var _sp_label: Label = %SpLabel
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _log: RichTextLabel = %BattleLog
@onready var _banner: Label = %Banner
@onready var _hand: HandView = %HandView
@onready var _deck_pile: PileView = %DeckPile
@onready var _discard_pile: PileView = %DiscardPile

var _interactive: bool = false


func _ready() -> void:
	_end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	_hand.card_selected.connect(_on_hand_card_selected)
	_hand.card_dropped.connect(_on_hand_card_dropped)
	_discard_pile.set_owner_name(DISCARD_PILE_NAME)
	_refresh_sp(null)
	_apply_interactive()


func sync_from_state(state: BattleState, selected_card: int) -> void:
	var actor: Unit = null if state.finished else state.current_unit()
	_refresh_sp(actor)
	if actor != null and actor.is_ally():
		_hand.set_cards(actor.hand, actor.sp, selected_card)
		_show_piles(actor.data.display_name, actor.deck.size(), actor.discard.size())
	else:
		_clear_hand(0)
		_dim_piles()
	if state.finished:
		_turn_label.text = "승리!" if state.ally_won else "패배..."
		return
	var alive: Array[bool] = []
	for member in state.initiative:
		alive.append(member.is_alive())
	_turn_label.text = turn_bar_text(state.round_index, state.initiative, alive, state.turn_index)


func show_turn(event: BattleEvent) -> void:
	_turn_label.text = turn_bar_text(event.round_index, event.order, event.alive, event.turn_index)
	if event.unit.is_ally():
		_clear_hand(event.unit.sp)
		_refresh_sp(event.unit)
		_show_piles(event.unit.data.display_name, event.deck_count, event.discard_count)
	else:
		_clear_hand(0)
		_refresh_sp(null)
		_dim_piles()


func set_interactive(enabled: bool) -> void:
	_interactive = enabled
	_hand.interactive = enabled
	_apply_interactive()


func set_pending_play(index: int) -> void:
	_hand.set_pending_play(index)


func draw_card(event: BattleEvent) -> void:
	_hand.draw_card(event.card, _deck_pile.center_global())
	_set_counts(event.deck_count, event.discard_count)


func reshuffle(event: BattleEvent) -> void:
	_hand.fly_backs(_discard_pile.center_global(), _deck_pile.center_global(), mini(event.amount, RESHUFFLE_GHOSTS_MAX))
	_set_counts(event.deck_count, event.discard_count)


func discard_hand(event: BattleEvent) -> void:
	_hand.discard_all(_discard_pile.center_global())
	_set_counts(event.deck_count, event.discard_count)


func remove_played_card(event: BattleEvent) -> void:
	_hand.remove_card(event.card)
	_hand.set_sp(event.unit.sp)
	_refresh_sp(event.unit)
	_set_counts(event.deck_count, event.discard_count)


func append_log(text: String) -> void:
	_log.append_text(text + "\n")


func show_banner(ally_won: bool) -> void:
	_banner.text = "승리!" if ally_won else "패배..."
	_banner.visible = true


func hand_view() -> HandView:
	return _hand


func deck_pile() -> PileView:
	return _deck_pile


func discard_pile() -> PileView:
	return _discard_pile


func sp_text() -> String:
	return _sp_label.text if _sp_panel.visible else ""


func log_text() -> String:
	return _log.get_parsed_text()


func end_turn_enabled() -> bool:
	return not _end_turn_button.disabled


func banner_visible() -> bool:
	return _banner.visible


func banner_text() -> String:
	return _banner.text


static func turn_bar_text(round_index: int, order: Array[Unit], alive: Array[bool], turn_index: int) -> String:
	var parts: PackedStringArray = []
	for i in order.size():
		if not alive[i]:
			continue
		var unit_name: String = order[i].data.display_name
		if i < turn_index:
			parts.append("[color=#%s]%s[/color]" % [ACTED_COLOR.to_html(false), unit_name])
		elif i == turn_index:
			parts.append("[b][color=#%s]▶%s[/color][/b]" % [CURRENT_TURN_COLOR.to_html(false), unit_name])
		else:
			parts.append(unit_name)
	return "R%d  %s" % [round_index, " → ".join(parts)]


func _refresh_sp(actor: Unit) -> void:
	_sp_panel.visible = actor != null and actor.is_ally()
	if not _sp_panel.visible:
		return
	var max_sp: int = (actor.data as AllyData).max_sp
	var pips: String = "●".repeat(actor.sp) + "○".repeat(maxi(max_sp - actor.sp, 0))
	_sp_label.text = "SP\n%s\n%d / %d" % [pips, actor.sp, max_sp]


func _clear_hand(sp: int) -> void:
	var none: Array[CardData] = []
	_hand.set_cards(none, sp, -1)


func _show_piles(owner_name: String, deck_count: int, discard_count: int) -> void:
	_deck_pile.set_owner_name(owner_name)
	_set_counts(deck_count, discard_count)
	_deck_pile.set_dimmed(false)
	_discard_pile.set_dimmed(false)


func _dim_piles() -> void:
	_deck_pile.set_dimmed(true)
	_discard_pile.set_dimmed(true)


func _set_counts(deck_count: int, discard_count: int) -> void:
	_deck_pile.set_count(deck_count)
	_discard_pile.set_count(discard_count)


func _apply_interactive() -> void:
	_end_turn_button.disabled = not _interactive


func _on_hand_card_selected(index: int) -> void:
	card_selected.emit(index)


func _on_hand_card_dropped(index: int, screen_position: Vector2) -> void:
	card_dropped.emit(index, screen_position)


func _on_end_turn_button_pressed() -> void:
	end_turn_pressed.emit()
