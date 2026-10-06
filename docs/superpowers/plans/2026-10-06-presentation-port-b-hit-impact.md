# 전투 연출 역이식 B — 타격감 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 유니티의 타격감 연출을 Godot 전투에 옮긴다. 무기가 닿는 순간 피해가 터지고, 흰 번쩍임·불꽃·튀는 숫자·넉백·카메라 푸시인·흔들림·히트스톱·처치 슬로모션·원거리 화살·효과음·화면 펄스가 그 순간에 겹치게 한다.

**Architecture:** 연출 부품은 서로 모르는 작은 노드로 나눈다. `BattleCamera`(카메라 오프셋·시간 배율), `Projectile`(화살 하나), `BattleAudio`+`BattleSounds`(효과음), `ScreenPulse`(화면 셰이더)가 따로 있고, `BattlePlayback` 만 이들을 부른다. 셋 다 null 이거나 `instant` 이면 연출 없이 지금처럼 재생한다. 판단 로직(타격 묶음 찾기, 넉백 거리, 흔들림 세기, 비행 시간, 클립 고르기)은 정적 함수로 빼서 헤드리스로 검사한다. 카메라·펄스·흰 번쩍임은 실제 시간으로 돌아 히트스톱 중에도 진행된다.

**Tech Stack:** Godot 4.7.2, GDScript(타입 명시), canvas_item 셰이더, `AudioStreamPolyphonic`, `CPUParticles3D`, 헤드리스 `TestCase` 러너.

**Spec:** `docs/superpowers/specs/2026-10-06-unity-presentation-port-design.md` (§5, §7, §8 B, §9, §10 B)

## Global Constraints

- 유니티 원본: `C:\Users\User\Desktop\projectvoidunityh\Assets\_Project\Scripts\View\` 의 `BattlePlayback.cs`, `BattleCamera.cs`, `Projectile.cs`, `BattleSounds.cs`, `BattleAudio.cs`, `ScreenPulse.cs`, `UnitView.cs`. 에셋은 `Assets/_Project/Audio/*.wav`, `Assets/_Project/Art/Effects/arrow.png`.
- 규칙 코어(`Scripts/combat/` 의 battle_state·unit·target_resolver·enemy_brain)는 건드리지 않는다.
- 수치 (spec 그대로): 히트스톱 배율 0.05, 피해 0.06초·처치 0.1초 / 슬로모션 0.3 배율 실제 0.35초 / 푸시인 거리 12%, 속도 8 / 흔들림 최대 0.25·감소 2.5/초·세기 `0.2 + 0.7·min(피해,10)/10`, 처치 1 / 넉백 `min(0.1 + 0.03·피해, 0.35)`, 피해 0 이면 0 / 원거리 반동 −0.1 / 화살 비행 `clamp(거리/16, 0.12, 0.35)`, 포물선 높이 거리×0.06, 길이 0.8 / 흰 번쩍임 실제 0.06초 / 불꽃 12개·수명 0.25 / 피해 숫자 1.6배, 처치 2배, 0.15초에 1배로 / 음높이 ±8% / 펄스: 처치 1, 피해 8 이상 0.5, 실제 0.4초에 0, 기본 비네트 0.38 + 0.25·level / 가슴 높이 1.6×0.55.
- 새 GDScript 는 타입 명시 + `class_name` + 주변처럼 촘촘한 한국어 주석.
- 테스트 실행: `& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tests/run_tests.gd` → 마지막 줄 `N/N passed`. 새 class_name 이 안 잡히면 `--headless --editor --quit --path .` 로 재스캔. 새 테스트 파일은 `tests/run_tests.gd` 의 `TEST_SCRIPTS` 에 추가.
- `Engine.time_scale` 을 바꾸는 테스트는 끝에서 반드시 1.0 으로 되돌린다 (다른 테스트가 영향받지 않게).
- 커밋 메시지 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. `project.godot` 의 무관한 변경은 커밋하지 않는다.

## Review Focus

1. **전투가 끝나거나 씬이 바뀌는 순간 히트스톱·슬로모션이 걸려 있는 경우** — 맵으로 돌아간 뒤에도 게임이 0.05/0.3 배속으로 남으면 안 된다. → Task 2 테스트 `exit tree restores time scale`.
2. **광역 공격으로 여러 유닛이 같은 묶음에서 맞고 그중 하나가 죽는 경우** — 히트스톱이 겹쳐 걸려도 가장 긴 것 하나만 유지되고, 슬로모션은 히트스톱이 끝난 뒤 한 번만. → Task 2 테스트 `overlapping hit stops keep the longest`.
3. **빗나간 공격(대상 칸이 비어 피해 이벤트가 없음)** — 타격 동기화 없이 돌진만 하고, 카메라 푸시가 남지 않아야 한다. → Task 6 테스트 `impact_start: no damage after attack`. 푸시는 `play()` 루프가 다음 비-피해 이벤트에서, 그리고 `play()` 끝에서 반드시 푼다 (Task 6 Step 3 루프 마지막 `_release_camera()`).
4. **피해 0 (방어도에 막힘)** — 넉백 없음, 막힘 소리, 흔들림은 최소 세기 0.2. → Task 1 `blocked hit picks the blocked clip`, Task 6 `knockback_distance(0) == 0`, Task 2 `zero damage shake is the base`.
5. **화면 펄스 ColorRect 가 클릭을 가로채는 경우** — 전체 화면을 덮으므로 마우스를 무시해야 카드·칸 클릭이 된다. → Task 4 테스트 `pulse overlay ignores the mouse`.

---

### Task 1: 효과음 — `BattleSounds` · `BattleAudio`

**Files:**
- Create: `Audio/melee_swing.wav`, `melee_hit.wav`, `ranged_shot.wav`, `ranged_hit.wav`, `blocked.wav`, `kill.wav` (+ `.import`)
- Create: `Scripts/view/battle_sounds.gd`, `Scripts/view/battle_audio.gd`, `Resources/audio/battle_sounds.tres`
- Create: `tests/test_battle_sounds.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Produces:
  - `class_name BattleSounds extends Resource` — `@export var melee_swing, melee_hit, ranged_shot, ranged_hit, blocked, kill: AudioStream`; `func for_attack(type: CardData.AttackType) -> AudioStream`; `func for_impact(type: CardData.AttackType, amount: int, died: bool) -> AudioStream`
  - `class_name BattleAudio extends Node` — `const PITCH_JITTER := 0.08`; `var sounds: BattleSounds`; `var play_count: int`; `func play(stream: AudioStream) -> void`

- [ ] **Step 1: 실패하는 테스트** — `tests/test_battle_sounds.gd`

```gdscript
# BattleSounds(효과음 고르기)와 BattleAudio(재생기) 테스트.
extends TestCase

# 효과음 묶음 스크립트.
const SoundsScript := preload("res://Scripts/view/battle_sounds.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 공격 소리 고르기.
	_test_attack_clips()
	# 타격 소리 고르기.
	_test_impact_clips()
	# 재생 횟수와 빈 클립.
	_test_audio_counts_real_plays()
	# 실제 창고 효과음 리소스.
	_test_sounds_resource()
	# 결과를 돌려준다.
	return results()


# 서로 구분되는 클립 6개를 채운 묶음.
func _sounds() -> BattleSounds:
	# 빈 묶음.
	var sounds: BattleSounds = SoundsScript.new()
	# 칸마다 다른 빈 스트림.
	sounds.melee_swing = AudioStreamWAV.new()
	sounds.melee_hit = AudioStreamWAV.new()
	sounds.ranged_shot = AudioStreamWAV.new()
	sounds.ranged_hit = AudioStreamWAV.new()
	sounds.blocked = AudioStreamWAV.new()
	sounds.kill = AudioStreamWAV.new()
	# 돌려준다.
	return sounds


# 근접은 휘두르기, 원거리는 발사.
func _test_attack_clips() -> void:
	# 묶음.
	var sounds: BattleSounds = _sounds()
	# 근접.
	check("melee attack swings", sounds.for_attack(CardData.AttackType.MELEE) == sounds.melee_swing)
	# 원거리.
	check("ranged attack shoots", sounds.for_attack(CardData.AttackType.RANGED) == sounds.ranged_shot)


# 처치 → 피해 0 → 공격 종류 순으로 고른다.
func _test_impact_clips() -> void:
	# 묶음.
	var sounds: BattleSounds = _sounds()
	# 처치가 가장 우선.
	check("kill wins", sounds.for_impact(CardData.AttackType.RANGED, 0, true) == sounds.kill)
	# 막힘.
	check("blocked hit picks the blocked clip", sounds.for_impact(CardData.AttackType.MELEE, 0, false) == sounds.blocked)
	# 근접 타격.
	check("melee hit", sounds.for_impact(CardData.AttackType.MELEE, 5, false) == sounds.melee_hit)
	# 원거리 타격.
	check("ranged hit", sounds.for_impact(CardData.AttackType.RANGED, 5, false) == sounds.ranged_hit)
	# 비어 있는 칸은 null.
	var empty: BattleSounds = SoundsScript.new()
	# null.
	check("missing clip is null", empty.for_impact(CardData.AttackType.MELEE, 5, false) == null)


# null 은 세지 않고, 스트림은 트리 밖에서도 오류 없이 센다.
func _test_audio_counts_real_plays() -> void:
	# 재생기.
	var audio := BattleAudio.new()
	# 빈 클립.
	audio.play(null)
	# 세지 않는다.
	check_eq("null clip is not played", audio.play_count, 0)
	# 실제 클립.
	audio.play(AudioStreamWAV.new())
	# 하나.
	check_eq("clip counted", audio.play_count, 1)
	# 지운다.
	audio.free()


# 저장된 효과음 리소스가 6칸 모두 채워져 있다.
func _test_sounds_resource() -> void:
	# 불러온다.
	var sounds: BattleSounds = load("res://Resources/audio/battle_sounds.tres")
	# 있다.
	check("battle_sounds.tres loads", sounds != null)
	# 모두 채워짐.
	check("all six clips set", sounds.melee_swing != null and sounds.melee_hit != null and sounds.ranged_shot != null and sounds.ranged_hit != null and sounds.blocked != null and sounds.kill != null)
```

`tests/run_tests.gd` 의 `TEST_SCRIPTS` 끝에 `"res://tests/test_battle_sounds.gd",` 추가.

- [ ] **Step 2: 실패 확인** — 테스트 실행. Expected: `BattleSounds` 를 못 찾아 suite FAIL.

- [ ] **Step 3: 에셋 복사·임포트** (Bash)

```bash
mkdir -p Audio Resources/audio
cp /c/Users/User/Desktop/projectvoidunityh/Assets/_Project/Audio/*.wav Audio/
ls Audio
```

그다음 `& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --editor --quit --path .` 로 임포트. Expected: `Audio/*.wav.import` 6개.

- [ ] **Step 4: 구현** — `Scripts/view/battle_sounds.gd`

```gdscript
## 전투 효과음 묶음. 공격 종류·피해·처치에 맞는 클립을 고른다. 비어 있는 칸은 null 이라 소리가 나지 않는다.
class_name BattleSounds
# Resource: .tres 로 저장해 인스펙터에서 클립을 바꿀 수 있다.
extends Resource

## 근접 공격을 휘두르는 소리.
@export var melee_swing: AudioStream
## 근접 공격이 맞는 소리.
@export var melee_hit: AudioStream
## 원거리 공격을 쏘는 소리.
@export var ranged_shot: AudioStream
## 원거리 공격이 맞는 소리.
@export var ranged_hit: AudioStream
## 방어도에 막혀 피해가 0 인 소리.
@export var blocked: AudioStream
## 처치 소리.
@export var kill: AudioStream


## 공격을 시작(근접) 또는 발사(원거리)할 때의 소리.
func for_attack(type: CardData.AttackType) -> AudioStream:
	# 원거리는 발사, 근접은 휘두르기.
	return ranged_shot if type == CardData.AttackType.RANGED else melee_swing


## 맞은 순간의 소리. 처치 → 막힘 → 공격 종류 순으로 고른다.
func for_impact(type: CardData.AttackType, amount: int, died: bool) -> AudioStream:
	# 처치가 가장 우선.
	if died:
		return kill
	# 피해가 없으면 막힘.
	if amount <= 0:
		return blocked
	# 공격 종류별 타격음.
	return ranged_hit if type == CardData.AttackType.RANGED else melee_hit
```

`Scripts/view/battle_audio.gd`

```gdscript
## 전투 효과음 재생기. 한 플레이어에서 여러 소리를 겹쳐 내고, 같은 소리가 반복돼도 덜 기계적이게 음높이를 조금씩 흔든다.
class_name BattleAudio
# Node: 씬 트리에 붙어야 소리가 난다.
extends Node

## 음높이를 흔드는 폭 (±8%).
const PITCH_JITTER: float = 0.08
## 동시에 겹쳐 낼 수 있는 소리 수.
const MAX_VOICES: int = 8

## 고를 클립 묶음 (BattlePlayback 이 여기서 고른다).
var sounds: BattleSounds
## 실제로 재생한 횟수 (테스트용).
var play_count: int = 0

# 여러 소리를 겹쳐 내는 플레이어 (처음 재생할 때 만든다).
var _player: AudioStreamPlayer


## 클립 하나를 낸다. null 이면 아무것도 안 한다. 트리 밖(테스트)에서는 세기만 한다.
func play(stream: AudioStream) -> void:
	# 빈 클립.
	if stream == null:
		return
	# 셌다.
	play_count += 1
	# 트리 밖이면 소리를 낼 수 없다.
	if not is_inside_tree():
		return
	# 처음이면 겹쳐 내기 플레이어를 만든다.
	if _player == null:
		_player = AudioStreamPlayer.new()
		var polyphonic := AudioStreamPolyphonic.new()
		polyphonic.polyphony = MAX_VOICES
		_player.stream = polyphonic
		add_child(_player)
		_player.play()
	# 겹쳐 내기 재생기에 음높이를 흔들어 넣는다.
	var playback := _player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	playback.play_stream(stream, 0.0, 0.0, 1.0 + randf_range(-PITCH_JITTER, PITCH_JITTER))
```

`Resources/audio/battle_sounds.tres`

```
[gd_resource type="Resource" script_class="BattleSounds" format=3]

[ext_resource type="Script" path="res://Scripts/view/battle_sounds.gd" id="1_script"]
[ext_resource type="AudioStream" path="res://Audio/melee_swing.wav" id="2_swing"]
[ext_resource type="AudioStream" path="res://Audio/melee_hit.wav" id="3_mhit"]
[ext_resource type="AudioStream" path="res://Audio/ranged_shot.wav" id="4_shot"]
[ext_resource type="AudioStream" path="res://Audio/ranged_hit.wav" id="5_rhit"]
[ext_resource type="AudioStream" path="res://Audio/blocked.wav" id="6_blocked"]
[ext_resource type="AudioStream" path="res://Audio/kill.wav" id="7_kill"]

[resource]
script = ExtResource("1_script")
melee_swing = ExtResource("2_swing")
melee_hit = ExtResource("3_mhit")
ranged_shot = ExtResource("4_shot")
ranged_hit = ExtResource("5_rhit")
blocked = ExtResource("6_blocked")
kill = ExtResource("7_kill")
```

- [ ] **Step 5: 통과 확인** — 재스캔 후 테스트 실행. Expected: 전체 통과.

- [ ] **Step 6: 커밋**

```bash
git add Audio Scripts/view/battle_sounds.gd* Scripts/view/battle_audio.gd* Resources/audio tests/test_battle_sounds.gd* tests/run_tests.gd
git commit -m "feat: add battle sound set and polyphonic sound player

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `BattleCamera` — 푸시인·흔들림·히트스톱·슬로모션

**Files:**
- Create: `Scripts/view/battle_camera.gd`, `tests/test_battle_camera.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Produces: `class_name BattleCamera extends Node`
  - 상수 `PUSH_FRACTION 0.12`, `PUSH_SHARPNESS 8.0`, `MAX_SHAKE_OFFSET 0.25`, `SHAKE_DECAY 2.5`, `HIT_STOP_SCALE 0.05`, `SLOW_MO_SCALE 0.3`, `SLOW_MO_TIME 0.35`, `SHAKE_DAMAGE_CAP 10`
  - `var camera: Camera3D`
  - `static func shake_for_damage(amount: int, died: bool) -> float`
  - `func set_base(position: Vector3, basis: Basis) -> void`, `func push_toward(point: Vector3) -> void`, `func release() -> void`, `func shake(strength: float) -> void`, `func hit_stop(seconds: float) -> void`, `func kill_slow_mo() -> void`, `func tick(real_delta: float) -> void`
  - 읽기용: `func push_offset() -> Vector3`, `func trauma() -> float`

- [ ] **Step 1: 실패하는 테스트** — `tests/test_battle_camera.gd`

```gdscript
# BattleCamera(타격 카메라 연출) 테스트. tick 에 실제 시간을 직접 넣어 검사한다.
extends TestCase


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 흔들림 세기.
	_test_shake_strength()
	# 히트스톱 → 복귀.
	_test_hit_stop()
	# 겹친 히트스톱.
	_test_overlapping_hit_stops()
	# 히트스톱 뒤 슬로모션.
	_test_slow_mo_after_hit_stop()
	# 히트스톱 없는 슬로모션.
	_test_slow_mo_alone()
	# 트리에서 빠질 때 복구.
	_test_exit_restores_time_scale()
	# 푸시인 수렴과 해제.
	_test_push()
	# 결과를 돌려준다.
	return results()


# 카메라를 단 연출 노드 (트리 밖).
func _fx() -> BattleCamera:
	# 연출 노드.
	var fx := BattleCamera.new()
	# 카메라.
	fx.camera = Camera3D.new()
	# 기본 구도.
	fx.set_base(Vector3(0.0, 5.0, 5.0), Basis.IDENTITY)
	# 돌려준다.
	return fx


# 연출 노드와 카메라를 지우고 시간 배율을 되돌린다.
func _done(fx: BattleCamera) -> void:
	# 카메라.
	fx.camera.free()
	# 연출 노드.
	fx.free()
	# 다른 테스트를 위해.
	Engine.time_scale = 1.0


# 피해에 비례하되 10 에서 멈추고, 처치는 1, 피해 0 은 기본 0.2.
func _test_shake_strength() -> void:
	# 피해 0.
	check("zero damage shake is the base", is_equal_approx(BattleCamera.shake_for_damage(0, false), 0.2))
	# 피해 5.
	check("half cap shake", is_equal_approx(BattleCamera.shake_for_damage(5, false), 0.55))
	# 상한.
	check("shake caps at 10 damage", is_equal_approx(BattleCamera.shake_for_damage(30, false), 0.9))
	# 처치.
	check("kill shakes fully", is_equal_approx(BattleCamera.shake_for_damage(0, true), 1.0))


# 히트스톱을 걸면 바로 0.05, 건 프레임의 시간은 빼지 않고, 다 지나면 1.
func _test_hit_stop() -> void:
	# 연출.
	var fx: BattleCamera = _fx()
	# 0.06초 멈춤.
	fx.hit_stop(0.06)
	# 바로 느려진다.
	check("hit stop slows time", is_equal_approx(Engine.time_scale, BattleCamera.HIT_STOP_SCALE))
	# 건 프레임.
	fx.tick(0.05)
	# 아직 멈춤.
	check("hit stop survives its own frame", is_equal_approx(Engine.time_scale, BattleCamera.HIT_STOP_SCALE))
	# 0.05 지남.
	fx.tick(0.05)
	# 아직.
	check("hit stop still running", is_equal_approx(Engine.time_scale, BattleCamera.HIT_STOP_SCALE))
	# 0.1 지남 (> 0.06).
	fx.tick(0.05)
	# 복귀.
	check("hit stop ends", is_equal_approx(Engine.time_scale, 1.0))
	# 정리.
	_done(fx)


# 짧은 히트스톱 뒤에 긴 것이 오면 긴 것만큼, 긴 것 뒤에 짧은 것이 와도 긴 것만큼.
func _test_overlapping_hit_stops() -> void:
	# 연출.
	var fx: BattleCamera = _fx()
	# 긴 것 먼저.
	fx.hit_stop(0.1)
	# 건 프레임.
	fx.tick(0.0)
	# 짧은 것.
	fx.hit_stop(0.06)
	# 건 프레임.
	fx.tick(0.0)
	# 0.08 지남.
	fx.tick(0.08)
	# 긴 쪽이 남아 아직 멈춤.
	check("overlapping hit stops keep the longest", is_equal_approx(Engine.time_scale, BattleCamera.HIT_STOP_SCALE))
	# 0.04 더.
	fx.tick(0.04)
	# 끝.
	check("longest hit stop ends", is_equal_approx(Engine.time_scale, 1.0))
	# 정리.
	_done(fx)


# 처치: 히트스톱이 끝나면 0.3 이 실제 0.35초 이어지고 1.
func _test_slow_mo_after_hit_stop() -> void:
	# 연출.
	var fx: BattleCamera = _fx()
	# 처치 연출.
	fx.hit_stop(0.1)
	fx.kill_slow_mo()
	# 건 프레임.
	fx.tick(0.0)
	# 히트스톱 중엔 그대로 0.05.
	check("slow mo waits for hit stop", is_equal_approx(Engine.time_scale, BattleCamera.HIT_STOP_SCALE))
	# 히트스톱 끝.
	fx.tick(0.11)
	# 슬로모션.
	check("slow mo follows hit stop", is_equal_approx(Engine.time_scale, BattleCamera.SLOW_MO_SCALE))
	# 0.3 지남.
	fx.tick(0.3)
	# 아직.
	check("slow mo lasts", is_equal_approx(Engine.time_scale, BattleCamera.SLOW_MO_SCALE))
	# 0.36 지남.
	fx.tick(0.06)
	# 복귀.
	check("slow mo ends", is_equal_approx(Engine.time_scale, 1.0))
	# 정리.
	_done(fx)


# 히트스톱 없이 불러도 다음 tick 에서 바로 슬로모션.
func _test_slow_mo_alone() -> void:
	# 연출.
	var fx: BattleCamera = _fx()
	# 슬로모션만.
	fx.kill_slow_mo()
	# 다음 프레임.
	fx.tick(0.016)
	# 0.3.
	check("slow mo without hit stop", is_equal_approx(Engine.time_scale, BattleCamera.SLOW_MO_SCALE))
	# 정리.
	_done(fx)


# 멈춘 채 트리에서 빠지면 시간 배율이 1 로 돌아온다.
func _test_exit_restores_time_scale() -> void:
	# 연출을 트리에 붙인다.
	var fx: BattleCamera = _fx()
	(Engine.get_main_loop() as SceneTree).root.add_child(fx)
	# 처치 연출 중.
	fx.hit_stop(0.1)
	fx.kill_slow_mo()
	# 빠진다.
	(Engine.get_main_loop() as SceneTree).root.remove_child(fx)
	# 복구.
	check("exit tree restores time scale", is_equal_approx(Engine.time_scale, 1.0))
	# 정리.
	_done(fx)


# 푸시인은 목표 쪽 12% 로 수렴하고, release 하면 0 으로 돌아온다. 카메라 위치에 반영된다.
func _test_push() -> void:
	# 연출.
	var fx: BattleCamera = _fx()
	# 원점 쪽으로.
	fx.push_toward(Vector3.ZERO)
	# 충분히 흐른다.
	for i in 60:
		fx.tick(0.05)
	# 목표 = (0,−5,−5)×0.12.
	check("push converges to 12 percent", fx.push_offset().is_equal_approx(Vector3(0.0, -0.6, -0.6)))
	# 카메라가 옮겨졌다.
	check("camera follows the push", fx.camera.position.is_equal_approx(Vector3(0.0, 4.4, 4.4)))
	# 해제.
	fx.release()
	for i in 60:
		fx.tick(0.05)
	# 원래대로.
	check("release returns home", fx.push_offset().is_equal_approx(Vector3.ZERO))
	# 정리.
	_done(fx)
```

`TEST_SCRIPTS` 에 `"res://tests/test_battle_camera.gd",` 추가.

- [ ] **Step 2: 실패 확인** — Expected: `BattleCamera` 없음으로 FAIL.

- [ ] **Step 3: 구현** — `Scripts/view/battle_camera.gd`

```gdscript
## 전투 카메라의 타격 연출. 기본 구도(set_base) 위에 푸시인·흔들림을 더하고, 히트스톱·처치 슬로모션으로 시간 배율을 바꾼다.
## 히트스톱 중에도 움직여야 하므로 실제 시간으로 돈다 (유니티 BattleCamera).
class_name BattleCamera
# Node: 카메라 옆에 붙어 매 프레임 카메라를 옮긴다.
extends Node

## 타격 지점까지 거리 중 이만큼만 다가간다 (보드가 화면에서 벗어나지 않을 정도).
const PUSH_FRACTION: float = 0.12
## 푸시인이 목표에 다가가는 빠르기.
const PUSH_SHARPNESS: float = 8.0
## 흔들림으로 밀리는 최대 거리.
const MAX_SHAKE_OFFSET: float = 0.25
## 초당 줄어드는 흔들림 세기 (1 이 0.4초 만에 사라진다).
const SHAKE_DECAY: float = 2.5
## 히트스톱 중 시간 배율.
const HIT_STOP_SCALE: float = 0.05
## 처치 슬로모션 시간 배율.
const SLOW_MO_SCALE: float = 0.3
## 처치 슬로모션을 실제 시간으로 유지하는 길이.
const SLOW_MO_TIME: float = 0.35
## 흔들림 세기가 더 오르지 않는 피해량.
const SHAKE_DAMAGE_CAP: int = 10
# 피해 0 의 흔들림 세기.
const _SHAKE_BASE: float = 0.2
# 피해 상한까지 더해지는 흔들림 세기.
const _SHAKE_PER_DAMAGE: float = 0.7
# 남은 차이가 이보다 작으면 목표에 붙인다.
const _SETTLE_EPSILON: float = 1e-5

## 움직일 카메라.
var camera: Camera3D

# 기본 구도.
var _base_position: Vector3 = Vector3.ZERO
var _base_basis: Basis = Basis.IDENTITY
# 지금 푸시인 오프셋과 목표.
var _push: Vector3 = Vector3.ZERO
var _push_target: Vector3 = Vector3.ZERO
# 흔들림 세기 (0..1).
var _trauma: float = 0.0
# 남은 히트스톱 (실제 초).
var _hit_stop_left: float = 0.0
# 히트스톱을 건 프레임의 시간은 이미 흘러간 것이라 빼지 않는다.
var _hit_stop_just_started: bool = false
# 히트스톱이 끝나면 슬로모션을 시작한다.
var _slow_mo_pending: bool = false
# 남은 슬로모션 (실제 초).
var _slow_mo_left: float = 0.0
# 지난 프레임의 실제 시각 (마이크로초).
var _last_usec: int = 0


## 피해량에 비례하되 상한이 있는 흔들림 세기 (0..1). 처치는 항상 가장 세다.
static func shake_for_damage(amount: int, died: bool) -> float:
	# 처치.
	if died:
		return 1.0
	# 피해 비례.
	return _SHAKE_BASE + _SHAKE_PER_DAMAGE * float(mini(amount, SHAKE_DAMAGE_CAP)) / float(SHAKE_DAMAGE_CAP)


## 연출이 없을 때의 카메라 위치·회전을 정하고 바로 적용한다.
func set_base(position: Vector3, basis: Basis) -> void:
	# 기억한다.
	_base_position = position
	_base_basis = basis
	# 지금 오프셋으로 적용.
	_apply(_push)


## 타격 지점 쪽으로 조금 다가간다.
func push_toward(point: Vector3) -> void:
	# 목표 오프셋.
	_push_target = (point - _base_position) * PUSH_FRACTION


## 푸시인을 풀고 기본 구도로 돌아간다.
func release() -> void:
	# 목표를 0 으로.
	_push_target = Vector3.ZERO


## 흔든다. 이미 더 세게 흔들리고 있으면 그대로.
func shake(strength: float) -> void:
	# 큰 쪽.
	_trauma = clampf(maxf(_trauma, strength), 0.0, 1.0)


## 시간을 잠깐 거의 멈춘다. 겹치면 남은 시간이 긴 쪽.
func hit_stop(seconds: float) -> void:
	# 긴 쪽.
	_hit_stop_left = maxf(_hit_stop_left, seconds)
	# 이번 프레임 시간은 빼지 않는다.
	_hit_stop_just_started = true
	# 바로 느리게.
	Engine.time_scale = HIT_STOP_SCALE


## 처치 연출: 히트스톱이 끝나면(없으면 바로) 잠깐 느리게 흐른다.
func kill_slow_mo() -> void:
	# 다음 기회에 시작.
	_slow_mo_pending = true


## 지금 푸시인 오프셋 (테스트용).
func push_offset() -> Vector3:
	return _push


## 지금 흔들림 세기 (테스트용).
func trauma() -> float:
	return _trauma


## 실제 시간 real_delta 만큼 진행한다.
func tick(real_delta: float) -> void:
	# --- 히트스톱 ---
	if _hit_stop_just_started:
		_hit_stop_just_started = false
	elif _hit_stop_left > 0.0:
		_hit_stop_left -= real_delta
		# 끝났으면 슬로모션 중이면 그 배율, 아니면 1.
		if _hit_stop_left <= 0.0:
			_hit_stop_left = 0.0
			Engine.time_scale = SLOW_MO_SCALE if _slow_mo_left > 0.0 else 1.0
	# --- 슬로모션 (히트스톱이 없을 때만) ---
	if _hit_stop_left <= 0.0 and not _hit_stop_just_started:
		if _slow_mo_pending:
			_slow_mo_pending = false
			_slow_mo_left = SLOW_MO_TIME
			Engine.time_scale = SLOW_MO_SCALE
		elif _slow_mo_left > 0.0:
			_slow_mo_left -= real_delta
			if _slow_mo_left <= 0.0:
				_slow_mo_left = 0.0
				Engine.time_scale = 1.0

	# --- 푸시인 ---
	_push = _push.lerp(_push_target, 1.0 - exp(-PUSH_SHARPNESS * real_delta))
	if _push.distance_squared_to(_push_target) < _SETTLE_EPSILON * _SETTLE_EPSILON:
		_push = _push_target

	# --- 흔들림 ---
	var shake_offset := Vector3.ZERO
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - SHAKE_DECAY * real_delta)
		# 제곱해야 약한 타격은 잔잔하고 센 타격만 크게 튄다. 화면 평면(카메라 x·y) 안의 무작위 방향.
		var angle: float = randf() * TAU
		shake_offset = (_base_basis.x * cos(angle) + _base_basis.y * sin(angle)) * (MAX_SHAKE_OFFSET * _trauma * _trauma)
	_apply(_push + shake_offset)


## 매 프레임: 실제 시간 차이로 진행한다.
func _process(_delta: float) -> void:
	# 지금 실제 시각.
	var now: int = Time.get_ticks_usec()
	# 첫 프레임은 0.
	var real_delta: float = 0.0 if _last_usec == 0 else float(now - _last_usec) / 1000000.0
	_last_usec = now
	tick(real_delta)


## 트리에서 빠질 때(씬 전환 등) 시간 배율이 남지 않게 한다.
func _exit_tree() -> void:
	# 멈춤·슬로모션이 남아 있으면 지운다.
	if _hit_stop_left > 0.0 or _slow_mo_left > 0.0 or _slow_mo_pending:
		_hit_stop_left = 0.0
		_slow_mo_left = 0.0
		_slow_mo_pending = false
		Engine.time_scale = 1.0


# 기본 구도 + offset 을 카메라에 적용한다.
func _apply(offset: Vector3) -> void:
	# 카메라가 없으면 (테스트) 넘어간다.
	if camera == null:
		return
	camera.transform = Transform3D(_base_basis, _base_position + offset)
```

- [ ] **Step 4: 통과 확인** — 재스캔 후 테스트 실행. Expected: 전체 통과.

- [ ] **Step 5: 커밋**

```bash
git add Scripts/view/battle_camera.gd* tests/test_battle_camera.gd* tests/run_tests.gd
git commit -m "feat: add battle camera push, shake, hit stop and kill slow motion

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `Projectile` — 포물선 화살

**Files:**
- Create: `Art/effects/arrow.png` (+ `.import`, 3D 압축 끔), `Scripts/view/projectile.gd`, `tests/test_projectile.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Produces: `class_name Projectile extends Node3D`
  - 상수 `MIN_FLIGHT 0.12`, `MAX_FLIGHT 0.35`, `SPEED 16.0`, `ARC_PER_DISTANCE 0.06`, `LENGTH 0.8`
  - `static func flight_time(distance: float) -> float`, `static func position_at(from: Vector3, to: Vector3, arc: float, t: float) -> Vector3`
  - `static func spawn(parent: Node, texture: Texture2D, from: Vector3, to: Vector3) -> Projectile` (parent 에 붙여 돌려준다)
  - `var duration: float`, `var mesh: MeshInstance3D`, `func fly() -> void` (await 가능, 끝나면 queue_free)

- [ ] **Step 1: 실패하는 테스트** — `tests/test_projectile.gd`

```gdscript
# Projectile(원거리 화살) 테스트: 비행 시간, 궤적, 그림 없이 만들기.
extends TestCase


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 비행 시간.
	_test_flight_time()
	# 궤적.
	_test_position_at()
	# 만들기.
	_test_spawn()
	# 결과를 돌려준다.
	return results()


# 가까우면 하한, 멀면 상한, 중간은 거리/16.
func _test_flight_time() -> void:
	# 하한.
	check("near flight clamps low", is_equal_approx(Projectile.flight_time(0.5), Projectile.MIN_FLIGHT))
	# 상한.
	check("far flight clamps high", is_equal_approx(Projectile.flight_time(20.0), Projectile.MAX_FLIGHT))
	# 비례.
	check("mid flight is proportional", is_equal_approx(Projectile.flight_time(4.0), 0.25))


# 양 끝은 출발·도착, 가운데는 직선보다 arc 만큼 높다.
func _test_position_at() -> void:
	# 출발·도착.
	var from := Vector3(0.0, 1.0, 0.0)
	var to := Vector3(4.0, 1.0, 0.0)
	# 시작.
	check("starts at from", Projectile.position_at(from, to, 0.24, 0.0).is_equal_approx(from))
	# 끝.
	check("ends at to", Projectile.position_at(from, to, 0.24, 1.0).is_equal_approx(to))
	# 가운데 = 직선 중점 + arc.
	check("arcs above the line", Projectile.position_at(from, to, 0.24, 0.5).is_equal_approx(Vector3(2.0, 1.24, 0.0)))


# 그림이 없어도 만들어지고, 거리로 비행 시간과 포물선을 정하고, 출발점에 놓인다.
func _test_spawn() -> void:
	# 부모.
	var parent := Node3D.new()
	# 그림 없이 4 거리.
	var arrow: Projectile = Projectile.spawn(parent, null, Vector3.ZERO, Vector3(4.0, 0.0, 0.0))
	# 부모에 붙었다.
	check("spawned under parent", arrow.get_parent() == parent)
	# 비행 시간.
	check("duration from distance", is_equal_approx(arrow.duration, 0.25))
	# 대체 그림이 들어간 판.
	check("fallback texture without art", (arrow.mesh.material_override as StandardMaterial3D).albedo_texture != null)
	# 판 길이.
	check("arrow length", is_equal_approx((arrow.mesh.mesh as QuadMesh).size.x, Projectile.LENGTH))
	# 출발점.
	check("placed at the start", arrow.position.is_equal_approx(Vector3.ZERO))
	# 정리.
	parent.free()
```

`TEST_SCRIPTS` 에 `"res://tests/test_projectile.gd",` 추가.

- [ ] **Step 2: 실패 확인** — Expected: `Projectile` 없음으로 FAIL.

- [ ] **Step 3: 화살 그림** (Bash) — 복사 후 임포트하고 3D 압축을 끈다.

```bash
cp /c/Users/User/Desktop/projectvoidunityh/Assets/_Project/Art/Effects/arrow.png Art/effects/
```

`& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --editor --quit --path .` → `sed -i 's#detect_3d/compress_to=1#detect_3d/compress_to=0#' Art/effects/arrow.png.import` → 같은 임포트 명령 한 번 더.

- [ ] **Step 4: 구현** — `Scripts/view/projectile.gd`

```gdscript
## 원거리 공격의 화살. 쏜 쪽 가슴에서 맞을 쪽 가슴까지 낮은 포물선으로 날아가고,
## 판은 카메라를 보되 그림은 화면에서 날아가는 방향을 가리킨다 (유니티 Projectile).
class_name Projectile
# Node3D: 3D 공간을 날아간다.
extends Node3D

## 가장 짧은 비행 시간.
const MIN_FLIGHT: float = 0.12
## 가장 긴 비행 시간.
const MAX_FLIGHT: float = 0.35
## 비행 속도 (초당 3D 단위).
const SPEED: float = 16.0
## 거리 1 당 포물선 최고 높이.
const ARC_PER_DISTANCE: float = 0.06
## 화살 판 길이.
const LENGTH: float = 0.8
# 그림이 없을 때 쓰는 흰 줄무늬의 세로/가로 비.
const _FALLBACK_ASPECT: float = 0.2

## 날아가는 데 걸리는 시간.
var duration: float = 0.0
## 화살 그림 판.
var mesh: MeshInstance3D

# 출발·도착·포물선 높이.
var _from: Vector3
var _to: Vector3
var _arc: float

# 그림이 없을 때 쓰는 흰 줄 (한 번만 만든다).
static var _fallback: Texture2D


## 거리에 비례하되 하한·상한이 있는 비행 시간.
static func flight_time(distance: float) -> float:
	return clampf(distance / SPEED, MIN_FLIGHT, MAX_FLIGHT)


## 진행률 t 의 위치: 직선 위에 4·arc·t·(1−t) 만큼 띄운다 (가운데에서 arc).
static func position_at(from: Vector3, to: Vector3, arc: float, t: float) -> Vector3:
	return from.lerp(to, t) + Vector3.UP * (4.0 * arc * t * (1.0 - t))


## 화살 하나를 만들어 parent 에 붙이고 출발점에 놓는다. texture 가 null 이면 흰 줄로 그린다.
static func spawn(parent: Node, texture: Texture2D, from: Vector3, to: Vector3) -> Projectile:
	# 화살 노드.
	var arrow := Projectile.new()
	arrow.name = "Projectile"
	# 그림 (없으면 흰 줄).
	var art: Texture2D = texture if texture != null else _get_fallback()
	var aspect: float = float(art.get_height()) / float(art.get_width()) if texture != null else _FALLBACK_ASPECT
	# 판.
	arrow.mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(LENGTH, LENGTH * aspect)
	arrow.mesh.mesh = quad
	# 무광, 알파 잘라내기, 픽셀 그대로, 양면.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = art
	arrow.mesh.material_override = material
	arrow.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.add_child(arrow.mesh)
	# 궤적.
	var distance: float = from.distance_to(to)
	arrow._from = from
	arrow._to = to
	arrow._arc = distance * ARC_PER_DISTANCE
	arrow.duration = flight_time(distance)
	# 붙이고 출발점에 놓는다.
	parent.add_child(arrow)
	arrow._place(0.0)
	return arrow


## 도착할 때까지 날아가고 스스로 지운다. await 할 수 있다.
func fly() -> void:
	# 0→1 진행률.
	var tween: Tween = create_tween()
	tween.tween_method(_place, 0.0, 1.0, duration)
	await tween.finished
	# 지운다.
	queue_free()


# 진행률 t 의 위치에 놓고, 카메라를 보며 화면상 진행 방향으로 돌린다.
func _place(t: float) -> void:
	# 위치.
	position = position_at(_from, _to, _arc, t)
	# 카메라가 없으면 (테스트) 방향은 그대로.
	if not is_inside_tree():
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	# 조금 뒤 위치와의 차이 = 진행 방향.
	var direction: Vector3 = position_at(_from, _to, _arc, t + 0.02) - position
	# 카메라 오른쪽·위로 투영한 화면상 각도.
	var view: Basis = camera.global_basis
	var angle: float = atan2(direction.dot(view.y), direction.dot(view.x))
	# 판(+Z)이 카메라를 보게 하고 그 평면 안에서 돌린다.
	basis = view * Basis(Vector3.BACK, angle)


# 16×4 흰 줄 (가운데 두 줄만 불투명).
static func _get_fallback() -> Texture2D:
	# 처음 한 번만 만든다.
	if _fallback == null:
		var image := Image.create(16, 4, false, Image.FORMAT_RGBA8)
		for y in 4:
			for x in 16:
				image.set_pixel(x, y, Color.WHITE if y == 1 or y == 2 else Color(1, 1, 1, 0))
		_fallback = ImageTexture.create_from_image(image)
	return _fallback
```

- [ ] **Step 5: 통과 확인** — 재스캔 후 테스트 실행. Expected: 전체 통과.

- [ ] **Step 6: 커밋**

```bash
git add Art/effects/arrow.png Art/effects/arrow.png.import Scripts/view/projectile.gd* tests/test_projectile.gd* tests/run_tests.gd
git commit -m "feat: add arcing arrow projectile for ranged attacks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `ScreenPulse` — 비네트·색수차 화면 셰이더

**Files:**
- Create: `Shaders/screen_pulse.gdshader`, `Scripts/view/screen_pulse.gd`, `tests/test_screen_pulse.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Produces: `class_name ScreenPulse extends CanvasLayer`
  - 상수 `DURATION 0.4`, `BASE_VIGNETTE 0.38`, `VIGNETTE_BOOST 0.25`
  - `var overlay: ColorRect`, `var material: ShaderMaterial` (트리에 붙기 전 `_init` 에서 만든다)
  - `func pulse(strength: float) -> void`, `func tick(real_delta: float) -> void`, `func level() -> float`
  - 셰이더 uniform: `vignette`, `vignette_smoothness`, `chromatic`

- [ ] **Step 1: 실패하는 테스트** — `tests/test_screen_pulse.gd`

```gdscript
# ScreenPulse(화면 펄스) 테스트: 올랐다가 실제 0.4초에 가라앉고, 셰이더 값에 반영되고, 클릭을 막지 않는지.
extends TestCase


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 펄스와 가라앉기.
	_test_pulse_and_decay()
	# 겹친 펄스.
	_test_stronger_pulse_wins()
	# 덮개 설정.
	_test_overlay()
	# 결과를 돌려준다.
	return results()


# 처치 펄스 1 → 색수차 1·비네트 0.63, 0.2초 뒤 절반, 0.4초 뒤 기본값.
func _test_pulse_and_decay() -> void:
	# 펄스.
	var fx := ScreenPulse.new()
	# 평소.
	check("rests at the base vignette", is_equal_approx(fx.material.get_shader_parameter("vignette"), ScreenPulse.BASE_VIGNETTE))
	# 처치.
	fx.pulse(1.0)
	# 오른다.
	check("pulse raises chromatic", is_equal_approx(fx.material.get_shader_parameter("chromatic"), 1.0))
	check("pulse tightens the vignette", is_equal_approx(fx.material.get_shader_parameter("vignette"), 0.63))
	# 0.2초.
	fx.tick(0.2)
	# 절반.
	check("pulse decays linearly", is_equal_approx(fx.level(), 0.5))
	# 0.4초.
	fx.tick(0.2)
	# 기본값.
	check("pulse settles", is_equal_approx(fx.level(), 0.0) and is_equal_approx(fx.material.get_shader_parameter("vignette"), ScreenPulse.BASE_VIGNETTE))
	# 정리.
	fx.free()


# 약한 펄스가 센 펄스를 덮어쓰지 않는다.
func _test_stronger_pulse_wins() -> void:
	# 펄스.
	var fx := ScreenPulse.new()
	# 센 것 다음 약한 것.
	fx.pulse(1.0)
	fx.pulse(0.5)
	# 1 유지.
	check("weaker pulse does not lower the level", is_equal_approx(fx.level(), 1.0))
	# 정리.
	fx.free()


# 덮개는 화면 전체를 덮고 마우스를 통과시키며, HUD 보다 아래 층이다.
func _test_overlay() -> void:
	# 펄스.
	var fx := ScreenPulse.new()
	# 마우스 무시.
	check("pulse overlay ignores the mouse", fx.overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	# 전체 화면.
	check("overlay fills the screen", is_equal_approx(fx.overlay.anchor_right, 1.0) and is_equal_approx(fx.overlay.anchor_bottom, 1.0))
	# HUD(1) 아래.
	check("overlay sits under the hud layer", fx.layer < 1)
	# 정리.
	fx.free()
```

`TEST_SCRIPTS` 에 `"res://tests/test_screen_pulse.gd",` 추가.

- [ ] **Step 2: 실패 확인** — Expected: `ScreenPulse` 없음으로 FAIL.

- [ ] **Step 3: 셰이더** — `Shaders/screen_pulse.gdshader`

```glsl
// 화면 전체 후처리: 가장자리를 어둡게(비네트) 하고, 펄스 때 가장자리로 갈수록 색을 어긋나게(색수차) 한다.
shader_type canvas_item;

// 3D 가 그려진 화면.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
// 가장자리 어둡기 (0 = 없음).
uniform float vignette : hint_range(0.0, 1.0) = 0.38;
// 어두워지기 시작하는 범위 (클수록 안쪽부터 부드럽게).
uniform float vignette_smoothness : hint_range(0.01, 1.0) = 0.45;
// 색수차 세기 (1 이면 가장자리에서 약 4픽셀 어긋남).
uniform float chromatic : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	// 화면 중심에서의 방향 (가장자리 ±0.5).
	vec2 d = uv - vec2(0.5);
	// 가장자리일수록 크게 어긋난다.
	vec2 offset = d * 2.0 * chromatic * 4.0 * SCREEN_PIXEL_SIZE;
	float r = texture(screen_texture, uv + offset).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - offset).b;
	// 중심 0, 모서리 1 인 거리.
	float dist = length(d) * 1.41421;
	// 안쪽은 그대로, 바깥으로 갈수록 vignette 만큼 어둡게.
	float shade = 1.0 - vignette * smoothstep(1.0 - vignette_smoothness - 0.3, 1.0, dist);
	COLOR = vec4(vec3(r, g, b) * shade, 1.0);
}
```

- [ ] **Step 4: 구현** — `Scripts/view/screen_pulse.gd`

```gdscript
## 화면 가장자리 비네트를 늘 깔고, 큰 타격·처치 때 가장자리를 조이고 색을 번지게 했다가 되돌린다.
## 실제 시간으로 가라앉아 슬로모션·히트스톱 중에도 제 속도다 (유니티 ScreenPulse).
class_name ScreenPulse
# CanvasLayer: 3D 화면 위, HUD 아래 층에 화면 전체 덮개를 그린다.
extends CanvasLayer

## 펄스가 0 으로 가라앉는 실제 시간.
const DURATION: float = 0.4
## 평소 비네트 세기.
const BASE_VIGNETTE: float = 0.38
## 펄스 1 일 때 더해지는 비네트.
const VIGNETTE_BOOST: float = 0.25
## 화면 셰이더.
const SHADER: Shader = preload("res://Shaders/screen_pulse.gdshader")

## 화면 전체 덮개.
var overlay: ColorRect
## 덮개의 셰이더 재질.
var material: ShaderMaterial

# 지금 펄스 세기 (0..1).
var _level: float = 0.0
# 지난 프레임의 실제 시각 (마이크로초).
var _last_usec: int = 0


## 덮개와 재질을 만든다 (트리에 붙기 전에 값을 읽을 수 있게).
func _init() -> void:
	# HUD(층 1) 아래.
	layer = 0
	# 화면 전체를 덮는 사각형.
	overlay = ColorRect.new()
	overlay.name = "PulseOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 카드·칸 클릭을 가로채지 않는다.
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 셰이더.
	material = ShaderMaterial.new()
	material.shader = SHADER
	overlay.material = material
	add_child(overlay)
	# 평소 값.
	_apply()


## 펄스를 준다 (처치 1, 큰 타격 0.5). 이미 더 세면 그대로.
func pulse(strength: float) -> void:
	# 큰 쪽.
	_level = maxf(_level, clampf(strength, 0.0, 1.0))
	_apply()


## 지금 펄스 세기.
func level() -> float:
	return _level


## 실제 시간 real_delta 만큼 가라앉힌다.
func tick(real_delta: float) -> void:
	# 가라앉을 것이 없다.
	if _level <= 0.0:
		return
	# 0.4초에 1 만큼.
	_level = maxf(0.0, _level - real_delta / DURATION)
	_apply()


## 매 프레임: 실제 시간 차이로 가라앉힌다.
func _process(_delta: float) -> void:
	# 지금 실제 시각.
	var now: int = Time.get_ticks_usec()
	# 첫 프레임은 0.
	var real_delta: float = 0.0 if _last_usec == 0 else float(now - _last_usec) / 1000000.0
	_last_usec = now
	tick(real_delta)


# 세기를 셰이더 값으로.
func _apply() -> void:
	material.set_shader_parameter("chromatic", _level)
	material.set_shader_parameter("vignette", BASE_VIGNETTE + VIGNETTE_BOOST * _level)
```

- [ ] **Step 5: 통과 확인** — 재스캔 후 테스트 실행. Expected: 전체 통과.

- [ ] **Step 6: 커밋**

```bash
git add Shaders/screen_pulse.gdshader* Scripts/view/screen_pulse.gd* tests/test_screen_pulse.gd* tests/run_tests.gd
git commit -m "feat: add screen pulse overlay with vignette and chromatic aberration

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `UnitView` 타격 순간 — 흰 번쩍임·불꽃·숫자 튀기기·넉백

**Files:**
- Modify: `Scripts/view/unit_view.gd`
- Test: `tests/test_unit_view.gd`

**Interfaces:**
- Consumes: `UnitMotion.knockback_reach` (A), `UnitView` A 구조 (`body_material`, `_hit_step`, `flash_and_shake`, `pop_text`, `_process`)
- Produces:
  - 상수 `HIT_WHITE_TIME 0.06`, `DAMAGE_POP_PUNCH 1.6`, `KILL_POP_PUNCH 2.0`, `SPARK_COUNT 12`, `CHEST_HEIGHT` (= `SPRITE_HEIGHT * 0.55`)
  - `var sparks: CPUParticles3D`
  - `func start_impact() -> void`, `func tick_flash(now_msec: int) -> void`
  - `static func pop_scale(t: float, punch: float) -> float`
  - `func pop_text(text: String, color: Color, punch: float = 1.0) -> void`
  - `func flash_and_shake(knockback: Vector3 = Vector3.ZERO) -> void`

- [ ] **Step 1: 실패하는 테스트** — `test_unit_view.gd` 의 `run()` 에 `_test_impact()`·`_test_pop_scale()` 호출을 추가하고 함수를 붙인다.

```gdscript
# 맞는 순간: 몸이 흰색이 되고 불꽃이 튀며, 실제 0.06초가 지나면 흰색이 꺼지는지.
func _test_impact() -> void:
	# 아군.
	var view: UnitView = _view(true)
	# 불꽃이 있다.
	check("sparks exist", view.sparks != null and view.sparks.one_shot)
	# 불꽃은 가슴 높이.
	check("sparks at chest height", is_equal_approx(view.sparks.position.y, UnitView.CHEST_HEIGHT))
	# 맞는다.
	view.start_impact()
	# 흰색.
	check("impact flashes white", is_equal_approx(view.body_material.get_shader_parameter("flash"), 1.0))
	# 불꽃 방출.
	check("impact emits sparks", view.sparks.emitting)
	# 아직 0.06초 전.
	view.tick_flash(Time.get_ticks_msec())
	# 그대로 흰색.
	check("white holds briefly", is_equal_approx(view.body_material.get_shader_parameter("flash"), 1.0))
	# 0.06초 뒤.
	view.tick_flash(Time.get_ticks_msec() + 61)
	# 꺼짐.
	check("white clears after 0.06 s", is_equal_approx(view.body_material.get_shader_parameter("flash"), 0.0))
	# 지운다.
	view.free()


# 피해 숫자 크기: punch 배에서 시작해 0.15초(POP_TIME 0.6 의 1/4)에 1 이 되고 그 뒤는 1.
func _test_pop_scale() -> void:
	# 시작.
	check("pop starts punched", is_equal_approx(UnitView.pop_scale(0.0, 1.6), 1.6))
	# 절반 (0.075초 = t 0.125).
	check("pop shrinks", is_equal_approx(UnitView.pop_scale(0.125, 2.0), 1.5))
	# 0.15초.
	check("pop settles at 0.15 s", is_equal_approx(UnitView.pop_scale(0.25, 2.0), 1.0))
	# 끝.
	check("pop stays at 1", is_equal_approx(UnitView.pop_scale(1.0, 2.0), 1.0))
```

`run()` 의 `_test_aura()` 다음 줄에:

```gdscript
	# 맞는 순간 이펙트.
	_test_impact()
	# 피해 숫자 크기.
	_test_pop_scale()
```

- [ ] **Step 2: 실패 확인** — Expected: `sparks`/`start_impact` 없음으로 FAIL.

- [ ] **Step 3: 구현** — `unit_view.gd`

상수 영역(오라 상수 다음)에 추가:

```gdscript
## 맞는 순간 몸이 완전히 흰색인 실제 시간.
const HIT_WHITE_TIME: float = 0.06
## 피해 숫자가 처음 튀는 배율.
const DAMAGE_POP_PUNCH: float = 1.6
## 처치 숫자가 처음 튀는 배율.
const KILL_POP_PUNCH: float = 2.0
## 피해 숫자가 크게 튀었다가 원래 크기로 돌아오는 시간.
const POP_PUNCH_TIME: float = 0.15
## 한 번에 튀는 불꽃 수.
const SPARK_COUNT: int = 12
## 불꽃·화살이 오가는 가슴 높이.
const CHEST_HEIGHT: float = SPRITE_HEIGHT * 0.55
# 불꽃 색 (뜨거운 흰색 → 주황).
const _SPARK_HOT := Color(1.0, 0.95, 0.8)
const _SPARK_WARM := Color(1.0, 0.55, 0.15)
```

변수 영역(`aura` 다음)에 추가:

```gdscript
## 맞는 순간 튀는 불꽃 (한 번씩 터뜨린다).
var sparks: CPUParticles3D
# 흰 번쩍임이 꺼질 실제 시각 (밀리초, 0 이면 꺼져 있음).
var _white_until_msec: int = 0
```

`setup` 의 `# --- 오라 ---` 바로 앞에:

```gdscript
	# --- 불꽃 ---
	sparks = _make_sparks()
```

`_process` 끝에 추가:

```gdscript
	# 흰 번쩍임은 실제 시간으로 끈다 (히트스톱 중에도 0.06초면 꺼진다).
	tick_flash(Time.get_ticks_msec())
	# 불꽃은 히트스톱 중에도 제 속도로 날아간다.
	sparks.speed_scale = 1.0 / maxf(Engine.time_scale, 0.01)
```

`flash_and_shake` 를 교체 (넉백 인자, 타격 순간):

```gdscript
## 피격 연출: 흰 번쩍임·불꽃으로 시작해 피격 띠(또는 움찔 자세) + 붉은 번쩍임 2회 + 좌우 흔들림.
## knockback 은 맞아서 밀려날 최대 변위(바닥 평면). 끝나면 정확히 제자리로 돌아온다. await 할 수 있다.
func flash_and_shake(knockback: Vector3 = Vector3.ZERO) -> void:
	# 연출 시작.
	_acting = true
	# 맞는 첫 순간.
	start_impact()
	# 0→1 진행률.
	var tween: Tween = create_tween()
	tween.tween_method(_hit_step.bind(home_position, knockback), 0.0, 1.0, hit_duration())
	await tween.finished
	# 제자리·원래 색.
	position = home_position
	body.position = Vector3.ZERO
	body_material.set_shader_parameter("tint", Color.WHITE)
	# 연출 끝, 대기 그림으로.
	_acting = false
	_return_to_idle()
```

`_hit_step` 시그니처와 끝을 바꾼다:

```gdscript
# 피격 한 순간: 모습, 4구간 중 0·2번째 붉은색, 좌우 흔들림, 넉백.
func _hit_step(t: float, home: Vector3, knockback: Vector3) -> void:
```

(본문 기존 줄 유지) 마지막 줄 다음에 추가:

```gdscript
	# 밀렸다가 돌아온다 (넉백이 없으면 제자리).
	position = home + knockback * UnitMotion.knockback_reach(t)
```

새 함수들 (`pop_text` 교체 포함):

```gdscript
## 맞는 첫 순간: 몸을 완전한 흰색으로 칠하고 불꽃을 튀긴다. 흰색은 실제 시간 0.06초 뒤 꺼진다.
func start_impact() -> void:
	# 흰색.
	body_material.set_shader_parameter("flash", 1.0)
	# 끌 시각.
	_white_until_msec = Time.get_ticks_msec() + int(HIT_WHITE_TIME * 1000.0)
	# 불꽃 한 번.
	sparks.restart()


## 실제 시각 now_msec 가 흰색을 끌 때를 지났으면 끈다.
func tick_flash(now_msec: int) -> void:
	# 켜져 있고 시간이 됐으면.
	if _white_until_msec > 0 and now_msec >= _white_until_msec:
		_white_until_msec = 0
		body_material.set_shader_parameter("flash", 0.0)


## 피해 숫자 크기: punch 배에서 시작해 POP_PUNCH_TIME 동안 1 로 줄어든다. t 는 POP_TIME 기준 진행률.
static func pop_scale(t: float, punch: float) -> float:
	return lerpf(punch, 1.0, clampf(t * POP_TIME / POP_PUNCH_TIME, 0.0, 1.0))
```

`pop_text` 는 기존 본문을 유지하되 시그니처에 `punch: float = 1.0` 를 더하고, 기존 병렬 트윈에 크기 줄을 하나 추가한다:

```gdscript
func pop_text(text: String, color: Color, punch: float = 1.0) -> void:
```

```gdscript
	# 처음엔 크게 튀었다가 원래 크기로.
	tween.tween_method(func(t: float) -> void: label.scale = Vector3.ONE * pop_scale(t, punch), 0.0, 1.0, POP_TIME)
```

`_make_aura` 앞에 불꽃 생성 함수:

```gdscript
# 가슴 높이에서 사방으로 튀는 네모 불꽃 (유니티 UnitView.MakeSparks). 한 번 터뜨리고 끝난다.
func _make_sparks() -> CPUParticles3D:
	# 입자 노드.
	var particles := CPUParticles3D.new()
	particles.name = "Sparks"
	particles.position = Vector3(0.0, CHEST_HEIGHT, 0.0)
	# 한 번에 다 나온다.
	particles.amount = SPARK_COUNT
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false
	particles.lifetime = 0.25
	# 이미 튄 불꽃은 몸이 밀려도 제자리.
	particles.local_coords = false
	# 작은 구에서 사방으로.
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.1
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.0
	# 중력 절반.
	particles.gravity = Vector3(0.0, -4.9, 0.0)
	# 크기 0.06~0.1.
	particles.scale_amount_min = 0.75
	particles.scale_amount_max = 1.25
	# 흰색~주황 사이에서 하나.
	var colors := Gradient.new()
	colors.set_color(0, _SPARK_HOT)
	colors.set_color(1, _SPARK_WARM)
	particles.color_initial_ramp = colors
	# 카메라를 보는 네모, 빛을 더한다.
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	quad.material = material
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	return particles
```

`reset_pose` 끝에 추가:

```gdscript
	# 흰 번쩍임 예약도 지운다.
	_white_until_msec = 0
```

- [ ] **Step 4: 통과 확인** — 테스트 실행. Expected: 전체 통과.

- [ ] **Step 5: 커밋**

```bash
git add Scripts/view/unit_view.gd tests/test_unit_view.gd
git commit -m "feat: add white hit flash, sparks, punchy damage numbers and knockback to unit view

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: `BattlePlayback` 타격 동기화와 `BattleRoot` 연결

**Files:**
- Modify: `Scripts/view/battle_playback.gd`, `Scripts/view/battle_root.gd`
- Test: `tests/test_battle_playback.gd`

**Interfaces:**
- Consumes: `BattleCamera` (Task 2), `BattleAudio`/`BattleSounds` (Task 1), `Projectile.spawn/fly` (Task 3), `ScreenPulse.pulse` (Task 4), `UnitView.flash_and_shake(knockback)`, `pop_text(..., punch)`, `attack_duration()`, `hit_duration()`, `CHEST_HEIGHT`, `KILL_POP_PUNCH`, `DAMAGE_POP_PUNCH`, `lunge_toward(target, distance)` (Task 5 / A), `UnitMotion.ATTACK_STRIKE`
- Produces:
  - `BattlePlayback`: `var camera_fx: BattleCamera`, `var audio: BattleAudio`, `var screen_fx: ScreenPulse`, `var projectile_texture: Texture2D`
  - 상수 `HIT_STOP_TIME 0.06`, `KILL_HIT_STOP_TIME 0.1`, `MAX_KNOCKBACK 0.35`, `RANGED_RECOIL -0.1`, `BIG_HIT_DAMAGE 8`
  - `static func impact_start(events: Array[BattleEvent], attack_index: int) -> int`, `static func knockback_distance(amount: int) -> float`, `static func keeps_camera_push(kind: BattleEvent.Kind) -> bool`, `static func attack_sound_at_strike(type: CardData.AttackType) -> bool`

- [ ] **Step 1: 실패하는 테스트** — `test_battle_playback.gd` 의 `run()` 끝(결과 반환 전)에 추가:

```gdscript
	# 타격 묶음 찾기.
	_test_impact_start()
	# 넉백 거리·카메라 유지·발사음 시점.
	_test_impact_rules()
	# instant 재생은 소리를 내지 않는다.
	_test_instant_is_silent()
```

함수들:

```gdscript
# 종류 목록으로 이벤트 배열을 만든다.
func _events(kinds: Array) -> Array[BattleEvent]:
	# 결과.
	var events: Array[BattleEvent] = []
	# 종류마다.
	for kind in kinds:
		events.append(BattleEvent.new(kind))
	# 돌려준다.
	return events


# 공격 뒤 첫 피해 위치: 바로 뒤, 로그 건너뜀, 없음, 다른 이벤트가 끼면 −1.
func _test_impact_start() -> void:
	# 종류 줄임말.
	var K := BattleEvent.Kind
	# 바로 뒤.
	check_eq("impact_start: damage right after", BattlePlayback.impact_start(_events([K.CARD_PLAYED, K.DAMAGED, K.DIED]), 0), 1)
	# 로그 건너뜀.
	check_eq("impact_start: skips logs", BattlePlayback.impact_start(_events([K.CARD_PLAYED, K.LOG, K.LOG, K.DAMAGED]), 0), 3)
	# 없음.
	check_eq("impact_start: no damage after attack", BattlePlayback.impact_start(_events([K.CARD_PLAYED, K.LOG]), 0), -1)
	# 다른 이벤트.
	check_eq("impact_start: other event breaks it", BattlePlayback.impact_start(_events([K.ENEMY_ACTED, K.BLOCK_GAINED, K.DAMAGED]), 0), -1)


# 넉백은 0 → 0, 증가, 상한 0.35. 피해·사망·로그만 푸시를 유지. 원거리만 타격 시점에 발사음.
func _test_impact_rules() -> void:
	# 0.
	check("knockback_distance(0) == 0", is_equal_approx(BattlePlayback.knockback_distance(0), 0.0))
	# 피해 5 → 0.25.
	check("knockback grows with damage", is_equal_approx(BattlePlayback.knockback_distance(5), 0.25))
	# 상한.
	check("knockback caps", is_equal_approx(BattlePlayback.knockback_distance(40), BattlePlayback.MAX_KNOCKBACK))
	# 푸시 유지.
	check("damage keeps the push", BattlePlayback.keeps_camera_push(BattleEvent.Kind.DAMAGED) and BattlePlayback.keeps_camera_push(BattleEvent.Kind.LOG))
	# 푸시 해제.
	check("turn start releases the push", not BattlePlayback.keeps_camera_push(BattleEvent.Kind.TURN_STARTED))
	# 원거리.
	check("ranged sound at strike", BattlePlayback.attack_sound_at_strike(CardData.AttackType.RANGED))
	# 근접.
	check("melee sound at start", not BattlePlayback.attack_sound_at_strike(CardData.AttackType.MELEE))


# 재생기에 소리를 달아도 instant 재생(처치까지)은 소리를 하나도 내지 않고 결과는 같다.
func _test_instant_is_silent() -> void:
	# 준비물.
	var rig: Dictionary = _rig()
	var state: BattleState = rig["state"]
	var recorder: BattleEventRecorder = rig["recorder"]
	var board: Board3D = rig["board"]
	var playback: BattlePlayback = rig["playback"]
	# 소리.
	var audio := BattleAudio.new()
	audio.sounds = load("res://Resources/audio/battle_sounds.tres")
	playback.audio = audio
	# 시작과 처치.
	state.start_battle()
	playback.play(recorder.take_events())
	board.sync_from_state(state)
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	state.play_card(0, foe.team, foe.cell)
	playback.play(recorder.take_events())
	# 결과는 그대로.
	check("instant kill still hides the foe", not board.view_for(foe).visible)
	# 소리 없음.
	check_eq("instant playback is silent", audio.play_count, 0)
	# 정리.
	audio.free()
	_free(rig)
```

- [ ] **Step 2: 실패 확인** — Expected: `impact_start` 등 없음으로 FAIL.

- [ ] **Step 3: `BattlePlayback` 구현** — `Scripts/view/battle_playback.gd`

상수 영역 끝에 추가:

```gdscript
## 피해 순간 히트스톱 길이 (실제 초).
const HIT_STOP_TIME: float = 0.06
## 처치 순간 히트스톱 길이 (실제 초).
const KILL_HIT_STOP_TIME: float = 0.1
## 넉백 최대 거리.
const MAX_KNOCKBACK: float = 0.35
## 원거리는 앞으로 나가지 않고 쏘는 순간 살짝 뒤로 물러난다.
const RANGED_RECOIL: float = -0.1
## 이 이상 피해면 화면 펄스를 약하게 준다.
const BIG_HIT_DAMAGE: int = 8
# 큰 타격 펄스 세기.
const _BIG_HIT_PULSE: float = 0.5
```

신호 영역에 추가:

```gdscript
## (내부용) 공격자의 돌진이 끝났을 때.
signal _lunge_finished
```

변수 영역(`instant` 아래)에 추가:

```gdscript
## 카메라 연출 (없으면 카메라 연출 없이 재생).
var camera_fx: BattleCamera
## 효과음 재생기 (없으면 소리 없이 재생).
var audio: BattleAudio
## 화면 펄스 (없으면 펄스 없이 재생).
var screen_fx: ScreenPulse
## 원거리 화살 그림 (없으면 흰 줄).
var projectile_texture: Texture2D

# 지금 재생 중인 타격 묶음을 만든 공격의 종류. 공격 없이 나온 피해는 근접으로 친다.
var _impact_type: CardData.AttackType = CardData.AttackType.MELEE
# 타격 묶음을 만든 공격자의 자리 (넉백 방향). _has_impact_origin 이 false 면 넉백하지 않는다.
var _impact_origin: Vector3 = Vector3.ZERO
var _has_impact_origin: bool = false
```

`play()` 의 while 본문을 교체:

```gdscript
	while i < events.size():
		# 이번 이벤트.
		var event: BattleEvent = events[i]
		# 피해·쓰러짐은 이어지는 만큼 모아 동시에 재생한다 (광역 공격이 한꺼번에 보이게).
		if _is_damage(event.kind):
			var batch: Array[BattleEvent] = []
			while i < events.size() and _is_damage(events[i].kind):
				batch.append(events[i])
				i += 1
			await _play_damage_batch(batch)
			_release_camera()
			continue
		# 돌진한 공격의 결과가 아니면 구도를 되돌린다.
		if not keeps_camera_push(event.kind):
			_release_camera()
		match event.kind:
			# 차례 시작: 현재 유닛 표시·순서 바 갱신.
			BattleEvent.Kind.TURN_STARTED:
				await _turn_started(event)
			# 카드 사용·적 행동: 뒤따르는 피해가 있으면 무기가 닿는 순간에 그 피해를 재생한다.
			BattleEvent.Kind.CARD_PLAYED, BattleEvent.Kind.ENEMY_ACTED:
				var impact: int = impact_start(events, i) if not instant and _is_attack(event) else -1
				# 피해가 없으면(빗나감·방어·휴식) 돌진·깡충만.
				if impact < 0:
					var no_hits: Array[BattleEvent] = []
					if event.kind == BattleEvent.Kind.CARD_PLAYED:
						await _card_played(event, no_hits, no_hits)
					else:
						await _enemy_acted(event, no_hits, no_hits)
				else:
					# 타격 묶음의 끝.
					var end: int = impact
					while end < events.size() and _is_damage(events[end].kind):
						end += 1
					# 사이의 로그와 타격 묶음.
					var logs: Array[BattleEvent] = events.slice(i + 1, impact)
					var hits: Array[BattleEvent] = events.slice(impact, end)
					if event.kind == BattleEvent.Kind.CARD_PLAYED:
						await _card_played(event, logs, hits)
					else:
						await _enemy_acted(event, logs, hits)
					_release_camera()
					# 묶음 끝 다음 이벤트로.
					i = end
					continue
			# 회복: 체력 바 갱신·숫자.
			BattleEvent.Kind.HEALED:
				await _healed(event)
			# 방어도: 방어도 표시·숫자.
			BattleEvent.Kind.BLOCK_GAINED:
				await _block_gained(event)
			# 로그: 기다림 없이 한 줄 추가.
			BattleEvent.Kind.LOG:
				hud.append_log(event.text)
			# 전투 종료: 승패 배너와 로그.
			BattleEvent.Kind.BATTLE_ENDED:
				hud.show_banner(event.ally_won)
				hud.append_log("전투 종료 — %s" % ("승리" if event.ally_won else "패배"))
			# 드로우.
			BattleEvent.Kind.CARD_DRAWN:
				hud.draw_card(event)
				await _wait(DRAW_WAIT)
			# 리셔플.
			BattleEvent.Kind.DECK_RESHUFFLED:
				hud.reshuffle(event)
				await _wait(RESHUFFLE_WAIT)
			# 손패 버리기.
			BattleEvent.Kind.HAND_DISCARDED:
				hud.discard_hand(event)
				await _wait(DISCARD_WAIT)
			# 이동.
			BattleEvent.Kind.UNIT_MOVED:
				await _unit_moved(event)
		# 다음 이벤트로.
		i += 1
	# 남은 푸시를 푼다.
	_release_camera()
	# 모든 이벤트를 재생했음을 알린다.
	finished.emit()
```

정적 함수와 도우미 (`_play_damage_batch` 앞):

```gdscript
## 공격 이벤트 뒤(로그는 건너뜀)에 이어지는 피해·사망 묶음의 첫 인덱스. 다른 이벤트가 끼거나 없으면 −1.
static func impact_start(events: Array[BattleEvent], attack_index: int) -> int:
	for i in range(attack_index + 1, events.size()):
		var kind: BattleEvent.Kind = events[i].kind
		# 피해·사망이면 여기.
		if kind == BattleEvent.Kind.DAMAGED or kind == BattleEvent.Kind.DIED:
			return i
		# 로그 말고 다른 것이 끼면 이 공격의 결과가 아니다.
		if kind != BattleEvent.Kind.LOG:
			return -1
	# 없음.
	return -1


## 피해량에 비례해 밀리는 거리. 막힌(0) 공격은 밀지 않는다.
static func knockback_distance(amount: int) -> float:
	return 0.0 if amount <= 0 else minf(0.1 + 0.03 * amount, MAX_KNOCKBACK)


## 돌진한 공격의 결과(피해·사망과 그 사이 로그)만 푸시인을 유지한다.
static func keeps_camera_push(kind: BattleEvent.Kind) -> bool:
	return kind == BattleEvent.Kind.DAMAGED or kind == BattleEvent.Kind.DIED or kind == BattleEvent.Kind.LOG


## 원거리 발사음은 화살이 나가는 순간에 낸다. 근접 휘두르기는 예비동작부터 들려야 타격을 이끈다.
static func attack_sound_at_strike(type: CardData.AttackType) -> bool:
	return type == CardData.AttackType.RANGED


# 피해·사망 이벤트인지.
static func _is_damage(kind: BattleEvent.Kind) -> bool:
	return kind == BattleEvent.Kind.DAMAGED or kind == BattleEvent.Kind.DIED


# 대상이 있는 공격인지 (카드 사용, 또는 대상 있는 적 공격).
static func _is_attack(event: BattleEvent) -> bool:
	return event.kind == BattleEvent.Kind.CARD_PLAYED or (event.action == EnemyBrain.Action.ATTACK and event.target != null)


# 연출 부품이 쓸 수 있는지 (instant 면 모두 끈다).
func _has_camera() -> bool:
	return camera_fx != null and not instant


func _has_audio() -> bool:
	return audio != null and audio.sounds != null and not instant


func _has_pulse() -> bool:
	return screen_fx != null and not instant


# 카메라 푸시를 푼다.
func _release_camera() -> void:
	if _has_camera():
		camera_fx.release()


# 맞은 유닛을 공격자 반대 방향(바닥 평면)으로 밀 변위. 공격자를 모르면 0.
func _knockback(view: UnitView, amount: int) -> Vector3:
	if not _has_impact_origin:
		return Vector3.ZERO
	var away: Vector3 = view.home_position - _impact_origin
	away.y = 0.0
	return away.normalized() * knockback_distance(amount) if away.length_squared() > 0.0 else Vector3.ZERO
```

`_card_played` 교체:

```gdscript
## 카드 사용 연출: 손패에서 카드를 빼고, 사용자가 대상 쪽으로 공격한다. hits 가 있으면 무기가 닿는 순간 재생한다.
func _card_played(event: BattleEvent, logs: Array[BattleEvent], hits: Array[BattleEvent]) -> void:
	# 손패에서 쓴 카드를 없애고 SP·묘지 숫자를 갱신한다 (instant 에서도 해야 하므로 먼저).
	hud.remove_played_card(event)
	# 테스트 모드면 움직임 연출은 건너뛴다.
	if instant:
		return
	# 카드가 사라지는 것이 보이도록 잠깐 기다린다.
	await _wait(PLAY_REMOVE_WAIT)
	# 카드를 쓴 유닛.
	var view: UnitView = board.view_for(event.unit)
	# 머리 위에 카드 이름.
	view.pop_text(event.card.display_name, Color.WHITE)
	# 겨냥한 칸 쪽으로 공격한다 (유닛이 없어도 칸 위치로).
	await _attack(view, board.layout.cell_position(event.target_team, event.target_cell), event.card.attack_type, logs, hits)
```

`_enemy_acted` 교체:

```gdscript
## 적 행동 연출: 공격이면 공격(뒤따르는 피해를 타격 순간에), 방어·휴식이면 깡충, 이동이면 없음.
func _enemy_acted(event: BattleEvent, logs: Array[BattleEvent], hits: Array[BattleEvent]) -> void:
	# 테스트 모드거나 이동이면 연출 없음.
	if instant or event.action == EnemyBrain.Action.MOVE:
		return
	# 행동한 적.
	var view: UnitView = board.view_for(event.unit)
	# 대상이 있는 공격.
	if event.action == EnemyBrain.Action.ATTACK and event.target != null:
		await _attack(view, board.view_for(event.target).home_position, (event.unit.data as EnemyData).attack_type, logs, hits)
	# 방어·휴식.
	else:
		await view.hop()
```

새 `_attack` 과 돌진 도우미:

```gdscript
# 공격 한 번: 푸시인·휘두르기 소리 → 돌진 시작 → 타격 시점까지 대기 → (원거리) 발사음·화살 → 타격 묶음 → 돌진 끝 대기.
func _attack(view: UnitView, target: Vector3, type: CardData.AttackType, logs: Array[BattleEvent], hits: Array[BattleEvent]) -> void:
	# 목표 쪽으로 조금 다가간다.
	if _has_camera():
		camera_fx.push_toward(target)
	# 근접은 예비동작부터 휘두르기 소리.
	if _has_audio() and not attack_sound_at_strike(type):
		audio.play(audio.sounds.for_attack(type))
	# 원거리는 뒤로 물러나는 반동, 근접은 앞으로 돌진. 기다리지 않고 시작한다.
	var ranged: bool = type == CardData.AttackType.RANGED
	var lunging: Array[bool] = [true]
	_lunge_and_flag(view, target, RANGED_RECOIL if ranged else UnitView.LUNGE_DISTANCE, lunging)
	# 무기가 닿는(쏘는) 순간까지.
	await _wait(UnitMotion.ATTACK_STRIKE * view.attack_duration())
	# 원거리는 이때 발사음과 화살.
	if _has_audio() and attack_sound_at_strike(type):
		audio.play(audio.sounds.for_attack(type))
	if ranged:
		var chest := Vector3.UP * UnitView.CHEST_HEIGHT
		var arrow: Projectile = Projectile.spawn(board, projectile_texture, view.home_position + chest, target + chest)
		await arrow.fly()
	# 타격 묶음.
	if not hits.is_empty():
		for log_event in logs:
			hud.append_log(log_event.text)
		_impact_type = type
		_impact_origin = view.home_position
		_has_impact_origin = true
		await _play_damage_batch(hits)
		_impact_type = CardData.AttackType.MELEE
		_has_impact_origin = false
	# 돌진이 끝날 때까지.
	while lunging[0]:
		await _lunge_finished


# 돌진을 끝까지 하고 flag[0] 을 false 로 바꾼 뒤 알린다 (호출한 쪽은 기다리지 않는다).
func _lunge_and_flag(view: UnitView, target: Vector3, distance: float, flag: Array[bool]) -> void:
	await view.lunge_toward(target, distance)
	flag[0] = false
	_lunge_finished.emit()
```

`_damaged` 교체:

```gdscript
## 피해 연출: 체력 표시 갱신, 튀는 숫자, 타격음, 히트스톱·흔들림, 큰 타격 펄스, 흰 번쩍임·불꽃·넉백.
func _damaged(event: BattleEvent) -> void:
	# 맞은 유닛.
	var view: UnitView = board.view_for(event.unit)
	# 체력·방어도 표시.
	view.set_stats(event.hp, event.unit.data.max_hp, event.block)
	# 로그.
	hud.append_log("%s 에게 %d 피해" % [event.unit.data.display_name, event.amount])
	# 테스트 모드면 여기까지만.
	if instant:
		return
	# 피해 숫자 (처치는 더 크게).
	view.pop_text("-%d" % event.amount, DAMAGE_COLOR, UnitView.KILL_POP_PUNCH if event.hp <= 0 else UnitView.DAMAGE_POP_PUNCH)
	# 타격음.
	if _has_audio():
		audio.play(audio.sounds.for_impact(_impact_type, event.amount, false))
	# 히트스톱과 흔들림.
	if _has_camera():
		camera_fx.hit_stop(HIT_STOP_TIME)
		camera_fx.shake(BattleCamera.shake_for_damage(event.amount, false))
	# 큰 타격 펄스.
	if _has_pulse() and event.amount >= BIG_HIT_DAMAGE:
		screen_fx.pulse(_BIG_HIT_PULSE)
	# 흰 번쩍임·불꽃·피격·넉백.
	await view.flash_and_shake(_knockback(view, event.amount))
	# 전체 피해 연출 시간이 DAMAGE_TIME 이 되도록 남은 시간 (피격 띠가 더 길면 기다리지 않는다).
	await _wait(maxf(0.0, DAMAGE_TIME - view.hit_duration()))
```

`_died` 교체:

```gdscript
## 쓰러짐 연출: 빈 칸 표시, 긴 히트스톱·최대 흔들림·슬로모션·펄스·처치음, 넘어지며 사라짐.
func _died(event: BattleEvent) -> void:
	# 빈 칸.
	board.mark_empty(event.unit.team, event.cell)
	# 쓰러진 유닛.
	var view: UnitView = board.view_for(event.unit)
	# 테스트 모드면 바로 숨긴다.
	if instant:
		view.set_alive(false)
		return
	# 카메라.
	if _has_camera():
		camera_fx.hit_stop(KILL_HIT_STOP_TIME)
		camera_fx.shake(BattleCamera.shake_for_damage(0, true))
		camera_fx.kill_slow_mo()
	# 펄스.
	if _has_pulse():
		screen_fx.pulse(1.0)
	# 처치음.
	if _has_audio():
		audio.play(audio.sounds.for_impact(_impact_type, 0, true))
	# 넘어지며 사라진다.
	await view.fade_out()
```

- [ ] **Step 4: `BattleRoot` 연결** — `Scripts/view/battle_root.gd`

상수 영역에 추가:

```gdscript
## 전투 효과음 묶음.
const BATTLE_SOUNDS: BattleSounds = preload("res://Resources/audio/battle_sounds.tres")
## 원거리 화살 그림.
const ARROW_TEXTURE: Texture2D = preload("res://Art/effects/arrow.png")
```

변수 영역에 추가:

```gdscript
## 카메라 타격 연출 (기본 구도 위에 푸시인·흔들림, 히트스톱·슬로모션).
var _camera_fx: BattleCamera
```

`_ready` 의 `_playback.hud = _hud` 다음 줄에 추가:

```gdscript
	# 카메라 연출을 만들어 카메라를 맡긴다.
	_camera_fx = BattleCamera.new()
	_camera_fx.camera = _camera
	add_child(_camera_fx)
	# 효과음 재생기.
	var battle_audio := BattleAudio.new()
	battle_audio.sounds = BATTLE_SOUNDS
	add_child(battle_audio)
	# 화면 펄스 (HUD 아래 층).
	var pulse := ScreenPulse.new()
	add_child(pulse)
	# 재생기에 연출 부품을 넘긴다.
	_playback.camera_fx = _camera_fx
	_playback.audio = battle_audio
	_playback.screen_fx = pulse
	_playback.projectile_texture = ARROW_TEXTURE
```

`_frame_camera` 의 마지막 세 줄(`_camera.fov` 이후)을 교체:

```gdscript
	# 시야각을 적용한다.
	_camera.fov = CAMERA_FOV_DEG
	# 바라볼 점에서 뒤(+z)·위(+y)로 distance 만큼 떨어진 곳.
	var camera_position: Vector3 = target + Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
	# 그 자리에서 바라볼 점을 보는 회전.
	var view := Transform3D(Basis.IDENTITY, camera_position).looking_at(target, Vector3.UP)
	# 연출이 이 구도 위에 오프셋을 더한다.
	_camera_fx.set_base(view.origin, view.basis)
```

- [ ] **Step 5: 통과 확인** — 테스트 실행. Expected: 전체 통과 (기존 재생 테스트 포함, 결과 동일).

- [ ] **Step 6: 커밋**

```bash
git add Scripts/view/battle_playback.gd Scripts/view/battle_root.gd tests/test_battle_playback.gd
git commit -m "feat: sync hits to the weapon strike with camera, sound, arrows and screen pulse

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: 실행 확인

**Files:** 없음 (확인만. 문제가 나오면 해당 Task 를 고치고 그 테스트를 다시 돌린다.)

- [ ] **Step 1: 전체 테스트** — Expected: `N/N passed`.

- [ ] **Step 2: 게임 실행** — `Start-Process "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" -ArgumentList "--path", ".", "res://Scenes/battle_3d.tscn" -PassThru` 로 띄우고, 런타임 TCP 7777 (스크래치패드 `rt.py`: 응답은 4바이트 LE 길이 + JSON) 로 클릭·캡처한다. 클릭 전 `inject_mouse_motion`, 클릭은 press/release 짝. 사거리 안의 대상을 고른다 (힌트 글자 `✓`).

- [ ] **Step 3: 확인 항목**
  - 근접 카드: 공격 띠 중간(약 0.5초)에 피해 숫자·흰 번쩍임·불꽃·넉백이 나온다 (공격자가 돌아오기 전).
  - 원거리 카드: 공격자가 살짝 물러나고 화살이 포물선으로 날아가 도착 순간 맞는다.
  - 처치: 잠깐 멈췄다가 느려지고, 화면 가장자리가 조여지며 색이 번진다. 끝나면 정상 속도 (`call_method` 로 `Engine` 값을 못 읽으면 다음 동작이 정상 속도로 재생되는지 캡처 간격으로 확인).
  - 카드·칸 클릭이 펄스 덮개에 막히지 않는다.
  - 콘솔 오류 0건 (셰이더 컴파일 포함).
  - 소리와 손맛은 사용자가 직접 플레이해 확인한다.

- [ ] **Step 4: 종료** — `Stop-Process -Id <Id>`. 수정이 있었다면 커밋.
