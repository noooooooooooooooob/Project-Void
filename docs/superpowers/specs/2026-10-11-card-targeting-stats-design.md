# 카드 타게팅·효과·스탯 개편 설계

- 작성일: 2026-10-11
- 대상: 카드 데이터, 타게팅 규칙, 효과 계산, 캐릭터 스탯, 적 행동, 카드 앞면, 범위 편집기
- 근거: Notion `세계관 / 카드` 페이지와 `등장인물 / 캐릭터 양식` 스탯 표 (2026-10-10 기준)
- 선행 문서: `2026-09-12` 전투 프로토타입 규칙, `2026-09-13-card-presentation-design.md`

## 1. 범위

Notion 카드 기획이 바뀌어 다음을 반영한다.

1. **사거리 삭제**: `attack_range`와 거리 계산(`reach`)을 없앤다.
2. **공격 종류 4가지**: 근접 / 원거리 / 아군 / 자신.
3. **범위를 오프셋 배열로**: 고정 모양(Shape enum) 대신 기준 유닛으로부터의 `Vector2i` 오프셋 목록.
4. **근접 규칙**: 자기 행의 맨 앞 적만 칠 수 있다.
5. **카드 분류와 색**: 공격 / 스킬 / 특수.
6. **% 계수**: 카드 수치는 사용자 스탯 × %. 전투 중엔 계산값, 덱 편집 화면에선 %로 보인다.
7. **캐릭터 스탯 8종**: HP, SP, 공격, 방어, 속도, 치명확률, 치명피해, 어그로.

제외: 카드 키워드(버리기·연결 등), 덱 코스트·장수 제한, 카드 등급, 일러스트, 어그로 규칙, 새 스탯용 장비 보너스. 맵 구조(스테이지형)는 그대로다.

## 2. 데이터 모델

### 2.1 `UnitData` (아군·적 공통)

| 필드 | 상태 | 기본값 | 비고 |
|---|---|---|---|
| `max_hp` | 기존 | 10 | |
| `speed` | 기존 | 10 | 1~10 |
| `attack` | 신규 | 10 | 피해·회복 효과의 기준 |
| `defense` | 신규 | 10 | 방어도 효과의 기준. 받는 피해는 줄이지 않는다 |
| `crit_chance` | 신규 | 1 | % |
| `crit_damage` | 신규 | 175 | % |
| `aggro` | 신규 | 100 | 값만 저장한다. 규칙은 나중에 정한다 |

SP는 지금처럼 `AllyData.max_sp`에 둔다 (적은 SP를 쓰지 않는다).

### 2.2 `CardEffect` (신규 Resource)

| 필드 | 값 |
|---|---|
| `kind` | `DAMAGE` / `BLOCK` / `HEAL` |
| `percent: int` | 120 = 120% |
| `target` | `AREA` (카드 범위 안의 유닛) / `SELF` (사용자) |

기준 스탯은 `kind`가 정한다: `DAMAGE`·`HEAL` → `attack`, `BLOCK` → `defense`.

### 2.3 `CardData`

| 필드 | 상태 | 내용 |
|---|---|---|
| `id`, `display_name`, `sp_cost` | 유지 | |
| `category` | 신규 | `ATTACK` / `SKILL` / `SPECIAL` — 카드 색 |
| `attack_type` | 변경 | `MELEE` / `RANGED` / `ALLY` / `SELF` |
| `area: Array[Vector2i]` | 신규 | 기준 칸에서의 오프셋. 비어 있으면 `[(0,0)]`(단일)로 취급 |
| `effects: Array[CardEffect]` | 신규 | 순서대로 적용 |
| `shape`, `attack_range`, `damage` | 삭제 | |

오프셋 좌표는 기존 격자 규칙을 따른다: `x` = 열(0이 앞줄, +가 뒤쪽), `y` = 행(+가 아래). 범위는 기준 유닛과 같은 편 격자에 적용된다.

예: 단일 `[(0,0)]`, 관통 `[(0,0),(1,0),(2,0)]`, 횡렬 `[(0,-1),(0,0),(0,1)]`, 뒤 한 칸만 `[(1,0)]`.

### 2.4 `EnemyData`

- 신규: `attack_card`, `defend_card`, `rest_card` (`CardData`, 비어 있을 수 있음)
- 유지: `move_chance`
- 삭제: `attack_damage`, `attack_type`, `attack_shape`, `attack_range`, `block_amount`, `rest_heal`

### 2.5 장비

`ItemData.attack_bonus`는 카드 피해에 직접 더하지 않고 `attack` 스탯에 더한다. `PartyState._boosted_deck`은 삭제되고, `build_battle_roster()`는 `AllyData` 복사본의 `attack`에 보너스를 굽는다.

### 2.6 기존 리소스 이전

- 카드 7장(`Resources/cards/`)을 새 형식으로 바꾼다. % 값은 공격 10 기준으로 기존 피해가 유지되도록 정한다 (예: 베기 피해 6 → `DAMAGE 60%`). 범위는 기존 모양을 오프셋으로 옮긴다.
- 적마다 공격·방어·휴식 카드를 만들어 기존 수치(피해·방어도·회복량)를 유지한다.

## 3. 규칙

### 3.1 기준 유닛 (`TargetResolver.valid_anchors(actor, card, units) -> Array[Unit]`)

| 공격 종류 | 기준이 될 수 있는 유닛 |
|---|---|
| `MELEE` | 상대 편에서 actor와 **같은 행 번호**에 살아 있는 유닛 중 가장 앞 열 한 명. 없으면 빈 목록 (카드 사용 불가) |
| `RANGED` | 상대 편의 살아 있는 유닛 전부 |
| `ALLY` | 같은 편의 살아 있는 유닛 전부 (자신 포함) |
| `SELF` | `[actor]` |

빈 칸은 기준이 될 수 없다.

### 3.2 범위

- `area_cells(anchor_cell, area, grid) -> Array[Vector2i]`: 기준 칸 + 각 오프셋, 격자 밖은 버린다. 미리보기도 이 함수를 쓴다.
- `units_in_area(anchor, area, units) -> Array[Unit]`: 기준 유닛과 같은 편이고 `area_cells` 안에 서 있는 살아 있는 유닛.

삭제: `reach`, `reach_cell`, `is_blocked`, `is_cell_blocked`, `is_valid_target`, `is_valid_cell`, `expand_shape`, `expand_shape_cell`, `shape_cells`, `_in_area`. `movable_cells`는 유지.

### 3.3 카드 사용 (`BattleState`)

- `play_card(hand_index, anchor: Unit) -> bool`: SP가 충분하고 `anchor`가 `valid_anchors` 안에 있으면 SP를 쓰고 카드를 묘지로 보낸 뒤 `resolve_card`를 부른다.
- `resolve_card(actor, card, anchor)`: 아군 카드와 적 행동이 함께 쓰는 효과 적용 함수. `effects`를 순서대로 처리하며, 대상은 `AREA` → `units_in_area(anchor)`, `SELF` → `[actor]`.
- 수치: `floor(기준 스탯 × percent / 100)`, `percent > 0`이면 최소 1.
- 치명타: `DAMAGE` 효과에서 **맞는 유닛마다** `crit_chance`%로 판정해, 성공하면 `× crit_damage / 100` (내림). 판정은 전용 난수 `crit_rng`를 쓴다 — 덱 셔플 난수와 섞으면 기존 시드의 드로우 순서가 바뀐다.
- `unit_damaged` 신호에 `critical: bool`을 추가한다.
- 방어도(block)는 지금처럼 피해를 먼저 흡수한다. 방어 스탯은 피해 계산에 끼지 않는다.
- `card_played` 신호는 기준 칸 대신 기준 유닛을 싣는다.

### 3.4 적 행동 (`EnemyBrain`)

- `decide()`: 이동 확률 판정 → 체력 30% 이하이고 `rest_card`가 있으면 휴식 → `attack_card`의 기준 후보가 없으면 방어 → 그 외 공격. (기존 흐름 유지)
- `find_target()`: `attack_card`의 `valid_anchors` 중 체력이 가장 낮은 유닛, 같으면 `unit_id`가 작은 유닛.
- 휴식·방어·공격 모두 해당 카드를 `resolve_card`로 적용한다. 카드가 비어 있는 행동은 고르지 않는다 (무작위 대체 후보에서도 뺀다). 고를 행동이 하나도 없으면 차례를 넘기고 로그에 "대기"를 남긴다.

## 4. 화면

### 4.1 조준

- `MELEE` / `SELF`: 조준이 없다. 카드를 손패 위로 끌어 놓으면 사용된다. 끄는 동안 자동 기준 유닛과 범위 칸을 강조한다. 근접인데 같은 행에 적이 없으면 카드가 흐려지고 "같은 행에 적 없음" 힌트를 띄운다.
- `RANGED` / `ALLY`: 화살표로 유닛을 겨냥한다. 올린 유닛 기준 `area_cells`를 미리 보여 주고, 무효 대상은 빨간색이다.
- 사거리·막힘 힌트 텍스트는 삭제한다.

### 4.2 연출

- 이벤트(`battle_event*`)는 기준 유닛을 기록한다.
- `ALLY` / `SELF` 카드는 돌진 없이 제자리 시전 모션. 회복·방어도 팝업은 기존 신호를 쓴다.
- 치명타면 피해 숫자에 "치명!"을 붙인다.

### 4.3 카드 앞면 (`card_view`)

Notion 스케치 구조:

```
┌───────────────────┐
│(SP)   이름   [근][▦]│  ← 공격 종류 배지, 5×5 범위 미니맵
│ ┌───────────────┐ │
│ │ 일러스트 자리  │ │  ← 분류 색으로 칠한 빈 박스
│ └───────────────┘ │
│  피해 7 · 자신 방어도 4 │  ← 효과 설명
└───────────────────┘
```

- 테두리·배경은 분류 색 (공격 빨강, 스킬 파랑, 특수 보라). 색은 상수 한곳에 둔다.
- 효과 문구는 순수 함수 `CardText.describe(card, stats_or_null) -> String`. 스탯을 주면 계산값(치명 미적용), `null`이면 % 표기 (`피해 60% · 자신 방어도 50%`).

### 4.4 파티 화면 (`party_view`)

- 스탯 패널에 공격, 방어, 치명확률, 치명피해, 어그로 추가.
- 덱 목록: `베기 ×2 — 피해 60%`.

## 5. 범위 편집기 (`addons/card_area_editor/`)

- `EditorInspectorPlugin`이 `CardData.area`를 5×5 토글 격자로 그린다. 가운데가 기준점, 위가 행 −, 오른쪽이 열 +(뒤쪽).
- 칸 클릭으로 `area`를 바로 갱신하고 Undo/Redo를 지원한다.
- `project.godot`에서 활성화한다. MCP 브리지 플러그인과 무관하다.
- 5×5(오프셋 −2~+2)는 현재 3×3 격자 기준이다.

## 6. 테스트

- 수정: `test_target_resolver`, `test_battle_state`, `test_enemy_brain`, `test_card_view`, `test_battle_root`, `test_party_state`, `test_party_view` 및 사거리·Shape를 참조하는 나머지.
- 신규:
  - 근접 기준: 같은 행 맨 앞 적 / 행이 비면 빈 목록 / 쓰러진 유닛 무시
  - `area_cells` 격자 경계 처리, `units_in_area`의 편 구분
  - 효과 수치: 내림, 최소 1, 기준 스탯 선택
  - 효과 대상 `AREA` / `SELF`, 효과 순서
  - 치명타: 고정 시드에서 결정적, 0%·100% 경계
  - `CardText` % 표기와 계산값 표기
  - 적이 카드로 공격·방어·휴식
  - 장비 `attack_bonus`가 `attack` 스탯에 반영
