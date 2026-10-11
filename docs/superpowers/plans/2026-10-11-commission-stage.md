# 의뢰 스테이지(거울던전식 1층) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 월드맵 노드(의뢰)에 들어가면 전투 한 번 대신 3줄 × 5칸 + 보스 격자 한 층을 진행하고, 의뢰 안에서는 체력이 전투 사이에 이어진다.

**Architecture:** 순수 로직(`StageNode`/`StageGraph`/`CommissionRun`/`StageLayout`, `Scripts/map/`)이 격자·진행·체력을 들고, 화면(`StageView`, `Scripts/view/`)은 그 상태를 그리기만 한다. 전투 쪽은 `UnitPlacement.start_hp` + `BattleState` 적용 + `BattleRoot.ally_final_hp()` 세 곳만 바꾼다. `GameRoot` 가 월드맵 → 의뢰 화면 → 전투 → 의뢰 화면 → 월드맵을 잇는다.

**Tech Stack:** Godot 4.7 GDScript (typed), 자체 `TestCase` 헤드리스 테스트 러너.

**Spec:** `docs/superpowers/specs/2026-10-11-commission-stage-design.md`

## Global Constraints

- 격자: `LANES = 3`, `STEPS = 5`, 시작 `lane 1 / step -1`, 보스 `lane 1 / step STEPS`.
- 칸 종류 가중치: 전투 6 : 이벤트 2 : 상점 1 : 휴식 1. `step 0` 은 항상 전투.
- 연결: 시작 → step 0 세 칸 전부, `(l, s)` → step `s+1` 중 `|l' − l| ≤ 1`, step 4 → 보스.
- `start_hp` 기본값 −1 = 최대 체력. 기존 전투 동작은 바뀌면 안 된다.
- 이벤트·상점·휴식은 빈 칸(이동만). 의뢰 중 파티 화면은 쓰지 않는다.
- 코드 스타일: 기존 GDScript 처럼 typed (`-> 타입`, 타입 있는 `var`), 새 재사용 클래스는 `class_name`, 주석은 한국어로 기존 파일과 같은 밀도(거의 모든 줄 위에 짧은 주석).
- 새 테스트 파일은 `tests/run_tests.gd` 의 `TEST_SCRIPTS` 에 추가해야 실행된다.

## 테스트 실행법

```powershell
# 새 class_name 을 만든 직후 한 번 (전역 클래스 캐시 재스캔)
& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --editor --quit --path "C:\Users\User\Desktop\Godot\Project-Void"
# 전체 테스트
& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --script res://tests/run_tests.gd
```

출력 끝의 `N/M passed` 와 `FAIL` 줄을 본다. 전면(동기) 실행, 타임아웃 2분.

## Review Focus

1. 의뢰 중 쓰러진 파티원(체력 0)이 다음 전투에 나오지 않고, 살아 있는 파티원의 체력이 올바른 사람에게 돌아가야 한다 (번호가 밀리면 엉뚱한 사람이 다친다) → Task 4 `_test_apply_battle_hp_maps_back_skipping_the_fallen`.
2. 보스가 아닌 칸에서 이겨도 의뢰가 성공 처리되면 안 된다 → Task 4 `_test_regular_win_keeps_the_run_going`.
3. 의뢰가 끝난 뒤(성공·실패) 격자를 더 누를 수 없어야 한다 → Task 4 `_test_finished_run_accepts_no_moves`.
4. 의뢰 중 월드맵 노드를 다시 눌러 두 번째 의뢰가 겹쳐 시작되면 안 된다 → Task 6 `_on_node_selected` 가드 + 통합 확인 단계.
5. 도망은 패배와 같이 의뢰 실패지만 진행도는 그대로여야 한다 → Task 4 `_test_fail_marks_failed` + Task 6 통합 확인.

---

## 파일 구조

| 파일 | 책임 |
|---|---|
| `Scripts/combat/data/unit_placement.gd` (수정) | `start_hp` 필드 |
| `Scripts/combat/battle_state.gd` (수정) | 아군 생성 시 `start_hp` 적용 |
| `Scripts/view/battle_root.gd` (수정) | `ally_final_hp()` |
| `Scripts/map/stage_node.gd` (새) | 격자 칸 하나 |
| `Scripts/map/stage_graph.gd` (새) | 격자 생성·연결 |
| `Scripts/map/commission_run.gd` (새) | 의뢰 진행 상태·체력·성공/실패 |
| `Scripts/map/stage_layout.gd` (새) | 칸 → 화면 좌표 |
| `Scripts/view/stage_view.gd` (새) | 의뢰 화면 |
| `Scripts/view/game_root.gd` (수정) | 화면 전환 연결 |
| `tests/test_stage_graph.gd`, `tests/test_commission_run.gd`, `tests/test_stage_layout.gd`, `tests/test_stage_view.gd` (새) | 테스트 |
| `tests/test_battle_state.gd`, `tests/test_battle_root.gd` (수정) | `start_hp` / `ally_final_hp` 테스트 |

---

### Task 1: `start_hp` — 시작 체력을 정할 수 있는 배치

**Files:**
- Modify: `Scripts/combat/data/unit_placement.gd`
- Modify: `Scripts/combat/battle_state.gd:89-97` (아군 생성 루프)
- Test: `tests/test_battle_state.gd`

**Interfaces:**
- Produces: `UnitPlacement.start_hp: int` (기본 −1). `BattleState` 가 아군 유닛을 만들 때 `start_hp >= 0` 이면 `hp = mini(start_hp, data.max_hp)`.

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test_battle_state.gd` 의 `run()` 에서 `_test_critical_hit()` 다음 줄(그리고 `return results()` 앞)에 추가:

```gdscript
	# 시작 체력 지정.
	_test_start_hp_sets_the_ally_starting_hp()
```

파일 끝에 추가:

```gdscript
# 배치의 start_hp: −1 이면 최대 체력(30), 값이 있으면 그 체력, 최대보다 크면 최대 체력.
func _test_start_hp_sets_the_ally_starting_hp() -> void:
	# 기본값(−1) 전투.
	var plain: BattleState = BattleStateScript.new(_encounter([]), _rng())
	# 최대 체력으로 시작.
	check_eq("start_hp -1 starts at max hp", plain.living_units(Unit.Team.ALLY)[0].hp, 30)
	# 시작 체력 12 인 구성.
	var hurt_encounter: EncounterData = _encounter([])
	hurt_encounter.ally_units[0].start_hp = 12
	# 그 구성의 전투.
	var hurt: BattleState = BattleStateScript.new(hurt_encounter, _rng())
	# 12 로 시작.
	check_eq("start_hp 12 starts at 12", hurt.living_units(Unit.Team.ALLY)[0].hp, 12)
	# 최대보다 큰 시작 체력.
	var over_encounter: EncounterData = _encounter([])
	over_encounter.ally_units[0].start_hp = 99
	# 그 구성의 전투.
	var over: BattleState = BattleStateScript.new(over_encounter, _rng())
	# 최대 체력으로 잘린다.
	check_eq("start_hp above max is clamped", over.living_units(Unit.Team.ALLY)[0].hp, 30)
```

- [ ] **Step 2: 실패 확인** — 테스트 실행. Expected: `test_battle_state.gd` 가 `start_hp` 없음 오류로 로드 실패하거나 `start_hp 12 starts at 12` FAIL.

- [ ] **Step 3: 구현** — `Scripts/combat/data/unit_placement.gd` 끝에 추가:

```gdscript
## 전투를 시작할 때의 체력. −1 이면 최대 체력으로 시작한다 (의뢰 안에서 체력을 이어갈 때 쓴다).
@export var start_hp: int = -1
```

`Scripts/combat/battle_state.gd` 의 아군 루프에서 `var ally := Unit.new(...)` 바로 다음에 추가:

```gdscript
		# 시작 체력이 정해져 있으면 그 체력으로 시작한다 (최대 체력을 넘지 않게).
		if placement.start_hp >= 0:
			ally.hp = mini(placement.start_hp, ally.data.max_hp)
```

- [ ] **Step 4: 통과 확인** — 테스트 실행. Expected: 새 3개 PASS, 전체 FAIL 0.

- [ ] **Step 5: Commit**

```bash
git add Scripts/combat/data/unit_placement.gd Scripts/combat/battle_state.gd tests/test_battle_state.gd
git commit -m "feat: let a placement set the ally's starting hp"
```

---

### Task 2: `BattleRoot.ally_final_hp()`

**Files:**
- Modify: `Scripts/view/battle_root.gd` (공개 함수 추가, `_on_flee_requested` 앞)
- Test: `tests/test_battle_root.gd`

**Interfaces:**
- Consumes: Task 1 `UnitPlacement.start_hp`.
- Produces: `BattleRoot.ally_final_hp() -> Array[int]` — 아군 유닛의 현재 체력, `encounter.ally_units` 순서.

- [ ] **Step 1: 실패하는 테스트 작성** — `run()` 의 `_test_finish_signal_waits_for_playback()` 다음 줄에:

```gdscript
	# 끝난 전투의 아군 체력.
	_test_ally_final_hp_reports_allies_in_placement_order()
```

파일 끝에 추가:

```gdscript
# 시작 체력 17 로 들어가 한 방에 이긴 전투: 아군 최종 체력은 [17].
func _test_ally_final_hp_reports_allies_in_placement_order() -> void:
	# 씬을 만든다.
	var battle: BattleRoot = BattleScene.instantiate()
	# 전투 구성.
	var encounter: EncounterData = _encounter()
	# 아군을 체력 17 로 시작시킨다.
	encounter.ally_units[0].start_hp = 17
	# 넣는다.
	battle.encounter = encounter
	# 연출 없이 즉시 재생.
	(battle.get_node("Playback") as BattlePlayback).instant = true
	# 트리에 붙여 전투를 시작한다.
	(Engine.get_main_loop() as SceneTree).root.add_child(battle)
	# 적.
	var foe: Unit = battle._state.living_units(Unit.Team.ENEMY)[0]
	# 결정타.
	battle._run(func() -> void: battle._state.play_card(0, foe))
	# 아군 한 명, 체력 17.
	var expected: Array[int] = [17]
	check_eq("ally_final_hp lists the ally's remaining hp", battle.ally_final_hp(), expected)
	# 정리.
	battle.free()
```

- [ ] **Step 2: 실패 확인** — Expected: `ally_final_hp` 없음 오류(스위트 실패).

- [ ] **Step 3: 구현** — `Scripts/view/battle_root.gd` 의 `_on_flee_requested` 앞에 추가:

```gdscript
## 아군의 지금 체력을 배치 순서대로 돌려준다. 의뢰가 다음 전투로 체력을 넘길 때 쓴다 (battle_finished 를 받은 직후 읽는다).
func ally_final_hp() -> Array[int]:
	# 모을 체력 목록.
	var result: Array[int] = []
	# 유닛은 아군이 배치 순서대로 먼저 들어 있다.
	for unit in _state.units:
		# 아군만.
		if unit.is_ally():
			result.append(unit.hp)
	# 돌려준다.
	return result
```

- [ ] **Step 4: 통과 확인** — Expected: 새 검사 PASS, 전체 FAIL 0.

- [ ] **Step 5: Commit**

```bash
git add Scripts/view/battle_root.gd tests/test_battle_root.gd
git commit -m "feat: expose the allies' final hp from a battle"
```

---

### Task 3: `StageNode` + `StageGraph` — 1층 격자

**Files:**
- Create: `Scripts/map/stage_node.gd`, `Scripts/map/stage_graph.gd`
- Test: `tests/test_stage_graph.gd` (새), `tests/run_tests.gd` 목록에 추가

**Interfaces:**
- Produces:
  - `StageNode` (RefCounted): `enum Kind { START, BATTLE, EVENT, SHOP, REST, BOSS }`, `id: int`, `lane: int`, `step: int`, `kind: Kind`, `connections: Array[int]`, `is_empty_room() -> bool` (EVENT/SHOP/REST 면 true), `_init(p_id, p_lane, p_step, p_kind)`.
  - `StageGraph` (RefCounted): `const LANES = 3`, `const STEPS = 5`, `start_id: int = 0`, `boss_id: int`, `nodes: Array[StageNode]`, `_init(rng: RandomNumberGenerator)`, `get_node(id) -> StageNode`, `node_count() -> int`, `node_at(lane, step) -> StageNode`.

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test_stage_graph.gd`:

```gdscript
# StageGraph(의뢰 1층 격자) 테스트: 칸 수, 연결 규칙, 첫 칸 전투, 시드 재현. 여러 시드로 반복한다.
extends TestCase

# 격자 스크립트.
const StageGraphScript := preload("res://Scripts/map/stage_graph.gd")

# 무작위 칸 종류가 달라도 규칙이 지켜지는지 보려고 여러 시드로 돌린다.
const SEEDS: Array[int] = [1, 42, 7]


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 시드마다.
	for seed_value in SEEDS:
		# 칸 수와 시작·보스.
		_test_node_count_and_ends(seed_value)
		# 시작은 첫 칸 셋과 이어진다.
		_test_start_connects_to_every_first_step_cell(seed_value)
		# 칸은 다음 칸 중 줄 차이 1 이하와 이어진다.
		_test_cells_connect_to_adjacent_lanes_of_the_next_step(seed_value)
		# 마지막 칸 셋은 보스로.
		_test_last_step_connects_to_the_boss(seed_value)
		# 첫 칸은 전투, 나머지는 보스·시작이 아닌 칸.
		_test_first_step_is_battle_and_middle_kinds_are_rollable(seed_value)
	# 같은 시드는 같은 격자.
	_test_same_seed_gives_the_same_kinds()
	# 결과를 돌려준다.
	return results()


# 시드를 고정해 격자를 만든다.
func _graph(seed_value: int) -> StageGraph:
	# 생성기.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = seed_value
	# 격자를 만들어 돌려준다.
	return StageGraphScript.new(rng)


# 3×5 칸 + 시작 + 보스. 시작은 id 0, lane 1, step -1. 보스는 lane 1, step STEPS.
func _test_node_count_and_ends(seed_value: int) -> void:
	# 격자.
	var graph: StageGraph = _graph(seed_value)
	# 칸 수.
	check_eq("seed %d: 3x5 cells + start + boss" % seed_value, graph.node_count(), StageGraph.LANES * StageGraph.STEPS + 2)
	# 시작.
	var start: StageNode = graph.get_node(graph.start_id)
	check_eq("seed %d: start is id 0" % seed_value, graph.start_id, 0)
	check_eq("seed %d: start kind" % seed_value, start.kind, StageNode.Kind.START)
	check_eq("seed %d: start step" % seed_value, start.step, -1)
	# 보스.
	var boss: StageNode = graph.get_node(graph.boss_id)
	check_eq("seed %d: boss kind" % seed_value, boss.kind, StageNode.Kind.BOSS)
	check_eq("seed %d: boss step" % seed_value, boss.step, StageGraph.STEPS)
	check_eq("seed %d: boss has no exits" % seed_value, boss.connections.size(), 0)


# 시작의 연결 = step 0 의 세 칸.
func _test_start_connects_to_every_first_step_cell(seed_value: int) -> void:
	# 격자.
	var graph: StageGraph = _graph(seed_value)
	# 시작의 연결.
	var exits: Array[int] = graph.get_node(graph.start_id).connections
	# 세 개.
	check_eq("seed %d: start has LANES exits" % seed_value, exits.size(), StageGraph.LANES)
	# 줄마다 step 0 칸이 들어 있다.
	for lane in StageGraph.LANES:
		check("seed %d: start reaches lane %d" % [seed_value, lane], exits.has(graph.node_at(lane, 0).id))


# (l, s) 의 연결 = step s+1 중 |l'-l| <= 1 인 칸 전부, 그 외는 없음.
func _test_cells_connect_to_adjacent_lanes_of_the_next_step(seed_value: int) -> void:
	# 격자.
	var graph: StageGraph = _graph(seed_value)
	# 마지막 step 앞까지.
	for step in StageGraph.STEPS - 1:
		for lane in StageGraph.LANES:
			# 그 칸.
			var node: StageNode = graph.node_at(lane, step)
			# 기대 연결.
			var expected: Array[int] = []
			for next_lane in StageGraph.LANES:
				if absi(next_lane - lane) <= 1:
					expected.append(graph.node_at(next_lane, step + 1).id)
			# 정렬해서 비교한다.
			var actual: Array[int] = node.connections.duplicate()
			actual.sort()
			expected.sort()
			check_eq("seed %d: (%d,%d) connects to adjacent lanes" % [seed_value, lane, step], actual, expected)


# step 4 의 세 칸은 보스로만 이어진다.
func _test_last_step_connects_to_the_boss(seed_value: int) -> void:
	# 격자.
	var graph: StageGraph = _graph(seed_value)
	# 줄마다.
	for lane in StageGraph.LANES:
		# 마지막 칸.
		var node: StageNode = graph.node_at(lane, StageGraph.STEPS - 1)
		# 보스 하나.
		var expected: Array[int] = [graph.boss_id]
		check_eq("seed %d: last cell in lane %d leads to the boss" % [seed_value, lane], node.connections, expected)


# step 0 은 전부 전투. 가운데 칸은 전투·이벤트·상점·휴식 중 하나.
func _test_first_step_is_battle_and_middle_kinds_are_rollable(seed_value: int) -> void:
	# 격자.
	var graph: StageGraph = _graph(seed_value)
	# 굴릴 수 있는 종류.
	var rollable: Array = [StageNode.Kind.BATTLE, StageNode.Kind.EVENT, StageNode.Kind.SHOP, StageNode.Kind.REST]
	# 칸마다.
	for step in StageGraph.STEPS:
		for lane in StageGraph.LANES:
			# 그 칸.
			var node: StageNode = graph.node_at(lane, step)
			# 첫 칸은 전투.
			if step == 0:
				check_eq("seed %d: (%d,0) is a battle" % [seed_value, lane], node.kind, StageNode.Kind.BATTLE)
			# 나머지는 굴린 종류.
			else:
				check("seed %d: (%d,%d) kind is rollable" % [seed_value, lane, step], rollable.has(node.kind))


# 같은 시드 두 번 → 칸 종류가 같다.
func _test_same_seed_gives_the_same_kinds() -> void:
	# 두 격자.
	var a: StageGraph = _graph(99)
	var b: StageGraph = _graph(99)
	# 종류 목록.
	var kinds_a: Array[int] = []
	var kinds_b: Array[int] = []
	for i in a.node_count():
		kinds_a.append(a.get_node(i).kind)
		kinds_b.append(b.get_node(i).kind)
	# 같다.
	check_eq("same seed gives the same room kinds", kinds_a, kinds_b)
```

`tests/run_tests.gd` 의 `TEST_SCRIPTS` 에서 `"res://tests/test_map_graph.gd",` 다음 줄에 추가:

```gdscript
	"res://tests/test_stage_graph.gd",
```

- [ ] **Step 2: 실패 확인** — Expected: `could not load test script` 또는 preload 실패.

- [ ] **Step 3: 구현** — `Scripts/map/stage_node.gd`:

```gdscript
## 의뢰 1층 격자의 칸 하나. 위치(줄·걸음), 종류, 다음으로 갈 수 있는 칸 목록을 가진다.
## 지나왔는지 같은 진행 상태는 여기 두지 않는다 — CommissionRun 이 관리한다.
class_name StageNode
# RefCounted: 노드가 아닌 가벼운 객체.
extends RefCounted

## 칸 종류. EVENT / SHOP / REST 는 지금은 빈 칸(들어가면 이동만 한다).
enum Kind { START, BATTLE, EVENT, SHOP, REST, BOSS }

## 격자 안에서 칸을 구분하는 번호. StageGraph.nodes 배열의 위치와 같다.
var id: int
## 세로 줄 (0 이 위). 시작·보스는 가운데 줄.
var lane: int
## 가로 걸음 (0 이 첫 칸). 시작은 -1, 보스는 StageGraph.STEPS.
var step: int
## 칸 종류.
var kind: Kind
## 이 칸에서 이어지는 칸 id 목록.
var connections: Array[int] = []


## 위치·종류로 칸을 만든다. 연결은 StageGraph 가 채운다.
func _init(p_id: int, p_lane: int, p_step: int, p_kind: Kind) -> void:
	# 번호.
	id = p_id
	# 줄.
	lane = p_lane
	# 걸음.
	step = p_step
	# 종류.
	kind = p_kind


## 아직 효과가 없는 빈 칸(이벤트·상점·휴식)이면 true.
func is_empty_room() -> bool:
	# 세 종류 중 하나인지.
	return kind == Kind.EVENT or kind == Kind.SHOP or kind == Kind.REST
```

`Scripts/map/stage_graph.gd`:

```gdscript
## 의뢰 1층 격자 (거울던전식). 시작 → LANES 줄 × STEPS 칸 → 보스, 왼쪽에서 오른쪽으로 한 칸씩 간다.
## 모양만 가진다 — 어디까지 왔는지는 CommissionRun 이 관리한다.
class_name StageGraph
# RefCounted: 노드가 아닌 가벼운 객체.
extends RefCounted

## 세로 줄 수.
const LANES: int = 3
## 시작과 보스 사이 칸 수.
const STEPS: int = 5
## 굴릴 수 있는 칸 종류 (ROLL_WEIGHTS 와 같은 순서).
const ROLL_KINDS: Array[int] = [StageNode.Kind.BATTLE, StageNode.Kind.EVENT, StageNode.Kind.SHOP, StageNode.Kind.REST]
## 칸 종류 가중치: 전투 6 : 이벤트 2 : 상점 1 : 휴식 1.
const ROLL_WEIGHTS: Array[int] = [6, 2, 1, 1]

## 시작 칸 id. 가장 먼저 만들어서 항상 0.
var start_id: int = 0
## 보스 칸 id.
var boss_id: int
## 모든 칸. 배열 위치가 곧 id.
var nodes: Array[StageNode] = []


## 칸을 만들고 잇는다. 첫 칸 줄은 전투로 고정, 나머지는 가중치로 굴린다.
func _init(rng: RandomNumberGenerator) -> void:
	# 시작 칸 (가운데 줄, 걸음 -1).
	_add(1, -1, StageNode.Kind.START)
	# 걸음별 줄별 칸 id.
	var grid: Array[Array] = []
	# 걸음마다.
	for step in STEPS:
		# 이 걸음의 칸 id.
		var column: Array[int] = []
		# 줄마다.
		for lane in LANES:
			# 첫 걸음은 전투, 나머지는 굴린다.
			var kind: StageNode.Kind = StageNode.Kind.BATTLE if step == 0 else _roll_kind(rng)
			# 칸을 만든다.
			column.append(_add(lane, step, kind))
		# 기억한다.
		grid.append(column)
	# 보스 칸 (가운데 줄, 마지막 걸음 다음).
	boss_id = _add(1, STEPS, StageNode.Kind.BOSS)

	# 시작은 첫 걸음의 모든 칸과 잇는다.
	for id in grid[0]:
		nodes[start_id].connections.append(id)
	# 칸마다 다음 걸음과 잇는다.
	for step in STEPS:
		for lane in LANES:
			# 이 칸.
			var node: StageNode = nodes[grid[step][lane]]
			# 마지막 걸음은 보스로.
			if step == STEPS - 1:
				node.connections.append(boss_id)
				continue
			# 같은 줄과 위·아래 한 줄.
			for next_lane in range(maxi(0, lane - 1), mini(LANES - 1, lane + 1) + 1):
				node.connections.append(grid[step + 1][next_lane])


## id 로 칸을 찾는다.
func get_node(id: int) -> StageNode:
	# 배열 위치가 곧 id.
	return nodes[id]


## 칸 개수.
func node_count() -> int:
	# 배열 길이.
	return nodes.size()


## 줄·걸음으로 칸을 찾는다. 없으면 null.
func node_at(lane: int, step: int) -> StageNode:
	# 칸마다 비교한다.
	for node in nodes:
		if node.lane == lane and node.step == step:
			return node
	# 없다.
	return null


## 칸을 하나 만들어 끝에 붙이고 그 id 를 돌려준다.
func _add(lane: int, step: int, kind: StageNode.Kind) -> int:
	# 새 id = 지금 길이.
	var id: int = nodes.size()
	# 만들어 붙인다.
	nodes.append(StageNode.new(id, lane, step, kind))
	# id 를 돌려준다.
	return id


## 가중치로 칸 종류 하나를 뽑는다.
func _roll_kind(rng: RandomNumberGenerator) -> StageNode.Kind:
	# 가중치 합.
	var total: int = 0
	for weight in ROLL_WEIGHTS:
		total += weight
	# 1 ~ 합 중 하나.
	var roll: int = rng.randi_range(1, total)
	# 누적하며 어느 구간인지 찾는다.
	for i in ROLL_KINDS.size():
		roll -= ROLL_WEIGHTS[i]
		if roll <= 0:
			return ROLL_KINDS[i] as StageNode.Kind
	# 도달하지 않는다 (안전망).
	return StageNode.Kind.BATTLE
```

- [ ] **Step 4: 통과 확인** — 클래스 캐시 재스캔 후 테스트 실행. Expected: `test_stage_graph.gd` 전부 PASS, 전체 FAIL 0.

- [ ] **Step 5: Commit**

```bash
git add Scripts/map/stage_node.gd Scripts/map/stage_graph.gd Scripts/map/*.uid tests/test_stage_graph.gd tests/*.uid tests/run_tests.gd
git commit -m "feat: generate the commission's first floor grid"
```

---

### Task 4: `CommissionRun` — 의뢰 진행·체력·성공/실패

**Files:**
- Create: `Scripts/map/commission_run.gd`
- Test: `tests/test_commission_run.gd` (새), `tests/run_tests.gd` 목록에 추가

**Interfaces:**
- Consumes: Task 1 `UnitPlacement.start_hp`, Task 3 `StageGraph`/`StageNode`.
- Produces: `CommissionRun` (RefCounted):
  - `enum State { IN_PROGRESS, SUCCEEDED, FAILED }`
  - `graph: StageGraph`, `map_node_id: int`, `current_id: int`, `visited: Array[int]`, `member_hp: Array[int]`, `member_max_hp: Array[int]`, `state: State`
  - `_init(rng: RandomNumberGenerator, p_map_node_id: int, p_member_max_hp: Array[int])`
  - `is_selectable(id: int) -> bool`, `enter(id: int) -> bool`, `current_kind() -> StageNode.Kind`
  - `battle_roster(full: Array[UnitPlacement]) -> Array[UnitPlacement]`, `apply_battle_hp(final_hp: Array[int]) -> void`
  - `finish_battle(won: bool) -> void`, `fail() -> void`, `is_finished() -> bool`

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test_commission_run.gd`:

```gdscript
# CommissionRun(의뢰 진행) 테스트: 이동 규칙, 빈 칸, 전투 배치의 체력, 체력 되돌리기, 성공·실패, 끝난 뒤 이동 불가.
extends TestCase

# 의뢰 진행 스크립트.
const CommissionRunScript := preload("res://Scripts/map/commission_run.gd")
# 배치 스크립트.
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
# 아군 데이터 스크립트.
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 처음 상태.
	_test_starts_at_start_with_full_hp()
	# 처음엔 첫 걸음만.
	_test_only_first_step_is_selectable_at_start()
	# 이동하면 다음 걸음 이웃만.
	_test_enter_moves_and_offers_adjacent_next_cells()
	# 못 가는 칸은 무시.
	_test_enter_rejects_unconnected_cells()
	# 전투 배치에 체력이 실린다.
	_test_battle_roster_carries_hp_and_skips_the_fallen()
	# 체력이 올바른 파티원에게 돌아간다.
	_test_apply_battle_hp_maps_back_skipping_the_fallen()
	# 일반 칸 승리는 계속.
	_test_regular_win_keeps_the_run_going()
	# 보스 승리는 성공.
	_test_boss_win_succeeds()
	# 패배는 실패.
	_test_loss_fails()
	# 도망은 실패.
	_test_fail_marks_failed()
	# 끝난 뒤 이동 불가.
	_test_finished_run_accepts_no_moves()
	# 결과를 돌려준다.
	return results()


# 시드 고정 의뢰 (월드맵 노드 3, 파티 최대 체력 [30, 20, 10]).
func _run(seed_value: int = 5) -> CommissionRun:
	# 생성기.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = seed_value
	# 최대 체력.
	var max_hp: Array[int] = [30, 20, 10]
	# 만들어 돌려준다.
	return CommissionRunScript.new(rng, 3, max_hp)


# 파티원 n 명의 전투 배치 (칸은 번호대로).
func _full_roster(count: int) -> Array[UnitPlacement]:
	# 배치 목록.
	var roster: Array[UnitPlacement] = []
	# 명수만큼.
	for i in count:
		# 데이터.
		var data: AllyData = AllyDataScript.new()
		# 이름으로 구분.
		data.id = StringName("m%d" % i)
		# 배치.
		var placement: UnitPlacement = PlacementScript.new()
		placement.unit_data = data
		placement.cell = Vector2i(0, i)
		roster.append(placement)
	# 돌려준다.
	return roster


# 보스 바로 앞(마지막 걸음 가운데 줄)까지 걸어간다.
func _walk_to_last_step(run: CommissionRun) -> void:
	# 걸음마다 가운데 줄로.
	for step in StageGraph.STEPS:
		run.enter(run.graph.node_at(1, step).id)


# 시작 칸에 서 있고, 진행 중이고, 체력은 최대, 지나온 칸은 시작뿐.
func _test_starts_at_start_with_full_hp() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	# 시작.
	check_eq("starts at start", run.current_id, run.graph.start_id)
	check_eq("starts in progress", run.state, CommissionRun.State.IN_PROGRESS)
	var full: Array[int] = [30, 20, 10]
	check_eq("hp starts full", run.member_hp, full)
	var visited: Array[int] = [run.graph.start_id]
	check_eq("visited starts with start", run.visited, visited)
	check_eq("map node id kept", run.map_node_id, 3)


# 처음엔 첫 걸음 세 칸만 고를 수 있다.
func _test_only_first_step_is_selectable_at_start() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	# 첫 걸음.
	for lane in StageGraph.LANES:
		check("first step lane %d selectable" % lane, run.is_selectable(run.graph.node_at(lane, 0).id))
	# 둘째 걸음과 보스는 아니다.
	check("second step not selectable", not run.is_selectable(run.graph.node_at(1, 1).id))
	check("boss not selectable", not run.is_selectable(run.graph.boss_id))


# (0,0) 에 들어가면 (0,1)·(1,1) 만 열리고 (2,1) 은 닫힌다.
func _test_enter_moves_and_offers_adjacent_next_cells() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	# 위 줄 첫 칸.
	var first: StageNode = run.graph.node_at(0, 0)
	check("entering a selectable cell succeeds", run.enter(first.id))
	check_eq("current moves", run.current_id, first.id)
	check("visited records the cell", run.visited.has(first.id))
	check_eq("current kind is the cell's kind", run.current_kind(), first.kind)
	check("same lane next is open", run.is_selectable(run.graph.node_at(0, 1).id))
	check("diagonal next is open", run.is_selectable(run.graph.node_at(1, 1).id))
	check("two lanes away is closed", not run.is_selectable(run.graph.node_at(2, 1).id))


# 이어지지 않은 칸은 들어갈 수 없고 상태가 그대로다.
func _test_enter_rejects_unconnected_cells() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	# 둘째 걸음으로 건너뛰기.
	check("skipping ahead is rejected", not run.enter(run.graph.node_at(1, 1).id))
	check_eq("current stays at start", run.current_id, run.graph.start_id)
	check_eq("visited unchanged", run.visited.size(), 1)


# 체력 [30, 0, 7] → 배치는 둘(0번 30, 2번 7), 데이터와 칸은 원래 것.
func _test_battle_roster_carries_hp_and_skips_the_fallen() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	# 둘째는 쓰러졌고 셋째는 7.
	run.member_hp = [30, 0, 7]
	# 전체 배치.
	var full: Array[UnitPlacement] = _full_roster(3)
	# 전투 배치.
	var roster: Array[UnitPlacement] = run.battle_roster(full)
	check_eq("fallen member is left out", roster.size(), 2)
	check_eq("first keeps its data", roster[0].unit_data, full[0].unit_data)
	check_eq("first starts at 30", roster[0].start_hp, 30)
	check_eq("third keeps its data", roster[1].unit_data, full[2].unit_data)
	check_eq("third keeps its cell", roster[1].cell, full[2].cell)
	check_eq("third starts at 7", roster[1].start_hp, 7)
	check_eq("original placement untouched", full[2].start_hp, -1)


# 위 배치로 싸운 결과 [12, 3] → 체력 [12, 0, 3].
func _test_apply_battle_hp_maps_back_skipping_the_fallen() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	run.member_hp = [30, 0, 7]
	# 배치를 만든다 (번호를 기억시킨다).
	run.battle_roster(_full_roster(3))
	# 전투 결과.
	var final_hp: Array[int] = [12, 3]
	run.apply_battle_hp(final_hp)
	var expected: Array[int] = [12, 0, 3]
	check_eq("hp goes back to the right members", run.member_hp, expected)


# 전투 칸에서 이기면 진행 중 그대로.
func _test_regular_win_keeps_the_run_going() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	# 첫 칸(전투).
	run.enter(run.graph.node_at(1, 0).id)
	# 승리.
	run.finish_battle(true)
	check_eq("regular win keeps the run in progress", run.state, CommissionRun.State.IN_PROGRESS)


# 보스에서 이기면 성공.
func _test_boss_win_succeeds() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	# 보스 앞까지.
	_walk_to_last_step(run)
	# 보스.
	check("boss is selectable from the last step", run.enter(run.graph.boss_id))
	# 승리.
	run.finish_battle(true)
	check_eq("boss win succeeds", run.state, CommissionRun.State.SUCCEEDED)
	check("succeeded run is finished", run.is_finished())


# 지면 실패.
func _test_loss_fails() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	run.enter(run.graph.node_at(1, 0).id)
	# 패배.
	run.finish_battle(false)
	check_eq("loss fails the run", run.state, CommissionRun.State.FAILED)


# 도망은 실패.
func _test_fail_marks_failed() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	run.enter(run.graph.node_at(1, 0).id)
	# 도망.
	run.fail()
	check_eq("fleeing fails the run", run.state, CommissionRun.State.FAILED)


# 끝난 의뢰는 아무 칸도 고를 수 없고, 끝난 뒤의 승리가 상태를 바꾸지 않는다.
func _test_finished_run_accepts_no_moves() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	run.enter(run.graph.node_at(1, 0).id)
	run.fail()
	# 다음 칸.
	var next_id: int = run.graph.node_at(1, 1).id
	check("finished run offers nothing", not run.is_selectable(next_id))
	check("finished run rejects moves", not run.enter(next_id))
	# 끝난 뒤 승리 보고.
	run.finish_battle(true)
	check_eq("late win does not change a failed run", run.state, CommissionRun.State.FAILED)
```

`tests/run_tests.gd` 에서 `"res://tests/test_stage_graph.gd",` 다음 줄에:

```gdscript
	"res://tests/test_commission_run.gd",
```

- [ ] **Step 2: 실패 확인** — Expected: 스크립트 로드 실패.

- [ ] **Step 3: 구현** — `Scripts/map/commission_run.gd`:

```gdscript
## 의뢰 하나의 진행 상태. 1층 격자, 지금 칸, 지나온 길, 파티원 현재 체력, 성공·실패를 가진다.
## 의뢰가 끝나면 버린다 — 다음 의뢰는 체력이 가득 찬 새 CommissionRun 으로 시작한다.
class_name CommissionRun
# RefCounted: 노드가 아닌 가벼운 객체. 화면 없이 테스트할 수 있다.
extends RefCounted

## 의뢰 상태. 보스를 이기면 성공, 지거나 도망치면 실패.
enum State { IN_PROGRESS, SUCCEEDED, FAILED }

## 이 의뢰의 1층 격자.
var graph: StageGraph
## 이 의뢰를 연 월드맵 노드 id.
var map_node_id: int
## 지금 서 있는 칸.
var current_id: int
## 지나온 칸 id (순서대로, 시작 포함).
var visited: Array[int] = []
## 파티원 번호별 현재 체력.
var member_hp: Array[int] = []
## 파티원 번호별 최대 체력 (화면 표시용).
var member_max_hp: Array[int] = []
## 의뢰 상태.
var state: State = State.IN_PROGRESS
## 마지막 battle_roster 에 들어간 파티원 번호 (배치 순서).
var _roster_indices: Array[int] = []


## 격자를 새로 뽑고 시작 칸에 선다. 체력은 최대로 시작한다.
func _init(rng: RandomNumberGenerator, p_map_node_id: int, p_member_max_hp: Array[int]) -> void:
	# 격자.
	graph = StageGraph.new(rng)
	# 월드맵 노드.
	map_node_id = p_map_node_id
	# 시작 칸.
	current_id = graph.start_id
	# 지나온 길은 시작부터.
	visited = [graph.start_id]
	# 최대 체력 (복사본).
	member_max_hp = p_member_max_hp.duplicate()
	# 현재 체력 = 최대.
	member_hp = p_member_max_hp.duplicate()


## 그 칸으로 지금 갈 수 있으면 true.
func is_selectable(id: int) -> bool:
	# 끝난 의뢰는 아무 데도 못 간다.
	if is_finished():
		return false
	# 지금 칸에서 이어진 칸만.
	return graph.get_node(current_id).connections.has(id)


## 그 칸으로 이동한다. 갈 수 없으면 아무것도 바꾸지 않고 false.
func enter(id: int) -> bool:
	# 갈 수 없으면 거절.
	if not is_selectable(id):
		return false
	# 이동.
	current_id = id
	# 길에 기록.
	visited.append(id)
	# 성공.
	return true


## 지금 칸의 종류.
func current_kind() -> StageNode.Kind:
	# 지금 칸을 본다.
	return graph.get_node(current_id).kind


## 끝났으면 (성공·실패) true.
func is_finished() -> bool:
	# 진행 중이 아니면 끝.
	return state != State.IN_PROGRESS


## 파티 전체 배치에서 쓰러진 파티원을 빼고 현재 체력을 실은 전투 배치를 만든다. 원본 배치는 바꾸지 않는다.
func battle_roster(full: Array[UnitPlacement]) -> Array[UnitPlacement]:
	# 만들 배치.
	var roster: Array[UnitPlacement] = []
	# 번호 기억을 새로 한다.
	_roster_indices.clear()
	# 파티원마다.
	for i in full.size():
		# 쓰러졌으면 뺀다.
		if member_hp[i] <= 0:
			continue
		# 새 배치 (원본을 건드리지 않는다).
		var placement := UnitPlacement.new()
		# 같은 데이터.
		placement.unit_data = full[i].unit_data
		# 같은 칸.
		placement.cell = full[i].cell
		# 지금 체력으로 시작.
		placement.start_hp = member_hp[i]
		# 넣는다.
		roster.append(placement)
		# 어느 파티원이었는지 기억한다.
		_roster_indices.append(i)
	# 돌려준다.
	return roster


## 전투가 끝난 뒤 아군 최종 체력(배치 순서)을 파티원 번호로 되돌려 쓴다.
func apply_battle_hp(final_hp: Array[int]) -> void:
	# 둘 중 짧은 쪽까지.
	for k in mini(final_hp.size(), _roster_indices.size()):
		# 0 아래로 내려가지 않게.
		member_hp[_roster_indices[k]] = maxi(0, final_hp[k])


## 전투 결과를 반영한다. 지면 실패, 보스에서 이기면 성공, 그 외 승리는 계속.
func finish_battle(won: bool) -> void:
	# 이미 끝났으면 무시.
	if is_finished():
		return
	# 패배.
	if not won:
		state = State.FAILED
	# 보스 승리.
	elif current_id == graph.boss_id:
		state = State.SUCCEEDED


## 도망: 의뢰 실패.
func fail() -> void:
	# 진행 중일 때만.
	if not is_finished():
		state = State.FAILED
```

- [ ] **Step 4: 통과 확인** — 캐시 재스캔 후 테스트 실행. Expected: `test_commission_run.gd` 전부 PASS, 전체 FAIL 0.

- [ ] **Step 5: Commit**

```bash
git add Scripts/map/commission_run.gd Scripts/map/*.uid tests/test_commission_run.gd tests/*.uid tests/run_tests.gd
git commit -m "feat: track a commission run's position, hp and outcome"
```

---

### Task 5: `StageLayout` + `StageView` — 의뢰 화면

**Files:**
- Create: `Scripts/map/stage_layout.gd`, `Scripts/view/stage_view.gd`
- Test: `tests/test_stage_layout.gd`, `tests/test_stage_view.gd` (새), `tests/run_tests.gd` 목록에 추가

**Interfaces:**
- Consumes: Task 3 `StageGraph`/`StageNode`, Task 4 `CommissionRun`, 기존 `PartyState.member_count()`, `PartyState.member_data(i).display_name`.
- Produces:
  - `StageLayout.node_position(node: StageNode) -> Vector2` — `x = (step + 1) * STEP_SPACING`, `y = lane * LANE_SPACING` (`STEP_SPACING = 150.0`, `LANE_SPACING = 110.0`).
  - `StageView` (Control): `signal node_selected(id: int)`, `_init(run: CommissionRun)`, `sync_from_run(run: CommissionRun, party: PartyState)`, `show_result(text)`, `hide_result()`, 테스트 접근자 `button_for(id) -> Button`, `button_count() -> int`, `hp_text(index) -> String`, `title_text() -> String`, `result_visible() -> bool`, `result_text() -> String`. 색 상수 `LOCKED_COLOR`, `SELECTABLE_COLOR`, `CURRENT_COLOR`, `VISITED_COLOR`.

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test_stage_layout.gd`:

```gdscript
# StageLayout(의뢰 격자 좌표) 테스트: 시작이 x 0, 걸음마다 오른쪽, 줄마다 아래.
extends TestCase

# 칸 스크립트.
const StageNodeScript := preload("res://Scripts/map/stage_node.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 시작.
	var start: StageNode = StageNodeScript.new(0, 1, -1, StageNode.Kind.START)
	check_eq("start sits at x 0", StageLayout.node_position(start), Vector2(0.0, StageLayout.LANE_SPACING))
	# (2, 3) 칸.
	var cell: StageNode = StageNodeScript.new(5, 2, 3, StageNode.Kind.BATTLE)
	check_eq("cell (2,3) position", StageLayout.node_position(cell), Vector2(4.0 * StageLayout.STEP_SPACING, 2.0 * StageLayout.LANE_SPACING))
	# 결과를 돌려준다.
	return results()
```

`tests/test_stage_view.gd`:

```gdscript
# StageView(의뢰 화면) 테스트: 칸마다 버튼, 누르면 신호, 상태별 눌림·색, 파티 체력 줄, 제목, 결과 문구.
extends TestCase

# 의뢰 화면 스크립트.
const StageViewScript := preload("res://Scripts/view/stage_view.gd")
# 의뢰 진행 스크립트.
const CommissionRunScript := preload("res://Scripts/map/commission_run.gd")
# 파티 상태 스크립트.
const PartyStateScript := preload("res://Scripts/party/party_state.gd")
# 아군 데이터 스크립트.
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
# 배치 스크립트.
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 칸마다 버튼.
	_test_creates_a_button_per_cell()
	# 누르면 신호.
	_test_button_press_emits_node_selected()
	# 고를 수 있는 칸만 눌린다, 지금·지나온 칸 색.
	_test_sync_enables_selectable_and_colors_path()
	# 체력 줄.
	_test_hp_lines_show_current_and_fallen()
	# 제목.
	_test_title()
	# 결과 문구.
	_test_result_banner()
	# 결과를 돌려준다.
	return results()


# 시드 고정 의뢰 (파티 최대 체력 [30, 20]).
func _run() -> CommissionRun:
	# 생성기.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# 최대 체력.
	var max_hp: Array[int] = [30, 20]
	# 의뢰.
	return CommissionRunScript.new(rng, 0, max_hp)


# 이름이 "가", "나" 인 두 명 파티.
func _party() -> PartyState:
	# 배치 목록.
	var roster: Array[UnitPlacement] = []
	for name in ["가", "나"]:
		# 데이터.
		var data: AllyData = AllyDataScript.new()
		data.display_name = name
		# 배치.
		var placement: UnitPlacement = PlacementScript.new()
		placement.unit_data = data
		roster.append(placement)
	# 파티.
	return PartyStateScript.new(roster)


# 화면을 만들어 트리에 붙인다 (_ready 가 돌아야 버튼이 생긴다).
func _view(run: CommissionRun) -> StageView:
	# 화면.
	var view: StageView = StageViewScript.new(run)
	# 붙인다.
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	# 돌려준다.
	return view


# 버튼 수 = 칸 수.
func _test_creates_a_button_per_cell() -> void:
	# 의뢰와 화면.
	var run: CommissionRun = _run()
	var view: StageView = _view(run)
	check_eq("one button per cell", view.button_count(), run.graph.node_count())
	# 정리.
	view.free()


# 버튼을 누르면 그 칸 id 를 알린다.
func _test_button_press_emits_node_selected() -> void:
	# 의뢰와 화면.
	var run: CommissionRun = _run()
	var view: StageView = _view(run)
	view.sync_from_run(run, _party())
	# 받은 id (람다에서 바꾸려고 배열).
	var got: Array[int] = []
	view.node_selected.connect(func(id: int) -> void: got.append(id))
	# 첫 걸음 가운데 칸.
	var target: int = run.graph.node_at(1, 0).id
	view.button_for(target).pressed.emit()
	var expected: Array[int] = [target]
	check_eq("pressing emits the cell id", got, expected)
	# 정리.
	view.free()


# (1,0) 으로 간 뒤: (0..2,1) 눌림, (1,0) 은 지금 칸 색, 시작은 지나온 색, 보스는 잠김.
func _test_sync_enables_selectable_and_colors_path() -> void:
	# 의뢰와 화면.
	var run: CommissionRun = _run()
	var view: StageView = _view(run)
	# 가운데 첫 칸으로.
	var here: int = run.graph.node_at(1, 0).id
	run.enter(here)
	view.sync_from_run(run, _party())
	# 다음 걸음 세 칸은 눌린다.
	for lane in StageGraph.LANES:
		var button: Button = view.button_for(run.graph.node_at(lane, 1).id)
		check("next lane %d enabled" % lane, not button.disabled)
		check_eq("next lane %d selectable color" % lane, button.modulate, StageView.SELECTABLE_COLOR)
	# 지금 칸.
	check_eq("current cell color", view.button_for(here).modulate, StageView.CURRENT_COLOR)
	check("current cell disabled", view.button_for(here).disabled)
	# 시작은 지나온 칸.
	check_eq("start shows as visited", view.button_for(run.graph.start_id).modulate, StageView.VISITED_COLOR)
	# 보스는 잠김.
	check("boss disabled", view.button_for(run.graph.boss_id).disabled)
	check_eq("boss locked color", view.button_for(run.graph.boss_id).modulate, StageView.LOCKED_COLOR)
	# 정리.
	view.free()


# 체력 줄: "가  30 / 30", 쓰러진 "나" 는 "나  쓰러짐".
func _test_hp_lines_show_current_and_fallen() -> void:
	# 의뢰와 화면.
	var run: CommissionRun = _run()
	var view: StageView = _view(run)
	# 둘째가 쓰러졌다.
	run.member_hp = [30, 0]
	view.sync_from_run(run, _party())
	check_eq("living member hp line", view.hp_text(0), "가  30 / 30")
	check_eq("fallen member hp line", view.hp_text(1), "나  쓰러짐")
	# 정리.
	view.free()


# 제목은 "1층 탐사 중".
func _test_title() -> void:
	# 화면.
	var view: StageView = _view(_run())
	check_eq("title text", view.title_text(), "1층 탐사 중")
	# 정리.
	view.free()


# 결과 문구 보이기·숨기기.
func _test_result_banner() -> void:
	# 화면.
	var view: StageView = _view(_run())
	check("result hidden at first", not view.result_visible())
	view.show_result("아무 일도 없었다")
	check("result shown", view.result_visible())
	check_eq("result text", view.result_text(), "아무 일도 없었다")
	view.hide_result()
	check("result hidden again", not view.result_visible())
	# 정리.
	view.free()
```

`tests/run_tests.gd` 에서 `"res://tests/test_map_view.gd",` 다음 줄에:

```gdscript
	"res://tests/test_stage_layout.gd",
	"res://tests/test_stage_view.gd",
```

- [ ] **Step 2: 실패 확인** — Expected: 두 스크립트 로드 실패.

- [ ] **Step 3: 구현** — `Scripts/map/stage_layout.gd`:

```gdscript
## 의뢰 격자 칸의 화면 좌표를 계산하는 도구. 칸의 줄·걸음(StageNode.lane/step)을 픽셀 위치로 바꾼다.
class_name StageLayout
# RefCounted: 정적 함수만 쓴다.
extends RefCounted

## 걸음 사이 가로 간격 (픽셀).
const STEP_SPACING: float = 150.0
## 줄 사이 세로 간격 (픽셀).
const LANE_SPACING: float = 110.0


## 칸이 그려질 위치. 시작(걸음 -1)이 x = 0, 위 줄(0)이 y = 0.
static func node_position(node: StageNode) -> Vector2:
	# 걸음에 1 을 더해 시작을 0 으로 맞춘다.
	var x: float = float(node.step + 1) * STEP_SPACING
	# 줄 번호에 세로 간격을 곱한다.
	var y: float = float(node.lane) * LANE_SPACING
	# 돌려준다.
	return Vector2(x, y)
```

`Scripts/view/stage_view.gd`:

```gdscript
## 의뢰 화면 (1층 격자). 칸마다 버튼을 놓고 연결선을 그리며, 아래에 파티 체력을 보여 준다.
## 진행 상태는 들고 있지 않는다 — GameRoot 가 sync_from_run 으로 넘겨 주는 CommissionRun 을 보고 색만 바꾼다.
class_name StageView
# Control: 화면 전체를 덮는 UI 노드.
extends Control

## 갈 수 있는 칸 버튼을 눌렀을 때.
signal node_selected(id: int)

## 칸 버튼 크기.
const NODE_SIZE: Vector2 = Vector2(56.0, 56.0)
## 아직 갈 수 없는 칸 색.
const LOCKED_COLOR := Color(0.3, 0.3, 0.32)
## 지금 갈 수 있는 칸 색.
const SELECTABLE_COLOR := Color(0.85, 0.75, 0.3)
## 지금 서 있는 칸 색.
const CURRENT_COLOR := Color(0.3, 0.6, 0.9)
## 지나온 칸 색.
const VISITED_COLOR := Color(0.9, 0.55, 0.2)
## 연결선 기본 색.
const LINE_COLOR := Color(0.45, 0.45, 0.5)
## 지나온 길 연결선 색.
const PATH_LINE_COLOR := Color(0.9, 0.55, 0.2)
## 제목 문구.
const TITLE_TEXT: String = "1층 탐사 중"

## 그리고 있는 의뢰.
var _run: CommissionRun
## 칸 id -> 버튼.
var _buttons: Dictionary = {}
## 제목 글자.
var _title_label: Label
## 결과 문구 (빈 칸·승리).
var _result_label: Label
## 파티 체력 줄을 담는 상자.
var _hp_box: HBoxContainer
## 파티원별 체력 글자.
var _hp_labels: Array[Label] = []
## 격자를 화면 가운데에 두기 위한 기준점.
var _origin: Vector2 = Vector2.ZERO


## 그릴 의뢰를 받는다. 버튼은 트리에 들어간 뒤(_ready) 만든다.
func _init(run: CommissionRun) -> void:
	# 의뢰를 기억한다.
	_run = run


## 화면을 구성한다.
func _ready() -> void:
	# 화면 전체를 덮는다.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 이 노드 자체는 마우스를 받지 않는다 (버튼만 받는다).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 제목.
	_title_label = _make_top_label(TITLE_TEXT, 20.0, 28)
	add_child(_title_label)
	# 결과 문구 (처음엔 숨김).
	_result_label = _make_top_label("", 70.0, 26)
	_result_label.visible = false
	add_child(_result_label)
	# 파티 체력 상자.
	_hp_box = _make_hp_box()
	add_child(_hp_box)
	# 칸 버튼.
	for node in _run.graph.nodes:
		_buttons[node.id] = _make_button(node)
	# 가운데로 맞춘다.
	_recenter()
	# 창 크기가 바뀌면 다시 맞춘다.
	get_viewport().size_changed.connect(_recenter)


## 진행 상태에 맞춰 버튼 눌림·색과 체력 줄을 바꾼다.
func sync_from_run(run: CommissionRun, party: PartyState) -> void:
	# 의뢰를 기억한다 (선 그리기용).
	_run = run
	# 칸마다.
	for node in run.graph.nodes:
		# 버튼.
		var button: Button = _buttons[node.id]
		# 갈 수 있는지.
		var selectable: bool = run.is_selectable(node.id)
		# 갈 수 없으면 막는다.
		button.disabled = not selectable
		# 색.
		button.modulate = _color_for(node.id, selectable)
	# 체력 줄을 다시 만든다.
	_rebuild_hp_lines(run, party)
	# 선을 다시 그린다.
	queue_redraw()


## 결과 문구를 띄운다.
func show_result(text: String) -> void:
	# 문구.
	_result_label.text = text
	# 보이기.
	_result_label.visible = true


## 결과 문구를 숨긴다.
func hide_result() -> void:
	# 숨긴다.
	_result_label.visible = false


## 그 칸의 버튼 (테스트용 접근자).
func button_for(id: int) -> Button:
	# 돌려준다.
	return _buttons[id]


## 버튼 개수 (테스트용 접근자).
func button_count() -> int:
	# 돌려준다.
	return _buttons.size()


## 파티원 체력 줄 글자 (테스트용 접근자).
func hp_text(index: int) -> String:
	# 돌려준다.
	return _hp_labels[index].text


## 제목 글자 (테스트용 접근자).
func title_text() -> String:
	# 돌려준다.
	return _title_label.text


## 결과 문구가 보이면 true (테스트용 접근자).
func result_visible() -> bool:
	# 돌려준다.
	return _result_label.visible


## 결과 문구 내용 (테스트용 접근자).
func result_text() -> String:
	# 돌려준다.
	return _result_label.text


## 칸 상태에 맞는 색. 우선순위: 지금 칸 > 갈 수 있음 > 지나옴 > 잠김.
func _color_for(id: int, selectable: bool) -> Color:
	# 지금 칸.
	if id == _run.current_id:
		return CURRENT_COLOR
	# 갈 수 있는 칸.
	if selectable:
		return SELECTABLE_COLOR
	# 지나온 칸.
	if _run.visited.has(id):
		return VISITED_COLOR
	# 잠김.
	return LOCKED_COLOR


## 칸 버튼 하나를 만든다. 처음엔 잠김 (sync_from_run 이 풀어 준다).
func _make_button(node: StageNode) -> Button:
	# 버튼.
	var button := Button.new()
	# 크기.
	button.custom_minimum_size = NODE_SIZE
	# 종류 글자.
	button.text = _label_for(node.kind)
	# 처음엔 막는다.
	button.disabled = true
	# 잠김 색.
	button.modulate = LOCKED_COLOR
	# 누르면 칸 id 를 알린다.
	button.pressed.connect(func() -> void: node_selected.emit(node.id))
	# 붙인다.
	add_child(button)
	# 돌려준다.
	return button


## 칸 종류 글자.
func _label_for(kind: StageNode.Kind) -> String:
	# 종류별.
	match kind:
		StageNode.Kind.START:
			return "시작"
		StageNode.Kind.BATTLE:
			return "전투"
		StageNode.Kind.EVENT:
			return "?"
		StageNode.Kind.SHOP:
			return "상점"
		StageNode.Kind.REST:
			return "휴식"
		_:
			return "보스"


## 화면 위쪽 가운데 글자를 만든다.
func _make_top_label(text: String, top: float, font_size: int) -> Label:
	# 글자.
	var label := Label.new()
	# 내용.
	label.text = text
	# 가운데 정렬.
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 화면 너비 전체.
	label.anchor_right = 1.0
	# 위치.
	label.position = Vector2(0.0, top)
	# 크기.
	label.add_theme_font_size_override("font_size", font_size)
	# 돌려준다.
	return label


## 화면 아래쪽 파티 체력 상자를 만든다.
func _make_hp_box() -> HBoxContainer:
	# 가로 상자.
	var box := HBoxContainer.new()
	# 화면 아래 가로 전체.
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.anchor_right = 1.0
	# 아래에서 70 ~ 20 픽셀.
	box.offset_top = -70.0
	box.offset_bottom = -20.0
	# 가운데 정렬.
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	# 사이 간격.
	box.add_theme_constant_override("separation", 40)
	# 돌려준다.
	return box


## 파티원마다 "이름  현재 / 최대" (쓰러졌으면 "이름  쓰러짐") 글자를 다시 만든다.
func _rebuild_hp_lines(run: CommissionRun, party: PartyState) -> void:
	# 기존 글자를 지운다.
	for label in _hp_labels:
		label.free()
	# 목록을 비운다.
	_hp_labels.clear()
	# 파티원마다.
	for i in party.member_count():
		# 글자.
		var label := Label.new()
		# 이름.
		var member_name: String = party.member_data(i).display_name
		# 쓰러졌는지에 따라.
		if run.member_hp[i] <= 0:
			label.text = "%s  쓰러짐" % member_name
		else:
			label.text = "%s  %d / %d" % [member_name, run.member_hp[i], run.member_max_hp[i]]
		# 붙인다.
		_hp_box.add_child(label)
		# 기억한다.
		_hp_labels.append(label)


## 격자 경계의 가운데가 화면 가운데에 오도록 기준점을 정하고 버튼을 옮긴다.
func _recenter() -> void:
	# 경계 상자.
	var min_pos: Vector2 = StageLayout.node_position(_run.graph.nodes[0])
	var max_pos: Vector2 = min_pos
	for node in _run.graph.nodes:
		var local: Vector2 = StageLayout.node_position(node)
		min_pos = min_pos.min(local)
		max_pos = max_pos.max(local)
	# 화면 가운데에 맞춘다.
	_origin = get_viewport_rect().size / 2.0 - (min_pos + max_pos) / 2.0
	# 버튼을 옮긴다 (가운데 기준이라 크기 절반을 뺀다).
	for node in _run.graph.nodes:
		(_buttons[node.id] as Button).position = _origin + StageLayout.node_position(node) - NODE_SIZE / 2.0
	# 선을 다시 그린다.
	queue_redraw()


## 연결선을 그린다. 지나온 길(연속한 두 칸)은 굵은 주황, 나머지는 얇은 회색.
func _draw() -> void:
	# 칸마다.
	for node in _run.graph.nodes:
		# 시작점.
		var from: Vector2 = _origin + StageLayout.node_position(node)
		# 이어진 칸마다.
		for next_id in node.connections:
			# 끝점.
			var to: Vector2 = _origin + StageLayout.node_position(_run.graph.get_node(next_id))
			# 지나온 길인지: 두 칸이 길에서 바로 이어져 있다.
			var index: int = _run.visited.find(node.id)
			var on_path: bool = index >= 0 and index + 1 < _run.visited.size() and _run.visited[index + 1] == next_id
			# 그린다.
			if on_path:
				draw_line(from, to, PATH_LINE_COLOR, 4.0)
			else:
				draw_line(from, to, LINE_COLOR, 2.0)
```

- [ ] **Step 4: 통과 확인** — 캐시 재스캔 후 테스트 실행. Expected: 두 스위트 PASS, 전체 FAIL 0.

- [ ] **Step 5: Commit**

```bash
git add Scripts/map/stage_layout.gd Scripts/view/stage_view.gd Scripts/map/*.uid Scripts/view/*.uid tests/test_stage_layout.gd tests/test_stage_view.gd tests/*.uid tests/run_tests.gd
git commit -m "feat: add the commission floor screen"
```

---

### Task 6: `GameRoot` 연결 + 통합 확인

**Files:**
- Modify: `Scripts/view/game_root.gd`
- Create (임시, 커밋하지 않음): 스크래치패드 `commission_smoke.gd`

**Interfaces:**
- Consumes: Task 2 `BattleRoot.ally_final_hp()`, Task 4 `CommissionRun` 전체, Task 5 `StageView`, 기존 `MapRunState.encounter_for/resolve_win/is_selectable`, `EncounterGenerator.assemble_encounter/build_enemy_placements`, `PartyState.stats(i)["max_hp"]`, `ItemPool.roll`.
- Produces: `GameRoot.stage_view: StageView` (의뢰 중이 아니면 null), `GameRoot._commission: CommissionRun` (의뢰 중이 아니면 null).

- [ ] **Step 1: `game_root.gd` 상수·변수 추가** — `FLED_TEXT` 아래에:

```gdscript
## 의뢰 중 빈 칸(이벤트·상점·휴식)에 들어갔을 때 띄우는 문구.
const EMPTY_ROOM_TEXT: String = "아무 일도 없었다"
## 의뢰 중 일반 전투에서 이겼을 때 첫 줄.
const BATTLE_WON_TEXT: String = "승리!"
```

`var party_view: PartyView` 아래에:

```gdscript
## 의뢰 화면. 의뢰 중이 아니면 null.
var stage_view: StageView
## 진행 중인 의뢰. 의뢰 중이 아니면 null.
var _commission: CommissionRun
```

- [ ] **Step 2: 월드맵 노드 선택 → 의뢰 시작** — `_on_node_selected` 를 다음으로 바꾼다:

```gdscript
## 지도에서 노드를 눌렀다: 그 노드의 의뢰를 시작한다.
func _on_node_selected(node_id: int) -> void:
	# 이미 전투·의뢰 중이거나 들어갈 수 없는 노드면 무시한다.
	if _battle != null or _commission != null or not run_state.is_selectable(node_id):
		return
	# 체력이 가득 찬 새 의뢰를 만든다.
	_commission = CommissionRun.new(_rng, node_id, _member_max_hp())
	# 의뢰 화면을 만든다.
	stage_view = StageView.new(_commission)
	# 붙인다.
	add_child(stage_view)
	# 칸을 누르면 그 칸으로 간다.
	stage_view.node_selected.connect(_on_stage_node_selected)
	# 칸 색과 체력 줄을 맞춘다.
	stage_view.sync_from_run(_commission, party)
	# 지난 결과 문구를 지운다.
	map_view.hide_result()
	# 지도를 숨긴다.
	map_view.hide()


## 파티원별 최대 체력 (장비 반영).
func _member_max_hp() -> Array[int]:
	# 모을 목록.
	var result: Array[int] = []
	# 파티원마다.
	for i in party.member_count():
		result.append(party.stats(i)["max_hp"])
	# 돌려준다.
	return result


## 의뢰 화면에서 칸을 눌렀다: 이동하고, 전투·보스면 전투를 연다.
func _on_stage_node_selected(id: int) -> void:
	# 전투 중이거나 갈 수 없으면 무시한다.
	if _battle != null or _commission == null or not _commission.enter(id):
		return
	# 들어간 칸의 종류.
	var kind: StageNode.Kind = _commission.current_kind()
	# 빈 칸: 문구만 띄운다.
	if kind != StageNode.Kind.BATTLE and kind != StageNode.Kind.BOSS:
		stage_view.show_result(EMPTY_ROOM_TEXT)
		stage_view.sync_from_run(_commission, party)
		return
	# 아군: 장비 반영 배치에서 쓰러진 파티원을 빼고 지금 체력을 싣는다.
	var allies: Array[UnitPlacement] = _commission.battle_roster(party.build_battle_roster())
	# 보스는 그 월드맵 노드의 적, 일반 전투는 새로 뽑은 적.
	var encounter: EncounterData
	if kind == StageNode.Kind.BOSS:
		encounter = run_state.encounter_for(_commission.map_node_id, allies)
	else:
		encounter = EncounterGenerator.assemble_encounter(allies, EncounterGenerator.build_enemy_placements(_rng, false))
	# 전투를 연다.
	_start_battle(encounter)
```

- [ ] **Step 3: 전투 시작·종료·도망 바꾸기** — 기존 `_start_battle`, `_on_battle_fled`, `_on_battle_finished` 를 다음으로 바꾼다 (`_victory_text` 는 그대로 둔다):

```gdscript
## 전투 씬을 만들어 띄운다.
func _start_battle(encounter: EncounterData) -> void:
	# 전투 씬을 만든다.
	_battle = BattleScene.instantiate()
	# 전투 구성.
	_battle.encounter = encounter
	# 전투가 끝나면 결과를 처리한다.
	_battle.battle_finished.connect(_on_battle_finished)
	# 도망치면 의뢰 실패.
	_battle.battle_fled.connect(_on_battle_fled)
	# 지난 결과 문구를 지운다.
	stage_view.hide_result()
	# 의뢰 화면을 숨긴다.
	stage_view.hide()
	# 전투 씬을 붙인다.
	add_child(_battle)


## 도망쳤다: 의뢰 실패, 진행도 변화 없이 지도로 돌아온다.
func _on_battle_fled() -> void:
	# 전투 중이 아니면 무시한다 (중복 신호 방어).
	if _battle == null:
		return
	# 전투 씬을 지운다.
	_battle.queue_free()
	# 전투 중이 아니라고 표시한다.
	_battle = null
	# 의뢰 실패.
	_commission.fail()
	# 지도로.
	_return_to_map(FLED_TEXT)


## 전투가 끝났다. 체력을 넘기고, 이겼으면 보상을 주고, 의뢰 결과에 따라 의뢰 화면이나 지도로 간다.
func _on_battle_finished(ally_won: bool) -> void:
	# 전투 중이 아니면 무시한다 (중복 신호 방어).
	if _battle == null:
		return
	# 씬을 지우기 전에 아군 체력을 의뢰로 넘긴다.
	_commission.apply_battle_hp(_battle.ally_final_hp())
	# 전투 씬을 지운다.
	_battle.queue_free()
	# 전투 중이 아니라고 표시한다.
	_battle = null
	# 의뢰에 결과를 반영한다.
	_commission.finish_battle(ally_won)
	# 얻은 아이템 (지면 없음).
	var loot: ItemData = null
	# 이겼으면 보상 아이템을 하나 뽑아 가방에 넣는다.
	if ally_won:
		loot = ItemPool.roll(_rng, _item_pool)
		party.add_item(loot)
	# 의뢰 결과별.
	match _commission.state:
		# 보스까지 이겼다: 월드맵 노드를 깬다.
		CommissionRun.State.SUCCEEDED:
			# 보스 노드였는지 미리 기억한다 (resolve_win 이 지도를 바꿀 수 있어서).
			var was_boss: bool = _commission.map_node_id == run_state.graph.boss_id
			# 진행도를 반영한다.
			run_state.resolve_win(_commission.map_node_id)
			# 지도로.
			_return_to_map(_victory_text(was_boss, loot))
		# 졌다.
		CommissionRun.State.FAILED:
			_return_to_map(DEFEATED_TEXT)
		# 아직 의뢰 중: 의뢰 화면으로.
		_:
			# 승리 문구 (+ 획득 아이템).
			var text: String = BATTLE_WON_TEXT
			if loot != null:
				text += "\n획득: %s" % loot.display_name
			stage_view.show_result(text)
			# 칸 색과 체력 줄을 맞춘다.
			stage_view.sync_from_run(_commission, party)
			# 의뢰 화면을 보인다.
			stage_view.show()


## 의뢰를 끝내고 지도로 돌아온다. 보스 클리어로 지도가 바뀌었으면 다시 짠다.
func _return_to_map(text: String) -> void:
	# 의뢰 화면을 지운다.
	stage_view.queue_free()
	# 의뢰 중이 아니라고 표시한다 (체력은 다음 의뢰에서 새로 가득 찬다).
	stage_view = null
	_commission = null
	# 문구를 띄운다.
	map_view.show_result(text)
	# 보스를 깨면 run_state 가 새 그래프를 만든다 — 바뀌었는지 따로 들고 다니지 않고 항상 다시 짠다 (버튼 몇 개라 비용이 작다).
	map_view.rebuild(run_state.graph)
	# 노드 색을 맞춘다.
	map_view.sync_from_state(run_state)
	# 지도를 보인다.
	map_view.show()
```

- [ ] **Step 4: 기존 테스트 확인** — 캐시 재스캔 후 전체 테스트 실행. Expected: 전체 FAIL 0 (GameRoot 를 직접 띄우는 테스트는 없고, 스크립트 파싱 오류가 없는지 확인하는 단계).

- [ ] **Step 5: 통합 스모크 스크립트 작성** — 스크래치패드(`C:\Users\User\AppData\Local\Temp\claude\C--Users-User-Desktop-Godot-Project-Void\0fbf0a80-8e4f-4736-be5d-ef880822058b\scratchpad\commission_smoke.gd`)에 작성. 전투 연출을 기다리지 않으려고 `_on_battle_finished` 를 직접 부른다:

```gdscript
# 의뢰 흐름 수동 확인: 월드맵 → 의뢰 → 빈 칸/전투(체력 유지) → 보스 → 월드맵 클리어, 그리고 패배·도망.
extends SceneTree

var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	_check()
	return false


func _fail(msg: String) -> void:
	print("SMOKE FAIL: ", msg)
	quit(1)


func _check() -> void:
	var game: GameRoot = (load("res://Scenes/game_root.tscn") as PackedScene).instantiate()
	root.add_child(game)
	var first_story: int = game.run_state.graph.get_node(game.run_state.graph.start_id).connections[0]
	# 1) 의뢰 시작.
	game._on_node_selected(first_story)
	if game.stage_view == null or game.map_view.visible:
		_fail("commission did not open")
		return
	# 겹쳐 열기 방지.
	var first_run: CommissionRun = game._commission
	game._on_node_selected(first_story)
	if game._commission != first_run:
		_fail("second commission overlapped")
		return
	# 2) 가운데 줄로 끝까지: 전투면 아군 체력 5 깎고 승리 처리.
	for step in StageGraph.STEPS:
		var id: int = game._commission.graph.node_at(1, step).id
		game._on_stage_node_selected(id)
		if game._battle != null:
			game._battle._state.units[0].hp -= 5
			game._on_battle_finished(true)
	print("hp after floor: ", game._commission.member_hp)
	if game._commission.member_hp[0] >= game._commission.member_max_hp[0]:
		_fail("hp did not carry over")
		return
	# 3) 보스.
	game._on_stage_node_selected(game._commission.graph.boss_id)
	if game._battle == null:
		_fail("boss battle did not open")
		return
	game._on_battle_finished(true)
	if game._commission != null or not game.run_state.cleared.has(first_story):
		_fail("boss win did not clear the map node")
		return
	print("boss cleared, map text: ", game.map_view.result_text())
	# 4) 다음 노드에서 패배.
	var second: int = game.run_state.graph.get_node(first_story).connections[0]
	game._on_node_selected(second)
	game._on_stage_node_selected(game._commission.graph.node_at(0, 0).id)
	game._on_battle_finished(false)
	if game._commission != null or game.run_state.cleared.has(second):
		_fail("defeat did not fail the commission cleanly")
		return
	# 5) 다시 들어가 도망.
	game._on_node_selected(second)
	if game._commission.member_hp != game._commission.member_max_hp:
		_fail("hp was not restored for a new commission")
		return
	game._on_stage_node_selected(game._commission.graph.node_at(2, 0).id)
	game._on_battle_fled()
	if game._commission != null or game.run_state.cleared.has(second):
		_fail("flee did not fail the commission cleanly")
		return
	print("SMOKE OK")
	quit(0)
```

step 0 은 항상 전투라 층을 지나면 첫 파티원 체력이 최소 한 번(5) 깎여 있어야 한다.

- [ ] **Step 6: 스모크 실행**

```powershell
& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --script "C:\Users\User\AppData\Local\Temp\claude\C--Users-User-Desktop-Godot-Project-Void\0fbf0a80-8e4f-4736-be5d-ef880822058b\scratchpad\commission_smoke.gd"
```

Expected: `hp after floor: [...]`, `boss cleared, map text: 챕터 클리어!…` 가 아니라 `승리!\n획득: …` (첫 스토리 노드는 보스가 아니다), 마지막 `SMOKE OK`, 종료 코드 0.

- [ ] **Step 7: 전체 테스트 다시 실행** — Expected: 전체 FAIL 0.

- [ ] **Step 8: Commit**

```bash
git add Scripts/view/game_root.gd
git commit -m "feat: run commissions as a floor between the world map and battles"
```
