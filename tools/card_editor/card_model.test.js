const test = require("node:test");
const assert = require("node:assert/strict");
const M = require("./card_model.js");

test("normalizeCard fills defaults", () => {
  assert.deepEqual(M.normalizeCard({ name: "  베기 ", sp: "1" }), {
    name: "베기", sp: 1, category: "attack", attackType: "melee",
    area: [], illustration: null, description: "", deckId: null,
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

const cards = [
  { id: "a", ...M.normalizeCard({ name: "베기", sp: 1, category: "attack" }) },
  { id: "b", ...M.normalizeCard({ name: "방어", sp: 0, category: "skill" }) },
  { id: "c", ...M.normalizeCard({ name: "관통사격", sp: 2, category: "attack" }) },
];

test("filterSort by category and query", () => {
  assert.deepEqual(M.filterSort(cards, { category: "attack", query: "", sort: "name" }).map((c) => c.id), ["c", "a"]);
  assert.deepEqual(M.filterSort(cards, { category: "all", query: "사격", sort: "name" }).map((c) => c.id), ["c"]);
});

test("filterSort by sp then name", () => {
  assert.deepEqual(M.filterSort(cards, { category: "all", query: "", sort: "sp" }).map((c) => c.id), ["b", "a", "c"]);
});

test("isAssetShared checks other cards only", () => {
  const list = [{ id: "x", illustration: "img1" }, { id: "y", illustration: "img1" }, { id: "z", illustration: null }];
  assert.equal(M.isAssetShared(list, "img1", "x"), true);
  assert.equal(M.isAssetShared(list.slice(0, 1), "img1", "x"), false);
});

test("writeErrorKind tells a too-large document from a refused write", () => {
  assert.equal(M.writeErrorKind({ code: "invalid_argument" }, true), "too_large");
  assert.equal(M.writeErrorKind({ code: "invalid_argument" }, null), "readonly");
  assert.equal(M.writeErrorKind({ code: "invalid_argument" }, false), "readonly");
  assert.equal(M.writeErrorKind({ code: "quota_exceeded" }, true), "quota");
  assert.equal(M.writeErrorKind({ code: "unavailable" }, true), "retry");
  assert.equal(M.writeErrorKind(undefined, true), "retry");
});

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
