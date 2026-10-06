# Projectile(원거리 화살) 테스트: 비행 시간, 궤적, 그림 없이 만들기.
extends TestCase


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 비행 시간.
	_test_flight_time()
	# 궤적.
	_test_position_at()
	# 만들기.
	_test_spawn()
	# 결과를 돌려준다.
	return results()


# 가까우면 하한, 멀면 상한, 중간은 거리/16.
func _test_flight_time() -> void:
	# 하한.
	check("near flight clamps low", is_equal_approx(Projectile.flight_time(0.5), Projectile.MIN_FLIGHT))
	# 상한.
	check("far flight clamps high", is_equal_approx(Projectile.flight_time(20.0), Projectile.MAX_FLIGHT))
	# 비례.
	check("mid flight is proportional", is_equal_approx(Projectile.flight_time(4.0), 0.25))


# 양 끝은 출발·도착, 가운데는 직선보다 arc 만큼 높다.
func _test_position_at() -> void:
	# 출발·도착.
	var from := Vector3(0.0, 1.0, 0.0)
	var to := Vector3(4.0, 1.0, 0.0)
	# 시작.
	check("starts at from", Projectile.position_at(from, to, 0.24, 0.0).is_equal_approx(from))
	# 끝.
	check("ends at to", Projectile.position_at(from, to, 0.24, 1.0).is_equal_approx(to))
	# 가운데 = 직선 중점 + arc.
	check("arcs above the line", Projectile.position_at(from, to, 0.24, 0.5).is_equal_approx(Vector3(2.0, 1.24, 0.0)))


# 그림이 없어도 만들어지고, 거리로 비행 시간과 포물선을 정하고, 출발점에 놓인다.
func _test_spawn() -> void:
	# 부모.
	var parent := Node3D.new()
	# 그림 없이 4 거리.
	var arrow: Projectile = Projectile.spawn(parent, null, Vector3.ZERO, Vector3(4.0, 0.0, 0.0))
	# 부모에 붙었다.
	check("spawned under parent", arrow.get_parent() == parent)
	# 비행 시간.
	check("duration from distance", is_equal_approx(arrow.duration, 0.25))
	# 대체 그림이 들어간 판.
	check("fallback texture without art", (arrow.mesh.material_override as StandardMaterial3D).albedo_texture != null)
	# 판 길이.
	check("arrow length", is_equal_approx((arrow.mesh.mesh as QuadMesh).size.x, Projectile.LENGTH))
	# 출발점.
	check("placed at the start", arrow.position.is_equal_approx(Vector3.ZERO))
	# 정리.
	parent.free()
