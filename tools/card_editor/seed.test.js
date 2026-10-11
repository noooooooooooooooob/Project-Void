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
