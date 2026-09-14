# UnitView(3D 유닛 화면) 테스트: 자식 구성, 체력 글자·막대, 부분 갱신, 원래 자리·생존 표시.
# 트리에 붙이지 않고 setup 결과만 확인하므로 렌더링 없이 돈다.
extends TestCase

# 아군 데이터 스크립트.
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
# 적 데이터 스크립트.
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# setup 이 스프라이트·이름·클릭 몸체·색을 만드는지.
	_test_setup_builds_parts()
	# 체력 글자와 막대 폭·위치.
	_test_stats_text_and_bar()
	# 체력·방어도를 따로 갱신.
	_test_partial_updates()
	# 원래 자리와 생존 표시.
	_test_home_and_alive()
	# 결과를 돌려준다.
	return results()


# 10×20 픽셀짜리 빈 텍스처를 만든다 (높이 20 으로 픽셀 크기 계산을 검사하기 위해).
func _texture() -> Texture2D:
	# 빈 이미지로 텍스처를 만든다.
	return ImageTexture.create_from_image(Image.create(10, 20, false, Image.FORMAT_RGBA8))


# 체력 30 짜리 테스트 유닛 화면을 만든다. ally 가 true 면 아군, 아니면 적군.
func _view(ally: bool) -> UnitView:
	# 편에 맞는 데이터.
	var data: UnitData = AllyDataScript.new() if ally else EnemyDataScript.new()
	# id.
	data.id = &"tester"
	# 이름.
	data.display_name = "테스터"
	# 최대 체력.
	data.max_hp = 30
	# 편.
	var team: Unit.Team = Unit.Team.ALLY if ally else Unit.Team.ENEMY
	# 화면 객체.
	var view := UnitView.new()
	# 규칙 유닛과 텍스처로 채운다.
	view.setup(Unit.new(0, data, team, Vector2i(0, 1)), _texture())
	# 돌려준다.
	return view


# setup 이 받은 텍스처·이름을 쓰고, 높이에 맞춰 크기를 정하고, 클릭 레이어와 편 색을 설정하는지.
func _test_setup_builds_parts() -> void:
	# 비교할 텍스처를 따로 잡아 둔다.
	var texture: Texture2D = _texture()
	# 아군 데이터.
	var data: AllyData = AllyDataScript.new()
	# 이름.
	data.display_name = "테스터"
	# 최대 체력.
	data.max_hp = 30
	# 화면 객체.
	var view := UnitView.new()
	# 채운다.
	view.setup(Unit.new(0, data, Unit.Team.ALLY, Vector2i(0, 1)), texture)
	# 스프라이트가 받은 텍스처를 쓴다.
	check("sprite uses the given texture", view.sprite.texture == texture)
	# 이름 글자.
	check_eq("name label", view.name_label.text, "테스터")
	# 픽셀 크기 = 유닛 높이 / 그림 높이 20.
	check("sprite is scaled to the unit height", is_equal_approx(view.sprite.pixel_size, UnitView.SPRITE_HEIGHT / 20.0))
	# 클릭 몸체가 클릭 레이어에 있다.
	check_eq("pick body on the board pick layer", view.pick_body.collision_layer, UnitView.PICK_LAYER_BIT)
	# 아군 색.
	check_eq("ally tint", view.sprite.modulate, UnitView.ALLY_TINT)
	# 지운다.
	view.free()

	# 적군 화면도 만들어 본다.
	var enemy: UnitView = _view(false)
	# 적군 색.
	check_eq("enemy tint", enemy.sprite.modulate, UnitView.ENEMY_TINT)
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
