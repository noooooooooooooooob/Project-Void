# 유니티 전투 연출 역이식 설계 — 유닛 외형 · 타격감 · 전투 공간

- 작성일: 2026-10-06
- 대상: 유니티 프로젝트 `C:\Users\User\Desktop\projectvoidunityh` 의 2.5D 전투 연출을 이 Godot 프로젝트로 옮긴다
- 상태: 승인 대기 (설계 대화 승인 2026-10-06)
- 원본: 유니티 저장소 `docs/superpowers/specs/` 의 `unity-port-phase1`, `hit-impact`, `hit-impact-2` 설계와 `Assets/_Project/Scripts/View/` 코드
- 선행 문서: `2026-09-13-battle-2-5d-design.md` (2.5D 보드), `2026-09-16-map-prototype-design.md` (맵·인카운터 생성)

## 1. 배경과 목표

유니티 프로젝트는 이 Godot 프로토타입의 전투 규칙과 2.5D 화면을 옮긴 것에서 시작해, 그 위에 연출을 많이 더했다: AI 생성 픽셀 유닛 6종과 애니메이션 띠, 코드 동작 곡선, 타격 타이밍·히트스톱·카메라 흔들림·투사체·효과음·화면 펄스, 조명이 들어간 창고 방. 이 문서는 그 연출을 Godot 로 다시 가져오는 설계다.

규칙 코어(`Scripts/combat/` 의 `BattleState`·`Unit`·`TargetResolver`·`EnemyBrain`), 카드 연출(손패·더미), 맵은 Godot 쪽이 원본이거나 유니티에 없으므로 **건드리지 않는다**.

**성공 기준**

1. Godot 에서 한 판을 해 보면 유니티 2.5D(`Battle.unity`) 화면·연출과 같은 느낌이 난다 (나란히 캡처 비교).
2. 기존 헤드리스 테스트가 모두 통과하고, 이 문서 §8 의 새 테스트가 통과한다.
3. 맵에서 생성된 전투에도 같은 방·연출이 나온다.
4. 플레이 중 콘솔 에러 0건.

## 2. 확정 사항 (2026-10-06 사용자 결정)

| 항목 | 결정 |
|---|---|
| 화면 | 2.5D(원근)만. 유니티의 Flat2D(`Battle2D`)는 가져오지 않는다 |
| 범위 | A 유닛 외형 + B 타격감 + C 전투 공간 전부. 문서는 하나, 구현 계획은 단계별 |
| 이식 방식 | **로직은 그대로, 렌더링은 Godot 기능으로**. 수치·타이밍·곡선·이벤트 흐름은 유니티와 1:1, URP 한계를 우회한 표현(가짜 빛기둥 판, 벽 그늘 판, emission 번쩍임)은 Godot 기능으로 대체 |
| 방 데이터 | `BattleRoomData` 리소스를 분리하고 `EncounterData.room` 이 가리킨다. 생성기는 창고 방 하나를 모든 전투에 붙인다 |
| 기존 배경 | `EncounterData.background` 와 `BattleRoot._apply_background` 는 제거한다 (방이 대체) |
| 진영 구분 | 스프라이트 틴트(`ALLY_TINT`/`ENEMY_TINT`)를 없애고 발밑 진영 고리 색으로 구분 (유니티와 동일) |
| 에셋 | 유니티에서 이미 64×64 로 정리된 PNG 와 WAV 를 복사한다. 새로 생성하지 않는다 |
| sentry | 유니티 최신 커밋 상태(새 그림 + 영혼불 오라, 애니메이션 띠 없음)를 따른다 |

**범위 밖**: Flat2D 화면, FBX 3D 소품(유니티도 스프라이트 소품이 우선 적용됨), `PixelSpriteProcessor` 같은 에셋 정리 도구, 컨셉 아트(`Art/Units/Concepts/`), 카드별 투사체 모양, 배경음악, 이동·방어·회복 효과음.

## 3. 구조와 파일

```
Scripts/view/
  unit_motion.gd        (신규) 동작 곡선. 순수 정적 함수 (유니티 UnitMotion)
  unit_view.gd          (수정) 시트 프레임·자세·흰 번쩍임·불꽃·오라·넉백·진영 고리
  battle_playback.gd    (수정) 타격 순간 동기화, 투사체, 카메라·소리·펄스 호출
  battle_camera.gd      (신규) 푸시인·흔들림·히트스톱·처치 슬로모션 (실제 시간)
  projectile.gd         (신규) 포물선 화살
  battle_audio.gd       (신규) 효과음 재생기
  screen_pulse.gd       (신규) 화면 셰이더(비네트·색수차) 제어
  battle_environment.gd (신규) 방: 바닥·벽·스포트라이트·먼지·소품
  board_3d.gd           (수정) 칸 텍스처, 유닛 그림 선택
  battle_root.gd        (수정) 위 부품 생성·연결, background 제거
Scripts/combat/data/
  unit_data.gd          (수정) sprite, idle/attack/hit_sheet, aura_texture
  battle_room_data.gd   (신규) 바닥·벽·칸 텍스처, 소품 목록
  prop_placement.gd     (신규) 소품 하나
  encounter_data.gd     (수정) background → room
Scripts/view/battle_sounds.gd (신규) 클립 6개 + 고르기 (표현 전용이라 view 에 둔다)
Scripts/map/encounter_generator.gd (수정) 만든 인카운터에 기본 방을 붙인다
Shaders/
  unit_sprite.gdshader  유닛·소품 몸 (프레임, 흰 번쩍임, 틴트, 디더 페이드)
  room_wall.gdshader    벽 (반복 텍스처 + 위로 갈수록 어두운 그늘)
  screen_pulse.gdshader 화면 전체 (비네트 + 색수차)
Art/
  units/{id}.png  units/anim/{id}_{idle|attack|hit}.png
  effects/arrow.png effects/spirit_flame.png
  props/{name}.png  rooms/warehouse_floor.png warehouse_wall.png tile_ally.png tile_enemy.png
Audio/ melee_swing.wav melee_hit.wav ranged_shot.wav ranged_hit.wav blocked.wav kill.wav
Resources/rooms/warehouse.tres
Resources/audio/battle_sounds.tres
```

- 모든 픽셀 텍스처는 임포트 시 필터 Nearest, 밉맵 없음. 바닥·벽 텍스처는 반복(repeat)을 켠다.
- 새 GDScript 는 기존 파일처럼 타입을 명시하고 `class_name` 을 단다. 주석 밀도는 주변 코드(한 줄씩 한국어 설명)에 맞춘다.
- 유니티 좌표는 먼 쪽이 +z 이고 Godot 은 먼 쪽이 −z 다. 위치 값을 옮길 때 z 부호를 뒤집는다.

## 4. A — 유닛 외형·동작

### 4.1 데이터 (`UnitData`)

| 필드 | 타입 | 의미 |
|---|---|---|
| `sprite` | `Texture2D` | 64×64 정지 그림. 비면 `placeholder_unit.png` |
| `idle_sheet` / `attack_sheet` / `hit_sheet` | `Texture2D` | 64px 프레임을 가로로 이은 띠. 프레임 수 = 너비 ÷ 높이 (현재 16) |
| `aura_texture` | `Texture2D` | 몸 주변에 계속 피어오르는 이펙트. 비면 없음 |

연결 상태 (유니티 `.asset` 기준):

| 유닛 | sprite | idle | attack | hit | aura |
|---|---|---|---|---|---|
| vanguard, archer, scout, stalker | O | O | O | O | — |
| brute | O | O | — | O | — |
| sentry | O (새 그림) | — | — | — | spirit_flame |

### 4.2 노드 구조 (`UnitView`)

```
UnitView (Node3D, 칸 위치. 돌진·넉백은 이 노드를 움직인다)
├─ Body    매 프레임 카메라 forward 의 수평 성분을 보도록 Y축만 회전 + 위쪽을 카메라 반대로 20° 기울임 (발이 축)
│  └─ Pose     발을 축으로 늘이기·기울이기. scale = (1 − s·0.5, 1 + s), rotation.z = lean · facing
│     └─ Sprite  MeshInstance3D(QuadMesh), 높이 1.6, 발이 원점. 적은 x 스케일 −1 (왼쪽을 본다)
├─ Shadow  발밑 접지 그림자 0.9×0.5, 검정 α0.7, 높이 0.01
├─ Ring    진영 고리 0.95×0.6, 아군 (0.3, 0.55, 1.0, 0.8) / 적 (1.0, 0.3, 0.25, 0.8), 높이 0.012
├─ Sparks  CPUParticles3D, 가슴 높이(1.6×0.55)
├─ Aura    CPUParticles3D, aura_texture 가 있을 때만, 높이 1.6×0.45
├─ 이름·HP 바·수치 글자 (지금 그대로)
└─ 클릭 판정 상자 (지금 그대로)
```

- 가로세로비는 프레임 하나(시트면 높이×높이, 아니면 그림 크기) 기준.
- 진영 고리 텍스처는 코드로 만든 고리 모양 `GradientTexture2D`(또는 작은 Image)로 만든다.

### 4.3 `unit_sprite.gdshader`

- `shader_type spatial; render_mode cull_disabled;` 알파 잘라내기(`ALPHA_SCISSOR_THRESHOLD` 0.5)로 그림자를 드리우고 조명을 받는다.
- uniform:
  - `texture_albedo` (filter_nearest), `frame: int`, `frame_count: int` — UV.x 를 `(frame + uv.x) / frame_count` 로 옮긴다
  - `flash: float` (0..1) — 알베도를 흰색으로 섞고 같은 양만큼 EMISSION 을 흰색으로 줘서 실루엣 전체가 흰색이 된다
  - `tint: vec3` — 붉은 번쩍임 `(1, 0.45, 0.45)` 와 평소 흰색
  - `fade: float` (1 = 보임) — 화면 좌표 디더(4×4 Bayer)로 픽셀을 버린다. 반투명 정렬 문제 없이 사라진다
- 소품(§6.3)도 같은 셰이더를 `frame_count = 1` 로 쓴다.

### 4.4 동작 (`unit_motion.gd`)

유니티 `UnitMotion.cs` 를 그대로 옮긴다. 키 사이 보간은 `smoothstep` (키마다 속도 0 → "멈칫").

| 곡선 | 시간 키 | 값 |
|---|---|---|
| `idle(time, phase)` | 주기 1.6초 | stretch = 0.03 · sin(2π·time/1.6 + phase) |
| `attack(t)` | 0, 0.3, 0.5, 0.75, 1 | stretch 0, −0.12, 0.12, −0.03, 0 / lean 0, 8, −10, 2, 0 |
| `lunge_reach(t)` | 0, 0.3, 0.5, 1 | 0, 0, 1, 0 |
| `hop(t)` | 0, 0.2, 0.35, 0.55, 0.85, 0.9, 1 | stretch 0, −0.15, 0.1, 0.03, 0.02, −0.12, 0 |
| `hop_height(t)` | 0, 0.2, 0.55, 0.85, 1 | 0, 0, 0.25, 0, 0 |
| `hit(t)` | 0, 0.15, 0.5, 1 | stretch 0, −0.1, 0.03, 0 / lean 0, 12, −3, 0 |
| `knockback_reach(t)` | 0, 0.15, 0.6, 1 | 0, 1, 0, 0 |
| `death(t)` | — | lean = 85 · t² |

상수: `ATTACK_STRIKE = 0.5`, `ATTACK_WINDUP_END = 0.3`, `KNOCKBACK_PEAK = 0.15`.

### 4.5 `UnitView` 동작 규칙

| 상황 | 시트 있음 | 시트 없음 |
|---|---|---|
| 대기 | idle 띠를 8fps 반복. 시작 프레임 = unit_id × 5 | `idle` 자세. phase = unit_id × 1.7 |
| 공격 (`lunge_toward(target, distance)`) | 1.0초 동안 attack 띠 진행률 재생 + `lunge_reach` 로 distance 만큼 나갔다 복귀 | 0.25초 동안 `attack` 자세 + 같은 돌진 |
| 피격 (`flash_and_shake(knockback)`) | 0.8초 동안 hit 띠 재생 | 0.24초 동안 `hit` 자세 |
| 방어·휴식 (`hop`) | 0.25초 `hop` 자세 + `hop_height` | 같음 |
| 사망 (`fade_out`) | 0.4초 동안 `death` 자세 + fade 1→0, 그림자·고리·HP 바 즉시 숨김, 오라 방출 중지 | 같음 |

- `attack_duration()` = attack 띠가 있으면 1.0 아니면 0.25, `hit_duration()` = hit 띠가 있으면 0.8 아니면 0.24.
- 띠를 재생할 때는 자세 곡선을 더하지 않는다 (과해진다).
- 연출 중에는 대기 동작을 멈춘다 (`_acting`).
- 피격 중에도 기존 좌우 흔들림(0.08, −0.08, 0.05, 0)과 붉은 번쩍임 2회(4분할 중 0·2번째)를 유지한다.
- 연출 상수 `LUNGE_DISTANCE` 0.4, `MOVE_TIME` 0.25, `POP_TIME` 0.6 등 기존 값은 그대로.
- `reset_pose()` 는 위치·자세·프레임·셰이더 값을 모두 기본으로 되돌린다.

### 4.6 오라

유니티 `MakeAura` 그대로: 수명 1.6초, 초당 2.5개, 크기 0.28~0.4, 위로 0.15~0.35 속도, 1.1 × (1.6×0.7) 상자에서 나온다, 알파 0→1(0.2)→1(0.6)→0, 크기 1→0.5, 월드 좌표(몸이 움직여도 이미 뜬 불꽃은 제자리), 미리 채움(preprocess). 빌보드 알파 블렌딩, 필터 Nearest.

## 5. B — 타격감

### 5.1 타격 타이밍 (`BattlePlayback`)

- 순수 함수 `static func impact_start(events, attack_index) -> int`: 공격 이벤트 뒤에서 `LOG` 는 건너뛰고 처음 만나는 `DAMAGED`/`DIED` 의 인덱스. 다른 이벤트가 먼저 오거나 없으면 −1.
- 공격 이벤트 = `CARD_PLAYED`, 또는 `action == ATTACK` 이고 대상이 있는 `ENEMY_ACTED`.
- `impact >= 0` 이고 instant 가 아니면:
  1. 카메라 푸시인, 근접이면 휘두르기 소리.
  2. 돌진을 동시에 시작 (원거리는 distance = −0.1 반동, 근접은 0.4).
  3. `ATTACK_STRIKE × attack_duration()` 기다린다.
  4. 원거리면 발사 소리 → 투사체 비행을 기다린다.
  5. 사이의 로그를 붙이고, 공격 종류·공격자 위치를 기억한 채 피해 묶음을 재생한다.
  6. 돌진과 피해 묶음이 모두 끝나면 카메라를 되돌리고 묶음 끝 다음 이벤트로 간다.
- `impact < 0` (빗나감·방어·휴식) 이면 지금처럼 돌진 또는 깡충만 한다.
- "동시에 시작 → 모두 끝나길 기다림"은 기존 `_play_damage_batch` 의 신호 + 남은 수 세기 패턴을 쓴다.
- 공격 종류: `CARD_PLAYED` 는 `event.card.attack_type`, `ENEMY_ACTED` 는 적 데이터의 `attack_type`. 공격 없이 나온 피해 묶음은 근접으로 친다.
- 원거리 목표 위치는 `CARD_PLAYED` 면 대상 칸 위치, `ENEMY_ACTED` 면 대상 유닛의 `home_position`.
- instant 모드는 지금과 똑같이 순서대로 상태만 반영한다.

### 5.2 넉백

- `static func knockback_distance(amount) -> float` = amount ≤ 0 이면 0, 아니면 `min(0.1 + 0.03·amount, 0.35)`.
- 방향 = (맞은 유닛 home − 공격자 home) 의 수평 성분. 공격자를 모르는 피해는 0.
- `flash_and_shake(knockback)` 이 `knockback_reach(t)` 로 루트를 밀었다 되돌리고, 끝나면 정확히 `home_position`.

### 5.3 피격 이펙트 (`UnitView`)

- `start_impact()`: 셰이더 `flash = 1`, 실제 시간(`Time.get_ticks_msec`) 기준 0.06초 뒤 0. 불꽃 12개 방출.
- 불꽃: 네모 픽셀, 흰 (1, 0.95, 0.8) ~ 주황 (1, 0.55, 0.15), 수명 0.25초, 속도 2~4, 크기 0.06~0.1, 중력 절반, 반지름 0.1 구에서 사방으로, 가산 블렌딩. 히트스톱 중에도 날아가도록 `speed_scale = 1 / Engine.time_scale` 로 보정한다.
- 피해 숫자: `pop_text(text, color, punch)` — 처음 0.15초 동안 punch 배 → 1배. 피해 1.6, 처치(남은 hp ≤ 0) 2.0.
- `static func pop_scale(t, punch) -> float` 로 크기 계산을 뺀다 (테스트 대상).

### 5.4 카메라 (`battle_camera.gd`)

`Camera3D` 에 붙는 노드. `BattleRoot._frame_camera` 가 계산한 기본 구도를 `set_base(position, basis)` 로 넘긴다.

| 기능 | 수치 |
|---|---|
| 푸시인 | 목표까지 거리의 12%, 지수 감쇠 속도 8 (`lerp(push, target, 1 − exp(−8·dt))`) |
| 흔들림 | trauma = max(trauma, 세기). 초당 2.5 감소. 오프셋 = 카메라 평면의 무작위 방향 × 0.25 × trauma² |
| 흔들림 세기 | `static shake_for_damage(amount, died)` = 처치 1, 아니면 0.2 + 0.7·min(amount, 10)/10 |
| 히트스톱 | `Engine.time_scale = 0.05`. 피해 0.06초, 처치 0.1초 (실제 시간). 건 프레임의 시간은 빼지 않는다 |
| 처치 슬로모션 | 히트스톱이 끝난 뒤(없으면 바로) `time_scale = 0.3` 을 실제 시간 0.35초 → 1 |

- 실제 시간 delta 로 돈다: `_process` 에서 `Time.get_ticks_usec` 차이로 계산해 `tick(real_delta)` 를 부른다. `tick` 은 테스트가 직접 부를 수 있다.
- `_exit_tree` 에서 멈춤·슬로모션이 남아 있으면 `time_scale = 1`.
- 되돌리기 규칙: 이벤트 종류가 `DAMAGED`/`DIED`/`LOG` 가 아니면 푸시인을 해제한다 (`static keeps_camera_push(kind)`).
- 대기(`_wait`)는 `create_timer` 기본값(시간 배율 적용)을 그대로 써서 히트스톱·슬로모션 동안 연출 전체가 함께 느려진다. 유니티 `WaitForSeconds` 와 같다.

### 5.5 투사체 (`projectile.gd`)

- `static flight_time(distance)` = clamp(distance / 16, 0.12, 0.35).
- `static position_at(from, to, arc, t)` = lerp(from, to, t) + up · 4·arc·t·(1−t). arc = distance × 0.06.
- 출발·도착은 가슴 높이(1.6 × 0.55). 길이 0.8 판, `arrow.png`(32×8) 비율, 없으면 코드로 만든 16×4 흰 줄.
- 판은 카메라 basis 를 따르고, 화면상 진행 방향(다음 위치 − 현재 위치를 카메라 right/up 에 투영한 각도)으로 Z 회전한다.
- 게임 시간(배율 적용)으로 난다. 도착하면 스스로 지운다. `fly()` 는 await 가능.

### 5.6 효과음

- `BattleSounds` (Resource): `melee_swing`, `melee_hit`, `ranged_shot`, `ranged_hit`, `blocked`, `kill` (`AudioStream`).
  - `for_attack(type)` = 원거리 `ranged_shot`, 근접 `melee_swing`.
  - `for_impact(type, amount, died)` = 처치 `kill` → 피해 0 `blocked` → 원거리 `ranged_hit` / 근접 `melee_hit`.
  - 비어 있는 칸은 null 이고 소리를 내지 않는다.
- `BattleAudio` (Node): `AudioStreamPlayer` 하나, `max_polyphony = 8`, 재생마다 `pitch_scale = 1 ± 0.08` 무작위. `play_count` (테스트용).
- 원거리 발사음은 화살이 나가는 순간, 근접 휘두르기는 공격 시작에 낸다 (`static attack_sound_at_strike(type)`).
- 광역 공격은 맞은 유닛마다 타격음을 낸다 (의도).
- `BattlePlayback.audio` 가 null 이거나 instant 면 소리 없음.

### 5.7 화면 펄스 (`screen_pulse.gd` + `screen_pulse.gdshader`)

- `CanvasLayer`(HUD 아래 층) 위의 전체 화면 `ColorRect` 가 `hint_screen_texture` 를 읽는다.
- 셰이더 uniform: `vignette`(기본 0.38), `vignette_smoothness`(0.45), `chromatic`(0..1, 1 일 때 가장자리에서 약 4px 어긋남 — 화면 보며 조정), `level`.
- `pulse(strength)`: level = max(level, clamp01(strength)). 처치 1, 피해 8 이상 0.5.
- level 은 실제 시간 0.4초 동안 0 으로 선형 감소. 적용값: chromatic = level, vignette = 0.38 + 0.25·level.
- `tick(real_delta)` 공개 (테스트).

## 6. C — 전투 공간

### 6.1 데이터

```
BattleRoomData (Resource)
  ground_texture: Texture2D
  wall_texture: Texture2D
  ally_tile_texture: Texture2D
  enemy_tile_texture: Texture2D
  props: Array[PropPlacement]

PropPlacement (Resource)
  texture: Texture2D
  position: Vector3   # 바닥 위치 (y 무시)
  height: float = 1.0 # 맞출 높이
```

- `EncounterData.room: BattleRoomData`. null 이면 방 없음(지금처럼 단색 배경, 칸은 단색).
- `skirmish.tres` 와 `EncounterGenerator.build_encounter` 가 만든 인카운터 모두 `res://Resources/rooms/warehouse.tres` 를 가리킨다.

### 6.2 방 (`battle_environment.gd`)

`static func build(parent, layout, room) -> BattleEnvironment` — room 이 null 이면 null.

| 요소 | 내용 |
|---|---|
| 바닥 | 40 × 24 평면, 보드 중심 아래(y = −TILE_THICKNESS). 텍스처 한 장이 5 단위. 색 (0.45, 0.45, 0.5) |
| 뒷벽 | 가장 먼 행에서 2 너머, 폭 = 좌우 옆벽 사이 |
| 옆벽 | 보드 좌우 끝에서 3 바깥, 보드 쪽을 향함, 길이 = 뒷벽부터 바닥 앞끝까지 |
| 벽 공통 | 높이 4, 텍스처 한 장이 4 단위, 텍스처 아래 12% 잘라냄, 색 (0.8, 0.8, 0.85). `room_wall.gdshader` 가 높이 0.35→1 구간에서 smoothstep 으로 최대 85% 까지 어둡게 |
| 클릭 | 바닥·벽·소품은 충돌체가 없다 (타일·유닛 클릭을 막지 않음) |

### 6.3 소품

- 유닛과 같은 빌보드(Y축 + 20° 기울임), `unit_sprite.gdshader`, 그림자 드리움. 높이 = `height`, 폭 = 비율대로.
- 창고 방 배치 (유니티 `skirmish.asset` 의 x, −z):

| 그림 | 위치 (x, z) | 높이 |
|---|---|---|
| crates | (−5.8, −2.7) | 1.6 |
| crates | (−5.3, 1.5) | 1.1 |
| railing | (−0.6, −3.2) | 1.0 |
| drum | (4.3, −2.9) | 1.1 |
| drum | (5.0, −2.2) | 1.1 |
| fan | (3.9, 1.9) | 1.8 |
| cardboard | (−3.0, −3.4) | 1.0 |
| worklight | (0.3, 2.6) | 1.6 |
| toolbox | (−6.0, −0.6) | 0.5 |

  옮긴 뒤 칸·유닛을 가리지 않는지 캡처로 확인하고, 가리면 위치만 조정한다.

### 6.4 조명·분위기

| 요소 | 설정 |
|---|---|
| 디렉셔널 라이트 | 세기 0.45, 흰색, 그림자 켬 |
| 앰비언트 | 색 (0.16, 0.17, 0.2) |
| 창문 빛 | SpotLight3D 2개. 뒷벽 위쪽(높이 4, 뒷벽 0.5 앞)의 좌우 30% / 75% 지점에서 보드 중심 + (−1.5, 0, −0.5) / (2.5, 0, 0.5) 쪽으로. 색 (1, 0.9, 0.75), 각도 35°, 범위 20, 그림자 켬. 세기는 화면 보며 조정 |
| 볼류메트릭 포그 | 켬. 색 (0.06, 0.065, 0.08) 계열, 밀도는 0.025 에서 시작해 빛기둥이 뒤쪽 유닛을 가리지 않을 만큼으로 조정. 스포트라이트의 볼류메트릭 기여로 빛기둥을 만든다 (유니티의 가짜 빛기둥 판은 만들지 않음) |
| 먼지 | 빛이 떨어지는 지점 위 1.5 에 CPUParticles3D. 수명 6초, 최대 60개, 초당 8개, 크기 0.02, 속도 0.05, 2×3×2 상자, 색 (1, 0.92, 0.8, 0.3), 가산 |
| Environment | SSAO 켬, Glow (threshold 0.9, intensity 0.5, 넓게 번짐), Adjustments (채도 0.82, 대비 1.08), 살짝 차가운 톤 (색 보정 (0.92, 0.96, 1.0) 상당) |
| 비네트 | §5.7 화면 셰이더 기본값 0.38 |

- 방이 없으면 Environment·조명은 지금 씬 설정 그대로 둔다.

### 6.5 칸

- `Board3D.build` 가 room 의 칸 텍스처를 받는다. 텍스처가 있으면 칸 윗면에 입히고 기본색은 흰 틴트(유니티 `TexturedTileTint`), 없으면 지금 진영 단색.
- 상태 발광색(현재·유효·이동·범위 등)과 이유 글자는 그대로.

## 7. 연결 (`BattleRoot`)

- `_ready` 에서: 방 생성 → 보드 생성(칸 텍스처) → `BattleCamera` 를 카메라에 붙이고 `_frame_camera` 결과를 `set_base` 로 → `BattleAudio`(sounds 리소스), `ScreenPulse` 생성 → `BattlePlayback` 에 camera / audio / pulse / projectile_texture 연결.
- 유닛 그림: `UnitData.sprite` 가 있으면 그것, 없으면 placeholder (`Board3D.build` 인자 변경).
- `_apply_background` 와 `EncounterData.background` 삭제. 이를 쓰던 테스트가 있으면 함께 정리.

## 8. 테스트

모두 기존 `TestCase` 러너, 먼저 실패를 확인한 뒤 구현한다.

**A**
- `test_unit_motion.gd`: 각 곡선 t=0·1 끝점, attack stretch 가 0.3 에서 −0.12·0.5 에서 0.12, lunge_reach 0.5 에서 1, hop_height 0.55 에서 0.25, knockback_reach 0.15 에서 1, death(1) = 85, idle 주기성.
- `test_unit_view.gd` 추가: 시트 프레임 수(1024×64 → 16), 적의 Sprite x 스케일 음수, 고리 색 진영별, sprite 없으면 placeholder, 시트 없으면 `attack_duration()` 0.25, 오라는 aura_texture 가 있을 때만, `reset_pose` 후 기본 자세.

**B**
- `test_battle_playback.gd` 추가: `impact_start` 4경우(바로 뒤 피해 / 로그 건너뜀 / 없음 / 다른 이벤트 끼어듦), `knockback_distance`(0→0, 증가, 상한 0.35), `keeps_camera_push`, instant 재생 결과가 기존과 같음, instant 에서 `play_count == 0`.
- `test_battle_camera.gd`: `shake_for_damage` 분기, `tick` 으로 히트스톱 → 0.05 → 끝나면 1, 슬로모션이 히트스톱 뒤 0.3 으로 이어져 0.35초 뒤 1, 히트스톱 없이 슬로모션만, 트리에서 빠질 때 1 복구, 푸시인 수렴.
- `test_projectile.gd`: `flight_time` 하한·상한·비례, `position_at` 양 끝점 일치·중간이 직선보다 높음, 텍스처 없이도 생성.
- `test_battle_sounds.gd`: `for_attack`·`for_impact` 각 분기, `attack_sound_at_strike`.
- `test_unit_view.gd` 추가: `start_impact` 직후 flash 1, 0.06초(실제 시간) 뒤 0, 불꽃 방출, `pop_scale`.
- `test_screen_pulse.gd`: pulse 후 level 상승, tick 0.4초 뒤 0, 셰이더 파라미터 반영.

**C**
- `test_battle_environment.gd`: room null → null, 바닥 1·벽 3, 뒷벽 z 가 가장 먼 행보다 먼 쪽, 소품 수 = props 수, 환경 노드에 충돌체 없음.
- `test_encounter_generator.gd` 추가: 생성된 인카운터의 room 이 창고 방.
- `test_data.gd` 추가: `skirmish.tres` 의 room 이 창고 방, 유닛 데이터의 sprite·시트 연결 상태가 §4.1 표와 같음.
- `test_board_3d.gd` 추가: 칸 텍스처가 있으면 칸 머티리얼에 들어감.

**수동 / MCP 확인 (단계마다)**
- 헤드리스 테스트 전체 통과.
- 게임을 실행해 런타임 캡처 → 유니티 2.5D 캡처와 나란히 비교.
- 콘솔 에러 0건.
- 타격 타이밍·소리 체감은 사용자가 직접 플레이해 확인.

## 9. 오류 처리

- 그림·시트·오라·화살·클립이 비어 있으면 대체(placeholder, 코드 모션, 흰 줄, 무음)로 진행하고 예외를 내지 않는다.
- 방이 없으면 방·조명 연출 없이 지금 화면으로.
- 연출이 중간에 끊겨도(씬 전환 등) `time_scale` 은 반드시 1 로 돌아온다 (`BattleCamera._exit_tree`).

## 10. 구현 단계

| 단계 | 내용 | 끝났을 때 |
|---|---|---|
| A | 에셋 복사·임포트, `UnitData` 필드, `unit_sprite.gdshader`, `unit_motion.gd`, `UnitView` 개편 | 유닛 6종이 그림·애니메이션·동작 곡선으로 움직인다 |
| B | `impact_start` 동기화, 넉백, 피격 이펙트, `BattleCamera`, 투사체, 효과음, 화면 펄스 | 타격 순간에 번쩍임·불꽃·흔들림·히트스톱·소리가 겹친다 |
| C | `BattleRoomData`·`PropPlacement`, `battle_environment.gd`, 조명·포그·Environment, 칸 텍스처, 생성기 연결, background 제거 | 맵에서 들어간 전투도 창고 방에서 벌어진다 |

각 단계는 별도 구현 계획(`docs/superpowers/plans/`)으로 쓰고, 끝날 때마다 테스트·캡처 확인 후 커밋한다.
