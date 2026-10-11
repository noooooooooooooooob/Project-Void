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
    return /^\d+$/.test(String(sp).trim());
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
      deckId: typeof r.deckId === "string" && r.deckId ? r.deckId : null,
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

  const byName = (a, b) => a.name.localeCompare(b.name, "ko");

  function filterSort(cards, { category = "all", query = "", sort = "name" } = {}) {
    const q = query.trim().toLowerCase();
    const list = cards.filter((c) =>
      (category === "all" || c.category === category) && (!q || c.name.toLowerCase().includes(q)));
    return list.sort(sort === "sp" ? (a, b) => a.sp - b.sp || byName(a, b) : byName);
  }

  function normalizeDeck(raw) {
    return { name: String(raw?.name ?? "").trim() || "이름 없는 덱" };
  }

  // deckId 가 null 이면 공용 카드.
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

  function isAssetShared(cards, assetId, exceptCardId) {
    return cards.some((c) => c.id !== exceptCardId && c.illustration === assetId);
  }

  // db 는 권한 거절과 256KiB 초과 문서를 같은 invalid_argument 로 돌려준다.
  // 쓰기 권한이 확인된(true) 사람이면 크기 문제로 본다.
  function writeErrorKind(err, writeAllowed) {
    const code = err?.code;
    if (code === "invalid_argument") return writeAllowed === true ? "too_large" : "readonly";
    if (code === "quota_exceeded") return "quota";
    return "retry";
  }

  const api = {
    CATEGORIES, CATEGORY_LABELS, ATTACK_TYPES, ATTACK_LABELS, ATTACK_BADGES, AREA_RADIUS,
    normalizeCard, validateCard, normalizeArea, toggleCell, areaOrDefault,
    filterSort, normalizeDeck, cardsInDeck, spHistogram, migrationWrites, isAssetShared,
    writeErrorKind,
  };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.CardModel = api;
})(typeof window !== "undefined" ? window : globalThis);
