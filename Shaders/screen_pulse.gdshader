// 화면 전체 후처리: 가장자리를 어둡게(비네트) 하고, 펄스 때 가장자리로 갈수록 색을 어긋나게(색수차) 한다.
shader_type canvas_item;

// 3D 가 그려진 화면.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
// 가장자리 어둡기 (0 = 없음).
uniform float vignette : hint_range(0.0, 1.0) = 0.38;
// 어두워지기 시작하는 범위 (클수록 안쪽부터 부드럽게).
uniform float vignette_smoothness : hint_range(0.01, 1.0) = 0.45;
// 색수차 세기 (1 이면 가장자리에서 약 4픽셀 어긋남).
uniform float chromatic : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	// 화면 중심에서의 방향 (가장자리 ±0.5).
	vec2 d = uv - vec2(0.5);
	// 가장자리일수록 크게 어긋난다.
	vec2 offset = d * 2.0 * chromatic * 4.0 * SCREEN_PIXEL_SIZE;
	float r = texture(screen_texture, uv + offset).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - offset).b;
	// 중심 0, 모서리 1 인 거리.
	float dist = length(d) * 1.41421;
	// 안쪽은 그대로, 바깥으로 갈수록 vignette 만큼 어둡게.
	float shade = 1.0 - vignette * smoothstep(1.0 - vignette_smoothness - 0.3, 1.0, dist);
	COLOR = vec4(vec3(r, g, b) * shade, 1.0);
}
