# BattleEnvironment(전투 방) 테스트: 방 없으면 없음, 바닥·벽 3면·소품·빛, 벽은 보드 바깥, 충돌체 없음.
extends TestCase


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 방 없음.
	_test_no_room()
	# 구성 요소.
	_test_parts()
	# 벽 위치 (두 격자).
	_test_walls_outside(Vector2i(3, 3), Vector2i(2, 2))
	_test_walls_outside(Vector2i(3, 3), Vector2i(3, 3))
	# 충돌체 없음.
	_test_no_colliders()
	# 실내 분위기.
	_test_atmosphere()
	# 결과를 돌려준다.
	return results()


# 텍스처 두 장과 소품 2개짜리 방.
func _room() -> BattleRoomData:
	# 방 데이터.
	var room := BattleRoomData.new()
	# 8×8 빈 바닥 그림.
	room.ground_texture = ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	# 8×8 빈 벽 그림.
	room.wall_texture = ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	# 소품 목록.
	var props: Array[PropPlacement] = []
	# 왼쪽(-5)과 오른쪽(5)에 하나씩.
	for x in [-5.0, 5.0]:
		# 소품 배치.
		var prop := PropPlacement.new()
		# 32×64 세로로 긴 그림.
		prop.texture = ImageTexture.create_from_image(Image.create(32, 64, false, Image.FORMAT_RGBA8))
		# 바닥 위치.
		prop.position = Vector3(x, 0.0, -3.0)
		# 높이.
		prop.height = 1.2
		# 목록에 넣는다.
		props.append(prop)
	# 방에 소품을 넣는다.
	room.props = props
	# 돌려준다.
	return room


# 방이 없으면 아무것도 만들지 않는다.
func _test_no_room() -> void:
	# null 방이면 null.
	check("no room builds nothing", BattleEnvironment.build(BoardLayout.new(Vector2i(3, 3), Vector2i(2, 2)), null) == null)


# 바닥 1, 벽 3, 소품 2, 창문 빛 2. 바닥은 보드 아래, 소품은 비율대로 높이를 맞춘다.
func _test_parts() -> void:
	# 방을 만든다.
	var env: BattleEnvironment = BattleEnvironment.build(BoardLayout.new(Vector2i(3, 3), Vector2i(2, 2)), _room())
	# 바닥이 있다.
	check("ground built", env.ground != null)
	# 바닥은 칸 두께만큼 아래.
	check("ground sits under the tiles", is_equal_approx(env.ground.position.y, -Board3D.TILE_THICKNESS))
	# 벽 세 면.
	check("three walls", env.back_wall != null and env.left_wall != null and env.right_wall != null)
	# 소품 둘.
	check_eq("props built", env.props.size(), 2)
	# 창문 빛 둘.
	check_eq("two window lights", env.lights.size(), 2)
	# 32×64 그림, 높이 1.2 → 폭 0.6.
	var quad: QuadMesh = (env.props[0].get_child(0) as MeshInstance3D).mesh
	# 비율이 맞다.
	check("prop keeps its aspect", quad.size.is_equal_approx(Vector2(0.6, 1.2)))
	# 정해진 바닥 위치에 선다.
	check("prop stands at its floor spot", is_equal_approx(env.props[0].position.x, -5.0) and is_equal_approx(env.props[0].position.z, -3.0))
	# 정리한다.
	env.free()


# 뒷벽은 가장 먼 행 너머(−z), 옆벽은 보드 좌우 끝 바깥.
func _test_walls_outside(ally_grid: Vector2i, enemy_grid: Vector2i) -> void:
	# 보드 배치.
	var layout := BoardLayout.new(ally_grid, enemy_grid)
	# 방을 만든다.
	var env: BattleEnvironment = BattleEnvironment.build(layout, _room())
	# 검사 이름에 붙일 격자 표시.
	var label: String = "%s/%s" % [ally_grid, enemy_grid]
	# 뒷벽은 보드 뒤.
	check("walls stand outside the board: back %s" % label, env.back_wall.position.z < -layout.depth() / 2.0)
	# 왼쪽 벽은 보드 왼쪽 바깥.
	check("walls stand outside the board: left %s" % label, env.left_wall.position.x < layout.min_x())
	# 오른쪽 벽은 보드 오른쪽 바깥.
	check("walls stand outside the board: right %s" % label, env.right_wall.position.x > layout.max_x())
	# 옆벽은 보드 쪽을 본다 (판의 앞 +Z 가 안쪽).
	check("left wall faces the board %s" % label, env.left_wall.global_basis.z.x > 0.9 if env.is_inside_tree() else env.left_wall.basis.z.x > 0.9)
	# 정리한다.
	env.free()


# 방의 어떤 노드도 클릭 광선에 걸리지 않는다.
func _test_no_colliders() -> void:
	# 방을 만든다.
	var env: BattleEnvironment = BattleEnvironment.build(BoardLayout.new(Vector2i(3, 3), Vector2i(2, 2)), _room())
	# 충돌체가 하나도 없다.
	check("room has no colliders", env.find_children("*", "CollisionObject3D", true, false).is_empty())
	# 정리한다.
	env.free()


# 실내 분위기: 앰비언트·안개·볼류메트릭 포그·SSAO·글로우·색 보정, 태양은 약하게·그림자.
func _test_atmosphere() -> void:
	# 빈 환경.
	var env := Environment.new()
	# 태양.
	var sun := DirectionalLight3D.new()
	# 분위기를 입힌다.
	BattleEnvironment.apply_atmosphere(env, sun)
	# 앰비언트 색.
	check_eq("ambient colour", env.ambient_light_color, BattleEnvironment.AMBIENT_COLOR)
	# 거리 안개.
	check("depth fog", env.fog_enabled and is_equal_approx(env.fog_density, BattleEnvironment.FOG_DENSITY))
	# 볼류메트릭 포그.
	check("volumetric fog for light shafts", env.volumetric_fog_enabled)
	# SSAO.
	check("ssao on", env.ssao_enabled)
	# 글로우.
	check("glow on", env.glow_enabled and is_equal_approx(env.glow_hdr_threshold, 0.9) and is_equal_approx(env.glow_intensity, 0.5))
	# 색 보정.
	check("muted colours", env.adjustment_enabled and is_equal_approx(env.adjustment_saturation, 0.82) and is_equal_approx(env.adjustment_contrast, 1.08))
	# 약한 태양 + 그림자.
	check("weak sun with shadows", is_equal_approx(sun.light_energy, BattleEnvironment.SUN_ENERGY) and sun.shadow_enabled)
	# 태양은 안개를 밝히지 않는다 (빛기둥은 창문 빛만).
	check("sun does not light the fog", is_equal_approx(sun.light_volumetric_fog_energy, 0.0))
	# 정리한다 (Environment 는 리소스라 자동 해제된다).
	sun.free()
