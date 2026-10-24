# BattleCamera(타격 카메라 연출) 테스트. tick 에 실제 시간을 직접 넣어 검사한다.
extends TestCase


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	_test_shake_strength()
	_test_hit_stop()
	_test_overlapping_hit_stops()
	_test_slow_mo_after_hit_stop()
	_test_slow_mo_alone()
	_test_exit_restores_time_scale()
	_test_push()
	return results()


# 카메라를 단 연출 노드 (트리 밖).
func _fx() -> BattleCamera:
	var fx := BattleCamera.new()
	fx.camera = Camera3D.new()
	fx.set_base(Vector3(0.0, 5.0, 5.0), Basis.IDENTITY)
	return fx


# 연출 노드와 카메라를 지우고 시간 배율을 되돌린다.
func _done(fx: BattleCamera) -> void:
	fx.camera.free()
	fx.free()
	Engine.time_scale = 1.0


# 피해에 비례하되 10 에서 멈추고, 처치는 1, 피해 0 은 기본 0.2.
func _test_shake_strength() -> void:
	# 피해 0.
	check("zero damage shake is the base", is_equal_approx(BattleCamera.shake_for_damage(0, false), 0.2))
	# 피해 5.
	check("half cap shake", is_equal_approx(BattleCamera.shake_for_damage(5, false), 0.55))
	check("shake caps at 10 damage", is_equal_approx(BattleCamera.shake_for_damage(30, false), 0.9))
	check("kill shakes fully", is_equal_approx(BattleCamera.shake_for_damage(0, true), 1.0))


# 히트스톱을 걸면 바로 0.05, 건 프레임의 시간은 빼지 않고, 다 지나면 1.
func _test_hit_stop() -> void:
	var fx: BattleCamera = _fx()
	# 0.06초 멈춤.
	fx.hit_stop(0.06)
	check("hit stop slows time", is_equal_approx(Engine.time_scale, BattleCamera.HIT_STOP_SCALE))
	fx.tick(0.05)
	check("hit stop survives its own frame", is_equal_approx(Engine.time_scale, BattleCamera.HIT_STOP_SCALE))
	# 0.05 지남.
	fx.tick(0.05)
	check("hit stop still running", is_equal_approx(Engine.time_scale, BattleCamera.HIT_STOP_SCALE))
	# 0.1 지남 (> 0.06).
	fx.tick(0.05)
	check("hit stop ends", is_equal_approx(Engine.time_scale, 1.0))
	_done(fx)


# 짧은 히트스톱 뒤에 긴 것이 오면 긴 것만큼, 긴 것 뒤에 짧은 것이 와도 긴 것만큼.
func _test_overlapping_hit_stops() -> void:
	var fx: BattleCamera = _fx()
	fx.hit_stop(0.1)
	fx.tick(0.0)
	fx.hit_stop(0.06)
	fx.tick(0.0)
	# 0.08 지남.
	fx.tick(0.08)
	check("overlapping hit stops keep the longest", is_equal_approx(Engine.time_scale, BattleCamera.HIT_STOP_SCALE))
	# 0.04 더.
	fx.tick(0.04)
	check("longest hit stop ends", is_equal_approx(Engine.time_scale, 1.0))
	_done(fx)


# 처치: 히트스톱이 끝나면 0.3 이 실제 0.35초 이어지고 1.
func _test_slow_mo_after_hit_stop() -> void:
	var fx: BattleCamera = _fx()
	fx.hit_stop(0.1)
	fx.kill_slow_mo()
	fx.tick(0.0)
	# 히트스톱 중엔 그대로 0.05.
	check("slow mo waits for hit stop", is_equal_approx(Engine.time_scale, BattleCamera.HIT_STOP_SCALE))
	fx.tick(0.11)
	check("slow mo follows hit stop", is_equal_approx(Engine.time_scale, BattleCamera.SLOW_MO_SCALE))
	# 0.3 지남.
	fx.tick(0.3)
	check("slow mo lasts", is_equal_approx(Engine.time_scale, BattleCamera.SLOW_MO_SCALE))
	# 0.36 지남.
	fx.tick(0.06)
	check("slow mo ends", is_equal_approx(Engine.time_scale, 1.0))
	_done(fx)


# 히트스톱 없이 불러도 다음 tick 에서 바로 슬로모션.
func _test_slow_mo_alone() -> void:
	var fx: BattleCamera = _fx()
	fx.kill_slow_mo()
	fx.tick(0.016)
	# 0.3.
	check("slow mo without hit stop", is_equal_approx(Engine.time_scale, BattleCamera.SLOW_MO_SCALE))
	_done(fx)


# 멈춘 채 트리에서 빠지면 시간 배율이 1 로 돌아온다.
func _test_exit_restores_time_scale() -> void:
	var fx: BattleCamera = _fx()
	(Engine.get_main_loop() as SceneTree).root.add_child(fx)
	fx.hit_stop(0.1)
	fx.kill_slow_mo()
	(Engine.get_main_loop() as SceneTree).root.remove_child(fx)
	check("exit tree restores time scale", is_equal_approx(Engine.time_scale, 1.0))
	_done(fx)


# 푸시인은 목표 쪽 12% 로 수렴하고, release 하면 0 으로 돌아온다. 카메라 위치에 반영된다.
func _test_push() -> void:
	var fx: BattleCamera = _fx()
	fx.push_toward(Vector3.ZERO)
	for i in 60:
		fx.tick(0.05)
	# 목표 = (0,−5,−5)×0.12.
	check("push converges to 12 percent", fx.push_offset().is_equal_approx(Vector3(0.0, -0.6, -0.6)))
	check("camera follows the push", fx.camera.position.is_equal_approx(Vector3(0.0, 4.4, 4.4)))
	fx.release()
	for i in 60:
		fx.tick(0.05)
	check("release returns home", fx.push_offset().is_equal_approx(Vector3.ZERO))
	_done(fx)
