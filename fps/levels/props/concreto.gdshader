shader_type spatial;
// Concreto envelhecido (muros, bunker): textura triplanar em coordenadas do mundo,
// escorridos verticais de sujeira, base escurecida pela umidade e, se `camo` > 0,
// pintura de camuflagem em manchas (como no Muro do Atlântico).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_g, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.78, 0.76, 0.71);
uniform float tile = 3.0;
// Altura do chão em volta (a base fica úmida e escura até ~1 m acima).
uniform float ground_y = 0.0;
uniform float camo = 0.0;
uniform vec3 camo_a : source_color = vec3(0.42, 0.38, 0.27);
uniform vec3 camo_b : source_color = vec3(0.3, 0.32, 0.22);
uniform float streaks = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 triplanar(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy) * w.x + texture(tex, p.xz) * w.y + texture(tex, p.xy) * w.z;
}

// Mesma projeção para a textura de ruído (o Godot exige uma função por tipo de amostrador).
float triplanar_noise(vec3 p, vec3 w) {
	return texture(noise_tex, p.zy).r * w.x + texture(noise_tex, p.xz).r * w.y + texture(noise_tex, p.xy).r * w.z;
}

void fragment() {
	vec3 w = pow(abs(world_normal), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = world_pos / tile;
	vec3 albedo = triplanar(albedo_tex, p, w).rgb * tint;

	// Escorridos: ruído esticado na vertical, mais forte logo abaixo do topo das paredes.
	float side = 1.0 - w.y;
	vec2 streak_uv = vec2(dot(world_pos.xz, vec2(0.7, 0.7)) * 0.9, world_pos.y * 0.06);
	float s = texture(noise_tex, streak_uv).r;
	float streak = smoothstep(0.5, 0.85, s) * side * streaks;
	albedo *= 1.0 - streak * 0.35;

	// Manchas grandes de sujeira e umidade na base.
	float big = texture(noise_tex, world_pos.xz * 0.05 + world_pos.y * 0.03).r;
	albedo *= mix(0.82, 1.06, big);
	float base = 1.0 - smoothstep(ground_y, ground_y + 1.1, world_pos.y + (big - 0.5) * 0.6);
	albedo = mix(albedo, albedo * vec3(0.55, 0.53, 0.48), base * 0.8);

	// Camuflagem: duas cores em manchas com borda suave, por cima do concreto.
	if (camo > 0.0) {
		vec3 q = world_pos * 0.045;
		float c1 = triplanar_noise(q, w);
		float c2 = triplanar_noise(q * 1.3 + 0.5, w);
		vec3 paint = mix(albedo, albedo * camo_a * 2.0, smoothstep(0.5, 0.62, c1));
		paint = mix(paint, albedo * camo_b * 2.0, smoothstep(0.53, 0.66, c2));
		albedo = mix(albedo, paint, camo * (1.0 - streak * 0.5));
	}

	ALBEDO = albedo;
	NORMAL_MAP = triplanar(normal_tex, p, w).rgb;
	ROUGHNESS = clamp(triplanar(rough_tex, p, w).g + base * -0.15, 0.4, 1.0);
	SPECULAR = 0.3;
}
