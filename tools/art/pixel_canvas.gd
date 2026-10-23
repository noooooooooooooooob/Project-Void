## 코드로 픽셀 아트를 그리는 작은 래스터 도구. 생성기(tools/generate_art.gd)가 쓴다.
## 좌표는 왼쪽 위가 (0, 0). 모든 함수는 캔버스 밖 픽셀을 조용히 무시한다.
class_name PixelCanvas
extends RefCounted

var image: Image
var width: int
var height: int


func _init(p_width: int, p_height: int, background: Color = Color(0, 0, 0, 0)) -> void:
	width = p_width
	height = p_height
	image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(background)


static func hex(code: String) -> Color:
	return Color.html(code)


func px(x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= width or y >= height:
		return
	if color.a >= 0.999:
		image.set_pixel(x, y, color)
		return
	if color.a <= 0.0:
		return
	image.set_pixel(x, y, image.get_pixel(x, y).blend(color))


func get_px(x: int, y: int) -> Color:
	if x < 0 or y < 0 or x >= width or y >= height:
		return Color(0, 0, 0, 0)
	return image.get_pixel(x, y)


func rect(x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			px(xx, yy, color)


func hline(x0: int, x1: int, y: int, color: Color) -> void:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		px(x, y, color)


func vline(x: int, y0: int, y1: int, color: Color) -> void:
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		px(x, y, color)


## 브레젠험 직선.
func line(x0: int, y0: int, x1: int, y1: int, color: Color, thickness: int = 1) -> void:
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	var x: int = x0
	var y: int = y0
	while true:
		if thickness <= 1:
			px(x, y, color)
		else:
			rect(x - thickness / 2, y - thickness / 2, thickness, thickness, color)
		if x == x1 and y == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


## 채운 타원 (중심 cx, cy / 반지름 rx, ry).
func ellipse(cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		for x in range(floori(cx - rx), ceili(cx + rx) + 1):
			var nx: float = (float(x) + 0.5 - cx) / maxf(rx, 0.01)
			var ny: float = (float(y) + 0.5 - cy) / maxf(ry, 0.01)
			if nx * nx + ny * ny <= 1.0:
				px(x, y, color)


func circle(cx: float, cy: float, r: float, color: Color) -> void:
	ellipse(cx, cy, r, r, color)


## 채운 다각형 (스캔라인, 짝홀 규칙).
func polygon(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	var min_y: float = points[0].y
	var max_y: float = points[0].y
	for p in points:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	for y in range(floori(min_y), ceili(max_y) + 1):
		var sample_y: float = float(y) + 0.5
		var xs: Array[float] = []
		for i in points.size():
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i + 1) % points.size()]
			if (a.y <= sample_y and b.y > sample_y) or (b.y <= sample_y and a.y > sample_y):
				xs.append(a.x + (sample_y - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		var i: int = 0
		while i + 1 < xs.size():
			for x in range(roundi(xs[i]), roundi(xs[i + 1])):
				px(x, y, color)
			i += 2


## 위에서 아래로 두 색을 섞은 세로 그라데이션 사각형.
func vgradient(x: int, y: int, w: int, h: int, top: Color, bottom: Color) -> void:
	for yy in h:
		var t: float = float(yy) / maxf(float(h - 1), 1.0)
		hline(x, x + w - 1, y + yy, top.lerp(bottom, t))


## 2색 디더(체커) 사각형. 픽셀 아트의 중간 톤용.
func dither(x: int, y: int, w: int, h: int, a: Color, b: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			px(xx, yy, a if (xx + yy) % 2 == 0 else b)


## 불투명 픽셀 둘레의 투명 픽셀에 외곽선 색을 칠한다 (상하좌우 기준).
func outline(color: Color) -> void:
	var src: Image = image.duplicate()
	for y in height:
		for x in width:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= width or ny >= height:
					continue
				if src.get_pixel(nx, ny).a > 0.5:
					image.set_pixel(x, y, color)
					break


## 결정적 잡음 점찍기 (seed 고정). 질감용.
func speckle(x: int, y: int, w: int, h: int, color: Color, density: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if rng.randf() < density:
				px(xx, yy, color)


## 다른 캔버스를 (x, y) 에 겹쳐 그린다 (알파 섞기). flip 이면 좌우 반전.
func stamp(other: PixelCanvas, x: int, y: int, flip: bool = false) -> void:
	for yy in other.height:
		for xx in other.width:
			var c: Color = other.image.get_pixel(other.width - 1 - xx if flip else xx, yy)
			if c.a > 0.0:
				px(x + xx, y + yy, c)


## 정수 배율로 키운 새 이미지 (최근접 이웃 — 픽셀이 뭉개지지 않는다).
func scaled(factor: int) -> Image:
	var copy: Image = image.duplicate()
	copy.resize(width * factor, height * factor, Image.INTERPOLATE_NEAREST)
	return copy


func save(path: String, factor: int = 1) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var out: Image = image if factor == 1 else scaled(factor)
	var err: Error = out.save_png(path)
	if err != OK:
		push_error("could not save %s (%s)" % [path, err])
