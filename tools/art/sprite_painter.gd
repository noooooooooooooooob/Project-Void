## 유닛 스프라이트(32×32 프레임)를 그리는 함수 모음. 아군·사람형은 humanoid(), 공허 괴물은 종류별 함수.
## 모두 오른쪽을 바라보게 그린다 (적은 화면이 좌우를 뒤집어 왼쪽을 보게 한다).
class_name SpritePainter
extends RefCounted

const OUTLINE := Color(0.05, 0.04, 0.07)
const VOID_BLACK := Color(0.06, 0.05, 0.09)
const VOID_PURPLE := Color(0.55, 0.32, 0.85)
const VOID_TEAL := Color(0.25, 0.75, 0.72)
const OIL_SHEEN := Color(0.32, 0.22, 0.5)

## 프레임 정보 키: bob(위아래 흔들림), lean(상체 앞뒤), arm(0 기본·1 준비·2 타격·3 피격), flash(타격 섬광).


## 사람형 하나를 그린다. spec 키:
## skin, hair, hair_style(short/long/fox/pony/helmet/bald), coat, coat_dark, pants, boots, accent, eye,
## weapon(sword/greatsword/claws/gun/staff/none), small(bool), closed_eyes(bool), hunch(int)
static func humanoid(c: PixelCanvas, spec: Dictionary, frame: Dictionary) -> void:
	var small: bool = spec.get("small", false)
	var o: int = 3 if small else 0
	var b: int = int(frame.get("bob", 0))
	var lean: int = int(frame.get("lean", 0)) + int(spec.get("hunch", 0))
	var arm: int = int(frame.get("arm", 0))
	var leg_top: int = 24 + (1 if small else 0)
	var skin: Color = spec["skin"]
	var hair: Color = spec["hair"]
	var coat: Color = spec["coat"]
	var coat_dark: Color = spec.get("coat_dark", coat.darkened(0.3))
	var pants: Color = spec.get("pants", Color(0.15, 0.15, 0.2))
	var boots: Color = spec.get("boots", Color(0.1, 0.08, 0.08))
	var accent: Color = spec.get("accent", coat.lightened(0.3))
	var eye: Color = spec.get("eye", Color(0.1, 0.1, 0.12))
	var top: int = 15 + o + b

	# 뒷팔.
	c.rect(11 + lean, top + 1, 2, 6, coat_dark)
	# 다리 (피격 땐 벌어진다).
	var spread: int = 1 if arm == 3 else 0
	c.rect(13 - spread, leg_top, 2, 30 - leg_top, pants)
	c.rect(17 + spread, leg_top, 2, 30 - leg_top, pants)
	c.rect(13 - spread, 29, 3, 2, boots)
	c.rect(17 + spread, 29, 3, 2, boots)
	# 몸통 (외투) + 그늘 + 밑단.
	c.rect(12 + lean, top, 8, leg_top - top + 1, coat)
	c.rect(12 + lean, top, 2, leg_top - top + 1, coat_dark)
	c.hline(11 + lean, 20 + lean, leg_top, coat)
	c.hline(11 + lean, 20 + lean, leg_top + 1, coat_dark)
	# 목 장식 (스카프·깃).
	c.hline(13 + lean, 19 + lean, top, accent)
	c.px(18 + lean, top + 1, accent)
	# 머리.
	var hx: float = 16.5 + lean
	var hy: float = 9.5 + o + b
	var style: String = spec.get("hair_style", "short")
	if style == "long" or style == "fox":
		c.rect(int(hx) - 5, int(hy) - 1, 4, 10 - (2 if small else 0), hair)
	if style == "pony":
		c.rect(int(hx) - 6, int(hy) - 1, 3, 5, hair)
	if style == "helmet":
		c.circle(hx, hy - 0.5, 5.2, spec.get("helmet", Color(0.45, 0.47, 0.52)))
	elif style != "bald":
		c.circle(hx, hy - 1.0, 5.0, hair)
	c.ellipse(hx + 1.6, hy + 1.0, 3.3, 3.4, skin)
	if style == "fox":
		# 여우를 흉내 낸 머리칼 두 갈래.
		c.polygon(PackedVector2Array([Vector2(hx - 4, hy - 3), Vector2(hx - 3, hy - 8), Vector2(hx - 0.5, hy - 4)]), hair)
		c.polygon(PackedVector2Array([Vector2(hx + 0.5, hy - 4), Vector2(hx + 2.5, hy - 8.5), Vector2(hx + 3.5, hy - 3)]), hair)
		c.px(int(hx) - 3, int(hy) - 6, hair.lightened(0.35))
		c.px(int(hx) + 2, int(hy) - 7, hair.lightened(0.35))
	if style == "helmet":
		c.hline(int(hx) - 1, int(hx) + 4, int(hy) - 1, spec.get("helmet", Color(0.45, 0.47, 0.52)).darkened(0.3))
	# 앞머리.
	if style != "bald" and style != "helmet":
		c.hline(int(hx), int(hx) + 3, int(hy) - 3, hair)
	# 눈.
	if spec.get("closed_eyes", false) or arm == 3:
		c.hline(int(hx) + 2, int(hx) + 3, int(hy) + 1, eye)
	else:
		c.px(int(hx) + 3, int(hy), eye)
		c.px(int(hx) + 3, int(hy) + 1, eye.darkened(0.4))

	# 앞팔 + 무기. 손 위치를 정한다.
	var shoulder := Vector2i(19 + lean, top + 1)
	var hand := Vector2i(20 + lean, top + 7)
	match arm:
		1:
			hand = Vector2i(16 + lean, top - 3)
		2:
			hand = Vector2i(26 + lean, top + 2)
		3:
			hand = Vector2i(22 + lean, top - 2)
	c.line(shoulder.x, shoulder.y, hand.x, hand.y, coat, 2)
	c.px(hand.x, hand.y, skin)
	c.px(hand.x + 1, hand.y, skin)
	_weapon(c, spec.get("weapon", "none"), hand, arm, bool(frame.get("flash", false)), spec)
	c.outline(OUTLINE)


static func _weapon(c: PixelCanvas, kind: String, hand: Vector2i, arm: int, flash: bool, spec: Dictionary) -> void:
	var steel := Color(0.78, 0.8, 0.86)
	var steel_dark := Color(0.45, 0.47, 0.55)
	match kind:
		"sword", "greatsword":
			var thick: int = 2 if kind == "greatsword" else 1
			var length: int = 10 if kind == "greatsword" else 8
			var tip: Vector2i
			match arm:
				1:
					tip = hand + Vector2i(-6, -length + 3)
				2:
					tip = hand + Vector2i(length, 0)
				_:
					tip = hand + Vector2i(length - 3, -length + 2)
			c.line(hand.x, hand.y, tip.x, tip.y, steel, thick)
			c.px(hand.x, hand.y + 1, steel_dark)
			if flash:
				c.line(hand.x + 2, hand.y - 4, tip.x + 1, tip.y + 2, Color(1, 1, 1, 0.8))
		"claws":
			var red := Color(0.85, 0.12, 0.18)
			if arm == 2:
				for i in 3:
					c.line(hand.x - 1, hand.y - 3 + i * 2, hand.x + 4, hand.y - 5 + i * 3, red)
				if flash:
					# 피의 할퀴기 궤적.
					for i in 3:
						c.line(hand.x + 2 + i, hand.y - 7, hand.x + 4 + i, hand.y + 5, Color(1.0, 0.25, 0.3, 0.85))
			else:
				for i in 3:
					c.px(hand.x + 2, hand.y - 1 + i, red)
		"gun":
			var body := Color(0.25, 0.22, 0.2)
			if arm == 2:
				c.rect(hand.x, hand.y - 1, 6, 2, body)
				if flash:
					c.circle(hand.x + 7.5, hand.y, 1.8, Color(1.0, 0.85, 0.4))
			else:
				c.rect(hand.x - 1, hand.y, 2, 5, body)
		"staff":
			var wood := Color(0.42, 0.3, 0.2)
			var top_end := hand + (Vector2i(6, -2) if arm == 2 else Vector2i(1, -12))
			c.line(hand.x, hand.y + 4, top_end.x, top_end.y, wood)
			c.circle(top_end.x + 0.5, top_end.y + 0.5, 1.6, spec.get("accent", VOID_TEAL))
			if flash:
				c.circle(top_end.x + 3.5, top_end.y + 0.5, 2.5, Color(0.6, 0.9, 1.0, 0.8))
		_:
			pass


# ---------------- 공허 괴물 ----------------

## 괴물 한 프레임. mode: "idle"(phase 0~3), "attack"(phase 0~2), "hit"(phase 0~1).
static func monster(c: PixelCanvas, kind: String, mode: String, phase: int) -> void:
	var ox: int = 0
	var oy: int = 0
	if mode == "idle":
		oy = 1 if phase >= 2 else 0
	elif mode == "attack":
		ox = [-2, 4, 1][phase]
	elif mode == "hit":
		ox = [-3, -1][phase]
	match kind:
		"rat":
			_rat(c, ox, oy, mode, phase)
		"hound":
			_hound(c, ox, oy, mode, phase)
		"leech":
			_leech(c, ox, oy, mode, phase)
		"brute":
			_brute(c, ox, oy, mode, phase)
		"crown":
			_crown(c, ox, oy, mode, phase)
		"hand":
			_hand(c, ox, oy, mode, phase)
		"husk":
			var frame := {"bob": oy, "lean": ox / 2 - 1, "arm": 2 if mode == "attack" and phase == 1 else (3 if mode == "hit" else 0), "flash": mode == "attack" and phase == 1}
			humanoid(c, {
				"skin": Color(0.55, 0.55, 0.6), "hair": Color(0.2, 0.2, 0.24), "hair_style": "short",
				"coat": Color(0.3, 0.3, 0.34), "pants": Color(0.2, 0.2, 0.24), "accent": OIL_SHEEN,
				"eye": VOID_PURPLE, "closed_eyes": true, "hunch": 1, "weapon": "none"}, frame)
			# 발밑의 검은 기름.
			c.ellipse(16, 30.5, 7, 1.5, VOID_BLACK)
			c.px(11, 30, OIL_SHEEN)
	if mode == "hit":
		_tint(c, Color(1.0, 0.85, 0.85), 0.25)


static func _eye(c: PixelCanvas, x: int, y: int, color: Color = VOID_PURPLE) -> void:
	c.px(x, y, color)
	c.px(x, y - 1, color.lightened(0.5))


static func _sheen(c: PixelCanvas, cx: int, cy: int, w: int) -> void:
	c.hline(cx - w / 2, cx + w / 2, cy, OIL_SHEEN)
	c.px(cx, cy, VOID_TEAL.darkened(0.2))


static func _rat(c: PixelCanvas, ox: int, oy: int, mode: String, phase: int) -> void:
	c.line(8 + ox, 25 + oy, 3 + ox, 21 + oy + (phase % 2), VOID_BLACK)
	c.ellipse(15 + ox, 25 + oy, 7, 4.5, VOID_BLACK)
	c.circle(21.5 + ox, 23 + oy, 3.5, VOID_BLACK)
	c.polygon(PackedVector2Array([Vector2(19 + ox, 21 + oy), Vector2(20 + ox, 17 + oy), Vector2(22 + ox, 20 + oy)]), VOID_BLACK)
	c.rect(10 + ox, 28 + oy, 2, 2, VOID_BLACK)
	c.rect(18 + ox, 28 + oy, 2, 2, VOID_BLACK)
	_eye(c, 23 + ox, 22 + oy)
	_sheen(c, 14 + ox, 22 + oy, 6)
	if mode == "attack" and phase == 1:
		c.rect(24 + ox, 24 + oy, 2, 1, Color(0.8, 0.15, 0.2))
	c.outline(OUTLINE)


static func _hound(c: PixelCanvas, ox: int, oy: int, mode: String, phase: int) -> void:
	c.ellipse(14 + ox, 20 + oy, 8, 4.5, VOID_BLACK)
	for lx in [8, 11, 17, 20]:
		c.line(lx + ox, 22 + oy, lx + ox + (1 if phase % 2 == 0 else 0), 29, VOID_BLACK, 2)
	c.circle(23 + ox, 17 + oy, 4, VOID_BLACK)
	c.rect(25 + ox, 18 + oy, 4, 2, VOID_BLACK)
	c.polygon(PackedVector2Array([Vector2(20 + ox, 15 + oy), Vector2(21 + ox, 10 + oy), Vector2(23 + ox, 14 + oy)]), VOID_BLACK)
	c.line(6 + ox, 18 + oy, 2 + ox, 14 + oy + (phase % 2), VOID_BLACK, 2)
	_eye(c, 25 + ox, 16 + oy, VOID_TEAL)
	_sheen(c, 13 + ox, 17 + oy, 8)
	# 기름 방울.
	c.px(15 + ox, 26 + (phase % 3), OIL_SHEEN)
	if mode == "attack" and phase == 1:
		c.rect(26 + ox, 20 + oy, 3, 1, Color(0.85, 0.85, 0.9))
	c.outline(OUTLINE)


static func _leech(c: PixelCanvas, ox: int, oy: int, mode: String, phase: int) -> void:
	for i in 7:
		var x: float = 6 + i * 3 + ox
		var y: float = 25 + oy + sin(float(i + phase) * 1.2) * 1.5
		c.circle(x, y, 3.0 - absf(float(i) - 3.0) * 0.25, VOID_BLACK if i % 2 == 0 else Color(0.1, 0.08, 0.15))
	c.circle(26 + ox, 23 + oy, 3, Color(0.35, 0.1, 0.18))
	c.circle(26 + ox, 23 + oy, 1.5, Color(0.8, 0.2, 0.3) if mode == "attack" else Color(0.15, 0.05, 0.08))
	_sheen(c, 15 + ox, 23 + oy, 8)
	c.outline(OUTLINE)


static func _brute(c: PixelCanvas, ox: int, oy: int, mode: String, phase: int) -> void:
	c.ellipse(15 + ox, 18 + oy, 9, 10, VOID_BLACK)
	c.rect(9 + ox, 26, 4, 5, VOID_BLACK)
	c.rect(17 + ox, 26, 4, 5, VOID_BLACK)
	var reach: int = 8 if mode == "attack" and phase == 1 else 2
	c.line(20 + ox, 14 + oy, 22 + ox + reach, 20 + oy, VOID_BLACK, 4)
	c.line(9 + ox, 14 + oy, 6 + ox, 23 + oy, VOID_BLACK, 4)
	c.circle(17 + ox, 8 + oy, 3.5, VOID_BLACK)
	_eye(c, 19 + ox, 8 + oy, Color(1.0, 0.6, 0.2))
	_sheen(c, 14 + ox, 14 + oy, 10)
	_sheen(c, 12 + ox, 20 + oy, 6)
	for i in 3:
		c.px(8 + i * 5 + ox, 29 + ((phase + i) % 2), OIL_SHEEN)
	c.outline(OUTLINE)


static func _crown(c: PixelCanvas, ox: int, oy: int, mode: String, phase: int) -> void:
	# 몸통 (프레임을 거의 채운다).
	c.ellipse(16 + ox, 19 + oy, 13, 11, VOID_BLACK)
	c.rect(5 + ox, 26, 22, 5, VOID_BLACK)
	# 녹슨 관으로 된 왕관.
	var rust := Color(0.55, 0.3, 0.18)
	for i in 5:
		var x: int = 7 + i * 4 + ox
		c.rect(x, 4 + oy + (i % 2) * 2, 2, 6, rust)
		c.px(x, 4 + oy + (i % 2) * 2, rust.lightened(0.3))
	# 가슴의 공허 핵 (청록 빛).
	var glow: float = 0.6 + 0.4 * sin(float(phase))
	c.circle(16 + ox, 19 + oy, 3.5, VOID_TEAL.darkened(0.3))
	c.circle(16 + ox, 19 + oy, 2.0, VOID_TEAL.lightened(glow * 0.4))
	# 여러 개의 눈.
	for e in [Vector2i(9, 14), Vector2i(23, 13), Vector2i(12, 23), Vector2i(21, 24), Vector2i(16, 11)]:
		_eye(c, e.x + ox, e.y + oy, VOID_PURPLE if (e.x + phase) % 2 == 0 else Color(1.0, 0.5, 0.3))
	if mode == "attack" and phase == 1:
		c.line(26 + ox, 18 + oy, 31, 24 + oy, VOID_BLACK, 4)
	_sheen(c, 12 + ox, 12 + oy, 6)
	c.outline(OUTLINE)


static func _hand(c: PixelCanvas, ox: int, oy: int, mode: String, phase: int) -> void:
	var dusk := Color(0.2, 0.08, 0.25)
	# 손바닥.
	c.ellipse(16 + ox, 22 + oy, 9, 8, dusk)
	# 손가락 다섯 개.
	var curl: int = 4 if mode == "attack" and phase == 1 else 0
	for i in 4:
		var x: int = 9 + i * 4 + ox
		c.line(x, 18 + oy, x + (curl if i > 1 else -curl / 2), 3 + oy + absi(i - 1) * 2 + curl, dusk, 3)
	c.line(7 + ox, 24 + oy, 2 + ox, 17 + oy, dusk, 3)
	# 손목은 바닥 아래로 이어진다.
	c.rect(10 + ox, 28, 12, 4, dusk)
	# 손바닥의 눈.
	c.ellipse(16 + ox, 22 + oy, 4, 2.5, Color(0.9, 0.85, 0.7))
	c.circle(16 + ox + (phase % 2), 22 + oy, 1.5, Color(0.6, 0.1, 0.5))
	c.px(16 + ox + (phase % 2), 22 + oy, Color.BLACK)
	c.outline(OUTLINE)


## 이미 그린 픽셀을 tint 쪽으로 amount 만큼 섞는다.
static func _tint(c: PixelCanvas, tint: Color, amount: float) -> void:
	for y in c.height:
		for x in c.width:
			var col: Color = c.image.get_pixel(x, y)
			if col.a > 0.0:
				var mixed: Color = col.lerp(tint, amount)
				mixed.a = col.a
				c.image.set_pixel(x, y, mixed)
