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
