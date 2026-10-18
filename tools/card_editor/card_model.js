// 카드 에디터의 순수 로직. 브라우저에서는 window.CardModel, Node 테스트에서는 module.exports.
(function (root) {
  const CATEGORIES = ["attack", "skill", "special"];
  const CATEGORY_LABELS = { attack: "공격", skill: "스킬", special: "특수" };
  const ATTACK_TYPES = ["melee", "ranged", "ally", "self"];
  const ATTACK_LABELS = { melee: "근접", ranged: "원거리", ally: "아군", self: "자신" };
  const ATTACK_BADGES = { melee: "근", ranged: "원", ally: "아", self: "자" };
  // 5×5 격자: -2..2. 게임 CardData.area 와 같은 좌표.
  const AREA_RADIUS = 2;
  const MAX_UPGRADES = 5;

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

  // 카드 앞면 항목. 강화 버전도 같은 항목을 따로 가진다.
  function normalizeFace(raw) {
    const r = raw || {};
    return {
      name: String(r.name ?? "").trim(),
      nameEn: String(r.nameEn ?? "").trim(),
      sp: isSpValid(r.sp) ? Number(String(r.sp).trim()) : 0,
      cost: isSpValid(r.cost) ? Number(String(r.cost).trim()) : 0,
      category: CATEGORIES.includes(r.category) ? r.category : "attack",
      attackType: ATTACK_TYPES.includes(r.attackType) ? r.attackType : "melee",
      area: normalizeArea(r.area),
      illustration: typeof r.illustration === "string" && r.illustration ? r.illustration : null,
      description: String(r.description ?? ""),
      descriptionEn: String(r.descriptionEn ?? ""),
      keywords: normalizeKeywordIds(r.keywords),
    };
  }

  // 카드에는 키워드 id 만 저장한다. 이름·설명은 keywords 컬렉션에서 찾는다.
  function normalizeKeywordIds(raw) {
    if (!Array.isArray(raw)) return [];
    return [...new Set(raw.filter((k) => typeof k === "string" && k))];
  }

  function normalizeKeyword(raw) {
    return {
      name: String(raw?.name ?? "").trim(), nameEn: String(raw?.nameEn ?? "").trim(),
      description: String(raw?.description ?? ""), descriptionEn: String(raw?.descriptionEn ?? ""),
    };
  }

  function validateKeyword(raw) {
    return String(raw?.name ?? "").trim() ? [] : ["이름을 입력하세요"];
  }

  // 지워진 키워드 id 는 건너뛴다.
  function faceKeywords(face, keywords) {
    const byId = new Map(keywords.map((k) => [k.id, k]));
    return (face.keywords || []).map((id) => byId.get(id)).filter(Boolean);
  }

  function keywordUsage(cards, keywordId) {
    return cards.filter((c) => [c, ...(c.upgrades || [])].some((f) => (f.keywords || []).includes(keywordId))).length;
  }

  function normalizeCard(raw) {
    const r = raw || {};
    return {
      ...normalizeFace(r),
      deckId: typeof r.deckId === "string" && r.deckId ? r.deckId : null,
      upgrades: rawUpgrades(r).filter((u) => u && typeof u === "object").slice(0, MAX_UPGRADES).map(normalizeFace),
    };
  }

  // 예전 문서는 강화 버전 하나를 upgrade 로 저장했다.
  function rawUpgrades(r) {
    if (Array.isArray(r.upgrades)) return r.upgrades;
    return r.upgrade ? [r.upgrade] : [];
  }

  // 다음 강화 단계: 바로 앞 단계를 복사하되 이름(한·영)은 사용자가 직접 채우도록 비워 둔다.
  function newUpgrade(card) {
    const ups = card.upgrades || [];
    const prev = normalizeFace(ups.length ? ups[ups.length - 1] : card);
    return { ...prev, name: "", nameEn: "" };
  }

  function faceErrors(raw) {
    const errors = [];
    if (!String(raw?.name ?? "").trim()) errors.push("이름을 입력하세요");
    if (!isSpValid(raw?.sp)) errors.push("SP는 0 이상의 정수예요");
    // 코스트가 없는 예전 카드는 0 으로 읽으므로 통과시킨다.
    if (raw?.cost != null && !isSpValid(raw.cost)) errors.push("코스트는 0 이상의 정수예요");
    return errors;
  }

  function validateCard(raw) {
    const errors = faceErrors(raw);
    (raw?.upgrades || []).forEach((u, i) => errors.push(...faceErrors(u).map((m) => `강화 ${i + 1}: ${m}`)));
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

  // 직접 정한 순서(order)가 있는 것이 앞, 없는 것은 fallback 순으로 뒤에 붙는다.
  function byOrder(fallback) {
    return (a, b) => {
      const ao = typeof a.order === "number", bo = typeof b.order === "number";
      if (ao && bo) return a.order - b.order || fallback(a, b);
      if (ao !== bo) return ao ? -1 : 1;
      return fallback(a, b);
    };
  }

  // 화면 순서대로 놓인 list 에서 from → to 로 옮긴 뒤, order 가 달라진 것만 돌려준다.
  function reorderWrites(list, from, to) {
    if (from === to) return [];
    const next = [...list];
    next.splice(to, 0, ...next.splice(from, 1));
    return next.map((item, i) => ({ id: item.id, order: i, prev: item.order }))
      .filter((w) => w.prev !== w.order)
      .map(({ id, order }) => ({ id, order }));
  }

  function filterSort(cards, { category = "all", query = "", sort = "name" } = {}) {
    const q = query.trim().toLowerCase();
    const list = cards.filter((c) =>
      (category === "all" || c.category === category) && (!q || c.name.toLowerCase().includes(q)));
    return list.sort(sort === "sp" ? (a, b) => a.sp - b.sp || byName(a, b) : sort === "manual" ? byOrder(byName) : byName);
  }

  function normalizeDeck(raw) {
    return { name: String(raw?.name ?? "").trim() || "이름 없는 덱", nameEn: String(raw?.nameEn ?? "").trim() };
  }

  // deckId 가 null 이면 공용 카드.
  function cardsInDeck(cards, deckId) {
    return cards.filter((c) => (c.deckId ?? null) === (deckId ?? null)).sort(byOrder(byName));
  }

  // 덱 코스트 평균 (기본 카드 기준, 소수 한 자리). 카드가 없으면 null.
  function averageCost(cards) {
    if (!cards.length) return null;
    return Math.round((cards.reduce((s, c) => s + (c.cost || 0), 0) / cards.length) * 10) / 10;
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
        data: { ...normalizeDeck(deck.data), createdAt: deck.data.createdAt ?? 0 } });
    }
    return writes;
  }

  // 카드 한 장이 쓰는 일러스트 (기본 + 강화, 중복 없이).
  function cardAssets(card) {
    return [...new Set([card.illustration, ...(card.upgrades || []).map((u) => u.illustration)].filter(Boolean))];
  }

  function isAssetShared(cards, assetId, exceptCardId) {
    return cards.some((c) => c.id !== exceptCardId && cardAssets(c).includes(assetId));
  }

  // 덱을 지울 때 함께 지워도 되는 일러스트: 그 덱 밖의 어떤 카드도 쓰지 않는 것만.
  function assetsFreedByDeckDelete(cards, deckId) {
    const used = new Set(cards.filter((c) => c.deckId !== deckId).flatMap(cardAssets));
    const freed = new Set();
    for (const c of cards) {
      if (c.deckId !== deckId) continue;
      for (const a of cardAssets(c)) if (!used.has(a)) freed.add(a);
    }
    return [...freed];
  }

  function formatBytes(n) {
    const MB = 1024 * 1024;
    if (n >= 1024 * MB) return Math.round((n / (1024 * MB)) * 10) / 10 + "GB";
    return Math.round((n / MB) * 10) / 10 + "MB";
  }

  // assets.list() 의 usage → 상단 표시 문구. 용량이나 파일 수가 80% 이상이면 경고.
  function formatUsage({ bytes, maxBytes, files, maxFiles }) {
    const warn = (maxBytes > 0 && bytes / maxBytes >= 0.8) || (maxFiles > 0 && files / maxFiles >= 0.8);
    return { text: `그림 저장 공간 ${formatBytes(bytes)} / ${formatBytes(maxBytes)} · 파일 ${files} / ${maxFiles}개`, warn };
  }

  // db 는 권한 거절과 256KiB 초과 문서를 같은 invalid_argument 로 돌려준다.
  // 쓰기 권한이 확인된(true) 사람이면 크기 문제로 본다.
  function writeErrorKind(err, writeAllowed) {
    const code = err?.code;
    if (code === "invalid_argument") return writeAllowed === true ? "too_large" : "readonly";
    if (code === "quota_exceeded") return "quota";
    return "retry";
  }

  // 게임용 export 는 면 하나를 { name, description } 두 언어 객체로 바꾸고, 그림은 artPath 로 경로를 받는다.
  function exportFace(face, keywords, artPath) {
    return {
      name: { ko: face.name, en: face.nameEn },
      description: { ko: face.description, en: face.descriptionEn },
      sp: face.sp, cost: face.cost, category: face.category, attackType: face.attackType,
      area: face.area,
      keywords: faceKeywords(face, keywords).map((k) => k.id),
      art: face.illustration ? (artPath(face.illustration) ?? null) : null,
    };
  }

  // 공용 카드 → 덱 순서(화면 탭 순서, 호출자가 정렬해 넘김). 지워진 덱의 카드는 빠진다.
  function exportCards(cards, decks) {
    return [...cardsInDeck(cards, null), ...decks.flatMap((d) => cardsInDeck(cards, d.id))];
  }

  function exportAssets(cards, decks) {
    return [...new Set(exportCards(cards, decks).flatMap(cardAssets))];
  }

  function buildExport({ cards, decks, keywords }, artPath) {
    const faceOut = (f) => exportFace(f, keywords, artPath);
    return {
      keywords: keywords.map((k) => ({ id: k.id, name: { ko: k.name, en: k.nameEn }, description: { ko: k.description, en: k.descriptionEn } })),
      decks: decks.map((d) => ({ id: d.id, name: { ko: d.name, en: d.nameEn } })),
      cards: exportCards(cards, decks).map((c) => ({
        id: c.id, deck: c.deckId ?? null, ...faceOut(c), upgrades: (c.upgrades || []).map(faceOut),
      })),
    };
  }

  const CRC_TABLE = (() => {
    const t = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      t[n] = c >>> 0;
    }
    return t;
  })();

  function crc32(bytes) {
    let c = 0xffffffff;
    for (let i = 0; i < bytes.length; i++) c = CRC_TABLE[(c ^ bytes[i]) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  }

  // 압축 없는 zip(store). 파일 이름은 UTF-8(flag 0x0800).
  function makeZip(entries) {
    const enc = new TextEncoder();
    const files = entries.map((e) => ({ name: enc.encode(e.name), bytes: e.bytes, crc: crc32(e.bytes) }));
    const cdSize = files.reduce((n, f) => n + 46 + f.name.length, 0);
    const total = files.reduce((n, f) => n + 30 + f.name.length + f.bytes.length, 0) + cdSize + 22;
    const out = new Uint8Array(total);
    const v = new DataView(out.buffer);
    let p = 0;
    const offsets = [];
    for (const f of files) {
      offsets.push(p);
      v.setUint32(p, 0x04034b50, true);
      v.setUint16(p + 4, 20, true);
      v.setUint16(p + 6, 0x0800, true);
      v.setUint16(p + 12, 0x0021, true); // 1980-01-01
      v.setUint32(p + 14, f.crc, true);
      v.setUint32(p + 18, f.bytes.length, true);
      v.setUint32(p + 22, f.bytes.length, true);
      v.setUint16(p + 26, f.name.length, true);
      out.set(f.name, p + 30);
      out.set(f.bytes, p + 30 + f.name.length);
      p += 30 + f.name.length + f.bytes.length;
    }
    const cdAt = p;
    files.forEach((f, i) => {
      v.setUint32(p, 0x02014b50, true);
      v.setUint16(p + 4, 20, true);
      v.setUint16(p + 6, 20, true);
      v.setUint16(p + 8, 0x0800, true);
      v.setUint16(p + 14, 0x0021, true);
      v.setUint32(p + 16, f.crc, true);
      v.setUint32(p + 20, f.bytes.length, true);
      v.setUint32(p + 24, f.bytes.length, true);
      v.setUint16(p + 28, f.name.length, true);
      v.setUint32(p + 42, offsets[i], true);
      out.set(f.name, p + 46);
      p += 46 + f.name.length;
    });
    v.setUint32(p, 0x06054b50, true);
    v.setUint16(p + 8, files.length, true);
    v.setUint16(p + 10, files.length, true);
    v.setUint32(p + 12, cdSize, true);
    v.setUint32(p + 16, cdAt, true);
    return out;
  }

  const api = {
    CATEGORIES, CATEGORY_LABELS, ATTACK_TYPES, ATTACK_LABELS, ATTACK_BADGES, AREA_RADIUS, MAX_UPGRADES,
    normalizeCard, newUpgrade, validateCard, cardAssets, normalizeArea, toggleCell, areaOrDefault,
    filterSort, normalizeDeck, cardsInDeck, spHistogram, averageCost, migrationWrites, isAssetShared, assetsFreedByDeckDelete, formatUsage,
    writeErrorKind, byOrder, reorderWrites, normalizeKeyword, validateKeyword, faceKeywords, keywordUsage,
    exportCards, exportAssets, buildExport, makeZip,
  };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.CardModel = api;
})(typeof window !== "undefined" ? window : globalThis);
