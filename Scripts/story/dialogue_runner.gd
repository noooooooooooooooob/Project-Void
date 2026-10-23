## 대본 명령을 차례로 진행하는 규칙 코어 (노드 비의존 — 화면 없이 테스트할 수 있다).
## advance() 를 부를 때마다 배경·일러스트·플래그·효과 같은 즉시 명령을 처리하고,
## 플레이어가 읽거나 골라야 하는 다음 "장면"(대사·서술·알림·선택지·끝)을 돌려준다.
class_name DialogueRunner
extends RefCounted

## 장면 종류.
const LINE: String = "line"
const NARRATION: String = "narration"
const NOTICE: String = "notice"
const CHOICE: String = "choice"
const END: String = "end"

## 현재 배경 id (빈 문자열이면 바꾸지 않음).
var background: String = ""
## 서 있는 일러스트: "left"/"right" → 등장인물 id.
var portraits: Dictionary = {}
## 플래그 확인·설정에 쓰는 사전 (GameState.flags 를 그대로 넘기면 공유된다).
var flags: Dictionary = {}
## 효과 처리기: func(effect: Dictionary) -> String (알림 문구, 없으면 빈 문자열).
var effect_handler: Callable
## 끝났으면 true, 그때의 결과 문자열.
var finished: bool = false
var result: String = ""

var _commands: Array[Dictionary] = []
var _pc: int = 0
var _labels: Dictionary = {}
var _pending_choice: Array = []
var _notices: Array[String] = []


func _init(commands: Array[Dictionary], p_flags: Dictionary = {}) -> void:
	_commands = commands
	flags = p_flags
	for i in _commands.size():
		if _commands[i].has("label"):
			_labels[_commands[i]["label"]] = i


static func from_script(script_id: String, p_flags: Dictionary = {}) -> DialogueRunner:
	return DialogueRunner.new(StoryScript.load_script(script_id), p_flags)


## 다음 장면을 돌려준다. 선택지를 보여 준 뒤에는 choose() 로 고르기 전까지 같은 선택지를 다시 돌려준다.
func advance() -> Dictionary:
	if not _pending_choice.is_empty():
		return {"kind": CHOICE, "options": _visible_options()}
	if not _notices.is_empty():
		return {"kind": NOTICE, "text": _notices.pop_front()}
	while _pc < _commands.size():
		var cmd: Dictionary = _commands[_pc]
		_pc += 1
		if cmd.has("say"):
			var speaker: String = cmd["say"]
			return {"kind": LINE, "speaker": speaker, "name": StoryCast.display_name(speaker), "text": cmd["text"], "side": _side_of(speaker)}
		if cmd.has("narrate"):
			return {"kind": NARRATION, "text": cmd["narrate"]}
		if cmd.has("choice"):
			_pending_choice = cmd["choice"]
			if _visible_options().is_empty():
				_pending_choice = []
				continue
			return {"kind": CHOICE, "options": _visible_options()}
		if cmd.has("end"):
			return _finish(cmd["end"])
		_apply(cmd)
		if not _notices.is_empty():
			return {"kind": NOTICE, "text": _notices.pop_front()}
	return _finish("")


## 보여 준 선택지 중 index 번째를 고른다 (_visible_options 기준 번호).
func choose(index: int) -> void:
	var options: Array = _visible_options()
	if index < 0 or index >= options.size():
		return
	var option: Dictionary = options[index]
	_pending_choice = []
	if option.has("goto"):
		_jump(option["goto"])


func _visible_options() -> Array:
	var out: Array = []
	for option in _pending_choice:
		if option.has("if") and not flags.has(option["if"]):
			continue
		out.append(option)
	return out


func _apply(cmd: Dictionary) -> void:
	if cmd.has("bg"):
		background = cmd["bg"]
	elif cmd.has("show"):
		var side: String = cmd["side"]
		# 같은 인물이 다른 쪽에 서 있으면 옮긴다.
		for s in portraits.keys():
			if portraits[s] == cmd["show"]:
				portraits.erase(s)
		portraits[side] = cmd["show"]
	elif cmd.has("hide"):
		if cmd["hide"] == "all":
			portraits.clear()
		else:
			portraits.erase(cmd["hide"])
	elif cmd.has("goto"):
		if cmd.has("if"):
			if flags.has(cmd["if"]):
				_jump(cmd["goto"])
		elif cmd.has("unless"):
			if not flags.has(cmd["unless"]):
				_jump(cmd["goto"])
		else:
			_jump(cmd["goto"])
	elif cmd.has("set"):
		flags[cmd["set"]] = true
	elif cmd.has("effect"):
		if effect_handler.is_valid():
			var message: String = effect_handler.call(cmd["effect"])
			if not message.is_empty():
				_notices.append(message)


func _jump(label: String) -> void:
	if not _labels.has(label):
		push_error("story label not found: %s" % label)
		return
	_pc = _labels[label]


func _side_of(speaker: String) -> String:
	for side in portraits:
		if portraits[side] == speaker:
			return side
	return "none"


func _finish(p_result: String) -> Dictionary:
	finished = true
	result = p_result
	_pc = _commands.size()
	return {"kind": END, "result": p_result}
