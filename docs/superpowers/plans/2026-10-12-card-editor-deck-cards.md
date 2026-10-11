# 카드 에디터: 덱 전용 카드 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 카드가 덱에 소속되게 바꾸고, 덱 화면 안에서 카드를 만들게 한다. 장수 기능은 없앤다.

**Architecture:** 카드 문서에 `deckId` 를 더하고 덱 문서의 `entries` 를 없앤다. 덱 계산은 `state.cards` 를 `deckId` 로 걸러서 한다. 라이브 데이터는 순수 함수 `migrationWrites` 로 만든 batch 를 `ArtifactData` 로 한 번 적용한다.

**Tech Stack:** 기존과 같음 (바닐라 JS, `node:test`, 아티팩트 `db`/`assets`/`user`).

**Spec:** `docs/superpowers/specs/2026-10-12-card-editor-deck-cards-design.md` (선행: `2026-10-12-card-editor-design.md`)

## Global Constraints

- 카드 `deckId`: 문자열 = 덱 전용, `null` = 공용
- 덱 문서: `{ name, createdAt }`
- 이전된 사본 id: `<덱id>--<카드id>`
- 장수 UI·데이터 없음
- 기존 제약(직접 쓴 문구, 분류 색, 5×5 범위, 400px, 라이트/다크) 유지

## Review Focus

1. 이전을 두 번 실행해도 사본이 늘지 않음 (Task 1 `migrationWrites` 멱등 테스트)
2. 덱 삭제 시 다른 카드가 쓰는 일러스트는 남음 (Task 1 `isAssetShared` 기존 테스트 + Task 3 삭제 경로)
3. 지워진 덱을 가리키는 카드(다른 탭에서 덱 삭제)는 어디에도 안 보이지만 화면이 깨지지 않음 (Task 1 `cardsInDeck` 테스트)
4. 공용 카드 탭에 덱 카드가 섞이지 않음 (Task 1 `cardsInDeck(cards, null)` 테스트)
5. 읽기 전용 보기에서 "이 덱에 새 카드"·복사·삭제가 보이지 않음 (Task 3 수동 확인)

---

### Task 1: 모델 변경

**Files:**
- Modify: `tools/card_editor/card_model.js`
- Test: `tools/card_editor/card_model.test.js`

**Interfaces:**
- Produces: `normalizeCard(raw)` 결과에 `deckId: string|null`; `normalizeDeck(raw) -> {name}`; `cardsInDeck(cards, deckId|null) -> Card[]` (이름순); `spHistogram(cards) -> [{sp, count}]`; `migrationWrites(cardDocs, deckDocs) -> write[]` (`cardDocs`/`deckDocs` 는 `{id, data, version}`); `isAssetShared`, `writeErrorKind`, `filterSort` 유지
- Removes: `setEntryCount`, `removeCardFromEntries`, `resolveEntries`, `deckTotal`

- [ ] **Step 1: 테스트 교체** — `card_model.test.js` 에서 `normalizeCard fills defaults` 기대값에 `deckId: null` 추가. Task 2(구 계획) 덱 테스트 5개(`normalizeDeck…`, `setEntryCount…`, `removeCardFromEntries`, `missing cards…`)를 지우고 아래로 바꾼다

```js
test("normalizeCard keeps deckId", () => {
  assert.equal(M.normalizeCard({ name: "x", sp: 1, deckId: "archer" }).deckId, "archer");
  assert.equal(M.normalizeCard({ name: "x", sp: 1, deckId: "" }).deckId, null);
});

test("normalizeDeck keeps only the name", () => {
  assert.deepEqual(M.normalizeDeck({ name: " ", entries: { a: 1 } }), { name: "이름 없는 덱" });
  assert.deepEqual(M.normalizeDeck({ name: "사수" }), { name: "사수" });
});

test("cardsInDeck filters by deck and keeps common cards apart", () => {
  const list = [
    { id: "1", ...M.normalizeCard({ name: "사격", sp: 1, deckId: "archer" }) },
    { id: "2", ...M.normalizeCard({ name: "관통", sp: 2, deckId: "archer" }) },
    { id: "3", ...M.normalizeCard({ name: "베기", sp: 1 }) },
    { id: "4", ...M.normalizeCard({ name: "고아", sp: 1, deckId: "gone" }) },
  ];
  assert.deepEqual(M.cardsInDeck(list, "archer").map((c) => c.id), ["2", "1"]);
  assert.deepEqual(M.cardsInDeck(list, null).map((c) => c.id), ["3"]);
  assert.deepEqual(M.spHistogram(M.cardsInDeck(list, "archer")), [{ sp: 1, count: 1 }, { sp: 2, count: 1 }]);
});

test("migrationWrites copies deck entries into deck cards and clears entries", () => {
  const cardDocs = [{ id: "shoot", version: 1, data: { name: "사격", sp: 1, category: "attack", attackType: "ranged", area: [], illustration: null, description: "", createdAt: 5 } }];
  const deckDocs = [{ id: "archer", version: 3, data: { name: "사수", entries: { shoot: 3, gone: 1 }, createdAt: 9 } }];
  assert.deepEqual(M.migrationWrites(cardDocs, deckDocs), [
    { op: "set", collection: "cards", doc_id: "archer--shoot",
      data: { name: "사격", sp: 1, category: "attack", attackType: "ranged", area: [], illustration: null, description: "", deckId: "archer", createdAt: 5 } },
    { op: "set", collection: "decks", doc_id: "archer", if_version: 3, data: { name: "사수", createdAt: 9 } },
  ]);
});

test("migrationWrites is a no-op once migrated", () => {
  const cardDocs = [{ id: "archer--shoot", version: 1, data: { name: "사격", sp: 1, deckId: "archer", createdAt: 5 } }];
  const deckDocs = [{ id: "archer", version: 4, data: { name: "사수", createdAt: 9 } }];
  assert.deepEqual(M.migrationWrites(cardDocs, deckDocs), []);
});
```

- [ ] **Step 2: 실패 확인** — `node --test "tools/card_editor/*.test.js"` → `M.cardsInDeck is not a function` 등으로 FAIL
- [ ] **Step 3: 구현** — `normalizeCard` 에 `deckId: typeof r.deckId === "string" && r.deckId ? r.deckId : null` 추가. `normalizeDeck` 은 `{ name }` 만 반환. `setEntryCount`·`removeCardFromEntries`·`resolveEntries`·`deckTotal` 삭제. 추가:

```js
  function cardsInDeck(cards, deckId) {
    return cards.filter((c) => (c.deckId ?? null) === (deckId ?? null)).sort(byName);
  }

  function spHistogram(cards) {
    const bins = new Map();
    for (const c of cards) bins.set(c.sp, (bins.get(c.sp) || 0) + 1);
    return [...bins.entries()].sort((a, b) => a[0] - b[0]).map(([sp, count]) => ({ sp, count }));
  }

  // 덱 entries → 덱 전용 카드 사본. 이미 이전된 덱(entries 없음)은 건드리지 않는다.
  function migrationWrites(cardDocs, deckDocs) {
    const byId = Object.fromEntries(cardDocs.map((d) => [d.id, d]));
    const writes = [];
    for (const deck of deckDocs) {
      if (!deck.data.entries) continue;
      for (const cardId of Object.keys(deck.data.entries)) {
        const src = byId[cardId];
        const copyId = deck.id + "--" + cardId;
        if (!src || byId[copyId]) continue;
        writes.push({ op: "set", collection: "cards", doc_id: copyId,
          data: { ...normalizeCard(src.data), deckId: deck.id, createdAt: src.data.createdAt ?? 0 } });
      }
      writes.push({ op: "set", collection: "decks", doc_id: deck.id, if_version: deck.version,
        data: { name: normalizeDeck(deck.data).name, createdAt: deck.data.createdAt ?? 0 } });
    }
    return writes;
  }
```

`api` 갱신.
- [ ] **Step 4: 통과 확인** — 같은 명령, 전부 PASS
- [ ] **Step 5: Commit** — `feat(card-editor): cards belong to decks, drop deck entries`

### Task 2: 시드 갱신

**Files:** Modify `tools/card_editor/seed.json`, `tools/card_editor/seed.test.js`

- [ ] **Step 1: 테스트 교체** — `seed.test.js` 를 아래 기대로 바꾼다: 공용 카드 7장(`deckId` 없음 또는 null), 덱 3개(`entries` 없음), 덱 카드는 사수 4 · 정찰병 4 · 선봉 4장, 모든 덱 카드의 `deckId` 가 시드 덱을 가리킴, 모든 카드가 `normalizeCard` 결과와 같음(createdAt 제외)

```js
const test = require("node:test");
const assert = require("node:assert/strict");
const M = require("./card_model.js");
const seed = require("./seed.json");

const cards = seed.filter((o) => o.collection === "cards");
const decks = seed.filter((o) => o.collection === "decks");
const deckIds = new Set(decks.map((d) => d.doc_id));

test("seed has 7 common cards, 3 decks and 12 deck cards", () => {
  assert.equal(cards.filter((c) => c.data.deckId === null).length, 7);
  assert.equal(decks.length, 3);
  const count = (id) => cards.filter((c) => c.data.deckId === id).length;
  assert.deepEqual([count("archer"), count("scout"), count("vanguard")], [4, 4, 4]);
});

test("seed cards are normalized, valid and point at seed decks", () => {
  for (const c of cards) {
    const { createdAt, ...body } = c.data;
    assert.deepEqual(M.validateCard(body), [], c.doc_id);
    assert.deepEqual(M.normalizeCard(body), body, c.doc_id);
    assert.ok(Number.isInteger(createdAt));
    if (body.deckId !== null) assert.ok(deckIds.has(body.deckId), c.doc_id);
  }
});

test("seed decks hold only name and createdAt", () => {
  for (const d of decks) assert.deepEqual(Object.keys(d.data).sort(), ["createdAt", "name"]);
});
```

- [ ] **Step 2: 실패 확인** → FAIL (deckId 없음)
- [ ] **Step 3: 시드 재생성** — 기존 `seed.json` 에 `migrationWrites` 를 적용하는 일회성 Node 명령으로 새 시드를 만든다(공용 카드에 `deckId: null` 추가, `if_version` 제거)
- [ ] **Step 4: 통과 확인**
- [ ] **Step 5: Commit** — `feat(card-editor): seed deck-owned cards`

### Task 3: 화면 변경

**Files:** Modify `tools/card_editor/index.src.html`

- [ ] **Step 1** 탭 글자 "카드" → "공용 카드". `renderCardGrid` 는 `M.filterSort(M.cardsInDeck(state.cards, null), state.filter)` 를 쓰고 빈 상태 판단도 공용 카드 기준
- [ ] **Step 2** `openEditor(card, deckId)` — 새 카드면 `deckId` 를 초안에 넣는다. 제목 = `<소속 이름> · 카드 편집|새 카드|카드 보기` (소속 이름: 덱 이름 또는 "공용 카드"). 저장 body 에 `deckId` 포함(`normalizeCard` 가 처리)
- [ ] **Step 3** 편집 창 하단: `#f-deck` 레이블 "복사할 덱", `#f-add-deck` 글자 "다른 덱에 복사", 목록은 현재 소속을 뺀 덱. 클릭 시 `db.collection("cards").doc().set({...normalizeCard(draft), deckId: 고른 덱, name, createdAt: Date.now()})` 후 토스트 "<덱>에 복사했어요"
- [ ] **Step 4** 카드 삭제: 덱 정리 루프 제거(entries 없음), 카드 삭제 + 공유 안 된 일러스트 삭제만
- [ ] **Step 5** 덱 화면: `saveDeck` 은 `{name, createdAt}` 만 쓴다. 목록 숫자 = `cardsInDeck(...).length + "장"`. 상세 = 이름, "이 덱에 새 카드"(→ `openEditor(null, deck.id)`), 덱 삭제("카드 N장도 삭제", 두 번째 클릭에 그 덱 카드 삭제 → 공유 안 된 일러스트 삭제 → 덱 삭제), 요약(카드 수, `spHistogram(rows)`), 카드 그리드(배지·스테퍼 없음). "덱에 넣기" 줄과 `.stepper` CSS 삭제
- [ ] **Step 6** 빌드·문법·테스트: `node tools/card_editor/build.mjs && node --test "tools/card_editor/*.test.js"` + 스크립트 문법 검사. 헤드리스 Edge 로 덱 화면 한 번 확인
- [ ] **Step 7: Commit** — `feat(card-editor): create cards inside decks`

### Task 4: 이전·게시

- [ ] **Step 1** `ArtifactData list` 로 `cards`, `decks` 를 읽어 JSON 으로 저장(`out_dir`)
- [ ] **Step 2** Node 로 `migrationWrites` 실행 → 결과 batch 를 `ArtifactData batch` 로 적용 (덱 쓰기는 `if_version` 으로 고정)
- [ ] **Step 3** 새 페이지 게시(같은 파일 경로, capabilities 생략)
- [ ] **Step 4** `cards` 다시 읽어 덱 카드 12장 + 공용 7장(+ 사용자가 만든 카드) 확인
- [ ] **Step 5** README 의 사용법(덱·장수 부분) 갱신, Commit — `docs(card-editor): update guide for deck cards`
