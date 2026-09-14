# 이동과 턴 단계 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 차례를 스탠바이 → 드로우 → 턴 행동 → 종료 전 → 종료 후 단계로 진행하고, 아군은 SP 1 로 한 칸, 적은 행동 하나로 한 칸 이동할 수 있게 한다.

**Architecture:** 규칙 코어(`Scripts/combat/`, 노드 없음)의 `BattleState` 에 단계 enum 과 `phase_started` 신호, `move_unit` / `apply_move` 와 `unit_moved` 신호를 더한다. 적 AI 는 `ai_rng` 로 이동 확률을 판정한다. 화면은 기존 이벤트 기록·재생 파이프라인에 `UNIT_MOVED` 를 추가해 유닛을 미끄러뜨리고, `BattleRoot` 가 이동 가능 칸을 파란 타일로 보여 주고 클릭을 이동으로 바꾼다.

**Tech Stack:** Godot 4.7.2, 타입 지정 GDScript, 헤드리스 테스트 러너 `tests/run_tests.gd`

**Spec:** `docs/superpowers/specs/2026-09-14-movement-turn-phases-design.md`

## Global Constraints

- Godot 실행 파일: `C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe`, 프로젝트: `C:\Users\User\Desktop\Godot\Project-Void`
- 테스트 명령 (항상 포그라운드, 타임아웃 300000ms): `& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --script res://tests/run_tests.gd` — 마지막 줄 `N/N passed`
- 새 테스트 파일은 `tests/run_tests.gd` 의 `TEST_SCRIPTS` 끝에 경로를 추가해야 실행된다
- 타입 지정 GDScript: 모든 `var` 에 타입, 모든 함수에 `-> 반환형`
- **주석 스타일**: 이 저장소의 모든 스크립트와 테스트는 줄 단위 한국어 주석을 쓴다. 새로 추가하거나 바꾸는 코드도 같은 밀도로 — 새 멤버(신호·enum·const·var·func) 위에 `##` 설명, 함수 안의 거의 모든 줄 위에 `#` 설명. 이 계획의 코드 블록에 주석이 이미 들어 있으니 그대로 옮긴다
- 여러 줄에 걸친 배열·딕셔너리·람다·함수 인자 안에는 주석을 넣지 않는다 (문장 위에만)
- 규칙 코어(`Scripts/combat/`)는 노드를 쓰지 않는다. 신호는 `BattleState` 안에서만 emit 한다
- 작업 트리의 무관한 미커밋 파일(`Resources/*.tres` uid 줄 변경, 미추적 `CLAUDE.md`, 미추적 `Scenes/battle.tscn`)은 건드리지 않는다. `git add` 는 과제에 적힌 파일만. `git add -A` / `git add .` 금지
- Godot 에디터 프로세스(창 제목에 "Project Void - Godot Engine")는 절대 종료하지 않는다
- 커밋 메시지는 heredoc, 끝에 두 줄:
  `Co-Authored-By: <구현 모델 이름> <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_017G27EF6BYVPF1Bk3fvY2mz`
- 테스트 합계 흐름: 시작 359 → T1 368 → T2 391 → T3 405 → T4 417 → T5 429 → T6 429
- RED 단계에서 새 이름을 참조하는 테스트 파일은 파싱에 실패해 "could not load test script" 로 실패할 수 있다. 그것도 RED 로 인정한다. 헤드리스 실행이 멈추면 타임아웃 뒤 그 Godot 헤드리스 프로세스만 종료한다

## 스펙과 다른 점 (계획 단계에서 정함)

| 스펙 | 계획 | 이유 |
|---|---|---|
| 4.2 `movable_cells` 만 명시 | `TargetResolver.grid_for(team)`, `_occupied(team, cell, units)` 도우미 추가 | 격자 범위·점유 검사를 한 곳에 둔다 |
| 6.5 클릭 이동 | `_try_move` 가 SP 0 이면 무시, 규칙이 거절하면 로그 "이동할 수 없는 칸" | 카드 사용 경로(`사용할 수 없는 대상`)와 같은 안전장치 |
| 4.4 `decide` | 막혔을 때의 무작위 선택을 `_random_fallback(state, actor)` 로 분리 | `decide` 가 길어지지 않게 |
| 5 `TURN_STARTED`/`DIED` | `BattleEvent.cell` 로 기록 시점의 칸을 복사, `Board3D.show_current`/`mark_empty` 가 유닛 대신 team+cell 을 받음 (최종 리뷰 수정, 2026-09-15) | 규칙이 적 차례를 끝까지 계산한 뒤에 재생하므로, 재생 시점에 `unit.cell` 을 읽으면 이미 이동 뒤의 칸이라 강조·빈 칸 표시가 이동보다 먼저 옮겨 보였다 |
| 4.5 `ai_rng` | `seed = p_rng.seed` 대신 `seed = hash([p_rng.seed, "enemy_ai"])` (최종 리뷰 수정, 2026-09-15) | 같은 시드로 시작하면 적 AI 의 k 번째 뽑기가 덱 섞기의 k 번째 뽑기와 같아져, 두 난수열이 같은 수열을 되풀이했다 |

## 파일 구조

| 경로 | 책임 |
|---|---|
| `Scripts/combat/battle_state.gd` (수정) | 단계 enum·신호·진행 순서 (T1), `move_unit`/`apply_move`/`unit_moved` (T2), `ai_rng` (T3) |
| `Scripts/combat/target_resolver.gd` (수정) | `MOVE_DIRECTIONS`, `grid_for`, `movable_cells`, `_occupied` (T2) |
| `Scripts/combat/data/enemy_data.gd` (수정) | `move_chance` (T3) |
| `Scripts/combat/enemy_brain.gd` (수정) | `Action.MOVE`, 확률 판정, `_random_fallback`, 이동 실행 (T3) |
| `Scripts/view/unit_view.gd` (수정) | `MOVE_TIME`, `slide_to` (T4) |
| `Scripts/view/board_3d.gd` (수정) | `TileState.MOVABLE`, `show_move_hints`, 힌트 지우기, `move_view`, 동기화 시 위치 맞춤 (T4) |
| `Scripts/view/battle_event.gd` (수정) | `Kind.UNIT_MOVED`, `from_cell`, `to_cell` (T5) |
| `Scripts/view/battle_event_recorder.gd` (수정) | `unit_moved` 기록 (T5) |
| `Scripts/view/battle_playback.gd` (수정) | `UNIT_MOVED` 재생, 적 `MOVE` 행동 연출 생략 (T5) |
| `Scripts/ui/battle_hud.gd` (수정) | `apply_move` (T5) |
| `Scripts/view/battle_root.gd` (수정) | `_refresh_hints`, `_try_move`, 클릭 이동 (T6) |
| `tests/test_turn_phases.gd` (새로) | 단계 순서 (T1) |
| `tests/test_movement.gd` (새로) | 아군 이동 규칙 (T2) |
| `tests/test_target_resolver.gd`, `test_enemy_brain.gd`, `test_card_zone_signals.gd`, `test_battle_signals.gd`, `test_event_recorder.gd`, `test_turn_order.gd`, `test_board_3d.gd`, `test_battle_playback.gd`, `run_tests.gd` (수정) | 과제별 테스트 추가, 기존 적 `move_chance = 0` |

---

### Task 1: 턴 단계

**Files:**
- Modify: `Scripts/combat/battle_state.gd`
- Create: `tests/test_turn_phases.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: 기존 `BattleState` (`turn_started`, `card_drawn`, `hand_discarded`, `_draw_cards`, `_discard_hand`, `_take_enemy_turn`, `check_end`)
- Produces: `enum BattleState.Phase { STANDBY, DRAW, ACTION, BEFORE_END, AFTER_END }`, `signal phase_started(unit: Unit, phase: Phase)`, `var phase: Phase`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_turn_phases.gd` 를 만든다:

```gdscript
# BattleState 턴 단계 테스트: 스탠바이 → 드로우 → 턴 행동 → 종료 전 → 종료 후 신호 순서,
# 스탠바이 처리 시점, 적 차례의 빈 드로우 단계, 전투가 끝나면 남은 단계 생략.
extends TestCase

# 전투 상태 스크립트.
const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
# 카드 데이터 스크립트.
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
# 아군 데이터 스크립트.
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
# 적 데이터 스크립트.
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
# 배치 데이터 스크립트.
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
# 전투 구성 스크립트.
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 아군 차례 시작의 단계 순서.
	_test_ally_turn_start_order()
	# 차례 종료 → 적 차례 → 다음 아군 차례의 단계 순서.
	_test_end_turn_runs_end_phases_then_enemy_turn()
	# 스탠바이 신호 시점엔 이전 값, 차례 시작 신호 시점엔 초기화된 값.
	_test_standby_resets_before_turn_started()
	# 적 행동으로 전투가 끝나면 적의 종료 단계는 없다.
	_test_battle_end_skips_end_phases()
	# 결과를 돌려준다.
	return results()


# 데이터와 칸으로 배치 한 줄을 만든다.
func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	# 배치 리소스.
	var placement: UnitPlacement = PlacementScript.new()
	# 유닛 데이터.
	placement.unit_data = data
	# 칸.
	placement.cell = cell
	# 돌려준다.
	return placement


# 아군 a(속도 10, SP 3, 카드 6장)를 ally_cell 에, 적 e(속도 1, 기본 근접 사거리 1·피해 5)를 적 앞줄 가운데에 세운 전투.
func _state(ally_cell: Vector2i) -> BattleState:
	# 아군 데이터.
	var ally: AllyData = AllyDataScript.new()
	# id.
	ally.id = &"a"
	# 이름.
	ally.display_name = "a"
	# 최대 체력.
	ally.max_hp = 30
	# 먼저 행동하도록 빠르게.
	ally.speed = 10
	# SP.
	ally.max_sp = 3
	# 덱 배열.
	var deck: Array[CardData] = []
	# 카드 6장.
	for i in 6:
		# 빈 카드.
		var card: CardData = CardDataScript.new()
		# 구분용 id.
		card.id = StringName("c%d" % i)
		# 덱에 넣는다.
		deck.append(card)
	# 덱을 넣는다.
	ally.deck = deck

	# 적 데이터.
	var enemy: EnemyData = EnemyDataScript.new()
	# id.
	enemy.id = &"e"
	# 이름.
	enemy.display_name = "e"
	# 최대 체력.
	enemy.max_hp = 20
	# 늦게 행동하도록 느리게.
	enemy.speed = 1

	# 전투 구성 (격자 기본 3×3).
	var encounter: EncounterData = EncounterScript.new()
	# 아군 배치.
	var allies: Array[UnitPlacement] = [_placement(ally, ally_cell)]
	# 적 배치.
	var enemies: Array[UnitPlacement] = [_placement(enemy, Vector2i(0, 1))]
	# 아군 배치 넣기.
	encounter.ally_units = allies
	# 적 배치 넣기.
	encounter.enemy_units = enemies
	# 난수 생성기.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = 11
	# 전투 상태를 만든다.
	return BattleStateScript.new(encounter, rng)


# 단계·차례 시작·드로우·손패 버리기 신호를 "phase:a:STANDBY" 같은 문자열로 기록하는 배열을 연결해 돌려준다.
func _record(state: BattleState) -> Array:
	# 기록 배열.
	var seen: Array = []
	# 단계 시작 → "phase:유닛:단계이름".
	state.phase_started.connect(func(unit: Unit, started: BattleState.Phase) -> void:
		seen.append("phase:%s:%s" % [unit.data.id, BattleState.Phase.keys()[started]]))
	# 차례 시작 → "turn:유닛".
	state.turn_started.connect(func(unit: Unit) -> void:
		seen.append("turn:%s" % unit.data.id))
	# 드로우 → "drawn:유닛".
	state.card_drawn.connect(func(unit: Unit, _card: CardData, _deck_count: int, _discard_count: int) -> void:
		seen.append("drawn:%s" % unit.data.id))
	# 손패 버리기 → "discarded:유닛".
	state.hand_discarded.connect(func(unit: Unit, _cards: Array[CardData], _discard_count: int) -> void:
		seen.append("discarded:%s" % unit.data.id))
	# 기록 배열을 돌려준다.
	return seen


# 시작하면 스탠바이 → 차례 시작 → 드로우(4장) → 턴 행동 순서이고, 현재 단계가 턴 행동인지.
func _test_ally_turn_start_order() -> void:
	# 전투.
	var state: BattleState = _state(Vector2i(0, 1))
	# 기록 연결.
	var seen: Array = _record(state)
	# 시작.
	state.start_battle()
	# 신호 순서.
	check_eq("ally turn start phases", seen, ["phase:a:STANDBY", "turn:a", "phase:a:DRAW", "drawn:a", "drawn:a", "drawn:a", "drawn:a", "phase:a:ACTION"])
	# 입력을 기다리는 단계.
	check_eq("waiting in the action phase", state.phase, BattleState.Phase.ACTION)


# 차례 종료: 아군 종료 전 → 종료 후(버리기) → 적 다섯 단계(드로우 없음) → 다음 아군 차례 시작.
func _test_end_turn_runs_end_phases_then_enemy_turn() -> void:
	# 전투.
	var state: BattleState = _state(Vector2i(0, 1))
	# 시작.
	state.start_battle()
	# 여기서부터 기록.
	var seen: Array = _record(state)
	# 차례 종료.
	state.end_turn()
	# 전체 순서 (적 드로우 단계에는 drawn 이 없다).
	check_eq("end phases, enemy phases, next ally start", seen, ["phase:a:BEFORE_END", "phase:a:AFTER_END", "discarded:a", "phase:e:STANDBY", "turn:e", "phase:e:DRAW", "phase:e:ACTION", "phase:e:BEFORE_END", "phase:e:AFTER_END", "phase:a:STANDBY", "turn:a", "phase:a:DRAW", "drawn:a", "drawn:a", "drawn:a", "drawn:a", "phase:a:ACTION"])


# 스탠바이 신호가 날 때는 이전 block·SP 이고, 차례 시작 신호가 날 때는 초기화된 값인지.
func _test_standby_resets_before_turn_started() -> void:
	# 아군이 뒷줄(2,1)이라 사거리 1 적에게 맞지 않는다.
	var state: BattleState = _state(Vector2i(2, 1))
	# 시작.
	state.start_battle()
	# 아군 유닛.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 이전 차례에 방어도가 남았다고 가정한다.
	ally.block = 7
	# SP 를 다 썼다고 가정한다.
	ally.sp = 0
	# 시점별 값을 담을 사전.
	var seen: Dictionary = {}
	# 아군의 스탠바이 신호 시점 값을 기록한다.
	state.phase_started.connect(func(unit: Unit, started: BattleState.Phase) -> void:
		if unit == ally and started == BattleState.Phase.STANDBY:
			seen["standby"] = [unit.block, unit.sp])
	# 아군의 차례 시작 신호 시점 값을 기록한다.
	state.turn_started.connect(func(unit: Unit) -> void:
		if unit == ally:
			seen["turn"] = [unit.block, unit.sp])
	# 차례 종료 → 적 차례(방어) → 아군 다음 차례.
	state.end_turn()
	# 스탠바이 시점 block 은 이전 값.
	check_eq("block still old at standby signal", seen["standby"][0], 7)
	# 스탠바이 시점 SP 는 이전 값.
	check_eq("sp still old at standby signal", seen["standby"][1], 0)
	# 차례 시작 시점 block 은 0.
	check_eq("block reset by turn_started", seen["turn"][0], 0)
	# 차례 시작 시점 SP 는 최대.
	check_eq("sp refilled by turn_started", seen["turn"][1], 3)


# 적 공격으로 마지막 아군이 쓰러지면 전투가 끝나고 적의 종료 전·종료 후 단계는 오지 않는지.
func _test_battle_end_skips_end_phases() -> void:
	# 아군이 적 사거리 안(0,1).
	var state: BattleState = _state(Vector2i(0, 1))
	# 시작.
	state.start_battle()
	# 아군 체력을 1 로 만든다.
	state.living_units(Unit.Team.ALLY)[0].take_damage(29)
	# 여기서부터 기록.
	var seen: Array = _record(state)
	# 차례 종료 → 적이 공격해 아군이 쓰러진다.
	state.end_turn()
	# 적 턴 행동에서 끝난다.
	check_eq("stops after the enemy action phase", seen, ["phase:a:BEFORE_END", "phase:a:AFTER_END", "discarded:a", "phase:e:STANDBY", "turn:e", "phase:e:DRAW", "phase:e:ACTION"])
	# 전투 종료.
	check("battle finished", state.finished)
```

`tests/run_tests.gd` 의 `TEST_SCRIPTS` 에서 `"res://tests/test_hand_view.gd",` 다음 줄에 추가:

```gdscript
	"res://tests/test_turn_phases.gd",
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: 테스트 명령
Expected: `test_turn_phases.gd` 가 로드되지 않거나(`phase_started`/`Phase` 없음) FAIL. 나머지 359 개는 PASS.

- [ ] **Step 3: 구현**

`Scripts/combat/battle_state.gd` 에서:

(a) 아래 두 줄 바로 뒤에

```gdscript
## 차례가 끝나 손패를 버렸다. cards 는 버린 카드들, discard_count 는 버린 뒤 묘지 장수.
signal hand_discarded(unit: Unit, cards: Array[CardData], discard_count: int)
```

추가:

```gdscript
## 한 차례의 단계. 아군·적 모두 이 순서로 진행한다.
## STANDBY 스탠바이(block 초기화·SP 회복), DRAW 드로우, ACTION 턴 행동, BEFORE_END 종료 전, AFTER_END 종료 후(손패 버리기).
enum Phase { STANDBY, DRAW, ACTION, BEFORE_END, AFTER_END }
## 차례의 한 단계가 시작됐다. 단계 값을 바꾼 직후, 그 단계의 처리보다 먼저 나간다.
signal phase_started(unit: Unit, phase: Phase)
```

(b) 아래 두 줄 바로 뒤에

```gdscript
## 끝났을 때 아군이 이겼으면 true.
var ally_won: bool = false
```

추가:

```gdscript
## 지금 진행 중인 차례 단계.
var phase: Phase = Phase.STANDBY
```

(c) `end_turn` 전체를 바꾼다. 기존:

```gdscript
## 지금 차례인 아군의 차례를 끝낸다. 손패를 버리고 다음 아군 차례까지 진행한다.
func end_turn() -> void:
	# 지금 차례인 유닛을 가져온다.
	var actor: Unit = current_unit()
	# 아군 차례였다면 남은 손패를 묘지로 버린다.
	if actor != null and actor.is_ally():
		_discard_hand(actor)
	# 다음 아군 차례가 올 때까지 진행한다.
	_run_until_player_input()
```

새로:

```gdscript
## 지금 차례인 아군의 차례를 끝낸다. 종료 전 → 종료 후(손패 버리기) 단계를 지나 다음 아군 차례까지 진행한다.
func end_turn() -> void:
	# 지금 차례인 유닛을 가져온다.
	var actor: Unit = current_unit()
	# 아군 차례였다면 종료 단계들을 진행한다.
	if actor != null and actor.is_ally():
		# 종료 전 → 종료 후. 손패는 종료 후 단계에서 버린다.
		_end_phases(actor)
	# 다음 아군 차례가 올 때까지 진행한다.
	_run_until_player_input()
```

(d) `_run_until_player_input` 의 문서 주석 한 줄

```gdscript
## 전투를 다음 입력 지점(아군 차례)까지 진행한다.
```

을

```gdscript
## 전투를 다음 입력 지점(아군의 턴 행동 단계)까지 진행한다.
```

으로 바꾸고, 같은 함수에서 `		# 방어도는 자기 차례가 시작될 때 사라진다 (한 바퀴 동안만 유지).` 줄부터 함수 마지막 줄 `		check_end()` 까지를 아래로 바꾼다:

```gdscript
		# 스탠바이 → 차례 시작 알림 → 드로우.
		_start_phases(actor)
		# 턴 행동 단계로 들어간다.
		_enter_phase(actor, Phase.ACTION)

		# 아군이면 여기서 멈추고 플레이어 입력을 기다린다 — 다음 진행은 end_turn() 이 이어 간다.
		if actor.is_ally():
			return

		# 적이면 AI 가 바로 행동한다.
		_take_enemy_turn(actor)
		# 적 행동으로 전투가 끝났는지 확인한다.
		check_end()
		# 전투가 끝났으면 남은 단계는 진행하지 않는다.
		if finished:
			return
		# 종료 전 → 종료 후.
		_end_phases(actor)
```

(e) `_run_until_player_input` 함수 바로 뒤, `# Unit.draw 와 같은 순서로 한 장씩 진행하되,` 주석 줄 앞에 추가:

```gdscript
## 현재 단계를 바꾸고 단계 시작 신호를 낸다.
func _enter_phase(actor: Unit, next_phase: Phase) -> void:
	# 현재 단계를 바꾼다.
	phase = next_phase
	# 단계 시작 신호를 낸다 (그 단계의 처리보다 먼저).
	phase_started.emit(actor, next_phase)


## 스탠바이(block 초기화·SP 회복) → 차례 시작 알림 → 드로우 단계를 진행한다.
func _start_phases(actor: Unit) -> void:
	# 스탠바이 단계.
	_enter_phase(actor, Phase.STANDBY)
	# 방어도는 자기 차례가 시작될 때 사라진다 (한 바퀴 동안만 유지).
	actor.block = 0
	# 아군이면 SP 를 최대치로 채운다.
	if actor.is_ally():
		actor.sp = (actor.data as AllyData).max_sp
	# 초기화된 값이 기록되도록 스탠바이 처리 뒤에 차례 시작을 알린다.
	turn_started.emit(actor)
	# 드로우 단계.
	_enter_phase(actor, Phase.DRAW)
	# 아군만 카드를 뽑는다 (적은 덱이 없어 단계만 지나간다).
	if actor.is_ally():
		_draw_cards(actor, DRAW_PER_TURN)


## 종료 전 → 종료 후 단계를 진행한다. 아군은 종료 후 단계에서 손패를 버린다.
func _end_phases(actor: Unit) -> void:
	# 종료 전 단계 (지금은 처리할 일이 없다).
	_enter_phase(actor, Phase.BEFORE_END)
	# 종료 후 단계.
	_enter_phase(actor, Phase.AFTER_END)
	# 아군이면 남은 손패를 묘지로 버린다.
	if actor.is_ally():
		_discard_hand(actor)
```

(f) 파일 맨 위 `##` 클래스 설명의 흐름 줄

```gdscript
## 흐름: start_battle() → (아군 차례에서 멈춤) → play_card() 여러 번 → end_turn() → (적 차례 자동 처리) → 다음 아군 차례에서 멈춤 ...
```

아래에 한 줄 추가:

```gdscript
## 한 차례는 Phase 순서(스탠바이 → 드로우 → 턴 행동 → 종료 전 → 종료 후)로 진행하고, 아군은 턴 행동 단계에서 멈춘다.
```

- [ ] **Step 4: 테스트 통과 확인**

Run: 테스트 명령
Expected: `368/368 passed`

- [ ] **Step 5: 커밋**

```bash
git add Scripts/combat/battle_state.gd tests/test_turn_phases.gd tests/run_tests.gd
git commit -F - <<'EOF'
feat: run each turn through standby, draw, action and end phases

Co-Authored-By: <구현 모델 이름> <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017G27EF6BYVPF1Bk3fvY2mz
EOF
```

---

### Task 2: 아군 이동 규칙

**Files:**
- Modify: `Scripts/combat/target_resolver.gd`
- Modify: `Scripts/combat/battle_state.gd`
- Modify: `tests/test_target_resolver.gd`
- Create: `tests/test_movement.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: T1 의 `BattleState` (턴 행동 단계에서 아군 차례 멈춤)
- Produces: `const TargetResolver.MOVE_DIRECTIONS: Array[Vector2i]`, `func TargetResolver.grid_for(team: Unit.Team) -> Vector2i`, `func TargetResolver.movable_cells(unit: Unit, all_units: Array[Unit]) -> Array[Vector2i]`, `signal BattleState.unit_moved(unit: Unit, from_cell: Vector2i, to_cell: Vector2i)`, `func BattleState.move_unit(to_cell: Vector2i) -> bool`, `func BattleState.apply_move(unit: Unit, to_cell: Vector2i) -> void` (로그 `"%s 이동" % display_name`)

- [ ] **Step 1: 실패하는 테스트 작성**

(a) `tests/test_target_resolver.gd` 의 `run()` 에서 `	_test_expand_sweep()` 줄 다음에 추가:

```gdscript
	# 가운데 칸의 이동 후보 네 칸.
	_test_movable_cells_in_the_middle()
	# 모서리 칸의 이동 후보 두 칸.
	_test_movable_cells_at_a_corner()
	# 살아 있는 유닛 칸은 빼고 쓰러진 유닛 칸은 넣는다.
	_test_movable_cells_skip_living_units()
	# 자기 편 격자 크기 안에서만.
	_test_movable_cells_stay_in_own_grid()
```

파일 끝에 추가:

```gdscript


# 3×3 가운데(1,1) 유닛은 위·아래·앞·뒤 순서로 네 칸에 갈 수 있는지.
func _test_movable_cells_in_the_middle() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 가운데 아군.
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(1, 1))
	# 전장 유닛 목록.
	var all: Array[Unit] = [a]
	# 기대값: 위(1,0), 아래(1,2), 앞(0,1), 뒤(2,1) (타입 있는 배열끼리 비교한다).
	var expected: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 2), Vector2i(0, 1), Vector2i(2, 1)]
	# 순서까지 같다.
	check_eq("middle cell has four moves in fixed order", resolver.movable_cells(a, all), expected)


# 모서리(0,0) 유닛은 아래와 뒤 두 칸만 갈 수 있는지.
func _test_movable_cells_at_a_corner() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 모서리 아군.
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 0))
	# 전장 유닛 목록.
	var all: Array[Unit] = [a]
	# 기대값: 아래(0,1), 뒤(1,0).
	var expected: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0)]
	# 두 칸.
	check_eq("corner cell has two moves", resolver.movable_cells(a, all), expected)


# 같은 편 살아 있는 유닛 칸은 빠지고, 쓰러진 유닛 칸과 다른 편 같은 좌표는 막지 않는지.
func _test_movable_cells_skip_living_units() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 가운데 아군.
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(1, 1))
	# 위 칸의 살아 있는 아군.
	var blocker: Unit = _unit(2, Unit.Team.ALLY, Vector2i(1, 0))
	# 아래 칸의 쓰러진 아군.
	var fallen: Unit = _unit(3, Unit.Team.ALLY, Vector2i(1, 2))
	# 쓰러뜨린다.
	fallen.take_damage(999)
	# 앞 칸과 같은 좌표에 선 적 (다른 편 격자라 막지 않는다).
	var foe: Unit = _unit(4, Unit.Team.ENEMY, Vector2i(0, 1))
	# 전장 유닛 목록.
	var all: Array[Unit] = [a, blocker, fallen, foe]
	# 기대값: 위는 막히고 아래·앞·뒤는 열린다.
	var expected: Array[Vector2i] = [Vector2i(1, 2), Vector2i(0, 1), Vector2i(2, 1)]
	# 비교.
	check_eq("living ally blocks, fallen ally and enemy side do not", resolver.movable_cells(a, all), expected)


# 적 격자가 2×2 이면 (1,1) 적은 위(1,0)와 앞(0,1)만 갈 수 있는지.
func _test_movable_cells_stay_in_own_grid() -> void:
	# 아군 3×3, 적군 2×2.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(2, 2))
	# 적 격자 오른쪽 아래 칸의 적.
	var e: Unit = _unit(1, Unit.Team.ENEMY, Vector2i(1, 1))
	# 전장 유닛 목록.
	var all: Array[Unit] = [e]
	# 기대값: 위(1,0)와 앞(0,1) — 아래(1,2)와 뒤(2,1)는 격자 밖.
	var expected: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	# 비교.
	check_eq("moves stay inside the unit's own grid", resolver.movable_cells(e, all), expected)
```

(b) `tests/test_movement.gd` 를 만든다:

```gdscript
# BattleState.move_unit(아군 이동) 테스트: 성공 시 SP·칸·신호·로그, 각종 거절, SP 가 남는 동안 연속 이동, 이동 후 사거리.
extends TestCase

# 전투 상태 스크립트.
const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
# 아군 데이터 스크립트.
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
# 적 데이터 스크립트.
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
# 배치 데이터 스크립트.
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
# 전투 구성 스크립트.
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 성공한 이동의 결과.
	_test_move_spends_sp_and_moves()
	# 규칙에 맞지 않는 칸 거절.
	_test_rejects_invalid_cells()
	# 아군 차례가 아니면 거절.
	_test_rejects_outside_an_ally_turn()
	# SP 가 남는 동안 연속 이동.
	_test_moves_while_sp_lasts()
	# 이동하면 사거리가 새 칸 기준.
	_test_reach_follows_the_new_cell()
	# 결과를 돌려준다.
	return results()


# 데이터와 칸으로 배치 한 줄을 만든다.
func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	# 배치 리소스.
	var placement: UnitPlacement = PlacementScript.new()
	# 유닛 데이터.
	placement.unit_data = data
	# 칸.
	placement.cell = cell
	# 돌려준다.
	return placement


# id·속도를 정한 아군 데이터 (체력 30, SP 3, 덱 없음).
func _ally(id: StringName, speed: int) -> AllyData:
	# 아군 데이터.
	var data: AllyData = AllyDataScript.new()
	# id.
	data.id = id
	# 이름은 id 와 같게.
	data.display_name = String(id)
	# 최대 체력.
	data.max_hp = 30
	# 속도.
	data.speed = speed
	# SP 3.
	data.max_sp = 3
	# 돌려준다.
	return data


# 아군 a(속도 10)를 a_cell 에, 아군 b(속도 5)를 (0,0) 에, 적 e(속도 1)를 적 (0,1) 에 세우고 전투를 시작한다 (a 차례에서 멈춤).
func _started_state(a_cell: Vector2i) -> BattleState:
	# 적 데이터.
	var enemy: EnemyData = EnemyDataScript.new()
	# id.
	enemy.id = &"e"
	# 이름.
	enemy.display_name = "e"
	# 최대 체력.
	enemy.max_hp = 20
	# 가장 느리게.
	enemy.speed = 1

	# 전투 구성 (격자 기본 3×3).
	var encounter: EncounterData = EncounterScript.new()
	# 아군 배치: a 는 a_cell, b 는 (0,0).
	var allies: Array[UnitPlacement] = [_placement(_ally(&"a", 10), a_cell), _placement(_ally(&"b", 5), Vector2i(0, 0))]
	# 적 배치.
	var enemies: Array[UnitPlacement] = [_placement(enemy, Vector2i(0, 1))]
	# 아군 배치 넣기.
	encounter.ally_units = allies
	# 적 배치 넣기.
	encounter.enemy_units = enemies
	# 난수 생성기.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = 21
	# 전투 상태.
	var state: BattleState = BattleStateScript.new(encounter, rng)
	# 시작 (a 의 턴 행동 단계에서 멈춘다).
	state.start_battle()
	# 돌려준다.
	return state


# id 로 전투 속 유닛을 찾는다.
func _unit(state: BattleState, id: StringName) -> Unit:
	# 모든 유닛 중.
	for unit in state.units:
		# id 가 같으면.
		if unit.data.id == id:
			# 그 유닛.
			return unit
	# 못 찾음.
	return null


# (1,1) 에서 뒤(2,1)로 이동: true, 새 칸, SP 3→2, 이동 신호의 두 칸, 로그 "a 이동".
func _test_move_spends_sp_and_moves() -> void:
	# a 가 (1,1) 인 전투.
	var state: BattleState = _started_state(Vector2i(1, 1))
	# a 유닛.
	var a: Unit = _unit(state, &"a")
	# 이동 신호 기록.
	var moved: Array = []
	# 이동 신호를 [id, 이전 칸, 새 칸] 으로 기록한다.
	state.unit_moved.connect(func(unit: Unit, from_cell: Vector2i, to_cell: Vector2i) -> void: moved.append([unit.data.id, from_cell, to_cell]))
	# 로그 기록.
	var logs: Array = []
	# 로그를 기록한다.
	state.log_message.connect(func(text: String) -> void: logs.append(text))
	# 이동 성공.
	check("move accepted", state.move_unit(Vector2i(2, 1)))
	# 새 칸.
	check_eq("unit stands on the new cell", a.cell, Vector2i(2, 1))
	# SP 2.
	check_eq("one sp spent", a.sp, 2)
	# 신호 인자.
	check_eq("move signal carries both cells", moved, [[&"a", Vector2i(1, 1), Vector2i(2, 1)]])
	# 로그.
	check_eq("move logged", logs, ["a 이동"])


# (0,1) 에서 대각선·두 칸·점유 칸·격자 밖은 거절되고 칸·SP 가 그대로이며, SP 0 이면 빈 칸도 거절되는지.
func _test_rejects_invalid_cells() -> void:
	# a 가 (0,1) 인 전투 (b 가 위 칸 (0,0) 에 있다).
	var state: BattleState = _started_state(Vector2i(0, 1))
	# a 유닛.
	var a: Unit = _unit(state, &"a")
	# 대각선.
	check("diagonal rejected", not state.move_unit(Vector2i(1, 2)))
	# 두 칸.
	check("two cells rejected", not state.move_unit(Vector2i(2, 1)))
	# b 가 선 칸.
	check("occupied cell rejected", not state.move_unit(Vector2i(0, 0)))
	# 격자 밖.
	check("outside the grid rejected", not state.move_unit(Vector2i(-1, 1)))
	# 칸 그대로.
	check_eq("cell unchanged", a.cell, Vector2i(0, 1))
	# SP 그대로.
	check_eq("sp unchanged", a.sp, 3)
	# SP 를 다 썼다고 가정한다.
	a.sp = 0
	# 비어 있는 아래 칸도 거절.
	check("no sp rejected", not state.move_unit(Vector2i(0, 2)))


# 끝난 전투와 적 차례에서는 이동이 거절되는지.
func _test_rejects_outside_an_ally_turn() -> void:
	# 끝난 전투.
	var finished_state: BattleState = _started_state(Vector2i(0, 1))
	# 끝난 것으로 표시.
	finished_state.finished = true
	# 거절.
	check("finished battle rejects moves", not finished_state.move_unit(Vector2i(0, 2)))
	# 적 차례 전투.
	var enemy_turn: BattleState = _started_state(Vector2i(0, 1))
	# 행동 순서를 적 하나로 바꾼다.
	enemy_turn.initiative = [_unit(enemy_turn, &"e")]
	# 그 적의 차례.
	enemy_turn.turn_index = 0
	# 거절.
	check("enemy turn rejects moves", not enemy_turn.move_unit(Vector2i(0, 2)))


# SP 3 으로 세 번 이동한 뒤 네 번째는 거절되는지.
func _test_moves_while_sp_lasts() -> void:
	# a 가 (0,1) 인 전투.
	var state: BattleState = _started_state(Vector2i(0, 1))
	# a 유닛.
	var a: Unit = _unit(state, &"a")
	# (1,1) → (2,1) → (2,2) → (2,1) 순서로 시도한다.
	var accepted: Array = [state.move_unit(Vector2i(1, 1)), state.move_unit(Vector2i(2, 1)), state.move_unit(Vector2i(2, 2)), state.move_unit(Vector2i(2, 1))]
	# 세 번 성공, 네 번째 실패.
	check_eq("three moves then out of sp", accepted, [true, true, true, false])
	# SP 0.
	check_eq("sp used up", a.sp, 0)
	# 세 번째 칸에 멈췄다.
	check_eq("stopped on the third cell", a.cell, Vector2i(2, 2))


# 앞줄에서 적까지 거리 1, 한 칸 뒤로 가면 거리 2 인지.
func _test_reach_follows_the_new_cell() -> void:
	# a 가 (0,1) 인 전투.
	var state: BattleState = _started_state(Vector2i(0, 1))
	# a 유닛.
	var a: Unit = _unit(state, &"a")
	# 적 유닛.
	var e: Unit = _unit(state, &"e")
	# 앞줄끼리 1.
	check_eq("front rank reach", state.resolver.reach(a, e), 1)
	# 한 칸 뒤로.
	state.move_unit(Vector2i(1, 1))
	# 2.
	check_eq("one step back adds one", state.resolver.reach(a, e), 2)
```

(c) `tests/run_tests.gd` 의 `TEST_SCRIPTS` 에서 `"res://tests/test_turn_phases.gd",` 다음 줄에 추가:

```gdscript
	"res://tests/test_movement.gd",
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: 테스트 명령
Expected: `test_target_resolver.gd` 와 `test_movement.gd` 가 로드되지 않거나(`movable_cells`/`move_unit` 없음) FAIL.

- [ ] **Step 3: 구현**

(a) `Scripts/combat/target_resolver.gd` 에서 아래 두 줄 바로 뒤에

```gdscript
## 적군 격자 크기 (x = 열 수, y = 행 수).
var enemy_grid: Vector2i
```

추가:

```gdscript

## 한 칸 이동 방향 후보. 위, 아래, 앞(적 쪽), 뒤 순서로 고정해 무작위 선택이 시드마다 재현되게 한다.
const MOVE_DIRECTIONS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
```

`rows_for` 함수 바로 뒤에 추가:

```gdscript


## 주어진 편 격자의 크기를 돌려준다.
func grid_for(team: Unit.Team) -> Vector2i:
	# 아군이면 아군 격자, 아니면 적군 격자.
	return ally_grid if team == Unit.Team.ALLY else enemy_grid
```

파일 끝에 추가:

```gdscript


## 유닛이 지금 한 칸 이동할 수 있는 칸 목록 (MOVE_DIRECTIONS 순서).
## 자기 편 격자 안이고 살아 있는 유닛이 없는 상하좌우 칸만 들어간다.
func movable_cells(unit: Unit, all_units: Array[Unit]) -> Array[Vector2i]:
	# 결과를 담을 배열.
	var cells: Array[Vector2i] = []
	# 그 편 격자 크기.
	var grid: Vector2i = grid_for(unit.team)
	# 네 방향마다.
	for direction in MOVE_DIRECTIONS:
		# 한 칸 옮긴 좌표.
		var cell: Vector2i = unit.cell + direction
		# 격자 밖이면 건너뛴다.
		if cell.x < 0 or cell.y < 0 or cell.x >= grid.x or cell.y >= grid.y:
			continue
		# 살아 있는 유닛이 있으면 건너뛴다.
		if _occupied(unit.team, cell, all_units):
			continue
		# 갈 수 있는 칸이다.
		cells.append(cell)
	# 모은 칸을 돌려준다.
	return cells


## 그 편의 그 칸에 살아 있는 유닛이 있으면 true. 쓰러진 유닛은 칸을 막지 않는다.
func _occupied(team: Unit.Team, cell: Vector2i, all_units: Array[Unit]) -> bool:
	# 모든 유닛을 확인한다.
	for other in all_units:
		# 같은 편, 같은 칸, 살아 있음이면 막혀 있다.
		if other.team == team and other.cell == cell and other.is_alive():
			return true
	# 비어 있다.
	return false
```

(b) `Scripts/combat/battle_state.gd` 에서 T1 이 추가한 두 줄

```gdscript
## 차례의 한 단계가 시작됐다. 단계 값을 바꾼 직후, 그 단계의 처리보다 먼저 나간다.
signal phase_started(unit: Unit, phase: Phase)
```

바로 뒤에 추가:

```gdscript
## 유닛이 한 칸 이동했다.
signal unit_moved(unit: Unit, from_cell: Vector2i, to_cell: Vector2i)
```

`play_card` 함수 끝(`	# 성공.` / `	return true`) 바로 뒤, `## 전투를 시작한다.` 문서 주석 앞에 추가:

```gdscript


## 지금 차례인 아군이 SP 1 을 써서 to_cell 로 한 칸 이동한다.
## 규칙에 맞지 않으면 아무것도 바꾸지 않고 false 를 돌려준다. 성공하면 true.
func move_unit(to_cell: Vector2i) -> bool:
	# 끝난 전투에서는 이동할 수 없다.
	if finished:
		return false
	# 지금 차례인 유닛.
	var actor: Unit = current_unit()
	# 차례 유닛이 없거나, 적이거나, 쓰러졌으면 이동할 수 없다.
	if actor == null or not actor.is_ally() or not actor.is_alive():
		return false
	# SP 가 없으면 이동할 수 없다.
	if actor.sp < 1:
		return false
	# 상하좌우 빈 칸이 아니면 이동할 수 없다.
	if not resolver.movable_cells(actor, units).has(to_cell):
		return false
	# SP 1 을 쓴다.
	actor.sp -= 1
	# 옮기고 알린다.
	apply_move(actor, to_cell)
	# 성공.
	return true


## 검사 없이 유닛을 to_cell 로 옮기고 알린다 (아군 move_unit 과 EnemyBrain 이 부르는 통로).
func apply_move(unit: Unit, to_cell: Vector2i) -> void:
	# 원래 칸을 기억한다.
	var from_cell: Vector2i = unit.cell
	# 칸을 바꾼다.
	unit.cell = to_cell
	# 이동 신호를 낸다.
	unit_moved.emit(unit, from_cell, to_cell)
	# 로그에 남긴다.
	write_log("%s 이동" % unit.data.display_name)
```

(`play_card` 뒤에 빈 줄이 두 줄이 되도록 정리한다 — 함수 사이 빈 줄 2개가 이 파일의 규칙.)

- [ ] **Step 4: 테스트 통과 확인**

Run: 테스트 명령
Expected: `391/391 passed`

- [ ] **Step 5: 커밋**

```bash
git add Scripts/combat/target_resolver.gd Scripts/combat/battle_state.gd tests/test_target_resolver.gd tests/test_movement.gd tests/run_tests.gd
git commit -F - <<'EOF'
feat: let the acting ally spend SP to step into an empty adjacent cell

Co-Authored-By: <구현 모델 이름> <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017G27EF6BYVPF1Bk3fvY2mz
EOF
```

---

### Task 3: 적 이동 AI

**Files:**
- Modify: `Scripts/combat/data/enemy_data.gd`
- Modify: `Scripts/combat/enemy_brain.gd`
- Modify: `Scripts/combat/battle_state.gd`
- Modify: `tests/test_enemy_brain.gd`, `tests/test_card_zone_signals.gd`, `tests/test_battle_signals.gd`, `tests/test_event_recorder.gd`, `tests/test_turn_order.gd`, `tests/test_battle_playback.gd`, `tests/test_turn_phases.gd`

**Interfaces:**
- Consumes: T2 의 `TargetResolver.movable_cells`, `BattleState.apply_move`
- Produces: `@export var EnemyData.move_chance: float = 0.25`, `enum EnemyBrain.Action { ATTACK, DEFEND, REST, MOVE }`, `var BattleState.ai_rng: RandomNumberGenerator`

- [ ] **Step 1: 기존 테스트의 적 무작위 이동 끄기 + 실패하는 테스트 작성**

기존 적 데이터 빌더마다 `move_chance = 0.0` 을 넣는다 (지금은 속성이 없어 로드 실패 — RED 의 일부).

(a) `tests/test_enemy_brain.gd`:

`_enemy` 에서

```gdscript
	# 휴식 행동의 회복량.
	data.rest_heal = rest_heal
```

바로 뒤에 추가:

```gdscript
	# 무작위 이동을 끈다 (기존 결정론적 결과를 확인하기 위해).
	data.move_chance = 0.0
```

`_state` 함수 전체를 바꾼다. 기존:

```gdscript
# 아군 배치 목록과 적 한 명(앞줄 가운데)으로 전투 상태를 만든다 (시작하지는 않음).
func _state(allies: Array, enemy: EnemyData) -> BattleState:
	# 타입이 있는 아군 배치 배열.
	var ally_placements: Array[UnitPlacement] = []
	# 받은 배치들을 넣는다.
	ally_placements.append_array(allies)
	# 적 배치 배열.
	var enemy_placements: Array[UnitPlacement] = []
	# 적 한 명을 앞줄 가운데에.
	enemy_placements.append(_placement(enemy, Vector2i(0, 1)))

	# 전투 구성.
	var encounter: EncounterData = EncounterScript.new()
	# 아군 격자 3×3.
	encounter.ally_grid = Vector2i(3, 3)
	# 적군 격자 3×3.
	encounter.enemy_grid = Vector2i(3, 3)
```

새로:

```gdscript
# 아군 배치 목록과 적 한 명으로 전투 상태를 만든다 (시작하지는 않음).
# 적 격자 크기와 적 칸을 바꿀 수 있다 (기본: 3×3 격자의 앞줄 가운데).
func _state(allies: Array, enemy: EnemyData, enemy_grid: Vector2i = Vector2i(3, 3), enemy_cell: Vector2i = Vector2i(0, 1)) -> BattleState:
	# 타입이 있는 아군 배치 배열.
	var ally_placements: Array[UnitPlacement] = []
	# 받은 배치들을 넣는다.
	ally_placements.append_array(allies)
	# 적 배치 배열.
	var enemy_placements: Array[UnitPlacement] = []
	# 적 한 명을 지정한 칸에.
	enemy_placements.append(_placement(enemy, enemy_cell))

	# 전투 구성.
	var encounter: EncounterData = EncounterScript.new()
	# 아군 격자 3×3.
	encounter.ally_grid = Vector2i(3, 3)
	# 적군 격자.
	encounter.enemy_grid = enemy_grid
```

`run()` 에서 `	_test_deterministic_across_runs()` 줄 다음에 추가:

```gdscript
	# 확률이 맞으면 이동한다.
	_test_moves_when_the_roll_hits()
	# 막혔으면 공격·방어·휴식 중 무작위.
	_test_blocked_move_picks_another_action()
	# 확률 0 이면 난수를 쓰지 않는다.
	_test_zero_chance_uses_no_randomness()
	# 같은 시드면 같은 칸으로 이동한다.
	_test_same_seed_same_moves()
```

파일 끝에 추가:

```gdscript


# move_chance 1 이면 이동을 고르고, 앞줄 가운데(0,1)에서 위·아래·뒤 중 한 칸으로 옮기며, 공격은 하지 않는지.
func _test_moves_when_the_roll_hits() -> void:
	# 이동 확률 100% 적.
	var mover: EnemyData = _enemy(5, 6, 5, 4)
	# 항상 이동을 고른다.
	mover.move_chance = 1.0
	# 아군 하나와 적 하나.
	var state: BattleState = _state([_placement(_ally(&"a", 30), Vector2i(0, 1))], mover)
	# 적 유닛.
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 이동을 고른다.
	check_eq("certain roll picks move", BrainScript.decide(state, foe), BrainScript.Action.MOVE)
	# 차례를 진행한다.
	BrainScript.take_turn(state, foe)
	# 원래 칸을 떠났다.
	check("moved off the starting cell", foe.cell != Vector2i(0, 1))
	# 위(0,0)·아래(0,2)·뒤(1,1) 중 하나 (앞은 격자 밖).
	check("moved one step up, down or back", [Vector2i(0, 0), Vector2i(0, 2), Vector2i(1, 1)].has(foe.cell))
	# 이동이 그 차례의 행동 전부라 아군은 맞지 않았다.
	check_eq("moving is the whole action", state.living_units(Unit.Team.ALLY)[0].hp, 30)


# 1×1 적 격자라 갈 칸이 없으면 이동 대신 공격·방어·휴식 중에서 고르고, 칠 대상이 없으면 공격은 후보에서 빠지는지.
func _test_blocked_move_picks_another_action() -> void:
	# 이동 확률 100% 적 (사거리 5).
	var mover: EnemyData = _enemy(5, 6, 5, 4)
	# 항상 이동을 시도한다.
	mover.move_chance = 1.0
	# 1×1 적 격자, 아군은 사거리 안.
	var state: BattleState = _state([_placement(_ally(&"a", 30), Vector2i(0, 1))], mover, Vector2i(1, 1), Vector2i(0, 0))
	# 적 유닛.
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 30 번 고른 결과.
	var picks: Array = []
	# 반복해서 고른다.
	for i in 30:
		picks.append(BrainScript.decide(state, foe))
	# 이동은 없다.
	check("blocked mover never picks MOVE", not picks.has(BrainScript.Action.MOVE))
	# 칠 대상이 있으니 공격도 나온다.
	check("blocked mover can attack a reachable target", picks.has(BrainScript.Action.ATTACK))
	# 방어나 휴식도 나온다.
	check("blocked mover can also defend or rest", picks.has(BrainScript.Action.DEFEND) or picks.has(BrainScript.Action.REST))

	# 사거리 1 적, 아군은 뒷줄(2,1)이라 칠 대상이 없다.
	var shy: EnemyData = _enemy(1, 6, 5, 4)
	# 항상 이동을 시도한다.
	shy.move_chance = 1.0
	# 1×1 적 격자.
	var far_state: BattleState = _state([_placement(_ally(&"far", 30), Vector2i(2, 1))], shy, Vector2i(1, 1), Vector2i(0, 0))
	# 적 유닛.
	var far_foe: Unit = far_state.living_units(Unit.Team.ENEMY)[0]
	# 30 번 고른 결과.
	var far_picks: Array = []
	# 반복해서 고른다.
	for i in 30:
		far_picks.append(BrainScript.decide(far_state, far_foe))
	# 공격은 없다.
	check("no attack without a target", not far_picks.has(BrainScript.Action.ATTACK))
	# 방어와 휴식이 둘 다 나온다.
	check("falls back to defend and rest", far_picks.has(BrainScript.Action.DEFEND) and far_picks.has(BrainScript.Action.REST))


# move_chance 0 이면 기존 규칙(공격)을 고르고 적 전용 난수 상태가 그대로인지.
func _test_zero_chance_uses_no_randomness() -> void:
	# 이동 확률 0 적 (_enemy 기본값).
	var state: BattleState = _state([_placement(_ally(&"a", 30), Vector2i(0, 1))], _enemy(5, 6, 5, 4))
	# 적 유닛.
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 고르기 전 난수 상태.
	var before: int = state.ai_rng.state
	# 기존 규칙대로 공격.
	check_eq("zero chance keeps the old choice", BrainScript.decide(state, foe), BrainScript.Action.ATTACK)
	# 난수를 쓰지 않았다.
	check_eq("zero chance draws no random number", state.ai_rng.state, before)


# 같은 시드로 만든 두 전투에서 이동 확률 100% 적이 같은 칸으로 가는지.
func _test_same_seed_same_moves() -> void:
	# 두 전투의 이동 결과.
	var cells: Array = []
	# 두 번 반복한다.
	for i in 2:
		# 이동 확률 100% 적.
		var mover: EnemyData = _enemy(5, 6, 5, 4)
		# 항상 이동한다.
		mover.move_chance = 1.0
		# 같은 시드(_rng 4242)의 전투.
		var state: BattleState = _state([_placement(_ally(&"a", 30), Vector2i(0, 1))], mover)
		# 적 유닛.
		var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
		# 차례를 진행한다.
		BrainScript.take_turn(state, foe)
		# 도착 칸을 기록한다.
		cells.append(foe.cell)
	# 둘이 같다.
	check_eq("same seed moves to the same cell", cells[0], cells[1])
```

(b) `tests/test_card_zone_signals.gd`:

`_state` 의 첫 두 줄

```gdscript
# 적 e(속도 1)는 기본 근접 공격으로 아군을 치기만 한다. 카드와 난수에 영향이 없다.
func _state(ally: AllyData) -> BattleState:
```

을 바꾼다:

```gdscript
# 적 e(속도 1)는 기본 근접 공격으로 아군을 친다. move_chance 로 무작위 이동을 켤 수 있다 (기본 0).
# 적 AI 는 전용 난수(ai_rng)를 쓰므로 카드 순서에 영향이 없다.
func _state(ally: AllyData, move_chance: float = 0.0) -> BattleState:
```

같은 함수의

```gdscript
	# 아군보다 느리게.
	enemy.speed = 1
```

바로 뒤에 추가:

```gdscript
	# 무작위 이동 확률.
	enemy.move_chance = move_chance
```

`run()` 에서 `	_test_state_draw_matches_unit_draw()` 줄 다음에 추가:

```gdscript
	# 적이 무작위로 움직여도 드로우 순서는 같다.
	_test_enemy_moves_do_not_change_draws()
```

파일 끝에 추가:

```gdscript


# 적이 매 차례 무작위로 이동해도(적 전용 난수) 아군이 뽑는 카드는 이동하지 않을 때와 같은지.
func _test_enemy_moves_do_not_change_draws() -> void:
	# 적이 움직이지 않는 전투.
	var still: BattleState = _state(_ally(6), 0.0)
	# 적이 항상 움직이는 전투 (같은 시드).
	var moving: BattleState = _state(_ally(6), 1.0)
	# 둘 다 시작.
	still.start_battle()
	# 둘 다 시작.
	moving.start_battle()
	# 둘 다 차례 종료 (적 차례를 지나 다음 드로우까지).
	still.end_turn()
	# 둘 다 차례 종료.
	moving.end_turn()
	# 두 전투의 두 번째 손패가 같다.
	check_eq("enemy randomness leaves the draw order alone", _ids(still.living_units(Unit.Team.ALLY)[0].hand), _ids(moving.living_units(Unit.Team.ALLY)[0].hand))
	# 움직이는 전투에서는 적이 실제로 자리를 옮겼다.
	check("the moving enemy left its cell", moving.living_units(Unit.Team.ENEMY)[0].cell != Vector2i(0, 1))
```

(c) `tests/test_battle_signals.gd` 의 `_enemy` 에서

```gdscript
	# 회복량.
	data.rest_heal = rest_heal
```

바로 뒤에 추가:

```gdscript
	# 무작위 이동을 끈다 (신호 순서를 정확히 확인하기 위해).
	data.move_chance = 0.0
```

(d) `tests/test_event_recorder.gd` 의 `_enemy` 에서

```gdscript
	# 회복 0.
	data.rest_heal = 0
```

바로 뒤에 추가:

```gdscript
	# 무작위 이동을 끈다 (이벤트 순서를 정확히 확인하기 위해).
	data.move_chance = 0.0
```

(e) `tests/test_turn_order.gd` 의 `_enemy` 에서

```gdscript
	# 최대 체력.
	data.max_hp = 10
```

바로 뒤에 추가:

```gdscript
	# 무작위 이동을 끈다 (차례 진행을 정확히 확인하기 위해).
	data.move_chance = 0.0
```

(f) `tests/test_battle_playback.gd` 의 `_rig` 에서

```gdscript
	# 느리게.
	enemy.speed = 1
```

바로 뒤에 추가:

```gdscript
	# 무작위 이동을 끈다 (재생 결과를 정확히 확인하기 위해).
	enemy.move_chance = 0.0
```

(g) `tests/test_turn_phases.gd` 의 `_state` 에서

```gdscript
	# 늦게 행동하도록 느리게.
	enemy.speed = 1
```

바로 뒤에 추가:

```gdscript
	# 무작위 이동을 끈다 (적이 확실히 공격·방어하도록).
	enemy.move_chance = 0.0
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: 테스트 명령
Expected: 위 파일들이 로드되지 않거나(`move_chance`/`MOVE`/`ai_rng` 없음) FAIL.

- [ ] **Step 3: 구현**

(a) `Scripts/combat/data/enemy_data.gd`:

클래스 설명 두 줄

```gdscript
## 적은 카드 대신 고정된 공격·방어·휴식 행동을 쓰며, 그 수치를 여기서 정한다.
## 어떤 행동을 할지는 EnemyBrain 이 정한다.
```

을 바꾼다:

```gdscript
## 적은 카드 대신 고정된 공격·방어·휴식·이동 행동을 쓰며, 그 수치를 여기서 정한다.
## 어떤 행동을 할지는 EnemyBrain 이 정한다.
```

파일 끝에 추가:

```gdscript
## 차례마다 이동을 먼저 고를 확률 (0.25 = 25%). 0 이면 이동하지 않고 난수도 쓰지 않는다.
@export var move_chance: float = 0.25
```

(b) `Scripts/combat/battle_state.gd`:

```gdscript
## 덱 섞기에 쓰는 난수 생성기. 시드를 고정하면 전투를 똑같이 재현할 수 있다.
var rng: RandomNumberGenerator
```

바로 뒤에 추가:

```gdscript
## 적 AI 전용 난수 생성기. 덱 섞기와 따로 써서, 적이 난수를 몇 번 쓰든 카드 순서가 바뀌지 않는다.
var ai_rng: RandomNumberGenerator
```

`_init` 의

```gdscript
	# 난수 생성기를 기억한다.
	rng = p_rng
```

바로 뒤에 추가:

```gdscript
	# 적 AI 전용 난수 생성기를 만든다.
	ai_rng = RandomNumberGenerator.new()
	# 같은 시드로 시작해, 전투 시드가 같으면 적 행동도 같게 한다.
	ai_rng.seed = p_rng.seed
```

(c) `Scripts/combat/enemy_brain.gd`:

```gdscript
## 적이 할 수 있는 행동. ATTACK 공격, DEFEND 방어도 얻기, REST 체력 회복.
enum Action { ATTACK, DEFEND, REST }
```

을 바꾼다:

```gdscript
## 적이 할 수 있는 행동. ATTACK 공격, DEFEND 방어도 얻기, REST 체력 회복, MOVE 한 칸 이동.
enum Action { ATTACK, DEFEND, REST, MOVE }
```

`decide` 의 문서 주석과 첫 줄들을 바꾼다. 기존:

```gdscript
## 이번 차례에 어떤 행동을 할지 정한다.
## 우선순위: 체력이 낮으면 휴식 → 칠 대상이 없으면 방어 → 그 외에는 공격.
static func decide(state: BattleState, actor: Unit) -> Action:
	# 적 전용 수치를 읽기 위해 EnemyData 로 형 변환한다.
	var data: EnemyData = actor.data as EnemyData
```

새로:

```gdscript
## 이번 차례에 어떤 행동을 할지 정한다.
## 먼저 move_chance 확률로 이동을 고른다 (갈 칸이 없으면 공격·방어·휴식 중 무작위).
## 이동을 고르지 않으면 우선순위: 체력이 낮으면 휴식 → 칠 대상이 없으면 방어 → 그 외에는 공격.
## 확률 판정에 적 전용 난수를 쓰므로, 같은 상황에서 여러 번 부르면 결과가 달라질 수 있다.
static func decide(state: BattleState, actor: Unit) -> Action:
	# 적 전용 수치를 읽기 위해 EnemyData 로 형 변환한다.
	var data: EnemyData = actor.data as EnemyData
	# 이동 확률이 있으면 먼저 판정한다 (0 이면 난수를 쓰지 않아 결과가 결정론적이다).
	if data.move_chance > 0.0 and state.ai_rng.randf() < data.move_chance:
		# 갈 칸이 있으면 이동한다.
		if not state.resolver.movable_cells(actor, state.units).is_empty():
			return Action.MOVE
		# 막혔으면 공격·방어·휴식 중 무작위로 고른다.
		return _random_fallback(state, actor)
```

(나머지 `# 현재 체력 / 최대 체력 비율을 소수로 구한다.` 이하 기존 줄은 그대로 둔다.)

`decide` 함수 바로 뒤(`find_target` 문서 주석 앞)에 추가:

```gdscript


## 이동하려 했지만 막혔을 때: 공격(칠 대상이 있을 때만)·방어·휴식 중 하나를 적 전용 난수로 고른다.
static func _random_fallback(state: BattleState, actor: Unit) -> Action:
	# 후보 행동 목록.
	var choices: Array[Action] = []
	# 칠 대상이 있을 때만 공격을 후보에 넣는다.
	if find_target(state, actor) != null:
		choices.append(Action.ATTACK)
	# 방어는 항상 후보.
	choices.append(Action.DEFEND)
	# 휴식도 항상 후보.
	choices.append(Action.REST)
	# 하나를 무작위로 고른다.
	return choices[state.ai_rng.randi_range(0, choices.size() - 1)]
```

`take_turn` 의 `match` 에서 공격 분기의 마지막 줄

```gdscript
			for victim in state.resolver.expand_shape(target, data.attack_shape, state.units):
				state.apply_damage(victim, data.attack_damage)
```

바로 뒤에 추가:

```gdscript
		# 이동: 갈 수 있는 칸 중 하나로 옮긴다.
		Action.MOVE:
			# 갈 수 있는 칸들.
			var cells: Array[Vector2i] = state.resolver.movable_cells(actor, state.units)
			# 칸이 없으면 아무것도 하지 않는다 (안전장치).
			if cells.is_empty():
				return
			# 적 전용 난수로 한 칸을 고른다.
			var cell: Vector2i = cells[state.ai_rng.randi_range(0, cells.size() - 1)]
			# 이동 행동을 알린다 (화면은 뒤따르는 이동 이벤트로 연출한다).
			state.report_enemy_action(actor, Action.MOVE, null)
			# 옮기고 알린다 (unit_moved 신호와 로그가 나간다).
			state.apply_move(actor, cell)
```

- [ ] **Step 4: 테스트 통과 확인**

Run: 테스트 명령
Expected: `405/405 passed`

- [ ] **Step 5: 커밋**

```bash
git add Scripts/combat/data/enemy_data.gd Scripts/combat/enemy_brain.gd Scripts/combat/battle_state.gd tests/test_enemy_brain.gd tests/test_card_zone_signals.gd tests/test_battle_signals.gd tests/test_event_recorder.gd tests/test_turn_order.gd tests/test_battle_playback.gd tests/test_turn_phases.gd
git commit -F - <<'EOF'
feat: let enemies spend their action on a random one-cell move

Co-Authored-By: <구현 모델 이름> <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017G27EF6BYVPF1Bk3fvY2mz
EOF
```

---

### Task 4: 보드 이동 표시

**Files:**
- Modify: `Scripts/view/unit_view.gd`
- Modify: `Scripts/view/board_3d.gd`
- Modify: `tests/test_board_3d.gd`

**Interfaces:**
- Consumes: 기존 `BoardLayout.cell_position`, `UnitView.set_home`, `Board3D._tag`
- Produces: `const UnitView.MOVE_TIME: float = 0.25`, `func UnitView.slide_to(world_position: Vector3) -> void` (await 가능), `enum Board3D.TileState` 끝에 `MOVABLE`, `const Board3D.MOVE_EMISSION`, `func Board3D.show_move_hints(team: Unit.Team, cells: Array[Vector2i]) -> void`, `func Board3D.move_view(unit: Unit, from_cell: Vector2i, to_cell: Vector2i, animate: bool) -> void` (animate 면 await 가능)

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_board_3d.gd` 의 `run()` 에서 `	_test_mark_empty()` 줄 다음에 추가:

```gdscript
	# move_view 가 위치·타일·클릭 칸을 옮긴다.
	_test_move_view_updates_tiles_and_pick_cell()
	# 이동 힌트 표시와 지우기.
	_test_move_hints()
	# 동기화가 유닛 화면을 규칙의 칸으로 맞춘다.
	_test_sync_places_views_on_current_cells()
```

파일 끝에 추가:

```gdscript


# 아군을 (0,1)→(1,1) 로 move_view 하면 화면 위치·원래 자리·두 타일 상태·클릭 칸 정보가 새 칸 기준인지.
func _test_move_view_updates_tiles_and_pick_cell() -> void:
	# 전투.
	var state: BattleState = _state()
	# 보드.
	var board := Board3D.new()
	# 만든다.
	board.build(state, _texture(20))
	# 시작 (아군 차례).
	state.start_battle()
	# 동기화 (아군 칸 강조).
	board.sync_from_state(state)
	# 아군 유닛.
	var ally: Unit = _unit(state, &"a")
	# 연출 없이 옮긴다.
	board.move_view(ally, Vector2i(0, 1), Vector2i(1, 1), false)
	# 새 칸의 3D 위치.
	var target: Vector3 = board.layout.cell_position(Unit.Team.ALLY, Vector2i(1, 1))
	# 화면 위치.
	check("view stands on the new cell", board.view_for(ally).position.is_equal_approx(target))
	# 원래 자리.
	check("home follows the new cell", board.view_for(ally).home_position.is_equal_approx(target))
	# 이전 칸은 빈 칸.
	check_eq("old tile empty", board.tile_state(Unit.Team.ALLY, Vector2i(0, 1)), Board3D.TileState.EMPTY)
	# 새 칸은 강조.
	check_eq("new tile current", board.tile_state(Unit.Team.ALLY, Vector2i(1, 1)), Board3D.TileState.CURRENT)
	# 클릭하면 새 칸으로 판정된다.
	check_eq("pick body reports the new cell", board.view_for(ally).pick_body.get_meta(&"cell"), Vector2i(1, 1))
	# 지운다.
	board.free()


# 이동 힌트를 주면 두 빈 칸이 MOVABLE 이 되고, 지우면 빈 칸으로 돌아가며 강조 칸은 그대로인지.
func _test_move_hints() -> void:
	# 전투.
	var state: BattleState = _state()
	# 보드.
	var board := Board3D.new()
	# 만든다.
	board.build(state, _texture(20))
	# 시작.
	state.start_battle()
	# 동기화.
	board.sync_from_state(state)
	# 힌트를 줄 두 빈 칸 (함수 인자가 타입 있는 배열이라 변수에 담는다).
	var cells: Array[Vector2i] = [Vector2i(1, 1), Vector2i(0, 0)]
	# 두 빈 칸에 이동 힌트.
	board.show_move_hints(Unit.Team.ALLY, cells)
	# (1,1) 이동 가능.
	check_eq("first hint tile movable", board.tile_state(Unit.Team.ALLY, Vector2i(1, 1)), Board3D.TileState.MOVABLE)
	# (0,0) 이동 가능.
	check_eq("second hint tile movable", board.tile_state(Unit.Team.ALLY, Vector2i(0, 0)), Board3D.TileState.MOVABLE)
	# 힌트를 지운다.
	board.clear_target_hints()
	# 빈 칸으로 돌아왔다.
	check_eq("cleared move hint back to empty", board.tile_state(Unit.Team.ALLY, Vector2i(1, 1)), Board3D.TileState.EMPTY)
	# 아군 칸 강조는 그대로.
	check_eq("current tile untouched", board.tile_state(Unit.Team.ALLY, Vector2i(0, 1)), Board3D.TileState.CURRENT)
	# 지운다.
	board.free()


# 규칙에서 아군 칸을 (2,2) 로 바꾼 뒤 동기화하면 화면 위치·클릭 칸·강조 타일이 (2,2) 기준인지.
func _test_sync_places_views_on_current_cells() -> void:
	# 전투.
	var state: BattleState = _state()
	# 보드.
	var board := Board3D.new()
	# 만든다.
	board.build(state, _texture(20))
	# 시작.
	state.start_battle()
	# 아군 유닛.
	var ally: Unit = _unit(state, &"a")
	# 화면을 거치지 않고 규칙에서만 옮긴다.
	ally.cell = Vector2i(2, 2)
	# 동기화.
	board.sync_from_state(state)
	# 화면 위치.
	check("sync moves the view to the rules cell", board.view_for(ally).position.is_equal_approx(board.layout.cell_position(Unit.Team.ALLY, Vector2i(2, 2))))
	# 클릭 칸.
	check_eq("sync retags the pick body", board.view_for(ally).pick_body.get_meta(&"cell"), Vector2i(2, 2))
	# 강조 타일.
	check_eq("sync highlights the new cell", board.tile_state(Unit.Team.ALLY, Vector2i(2, 2)), Board3D.TileState.CURRENT)
	# 지운다.
	board.free()
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: 테스트 명령
Expected: `test_board_3d.gd` 가 로드되지 않거나(`move_view`/`MOVABLE` 없음) FAIL.

- [ ] **Step 3: 구현**

(a) `Scripts/view/unit_view.gd`:

```gdscript
## 쓰러질 때 서서히 사라지는 시간.
const FADE_TIME: float = 0.4
```

바로 뒤에 추가:

```gdscript
## 한 칸 이동할 때 미끄러지는 시간.
const MOVE_TIME: float = 0.25
```

`set_home` 함수 바로 뒤에 추가:

```gdscript


## 새 자리로 미끄러져 이동한다. 원래 자리를 먼저 바꾸므로 이후 돌진 연출도 새 자리로 돌아온다. await 가능.
func slide_to(world_position: Vector3) -> void:
	# 돌아올 자리를 새 위치로 바꾼다.
	home_position = world_position
	# 위치 트윈을 만든다.
	var tween: Tween = create_tween()
	# MOVE_TIME 동안 새 위치로 옮긴다.
	tween.tween_property(self, "position", world_position, MOVE_TIME)
	# 끝날 때까지 기다린다.
	await tween.finished
```

(b) `Scripts/view/board_3d.gd`:

타일 상태 설명과 enum 을 바꾼다. 기존:

```gdscript
## 타일 모습 상태.
## BASE 유닛이 있는 기본, EMPTY 빈 칸(어둡게), CURRENT 지금 차례(노란 빛), VALID 칠 수 있음(초록 빛), INVALID 칠 수 없음(더 어둡게).
enum TileState { BASE, EMPTY, CURRENT, VALID, INVALID }
```

새로:

```gdscript
## 타일 모습 상태.
## BASE 유닛이 있는 기본, EMPTY 빈 칸(어둡게), CURRENT 지금 차례(노란 빛), VALID 칠 수 있음(초록 빛), INVALID 칠 수 없음(더 어둡게),
## MOVABLE 이동할 수 있는 빈 칸(파란 빛).
enum TileState { BASE, EMPTY, CURRENT, VALID, INVALID, MOVABLE }
```

```gdscript
## 칠 수 있는 대상 타일이 내는 빛 색.
const VALID_EMISSION := Color(0.45, 0.85, 0.45)
```

바로 뒤에 추가:

```gdscript
## 이동할 수 있는 타일이 내는 빛 색.
const MOVE_EMISSION := Color(0.45, 0.65, 1.0)
```

`sync_from_state` 에서

```gdscript
		# 그 유닛의 화면 객체.
		var view: UnitView = _views[unit]
```

바로 뒤에 추가:

```gdscript
		# 규칙의 현재 칸 위치를 원래 자리로 삼는다 (이동 연출이 어긋나도 실제 상태로 맞춘다).
		view.set_home(layout.cell_position(unit.team, unit.cell))
		# 클릭 칸 정보도 현재 칸으로 다시 붙인다.
		_tag(view.pick_body, unit.team, unit.cell)
```

`clear_target_hints` 를 바꾼다. 기존:

```gdscript
## 사거리 힌트 글자와 초록/어두운 타일 표시를 모두 지운다.
func clear_target_hints() -> void:
	# 모든 칸의 힌트를 확인한다.
	for key in _hints:
		# 글자를 숨긴다.
		(_hints[key] as Label3D).visible = false
		# 그 칸의 현재 타일 상태 (없으면 EMPTY 로 본다).
		var current: TileState = _tile_states.get(key, TileState.EMPTY)
		# 힌트 때문에 바뀐 상태였으면 기본으로 되돌린다 (강조·빈 칸은 그대로).
		if current == TileState.VALID or current == TileState.INVALID:
			set_tile_state(key.x as Unit.Team, Vector2i(key.y, key.z), TileState.BASE)
```

새로:

```gdscript
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
```

`clear_target_hints` 함수 바로 뒤에 추가:

```gdscript


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
```

`set_tile_state` 에서

```gdscript
	# 강조·유효 상태일 때만 스스로 빛나게 한다.
	material.emission_enabled = new_state == TileState.CURRENT or new_state == TileState.VALID
```

을 바꾼다:

```gdscript
	# 강조·유효·이동 가능 상태일 때만 스스로 빛나게 한다.
	material.emission_enabled = new_state == TileState.CURRENT or new_state == TileState.VALID or new_state == TileState.MOVABLE
```

같은 함수 `match` 의 마지막 분기

```gdscript
		# 칠 수 없음: 60% 어둡게.
		TileState.INVALID:
			material.albedo_color = base.darkened(0.6)
```

바로 뒤에 추가:

```gdscript
		# 이동 가능: 편 색 + 파란 빛.
		TileState.MOVABLE:
			# 바탕은 편 색.
			material.albedo_color = base
			# 빛 색을 파랗게.
			material.emission = MOVE_EMISSION
			# 빛 세기.
			material.emission_energy_multiplier = 0.6
```

- [ ] **Step 4: 테스트 통과 확인**

Run: 테스트 명령
Expected: `417/417 passed`

- [ ] **Step 5: 커밋**

```bash
git add Scripts/view/unit_view.gd Scripts/view/board_3d.gd tests/test_board_3d.gd
git commit -F - <<'EOF'
feat: slide unit views between cells and light movable tiles

Co-Authored-By: <구현 모델 이름> <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017G27EF6BYVPF1Bk3fvY2mz
EOF
```

---

### Task 5: 이동 이벤트 기록과 재생

**Files:**
- Modify: `Scripts/view/battle_event.gd`
- Modify: `Scripts/view/battle_event_recorder.gd`
- Modify: `Scripts/view/battle_playback.gd`
- Modify: `Scripts/ui/battle_hud.gd`
- Modify: `tests/test_event_recorder.gd`
- Modify: `tests/test_battle_playback.gd`

**Interfaces:**
- Consumes: T2 `BattleState.unit_moved`, `move_unit`; T3 `EnemyBrain.Action.MOVE`, `EnemyData.move_chance`; T4 `Board3D.move_view`
- Produces: `BattleEvent.Kind.UNIT_MOVED`, `var BattleEvent.from_cell: Vector2i`, `var BattleEvent.to_cell: Vector2i`, `func BattleHud.apply_move(event: BattleEvent) -> void`

- [ ] **Step 1: 실패하는 테스트 작성**

(a) `tests/test_event_recorder.gd` 의 `run()` 에서 `	_test_card_zone_events_snapshot()` 줄 다음에 추가:

```gdscript
	# 아군 이동: 이동 → 로그.
	_test_ally_move_records_move_then_log()
	# 적 이동: 행동 → 이동 → 로그.
	_test_enemy_move_records_action_move_log()
```

파일 끝에 추가:

```gdscript


# 아군이 (0,1)→(1,1) 로 이동하면 [UNIT_MOVED, LOG] 가 기록되고 두 칸·유닛·로그 문장이 맞는지.
func _test_ally_move_records_move_then_log() -> void:
	# 적 하나인 전투.
	var state: BattleState = _state(1, 1)
	# 기록기 연결.
	var recorder := BattleEventRecorder.new(state)
	# 시작 (아군 차례).
	state.start_battle()
	# 시작 기록은 버린다.
	recorder.take_events()

	# 한 칸 뒤로 이동.
	state.move_unit(Vector2i(1, 1))
	# 기록 꺼내기.
	var events: Array[BattleEvent] = recorder.take_events()
	# 종류 별칭.
	var k := BattleEvent.Kind
	# 종류 순서.
	check_eq("ally move kinds", _kinds(events), [k.UNIT_MOVED, k.LOG])
	# 이전 칸.
	check_eq("from cell", events[0].from_cell, Vector2i(0, 1))
	# 새 칸.
	check_eq("to cell", events[0].to_cell, Vector2i(1, 1))
	# 주인공은 아군.
	check("moved unit is the ally", events[0].unit.is_ally())
	# 로그 문장.
	check_eq("move log text", events[1].text, "a 이동")


# 이동 확률 100% 적의 차례를 돌리면 [ENEMY_ACTED(MOVE), UNIT_MOVED, LOG] 이고 새 칸이 실제 칸과 같은지.
func _test_enemy_move_records_action_move_log() -> void:
	# 적 하나인 전투 (e1 은 적 격자 (0,0)).
	var state: BattleState = _state(1, 1)
	# 기록기 연결.
	var recorder := BattleEventRecorder.new(state)
	# 적 유닛.
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 항상 이동하게 한다.
	(foe.data as EnemyData).move_chance = 1.0
	# 적 차례 처리.
	EnemyBrain.take_turn(state, foe)
	# 기록 꺼내기.
	var events: Array[BattleEvent] = recorder.take_events()
	# 종류 별칭.
	var k := BattleEvent.Kind
	# 종류 순서.
	check_eq("enemy move kinds", _kinds(events), [k.ENEMY_ACTED, k.UNIT_MOVED, k.LOG])
	# 행동은 이동.
	check_eq("enemy action is move", events[0].action, EnemyBrain.Action.MOVE)
	# 기록된 새 칸 = 실제 칸.
	check_eq("recorded destination matches the unit", events[1].to_cell, foe.cell)
```

(b) `tests/test_battle_playback.gd` 의 `run()` 에서 `	_test_end_turn_discards_then_reshuffles_and_draws()` 줄 다음에 추가:

```gdscript
	# 아군 이동 이벤트 재생.
	_test_move_event_moves_the_view()
```

파일 끝에 추가:

```gdscript


# 아군이 (0,1)→(1,1) 로 이동한 이벤트를 재생하면 화면 위치·강조 타일·SP 패널·로그가 바뀌는지.
func _test_move_event_moves_the_view() -> void:
	# 준비물.
	var rig: Dictionary = _rig()
	# 전투 상태.
	var state: BattleState = rig["state"]
	# 기록기.
	var recorder: BattleEventRecorder = rig["recorder"]
	# 보드.
	var board: Board3D = rig["board"]
	# HUD.
	var hud: BattleHud = rig["hud"]
	# 재생기.
	var playback: BattlePlayback = rig["playback"]

	# 시작.
	state.start_battle()
	# 시작 이벤트 재생.
	playback.play(recorder.take_events())
	# 아군 유닛.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 한 칸 뒤로 이동.
	state.move_unit(Vector2i(1, 1))
	# 이동 이벤트 재생.
	playback.play(recorder.take_events())
	# 화면 위치.
	check("view moved to the new cell", board.view_for(ally).position.is_equal_approx(board.layout.cell_position(Unit.Team.ALLY, Vector2i(1, 1))))
	# 새 칸 강조.
	check_eq("new cell highlighted", board.tile_state(Unit.Team.ALLY, Vector2i(1, 1)), Board3D.TileState.CURRENT)
	# SP 2 표시.
	check_eq("sp panel shows the spent sp", hud.sp_text(), "SP\n●●○\n2 / 3")
	# 로그.
	check("move logged", hud.log_text().contains("a 이동"))
	# 정리.
	_free(rig)
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: 테스트 명령
Expected: 두 파일이 로드되지 않거나(`UNIT_MOVED`/`from_cell` 없음) FAIL, 또는 재생 테스트의 위치·SP 검사 FAIL.

- [ ] **Step 3: 구현**

(a) `Scripts/view/battle_event.gd`:

```gdscript
enum Kind { TURN_STARTED, CARD_PLAYED, ENEMY_ACTED, DAMAGED, HEALED, BLOCK_GAINED, DIED, LOG, BATTLE_ENDED, CARD_DRAWN, DECK_RESHUFFLED, HAND_DISCARDED }
```

을 바꾼다:

```gdscript
enum Kind { TURN_STARTED, CARD_PLAYED, ENEMY_ACTED, DAMAGED, HEALED, BLOCK_GAINED, DIED, LOG, BATTLE_ENDED, CARD_DRAWN, DECK_RESHUFFLED, HAND_DISCARDED, UNIT_MOVED }
```

```gdscript
## 기록 시점의 묘지 장수.
var discard_count: int = 0
```

바로 뒤에 추가:

```gdscript
## 이동 전 칸 (UNIT_MOVED).
var from_cell: Vector2i = Vector2i.ZERO
## 이동 후 칸 (UNIT_MOVED).
var to_cell: Vector2i = Vector2i.ZERO
```

(b) `Scripts/view/battle_event_recorder.gd`:

`_init` 의

```gdscript
	# 손패 버리기 신호 → 기록.
	state.hand_discarded.connect(_on_hand_discarded)
```

바로 뒤에 추가:

```gdscript
	# 이동 신호 → 기록.
	state.unit_moved.connect(_on_unit_moved)
```

파일 끝에 추가:

```gdscript


## 이동: 누가 어느 칸에서 어느 칸으로 옮겼는지.
func _on_unit_moved(unit: Unit, from_cell: Vector2i, to_cell: Vector2i) -> void:
	# 이동 기록을 만든다.
	var event := BattleEvent.new(BattleEvent.Kind.UNIT_MOVED)
	# 이동한 유닛.
	event.unit = unit
	# 이전 칸.
	event.from_cell = from_cell
	# 새 칸.
	event.to_cell = to_cell
	# 목록에 추가한다.
	_events.append(event)
```

(c) `Scripts/ui/battle_hud.gd`:

`remove_played_card` 함수 바로 뒤에 추가:

```gdscript


## 이동 이벤트: 아군이 이동했으면 줄어든 SP 로 SP 패널과 카드 흐림을 갱신한다.
func apply_move(event: BattleEvent) -> void:
	# 적 이동은 SP 와 상관없다.
	if not event.unit.is_ally():
		return
	# 남은 SP 로 카드 흐림을 다시 계산한다.
	_hand.set_sp(event.unit.sp)
	# SP 패널을 갱신한다.
	_refresh_sp(event.unit)
```

(d) `Scripts/view/battle_playback.gd`:

`play` 의 `match` 에서 마지막 분기

```gdscript
			# 손패 버리기: 손패 → 묘지 연출을 시작하고 기다린다.
			BattleEvent.Kind.HAND_DISCARDED:
				# 손패 카드들이 묘지로 날아가기 시작한다.
				hud.discard_hand(event)
				# 연출이 보이도록 기다린다.
				await _wait(DISCARD_WAIT)
```

바로 뒤에 추가:

```gdscript
			# 이동: 유닛이 새 칸으로 미끄러진다.
			BattleEvent.Kind.UNIT_MOVED:
				await _unit_moved(event)
```

`_enemy_acted` 에서

```gdscript
	# 테스트 모드면 움직임 연출은 건너뛴다.
	if instant:
		return
	# 행동한 적의 화면 객체.
	var view: UnitView = board.view_for(event.unit)
```

을 바꾼다:

```gdscript
	# 테스트 모드면 움직임 연출은 건너뛴다.
	if instant:
		return
	# 이동은 뒤따르는 이동 이벤트가 보여 주므로 여기서는 연출하지 않는다.
	if event.action == EnemyBrain.Action.MOVE:
		return
	# 행동한 적의 화면 객체.
	var view: UnitView = board.view_for(event.unit)
```

그리고 `_enemy_acted` 의 문서 주석 `## 적 행동 연출: 공격이면 돌진, 방어·휴식이면 제자리 뛰기.` 를 `## 적 행동 연출: 공격이면 돌진, 방어·휴식이면 제자리 뛰기, 이동이면 없음(UNIT_MOVED 가 보여 준다).` 로 바꾼다.

`_damaged` 함수 바로 앞(`## 피해 연출:` 문서 주석 앞)에 추가:

```gdscript
## 이동 연출: 아군이면 SP 표시를 갱신하고, 유닛을 새 칸으로 옮긴다.
func _unit_moved(event: BattleEvent) -> void:
	# SP 패널과 카드 흐림을 갱신한다 (적이면 HUD 가 무시한다).
	hud.apply_move(event)
	# 보드에서 유닛을 옮긴다. 테스트 모드면 즉시, 아니면 미끄러짐이 끝날 때까지 기다린다.
	await board.move_view(event.unit, event.from_cell, event.to_cell, not instant)


```

- [ ] **Step 4: 테스트 통과 확인**

Run: 테스트 명령
Expected: `429/429 passed`

- [ ] **Step 5: 커밋**

```bash
git add Scripts/view/battle_event.gd Scripts/view/battle_event_recorder.gd Scripts/view/battle_playback.gd Scripts/ui/battle_hud.gd tests/test_event_recorder.gd tests/test_battle_playback.gd
git commit -F - <<'EOF'
feat: record and play unit moves

Co-Authored-By: <구현 모델 이름> <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017G27EF6BYVPF1Bk3fvY2mz
EOF
```

---

### Task 6: 클릭 이동 입력

**Files:**
- Modify: `Scripts/view/battle_root.gd`

**Interfaces:**
- Consumes: T2 `BattleState.move_unit`, `TargetResolver.movable_cells`; T4 `Board3D.show_move_hints`, `clear_target_hints`
- Produces: 없음 (씬 루트)

이 과제는 씬 루트라 단위 테스트가 없다 (기존 패턴). 헤드리스 탐침 스크립트로 확인하고, 창 모드 확인은 컨트롤러가 한다.

- [ ] **Step 1: 구현**

`Scripts/view/battle_root.gd` 에서:

(a) `_run` 의 마지막 두 줄

```gdscript
	# 전투가 끝났으면 계속 잠그고, 아니면 입력을 푼다.
	_set_busy(_state.finished)
```

바로 뒤에 추가:

```gdscript
	# 잠금이 풀린 상태에 맞는 힌트(이동 가능 칸 등)를 보여 준다.
	_refresh_hints()
```

(b) `_on_card_selected` 와 `_on_card_dropped` 안의

```gdscript
	# 대상 칸마다 사거리 힌트를 새로 보여 준다.
	_refresh_target_hints()
```

```gdscript
	# 힌트를 그 카드 기준으로 갱신한다.
	_refresh_target_hints()
```

를 각각 바꾼다:

```gdscript
	# 선택 상태에 맞는 힌트를 새로 보여 준다 (카드면 사거리, 해제면 이동 가능 칸).
	_refresh_hints()
```

```gdscript
	# 힌트를 그 카드 기준으로 갱신한다.
	_refresh_hints()
```

(c) `_on_cell_clicked` 에서

```gdscript
	# 잠겨 있거나 고른 카드가 없으면 할 일이 없다.
	if _busy or _selected_card < 0:
		return
```

를 바꾼다:

```gdscript
	# 잠겨 있으면 할 일이 없다.
	if _busy:
		return
	# 고른 카드가 없으면 이동을 시도한다.
	if _selected_card < 0:
		# 드래그가 아닌 아군 칸 클릭만 이동으로 본다.
		if not from_drop and team == Unit.Team.ALLY:
			_try_move(cell)
		return
```

(d) `_clear_selection` 전체를 바꾼다. 기존:

```gdscript
## 카드 선택과 사거리 힌트를 지운다.
func _clear_selection() -> void:
	# 선택 없음으로.
	_selected_card = -1
	# 보드의 힌트 표시를 지운다.
	_board.clear_target_hints()
```

새로:

```gdscript
## 카드 선택을 지우고 힌트를 다시 정한다 (입력 가능하면 이동 가능 칸, 잠겨 있으면 없음).
func _clear_selection() -> void:
	# 선택 없음으로.
	_selected_card = -1
	# 선택이 없는 상태의 힌트로 바꾼다.
	_refresh_hints()
```

(e) `_on_end_turn_pressed` 함수 바로 뒤에 추가:

```gdscript


## 지금 차례 아군을 cell 로 이동시킨다. 이동할 수 없는 칸이면 무시한다.
func _try_move(cell: Vector2i) -> void:
	# 지금 차례인 유닛.
	var actor: Unit = _state.current_unit()
	# 아군 차례가 아니거나 SP 가 없으면 무시한다.
	if actor == null or not actor.is_ally() or actor.sp < 1:
		return
	# 상하좌우 빈 칸이 아니면 무시한다.
	if not _state.resolver.movable_cells(actor, _state.units).has(cell):
		return
	# 이동을 실행하고 재생한다. 규칙이 거절하면(예상 밖 상황) 로그를 남긴다.
	_run(func() -> void:
		if not _state.move_unit(cell):
			_hud.append_log("이동할 수 없는 칸"))


## 지금 상황에 맞는 힌트를 보드에 보여 준다.
## 카드 선택 중이면 사거리 힌트, 선택이 없고 이동할 수 있으면 이동 가능 칸, 그 외에는 지운다.
func _refresh_hints() -> void:
	# 카드를 골랐으면 사거리 힌트.
	if _selected_card >= 0:
		_refresh_target_hints()
		return
	# 지금 차례인 유닛.
	var actor: Unit = _state.current_unit()
	# 잠겨 있거나, 끝났거나, 아군 차례가 아니거나, SP 가 없으면 힌트를 지운다.
	if _busy or _state.finished or actor == null or not actor.is_ally() or actor.sp < 1:
		_board.clear_target_hints()
		return
	# 이동할 수 있는 칸을 표시한다.
	_board.show_move_hints(actor.team, _state.resolver.movable_cells(actor, _state.units))
```

(f) 파일 맨 위 `##` 설명의 둘째 줄

```gdscript
## 플레이어 입력(카드 선택, 칸 클릭, 드래그 놓기, 차례 종료)을 받아 규칙을 부르고,
```

을 바꾼다:

```gdscript
## 플레이어 입력(카드 선택, 칸 클릭 — 카드 사용 또는 이동, 드래그 놓기, 차례 종료)을 받아 규칙을 부르고,
```

- [ ] **Step 2: 전체 테스트와 스모크 실행**

Run: 테스트 명령
Expected: `429/429 passed`

Run: `& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --quit-after 120 res://Scenes/battle_3d.tscn 2>&1 | Select-String -Pattern "ERROR|SCRIPT|Parse"`
Expected: 출력 없음

- [ ] **Step 3: 헤드리스 탐침 (커밋하지 않음)**

`tests/_probe_move.gd` 를 만든다 (확인 뒤 삭제):

```gdscript
# 임시 탐침: 전투 씬을 띄워 첫 아군 차례의 이동 힌트, 클릭 이동, 카드 선택 시 힌트 전환을 출력한다. 커밋하지 않는다.
extends SceneTree

# 전투 씬 루트.
var _battle: Node
# 시작 시각 (밀리초).
var _started_at: int = 0
# 진행 단계.
var _step: int = 0


# 매 프레임 불린다. true 를 돌려주면 끝난다.
func _process(_delta: float) -> bool:
	# 첫 프레임: 씬을 띄운다.
	if _battle == null:
		_battle = (load("res://Scenes/battle_3d.tscn") as PackedScene).instantiate()
		root.add_child(_battle)
		_started_at = Time.get_ticks_msec()
		return false
	# 경과 시간.
	var elapsed: int = Time.get_ticks_msec() - _started_at
	# 규칙 상태.
	var state: BattleState = _battle.get("_state")
	# 보드.
	var board: Board3D = _battle.get("_board")
	# 3초 뒤: 이동 힌트 확인 후 첫 이동 칸 클릭.
	if _step == 0 and elapsed > 3000:
		_step = 1
		var actor: Unit = state.current_unit()
		var cells: Array[Vector2i] = state.resolver.movable_cells(actor, state.units)
		print("PROBE actor=", actor.data.display_name, " cell=", actor.cell, " sp=", actor.sp, " busy=", _battle.get("_busy"))
		for cell in cells:
			print("PROBE hint ", cell, " state=", Board3D.TileState.keys()[board.tile_state(actor.team, cell)])
		_battle.set_meta(&"probe_target", cells[0])
		_battle.call("_on_cell_clicked", actor.team, cells[0])
		return false
	# 6초 뒤: 이동 결과 확인, 카드 선택/해제 시 힌트 전환 확인.
	if _step == 1 and elapsed > 6000:
		_step = 2
		var actor: Unit = state.current_unit()
		var target: Vector2i = _battle.get_meta(&"probe_target")
		print("PROBE moved cell=", actor.cell, " expected=", target, " sp=", actor.sp)
		print("PROBE view_at_cell=", board.view_for(actor).position.is_equal_approx(board.layout.cell_position(actor.team, actor.cell)))
		print("PROBE new_tile=", Board3D.TileState.keys()[board.tile_state(actor.team, actor.cell)])
		var movable_after: Array[Vector2i] = state.resolver.movable_cells(actor, state.units)
		print("PROBE hints_after_move=", movable_after.map(func(c: Vector2i) -> String: return Board3D.TileState.keys()[board.tile_state(actor.team, c)]))
		_battle.call("_on_card_selected", 0)
		print("PROBE with_card=", movable_after.map(func(c: Vector2i) -> String: return Board3D.TileState.keys()[board.tile_state(actor.team, c)]))
		_battle.call("_on_card_selected", -1)
		print("PROBE after_deselect=", movable_after.map(func(c: Vector2i) -> String: return Board3D.TileState.keys()[board.tile_state(actor.team, c)]))
		return true
	# 계속.
	return false
```

Run: `& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --script res://tests/_probe_move.gd 2>&1 | Select-String -Pattern "PROBE|ERROR|SCRIPT"` (타임아웃 120000)

Expected:
- `PROBE actor=정찰병 ... sp=3 busy=false`
- 모든 `PROBE hint` 줄의 `state=MOVABLE`
- `PROBE moved cell=` 과 `expected=` 가 같고 `sp=2`
- `PROBE view_at_cell=true`, `PROBE new_tile=CURRENT`
- `PROBE hints_after_move=` 는 모두 `MOVABLE`
- `PROBE with_card=` 에는 `MOVABLE` 이 없다
- `PROBE after_deselect=` 는 다시 모두 `MOVABLE`
- ERROR/SCRIPT 줄 없음

확인 뒤 `tests/_probe_move.gd` 와 Godot 가 만든 `tests/_probe_move.gd.uid`(생겼다면)를 삭제한다.

- [ ] **Step 4: 커밋**

```bash
git add Scripts/view/battle_root.gd
git commit -F - <<'EOF'
feat: show movable cells and move the acting ally on click

Co-Authored-By: <구현 모델 이름> <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017G27EF6BYVPF1Bk3fvY2mz
EOF
```

- [ ] **Step 5: 창 모드 확인 (컨트롤러)**

스펙 8.2 항목을 게임 창에서 확인한다 (이동 힌트 표시·전환, 클릭 이동과 SP 감소·로그, SP 0 에서 힌트 없음, 적 이동, godot.log ERROR 없음).
