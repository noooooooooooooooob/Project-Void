# ScreenPulse(화면 펄스) 테스트: 올랐다가 실제 0.4초에 가라앉고, 셰이더 값에 반영되고, 클릭을 막지 않는지.
extends TestCase


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 펄스와 가라앉기.
	_test_pulse_and_decay()
	# 겹친 펄스.
	_test_stronger_pulse_wins()
	# 덮개 설정.
	_test_overlay()
	# 결과를 돌려준다.
	return results()


# 처치 펄스 1 → 색수차 1·비네트 0.63, 0.2초 뒤 절반, 0.4초 뒤 기본값.
func _test_pulse_and_decay() -> void:
	# 펄스.
	var fx := ScreenPulse.new()
	# 평소.
	check("rests at the base vignette", is_equal_approx(fx.material.get_shader_parameter("vignette"), ScreenPulse.BASE_VIGNETTE))
	# 처치.
	fx.pulse(1.0)
	# 오른다.
	check("pulse raises chromatic", is_equal_approx(fx.material.get_shader_parameter("chromatic"), 1.0))
	check("pulse tightens the vignette", is_equal_approx(fx.material.get_shader_parameter("vignette"), 0.63))
	# 0.2초.
	fx.tick(0.2)
	# 절반.
	check("pulse decays linearly", is_equal_approx(fx.level(), 0.5))
	# 0.4초.
	fx.tick(0.2)
	# 기본값.
	check("pulse settles", is_equal_approx(fx.level(), 0.0) and is_equal_approx(fx.material.get_shader_parameter("vignette"), ScreenPulse.BASE_VIGNETTE))
	# 정리.
	fx.free()


# 약한 펄스가 센 펄스를 덮어쓰지 않는다.
func _test_stronger_pulse_wins() -> void:
	# 펄스.
	var fx := ScreenPulse.new()
	# 센 것 다음 약한 것.
	fx.pulse(1.0)
	fx.pulse(0.5)
	# 1 유지.
	check("weaker pulse does not lower the level", is_equal_approx(fx.level(), 1.0))
	# 정리.
	fx.free()


# 덮개는 화면 전체를 덮고 마우스를 통과시키며, HUD 보다 아래 층이다.
func _test_overlay() -> void:
	# 펄스.
	var fx := ScreenPulse.new()
	# 마우스 무시.
	check("pulse overlay ignores the mouse", fx.overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	# 전체 화면.
	check("overlay fills the screen", is_equal_approx(fx.overlay.anchor_right, 1.0) and is_equal_approx(fx.overlay.anchor_bottom, 1.0))
	# HUD(1) 아래.
	check("overlay sits under the hud layer", fx.layer < 1)
	# 정리.
	fx.free()
