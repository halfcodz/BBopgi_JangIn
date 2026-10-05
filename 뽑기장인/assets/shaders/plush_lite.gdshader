shader_type spatial;
// 인형 원단 셰이더(휴대폰 웹용 가벼운 판): 색 배합·털 결 무늬·가장자리 광택은 같고,
// 텍스처 읽기를 6번 → 3번으로 줄이고(털 노멀맵 생략) 조명 계산을 단순하게 했다.
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec4 main_color : source_color = vec4(0.62, 0.42, 0.26, 1.0);
uniform vec4 accent_color : source_color = vec4(0.93, 0.85, 0.72, 1.0);
uniform vec4 accent2_color : source_color = vec4(0.98, 0.72, 0.78, 1.0);
uniform sampler2D fabric_albedo : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D fabric_normal : hint_normal, filter_linear_mipmap, repeat_enable;  // 쓰지 않음(원래 셰이더와 같은 이름 맞춤)
uniform float tile_size = 0.035;
uniform float normal_strength = 0.9;
uniform float sheen = 0.55;
uniform float ao_strength = 1.0;

varying vec3 opos;
varying vec3 onrm;

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

void fragment() {
	vec3 w = pow(abs(onrm), vec3(4.0));
	w /= (w.x + w.y + w.z + 1e-5);
	float a = texture(fabric_albedo, opos.zy / tile_size).r * w.x
		+ texture(fabric_albedo, opos.xz / tile_size).r * w.y
		+ texture(fabric_albedo, opos.xy / tile_size).r * w.z;
	float accent = smoothstep(0.15, 0.85, COLOR.r);
	float accent2 = smoothstep(0.15, 0.85, COLOR.g);
	float ao = mix(1.0, COLOR.b, ao_strength);
	vec3 base = mix(main_color.rgb, accent_color.rgb, accent);
	base = mix(base, accent2_color.rgb, accent2);
	vec3 col = base * a * ao;
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 3.0);
	col = mix(col, col * 1.35 + base * 0.12, rim * sheen);
	ALBEDO = col;
	ROUGHNESS = 0.96;
	SPECULAR = 0.22;
	AO = ao;
	AO_LIGHT_AFFECT = 0.35;
}
