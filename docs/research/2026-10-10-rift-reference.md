# Rift(유니티) 참고 분석 — Project Void 에 가져올 만한 것

- 작성일: 2026-10-10
- 대상: `C:\Users\User\Desktop\Unity\Rift` (Unity 6 / URP, 5x5 양쪽 격자 턴제 RPG)
- 상태: 참고 자료. 아직 적용 결정 없음 — 쓸 때 Notion 기획서와 맞춰 보고 brainstorming 부터 시작한다.
- 읽은 범위: `Assets/Scripts/`, `Assets/Scriptable Object/` 의 게임 코드 전부. 서드파티(TextMesh Pro, PixPlays, DOTween 등)와 작은 연출 파일(패럴랙스, 버튼 호버, 파티클 스케일, 스테이지 선택 카메라, 에디터 도구)은 제목만 확인.

결론: **코드가 아니라 설계·데이터 구조를 가져올 프로젝트**다. Rift 는 규칙 계산이 MonoBehaviour·코루틴·연출 안에 섞여 있어 그대로 이식할 수 없다. Void 의 "규칙 코어는 순수 로직 + 신호" 구조로 다시 짜야 한다.

## A. 가져올 만한 것

### A1. 전투 사이 파티 상태 유지 (`Scripts/Party_Manager.cs`)
- HP 가 다음 전투로 이어진다. 전투 중 사망한 유닛은 파티에서 **영구 제거**(`UpdatePartyAfterBattle`).
- 전투 종료 시 Battle 버프만 지우고 Stage/Permanent 버프는 남긴다.
- 파티 전체 회복·피해 헬퍼: `HealPartyPercent/Fixed`, `DamagePartyPercent/Fixed` — 이벤트·휴식이 이것을 쓴다.
- `money` + `GainMoney`.
- Void 현황: `PartyState` 는 데이터만 들고, 전투마다 최대 HP 로 시작, 사망 불이익 없음. 골드 없음.
- 적용 시 주의: Void 에는 반복 파밍 노드가 있어 HP 유지 시 회복 수단이 같이 필요. 전투 코어(`Unit._init` 이 `hp = max_hp`)에 시작 HP 를 넘기는 작은 수정이 필요.

### A2. 버프/상태이상 시스템 (`Scripts/Effect/`, `Scriptable Object/BuffData.cs`)
- `EffectTrigger`(Flags): Passive, OnAttack, OnHit, OnDamaged, OnTurnStart, OnTurnEnd, OnKill.
- `BuffData`: 이름·설명·아이콘, `buffType`(Battle / Stage / Permanent), `duration`(0 = 영구), `maxStacks`, `effects` 목록.
- `BuffInstance`: 남은 턴, 스택. 같은 버프 재적용 시 스택 +1(상한까지) + 지속 시간 갱신. 턴 종료 시 지속 시간 감소.
- `EffectHandler`: 장비 이펙트 + 버프 이펙트를 트리거별로 발동.
- 효과 목록(수치 포함):
  - 출혈 `BleedEffect` — OnTurnEnd, 스택 × 10 피해
  - 화상 `BurnEffect` — OnTurnEnd, 현재 HP × (5% + 스택당 2%), 최소 1
  - 동상 `FrostbiteEffect` — Passive, 스택당 기본 SPD 10% 감소(최소 1)
  - 적중 시 추가 피해 `DamageOnHitEffect` — 고정 / ATK% / 대상 최대 HP%
  - 턴마다 회복 `HealOnTurnEffect` — 고정 / 최대 HP%
  - 흡혈 `LifestealEffect` — 준 피해의 %
  - HP 비례 흡혈 `HPBasedLSEffect` — HP 낮을수록 흡혈 증가(최대 +30%)
  - 스탯 증감 `StatModifierEffect` — 고정 / %
  - 광폭화(HongYeon 스킬1 이 아군에게 부여, 데이터 에셋)
- 장비(`EquipmentData.effects`)와 캐릭터 고유 패시브(`UnitData.innatePassives`)가 같은 구조를 쓴다.
- 적용 시 주의: 능력치를 직접 더하고 빼지 말고, Void 처럼 "원본 + 적용 중인 효과 목록 → 읽을 때 계산" 으로 한다.

### A3. 맵 노드: 이벤트 · 상점 · 휴식 + 골드
- 이벤트 (`EventSceneData`, `Event_Manager`): 선택지마다 무조건 내는 대가(costType/costValue) → `successRate` 판정 → 성공/실패 결과(HealPercent, HealFixed, DamagePercent, DamageFixed, Gold) + 결과 문구. 이벤트는 폴더에서 무작위 하나.
- 상점 (`Shop_Scene_Manager`): 전체 장비 중 중복 없이 UI 칸 수만큼 진열, 리롤 50 골드, 아이템마다 `price`. 인벤토리 9칸이 가득 차면 구매 불가.
- 휴식 (`Rest_Scene_Manager`): 1 명 최대 HP 70% 회복 또는 전원 30% 회복 중 선택.
- 맵 생성 (`Stage_Manager`): 층마다 노드 3 개, 전투 70% / 이벤트 20% / 상점 10%. 보스 직전 층은 휴식 1 개 강제, 마지막 층은 보스.
- 전투 보상 골드: `BattleMap.awardGold` / `BossMap.awardGold`.

## B. 아이디어 수준에서 참고할 만한 것
- 보스 고정 패턴 (`Unit/Amatsu/Amatsu_AI.cs`): 스킬1 → 2 → 3 → 궁극기 순환. Void `EnemyBrain` 에 보스용 패턴으로.
- 궁극기 게이지(UP): 행동마다 +1, 가득 차면 남의 턴 중에도 끼어들어 사용(`Turn_Manager.ActivateUltimate` 가 현재 턴 코루틴을 멈추고 궁극기 턴 → 원래 턴 재개). 카드 게임에서는 특수 카드·끼어들기로 변형 가능.
- 유닛 상세 패널 (`Battle/UI/Unit_Description.cs`): 스킬 범위를 작은 격자에 색칠해서 표시 — Void 카드 범위 모양(SINGLE/PIERCE/SWEEP/AREA/LINE) 미리보기에 쓸 만함.
- 버프 아이콘 UI (`Unit/UI/Buff_Icon_UI.cs`): 남은 턴·스택 숫자 + 마우스 오버 툴팁.
- 피해 숫자 종류 (`VFX/DamageText.cs`): 일반(흰색) / 치명타(노랑, 크게, 강한 흔들림) / 회복(초록, +표시) / 빗나감(회색 MISS).

## C. 가져오면 안 되는 것
- SPD 기반 턴 게이지(ATB) — Void 는 라운드 속도 순서 + 턴 순서 표시(`battle_hud.turn_bar_text`)가 이미 있음.
- 데미지 공식(`Method.cs`: EV 회피, DEF/(DEF+100) 감쇠, DR, AP 관통, CA 반격) — Void 의 고정 카드 피해 + 방어도 구조와 충돌.
- 팀 공용 행동 포인트(시작 2, 턴마다 +1) — Void 는 유닛별 SP.
- 구조: 싱글톤 매니저, DontDestroyOnLoad 로 유닛 GameObject 를 들고 다니기, 능력치 직접 가감.

## Rift 의 버그 (옮길 때 피할 것)
- % 보정 가감이 원래대로 안 돌아옴: ATK 100 → +10% = 110 → 제거 = 99.
- `HPBasedLSEffect.savedBonus` 를 ScriptableObject 에셋에 저장 → 같은 효과를 가진 유닛끼리 값을 덮어씀.
- 흡혈 계산 결과를 버림: Penguin_Attack/Skill1, Amatsu_AI, Unit_Ultimate 에서 `Method.CalculateLifeSteal` 반환값 미사용. `Unit_Attack.Attack` 은 피해 10% 를 하드코딩으로 추가 회복.
- `Enemy_AI.ExecuteTurn` 의 `while(true)` + `continue` — 가능한 행동이 없으면 무한 루프.
- 장비를 `UnitEquipment` 와 `EffectHandler` 두 곳에서 관리.

## 추천 적용 순서
A1(HP 유지·사망 규칙) → A2(버프) → A3(이벤트 → 휴식 → 상점·골드).
A1 이 정해져야 회복 노드의 가치와 골드 경제가 정해지고, A2 가 있어야 장비 효과·고유 패시브를 붙일 수 있다.
