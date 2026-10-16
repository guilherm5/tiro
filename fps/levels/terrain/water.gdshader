shader_type spatial;
render_mode cull_disabled, depth_draw_always;
// Mar: ondas leves no vértice, cor que escurece com a profundidade e espuma onde a
// água encontra a areia e os obstáculos (usa a profundidade da cena).

uniform vec3 shallow_color : source_color = vec3(0.24, 0.31, 0.27);
uniform vec3 deep_color : source_color = vec3(0.05, 0.1, 0.11);
uniform vec3 foam_color : source_color = vec3(0.62, 0.64, 0.6);
uniform float depth_fade = 1.8;
uniform float foam_distance = 0.03;
uniform float wave_height = 0.08;
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
// Retângulo (x, z) sem água: o porão do barco do jogador.
uniform vec3 hull_min = vec3(0.0);
uniform vec3 hull_max = vec3(0.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world_pos.x * 0.21 + TIME * 1.1) * wave_height
		+ sin(world_pos.z * 0.33 - TIME * 1.4) * wave_height * 1.3;
}

void fragment() {
	if (world_pos.x > hull_min.x && world_pos.x < hull_max.x && world_pos.z > hull_min.z && world_pos.z < hull_max.z) {
		discard;
	}
	// Distância entre a superfície da água e o que está atrás dela.
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	// Profundidade vertical (no mundo), não ao longo do olhar: a espuma não alarga
	// quando a água é vista de lado.
	vec3 behind_world = (INV_VIEW_MATRIX * vec4(behind.xyz, 1.0)).xyz;
	float water_depth = max(world_pos.y - behind_world.y, 0.0);

	float t = clamp(water_depth / depth_fade, 0.0, 1.0);
	vec3 color = mix(shallow_color, deep_color, t);

	vec2 uv = world_pos.xz;
	float noise = texture(foam_noise, uv * 0.15 + vec2(TIME * 0.02, 0.0)).r;
	// Espuma: faixa fina na beira, em linhas que chegam e voltam com as ondas, e um
	// pouco em volta dos obstáculos (não um lençol branco em toda a parte rasa).
	float edge = 1.0 - smoothstep(0.0, foam_distance, water_depth);
	// Franja suave e contínua (a praia é quase plana: manchas de ruído aqui viravam
	// "camuflagem"); só um leve tremor do ruído e linhas finas indo e voltando.
	float surf = sin(water_depth * 120.0 - TIME * 2.2 + noise * 3.0) * 0.5 + 0.5;
	float foam = edge * (0.22 + 0.08 * noise) + edge * smoothstep(0.9, 0.98, surf) * 0.15;
	// Ondinhas chegando à praia: faixas finas que avançam no raso e se quebram com o ruído.
	float shore = 1.0 - smoothstep(0.02, 0.14, water_depth);
	float wave = sin(water_depth * 55.0 + TIME * 1.6 + noise * 4.0);
	foam += shore * smoothstep(0.82, 0.97, wave) * smoothstep(0.35, 0.6, noise) * 0.35;
	ALBEDO = mix(color, foam_color, foam);
	ALPHA = clamp(mix(0.6, 0.96, t) + foam, 0.0, 1.0);
	// Ondulações pequenas em duas direções (ondas grandes no vértice): reflexo do céu
	// partido em muitos pedaços, sem manchas grandes.
	vec3 n1 = texture(normal_a, uv * 0.45 + vec2(TIME * 0.04, TIME * 0.025)).rgb;
	vec3 n2 = texture(normal_b, uv * 0.7 - vec2(TIME * 0.03, TIME * 0.05)).rgb;
	NORMAL_MAP = normalize((n1 + n2) * 0.5);
	// Água rasa é mais calma (o reflexo do céu em ondulação forte vira manchas).
	NORMAL_MAP_DEPTH = mix(0.08, 0.3, smoothstep(0.0, 0.6, water_depth));
	ROUGHNESS = mix(0.16, 0.9, foam);
	SPECULAR = 0.35;
}
