# 맵 프로토타입 설계

- 작성일: 2026-09-16
- 대상: 슬레이 더 스파이어 방식 노드 맵과 전투 연결
- 상태: 승인 대기
- 선행 문서: `2026-09-12-combat-prototype-design.md` (전투 규칙, 변경하지 않음)

## 1. 배경

전투 시스템은 규칙(헤드리스 테스트로 검증) → 이벤트 기록·재생 → 2.5D 화면까지 완성됐다. 지금은 `battle_3d.tscn`이 메인 씬이고, 인카운터는 `Resources/encounters/skirmish.tres` 하나로 고정돼 있다. 이 문서는 그 위에 "노드를 골라 전투에 들어가고, 이기면 다음 노드로 진행하는" 런 구조를 얹는 설계다.

전투 규칙(`Scripts/combat/`)은 완전히 그대로 둔다. 이번 작업은 **어떤 인카운터를, 언제, 어떤 화면으로 띄우는가**를 다루는 한 단계 바깥 레이어다.

## 2. 범위

### 포함 (사용자 요청 그대로)

- 시작 노드 1개 → 2갈래 분기 → 갈래당 4스텝 → 보스 노드 1개로 합류하는 고정 그래프
- 현재 위치에서 연결된 다음 노드만 선택 가능
- 노드 클릭 → 전투 진입, 승리 시 클리어 처리 후 맵 복귀, 패배 시 런 종료·맵 초기화
- 노드마다 `Resources/units/`에서 적 구성을 랜덤 조합
- `Resources/cards/`에서 시작 덱을 랜덤 구성
- 맵 로직은 Node 비의존 `RefCounted`, 시드 주입 가능, 헤드리스 테스트

### 제외

전투 보상/카드 획득/덱 영속성, 상점·휴식·이벤트 노드, 맵 그래픽 완성도, 세이브·로드. 전투 규칙 자체(피해·타겟팅·턴 진행) 변경도 제외 — `Scripts/combat/`은 손대지 않는다.

## 3. 확정한 가정 (승인 필요)

사용자 요청에 명시되지 않아 이번 설계에서 임의로 정한 부분이다. 아래 표만 검토하면 스펙 전체를 검토한 것과 같다.

| 항목 | 결정 | 근거 |
|---|---|---|
| 아군 구성 | `vanguard`/`archer`/`scout` 3기 고정 로스터, 배치도 `skirmish.tres`와 동일 `(0,1)/(2,0)/(1,2)`, 아군 그리드 3×3 고정 | 사용자는 "적 구성"과 "시작 덱"만 랜덤화를 요청했다. 아군 유닛 자체(로스터)를 랜덤화한다는 언급은 없었다 |
| 시작 덱 | **런 시작 시 한 번**, 아군 유닛별로 `Resources/cards/`에서 8장을 중복 허용 균등 추출해 덱을 구성한다. 이 덱은 런 내내 고정이고 전투마다 초기화돼 재사용된다 | "전투마다 덱 초기화"(제외 항목)는 매 전투 같은 구성으로 리셋된다는 뜻이지, 노드마다 다른 덱을 새로 뽑으라는 뜻이 아니라고 해석했다. 노드마다 다시 뽑으면 "성장이 없는 런"이라는 의미 자체가 흐려진다 |
| 적 그리드 | 모든 노드에서 3×3 고정 | 아군 그리드와 통일해 좌표계 특이 케이스를 줄인다 |
| 일반 노드 적 수 | 1~3마리, `Resources/units/`의 `EnemyData` 전체 풀에서 중복 허용 무작위 추출, 서로 다른 랜덤 칸에 배치 | 스커미시(3마리)보다 가볍게도, 비슷하게도 나올 수 있게 |
| 보스 노드 적 수 | 4마리 고정, 같은 풀에서 추출 | 능력치 스케일링은 범위 밖이므로 "더 강하다"를 숫자(마릿수)로만 표현한다 |
| 보스 클리어 시 | 새 런으로 초기화 (패배와 동일하게 `reset()`) | 보상·다음 층 개념이 없는 프로토타입이라 "클리어 = 런 종료"가 가장 단순하다 |
| 노드 좌표/시각화 | 2D `Control`에 원(노드)과 선(연결)만 그린다. 씬 파일 없이 코드로 구성 (`UnitView`가 코드로 자식을 만드는 전례를 따름) | 그래픽 완성도는 명시적으로 범위 밖 |

이 표의 어느 항목이든 다르게 가고 싶으면 계획 단계 전에 알려달라.

## 4. 아키텍처

기존 3계층(표현 / 규칙 코어 / 데이터)을 맵에도 그대로 적용하고, 그 위에 **런 전체를 오케스트레이션하는 `GameRoot`**를 새 메인 씬으로 둔다.

```
┌────────────────────────────────────────────────────────┐
│  GameRoot (Node)  — 새 메인 씬                          │
│  MapView 와 BattleRoot 인스턴스 중 하나만 화면에 띄운다   │
└───────────┬──────────────────────────┬─────────────────┘
            │                          │
┌───────────▼─────────────┐  ┌─────────▼──────────────────┐
│  맵 표현 (Scripts/view/)  │  │  battle_3d.tscn 인스턴스     │
│  MapView (Control)       │  │  (기존 BattleRoot, 무수정 흐름)│
└───────────┬─────────────┘  └─────────┬──────────────────┘
            │ 읽기 전용                  │ battle_finished(ally_won) (신규 시그널)
┌───────────▼──────────────────────────▼─────────────────┐
│  맵 규칙 코어 (RefCounted, Scripts/map/)                  │
│  MapGraph / MapNode / MapLayout / MapRunState /          │
│  EncounterGenerator                                      │
└───────────┬──────────────────────────────────────────────┘
            │ 생성 시 소비
┌───────────▼──────────────────────────────────────────────┐
│  기존 데이터 (Resource) — Scripts/combat/data/            │
│  CardData / UnitData(AllyData/EnemyData) / EncounterData  │
└────────────────────────────────────────────────────────────┘
```

`Scripts/combat/`은 이 다이어그램에서 최하단 데이터 계층의 타입만 제공한다. 맵 규칙 코어는 그 타입의 인스턴스를 만들 뿐(읽기 전용 소비 + 새 인스턴스 생성), 기존 파일은 한 줄도 바꾸지 않는다.

**만들지 않는 것:** `BattleRoot`/`Board3D` 재사용·리셋 로직. 노드에 들어갈 때마다 `battle_3d.tscn`을 새로 인스턴스하고, 전투가 끝나면 통째로 `queue_free()`한다. 기존 표현 레이어(수십 개 테스트로 덮인 `Board3D`, `UnitView`, `BattlePlayback`)를 재진입 가능하게 고치는 것보다 매번 새로 만드는 편이 훨씬 단순하고, 검증된 코드를 건드리지 않는다. 프로토타입 규모에서 씬 재생성 비용은 무시할 만하다.

## 5. 맵 그래프 (`Scripts/map/map_node.gd`, `map_graph.gd`)

```gdscript
# MapNode (RefCounted) — 그래프의 정점 하나. 구조 정보만 가진다 (진행 상태는 MapRunState 가 소유)
id: int
branch: int          # -1 = 시작/보스, 0 또는 1 = 어느 갈래인지
step: int            # -1 = 시작/보스, 0~3 = 갈래 안에서 몇 번째인지
is_boss: bool
connections: Array[int]   # 이 노드에서 도달 가능한 다음 노드 id 들
```

```gdscript
# MapGraph (RefCounted)
const BRANCH_COUNT: int = 2
const STEPS_PER_BRANCH: int = 4

start_id: int   # 항상 0
boss_id: int    # 항상 BRANCH_COUNT * STEPS_PER_BRANCH + 1
nodes: Array[MapNode]

func get_node(id: int) -> MapNode
func node_count() -> int
```

토폴로지는 고정이다 (id는 생성 순서로 부여):

```
0 (시작) ──┬─→ 1 → 2 → 3 → 4 ──┐
           └─→ 5 → 6 → 7 → 8 ──┴─→ 9 (보스)
```

시작 노드의 `connections`는 `[1, 5]`(각 갈래의 첫 스텝). 갈래 내부는 `i → i+1` 선형 체인. 각 갈래의 마지막 스텝(4, 8)은 `connections = [9]`. 보스는 `connections = []`.

`BRANCH_COUNT`/`STEPS_PER_BRANCH`를 상수로 뽑아둔 이유는 "약 4스텝"이 플레이해보고 조정될 값이기 때문이다(9.1 카드 수치처럼).

## 6. 맵 레이아웃 (`Scripts/map/map_layout.gd`)

`BoardLayout`/`HandLayout`과 같은 성격의 순수 계산 클래스. 노드 배치 좌표만 계산하고 그리기는 `MapView`가 한다.

```gdscript
class_name MapLayout
extends RefCounted

const STEP_SPACING: float = 120.0     # 시작에서 멀어지는 방향 간격
const BRANCH_SPACING: float = 220.0   # 두 갈래 사이 가로 간격

static func node_position(node: MapNode) -> Vector2
```

- 시작 노드: `(0, 0)`
- 갈래 `b`, 스텝 `s`: `x = (b == 0 ? -1 : 1) * BRANCH_SPACING / 2`, `y = (s + 1) * STEP_SPACING`
- 보스: `x = 0`, `y = (STEPS_PER_BRANCH + 1) * STEP_SPACING`

`y`가 커질수록 "시작에서 멀다"는 뜻이다. `MapView`가 화면에 그릴 때 이 값을 뷰포트 좌표로 변환한다(예: 시작을 화면 아래쪽에 두고 `y`를 위로 갈수록 빼는 식) — 뒤집는 책임은 표현 레이어에 둔다.

## 7. 런 상태와 인카운터 생성 (`Scripts/map/map_run_state.gd`, `encounter_generator.gd`)

### 7.1 `EncounterGenerator`

```gdscript
class_name EncounterGenerator
extends RefCounted

const STARTER_DECK_SIZE: int = 8
const ALLY_GRID: Vector2i = Vector2i(3, 3)
const ENEMY_GRID: Vector2i = Vector2i(3, 3)
const ALLY_PLACEMENTS: Array = [
	{"path": "res://Resources/units/vanguard.tres", "cell": Vector2i(0, 1)},
	{"path": "res://Resources/units/archer.tres",   "cell": Vector2i(2, 0)},
	{"path": "res://Resources/units/scout.tres",    "cell": Vector2i(1, 2)},
]
const REGULAR_ENEMY_MIN: int = 1
const REGULAR_ENEMY_MAX: int = 3
const BOSS_ENEMY_COUNT: int = 4

static func build_ally_roster(rng: RandomNumberGenerator) -> Array[UnitPlacement]
static func build_encounter(rng: RandomNumberGenerator, ally_units: Array[UnitPlacement], is_boss: bool) -> EncounterData
```

- `build_ally_roster`: 런당 **한 번** 호출된다. `ALLY_PLACEMENTS`의 각 `.tres`를 로드해 `.duplicate()`한 뒤(로드 캐시를 공유하는 원본 리소스를 직접 고치면 다른 곳에서도 값이 바뀐다) `.deck`을 `_random_deck(rng, 카드 풀)`로 덮어쓴다. 반환된 `UnitPlacement` 배열은 이 런의 모든 노드에서 **같은 객체를 그대로 재사용**한다 — 그래야 "전투마다 초기화되지만 구성은 런 내내 고정"이 성립한다.
- `build_encounter`: `ally_units`를 그대로 넣고, `enemy_units`만 매번 새로 굴린다 (`REGULAR_ENEMY_MIN~MAX` 또는 `BOSS_ENEMY_COUNT`마리를 적 풀에서 중복 허용 추출, `ENEMY_GRID`의 칸을 셔플해 겹치지 않게 배치).
- 카드 풀은 `res://Resources/cards/`, 적 풀은 `res://Resources/units/`에서 `EnemyData`인 리소스만 `DirAccess`로 스캔해 로드한다. 파일명을 하드코딩하지 않아 나중에 카드/유닛이 추가돼도 자동으로 풀에 들어간다.
- 셔플은 기존 `Unit._shuffle`과 같은 방식으로 손으로 구현한다 (`Array.shuffle()` 금지 — Global Constraints).

### 7.2 `MapRunState`

```gdscript
class_name MapRunState
extends RefCounted

var graph: MapGraph
var rng: RandomNumberGenerator
var current_node_id: int
var cleared: Dictionary        # node_id(int) -> true

func _init(p_rng: RandomNumberGenerator) -> void
func is_selectable(node_id: int) -> bool
func encounter_for(node_id: int) -> EncounterData
func resolve_win(node_id: int) -> void
func reset() -> void
```

- `_init`은 `reset()`을 호출해 첫 런을 만든다.
- `reset()`: 새 `MapGraph`를 만들고, `current_node_id = graph.start_id`, `cleared = {start_id: true}`로 되돌린 뒤 `EncounterGenerator.build_ally_roster(rng)`로 아군 로스터를 새로 뽑고, 그래프의 시작을 제외한 모든 노드에 대해 `EncounterGenerator.build_encounter(...)`를 호출해 `_encounters` 딕셔너리를 채운다. **주입된 `rng`는 새로 만들지 않고 계속 이어 쓴다** — 세션 전체가 하나의 시드로 재현 가능해야 하기 때문이다(패배해도 난수 스트림은 끊기지 않는다).
- `is_selectable(node_id)`: `node_id`가 `graph.get_node(current_node_id).connections`에 있고 아직 `cleared`에 없으면 true.
- `resolve_win(node_id)`: `is_selectable(node_id)`가 아니면 아무 것도 안 한다(방어적). 맞으면 `current_node_id = node_id`, `cleared[node_id] = true`. `node_id == graph.boss_id`면 그 자리에서 `reset()`을 호출해 새 런을 시작한다.
- 패배 시 `GameRoot`가 직접 `reset()`을 호출한다.

## 8. 화면 (`Scripts/view/map_view.gd`, `game_root.gd`)

### 8.1 `MapView`

```gdscript
class_name MapView
extends Control

signal node_selected(node_id: int)

func sync_from_state(run_state: MapRunState) -> void
func show_result(text: String) -> void
func hide_result() -> void
```

- 씬 파일 없이 `_ready()`에서 그래프 노드 수만큼 `Button`(원형처럼 보이게 `custom_minimum_size` 정사각 + 둥근 스타일박스)을 코드로 만들어 `MapLayout.node_position()` + 화면 앵커로 배치한다. 각 버튼 `pressed`는 `node_selected(id)`를 낸다.
- `_draw()`에서 그래프의 모든 간선을 `draw_line`으로 그린다(좌표는 같은 `MapLayout` 함수 재사용).
- `sync_from_state`가 매번 버튼 상태를 다시 계산한다: 현재 노드(강조색), 클리어된 노드(어둡게+비활성), 선택 가능한 노드(활성+밝은 강조), 그 외(비활성+어둡게). 보스 노드는 테두리색으로 구분.
- 상태를 신호로 밀어내지 않고 `GameRoot`가 상태 변화 후 `sync_from_state`를 호출해 당긴다 — 맵에는 전투처럼 순차 연출이 필요 없어서 이벤트 기록·재생 구조가 과하다.
- `show_result(text)`: 화면 중앙에 텍스트 배너를 띄운다(`BattleHud`의 승패 배너와 같은 성격, 코드로 만든 `Label` 하나). `hide_result()`는 숨긴다. 둘 다 노드 상태와 무관하게 즉시 반영되는 단순 표시일 뿐 — 자동 사라짐 타이머는 두지 않는다(다음 노드를 고르면 맵이 아예 가려지므로 자연히 안 보이게 된다).

### 8.2 `GameRoot` (신규 메인 씬)

```gdscript
class_name GameRoot
extends Node

const BattleScene: PackedScene = preload("res://Scenes/battle_3d.tscn")

var run_state: MapRunState
var map_view: MapView
var _battle: Node3D   # 현재 떠 있는 BattleRoot 인스턴스, 없으면 null
```

흐름:

1. `_ready()`: 시드 있는 `RandomNumberGenerator`로 `run_state = MapRunState.new(rng)` 생성. `map_view = MapView.new()`를 자식으로 붙이고 `sync_from_state(run_state)`.
2. `map_view.node_selected(id)` 수신 → `run_state.is_selectable(id)` 재확인(방어적) → `_start_battle(id)`.
3. `_start_battle(id)`: `BattleScene.instantiate()`로 `_battle` 생성 → `_battle.encounter = run_state.encounter_for(id)` (이 시점엔 아직 트리 밖이라 `_ready()`가 안 돌았으므로 안전하게 대입 가능) → `_battle.battle_finished.connect(_on_battle_finished.bind(id))` → `map_view.hide()` → `add_child(_battle)` (여기서 기존 `_ready()` 흐름이 그대로 실행되어 전투가 시작된다).
4. `_on_battle_finished(ally_won, id)`: `_battle.queue_free(); _battle = null`.
   - `ally_won`이 true 고 `id == run_state.graph.boss_id`면: `run_state.resolve_win(id)` (내부에서 바로 `reset()`까지 호출됨) 후 `map_view.show_result("런 클리어! 새 런을 시작합니다")`.
   - `ally_won`이 true 고 보스가 아니면: `run_state.resolve_win(id)` 후 `map_view.hide_result()` (일반 승리는 결과 표시 없음).
   - `ally_won`이 false 면: `run_state.reset()` 후 `map_view.show_result("패배... 런을 초기화합니다")`.
   - 마지막에 항상 `map_view.sync_from_state(run_state)` → `map_view.show()`.

`Scenes/game_root.tscn`은 `[node type="Node" script=GameRoot]` 하나뿐인 최소 씬이다 (Godot이 `run/main_scene`에 `.tscn`만 받아서 필요).

## 9. `battle_root.gd` 변경 (유일한 기존 파일 수정)

`Scripts/combat/`은 그대로 두고, `Scripts/view/battle_root.gd`에 신호 하나만 추가한다.

```gdscript
signal battle_finished(ally_won: bool)
```

`_ready()`의 `_state = BattleState.new(...)` 다음 줄에 추가:

```gdscript
_state.battle_ended.connect(func(ally_won: bool) -> void: battle_finished.emit(ally_won))
```

그 외 `_ready()`, `_run()`, 입력 처리 등 기존 흐름은 전부 그대로다. `battle_3d.tscn`의 `encounter` 기본값(스커미시)도 그대로 둔다 — `GameRoot`가 `add_child()` 전에 덮어쓰므로 맵 플로우에는 영향이 없고, 씬을 단독으로 열어 손으로 테스트할 때는 기존처럼 스커미시가 뜬다.

**구현 중 스펙과 다른 점**: `battle_root.gd`는 원래 `class_name`이 없었다. `GameRoot`가 `.encounter`/`.battle_finished`에 타입 명시로 접근하려면 이름이 필요해서 `class_name BattleRoot`를 한 줄 추가했다 — 동작 변화는 없다.

## 10. 파일 변경

**추가**

| 경로 | 책임 |
|---|---|
| `Scripts/map/map_node.gd` | 노드 1개의 구조 정보 |
| `Scripts/map/map_graph.gd` | 고정 토폴로지 생성 |
| `Scripts/map/map_layout.gd` | 노드 좌표 계산 (순수 함수) |
| `Scripts/map/encounter_generator.gd` | 아군 로스터·적 구성 랜덤 생성 |
| `Scripts/map/map_run_state.gd` | 런 진행 상태, 선택 규칙, 승패 처리 |
| `Scripts/view/map_view.gd` | 맵 화면 (원+선, 노드 클릭) |
| `Scripts/view/game_root.gd` | 맵↔전투 전환 오케스트레이션 |
| `Scenes/game_root.tscn` | 새 메인 씬 (스크립트 하나만 붙은 빈 `Node`) |
| `tests/test_map_graph.gd` | 토폴로지 검증 |
| `tests/test_map_layout.gd` | 좌표 계산 검증 |
| `tests/test_encounter_generator.gd` | 랜덤 생성 결정론·구성 검증 |
| `tests/test_map_run_state.gd` | 선택 규칙, 승패, 리셋 검증 |
| `tests/test_map_view.gd` | 버튼 상태, 클릭 신호, 결과 배너 검증 |

**수정**

| 경로 | 변경 내용 |
|---|---|
| `project.godot` | `run/main_scene` → `res://Scenes/game_root.tscn` |
| `Scripts/view/battle_root.gd` | `battle_finished(ally_won)` 신호 추가 (9장) |
| `tests/run_tests.gd` | `TEST_SCRIPTS`에 신규 테스트 5개 추가 |

**손대지 않음**: `Scripts/combat/` 전체, `Scenes/battle_3d.tscn`, `Scenes/battle_hud.tscn`, `Scripts/ui/`, `Scripts/view/`의 나머지 파일(`board_3d.gd`, `board_layout.gd`, `unit_view.gd`, `battle_playback.gd`, `battle_event*.gd`), 기존 `Resources/*`.

## 11. 테스트 전략

전부 헤드리스, `RefCounted`만 생성해 검증한다 (표현 레이어는 `MapView`의 버튼 상태 정도만 트리에 붙여서 확인).

1. **`MapGraph`** — 노드 총 10개, 시작의 `connections`가 두 갈래 첫 스텝, 갈래 내부가 선형 체인, 양 갈래 마지막이 보스로 모임, `BRANCH_COUNT`/`STEPS_PER_BRANCH`를 바꿔도 공식이 일반화되는지(예: 3갈래 3스텝으로 바꿔 재검증)
2. **`MapLayout`** — 두 갈래가 좌우 대칭, 스텝이 커질수록 시작에서 멀어짐, 보스가 두 갈래보다 더 멀리 있고 가운데 정렬
3. **`EncounterGenerator`**
   - 같은 시드 → 같은 덱 구성, 같은 적 구성 (결정론)
   - 아군 로스터가 3기, `ALLY_PLACEMENTS`와 같은 셀, 그리드 3×3
   - 일반 노드 적 수가 1~3 범위, 보스 노드는 4
   - 적이 전부 `EnemyData` 풀에서만 나옴 (아군 유닛이 섞이지 않음)
   - 배치된 칸이 서로 겹치지 않음
   - 원본 `.tres`를 두 번 로드해도 `deck`이 오염되지 않음 (duplicate 검증)
4. **`MapRunState`**
   - 시작 노드에서 두 갈래 첫 스텝만 선택 가능, 나머지는 불가
   - 한쪽 갈래에 진입하면 반대쪽 갈래는 더 이상 선택 불가 (연결이 끊겨 있으므로 자연히 성립 — 이걸 명시적으로 확인)
   - `resolve_win`이 `current_node_id` 갱신과 `cleared` 반영을 함께 하는지
   - 보스 클리어 시 `reset()`이 불려 그래프와 인카운터가 갈리는지 (새 `MapGraph` 인스턴스, `current_node_id`가 다시 시작으로)
   - 같은 시드로 두 번 실행한 결과가 같음 (전체 결정론)
5. **`MapView`** (트리에 붙여서 확인)
   - 노드 수만큼 버튼 생성, `node_selected`가 클릭한 id를 낸다
   - `sync_from_state` 후 선택 가능한 노드만 활성, 나머지는 비활성
   - `show_result("텍스트")` 후 배너 표시·텍스트 일치, `hide_result()` 후 숨김

`tests/run_tests.gd`의 `TEST_SCRIPTS`에 이 5개를 추가한다. `GameRoot`의 씬 전환·`BattleRoot` 배선은 기존 `battle_root.gd`처럼 실행 검증(수동 플레이)으로 확인하고, 별도 헤드리스 테스트는 만들지 않는다 — `BattleRoot` 재사용 없이 매번 새로 인스턴스하는 구조라 통합 지점이 단순해서 그럴 가치가 적다.

## 12. 미결정 사항

- 정확한 스텝 수(4)와 갈래 수(2), 덱 크기(8장), 적 마릿수 범위(1~3, 보스 4)는 전부 플레이해보고 조정할 출발값이다.
- 노드 타입이 전투 하나뿐이라 `MapNode`에 타입 필드를 아직 안 뒀다. 상점/휴식/이벤트가 들어오는 다음 이터레이션에서 `NodeKind` enum이 필요해진다.
- 보스 클리어·패배 결과 표시는 `MapView.show_result()` 텍스트 배너 수준이다(8.1, 8.2 참조). 연출(페이드, 소리 등)은 다음 이터레이션.
