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
