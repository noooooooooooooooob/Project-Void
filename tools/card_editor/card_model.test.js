const test = require("node:test");
const assert = require("node:assert/strict");
const M = require("./card_model.js");

test("normalizeCard fills defaults", () => {
  assert.deepEqual(M.normalizeCard({ name: "  베기 ", sp: "1" }), {
    name: "베기", sp: 1, cost: 0, category: "attack", attackType: "melee",
    area: [], illustration: null, description: "", keywords: [], deckId: null, upgrades: [],
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
  { id: "a", ...M.normalizeCard({ name: "베기", sp: 1, cost: 0, category: "attack" }) },
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
      data: { name: "사격", sp: 1, cost: 0, category: "attack", attackType: "ranged", area: [], illustration: null, description: "", keywords: [], deckId: "archer", upgrades: [], createdAt: 5 } },
    { op: "set", collection: "decks", doc_id: "archer", if_version: 3, data: { name: "사수", createdAt: 9 } },
  ]);
});

test("migrationWrites is a no-op once migrated", () => {
  const cardDocs = [{ id: "archer--shoot", version: 1, data: { name: "사격", sp: 1, deckId: "archer", createdAt: 5 } }];
  const deckDocs = [{ id: "archer", version: 4, data: { name: "사수", createdAt: 9 } }];
  assert.deepEqual(M.migrationWrites(cardDocs, deckDocs), []);
});

test("assetsFreedByDeckDelete keeps illustrations used outside the deck", () => {
  const list = [
    { id: "a1", deckId: "archer", illustration: "only" },
    { id: "a2", deckId: "archer", illustration: "shared-copy" },
    { id: "a3", deckId: "archer", illustration: "shared-common" },
    { id: "a4", deckId: "archer", illustration: "only" },
    { id: "a5", deckId: "archer", illustration: "shared-orphan" },
    { id: "a6", deckId: "archer", illustration: null },
    { id: "s1", deckId: "scout", illustration: "shared-copy" },
    { id: "c1", deckId: null, illustration: "shared-common" },
    { id: "o1", deckId: "gone", illustration: "shared-orphan" },
  ];
  assert.deepEqual(M.assetsFreedByDeckDelete(list, "archer"), ["only"]);
});

test("formatUsage shows bytes and files against the limits", () => {
  const MB = 1024 * 1024;
  assert.deepEqual(M.formatUsage({ bytes: 12.4 * MB, maxBytes: 1024 * MB, files: 34, maxFiles: 1000 }),
    { text: "그림 저장 공간 12.4MB / 1GB · 파일 34 / 1000개", warn: false });
  assert.deepEqual(M.formatUsage({ bytes: 0, maxBytes: 500 * MB, files: 0, maxFiles: 100 }),
    { text: "그림 저장 공간 0MB / 500MB · 파일 0 / 100개", warn: false });
});

test("formatUsage warns at 80% of bytes or files", () => {
  const MB = 1024 * 1024;
  assert.equal(M.formatUsage({ bytes: 80 * MB, maxBytes: 100 * MB, files: 1, maxFiles: 100 }).warn, true);
  assert.equal(M.formatUsage({ bytes: 1, maxBytes: 100 * MB, files: 80, maxFiles: 100 }).warn, true);
  assert.equal(M.formatUsage({ bytes: 79 * MB, maxBytes: 100 * MB, files: 79, maxFiles: 100 }).warn, false);
});

test("normalizeCard keeps upgrades without deck fields, at most 5", () => {
  const c = M.normalizeCard({ name: "베기", sp: 1, deckId: "archer",
    upgrades: [{ name: " 베기+ ", sp: "0", category: "skill", area: [[0, 0], [9, 9]], illustration: "img2", deckId: "x" }, "nope"] });
  assert.deepEqual(c.upgrades, [{
    name: "베기+", sp: 0, cost: 0, category: "skill", attackType: "melee",
    area: [[0, 0]], illustration: "img2", description: "", keywords: [],
  }]);
  const many = M.normalizeCard({ name: "x", upgrades: Array.from({ length: 7 }, (_, i) => ({ name: "u" + i })) });
  assert.equal(many.upgrades.length, M.MAX_UPGRADES);
  assert.equal(M.MAX_UPGRADES, 5);
});

test("normalizeCard reads an old single upgrade as the first upgrade", () => {
  assert.deepEqual(M.normalizeCard({ name: "x", upgrade: { name: "x+" } }).upgrades.map((u) => u.name), ["x+"]);
  assert.deepEqual(M.normalizeCard({ name: "x", upgrade: null }).upgrades, []);
  assert.equal("upgrade" in M.normalizeCard({ name: "x", upgrade: { name: "x+" } }), false);
});

test("newUpgrade copies the previous level", () => {
  const base = M.normalizeCard({ name: "베기", sp: 2, area: [[0, 0]], illustration: "img", description: "d", deckId: "archer" });
  assert.deepEqual(M.newUpgrade(base), {
    name: "베기+", sp: 2, cost: 0, category: "attack", attackType: "melee",
    area: [[0, 0]], illustration: "img", description: "d", keywords: [],
  });
  const lv1 = { ...base, upgrades: [{ ...M.newUpgrade(base), sp: 1, description: "d1" }] };
  assert.deepEqual(M.newUpgrade(lv1), { ...lv1.upgrades[0], name: "베기+2" });
});

test("validateCard checks every upgrade", () => {
  assert.deepEqual(M.validateCard({ name: "x", sp: 1, upgrades: [{ name: "a", sp: 1 }, { name: "", sp: "-1" }] }),
    ["강화 2: 이름을 입력하세요", "강화 2: SP는 0 이상의 정수예요"]);
  assert.deepEqual(M.validateCard({ name: "x", sp: 1, upgrades: [] }), []);
  assert.deepEqual(M.validateCard({ name: "x", sp: 1 }), []);
});

test("asset rules count upgrade illustrations", () => {
  const list = [
    { id: "x", deckId: "archer", illustration: "img1", upgrades: [{ illustration: "up1" }, { illustration: "up2" }] },
    { id: "y", deckId: null, illustration: null, upgrades: [{ illustration: "img1" }, { illustration: "up2" }] },
  ];
  assert.equal(M.isAssetShared(list, "img1", "x"), true);
  assert.equal(M.isAssetShared(list, "up1", "y"), true);
  assert.equal(M.isAssetShared(list, "up1", "x"), false);
  assert.deepEqual(M.assetsFreedByDeckDelete(list, "archer"), ["up1"]);
  assert.deepEqual(M.cardAssets({ illustration: "a", upgrades: [{ illustration: "a" }, { illustration: null }] }), ["a"]);
});

test("cost defaults to 0 and is validated like sp", () => {
  assert.equal(M.normalizeCard({ name: "x" }).cost, 0);
  assert.equal(M.normalizeCard({ name: "x", cost: " 3 " }).cost, 3);
  assert.equal(M.normalizeCard({ name: "x", upgrades: [{ name: "x+", cost: 2 }] }).upgrades[0].cost, 2);
  assert.deepEqual(M.validateCard({ name: "x", sp: 1, cost: "-1" }), ["코스트는 0 이상의 정수예요"]);
  assert.deepEqual(M.validateCard({ name: "x", sp: 1 }), []);
  assert.deepEqual(M.validateCard({ name: "x", sp: 1, upgrades: [{ name: "a", sp: 1, cost: "1.5" }] }),
    ["강화 1: 코스트는 0 이상의 정수예요"]);
});

test("averageCost uses base card cost, one decimal", () => {
  assert.equal(M.averageCost([]), null);
  assert.equal(M.averageCost([{ cost: 1 }, { cost: 2 }, { cost: 2, upgrades: [{ cost: 9 }] }]), 1.7);
});

test("normalizeCard keeps keyword ids per face, unique, strings only", () => {
  const c = M.normalizeCard({ name: "x", keywords: ["k1", "k1", "", 3, "k2"],
    upgrades: [{ name: "x+", keywords: ["k3"] }, { name: "x+2" }] });
  assert.deepEqual(c.keywords, ["k1", "k2"]);
  assert.deepEqual(c.upgrades.map((u) => u.keywords), [["k3"], []]);
  assert.deepEqual(M.normalizeCard({ name: "x", keywords: "k1" }).keywords, []);
});

test("newUpgrade copies keywords", () => {
  const base = M.normalizeCard({ name: "x", keywords: ["k1"] });
  const up = M.newUpgrade(base);
  assert.deepEqual(up.keywords, ["k1"]);
  up.keywords.push("k2");
  assert.deepEqual(base.keywords, ["k1"]);
});

test("normalizeKeyword and validateKeyword", () => {
  assert.deepEqual(M.normalizeKeyword({ name: " 관통 ", description: "뒤까지 맞힘", x: 1 }), { name: "관통", description: "뒤까지 맞힘" });
  assert.deepEqual(M.normalizeKeyword(null), { name: "", description: "" });
  assert.deepEqual(M.validateKeyword({ name: " " }), ["이름을 입력하세요"]);
  assert.deepEqual(M.validateKeyword({ name: "관통" }), []);
});

test("faceKeywords resolves ids in card order and skips deleted ones", () => {
  const kws = [{ id: "a", name: "출혈", description: "d1" }, { id: "b", name: "관통", description: "d2" }];
  assert.deepEqual(M.faceKeywords({ keywords: ["b", "gone", "a"] }, kws).map((k) => k.name), ["관통", "출혈"]);
  assert.deepEqual(M.faceKeywords({}, kws), []);
});

test("keywordUsage counts cards using a keyword on any face", () => {
  const cards = [
    { keywords: ["a"], upgrades: [] },
    { keywords: [], upgrades: [{ keywords: ["a"] }] },
    { keywords: ["b"], upgrades: [{ keywords: ["b"] }] },
  ];
  assert.equal(M.keywordUsage(cards, "a"), 2);
  assert.equal(M.keywordUsage(cards, "b"), 1);
  assert.equal(M.keywordUsage(cards, "z"), 0);
});

test("byOrder puts ordered items first, then falls back", () => {
  const list = [{ id: "a", name: "가" }, { id: "b", name: "나", order: 1 }, { id: "c", name: "다", order: 0 }, { id: "d", name: "라" }];
  assert.deepEqual([...list].sort(M.byOrder((x, y) => y.name.localeCompare(x.name, "ko"))).map((x) => x.id), ["c", "b", "d", "a"]);
});

test("cardsInDeck and filterSort manual respect order", () => {
  const list = [
    { id: "1", name: "가", sp: 1, category: "attack", deckId: "d", order: 1 },
    { id: "2", name: "나", sp: 1, category: "attack", deckId: "d", order: 0 },
    { id: "3", name: "다", sp: 1, category: "attack", deckId: "d" },
  ];
  assert.deepEqual(M.cardsInDeck(list, "d").map((c) => c.id), ["2", "1", "3"]);
  assert.deepEqual(M.filterSort(list, { sort: "manual" }).map((c) => c.id), ["2", "1", "3"]);
  assert.deepEqual(M.filterSort(list, { sort: "name" }).map((c) => c.id), ["1", "2", "3"]);
});

test("reorderWrites moves an item and returns only changed orders", () => {
  const list = [{ id: "a", order: 0 }, { id: "b", order: 1 }, { id: "c" }, { id: "d", order: 3 }];
  assert.deepEqual(M.reorderWrites(list, 0, 2), [{ id: "b", order: 0 }, { id: "c", order: 1 }, { id: "a", order: 2 }]);
  assert.deepEqual(M.reorderWrites(list, 3, 0), [{ id: "d", order: 0 }, { id: "a", order: 1 }, { id: "b", order: 2 }, { id: "c", order: 3 }]);
  assert.deepEqual(M.reorderWrites(list, 1, 1), []);
});
