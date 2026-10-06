## 화면 가장자리 비네트를 늘 깔고, 큰 타격·처치 때 가장자리를 조이고 색을 번지게 했다가 되돌린다.
## 실제 시간으로 가라앉아 슬로모션·히트스톱 중에도 제 속도다 (유니티 ScreenPulse).
class_name ScreenPulse
# CanvasLayer: 3D 화면 위, HUD 아래 층에 화면 전체 덮개를 그린다.
extends CanvasLayer

## 펄스가 0 으로 가라앉는 실제 시간.
const DURATION: float = 0.4
## 평소 비네트 세기.
const BASE_VIGNETTE: float = 0.38
## 펄스 1 일 때 더해지는 비네트.
const VIGNETTE_BOOST: float = 0.25
## 화면 셰이더.
const SHADER: Shader = preload("res://Shaders/screen_pulse.gdshader")

## 화면 전체 덮개.
var overlay: ColorRect
## 덮개의 셰이더 재질.
var material: ShaderMaterial

# 지금 펄스 세기 (0..1).
var _level: float = 0.0
# 지난 프레임의 실제 시각 (마이크로초).
var _last_usec: int = 0


## 덮개와 재질을 만든다 (트리에 붙기 전에 값을 읽을 수 있게).
func _init() -> void:
	# HUD(층 1) 아래.
	layer = 0
	# 화면 전체를 덮는 사각형.
	overlay = ColorRect.new()
	overlay.name = "PulseOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 카드·칸 클릭을 가로채지 않는다.
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 셰이더.
	material = ShaderMaterial.new()
	material.shader = SHADER
	overlay.material = material
	add_child(overlay)
	# 평소 값.
	_apply()


## 펄스를 준다 (처치 1, 큰 타격 0.5). 이미 더 세면 그대로.
func pulse(strength: float) -> void:
	# 큰 쪽.
	_level = maxf(_level, clampf(strength, 0.0, 1.0))
	_apply()


## 지금 펄스 세기.
func level() -> float:
	return _level


## 실제 시간 real_delta 만큼 가라앉힌다.
func tick(real_delta: float) -> void:
	# 가라앉을 것이 없다.
	if _level <= 0.0:
		return
	# 0.4초에 1 만큼.
	_level = maxf(0.0, _level - real_delta / DURATION)
	_apply()


## 매 프레임: 실제 시간 차이로 가라앉힌다.
func _process(_delta: float) -> void:
	# 지금 실제 시각.
	var now: int = Time.get_ticks_usec()
	# 첫 프레임은 0.
	var real_delta: float = 0.0 if _last_usec == 0 else float(now - _last_usec) / 1000000.0
	_last_usec = now
	tick(real_delta)


# 세기를 셰이더 값으로.
func _apply() -> void:
	material.set_shader_parameter("chromatic", _level)
	material.set_shader_parameter("vignette", BASE_VIGNETTE + VIGNETTE_BOOST * _level)
