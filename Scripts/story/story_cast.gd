## 대본에 나오는 등장인물: id → 화면 이름, 일러스트, 이름 색.
class_name StoryCast
extends RefCounted

const PORTRAIT_DIR: String = "res://Art/gen/portraits"

const CAST: Dictionary = {
	"hangyeol": {"name": "한결", "portrait": "hangyeol", "color": Color(0.72, 0.62, 1.0)},
	"hongyeon": {"name": "홍연", "portrait": "hongyeon", "color": Color(1.0, 0.45, 0.5)},
	"hyeolgwi": {"name": "장로 혈귀", "portrait": "hyeolgwi", "color": Color(0.9, 0.3, 0.35)},
	"doyun": {"name": "강도윤", "portrait": "doyun", "color": Color(1.0, 0.68, 0.38)},
	"mira": {"name": "서미라", "portrait": "mira", "color": Color(0.6, 0.85, 0.55)},
	"baekjun": {"name": "백준", "portrait": "baekjun", "color": Color(0.5, 0.9, 0.88)},
	"supervisor": {"name": "하수도 감독관", "portrait": "supervisor", "color": Color(0.85, 0.75, 0.55)},
	"instructor": {"name": "교관", "portrait": "instructor", "color": Color(0.78, 0.68, 0.95)},
	"unknown": {"name": "???", "portrait": "", "color": Color(0.7, 0.7, 0.75)},
	"voice": {"name": "목소리", "portrait": "", "color": Color(0.6, 0.85, 0.85)},
}


static func has(id: String) -> bool:
	return CAST.has(id)


static func display_name(id: String) -> String:
	return CAST[id]["name"] if CAST.has(id) else id


static func name_color(id: String) -> Color:
	return CAST[id]["color"] if CAST.has(id) else Color.WHITE


## 일러스트 그림. 없으면 null.
static func portrait(id: String) -> Texture2D:
	if not CAST.has(id) or (CAST[id]["portrait"] as String).is_empty():
		return null
	var path: String = "%s/%s.png" % [PORTRAIT_DIR, CAST[id]["portrait"]]
	return load(path) if ResourceLoader.exists(path) else null
