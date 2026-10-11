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
