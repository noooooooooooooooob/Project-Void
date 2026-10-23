## 줄 단위 대본 텍스트를 명령 목록으로 바꾸는 파서. 대본은 Resources/story/*.txt 에 둔다.
##
## 형식 (한 줄에 한 명령, 빈 줄과 // 주석은 무시):
##   hongyeon: 대사            등장인물 id 와 대사 (id 는 StoryCast 에 있어야 한다)
##   > 서술                    나레이션
##   @bg office                배경 바꾸기 (Art/gen/bg/<id>.png)
##   @show hongyeon right      일러스트를 왼쪽(left)·오른쪽(right)에 세우기
##   @hide right               일러스트 내리기 (left / right / all)
##   @label 이름 / @goto 이름  흐름 이동
##   @if 플래그 라벨           플래그가 있으면 라벨로 (@unless 는 반대)
##   @set 플래그               플래그 켜기
##   @effect 종류 값...        효과 (GameFlow 가 처리: gold 30, item random, heal 30, join hongyeon ...)
##   @end 결과                 대본 끝 (결과 문자열은 선택)
##   * 선택지 글 -> 라벨       연속된 * 줄이 한 번의 선택지가 된다. "* [플래그] 글 -> 라벨" 은 플래그가 있을 때만 보인다.
class_name StoryScript
extends RefCounted

const STORY_DIR: String = "res://Resources/story"


## 대본 파일을 읽어 명령 목록으로 돌려준다. 파일이 없으면 빈 목록.
static func load_script(script_id: String) -> Array[Dictionary]:
	var path: String = "%s/%s.txt" % [STORY_DIR, script_id]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("story script not found: %s" % path)
		return []
	return parse(file.get_as_text())


## 대본 텍스트를 명령 목록으로 바꾼다.
static func parse(text: String) -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	var pending_choice: Array = []
	for raw in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.is_empty() or line.begins_with("//"):
			continue
		# 선택지 줄은 모아 두었다가, 다른 줄이 나오면 한 명령으로 만든다.
		if line.begins_with("*"):
			pending_choice.append(_choice_option(line.substr(1).strip_edges()))
			continue
		if not pending_choice.is_empty():
			commands.append({"choice": pending_choice})
			pending_choice = []
		commands.append(_command(line))
	if not pending_choice.is_empty():
		commands.append({"choice": pending_choice})
	return commands


static func _choice_option(body: String) -> Dictionary:
	var option: Dictionary = {}
	if body.begins_with("["):
		var close: int = body.find("]")
		option["if"] = body.substr(1, close - 1).strip_edges()
		body = body.substr(close + 1).strip_edges()
	var arrow: int = body.rfind("->")
	if arrow >= 0:
		option["goto"] = body.substr(arrow + 2).strip_edges()
		body = body.substr(0, arrow).strip_edges()
	option["text"] = body
	return option


static func _command(line: String) -> Dictionary:
	if line.begins_with(">"):
		return {"narrate": line.substr(1).strip_edges()}
	if line.begins_with("@"):
		var parts: PackedStringArray = line.substr(1).split(" ", false)
		var head: String = parts[0]
		var args: PackedStringArray = parts.slice(1)
		match head:
			"bg":
				return {"bg": args[0] if args.size() > 0 else ""}
			"show":
				return {"show": args[0], "side": args[1] if args.size() > 1 else "right"}
			"hide":
				return {"hide": args[0] if args.size() > 0 else "all"}
			"label":
				return {"label": args[0]}
			"goto":
				return {"goto": args[0]}
			"if":
				return {"if": args[0], "goto": args[1]}
			"unless":
				return {"unless": args[0], "goto": args[1]}
			"set":
				return {"set": args[0]}
			"effect":
				return {"effect": {"type": args[0], "args": Array(args.slice(1))}}
			"end":
				return {"end": " ".join(args)}
		push_error("unknown story command: %s" % line)
		return {"narrate": line}
	var colon: int = line.find(":")
	if colon > 0:
		var speaker: String = line.substr(0, colon).strip_edges()
		if StoryCast.has(speaker):
			return {"say": speaker, "text": line.substr(colon + 1).strip_edges()}
	# id 가 아닌 콜론 줄은 서술로 본다.
	return {"narrate": line}
