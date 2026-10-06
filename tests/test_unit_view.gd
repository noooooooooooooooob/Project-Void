# UnitView(3D 유닛 화면) 테스트: 자식 구성, 체력 글자·막대, 부분 갱신, 원래 자리·생존 표시.
# 트리에 붙이지 않고 setup 결과만 확인하므로 렌더링 없이 돈다.
extends TestCase

# 아군 데이터 스크립트.
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
# 적 데이터 스크립트.
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# setup 이 몸·셰이더·고리·클릭 몸체를 만드는지.
	_test_setup_builds_parts()
	# 체력 글자와 막대 폭·위치.
	_test_stats_text_and_bar()
	# 체력·방어도를 따로 갱신.
	_test_partial_updates()
	# 원래 자리와 생존 표시.
	_test_home_and_alive()
	# 애니메이션 띠 프레임 선택.
	_test_sheet_frames()
	# 띠 유무에 따른 대기 동작과 연출 시간.
	_test_idle_and_durations()
	# 자세 적용과 되돌리기.
	_test_pose_and_reset()
	# 빌보드 회전 계산.
	_test_billboard_rotation()
	# 오라 입자.
	_test_aura()
	# 맞는 순간 이펙트.
	_test_impact()
	# 피해 숫자 크기.
	_test_pop_scale()
	# 결과를 돌려준다.
	return results()


# 10×20 픽셀짜리 빈 텍스처를 만든다 (높이 20 으로 픽셀 크기 계산을 검사하기 위해).
func _texture() -> Texture2D:
	# 빈 이미지로 텍스처를 만든다.
	return ImageTexture.create_from_image(Image.create(10, 20, false, Image.FORMAT_RGBA8))


# 체력 30 짜리 테스트 유닛 화면을 만든다. ally 가 true 면 아군. sheets 는 [idle, attack, hit] (null 허용).
func _view(ally: bool, sheets: Array = [null, null, null]) -> UnitView:
	# 편에 맞는 데이터.
	var data: UnitData = AllyDataScript.new() if ally else EnemyDataScript.new()
	# id.
	data.id = &"tester"
	# 이름.
	data.display_name = "테스터"
	# 최대 체력.
	data.max_hp = 30
	# 대기 띠.
	data.idle_sheet = sheets[0]
	# 공격 띠.
	data.attack_sheet = sheets[1]
	# 피격 띠.
	data.hit_sheet = sheets[2]
	# 편.
	var team: Unit.Team = Unit.Team.ALLY if ally else Unit.Team.ENEMY
	# 화면 객체.
	var view := UnitView.new()
	# 규칙 유닛과 텍스처로 채운다.
	view.setup(Unit.new(0, data, team, Vector2i(0, 1)), _texture())
	# 돌려준다.
	return view


# 64px 프레임 16장짜리 빈 띠 (1024×64).
func _sheet() -> Texture2D:
	# 빈 이미지로 텍스처를 만든다.
	return ImageTexture.create_from_image(Image.create(1024, 64, false, Image.FORMAT_RGBA8))


# setup 이 받은 그림·이름을 쓰고, 비율대로 1.6 높이 판을 만들고, 클릭 레이어·좌우 반전·고리 색을 정하는지.
func _test_setup_builds_parts() -> void:
	# 10×20 그림의 아군.
	var view: UnitView = _view(true)
	# 정지 그림을 기억한다.
	check("still texture kept", view.still_texture != null and view.still_texture.get_height() == 20)
	# 띠가 없으면 셰이더가 정지 그림을 쓴다.
	check("shader shows the still texture", view.body_material.get_shader_parameter("texture_albedo") == view.still_texture)
	# 이름 글자.
	check_eq("name label", view.name_label.text, "테스터")
	# 판 크기 = (1.6 × 10/20, 1.6).
	check("sprite quad keeps the texture aspect", (view.sprite.mesh as QuadMesh).size.is_equal_approx(Vector2(0.8, UnitView.SPRITE_HEIGHT)))
	# 발이 원점: 판 중심이 절반 높이.
	check("sprite stands on its feet", is_equal_approx(view.sprite.position.y, UnitView.SPRITE_HEIGHT / 2.0))
	# 클릭 몸체.
	check_eq("pick body on the board pick layer", view.pick_body.collision_layer, UnitView.PICK_LAYER_BIT)
	# 아군은 오른쪽을 본다.
	check("ally faces right", view.body_material.get_shader_parameter("flip_h") == false)
	# 아군 고리 색.
	check_eq("ally ring colour", (view.ring.material_override as StandardMaterial3D).albedo_color, UnitView.ALLY_RING_COLOR)
	# 몸 계층: Body → Pose → Sprite.
	check("sprite sits under pose under body", view.sprite.get_parent() == view.pose and view.pose.get_parent() == view.body)
	# 지운다.
	view.free()

	# 적군.
	var enemy: UnitView = _view(false)
	# 적은 왼쪽을 본다.
	check("enemy is mirrored in the shader", enemy.body_material.get_shader_parameter("flip_h") == true)
	# 음수 스케일로 뒤집으면 양면 셰이더가 법선을 뒤집어 적만 빛을 등진다 (어둡게 보임).
	check("enemy keeps a positive scale so it is lit like allies", is_equal_approx(enemy.sprite.scale.x, 1.0))
	# 적 고리 색.
	check_eq("enemy ring colour", (enemy.ring.material_override as StandardMaterial3D).albedo_color, UnitView.ENEMY_RING_COLOR)
	# 지운다.
	enemy.free()


# 체력 12/30, 방어도 6 이면 글자와 막대가 맞고, 체력이 가득 차고 방어도 0 이면 방어도 글자가 빠지는지.
func _test_stats_text_and_bar() -> void:
	# 아군 화면.
	var view: UnitView = _view(true)
	# 체력 12, 최대 30, 방어도 6.
	view.set_stats(12, 30, 6)
	# 글자.
	check_eq("hp and block text", view.stat_label.text, "12/30  방6")
	# 막대 폭 = 0.9 × 12/30 = 0.36.
	check("fill width is the hp ratio", is_equal_approx((view.hp_fill.mesh as QuadMesh).size.x, 0.36))
	# 왼쪽 정렬 위치 = -0.9 × (1 - 0.4) / 2 = -0.27.
	check("fill is anchored left", is_equal_approx(view.hp_fill.position.x, -0.27))

	# 가득 찬 체력, 방어도 0.
	view.set_stats(30, 30, 0)
	# 방어도 글자가 없다.
	check_eq("no block text when zero", view.stat_label.text, "30/30")
	# 가득 찬 막대는 가운데.
	check("full bar is centred", is_equal_approx(view.hp_fill.position.x, 0.0))
	# 지운다.
	view.free()


# set_hp 와 set_block 을 따로 불러도 둘 다 반영되고, 체력 0 이면 막대가 숨는지.
func _test_partial_updates() -> void:
	# 아군 화면.
	var view: UnitView = _view(true)
	# 체력만 바꾼다.
	view.set_hp(10, 30)
	# 방어도만 바꾼다.
	view.set_block(4)
	# 둘 다 글자에 반영.
	check_eq("hp and block update separately", view.stat_label.text, "10/30  방4")
	# 체력 0.
	view.set_hp(0, 30)
	# 채움 막대 숨김.
	check("empty bar is hidden", not view.hp_fill.visible)
	# 지운다.
	view.free()


# set_home 이 위치와 원래 자리를 정하고, set_alive(false) 가 숨기고 클릭을 끄는지.
func _test_home_and_alive() -> void:
	# 아군 화면.
	var view: UnitView = _view(true)
	# 원래 자리를 정한다.
	view.set_home(Vector3(1.0, 0.0, 2.0))
	# 지금 위치.
	check_eq("placed at home", view.position, Vector3(1.0, 0.0, 2.0))
	# 기억한 원래 자리.
	check_eq("home remembered", view.home_position, Vector3(1.0, 0.0, 2.0))
	# 쓰러짐으로.
	view.set_alive(false)
	# 숨겨졌다.
	check("dead view hidden", not view.visible)
	# 클릭 판정이 꺼졌다.
	check("dead view not pickable", view.pick_shape.disabled)
	# 지운다.
	view.free()


# 띠는 너비 ÷ 높이 장이고, 진행률·번호가 마지막 프레임을 넘지 않는지.
func _test_sheet_frames() -> void:
	# 16장 띠.
	var sheet: Texture2D = _sheet()
	# 프레임 수.
	check_eq("frame count from sheet size", UnitView.frame_count(sheet), 16)
	# 대기 띠가 있는 아군.
	var view: UnitView = _view(true, [sheet, null, null])
	# 처음엔 대기 띠의 시작 프레임 (unit_id 0 → 0).
	check("idle sheet shown on setup", view.body_material.get_shader_parameter("texture_albedo") == sheet)
	# 셰이더 프레임 수.
	check_eq("shader frame count", view.body_material.get_shader_parameter("frame_count"), 16)
	# 진행률 끝은 마지막 프레임.
	view.show_sheet_progress(sheet, 1.0)
	# 15번.
	check_eq("progress end is the last frame", view.body_material.get_shader_parameter("frame"), 15)
	# 번호가 넘치면 감는다.
	view.show_frame(sheet, 18)
	# 18 % 16 = 2.
	check_eq("frame index wraps", view.body_material.get_shader_parameter("frame"), 2)
	# 지운다.
	view.free()


# 대기: 띠가 있으면 8fps 프레임, 없으면 숨쉬기 자세. 연출 시간은 띠 유무로 정해진다.
func _test_idle_and_durations() -> void:
	# 띠 없는 아군.
	var plain: UnitView = _view(true)
	# 0.4초 (숨쉬기 최대).
	plain.tick_idle(0.4)
	# 세로로 늘었다 (phase = unit_id 0 × 1.7 = 0).
	check("idle breathes without a sheet", is_equal_approx(plain.pose.scale.y, 1.03))
	# 코드 공격 시간.
	check("attack uses action time without sheet", is_equal_approx(plain.attack_duration(), UnitView.ACTION_TIME))
	# 코드 피격 시간.
	check("hit uses flash time without sheet", is_equal_approx(plain.hit_duration(), UnitView.FLASH_TIME))
	# 지운다.
	plain.free()

	# 대기·피격 띠만 있는 유닛 (brute 와 같은 구성).
	var mixed: UnitView = _view(true, [_sheet(), null, _sheet()])
	# 1초 → 8번째 프레임.
	mixed.tick_idle(1.0)
	# 8.
	check_eq("idle sheet plays at 8 fps", mixed.body_material.get_shader_parameter("frame"), 8)
	# 띠 재생 중에는 자세를 건드리지 않는다.
	check("sheet idle keeps pose scale", mixed.pose.scale.is_equal_approx(Vector3.ONE))
	# 공격은 코드 시간, 피격은 띠 시간.
	check("mixed sheets pick durations per action", is_equal_approx(mixed.attack_duration(), UnitView.ACTION_TIME) and is_equal_approx(mixed.hit_duration(), UnitView.HIT_FRAME_TIME))
	# 지운다.
	mixed.free()


# 기울기는 적에게서 거울상이고, reset_pose 가 자세·셰이더 값을 모두 되돌리는지.
func _test_pose_and_reset() -> void:
	# 아군과 적.
	var ally: UnitView = _view(true)
	var enemy: UnitView = _view(false)
	# 같은 자세 (뒤로 10°).
	ally.apply_pose(UnitMotion.Pose.new(0.1, 10.0))
	enemy.apply_pose(UnitMotion.Pose.new(0.1, 10.0))
	# 아군 +10°, 적 −10°.
	check("lean mirrors for enemies", is_equal_approx(ally.pose.rotation.z, deg_to_rad(10.0)) and is_equal_approx(enemy.pose.rotation.z, deg_to_rad(-10.0)))
	# 늘이면 옆으로 얇아진다.
	check("stretch keeps volume", ally.pose.scale.is_equal_approx(Vector3(0.95, 1.1, 1.0)))
	# 연출이 끊긴 상태를 흉내 낸다.
	ally.body_material.set_shader_parameter("fade", 0.3)
	ally.body_material.set_shader_parameter("tint", UnitView.FLASH_TINT)
	ally.body.position = Vector3(0.08, 0.2, 0.0)
	# 되돌린다.
	ally.reset_pose()
	# 셰이더 값.
	check("reset_pose restores shader state", is_equal_approx(ally.body_material.get_shader_parameter("fade"), 1.0) and ally.body_material.get_shader_parameter("tint") == Color.WHITE)
	# 자세와 몸 위치.
	check("reset_pose restores pose", ally.pose.scale.is_equal_approx(Vector3.ONE) and ally.body.position.is_equal_approx(Vector3.ZERO))
	# 지운다.
	ally.free()
	enemy.free()


# 카메라 방향의 수평 성분을 보고 Y축만 돌며, 위쪽은 카메라 반대로 기울이는지.
func _test_billboard_rotation() -> void:
	# 기본 카메라(+z 에서 −z 를 내려다봄).
	var front: Vector3 = UnitView.billboard_rotation(Vector3(0.0, -0.7, -0.7), 20.0)
	# 돌지 않고 20° 뒤로.
	check("front camera keeps yaw 0", front.is_equal_approx(Vector3(deg_to_rad(-20.0), 0.0, 0.0)))
	# +x 를 보는 카메라 → 판이 −x 쪽(카메라)을 보도록 −90°.
	var side: Vector3 = UnitView.billboard_rotation(Vector3(1.0, 0.0, 0.0), 20.0)
	# −90°.
	check("side camera turns the body", is_equal_approx(side.y, deg_to_rad(-90.0)))
	# 수평 성분이 없으면(바로 아래를 봄) 돌지 않는다.
	check("billboard without horizontal forward keeps yaw 0", is_equal_approx(UnitView.billboard_rotation(Vector3.DOWN, 20.0).y, 0.0))


# 오라 그림이 있는 유닛에만 위로 피어오르는 입자가 생기는지.
func _test_aura() -> void:
	# 오라 없는 유닛.
	var plain: UnitView = _view(true)
	# 없다.
	check("no aura without texture", plain.aura == null)
	# 지운다.
	plain.free()

	# 오라 있는 유닛.
	var data: UnitData = AllyDataScript.new()
	data.display_name = "보초"
	data.max_hp = 20
	data.aura_texture = ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	var view := UnitView.new()
	view.setup(Unit.new(0, data, Unit.Team.ALLY, Vector2i(0, 0)), _texture())
	# 있다.
	check("aura exists with texture", view.aura != null)
	# 계속 나온다.
	check("aura keeps emitting", view.aura.emitting and not view.aura.one_shot)
	# 이미 뜬 불꽃은 몸이 움직여도 제자리 (월드 좌표).
	check("aura particles live in world space", not view.aura.local_coords)
	# 수명.
	check("aura lifetime", is_equal_approx(view.aura.lifetime, UnitView.AURA_LIFETIME))
	# 그림이 입자 재질에 들어갔다.
	check("aura uses the texture", ((view.aura.mesh as QuadMesh).material as StandardMaterial3D).albedo_texture == data.aura_texture)
	# 지운다.
	view.free()


# 맞는 순간: 몸이 흰색이 되고 불꽃이 튀며, 실제 0.06초가 지나면 흰색이 꺼지는지.
func _test_impact() -> void:
	# 아군.
	var view: UnitView = _view(true)
	# 불꽃이 있다.
	check("sparks exist", view.sparks != null and view.sparks.one_shot)
	# 불꽃은 가슴 높이.
	check("sparks at chest height", is_equal_approx(view.sparks.position.y, UnitView.CHEST_HEIGHT))
	# 게임에서처럼 트리에 붙인다 (불꽃은 월드 좌표라 트리 안에서 터뜨린다).
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	# 맞는다.
	view.start_impact()
	# 흰색.
	check("impact flashes white", is_equal_approx(view.body_material.get_shader_parameter("flash"), 1.0))
	# 불꽃 방출.
	check("impact emits sparks", view.sparks.emitting)
	# 아직 0.06초 전.
	view.tick_flash(Time.get_ticks_msec())
	# 그대로 흰색.
	check("white holds briefly", is_equal_approx(view.body_material.get_shader_parameter("flash"), 1.0))
	# 0.06초 뒤.
	view.tick_flash(Time.get_ticks_msec() + 61)
	# 꺼짐.
	check("white clears after 0.06 s", is_equal_approx(view.body_material.get_shader_parameter("flash"), 0.0))
	# 지운다.
	view.free()


# 피해 숫자 크기: punch 배에서 시작해 0.15초(POP_TIME 0.6 의 1/4)에 1 이 되고 그 뒤는 1.
func _test_pop_scale() -> void:
	# 시작.
	check("pop starts punched", is_equal_approx(UnitView.pop_scale(0.0, 1.6), 1.6))
	# 절반 (0.075초 = t 0.125).
	check("pop shrinks", is_equal_approx(UnitView.pop_scale(0.125, 2.0), 1.5))
	# 0.15초.
	check("pop settles at 0.15 s", is_equal_approx(UnitView.pop_scale(0.25, 2.0), 1.0))
	# 끝.
	check("pop stays at 1", is_equal_approx(UnitView.pop_scale(1.0, 2.0), 1.0))
