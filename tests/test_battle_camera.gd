# BattleCamera(타격 카메라 연출) 테스트. tick 에 실제 시간을 직접 넣어 검사한다.
extends TestCase


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 흔들림 세기.
	_test_shake_strength()
	# 히트스톱 → 복귀.
	_test_hit_stop()
	# 겹친 히트스톱.
	_test_overlapping_hit_stops()
	# 히트스톱 뒤 슬로모션.
	_test_slow_mo_after_hit_stop()
	# 히트스톱 없는 슬로모션.
	_test_slow_mo_alone()
	# 트리에서 빠질 때 복구.
	_test_exit_restores_time_scale()
	# 푸시인 수렴과 해제.
	_test_push()
	# 결과를 돌려준다.
	return results()


# 카메라를 단 연출 노드 (트리 밖).
func _fx() -> BattleCamera:
	# 연출 노드.
	var fx := BattleCamera.new()
	# 카메라.
	fx.camera = Camera3D.new()
	# 기본 구도.
	fx.set_base(Vector3(0.0, 5.0, 5.0), Basis.IDENTITY)
	# 돌려준다.
	return fx


# 연출 노드와 카메라를 지우고 시간 배율을 되돌린다.
func _done(fx: BattleCamera) -> void:
	# 카메라.
	fx.camera.free()
	# 연출 노드.
	fx.free()
	# 다른 테스트를 위해.
	Engine.time_scale = 1.0


# 피해에 비례하되 10 에서 멈추고, 처치는 1, 피해 0 은 기본 0.2.
func _test_shake_strength() -> void:
	# 피해 0.
	check("zero damage shake is the base", is_equal_approx(BattleCamera.shake_for_damage(0, false), 0.2))
	# 피해 5.
	check("half cap shake", is_equal_approx(BattleCamera.shake_for_damage(5, false), 0.55))
	# 상한.
	check("shake caps at 10 damage", is_equal_approx(BattleCamera.shake_for_damage(30, false), 0.9))
	# 처치.
	check("kill shakes fully", is_equal_approx(BattleCamera.shake_for_damage(0, true), 1.0))


# 히트스톱을 걸면 바로 0.05, 건 프레임의 시간은 빼지 않고, 다 지나면 1.
func _test_hit_stop() -> void:
	# 연출.
	var fx: BattleCamera = _fx()
	# 0.06초 멈춤.
	fx.hit_stop(0.06)
	# 바로 느려진다.
	check("hit stop slows time", is_equal_approx(Engine.time_scale, BattleCamera.HIT_STOP_SCALE))
	# 건 프레임.
	fx.tick(0.05)
	# 아직 멈춤.
	check("hit stop survives its own frame", is_equal_approx(Engine.time_scale, BattleCamera.HIT_STOP_SCALE))
	# 0.05 지남.
	fx.tick(0.05)
	# 아직.
	check("hit stop still running", is_equal_approx(Engine.time_scale, BattleCamera.HIT_STOP_SCALE))
	# 0.1 지남 (> 0.06).
	fx.tick(0.05)
	# 복귀.
	check("hit stop ends", is_equal_approx(Engine.time_scale, 1.0))
	# 정리.
	_done(fx)


# 짧은 히트스톱 뒤에 긴 것이 오면 긴 것만큼, 긴 것 뒤에 짧은 것이 와도 긴 것만큼.
func _test_overlapping_hit_stops() -> void:
	# 연출.
	var fx: BattleCamera = _fx()
	# 긴 것 먼저.
	fx.hit_stop(0.1)
	# 건 프레임.
	fx.tick(0.0)
	# 짧은 것.
	fx.hit_stop(0.06)
	# 건 프레임.
	fx.tick(0.0)
	# 0.08 지남.
	fx.tick(0.08)
	# 긴 쪽이 남아 아직 멈춤.
	check("overlapping hit stops keep the longest", is_equal_approx(Engine.time_scale, BattleCamera.HIT_STOP_SCALE))
	# 0.04 더.
	fx.tick(0.04)
	# 끝.
	check("longest hit stop ends", is_equal_approx(Engine.time_scale, 1.0))
	# 정리.
	_done(fx)


# 처치: 히트스톱이 끝나면 0.3 이 실제 0.35초 이어지고 1.
func _test_slow_mo_after_hit_stop() -> void:
	# 연출.
	var fx: BattleCamera = _fx()
	# 처치 연출.
	fx.hit_stop(0.1)
	fx.kill_slow_mo()
	# 건 프레임.
	fx.tick(0.0)
	# 히트스톱 중엔 그대로 0.05.
	check("slow mo waits for hit stop", is_equal_approx(Engine.time_scale, BattleCamera.HIT_STOP_SCALE))
	# 히트스톱 끝.
	fx.tick(0.11)
	# 슬로모션.
	check("slow mo follows hit stop", is_equal_approx(Engine.time_scale, BattleCamera.SLOW_MO_SCALE))
	# 0.3 지남.
	fx.tick(0.3)
	# 아직.
	check("slow mo lasts", is_equal_approx(Engine.time_scale, BattleCamera.SLOW_MO_SCALE))
	# 0.36 지남.
	fx.tick(0.06)
	# 복귀.
	check("slow mo ends", is_equal_approx(Engine.time_scale, 1.0))
	# 정리.
	_done(fx)


# 히트스톱 없이 불러도 다음 tick 에서 바로 슬로모션.
func _test_slow_mo_alone() -> void:
	# 연출.
	var fx: BattleCamera = _fx()
	# 슬로모션만.
	fx.kill_slow_mo()
	# 다음 프레임.
	fx.tick(0.016)
	# 0.3.
	check("slow mo without hit stop", is_equal_approx(Engine.time_scale, BattleCamera.SLOW_MO_SCALE))
	# 정리.
	_done(fx)


# 멈춘 채 트리에서 빠지면 시간 배율이 1 로 돌아온다.
func _test_exit_restores_time_scale() -> void:
	# 연출을 트리에 붙인다.
	var fx: BattleCamera = _fx()
	(Engine.get_main_loop() as SceneTree).root.add_child(fx)
	# 처치 연출 중.
	fx.hit_stop(0.1)
	fx.kill_slow_mo()
	# 빠진다.
	(Engine.get_main_loop() as SceneTree).root.remove_child(fx)
	# 복구.
	check("exit tree restores time scale", is_equal_approx(Engine.time_scale, 1.0))
	# 정리.
	_done(fx)


# 푸시인은 목표 쪽 12% 로 수렴하고, release 하면 0 으로 돌아온다. 카메라 위치에 반영된다.
func _test_push() -> void:
	# 연출.
	var fx: BattleCamera = _fx()
	# 원점 쪽으로.
	fx.push_toward(Vector3.ZERO)
	# 충분히 흐른다.
	for i in 60:
		fx.tick(0.05)
	# 목표 = (0,−5,−5)×0.12.
	check("push converges to 12 percent", fx.push_offset().is_equal_approx(Vector3(0.0, -0.6, -0.6)))
	# 카메라가 옮겨졌다.
	check("camera follows the push", fx.camera.position.is_equal_approx(Vector3(0.0, 4.4, 4.4)))
	# 해제.
	fx.release()
	for i in 60:
		fx.tick(0.05)
	# 원래대로.
	check("release returns home", fx.push_offset().is_equal_approx(Vector3.ZERO))
	# 정리.
	_done(fx)
