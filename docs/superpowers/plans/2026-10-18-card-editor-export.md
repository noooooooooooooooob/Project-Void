# 카드 에디터 영어 칸 + JSON 내보내기 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 카드·키워드·덱에 영어 이름/설명을 추가하고, 전체 데이터를 `cards.json` + 일러스트가 든 zip으로 내보낸다.

**Architecture:** 데이터 변환(영어 필드 정규화, 내보내기 JSON, zip 바이트)은 모두 `card_model.js` 순수 함수로 만들고 Node 테스트로 검증한다. `index.src.html`은 입력 칸, 저장, 버튼 흐름(그림 fetch → `buildExport` → `makeZip` → `downloads.save`)만 맡는다.

**Tech Stack:** 바닐라 JS, Node `node:test`, claude.ai 아티팩트 런타임(`db`, `assets`, `user`, `downloads`)

**Spec:** `docs/superpowers/specs/2026-10-18-card-editor-export-design.md`

## Global Constraints

- 테스트: 저장소 루트에서 `node --test "tools/card_editor/*.test.js"`, 빌드: `node tools/card_editor/build.mjs`
- 외부 라이브러리 추가 금지 (zip 도 직접)
- db 필드 이름: 카드 면·키워드 `nameEn`, `descriptionEn` / 덱 `nameEn`. 없는 예전 문서는 `""`
- JSON 최상위 키는 `keywords`, `decks`, `cards` 뿐. 텍스트는 `{ "ko": ..., "en": ... }`
- zip 파일 이름 `project-void-cards.zip`, 안에 `cards.json`, `art/{assetId}.{ext}`
- 화면 문구는 기존처럼 한국어 해요체
- 커밋은 사용자가 요청할 때만 (작업 트리에 이전 작업의 미커밋 변경이 있음)

## Review Focus

1. 예전 문서(영어 필드 없음)를 열고 저장 → 영어가 `""`로 저장되고 다른 값은 그대로 (Task 1 테스트)
2. 키워드/덱 이름만 고쳐 저장해도 영어 값이 지워지지 않음 (Task 4 수동 확인 + `saveKeyword`/`saveDeck` 가 영어 필드를 씀)
3. 지워진 키워드 id, 지워진 덱의 카드 → JSON 에서 빠지고, 그 카드의 그림도 zip 에 안 들어감 (Task 2 테스트)
4. 강화 면만 그림이 있거나 기본과 강화가 같은 그림 → 파일 하나, 각 면의 `art` 경로가 맞음 (Task 2 테스트)
5. 그림 0개(카드 0장 포함) zip 도 올바른 zip (Task 3 테스트)

---

### Task 1: 영어 필드 정규화와 강화 이름 비우기

**Files:**
- Modify: `tools/card_editor/card_model.js` (`normalizeFace`, `normalizeKeyword`, `normalizeDeck`, `newUpgrade`)
- Test: `tools/card_editor/card_model.test.js`

**Interfaces:**
- Produces: `normalizeFace` 결과에 `nameEn: string`(trim), `descriptionEn: string` 추가 (그래서 `normalizeCard` 기본 면과 각 `upgrades[]` 에도). `normalizeKeyword` → `{ name, nameEn, description, descriptionEn }`. `normalizeDeck` → `{ name, nameEn }`. `newUpgrade(card)` → 앞 단계 복사 + `name: ""`, `nameEn: ""`.

- [ ] **Step 1: 기존 테스트의 기대 객체 갱신 + 새 테스트 작성**

기존 deepEqual 테스트(`normalizeCard fills defaults`, `normalizeCard keeps upgrades…`, `newUpgrade copies the previous level`, `migrationWrites copies…`, `normalizeKeyword and validateKeyword`, `normalizeDeck keeps only the name`)의 기대값에 `nameEn: ""`, `descriptionEn: ""`(덱은 `nameEn` 만)를 넣고, `newUpgrade` 기대 이름을 `""` 로 바꾼다. 새 테스트:

```js
test("faces, keywords and decks keep English text", () => {
  const c = M.normalizeCard({ name: "베기", nameEn: " Slash ", descriptionEn: "Hit\nhard",
    upgrades: [{ name: "베기 강", nameEn: "Hard Slash" }] });
  assert.equal(c.nameEn, "Slash");
  assert.equal(c.descriptionEn, "Hit\nhard");
  assert.equal(c.upgrades[0].nameEn, "Hard Slash");
  assert.equal(c.upgrades[0].descriptionEn, "");
  assert.deepEqual(M.normalizeKeyword({ name: "화상", nameEn: " Burn ", descriptionEn: "d" }),
    { name: "화상", nameEn: "Burn", description: "", descriptionEn: "d" });
  assert.deepEqual(M.normalizeDeck({ name: "포수", nameEn: " Gunner " }), { name: "포수", nameEn: "Gunner" });
});

test("newUpgrade leaves both names blank", () => {
  const base = M.normalizeCard({ name: "베기", nameEn: "Slash", descriptionEn: "e" });
  const up = M.newUpgrade(base);
  assert.equal(up.name, "");
  assert.equal(up.nameEn, "");
  assert.equal(up.descriptionEn, "e");
});
```

- [ ] **Step 2: 실패 확인** — `node --test "tools/card_editor/*.test.js"` → 위 테스트들 FAIL
- [ ] **Step 3: 구현** — 위 Interfaces 대로. `newUpgrade` 의 `level` 계산과 "+" 주석은 지운다.
- [ ] **Step 4: 통과 확인** — 같은 명령, 전부 PASS

### Task 2: `buildExport`, `exportAssets`

**Files:**
- Modify: `tools/card_editor/card_model.js`
- Test: `tools/card_editor/card_model.test.js`

**Interfaces:**
- Consumes: Task 1 정규화 결과, 기존 `cardsInDeck`, `cardAssets`
- Produces:
  - `exportCards(cards, decks) -> card[]`: 공용 카드(`cardsInDeck(cards, null)`) 다음 `decks` 순서대로 `cardsInDeck(cards, d.id)`. 지워진 덱 카드 제외. `decks` 는 화면 순서로 정렬된 것을 받는다.
  - `exportAssets(cards, decks) -> string[]`: `exportCards` 결과의 `cardAssets` 를 순서대로, 중복 없이.
  - `buildExport({ cards, decks, keywords }, artPath) -> { keywords, decks, cards }`: `artPath(assetId) -> string | null`. 스펙의 `cards.json` 형식 그대로. 면 필드 순서: `name, description, sp, cost, category, attackType, area, keywords, art` (기본 면은 앞에 `id, deck`, 뒤에 `upgrades`). 면의 `keywords` 는 `keywords` 목록에 있는 id 만, 붙인 순서. 그림 없는 면은 `art: null` (artPath 를 부르지 않음).

- [ ] **Step 1: 테스트 작성**

```js
const exKws = [{ id: "k1", name: "화상", nameEn: "Burn", description: "d", descriptionEn: "e" }];
const exDecks = [{ id: "d2", name: "포수", nameEn: "Gunner", order: 0 }, { id: "d1", name: "검사", nameEn: "", order: 1 }];
const exCards = [
  { id: "x", ...M.normalizeCard({ name: "나", deckId: "d1", illustration: "a1" }) },
  { id: "y", ...M.normalizeCard({ name: "가", sp: 2, cost: 1, nameEn: "Ga", keywords: ["gone", "k1"], area: [[1, 0], [0, 0]],
      illustration: "a1", upgrades: [{ name: "가 강", illustration: "a2" }] }) },
  { id: "z", ...M.normalizeCard({ name: "다", deckId: "d2" }) },
  { id: "o", ...M.normalizeCard({ name: "고아", deckId: "deleted", illustration: "a3" }) },
];

test("exportCards puts common cards first, then decks in tab order, skipping orphans", () => {
  assert.deepEqual(M.exportCards(exCards, exDecks).map((c) => c.id), ["y", "z", "x"]);
});

test("exportAssets lists each used illustration once", () => {
  assert.deepEqual(M.exportAssets(exCards, exDecks), ["a1", "a2"]);
});

test("buildExport writes the game JSON shape", () => {
  const out = M.buildExport({ cards: exCards, decks: exDecks, keywords: exKws }, (id) => (id === "a2" ? null : `art/${id}.png`));
  assert.deepEqual(Object.keys(out), ["keywords", "decks", "cards"]);
  assert.deepEqual(out.keywords, [{ id: "k1", name: { ko: "화상", en: "Burn" }, description: { ko: "d", en: "e" } }]);
  assert.deepEqual(out.decks, [{ id: "d2", name: { ko: "포수", en: "Gunner" } }, { id: "d1", name: { ko: "검사", en: "" } }]);
  assert.deepEqual(out.cards[0], {
    id: "y", deck: null, name: { ko: "가", en: "Ga" }, description: { ko: "", en: "" },
    sp: 2, cost: 1, category: "attack", attackType: "melee", area: [[0, 0], [1, 0]], keywords: ["k1"], art: "art/a1.png",
    upgrades: [{ name: { ko: "가 강", en: "" }, description: { ko: "", en: "" }, sp: 0, cost: 0, category: "attack",
      attackType: "melee", area: [], keywords: [], art: null }],
  });
  assert.equal(out.cards[1].art, null);
  assert.deepEqual(out.cards[2].upgrades, []);
  assert.equal(out.cards[2].deck, "d1");
});
```

- [ ] **Step 2: 실패 확인** — `exportCards is not a function`
- [ ] **Step 3: 구현** 후 `api` 에 `exportCards, exportAssets, buildExport` 추가
- [ ] **Step 4: 통과 확인**

### Task 3: `makeZip`

**Files:**
- Modify: `tools/card_editor/card_model.js`
- Test: `tools/card_editor/card_model.test.js`

**Interfaces:**
- Produces: `makeZip(entries: { name: string, bytes: Uint8Array }[]) -> Uint8Array` — store(압축 없음) zip. 각 항목: local header(`0x04034b50`, version 20, flag `0x0800` UTF-8, method 0, 시각/날짜 0, CRC32, 크기 2번, 이름 길이, extra 0) + 이름(UTF-8) + 바이트. 끝에 central directory(`0x02014b50`, 같은 값 + local header offset) 와 EOCD(`0x06054b50`, 항목 수, cd 크기, cd offset). 리틀엔디언. CRC32 는 표준 다항식 `0xEDB88320` 표.

- [ ] **Step 1: 테스트 작성** — 시스템 압축 도구 없이 직접 파싱해 확인한다.

```js
function readZip(buf) {
  const v = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  const eocd = buf.length - 22;
  assert.equal(v.getUint32(eocd, true), 0x06054b50);
  const count = v.getUint16(eocd + 10, true);
  let p = v.getUint32(eocd + 16, true);
  const out = [];
  for (let i = 0; i < count; i++) {
    assert.equal(v.getUint32(p, true), 0x02014b50);
    const crc = v.getUint32(p + 16, true), size = v.getUint32(p + 20, true);
    const nameLen = v.getUint16(p + 28, true), off = v.getUint32(p + 42, true);
    const name = new TextDecoder().decode(buf.subarray(p + 46, p + 46 + nameLen));
    assert.equal(v.getUint32(off, true), 0x04034b50);
    const dataAt = off + 30 + v.getUint16(off + 26, true) + v.getUint16(off + 28, true);
    out.push({ name, crc, bytes: buf.subarray(dataAt, dataAt + size) });
    p += 46 + nameLen;
  }
  return out;
}

test("makeZip stores files that read back with correct CRC32", () => {
  const json = new TextEncoder().encode('{"a":"베기"}');
  const zip = M.makeZip([{ name: "cards.json", bytes: json }, { name: "art/한글.png", bytes: new Uint8Array([1, 2, 3]) }]);
  const files = readZip(zip);
  assert.deepEqual(files.map((f) => f.name), ["cards.json", "art/한글.png"]);
  assert.deepEqual([...files[1].bytes], [1, 2, 3]);
  assert.equal(new TextDecoder().decode(files[0].bytes), '{"a":"베기"}');
  assert.equal(files[1].crc, 0x55bc801d); // CRC32 of [1,2,3]
});

test("makeZip with no entries is an empty archive", () => {
  const zip = M.makeZip([]);
  assert.equal(zip.length, 22);
  assert.deepEqual(readZip(zip), []);
});
```

- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현** 후 `api` 에 `makeZip` 추가
- [ ] **Step 4: 통과 확인** — 추가로 Node 에서 만든 zip 을 PowerShell `Expand-Archive` 로 풀어 열리는지 한 번 확인

### Task 4: 영어 입력 칸 (카드·키워드·덱)

**Files:**
- Modify: `tools/card_editor/index.src.html`

**Interfaces:**
- Consumes: Task 1 필드

- [ ] **Step 1: 카드 편집 창** — 이름 줄(`.row`) 바로 아래 `<label class="field"><span>영어 이름</span><input id="f-name-en" type="text" autocomplete="off"></label>`, 설명 아래 `<label class="field"><span>영어 설명</span><textarea id="f-desc-en" maxlength="20000"></textarea></label>`. `fillEditorInputs` 가 `face().nameEn/descriptionEn` 을 채우고, input 이벤트가 `face()` 에 쓰며, `openEditor` 의 readOnly 목록에 두 id 추가.
- [ ] **Step 2: 키워드 탭** — 각 행 이름 입력 옆에 영어 이름 input(`aria-label` "키워드 영어 이름", placeholder "영어 이름"), 설명 아래 영어 설명 textarea(placeholder "영어 설명"). change 시 `saveKeyword(kw, { nameEn })` / `{ descriptionEn }`. `saveKeyword` 와 `createKeyword` 가 `nameEn`, `descriptionEn` 을 함께 쓴다 (`createKeyword` 는 `""`). 키워드 snapshot 은 이미 `normalizeKeyword` 를 거친다.
- [ ] **Step 3: 덱 탭** — `deck-head` 의 이름 input 다음에 영어 덱 이름 input(`id="deck-name-en"`, placeholder "영어 이름", 같은 readonly 규칙, 기존 `.deck-head input` 스타일보다 작은 본문 글꼴). change 시 `saveDeck(deck, { nameEn })`. `saveDeck`, `createDeck` 이 `nameEn` 을 함께 쓴다. 다시 그릴 때 입력 보존 로직을 `deck-name-en` 에도 적용.
- [ ] **Step 4: 확인** — 빌드 후 테스트 통과, 게시 전 로컬에서 `dist/card-editor.html` 을 브라우저로 열어 칸이 보이고 레이아웃(폭 360px 포함)이 깨지지 않는지 확인

### Task 5: 내보내기 버튼, 문서, 게시

**Files:**
- Modify: `tools/card_editor/index.src.html`, `tools/card_editor/README.md`

**Interfaces:**
- Consumes: `exportCards`, `exportAssets`, `buildExport`, `makeZip`

- [ ] **Step 1: 버튼** — 상단 `#new-card` 앞에 `<button id="export" type="button" class="btn" hidden>내보내기</button>`. `boot()` 에서 `db` 확보 뒤 `downloads = await claude.use("downloads")`, 있으면 보이게 (모든 탭, 읽기 전용 포함).
- [ ] **Step 2: 흐름** — 클릭: 버튼 잠금 → `exportAssets(state.cards, state.decks)` 각 id 를 `fetch("/_blob/" + id)` (실패·`!ok` 는 빠진 것으로 셈) → 확장자 `{ "image/png": "png", "image/jpeg": "jpg", "image/webp": "webp", "image/gif": "gif" }[type] ?? "bin"` → `buildExport(state, (id) => paths.get(id) ?? null)` → `JSON.stringify(json, null, 2)` 를 `cards.json` 으로, 그림을 `art/…` 로 `makeZip` → `downloads.save({ filename: "project-void-cards.zip", data: new Blob([zip]) })`. 결과: `saved` 면 빠진 그림이 있을 때만 "그림 n개를 넣지 못했어요", 없으면 "내보냈어요". 오류 `declined` 는 조용히, `rate_limited` 는 "잠시 후 다시 눌러 주세요", 그 외 "내보내지 못했어요". `finally` 에서 잠금 해제.
- [ ] **Step 3: README** — "카드 내보내기" 절: 버튼 위치, zip 구성, `cards.json` 형식(스펙의 예시와 값 목록), 영어 칸 설명, "강화 이름은 빈 칸으로 시작" 반영. 알려진 제한의 "`.tres` 가져오기·내보내기 없음" 줄은 "Godot 가져오기 없음 (JSON 내보내기만)" 으로 고친다.
- [ ] **Step 4: 빌드·테스트** — 테스트 PASS, `node tools/card_editor/build.mjs`
- [ ] **Step 5: 게시** — `dist/card-editor.html` 을 기존 URL `https://claude.ai/artifact/T2zETQHPfWew1HejtgHKHd` 에 publish, `capabilities: { assets: {}, db: {}, user: {}, downloads: true }`. 그 뒤 `ArtifactData list` 로 `cards`/`decks`/`keywords` 가 그대로인지 확인하고, 사용자에게 실제 내보내기(그림 fetch 동작 포함)를 눌러 봐 달라고 요청
