## 보드를 둘러싼 방 디오라마: 반복 바닥, 뒷벽·좌우 벽, 가장자리 소품, 창문 스포트라이트와 빛 속 먼지.
## 모두 3D 라서 원근·조명·그림자를 받아 칸이 실제 방 바닥 위에 놓인 것처럼 보인다 (유니티 BattleEnvironment).
## 클릭 판정에 끼지 않도록 충돌체를 만들지 않는다.
class_name BattleEnvironment
# Node3D: 방 전체를 묶는 노드.
extends Node3D

## 벽 셰이더.
const WALL_SHADER: Shader = preload("res://Shaders/room_wall.gdshader")
## 바닥 폭·깊이.
const GROUND_WIDTH: float = 40.0
const GROUND_DEPTH: float = 24.0
## 바닥 텍스처 한 장이 덮는 크기.
const GROUND_TILE_SIZE: float = 5.0
## 바닥이 유닛보다 튀지 않게 어둡게 칠하는 색.
const GROUND_TINT := Color(0.45, 0.45, 0.5)
## 벽 높이 (44° 카메라에는 아래 약 4 단위만 보인다).
const WALL_HEIGHT: float = 4.0
## 벽 텍스처 한 장이 덮는 크기.
const WALL_TILE_SIZE: float = 4.0
## 뒷벽은 가장 먼 행에서, 옆벽은 보드 좌우 끝에서 이만큼 떨어진다.
const BACK_WALL_GAP: float = 2.0
const SIDE_WALL_GAP: float = 3.0
## 벽 색.
const WALL_TINT := Color(0.8, 0.8, 0.85)
## 벽 텍스처 아래쪽에 그려진 바닥 줄을 잘라내는 비율.
const WALL_FLOOR_CROP: float = 0.12
## 벽 맨 위의 최대 어둡기.
const WALL_SHADE_ALPHA: float = 0.85
## 창문 빛 색.
const LIGHT_COLOR := Color(1.0, 0.9, 0.75)
## 창문 빛 세기 (화면을 보며 맞춘다).
const LIGHT_ENERGY: float = 3.0
## 먼지 색.
const DUST_COLOR := Color(1.0, 0.92, 0.8, 0.3)
## 실내 앰비언트 색.
const AMBIENT_COLOR := Color(0.16, 0.17, 0.2)
## 멀어질수록 깔리는 어두운 안개 색과 밀도.
const FOG_COLOR := Color(0.06, 0.065, 0.08)
const FOG_DENSITY: float = 0.025
## 창문 빛이 보이는 볼류메트릭 포그 밀도 (뒤쪽 유닛을 가리지 않을 만큼 옅게, 화면을 보며 맞춘다).
const VOLUMETRIC_DENSITY: float = 0.02
## 실내라 약한 태양.
const SUN_ENERGY: float = 0.45

## 바닥.
var ground: MeshInstance3D
## 뒷벽·왼쪽 벽·오른쪽 벽.
var back_wall: MeshInstance3D
var left_wall: MeshInstance3D
var right_wall: MeshInstance3D
## 소품 (카메라를 향해 도는 피벗).
var props: Array[Node3D] = []
## 창문 스포트라이트.
var lights: Array[SpotLight3D] = []


## 보드 배치와 방 데이터로 방을 만든다. 방이 없으면 null.
static func build(layout: BoardLayout, room: BattleRoomData) -> BattleEnvironment:
	# 방 없음.
	if room == null:
		return null
	# 방 노드.
	var env := BattleEnvironment.new()
	env.name = "Environment"
	# 보드 중심과 바닥 높이 (칸 윗면 0 에서 두께만큼 아래).
	var center: Vector3 = layout.center()
	var floor_y: float = -Board3D.TILE_THICKNESS

	# --- 바닥 ---
	if room.ground_texture != null:
		env.ground = MeshInstance3D.new()
		env.ground.name = "Ground"
		var plane := PlaneMesh.new()
		plane.size = Vector2(GROUND_WIDTH, GROUND_DEPTH)
		env.ground.mesh = plane
		var material := StandardMaterial3D.new()
		material.albedo_texture = room.ground_texture
		material.albedo_color = GROUND_TINT
		# 텍스처 한 장이 5 단위를 덮게 반복한다.
		material.uv1_scale = Vector3(GROUND_WIDTH / GROUND_TILE_SIZE, GROUND_DEPTH / GROUND_TILE_SIZE, 1.0)
		env.ground.material_override = material
		env.ground.position = Vector3(center.x, floor_y, center.z)
		env.add_child(env.ground)

	# --- 벽 ---
	# 0행이 −z (화면 안쪽). 뒷벽은 가장 먼 행 너머, 옆벽은 보드 좌우 끝 너머.
	var back_z: float = -(layout.depth() / 2.0 + BACK_WALL_GAP)
	var left_x: float = layout.min_x() - SIDE_WALL_GAP
	var right_x: float = layout.max_x() + SIDE_WALL_GAP
	var front_z: float = center.z + GROUND_DEPTH / 2.0
	var side_length: float = front_z - back_z
	if room.wall_texture != null:
		# 뒷벽은 앞(+z, 카메라 쪽)을 본다.
		env.back_wall = env._wall("BackWall", room.wall_texture, Vector3(center.x, floor_y, back_z), 0.0, right_x - left_x)
		# 왼쪽 벽은 +x(보드 쪽)를 본다.
		env.left_wall = env._wall("LeftWall", room.wall_texture, Vector3(left_x, floor_y, back_z + side_length / 2.0), 90.0, side_length)
		# 오른쪽 벽은 −x 를 본다.
		env.right_wall = env._wall("RightWall", room.wall_texture, Vector3(right_x, floor_y, back_z + side_length / 2.0), -90.0, side_length)
		# 뒷벽 위쪽 창문에서 비스듬히 들어오는 빛 두 줄기와 그 아래 먼지.
		env._window_light(Vector3(left_x + (right_x - left_x) * 0.3, WALL_HEIGHT, back_z + 0.5), center + Vector3(-1.5, floor_y, -0.5))
		env._window_light(Vector3(left_x + (right_x - left_x) * 0.75, WALL_HEIGHT, back_z + 0.5), center + Vector3(2.5, floor_y, 0.5))

	# --- 소품 ---
	for placement in room.props:
		if placement.texture != null:
			env.props.append(env._prop(placement, floor_y))
	return env


## 실내 분위기로 환경·태양을 바꾼다 (유니티 AtmosphereSetup + Battle.unity 안개·조명).
static func apply_atmosphere(env: Environment, sun: DirectionalLight3D) -> void:
	# 바깥은 안개 색과 같은 어둠.
	env.background_mode = Environment.BG_COLOR
	env.background_color = FOG_COLOR
	# 실내 앰비언트.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = 1.0
	# 멀어질수록 어두워지는 안개.
	env.fog_enabled = true
	env.fog_light_color = FOG_COLOR
	env.fog_density = FOG_DENSITY
	# 빛기둥을 만드는 옅은 볼류메트릭 포그 (창문 스포트라이트만 밝힌다).
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = VOLUMETRIC_DENSITY
	env.volumetric_fog_albedo = Color(1.0, 0.95, 0.9)
	# 구석 그늘.
	env.ssao_enabled = true
	# 창문·밝은 곳이 은은하게 번지게.
	env.glow_enabled = true
	env.glow_hdr_threshold = 0.9
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1
	# 채도를 낮추고 대비를 조금 올린다.
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.82
	env.adjustment_contrast = 1.08
	# 약한 태양, 그림자는 켠다. 태양이 안개 전체를 밝히면 빛기둥이 묻히므로 안개에는 기여하지 않는다.
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	sun.light_volumetric_fog_energy = 0.0


## 매 프레임: 소품을 카메라 쪽으로 돌린다 (유닛과 같은 세로축 빌보드 + 20° 기울임).
func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var rotation_now: Vector3 = UnitView.billboard_rotation(-camera.global_basis.z, UnitView.BODY_TILT_DEG)
	for prop in props:
		prop.rotation = rotation_now


# 벽 한 면: 아래 가운데 bottom_center, 세로축 yaw_deg 회전, 가로 length, 높이 WALL_HEIGHT.
func _wall(wall_name: String, texture: Texture2D, bottom_center: Vector3, yaw_deg: float, length: float) -> MeshInstance3D:
	var wall := MeshInstance3D.new()
	wall.name = wall_name
	var quad := QuadMesh.new()
	quad.size = Vector2(length, WALL_HEIGHT)
	wall.mesh = quad
	# 반복 텍스처·그늘 셰이더.
	var material := ShaderMaterial.new()
	material.shader = WALL_SHADER
	material.set_shader_parameter("texture_albedo", texture)
	material.set_shader_parameter("tint", WALL_TINT)
	material.set_shader_parameter("uv_scale", Vector2(length / WALL_TILE_SIZE, WALL_HEIGHT / WALL_TILE_SIZE * (1.0 - WALL_FLOOR_CROP)))
	material.set_shader_parameter("shade_alpha", WALL_SHADE_ALPHA)
	wall.material_override = material
	# 판 중심을 높이 절반에.
	wall.position = bottom_center + Vector3.UP * (WALL_HEIGHT / 2.0)
	wall.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	add_child(wall)
	return wall


# 창문 스포트라이트 하나와 빛이 떨어지는 곳 위의 먼지.
func _window_light(from: Vector3, target: Vector3) -> void:
	var spot := SpotLight3D.new()
	spot.name = "WindowLight"
	spot.light_color = LIGHT_COLOR
	spot.light_energy = LIGHT_ENERGY
	spot.spot_range = 20.0
	# 유니티 spotAngle 35° 는 전체 각도, Godot 은 반각.
	spot.spot_angle = 17.5
	spot.shadow_enabled = true
	add_child(spot)
	spot.look_at_from_position(from, target, Vector3.UP)
	lights.append(spot)
	_dust(target + Vector3.UP * 1.5)


# 빛 속에 천천히 떠다니는 먼지.
func _dust(at: Vector3) -> void:
	var dust := CPUParticles3D.new()
	dust.name = "Dust"
	dust.position = at
	dust.amount = 48
	dust.lifetime = 6.0
	dust.preprocess = 6.0
	dust.local_coords = false
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.0, 1.5, 1.0)
	dust.direction = Vector3.UP
	dust.spread = 180.0
	dust.gravity = Vector3.ZERO
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.05
	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.02)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = DUST_COLOR
	quad.material = material
	dust.mesh = quad
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.emitting = true
	add_child(dust)


# 소품 하나: 바닥 위치에 선 피벗 + 높이에 맞춘 그림 판 (유닛과 같은 셰이더, 그림자 드리움).
func _prop(placement: PropPlacement, floor_y: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Prop"
	pivot.position = Vector3(placement.position.x, floor_y, placement.position.z)
	var sprite := MeshInstance3D.new()
	var quad := QuadMesh.new()
	var aspect: float = float(placement.texture.get_width()) / float(placement.texture.get_height())
	quad.size = Vector2(placement.height * aspect, placement.height)
	sprite.mesh = quad
	sprite.position = Vector3(0.0, placement.height / 2.0, 0.0)
	var material := ShaderMaterial.new()
	material.shader = UnitView.UNIT_SHADER
	material.set_shader_parameter("texture_albedo", placement.texture)
	sprite.material_override = material
	pivot.add_child(sprite)
	add_child(pivot)
	return pivot
