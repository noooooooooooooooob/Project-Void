## 방 텍스처(바닥·벽·타일), 소품, 대화 배경(픽셀), 캐릭터 일러스트(매끈한 그림), 아이템 아이콘을 그리는 함수 모음.
class_name ScenePainter
extends RefCounted

## 방 테마별 색.
const THEMES: Dictionary = {
	"factory": {"floor": Color(0.22, 0.21, 0.22), "mortar": Color(0.13, 0.12, 0.14), "wall": Color(0.27, 0.26, 0.28), "accent": Color(0.45, 0.28, 0.18)},
	"sewer": {"floor": Color(0.2, 0.24, 0.23), "mortar": Color(0.1, 0.13, 0.12), "wall": Color(0.3, 0.22, 0.19), "accent": Color(0.2, 0.32, 0.3)},
	"core": {"floor": Color(0.15, 0.15, 0.2), "mortar": Color(0.07, 0.07, 0.11), "wall": Color(0.18, 0.15, 0.2), "accent": Color(0.25, 0.75, 0.72)},
	"twilight": {"floor": Color(0.24, 0.16, 0.3), "mortar": Color(0.12, 0.07, 0.16), "wall": Color(0.35, 0.18, 0.35), "accent": Color(0.95, 0.55, 0.35)},
}


# ---------------- 방 ----------------

static func floor_texture(theme: String, seed_value: int) -> PixelCanvas:
	var t: Dictionary = THEMES[theme]
	var c := PixelCanvas.new(64, 64, t["floor"])
	c.speckle(0, 0, 64, 64, (t["floor"] as Color).lightened(0.12), 0.08, seed_value)
	c.speckle(0, 0, 64, 64, (t["floor"] as Color).darkened(0.18), 0.1, seed_value + 1)
	# 돌판 줄눈.
	for i in 4:
		c.hline(0, 63, i * 16, t["mortar"])
		var off: int = 8 if i % 2 == 1 else 0
		for k in 4:
			c.vline((k * 16 + off) % 64, i * 16, i * 16 + 15, t["mortar"])
	# 갈라진 틈.
	c.line(5, 40, 14, 47, t["mortar"])
	c.line(14, 47, 18, 46, t["mortar"])
	# 공허 오염: 검은 기름 줄기 + 무지갯빛.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for v in 2:
		var x: int = rng.randi_range(0, 63)
		var y: int = rng.randi_range(0, 63)
		for s in 24:
			c.px(x % 64, y % 64, SpritePainter.VOID_BLACK)
			if s % 6 == 0:
				c.px((x + 1) % 64, y % 64, SpritePainter.OIL_SHEEN)
			x += rng.randi_range(0, 2) - (0 if v == 0 else 1)
			y += rng.randi_range(-1, 1)
	if theme == "sewer":
		c.ellipse(44, 22, 8, 3, Color(0.1, 0.16, 0.18))
		c.hline(40, 46, 21, Color(0.35, 0.5, 0.52))
	if theme == "core":
		c.circle(30, 30, 2, SpritePainter.VOID_TEAL.darkened(0.3))
	return c


static func wall_texture(theme: String, seed_value: int) -> PixelCanvas:
	var t: Dictionary = THEMES[theme]
	var c := PixelCanvas.new(64, 64, t["wall"])
	match theme:
		"factory":
			for k in 4:
				c.vline(k * 16, 0, 63, (t["wall"] as Color).darkened(0.35))
				c.vline(k * 16 + 1, 0, 63, (t["wall"] as Color).lightened(0.1))
				for r in [4, 30, 58]:
					c.px(k * 16 + 4, r, (t["wall"] as Color).lightened(0.3))
					c.px(k * 16 + 12, r, (t["wall"] as Color).lightened(0.3))
			c.speckle(0, 20, 64, 30, t["accent"], 0.06, seed_value)
			# 어두운 창.
			c.rect(20, 10, 10, 8, Color(0.08, 0.08, 0.1))
			c.hline(20, 29, 14, (t["wall"] as Color).darkened(0.2))
		"sewer", "core":
			for row in 16:
				var off: int = 4 if row % 2 == 1 else 0
				c.hline(0, 63, row * 4, t["mortar"])
				for k in 8:
					c.px((k * 8 + off) % 64, row * 4 + 1, t["mortar"])
					c.px((k * 8 + off) % 64, row * 4 + 2, t["mortar"])
					c.px((k * 8 + off) % 64, row * 4 + 3, t["mortar"])
			c.speckle(0, 0, 64, 64, (t["wall"] as Color).lightened(0.15), 0.05, seed_value)
			# 가로 배관.
			c.rect(0, 40, 64, 5, Color(0.32, 0.34, 0.33))
			c.hline(0, 63, 40, Color(0.5, 0.52, 0.5))
			c.hline(0, 63, 44, Color(0.18, 0.19, 0.19))
			c.rect(30, 39, 3, 7, Color(0.28, 0.2, 0.16))
			if theme == "core":
				for v in 3:
					c.line(10 + v * 20, 0, 6 + v * 20, 63, SpritePainter.VOID_BLACK, 2)
					c.px(8 + v * 20, 30, SpritePainter.VOID_TEAL)
		"twilight":
			c.vgradient(0, 0, 64, 64, Color(0.3, 0.12, 0.38), Color(0.8, 0.45, 0.35))
			# 뒤틀린 건물 실루엣.
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var x: int = 0
			while x < 64:
				var w: int = rng.randi_range(5, 10)
				var h: int = rng.randi_range(18, 40)
				c.rect(x, 64 - h, w, h, Color(0.12, 0.06, 0.16))
				x += w + rng.randi_range(0, 2)
			c.speckle(0, 0, 64, 20, Color(1, 0.9, 0.95, 0.6), 0.02, seed_value)
	return c


static func tile_texture(theme: String, enemy: bool) -> PixelCanvas:
	var t: Dictionary = THEMES[theme]
	var base: Color = (t["floor"] as Color).lightened(0.08)
	var c := PixelCanvas.new(32, 32, base)
	c.speckle(0, 0, 32, 32, base.darkened(0.15), 0.12, 7 if enemy else 3)
	var rim: Color = Color(0.85, 0.3, 0.3) if enemy else Color(0.35, 0.55, 0.95)
	c.rect(0, 0, 32, 1, rim)
	c.rect(0, 31, 32, 1, rim.darkened(0.3))
	c.rect(0, 0, 1, 32, rim)
	c.rect(31, 0, 1, 32, rim.darkened(0.3))
	c.rect(2, 2, 28, 1, base.lightened(0.15))
	return c


# ---------------- 소품 (빌보드) ----------------

static func prop(kind: String) -> PixelCanvas:
	var c: PixelCanvas
	match kind:
		"barrel":
			c = PixelCanvas.new(20, 26)
			c.rect(3, 3, 14, 22, Color(0.35, 0.18, 0.14))
			c.rect(3, 3, 3, 22, Color(0.25, 0.12, 0.1))
			for y in [6, 14, 22]:
				c.hline(3, 16, y, Color(0.5, 0.5, 0.48))
			c.ellipse(10, 3, 7, 2, Color(0.2, 0.1, 0.08))
			c.rect(12, 8, 3, 5, SpritePainter.VOID_BLACK)
		"crate":
			c = PixelCanvas.new(24, 22)
			c.rect(1, 2, 22, 19, Color(0.42, 0.3, 0.18))
			c.line(1, 2, 22, 20, Color(0.3, 0.2, 0.12), 2)
			c.line(22, 2, 1, 20, Color(0.3, 0.2, 0.12), 2)
			c.hline(1, 22, 2, Color(0.55, 0.4, 0.25))
		"valve":
			c = PixelCanvas.new(16, 40)
			c.rect(5, 0, 6, 40, Color(0.34, 0.36, 0.35))
			c.rect(5, 0, 2, 40, Color(0.22, 0.24, 0.23))
			c.circle(8, 16, 5, Color(0.55, 0.15, 0.12))
			c.circle(8, 16, 3, Color(0, 0, 0, 0))
			c.rect(7, 15, 2, 2, Color(0.34, 0.36, 0.35))
			c.rect(4, 30, 8, 3, Color(0.25, 0.27, 0.26))
		"crystal":
			c = PixelCanvas.new(22, 30)
			c.polygon(PackedVector2Array([Vector2(11, 0), Vector2(17, 12), Vector2(14, 30), Vector2(7, 30), Vector2(5, 12)]), SpritePainter.VOID_TEAL.darkened(0.2))
			c.polygon(PackedVector2Array([Vector2(11, 0), Vector2(14, 12), Vector2(11, 30), Vector2(7, 30), Vector2(5, 12)]), SpritePainter.VOID_TEAL)
			c.line(10, 4, 8, 16, Color(0.8, 1.0, 1.0))
			c.polygon(PackedVector2Array([Vector2(17, 14), Vector2(21, 22), Vector2(18, 30), Vector2(14, 30)]), SpritePainter.VOID_PURPLE)
		"lamp":
			c = PixelCanvas.new(14, 44)
			c.rect(6, 6, 2, 38, Color(0.2, 0.2, 0.22))
			c.rect(3, 2, 8, 5, Color(0.25, 0.25, 0.27))
			c.rect(4, 7, 6, 3, Color(1.0, 0.85, 0.5))
			c.rect(3, 41, 8, 3, Color(0.2, 0.2, 0.22))
		"growth":
			c = PixelCanvas.new(26, 34)
			for i in 4:
				var x0: int = 4 + i * 6
				c.line(x0, 33, x0 + (i % 2) * 4 - 2, 8 + i * 3, SpritePainter.VOID_BLACK, 3)
				c.circle(x0 + (i % 2) * 4 - 2, 8 + i * 3, 2, SpritePainter.VOID_BLACK)
				c.px(x0 + (i % 2) * 4 - 2, 7 + i * 3, SpritePainter.VOID_PURPLE)
			c.ellipse(13, 32, 12, 2, SpritePainter.VOID_BLACK)
		"rubble":
			c = PixelCanvas.new(28, 14)
			c.polygon(PackedVector2Array([Vector2(0, 14), Vector2(5, 5), Vector2(12, 7), Vector2(17, 2), Vector2(24, 6), Vector2(28, 14)]), Color(0.32, 0.3, 0.3))
			c.speckle(0, 4, 28, 10, Color(0.2, 0.19, 0.2), 0.3, 11)
		_:
			c = PixelCanvas.new(8, 8, Color.MAGENTA)
	c.outline(SpritePainter.OUTLINE)
	return c


# ---------------- 대화 배경 (320×180 픽셀) ----------------

static func background(kind: String) -> PixelCanvas:
	var c := PixelCanvas.new(320, 180)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	match kind:
		"title":
			c.vgradient(0, 0, 320, 180, Color(0.04, 0.03, 0.08), Color(0.18, 0.1, 0.2))
			c.speckle(0, 0, 320, 90, Color(0.9, 0.9, 1.0, 0.7), 0.004, 1)
			# 하늘의 균열.
			c.ellipse(220, 55, 14, 40, Color(0.25, 0.12, 0.4, 0.5))
			c.polygon(PackedVector2Array([Vector2(220, 15), Vector2(228, 55), Vector2(220, 95), Vector2(212, 55)]), SpritePainter.VOID_BLACK)
			c.line(220, 15, 228, 55, SpritePainter.VOID_PURPLE)
			c.line(228, 55, 220, 95, SpritePainter.VOID_TEAL)
			c.line(220, 15, 212, 55, SpritePainter.VOID_TEAL)
			c.line(212, 55, 220, 95, SpritePainter.VOID_PURPLE)
			_skyline(c, rng, 180, Color(0.05, 0.04, 0.07), 0, 320, true)
		"academy":
			c.vgradient(0, 0, 320, 180, Color(0.32, 0.26, 0.22), Color(0.18, 0.14, 0.12))
			for i in 4:
				var x: int = 30 + i * 75
				c.rect(x, 20, 34, 80, Color(0.55, 0.62, 0.7))
				c.rect(x + 16, 20, 2, 80, Color(0.3, 0.26, 0.22))
				c.polygon(PackedVector2Array([Vector2(x, 100), Vector2(x + 34, 100), Vector2(x + 50, 180), Vector2(x - 10, 180)]), Color(1.0, 0.95, 0.8, 0.12))
			c.rect(0, 130, 320, 50, Color(0.28, 0.2, 0.16))
			for i in 3:
				c.rect(60 + i * 90, 8, 14, 28, Color(0.45, 0.12, 0.14))
		"office":
			c.vgradient(0, 0, 320, 180, Color(0.24, 0.17, 0.14), Color(0.16, 0.11, 0.09))
			c.rect(0, 135, 320, 45, Color(0.3, 0.2, 0.13))
			for i in 8:
				c.vline(i * 40, 135, 179, Color(0.22, 0.14, 0.09))
			# 창 너머의 도시.
			c.rect(190, 25, 90, 70, Color(0.12, 0.1, 0.18))
			_skyline(c, rng, 95, Color(0.06, 0.05, 0.09), 190, 280, false)
			c.rect(188, 23, 94, 2, Color(0.35, 0.25, 0.18))
			c.rect(188, 95, 94, 3, Color(0.35, 0.25, 0.18))
			c.rect(234, 25, 2, 70, Color(0.35, 0.25, 0.18))
			# 책장.
			c.rect(20, 30, 60, 105, Color(0.28, 0.18, 0.12))
			for shelf in 4:
				c.hline(20, 79, 55 + shelf * 25, Color(0.18, 0.11, 0.07))
				for b in 10:
					c.rect(23 + b * 5, 38 + shelf * 25, 4, 16, Color.from_hsv(rng.randf(), 0.4, 0.4))
			# 책상과 등.
			c.rect(100, 110, 110, 10, Color(0.36, 0.24, 0.15))
			c.rect(105, 120, 8, 25, Color(0.3, 0.2, 0.12))
			c.rect(197, 120, 8, 25, Color(0.3, 0.2, 0.12))
			c.circle(120, 100, 9, Color(1.0, 0.85, 0.5, 0.25))
			c.rect(117, 100, 6, 10, Color(0.6, 0.5, 0.3))
			c.rect(140, 105, 30, 5, Color(0.85, 0.82, 0.75))
		"sewer_gate":
			c.vgradient(0, 0, 320, 180, Color(0.1, 0.12, 0.12), Color(0.05, 0.06, 0.06))
			for row in 30:
				var off: int = 6 if row % 2 == 1 else 0
				c.hline(0, 319, row * 6, Color(0.14, 0.12, 0.11))
				for k in 28:
					c.vline(k * 12 + off, row * 6, row * 6 + 5, Color(0.14, 0.12, 0.11))
			c.ellipse(160, 110, 80, 90, Color(0.02, 0.02, 0.03))
			c.rect(80, 110, 160, 70, Color(0.02, 0.02, 0.03))
			c.rect(0, 150, 320, 30, Color(0.1, 0.14, 0.15))
			c.hline(0, 319, 150, Color(0.3, 0.4, 0.42))
			# 균열에서 새는 검은 기름.
			c.polygon(PackedVector2Array([Vector2(160, 60), Vector2(168, 100), Vector2(160, 150), Vector2(152, 100)]), SpritePainter.VOID_BLACK)
			c.line(160, 60, 168, 100, SpritePainter.VOID_PURPLE)
			c.line(152, 100, 160, 150, SpritePainter.VOID_TEAL)
			for i in 6:
				c.vline(120 + i * 15, 150, 152 + rng.randi_range(4, 20), SpritePainter.VOID_BLACK)
		"void":
			c.vgradient(0, 0, 320, 180, Color(0.02, 0.02, 0.04), Color(0.08, 0.05, 0.12))
			for i in 40:
				var x: int = rng.randi_range(0, 319)
				var y: int = rng.randi_range(0, 179)
				c.rect(x, y, rng.randi_range(2, 8), rng.randi_range(2, 5), Color(0.12, 0.1, 0.16))
			for v in 6:
				var x: int = rng.randi_range(0, 319)
				var y: int = 179
				for s in 60:
					c.px(x, y, SpritePainter.VOID_PURPLE if s % 3 else SpritePainter.VOID_TEAL)
					x += rng.randi_range(-2, 2)
					y -= rng.randi_range(1, 3)
		"twilight":
			c.vgradient(0, 0, 320, 180, Color(0.25, 0.08, 0.32), Color(0.95, 0.5, 0.3))
			c.circle(160, 70, 26, Color(0.05, 0.02, 0.06))
			c.circle(160, 70, 29, Color(1.0, 0.6, 0.4, 0.25))
			# 거꾸로 매달린 도시.
			var x: int = 0
			while x < 320:
				var w: int = rng.randi_range(8, 20)
				var h: int = rng.randi_range(15, 45)
				c.rect(x, 0, w, h, Color(0.1, 0.04, 0.12))
				x += w + rng.randi_range(0, 4)
			_skyline(c, rng, 180, Color(0.08, 0.03, 0.1), 0, 320, false)
		"alley_rain":
			c.vgradient(0, 0, 320, 180, Color(0.06, 0.07, 0.1), Color(0.1, 0.1, 0.13))
			c.polygon(PackedVector2Array([Vector2(0, 0), Vector2(110, 0), Vector2(130, 180), Vector2(0, 180)]), Color(0.12, 0.11, 0.13))
			c.polygon(PackedVector2Array([Vector2(210, 0), Vector2(320, 0), Vector2(320, 180), Vector2(190, 180)]), Color(0.13, 0.12, 0.14))
			c.rect(0, 160, 320, 20, Color(0.08, 0.08, 0.1))
			c.circle(250, 70, 22, Color(1.0, 0.8, 0.5, 0.15))
			c.rect(248, 60, 4, 100, Color(0.15, 0.15, 0.17))
			c.rect(244, 58, 12, 6, Color(1.0, 0.85, 0.55))
			for i in 220:
				var rx: int = rng.randi_range(0, 319)
				var ry: int = rng.randi_range(0, 175)
				c.line(rx, ry, rx - 1, ry + 4, Color(0.6, 0.65, 0.8, 0.35))
			# 웅덩이에 비친 핏빛.
			c.ellipse(150, 168, 30, 4, Color(0.4, 0.05, 0.08, 0.6))
		"core_room":
			c.vgradient(0, 0, 320, 180, Color(0.03, 0.03, 0.06), Color(0.08, 0.08, 0.12))
			c.circle(160, 85, 50, Color(0.25, 0.75, 0.72, 0.12))
			c.circle(160, 85, 30, Color(0.25, 0.75, 0.72, 0.2))
			c.circle(160, 85, 12, SpritePainter.VOID_TEAL)
			c.circle(160, 85, 6, Color(0.85, 1.0, 1.0))
			for r in 3:
				for a in 48:
					var ang: float = TAU * float(a) / 48.0
					c.px(160 + roundi(cos(ang) * (60 + r * 18)), 85 + roundi(sin(ang) * (60 + r * 18) * 0.5), SpritePainter.VOID_PURPLE if (a + r) % 3 == 0 else Color(0, 0, 0, 0))
			c.rect(0, 150, 320, 30, Color(0.06, 0.06, 0.09))
		_:
			c.vgradient(0, 0, 320, 180, Color.BLACK, Color(0.1, 0.1, 0.1))
	return c


static func _skyline(c: PixelCanvas, rng: RandomNumberGenerator, base_y: int, color: Color, x_from: int, x_to: int, chimneys: bool) -> void:
	var x: int = x_from
	while x < x_to:
		var w: int = rng.randi_range(10, 26)
		var h: int = rng.randi_range(18, 50)
		c.rect(x, base_y - h, mini(w, x_to - x), h, color)
		if chimneys and rng.randf() < 0.35:
			c.rect(x + w / 2, base_y - h - 12, 3, 12, color)
		for wy in range(base_y - h + 4, base_y - 4, 6):
			if rng.randf() < 0.2:
				c.rect(x + 3, wy, 2, 2, Color(1.0, 0.8, 0.45, 0.8))
		x += w + 1


# ---------------- 아이템 아이콘 (16×16) ----------------

static func icon(kind: String, color: Color) -> PixelCanvas:
	var c := PixelCanvas.new(16, 16)
	match kind:
		"weapon":
			c.line(3, 13, 12, 4, Color(0.8, 0.82, 0.88), 2)
			c.line(4, 9, 7, 12, color, 2)
		"armor":
			c.polygon(PackedVector2Array([Vector2(3, 3), Vector2(13, 3), Vector2(13, 9), Vector2(8, 14), Vector2(3, 9)]), color)
			c.vline(8, 4, 12, color.lightened(0.3))
		"accessory":
			c.circle(8, 9, 4.5, color)
			c.circle(8, 9, 2.0, Color(0, 0, 0, 0))
			c.rect(7, 2, 2, 3, Color(0.8, 0.7, 0.4))
		"card":
			c.rect(4, 2, 9, 12, Color(0.9, 0.88, 0.8))
			c.rect(5, 3, 7, 5, color)
		"gold":
			c.circle(8, 8, 5.5, Color(0.95, 0.78, 0.3))
			c.circle(8, 8, 3.5, Color(0.8, 0.6, 0.2))
		"heart":
			c.circle(6, 7, 3, color)
			c.circle(10, 7, 3, color)
			c.polygon(PackedVector2Array([Vector2(3, 8), Vector2(13, 8), Vector2(8, 14)]), color)
	c.outline(SpritePainter.OUTLINE)
	return c


# ---------------- 일러스트 (매끈한 그림, 360×504) ----------------

## spec 키: skin, hair, hair_style(short/long/fox/slick/bob/cap), outfit, outfit_dark, accent, eye, age(young/old), beard(bool), scar(bool), extra(armor/goggles/hat/none)
static func portrait(spec: Dictionary) -> Image:
	const S: int = 2
	var w: int = 360 * S
	var h: int = 504 * S
	var c := PixelCanvas.new(w, h)
	var skin: Color = spec["skin"]
	var hair: Color = spec["hair"]
	var outfit: Color = spec["outfit"]
	var outfit_dark: Color = spec.get("outfit_dark", outfit.darkened(0.35))
	var accent: Color = spec.get("accent", outfit.lightened(0.3))
	var eye: Color = spec.get("eye", Color(0.2, 0.15, 0.12))
	var style: String = spec.get("hair_style", "short")
	var small: bool = spec.get("small", false)
	var head_y: float = (230.0 if small else 200.0) * S
	var cx: float = 180.0 * S
	# 뒷머리.
	if style == "long" or style == "fox":
		c.polygon(PackedVector2Array([Vector2(cx - 95 * S, head_y - 40 * S), Vector2(cx + 95 * S, head_y - 40 * S), Vector2(cx + 115 * S, head_y + 230 * S), Vector2(cx - 120 * S, head_y + 240 * S)]), hair.darkened(0.15))
	# 어깨와 옷.
	var shoulder_y: float = head_y + 140 * S
	c.polygon(PackedVector2Array([Vector2(cx - 60 * S, shoulder_y - 20 * S), Vector2(cx + 60 * S, shoulder_y - 20 * S), Vector2(cx + 170 * S, shoulder_y + 60 * S), Vector2(cx + 180 * S, h), Vector2(cx - 180 * S, h), Vector2(cx - 170 * S, shoulder_y + 60 * S)]), outfit)
	c.polygon(PackedVector2Array([Vector2(cx - 60 * S, shoulder_y - 20 * S), Vector2(cx - 170 * S, shoulder_y + 60 * S), Vector2(cx - 180 * S, h), Vector2(cx - 110 * S, h), Vector2(cx - 40 * S, shoulder_y + 40 * S)]), outfit_dark)
	# 깃.
	c.polygon(PackedVector2Array([Vector2(cx - 45 * S, shoulder_y - 25 * S), Vector2(cx, shoulder_y + 70 * S), Vector2(cx + 45 * S, shoulder_y - 25 * S), Vector2(cx + 25 * S, shoulder_y - 25 * S), Vector2(cx, shoulder_y + 20 * S), Vector2(cx - 25 * S, shoulder_y - 25 * S)]), accent)
	match spec.get("extra", "none"):
		"armor":
			c.ellipse(cx - 130 * S, shoulder_y + 40 * S, 60 * S, 40 * S, Color(0.5, 0.52, 0.58))
			c.ellipse(cx + 130 * S, shoulder_y + 40 * S, 60 * S, 40 * S, Color(0.58, 0.6, 0.66))
		"ribbon":
			c.polygon(PackedVector2Array([Vector2(cx - 18 * S, shoulder_y + 10 * S), Vector2(cx - 50 * S, shoulder_y + 40 * S), Vector2(cx - 30 * S, shoulder_y + 50 * S), Vector2(cx, shoulder_y + 20 * S), Vector2(cx + 30 * S, shoulder_y + 50 * S), Vector2(cx + 50 * S, shoulder_y + 40 * S), Vector2(cx + 18 * S, shoulder_y + 10 * S)]), Color(0.75, 0.08, 0.15))
	# 목.
	c.rect(int(cx - 26 * S), int(head_y + 60 * S), 52 * S, 70 * S, skin.darkened(0.12))
	# 얼굴.
	c.ellipse(cx, head_y, 78 * S, 92 * S, skin)
	c.ellipse(cx - 40 * S, head_y + 30 * S, 34 * S, 50 * S, Color(skin.r * 0.9, skin.g * 0.85, skin.b * 0.85, 0.25))
	# 눈.
	var eye_y: float = head_y + 8 * S
	for side in [-1, 1]:
		var ex: float = cx + side * 30 * S
		c.ellipse(ex, eye_y, 17 * S, 11 * S, Color(0.97, 0.96, 0.94))
		c.ellipse(ex + 2 * S, eye_y, 9 * S, 10 * S, eye)
		c.ellipse(ex + 2 * S, eye_y, 4 * S, 5 * S, eye.darkened(0.6))
		c.circle(ex + 5 * S, eye_y - 4 * S, 2.5 * S, Color(1, 1, 1, 0.9))
		# 윗눈꺼풀.
		c.line(int(ex - 17 * S), int(eye_y - 8 * S), int(ex + 17 * S), int(eye_y - 10 * S), Color(0.12, 0.08, 0.08), 3 * S)
		if spec.get("sleepy", false):
			c.rect(int(ex - 18 * S), int(eye_y - 12 * S), 36 * S, 9 * S, skin)
			c.line(int(ex - 17 * S), int(eye_y - 3 * S), int(ex + 17 * S), int(eye_y - 4 * S), Color(0.12, 0.08, 0.08), 3 * S)
		# 눈썹.
		var brow_tilt: float = -4.0 if spec.get("stern", false) else 2.0
		c.line(int(ex - 18 * S), int(eye_y - 26 * S + side * brow_tilt * S), int(ex + 16 * S), int(eye_y - 28 * S - side * brow_tilt * S), hair.darkened(0.2), 4 * S)
	# 코와 입.
	c.line(int(cx + 4 * S), int(head_y + 25 * S), int(cx), int(head_y + 38 * S), skin.darkened(0.25), 2 * S)
	c.line(int(cx - 14 * S), int(head_y + 56 * S), int(cx + 14 * S), int(head_y + 55 * S), Color(0.5, 0.25, 0.25), 3 * S)
	if spec.get("beard", false):
		c.polygon(PackedVector2Array([Vector2(cx - 60 * S, head_y + 30 * S), Vector2(cx + 60 * S, head_y + 30 * S), Vector2(cx + 40 * S, head_y + 85 * S), Vector2(cx, head_y + 98 * S), Vector2(cx - 40 * S, head_y + 85 * S)]), Color(hair.r, hair.g, hair.b, 0.55))
		c.line(int(cx - 18 * S), int(head_y + 56 * S), int(cx + 18 * S), int(head_y + 55 * S), Color(0.35, 0.2, 0.2), 3 * S)
	if spec.get("scar", false):
		c.line(int(cx + 38 * S), int(head_y - 20 * S), int(cx + 55 * S), int(head_y + 30 * S), Color(0.65, 0.35, 0.35), 3 * S)
	# 앞머리.
	match style:
		"short", "fox", "long":
			c.polygon(PackedVector2Array([Vector2(cx - 88 * S, head_y + 10 * S), Vector2(cx - 82 * S, head_y - 70 * S), Vector2(cx - 20 * S, head_y - 105 * S), Vector2(cx + 60 * S, head_y - 95 * S), Vector2(cx + 90 * S, head_y - 30 * S), Vector2(cx + 85 * S, head_y + 5 * S), Vector2(cx + 60 * S, head_y - 40 * S), Vector2(cx + 20 * S, head_y - 25 * S), Vector2(cx - 10 * S, head_y - 45 * S), Vector2(cx - 40 * S, head_y - 20 * S), Vector2(cx - 65 * S, head_y - 35 * S)]), hair)
		"slick":
			c.polygon(PackedVector2Array([Vector2(cx - 82 * S, head_y - 10 * S), Vector2(cx - 70 * S, head_y - 80 * S), Vector2(cx, head_y - 102 * S), Vector2(cx + 75 * S, head_y - 80 * S), Vector2(cx + 84 * S, head_y - 15 * S), Vector2(cx + 60 * S, head_y - 60 * S), Vector2(cx - 60 * S, head_y - 62 * S)]), hair)
		"bob":
			c.polygon(PackedVector2Array([Vector2(cx - 95 * S, head_y + 60 * S), Vector2(cx - 90 * S, head_y - 70 * S), Vector2(cx, head_y - 105 * S), Vector2(cx + 90 * S, head_y - 70 * S), Vector2(cx + 95 * S, head_y + 60 * S), Vector2(cx + 70 * S, head_y + 55 * S), Vector2(cx + 65 * S, head_y - 40 * S), Vector2(cx - 65 * S, head_y - 40 * S), Vector2(cx - 70 * S, head_y + 55 * S)]), hair)
		"cap":
			c.ellipse(cx, head_y - 55 * S, 92 * S, 50 * S, hair)
			c.rect(int(cx - 30 * S), int(head_y - 45 * S), 130 * S, 14 * S, hair.darkened(0.3))
	if style == "fox":
		for side in [-1, 1]:
			var bx: float = cx + side * 45 * S
			c.polygon(PackedVector2Array([Vector2(bx - 28 * S, head_y - 80 * S), Vector2(bx + side * 8 * S, head_y - 160 * S), Vector2(bx + 28 * S, head_y - 85 * S)]), hair)
			c.polygon(PackedVector2Array([Vector2(bx - 14 * S, head_y - 88 * S), Vector2(bx + side * 6 * S, head_y - 140 * S), Vector2(bx + 14 * S, head_y - 90 * S)]), hair.lightened(0.25))
	if spec.get("extra", "none") == "goggles":
		c.rect(int(cx - 80 * S), int(head_y - 62 * S), 160 * S, 18 * S, Color(0.25, 0.2, 0.15))
		c.circle(cx - 30 * S, head_y - 53 * S, 16 * S, Color(0.4, 0.75, 0.85))
		c.circle(cx + 30 * S, head_y - 53 * S, 16 * S, Color(0.4, 0.75, 0.85))
	# 오른쪽 가장자리 빛.
	c.ellipse(cx + 70 * S, head_y - 10 * S, 8 * S, 60 * S, Color(1, 1, 1, 0.08))
	var out: Image = c.image
	out.resize(360, 504, Image.INTERPOLATE_LANCZOS)
	return out
