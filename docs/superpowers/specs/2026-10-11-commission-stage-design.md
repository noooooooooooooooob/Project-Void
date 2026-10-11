# 의뢰 스테이지(거울던전식 1층) 설계

- 작성일: 2026-10-11
- 대상: 월드맵 노드(의뢰)에 들어가면 전투 한 번이 아니라 거울던전식 격자 한 층을 진행한다
- 선행 문서: `2026-10-08-map-party-inventory-design.md` (월드맵·파티·인벤토리는 그대로)
- 참고
  - Notion `의뢰` 페이지: "거던식 진행", 전투 / 상점 / 이벤트 / 휴식 / 보스
  - Notion 할 일 `맵/던전 코어`: "갈래 2개 × 4칸 고정, 보스에서 합류" → **이 문서의 격자로 대체**
  - Figma `Project Void UI Wireframes` (`cPKjLHuAgOEmvdLHLDsYnr`) 02 월드맵: 의뢰서 패널의 "스테이지 미리보기"
  - 림버스 컴퍼니 거울던전 2 맵 (3줄 격자, 왼쪽 → 오른쪽, 끝에 출구·보스)

## 1. 범위

포함:

1. 월드맵의 모든 노드(스토리·파밍·보스)가 **의뢰**가 된다. 들어가면 의뢰 1층을 진행한다.
2. 의뢰 1층: 3줄 × 5칸 격자 + 보스. 전투·보스 칸만 실제로 동작한다.
3. 의뢰 안에서 전투 사이 **체력 이어가기**.
4. 의뢰 화면(`StageView`)과 `GameRoot` 화면 전환.

제외: 2층 이상, 공허 깊이(박명·암야·심연), 핵 정화, 의뢰서 패널, 시작 버프, 이벤트·상점·휴식의 실제 효과, 파티 편성, 세이브·로드.

## 2. 흐름

```
월드맵 ─(노드 선택)→ 의뢰 1층 ─(보스 승리)→ 월드맵 (노드 클리어: 기존 resolve_win)
                       │
                       ├─ 전투 패배 / 도망 → 의뢰 실패, 월드맵으로 (진행도 그대로)
                       └─ 의뢰가 끝나면 (성공·실패 모두) 파티 체력 전부 회복
```

- 월드맵의 해금 규칙(`MapRunState.is_selectable`)과 보스 클리어 시 새 지도는 그대로다.
- 의뢰에 들어갈 때마다 1층 격자를 새로 뽑는다 (시드 rng 를 이어 쓴다).

## 3. 1층 격자

### 3.1 모양

```
        (0,0) ─ (0,1) ─ (0,2) ─ (0,3) ─ (0,4)
시작 ─  (1,0) ─ (1,1) ─ (1,2) ─ (1,3) ─ (1,4) ─ 보스
        (2,0) ─ (2,1) ─ (2,2) ─ (2,3) ─ (2,4)
```

- 칸 좌표는 `(lane, step)`: `lane` 0~2 (위→아래), `step` 0~4 (왼쪽→오른쪽).
- 시작은 `step 0` 의 세 칸 모두와 이어진다.
- 칸 `(l, s)` 은 `step s+1` 의 칸 중 `|l' − l| ≤ 1` 인 칸과 이어진다 (같은 줄 앞칸 + 위·아래 비스듬한 칸).
- `step 4` 의 세 칸은 모두 보스로 이어진다.
- `LANES = 3`, `STEPS = 5` 는 상수. 플레이하며 조정할 출발값이다.

### 3.2 칸 종류

`StageNode.Kind`: `START`, `BATTLE`, `EVENT`, `SHOP`, `REST`, `BOSS`.

- 격자 칸마다 종류를 가중치로 뽑는다: 전투 6 : 이벤트 2 : 상점 1 : 휴식 1.
- `step 0` 은 항상 전투다 (첫 칸부터 빈 칸만 고르는 것을 막는다).
- `EVENT` / `SHOP` / `REST` 는 이번 범위에서 **빈 칸**이다. 고르면 효과 없이 그 칸으로 이동한다.

### 3.3 적 구성

- 전투 칸: 들어갈 때마다 `EncounterGenerator.build_enemy_placements(rng, false)`.
- 보스 칸: 그 월드맵 노드가 지금 주는 적. 즉 기존 `MapRunState.encounter_for(node_id, …)` 의 적 (스토리·보스 노드는 고정 적, 파밍 노드는 새로 뽑은 적).

## 4. 진행 상태 — `CommissionRun` (`Scripts/map/commission_run.gd`, RefCounted)

화면 없이 테스트할 수 있는 순수 로직.

| 항목 | 내용 |
|---|---|
| 생성 | `CommissionRun.new(rng, map_node_id, member_max_hp: Array[int])` — 격자를 만들고 시작 칸에 선다. 파티원 현재 체력 = 최대 체력. |
| `graph: StageGraph` | 이 의뢰의 격자. |
| `current_id` | 지금 서 있는 칸 (처음엔 시작). |
| `visited` | 지나온 칸 id 들 (화면에서 길 강조용). |
| `member_hp: Array[int]` | 파티원 번호별 현재 체력. |
| `is_selectable(id)` | 지금 칸의 `connections` 에 있고, 의뢰가 끝나지 않았으면 true. |
| `enter(id) -> Kind` | 고른 칸으로 이동하고 그 종류를 돌려준다. 빈 칸이면 이동으로 끝. 전투·보스면 호출한 쪽이 전투를 연다. 고를 수 없는 칸이면 아무것도 바꾸지 않는다. |
| `battle_roster(full: Array[UnitPlacement])` | `PartyState.build_battle_roster()` 결과에서 **체력 0 인 파티원을 뺀** 배치를 돌려주고, 각 배치에 `start_hp = member_hp[i]` 를 넣는다. 어떤 파티원 번호가 들어갔는지 기억한다. |
| `apply_battle_hp(final_hp: Array[int])` | 전투가 끝난 뒤 아군 최종 체력(배치 순서)을 기억해 둔 번호로 되돌려 `member_hp` 에 쓴다. |
| `state` | `IN_PROGRESS` / `SUCCEEDED` (보스 승리) / `FAILED` (패배·도망). |
| `finish_battle(won: bool)` | 졌으면 `FAILED`. 이겼고 지금 칸이 보스면 `SUCCEEDED`. |
| `fail()` | 도망: `FAILED`. |

의뢰가 끝나면 `CommissionRun` 은 버린다 — 다음 의뢰는 체력이 가득 찬 새 `CommissionRun` 으로 시작하므로 "의뢰 종료 시 회복"이 따로 필요 없다.

`StageGraph` (`Scripts/map/stage_graph.gd`) 와 `StageNode` (`Scripts/map/stage_node.gd`) 는 `MapGraph` / `MapNode` 와 같은 방식이다: `nodes` 배열 위치가 id, `start_id = 0`, `boss_id`, 노드는 `lane`, `step`, `kind`, `connections`. 시작은 `step = -1, lane = 1`, 보스는 `step = STEPS, lane = 1`.

## 5. 체력 이어가기 — 전투 쪽 최소 변경

| 파일 | 변경 |
|---|---|
| `Scripts/combat/data/unit_placement.gd` | `@export var start_hp: int = -1` 추가. −1 이면 최대 체력으로 시작. |
| `Scripts/combat/battle_state.gd` | 아군 유닛을 만든 직후 `start_hp >= 0` 이면 `hp = mini(start_hp, max_hp)`. |
| `Scripts/view/battle_root.gd` | `ally_final_hp() -> Array[int]`: 아군 유닛의 현재 체력을 배치 순서대로 돌려준다. `GameRoot` 가 `battle_finished` 를 받았을 때 씬을 지우기 전에 읽는다. |

- 기존 전투(테스트, `skirmish.tres` 등)는 `start_hp = -1` 이라 동작이 바뀌지 않는다.
- 체력 0 이 된 파티원은 그 의뢰의 남은 전투에서 빠지고, 의뢰가 끝나면 (새 `CommissionRun` 으로) 복귀한다.
- 아군이 전멸하면 기존 규칙대로 패배 → 의뢰 실패.

## 6. 화면

### 6.1 `StageView` (`Scripts/view/stage_view.gd`, 코드로 구성하는 전체 화면 Control — MapView 와 같은 방식)

- 위: "1층 탐사 중" 제목.
- 가운데: 격자 버튼. 칸 위치 계산은 `StageLayout` (`Scripts/map/stage_layout.gd`, `MapLayout` 과 같은 순수 함수) 이 한다: `step` → x, `lane` → y. 연결선은 `_draw` 로 그린다.
- 칸 표시: 종류 글자(전투 / ? / 상점 / 휴식 / 보스). 색은 MapView 와 같은 규칙 — 잠김(회색), 고를 수 있음(금색), 지금 칸(파랑), 지나온 칸·길(주황 강조).
- 아래: 파티원별 이름과 `현재 / 최대` 체력 줄. 0 이면 "쓰러짐".
- 결과 문구: 빈 칸을 지나면 "아무 일도 없었다", 전투 승리면 "승리! 획득: …" (기존 문구 재사용).
- 신호: `node_selected(id)`.
- 공개 함수: `rebuild(run)`, `sync_from_run(run, party)`, `show_result(text)`, 테스트용 `button_for(id)`.

### 6.2 `GameRoot` 연결

- 월드맵 `node_selected` → `CommissionRun` 을 만들고 월드맵을 숨기고 `StageView` 를 보인다.
- `StageView.node_selected(id)` → `run.enter(id)`.
  - 빈 칸: 문구를 띄우고 화면을 맞춘다.
  - 전투: 일반 적으로 전투를 연다. 보스: `run_state.encounter_for(map_node_id, …)` 의 적으로 전투를 연다. 아군은 `run.battle_roster(party.build_battle_roster())`.
- 전투 끝 (`battle_finished`): `run.apply_battle_hp(_battle.ally_final_hp())` → `run.finish_battle(won)`.
  - 이겼으면 지금처럼 아이템 1개를 가방에 넣는다.
  - `SUCCEEDED`: `run_state.resolve_win(map_node_id)` → 월드맵으로 (보스 노드였으면 기존 챕터 클리어 처리).
  - `FAILED`: 월드맵으로, 패배 문구.
  - `IN_PROGRESS`: `StageView` 로 돌아온다.
- 도망 (`battle_fled`): `run.fail()` → 월드맵으로, 도망 문구.
- 파티 버튼은 월드맵에서만 쓴다 (의뢰 중 장비 교체는 이번 범위 밖).

## 7. 테스트

- `test_stage_graph`: 칸 수(3×5 + 시작 + 보스), 연결 규칙(줄 차이 ≤ 1, 시작 → step 0 전부, step 4 → 보스), step 0 은 전투, 같은 시드 → 같은 격자.
- `test_commission_run`: 고를 수 있는 칸, 고를 수 없는 칸 무시, 빈 칸 이동, `battle_roster` 의 0 체력 제외와 `start_hp`, `apply_battle_hp` 번호 되돌리기, 보스 승리 → `SUCCEEDED`, 패배·도망 → `FAILED`, 끝난 뒤 이동 불가.
- `test_battle_state` (추가): `start_hp` 가 있으면 그 체력으로, −1 이면 최대 체력으로 시작. 최대 체력보다 크면 최대 체력.
- `test_stage_view`: 버튼 수, 상태별 색, 누르면 `node_selected`, 파티 체력 줄 표시.
- `test_stage_layout`: 위치 계산.
- 통합: `GameRoot` 를 띄워 월드맵 → 의뢰 → 빈 칸 → 전투(체력 감소 유지) → 보스 승리 → 월드맵 노드 클리어, 그리고 패배 → 월드맵 복귀를 직접 진행해 확인한다.

## 8. 다음 단계

- 이벤트·상점·휴식 칸의 실제 효과 (휴식 = 체력 회복부터).
- 의뢰서 패널(02 월드맵 오른쪽)과 스테이지 미리보기.
- 2층 이상, 공허 깊이, 핵 정화.
- 칸 종류 비율·격자 크기 조정.
