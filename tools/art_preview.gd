# 생성한 유닛 그림을 한 장에 모아 확대한 미리보기를 만든다 (확인용).
# 실행: Godot --headless --path <프로젝트> --script res://tools/art_preview.gd -- <출력 png> [배율] [id...]
extends SceneTree


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://preview.png"
	var scale: int = int(args[1]) if args.size() > 1 else 3
	var ids: PackedStringArray = args.slice(2) if args.size() > 2 else PackedStringArray(["hangyeol", "hongyeon", "doyun", "mira", "baekjun", "rat", "hound", "leech", "husk", "brute", "crown", "hand"])
	var rows: Array[Image] = []
	var width: int = 0
	for id in ids:
		var row: Image = null
		for suffix in ["_idle", "_attack", "_hit"]:
			var img := Image.load_from_file(ProjectSettings.globalize_path("res://Art/gen/units/%s%s.png" % [id, suffix]))
			if img == null:
				continue
			img.convert(Image.FORMAT_RGBA8)
			if row == null:
				row = img
			else:
				var joined := Image.create(row.get_width() + 8 + img.get_width(), row.get_height(), false, Image.FORMAT_RGBA8)
				joined.fill(Color(0, 0, 0, 0))
				joined.blit_rect(row, Rect2i(Vector2i.ZERO, row.get_size()), Vector2i.ZERO)
				joined.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(row.get_width() + 8, 0))
				row = joined
		if row != null:
			rows.append(row)
			width = maxi(width, row.get_width())
	var height: int = 0
	for r in rows:
		height += r.get_height() + 4
	var sheet := Image.create(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.42, 0.4, 0.46))
	var y: int = 0
	for r in rows:
		sheet.blend_rect(r, Rect2i(Vector2i.ZERO, r.get_size()), Vector2i(0, y))
		y += r.get_height() + 4
	sheet.resize(width * scale, height * scale, Image.INTERPOLATE_NEAREST)
	sheet.save_png(out_path)
	quit()
