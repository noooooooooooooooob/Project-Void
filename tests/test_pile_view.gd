# PileView(덱·묘지 더미 화면) 테스트: 글자, 흐림, 중심 좌표.
extends TestCase


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 장수·이름 글자.
	_test_labels()
	# 흐림 켜기/끄기.
	_test_dimming()
	# 중심 좌표 계산.
	_test_center()
	# 결과를 돌려준다.
	return results()


# 장수는 0 으로 시작하고, set_count / set_owner_name 이 글자를 바꾸는지.
func _test_labels() -> void:
	# 더미를 만든다 (_init 에서 자식 노드가 만들어진다).
	var pile := PileView.new()
	# 처음 장수는 "0".
	check_eq("starts at zero", pile.count_text(), "0")
	# 장수를 7 로 바꾼다.
	pile.set_count(7)
	# 글자가 "7" 이 됐는지.
	check_eq("count text", pile.count_text(), "7")
	# 이름을 바꾼다.
	pile.set_owner_name("선봉")
	# 이름 글자가 바뀌었는지.
	check_eq("owner text", pile.owner_text(), "선봉")
	# 트리에 붙이지 않은 노드는 직접 지워야 한다.
	pile.free()


# set_dimmed 로 흐림 상태가 켜지고 꺼지는지.
func _test_dimming() -> void:
	# 더미를 만든다.
	var pile := PileView.new()
	# 흐리게.
	pile.set_dimmed(true)
	# 흐림 상태인지.
	check("dimmed", pile.is_dimmed())
	# 또렷하게.
	pile.set_dimmed(false)
	# 흐림이 풀렸는지.
	check("not dimmed", not pile.is_dimmed())
	# 지운다.
	pile.free()


# center_global 이 화면 좌표 기준으로 더미 가운데를 돌려주는지.
func _test_center() -> void:
	# 더미를 만든다.
	var pile := PileView.new()
	# 전역 좌표가 의미 있도록 루트 창에 붙인다.
	(Engine.get_main_loop() as SceneTree).root.add_child(pile)
	# 왼쪽 위를 (100, 200) 에 둔다.
	pile.position = Vector2(100, 200)
	# 크기 90×126 의 절반을 더한 (145, 263) 이어야 한다.
	check("center of the pile in viewport coordinates", pile.center_global().is_equal_approx(Vector2(145, 263)))
	# 지운다.
	pile.free()
