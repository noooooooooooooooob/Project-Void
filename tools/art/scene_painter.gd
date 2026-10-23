## 전투 칸 타일과 아이템 아이콘을 그리는 함수 모음 (픽셀 아트).
class_name ScenePainter
extends RefCounted


## 전투 칸 타일 (32×32): 비스듬히 깎은 돌판 + 편 색 테두리 빛.
static func tile_texture(enemy: bool) -> PixelCanvas:
	var base: Color = Color(0.2, 0.18, 0.24)
	var rim: Color = Color(0.95, 0.35, 0.38) if enemy else Color(0.4, 0.62, 1.0)
	var c := PixelCanvas.new(32, 32, base)
	# 위·왼쪽은 밝게, 아래·오른쪽은 어둡게 깎은 면.
	for i in 3:
		c.hline(i, 31 - i, i, base.lightened(0.25 - i * 0.06))
		c.vline(i, i, 31 - i, base.lightened(0.18 - i * 0.05))
		c.hline(i, 31 - i, 31 - i, base.darkened(0.45 - i * 0.1))
		c.vline(31 - i, i, 31 - i, base.darkened(0.35 - i * 0.08))
	# 돌 질감.
	c.speckle(4, 4, 24, 24, base.lightened(0.08), 0.12, 21 if enemy else 13)
	c.speckle(4, 4, 24, 24, base.darkened(0.15), 0.12, 31 if enemy else 17)
	c.line(9, 18, 15, 22, base.darkened(0.3))
	c.line(15, 22, 19, 21, base.darkened(0.3))
	# 테두리 빛 (모서리는 밝게).
	c.hline(4, 27, 4, rim.darkened(0.15))
	c.hline(4, 27, 27, rim.darkened(0.45))
	c.vline(4, 4, 27, rim.darkened(0.25))
	c.vline(27, 4, 27, rim.darkened(0.45))
	for p in [Vector2i(4, 4), Vector2i(27, 4), Vector2i(4, 27), Vector2i(27, 27)]:
		c.px(p.x, p.y, rim.lightened(0.35))
	return c


## 아이템 아이콘 (24×24, 입체 명암).
static func icon(kind: String, color: Color) -> PixelCanvas:
	var r := ShadeRenderer.new()
	r.material("main", color)
	r.material("metal", Color(0.75, 0.77, 0.84), {"ramp": [Color(0.25, 0.25, 0.32), Color(0.48, 0.5, 0.58), Color(0.75, 0.77, 0.84), Color(0.97, 0.98, 1.0)]})
	r.material("gold", Color(0.9, 0.7, 0.3))
	r.material("paper", Color(0.9, 0.86, 0.76))
	var shapes: Array = []
	match kind:
		"weapon":
			shapes.append({"t": "c", "m": "metal", "line": true, "ax": 7, "ay": 17, "bx": 19, "by": 5, "r": 1.8})
			shapes.append({"t": "c", "m": "main", "ax": 5, "ay": 13, "bx": 11, "by": 19, "r": 1.4})
			shapes.append({"t": "c", "m": "gold", "ax": 4, "ay": 20, "bx": 7, "by": 17, "r": 1.4})
		"armor":
			shapes.append({"t": "p", "m": "main", "pts": [Vector2(4, 4), Vector2(20, 4), Vector2(20, 13), Vector2(12, 21), Vector2(4, 13)]})
			shapes.append({"t": "c", "m": "metal", "ax": 12, "ay": 6, "bx": 12, "by": 17, "r": 1.3})
		"accessory":
			shapes.append({"t": "e", "m": "gold", "cx": 12, "cy": 13, "rx": 7, "ry": 7})
			shapes.append({"t": "e", "m": "main", "line": true, "cx": 12, "cy": 13, "rx": 3.6, "ry": 3.6})
			shapes.append({"t": "c", "m": "gold", "ax": 12, "ay": 3, "bx": 12, "by": 6, "r": 1.4})
		"card":
			shapes.append({"t": "b", "m": "paper", "cx": 12, "cy": 12, "hw": 7, "hh": 9, "r": 1.5})
			shapes.append({"t": "b", "m": "main", "flat": true, "cx": 12, "cy": 9, "hw": 5, "hh": 4, "r": 1})
		"gold":
			shapes.append({"t": "e", "m": "gold", "cx": 12, "cy": 12, "rx": 8, "ry": 8})
			shapes.append({"t": "e", "m": "gold", "line": true, "shade": -1, "cx": 12, "cy": 12, "rx": 4.5, "ry": 4.5})
		"heart":
			shapes.append({"t": "e", "m": "main", "cx": 8.5, "cy": 10, "rx": 4.6, "ry": 4.6})
			shapes.append({"t": "e", "m": "main", "cx": 15.5, "cy": 10, "rx": 4.6, "ry": 4.6})
			shapes.append({"t": "p", "m": "main", "pts": [Vector2(4, 11), Vector2(20, 11), Vector2(12, 20)]})
	var c := PixelCanvas.new(24, 24)
	c.image = r.render_pixel(shapes, 24, 24)
	return c
