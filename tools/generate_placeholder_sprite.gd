extends SceneTree

const WIDTH: int = 128
const HEIGHT: int = 192
const OUTPUT: String = "res://Resources/sprites/placeholder_unit.png"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://Resources/sprites")
	var image: Image = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_fill_circle(image, Vector2(64, 40), 28.0)
	_fill_rounded_rect(image, Rect2(24, 72, 80, 116), 24.0)

	var err: int = image.save_png(ProjectSettings.globalize_path(OUTPUT))
	if err != OK:
		push_error("failed to save %s (error %d)" % [OUTPUT, err])
		quit(1)
		return
	print("wrote %s" % OUTPUT)
	quit(0)


func _fill_circle(image: Image, center: Vector2, radius: float) -> void:
	for y in HEIGHT:
		for x in WIDTH:
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				image.set_pixel(x, y, Color.WHITE)


func _fill_rounded_rect(image: Image, rect: Rect2, radius: float) -> void:
	var inner: Rect2 = rect.grow(-radius)
	for y in HEIGHT:
		for x in WIDTH:
			var point := Vector2(x + 0.5, y + 0.5)
			if not rect.has_point(point):
				continue
			var nearest := Vector2(clampf(point.x, inner.position.x, inner.end.x), clampf(point.y, inner.position.y, inner.end.y))
			if point.distance_to(nearest) <= radius:
				image.set_pixel(x, y, Color.WHITE)
