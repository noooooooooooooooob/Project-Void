# 카드 연출 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 버튼 손패를 부채꼴 카드로 바꾸고, 덱·묘지 더미와 드로우·리셔플·손패 버리기 연출, 클릭·드래그 카드 사용을 넣는다.

**Architecture:** `BattleState` 가 카드 한 장 단위로 `card_drawn` / `deck_reshuffled` / `hand_discarded` 신호를 낸다. 기존 `BattleEventRecorder` → `BattlePlayback` 흐름에 이벤트 3종을 추가하고, `BattleHud` 가 `HandView`(부채꼴 손패) · `PileView`(더미)에 연출을 위임한다. 드래그 놓기는 `Board3D.request_pick` 으로 기존 클릭 판정 경로를 재사용한다.

**Tech Stack:** Godot 4.7.2 (stable), GDScript (타입 명시), 자체 헤드리스 테스트 러너

**Spec:** `docs/superpowers/specs/2026-09-13-card-presentation-design.md`

## Global Constraints

- Godot 4.7.2. 엔진 버전 올리지 말 것.
- Godot 실행 파일: `C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe` (MCP 서버 설정 경로 `C:\Program Files\Godot\Godot.exe` 는 없다)
- 타입 명시 GDScript. 모든 함수에 `-> ReturnType`, 모든 `var` 에 타입.
- 외부 애드온/의존성 추가 금지.
- 규칙 코어(`Scripts/combat/`) 는 `Node` 를 상속하거나 참조하지 않는다. 뽑는 장수, 섞는 방식과 난수 소비 순서, 버리는 시점은 바꾸지 않는다. 신호는 `BattleState` 안에서만 낸다.
- 난수는 `BattleState.rng` 로만.
- 전역 함수와 이름이 겹치는 식별자 금지: `range`, `log`, `sign`, 그리고 Node 속성과 겹치는 `name` (지역 변수·매개변수). `owner_name`, `unit_name` 등을 쓴다.
- 주석은 WHY 가 비자명할 때만.
- 테스트 명령: `& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --script res://tests/run_tests.gd` — 전면(동기) 실행, timeout 5분. `[MCP Runtime] ...` 줄은 정상.
- 새 `class_name` 스크립트를 추가하면 테스트 전에 클래스 캐시 갱신: `& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --editor --quit --path "C:\Users\User\Desktop\Godot\Project-Void"`. "Could not find type X" 는 캐시 문제다 — preload 우회 금지.
- 헤드리스 테스트에서 노드를 트리에 붙일 때: `(Engine.get_main_loop() as SceneTree).root.add_child(node)`, 테스트 끝에 `node.free()`. 러너는 첫 `_process` 프레임에서 실행되므로 `_ready` 가 돈다.
- 새 `.gd` 마다 Godot 가 만드는 `.gd.uid` 를 같이 커밋한다.
- 작업 트리에는 무관한 미커밋 변경(`Resources/*.tres` uid 줄, 미추적 `CLAUDE.md`, 미추적 `Scenes/battle.tscn`)이 있다. 건드리지 말고 태스크가 지정한 파일만 `git add`. `git add -A` / `git add .` 금지.
- 커밋 메시지: 제목 한 줄, 빈 줄, 트레일러 두 줄. Bash heredoc(`git commit -F - <<'MSG' ... MSG`)으로 넘긴다.
  ```
  Co-Authored-By: <커밋을 만든 Claude 모델 이름> <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_016mWJpHQu18LvtDTZoFSsZq
  ```
- 게임 실행(실행 검증): `Start-Process -FilePath "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" -ArgumentList '--path "C:\Users\User\Desktop\Godot\Project-Void"' -PassThru`, 끝나면 `Stop-Process -Id <pid>`. 게임이 떠 있는 동안 헤드리스 명령을 돌리지 않는다(포트 7777).
- MCP 입력 주입: `inject-mouse-motion` 을 먼저 보내고, `inject-mouse-click` 은 누르기(`pressed: true`)와 떼기(`pressed: false`)를 짝으로. 드래그는 누르기 → motion 여러 번 → 떼기.
- 게임 로그: `%APPDATA%\Godot\app_userdata\Project Void\logs\godot.log` 에서 `SCRIPT ERROR` 확인.

## 스펙과 다른 점 (계획 단계에서 정함)

| 스펙 | 계획 | 이유 |
|---|---|---|
| 8.1 리셔플 순서 테스트 예시 "덱 2장·묘지 3장" | 덱 6장으로 시작 → 4장 드로우 → 차례 종료(묘지 4, 덱 2) → 다음 드로우에서 `drawn, drawn, reshuffled(4), drawn, drawn` | 실제 게임 흐름(start_battle → end_turn)만으로 같은 상황을 만들 수 있어 규칙 내부를 조작하지 않는다 |
| `HandView` 메서드 목록 | `set_interactive` 세터 속성, `fly_backs(from_global, to_global, count)`(리셔플 유령 카드), `is_aiming()` 추가 | HUD 가 카드 뒷면 그리기를 중복하지 않게 하고, 드래그 화살표 상태를 테스트한다 |
| `CardView` | `static make_back() -> Panel` 추가 | 카드 뒷면·더미·리셔플 유령 카드가 같은 뒷면을 쓴다 |
| `PileView` | `is_dimmed()` 추가 | 흐림 상태 테스트 |

## 파일 구조

| 경로 | 책임 |
|---|---|
| `Scripts/combat/unit.gd` (수정) | `reshuffle_discard`, `draw_one`, `draw` 가 둘을 사용 |
| `Scripts/combat/battle_state.gd` (수정) | 신호 3종, `_draw_cards`, `_discard_hand` |
| `Scripts/view/battle_event.gd` (수정) | 종류 3개, 필드 `cards` / `deck_count` / `discard_count` |
| `Scripts/view/battle_event_recorder.gd` (수정) | 새 신호 기록, 장수 스냅샷 |
| `Scripts/ui/cards/card_view.gd` | 카드 1장 |
| `Scripts/ui/cards/pile_view.gd` | 덱/묘지 더미 |
| `Scripts/ui/cards/hand_layout.gd` | 부채꼴 계산 |
| `Scripts/ui/cards/aim_arrow.gd` | 조준 화살표 그리기 |
| `Scripts/ui/cards/hand_view.gd` | 손패 배치·선택·드래그·연출 |
| `Scenes/battle_hud.tscn`, `Scripts/ui/battle_hud.gd` (수정) | 손패·더미 통합, 배치 변경 |
| `Scripts/view/battle_playback.gd` (수정) | 새 이벤트 재생 |
| `Scripts/view/board_3d.gd` (수정) | `request_pick`, `pick_missed` |
| `Scripts/view/battle_root.gd` (수정) | 드래그 놓기, `set_pending_play` |
| `tests/test_card_zone_signals.gd`, `test_card_view.gd`, `test_pile_view.gd`, `test_hand_layout.gd`, `test_hand_view.gd` (신규), `test_event_recorder.gd`, `test_battle_hud.gd`, `test_battle_playback.gd` (수정) | 헤드리스 테스트 |

테스트 합계 흐름: 현재 251 → T1 261 → T2 272 → T3 302 → T4 325 → T5 339 → T6 347 → T7 347.

---

### Task 1: 카드 존 신호 (드로우 · 리셔플 · 손패 버리기)

**Files:**
- Modify: `Scripts/combat/unit.gd` (`draw` 분리)
- Modify: `Scripts/combat/battle_state.gd` (신호 3종, `_draw_cards`, `_discard_hand`)
- Create: `tests/test_card_zone_signals.gd`
- Modify: `tests/run_tests.gd` (`TEST_SCRIPTS` 끝에 `"res://tests/test_card_zone_signals.gd",`)

**Interfaces:**
- Consumes: 기존 `Unit.deck/hand/discard`, `Unit._shuffle`, `Unit.discard_hand()`, `BattleState._run_until_player_input()`, `BattleState.end_turn()`
- Produces:
  - `Unit.reshuffle_discard(rng: RandomNumberGenerator) -> int`, `Unit.draw_one() -> CardData`
  - `BattleState.deck_reshuffled(unit: Unit, count: int)`
  - `BattleState.card_drawn(unit: Unit, card: CardData, deck_count: int, discard_count: int)` — 뽑은 직후 장수
  - `BattleState.hand_discarded(unit: Unit, cards: Array[CardData], discard_count: int)` — 버린 직후 묘지 장수, 손패가 비어도 발생
  - 순서: 아군 차례 시작 `turn_started` → (`deck_reshuffled`) → `card_drawn` ×4, 차례 종료 `hand_discarded` → 다음 유닛들

- [ ] **Step 1: 실패하는 테스트 작성**

Create `tests/test_card_zone_signals.gd`:

```gdscript
extends TestCase

const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
const UnitScript := preload("res://Scripts/combat/unit.gd")
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")

const SEED: int = 2024


func run() -> Array[Dictionary]:
	_test_draw_reports_counts()
	_test_reshuffle_happens_mid_draw()
	_test_draw_stops_when_deck_and_discard_are_empty()
	_test_hand_discarded_carries_cards()
	_test_state_draw_matches_unit_draw()
	return results()


func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


# 서로 구분되는 카드 c0..c(n-1) 로 된 덱을 가진 아군 a(속도 10).
func _ally(deck_size: int) -> AllyData:
	var data: AllyData = AllyDataScript.new()
	data.id = &"a"
	data.display_name = "a"
	data.max_hp = 30
	data.speed = 10
	data.max_sp = 3
	var deck: Array[CardData] = []
	for i in deck_size:
		var card: CardData = CardDataScript.new()
		card.id = StringName("c%d" % i)
		card.display_name = "c%d" % i
		deck.append(card)
	data.deck = deck
	return data


# 적 e(속도 1)는 기본 근접 공격으로 아군을 치기만 한다. 카드와 난수에 영향이 없다.
func _state(ally: AllyData) -> BattleState:
	var enemy: EnemyData = EnemyDataScript.new()
	enemy.id = &"e"
	enemy.display_name = "e"
	enemy.max_hp = 20
	enemy.speed = 1

	var encounter: EncounterData = EncounterScript.new()
	var allies: Array[UnitPlacement] = [_placement(ally, Vector2i(0, 1))]
	var enemies: Array[UnitPlacement] = [_placement(enemy, Vector2i(0, 1))]
	encounter.ally_units = allies
	encounter.enemy_units = enemies
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	return BattleStateScript.new(encounter, rng)


func _record(state: BattleState) -> Array:
	var seen: Array = []
	state.card_drawn.connect(func(_unit: Unit, _card: CardData, deck_count: int, discard_count: int) -> void:
		seen.append("drawn:%d:%d" % [deck_count, discard_count]))
	state.deck_reshuffled.connect(func(_unit: Unit, count: int) -> void:
		seen.append("reshuffled:%d" % count))
	state.hand_discarded.connect(func(_unit: Unit, cards: Array[CardData], discard_count: int) -> void:
		seen.append("discarded:%d:%d" % [cards.size(), discard_count]))
	return seen


func _ids(cards: Array[CardData]) -> Array:
	var ids: Array = []
	for card in cards:
		ids.append(card.id)
	return ids


func _test_draw_reports_counts() -> void:
	var state: BattleState = _state(_ally(6))
	var seen: Array = _record(state)
	state.start_battle()
	check_eq("four draws with shrinking deck", seen, ["drawn:5:0", "drawn:4:0", "drawn:3:0", "drawn:2:0"])
	check_eq("hand holds four cards", state.living_units(Unit.Team.ALLY)[0].hand.size(), 4)


func _test_reshuffle_happens_mid_draw() -> void:
	var state: BattleState = _state(_ally(6))
	state.start_battle()
	var seen: Array = _record(state)
	# 차례 종료 → 적 차례 → 같은 아군의 다음 차례 드로우까지 이어진다. 덱 2장, 묘지 4장에서 시작한다.
	state.end_turn()
	check_eq("discard, two draws, reshuffle, two draws", seen,
		["discarded:4:4", "drawn:1:4", "drawn:0:4", "reshuffled:4", "drawn:3:0", "drawn:2:0"])
	check_eq("hand refilled to four", state.living_units(Unit.Team.ALLY)[0].hand.size(), 4)


func _test_draw_stops_when_deck_and_discard_are_empty() -> void:
	var state: BattleState = _state(_ally(2))
	var seen: Array = _record(state)
	state.start_battle()
	check_eq("only two draws, no reshuffle", seen, ["drawn:1:0", "drawn:0:0"])
	check_eq("hand holds two cards", state.living_units(Unit.Team.ALLY)[0].hand.size(), 2)


func _test_hand_discarded_carries_cards() -> void:
	var state: BattleState = _state(_ally(6))
	state.start_battle()
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	var before: Array[CardData] = ally.hand.duplicate()
	var discarded: Array = []
	state.hand_discarded.connect(func(_unit: Unit, cards: Array[CardData], discard_count: int) -> void:
		discarded.append([cards.duplicate(), discard_count]))

	state.end_turn()
	check_eq("discarded cards in hand order", discarded[0][0], before)
	check_eq("discard count right after discarding", discarded[0][1], 4)


func _test_state_draw_matches_unit_draw() -> void:
	var data: AllyData = _ally(6)
	var state: BattleState = _state(data)
	state.start_battle()
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	var first_hand: Array = _ids(ally.hand)
	state.end_turn()
	var second_hand: Array = _ids(ally.hand)

	# BattleState 생성자는 아군 덱을 한 번 섞고, 적 행동은 난수를 쓰지 않는다.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var reference: Unit = UnitScript.new(0, data, Unit.Team.ALLY, Vector2i(0, 1))
	reference.shuffle_deck(rng)
	reference.draw(BattleState.DRAW_PER_TURN, rng)
	check_eq("first hand matches Unit.draw", first_hand, _ids(reference.hand))
	reference.discard_hand()
	reference.draw(BattleState.DRAW_PER_TURN, rng)
	check_eq("second hand, across a reshuffle, matches Unit.draw", second_hand, _ids(reference.hand))
```

- [ ] **Step 2: 실패 확인**

Run: 테스트 명령

Expected: `test_card_zone_signals.gd` 로드 또는 실행 실패 (`card_drawn` 등 신호 없음, 러너에 해당 스위트 FAIL 줄). 나머지 251개 PASS.

- [ ] **Step 3: `Unit.draw` 분리**

`Scripts/combat/unit.gd` 의 `draw()` 를 아래 세 함수로 교체한다 (`shuffle_deck()` 과 `discard_hand()` 사이):

```gdscript
func reshuffle_discard(rng: RandomNumberGenerator) -> int:
	var count: int = discard.size()
	deck.append_array(discard)
	discard.clear()
	_shuffle(deck, rng)
	return count


func draw_one() -> CardData:
	if deck.is_empty():
		return null
	var card: CardData = deck.pop_front()
	hand.append(card)
	return card


func draw(count: int, rng: RandomNumberGenerator) -> void:
	for _i in count:
		if deck.is_empty():
			if discard.is_empty():
				return
			reshuffle_discard(rng)
		draw_one()
```

`reshuffle_discard` 는 덱이 빈 상태에서만 부른다. 기존 구현(`deck = discard.duplicate()` 후 섞기)과 섞는 대상·난수 소비가 같다.

- [ ] **Step 4: `BattleState` 신호와 통로**

`Scripts/combat/battle_state.gd` 의 신호 선언 끝에 추가:

```gdscript
signal deck_reshuffled(unit: Unit, count: int)
signal card_drawn(unit: Unit, card: CardData, deck_count: int, discard_count: int)
signal hand_discarded(unit: Unit, cards: Array[CardData], discard_count: int)
```

`end_turn()` 에서 `actor.discard_hand()` 를 `_discard_hand(actor)` 로 바꾼다:

```gdscript
func end_turn() -> void:
	var actor: Unit = current_unit()
	if actor != null and actor.is_ally():
		_discard_hand(actor)
	_run_until_player_input()
```

`_run_until_player_input()` 에서 `actor.draw(DRAW_PER_TURN, rng)` 를 `_draw_cards(actor, DRAW_PER_TURN)` 로 바꾼다.

`_take_enemy_turn()` 위에 추가:

```gdscript
# Unit.draw 와 같은 순서로 한 장씩 진행하되, 화면이 순서대로 연출할 수 있게 매 단계 신호를 낸다.
func _draw_cards(actor: Unit, count: int) -> void:
	for _i in count:
		if actor.deck.is_empty():
			if actor.discard.is_empty():
				return
			deck_reshuffled.emit(actor, actor.reshuffle_discard(rng))
		var card: CardData = actor.draw_one()
		card_drawn.emit(actor, card, actor.deck.size(), actor.discard.size())


func _discard_hand(actor: Unit) -> void:
	var cards: Array[CardData] = actor.hand.duplicate()
	actor.discard_hand()
	hand_discarded.emit(actor, cards, actor.discard.size())
```

- [ ] **Step 5: 통과 확인**

Run: 테스트 명령

Expected: `261/261 passed` (251 + 신규 10). 기존 `test_unit.gd` 의 드로우·리셔플 테스트도 그대로 PASS.

- [ ] **Step 6: 커밋**

```bash
git add Scripts/combat/unit.gd Scripts/combat/battle_state.gd tests/test_card_zone_signals.gd tests/test_card_zone_signals.gd.uid tests/run_tests.gd
git commit -F - <<'MSG'
feat: emit draw, reshuffle and hand-discard signals from battle state

Co-Authored-By: <model> <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016mWJpHQu18LvtDTZoFSsZq
MSG
```

---

### Task 2: 카드 존 이벤트 기록

**Files:**
- Modify: `Scripts/view/battle_event.gd`
- Modify: `Scripts/view/battle_event_recorder.gd`
- Modify: `tests/test_event_recorder.gd`

**Interfaces:**
- Consumes: Task 1 신호 3종, 기존 `turn_started`, `card_played`
- Produces:
  - `BattleEvent.Kind` 끝에 `CARD_DRAWN, DECK_RESHUFFLED, HAND_DISCARDED` 추가 (기존 값 순서 유지)
  - `BattleEvent` 필드 `cards: Array[CardData]`, `deck_count: int`, `discard_count: int`
  - 채우는 값:
    - `CARD_DRAWN`: unit, card, deck_count, discard_count (신호 인자)
    - `DECK_RESHUFFLED`: unit, amount(되돌린 장수), deck_count·discard_count(신호 순간 `unit.deck/discard.size()`)
    - `HAND_DISCARDED`: unit, cards(복사), discard_count(신호 인자), deck_count(`unit.deck.size()`)
    - `TURN_STARTED`, `CARD_PLAYED`: 기존 필드 + deck_count·discard_count (신호 순간 값)

- [ ] **Step 1: 기존 테스트를 새 이벤트 순서에 맞추고 새 테스트 추가 (실패하는 테스트)**

`tests/test_event_recorder.gd` 에서 기존 파일의 `Kind` 표기 방식(`var k := BattleEvent.Kind` 또는 풀어 쓴 `BattleEvent.Kind.X`)을 그대로 따른다.

`_test_start_battle_records_first_turn()` 전체를 교체:

```gdscript
func _test_start_battle_records_first_turn() -> void:
	var state: BattleState = _state(1, 2)
	var recorder := BattleEventRecorder.new(state)
	state.start_battle()
	var events: Array[BattleEvent] = recorder.take_events()
	var k := BattleEvent.Kind

	check_eq("turn start then the single draw", _kinds(events), [k.TURN_STARTED, k.CARD_DRAWN])
	check("subject is the ally", events[0].unit.is_ally())
	check_eq("round snapshot", events[0].round_index, 1)
	check_eq("turn index snapshot", events[0].turn_index, 0)
	check_eq("order has every unit", events[0].order.size(), 3)
	check_eq("alive flags", events[0].alive, [true, true, true])
	check_eq("hp snapshot", events[0].hp, 30)
	check_eq("deck snapshot before the draw", events[0].deck_count, 1)
	check_eq("discard snapshot before the draw", events[0].discard_count, 0)
	check_eq("take_events empties the queue", recorder.take_events().size(), 0)
```

`_test_end_turn_records_enemies_in_order()` 전체를 교체 (아군 덱은 zap 1장뿐이라, 차례 종료에 버리고 다음 차례에 리셔플 후 뽑는다):

```gdscript
func _test_end_turn_records_enemies_in_order() -> void:
	var state: BattleState = _state(1, 2)
	var recorder := BattleEventRecorder.new(state)
	state.start_battle()
	recorder.take_events()
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]

	state.end_turn()
	var events: Array[BattleEvent] = recorder.take_events()
	var k := BattleEvent.Kind
	check_eq("event kinds in play order", _kinds(events), [
		k.HAND_DISCARDED,
		k.TURN_STARTED, k.ENEMY_ACTED, k.LOG, k.DAMAGED,
		k.TURN_STARTED, k.ENEMY_ACTED, k.LOG, k.DAMAGED,
		k.TURN_STARTED, k.DECK_RESHUFFLED, k.CARD_DRAWN,
	])
	check_eq("faster enemy acts first", events[1].unit.data.id, &"e1")
	check_eq("attack targets the ally", events[2].target.data.id, &"a")
	check_eq("first hit snapshot", events[4].hp, 26)
	check_eq("second hit snapshot", events[8].hp, 23)
	check_eq("last snapshot matches state", events[8].hp, ally.hp)
	check_eq("ally's next turn is round 2", events[9].round_index, 2)
```

`_test_card_play_records_action_then_damage()` 의 마지막 `check_eq("damage hp snapshot", ...)` 뒤에 추가:

```gdscript
	check_eq("deck after playing", events[0].deck_count, 0)
	check_eq("discard after playing", events[0].discard_count, 1)
```

새 테스트 함수를 파일 끝에 추가하고 `run()` 의 마지막 호출 뒤에 `_test_card_zone_events_snapshot()` 을 넣는다:

```gdscript
func _test_card_zone_events_snapshot() -> void:
	var state: BattleState = _state(1, 2)
	var recorder := BattleEventRecorder.new(state)
	state.start_battle()
	recorder.take_events()

	state.end_turn()
	var events: Array[BattleEvent] = recorder.take_events()
	var discarded: BattleEvent = events[0]
	var reshuffled: BattleEvent = events[10]
	var drawn: BattleEvent = events[11]
	check_eq("discarded cards", discarded.cards.size(), 1)
	check_eq("discard pile after discarding", discarded.discard_count, 1)
	check_eq("deck when discarding", discarded.deck_count, 0)
	check_eq("reshuffled amount", reshuffled.amount, 1)
	check_eq("deck after reshuffle", reshuffled.deck_count, 1)
	check_eq("discard after reshuffle", reshuffled.discard_count, 0)
	check_eq("drawn card", drawn.card.id, &"zap")
	check_eq("deck after the draw", drawn.deck_count, 0)
```

- [ ] **Step 2: 실패 확인**

Run: 테스트 명령

Expected: `test_event_recorder.gd` 가 로드 실패(`CARD_DRAWN`, `deck_count` 없음)하거나 해당 FAIL. 나머지 PASS.

- [ ] **Step 3: `BattleEvent` 확장**

`Scripts/view/battle_event.gd` 의 enum 을 교체하고 필드를 추가:

```gdscript
enum Kind { TURN_STARTED, CARD_PLAYED, ENEMY_ACTED, DAMAGED, HEALED, BLOCK_GAINED, DIED, LOG, BATTLE_ENDED, CARD_DRAWN, DECK_RESHUFFLED, HAND_DISCARDED }
```

`var turn_index: int = -1` 아래에:

```gdscript
var cards: Array[CardData] = []
var deck_count: int = 0
var discard_count: int = 0
```

- [ ] **Step 4: 기록기 확장**

`Scripts/view/battle_event_recorder.gd` 의 `_init` 연결 목록 끝에:

```gdscript
	state.card_drawn.connect(_on_card_drawn)
	state.deck_reshuffled.connect(_on_deck_reshuffled)
	state.hand_discarded.connect(_on_hand_discarded)
```

`_on_turn_started` 의 `_events.append(event)` 바로 앞에:

```gdscript
	event.deck_count = unit.deck.size()
	event.discard_count = unit.discard.size()
```

`_on_card_played` 의 `_events.append(event)` 바로 앞에:

```gdscript
	event.deck_count = actor.deck.size()
	event.discard_count = actor.discard.size()
```

파일 끝에 추가:

```gdscript
func _on_card_drawn(unit: Unit, card: CardData, deck_count: int, discard_count: int) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.CARD_DRAWN)
	event.unit = unit
	event.card = card
	event.deck_count = deck_count
	event.discard_count = discard_count
	_events.append(event)


func _on_deck_reshuffled(unit: Unit, count: int) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.DECK_RESHUFFLED)
	event.unit = unit
	event.amount = count
	event.deck_count = unit.deck.size()
	event.discard_count = unit.discard.size()
	_events.append(event)


func _on_hand_discarded(unit: Unit, cards: Array[CardData], discard_count: int) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.HAND_DISCARDED)
	event.unit = unit
	event.cards = cards.duplicate()
	event.discard_count = discard_count
	event.deck_count = unit.deck.size()
	_events.append(event)
```

- [ ] **Step 5: 통과 확인**

Run: 테스트 명령

Expected: `272/272 passed` (261 + 신규 11: 첫 차례 테스트 +1, 카드 사용 테스트 +2, 새 테스트 8). `test_battle_playback.gd` 도 PASS — 재생기는 아직 새 종류를 무시한다.

- [ ] **Step 6: 커밋**

```bash
git add Scripts/view/battle_event.gd Scripts/view/battle_event_recorder.gd tests/test_event_recorder.gd
git commit -F - <<'MSG'
feat: record draw, reshuffle and discard events with pile counts

Co-Authored-By: <model> <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016mWJpHQu18LvtDTZoFSsZq
MSG
```

---

### Task 3: 카드 한 장, 더미, 부채꼴 계산

**Files:**
- Create: `Scripts/ui/cards/card_view.gd`, `Scripts/ui/cards/pile_view.gd`, `Scripts/ui/cards/hand_layout.gd`
- Create: `tests/test_card_view.gd`, `tests/test_pile_view.gd`, `tests/test_hand_layout.gd`
- Modify: `tests/run_tests.gd` (세 파일을 `TEST_SCRIPTS` 끝에 추가)

**Interfaces:**
- Consumes: `CardData` (`display_name`, `sp_cost`, `attack_type`, `shape`, `attack_range`, `damage`)
- Produces:
  - `class_name CardView extends Control`
    - 상수 `SIZE = Vector2(110, 154)`, `MELEE_COLOR = Color(0.85, 0.4, 0.35)`, `RANGED_COLOR = Color(0.4, 0.6, 0.95)`, `BACK_COLOR = Color(0.18, 0.22, 0.38)`, `UNAFFORDABLE_MODULATE = Color(1, 1, 1, 0.55)`
    - 필드 `card: CardData`
    - `setup(p_card: CardData) -> void` (트리 밖에서도 동작, `pivot_offset = SIZE / 2`, `mouse_filter = STOP`)
    - `set_face_up(face_up: bool) -> void`, `is_face_up() -> bool`, `set_affordable(affordable: bool) -> void`
    - `cost_text() -> String`, `name_text() -> String`, `damage_text() -> String`, `footer_text() -> String`, `border_color() -> Color`
    - `static make_back() -> Panel` — `CardView.SIZE` 크기 뒷면 패널 (mouse IGNORE)
  - `class_name PileView extends Control` — 자식은 `_init` 에서 만든다 (씬에 스크립트만 붙여도 동작)
    - 상수 `SIZE = Vector2(90, 126)`, `DIM_MODULATE = Color(1, 1, 1, 0.4)`
    - `set_owner_name(owner_name: String)`, `set_count(count: int)`, `set_dimmed(dimmed: bool)`, `is_dimmed() -> bool`, `count_text() -> String`, `owner_text() -> String`, `center_global() -> Vector2`
  - `class_name HandLayout extends RefCounted`
    - 상수 `CARD_ANGLE_DEG = 6.0`, `MAX_SPREAD_DEG = 40.0`, `RADIUS = 900.0`
    - `static slot(index: int, count: int, anchor: Vector2) -> Dictionary` → `{"position": Vector2 (카드 중심), "rotation": float (라디안)}`

- [ ] **Step 1: 실패하는 테스트 작성**

Create `tests/test_card_view.gd`:

```gdscript
extends TestCase

const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")


func run() -> Array[Dictionary]:
	_test_ranged_sweep_card_face()
	_test_melee_single_card_face()
	_test_face_toggle()
	_test_affordable_dimming()
	return results()


func _card(display_name: String, cost: int, attack_type: CardData.AttackType, shape: CardData.Shape, attack_range: int, damage: int) -> CardData:
	var card: CardData = CardDataScript.new()
	card.display_name = display_name
	card.sp_cost = cost
	card.attack_type = attack_type
	card.shape = shape
	card.attack_range = attack_range
	card.damage = damage
	return card


func _test_ranged_sweep_card_face() -> void:
	var view := CardView.new()
	view.setup(_card("일제사격", 2, CardData.AttackType.RANGED, CardData.Shape.SWEEP, 4, 3))
	check_eq("cost", view.cost_text(), "2")
	check_eq("name", view.name_text(), "일제사격")
	check_eq("damage", view.damage_text(), "3")
	check_eq("footer", view.footer_text(), "원거리 · 사거리 4 · 횡렬")
	check_eq("ranged border", view.border_color(), CardView.RANGED_COLOR)
	check_eq("card size", view.size, CardView.SIZE)
	view.free()


func _test_melee_single_card_face() -> void:
	var view := CardView.new()
	view.setup(_card("베기", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 2, 6))
	check_eq("melee footer", view.footer_text(), "근접 · 사거리 2 · 단일")
	check_eq("melee border", view.border_color(), CardView.MELEE_COLOR)
	view.free()


func _test_face_toggle() -> void:
	var view := CardView.new()
	view.setup(_card("관통사격", 2, CardData.AttackType.RANGED, CardData.Shape.PIERCE, 3, 5))
	check("starts face up", view.is_face_up())
	view.set_face_up(false)
	check("turned face down", not view.is_face_up())
	view.free()


func _test_affordable_dimming() -> void:
	var view := CardView.new()
	view.setup(_card("베기", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 2, 6))
	view.set_affordable(false)
	check_eq("unaffordable is dimmed", view.modulate, CardView.UNAFFORDABLE_MODULATE)
	view.set_affordable(true)
	check_eq("affordable is not dimmed", view.modulate, Color.WHITE)
	view.free()
```

Create `tests/test_pile_view.gd`:

```gdscript
extends TestCase


func run() -> Array[Dictionary]:
	_test_labels()
	_test_dimming()
	_test_center()
	return results()


func _test_labels() -> void:
	var pile := PileView.new()
	check_eq("starts at zero", pile.count_text(), "0")
	pile.set_count(7)
	check_eq("count text", pile.count_text(), "7")
	pile.set_owner_name("선봉")
	check_eq("owner text", pile.owner_text(), "선봉")
	pile.free()


func _test_dimming() -> void:
	var pile := PileView.new()
	pile.set_dimmed(true)
	check("dimmed", pile.is_dimmed())
	pile.set_dimmed(false)
	check("not dimmed", not pile.is_dimmed())
	pile.free()


func _test_center() -> void:
	var pile := PileView.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(pile)
	pile.position = Vector2(100, 200)
	check("center of the pile in viewport coordinates", pile.center_global().is_equal_approx(Vector2(145, 263)))
	pile.free()
```

Create `tests/test_hand_layout.gd`:

```gdscript
extends TestCase

const ANCHOR := Vector2(576, 538)


func run() -> Array[Dictionary]:
	_test_single_card_sits_on_anchor()
	_test_odd_hand_is_symmetric()
	_test_spread_per_card()
	_test_spread_is_capped()
	return results()


func _test_single_card_sits_on_anchor() -> void:
	var slot: Dictionary = HandLayout.slot(0, 1, ANCHOR)
	check_eq("single card position", slot["position"], ANCHOR)
	check_eq("single card rotation", slot["rotation"], 0.0)


func _test_odd_hand_is_symmetric() -> void:
	var left: Dictionary = HandLayout.slot(0, 5, ANCHOR)
	var middle: Dictionary = HandLayout.slot(2, 5, ANCHOR)
	var right: Dictionary = HandLayout.slot(4, 5, ANCHOR)
	check("middle card on anchor", (middle["position"] as Vector2).is_equal_approx(ANCHOR))
	check("middle card upright", is_equal_approx(middle["rotation"], 0.0))
	check("mirrored horizontally", is_equal_approx(left["position"].x - ANCHOR.x, -(right["position"].x - ANCHOR.x)))
	check("same height on both ends", is_equal_approx(left["position"].y, right["position"].y))
	check("mirrored rotation", is_equal_approx(left["rotation"], -right["rotation"]))
	check("outer cards sit lower than the middle", left["position"].y > ANCHOR.y)


func _test_spread_per_card() -> void:
	check("four cards: first at -9 degrees", is_equal_approx(HandLayout.slot(0, 4, ANCHOR)["rotation"], deg_to_rad(-9.0)))
	check("four cards: last at +9 degrees", is_equal_approx(HandLayout.slot(3, 4, ANCHOR)["rotation"], deg_to_rad(9.0)))


func _test_spread_is_capped() -> void:
	check("ten cards: first capped at -20 degrees", is_equal_approx(HandLayout.slot(0, 10, ANCHOR)["rotation"], deg_to_rad(-20.0)))
	check("ten cards: last capped at +20 degrees", is_equal_approx(HandLayout.slot(9, 10, ANCHOR)["rotation"], deg_to_rad(20.0)))
```

- [ ] **Step 2: 실패 확인**

Run: 테스트 명령

Expected: 세 스위트 로드 실패 (`CardView` / `PileView` / `HandLayout` 없음). 나머지 272개 PASS.

- [ ] **Step 3: `CardView` 구현**

Create `Scripts/ui/cards/card_view.gd`:

```gdscript
class_name CardView
extends Control

const SIZE := Vector2(110, 154)
const MELEE_COLOR := Color(0.85, 0.4, 0.35)
const RANGED_COLOR := Color(0.4, 0.6, 0.95)
const FACE_COLOR := Color(0.12, 0.12, 0.15)
const BACK_COLOR := Color(0.18, 0.22, 0.38)
const UNAFFORDABLE_MODULATE := Color(1, 1, 1, 0.55)
const SHAPE_NAMES: Dictionary = {
	CardData.Shape.SINGLE: "단일",
	CardData.Shape.SWEEP: "횡렬",
	CardData.Shape.PIERCE: "관통",
}

var card: CardData

var _face: Panel
var _back: Panel
var _cost_label: Label
var _name_label: Label
var _damage_label: Label
var _footer_label: Label
var _border_color: Color = Color.WHITE


func setup(p_card: CardData) -> void:
	card = p_card
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	var melee: bool = card.attack_type == CardData.AttackType.MELEE
	_border_color = MELEE_COLOR if melee else RANGED_COLOR

	_face = _make_panel(FACE_COLOR, _border_color, 8)
	add_child(_face)

	var cost_badge: Panel = _make_panel(_border_color, _border_color, 14)
	cost_badge.position = Vector2(6, 6)
	cost_badge.size = Vector2(28, 28)
	_face.add_child(cost_badge)
	_cost_label = _make_label(str(card.sp_cost), 18, Vector2.ZERO, cost_badge.size)
	cost_badge.add_child(_cost_label)

	_name_label = _make_label(card.display_name, 16, Vector2(0, 36), Vector2(SIZE.x, 24))
	_face.add_child(_name_label)
	_damage_label = _make_label(str(card.damage), 40, Vector2(0, 62), Vector2(SIZE.x, 50))
	_face.add_child(_damage_label)
	var kind: String = "근접" if melee else "원거리"
	_footer_label = _make_label("%s · 사거리 %d · %s" % [kind, card.attack_range, SHAPE_NAMES[card.shape]], 11, Vector2(4, 114), Vector2(SIZE.x - 8, 34))
	_footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_face.add_child(_footer_label)

	_back = make_back()
	add_child(_back)
	set_face_up(true)


static func make_back() -> Panel:
	var back: Panel = _make_panel(BACK_COLOR, BACK_COLOR.lightened(0.3), 8)
	back.add_child(_make_label("VOID", 22, Vector2(0, 60), Vector2(SIZE.x, 34)))
	return back


func set_face_up(face_up: bool) -> void:
	_face.visible = face_up
	_back.visible = not face_up


func is_face_up() -> bool:
	return _face.visible


func set_affordable(affordable: bool) -> void:
	modulate = Color.WHITE if affordable else UNAFFORDABLE_MODULATE


func cost_text() -> String:
	return _cost_label.text


func name_text() -> String:
	return _name_label.text


func damage_text() -> String:
	return _damage_label.text


func footer_text() -> String:
	return _footer_label.text


func border_color() -> Color:
	return _border_color


static func _make_panel(background: Color, border: Color, radius: int) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override(&"panel", style)
	return panel


static func _make_label(text: String, font_size: int, at: Vector2, box: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = box
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
```

- [ ] **Step 4: `PileView` 구현**

Create `Scripts/ui/cards/pile_view.gd`:

```gdscript
class_name PileView
extends Control

const SIZE := Vector2(90, 126)
const DIM_MODULATE := Color(1, 1, 1, 0.4)

var _owner_label: Label
var _count_label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE

	var back: Panel = CardView.make_back()
	back.scale = SIZE / CardView.SIZE
	add_child(back)

	_count_label = Label.new()
	_count_label.position = Vector2(0, SIZE.y - 38)
	_count_label.size = Vector2(SIZE.x, 32)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override(&"font_size", 24)
	_count_label.add_theme_constant_override(&"outline_size", 6)
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count_label)

	_owner_label = Label.new()
	_owner_label.position = Vector2(0, -26)
	_owner_label.size = Vector2(SIZE.x, 24)
	_owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_owner_label.add_theme_font_size_override(&"font_size", 14)
	_owner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_owner_label)

	set_count(0)


func set_owner_name(owner_name: String) -> void:
	_owner_label.text = owner_name


func set_count(count: int) -> void:
	_count_label.text = str(count)


func set_dimmed(dimmed: bool) -> void:
	modulate = DIM_MODULATE if dimmed else Color.WHITE


func is_dimmed() -> bool:
	return modulate == DIM_MODULATE


func count_text() -> String:
	return _count_label.text


func owner_text() -> String:
	return _owner_label.text


func center_global() -> Vector2:
	return global_position + SIZE / 2.0
```

- [ ] **Step 5: `HandLayout` 구현**

Create `Scripts/ui/cards/hand_layout.gd`:

```gdscript
class_name HandLayout
extends RefCounted

const CARD_ANGLE_DEG: float = 6.0
const MAX_SPREAD_DEG: float = 40.0
const RADIUS: float = 900.0


# 반지름 RADIUS 인 원의 꼭대기(anchor)에서 좌우로 부채꼴을 편다. 바깥 카드일수록 조금 아래로 내려간다.
static func slot(index: int, count: int, anchor: Vector2) -> Dictionary:
	if count <= 1:
		return {"position": anchor, "rotation": 0.0}
	var spread: float = minf(CARD_ANGLE_DEG * (count - 1), MAX_SPREAD_DEG)
	var angle: float = deg_to_rad(-spread / 2.0 + spread * float(index) / float(count - 1))
	var offset := Vector2(sin(angle) * RADIUS, (1.0 - cos(angle)) * RADIUS)
	return {"position": anchor + offset, "rotation": angle}
```

- [ ] **Step 6: 클래스 캐시 갱신 후 통과 확인**

Run: 클래스 캐시 갱신 명령, 그다음 테스트 명령

Expected: `302/302 passed` (272 + CardView 12 + PileView 6 + HandLayout 12)

- [ ] **Step 7: 커밋**

```bash
git add Scripts/ui/cards/card_view.gd Scripts/ui/cards/card_view.gd.uid Scripts/ui/cards/pile_view.gd Scripts/ui/cards/pile_view.gd.uid Scripts/ui/cards/hand_layout.gd Scripts/ui/cards/hand_layout.gd.uid tests/test_card_view.gd tests/test_card_view.gd.uid tests/test_pile_view.gd tests/test_pile_view.gd.uid tests/test_hand_layout.gd tests/test_hand_layout.gd.uid tests/run_tests.gd
git commit -F - <<'MSG'
feat: add card, pile and fan layout building blocks

Co-Authored-By: <model> <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016mWJpHQu18LvtDTZoFSsZq
MSG
```

---

### Task 4: 손패 뷰와 조준 화살표

**Files:**
- Create: `Scripts/ui/cards/aim_arrow.gd`, `Scripts/ui/cards/hand_view.gd`
- Create: `tests/test_hand_view.gd`
- Modify: `tests/run_tests.gd` (`"res://tests/test_hand_view.gd",` 추가)

**Interfaces:**
- Consumes: Task 3 `CardView` (`SIZE`, `setup`, `set_face_up`, `is_face_up`, `set_affordable`, `card`, `make_back`), `HandLayout.slot`
- Produces:
  - `class_name AimArrow extends Control`: `show_aim(from_global: Vector2, to_global: Vector2) -> void`, `hide_aim() -> void`, `is_aiming() -> bool`
  - `class_name HandView extends Control` (루트 `mouse_filter = IGNORE`, 자식 카드만 STOP)
    - `signal card_selected(index: int)` (-1 = 해제), `signal card_dropped(index: int, screen_position: Vector2)`
    - 상수 `BOTTOM_OFFSET = 110.0`, `LIFT = 40.0`, `SELECTED_SCALE = 1.1`, `DRAG_THRESHOLD = 12.0`
    - `var instant: bool`, `var interactive: bool` (false 로 바꾸면 누르기·드래그 취소, 선택 해제)
    - `anchor() -> Vector2` (가운데 카드 중심, 로컬 좌표)
    - `set_cards(cards: Array[CardData], sp: int, selected: int)`, `draw_card(card: CardData, from_global: Vector2)`, `remove_card(card: CardData)`, `discard_all(to_global: Vector2)`, `fly_backs(from_global: Vector2, to_global: Vector2, count: int)`, `set_sp(sp: int)`, `set_pending_play(index: int)`
    - `card_views() -> Array[CardView]` (복사본), `selected_index() -> int`, `is_aiming() -> bool`
    - 구조 변경(카드 추가·제거·선택)은 즉시, 위치·크기·투명도는 트윈 (`instant` 면 즉시)

- [ ] **Step 1: 실패하는 테스트 작성**

Create `tests/test_hand_view.gd`:

```gdscript
extends TestCase

const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")


func run() -> Array[Dictionary]:
	_test_set_cards_lays_out()
	_test_selected_card_lifts()
	_test_draw_card_appends()
	_test_remove_card_prefers_pending_play()
	_test_discard_all_empties()
	_test_click_toggles_selection()
	_test_drag_emits_drop()
	_test_locked_hand_ignores_input()
	return results()


func _card(display_name: String, cost: int) -> CardData:
	var card: CardData = CardDataScript.new()
	card.display_name = display_name
	card.sp_cost = cost
	card.damage = 1
	card.attack_range = 1
	return card


func _cards(list: Array) -> Array[CardData]:
	var typed: Array[CardData] = []
	typed.append_array(list)
	return typed


func _hand() -> HandView:
	var hand := HandView.new()
	hand.instant = true
	(Engine.get_main_loop() as SceneTree).root.add_child(hand)
	hand.size = Vector2(1152, 648)
	return hand


func _press(view: CardView, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	view.gui_input.emit(event)


func _move(view: CardView, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	view.gui_input.emit(event)


func _test_set_cards_lays_out() -> void:
	var hand: HandView = _hand()
	hand.set_cards(_cards([_card("a", 1), _card("b", 1), _card("big", 9)]), 3, -1)
	var views: Array[CardView] = hand.card_views()
	check_eq("three card views", views.size(), 3)
	var middle: Dictionary = HandLayout.slot(1, 3, hand.anchor())
	check("middle card centred on its slot", (views[1].position + CardView.SIZE / 2.0).is_equal_approx(middle["position"]))
	check_eq("unaffordable card dimmed", views[2].modulate, CardView.UNAFFORDABLE_MODULATE)
	hand.free()


func _test_selected_card_lifts() -> void:
	var hand: HandView = _hand()
	hand.set_cards(_cards([_card("a", 1), _card("b", 1), _card("c", 1)]), 3, 0)
	var view: CardView = hand.card_views()[0]
	var slot: Dictionary = HandLayout.slot(0, 3, hand.anchor())
	check("lifted above its slot", is_equal_approx(view.position.y, slot["position"].y - CardView.SIZE.y / 2.0 - HandView.LIFT))
	check_eq("upright while selected", view.rotation, 0.0)
	check("enlarged while selected", view.scale.is_equal_approx(Vector2.ONE * HandView.SELECTED_SCALE))
	hand.free()


func _test_draw_card_appends() -> void:
	var hand: HandView = _hand()
	var first: CardData = _card("a", 1)
	var drawn: CardData = _card("b", 1)
	hand.set_cards(_cards([first]), 3, -1)
	hand.draw_card(drawn, Vector2.ZERO)
	var views: Array[CardView] = hand.card_views()
	check_eq("hand grew", views.size(), 2)
	check("drawn card is last", views[1].card == drawn)
	check("drawn card face up when instant", views[1].is_face_up())
	hand.free()


func _test_remove_card_prefers_pending_play() -> void:
	var hand: HandView = _hand()
	var strike: CardData = _card("strike", 1)
	hand.set_cards(_cards([strike, strike, _card("shot", 1)]), 3, -1)
	var left: CardView = hand.card_views()[0]
	var right: CardView = hand.card_views()[1]
	hand.set_pending_play(1)
	hand.remove_card(strike)
	var views: Array[CardView] = hand.card_views()
	check_eq("one card removed", views.size(), 2)
	check("the remembered copy was removed", not views.has(right))
	check("the other copy stays", views[0] == left)
	hand.free()


func _test_discard_all_empties() -> void:
	var hand: HandView = _hand()
	hand.set_cards(_cards([_card("a", 1), _card("b", 1)]), 3, 1)
	hand.discard_all(Vector2.ZERO)
	check_eq("no cards left", hand.card_views().size(), 0)
	check_eq("selection cleared", hand.selected_index(), -1)
	hand.free()


func _test_click_toggles_selection() -> void:
	var hand: HandView = _hand()
	hand.interactive = true
	hand.set_cards(_cards([_card("a", 1), _card("b", 1)]), 3, -1)
	var picked: Array = []
	hand.card_selected.connect(func(index: int) -> void: picked.append(index))
	var view: CardView = hand.card_views()[1]
	_press(view, Vector2(100, 100), true)
	_press(view, Vector2(102, 101), false)
	_press(view, Vector2(100, 100), true)
	_press(view, Vector2(100, 100), false)
	check_eq("select then deselect", picked, [1, -1])
	check_eq("nothing selected at the end", hand.selected_index(), -1)
	hand.free()


func _test_drag_emits_drop() -> void:
	var hand: HandView = _hand()
	hand.interactive = true
	hand.set_cards(_cards([_card("a", 1), _card("b", 1)]), 3, -1)
	var picked: Array = []
	var dropped: Array = []
	hand.card_selected.connect(func(index: int) -> void: picked.append(index))
	hand.card_dropped.connect(func(index: int, at: Vector2) -> void: dropped.append([index, at]))
	var view: CardView = hand.card_views()[0]
	_press(view, Vector2(500, 560), true)
	_move(view, Vector2(500, 500))
	check_eq("dragging selects the card", picked, [0])
	check("aim arrow shown while dragging", hand.is_aiming())
	_press(view, Vector2(700, 200), false)
	check_eq("drop reports card and position", dropped, [[0, Vector2(700, 200)]])
	check("aim arrow hidden after drop", not hand.is_aiming())
	check_eq("card returns unselected", hand.selected_index(), -1)
	hand.free()


func _test_locked_hand_ignores_input() -> void:
	var hand: HandView = _hand()
	hand.set_cards(_cards([_card("a", 1)]), 3, -1)
	var picked: Array = []
	hand.card_selected.connect(func(index: int) -> void: picked.append(index))
	var view: CardView = hand.card_views()[0]
	_press(view, Vector2(100, 100), true)
	_press(view, Vector2(100, 100), false)
	check_eq("no selection while not interactive", picked, [])

	hand.interactive = true
	_press(view, Vector2(100, 100), true)
	_press(view, Vector2(100, 100), false)
	hand.interactive = false
	check_eq("locking clears the selection", hand.selected_index(), -1)
	hand.free()
```

- [ ] **Step 2: 실패 확인**

Run: 테스트 명령

Expected: `test_hand_view.gd` 로드 실패 (`HandView` 없음). 나머지 302개 PASS.

- [ ] **Step 3: `AimArrow` 구현**

Create `Scripts/ui/cards/aim_arrow.gd`:

```gdscript
class_name AimArrow
extends Control

const COLOR := Color(1.0, 1.0, 1.0, 0.9)
const WIDTH: float = 6.0
const HEAD_SIZE: float = 18.0
const SEGMENTS: int = 20
const ARC_HEIGHT: float = 120.0

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)


func show_aim(from_global: Vector2, to_global: Vector2) -> void:
	_from = from_global - global_position
	_to = to_global - global_position
	visible = true
	queue_redraw()


func hide_aim() -> void:
	visible = false


func is_aiming() -> bool:
	return visible


func _draw() -> void:
	var control_point := Vector2((_from.x + _to.x) / 2.0, minf(_from.y, _to.y) - ARC_HEIGHT)
	var points := PackedVector2Array()
	for i in SEGMENTS + 1:
		var t: float = float(i) / SEGMENTS
		points.append(_from.lerp(control_point, t).lerp(control_point.lerp(_to, t), t))
	draw_polyline(points, COLOR, WIDTH, true)
	var direction: Vector2 = (points[SEGMENTS] - points[SEGMENTS - 1]).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var base: Vector2 = _to - direction * HEAD_SIZE
	draw_colored_polygon(PackedVector2Array([_to, base + normal * HEAD_SIZE * 0.6, base - normal * HEAD_SIZE * 0.6]), COLOR)
```

- [ ] **Step 4: `HandView` 구현**

Create `Scripts/ui/cards/hand_view.gd`:

```gdscript
class_name HandView
extends Control

signal card_selected(index: int)
signal card_dropped(index: int, screen_position: Vector2)

const BOTTOM_OFFSET: float = 110.0
const LIFT: float = 40.0
const SELECTED_SCALE: float = 1.1
const DRAG_THRESHOLD: float = 12.0
const LAYOUT_TIME: float = 0.2
const DRAW_TIME: float = 0.25
const DRAW_START_SCALE: float = 0.6
const DISCARD_TIME: float = 0.3
const DISCARD_STAGGER: float = 0.03
const PLAY_FADE_TIME: float = 0.12
const GHOST_TIME: float = 0.3
const GHOST_STAGGER: float = 0.04

# 테스트용. 트윈 없이 최종 배치만 반영한다.
var instant: bool = false
var interactive: bool = false:
	set(value):
		interactive = value
		if not value:
			_cancel_press()
			if _selected >= 0:
				_selected = -1
				_layout(true)

var _cards: Array[CardView] = []
# 날아오는 중인 카드는 재배치 트윈과 겹치지 않게 비행이 끝날 때까지 배치에서 뺀다.
var _flying: Array[CardView] = []
var _selected: int = -1
var _pending_play: int = -1
var _sp: int = 0
var _press_view: CardView
var _press_position: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _arrow: AimArrow


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow = AimArrow.new()
	add_child(_arrow)


func anchor() -> Vector2:
	return Vector2(size.x / 2.0, size.y - BOTTOM_OFFSET)


func set_cards(cards: Array[CardData], sp: int, selected: int) -> void:
	for view in _cards:
		_free_view(view)
	_cards.clear()
	_flying.clear()
	_cancel_press()
	_sp = sp
	_selected = selected
	_pending_play = -1
	for card in cards:
		_cards.append(_make_view(card))
	_layout(false)


func draw_card(card: CardData, from_global: Vector2) -> void:
	var view: CardView = _make_view(card)
	_cards.append(view)
	if instant:
		_layout(false)
		return
	_flying.append(view)
	view.position = from_global - global_position - CardView.SIZE / 2.0
	view.rotation = 0.0
	view.scale = Vector2.ONE * DRAW_START_SCALE
	view.set_face_up(false)
	_layout(true)

	var target: Dictionary = _slot_transform(_cards.size() - 1)
	var move: Tween = view.create_tween().set_parallel(true)
	move.tween_property(view, "position", target["position"], DRAW_TIME)
	move.tween_property(view, "rotation", target["rotation"], DRAW_TIME)
	move.tween_property(view, "scale:y", (target["scale"] as Vector2).y, DRAW_TIME)
	var flip: Tween = view.create_tween()
	flip.tween_property(view, "scale:x", 0.0, DRAW_TIME / 2.0)
	flip.tween_callback(view.set_face_up.bind(true))
	flip.tween_property(view, "scale:x", (target["scale"] as Vector2).x, DRAW_TIME / 2.0)
	flip.tween_callback(_on_flight_finished.bind(view))


func remove_card(card: CardData) -> void:
	var index: int = -1
	if _pending_play >= 0 and _pending_play < _cards.size() and _cards[_pending_play].card == card:
		index = _pending_play
	else:
		for i in _cards.size():
			if _cards[i].card == card:
				index = i
				break
	_pending_play = -1
	if index < 0:
		return

	var view: CardView = _cards[index]
	_cards.remove_at(index)
	_flying.erase(view)
	if _selected == index:
		_selected = -1
	elif _selected > index:
		_selected -= 1

	if instant:
		_free_view(view)
	else:
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fade: Tween = view.create_tween()
		fade.tween_property(view, "modulate:a", 0.0, PLAY_FADE_TIME)
		fade.tween_callback(view.queue_free)
	_layout(true)


func discard_all(to_global: Vector2) -> void:
	var leaving: Array[CardView] = _cards.duplicate()
	_cards.clear()
	_flying.clear()
	_cancel_press()
	_selected = -1
	_pending_play = -1
	for i in leaving.size():
		var view: CardView = leaving[i]
		if instant:
			_free_view(view)
			continue
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var delay: float = i * DISCARD_STAGGER
		var tween: Tween = view.create_tween().set_parallel(true)
		tween.tween_property(view, "position", to_global - global_position - CardView.SIZE / 2.0, DISCARD_TIME).set_delay(delay)
		tween.tween_property(view, "scale", Vector2.ONE * 0.5, DISCARD_TIME).set_delay(delay)
		tween.tween_property(view, "modulate:a", 0.0, DISCARD_TIME).set_delay(delay)
		tween.chain().tween_callback(view.queue_free)


func fly_backs(from_global: Vector2, to_global: Vector2, count: int) -> void:
	if instant:
		return
	for i in count:
		var ghost: Panel = CardView.make_back()
		ghost.pivot_offset = CardView.SIZE / 2.0
		ghost.position = from_global - global_position - CardView.SIZE / 2.0
		ghost.scale = Vector2.ONE * 0.8
		add_child(ghost)
		var tween: Tween = ghost.create_tween()
		tween.tween_property(ghost, "position", to_global - global_position - CardView.SIZE / 2.0, GHOST_TIME).set_delay(i * GHOST_STAGGER)
		tween.tween_callback(ghost.queue_free)


func set_sp(sp: int) -> void:
	_sp = sp
	for view in _cards:
		view.set_affordable(view.card.sp_cost <= _sp)


func set_pending_play(index: int) -> void:
	_pending_play = index


func card_views() -> Array[CardView]:
	return _cards.duplicate()


func selected_index() -> int:
	return _selected


func is_aiming() -> bool:
	return _arrow.is_aiming()


func _make_view(card: CardData) -> CardView:
	var view := CardView.new()
	view.setup(card)
	view.set_affordable(card.sp_cost <= _sp)
	view.gui_input.connect(_on_card_gui_input.bind(view))
	add_child(view)
	move_child(_arrow, -1)
	return view


# queue_free 만 하면 이번 프레임 동안 자식으로 남으므로 먼저 떼어 낸다.
func _free_view(view: CardView) -> void:
	if view.get_parent() == self:
		remove_child(view)
	view.queue_free()


func _slot_transform(index: int) -> Dictionary:
	var slot: Dictionary = HandLayout.slot(index, _cards.size(), anchor())
	var at: Vector2 = (slot["position"] as Vector2) - CardView.SIZE / 2.0
	var turn: float = slot["rotation"]
	var grow := Vector2.ONE
	if index == _selected:
		at.y -= LIFT
		turn = 0.0
		grow = Vector2.ONE * SELECTED_SCALE
	return {"position": at, "rotation": turn, "scale": grow}


func _layout(animate: bool) -> void:
	for i in _cards.size():
		var view: CardView = _cards[i]
		view.set_affordable(view.card.sp_cost <= _sp)
		view.z_index = _cards.size() if i == _selected else i
		if _flying.has(view):
			continue
		var target: Dictionary = _slot_transform(i)
		var previous: Tween = view.get_meta(&"layout_tween", null)
		if previous != null and previous.is_valid():
			previous.kill()
		if animate and not instant and view.is_inside_tree():
			var tween: Tween = view.create_tween().set_parallel(true)
			tween.tween_property(view, "position", target["position"], LAYOUT_TIME)
			tween.tween_property(view, "rotation", target["rotation"], LAYOUT_TIME)
			tween.tween_property(view, "scale", target["scale"], LAYOUT_TIME)
			view.set_meta(&"layout_tween", tween)
		else:
			view.position = target["position"]
			view.rotation = target["rotation"]
			view.scale = target["scale"]


func _on_flight_finished(view: CardView) -> void:
	_flying.erase(view)
	if _cards.has(view):
		_layout(true)


func _on_card_gui_input(event: InputEvent, view: CardView) -> void:
	if not interactive or not _cards.has(view):
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press_view = view
			_press_position = button.global_position
			_dragging = false
		elif _press_view == view:
			if _dragging:
				_finish_drag(button.global_position)
			else:
				_toggle(_cards.find(view))
			_press_view = null
		view.accept_event()
		return

	var motion := event as InputEventMouseMotion
	if motion == null or _press_view != view:
		return
	if not _dragging and motion.global_position.distance_to(_press_position) >= DRAG_THRESHOLD:
		_dragging = true
		_selected = _cards.find(view)
		_layout(true)
		card_selected.emit(_selected)
	if _dragging:
		_arrow.show_aim(view.global_position + Vector2(CardView.SIZE.x / 2.0, 0.0), motion.global_position)
	view.accept_event()


func _toggle(index: int) -> void:
	_selected = -1 if _selected == index else index
	_layout(true)
	card_selected.emit(_selected)


func _finish_drag(screen_position: Vector2) -> void:
	var index: int = _cards.find(_press_view)
	_dragging = false
	_arrow.hide_aim()
	_selected = -1
	_layout(true)
	card_dropped.emit(index, screen_position)


func _cancel_press() -> void:
	_press_view = null
	_dragging = false
	if _arrow != null:
		_arrow.hide_aim()
```

- [ ] **Step 5: 클래스 캐시 갱신 후 통과 확인**

Run: 클래스 캐시 갱신 명령, 그다음 테스트 명령

Expected: `325/325 passed` (302 + 23). 출력에 `SCRIPT ERROR` 없음.

- [ ] **Step 6: 커밋**

```bash
git add Scripts/ui/cards/aim_arrow.gd Scripts/ui/cards/aim_arrow.gd.uid Scripts/ui/cards/hand_view.gd Scripts/ui/cards/hand_view.gd.uid tests/test_hand_view.gd tests/test_hand_view.gd.uid tests/run_tests.gd
git commit -F - <<'MSG'
feat: add fanned hand view with click, drag and pile animations

Co-Authored-By: <model> <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016mWJpHQu18LvtDTZoFSsZq
MSG
```

---

### Task 5: HUD 에 손패·더미 통합

**Files:**
- Modify (전체 교체): `Scenes/battle_hud.tscn`, `Scripts/ui/battle_hud.gd`, `tests/test_battle_hud.gd`

**Interfaces:**
- Consumes: Task 4 `HandView`, Task 3 `PileView`/`CardView`, Task 2 `BattleEvent` (`deck_count`, `discard_count`, `cards`, `card`, `amount`)
- Produces: `class_name BattleHud extends Control`
  - `signal card_selected(index: int)`, `signal card_dropped(index: int, screen_position: Vector2)`, `signal end_turn_pressed`
  - 상수 `CURRENT_TURN_COLOR`, `ACTED_COLOR`, `RESHUFFLE_GHOSTS_MAX = 6`
  - `sync_from_state(state: BattleState, selected_card: int)`, `show_turn(event: BattleEvent)`, `set_interactive(enabled: bool)`, `set_pending_play(index: int)`
  - 재생용: `draw_card(event)`, `reshuffle(event)`, `discard_hand(event)`, `remove_played_card(event)`
  - `append_log(text)`, `show_banner(ally_won)`, `static turn_bar_text(...)` (기존 그대로)
  - 조회용: `hand_view() -> HandView`, `deck_pile() -> PileView`, `discard_pile() -> PileView`, `sp_text()`, `log_text()`, `end_turn_enabled()`, `banner_visible()`, `banner_text()`
  - 제거: `hand_buttons()`, 버튼 테두리 코드
  - 덱 더미 이름 = 현재 아군 이름, 묘지 더미 이름 = `"묘지"`

기존 `BattleRoot` 는 `card_selected`, `end_turn_pressed`, `sync_from_state`, `set_interactive`, `append_log` 만 쓰므로 이 태스크 후에도 게임이 돈다 (재생기는 T6 전까지 새 이벤트를 무시하고, 재생 후 동기화에서 손패가 나타난다).

- [ ] **Step 1: 테스트 전체 교체 (실패하는 테스트)**

Replace `tests/test_battle_hud.gd` entirely:

```gdscript
extends TestCase

const HudScene := preload("res://Scenes/battle_hud.tscn")
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


func run() -> Array[Dictionary]:
	_test_sync_builds_hand_and_piles()
	_test_interactive_lock()
	_test_turn_bar_text()
	_test_hand_signals_are_relayed()
	_test_enemy_turn_clears_hand_and_dims_piles()
	_test_ally_turn_shows_pile_snapshot()
	_test_playback_helpers()
	_test_log_and_banner()
	return results()


func _hud() -> BattleHud:
	var hud: BattleHud = HudScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	return hud


func _card(id: StringName, attack_type: CardData.AttackType, cost: int) -> CardData:
	var card: CardData = CardDataScript.new()
	card.id = id
	card.display_name = String(id)
	card.sp_cost = cost
	card.attack_type = attack_type
	card.attack_range = 2
	card.damage = 6
	return card


func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


# 아군 a(속도 10, SP 3) 덱 strike(근접 1) / shot(원거리 1) / big(원거리 9) — 시작하면 3장 모두 손패, 덱 0. 적 e(속도 1).
func _started_state() -> BattleState:
	var ally: AllyData = AllyDataScript.new()
	ally.id = &"a"
	ally.display_name = "a"
	ally.max_hp = 30
	ally.speed = 10
	ally.max_sp = 3
	var deck: Array[CardData] = [
		_card(&"strike", CardData.AttackType.MELEE, 1),
		_card(&"shot", CardData.AttackType.RANGED, 1),
		_card(&"big", CardData.AttackType.RANGED, 9),
	]
	ally.deck = deck

	var enemy: EnemyData = EnemyDataScript.new()
	enemy.id = &"e"
	enemy.display_name = "e"
	enemy.max_hp = 20
	enemy.speed = 1

	var encounter: EncounterData = EncounterScript.new()
	var allies: Array[UnitPlacement] = [_placement(ally, Vector2i(0, 1))]
	var enemies: Array[UnitPlacement] = [_placement(enemy, Vector2i(0, 1))]
	encounter.ally_units = allies
	encounter.enemy_units = enemies
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var state := BattleState.new(encounter, rng)
	state.start_battle()
	return state


func _view_named(views: Array[CardView], display_name: String) -> CardView:
	for view in views:
		if view.card.display_name == display_name:
			return view
	return null


func _turn_event(state: BattleState, unit: Unit, turn_index: int) -> BattleEvent:
	var event := BattleEvent.new(BattleEvent.Kind.TURN_STARTED)
	event.unit = unit
	event.round_index = 1
	event.order = state.initiative
	var alive: Array[bool] = [true, true]
	event.alive = alive
	event.turn_index = turn_index
	return event


func _test_sync_builds_hand_and_piles() -> void:
	var hud: BattleHud = _hud()
	var state: BattleState = _started_state()
	hud.sync_from_state(state, -1)
	hud.set_interactive(true)

	var views: Array[CardView] = hud.hand_view().card_views()
	check_eq("one card view per card in hand", views.size(), 3)
	check_eq("melee card border", _view_named(views, "strike").border_color(), CardView.MELEE_COLOR)
	check_eq("unaffordable card dimmed", _view_named(views, "big").modulate, CardView.UNAFFORDABLE_MODULATE)
	check_eq("sp panel text", hud.sp_text(), "SP\n●●●\n3 / 3")
	check_eq("deck pile names the ally", hud.deck_pile().owner_text(), "a")
	check_eq("deck pile count", hud.deck_pile().count_text(), "0")
	check_eq("discard pile count", hud.discard_pile().count_text(), "0")
	check("end turn enabled", hud.end_turn_enabled())
	hud.free()


func _test_interactive_lock() -> void:
	var hud: BattleHud = _hud()
	hud.sync_from_state(_started_state(), 0)
	hud.set_interactive(true)
	hud.set_interactive(false)
	check("hand locked", not hud.hand_view().interactive)
	check("end turn locked", not hud.end_turn_enabled())
	check_eq("lock clears the selection", hud.hand_view().selected_index(), -1)
	hud.free()


func _test_turn_bar_text() -> void:
	var state: BattleState = _started_state()
	var order: Array[Unit] = state.initiative
	var both_alive: Array[bool] = [true, true]
	var enemy_dead: Array[bool] = [true, false]
	var current: String = BattleHud.turn_bar_text(1, order, both_alive, 0)
	check("current unit marked", current.contains("▶a"))
	var acted: String = BattleHud.turn_bar_text(1, order, both_alive, 1)
	check("acted unit greyed", acted.contains("[color=#%s]a[/color]" % BattleHud.ACTED_COLOR.to_html(false)))
	var dead: String = BattleHud.turn_bar_text(1, order, enemy_dead, 0)
	check("dead unit left out", dead.contains("▶a") and not dead.contains("→"))


func _test_hand_signals_are_relayed() -> void:
	var hud: BattleHud = _hud()
	var picked: Array = []
	var dropped: Array = []
	hud.card_selected.connect(func(index: int) -> void: picked.append(index))
	hud.card_dropped.connect(func(index: int, at: Vector2) -> void: dropped.append([index, at]))
	hud.hand_view().card_selected.emit(1)
	hud.hand_view().card_dropped.emit(0, Vector2(10, 20))
	check_eq("selection relayed", picked, [1])
	check_eq("drop relayed", dropped, [[0, Vector2(10, 20)]])
	hud.free()


func _test_enemy_turn_clears_hand_and_dims_piles() -> void:
	var hud: BattleHud = _hud()
	var state: BattleState = _started_state()
	hud.sync_from_state(state, -1)
	hud.show_turn(_turn_event(state, state.living_units(Unit.Team.ENEMY)[0], 1))
	check_eq("hand cleared on enemy turn", hud.hand_view().card_views().size(), 0)
	check_eq("sp hidden on enemy turn", hud.sp_text(), "")
	check("piles dimmed on enemy turn", hud.deck_pile().is_dimmed())
	hud.free()


func _test_ally_turn_shows_pile_snapshot() -> void:
	var hud: BattleHud = _hud()
	var state: BattleState = _started_state()
	var event: BattleEvent = _turn_event(state, state.living_units(Unit.Team.ALLY)[0], 0)
	event.deck_count = 5
	event.discard_count = 2
	hud.show_turn(event)
	check_eq("deck owner is the acting ally", hud.deck_pile().owner_text(), "a")
	check_eq("deck count from snapshot", hud.deck_pile().count_text(), "5")
	check_eq("discard count from snapshot", hud.discard_pile().count_text(), "2")
	check("piles lit on ally turn", not hud.deck_pile().is_dimmed())
	hud.free()


func _test_playback_helpers() -> void:
	var hud: BattleHud = _hud()
	var state: BattleState = _started_state()
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	hud.sync_from_state(state, -1)

	var drawn := BattleEvent.new(BattleEvent.Kind.CARD_DRAWN)
	drawn.unit = ally
	drawn.card = ally.hand[0]
	drawn.deck_count = 1
	drawn.discard_count = 0
	hud.draw_card(drawn)
	check_eq("drawn card joins the hand", hud.hand_view().card_views().size(), 4)
	check_eq("deck count after draw", hud.deck_pile().count_text(), "1")

	var played := BattleEvent.new(BattleEvent.Kind.CARD_PLAYED)
	played.unit = ally
	played.card = ally.hand[0]
	played.deck_count = 1
	played.discard_count = 1
	hud.set_pending_play(0)
	hud.remove_played_card(played)
	check_eq("played card leaves the hand", hud.hand_view().card_views().size(), 3)
	check_eq("discard count after play", hud.discard_pile().count_text(), "1")

	var discarded := BattleEvent.new(BattleEvent.Kind.HAND_DISCARDED)
	discarded.unit = ally
	discarded.discard_count = 4
	discarded.deck_count = 1
	hud.discard_hand(discarded)
	check_eq("hand empty after discard", hud.hand_view().card_views().size(), 0)
	check_eq("discard count after discard", hud.discard_pile().count_text(), "4")

	var reshuffled := BattleEvent.new(BattleEvent.Kind.DECK_RESHUFFLED)
	reshuffled.unit = ally
	reshuffled.amount = 4
	reshuffled.deck_count = 5
	reshuffled.discard_count = 0
	hud.reshuffle(reshuffled)
	check_eq("deck refilled", hud.deck_pile().count_text(), "5")
	check_eq("discard emptied", hud.discard_pile().count_text(), "0")
	hud.free()


func _test_log_and_banner() -> void:
	var hud: BattleHud = _hud()
	hud.append_log("hello")
	check("log keeps lines", hud.log_text().contains("hello"))
	hud.show_banner(false)
	check("banner shown", hud.banner_visible())
	check_eq("defeat banner text", hud.banner_text(), "패배...")
	hud.free()
```

- [ ] **Step 2: 실패 확인**

Run: 테스트 명령

Expected: `test_battle_hud.gd` 가 로드 또는 실행 실패 (`hand_view` 등 없음). 나머지 PASS.

- [ ] **Step 3: HUD 씬 전체 교체**

Replace `Scenes/battle_hud.tscn` entirely. 루트·장식·`HandView` 는 `mouse_filter = 2` (IGNORE), 로그 패널은 스크롤을 위해 기본값. `HandView` 는 더미·차례 종료 버튼보다 뒤(위에 그려지게) 둔다:

```
[gd_scene format=3]

[ext_resource type="Script" path="res://Scripts/ui/battle_hud.gd" id="1_hud"]
[ext_resource type="Script" path="res://Scripts/ui/cards/hand_view.gd" id="2_hand"]
[ext_resource type="Script" path="res://Scripts/ui/cards/pile_view.gd" id="3_pile"]

[node name="BattleHud" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1_hud")

[node name="TurnLabel" type="RichTextLabel" parent="."]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 10
anchor_right = 1.0
offset_left = 16.0
offset_top = 16.0
offset_right = -16.0
offset_bottom = 48.0
grow_horizontal = 2
mouse_filter = 2
bbcode_enabled = true
fit_content = true
scroll_active = false
autowrap_mode = 0

[node name="LogPanel" type="PanelContainer" parent="."]
layout_mode = 1
offset_left = 16.0
offset_top = 56.0
offset_right = 376.0
offset_bottom = 216.0

[node name="BattleLog" type="RichTextLabel" parent="LogPanel"]
unique_name_in_owner = true
layout_mode = 2
scroll_following = true

[node name="SpPanel" type="PanelContainer" parent="."]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 2
anchor_top = 1.0
anchor_bottom = 1.0
offset_left = 16.0
offset_top = -250.0
offset_right = 112.0
offset_bottom = -178.0
grow_vertical = 0
mouse_filter = 2

[node name="SpLabel" type="Label" parent="SpPanel"]
unique_name_in_owner = true
layout_mode = 2
horizontal_alignment = 1
vertical_alignment = 1

[node name="DeckPile" type="Control" parent="."]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 2
anchor_top = 1.0
anchor_bottom = 1.0
offset_left = 16.0
offset_top = -142.0
offset_right = 106.0
offset_bottom = -16.0
grow_vertical = 0
mouse_filter = 2
script = ExtResource("3_pile")

[node name="DiscardPile" type="Control" parent="."]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -236.0
offset_top = -142.0
offset_right = -146.0
offset_bottom = -16.0
grow_horizontal = 0
grow_vertical = 0
mouse_filter = 2
script = ExtResource("3_pile")

[node name="EndTurnButton" type="Button" parent="."]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -130.0
offset_top = -64.0
offset_right = -16.0
offset_bottom = -16.0
grow_horizontal = 0
grow_vertical = 0
text = "차례 종료"

[node name="HandView" type="Control" parent="."]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("2_hand")

[node name="Banner" type="Label" parent="."]
unique_name_in_owner = true
visible = false
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -300.0
offset_top = -60.0
offset_right = 300.0
offset_bottom = 60.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
theme_override_font_sizes/font_size = 64
horizontal_alignment = 1
vertical_alignment = 1
```

- [ ] **Step 4: HUD 스크립트 전체 교체**

Replace `Scripts/ui/battle_hud.gd` entirely:

```gdscript
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
		# 드로우 연출이 이어지므로 손패를 비우고, 새 카드가 SP 부족으로 흐려지지 않게 현재 SP 로 시작한다.
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
```

- [ ] **Step 5: 통과 확인**

Run: 테스트 명령

Expected: `339/339 passed` (325 − 기존 HUD 20 + 새 HUD 34).

Run (스모크):
```
& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --quit-after 60 res://Scenes/battle_3d.tscn
```
Expected: `SCRIPT ERROR` / `ERROR` 없음 (`[MCP Runtime]` 줄은 무관).

- [ ] **Step 6: 커밋**

```bash
git add Scenes/battle_hud.tscn Scripts/ui/battle_hud.gd tests/test_battle_hud.gd
git commit -F - <<'MSG'
feat: put the fanned hand and deck/discard piles into the battle HUD

Co-Authored-By: <model> <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016mWJpHQu18LvtDTZoFSsZq
MSG
```

---

### Task 6: 재생기에 카드 연출 추가

**Files:**
- Modify: `Scripts/view/battle_playback.gd`
- Modify: `tests/test_battle_playback.gd`

**Interfaces:**
- Consumes: Task 5 `BattleHud.draw_card/reshuffle/discard_hand/remove_played_card`, `hand_view()`, `deck_pile()`, `discard_pile()`
- Produces: `BattlePlayback` 이 `CARD_DRAWN`(0.12s), `DECK_RESHUFFLED`(0.45s), `HAND_DISCARDED`(0.35s) 를 재생하고, `CARD_PLAYED` 에서 기존 연출 전에 `hud.remove_played_card` 후 0.2s 기다린다. `instant` 면 대기 없이 반영만.

- [ ] **Step 1: 실패하는 테스트 추가**

`tests/test_battle_playback.gd` 의 `run()` 에서 기존 호출 뒤에 추가:

```gdscript
	_test_turn_start_draws_into_hand()
	_test_end_turn_discards_then_reshuffles_and_draws()
```

`_test_kill_plays_to_banner()` 의 `check("victory banner", ...)` 줄 뒤에 추가:

```gdscript
	check_eq("played card left the hand", hud.hand_view().card_views().size(), 0)
```

파일 끝에 추가 (기존 `_rig()` 는 아군 덱이 zap 1장, 적 e 는 기본 근접 공격으로 아군을 친다):

```gdscript
func _test_turn_start_draws_into_hand() -> void:
	var rig: Dictionary = _rig()
	var state: BattleState = rig["state"]
	var recorder: BattleEventRecorder = rig["recorder"]
	var hud: BattleHud = rig["hud"]
	var playback: BattlePlayback = rig["playback"]

	state.start_battle()
	playback.play(recorder.take_events())
	check_eq("drawn card is in the hand", hud.hand_view().card_views().size(), 1)
	check_eq("deck pile emptied by the draw", hud.deck_pile().count_text(), "0")
	check_eq("deck pile names the ally", hud.deck_pile().owner_text(), "a")
	_free(rig)


func _test_end_turn_discards_then_reshuffles_and_draws() -> void:
	var rig: Dictionary = _rig()
	var state: BattleState = rig["state"]
	var recorder: BattleEventRecorder = rig["recorder"]
	var hud: BattleHud = rig["hud"]
	var playback: BattlePlayback = rig["playback"]

	state.start_battle()
	playback.play(recorder.take_events())
	state.end_turn()
	var events: Array[BattleEvent] = recorder.take_events()

	var discard_only: Array[BattleEvent] = [events[0]]
	playback.play(discard_only)
	check_eq("hand discarded", hud.hand_view().card_views().size(), 0)
	check_eq("discard pile holds the card", hud.discard_pile().count_text(), "1")

	playback.play(events.slice(1))
	check_eq("card drawn again after the reshuffle", hud.hand_view().card_views().size(), 1)
	check_eq("discard pile emptied by the reshuffle", hud.discard_pile().count_text(), "0")
	_free(rig)
```

- [ ] **Step 2: 실패 확인**

Run: 테스트 명령

Expected: 새 테스트와 "played card left the hand" 가 FAIL (재생기가 새 이벤트를 무시함). 나머지 PASS.

- [ ] **Step 3: 재생기 구현**

`Scripts/view/battle_playback.gd` 의 상수 목록 끝에 추가:

```gdscript
const DRAW_WAIT: float = 0.12
const RESHUFFLE_WAIT: float = 0.45
const DISCARD_WAIT: float = 0.35
const PLAY_REMOVE_WAIT: float = 0.2
```

`play()` 의 `match` 에서 `BattleEvent.Kind.BATTLE_ENDED:` 블록 뒤에 추가:

```gdscript
			BattleEvent.Kind.CARD_DRAWN:
				hud.draw_card(event)
				await _wait(DRAW_WAIT)
			BattleEvent.Kind.DECK_RESHUFFLED:
				hud.reshuffle(event)
				await _wait(RESHUFFLE_WAIT)
			BattleEvent.Kind.HAND_DISCARDED:
				hud.discard_hand(event)
				await _wait(DISCARD_WAIT)
```

`_card_played()` 전체를 교체:

```gdscript
func _card_played(event: BattleEvent) -> void:
	hud.remove_played_card(event)
	if instant:
		return
	await _wait(PLAY_REMOVE_WAIT)
	var view: UnitView = board.view_for(event.unit)
	view.pop_text(event.card.display_name, Color.WHITE)
	await view.lunge_toward(board.view_for(event.target).home_position)
```

- [ ] **Step 4: 통과 확인**

Run: 테스트 명령

Expected: `347/347 passed` (339 + 8). 출력에 `SCRIPT ERROR` 없음.

- [ ] **Step 5: 커밋**

```bash
git add Scripts/view/battle_playback.gd tests/test_battle_playback.gd
git commit -F - <<'MSG'
feat: play draw, reshuffle and discard events in the battle playback

Co-Authored-By: <model> <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016mWJpHQu18LvtDTZoFSsZq
MSG
```

---

### Task 7: 드래그 놓기 연결과 실행 검증

**Files:**
- Modify: `Scripts/view/board_3d.gd` (`pick_missed`, `request_pick`)
- Modify (전체 교체): `Scripts/view/battle_root.gd`

**Interfaces:**
- Consumes: Task 5 `BattleHud.card_dropped`, `set_pending_play`; 기존 `Board3D.cell_clicked`, `clear_target_hints`, `show_target_hints`
- Produces:
  - `Board3D.signal pick_missed`, `Board3D.request_pick(screen_position: Vector2) -> void`
  - `BattleRoot`: 드래그 놓기 → 판정 요청 → 유효 대상이면 사용, 무효·빗나감이면 선택 해제. 클릭 경로의 무효 대상은 지금처럼 선택 유지. 사용 직전 `hud.set_pending_play(card_index)`.
- 자동화 테스트 없음 (루트 연결 흐름 테스트는 후속 과제). 헤드리스 스모크 + 실행 검증으로 확인.

- [ ] **Step 1: `Board3D` 판정 요청과 빗나감 신호**

`Scripts/view/board_3d.gd` 에서 `signal cell_clicked(...)` 아래에:

```gdscript
signal pick_missed
```

`_unhandled_input()` 바로 위에 추가:

```gdscript
# 드래그로 놓은 카드처럼 마우스 이벤트가 보드에 오지 않는 경우에도 같은 판정 경로를 쓴다.
func request_pick(screen_position: Vector2) -> void:
	_pending_click = screen_position
	_has_pending_click = true
```

`_physics_process()` 에서 카메라가 없을 때와 레이가 아무것도 맞히지 못했을 때의 `return` 앞에 각각 `pick_missed.emit()` 을 넣는다:

```gdscript
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		pick_missed.emit()
		return
```

```gdscript
	if hit.is_empty():
		pick_missed.emit()
		return
```

- [ ] **Step 2: `BattleRoot` 전체 교체**

Replace `Scripts/view/battle_root.gd` entirely:

```gdscript
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
# 드래그로 놓은 카드의 판정 결과를 기다리는 중. 빗나가거나 무효면 클릭과 달리 선택을 해제한다.
var _awaiting_drop: bool = false

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
	_board.pick_missed.connect(_on_pick_missed)
	_hud.card_selected.connect(_on_card_selected)
	_hud.card_dropped.connect(_on_card_dropped)
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
		_awaiting_drop = false
		_clear_selection()
	_board.input_enabled = not busy
	_hud.set_interactive(not busy)


func _on_card_selected(index: int) -> void:
	if _busy:
		return
	_selected_card = index
	_refresh_target_hints()


func _on_card_dropped(index: int, screen_position: Vector2) -> void:
	if _busy:
		return
	_selected_card = index
	_refresh_target_hints()
	_awaiting_drop = true
	_board.request_pick(screen_position)


func _on_pick_missed() -> void:
	if not _awaiting_drop:
		return
	_awaiting_drop = false
	_clear_selection()


func _on_cell_clicked(team: Unit.Team, cell: Vector2i) -> void:
	var from_drop: bool = _awaiting_drop
	_awaiting_drop = false
	if _busy or _selected_card < 0:
		return
	var actor: Unit = _state.current_unit()
	var target: Unit = _unit_at(team, cell) if team == Unit.Team.ENEMY else null
	if actor == null or target == null or _selected_card >= actor.hand.size():
		if from_drop:
			_clear_selection()
		return
	var card: CardData = actor.hand[_selected_card]
	# 클릭은 선택을 유지한 채 다른 대상을 고를 수 있게 규칙 호출 전에 거르고, 드래그는 손패로 돌려보낸다.
	if not _state.resolver.is_valid_target(actor, target, card.attack_type, card.attack_range, _state.units):
		_hud.append_log("사용할 수 없는 대상")
		if from_drop:
			_clear_selection()
		return
	var card_index: int = _selected_card
	_hud.set_pending_play(card_index)
	_run(func() -> void:
		if not _state.play_card(card_index, target):
			_hud.append_log("사용할 수 없는 대상"))


func _on_end_turn_pressed() -> void:
	if _busy:
		return
	_run(_state.end_turn)


func _clear_selection() -> void:
	_selected_card = -1
	_board.clear_target_hints()


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
```

- [ ] **Step 3: 헤드리스 스모크와 회귀 테스트**

Run: 테스트 명령 → Expected `347/347 passed`

Run:
```
& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --quit-after 60 res://Scenes/battle_3d.tscn
```
Expected: `SCRIPT ERROR` / `ERROR` 없음.

- [ ] **Step 4: 실행 검증 (MCP)**

`mcp__godot__runtime-status` 로 런타임 도구가 쓸 수 있는지 먼저 본다 (도구가 없으면 ToolSearch 로 `select:mcp__godot__runtime-status,mcp__godot__capture-screenshot,mcp__godot__inject-mouse-click,mcp__godot__inject-mouse-motion,mcp__godot__call-runtime-method` 를 불러오고, 그래도 없으면 `mcp__godot__tool-groups` action activate group runtime). **MCP Godot 도구 자체가 없으면 Step 5 로 대체한다.**

게임을 띄우고 확인:

1. 첫 화면 스크린샷 — Expected: 아래 가운데 부채꼴 손패 4장, 왼쪽 아래 덱 더미 이름 `정찰병` 장수 `2`, 오른쪽 아래 묘지 `0`, 그 위 SP 패널. 손패·더미가 보드 유닛(특히 앞줄 발밑)을 가리지 않는다. 가리면 `CAMERA_TARGET_OFFSET` 의 z 만 조정하고 커밋 본문에 값을 적는다
2. 차례 종료 클릭 직후 곧바로 스크린샷 — Expected: 날아오는 중이거나 뒤집히는 중인 카드, 또는 묘지로 날아가는 카드가 보인다 (도구 지연으로 놓치면 다시 시도하고 시도 횟수를 보고)
3. 클릭 사용 — 선봉 차례에 `[근접]` 카드 클릭(들어올려짐) → 괴한 클릭. Expected: 카드가 사라지고 나머지가 재배치, 묘지 +1, 괴한 HP 감소
4. 드래그 사용 — 카드 위에서 누르기 → 괴한 쪽으로 motion 여러 번 → 괴한 몸통에서 떼기. Expected: 드래그 중 스크린샷에 조준 화살표, 떼면 사용(HP 감소, 묘지 +1)
5. 드래그 취소 — 카드를 끌어 하늘(보드 위 빈 곳)에서 떼기. Expected: 카드가 손패로 돌아가고 들어올림 해제, HP·SP 변화 없음
6. 차례 종료 — Expected: 남은 손패가 묘지 더미로 날아가고 묘지 장수 증가
7. 2라운드 같은 아군 차례 — Expected: 묘지→덱 유령 카드 이동 후 드로우, 묘지 0 으로 리셋

각 항목의 좌표·스크린샷 묘사·HP/SP/장수 전후 값을 보고서에 적는다. 끝나면 게임을 끄고 `godot.log` 에 `SCRIPT ERROR` 가 없는지 확인한다.

- [ ] **Step 5: (MCP 를 쓸 수 없을 때만) 헤드리스 대체 확인**

프로젝트 밖(스크래치 폴더)에 아래 스크립트를 만들어 실행한다. 커밋하지 않는다.

```gdscript
extends SceneTree

# MCP 입력 주입을 쓸 수 없을 때의 대체 확인. 실제 battle_3d 씬에 가짜 마우스 이벤트와 request_pick 을 흘린다.

var _scene: Node3D
var _frame: int = 0
var _step: int = 0
var _next_frame: int = 0
var _reshuffles: int = 0
var _hp_before: int = 0


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < _next_frame:
		return false
	match _step:
		0:
			_scene = (load("res://Scenes/battle_3d.tscn") as PackedScene).instantiate()
			_scene.get_node("Playback").instant = true
			root.add_child(_scene)
			_step = 1
			_next_frame = _frame + 3
		1:
			var state: BattleState = _scene.get("_state")
			state.deck_reshuffled.connect(func(unit: Unit, count: int) -> void:
				_reshuffles += 1
				print("reshuffle: ", unit.data.display_name, " ", count))
			var hud: BattleHud = _scene.get_node("%Hud")
			print("first turn: ", state.current_unit().data.display_name, " hand=", hud.hand_view().card_views().size(),
				" deck=", hud.deck_pile().count_text(), " discard=", hud.discard_pile().count_text())
			_advance_to_melee_vanguard()
			_drag_melee_to(&"brute")
			_step = 2
			_next_frame = _frame + 3
		2:
			var hud: BattleHud = _scene.get_node("%Hud")
			print("drag use: brute hp ", _hp_before, " -> ", _unit(&"brute").hp, ", hand=", hud.hand_view().card_views().size(),
				", discard=", hud.discard_pile().count_text(), ", busy=", _scene.get("_busy"))
			_hp_before = _unit(&"brute").hp
			_drag_card(0, Vector2(576, 30))
			_step = 3
			_next_frame = _frame + 3
		3:
			var hud: BattleHud = _scene.get_node("%Hud")
			print("drag cancel: brute hp ", _hp_before, " -> ", _unit(&"brute").hp, ", root selected=", _scene.get("_selected_card"),
				", hand selected=", hud.hand_view().selected_index())
			var state: BattleState = _scene.get("_state")
			for i in 12:
				if state.finished:
					break
				_scene.call("_on_end_turn_pressed")
			print("reshuffles seen: ", _reshuffles)
			quit(0)
	return false


func _unit(id: StringName) -> Unit:
	for unit in (_scene.get("_state") as BattleState).units:
		if unit.data.id == id:
			return unit
	return null


func _melee_index(actor: Unit) -> int:
	for i in actor.hand.size():
		if actor.hand[i].attack_type == CardData.AttackType.MELEE and actor.hand[i].sp_cost <= actor.sp:
			return i
	return -1


func _advance_to_melee_vanguard() -> void:
	var state: BattleState = _scene.get("_state")
	for i in 20:
		var actor: Unit = state.current_unit()
		if actor.data.id == &"vanguard" and _melee_index(actor) >= 0:
			return
		_scene.call("_on_end_turn_pressed")


func _drag_melee_to(id: StringName) -> void:
	var actor: Unit = (_scene.get("_state") as BattleState).current_unit()
	var camera: Camera3D = _scene.get_node("%Camera")
	var board: Board3D = _scene.get_node("%Board")
	_hp_before = _unit(id).hp
	var body: Vector3 = board.view_for(_unit(id)).home_position + Vector3(0.0, 0.8, 0.0)
	_drag_card(_melee_index(actor), camera.unproject_position(body))


func _drag_card(index: int, drop_at: Vector2) -> void:
	var hud: BattleHud = _scene.get_node("%Hud")
	var view: CardView = hud.hand_view().card_views()[index]
	var start: Vector2 = view.global_position + CardView.SIZE / 2.0
	_mouse_button(view, start, true)
	_mouse_motion(view, start + Vector2(0.0, -40.0))
	_mouse_motion(view, drop_at)
	_mouse_button(view, drop_at, false)


func _mouse_button(view: CardView, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	view.gui_input.emit(event)


func _mouse_motion(view: CardView, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	view.gui_input.emit(event)
```

Run: `& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --script "<스크래치 경로>\card_flow_probe.gd"`

Expected:
- `first turn: 정찰병 hand=4 deck=2 discard=0`
- `drag use: brute hp N -> N-6` (선봉 베기) 또는 `N-4` (횡베기), `hand=3`, `discard=1`, `busy=false`
- `drag cancel: brute hp M -> M`, `root selected=-1`, `hand selected=-1`
- `reshuffle: ...` 줄이 1번 이상, `reshuffles seen: ` 1 이상
- `SCRIPT ERROR` 없음

보고서에 출력 전체를 붙이고, 창 모드(스크린샷) 확인이 남았음을 적는다.

- [ ] **Step 6: 커밋**

```bash
git add Scripts/view/board_3d.gd Scripts/view/battle_root.gd
git commit -F - <<'MSG'
feat: play cards by dragging them onto enemies

Co-Authored-By: <model> <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016mWJpHQu18LvtDTZoFSsZq
MSG
```

(카메라 상수를 바꿨다면 `battle_root.gd` 커밋 본문에 바뀐 값을 적는다.)

---

## 완료 기준

- 헤드리스 테스트 `347/347 passed`
- Task 7 Step 4 의 7개 항목(또는 MCP 가 없을 때 Step 5 의 기대 출력)이 확인됨
- `Scripts/combat/` 변경은 `Unit.draw` 분리와 `BattleState` 신호·통로뿐이고 기존 규칙 테스트가 모두 통과
