## 도형(타원·캡슐·둥근 상자·다각형)을 입체 법선으로 조명해 그리는 렌더러.
## "pixel" 모드: 픽셀 중심 한 점만 보고 색 램프로 양자화 + 바깥 외곽선 + 재질 경계선 → 픽셀 아트.
##
## 도형(Dictionary):
##   t: "e"(타원 cx,cy,rx,ry) / "c"(캡슐 ax,ay,bx,by,r) / "b"(둥근 상자 cx,cy,hw,hh,r) / "p"(다각형 pts)
##   m: 재질 키, shade: 밝기 보정(-1 이면 한 단계 어둡게), line: true 면 같은 재질끼리도 경계선, flat: true 면 법선을 평평하게
## 목록 뒤쪽 도형이 위에 그려진다.
class_name ShadeRenderer
extends RefCounted

## 왼쪽 위 앞에서 비추는 빛.
const LIGHT := Vector3(-0.55, -0.65, 0.52)

var materials: Dictionary = {}


## 기본색 하나로 색상이 이동하는 4단 램프를 만든다: [가장 어두움, 그늘, 기본, 밝음]. 그늘은 보라·파랑 쪽, 밝음은 노랑 쪽으로 돈다.
static func ramp(base: Color, shadow_hue: float = 0.72, light_hue: float = 0.12) -> Array[Color]:
	var deep: Color = _shift(base, shadow_hue, 0.12, 0.42, 0.15)
	var shadow: Color = _shift(base, shadow_hue, 0.06, 0.68, 0.08)
	var light: Color = _shift(base, light_hue, 0.05, 1.22, -0.12)
	return [deep, shadow, base, light]


static func _shift(c: Color, target_hue: float, amount: float, value_mul: float, sat_add: float) -> Color:
	var h: float = c.h
	var d: float = wrapf(target_hue - h, -0.5, 0.5)
	h = wrapf(h + d * amount * (1.0 if c.s > 0.05 else 0.0), 0.0, 1.0)
	return Color.from_hsv(h, clampf(c.s + sat_add, 0.0, 1.0), clampf(c.v * value_mul, 0.0, 1.0), c.a)


## 재질을 등록한다. outline 을 안 주면 가장 어두운 색을 더 어둡게 쓴다. rim 은 오른쪽 뒤 테두리 빛.
func material(key: String, base: Color, opts: Dictionary = {}) -> void:
	var r: Array = opts.get("ramp", ramp(base))
	materials[key] = {
		"ramp": r,
		"outline": opts.get("outline", r[0].darkened(0.55)),
		"rim": opts.get("rim", Color(0, 0, 0, 0)),
		"emissive": opts.get("emissive", false),
	}


# ---------------- 도형 판정 ----------------

## 점 (x, y) 가 도형 안이면 법선(Vector3), 밖이면 null.
static func _hit(s: Dictionary, x: float, y: float) -> Variant:
	match s["t"]:
		"e":
			var u: float = (x - float(s["cx"])) / float(s["rx"])
			var v: float = (y - float(s["cy"])) / float(s["ry"])
			var d: float = u * u + v * v
			if d > 1.0:
				return null
			return Vector3(u, v, sqrt(maxf(1.0 - d, 0.0)))
		"c":
			var a := Vector2(s["ax"], s["ay"])
			var b := Vector2(s["bx"], s["by"])
			var p := Vector2(x, y)
			var ab: Vector2 = b - a
			var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var q: Vector2 = a + ab * t
			var r: float = float(s["r"])
			var dv: Vector2 = (p - q) / r
			var d: float = dv.length_squared()
			if d > 1.0:
				return null
			return Vector3(dv.x, dv.y, sqrt(maxf(1.0 - d, 0.0)))
		"b":
			var hw: float = float(s["hw"])
			var hh: float = float(s["hh"])
			var rr: float = float(s.get("r", 2.0))
			var lx: float = x - float(s["cx"])
			var ly: float = y - float(s["cy"])
			var qx: float = absf(lx) - hw + rr
			var qy: float = absf(ly) - hh + rr
			var outside: float = Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - rr
			if outside > 0.0:
				return null
			var u: float = clampf(lx / hw, -1.0, 1.0)
			return Vector3(u * 0.85, clampf(ly / hh, -1.0, 1.0) * 0.25, sqrt(maxf(1.0 - u * u * 0.72, 0.05)))
		"p":
			if not _in_poly(s["pts"], x, y):
				return null
			var bb: Rect2 = s["_bb"]
			var u: float = (x - bb.position.x) / maxf(bb.size.x, 1.0) * 2.0 - 1.0
			var v: float = (y - bb.position.y) / maxf(bb.size.y, 1.0) * 2.0 - 1.0
			if s.get("flat", false):
				return Vector3(0, -0.1, 1)
			return Vector3(u * 0.55, v * 0.3, 0.8)
	return null


static func _in_poly(pts: PackedVector2Array, x: float, y: float) -> bool:
	var inside: bool = false
	var j: int = pts.size() - 1
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[j]
		if (a.y > y) != (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		j = i
	return inside


static func _bounds(s: Dictionary) -> Rect2:
	match s["t"]:
		"e":
			return Rect2(float(s["cx"]) - float(s["rx"]), float(s["cy"]) - float(s["ry"]), float(s["rx"]) * 2.0, float(s["ry"]) * 2.0)
		"c":
			var r: float = float(s["r"])
			var mn := Vector2(minf(s["ax"], s["bx"]) - r, minf(s["ay"], s["by"]) - r)
			var mx := Vector2(maxf(s["ax"], s["bx"]) + r, maxf(s["ay"], s["by"]) + r)
			return Rect2(mn, mx - mn)
		"b":
			return Rect2(float(s["cx"]) - float(s["hw"]), float(s["cy"]) - float(s["hh"]), float(s["hw"]) * 2.0, float(s["hh"]) * 2.0)
		"p":
			var pts: PackedVector2Array = s["pts"]
			var mn2: Vector2 = pts[0]
			var mx2: Vector2 = pts[0]
			for p in pts:
				mn2 = Vector2(minf(mn2.x, p.x), minf(mn2.y, p.y))
				mx2 = Vector2(maxf(mx2.x, p.x), maxf(mx2.y, p.y))
			return Rect2(mn2, mx2 - mn2)
	return Rect2()


## 2차 베지어 곡선들을 이어 다각형 점으로 만든다. points 는 [시작, 조절, 끝, 조절, 끝, ...] (마지막 끝은 시작과 닫힘).
static func bezier_poly(points: Array, steps: int = 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	var start: Vector2 = points[0]
	var i: int = 1
	while i + 1 < points.size():
		var c: Vector2 = points[i]
		var e: Vector2 = points[i + 1]
		for k in steps:
			var t: float = float(k) / float(steps)
			out.append(start.lerp(c, t).lerp(c.lerp(e, t), t))
		start = e
		i += 2
	return out


# ---------------- 그리기 ----------------

## 픽셀 아트 한 장. 바깥 외곽선과 재질 경계선을 넣는다.
func render_pixel(shapes: Array, w: int, h: int) -> Image:
	var prepared: Array = _prepare(shapes)
	var idx := PackedInt32Array()
	idx.resize(w * h)
	idx.fill(-1)
	var light_level := PackedFloat32Array()
	light_level.resize(w * h)
	var normal_x := PackedFloat32Array()
	normal_x.resize(w * h)
	var lightv: Vector3 = LIGHT.normalized()
	for si in prepared.size():
		var s: Dictionary = prepared[si]
		var bb: Rect2 = s["_bb"]
		for y in range(maxi(0, floori(bb.position.y) - 1), mini(h, ceili(bb.end.y) + 1)):
			for x in range(maxi(0, floori(bb.position.x) - 1), mini(w, ceili(bb.end.x) + 1)):
				var n: Variant = _hit(s, float(x) + 0.5, float(y) + 0.5)
				if n == null:
					continue
				var nv: Vector3 = (n as Vector3).normalized()
				idx[y * w + x] = si
				light_level[y * w + x] = clampf(nv.dot(lightv) * 0.85 + 0.38 + float(s.get("shade", 0)) * 0.22, 0.0, 1.0)
				normal_x[y * w + x] = nv.x
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var si: int = idx[y * w + x]
			if si < 0:
				continue
			var s: Dictionary = prepared[si]
			var m: Dictionary = materials[s["m"]]
			var r: Array = m["ramp"]
			var l: float = light_level[y * w + x]
			# 경계 근처는 체커 디더로 섞는다.
			var bias: float = 0.035 if (x + y) % 2 == 0 else -0.035
			var level: int = _level(l + bias)
			var col: Color = r[level]
			var rim: Color = m["rim"]
			if rim.a > 0.0 and normal_x[y * w + x] > 0.62:
				col = col.lerp(rim, 0.75)
			img.set_pixel(x, y, col)
	# 재질 경계선: 뒤에 있는 도형 쪽 픽셀을 가장 어두운 색으로.
	var src: Image = img.duplicate()
	for y in h:
		for x in w:
			var si: int = idx[y * w + x]
			if si < 0:
				continue
			var s: Dictionary = prepared[si]
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var ti: int = idx[ny * w + nx]
				if ti <= si:
					continue
				var t: Dictionary = prepared[ti]
				if t["m"] == s["m"] and not t.get("line", false):
					continue
				if t.get("noline", false):
					continue
				img.set_pixel(x, y, (materials[s["m"]]["ramp"] as Array)[0])
				break
	# 바깥 외곽선 (도형의 재질 외곽선 색).
	src = img.duplicate()
	for y in h:
		for x in w:
			if idx[y * w + x] >= 0:
				continue
			var best: int = -1
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				best = maxi(best, idx[ny * w + nx])
			if best >= 0:
				var m2: Dictionary = materials[prepared[best]["m"]]
				if not m2["emissive"]:
					img.set_pixel(x, y, m2["outline"])
	return img


static func _level(l: float) -> int:
	if l < 0.26:
		return 0
	if l < 0.5:
		return 1
	if l < 0.84:
		return 2
	return 3


func _prepare(shapes: Array) -> Array:
	var out: Array = []
	for s in shapes:
		var copy: Dictionary = (s as Dictionary).duplicate()
		if copy["t"] == "p" and copy["pts"] is Array:
			copy["pts"] = PackedVector2Array(copy["pts"])
		copy["_bb"] = _bounds(copy)
		out.append(copy)
	return out
