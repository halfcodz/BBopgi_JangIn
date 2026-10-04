shader_type spatial;
// 인형 원단 셰이더
//  - 버텍스 컬러 R: 포인트 원단(주둥이/발바닥/배) 비율, G: 세번째 원단(볼터치/분홍), B: 구운 AO
//  - 오브젝트 공간 트라이플래너로 털 결 텍스처(알베도+노멀)
//  - 가장자리 털 광택(시인)과 미세 산란(backlight)
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 main_color : source_color = vec4(0.62, 0.42, 0.26, 1.0);
uniform vec4 accent_color : source_color = vec4(0.93, 0.85, 0.72, 1.0);
uniform vec4 accent2_color : source_color = vec4(0.98, 0.72, 0.78, 1.0);
uniform sampler2D fabric_albedo : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fabric_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_size = 0.035; // 텍스처 한 장이 덮는 길이(m)
uniform float normal_strength = 0.9;
uniform float sheen = 0.55;
uniform float ao_strength = 1.0;

varying vec3 opos;
varying vec3 onrm;

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

vec3 tri_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / (w.x + w.y + w.z + 1e-5);
}

void fragment() {
	vec3 w = tri_weights(onrm);
	vec2 uvx = opos.zy / tile_size;
	vec2 uvy = opos.xz / tile_size;
	vec2 uvz = opos.xy / tile_size;
	float a = texture(fabric_albedo, uvx).r * w.x + texture(fabric_albedo, uvy).r * w.y + texture(fabric_albedo, uvz).r * w.z;
	// 트라이플래너 노멀 (whiteout 블렌딩, 오브젝트 공간) – UV/탄젠트 없이 동작
	vec3 tx = texture(fabric_normal, uvx).rgb * 2.0 - 1.0;
	vec3 ty = texture(fabric_normal, uvy).rgb * 2.0 - 1.0;
	vec3 tz = texture(fabric_normal, uvz).rgb * 2.0 - 1.0;
	tx.xy *= normal_strength; ty.xy *= normal_strength; tz.xy *= normal_strength;
	vec3 on = normalize(onrm);
	vec3 nX = vec3(tx.xy + on.zy, abs(tx.z) * on.x).zyx;
	vec3 nY = vec3(ty.xy + on.xz, abs(ty.z) * on.y).xzy;
	vec3 nZ = vec3(tz.xy + on.xy, abs(tz.z) * on.z);
	vec3 n_obj = normalize(nX * w.x + nY * w.y + nZ * w.z);
	vec3 n_view = normalize((VIEW_MATRIX * vec4(MODEL_NORMAL_MATRIX * n_obj, 0.0)).xyz);

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
	NORMAL = n_view;
	ROUGHNESS = 0.96;
	SPECULAR = 0.22;
	BACKLIGHT = base * 0.12;
	AO = ao;
	AO_LIGHT_AFFECT = 0.35;
}
