## 64×64 프레임용 사람형·괴물 도형을 조립한다. ShadeRenderer.render_pixel 로 그린 뒤 details(눈 등 픽셀)를 덧찍는다.
## 모두 오른쪽을 본다 (3/4 시점: 얼굴이 머리의 오른쪽에 있다).
class_name FigureBuilder
extends RefCounted


## 재질을 렌더러에 등록한다.
static func register_human(r: ShadeRenderer, spec: Dictionary) -> void:
	r.material("skin", spec["skin"], {"ramp": ShadeRenderer.ramp(spec["skin"], 0.98, 0.1)})
	r.material("hair", spec["hair"])
	r.material("coat", spec["coat"])
	r.material("accent", spec["accent"])
	r.material("pants", spec.get("pants", Color(0.16, 0.16, 0.2)))
	r.material("boots", spec.get("boots", Color(0.18, 0.12, 0.1)))
	r.material("metal", Color(0.72, 0.74, 0.8), {"ramp": [Color(0.22, 0.22, 0.3), Color(0.45, 0.47, 0.56), Color(0.72, 0.74, 0.82), Color(0.96, 0.97, 1.0)]})
	r.material("wood", Color(0.42, 0.28, 0.18))
	r.material("blood", Color(0.82, 0.08, 0.16), {"emissive": true, "ramp": [Color(0.4, 0.02, 0.08), Color(0.62, 0.05, 0.12), Color(0.86, 0.1, 0.18), Color(1.0, 0.45, 0.45)]})
	r.material("glow", spec.get("glow", Color(0.5, 0.9, 1.0)), {"emissive": true, "ramp": [Color(0.3, 0.6, 0.8), Color(0.5, 0.85, 1.0), Color(0.75, 0.95, 1.0), Color(1, 1, 1)]})
	if spec.has("helmet"):
		r.material("helmet", spec["helmet"])


## 사람형 한 프레임. frame: bob, lean, arm(0 기본·1 준비·2 타격·3 피격), flash.
## 돌려주는 값: {"shapes": [...], "details": [[x, y, Color], ...]}
static func human(spec: Dictionary, frame: Dictionary) -> Dictionary:
	var small: bool = spec.get("small", false)
	var bob: float = float(frame.get("bob", 0))
	var lean: float = float(frame.get("lean", 0))
	var arm: int = int(frame.get("arm", 0))
	var flash: bool = frame.get("flash", false)
	# 작은 체구는 상체를 아래로 내리고 다리를 짧게.
	var dy: float = 4.0 if small else 0.0
	var ux: float = lean
	var uy: float = bob + dy
	var hip: float = 44.0 + (2.0 if small else 0.0)
	var shapes: Array = []
	var details: Array = []
	var step: float = 2.0 if arm == 2 else (-1.0 if arm == 3 else 0.0)

	# --- 뒤쪽 (뒷머리·뒷팔·뒷다리) ---
	var style: String = spec.get("hair_style", "short")
	if style == "long" or style == "fox":
		shapes.append({"t": "p", "m": "hair", "shade": -1, "pts": ShadeRenderer.bezier_poly([
			Vector2(25 + ux, 15 + uy), Vector2(19 + ux, 30 + uy), Vector2(22 + ux, 44 + uy - (3 if small else 0)),
			Vector2(29 + ux, 46 + uy), Vector2(33 + ux, 40 + uy), Vector2(34 + ux, 22 + uy), Vector2(25 + ux, 15 + uy)])})
	if style == "pony":
		shapes.append({"t": "c", "m": "hair", "shade": -1, "ax": 24 + ux, "ay": 18 + uy, "bx": 20 + ux, "by": 30 + uy, "r": 3.0})
	shapes.append({"t": "c", "m": "coat", "shade": -1, "ax": 26 + ux, "ay": 31 + uy, "bx": 25 + ux - lean * 0.5, "by": 41 + uy, "r": 2.4})
	shapes.append({"t": "e", "m": "skin", "shade": -1, "cx": 25 + ux - lean * 0.5, "cy": 42.5 + uy, "rx": 2.0, "ry": 2.0})
	shapes.append({"t": "c", "m": "pants", "shade": -1, "ax": 29, "ay": hip, "bx": 28 - step * 0.5, "by": 57, "r": 2.8})
	shapes.append({"t": "e", "m": "boots", "shade": -1, "cx": 28.5 - step * 0.5, "cy": 59, "rx": 3.8, "ry": 2.4})

	# --- 몸통 ---
	var torso_top: float = 29.0 + uy
	var torso_h: float = hip - torso_top
	if spec.get("long_coat", true):
		shapes.append({"t": "p", "m": "coat", "pts": [Vector2(24.5 + ux, hip - 6), Vector2(37.5 + ux, hip - 6), Vector2(40 + ux * 0.5, hip + 6 - (2 if small else 0)), Vector2(22 + ux * 0.5, hip + 6 - (2 if small else 0))]})
	shapes.append({"t": "c", "m": "pants", "ax": 34, "ay": hip, "bx": 35 + step, "by": 57, "r": 2.9})
	shapes.append({"t": "e", "m": "boots", "cx": 36.5 + step, "cy": 59, "rx": 4.2, "ry": 2.5})
	shapes.append({"t": "b", "m": "coat", "cx": 31 + ux, "cy": torso_top + torso_h * 0.5, "hw": 7.0, "hh": torso_h * 0.5 + 1.0, "r": 3.0})
	shapes.append({"t": "b", "m": "accent", "flat": true, "cx": 31 + ux, "cy": hip - 3, "hw": 7.2, "hh": 1.1, "r": 0.5, "noline": true})
	# 깃·스카프.
	shapes.append({"t": "c", "m": "accent", "ax": 26.5 + ux, "ay": torso_top + 0.5, "bx": 36 + ux, "by": torso_top + 0.5, "r": 2.3})
	if spec.get("scarf_tail", false):
		shapes.append({"t": "c", "m": "accent", "shade": -1, "ax": 27 + ux, "ay": torso_top + 1, "bx": 22 + ux - bob, "by": torso_top + 7, "r": 1.8})

	# --- 머리 ---
	var hx: float = 33.0 + ux + (-1.0 if arm == 3 else 0.0)
	var hy: float = 19.0 + uy
	shapes.append({"t": "c", "m": "skin", "ax": 32 + ux, "ay": hy + 7, "bx": 32 + ux, "by": torso_top, "r": 2.2, "noline": true})
	if style == "helmet":
		shapes.append({"t": "e", "m": "helmet", "cx": hx - 0.5, "cy": hy - 0.5, "rx": 9.6, "ry": 9.6})
	else:
		shapes.append({"t": "e", "m": "hair", "cx": hx - 1.5, "cy": hy - 1.0, "rx": 9.2, "ry": 9.0})
	shapes.append({"t": "e", "m": "skin", "cx": hx + 1.5, "cy": hy + 1.5, "rx": 7.2, "ry": 7.4})
	if style == "helmet":
		shapes.append({"t": "b", "m": "helmet", "cx": hx + 1, "cy": hy - 5, "hw": 9.5, "hh": 3.0, "r": 1.5, "line": true})
		shapes.append({"t": "b", "m": "metal", "flat": true, "cx": hx + 4, "cy": hy - 2.4, "hw": 5.5, "hh": 0.8, "r": 0.4})
	elif style != "bald":
		# 앞머리 덩어리들.
		shapes.append({"t": "e", "m": "hair", "line": true, "cx": hx - 0.5, "cy": hy - 6.0, "rx": 8.5, "ry": 4.6})
		shapes.append({"t": "p", "m": "hair", "line": true, "pts": [Vector2(hx + 1, hy - 8), Vector2(hx + 9, hy - 5), Vector2(hx + 8, hy + 1), Vector2(hx + 5, hy - 3), Vector2(hx + 2, hy - 1)]})
		shapes.append({"t": "e", "m": "hair", "line": true, "cx": hx - 5.5, "cy": hy - 0.5, "rx": 3.6, "ry": 6.5})
		if style == "long" or style == "fox":
			shapes.append({"t": "c", "m": "hair", "line": true, "ax": hx + 7.5, "ay": hy - 2, "bx": hx + 7.0, "by": hy + 8, "r": 1.7})
	if style == "fox":
		for k in 2:
			var bx: float = hx - 5.0 + k * 7.0
			shapes.append({"t": "p", "m": "hair", "line": true, "pts": [Vector2(bx - 3, hy - 7), Vector2(bx - 1 + k, hy - 15 + k), Vector2(bx + 3, hy - 8)]})
			shapes.append({"t": "p", "m": "accent", "noline": true, "pts": [Vector2(bx - 1.2, hy - 8), Vector2(bx - 0.5 + k, hy - 12.5 + k), Vector2(bx + 1.4, hy - 8.5)]})

	# --- 앞팔·무기 ---
	var shoulder := Vector2(36 + ux, torso_top + 2)
	var hand := Vector2(37 + ux, 41 + uy)
	match arm:
		1:
			hand = Vector2(29 + ux, 25 + uy)
		2:
			hand = Vector2(46 + ux, 33 + uy)
		3:
			hand = Vector2(40 + ux, 27 + uy)
	shapes.append({"t": "c", "m": "coat", "ax": shoulder.x, "ay": shoulder.y, "bx": hand.x - 0.5, "by": hand.y - 0.5, "r": 2.5})
	_weapon(shapes, spec.get("weapon", "none"), hand, arm, flash)
	shapes.append({"t": "e", "m": "skin", "cx": hand.x, "cy": hand.y, "rx": 2.1, "ry": 2.1})

	# --- 얼굴 픽셀 ---
	var eye_color: Color = spec.get("eye", Color(0.15, 0.1, 0.1))
	var ex: int = roundi(hx + 5.0)
	var ey: int = roundi(hy + 1.0)
	if arm == 3 or spec.get("closed_eyes", false):
		details.append([ex - 1, ey + 1, Color(0.2, 0.1, 0.12)])
		details.append([ex, ey + 1, Color(0.2, 0.1, 0.12)])
		details.append([ex - 5, ey + 1, Color(0.2, 0.1, 0.12)])
	else:
		for e in [Vector2i(ex, ey), Vector2i(ex - 5, ey)]:
			details.append([e.x, e.y - 1, Color(0.12, 0.07, 0.09)])
			details.append([e.x - 1, e.y - 1, Color(0.12, 0.07, 0.09)])
			details.append([e.x, e.y, eye_color])
			details.append([e.x, e.y + 1, eye_color.darkened(0.35)])
			details.append([e.x - 1, e.y, eye_color.lightened(0.45)])
			details.append([e.x - 1, e.y + 1, eye_color.darkened(0.1)])
	details.append([ex - 2, ey + 4, (spec["skin"] as Color).darkened(0.35)])
	if spec.get("blush", false):
		details.append([ex + 1, ey + 3, Color(0.95, 0.55, 0.55)])
	return {"shapes": shapes, "details": details}


static func _weapon(shapes: Array, kind: String, hand: Vector2, arm: int, flash: bool) -> void:
	match kind:
		"sword", "greatsword":
			var big: bool = kind == "greatsword"
			var length: float = 18.0 if big else 14.0
			var dir: Vector2
			match arm:
				1:
					dir = Vector2(-0.55, -0.83)
				2:
					dir = Vector2(1.0, 0.05)
				_:
					dir = Vector2(0.55, -0.83)
			var tip: Vector2 = hand + dir * length
			var guard_n := Vector2(-dir.y, dir.x)
			shapes.append({"t": "c", "m": "metal", "line": true, "ax": hand.x + dir.x * 3, "ay": hand.y + dir.y * 3, "bx": tip.x, "by": tip.y, "r": 1.9 if big else 1.25})
			shapes.append({"t": "c", "m": "accent", "ax": hand.x + dir.x * 2.5 - guard_n.x * 3, "ay": hand.y + dir.y * 2.5 - guard_n.y * 3, "bx": hand.x + dir.x * 2.5 + guard_n.x * 3, "by": hand.y + dir.y * 2.5 + guard_n.y * 3, "r": 1.0})
			shapes.append({"t": "c", "m": "wood", "ax": hand.x - dir.x * 2, "ay": hand.y - dir.y * 2, "bx": hand.x + dir.x * 1.5, "by": hand.y + dir.y * 1.5, "r": 1.1})
			if flash:
				shapes.append({"t": "c", "m": "glow", "noline": true, "ax": hand.x + 4, "ay": hand.y - 9, "bx": tip.x + 2, "by": tip.y + 5, "r": 0.9})
		"claws":
			if arm == 2:
				for i in 3:
					shapes.append({"t": "c", "m": "blood", "noline": true, "ax": hand.x + 1, "ay": hand.y - 3 + i * 2.5, "bx": hand.x + 7, "by": hand.y - 6 + i * 3.5, "r": 0.9})
				if flash:
					for i in 3:
						shapes.append({"t": "c", "m": "blood", "noline": true, "ax": hand.x + 5 + i * 2, "ay": hand.y - 12 + i, "bx": hand.x + 9 + i * 2, "by": hand.y + 6, "r": 1.1})
			else:
				for i in 3:
					shapes.append({"t": "c", "m": "blood", "noline": true, "ax": hand.x + 1, "ay": hand.y - 1 + i * 1.5, "bx": hand.x + 3.5, "by": hand.y + 1 + i * 1.5, "r": 0.7})
		"gun":
			if arm == 2:
				shapes.append({"t": "b", "m": "wood", "cx": hand.x + 1, "cy": hand.y + 1.5, "hw": 2.5, "hh": 1.6, "r": 0.6})
				shapes.append({"t": "c", "m": "metal", "line": true, "ax": hand.x, "ay": hand.y - 0.5, "bx": hand.x + 11, "by": hand.y - 0.5, "r": 1.3})
				if flash:
					shapes.append({"t": "e", "m": "glow", "noline": true, "cx": hand.x + 13.5, "cy": hand.y - 0.5, "rx": 2.8, "ry": 2.2})
			else:
				shapes.append({"t": "c", "m": "metal", "line": true, "ax": hand.x, "ay": hand.y - 2, "bx": hand.x + 1, "by": hand.y + 9, "r": 1.3})
				shapes.append({"t": "b", "m": "wood", "cx": hand.x + 0.5, "cy": hand.y - 1, "hw": 1.6, "hh": 2.4, "r": 0.6})
		"staff":
			var top: Vector2 = hand + (Vector2(11, -3) if arm == 2 else Vector2(1.5, -18))
			var bottom: Vector2 = hand + (Vector2(-6, 2) if arm == 2 else Vector2(-0.5, 15))
			shapes.append({"t": "c", "m": "wood", "line": true, "ax": bottom.x, "ay": bottom.y, "bx": top.x, "by": top.y, "r": 1.2})
			shapes.append({"t": "e", "m": "glow", "cx": top.x, "cy": top.y, "rx": 2.6, "ry": 2.6})
			if flash:
				shapes.append({"t": "e", "m": "glow", "noline": true, "cx": top.x + 5, "cy": top.y, "rx": 3.5, "ry": 3.0})


# ---------------- 공허 괴물 ----------------

static func register_void(r: ShadeRenderer, accent: Color = Color(0.55, 0.32, 0.85)) -> void:
	r.material("void", Color(0.13, 0.1, 0.2), {
		"ramp": [Color(0.03, 0.02, 0.06), Color(0.07, 0.05, 0.12), Color(0.14, 0.1, 0.22), Color(0.3, 0.22, 0.45)],
		"outline": Color(0.02, 0.01, 0.03),
		"rim": Color(0.3, 0.8, 0.78),
	})
	r.material("void2", Color(0.2, 0.12, 0.28), {
		"ramp": [Color(0.05, 0.03, 0.08), Color(0.12, 0.06, 0.18), Color(0.22, 0.12, 0.32), Color(0.45, 0.28, 0.6)],
		"outline": Color(0.02, 0.01, 0.03),
		"rim": accent,
	})
	r.material("eye", Color(0.8, 0.5, 1.0), {"emissive": true, "ramp": [Color(0.6, 0.3, 0.9), Color(0.75, 0.45, 1.0), Color(0.9, 0.7, 1.0), Color(1, 1, 1)]})
	r.material("eye2", Color(1.0, 0.55, 0.25), {"emissive": true, "ramp": [Color(0.8, 0.3, 0.1), Color(1.0, 0.5, 0.2), Color(1.0, 0.75, 0.4), Color(1, 1, 0.9)]})
	r.material("core", Color(0.3, 0.85, 0.8), {"emissive": true, "ramp": [Color(0.1, 0.45, 0.45), Color(0.2, 0.7, 0.68), Color(0.45, 0.95, 0.9), Color(0.92, 1.0, 1.0)]})
	r.material("rust", Color(0.55, 0.3, 0.18))
	r.material("bone", Color(0.82, 0.78, 0.68))
	r.material("flesh", Color(0.55, 0.15, 0.22))
	r.material("pale", Color(0.55, 0.55, 0.62))
	r.material("rag", Color(0.3, 0.3, 0.35))
	r.material("palm", Color(0.28, 0.12, 0.32), {"rim": Color(1.0, 0.55, 0.35)})
	r.material("iris", Color(0.92, 0.88, 0.75))


## 괴물 한 프레임. mode: idle(phase 0~3) / attack(0~2) / hit(0~1).
static func monster(kind: String, mode: String, phase: int) -> Dictionary:
	var ox: float = 0.0
	var oy: float = 0.0
	var squash: float = 0.0
	if mode == "idle":
		oy = [0.0, 0.5, 1.0, 0.5][phase]
		squash = [0.0, 0.5, 1.0, 0.5][phase]
	elif mode == "attack":
		ox = [-3.0, 6.0, 2.0][phase]
	elif mode == "hit":
		ox = [-5.0, -2.0][phase]
	var lunge: bool = mode == "attack" and phase == 1
	var shapes: Array = []
	var details: Array = []
	match kind:
		"rat":
			shapes.append({"t": "c", "m": "void2", "ax": 20 + ox, "ay": 52, "bx": 9 + ox, "by": 46 - phase % 2, "r": 1.2})
			shapes.append({"t": "e", "m": "void", "cx": 30 + ox, "cy": 51 + oy * 0.5, "rx": 12 + squash * 0.5, "ry": 8 - squash * 0.4})
			shapes.append({"t": "e", "m": "void", "cx": 41 + ox, "cy": 47 + oy * 0.5, "rx": 6.5, "ry": 5.5})
			shapes.append({"t": "p", "m": "void2", "pts": [Vector2(37 + ox, 43), Vector2(38 + ox, 36), Vector2(42 + ox, 42)]})
			shapes.append({"t": "c", "m": "void2", "ax": 24 + ox, "ay": 56, "bx": 24 + ox, "by": 60, "r": 1.8})
			shapes.append({"t": "c", "m": "void2", "ax": 36 + ox, "ay": 56, "bx": 37 + ox, "by": 60, "r": 1.8})
			if lunge:
				shapes.append({"t": "e", "m": "flesh", "cx": 47 + ox, "cy": 49, "rx": 2.5, "ry": 1.6})
			shapes.append({"t": "e", "m": "eye", "cx": 44 + ox, "cy": 46 + oy * 0.5, "rx": 1.4, "ry": 1.4})
		"hound":
			shapes.append({"t": "c", "m": "void2", "ax": 15 + ox, "ay": 39, "bx": 6 + ox, "by": 31 + phase % 2, "r": 2.0})
			for lx in [17.0, 22.0]:
				shapes.append({"t": "c", "m": "void2", "ax": lx + ox, "ay": 43, "bx": lx - 1 + ox, "by": 59, "r": 2.2})
			shapes.append({"t": "e", "m": "void", "cx": 27 + ox, "cy": 40 + oy, "rx": 14, "ry": 8.5})
			for lx in [30.0, 35.0]:
				shapes.append({"t": "c", "m": "void", "ax": lx + ox, "ay": 44, "bx": lx + 1 + ox + (2.0 if lunge else 0.0), "by": 59, "r": 2.3})
			shapes.append({"t": "e", "m": "void", "cx": 44 + ox, "cy": 33 + oy, "rx": 7, "ry": 6.5})
			shapes.append({"t": "b", "m": "void", "cx": 50 + ox, "cy": 36 + oy + (1.5 if lunge else 0.0), "hw": 5, "hh": 2.5, "r": 1.5})
			shapes.append({"t": "p", "m": "void2", "pts": [Vector2(39 + ox, 29 + oy), Vector2(40 + ox, 20 + oy), Vector2(45 + ox, 28 + oy)]})
			if lunge:
				for t in 3:
					shapes.append({"t": "p", "m": "bone", "noline": true, "pts": [Vector2(48 + t * 2 + ox, 38 + oy), Vector2(49 + t * 2 + ox, 41 + oy), Vector2(50 + t * 2 + ox, 38 + oy)]})
			shapes.append({"t": "e", "m": "eye", "cx": 46 + ox, "cy": 32 + oy, "rx": 1.5, "ry": 1.3})
			# 기름 방울.
			shapes.append({"t": "e", "m": "void2", "cx": 28 + ox, "cy": 51 + (phase % 3) * 2, "rx": 1.0, "ry": 1.5})
		"leech":
			for i in 8:
				var x: float = 12 + i * 5.2 + ox
				var y: float = 50 + oy * 0.5 + sin(float(i + phase) * 1.1) * 2.2
				var rr: float = 5.5 - absf(float(i) - 3.5) * 0.45
				shapes.append({"t": "e", "m": "void" if i % 2 == 0 else "void2", "line": true, "cx": x, "cy": y, "rx": rr, "ry": rr * 0.9})
			shapes.append({"t": "e", "m": "flesh", "cx": 53 + ox, "cy": 47 + oy * 0.5, "rx": 4.5, "ry": 5.0})
			shapes.append({"t": "e", "m": "void", "cx": 54.5 + ox, "cy": 47 + oy * 0.5, "rx": 2.2 + (1.2 if lunge else 0.0), "ry": 2.6})
			for t in 4:
				details.append([53 + t + int(ox), 43 + int(oy * 0.5), Color(0.9, 0.85, 0.75)])
		"husk":
			var frame := {"bob": oy, "lean": ox * 0.4 - 1.0, "arm": 2 if lunge else (3 if mode == "hit" else 0), "flash": false}
			var built: Dictionary = human({
				"skin": Color(0.55, 0.56, 0.62), "hair": Color(0.18, 0.18, 0.22), "hair_style": "short",
				"coat": Color(0.3, 0.3, 0.35), "accent": Color(0.22, 0.16, 0.3), "pants": Color(0.2, 0.2, 0.24),
				"eye": Color(0.7, 0.45, 1.0), "closed_eyes": true, "weapon": "none", "long_coat": false}, frame)
			shapes = built["shapes"]
			details = built["details"]
			shapes.push_front({"t": "e", "m": "void", "cx": 32, "cy": 60.5, "rx": 13, "ry": 2.5})
			# 몸에서 흐르는 검은 기름.
			shapes.append({"t": "c", "m": "void", "noline": true, "ax": 30 + ox * 0.4, "ay": 33 + oy, "bx": 29 + ox * 0.4, "by": 46 + oy, "r": 1.3})
		"brute":
			shapes.append({"t": "c", "m": "void2", "ax": 22 + ox, "ay": 26 + oy, "bx": 14 + ox, "by": 47 + oy, "r": 5.5})
			shapes.append({"t": "c", "m": "void", "ax": 25 + ox, "ay": 48, "bx": 24 + ox, "by": 60, "r": 4.5})
			shapes.append({"t": "c", "m": "void", "ax": 37 + ox, "ay": 48, "bx": 39 + ox, "by": 60, "r": 4.8})
			shapes.append({"t": "e", "m": "void", "cx": 31 + ox, "cy": 37 + oy, "rx": 15 + squash * 0.5, "ry": 16 - squash * 0.5})
			shapes.append({"t": "e", "m": "void", "line": true, "cx": 35 + ox, "cy": 19 + oy, "rx": 7, "ry": 6.5})
			var reach: Vector2 = Vector2(57 + ox, 36) if lunge else Vector2(47 + ox, 47 + oy)
			shapes.append({"t": "c", "m": "void", "line": true, "ax": 41 + ox, "ay": 28 + oy, "bx": reach.x, "by": reach.y, "r": 6.0})
			shapes.append({"t": "e", "m": "void2", "line": true, "cx": reach.x, "cy": reach.y + 2, "rx": 6.5, "ry": 5.5})
			shapes.append({"t": "e", "m": "eye2", "cx": 39 + ox, "cy": 18 + oy, "rx": 1.6, "ry": 1.4})
			shapes.append({"t": "e", "m": "eye2", "cx": 35 + ox, "cy": 19 + oy, "rx": 1.1, "ry": 1.0})
			for i in 3:
				shapes.append({"t": "e", "m": "void2", "noline": true, "cx": 20 + i * 10 + ox, "cy": 56 + ((phase + i) % 2) * 2, "rx": 1.2, "ry": 2.0})
		"crown":
			shapes.append({"t": "c", "m": "void2", "ax": 12 + ox, "ay": 34 + oy, "bx": 5 + ox, "by": 55, "r": 5.0})
			shapes.append({"t": "e", "m": "void", "cx": 32 + ox, "cy": 40 + oy, "rx": 26 + squash, "ry": 21 - squash * 0.5})
			shapes.append({"t": "b", "m": "void", "cx": 32 + ox, "cy": 57, "hw": 24, "hh": 6, "r": 4})
			for i in 5:
				var x: float = 14 + i * 9 + ox
				var top: float = 8 + (i % 2) * 4 + oy
				shapes.append({"t": "b", "m": "rust", "line": true, "cx": x, "cy": top + 6, "hw": 2.4, "hh": 6, "r": 1.0})
				shapes.append({"t": "e", "m": "rust", "line": true, "cx": x, "cy": top, "rx": 3.2, "ry": 1.8})
			shapes.append({"t": "e", "m": "void2", "cx": 32 + ox, "cy": 40 + oy, "rx": 9, "ry": 8})
			shapes.append({"t": "e", "m": "core", "cx": 32 + ox, "cy": 40 + oy, "rx": 5.5, "ry": 5.5})
			for e in [Vector2(17, 30), Vector2(47, 27), Vector2(22, 49), Vector2(43, 50), Vector2(32, 24)]:
				shapes.append({"t": "e", "m": "eye" if int(e.x + phase) % 2 == 0 else "eye2", "cx": e.x + ox, "cy": e.y + oy, "rx": 1.8, "ry": 1.5})
			var arm_end: Vector2 = Vector2(62, 44) if lunge else Vector2(55 + ox, 53)
			shapes.append({"t": "c", "m": "void", "line": true, "ax": 50 + ox, "ay": 35 + oy, "bx": arm_end.x, "by": arm_end.y, "r": 5.5})
		"hand":
			shapes.append({"t": "b", "m": "palm", "cx": 32 + ox, "cy": 58, "hw": 11, "hh": 6, "r": 3})
			shapes.append({"t": "e", "m": "palm", "cx": 32 + ox, "cy": 44 + oy, "rx": 16, "ry": 13})
			var curl: float = 7.0 if lunge else 0.0
			for i in 4:
				var x: float = 21 + i * 7.5 + ox
				var tip_y: float = 8 + absf(float(i) - 1.5) * 5 + curl + oy
				shapes.append({"t": "c", "m": "palm", "line": true, "ax": x, "ay": 36 + oy, "bx": x + (curl * 0.6 if i > 1 else -curl * 0.3), "by": tip_y, "r": 3.6})
			shapes.append({"t": "c", "m": "palm", "line": true, "ax": 18 + ox, "ay": 48 + oy, "bx": 7 + ox, "by": 36 + oy, "r": 3.8})
			shapes.append({"t": "e", "m": "iris", "cx": 32 + ox, "cy": 45 + oy, "rx": 7.5, "ry": 4.5})
			shapes.append({"t": "e", "m": "eye", "cx": 32 + ox + (phase % 2), "cy": 45 + oy, "rx": 3.2, "ry": 3.2})
			details.append([32 + int(ox) + (phase % 2), 45 + int(oy), Color(0.05, 0.0, 0.05)])
	return {"shapes": shapes, "details": details}
