# 대본 파서(StoryScript)와 진행기(DialogueRunner) 테스트.
extends TestCase


func run() -> Array[Dictionary]:
	_test_parses_lines_narration_and_commands()
	_test_groups_consecutive_choice_lines()
	_test_unknown_speaker_becomes_narration()
	_test_runner_walks_lines_and_applies_state()
	_test_choice_jumps_to_label()
	_test_conditional_options_and_jumps()
	_test_effects_produce_notices()
	_test_end_reports_result()
	_test_every_story_file_parses()
	return results()


func _test_parses_lines_narration_and_commands() -> void:
	var cmds: Array[Dictionary] = StoryScript.parse("// 주석\n@bg office\nhongyeon: 안녕\n> 비가 온다\n@show hongyeon left\n@effect gold 30\n@end done")
	check_eq("six commands (comment skipped)", cmds.size(), 6)
	check_eq("background", cmds[0], {"bg": "office"})
	check_eq("dialogue line", cmds[1], {"say": "hongyeon", "text": "안녕"})
	check_eq("narration", cmds[2], {"narrate": "비가 온다"})
	check_eq("show", cmds[3], {"show": "hongyeon", "side": "left"})
	check_eq("effect", cmds[4], {"effect": {"type": "gold", "args": ["30"]}})
	check_eq("end", cmds[5], {"end": "done"})


func _test_groups_consecutive_choice_lines() -> void:
	var cmds: Array[Dictionary] = StoryScript.parse("* 간다 -> a\n* [brave] 뛰어든다 -> b\n> 끝")
	check_eq("one choice command then narration", cmds.size(), 2)
	var options: Array = cmds[0]["choice"]
	check_eq("two options", options.size(), 2)
	check_eq("plain option", options[0], {"text": "간다", "goto": "a"})
	check_eq("conditional option", options[1], {"text": "뛰어든다", "goto": "b", "if": "brave"})


func _test_unknown_speaker_becomes_narration() -> void:
	var cmds: Array[Dictionary] = StoryScript.parse("시간: 새벽 3시")
	check_eq("not a cast id -> narration", cmds[0], {"narrate": "시간: 새벽 3시"})


func _test_runner_walks_lines_and_applies_state() -> void:
	var runner := DialogueRunner.new(StoryScript.parse("@bg office\n@show hongyeon right\nhongyeon: 졸려\n@hide right\nhongyeon: 잘게"))
	var first: Dictionary = runner.advance()
	check_eq("background applied before the first line", runner.background, "office")
	check_eq("line kind", first["kind"], DialogueRunner.LINE)
	check_eq("speaker name", first["name"], "홍연")
	check_eq("speaker stands on the right", first["side"], "right")
	var second: Dictionary = runner.advance()
	check_eq("hidden speaker has no side", second["side"], "none")
	check_eq("then the script ends", runner.advance()["kind"], DialogueRunner.END)
	check("runner reports finished", runner.finished)


func _test_choice_jumps_to_label() -> void:
	var runner := DialogueRunner.new(StoryScript.parse("* 왼쪽 -> l\n* 오른쪽 -> r\n@label l\n> 왼쪽으로 갔다\n@end left\n@label r\n> 오른쪽으로 갔다\n@end right"))
	var beat: Dictionary = runner.advance()
	check_eq("choice shown", beat["kind"], DialogueRunner.CHOICE)
	check_eq("the same choice repeats until chosen", runner.advance()["kind"], DialogueRunner.CHOICE)
	runner.choose(1)
	check_eq("jumped to the chosen branch", runner.advance()["text"], "오른쪽으로 갔다")
	check_eq("result of that branch", runner.advance()["result"], "right")


func _test_conditional_options_and_jumps() -> void:
	var flags: Dictionary = {"met": true}
	var runner := DialogueRunner.new(StoryScript.parse("@if met known\n> 처음 본다\n@label known\n* [met] 아는 척 -> a\n* [secret] 비밀 -> b\n@label a\n@set greeted\n@end"), flags)
	var beat: Dictionary = runner.advance()
	check_eq("@if skipped the first-meeting line and showed the choice", beat["kind"], DialogueRunner.CHOICE)
	check_eq("only the option whose flag is set is visible", beat["options"].size(), 1)
	runner.choose(0)
	runner.advance()
	check("@set writes into the shared flags", flags.has("greeted"))


func _test_effects_produce_notices() -> void:
	var runner := DialogueRunner.new(StoryScript.parse("@effect gold 30\n> 다음"))
	var seen: Array = []
	runner.effect_handler = func(effect: Dictionary) -> String:
		seen.append(effect)
		return "자금 +30"
	var beat: Dictionary = runner.advance()
	check_eq("effect handler received the effect", seen, [{"type": "gold", "args": ["30"]}])
	check_eq("its message is shown as a notice", beat, {"kind": DialogueRunner.NOTICE, "text": "자금 +30"})
	check_eq("then the story continues", runner.advance()["text"], "다음")


func _test_end_reports_result() -> void:
	var runner := DialogueRunner.new(StoryScript.parse("> 하나"))
	runner.advance()
	var beat: Dictionary = runner.advance()
	check_eq("running off the end finishes with an empty result", beat, {"kind": DialogueRunner.END, "result": ""})


## 실제 대본 파일들이 모두 읽히고, goto 라벨이 존재하며, 등장인물 id 가 올바른지.
func _test_every_story_file_parses() -> void:
	var files: Array[String] = []
	_collect(StoryScript.STORY_DIR, "", files)
	check("there are story files", files.size() > 0)
	for script_id in files:
		var cmds: Array[Dictionary] = StoryScript.load_script(script_id)
		check("%s has commands" % script_id, cmds.size() > 0)
		var labels: Dictionary = {}
		for c in cmds:
			if c.has("label"):
				labels[c["label"]] = true
		for c in cmds:
			if c.has("goto"):
				check("%s: label %s exists" % [script_id, c["goto"]], labels.has(c["goto"]))
			if c.has("choice"):
				for option in c["choice"]:
					if option.has("goto"):
						check("%s: choice label %s exists" % [script_id, option["goto"]], labels.has(option["goto"]))
			if c.has("show"):
				check("%s: cast %s exists" % [script_id, c["show"]], StoryCast.has(c["show"]))


func _collect(dir_path: String, prefix: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".txt"):
			out.append(prefix + f.get_basename())
	for d in dir.get_directories():
		_collect("%s/%s" % [dir_path, d], prefix + d + "/", out)
