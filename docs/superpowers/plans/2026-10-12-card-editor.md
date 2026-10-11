# 카드 에디터 (웹) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 이름·SP·지문 등을 직접 쓰면 카드 모양으로 보이고 덱으로 모아 볼 수 있는 claude.ai 아티팩트 웹 페이지를 만든다.

**Architecture:** 순수 로직(`card_model.js`)과 화면(`index.src.html`)을 나눈다. 로직은 Node 내장 테스트로 검증하고, 빌드 스크립트가 로직을 HTML 안에 인라인해 `dist/card-editor.html` 한 파일을 만든다. 카드·덱은 아티팩트 `db` 컬렉션 `cards`, `decks` 에, 일러스트는 `assets` 에 저장한다. 초기 데이터는 첫 게시 후 `ArtifactData` 로 넣는다.

**Tech Stack:** 바닐라 HTML/CSS/JS (라이브러리 없음), Node 24 `node:test`, claude.ai 아티팩트 런타임 0.2.75 (`db`, `user`, `assets`).

**Spec:** `docs/superpowers/specs/2026-10-12-card-editor-design.md`

## Global Constraints

- 문구는 모두 사용자가 직접 쓴다. 효과 수치에서 문구를 자동 생성하지 않는다
- 키워드 항목 없음
- 분류 색: 공격 빨강, 스킬 파랑, 특수 보라
- 공격 종류: 근접 / 원거리 / 아군 / 자신 (배지 글자 근·원·아·자 — 게임 `CardText.BADGES` 와 같음)
- 범위: 5×5 격자, 가운데 (0,0) 이 기준 칸. x = 열(+ 가 뒤쪽), y = 행(+ 가 아래) — 게임 `CardData.area` 와 같은 좌표
- 범위가 비면 가운데 한 칸
- SP 는 0 이상 정수
- 외부 스크립트 없음. 폰트만 Google Fonts
- 라이트/다크 둘 다, 폭 400px 에서 가로 스크롤 없음
- 덱 장수·코스트 제한 없음
- Godot 이 이 폴더를 가져오지 않도록 `tools/card_editor/.gdignore`

## Review Focus

1. SP 칸을 비우거나 음수·소수·글자를 넣고 저장 → 저장되지 않고 "SP는 0 이상의 정수예요" 표시 (Task 1 `validateCard` 테스트)
2. 덱에 들어간 카드를 지움 → 모든 덱에서 빠지고, 다른 창에서 이미 지워진 카드 id 가 덱에 남아 있어도 덱 화면이 깨지지 않고 장수·SP 막대에서 제외 (Task 2 `removeCardFromEntries`, `spHistogram`, `resolveEntries` 테스트)
3. 복제한 카드는 일러스트 id 를 공유 → 한쪽을 지워도 다른 쪽 그림이 남아야 함 (Task 2 `isAssetShared` 테스트)
4. 쓰기 권한 없는 보기(Viewer) → 편집 버튼 대신 읽기 전용 안내, 저장 실패 시 오류 문구 (Task 5 수동 확인 항목)
5. 아주 긴 이름·설명 → 카드 밖으로 넘치지 않고 잘려 보이며 편집 창에서는 전부 보임 (Task 4 수동 확인 항목)

---

## 파일 구조

```
tools/card_editor/
  .gdignore              Godot 가져오기 제외 (빈 파일)
  .gitignore             dist/ 제외
  card_model.js          순수 로직 (브라우저: window.CardModel / Node: module.exports)
  card_model.test.js     node:test 테스트
  seed.json              초기 카드 7장 + 덱 3개 (ArtifactData batch 형식)
  seed.test.js           seed 가 모델 규칙을 지키는지 테스트
  index.src.html         화면 (스타일 + 앱 스크립트, <!-- @inline card_model.js --> 자리)
  build.mjs              index.src.html + card_model.js → dist/card-editor.html
```

db 문서 모양:

```js
// cards/{id}
{ name: "베기", sp: 1, category: "attack", attackType: "melee",
  area: [[0,0]], illustration: null /* 또는 asset id */, description: "", createdAt: 1760227200000 }
// decks/{id}
{ name: "사수", entries: { shoot: 3, volley: 1 }, createdAt: 1760227200000 }
```

---

### Task 1: 카드 모델 (정규화·검증·범위)

**Files:**
- Create: `tools/card_editor/.gdignore`, `tools/card_editor/.gitignore`
- Create: `tools/card_editor/card_model.js`
- Test: `tools/card_editor/card_model.test.js`

**Interfaces:**
- Produces: `CardModel.CATEGORIES`, `CATEGORY_LABELS`, `ATTACK_TYPES`, `ATTACK_LABELS`, `ATTACK_BADGES`, `AREA_RADIUS`, `normalizeCard(raw) -> Card`, `validateCard(raw) -> string[]`, `normalizeArea(raw) -> [x,y][]`, `toggleCell(area, x, y) -> [x,y][]`, `areaOrDefault(area) -> [x,y][]`

- [ ] **Step 1: 폴더 설정 파일**

`tools/card_editor/.gdignore` 빈 파일. `tools/card_editor/.gitignore`:

```
dist/
```

- [ ] **Step 2: 실패하는 테스트 작성** — `tools/card_editor/card_model.test.js`

```js
const test = require("node:test");
const assert = require("node:assert/strict");
const M = require("./card_model.js");

test("normalizeCard fills defaults", () => {
  assert.deepEqual(M.normalizeCard({ name: "  베기 ", sp: "1" }), {
    name: "베기", sp: 1, category: "attack", attackType: "melee",
    area: [], illustration: null, description: "",
  });
});

test("normalizeCard rejects unknown enums", () => {
  const c = M.normalizeCard({ name: "x", sp: 0, category: "boss", attackType: "laser" });
  assert.equal(c.category, "attack");
  assert.equal(c.attackType, "melee");
});

test("normalizeCard keeps description line breaks", () => {
  assert.equal(M.normalizeCard({ name: "x", description: "첫 줄\n둘째 줄" }).description, "첫 줄\n둘째 줄");
});

test("validateCard requires a name", () => {
  assert.deepEqual(M.validateCard({ name: "   ", sp: 1 }), ["이름을 입력하세요"]);
});

test("validateCard rejects bad sp", () => {
  for (const sp of ["", "-1", "1.5", "abc", null, undefined]) {
    assert.deepEqual(M.validateCard({ name: "x", sp }), ["SP는 0 이상의 정수예요"], `sp=${sp}`);
  }
  assert.deepEqual(M.validateCard({ name: "x", sp: "0" }), []);
  assert.deepEqual(M.validateCard({ name: "x", sp: 3 }), []);
});

test("normalizeArea drops out-of-range, duplicates and sorts", () => {
  assert.deepEqual(M.normalizeArea([[1, 0], [0, 0], [3, 0], [1, 0], [0, -1], ["a", 0]]),
    [[0, -1], [0, 0], [1, 0]]);
  assert.deepEqual(M.normalizeArea(null), []);
});

test("toggleCell adds and removes", () => {
  const a = M.toggleCell([], 1, 0);
  assert.deepEqual(a, [[1, 0]]);
  assert.deepEqual(M.toggleCell(a, 1, 0), []);
});

test("areaOrDefault returns origin when empty", () => {
  assert.deepEqual(M.areaOrDefault([]), [[0, 0]]);
  assert.deepEqual(M.areaOrDefault([[1, 1]]), [[1, 1]]);
});
```

- [ ] **Step 3: 실패 확인**

Run: `node --test tools/card_editor/`
Expected: FAIL — `Cannot find module './card_model.js'`

- [ ] **Step 4: 구현** — `tools/card_editor/card_model.js`

```js
// 카드 에디터의 순수 로직. 브라우저에서는 window.CardModel, Node 테스트에서는 module.exports.
(function (root) {
  const CATEGORIES = ["attack", "skill", "special"];
  const CATEGORY_LABELS = { attack: "공격", skill: "스킬", special: "특수" };
  const ATTACK_TYPES = ["melee", "ranged", "ally", "self"];
  const ATTACK_LABELS = { melee: "근접", ranged: "원거리", ally: "아군", self: "자신" };
  const ATTACK_BADGES = { melee: "근", ranged: "원", ally: "아", self: "자" };
  // 5×5 격자: -2..2. 게임 CardData.area 와 같은 좌표.
  const AREA_RADIUS = 2;

  function isSpValid(sp) {
    if (sp === null || sp === undefined) return false;
    const s = String(sp).trim();
    return /^\d+$/.test(s);
  }

  function normalizeArea(raw) {
    if (!Array.isArray(raw)) return [];
    const seen = new Set();
    const out = [];
    for (const cell of raw) {
      if (!Array.isArray(cell) || cell.length !== 2) continue;
      const [x, y] = cell;
      if (!Number.isInteger(x) || !Number.isInteger(y)) continue;
      if (Math.abs(x) > AREA_RADIUS || Math.abs(y) > AREA_RADIUS) continue;
      const key = x + "," + y;
      if (seen.has(key)) continue;
      seen.add(key);
      out.push([x, y]);
    }
    out.sort((a, b) => a[1] - b[1] || a[0] - b[0]);
    return out;
  }

  function normalizeCard(raw) {
    const r = raw || {};
    return {
      name: String(r.name ?? "").trim(),
      sp: isSpValid(r.sp) ? Number(String(r.sp).trim()) : 0,
      category: CATEGORIES.includes(r.category) ? r.category : "attack",
      attackType: ATTACK_TYPES.includes(r.attackType) ? r.attackType : "melee",
      area: normalizeArea(r.area),
      illustration: typeof r.illustration === "string" && r.illustration ? r.illustration : null,
      description: String(r.description ?? ""),
    };
  }

  function validateCard(raw) {
    const errors = [];
    if (!String(raw?.name ?? "").trim()) errors.push("이름을 입력하세요");
    if (!isSpValid(raw?.sp)) errors.push("SP는 0 이상의 정수예요");
    return errors;
  }

  function toggleCell(area, x, y) {
    const has = area.some(([cx, cy]) => cx === x && cy === y);
    return normalizeArea(has ? area.filter(([cx, cy]) => !(cx === x && cy === y)) : [...area, [x, y]]);
  }

  function areaOrDefault(area) {
    return area && area.length ? area : [[0, 0]];
  }

  const api = {
    CATEGORIES, CATEGORY_LABELS, ATTACK_TYPES, ATTACK_LABELS, ATTACK_BADGES, AREA_RADIUS,
    normalizeCard, validateCard, normalizeArea, toggleCell, areaOrDefault,
  };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.CardModel = api;
})(typeof window !== "undefined" ? window : globalThis);
```

- [ ] **Step 5: 통과 확인**

Run: `node --test tools/card_editor/`
Expected: PASS (8 tests)

- [ ] **Step 6: Commit**

```bash
git add tools/card_editor/.gdignore tools/card_editor/.gitignore tools/card_editor/card_model.js tools/card_editor/card_model.test.js
git commit -m "feat(card-editor): add card model normalize, validate and area helpers"
```

---

### Task 2: 목록·덱 로직

**Files:**
- Modify: `tools/card_editor/card_model.js` (함수 추가, `api` 에 등록)
- Test: `tools/card_editor/card_model.test.js` (테스트 추가)

**Interfaces:**
- Consumes: Task 1 의 `normalizeCard`
- Produces:
  - `filterSort(cards, {category, query, sort}) -> Card[]` — `cards` 는 `{id, ...Card}`; `category` 는 `"all"` 또는 분류; `sort` 는 `"name"` | `"sp"`
  - `normalizeDeck(raw) -> {name, entries}`
  - `setEntryCount(entries, cardId, count) -> entries` (0 이하면 키 제거)
  - `removeCardFromEntries(entries, cardId) -> entries`
  - `resolveEntries(entries, cardsById) -> [{card, count}]` (없는 카드 제외, 카드 이름순)
  - `deckTotal(entries, cardsById) -> number` (없는 카드 제외)
  - `spHistogram(entries, cardsById) -> [{sp, count}]` (SP 오름차순)
  - `isAssetShared(cards, assetId, exceptCardId) -> boolean`

- [ ] **Step 1: 실패하는 테스트 추가** — `card_model.test.js` 끝에

```js
const cards = [
  { id: "a", ...M.normalizeCard({ name: "베기", sp: 1, category: "attack" }) },
  { id: "b", ...M.normalizeCard({ name: "방어", sp: 0, category: "skill" }) },
  { id: "c", ...M.normalizeCard({ name: "관통사격", sp: 2, category: "attack" }) },
];
const byId = Object.fromEntries(cards.map((c) => [c.id, c]));

test("filterSort by category and query", () => {
  assert.deepEqual(M.filterSort(cards, { category: "attack", query: "", sort: "name" }).map((c) => c.id), ["c", "a"]);
  assert.deepEqual(M.filterSort(cards, { category: "all", query: "사격", sort: "name" }).map((c) => c.id), ["c"]);
});

test("filterSort by sp then name", () => {
  assert.deepEqual(M.filterSort(cards, { category: "all", query: "", sort: "sp" }).map((c) => c.id), ["b", "a", "c"]);
});

test("normalizeDeck drops bad counts and names empty decks", () => {
  assert.deepEqual(M.normalizeDeck({ name: " ", entries: { a: 2, b: 0, c: -1, d: 1.5, e: "x" } }),
    { name: "이름 없는 덱", entries: { a: 2 } });
});

test("setEntryCount adds, changes and removes at zero", () => {
  const e1 = M.setEntryCount({}, "a", 1);
  assert.deepEqual(e1, { a: 1 });
  assert.deepEqual(M.setEntryCount(e1, "a", 3), { a: 3 });
  assert.deepEqual(M.setEntryCount(e1, "a", 0), {});
  assert.deepEqual(e1, { a: 1 }, "input not mutated");
});

test("removeCardFromEntries", () => {
  assert.deepEqual(M.removeCardFromEntries({ a: 2, b: 1 }, "a"), { b: 1 });
});

test("missing cards are skipped in deck math", () => {
  const entries = { a: 3, c: 2, gone: 5 };
  assert.equal(M.deckTotal(entries, byId), 5);
  assert.deepEqual(M.spHistogram(entries, byId), [{ sp: 1, count: 3 }, { sp: 2, count: 2 }]);
  assert.deepEqual(M.resolveEntries(entries, byId).map((r) => [r.card.id, r.count]), [["c", 2], ["a", 3]]);
});

test("isAssetShared checks other cards only", () => {
  const list = [{ id: "x", illustration: "img1" }, { id: "y", illustration: "img1" }, { id: "z", illustration: null }];
  assert.equal(M.isAssetShared(list, "img1", "x"), true);
  assert.equal(M.isAssetShared(list.slice(0, 1), "img1", "x"), false);
});
```

- [ ] **Step 2: 실패 확인**

Run: `node --test tools/card_editor/`
Expected: FAIL — `M.filterSort is not a function`

- [ ] **Step 3: 구현** — `card_model.js` 의 `const api = {` 위에 추가

```js
  const byName = (a, b) => a.name.localeCompare(b.name, "ko");

  function filterSort(cards, { category = "all", query = "", sort = "name" } = {}) {
    const q = query.trim().toLowerCase();
    const list = cards.filter((c) =>
      (category === "all" || c.category === category) && (!q || c.name.toLowerCase().includes(q)));
    return list.sort(sort === "sp" ? (a, b) => a.sp - b.sp || byName(a, b) : byName);
  }

  function normalizeDeck(raw) {
    const r = raw || {};
    const entries = {};
    for (const [id, n] of Object.entries(r.entries || {})) {
      if (Number.isInteger(n) && n > 0) entries[id] = n;
    }
    return { name: String(r.name ?? "").trim() || "이름 없는 덱", entries };
  }

  function setEntryCount(entries, cardId, count) {
    const next = { ...entries };
    if (count > 0) next[cardId] = count;
    else delete next[cardId];
    return next;
  }

  function removeCardFromEntries(entries, cardId) {
    return setEntryCount(entries, cardId, 0);
  }

  function resolveEntries(entries, cardsById) {
    return Object.entries(entries)
      .filter(([id]) => cardsById[id])
      .map(([id, count]) => ({ card: cardsById[id], count }))
      .sort((a, b) => byName(a.card, b.card));
  }

  function deckTotal(entries, cardsById) {
    return resolveEntries(entries, cardsById).reduce((sum, r) => sum + r.count, 0);
  }

  function spHistogram(entries, cardsById) {
    const bins = new Map();
    for (const { card, count } of resolveEntries(entries, cardsById)) {
      bins.set(card.sp, (bins.get(card.sp) || 0) + count);
    }
    return [...bins.entries()].sort((a, b) => a[0] - b[0]).map(([sp, count]) => ({ sp, count }));
  }

  function isAssetShared(cards, assetId, exceptCardId) {
    return cards.some((c) => c.id !== exceptCardId && c.illustration === assetId);
  }
```

`api` 객체에 `filterSort, normalizeDeck, setEntryCount, removeCardFromEntries, resolveEntries, deckTotal, spHistogram, isAssetShared` 를 추가한다.

- [ ] **Step 4: 통과 확인**

Run: `node --test tools/card_editor/`
Expected: PASS (15 tests)

- [ ] **Step 5: Commit**

```bash
git add tools/card_editor/card_model.js tools/card_editor/card_model.test.js
git commit -m "feat(card-editor): add list filtering and deck helpers"
```

---

### Task 3: 초기 데이터

**Files:**
- Create: `tools/card_editor/seed.json`
- Test: `tools/card_editor/seed.test.js`

**Interfaces:**
- Consumes: `normalizeCard`, `validateCard`, `normalizeDeck`
- Produces: `seed.json` — `ArtifactData` `batch` 의 `ops` 배열로 그대로 쓴다 (`[{op:"set", collection, doc_id, data}]`). 정확한 batch 필드 이름은 Task 7 에서 `ArtifactData` 스키마를 불러와 맞춘다.

값은 `Resources/cards/*.tres` (분류는 전부 기본값 공격, `attack_type` 없으면 근접 / 1 이면 원거리) 와 `Resources/units/{archer,scout,vanguard}.tres` 의 덱에서 옮겼다.

- [ ] **Step 1: 실패하는 테스트** — `tools/card_editor/seed.test.js`

```js
const test = require("node:test");
const assert = require("node:assert/strict");
const M = require("./card_model.js");
const seed = require("./seed.json");

const cards = seed.filter((o) => o.collection === "cards");
const decks = seed.filter((o) => o.collection === "decks");

test("seed has 7 cards and 3 decks", () => {
  assert.equal(cards.length, 7);
  assert.equal(decks.length, 3);
});

test("seed cards are already normalized and valid", () => {
  for (const c of cards) {
    const { createdAt, ...body } = c.data;
    assert.deepEqual(M.validateCard(body), [], c.doc_id);
    assert.deepEqual(M.normalizeCard(body), body, c.doc_id);
    assert.ok(Number.isInteger(createdAt));
  }
});

test("seed decks only reference seed cards", () => {
  const ids = new Set(cards.map((c) => c.doc_id));
  for (const d of decks) {
    for (const id of Object.keys(d.data.entries)) assert.ok(ids.has(id), `${d.doc_id} → ${id}`);
    assert.deepEqual(M.normalizeDeck(d.data).entries, d.data.entries);
  }
});

test("seed deck sizes match the game", () => {
  const size = (id) => Object.values(decks.find((d) => d.doc_id === id).data.entries).reduce((a, b) => a + b, 0);
  assert.equal(size("archer"), 8);
  assert.equal(size("scout"), 6);
  assert.equal(size("vanguard"), 8);
});
```

- [ ] **Step 2: 실패 확인**

Run: `node --test tools/card_editor/`
Expected: FAIL — `Cannot find module './seed.json'`

- [ ] **Step 3: 데이터 작성** — `tools/card_editor/seed.json`

```json
[
  {"op":"set","collection":"cards","doc_id":"strike","data":{"name":"베기","sp":1,"category":"attack","attackType":"melee","area":[],"illustration":null,"description":"","createdAt":1760227200000}},
  {"op":"set","collection":"cards","doc_id":"shoot","data":{"name":"사격","sp":1,"category":"attack","attackType":"ranged","area":[],"illustration":null,"description":"","createdAt":1760227200001}},
  {"op":"set","collection":"cards","doc_id":"cleave","data":{"name":"횡베기","sp":2,"category":"attack","attackType":"melee","area":[[0,-1],[0,0],[0,1]],"illustration":null,"description":"","createdAt":1760227200002}},
  {"op":"set","collection":"cards","doc_id":"skewer","data":{"name":"꿰뚫기","sp":2,"category":"attack","attackType":"melee","area":[[0,0],[1,0],[2,0]],"illustration":null,"description":"","createdAt":1760227200003}},
  {"op":"set","collection":"cards","doc_id":"volley","data":{"name":"일제사격","sp":2,"category":"attack","attackType":"ranged","area":[[0,-2],[0,-1],[0,0],[0,1],[0,2]],"illustration":null,"description":"","createdAt":1760227200004}},
  {"op":"set","collection":"cards","doc_id":"piercing_shot","data":{"name":"관통사격","sp":2,"category":"attack","attackType":"ranged","area":[[-2,0],[-1,0],[0,0],[1,0],[2,0]],"illustration":null,"description":"","createdAt":1760227200005}},
  {"op":"set","collection":"cards","doc_id":"blast","data":{"name":"폭발탄","sp":2,"category":"attack","attackType":"ranged","area":[[0,0],[1,0],[0,1],[1,1]],"illustration":null,"description":"","createdAt":1760227200006}},
  {"op":"set","collection":"decks","doc_id":"archer","data":{"name":"사수","entries":{"shoot":3,"volley":1,"piercing_shot":2,"blast":2},"createdAt":1760227200100}},
  {"op":"set","collection":"decks","doc_id":"scout","data":{"name":"정찰병","entries":{"strike":2,"shoot":2,"volley":1,"cleave":1},"createdAt":1760227200101}},
  {"op":"set","collection":"decks","doc_id":"vanguard","data":{"name":"선봉","entries":{"strike":3,"cleave":2,"shoot":1,"skewer":2},"createdAt":1760227200102}}
]
```

- [ ] **Step 4: 통과 확인**

Run: `node --test tools/card_editor/`
Expected: PASS (19 tests)

- [ ] **Step 5: Commit**

```bash
git add tools/card_editor/seed.json tools/card_editor/seed.test.js
git commit -m "feat(card-editor): add seed cards and decks from the game data"
```

---

### Task 4: 페이지 뼈대·카드 렌더링·카드 목록 + 빌드

**Files:**
- Create: `tools/card_editor/index.src.html`
- Create: `tools/card_editor/build.mjs`

**Interfaces:**
- Consumes: `window.CardModel` 전체
- Produces (Task 5·6 이 같은 파일에서 쓴다): 전역 스코프 안의 `state`, `h(tag, attrs, ...kids)`, `renderCard(card, {count, onClick})`, `render()`, `toast(msg)`, `db`, `assets` 변수, `openEditor(card | null)` 자리(이 Task 에서는 빈 함수), `renderDecks()` 자리(빈 함수)

- [ ] **Step 1: 빌드 스크립트** — `tools/card_editor/build.mjs`

```js
// index.src.html 의 인라인 표시를 card_model.js 내용으로 바꿔 dist/card-editor.html 하나로 만든다.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const MARK = "<!-- @inline card_model.js -->";
const src = readFileSync(join(here, "index.src.html"), "utf8");
if (!src.includes(MARK)) throw new Error("inline marker missing in index.src.html");
const model = readFileSync(join(here, "card_model.js"), "utf8");
mkdirSync(join(here, "dist"), { recursive: true });
writeFileSync(join(here, "dist", "card-editor.html"), src.replace(MARK, () => `<script>\n${model}\n</script>`));
console.log("built dist/card-editor.html");
```

- [ ] **Step 2: 페이지** — `tools/card_editor/index.src.html`

```html
<title>Project Void 카드</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Black+Han+Sans&family=IBM+Plex+Sans+KR:wght@400;600&display=swap">
<style>
/* 레이아웃: 위 탭 바 → 카드 그리드 / 덱 화면은 왼쪽 덱 목록 + 오른쪽 덱 상세. 편집은 오른쪽에서 열리는 시트 */
:root {
  --bg: #f2f1f5; --surface: #ffffff; --fg: #1d1b24; --muted: #686577; --line: #dcd9e3; --accent: #5b4bd6;
  --face: #fbfaf7; --art: #e7e4ee; --art-line: #d3cfdc;
  --attack: #c3413a; --skill: #2d6cc9; --special: #8b3fc2; --danger: #b3261e; --on-accent: #ffffff;
  --display: "Black Han Sans", "Malgun Gothic", "Apple SD Gothic Neo", sans-serif;
  --body: "IBM Plex Sans KR", "Malgun Gothic", "Apple SD Gothic Neo", sans-serif;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #131219; --surface: #1c1a24; --fg: #ecebf2; --muted: #9a97a8; --line: #302d3c; --accent: #a092ff;
    --face: #24222d; --art: #2e2b38; --art-line: #3b3848;
    --attack: #e0625a; --skill: #5b93e8; --special: #b06ee0; --danger: #f2867e; --on-accent: #131219;
    color-scheme: dark;
  }
}
:root[data-theme="dark"] {
  --bg: #131219; --surface: #1c1a24; --fg: #ecebf2; --muted: #9a97a8; --line: #302d3c; --accent: #a092ff;
  --face: #24222d; --art: #2e2b38; --art-line: #3b3848;
  --attack: #e0625a; --skill: #5b93e8; --special: #b06ee0; --danger: #f2867e; --on-accent: #131219;
  color-scheme: dark;
}
body { background: var(--bg); color: var(--fg); font-family: var(--body); font-size: 14px; }
.wrap { max-width: 1200px; margin: 0 auto; padding-inline: 16px; padding-block: 16px 48px; display: grid; gap: 16px; }
button, input, select, textarea { font: inherit; color: inherit; }
button { cursor: pointer; }
:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }

/* 상단 */
.top { display: flex; flex-wrap: wrap; align-items: center; gap: 12px; }
.brand { font-family: var(--display); font-size: 22px; letter-spacing: .02em; margin: 0; }
.tabs { display: flex; gap: 4px; background: var(--surface); border: 1px solid var(--line); border-radius: 8px; padding: 3px; }
.tabs button { border: 0; background: none; padding: 6px 14px; border-radius: 6px; color: var(--muted); }
.tabs button[aria-selected="true"] { background: var(--accent); color: var(--on-accent); }
.top .spacer { flex: 1; }
.btn { border: 1px solid var(--line); background: var(--surface); padding: 7px 14px; border-radius: 6px; }
.btn.primary { background: var(--accent); border-color: var(--accent); color: var(--on-accent); font-weight: 600; }
.btn.danger { color: var(--danger); }
.btn.danger.armed { background: var(--danger); border-color: var(--danger); color: var(--on-accent); }
.btn:disabled { opacity: .45; cursor: default; }
.notice { color: var(--muted); font-size: 13px; }

/* 툴바 */
.toolbar { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
.chips { display: flex; gap: 4px; flex-wrap: wrap; }
.chip { border: 1px solid var(--line); background: var(--surface); border-radius: 999px; padding: 4px 12px; font-size: 13px; }
.chip[aria-pressed="true"] { border-color: var(--fg); font-weight: 600; }
.chip .dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; margin-right: 6px; vertical-align: 1px; }
.toolbar input[type="search"], .toolbar select { border: 1px solid var(--line); background: var(--surface); border-radius: 6px; padding: 6px 10px; min-width: 0; }
.toolbar input[type="search"] { flex: 1 1 160px; max-width: 260px; }

/* 카드 그리드 */
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(176px, 1fr)); gap: 16px; }
.empty { border: 1px dashed var(--line); border-radius: 10px; padding: 32px 16px; text-align: center; color: var(--muted); display: grid; gap: 10px; justify-items: center; }

/* 카드 한 장 (Notion 예시 그림: 이름 / SP 원이 겹친 일러스트 / 오른쪽 위 공격 종류·범위 / 설명) */
.card { --cat: var(--attack); position: relative; aspect-ratio: 5 / 7; max-width: 100%; background: var(--face); border: 3px solid var(--cat); border-radius: 12px; padding: 10px 12px 12px; display: grid; grid-template-rows: auto auto 1fr; gap: 8px; text-align: left; overflow: hidden; }
.card.cat-skill { --cat: var(--skill); }
.card.cat-special { --cat: var(--special); }
button.card { cursor: pointer; transition: transform .12s ease; }
button.card:hover { transform: translateY(-2px); }
.card-name { font-family: var(--display); font-weight: 400; font-size: 17px; line-height: 1.2; margin: 0; text-align: center; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.card-art { position: relative; margin: 4px 22px 0 10px; aspect-ratio: 4 / 3; background: var(--art); border: 1px solid var(--art-line); border-radius: 4px; background-image: repeating-linear-gradient(135deg, transparent 0 7px, var(--art-line) 7px 8px); }
.card-art img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; border-radius: 3px; }
.card-sp { position: absolute; left: -14px; top: -12px; width: 30px; height: 30px; border-radius: 50%; display: grid; place-items: center; background: var(--cat); color: var(--on-accent); font-family: var(--display); font-size: 16px; border: 2px solid var(--face); font-variant-numeric: tabular-nums; }
.card-side { position: absolute; right: -20px; top: -6px; display: grid; gap: 4px; justify-items: center; }
.card-badge { width: 22px; height: 22px; border-radius: 4px; display: grid; place-items: center; background: var(--fg); color: var(--face); font-size: 12px; font-weight: 600; }
.mini { display: grid; grid-template-columns: repeat(5, 5px); gap: 1px; padding: 3px; background: var(--face); border: 1px solid var(--art-line); border-radius: 4px; }
.mini i { width: 5px; height: 5px; background: var(--art-line); border-radius: 1px; }
.mini i.on { background: var(--cat); }
.mini i.origin { box-shadow: 0 0 0 1px var(--fg); }
.card-desc { margin: 0; font-size: 12px; line-height: 1.5; white-space: pre-wrap; overflow-wrap: anywhere; overflow: hidden; color: var(--fg); -webkit-mask-image: linear-gradient(to bottom, #000 80%, transparent); mask-image: linear-gradient(to bottom, #000 80%, transparent); }
.card-desc:empty::before { content: "설명 없음"; color: var(--muted); }
.card-count { position: absolute; right: 8px; bottom: 8px; background: var(--fg); color: var(--face); border-radius: 999px; padding: 1px 8px; font-size: 12px; font-weight: 600; font-variant-numeric: tabular-nums; }

/* 토스트 */
.toast { position: fixed; left: 50%; bottom: calc(16px + env(safe-area-inset-bottom, 0px)); transform: translateX(-50%); background: var(--fg); color: var(--bg); padding: 8px 14px; border-radius: 6px; font-size: 13px; max-width: calc(100% - 32px); }

@media (prefers-reduced-motion: reduce) { * { transition: none !important; } }
</style>

<div class="wrap">
  <header class="top">
    <h1 class="brand">Project Void 카드</h1>
    <nav class="tabs" role="tablist">
      <button id="tab-cards" role="tab" aria-selected="true" data-view="cards">카드</button>
      <button id="tab-decks" role="tab" aria-selected="false" data-view="decks">덱</button>
    </nav>
    <span class="spacer"></span>
    <span id="notice" class="notice"></span>
    <button id="new-card" class="btn primary" hidden>새 카드</button>
  </header>

  <section id="view-cards" class="wrap" style="padding:0">
    <div class="toolbar">
      <div class="chips" id="cat-chips"></div>
      <input id="search" type="search" placeholder="이름 검색" aria-label="이름 검색">
      <select id="sort" aria-label="정렬">
        <option value="name">이름순</option>
        <option value="sp">SP순</option>
      </select>
    </div>
    <div id="card-grid" class="grid"></div>
  </section>

  <section id="view-decks" hidden></section>
</div>
<div id="toast" class="toast" hidden></div>

<!-- @inline card_model.js -->
<script>
const M = window.CardModel;
const state = {
  cards: [], decks: [], loaded: false, view: "cards",
  filter: { category: "all", query: "", sort: "name" },
  deckId: null, canWrite: false,
};
let db = null;
let assets = null;
const $ = (sel) => document.querySelector(sel);

function h(tag, attrs, ...kids) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v == null || v === false) continue;
    if (k === "class") el.className = v;
    else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    else el.setAttribute(k, v === true ? "" : String(v));
  }
  for (const kid of kids.flat()) {
    if (kid == null || kid === false) continue;
    el.append(kid.nodeType ? kid : String(kid));
  }
  return el;
}

let toastTimer = 0;
function toast(msg) {
  const t = $("#toast");
  t.textContent = msg;
  t.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { t.hidden = true; }, 2600);
}

function cardsById() {
  return Object.fromEntries(state.cards.map((c) => [c.id, c]));
}

function miniGrid(area) {
  const on = new Set(M.areaOrDefault(area).map(([x, y]) => x + "," + y));
  const g = h("div", { class: "mini", title: "범위" });
  for (let y = -M.AREA_RADIUS; y <= M.AREA_RADIUS; y++) {
    for (let x = -M.AREA_RADIUS; x <= M.AREA_RADIUS; x++) {
      const cls = [on.has(x + "," + y) ? "on" : "", x === 0 && y === 0 ? "origin" : ""].join(" ").trim();
      g.append(h("i", { class: cls || null }));
    }
  }
  return g;
}

// 카드 한 장. onClick 이 있으면 버튼으로 만든다.
function renderCard(card, { count, onClick } = {}) {
  const img = card.illustration
    ? h("img", { src: "/_blob/" + card.illustration, alt: "", onerror: (e) => e.target.remove() })
    : null;
  const art = h("div", { class: "card-art" },
    img,
    h("span", { class: "card-sp", title: "SP " + card.sp }, card.sp),
    h("div", { class: "card-side" },
      h("span", { class: "card-badge", title: M.ATTACK_LABELS[card.attackType] }, M.ATTACK_BADGES[card.attackType]),
      miniGrid(card.area)));
  const body = [
    h("h3", { class: "card-name", title: card.name }, card.name || "이름 없음"),
    art,
    h("p", { class: "card-desc" }, card.description),
    count ? h("span", { class: "card-count" }, "×" + count) : null,
  ];
  const cls = "card cat-" + card.category;
  return onClick
    ? h("button", { class: cls, type: "button", onclick: onClick, "aria-label": card.name + " 편집" }, body)
    : h("article", { class: cls }, body);
}

function renderChips() {
  const box = $("#cat-chips");
  box.replaceChildren(
    ...[["all", "전체", null], ...M.CATEGORIES.map((c) => [c, M.CATEGORY_LABELS[c], c])].map(([value, label, cat]) =>
      h("button", {
        class: "chip", type: "button", "aria-pressed": String(state.filter.category === value),
        onclick: () => { state.filter.category = value; render(); },
      }, cat ? h("span", { class: "dot", style: `background:var(--${cat})` }) : null, label)));
}

function renderCardGrid() {
  const grid = $("#card-grid");
  if (!state.loaded) {
    grid.replaceChildren(h("div", { class: "empty" }, "카드를 불러오는 중이에요"));
    return;
  }
  const list = M.filterSort(state.cards, state.filter);
  if (!state.cards.length) {
    grid.replaceChildren(h("div", { class: "empty" },
      h("strong", {}, "아직 카드가 없어요"),
      state.canWrite ? "오른쪽 위 ‘새 카드’로 첫 카드를 만들어 보세요." : "편집 권한이 있는 사람이 카드를 추가하면 여기에 보여요."));
    return;
  }
  if (!list.length) {
    grid.replaceChildren(h("div", { class: "empty" }, "조건에 맞는 카드가 없어요"));
    return;
  }
  grid.replaceChildren(...list.map((c) => renderCard(c, { onClick: () => openEditor(c) })));
}

function render() {
  for (const b of document.querySelectorAll(".tabs button")) b.setAttribute("aria-selected", String(b.dataset.view === state.view));
  $("#view-cards").hidden = state.view !== "cards";
  $("#view-decks").hidden = state.view !== "decks";
  $("#new-card").hidden = !state.canWrite;
  if (state.view === "cards") { renderChips(); renderCardGrid(); }
  else renderDecks();
}

// Task 5 에서 채운다.
function openEditor(card) {}
// Task 6 에서 채운다.
function renderDecks() {}

for (const b of document.querySelectorAll(".tabs button")) {
  b.addEventListener("click", () => { state.view = b.dataset.view; render(); });
}
$("#search").addEventListener("input", (e) => { state.filter.query = e.target.value; renderCardGrid(); });
$("#sort").addEventListener("change", (e) => { state.filter.sort = e.target.value; renderCardGrid(); });
$("#new-card").addEventListener("click", () => openEditor(null));

function onDbError(e) {
  $("#notice").textContent = "저장소 연결이 끊겼어요. 새로고침해 주세요.";
  console.warn("db", e);
}

async function boot() {
  render();
  if (!window.claude?.use) {
    state.loaded = true;
    $("#notice").textContent = "claude.ai 에서 열어야 카드가 저장돼요.";
    render();
    return;
  }
  db = await claude.use("db");
  if (!db) {
    state.loaded = true;
    $("#notice").textContent = "저장소를 쓸 수 없어요. 로그인했는지 확인해 주세요.";
    render();
    return;
  }
  const user = await claude.use("user");
  state.canWrite = user ? (await user.can("data.write")) !== false : true;
  assets = state.canWrite ? await claude.use("assets") : null;
  if (!state.canWrite) $("#notice").textContent = "읽기 전용으로 보고 있어요.";
  db.collection("cards").onSnapshot((snap) => {
    state.cards = snap.docs.map((d) => ({ id: d.id, ...M.normalizeCard(d.data()) }));
    state.loaded = true;
    render();
  }, onDbError);
  db.collection("decks").onSnapshot((snap) => {
    state.decks = snap.docs
      .map((d) => ({ id: d.id, createdAt: d.data().createdAt || 0, ...M.normalizeDeck(d.data()) }))
      .sort((a, b) => a.createdAt - b.createdAt);
    render();
  }, onDbError);
}
boot();
</script>
```

- [ ] **Step 3: 빌드·문법 확인**

Run: `node tools/card_editor/build.mjs && node -e "const s=require('fs').readFileSync('tools/card_editor/dist/card-editor.html','utf8');const m=[...s.matchAll(/<script>([\s\S]*?)<\/script>/g)];m.forEach(x=>new Function(x[1]));console.log('scripts ok',m.length)"`
Expected: `built dist/card-editor.html` 다음 `scripts ok 2`

- [ ] **Step 4: 로컬 렌더 확인 (수동)**

`tools/card_editor/dist/card-editor.html` 을 브라우저로 연다. 확인: "claude.ai 에서 열어야…" 안내, 빈 상태 문구, 400px 폭에서 가로 스크롤 없음, 다크 모드 색. 개발자 도구 콘솔에서 아래를 실행해 카드 모양과 Review Focus 5번(긴 이름·설명이 카드 밖으로 넘치지 않음)을 확인한다:

```js
state.cards = [{ id: "t", ...M.normalizeCard({ name: "아주아주아주아주 긴 카드 이름입니다", sp: 3, category: "special", attackType: "ranged", area: [[0,0],[1,0],[0,1]], description: "첫 줄\n".repeat(20) }) }]; render();
```

- [ ] **Step 5: Commit**

```bash
git add tools/card_editor/index.src.html tools/card_editor/build.mjs
git commit -m "feat(card-editor): add page shell, card rendering and card list"
```

---

### Task 5: 편집 창 (실시간 미리보기·저장·삭제·복제·일러스트·덱에 추가)

**Files:**
- Modify: `tools/card_editor/index.src.html` (스타일 추가, 편집 시트 마크업 추가, `openEditor` 교체)

**Interfaces:**
- Consumes: Task 4 의 `state`, `h`, `renderCard`, `toast`, `db`, `assets`, `cardsById`; Task 2 의 `isAssetShared`, `removeCardFromEntries`, `setEntryCount`
- Produces: `openEditor(card | null)` — `card` 는 `{id, ...Card}` (저장된 카드), `null` 은 새 카드; 복제는 내부에서 `id` 없는 초안으로 연다

- [ ] **Step 1: 스타일 추가** — `<style>` 의 `/* 토스트 */` 위에

```css
/* 편집 시트 */
.scrim { position: fixed; inset: 0; background: color-mix(in srgb, var(--fg) 35%, transparent); }
.sheet { position: fixed; top: 0; right: 0; bottom: 0; width: min(760px, 100%); background: var(--surface); border-left: 1px solid var(--line); display: grid; grid-template-rows: auto 1fr auto; padding-top: env(safe-area-inset-top, 0px); padding-bottom: env(safe-area-inset-bottom, 0px); }
.sheet-head, .sheet-foot { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; padding: 12px 16px; border-bottom: 1px solid var(--line); }
.sheet-foot { border-bottom: 0; border-top: 1px solid var(--line); }
.sheet-head h2 { font-family: var(--display); font-weight: 400; font-size: 18px; margin: 0; flex: 1; }
.sheet-body { overflow: auto; padding: 16px; display: grid; grid-template-columns: minmax(0, 1fr) 220px; gap: 20px; align-items: start; }
@media (max-width: 640px) { .sheet-body { grid-template-columns: minmax(0, 1fr); } .preview { order: -1; justify-self: center; width: 200px; } }
.form { display: grid; gap: 14px; min-width: 0; }
.field { display: grid; gap: 6px; }
.field > span { font-size: 12px; font-weight: 600; color: var(--muted); letter-spacing: .04em; }
.field input[type="text"], .field input[type="number"], .field select, .field textarea { border: 1px solid var(--line); background: var(--bg); border-radius: 6px; padding: 8px 10px; min-width: 0; }
.field textarea { min-height: 140px; resize: vertical; line-height: 1.5; }
.row { display: flex; flex-wrap: wrap; gap: 12px; }
.row > .field { flex: 1 1 120px; }
.seg { display: flex; flex-wrap: wrap; gap: 4px; }
.seg button { border: 1px solid var(--line); background: var(--bg); border-radius: 6px; padding: 6px 12px; }
.seg button[aria-pressed="true"] { border-color: var(--fg); font-weight: 600; }
.area-edit { display: grid; grid-template-columns: repeat(5, 32px); gap: 4px; }
.area-edit button { width: 32px; height: 32px; border: 1px solid var(--line); background: var(--bg); border-radius: 4px; padding: 0; }
.area-edit button[aria-pressed="true"] { background: var(--accent); border-color: var(--accent); }
.area-edit button.origin { box-shadow: inset 0 0 0 2px var(--fg); }
.errors { color: var(--danger); font-size: 13px; margin: 0; padding-left: 18px; }
.preview { position: sticky; top: 0; display: grid; gap: 8px; }
.preview .notice { text-align: center; }
```

- [ ] **Step 2: 마크업 추가** — `<div id="toast" …>` 바로 위에

```html
<div id="editor" hidden>
  <div class="scrim" id="editor-scrim"></div>
  <aside class="sheet" role="dialog" aria-modal="true" aria-labelledby="editor-title">
    <div class="sheet-head">
      <h2 id="editor-title">카드 편집</h2>
      <button class="btn" type="button" id="editor-close">닫기</button>
    </div>
    <div class="sheet-body">
      <form class="form" id="editor-form" novalidate>
        <div class="row">
          <label class="field"><span>이름</span><input id="f-name" type="text" autocomplete="off"></label>
          <label class="field" style="flex:0 1 96px"><span>SP</span><input id="f-sp" type="number" min="0" step="1" inputmode="numeric"></label>
        </div>
        <div class="field"><span>분류</span><div class="seg" id="f-category"></div></div>
        <div class="field"><span>공격 종류</span><div class="seg" id="f-attack"></div></div>
        <div class="field"><span>범위 (가운데가 기준 칸, 아무것도 안 고르면 단일)</span><div class="area-edit" id="f-area"></div></div>
        <div class="field" id="f-illust-field">
          <span>일러스트</span>
          <div class="row" style="align-items:center">
            <input id="f-illust" type="file" accept="image/png,image/jpeg,image/webp,image/gif">
            <button class="btn" type="button" id="f-illust-clear">그림 빼기</button>
          </div>
        </div>
        <label class="field"><span>설명</span><textarea id="f-desc"></textarea></label>
        <ul class="errors" id="f-errors" hidden></ul>
      </form>
      <div class="preview">
        <div id="f-preview"></div>
        <p class="notice">미리보기</p>
      </div>
    </div>
    <div class="sheet-foot">
      <button class="btn primary" type="button" id="f-save">저장</button>
      <button class="btn" type="button" id="f-dup">복제</button>
      <select id="f-deck" aria-label="추가할 덱" class="btn"></select>
      <button class="btn" type="button" id="f-add-deck">덱에 추가</button>
      <span class="spacer" style="flex:1"></span>
      <button class="btn danger" type="button" id="f-delete">삭제</button>
    </div>
  </aside>
</div>
```

- [ ] **Step 3: `openEditor` 교체** — `// Task 5 에서 채운다.` 와 빈 `openEditor` 를 지우고 아래로 바꾼다

```js
// 편집 중인 초안. id 가 없으면 아직 저장 안 된 새 카드.
let draft = null;
let deleteArmed = false;

function draftCard() {
  return { id: draft.id, ...M.normalizeCard(draft) };
}

function syncEditorPreview() {
  $("#f-preview").replaceChildren(renderCard(draftCard()));
}

function renderSeg(box, values, labels, current, onPick) {
  box.replaceChildren(...values.map((v) => h("button", {
    type: "button", "aria-pressed": String(v === current),
    onclick: () => { onPick(v); renderEditorControls(); syncEditorPreview(); },
  }, labels[v])));
}

function renderEditorControls() {
  renderSeg($("#f-category"), M.CATEGORIES, M.CATEGORY_LABELS, draft.category, (v) => { draft.category = v; });
  renderSeg($("#f-attack"), M.ATTACK_TYPES, M.ATTACK_LABELS, draft.attackType, (v) => { draft.attackType = v; });
  const on = new Set(draft.area.map(([x, y]) => x + "," + y));
  const cells = [];
  for (let y = -M.AREA_RADIUS; y <= M.AREA_RADIUS; y++) {
    for (let x = -M.AREA_RADIUS; x <= M.AREA_RADIUS; x++) {
      cells.push(h("button", {
        type: "button", class: x === 0 && y === 0 ? "origin" : null,
        "aria-pressed": String(on.has(x + "," + y)), "aria-label": `열 ${x}, 행 ${y}`,
        onclick: () => { draft.area = M.toggleCell(draft.area, x, y); renderEditorControls(); syncEditorPreview(); },
      }));
    }
  }
  $("#f-area").replaceChildren(...cells);
  const saved = Boolean(draft.id);
  $("#f-dup").disabled = !saved;
  $("#f-delete").hidden = !saved;
  $("#f-deck").hidden = !saved || !state.decks.length;
  $("#f-add-deck").hidden = !saved || !state.decks.length;
  $("#f-deck").replaceChildren(...state.decks.map((d) => h("option", { value: d.id }, d.name)));
  $("#f-illust-field").hidden = !assets;
  $("#f-illust-clear").disabled = !draft.illustration;
  for (const id of ["#f-save", "#f-dup", "#f-delete", "#f-add-deck"]) $(id).hidden ||= !state.canWrite;
}

function openEditor(card) {
  draft = card
    ? { ...card, area: [...card.area], sp: String(card.sp) }
    : { id: null, ...M.normalizeCard({ name: "", sp: 1 }), sp: "1" };
  deleteArmed = false;
  $("#f-delete").classList.remove("armed");
  $("#f-delete").textContent = "삭제";
  $("#editor-title").textContent = draft.id ? "카드 편집" : "새 카드";
  $("#f-name").value = draft.name;
  $("#f-sp").value = draft.sp;
  $("#f-desc").value = draft.description;
  $("#f-illust").value = "";
  $("#f-errors").hidden = true;
  for (const id of ["#f-name", "#f-sp", "#f-desc"]) $(id).readOnly = !state.canWrite;
  renderEditorControls();
  syncEditorPreview();
  $("#editor").hidden = false;
  $("#f-name").focus();
}

function closeEditor() {
  $("#editor").hidden = true;
  draft = null;
}

function showErrors(list) {
  const ul = $("#f-errors");
  ul.replaceChildren(...list.map((m) => h("li", {}, m)));
  ul.hidden = !list.length;
}

function writeFailed(e) {
  console.warn("write", e);
  if (e?.code === "invalid_argument") {
    state.canWrite = false;
    $("#notice").textContent = "읽기 전용으로 보고 있어요.";
    toast("편집 권한이 없어 저장하지 못했어요.");
  } else if (e?.code === "quota_exceeded") {
    toast("저장 공간이 가득 찼어요. 안 쓰는 카드를 지운 뒤 다시 저장하세요.");
  } else {
    toast("저장하지 못했어요. 잠시 후 다시 시도하세요.");
  }
}

$("#f-name").addEventListener("input", (e) => { draft.name = e.target.value; syncEditorPreview(); });
$("#f-sp").addEventListener("input", (e) => { draft.sp = e.target.value; syncEditorPreview(); });
$("#f-desc").addEventListener("input", (e) => { draft.description = e.target.value; syncEditorPreview(); });
$("#editor-close").addEventListener("click", closeEditor);
$("#editor-scrim").addEventListener("click", closeEditor);
document.addEventListener("keydown", (e) => { if (e.key === "Escape" && draft) closeEditor(); });

$("#f-illust").addEventListener("change", async (e) => {
  const file = e.target.files?.[0];
  if (!file || !assets) return;
  try {
    const res = await assets.upload(file);
    draft.illustration = res.id;
    renderEditorControls();
    syncEditorPreview();
  } catch (err) {
    console.warn("upload", err);
    toast(err?.code === "too_large" ? "20MB 이하 그림만 올릴 수 있어요."
      : err?.code === "unsupported_type" ? "PNG, JPG, WEBP, GIF 그림만 올릴 수 있어요."
      : "그림을 올리지 못했어요.");
  }
});
$("#f-illust-clear").addEventListener("click", () => {
  draft.illustration = null;
  renderEditorControls();
  syncEditorPreview();
});

$("#f-save").addEventListener("click", async () => {
  const errors = M.validateCard(draft);
  showErrors(errors);
  if (errors.length || !db) return;
  const body = M.normalizeCard(draft);
  const prev = draft.id ? state.cards.find((c) => c.id === draft.id) : null;
  const ref = draft.id ? db.doc("cards/" + draft.id) : db.collection("cards").doc();
  try {
    await ref.set({ ...body, createdAt: prev?.createdAt ?? Date.now() });
    draft.id = ref.id;
    toast("저장했어요");
    $("#editor-title").textContent = "카드 편집";
    renderEditorControls();
  } catch (e) { writeFailed(e); }
});

$("#f-dup").addEventListener("click", () => {
  const copy = { ...draftCard(), id: null, name: draft.name + " 사본" };
  openEditor(null);
  draft = { ...copy, sp: String(copy.sp) };
  $("#f-name").value = draft.name;
  $("#f-sp").value = draft.sp;
  $("#f-desc").value = draft.description;
  renderEditorControls();
  syncEditorPreview();
});

$("#f-add-deck").addEventListener("click", async () => {
  const deck = state.decks.find((d) => d.id === $("#f-deck").value);
  if (!deck || !draft.id) return;
  const entries = M.setEntryCount(deck.entries, draft.id, (deck.entries[draft.id] || 0) + 1);
  try {
    // update 는 중첩 객체를 병합하므로 덱은 항상 set 으로 통째로 쓴다.
    await db.doc("decks/" + deck.id).set({ name: deck.name, entries, createdAt: deck.createdAt });
    toast(`${deck.name}에 추가했어요 (×${entries[draft.id]})`);
  } catch (e) { writeFailed(e); }
});

$("#f-delete").addEventListener("click", async () => {
  if (!deleteArmed) {
    deleteArmed = true;
    $("#f-delete").classList.add("armed");
    $("#f-delete").textContent = "한 번 더 누르면 삭제";
    return;
  }
  const id = draft.id;
  const illustration = draft.illustration;
  try {
    for (const deck of state.decks.filter((d) => d.entries[id])) {
      await db.doc("decks/" + deck.id).set({ name: deck.name, entries: M.removeCardFromEntries(deck.entries, id), createdAt: deck.createdAt });
    }
    await db.doc("cards/" + id).delete();
    if (illustration && assets && !M.isAssetShared(state.cards, illustration, id)) {
      await assets.delete(illustration).catch((e) => console.warn("asset delete", e));
    }
    closeEditor();
    toast("삭제했어요");
  } catch (e) { writeFailed(e); }
});
```

- [ ] **Step 4: 빌드·문법 확인**

Run: `node tools/card_editor/build.mjs && node -e "const s=require('fs').readFileSync('tools/card_editor/dist/card-editor.html','utf8');const m=[...s.matchAll(/<script>([\s\S]*?)<\/script>/g)];m.forEach(x=>new Function(x[1]));console.log('scripts ok',m.length)" && node --test tools/card_editor/`
Expected: `scripts ok 2`, 테스트 PASS (19)

- [ ] **Step 5: 로컬 확인 (수동)**

브라우저로 `dist/card-editor.html` 을 열고 콘솔에서 `state.canWrite = true; render(); openEditor(null)` 실행. 확인: 이름·SP·설명 입력이 미리보기에 바로 반영, 분류 바꾸면 테두리 색 변경, 범위 칸 클릭 시 미니 격자 변경, 저장 누르면 SP 빈칸일 때 "SP는 0 이상의 정수예요" (Review Focus 1). db 가 없으므로 저장 자체는 Task 7 에서 확인. 400px 폭에서 미리보기가 위로 올라가는지 확인.

- [ ] **Step 6: Commit**

```bash
git add tools/card_editor/index.src.html
git commit -m "feat(card-editor): add card editor sheet with live preview"
```

---

### Task 6: 덱 화면

**Files:**
- Modify: `tools/card_editor/index.src.html` (스타일 추가, `renderDecks` 교체)

**Interfaces:**
- Consumes: Task 4 의 `state`, `h`, `renderCard`, `toast`, `db`, `cardsById`, `render`; Task 5 의 `openEditor`, `writeFailed`; Task 2 의 `resolveEntries`, `deckTotal`, `spHistogram`, `setEntryCount`
- Produces: `renderDecks()`

- [ ] **Step 1: 스타일 추가** — `/* 편집 시트 */` 위에

```css
/* 덱 */
.decks { display: grid; grid-template-columns: 220px minmax(0, 1fr); gap: 20px; align-items: start; }
@media (max-width: 720px) { .decks { grid-template-columns: minmax(0, 1fr); } }
.deck-list { display: grid; gap: 4px; }
.deck-list button.item { display: flex; justify-content: space-between; gap: 8px; text-align: left; border: 1px solid transparent; background: none; border-radius: 6px; padding: 8px 10px; }
.deck-list button.item[aria-current="true"] { background: var(--surface); border-color: var(--line); font-weight: 600; }
.deck-list .n { color: var(--muted); font-variant-numeric: tabular-nums; }
.deck-detail { display: grid; gap: 16px; min-width: 0; }
.deck-head { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
.deck-head input { font-family: var(--display); font-size: 20px; border: 1px solid transparent; background: none; border-radius: 6px; padding: 4px 8px; flex: 1 1 200px; min-width: 0; }
.deck-head input:hover, .deck-head input:focus { border-color: var(--line); background: var(--surface); }
.summary { display: flex; flex-wrap: wrap; gap: 24px; align-items: end; background: var(--surface); border: 1px solid var(--line); border-radius: 10px; padding: 12px 16px; }
.total { display: grid; }
.total b { font-family: var(--display); font-weight: 400; font-size: 32px; line-height: 1; font-variant-numeric: tabular-nums; }
.total span, .bars-label { font-size: 12px; color: var(--muted); }
.bars { display: flex; gap: 6px; align-items: end; height: 72px; }
.bar { display: grid; grid-template-rows: auto 1fr auto; justify-items: center; gap: 2px; height: 100%; font-size: 11px; font-variant-numeric: tabular-nums; }
.bar i { width: 18px; align-self: end; background: var(--accent); border-radius: 3px 3px 0 0; min-height: 2px; }
.bar small { color: var(--muted); }
.slot { display: grid; gap: 6px; }
.stepper { display: flex; justify-content: center; align-items: center; gap: 6px; }
.stepper button { width: 28px; height: 28px; border: 1px solid var(--line); background: var(--surface); border-radius: 6px; padding: 0; }
.stepper span { min-width: 2ch; text-align: center; font-variant-numeric: tabular-nums; }
.add-row { display: flex; flex-wrap: wrap; gap: 8px; }
.add-row select { border: 1px solid var(--line); background: var(--surface); border-radius: 6px; padding: 6px 10px; min-width: 0; flex: 0 1 240px; }
```

- [ ] **Step 2: `renderDecks` 교체** — `// Task 6 에서 채운다.` 와 빈 `renderDecks` 를 지우고 아래로 바꾼다

```js
let deckDeleteArmed = null;

async function saveDeck(deck, patch) {
  try {
    // update 는 중첩 객체를 병합하므로 덱은 항상 set 으로 통째로 쓴다.
    await db.doc("decks/" + deck.id).set({ name: deck.name, entries: deck.entries, createdAt: deck.createdAt, ...patch });
  } catch (e) { writeFailed(e); }
}

async function createDeck() {
  try {
    const ref = db.collection("decks").doc();
    await ref.set({ name: "새 덱", entries: {}, createdAt: Date.now() });
    state.deckId = ref.id;
  } catch (e) { writeFailed(e); }
}

function renderDecks() {
  const root = $("#view-decks");
  const byId = cardsById();
  if (!state.decks.find((d) => d.id === state.deckId)) state.deckId = state.decks[0]?.id ?? null;
  const deck = state.decks.find((d) => d.id === state.deckId);

  const list = h("nav", { class: "deck-list", "aria-label": "덱 목록" },
    ...state.decks.map((d) => h("button", {
      type: "button", class: "item", "aria-current": String(d.id === state.deckId),
      onclick: () => { state.deckId = d.id; deckDeleteArmed = null; renderDecks(); },
    }, h("span", {}, d.name), h("span", { class: "n" }, M.deckTotal(d.entries, byId) + "장"))),
    state.canWrite && db ? h("button", { type: "button", class: "btn", onclick: createDeck }, "새 덱") : null);

  if (!deck) {
    root.replaceChildren(h("div", { class: "decks" }, list,
      h("div", { class: "empty" }, h("strong", {}, "아직 덱이 없어요"),
        state.canWrite ? "‘새 덱’으로 만들고 카드를 넣어 보세요." : "편집 권한이 있는 사람이 덱을 만들면 여기에 보여요.")));
    return;
  }

  const rows = M.resolveEntries(deck.entries, byId);
  const hist = M.spHistogram(deck.entries, byId);
  const peak = Math.max(1, ...hist.map((b) => b.count));
  const ro = !state.canWrite || !db;

  const nameInput = h("input", { id: "deck-name", type: "text", value: deck.name, "aria-label": "덱 이름", readonly: ro });
  nameInput.addEventListener("change", () => {
    const name = nameInput.value.trim() || "이름 없는 덱";
    if (name !== deck.name) saveDeck(deck, { name });
  });

  const delBtn = h("button", {
    type: "button", class: "btn danger" + (deckDeleteArmed === deck.id ? " armed" : ""), hidden: ro,
    onclick: async () => {
      if (deckDeleteArmed !== deck.id) { deckDeleteArmed = deck.id; renderDecks(); return; }
      deckDeleteArmed = null;
      try { await db.doc("decks/" + deck.id).delete(); toast("덱을 삭제했어요"); } catch (e) { writeFailed(e); }
    },
  }, deckDeleteArmed === deck.id ? "한 번 더 누르면 삭제" : "덱 삭제");

  const summary = h("div", { class: "summary" },
    h("div", { class: "total" }, h("b", {}, M.deckTotal(deck.entries, byId)), h("span", {}, "총 장수")),
    h("div", {},
      h("div", { class: "bars-label" }, "SP별 장수"),
      hist.length
        ? h("div", { class: "bars" }, ...hist.map((b) => h("div", { class: "bar", title: `SP ${b.sp}: ${b.count}장` },
            h("span", {}, b.count), h("i", { style: `height:${Math.round((b.count / peak) * 48)}px` }), h("small", {}, "SP " + b.sp))))
        : h("div", { class: "notice" }, "카드가 없어요")));

  const addable = M.filterSort(state.cards, { category: "all", query: "", sort: "name" });
  const addSel = h("select", { id: "deck-add", "aria-label": "넣을 카드" }, ...addable.map((c) => h("option", { value: c.id }, `${c.name} (SP ${c.sp})`)));
  const addRow = ro || !addable.length ? null : h("div", { class: "add-row" }, addSel,
    h("button", { type: "button", class: "btn", onclick: () => {
      const id = addSel.value;
      saveDeck(deck, { entries: M.setEntryCount(deck.entries, id, (deck.entries[id] || 0) + 1) });
    } }, "덱에 넣기"));

  const grid = rows.length
    ? h("div", { class: "grid" }, ...rows.map(({ card, count }) => h("div", { class: "slot" },
        renderCard(card, { count, onClick: () => openEditor(card) }),
        ro ? null : h("div", { class: "stepper" },
          h("button", { type: "button", "aria-label": card.name + " 한 장 빼기",
            onclick: () => saveDeck(deck, { entries: M.setEntryCount(deck.entries, card.id, count - 1) }) }, "−"),
          h("span", {}, count),
          h("button", { type: "button", "aria-label": card.name + " 한 장 더",
            onclick: () => saveDeck(deck, { entries: M.setEntryCount(deck.entries, card.id, count + 1) }) }, "+")))))
    : h("div", { class: "empty" }, "이 덱은 비어 있어요. 위에서 카드를 넣거나, 카드 편집 창의 ‘덱에 추가’를 쓰세요.");

  root.replaceChildren(h("div", { class: "decks" }, list,
    h("div", { class: "deck-detail" }, h("div", { class: "deck-head" }, nameInput, delBtn), summary, addRow, grid)));
}
```

- [ ] **Step 3: 빌드·문법 확인**

Run: `node tools/card_editor/build.mjs && node -e "const s=require('fs').readFileSync('tools/card_editor/dist/card-editor.html','utf8');const m=[...s.matchAll(/<script>([\s\S]*?)<\/script>/g)];m.forEach(x=>new Function(x[1]));console.log('scripts ok',m.length)" && node --test tools/card_editor/`
Expected: `scripts ok 2`, 테스트 PASS (19)

- [ ] **Step 4: 로컬 확인 (수동)**

콘솔에서 seed 를 넣어 덱 화면을 본다 (Review Focus 2: 없는 카드 id `gone` 이 있어도 깨지지 않음):

```js
const S = [/* seed.json 내용 붙여넣기 */];
state.cards = S.filter(o => o.collection === "cards").map(o => ({ id: o.doc_id, ...M.normalizeCard(o.data) }));
state.decks = S.filter(o => o.collection === "decks").map(o => ({ id: o.doc_id, createdAt: o.data.createdAt, ...M.normalizeDeck(o.data) }));
state.decks[0].entries.gone = 4; state.loaded = true; state.view = "decks"; render();
```

확인: 사수 덱 총 8장, SP 막대 SP1 3 / SP2 5, 카드에 ×N 배지.

- [ ] **Step 5: Commit**

```bash
git add tools/card_editor/index.src.html
git commit -m "feat(card-editor): add deck view with counts and sp bars"
```

---

### Task 7: 게시·초기 데이터·기능 확인

**Files:** 없음 (게시 작업)

- [ ] **Step 1: 빌드**

Run: `node tools/card_editor/build.mjs`

- [ ] **Step 2: 첫 게시**

Artifact 도구 publish: `file_path` = `tools/card_editor/dist/card-editor.html`, `icon` = `"cards"`, `description` = "Project Void 카드를 직접 쓰고 카드 모양으로 보며 덱으로 묶는 편집기", `capabilities` = `{"db": {}, "user": {}, "assets": {}}`. 결과의 URL 을 기록한다.

- [ ] **Step 3: 초기 데이터 넣기**

ToolSearch 로 `ArtifactData` 스키마를 불러오고, 그 `batch` 형식에 맞춰 `seed.json` 10개 문서를 한 번에 쓴다 (url = Step 2 URL).

- [ ] **Step 4: 기능 확인 (한 번)**

`ArtifactData` `list` 로 `cards` (7개), `decks` (3개) 를 읽어 확인한다.

- [ ] **Step 5: 사용자에게 전달**

링크와 함께 한 줄씩: 확인한 것(데이터 읽기), 확인 못 한 것(실제 브라우저에서 저장·업로드), `assets` 를 켜서 조직 밖 공개 링크 공유는 안 된다는 점.
