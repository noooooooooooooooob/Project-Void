# 전투 화면 2.5D 전환 설계

- 작성일: 2026-09-13
- 대상: 전투 프로토타입의 표현 레이어
- 상태: 승인 대기
- 선행 문서: `2026-09-12-combat-prototype-design.md`
- 구현 계획: `docs/superpowers/plans/2026-09-13-battle-2-5d.md` — 계획 단계에서 `unit_view.tscn` 을 코드 생성으로, HUD 를 별도 씬으로 바꾸는 등 조정한 내용은 계획의 "스펙과 다른 점" 표에 있다

## 1. 배경

전투 규칙은 헤드리스 테스트 123개로 덮인 상태로 완성됐고, 화면은 버튼 그리드로 된 최소 2D UI다. 기획서(Notion 기획하기 > 개발 레퍼런스 (2.5D))의 결론은 "진영 타일(3D) 위에 Sprite3D + Billboard 로 2D 캐릭터를 배치"이고, 그래픽 파이프라인은 Aseprite 초안 → ComfyUI 스프라이트시트 → 보정이다.

이 문서는 규칙 레이어를 그대로 두고 전투 화면을 그 방식의 2.5D 로 다시 만드는 설계다.

## 2. 확정 사항 (2026-09-13 사용자 결정)

| 항목 | 결정 |
|---|---|
| 범위 | 기존 전투 화면만 2.5D 로 전환. 규칙 판정은 바꾸지 않는다 |
| 캐릭터 그림 | 임시 실루엣 스프라이트로 구조 먼저. 실제 아트는 별도 작업 |
| 카메라 | 전장 앞쪽 위에서 내려다보는 고정 원근 카메라 (설계 35°, 실행 확인 후 44°) |
| 연출 | 행동을 하나씩 순차 재생, 재생 중 입력 잠금 |
| 구조 | 규칙은 동기 처리 그대로, 표현 쪽이 신호를 이벤트로 기록했다가 재생 |

기각한 구조: (2) 규칙을 비동기로 바꿔 연출 완료를 기다리게 하는 안 — 규칙이 화면 타이밍에 묶이고 동기 테스트가 흔들린다. (3) 처리 전후 상태만 비교해 연출하는 안 — 누가 누구를 때렸는지와 순서를 알 수 없다.

## 3. 범위

### 포함

- 3D 진영 타일, 고정 카메라, 조명
- 빌보드 유닛 표현 (임시 실루엣, 이름, HP 바, 방어도)
- 이벤트 기록·순차 재생과 입력 잠금
- 공격 돌진, 피격 번쩍임·흔들림, 떠오르는 숫자, 사망 페이드, 승패 배너
- 타일 위 타겟 가능 여부 표시와 이유 글자 (현재 2D 의 사거리 표시를 옮김)
- 레이캐스트 클릭 판정 (타일, 유닛 몸통)
- HUD: 행동 순서 바, SP, 손패(근접/원거리 표시 포함), 차례 종료, 자동 스크롤 로그
- 규칙 레이어에 신호 추가

### 제외

실제 캐릭터 아트, 스프라이트시트 애니메이션 프레임, 방향별 빌보드 셰이더, 카메라 이동·회전, 사운드, 파티클 VFX, 호버 강조, 연출 건너뛰기.

## 4. 아키텍처

```
규칙 레이어 (Scripts/combat/)           ← 신호 4종만 추가, 판정 불변
   │ 신호 (동기)
   ▼
BattleEventRecorder ── 이벤트 큐 (스냅샷 포함)
   │
   ▼
BattleRoot (입력 잠금, 전체 동기화) ──► BattlePlayback ──► Board3D / UnitView / BattleHud
   ▲                                                           │
   └──────────── cell_clicked / 카드 선택 / 차례 종료 ◄─────────┘
```

규칙 레이어는 표현을 전혀 모른다. 표현은 규칙 상태를 **읽기만** 하고, 변경은 `play_card()` / `end_turn()` / `start_battle()` 호출로만 한다.

### 4.1 파일 구성

| 파일 | 역할 |
|---|---|
| `Scripts/view/battle_event.gd` | `class_name BattleEvent`. 이벤트 1건 (6장) |
| `Scripts/view/battle_event_recorder.gd` | `class_name BattleEventRecorder`. 규칙 신호 → 이벤트 큐 |
| `Scripts/view/battle_playback.gd` | `class_name BattlePlayback`. 큐를 순서대로 재생, 끝나면 `finished` |
| `Scripts/view/board_layout.gd` | `class_name BoardLayout`. 칸 → 월드 좌표 계산 (순수 함수) |
| `Scripts/view/board_3d.gd` | `class_name Board3D`. 타일·유닛 뷰 생성, 강조 상태, 레이캐스트 클릭 |
| `Scripts/view/unit_view.gd` + `Scenes/unit_view.tscn` | `class_name UnitView`. 빌보드 스프라이트, 머리 위 표시, 연출 동작 |
| `Scripts/ui/battle_hud.gd` | `class_name BattleHud`. 순서 바, SP, 손패, 차례 종료, 로그, 배너 |
| `Scripts/view/battle_root.gd` + `Scenes/battle_3d.tscn` | 전체 연결, 입력 잠금, 타겟 힌트 계산 |
| `tools/generate_placeholder_sprite.gd` | 임시 실루엣 PNG 생성 |

## 5. 규칙 레이어 변경

### 5.1 추가 신호 (`BattleState`)

```gdscript
signal card_played(actor: Unit, card: CardData, primary: Unit)
signal enemy_acted(actor: Unit, action: EnemyBrain.Action, target: Unit)  # 방어/휴식이면 target = null
signal unit_healed(unit: Unit, amount: int)    # 실제 회복된 양 (최대치 초과분 제외)
signal block_gained(unit: Unit, amount: int)
```

### 5.2 발생 순서

- `play_card()`: SP 차감·손패 이동 후 `card_played` → 기존 로그 → 대상별 `unit_damaged` (/ `unit_died`)
- `EnemyBrain.take_turn()`: 행동 결정 후 `enemy_acted` → 행동 적용
  - 공격: 대상별 `unit_damaged` (/ `unit_died`)
  - 방어: `block_gained`
  - 휴식: `unit_healed`

### 5.3 통로 정리

지금 `EnemyBrain` 은 `actor.heal()` / `actor.gain_block()` 을 직접 부른다. `BattleState.apply_heal(unit, amount)` / `apply_block(unit, amount)` 를 추가해 `apply_damage` 와 같은 방식으로 신호를 내보내고, `EnemyBrain` 은 이것만 쓴다. `enemy_acted` 도 `BattleState.report_enemy_action(actor, action, target)` 를 통해 내보낸다. 기존 원칙("시그널을 밖에서 직접 emit 하지 않도록 통로를 하나로 둔다")을 따른다.

회복·방어·피해 수치와 판정 로직은 그대로다.

## 6. 이벤트 모델

`BattleEvent` 는 `kind` 와 종류별 필드를 가진다. 유닛 수치는 **신호가 발생한 순간의 값**을 복사해 둔다. 규칙은 동기로 끝까지 진행하므로, 재생 시점에 규칙 상태를 읽으면 이미 최종값이기 때문이다.

| kind | 필드 | 발생 신호 |
|---|---|---|
| `TURN_STARTED` | unit, round_index, order(Array[Unit]), alive(Array[bool]), turn_index, block | `turn_started` |
| `CARD_PLAYED` | actor, card, primary | `card_played` |
| `ENEMY_ACTED` | actor, action, target | `enemy_acted` |
| `DAMAGED` | unit, amount, hp, block | `unit_damaged` |
| `HEALED` | unit, amount, hp | `unit_healed` |
| `BLOCK_GAINED` | unit, amount, block | `block_gained` |
| `DIED` | unit | `unit_died` |
| `LOG` | text | `log_message` |
| `BATTLE_ENDED` | ally_won | `battle_ended` |

`TURN_STARTED` 의 순서 바 정보는 `state.initiative` 복사본과 각 유닛의 생존 여부, `turn_index` 다.

`BattleEventRecorder` 는 생성 시 `BattleState` 의 신호에 연결하고 `take_events() -> Array[BattleEvent]` 로 쌓인 이벤트를 넘기며 비운다.

## 7. 재생

### 7.1 흐름

1. `BattleRoot` 가 규칙 호출(`start_battle` / `play_card` / `end_turn`) 직전에 입력을 잠근다.
2. 호출이 끝나면 `recorder.take_events()` 를 `BattlePlayback.play(events)` 에 넘기고 `finished` 를 기다린다.
3. 끝나면 `Board3D.sync_from_state(state)` 와 `BattleHud.sync_from_state(state)` 로 **실제 규칙 상태로 전체 동기화**한다. 연출 중 표시값이 어긋났더라도 여기서 바로잡힌다.
4. 전투가 끝나지 않았으면 입력을 푼다.

`play_card()` 가 `false` 를 반환하면(무효 대상) 이벤트가 없으므로 로그에 "사용할 수 없는 대상" 만 남기고 잠금을 푼다.

### 7.2 종류별 연출

| kind | 연출 | 대기 |
|---|---|---|
| `TURN_STARTED` | 현재 차례 타일 강조 이동, 순서 바 갱신, 해당 유닛 방어도 표시 갱신, 로그 "― X 차례" | 적 0.2s / 아군 0s |
| `CARD_PLAYED` | 공격자 머리 위에 카드 이름 표시, 대상 쪽으로 0.4m 돌진 후 복귀 | 0.25s |
| `ENEMY_ACTED` | 공격이면 돌진 후 복귀, 방어·휴식이면 제자리 튀기 | 0.25s |
| `DAMAGED` | 흰색 번쩍임 2회 + 좌우 흔들림, `-amount` 숫자가 0.6m 떠오르며 사라짐, HP 바를 hp 로, 방어도 갱신, 로그 "X 에게 N 피해" | 0.5s |
| `HEALED` | 초록 `+amount`, HP 바 갱신 | 0.4s |
| `BLOCK_GAINED` | 파랑 `+amount 방어`, 방어도 갱신 | 0.4s |
| `DIED` | 스프라이트·머리 위 표시 페이드아웃, 클릭 판정 끔, 타일을 빈 칸 색으로 | 0.4s |
| `LOG` | HUD 로그에 한 줄 추가 | 0s |
| `BATTLE_ENDED` | 화면 중앙 배너 "승리!" / "패배..." | — |

피해 숫자는 로그와 같은 원시 피해량이다. 방어도에 흡수된 부분은 HP 바와 방어도 표시로 드러난다.

### 7.3 입력 잠금

잠금 중에는 손패 버튼과 "차례 종료" 가 비활성이고, `Board3D` 는 클릭을 무시한다. 카드 선택 상태는 잠글 때 해제한다.

## 8. 3D 배치

### 8.1 좌표 (`BoardLayout`)

바닥은 XZ 평면, 위쪽이 +Y, 카메라는 +Z 쪽에 있다.

```
TILE_SIZE    = 1.0     # 타일 한 변
CELL_PITCH   = 1.1     # 칸 간격 (타일 + 틈)
SIDE_GAP     = 1.5     # 두 진영 col 0 칸 경계(CELL_PITCH 기준) 사이 거리

x(team, col) = sign × (SIDE_GAP / 2 + CELL_PITCH / 2 + col × CELL_PITCH)
               sign = -1 (아군), +1 (적군)
z(row, rows) = TargetResolver.center_offset(row, rows) × CELL_PITCH
```

- col 0 이 가운데 간격에 가장 가깝다 (규칙의 "col 0 = 최전열" 과 일치)
- row 0 이 화면 안쪽(-Z, 먼 쪽), 행 번호가 커질수록 카메라 쪽
- 중앙 정렬 공식을 규칙과 같은 함수로 써서, 행 수 홀짝이 다른 진영이 반 칸 어긋나 놓이는 모습이 규칙과 그대로 일치한다

### 8.2 카메라

- `Camera3D` 원근, 세로 FOV 40°, 피치 -44° (설계값 -35°. 실행 확인에서 보드와 머리 위 표시가 잘리고 같은 열 앞뒤 유닛이 겹쳐 조정, 2026-09-13)
- 바라보는 점: 보드 중심 + (0, 0, 0.6) — 아래쪽 HUD 에 보드가 가리지 않게 약간 앞으로 당긴다
- 거리: 보드 가로 폭 × 1.8 가 가로 시야에, 보드 깊이 × 1.8 가 세로 시야에 들어가는 거리 중 큰 값 (설계값 1.2 에서 같은 이유로 조정. 이 계산은 피치에 따른 원근 축소와 유닛 높이를 반영하지 않아 1.8 은 3×3 / 2×2 조우 기준이다)
- 뷰포트 크기가 바뀌면 다시 계산한다
- 상수는 실행 확인 단계에서 조정할 수 있는 출발값이다

### 8.3 조명과 배경

`DirectionalLight3D` 1개 (그림자 없음), `WorldEnvironment` 단색 배경 + 주변광.

## 9. 보드와 타일

### 9.1 타일

`Board3D` 가 인카운터 그리드 크기대로 칸마다 얇은 박스 메시(1.0 × 0.1 × 1.0)와 `StaticBody3D` + `BoxShape3D` 를 만든다. 유닛이 없는 칸도 타일은 있다.

| 상태 | 표현 |
|---|---|
| 기본 | 아군 청회색 / 적군 적회색 |
| 빈 칸 | 기본색보다 어둡게 |
| 현재 차례 | 노란 발광 |
| 타겟 가능 | 초록 발광 |
| 타겟 불가 | 어둡게 |

### 9.2 타겟 힌트

카드가 선택돼 있고 잠금이 아닐 때, 살아 있는 적이 있는 칸마다 `BattleRoot` 가 아래를 계산해 `Board3D.show_target_hints(hints)` 로 넘긴다. 판정은 현재 2D 화면과 같다.

- 유효 여부: `resolver.is_valid_target(actor, target, card.attack_type, card.attack_range, units)` — `play_card` 와 같은 함수
- 이유 글자: 유효하면 `✓ 거리 N`, 사거리 밖이면 `거리 N`, 사거리 안인데 무효면 `막힘`

글자는 그 칸 유닛의 머리 위(이름표보다 위, y = OVERHEAD_Y + 0.6)에 빌보드 `Label3D` 로 띄운다. 처음 설계한 "타일 앞 가장자리" 는 앞 행 유닛의 클릭 판정 박스에 가려져, 뒤 유닛의 힌트 글자를 누르면 앞 유닛이 공격당하는 문제가 있어 옮겼다 (2026-09-13 최종 리뷰).

### 9.3 클릭 판정

- `Board3D._unhandled_input` 에서 왼쪽 버튼 **뗄 때** 카메라 레이캐스트 (`PhysicsDirectSpaceState3D.intersect_ray`, 길이 100m, 충돌 레이어 2 = 보드 픽 전용)
- 타일 바디와 유닛 몸통 바디 모두 `(team, cell)` 을 메타데이터로 가진다. 어느 쪽에 맞아도 같은 칸으로 처리해 `cell_clicked(team, cell)` 을 보낸다
- HUD `Control` 이 받은 클릭은 `_unhandled_input` 까지 오지 않으므로 보드로 새지 않는다
- 죽은 유닛의 몸통 바디는 충돌을 끈다

## 10. 유닛 표현 (`UnitView`)

`Scenes/unit_view.tscn` 구성:

| 노드 | 내용 |
|---|---|
| `Sprite` (Sprite3D) | Y축 고정 빌보드, alpha scissor, 비조명(unshaded), 높이 약 1.6m, 진영 색으로 modulate |
| `Shadow` (MeshInstance3D) | 발밑 원형 그림자 판 (방사형 그라데이션 텍스처) |
| `Overhead` (Node3D) | `NameLabel` (Label3D), HP 바 (빌보드 사각형 2장: 배경 / 채움, 채움은 비율만큼 가로 스케일), `StatLabel` (Label3D, `28/28  방6`) |
| `PickBody` (StaticBody3D) | 스프라이트 크기 박스 충돌 |

- 스프라이트: `UnitData` 에 `@export var sprite: Texture2D` 를 추가한다. 지정돼 있으면 그 텍스처, 비어 있으면 `Resources/sprites/placeholder_unit.png`
- 임시 실루엣: `tools/generate_placeholder_sprite.gd` 가 흰색 실루엣(원형 머리 + 둥근 몸통, 투명 배경) PNG 를 만든다. 아군 `Color(0.55, 0.75, 1.0)`, 적군 `Color(1.0, 0.55, 0.5)` 로 칠한다
- 번쩍임은 modulate 를 순간적으로 `Color(2, 2, 2)` 로 올렸다 되돌린다
- 떠오르는 숫자는 재생 중 `Label3D` 를 생성해 트윈 후 해제한다

공개 메서드 (재생기가 사용, 전부 `await` 가능):

```gdscript
func setup(unit: Unit, texture: Texture2D) -> void
func set_stats(hp: int, max_hp: int, block: int) -> void
func lunge_toward(world_target: Vector3) -> void
func hop() -> void
func flash_and_shake() -> void
func pop_text(text: String, color: Color) -> void
func fade_out() -> void
```

## 11. HUD (`BattleHud`)

`battle_3d.tscn` 의 `CanvasLayer` 아래 `Control` 에 붙는다. 현재 `battle_controller.gd` 의 손패·SP·순서 바 로직을 옮긴다.

| 위치 | 요소 |
|---|---|
| 위 | 행동 순서 바 (`RichTextLabel`, 행동함 회색 / 현재 강조) |
| 아래 | SP 패널, 손패 (근접 붉은 / 원거리 푸른 테두리, `[근접]`/`[원거리]`, 사거리), 차례 종료 |
| 왼쪽 아래 | 반투명 로그 패널, `scroll_following = true` |
| 중앙 | 승패 배너 (평소 숨김) |

신호: `card_selected(index: int)` (-1 = 해제), `end_turn_pressed`.
메서드: `show_turn(event: BattleEvent)`, `append_log(text)`, `set_interactive(enabled)`, `show_banner(ally_won)`, `sync_from_state(state, selected_card)`.

## 12. 파일 변경

- **추가**: 4.1 표의 파일 전부, `Scenes/battle_3d.tscn`, `Scenes/unit_view.tscn`, `Resources/sprites/placeholder_unit.png`, `tests/test_battle_signals.gd`, `tests/test_event_recorder.gd`, `tests/test_board_layout.gd`
- **수정**: `Scripts/combat/battle_state.gd`, `Scripts/combat/enemy_brain.gd`, `Scripts/combat/data/unit_data.gd`, `project.godot` (메인 씬 → `battle_3d.tscn`), `tests/run_tests.gd` (새 테스트 등록)
- **삭제**: `Scenes/battle.tscn`, `Scripts/ui/battle_controller.gd`

## 13. 테스트와 검증

### 13.1 헤드리스 단위 테스트

- `test_battle_signals.gd`
  - `play_card` 에서 `card_played` 가 첫 `unit_damaged` 보다 먼저 온다
  - 적 공격: `enemy_acted(ATTACK, target)` 가 `unit_damaged` 보다 먼저 온다
  - 적 방어: `enemy_acted(DEFEND, null)` 다음 `block_gained(block_amount)`
  - 적 휴식: `enemy_acted(REST, null)` 다음 `unit_healed` — 최대 HP 에 막히면 실제 회복량
- `test_event_recorder.gd`
  - `end_turn` 한 번에 적 둘이 같은 아군을 공격할 때 이벤트 순서가 `TURN_STARTED → ENEMY_ACTED → DAMAGED → … → TURN_STARTED(다음 아군)`
  - 연속 `DAMAGED` 의 `hp` 스냅샷이 매번 그 시점 값이고 마지막 값이 규칙 상태와 같다
  - `take_events()` 후 큐가 빈다
- `test_board_layout.gd`
  - 아군 x 는 음수, 적군 x 는 양수, 같은 col 이면 절댓값이 같다
  - col 0 이 col 1 보다 중심에 가깝다
  - row 0 의 z 가 row 2 보다 작다
  - 3행 vs 2행에서 적군 z 가 ±0.55
- 기존 123개 전부 통과

### 13.2 실행 검증 (MCP 스크린샷 · 입력 주입)

1. 시작 화면에 두 진영 타일과 유닛이 모두 보이고 HUD 에 가리지 않는다
2. 카드 선택 시 타일 강조와 이유 글자가 규칙과 일치한다 (선봉 베기: 괴한 ✓1, 보초 막힘, 추적자 ✓2)
3. 유닛 몸통 클릭과 타일 클릭이 모두 같은 대상으로 처리된다
4. 차례 종료 후 재생 중간 스크린샷에서 적이 한 명씩 행동하고, 그동안 손패·차례 종료가 비활성이다
5. 유닛이 죽으면 사라지고 칸이 빈 칸으로 바뀐다
6. 전투 종료 시 배너가 뜬다

## 14. 후속 작업

- ComfyUI 로 유닛 스프라이트 제작 후 `UnitData.sprite` 지정
- 스프라이트시트 애니메이션 (대기/공격/피격)
- 연출 속도 조절·건너뛰기
