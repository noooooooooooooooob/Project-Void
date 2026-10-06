# 전투 연출 역이식 A — 유닛 외형·동작 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 유니티에서 만든 픽셀 유닛 그림·애니메이션 띠·코드 동작 곡선을 Godot 의 `UnitView` 로 옮겨, 유닛 6종이 실제 그림으로 숨쉬고 공격·피격·깡충·쓰러짐 동작을 하게 한다.

**Architecture:** 동작 곡선은 Node 비의존 정적 함수(`UnitMotion`)로 두고, `UnitView` 는 `Body`(빌보드) → `Pose`(늘이기·기울이기) → `Sprite`(사각형 메시 + `unit_sprite.gdshader`) 계층으로 바꾼다. 셰이더 uniform(`frame`, `frame_count`, `tint`, `flash`, `fade`)으로 띠 프레임·번쩍임·디더 페이드를 처리한다. 진영 틴트는 없애고 발밑 고리 색으로 구분한다.

**Tech Stack:** Godot 4.7.2 (Forward Plus), GDScript(타입 명시), spatial 셰이더, 헤드리스 `TestCase` 러너.

**Spec:** `docs/superpowers/specs/2026-10-06-unity-presentation-port-design.md` (§2, §3, §4, §8 A, §10 A)

## Global Constraints

- 유니티 원본: `C:\Users\User\Desktop\projectvoidunityh\Assets\_Project\` (그림은 `Art/`, 코드는 `Scripts/View/UnitView.cs`, `UnitMotion.cs`)
- 규칙 코어(`Scripts/combat/` 의 `battle_state.gd`·`unit.gd`·`target_resolver.gd`·`enemy_brain.gd`)는 건드리지 않는다.
- 새 GDScript 는 타입을 명시하고 `class_name` 을 단다. 주석은 주변 파일처럼 한국어로 촘촘히(`##` 문서 주석 + 단계별 `#` 주석).
- 정수 나눗셈은 `@warning_ignore("integer_division")` 를 붙인다 (기존 관례, `Scripts/map/map_graph.gd`).
- 그림 높이 `SPRITE_HEIGHT = 1.6`, 몸 기울임 20°, 대기 8fps, 공격 띠 1.0초, 피격 띠 0.8초, 띠 없을 때 공격·깡충 `ACTION_TIME = 0.25`, 피격 `FLASH_TIME = 0.24`, 쓰러짐 `FADE_TIME = 0.4`.
- 붉은 번쩍임 색 `(1, 0.45, 0.45)`, 접지 그림자 `(0, 0, 0, 0.7)` 0.9×0.5, 고리 0.95×0.6 아군 `(0.3, 0.55, 1.0, 0.8)` / 적 `(1.0, 0.3, 0.25, 0.8)`.
- 테스트 실행: `& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tests/run_tests.gd` (PowerShell, 저장소 루트). 마지막 줄 `N/N passed`, 종료 코드 0 이 통과.
- 새 `class_name` 이 "Could not find type" 으로 안 잡히면 코드를 고치지 말고 `& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --editor --quit --path .` 로 한 번 재스캔한 뒤 다시 돌린다.
- 새 테스트 파일은 `tests/run_tests.gd` 의 `TEST_SCRIPTS` 에 추가해야 실행된다.
- 커밋 메시지 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. `project.godot` 의 무관한 기존 변경은 커밋에 넣지 않는다.

## Review Focus

1. **placeholder 그림(128×192, 세로로 긴 그림)을 쓰는 유닛** — 맵 생성 전투에 데이터에 그림이 없는 유닛이 오면 비율이 깨지지 않고 1.6 높이로 서야 한다. → Task 3 테스트 `sprite quad keeps the texture aspect`.
2. **띠가 일부만 있는 유닛(brute: idle·hit 있음, attack 없음)** — 공격은 코드 자세로, 피격은 띠로 재생되고 시간도 각각 0.25 / 0.8 이어야 한다. → Task 3 테스트 `mixed sheets pick durations per action`.
3. **전투 중 쓰러졌다가 `sync_from_state` 로 다시 보이는 경우(재생 중단 후 동기화)** — `reset_pose` 뒤 fade 가 1, tint 가 흰색, 자세가 기본이어야 유닛이 투명하거나 붉은 채로 남지 않는다. → Task 3 테스트 `reset_pose restores shader state`.
4. **적(좌우 반전) 유닛의 기울기** — "뒤로 젖힘"이 화면상 반대 방향이어야 한다(아군 +, 적 −). → Task 3 테스트 `lean mirrors for enemies`.
5. **카메라가 없을 때(헤드리스·씬 전환 중)** — `_process` 가 카메라 null 에서 오류 없이 넘어가야 한다. → Task 3 Step 3 구현의 null 가드 + 테스트 `billboard without horizontal forward keeps yaw 0`.

---

### Task 1: 에셋 복사와 `UnitData` 연결

**Files:**
- Create: `Art/units/*.png` (6), `Art/units/anim/*.png` (14), `Art/effects/spirit_flame.png` 와 각 `.import`
- Modify: `Scripts/combat/data/unit_data.gd`
- Modify: `Resources/units/vanguard.tres`, `archer.tres`, `scout.tres`, `stalker.tres`, `brute.tres`, `sentry.tres`
- Test: `tests/test_data.gd`

**Interfaces:**
- Produces: `UnitData.sprite: Texture2D`(기존), `UnitData.idle_sheet / attack_sheet / hit_sheet / aura_texture: Texture2D`

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test_data.gd` 의 `run()` 에 호출을 추가하고 함수를 맨 아래에 붙인다.

```gdscript
	# 유닛 .tres 의 그림·띠·오라 연결 상태.
	_test_unit_art_links()
```

```gdscript
# 유닛 6종이 유니티와 같은 그림·애니메이션 띠·오라를 가리키는지 (설계 §4.1 표).
func _test_unit_art_links() -> void:
	# id → [idle, attack, hit, aura] 가 있어야 하는지.
	var expected: Dictionary = {
		"vanguard": [true, true, true, false],
		"archer": [true, true, true, false],
		"scout": [true, true, true, false],
		"stalker": [true, true, true, false],
		"brute": [true, false, true, false],
		"sentry": [false, false, false, true],
	}
	# 유닛마다.
	for id in expected:
		# 데이터 파일을 불러온다.
		var data: UnitData = load("res://Resources/units/%s.tres" % id)
		# 기대값.
		var flags: Array = expected[id]
		# 정지 그림은 모두 있다.
		check("%s has a sprite" % id, data.sprite != null)
		# 대기 띠.
		check_eq("%s idle sheet" % id, data.idle_sheet != null, flags[0])
		# 공격 띠.
		check_eq("%s attack sheet" % id, data.attack_sheet != null, flags[1])
		# 피격 띠.
		check_eq("%s hit sheet" % id, data.hit_sheet != null, flags[2])
		# 오라.
		check_eq("%s aura" % id, data.aura_texture != null, flags[3])
	# 띠는 64px 프레임 16장이다.
	var vanguard: UnitData = load("res://Resources/units/vanguard.tres")
	# 폭 1024, 높이 64.
	check_eq("sheet is 16 frames of 64px", Vector2i(vanguard.idle_sheet.get_width(), vanguard.idle_sheet.get_height()), Vector2i(1024, 64))
```

- [ ] **Step 2: 실패 확인**

Run: `& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tests/run_tests.gd`
Expected: `test_data.gd` 에서 `has a sprite` 들이 FAIL (또는 `idle_sheet` 속성이 없어 스크립트 오류로 suite FAIL).

- [ ] **Step 3: 에셋 복사** (Bash, 저장소 루트)

```bash
U=/c/Users/User/Desktop/projectvoidunityh/Assets/_Project/Art
mkdir -p Art/units/anim Art/effects
cp $U/Units/{vanguard,archer,scout,brute,sentry,stalker}.png Art/units/
for u in vanguard archer scout stalker; do for k in idle attack hit; do cp $U/Units/Anim/${u}_$k.png Art/units/anim/; done; done
cp $U/Units/Anim/brute_idle.png $U/Units/Anim/brute_hit.png Art/units/anim/
cp $U/Effects/spirit_flame.png Art/effects/
ls Art/units Art/units/anim Art/effects
```

Expected: units 6개, anim 14개, effects 1개. (sentry 의 옛 띠는 유니티에서도 쓰지 않으므로 복사하지 않는다.)

- [ ] **Step 4: 임포트하고 3D 압축 끄기** — 64px 픽셀 그림이 3D 에서 쓰일 때 VRAM 압축되어 뭉개지지 않게 한다.

```powershell
& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --editor --quit --path .
```

```bash
sed -i 's#detect_3d/compress_to=1#detect_3d/compress_to=0#' Art/units/*.import Art/units/anim/*.import Art/effects/*.import
grep -L "compress_to=0" Art/units/*.import Art/units/anim/*.import Art/effects/*.import
```

Expected: 마지막 `grep -L` 출력이 비어 있음. 그다음 위 PowerShell 임포트 명령을 한 번 더 실행해 설정을 반영한다.

- [ ] **Step 5: `UnitData` 필드 추가** — `Scripts/combat/data/unit_data.gd` 끝(`sprite` 아래)에 붙인다.

```gdscript
## 64px 프레임을 가로로 이어 붙인 대기 애니메이션 띠 (프레임 수 = 너비 ÷ 높이). 비어 있으면 sprite 한 장 + 코드 숨쉬기.
@export var idle_sheet: Texture2D
## 공격 애니메이션 띠. 비어 있으면 코드 자세(UnitMotion.attack)로 공격한다.
@export var attack_sheet: Texture2D
## 피격 애니메이션 띠. 비어 있으면 코드 자세(UnitMotion.hit)로 움찔한다.
@export var hit_sheet: Texture2D
## 몸 주변에 계속 피어오르는 이펙트 그림 (예: 영혼불). 비어 있으면 없음.
@export var aura_texture: Texture2D
```

- [ ] **Step 6: `.tres` 연결** — 각 파일의 마지막 `[ext_resource ...]` 줄 아래에 텍스처 ext_resource 를 추가하고, `[resource]` 블록 끝에 속성을 추가한다. (uid 는 생략해도 경로로 불린다 — `vanguard.tres` 의 `skewer` 줄과 같은 형식.)

`Resources/units/vanguard.tres`:

```
[ext_resource type="Texture2D" path="res://Art/units/vanguard.png" id="10_sprite"]
[ext_resource type="Texture2D" path="res://Art/units/anim/vanguard_idle.png" id="11_idle"]
[ext_resource type="Texture2D" path="res://Art/units/anim/vanguard_attack.png" id="12_attack"]
[ext_resource type="Texture2D" path="res://Art/units/anim/vanguard_hit.png" id="13_hit"]
```

```
sprite = ExtResource("10_sprite")
idle_sheet = ExtResource("11_idle")
attack_sheet = ExtResource("12_attack")
hit_sheet = ExtResource("13_hit")
```

`archer.tres`, `scout.tres`, `stalker.tres`: 위와 같은 4줄 + 4속성, 경로의 `vanguard` 만 각 id 로 바꾼다.

`Resources/units/brute.tres` (attack 없음):

```
[ext_resource type="Texture2D" path="res://Art/units/brute.png" id="10_sprite"]
[ext_resource type="Texture2D" path="res://Art/units/anim/brute_idle.png" id="11_idle"]
[ext_resource type="Texture2D" path="res://Art/units/anim/brute_hit.png" id="13_hit"]
```

```
sprite = ExtResource("10_sprite")
idle_sheet = ExtResource("11_idle")
hit_sheet = ExtResource("13_hit")
```

`Resources/units/sentry.tres` (띠 없음, 오라):

```
[ext_resource type="Texture2D" path="res://Art/units/sentry.png" id="10_sprite"]
[ext_resource type="Texture2D" path="res://Art/effects/spirit_flame.png" id="14_aura"]
```

```
sprite = ExtResource("10_sprite")
aura_texture = ExtResource("14_aura")
```

- [ ] **Step 7: 통과 확인**

Run: 테스트 실행 명령 (Global Constraints)
Expected: `test_data.gd` 의 새 검사 전부 PASS, 전체 `N/N passed`. (이 시점에 `test_board_3d` 의 그림 검사는 기존 `UnitView` 가 `unit.data.sprite` 를 그대로 쓰므로 계속 통과한다.)

- [ ] **Step 8: 커밋**

```bash
git add Art Scripts/combat/data/unit_data.gd Resources/units tests/test_data.gd
git commit -m "feat: import Unity unit sprites and animation sheets into unit data

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `UnitMotion` 동작 곡선

**Files:**
- Create: `Scripts/view/unit_motion.gd`
- Create: `tests/test_unit_motion.gd`
- Modify: `tests/run_tests.gd` (`TEST_SCRIPTS` 에 `"res://tests/test_unit_motion.gd"` 를 `test_unit_view.gd` 앞에 추가)

**Interfaces:**
- Produces:
  - `class UnitMotion.Pose` — `var stretch: float`, `var lean: float`, `func _init(p_stretch: float = 0.0, p_lean: float = 0.0)`
  - `static func idle(time: float, phase: float) -> UnitMotion.Pose`
  - `static func attack(t: float) -> UnitMotion.Pose`, `static func lunge_reach(t: float) -> float`
  - `static func hop(t: float) -> UnitMotion.Pose`, `static func hop_height(t: float) -> float`
  - `static func hit(t: float) -> UnitMotion.Pose`, `static func knockback_reach(t: float) -> float`
  - `static func death(t: float) -> UnitMotion.Pose`
  - 상수 `IDLE_PERIOD 1.6`, `IDLE_STRETCH 0.03`, `DEATH_LEAN 85.0`, `ATTACK_WINDUP_END 0.3`, `ATTACK_STRIKE 0.5`, `KNOCKBACK_PEAK 0.15`

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test_unit_motion.gd`

```gdscript
# UnitMotion(유닛 자세 곡선) 테스트: 각 곡선의 끝점·키 값·주기.
extends TestCase


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 숨쉬기.
	_test_idle()
	# 공격 자세와 돌진.
	_test_attack()
	# 깡충.
	_test_hop()
	# 피격과 넉백.
	_test_hit_and_knockback()
	# 쓰러짐.
	_test_death()
	# 결과를 돌려준다.
	return results()


# 숨쉬기는 1.6초 주기 사인이고 최대 0.03 늘어나며 기울지 않는지.
func _test_idle() -> void:
	# 0초는 0.
	check("idle starts flat", is_equal_approx(UnitMotion.idle(0.0, 0.0).stretch, 0.0))
	# 주기의 1/4 (0.4초) 에서 최대.
	check("idle peaks at a quarter period", is_equal_approx(UnitMotion.idle(0.4, 0.0).stretch, 0.03))
	# 한 주기 뒤 같은 값.
	check("idle repeats every period", is_equal_approx(UnitMotion.idle(0.3, 1.0).stretch, UnitMotion.idle(1.9, 1.0).stretch))
	# 기울기 없음.
	check("idle does not lean", is_equal_approx(UnitMotion.idle(0.4, 0.0).lean, 0.0))


# 공격: 0.3 에서 웅크림(−0.12, 뒤로 8°), 0.5 에서 뻗음(0.12, 앞으로 −10°), 끝은 0. 돌진은 0.3 까지 0, 0.5 에서 1, 끝 0.
func _test_attack() -> void:
	# 예비동작.
	check("attack winds up", is_equal_approx(UnitMotion.attack(0.3).stretch, -0.12))
	# 예비동작 기울기.
	check("attack leans back on windup", is_equal_approx(UnitMotion.attack(0.3).lean, 8.0))
	# 타격.
	check("attack stretches on strike", is_equal_approx(UnitMotion.attack(0.5).stretch, 0.12))
	# 타격 기울기.
	check("attack leans forward on strike", is_equal_approx(UnitMotion.attack(0.5).lean, -10.0))
	# 끝.
	check("attack settles", is_equal_approx(UnitMotion.attack(1.0).stretch, 0.0))
	# 예비동작 동안 제자리.
	check("lunge holds during windup", is_equal_approx(UnitMotion.lunge_reach(0.3), 0.0))
	# 타격 순간 끝까지.
	check("lunge reaches at strike", is_equal_approx(UnitMotion.lunge_reach(UnitMotion.ATTACK_STRIKE), 1.0))
	# 끝은 제자리.
	check("lunge returns home", is_equal_approx(UnitMotion.lunge_reach(1.0), 0.0))
	# 범위 밖 t 는 잘린다.
	check("lunge clamps t", is_equal_approx(UnitMotion.lunge_reach(2.0), 0.0))


# 깡충: 0.2 에서 웅크림 −0.15, 0.9 에서 착지 눌림 −0.12, 높이는 0.55 에서 0.25.
func _test_hop() -> void:
	# 웅크림.
	check("hop crouches", is_equal_approx(UnitMotion.hop(0.2).stretch, -0.15))
	# 착지.
	check("hop squashes on landing", is_equal_approx(UnitMotion.hop(0.9).stretch, -0.12))
	# 최고점.
	check("hop peaks", is_equal_approx(UnitMotion.hop_height(0.55), 0.25))
	# 웅크리는 동안 바닥.
	check("hop stays grounded while crouching", is_equal_approx(UnitMotion.hop_height(0.2), 0.0))


# 피격: 0.15 에서 눌림 −0.1·뒤로 12°. 넉백은 0.15 에서 1, 0.6 부터 0.
func _test_hit_and_knockback() -> void:
	# 눌림.
	check("hit squashes", is_equal_approx(UnitMotion.hit(0.15).stretch, -0.1))
	# 젖힘.
	check("hit leans back", is_equal_approx(UnitMotion.hit(0.15).lean, 12.0))
	# 끝.
	check("hit settles", is_equal_approx(UnitMotion.hit(1.0).lean, 0.0))
	# 넉백 최대.
	check("knockback peaks", is_equal_approx(UnitMotion.knockback_reach(UnitMotion.KNOCKBACK_PEAK), 1.0))
	# 복귀.
	check("knockback returns", is_equal_approx(UnitMotion.knockback_reach(0.6), 0.0))
	# 시작.
	check("knockback starts home", is_equal_approx(UnitMotion.knockback_reach(0.0), 0.0))


# 쓰러짐: t² 로 85° 까지.
func _test_death() -> void:
	# 시작은 0.
	check("death starts upright", is_equal_approx(UnitMotion.death(0.0).lean, 0.0))
	# 절반이면 1/4.
	check("death accelerates", is_equal_approx(UnitMotion.death(0.5).lean, 85.0 * 0.25))
	# 끝.
	check("death topples", is_equal_approx(UnitMotion.death(1.0).lean, 85.0))
```

- [ ] **Step 2: 실패 확인** — `run_tests.gd` 에 파일을 추가하고 실행.

Expected: `test_unit_motion.gd` 가 `UnitMotion` 을 찾지 못해 suite FAIL.

- [ ] **Step 3: 구현** — `Scripts/view/unit_motion.gd`

```gdscript
## 한 장짜리 스프라이트에 생기를 주는 자세 곡선 모음 (유니티 UnitMotion 그대로).
## 진행률 t(0→1)를 넣으면 자세가 나온다. 자세는 발을 축으로 한 늘이기(stretch)와
## 기울기(lean, 도 단위, 양수 = 바라보는 방향의 뒤쪽)뿐이다.
class_name UnitMotion
# RefCounted: 노드가 아닌 가벼운 객체 (정적 함수만 쓴다).
extends RefCounted

## 한 순간의 자세.
class Pose:
	## 세로로 늘어난 정도 (0.1 = 10% 길어짐, 음수는 눌림).
	var stretch: float
	## 뒤로 젖힌 각도 (도).
	var lean: float

	## 늘이기와 기울기로 자세를 만든다.
	func _init(p_stretch: float = 0.0, p_lean: float = 0.0) -> void:
		# 늘이기.
		stretch = p_stretch
		# 기울기.
		lean = p_lean


## 숨쉬기 한 번의 주기 (초).
const IDLE_PERIOD: float = 1.6
## 숨쉬기로 늘어나는 최대 비율.
const IDLE_STRETCH: float = 0.03
## 쓰러질 때 끝까지 넘어가는 각도.
const DEATH_LEAN: float = 85.0
## 공격 예비동작이 끝나는 진행률.
const ATTACK_WINDUP_END: float = 0.3
## 무기가 닿는 진행률 (돌진이 가장 멀리 나간 순간).
const ATTACK_STRIKE: float = 0.5
## 넉백이 가장 멀리 밀린 진행률.
const KNOCKBACK_PEAK: float = 0.15

# 공격 자세 키.
const _ATTACK_TIMES: Array[float] = [0.0, ATTACK_WINDUP_END, ATTACK_STRIKE, 0.75, 1.0]
const _ATTACK_STRETCH: Array[float] = [0.0, -0.12, 0.12, -0.03, 0.0]
const _ATTACK_LEAN: Array[float] = [0.0, 8.0, -10.0, 2.0, 0.0]
# 돌진 거리 키.
const _LUNGE_TIMES: Array[float] = [0.0, ATTACK_WINDUP_END, ATTACK_STRIKE, 1.0]
const _LUNGE_VALUES: Array[float] = [0.0, 0.0, 1.0, 0.0]
# 깡충 자세 키.
const _HOP_TIMES: Array[float] = [0.0, 0.2, 0.35, 0.55, 0.85, 0.9, 1.0]
const _HOP_STRETCH: Array[float] = [0.0, -0.15, 0.1, 0.03, 0.02, -0.12, 0.0]
# 깡충 높이 키.
const _HOP_HEIGHT_TIMES: Array[float] = [0.0, 0.2, 0.55, 0.85, 1.0]
const _HOP_HEIGHT_VALUES: Array[float] = [0.0, 0.0, 0.25, 0.0, 0.0]
# 넉백 키.
const _KNOCKBACK_TIMES: Array[float] = [0.0, KNOCKBACK_PEAK, 0.6, 1.0]
const _KNOCKBACK_VALUES: Array[float] = [0.0, 1.0, 0.0, 0.0]
# 피격 자세 키.
const _HIT_TIMES: Array[float] = [0.0, 0.15, 0.5, 1.0]
const _HIT_STRETCH: Array[float] = [0.0, -0.1, 0.03, 0.0]
const _HIT_LEAN: Array[float] = [0.0, 12.0, -3.0, 0.0]


## 대기 중 숨쉬기. phase 로 유닛마다 박자를 어긋나게 한다.
static func idle(time: float, phase: float) -> Pose:
	# 사인 한 주기가 IDLE_PERIOD 초.
	return Pose.new(IDLE_STRETCH * sin(TAU * time / IDLE_PERIOD + phase))


## 공격 자세: 웅크렸다가(예비동작) 뻗으며 앞으로 숙인다.
static func attack(t: float) -> Pose:
	# 늘이기와 기울기를 각각 키에서 읽는다.
	return Pose.new(_eval(_ATTACK_TIMES, _ATTACK_STRETCH, t), _eval(_ATTACK_TIMES, _ATTACK_LEAN, t))


## 공격할 때 몸이 앞으로 나간 정도 (0 = 제자리, 1 = 끝까지).
static func lunge_reach(t: float) -> float:
	# 예비동작 동안은 제자리.
	return _eval(_LUNGE_TIMES, _LUNGE_VALUES, t)


## 깡충 자세: 웅크림 → 늘어남 → 착지 눌림.
static func hop(t: float) -> Pose:
	# 늘이기만 쓴다.
	return Pose.new(_eval(_HOP_TIMES, _HOP_STRETCH, t))


## 깡충 높이 (3D 단위).
static func hop_height(t: float) -> float:
	# 웅크리는 동안은 바닥.
	return _eval(_HOP_HEIGHT_TIMES, _HOP_HEIGHT_VALUES, t)


## 피격 자세: 눌리며 뒤로 젖혔다가 돌아온다.
static func hit(t: float) -> Pose:
	# 늘이기와 기울기를 각각 키에서 읽는다.
	return Pose.new(_eval(_HIT_TIMES, _HIT_STRETCH, t), _eval(_HIT_TIMES, _HIT_LEAN, t))


## 맞아서 밀려난 정도 (0 = 제자리, 1 = 끝까지). 확 밀렸다가 천천히 돌아온다.
static func knockback_reach(t: float) -> float:
	# 0.15 에서 최대, 0.6 부터 제자리.
	return _eval(_KNOCKBACK_TIMES, _KNOCKBACK_VALUES, t)


## 쓰러짐: 처음엔 천천히, 끝에서 빠르게 넘어간다.
static func death(t: float) -> Pose:
	# 제곱이라 가속한다.
	return Pose.new(0.0, DEATH_LEAN * t * t)


# 키 사이를 smoothstep 으로 잇는다. 키마다 속도가 0 이 되어 동작의 "멈칫"이 생긴다.
static func _eval(times: Array[float], values: Array[float], t: float) -> float:
	# 범위 밖 진행률은 자른다.
	var clamped: float = clampf(t, 0.0, 1.0)
	# 이 진행률이 들어 있는 구간을 찾는다.
	for i in range(1, times.size()):
		if clamped <= times[i]:
			# 구간 안에서의 진행률.
			var local: float = inverse_lerp(times[i - 1], times[i], clamped)
			# 부드럽게 섞는다.
			return lerpf(values[i - 1], values[i], smoothstep(0.0, 1.0, local))
	# 마지막 키 값.
	return values[values.size() - 1]
```

- [ ] **Step 4: 통과 확인** — 테스트 실행. Expected: `test_unit_motion.gd` 전부 PASS, 전체 통과.

- [ ] **Step 5: 커밋**

```bash
git add Scripts/view/unit_motion.gd tests/test_unit_motion.gd tests/run_tests.gd
git commit -m "feat: port Unity unit motion curves

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: 유닛 셰이더와 `UnitView` 개편

**Files:**
- Create: `Shaders/unit_sprite.gdshader`
- Modify: `Scripts/view/unit_view.gd` (전체 교체 — 아래 코드)
- Modify: `Scripts/view/battle_playback.gd:231-233` (피격 대기 시간)
- Modify: `tests/test_unit_view.gd` (`_test_setup_builds_parts` 교체 + 새 검사)
- Modify: `tests/test_board_3d.gd:148,150`

**Interfaces:**
- Consumes: `UnitMotion.Pose`, `UnitMotion.idle/attack/lunge_reach/hop/hop_height/hit/death` (Task 2), `UnitData.idle_sheet/attack_sheet/hit_sheet` (Task 1)
- Produces (B 단계가 쓴다):
  - `UnitView.setup(p_unit: Unit, texture: Texture2D) -> void` (시그니처 유지)
  - `var body: Node3D`, `var pose: Node3D`, `var sprite: MeshInstance3D`, `var body_material: ShaderMaterial`, `var ring: MeshInstance3D`, `var shadow: MeshInstance3D`, `var still_texture: Texture2D`
  - `func attack_duration() -> float`, `func hit_duration() -> float`
  - `func lunge_toward(world_target: Vector3, distance: float = LUNGE_DISTANCE) -> void` (await 가능)
  - `func flash_and_shake() -> void`, `func hop() -> void`, `func fade_out() -> void`, `func reset_pose() -> void`
  - `func tick_idle(time: float) -> void`, `func apply_pose(p: UnitMotion.Pose) -> void`
  - `func show_frame(sheet: Texture2D, index: int) -> void`, `func show_sheet_progress(sheet: Texture2D, t: float) -> void`
  - `static func frame_count(sheet: Texture2D) -> int`, `static func billboard_rotation(camera_forward: Vector3, tilt_deg: float) -> Vector3`
  - 셰이더 파라미터 이름: `texture_albedo`, `frame`, `frame_count`, `tint`, `flash`, `fade`

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test_unit_view.gd` 를 다음처럼 바꾼다.

`run()` 을 교체:

```gdscript
# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# setup 이 몸·셰이더·고리·클릭 몸체를 만드는지.
	_test_setup_builds_parts()
	# 체력 글자와 막대 폭·위치.
	_test_stats_text_and_bar()
	# 체력·방어도를 따로 갱신.
	_test_partial_updates()
	# 원래 자리와 생존 표시.
	_test_home_and_alive()
	# 애니메이션 띠 프레임 선택.
	_test_sheet_frames()
	# 띠 유무에 따른 대기 동작과 연출 시간.
	_test_idle_and_durations()
	# 자세 적용과 되돌리기.
	_test_pose_and_reset()
	# 빌보드 회전 계산.
	_test_billboard_rotation()
	# 결과를 돌려준다.
	return results()
```

`_view` 를 띠를 받을 수 있게 교체:

```gdscript
# 체력 30 짜리 테스트 유닛 화면을 만든다. ally 가 true 면 아군. sheets 는 [idle, attack, hit] (null 허용).
func _view(ally: bool, sheets: Array = [null, null, null]) -> UnitView:
	# 편에 맞는 데이터.
	var data: UnitData = AllyDataScript.new() if ally else EnemyDataScript.new()
	# id.
	data.id = &"tester"
	# 이름.
	data.display_name = "테스터"
	# 최대 체력.
	data.max_hp = 30
	# 대기 띠.
	data.idle_sheet = sheets[0]
	# 공격 띠.
	data.attack_sheet = sheets[1]
	# 피격 띠.
	data.hit_sheet = sheets[2]
	# 편.
	var team: Unit.Team = Unit.Team.ALLY if ally else Unit.Team.ENEMY
	# 화면 객체.
	var view := UnitView.new()
	# 규칙 유닛과 텍스처로 채운다.
	view.setup(Unit.new(0, data, team, Vector2i(0, 1)), _texture())
	# 돌려준다.
	return view


# 64px 프레임 16장짜리 빈 띠 (1024×64).
func _sheet() -> Texture2D:
	# 빈 이미지로 텍스처를 만든다.
	return ImageTexture.create_from_image(Image.create(1024, 64, false, Image.FORMAT_RGBA8))
```

`_test_setup_builds_parts` 교체:

```gdscript
# setup 이 받은 그림·이름을 쓰고, 비율대로 1.6 높이 판을 만들고, 클릭 레이어·좌우 반전·고리 색을 정하는지.
func _test_setup_builds_parts() -> void:
	# 10×20 그림의 아군.
	var view: UnitView = _view(true)
	# 정지 그림을 기억한다.
	check("still texture kept", view.still_texture != null and view.still_texture.get_height() == 20)
	# 띠가 없으면 셰이더가 정지 그림을 쓴다.
	check("shader shows the still texture", view.body_material.get_shader_parameter("texture_albedo") == view.still_texture)
	# 이름 글자.
	check_eq("name label", view.name_label.text, "테스터")
	# 판 크기 = (1.6 × 10/20, 1.6).
	check("sprite quad keeps the texture aspect", (view.sprite.mesh as QuadMesh).size.is_equal_approx(Vector2(0.8, UnitView.SPRITE_HEIGHT)))
	# 발이 원점: 판 중심이 절반 높이.
	check("sprite stands on its feet", is_equal_approx(view.sprite.position.y, UnitView.SPRITE_HEIGHT / 2.0))
	# 클릭 몸체.
	check_eq("pick body on the board pick layer", view.pick_body.collision_layer, UnitView.PICK_LAYER_BIT)
	# 아군은 오른쪽을 본다.
	check("ally faces right", is_equal_approx(view.sprite.scale.x, 1.0))
	# 아군 고리 색.
	check_eq("ally ring colour", (view.ring.material_override as StandardMaterial3D).albedo_color, UnitView.ALLY_RING_COLOR)
	# 몸 계층: Body → Pose → Sprite.
	check("sprite sits under pose under body", view.sprite.get_parent() == view.pose and view.pose.get_parent() == view.body)
	# 지운다.
	view.free()

	# 적군.
	var enemy: UnitView = _view(false)
	# 적은 왼쪽을 본다.
	check("enemy is mirrored", is_equal_approx(enemy.sprite.scale.x, -1.0))
	# 적 고리 색.
	check_eq("enemy ring colour", (enemy.ring.material_override as StandardMaterial3D).albedo_color, UnitView.ENEMY_RING_COLOR)
	# 지운다.
	enemy.free()
```

새 함수들을 파일 끝에 추가:

```gdscript
# 띠는 너비 ÷ 높이 장이고, 진행률·번호가 마지막 프레임을 넘지 않는지.
func _test_sheet_frames() -> void:
	# 16장 띠.
	var sheet: Texture2D = _sheet()
	# 프레임 수.
	check_eq("frame count from sheet size", UnitView.frame_count(sheet), 16)
	# 대기 띠가 있는 아군.
	var view: UnitView = _view(true, [sheet, null, null])
	# 처음엔 대기 띠의 시작 프레임 (unit_id 0 → 0).
	check("idle sheet shown on setup", view.body_material.get_shader_parameter("texture_albedo") == sheet)
	# 셰이더 프레임 수.
	check_eq("shader frame count", view.body_material.get_shader_parameter("frame_count"), 16)
	# 진행률 끝은 마지막 프레임.
	view.show_sheet_progress(sheet, 1.0)
	# 15번.
	check_eq("progress end is the last frame", view.body_material.get_shader_parameter("frame"), 15)
	# 번호가 넘치면 감는다.
	view.show_frame(sheet, 18)
	# 18 % 16 = 2.
	check_eq("frame index wraps", view.body_material.get_shader_parameter("frame"), 2)
	# 지운다.
	view.free()


# 대기: 띠가 있으면 8fps 프레임, 없으면 숨쉬기 자세. 연출 시간은 띠 유무로 정해진다.
func _test_idle_and_durations() -> void:
	# 띠 없는 아군.
	var plain: UnitView = _view(true)
	# 0.4초 (숨쉬기 최대).
	plain.tick_idle(0.4)
	# 세로로 늘었다 (phase = unit_id 0 × 1.7 = 0).
	check("idle breathes without a sheet", is_equal_approx(plain.pose.scale.y, 1.03))
	# 코드 공격 시간.
	check("attack uses action time without sheet", is_equal_approx(plain.attack_duration(), UnitView.ACTION_TIME))
	# 코드 피격 시간.
	check("hit uses flash time without sheet", is_equal_approx(plain.hit_duration(), UnitView.FLASH_TIME))
	# 지운다.
	plain.free()

	# 대기·피격 띠만 있는 유닛 (brute 와 같은 구성).
	var mixed: UnitView = _view(true, [_sheet(), null, _sheet()])
	# 1초 → 8번째 프레임.
	mixed.tick_idle(1.0)
	# 8.
	check_eq("idle sheet plays at 8 fps", mixed.body_material.get_shader_parameter("frame"), 8)
	# 띠 재생 중에는 자세를 건드리지 않는다.
	check("sheet idle keeps pose scale", mixed.pose.scale.is_equal_approx(Vector3.ONE))
	# 공격은 코드 시간, 피격은 띠 시간.
	check("mixed sheets pick durations per action", is_equal_approx(mixed.attack_duration(), UnitView.ACTION_TIME) and is_equal_approx(mixed.hit_duration(), UnitView.HIT_FRAME_TIME))
	# 지운다.
	mixed.free()


# 기울기는 적에게서 거울상이고, reset_pose 가 자세·셰이더 값을 모두 되돌리는지.
func _test_pose_and_reset() -> void:
	# 아군과 적.
	var ally: UnitView = _view(true)
	var enemy: UnitView = _view(false)
	# 같은 자세 (뒤로 10°).
	ally.apply_pose(UnitMotion.Pose.new(0.1, 10.0))
	enemy.apply_pose(UnitMotion.Pose.new(0.1, 10.0))
	# 아군 +10°, 적 −10°.
	check("lean mirrors for enemies", is_equal_approx(ally.pose.rotation.z, deg_to_rad(10.0)) and is_equal_approx(enemy.pose.rotation.z, deg_to_rad(-10.0)))
	# 늘이면 옆으로 얇아진다.
	check("stretch keeps volume", ally.pose.scale.is_equal_approx(Vector3(0.95, 1.1, 1.0)))
	# 연출이 끊긴 상태를 흉내 낸다.
	ally.body_material.set_shader_parameter("fade", 0.3)
	ally.body_material.set_shader_parameter("tint", UnitView.FLASH_TINT)
	ally.body.position = Vector3(0.08, 0.2, 0.0)
	# 되돌린다.
	ally.reset_pose()
	# 셰이더 값.
	check("reset_pose restores shader state", is_equal_approx(ally.body_material.get_shader_parameter("fade"), 1.0) and ally.body_material.get_shader_parameter("tint") == Color.WHITE)
	# 자세와 몸 위치.
	check("reset_pose restores pose", ally.pose.scale.is_equal_approx(Vector3.ONE) and ally.body.position.is_equal_approx(Vector3.ZERO))
	# 지운다.
	ally.free()
	enemy.free()


# 카메라 방향의 수평 성분을 보고 Y축만 돌며, 위쪽은 카메라 반대로 기울이는지.
func _test_billboard_rotation() -> void:
	# 기본 카메라(+z 에서 −z 를 내려다봄).
	var front: Vector3 = UnitView.billboard_rotation(Vector3(0.0, -0.7, -0.7), 20.0)
	# 돌지 않고 20° 뒤로.
	check("front camera keeps yaw 0", front.is_equal_approx(Vector3(deg_to_rad(-20.0), 0.0, 0.0)))
	# +x 를 보는 카메라 → 판이 −x 쪽(카메라)을 보도록 −90°.
	var side: Vector3 = UnitView.billboard_rotation(Vector3(1.0, 0.0, 0.0), 20.0)
	# −90°.
	check("side camera turns the body", is_equal_approx(side.y, deg_to_rad(-90.0)))
	# 수평 성분이 없으면(바로 아래를 봄) 돌지 않는다.
	check("billboard without horizontal forward keeps yaw 0", is_equal_approx(UnitView.billboard_rotation(Vector3.DOWN, 20.0).y, 0.0))
```

`tests/test_board_3d.gd` 148·150 줄을 교체:

```gdscript
	check("unit sprite wins over placeholder", board.view_for(ally).still_texture == own_sprite)
```

```gdscript
	check("placeholder when no sprite", board.view_for(foe).still_texture == placeholder)
```

- [ ] **Step 2: 실패 확인** — 테스트 실행. Expected: `test_unit_view.gd` 가 `still_texture`/`body_material` 등이 없어 FAIL.

- [ ] **Step 3: 셰이더 작성** — `Shaders/unit_sprite.gdshader`

```glsl
// 유닛·소품 몸 셰이더. 가로 띠 텍스처에서 한 프레임을 고르고, 붉은/흰 번쩍임과 디더 페이드를 한다.
// 알파 잘라내기라 그림자를 드리우고 깊이 정렬 문제가 없다.
shader_type spatial;
// 적은 판을 좌우로 뒤집어(음수 스케일) 쓰므로 양면을 그린다.
render_mode cull_disabled;

// 그림 (정지 그림 또는 64px 프레임을 가로로 이은 띠). 픽셀이 뭉개지지 않게 최근접 샘플링.
uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_disable;
// 보여 줄 프레임 번호 (0부터).
uniform int frame = 0;
// 띠의 프레임 수 (정지 그림은 1).
uniform int frame_count = 1;
// 곱하는 색 (평소 흰색, 피격 때 붉은색).
uniform vec3 tint : source_color = vec3(1.0);
// 1 이면 실루엣 전체가 흰색 (타격 순간).
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// 1 이면 다 보이고 0 이면 다 사라진다. 화면 좌표 디더로 픽셀을 버린다.
uniform float fade : hint_range(0.0, 1.0) = 1.0;

// 4×4 Bayer 행렬 문턱값 ((i + 0.5) / 16).
const float BAYER[16] = float[](
	0.03125, 0.53125, 0.15625, 0.65625,
	0.78125, 0.28125, 0.90625, 0.40625,
	0.21875, 0.71875, 0.09375, 0.59375,
	0.96875, 0.46875, 0.84375, 0.34375);

void fragment() {
	// 띠에서 이 프레임 칸으로 가로 좌표를 옮긴다.
	float count = float(max(frame_count, 1));
	vec2 uv = vec2((float(frame) + UV.x) / count, UV.y);
	vec4 color = texture(texture_albedo, uv);
	// 사라지는 중이면 화면 픽셀 위치별 문턱값보다 fade 가 작을 때 버린다.
	if (fade < 1.0) {
		int x = int(FRAGCOORD.x) % 4;
		int y = int(FRAGCOORD.y) % 4;
		if (fade <= BAYER[y * 4 + x]) {
			discard;
		}
	}
	// 흰 번쩍임은 색을 흰색으로 섞고 그만큼 스스로 빛나게 해서 조명과 상관없이 하얗게 보인다.
	ALBEDO = mix(color.rgb * tint, vec3(1.0), flash);
	EMISSION = vec3(flash);
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
```

- [ ] **Step 4: `UnitView` 교체** — `Scripts/view/unit_view.gd` 전체를 아래로 바꾼다. 기존의 `set_stats`·`set_hp`·`set_block`·`set_home`·`slide_to`·`set_alive`·`pop_text`·`_refresh_stats`·`_make_label`·`_make_bar` 는 **기존 코드를 그대로** 두고(아래에서 `# (기존 그대로)` 로 표시한 자리), 나머지를 교체한다. `_shadow_material` 은 삭제한다.

```gdscript
## 3D 보드 위에 서 있는 유닛 한 명의 화면 표현.
## 카메라를 향해 서는 몸(빌보드) 위에 픽셀 그림·애니메이션 띠를 그리고, 발밑 그림자·진영 고리,
## 머리 위 이름·체력 바·수치 글자, 클릭 판정용 충돌 상자를 가진다. 규칙 상태는 바꾸지 않고 보여 주기만 한다.
class_name UnitView
# Node3D: 3D 공간에 위치를 가지는 노드.
extends Node3D

## 유닛·소품 몸 셰이더 (프레임·번쩍임·디더 페이드).
const UNIT_SHADER: Shader = preload("res://Shaders/unit_sprite.gdshader")

## 스프라이트가 화면에 그려질 높이 (3D 단위). 그림 크기와 상관없이 이 높이로 맞춘다.
const SPRITE_HEIGHT: float = 1.6
## 발을 축으로 카메라 반대쪽으로 눕히는 각도. 44° 로 내려다볼 때 판이 덜 눌려 보인다.
const BODY_TILT_DEG: float = 20.0
## 대기 띠의 초당 프레임 수.
const IDLE_FPS: float = 8.0
## 공격 띠 한 번의 길이. 그려진 동작은 코드 모션보다 길어야 읽힌다 (16장 기준 16fps).
const ATTACK_FRAME_TIME: float = 1.0
## 피격 띠 한 번의 길이 (16장 기준 20fps).
const HIT_FRAME_TIME: float = 0.8
## 피격 때 곱하는 붉은색.
const FLASH_TINT := Color(1.0, 0.45, 0.45)
## 발밑 접지 그림자 색.
const CONTACT_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.7)
## 아군 진영 고리 색.
const ALLY_RING_COLOR := Color(0.3, 0.55, 1.0, 0.8)
## 적군 진영 고리 색.
const ENEMY_RING_COLOR := Color(1.0, 0.3, 0.25, 0.8)
## 체력 바가 놓이는 높이 (발밑 기준).
const OVERHEAD_Y: float = 2.0
## 체력 바 전체 폭.
const HP_BAR_WIDTH: float = 0.9
## 체력 바 높이.
const HP_BAR_HEIGHT: float = 0.1
## 클릭 광선이 맞히는 충돌 레이어 값 (비트 값 2 = 2번 레이어). 타일도 같은 레이어를 쓴다.
const PICK_LAYER_BIT: int = 2
## 돌진할 때 앞으로 나가는 거리.
const LUNGE_DISTANCE: float = 0.4
## 띠 없는 공격·깡충 한 번에 걸리는 시간.
const ACTION_TIME: float = 0.25
## 띠 없는 피격 연출 시간.
const FLASH_TIME: float = 0.24
## 떠오르는 숫자가 사라지기까지 시간.
const POP_TIME: float = 0.6
## 쓰러질 때 서서히 사라지는 시간.
const FADE_TIME: float = 0.4
## 한 칸 이동할 때 미끄러지는 시간.
const MOVE_TIME: float = 0.25
# 피격 흔들림의 좌우 위치 키 (4구간).
const _SHAKE_KEYS: Array[float] = [0.0, 0.08, -0.08, 0.05, 0.0]

## 보여 주는 규칙 유닛.
var unit: Unit
## 유닛이 원래 서 있는 칸의 위치. 돌진 뒤 이 위치로 돌아온다.
var home_position: Vector3 = Vector3.ZERO
## 카메라를 향해 도는 몸 피벗 (발 위치). 깡충·흔들림은 이 노드를 움직인다.
var body: Node3D
## 발을 축으로 늘이기·기울이기를 맡는 피벗.
var pose: Node3D
## 그림을 그리는 사각형 판.
var sprite: MeshInstance3D
## 판의 셰이더 재질 (유닛마다 따로라 번쩍임이 번지지 않는다).
var body_material: ShaderMaterial
## 데이터의 정지 그림 (없으면 임시 그림).
var still_texture: Texture2D
## 대기 띠 (없으면 null).
var idle_sheet: Texture2D
## 공격 띠 (없으면 null).
var attack_sheet: Texture2D
## 피격 띠 (없으면 null).
var hit_sheet: Texture2D
## 머리 위 이름 글자.
var name_label: Label3D
## 체력 바 아래 "현재/최대 방N" 글자.
var stat_label: Label3D
## 체력 바 배경 (어두운 막대).
var hp_back: MeshInstance3D
## 체력 바 채움 (초록 막대, 체력 비율만큼 폭이 준다).
var hp_fill: MeshInstance3D
## 발밑 접지 그림자.
var shadow: MeshInstance3D
## 발밑 진영 고리.
var ring: MeshInstance3D
## 클릭 판정용 물리 몸체.
var pick_body: StaticBody3D
## pick_body 의 충돌 모양 (쓰러지면 꺼서 클릭이 통과하게 한다).
var pick_shape: CollisionShape3D

## 표시 중인 체력.
var _hp: int = 0
## 표시 중인 최대 체력 (0 으로 나누지 않게 최소 1).
var _max_hp: int = 1
## 표시 중인 방어도.
var _block: int = 0
## 아군 1, 적 −1 (적은 그림을 좌우로 뒤집어 왼쪽을 본다).
var _facing: float = 1.0
## 연출 중이면 true. 그동안은 대기 동작을 멈춘다 (연출이 자세를 잡는다).
var _acting: bool = false
## 대기 동작용 누적 시간.
var _clock: float = 0.0
## 숨쉬기 박자를 유닛마다 어긋나게 하는 위상.
var _idle_phase: float = 0.0
## 대기 띠 시작 프레임을 유닛마다 어긋나게 하는 값.
var _idle_frame_offset: int = 0

# 모든 유닛이 같이 쓰는 그림자·고리 텍스처 (한 번만 만든다).
static var _shadow_texture: Texture2D
static var _ring_texture: Texture2D


## 유닛과 정지 그림을 받아 필요한 자식 노드를 모두 만든다. 트리에 붙이기 전에 불러도 된다.
func setup(p_unit: Unit, texture: Texture2D) -> void:
	# 보여 줄 유닛을 기억한다.
	unit = p_unit
	# 적은 왼쪽을 보도록 뒤집는다.
	_facing = 1.0 if unit.is_ally() else -1.0
	# 그림과 띠를 기억한다.
	still_texture = texture
	idle_sheet = unit.data.idle_sheet
	attack_sheet = unit.data.attack_sheet
	hit_sheet = unit.data.hit_sheet
	# 유닛마다 숨쉬기·대기 프레임을 어긋나게 한다.
	_idle_phase = unit.unit_id * 1.7
	_idle_frame_offset = unit.unit_id * 5

	# --- 몸 ---
	# 카메라를 향해 도는 피벗.
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	# 늘이기·기울이기 피벗.
	pose = Node3D.new()
	pose.name = "Pose"
	body.add_child(pose)
	# 그림 판. 높이 1.6 에 그림 비율대로 폭을 맞춘다.
	sprite = MeshInstance3D.new()
	sprite.name = "Sprite"
	var quad := QuadMesh.new()
	quad.size = Vector2(SPRITE_HEIGHT * float(texture.get_width()) / float(texture.get_height()), SPRITE_HEIGHT)
	sprite.mesh = quad
	# 판 중심을 절반 높이에 두어 발이 피벗에 닿게 한다.
	sprite.position = Vector3(0.0, SPRITE_HEIGHT / 2.0, 0.0)
	# 적은 좌우 반전.
	sprite.scale = Vector3(_facing, 1.0, 1.0)
	# 유닛마다 따로 쓰는 셰이더 재질.
	body_material = ShaderMaterial.new()
	body_material.shader = UNIT_SHADER
	sprite.material_override = body_material
	pose.add_child(sprite)
	# 대기 모습으로 시작한다.
	_return_to_idle()

	# --- 발밑 ---
	# 접지 그림자.
	shadow = _floor_decal(_get_shadow_texture(), Vector2(0.9, 0.5), 0.01, CONTACT_SHADOW_COLOR)
	# 진영 고리.
	ring = _floor_decal(_get_ring_texture(), Vector2(0.95, 0.6), 0.012, ALLY_RING_COLOR if unit.is_ally() else ENEMY_RING_COLOR)

	# --- 이름·체력 바·수치 글자·클릭 판정 ---
	# (기존 setup 의 "--- 이름 ---" 부터 "set_stats(unit.hp, ...)" 까지를 그대로 둔다.
	#  단, 클릭 판정 모양의 위치는 기존 `_sprite_home` 대신 Vector3(0.0, SPRITE_HEIGHT / 2.0, 0.0).)


## 매 프레임: 몸을 카메라 쪽으로 돌리고 대기 동작을 진행한다.
func _process(delta: float) -> void:
	# 지금 화면을 그리는 3D 카메라 (헤드리스·전환 중에는 없을 수 있다).
	var camera: Camera3D = get_viewport().get_camera_3d()
	# 있으면 그 방향으로 돌린다.
	if camera != null:
		body.rotation = billboard_rotation(-camera.global_basis.z, BODY_TILT_DEG)
	# 시간을 쌓는다 (게임 시간이라 히트스톱 때 같이 멈춘다).
	_clock += delta
	# 대기 동작.
	tick_idle(_clock)


## 카메라 시선(camera_forward)의 수평 성분을 보도록 Y축만 돌리고, 위쪽을 카메라 반대로 tilt_deg 만큼 눕힌 회전.
static func billboard_rotation(camera_forward: Vector3, tilt_deg: float) -> Vector3:
	# 높이 성분을 버린 시선.
	var flat := Vector3(camera_forward.x, 0.0, camera_forward.z)
	# 바로 아래를 보면 돌 방향이 없다.
	if flat.length_squared() == 0.0:
		return Vector3(deg_to_rad(-tilt_deg), 0.0, 0.0)
	# 판의 앞(+Z)이 카메라 쪽(시선 반대)을 보게 한다. 회전 순서가 YXZ 라 Y 로 돈 뒤 로컬 X 로 눕는다.
	return Vector3(deg_to_rad(-tilt_deg), atan2(-flat.x, -flat.z), 0.0)


## 띠 텍스처의 프레임 수 (너비 ÷ 높이, 최소 1).
static func frame_count(sheet: Texture2D) -> int:
	# 정수 나눗셈이 의도다 (64px 프레임 단위).
	@warning_ignore("integer_division")
	return maxi(1, sheet.get_width() / sheet.get_height())


## 띠의 index 번 프레임을 보인다 (넘치면 감는다).
func show_frame(sheet: Texture2D, index: int) -> void:
	# 이 띠의 프레임 수.
	var count: int = frame_count(sheet)
	# 셰이더에 띠와 프레임을 넘긴다.
	body_material.set_shader_parameter("texture_albedo", sheet)
	body_material.set_shader_parameter("frame_count", count)
	body_material.set_shader_parameter("frame", posmod(index, count))


## 진행률 t(0~1)에 해당하는 띠 프레임을 보인다. 끝은 마지막 프레임에 머문다.
func show_sheet_progress(sheet: Texture2D, t: float) -> void:
	# 이 띠의 프레임 수.
	var count: int = frame_count(sheet)
	# 진행률을 프레임 번호로.
	show_frame(sheet, mini(int(floor(t * count)), count - 1))


## 대기 동작 한 번: 띠가 있으면 8fps 프레임, 없으면 숨쉬기 자세. 연출 중이면 아무것도 안 한다.
func tick_idle(time: float) -> void:
	# 연출이 자세를 잡고 있다.
	if _acting:
		return
	# 그려진 대기 동작.
	if idle_sheet != null:
		show_frame(idle_sheet, int(floor(time * IDLE_FPS)) + _idle_frame_offset)
		return
	# 코드 숨쉬기.
	apply_pose(UnitMotion.idle(time, _idle_phase))


## 자세를 몸에 적용한다. 위로 늘면 옆으로 얇아져 부피가 유지돼 보인다. 기울기는 바라보는 방향의 뒤쪽.
func apply_pose(p: UnitMotion.Pose) -> void:
	# 늘이기.
	pose.scale = Vector3(1.0 - p.stretch * 0.5, 1.0 + p.stretch, 1.0)
	# 적은 반대로 기운다.
	pose.rotation = Vector3(0.0, 0.0, deg_to_rad(p.lean * _facing))


## 공격 한 번의 길이 (띠가 있으면 띠 길이).
func attack_duration() -> float:
	return ATTACK_FRAME_TIME if attack_sheet != null else ACTION_TIME


## 피격 한 번의 길이 (띠가 있으면 띠 길이).
func hit_duration() -> float:
	return HIT_FRAME_TIME if hit_sheet != null else FLASH_TIME


# (기존 그대로) set_stats / set_hp / set_block / set_home / slide_to


## 연출 도중 끊겼을 수 있는 자세·위치·셰이더 값을 기본으로 되돌린다.
func reset_pose() -> void:
	# 원래 칸 위치로.
	position = home_position
	# 깡충·흔들림 되돌림.
	body.position = Vector3.ZERO
	# 연출 끝.
	_acting = false
	# 기본 자세.
	apply_pose(UnitMotion.Pose.new())
	# 대기 그림.
	_return_to_idle()
	# 색·번쩍임·투명도.
	body_material.set_shader_parameter("tint", Color.WHITE)
	body_material.set_shader_parameter("flash", 0.0)
	body_material.set_shader_parameter("fade", 1.0)


# (기존 그대로) set_alive


## 목표 쪽으로 distance 만큼 나갔다 돌아온다 (음수면 뒤로 물러나는 반동). 끝날 때까지 await 할 수 있다.
func lunge_toward(world_target: Vector3, distance: float = LUNGE_DISTANCE) -> void:
	# 원래 위치에서 목표까지의 수평 방향.
	var direction: Vector3 = world_target - home_position
	direction.y = 0.0
	# 길이가 0 이 아니면 길이 1 로.
	if direction.length() > 0.0:
		direction = direction.normalized()
	# 연출 시작.
	_acting = true
	# 0→1 진행률로 한 걸음씩 그린다.
	var tween: Tween = create_tween()
	tween.tween_method(_lunge_step.bind(home_position, home_position + direction * distance), 0.0, 1.0, attack_duration())
	await tween.finished
	# 연출 끝, 대기 그림으로.
	_acting = false
	_return_to_idle()


# 돌진 한 순간: 위치는 돌진 곡선, 모습은 공격 띠 또는 공격 자세 (둘을 겹치면 과해진다).
func _lunge_step(t: float, home: Vector3, lunge: Vector3) -> void:
	# 위치.
	position = home.lerp(lunge, UnitMotion.lunge_reach(t))
	# 그려진 공격.
	if attack_sheet != null:
		show_sheet_progress(attack_sheet, t)
	# 코드 공격 자세.
	else:
		apply_pose(UnitMotion.attack(t))


## 제자리에서 한 번 뛴다 (방어·휴식 행동 표시). 끝날 때까지 await 할 수 있다.
func hop() -> void:
	# 연출 시작.
	_acting = true
	# 0→1 진행률.
	var tween: Tween = create_tween()
	tween.tween_method(_hop_step, 0.0, 1.0, ACTION_TIME)
	await tween.finished
	# 바닥으로.
	body.position = Vector3.ZERO
	# 연출 끝.
	_acting = false


# 깡충 한 순간: 높이와 자세.
func _hop_step(t: float) -> void:
	# 높이.
	body.position = Vector3(0.0, UnitMotion.hop_height(t), 0.0)
	# 웅크림·늘어남.
	apply_pose(UnitMotion.hop(t))


## 피격 연출: 피격 띠(또는 움찔 자세) + 붉은 번쩍임 2회 + 좌우 흔들림. 끝날 때까지 await 할 수 있다.
func flash_and_shake() -> void:
	# 연출 시작.
	_acting = true
	# 0→1 진행률.
	var tween: Tween = create_tween()
	tween.tween_method(_hit_step, 0.0, 1.0, hit_duration())
	await tween.finished
	# 제자리·원래 색.
	body.position = Vector3.ZERO
	body_material.set_shader_parameter("tint", Color.WHITE)
	# 연출 끝, 대기 그림으로.
	_acting = false
	_return_to_idle()


# 피격 한 순간: 모습, 4구간 중 0·2번째 붉은색, 좌우 흔들림.
func _hit_step(t: float) -> void:
	# 그려진 피격.
	if hit_sheet != null:
		show_sheet_progress(hit_sheet, t)
	# 코드 움찔 자세.
	else:
		apply_pose(UnitMotion.hit(t))
	# 몇 번째 구간인지 (0~3).
	var quarter: int = mini(int(t * 4.0), 3)
	# 짝수 구간은 붉게.
	body_material.set_shader_parameter("tint", FLASH_TINT if quarter % 2 == 0 and t < 1.0 else Color.WHITE)
	# 구간 안 진행률로 흔들림 키 사이를 잇는다.
	var local: float = t * 4.0 - quarter
	body.position = Vector3(lerpf(_SHAKE_KEYS[quarter], _SHAKE_KEYS[quarter + 1], local), 0.0, 0.0)


# (기존 그대로) pop_text


## 쓰러짐 연출: 막대·그림자·고리를 바로 숨기고, 넘어지며 픽셀이 흩어져 사라진 뒤 숨긴다.
func fade_out() -> void:
	# 사라지는 동안에도 클릭되지 않게 판정을 끈다.
	pick_shape.disabled = true
	# 체력 바·발밑 표시를 숨긴다.
	hp_back.visible = false
	hp_fill.visible = false
	shadow.visible = false
	ring.visible = false
	# 연출 시작 (끝나도 숨겨지므로 되돌리지 않는다).
	_acting = true
	# 0→1 진행률.
	var tween: Tween = create_tween()
	tween.tween_method(_fade_step, 0.0, 1.0, FADE_TIME)
	await tween.finished
	# 완전히 숨긴다.
	visible = false


# 쓰러짐 한 순간: 넘어지는 자세, 디더 페이드, 글자 투명도.
func _fade_step(t: float) -> void:
	# 넘어짐.
	apply_pose(UnitMotion.death(t))
	# 남은 불투명도.
	var alpha: float = 1.0 - t
	# 몸.
	body_material.set_shader_parameter("fade", alpha)
	# 글자와 외곽선.
	name_label.modulate.a = alpha
	name_label.outline_modulate.a = alpha
	stat_label.modulate.a = alpha
	stat_label.outline_modulate.a = alpha


# 대기 모습: 대기 띠의 시작 프레임, 없으면 정지 그림.
func _return_to_idle() -> void:
	# 띠가 있으면 그 첫 프레임.
	if idle_sheet != null:
		show_frame(idle_sheet, _idle_frame_offset)
		return
	# 정지 그림 한 장.
	body_material.set_shader_parameter("texture_albedo", still_texture)
	body_material.set_shader_parameter("frame_count", 1)
	body_material.set_shader_parameter("frame", 0)


# (기존 그대로) _refresh_stats / _make_label / _make_bar


# 발밑 바닥에 까는 평면 하나 (그림자·고리). 조명과 그림자에 영향받지 않는다.
func _floor_decal(texture: Texture2D, size: Vector2, height: float, color: Color) -> MeshInstance3D:
	# 바닥 평면.
	var decal := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	decal.mesh = plane
	# 반투명 무광 재질에 색을 곱한다.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.albedo_color = color
	decal.material_override = material
	# 바닥 장식은 그림자를 드리우지 않는다.
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 타일과 겹쳐 깜빡이지 않게 살짝 띄운다.
	decal.position = Vector3(0.0, height, 0.0)
	add_child(decal)
	return decal


# 가운데가 진하고(0.5) 가장자리로 갈수록 투명한 원 (유니티 ViewAssets.CreateShadow).
static func _get_shadow_texture() -> Texture2D:
	# 처음 한 번만 만든다.
	if _shadow_texture == null:
		_shadow_texture = _radial_texture(func(r: float) -> float: return 0.5 * (1.0 - clampf(r, 0.0, 1.0)))
	return _shadow_texture


# 반지름 0.8~0.95 사이만 불투명한 얇은 고리 (유니티 ViewAssets.CreateRing).
static func _get_ring_texture() -> Texture2D:
	# 처음 한 번만 만든다.
	if _ring_texture == null:
		_ring_texture = _radial_texture(func(r: float) -> float: return clampf(1.0 - absf(r - 0.875) / 0.075, 0.0, 1.0))
	return _ring_texture


# 64×64 흰 텍스처. 중심에서의 거리(반지름 1 기준) r 마다 alpha_at(r) 을 알파로 쓴다.
static func _radial_texture(alpha_at: Callable) -> Texture2D:
	# 한 변의 픽셀 수.
	var size: int = 64
	# 빈 이미지.
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	# 중심.
	var center := Vector2((size - 1) / 2.0, (size - 1) / 2.0)
	# 픽셀마다 알파를 정한다.
	for y in size:
		for x in size:
			var r: float = Vector2(x, y).distance_to(center) / (size / 2.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha_at.call(r)))
	# 텍스처로 만든다.
	return ImageTexture.create_from_image(image)
```

`setup` 안의 기존 "--- 이름 ---" ~ `set_stats` 블록은 그대로 옮겨 붙이고, 클릭 판정 줄만 `pick_shape.position = Vector3(0.0, SPRITE_HEIGHT / 2.0, 0.0)` 로 바꾼다. 기존 변수 `_tint`, `_sprite_home`, 상수 `ALLY_TINT`·`ENEMY_TINT`·`FLASH_COLOR`, 함수 `_shadow_material` 은 지운다.

- [ ] **Step 5: 재생 쪽 피격 대기 수정** — `Scripts/view/battle_playback.gd` 의 `_damaged` 마지막 두 줄을 교체:

```gdscript
	# 번쩍이고 흔들리는 연출이 끝날 때까지 기다린다.
	await view.flash_and_shake()
	# 전체 피해 연출 시간이 DAMAGE_TIME 이 되도록 남은 시간을 기다린다 (피격 띠가 더 길면 기다리지 않는다).
	await _wait(maxf(0.0, DAMAGE_TIME - view.hit_duration()))
```

- [ ] **Step 6: 통과 확인** — 테스트 실행. Expected: `test_unit_view.gd`·`test_board_3d.gd`·`test_battle_playback.gd` 포함 전체 `N/N passed`. 셰이더 문법 오류는 헤드리스에서 안 잡히므로 Task 5 실행 확인에서 본다.

- [ ] **Step 7: 커밋**

```bash
git add Shaders/unit_sprite.gdshader Scripts/view/unit_view.gd Scripts/view/battle_playback.gd tests/test_unit_view.gd tests/test_board_3d.gd
git commit -m "feat: draw units with pixel sprites, animation sheets and motion curves

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: 영혼불 오라

**Files:**
- Modify: `Scripts/view/unit_view.gd`
- Test: `tests/test_unit_view.gd`

**Interfaces:**
- Consumes: `UnitData.aura_texture` (Task 1), `UnitView.setup`, `fade_out` (Task 3)
- Produces: `var aura: CPUParticles3D` (없으면 null), 상수 `AURA_LIFETIME 1.6`, `AURA_RATE 2.5`, `AURA_SIZE 0.4`

- [ ] **Step 1: 실패하는 테스트** — `run()` 에 `_test_aura()` 호출을 추가하고 함수를 붙인다.

```gdscript
# 오라 그림이 있는 유닛에만 위로 피어오르는 입자가 생기는지.
func _test_aura() -> void:
	# 오라 없는 유닛.
	var plain: UnitView = _view(true)
	# 없다.
	check("no aura without texture", plain.aura == null)
	# 지운다.
	plain.free()

	# 오라 있는 유닛.
	var data: UnitData = AllyDataScript.new()
	data.display_name = "보초"
	data.max_hp = 20
	data.aura_texture = ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	var view := UnitView.new()
	view.setup(Unit.new(0, data, Unit.Team.ALLY, Vector2i(0, 0)), _texture())
	# 있다.
	check("aura exists with texture", view.aura != null)
	# 계속 나온다.
	check("aura keeps emitting", view.aura.emitting and not view.aura.one_shot)
	# 이미 뜬 불꽃은 몸이 움직여도 제자리 (월드 좌표).
	check("aura particles live in world space", not view.aura.local_coords)
	# 수명.
	check("aura lifetime", is_equal_approx(view.aura.lifetime, UnitView.AURA_LIFETIME))
	# 그림이 입자 재질에 들어갔다.
	check("aura uses the texture", ((view.aura.mesh as QuadMesh).material as StandardMaterial3D).albedo_texture == data.aura_texture)
	# 지운다.
	view.free()
```

- [ ] **Step 2: 실패 확인** — Expected: `aura` 속성이 없어 FAIL.

- [ ] **Step 3: 구현** — `unit_view.gd` 상수 영역에 추가:

```gdscript
## 영혼불 한 알이 피어올라 사라지는 시간.
const AURA_LIFETIME: float = 1.6
## 초당 피어오르는 영혼불 수.
const AURA_RATE: float = 2.5
## 영혼불 한 알의 최대 크기 (몸 그림 64px 중 16px 정도).
const AURA_SIZE: float = 0.4
```

변수 영역에 추가:

```gdscript
## 몸 주변에 피어오르는 오라 입자 (오라 그림이 없으면 null).
var aura: CPUParticles3D
```

`setup` 의 `--- 발밑 ---` 블록 바로 앞에 추가:

```gdscript
	# --- 오라 ---
	# 데이터에 오라 그림이 있을 때만.
	if unit.data.aura_texture != null:
		aura = _make_aura(unit.data.aura_texture)
```

`fade_out` 의 `ring.visible = false` 다음 줄에 추가:

```gdscript
	# 오라는 새로 나오지 않게 한다 (이미 뜬 불꽃은 마저 사라진다).
	if aura != null:
		aura.emitting = false
```

새 함수 (`_floor_decal` 앞):

```gdscript
# 몸 둘레에서 천천히 떠올라 옅어지며 사라지는 불꽃 (유니티 UnitView.MakeAura).
func _make_aura(texture: Texture2D) -> CPUParticles3D:
	# 입자 노드.
	var particles := CPUParticles3D.new()
	particles.name = "Aura"
	# 몸 가운데 높이.
	particles.position = Vector3(0.0, SPRITE_HEIGHT * 0.45, 0.0)
	# 동시에 떠 있는 최대 수 = 수명 × 초당 수 (올림).
	particles.amount = ceili(AURA_LIFETIME * AURA_RATE)
	particles.lifetime = AURA_LIFETIME
	# 처음부터 가득 차 있게.
	particles.preprocess = AURA_LIFETIME
	# 이미 뜬 불꽃은 몸이 움직여도 제자리.
	particles.local_coords = false
	# 몸을 감싸는 납작한 상자에서 나온다.
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.55, SPRITE_HEIGHT * 0.35, 0.05)
	# 위로 천천히.
	particles.direction = Vector3.UP
	particles.spread = 15.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = 0.15
	particles.initial_velocity_max = 0.35
	# 크기 0.7~1 배, 수명 동안 절반으로 준다.
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.0
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.5))
	particles.scale_amount_curve = shrink
	# 알파: 0 → 1(0.2) → 1(0.6) → 0.
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.6, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	particles.color_ramp = fade
	# 카메라를 보는 픽셀 그림 판 (알파 섞기, 더하기 아님).
	var quad := QuadMesh.new()
	quad.size = Vector2(AURA_SIZE, AURA_SIZE)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	quad.material = material
	particles.mesh = quad
	# 그림자는 드리우지 않는다.
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 계속 나온다.
	particles.emitting = true
	add_child(particles)
	return particles
```

- [ ] **Step 4: 통과 확인** — 테스트 실행. Expected: 전체 통과.

- [ ] **Step 5: 커밋**

```bash
git add Scripts/view/unit_view.gd tests/test_unit_view.gd
git commit -m "feat: add rising spirit-flame aura for units with an aura texture

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: 실행 확인

**Files:** 없음 (확인만. 문제가 나오면 해당 Task 파일을 고치고 그 Task 의 테스트를 다시 돌린다.)

- [ ] **Step 1: 전체 테스트** — 테스트 실행. Expected: `N/N passed`, 종료 코드 0.

- [ ] **Step 2: 게임 실행** (PowerShell)

```powershell
$p = Start-Process "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" -ArgumentList "--path", "." -PassThru
$p.Id
```

`mcp__godot__runtime-status` 로 running 확인. 맵 화면에서 첫 노드를 클릭해 전투로 들어간다 (클릭 전에 같은 좌표로 `inject-mouse-motion`, 클릭은 `pressed: true` / `pressed: false` 짝).

- [ ] **Step 3: 확인 항목** — `capture_screenshot` 으로 캡처하고 본다.
  - 유닛 6종이 픽셀 그림으로 1.6 높이에 서 있고 적은 왼쪽을 본다. 발밑에 그림자와 파랑/빨강 고리.
  - 대기 띠가 움직인다 (2초 간격 캡처 두 장이 다름). sentry 주변에 영혼불이 피어오른다.
  - 카드를 써서 공격: 공격 띠가 재생되고 앞으로 나갔다 돌아온다. 맞은 쪽은 피격 띠 + 붉은 번쩍임 + 흔들림.
  - 쓰러진 유닛이 넘어지며 픽셀이 흩어져 사라진다.
  - `mcp__godot__editor-debug-output` 또는 콘솔에 셰이더 컴파일 오류·스크립트 오류 0건.
  - 유니티 `Battle.unity` 캡처(유니티 프로젝트에서 사용자가 제공하거나 기존 캡처)와 나란히 비교.

- [ ] **Step 4: 종료** — `Stop-Process -Id <위의 Id>`

- [ ] **Step 5: 확인 중 수정이 있었다면 커밋**

```bash
git add -A Scripts Shaders tests
git commit -m "fix: adjust unit presentation after in-game check

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

이 단계에서는 공격 띠(1.0초)가 끝난 뒤에 피해가 나오므로 공격이 예전보다 느리게 느껴진다. 타격 순간 동기화는 B 단계 계획에서 다룬다.
