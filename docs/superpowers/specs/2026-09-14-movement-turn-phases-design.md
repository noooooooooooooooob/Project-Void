# 이동과 턴 단계 설계

- 작성일: 2026-09-14
- 대상: 전투 규칙(차례 진행, 이동, 적 AI)과 전투 화면(이동 입력·연출)
- 상태: 승인됨 (구현 진행)
- 선행 문서: `2026-09-12-combat-prototype-design.md`, `2026-09-13-battle-2-5d-design.md`, `2026-09-13-card-presentation-design.md`
- 기획: Notion 상세설계 > 전투 프로토타입 확정 규칙 (2026-09-12) > 이동과 턴 단계 (2026-09-14 확정)

## 1. 배경

지금 유닛은 전투 내내 제자리에 서 있고, 한 차례는 "block 초기화 → (아군) SP 회복·드로우 → 행동 → 손패 버리기" 가 한 함수 안에서 이어진다. 2026-09-14 기획에서 이동과 턴 단계가 확정됐다. 이 문서는 그 규칙을 코드에 넣는 설계다.

## 2. 확정 사항 (2026-09-14 사용자 결정)

| 항목 | 결정 |
|---|---|
| 아군 이동 | SP 1 로 한 칸. 자기 진영 안, 상하좌우만, 살아 있는 유닛이 있는 칸은 불가, SP 가 남는 한 반복 |
| 적 이동 | 행동 하나로 취급 (SP 없음). 차례에 공격 / 방어 / 휴식 / 이동 중 하나 |
| 적 이동 선택 | 차례마다 먼저 `move_chance`(기본 25%) 확률 판정. 성공하면 이동, 갈 칸이 없으면 공격·방어·휴식 중 무작위. 실패하면 기존 휴식 → 방어 → 공격 규칙 |
| 턴 단계 | 아군·적 모두 스탠바이 → 드로우 → 턴 행동 → 종료 전 → 종료 후 |
| 단계별 처리 | 스탠바이: block 0, SP 전량 회복 / 드로우: 아군 4장 (적은 단계만 있고 드로우 없음) / 종료 후: 손패 버리기 |
| 상태이상·패시브 | 종류마다 발동 단계가 다르다 (이번 범위에는 없음) |
| 이동 조작 | 카드를 고르지 않은 상태에서 이동 가능한 빈 칸을 클릭 |
| 단계 표시 | 화면에 표시하지 않는다 (규칙 구조와 신호만) |
| 구조 | `BattleState` 에 단계 enum + `phase_started` 신호 |

기각한 구조: 단계를 함수로만 나누는 안 — 단계 순서를 테스트할 수 없고 상태이상을 붙일 자리가 없다. 밖에서 `advance_phase()` 로 단계를 넘기는 상태 머신 — 플레이어가 단계를 직접 넘길 일이 없어 과하다.

## 3. 범위

### 포함

- 턴 단계 enum, 현재 단계, `phase_started` 신호, 단계 순서에 맞춘 차례 진행
- 아군 이동 규칙 (`move_unit`), 이동 가능 칸 계산
- 적 이동 행동, 확률 판정, 막혔을 때 무작위 대체 행동, 적 전용 난수
- 이동 이벤트 기록·재생, 유닛 미끄러짐 연출
- 이동 가능 칸 표시(타일 빛)와 클릭 이동

### 제외

단계 화면 표시, 상태이상·패시브, 이동 카드, 이동 되돌리기, 경로 미리보기(두 칸 이상), 적 AI 의 목적 있는 이동, 키보드 조작.

## 4. 규칙 레이어 변경

### 4.1 턴 단계 (`BattleState`)

```gdscript
enum Phase { STANDBY, DRAW, ACTION, BEFORE_END, AFTER_END }
signal phase_started(unit: Unit, phase: Phase)
var phase: Phase = Phase.STANDBY
```

`phase_started` 는 단계 값을 바꾼 직후, 그 단계의 처리보다 먼저 나간다.

차례 시작 (`_run_until_player_input` 이 살아 있는 다음 유닛을 찾은 뒤):

1. `STANDBY` — `block = 0`, 아군이면 `sp = max_sp`
2. `turn_started(unit)` — 기존 신호. 초기화된 block 이 기록되도록 스탠바이 처리 뒤에 둔다
3. `DRAW` — 아군이면 `DRAW_PER_TURN` 장 드로우, 적은 아무것도 하지 않는다
4. `ACTION` — 아군이면 여기서 멈추고 입력을 기다린다. 적이면 `EnemyBrain.take_turn` 후 `check_end()`
5. 적이고 전투가 끝나지 않았으면 `BEFORE_END` → `AFTER_END` 를 지나 다음 유닛

`end_turn()` (지금 차례가 아군일 때): `BEFORE_END` → `AFTER_END` 에서 `_discard_hand` → 다음 아군 차례까지 진행. 전투가 턴 행동 중에 끝나면 남은 단계는 진행하지 않는다 (루프가 `finished` 에서 멈추고, 끝난 전투에서는 `BattleRoot` 가 `end_turn` 을 부르지 않는다).

신호 순서 예 (아군 a 가 먼저, 적 e):

```
start_battle: phase(a,STANDBY) turn(a) phase(a,DRAW) drawn×N phase(a,ACTION)
end_turn:     phase(a,BEFORE_END) phase(a,AFTER_END) discarded
              phase(e,STANDBY) turn(e) phase(e,DRAW) phase(e,ACTION) acted(e)… phase(e,BEFORE_END) phase(e,AFTER_END)
              phase(a,STANDBY) …
```

### 4.2 이동 가능 칸 (`TargetResolver`)

```gdscript
func movable_cells(unit: Unit, all_units: Array[Unit]) -> Array[Vector2i]
```

- 후보 순서는 위 `(0,-1)`, 아래 `(0,1)`, 앞 `(-1,0)`, 뒤 `(1,0)` — 무작위 선택이 시드마다 재현되도록 고정한다
- 자기 편 격자 범위 `0 ≤ x < grid.x`, `0 ≤ y < grid.y` 안
- 그 칸에 **살아 있는** 유닛이 없어야 한다 (쓰러진 유닛의 칸은 빈 칸)

### 4.3 이동 (`BattleState`)

```gdscript
signal unit_moved(unit: Unit, from_cell: Vector2i, to_cell: Vector2i)
func move_unit(to_cell: Vector2i) -> bool        # 지금 차례 아군이 SP 1 로 한 칸 이동
func apply_move(unit: Unit, to_cell: Vector2i) -> void   # 검사 없이 옮기고 알리는 통로 (EnemyBrain 도 사용)
```

`move_unit` 은 전투 진행 중, 지금 차례가 살아 있는 아군, `sp >= 1`, `to_cell` 이 `movable_cells` 에 있을 때만 `sp -= 1` 후 `apply_move` 를 부르고 true. 아니면 아무것도 바꾸지 않고 false. 차례 단계는 확인하지 않는다 (아군 차례에 멈추는 곳이 `ACTION` 뿐이다).

`apply_move` 는 `cell` 을 바꾸고 `unit_moved` → `write_log("%s 이동")` 순으로 알린다.

거리·막힘은 `cell` 을 그대로 읽으므로 이동 직후 사거리 판정이 바뀐다. 추가 작업은 없다.

### 4.4 적 이동 (`EnemyData`, `EnemyBrain`)

```gdscript
# EnemyData
@export var move_chance: float = 0.25
# EnemyBrain
enum Action { ATTACK, DEFEND, REST, MOVE }   # MOVE 는 끝에 추가
```

`decide(state, actor)`:

1. `move_chance > 0` 이면 `state.ai_rng.randf() < move_chance` 판정 (0 이면 난수를 쓰지 않는다)
2. 성공: `movable_cells` 가 비어 있지 않으면 `MOVE`. 비어 있으면 후보 `[ATTACK(칠 대상이 있을 때만), DEFEND, REST]` 중 `ai_rng.randi_range` 로 하나
3. 실패: 기존 규칙 (HP 30% 이하이고 회복량이 있으면 휴식 → 대상이 없으면 방어 → 공격)

`take_turn` 의 `MOVE`: `movable_cells` 중 `ai_rng` 로 한 칸을 고르고 `report_enemy_action(actor, MOVE, null)` → `apply_move`. 칸이 없으면 아무것도 하지 않는다 (안전장치).

### 4.5 적 전용 난수 (`BattleState`)

```gdscript
var ai_rng: RandomNumberGenerator   # _init 에서 새로 만들고 seed = hash([rng.seed, "enemy_ai"])
```

적 AI 는 `ai_rng` 만 쓴다. 덱 섞기는 계속 `rng` 를 써서, 적이 난수를 몇 번 쓰든 카드 순서가 바뀌지 않는다. 시드가 같으면 적 행동도 같다. `ai_rng` 의 시드는 전투 시드에서 따로 뽑아, 적 AI 가 덱 섞기와 같은 난수 수열을 되풀이하지 않게 한다.

기존 테스트가 만드는 적은 `move_chance = 0` 으로 두어 지금의 결정론적 기대값을 유지한다. `Resources/units/*.tres` 는 값을 쓰지 않으므로 기본 25% 가 적용된다.

## 5. 이벤트 모델 변경

- `BattleEvent.Kind` 끝에 `UNIT_MOVED`, 필드 `from_cell: Vector2i`, `to_cell: Vector2i`
- `BattleEventRecorder` 가 `unit_moved` 를 기록한다. `phase_started` 는 기록하지 않는다 (화면에 표시하지 않음)
- 발생 순서: 아군 이동 `UNIT_MOVED → LOG`, 적 이동 `ENEMY_ACTED(MOVE) → UNIT_MOVED → LOG`
- `TURN_STARTED`·`DIED` 는 기록 시점의 `cell` 을 복사한다 (재생 때 규칙의 칸은 이미 이동 뒤일 수 있다)

## 6. 화면 변경

### 6.1 `UnitView`

```gdscript
const MOVE_TIME: float = 0.25
func slide_to(world_position: Vector3) -> void   # home_position 을 바꾸고 MOVE_TIME 동안 미끄러진다. await 가능
```

### 6.2 `Board3D`

- `TileState` 끝에 `MOVABLE` — 편 색 + `MOVE_EMISSION = Color(0.45, 0.65, 1.0)` 빛 (세기 0.6)
- `show_move_hints(team, cells)` — 이전 힌트를 지우고 칸들을 `MOVABLE` 로
- `clear_target_hints()` — 사거리 힌트(`VALID`/`INVALID`)는 `BASE`, 이동 힌트(`MOVABLE`)는 `EMPTY` 로 되돌린다
- `move_view(unit, from_cell, to_cell, animate)` — 원래 칸 `EMPTY`, 새 칸 `CURRENT`, 유닛 클릭 몸체의 칸 메타 갱신, `animate` 면 `await slide_to`, 아니면 `set_home`
- `sync_from_state` — 유닛 화면을 규칙의 현재 칸 위치로 옮기고(`set_home`) 클릭 몸체 칸 메타를 다시 붙인다 (연출이 어긋나도 실제 상태로 맞춘다)
- `show_current(team, cell)`, `mark_empty(team, cell)` — 유닛 대신 편·칸을 받는다 (재생은 이벤트의 기록 칸을 넘긴다)

### 6.3 `BattleHud`

- `apply_move(event)` — 아군이면 손패 SP 흐림(`set_sp`)과 SP 패널을 갱신한다. 새 표시는 없다

### 6.4 `BattlePlayback`

- `UNIT_MOVED` → `hud.apply_move(event)` 후 `await board.move_view(unit, from, to, not instant)`
- `ENEMY_ACTED` 의 `MOVE` 는 제자리 뛰기를 하지 않는다 (이동은 뒤따르는 `UNIT_MOVED` 가 보여준다)

### 6.5 `BattleRoot` 입력

- 힌트는 `_refresh_hints()` 한 곳에서 정한다
  - 카드 선택 중 → 기존 사거리 힌트
  - 선택 없음 + 입력 가능(`not _busy`) + 전투 진행 중 + 지금 차례가 아군 + `sp >= 1` → `show_move_hints(아군, movable_cells)`
  - 그 외 → `clear_target_hints()`
- 부르는 곳: 카드 선택 변경, `_clear_selection()`, `_run` 이 동기화하고 잠금을 푼 뒤
- `cell_clicked`: 잠금 중이면 무시. 카드 선택이 없고 드래그 놓기가 아니며 아군 칸이면, 그 칸이 `movable_cells` 에 있을 때 `_run(move_unit)`. 그 밖의 선택 없는 클릭은 무시. 카드 선택 중 동작은 지금과 같다

## 7. 재생 시간

| 이벤트 | 대기 |
|---|---|
| `UNIT_MOVED` | `UnitView.MOVE_TIME` (0.25초) 미끄러짐이 끝날 때까지 |
| `ENEMY_ACTED(MOVE)` | 없음 |

## 8. 테스트와 검증

### 8.1 헤드리스 단위 테스트

- `TargetResolver.movable_cells`: 가운데(4칸), 모서리(2칸), 살아 있는 유닛 칸 제외, 쓰러진 유닛 칸 포함, 대각선 없음, 격자 크기가 다른 편
- `move_unit`: 성공 시 SP −1·칸 변경·`unit_moved`·로그, 거절(SP 0, 대각선, 두 칸, 점유 칸, 진영 밖, 적 차례, 끝난 전투)에서 변화 없음, SP 가 남는 동안 연속 이동
- 턴 단계: 아군 시작·`end_turn`·적 차례의 신호 순서 (4.1 예), 스탠바이 신호 시점엔 이전 block·SP 이고 `turn_started` 시점엔 초기화된 값, 적 드로우 단계에 `card_drawn` 없음, `hand_discarded` 가 `AFTER_END` 뒤
- `EnemyBrain`: `move_chance = 1` 이고 칸이 있으면 `MOVE` 와 이동 결과, 막혔으면 공격·방어·휴식 중 하나(대상 없으면 공격 제외), `move_chance = 0` 이면 기존 결과, 같은 시드 같은 결과, 적 이동 여부와 무관하게 아군 손패가 같다(`ai_rng` 분리)
- 기록기: `UNIT_MOVED` 필드와 아군/적 이동 이벤트 순서
- `Board3D`: `move_view` 후 위치·타일 상태·클릭 칸 메타, `show_move_hints`/`clear_target_hints`, `sync_from_state` 가 칸 위치로 맞춤
- `BattlePlayback`: `UNIT_MOVED` 즉시 반영, 아군 이동 뒤 HUD SP
- 기존 테스트의 적 데이터는 `move_chance = 0`

### 8.2 실행 검증 (창 모드, 컨트롤러)

- 첫 아군 차례에 이동 가능한 빈 칸이 파랗게 빛나고, 카드를 고르면 사거리 힌트로 바뀌고, 선택을 풀면 돌아온다
- 빈 칸 클릭 → 유닛이 미끄러지고 SP 가 1 줄고 로그 "○○ 이동", 새 칸 기준으로 힌트·사거리가 바뀐다
- SP 0 이면 이동 힌트가 사라진다
- 적 차례에 적이 이동하는 모습 (확률이라 여러 라운드 관찰)
- godot.log 에 ERROR 없음

## 9. 후속 작업

- 단계 화면 표시, 상태이상·패시브의 단계별 발동
- 적 AI 의 목적 있는 이동 (사거리 확보, 후퇴)
- 이동 경로 미리보기, 이동 취소
