# Art/ext/ 의 원본 배경(그림) 3장으로 대화 배경과 전투 배경(픽셀화)을 만든다.
# 실행: Godot --headless --path <프로젝트> --script res://tools/process_backgrounds.gd
# 결과: Art/gen/bg/*.png (대화·화면 배경, 원본 해상도), Art/gen/battle/*.png (전투 배경, 픽셀 아트 344×192)
extends SceneTree

const SRC: String = "res://Art/ext"
const OUT_BG: String = "res://Art/gen/bg"
const OUT_BATTLE: String = "res://Art/gen/battle"
## 전투 배경 축소 배율과 팔레트 색 수.
const PIXEL_FACTOR: int = 4
const PALETTE_SIZE: int = 32


func _initialize() -> void:
	var started: int = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(OUT_BG)
	DirAccess.make_dir_recursive_absolute(OUT_BATTLE)
	var office: Image = _load("office_bg.png")
	var sewer: Image = _load("sewer_battle_bg.png")
	var title: Image = _load("title_keyart.png")

	# --- 대화·화면 배경 ---
	_save(title, "%s/title.png" % OUT_BG)
	_save(office, "%s/office.png" % OUT_BG)
	_save(sewer, "%s/sewer_gate.png" % OUT_BG)

	var academy: Image = office.duplicate()
	_grade(academy, Color(1.15, 1.02, 0.86), Color(0.04, 0.02, 0.0), 1.05, 0.85)
	_vignette(academy, 0.35)
	_save(academy, "%s/academy.png" % OUT_BG)

	var void_img: Image = _void_version(sewer)
	_save(void_img, "%s/void.png" % OUT_BG)

	var twilight: Image = _twilight_version(title)
	_save(twilight, "%s/twilight.png" % OUT_BG)

	var core: Image = _core_version(sewer)
	_save(core, "%s/core_room.png" % OUT_BG)

	var alley: Image = title.get_region(Rect2i(700, 300, 676, 468))
	alley.resize(1376, 768, Image.INTERPOLATE_LANCZOS)
	_grade(alley, Color(0.55, 0.62, 0.85), Color(0.0, 0.0, 0.03), 1.1, 0.7)
	_rain(alley, 1400, 7)
	_vignette(alley, 0.6)
	_save(alley, "%s/alley_rain.png" % OUT_BG)

	# --- 전투 배경 (픽셀화) ---
	_save(_pixelate(sewer), "%s/sewer.png" % OUT_BATTLE)
	var factory: Image = sewer.duplicate()
	_grade(factory, Color(0.92, 1.05, 0.95), Color(0.0, 0.01, 0.0), 1.0, 0.75)
	_save(_pixelate(factory), "%s/factory.png" % OUT_BATTLE)
	_save(_pixelate(_twilight_version(sewer)), "%s/twilight.png" % OUT_BATTLE)
	_save(_pixelate(core), "%s/core.png" % OUT_BATTLE)
	print("backgrounds processed in %d ms" % (Time.get_ticks_msec() - started))
	quit()


func _load(file_name: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [SRC, file_name]))
	img.convert(Image.FORMAT_RGBA8)
	return img


func _save(img: Image, path: String) -> void:
	var err: Error = img.save_png(path)
	if err != OK:
		push_error("could not save %s" % path)


# ---------------- 색 보정 ----------------

## 곱하기·더하기·대비·채도 보정.
func _grade(img: Image, mul: Color, add: Color, contrast: float, saturation: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			var r: float = (c.r * mul.r + add.r - 0.5) * contrast + 0.5
			var g: float = (c.g * mul.g + add.g - 0.5) * contrast + 0.5
			var b: float = (c.b * mul.b + add.b - 0.5) * contrast + 0.5
			var lum: float = r * 0.299 + g * 0.587 + b * 0.114
			img.set_pixel(x, y, Color(clampf(lerpf(lum, r, saturation), 0, 1), clampf(lerpf(lum, g, saturation), 0, 1), clampf(lerpf(lum, b, saturation), 0, 1), c.a))


## 밝기를 색 띠로 바꾼다 (어두움 → 밝음 순서의 colors).
func _gradient_map(img: Image, colors: Array, amount: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			var lum: float = clampf(c.r * 0.299 + c.g * 0.587 + c.b * 0.114, 0.0, 1.0)
			var t: float = lum * float(colors.size() - 1)
			var i: int = mini(floori(t), colors.size() - 2)
			var mapped: Color = (colors[i] as Color).lerp(colors[i + 1], t - float(i))
			img.set_pixel(x, y, c.lerp(mapped, amount))


func _vignette(img: Image, strength: float) -> void:
	var w: float = float(img.get_width())
	var h: float = float(img.get_height())
	for y in img.get_height():
		for x in img.get_width():
			var dx: float = (float(x) / w - 0.5) * 1.6
			var dy: float = (float(y) / h - 0.5) * 1.6
			var d: float = clampf(sqrt(dx * dx + dy * dy) - 0.35, 0.0, 1.0)
			var c: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, c.darkened(d * strength))


func _glow(img: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(maxi(0, int(center.y - radius)), mini(img.get_height(), int(center.y + radius))):
		for x in range(maxi(0, int(center.x - radius)), mini(img.get_width(), int(center.x + radius))):
			var d: float = Vector2(x, y).distance_to(center) / radius
			if d >= 1.0:
				continue
			var k: float = (1.0 - d) * (1.0 - d) * color.a
			var c: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(minf(c.r + color.r * k, 1.0), minf(c.g + color.g * k, 1.0), minf(c.b + color.b * k, 1.0), c.a))


func _rain(img: Image, count: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var x: int = rng.randi_range(0, img.get_width() - 1)
		var y: int = rng.randi_range(0, img.get_height() - 1)
		var length: int = rng.randi_range(10, 26)
		for k in length:
			var px: int = x - k / 4
			var py: int = y + k
			if px < 0 or py >= img.get_height():
				break
			var c: Color = img.get_pixel(px, py)
			img.set_pixel(px, py, c.lerp(Color(0.75, 0.8, 0.95), 0.25))


## 공허 내부: 어둡고 보랏빛, 무지갯빛 균열.
func _void_version(src: Image) -> Image:
	var img: Image = src.duplicate()
	_grade(img, Color(0.55, 0.45, 0.7), Color(0.0, 0.0, 0.02), 1.25, 0.45)
	_gradient_map(img, [Color(0.01, 0.0, 0.03), Color(0.12, 0.06, 0.2), Color(0.35, 0.22, 0.5), Color(0.55, 0.85, 0.85)], 0.5)

	_vignette(img, 0.75)
	return img


## 황혼층: 보라→주황 띠, 몽환적.
func _twilight_version(src: Image) -> Image:
	var img: Image = src.duplicate()
	_gradient_map(img, [Color(0.06, 0.01, 0.1), Color(0.32, 0.08, 0.36), Color(0.85, 0.35, 0.4), Color(1.0, 0.75, 0.5)], 0.78)
	_grade(img, Color(1, 1, 1), Color(0, 0, 0), 1.1, 1.1)
	_vignette(img, 0.5)
	return img


## 핵의 방: 어두운 하수도 + 균열 자리의 청록 빛.
func _core_version(src: Image) -> Image:
	var img: Image = src.duplicate()
	_grade(img, Color(0.5, 0.55, 0.6), Color(0, 0, 0), 1.2, 0.5)
	_glow(img, Vector2(930, 300), 320.0, Color(0.2, 0.75, 0.7, 0.75))
	_glow(img, Vector2(930, 300), 110.0, Color(0.5, 1.0, 0.95, 0.9))

	_vignette(img, 0.6)
	return img


## 바닥에서 위로 뻗는 검은 기름 줄기와 무지갯빛 테두리.
func _veins(img: Image, count: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for v in count:
		var x: float = rng.randf_range(0, img.get_width())
		var y: float = img.get_height() - 1
		var width: float = rng.randf_range(3.0, 7.0)
		while y > img.get_height() * rng.randf_range(0.2, 0.6) and width > 0.6:
			for k in range(-int(width), int(width) + 1):
				var px: int = int(x) + k
				if px < 0 or px >= img.get_width():
					continue
				var edge: bool = absi(k) >= int(width) - 1
				var tint: Color = Color(0.5, 0.85, 0.85) if (int(y) / 7) % 2 == 0 else Color(0.6, 0.4, 0.95)
				img.set_pixel(px, int(y), tint.darkened(0.2) if edge else Color(0.02, 0.01, 0.04))
			x += rng.randf_range(-2.0, 2.0)
			y -= 1.0
			width -= 0.012


# ---------------- 픽셀화 ----------------

## 1/PIXEL_FACTOR 로 줄이고 PALETTE_SIZE 색으로 양자화한다 (k-평균).
func _pixelate(src: Image) -> Image:
	var img: Image = src.duplicate()
	img.resize(src.get_width() / PIXEL_FACTOR, src.get_height() / PIXEL_FACTOR, Image.INTERPOLATE_LANCZOS)
	# 대비를 살짝 올려 픽셀 아트처럼 또렷하게.
	_grade(img, Color(1, 1, 1), Color(0, 0, 0), 1.08, 1.1)
	var palette: Array[Color] = _kmeans(img, PALETTE_SIZE, 10)
	for y in img.get_height():
		for x in img.get_width():
			img.set_pixel(x, y, _nearest(palette, img.get_pixel(x, y)))
	return img


func _kmeans(img: Image, k: int, iterations: int) -> Array[Color]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var samples: Array[Color] = []
	for i in 5000:
		samples.append(img.get_pixel(rng.randi_range(0, img.get_width() - 1), rng.randi_range(0, img.get_height() - 1)))
	var centers: Array[Color] = []
	for i in k:
		centers.append(samples[rng.randi_range(0, samples.size() - 1)])
	for it in iterations:
		var sums: Array[Vector3] = []
		var counts: Array[int] = []
		for i in k:
			sums.append(Vector3.ZERO)
			counts.append(0)
		for c in samples:
			var best: int = _nearest_index(centers, c)
			sums[best] += Vector3(c.r, c.g, c.b)
			counts[best] += 1
		for i in k:
			if counts[i] > 0:
				var m: Vector3 = sums[i] / float(counts[i])
				centers[i] = Color(m.x, m.y, m.z)
	return centers


func _nearest_index(palette: Array[Color], c: Color) -> int:
	var best: int = 0
	var best_d: float = INF
	for i in palette.size():
		var p: Color = palette[i]
		var dr: float = p.r - c.r
		var dg: float = p.g - c.g
		var db: float = p.b - c.b
		var d: float = dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11
		if d < best_d:
			best_d = d
			best = i
	return best


func _nearest(palette: Array[Color], c: Color) -> Color:
	return palette[_nearest_index(palette, c)]
