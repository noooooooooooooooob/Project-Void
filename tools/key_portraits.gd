# Art/ext/portraits/ 의 일러스트(마젠타 단색 배경)에서 배경을 투명하게 빼고 가장자리 분홍 번짐을 지워 Art/gen/portraits/ 에 저장한다.
# 실행: Godot --headless --path <프로젝트> --script res://tools/key_portraits.gd
extends SceneTree

const SRC: String = "res://Art/ext/portraits"
const OUT: String = "res://Art/gen/portraits"
## 이 정도 이상 마젠타면 완전히 투명, 이하면 불투명 (사이는 부드럽게).
const KEY_FULL: float = 0.42
const KEY_NONE: float = 0.16


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var dir := DirAccess.open(SRC)
	for file_name in dir.get_files():
		if not file_name.ends_with(".png"):
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [SRC, file_name]))
		img.convert(Image.FORMAT_RGBA8)
		_key(img)
		img.save_png("%s/%s" % [OUT, file_name])
		print("keyed %s" % file_name)
	quit()


func _key(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			# 마젠타 정도: 빨강·파랑이 초록보다 얼마나 큰가.
			var magenta: float = minf(c.r, c.b) - c.g
			var alpha: float = 1.0 - smoothstep(KEY_NONE, KEY_FULL, magenta)
			if alpha <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# 번짐 제거: 마젠타 성분을 초록 쪽으로 눌러 준다.
			if magenta > 0.0:
				var spill: float = magenta * 0.85
				c.r = maxf(c.r - spill, 0.0)
				c.b = maxf(c.b - spill, 0.0)
			c.a = alpha
			img.set_pixel(x, y, c)
