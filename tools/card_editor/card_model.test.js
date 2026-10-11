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
