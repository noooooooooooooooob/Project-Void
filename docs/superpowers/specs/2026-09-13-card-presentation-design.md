# 카드 연출 설계 (덱 · 드로우 · 손패 · 버리기)

- 작성일: 2026-09-13
- 대상: 전투 화면의 카드 표현
- 상태: 승인 대기
- 선행 문서: `2026-09-13-battle-2-5d-design.md` (이벤트 기록·재생 구조를 그대로 확장한다)

## 1. 배경

규칙에는 아군 유닛마다 덱 / 손패 / 묘지 / 제외 존이 있다. 차례가 시작되면 4장을 뽑고, 덱이 비면 묘지를 섞어 되돌리고, 차례가 끝나면 손패를 묘지로 보낸다. 지금 화면은 이 과정을 보여주지 않는다. 손패는 HUD 에 일자로 늘어선 버튼이고, 덱과 묘지는 보이지 않는다.

이 문서는 카드를 실제 카드 모양으로 바꾸고 덱 · 드로우 · 버리기 · 리셔플을 연출하는 설계다.

## 2. 확정 사항 (2026-09-13 사용자 결정)

| 항목 | 결정 |
|---|---|
| 배치 | 화면 아래 가운데 부채꼴 손패, 왼쪽 아래 덱 더미, 오른쪽 아래 묘지 더미 |
| 사용 방식 | 클릭(카드 → 적)과 드래그(카드를 적에게 놓기, 조준 화살표) 둘 다 |
| 연출 | 드로우, 손패 버리기, 리셔플 |
| 더미 표시 | 현재 차례 아군의 덱·묘지만 |
| 구조 | `BattleState` 가 카드 한 장 단위로 신호를 내고, 기존 이벤트 기록·재생에 종류를 추가 |

기각한 구조: `Unit` 이 직접 신호를 내는 안 — 신호 통로가 둘로 갈라지고 기록기가 유닛마다 연결해야 한다. 차례 전후 손패·덱을 비교하는 안 — 드로우 도중 리셔플이 몇 번째에 일어났는지 알 수 없다.

## 3. 범위

### 포함

- 카드 앞면/뒷면 표현, 근접/원거리 테두리, SP 부족 흐림
- 부채꼴 손패 배치와 재배치, 선택 들어올리기
- 클릭 사용, 드래그 사용과 조준 화살표, 빈 곳에 놓으면 취소
- 덱·묘지 더미 (현재 차례 아군 이름, 장수)
- 드로우 · 리셔플 · 손패 버리기 연출
- 규칙 레이어에 신호 3종 추가

### 제외

카드 사용 비행 연출(쓴 카드는 손패에서 사라진다), 호버 확대, 아군별 덱 요약 표시, 카드 일러스트, 제외 존 표시, 키보드 조작.

## 4. 규칙 레이어 변경

판정(뽑는 장수, 섞는 방식과 난수 소비 순서, 버리는 시점)은 바꾸지 않는다.

### 4.1 `Unit`

`draw()` 를 두 동작으로 나눈다.

```gdscript
func reshuffle_discard(rng: RandomNumberGenerator) -> int   # 묘지 전부를 덱으로 옮겨 섞고 옮긴 장수를 돌려준다
func draw_one() -> CardData                                 # 덱 맨 앞 1장을 손패로. 덱이 비었으면 null
func draw(count: int, rng: RandomNumberGenerator) -> void  # 기존 동작 유지: 위 둘을 같은 순서로 부른다
```

`draw()` 는 `for i in count: 덱이 비었으면 (묘지도 비었으면 return) reshuffle_discard(rng); draw_one()` 이다. 기존 구현과 난수 소비 순서가 같아 기존 테스트 결과가 바뀌지 않는다.

### 4.2 `BattleState` 신호

```gdscript
signal deck_reshuffled(unit: Unit, count: int)
signal card_drawn(unit: Unit, card: CardData, deck_count: int, discard_count: int)   # 뽑은 직후 장수
signal hand_discarded(unit: Unit, cards: Array[CardData], discard_count: int)       # 버린 직후 묘지 장수
```

- 차례 시작 드로우: `_run_until_player_input()` 의 `actor.draw(DRAW_PER_TURN, rng)` 를 `_draw_cards(actor, DRAW_PER_TURN)` 로 바꾼다. 한 장마다 덱이 비었으면 `reshuffle_discard` 후 `deck_reshuffled`, 이어서 `draw_one` 후 `card_drawn` 을 낸다. 덱과 묘지가 모두 비면 멈춘다
- 차례 종료: `end_turn()` 의 `actor.discard_hand()` 를 `_discard_hand(actor)` 로 바꾼다. 버리기 전 손패를 복사해 두고, 버린 뒤 `hand_discarded` 를 낸다. 손패가 비어 있어도 낸다
- 신호는 모두 `BattleState` 안에서만 낸다 (기존 원칙)

### 4.3 발생 순서

- 아군 차례 시작: `turn_started` → (`deck_reshuffled`) → `card_drawn` ×4. 리셔플은 덱이 비는 순간 드로우 사이에 끼어든다
- 차례 종료: `hand_discarded` → 다음 유닛들의 차례

## 5. 이벤트 모델 변경

`BattleEvent` 에 필드 `cards: Array[CardData]`, `deck_count: int`, `discard_count: int` 를 추가한다.

| kind | 채우는 필드 | 신호 |
|---|---|---|
| `CARD_DRAWN` (신규) | unit, card, deck_count, discard_count | `card_drawn` |
| `DECK_RESHUFFLED` (신규) | unit, amount(되돌린 장수), deck_count, discard_count(0) | `deck_reshuffled` |
| `HAND_DISCARDED` (신규) | unit, cards, discard_count, deck_count | `hand_discarded` |
| `TURN_STARTED` (기존) | + deck_count, discard_count (드로우 전 값) | `turn_started` |
| `CARD_PLAYED` (기존) | + deck_count, discard_count (사용 직후 값) | `card_played` |

`DECK_RESHUFFLED` 의 deck_count 와 `HAND_DISCARDED` 의 deck_count 는 기록기가 신호 순간의 `unit.deck.size()` 로 채운다.

## 6. 화면 구성

### 6.1 파일

| 파일 | 역할 |
|---|---|
| `Scripts/ui/cards/card_view.gd` | `class_name CardView extends Control`. 카드 1장 (앞면/뒷면), 자식은 코드로 만든다 |
| `Scripts/ui/cards/hand_layout.gd` | `class_name HandLayout extends RefCounted`. 장수 → 부채꼴 위치·각도 (순수 계산) |
| `Scripts/ui/cards/hand_view.gd` | `class_name HandView extends Control`. 손패 카드들, 선택, 드래그, 드로우·버리기 연출 |
| `Scripts/ui/cards/aim_arrow.gd` | `class_name AimArrow extends Control`. 드래그 중 조준 곡선 화살표 그리기 |
| `Scripts/ui/cards/pile_view.gd` | `class_name PileView extends Control`. 덱 또는 묘지 더미 |
| `Scenes/battle_hud.tscn`, `Scripts/ui/battle_hud.gd` (수정) | 버튼 손패를 `HandView` 로 교체, 더미 2개 추가, 배치 변경 |
| `Scripts/view/battle_playback.gd` (수정) | 새 이벤트 재생 |
| `Scripts/view/board_3d.gd` (수정) | 화면 좌표 판정 요청과 빗나감 신호 |
| `Scripts/view/battle_root.gd` (수정) | 드래그 놓기 처리 |

### 6.2 `CardView`

- 크기 `SIZE = Vector2(110, 154)`, 회전 기준점은 가운데
- 앞면: 어두운 바탕, 테두리 3px (근접 `Color(0.85, 0.4, 0.35)` / 원거리 `Color(0.4, 0.6, 0.95)`)
  - 왼쪽 위 원 안에 SP 비용 숫자
  - 위쪽 가운데 이름
  - 가운데 큰 피해 숫자
  - 아래 왼쪽 위 정렬 두 줄 `사거리 2` / `근접 · 단일` 형식, (8, 114) 위치 (형태: SINGLE 단일, SWEEP 횡렬, PIERCE 관통). 부채꼴에서는 오른쪽 약 20px 가 다음 카드에 가려지므로 사거리를 왼쪽 윗줄에 둔다
- 뒷면: 남색 `Color(0.18, 0.22, 0.38)` 바탕, 가운데 `VOID`
- SP 부족: modulate `Color(1, 1, 1, 0.55)`, 비용이 현재 SP 를 넘는 카드는 흐려지고 누르기·드래그를 무시한다
- `mouse_filter = STOP` (카드 위 클릭은 보드로 새지 않는다)

```gdscript
func setup(p_card: CardData) -> void
func set_face_up(face_up: bool) -> void
func is_face_up() -> bool
func set_affordable(affordable: bool) -> void
func cost_text() -> String        # "1"
func name_text() -> String        # "베기"
func damage_text() -> String      # "6"
func footer_text() -> String      # "사거리 2\n근접 · 단일"
func border_color() -> Color
```

### 6.3 `HandLayout`

```
CARD_ANGLE_DEG = 6      # 한 장당 벌어지는 각도
MAX_SPREAD_DEG = 40     # 전체 최대 벌어짐
RADIUS         = 900    # 부채꼴 원의 반지름 (px)

spread   = min(CARD_ANGLE_DEG × (count − 1), MAX_SPREAD_DEG)
angle_i  = count == 1 ? 0 : −spread/2 + spread × i/(count − 1)
position = anchor + (sin(angle_i) × RADIUS, (1 − cos(angle_i)) × RADIUS)
rotation = angle_i
```

`static func slot(index: int, count: int, anchor: Vector2) -> Dictionary` 가 `{"position": Vector2, "rotation": float}` (라디안)을 돌려준다. `anchor` 는 가운데 카드의 중심점이다.

### 6.4 `HandView`

- 손패 영역은 화면 아래 가운데. `anchor` 는 뷰포트 가로 가운데, 아래에서 110px
- 선택된 카드: 40px 위로, 회전 0, 1.1배, 맨 앞
- 잠금(`interactive = false`) 중에는 선택·드래그를 받지 않는다
- 장수가 바뀌면 남은 카드가 0.2s 에 걸쳐 새 자리로 이동한다

```gdscript
signal card_selected(index: int)                              # -1 = 해제
signal card_dropped(index: int, screen_position: Vector2)

var instant: bool      # 테스트용: 트윈 없이 최종 상태만
var interactive: bool

func set_cards(cards: Array[CardData], sp: int, selected: int) -> void   # 동기화용, 연출 없음. 이미 같은 손패(장수·카드 순서 동일)면 뷰를 다시 만들지 않아 재생 직후 동기화가 마지막 드로우 비행을 끊지 않는다
func draw_card(card: CardData, from_global: Vector2) -> void           # 연출, 기다리지 않음
func set_pending_play(index: int) -> void                              # 곧 사용될 카드 위치를 기억 (잠금으로 선택이 풀려도 유지)
func remove_card(card: CardData) -> void                               # 기억한 위치의 카드가 같은 카드면 그것, 아니면 같은 카드 첫 장. 제거 후 기억 해제
func discard_all(to_global: Vector2) -> void                            # 연출, 기다리지 않음
func set_sp(sp: int) -> void                                            # SP 부족 흐림 갱신
func card_views() -> Array[CardView]
func selected_index() -> int
```

입력:
- 카드를 누르고 **12px 이상** 움직이지 않은 채 떼면 클릭 → 선택 토글 → `card_selected`
- 누른 채 12px 이상 움직이면 드래그 → 해당 카드 선택 + `card_selected(index)`, `AimArrow` 가 카드 위쪽 가운데에서 커서까지 곡선을 그린다
- 드래그 중 떼면 `card_dropped(index, 뷰포트 좌표)` 를 내고, 카드는 선택 해제된 채 손패 자리로 돌아간다 (결과는 루트가 처리)

### 6.5 `PileView`

- 덱: 왼쪽 아래 (여백 16px), 묘지: 오른쪽 아래 차례 종료 버튼 왼쪽
- 뒷면 카드 모양 90×126px 위에 장수 숫자, 그 위에 유닛 이름

```gdscript
func set_owner_name(name: String) -> void
func set_count(count: int) -> void
func set_dimmed(dimmed: bool) -> void
func count_text() -> String
func owner_text() -> String
func center_global() -> Vector2
```

### 6.6 HUD 배치 변경

- 위: 행동 순서 바 (그대로)
- 왼쪽 위: 로그 패널 (순서 바 아래 좁은 세로 칸 x 16..216, y 56..380 — 넓은 왼쪽 위 칸은 아군 유닛을 가렸다)
- 왼쪽 아래: SP 패널(위) + 덱 더미(아래)
- 아래 가운데: `HandView`
- 오른쪽 아래: 묘지 더미 + 차례 종료
- 가운데: 승패 배너 (그대로)
- 루트와 장식 노드는 `mouse_filter = IGNORE` 를 유지한다. `HandView` 루트도 IGNORE, 카드만 STOP

`BattleHud` 변경:
- 신호 추가: `card_dropped(index: int, screen_position: Vector2)` (HandView 에서 전달)
- `sync_from_state(state, selected_card)`: 손패 `set_cards`, 더미 장수·이름을 실제 상태로
- `show_turn(event)`: 아군이면 더미 이름·장수(스냅샷) 설정 후 흐림 해제, 적이면 더미 흐림
- 재생용: `draw_card(event)`, `reshuffle(event)`, `discard_hand(event)`, `remove_played_card(event)`
- `set_pending_play(index: int)`: `HandView.set_pending_play` 전달. 같은 카드가 여러 장일 때 플레이어가 고른 그 카드가 사라지게 하기 위함 (잠글 때 선택이 해제되므로 선택 상태로는 알 수 없다)
- 조회용 `hand_buttons()` 는 `hand_view() -> HandView`, `deck_pile() -> PileView`, `discard_pile() -> PileView` 로 바꾼다

### 6.7 드래그 놓기 처리

- `Board3D`
  - `func request_pick(screen_position: Vector2) -> void` — 기존 클릭과 같은 대기 판정에 넣는다
  - `signal pick_missed` — 판정 레이가 아무것도 맞히지 못하면 낸다
- `BattleRoot`
  - `card_dropped(index, pos)`: 잠금이면 무시. `_selected_card = index`, 힌트 갱신, `_awaiting_drop = true`, `request_pick(pos)`
  - `cell_clicked`: 기존 흐름. 단 `_awaiting_drop` 중에 무효 대상이면 로그 `사용할 수 없는 대상` 과 함께 선택·힌트를 해제한다 (클릭 경로는 지금처럼 선택 유지)
  - `pick_missed`: `_awaiting_drop` 이면 선택·힌트 해제. 아니면 무시
  - 어느 경우든 처리 후 `_awaiting_drop = false`
  - 유효 대상으로 `play_card` 를 부르기 직전(클릭·드래그 공통) `hud.set_pending_play(card_index)` 를 호출한다

## 7. 재생

| kind | 연출 | 재생기 대기 |
|---|---|---|
| `TURN_STARTED` | 기존 + `hud.show_turn` 이 더미 이름·장수 설정 | 기존 |
| `CARD_DRAWN` | 덱 더미 중심에서 뒷면 카드가 손패 자리로 0.25s 비행, 절반 지점에서 앞면으로 뒤집힘(가로 스케일 1→0→1), 크기 0.6→1. 덱·묘지 장수를 스냅샷으로 | 0.12s (비행은 겹쳐 진행) |
| `DECK_RESHUFFLED` | 뒷면 카드 min(장수, 6)장이 묘지→덱으로 0.3s, 0.04s 간격. 묘지 0, 덱 장수 갱신 | 0.45s |
| `HAND_DISCARDED` | 남은 손패가 묘지 더미로 0.3s, 0.03s 간격, 0.5배로 줄며 흐려진 뒤 제거. 묘지 장수 갱신 | 0.35s |
| `CARD_PLAYED` | 기존 연출 전에 `hud.remove_played_card`: 쓴 카드 0.12s 페이드 후 제거, 나머지 0.2s 재배치, 덱·묘지 장수 갱신 | 기존 + 0.2s |

`instant` 모드에서는 모든 트윈과 대기를 건너뛰고 카드 추가·제거·장수만 즉시 반영한다. 재생이 끝나면 지금처럼 실제 상태로 전체 동기화한다.

## 8. 테스트와 검증

### 8.1 헤드리스 단위 테스트

- 규칙 신호 (`tests/test_card_zone_signals.gd`)
  - 덱 6장에서 4장 드로우: `card_drawn` 4번, deck_count 5→4→3→2, 손패 4장
  - 덱 2장·묘지 3장에서 4장 드로우: `drawn, drawn, reshuffled(3), drawn, drawn` 순서, 리셔플 직후 첫 drawn 의 deck_count 2
  - 덱·묘지 모두 비면 드로우 중단, 신호 없음
  - `end_turn` 에서 `hand_discarded` 가 버린 카드 목록과 묘지 장수를 담는다
  - 같은 시드에서 `Unit.draw()` 와 `_draw_cards` 경로의 손패 순서가 같다
- 기록기: 새 3종의 필드와 `TURN_STARTED`/`CARD_PLAYED` 의 장수 스냅샷
- `HandLayout`: 좌우 대칭, 홀수 장 가운데 회전 0, 벌어짐 최대 40° 제한, 1장이면 anchor 그대로
- `CardView`: 네 글자 조회값, 근접/원거리 테두리 색, 앞뒷면 전환, SP 부족 흐림
- `PileView`: 장수·이름 글자, 흐림
- `HandView` (instant, 트리에 붙여서): `set_cards` 장수, `draw_card` 추가, 선택 들어올리기(선택 카드 y 가 자기 슬롯보다 40 작음), 같은 카드 2장 중 `set_pending_play` 로 기억한 오른쪽 카드를 `remove_card` 가 제거, `discard_all` 후 0장, 가짜 마우스 이벤트로 클릭 → `card_selected`, 12px 이상 이동 후 뗌 → `card_dropped`, `interactive = false` 면 신호 없음
- 재생기 (instant): `CARD_DRAWN` 뒤 손패 장수·덱 장수, `HAND_DISCARDED` 뒤 손패 0장·묘지 장수, `DECK_RESHUFFLED` 뒤 장수
- 기존 HUD 테스트의 버튼 기반 단정은 `HandView`/`CardView` 기반으로 바꾼다. 기존 테스트 전부 통과

### 8.2 실행 검증

1. 첫 화면: 손패 부채꼴, 덱 더미(정찰병, 2), 묘지(0), 손패와 더미가 보드 유닛을 가리지 않음
2. 차례 넘김 직후 스크린샷에 날아오는 중인 카드
3. 클릭 사용: 카드 클릭 → 적 클릭 → 카드가 사라지고 묘지 +1
4. 드래그 사용: 카드를 끌어 적 위에 놓음 → 화살표가 보이고, 놓으면 사용
5. 드래그 취소: 빈 곳에 놓음 → 카드가 손패로 돌아가고 선택 해제, 변화 없음
6. 차례 종료: 남은 손패가 묘지로 날아가고 묘지 장수 증가
7. 2라운드 같은 유닛 차례: 리셔플 연출 후 드로우

Godot MCP 연결이 없으면 헤드리스로 실제 씬을 띄워 레이캐스트·입력 경로를 호출하는 방식으로 대체하고, 창 모드 확인이 남았음을 보고한다.

## 9. 후속 작업

- 카드 사용 비행 연출, 호버 확대
- 카드 일러스트 (ComfyUI)
- 제외 존 표시
