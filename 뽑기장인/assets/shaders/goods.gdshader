shader_type spatial;
// 굿즈(말랑이·키캡·팝잇·슬라임) 셰이더
//  - 버텍스 컬러 R: 포인트 색 비율, G: 세번째 색 비율, B: 구운 AO
//  - 재질은 roughness / clearcoat / soft(말랑이 표면의 부드러운 산란) 로 구분
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 main_color : source_color = vec4(1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.6, 0.7, 1.0);
uniform vec4 accent2_color : source_color = vec4(0.3, 0.3, 0.35, 1.0);
uniform float roughness_v = 0.5;
uniform float clearcoat_v = 0.0;
uniform float soft = 0.0;      // 0~1: 폼(말랑이) 같은 부드러운 가장자리 밝기
uniform float speckle = 0.0;   // 폼 표면 미세 요철
uniform float ao_strength = 1.0;

varying vec3 opos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	opos = VERTEX;
}

void fragment() {
	float accent = smoothstep(0.15, 0.85, COLOR.r);
	float accent2 = smoothstep(0.15, 0.85, COLOR.g);
	float ao = mix(1.0, COLOR.b, ao_strength);
	vec3 base = mix(main_color.rgb, accent_color.rgb, accent);
	base = mix(base, accent2_color.rgb, accent2);
	float n = hash(floor(opos * 2200.0));
	base *= 1.0 - speckle * n;
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 2.5);
	vec3 col = base * ao;
	col = mix(col, col * 1.25 + vec3(0.04), rim * soft);
	ALBEDO = col;
	ROUGHNESS = roughness_v;
	CLEARCOAT = clearcoat_v;
	CLEARCOAT_ROUGHNESS = 0.08;
	SPECULAR = 0.5;
	BACKLIGHT = vec3(0.25) * soft * base;
}
