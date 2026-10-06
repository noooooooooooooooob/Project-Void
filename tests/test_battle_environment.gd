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
	var room := BattleRoomData.new()
	room.ground_texture = ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	room.wall_texture = ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	var props: Array[PropPlacement] = []
	for x in [-5.0, 5.0]:
		var prop := PropPlacement.new()
		prop.texture = ImageTexture.create_from_image(Image.create(32, 64, false, Image.FORMAT_RGBA8))
		prop.position = Vector3(x, 0.0, -3.0)
		prop.height = 1.2
		props.append(prop)
	room.props = props
	return room


# 방이 없으면 아무것도 만들지 않는다.
func _test_no_room() -> void:
	check("no room builds nothing", BattleEnvironment.build(BoardLayout.new(Vector2i(3, 3), Vector2i(2, 2)), null) == null)


# 바닥 1, 벽 3, 소품 2, 창문 빛 2. 바닥은 보드 아래, 소품은 비율대로 높이를 맞춘다.
func _test_parts() -> void:
	var env: BattleEnvironment = BattleEnvironment.build(BoardLayout.new(Vector2i(3, 3), Vector2i(2, 2)), _room())
	check("ground built", env.ground != null)
	check("ground sits under the tiles", is_equal_approx(env.ground.position.y, -Board3D.TILE_THICKNESS))
	check("three walls", env.back_wall != null and env.left_wall != null and env.right_wall != null)
	check_eq("props built", env.props.size(), 2)
	check_eq("two window lights", env.lights.size(), 2)
	# 32×64 그림, 높이 1.2 → 폭 0.6.
	var quad: QuadMesh = (env.props[0].get_child(0) as MeshInstance3D).mesh
	check("prop keeps its aspect", quad.size.is_equal_approx(Vector2(0.6, 1.2)))
	check("prop stands at its floor spot", is_equal_approx(env.props[0].position.x, -5.0) and is_equal_approx(env.props[0].position.z, -3.0))
	env.free()


# 뒷벽은 가장 먼 행 너머(−z), 옆벽은 보드 좌우 끝 바깥.
func _test_walls_outside(ally_grid: Vector2i, enemy_grid: Vector2i) -> void:
	var layout := BoardLayout.new(ally_grid, enemy_grid)
	var env: BattleEnvironment = BattleEnvironment.build(layout, _room())
	var label: String = "%s/%s" % [ally_grid, enemy_grid]
	check("walls stand outside the board: back %s" % label, env.back_wall.position.z < -layout.depth() / 2.0)
	check("walls stand outside the board: left %s" % label, env.left_wall.position.x < layout.min_x())
	check("walls stand outside the board: right %s" % label, env.right_wall.position.x > layout.max_x())
	# 옆벽은 보드 쪽을 본다 (판의 앞 +Z 가 안쪽).
	check("left wall faces the board %s" % label, env.left_wall.global_basis.z.x > 0.9 if env.is_inside_tree() else env.left_wall.basis.z.x > 0.9)
	env.free()


# 방의 어떤 노드도 클릭 광선에 걸리지 않는다.
func _test_no_colliders() -> void:
	var env: BattleEnvironment = BattleEnvironment.build(BoardLayout.new(Vector2i(3, 3), Vector2i(2, 2)), _room())
	check("room has no colliders", env.find_children("*", "CollisionObject3D", true, false).is_empty())
	env.free()


# 실내 분위기: 앰비언트·안개·볼류메트릭 포그·SSAO·글로우·색 보정, 태양은 약하게·그림자.
func _test_atmosphere() -> void:
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	BattleEnvironment.apply_atmosphere(env, sun)
	check_eq("ambient colour", env.ambient_light_color, BattleEnvironment.AMBIENT_COLOR)
	check("depth fog", env.fog_enabled and is_equal_approx(env.fog_density, BattleEnvironment.FOG_DENSITY))
	check("volumetric fog for light shafts", env.volumetric_fog_enabled)
	check("ssao on", env.ssao_enabled)
	check("glow on", env.glow_enabled and is_equal_approx(env.glow_hdr_threshold, 0.9) and is_equal_approx(env.glow_intensity, 0.5))
	check("muted colours", env.adjustment_enabled and is_equal_approx(env.adjustment_saturation, 0.82) and is_equal_approx(env.adjustment_contrast, 1.08))
	check("weak sun with shadows", is_equal_approx(sun.light_energy, BattleEnvironment.SUN_ENERGY) and sun.shadow_enabled)
	# 태양은 안개를 밝히지 않는다 (빛기둥은 창문 빛만).
	check("sun does not light the fog", is_equal_approx(sun.light_volumetric_fog_energy, 0.0))
	sun.free()
