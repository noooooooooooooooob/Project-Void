// 유닛·소품 몸 셰이더. 가로 띠 텍스처에서 한 프레임을 고르고, 붉은/흰 번쩍임과 디더 페이드를 한다.
// 알파 잘라내기라 그림자를 드리우고 깊이 정렬 문제가 없다.
shader_type spatial;
// 빌보드가 카메라 쪽을 보지만 연출 중 기울어도 사라지지 않게 양면을 그린다.
render_mode cull_disabled;

// 그림 (정지 그림 또는 64px 프레임을 가로로 이은 띠). 픽셀이 뭉개지지 않게 최근접 샘플링.
uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_disable;
// 보여 줄 프레임 번호 (0부터).
uniform int frame = 0;
// 띠의 프레임 수 (정지 그림은 1).
uniform int frame_count = 1;
// 곱하는 색 (평소 흰색, 피격 때 붉은색).
uniform vec3 tint : source_color = vec3(1.0);
// 1 이면 실루엣 전체가 흰색 (타격 순간).
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// true 면 그림을 좌우로 뒤집는다 (적은 왼쪽을 본다). 음수 스케일로 뒤집으면 양면 그리기가 법선을 뒤집어 빛을 등진다.
uniform bool flip_h = false;
// 1 이면 다 보이고 0 이면 다 사라진다. 화면 좌표 디더로 픽셀을 버린다.
uniform float fade : hint_range(0.0, 1.0) = 1.0;

// 4×4 Bayer 행렬 문턱값 ((i + 0.5) / 16).
const float BAYER[16] = float[](
	0.03125, 0.53125, 0.15625, 0.65625,
	0.78125, 0.28125, 0.90625, 0.40625,
	0.21875, 0.71875, 0.09375, 0.59375,
	0.96875, 0.46875, 0.84375, 0.34375);

void fragment() {
	// 띠에서 이 프레임 칸으로 가로 좌표를 옮긴다.
	float count = float(max(frame_count, 1));
	float u = flip_h ? 1.0 - UV.x : UV.x;
	vec2 uv = vec2((float(frame) + u) / count, UV.y);
	vec4 color = texture(texture_albedo, uv);
	// 사라지는 중이면 화면 픽셀 위치별 문턱값보다 fade 가 작을 때 버린다.
	if (fade < 1.0) {
		int x = int(FRAGCOORD.x) % 4;
		int y = int(FRAGCOORD.y) % 4;
		if (fade <= BAYER[y * 4 + x]) {
			discard;
		}
	}
	// 흰 번쩍임은 색을 흰색으로 섞고 그만큼 스스로 빛나게 해서 조명과 상관없이 하얗게 보인다.
	ALBEDO = mix(color.rgb * tint, vec3(1.0), flash);
	EMISSION = vec3(flash);
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
