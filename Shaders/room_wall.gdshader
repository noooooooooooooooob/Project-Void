// 방 벽: 반복 텍스처에 색을 곱하고, 위로 갈수록 어두워지는 그늘(천장 아래 어둠)을 칠한다.
shader_type spatial;
// 옆벽 안쪽·뒷벽 앞쪽만 보이지만 회전 방향과 상관없게 양면.
render_mode cull_disabled;

// 벽 텍스처 (반복).
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
// 곱하는 색.
uniform vec3 tint : source_color = vec3(0.8, 0.8, 0.85);
// 텍스처 반복 횟수 (가로, 세로).
uniform vec2 uv_scale = vec2(1.0);
// 맨 위에서의 최대 어둡기.
uniform float shade_alpha = 0.85;

void fragment() {
	// 반복 좌표 (세로는 위쪽부터 uv_scale.y 만큼만 써서 텍스처 아래쪽 바닥 줄을 잘라낸다).
	vec3 color = texture(texture_albedo, UV * uv_scale).rgb * tint;
	// 0 = 벽 아래, 1 = 벽 위.
	float height = 1.0 - UV.y;
	// 0.35 위부터 부드럽게 어두워진다.
	float shade = smoothstep(0.0, 1.0, clamp((height - 0.35) / 0.65, 0.0, 1.0)) * shade_alpha;
	ALBEDO = color * (1.0 - shade);
}
