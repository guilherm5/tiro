shader_type spatial;
// Chão da fase em camadas:
//  - areia molhada perto da água e areia fina seca acima (pela altura, com ruído);
//  - grama nas encostas (cor do vértice G, calculada pelo BeachTerrain);
//  - terra com pedras na trincheira (B) e onde o terreno é íngreme;
//  - crateras queimadas (R).
// Duas escalas da mesma textura e manchas grandes quebram a repetição.

uniform sampler2D dry_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dry_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dry_roughness : hint_roughness_g, filter_linear_mipmap, repeat_enable;
uniform sampler2D wet_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wet_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D wet_roughness : hint_roughness_g, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D breakup_noise : filter_linear_mipmap, repeat_enable;

// Metros por repetição da textura.
uniform float tile_size = 4.0;
uniform float grass_tile = 3.0;
uniform float dirt_tile = 3.0;
uniform float water_level = -1.5;
// Faixa (em metros de altura) da areia molhada acima da água.
uniform float wet_band = 1.6;
uniform vec3 dry_tint : source_color = vec3(1.02, 0.94, 0.8);
// A textura de areia molhada é clara; escurece para areia encharcada.
uniform vec3 wet_tint : source_color = vec3(0.55, 0.5, 0.42);
uniform vec3 grass_tint : source_color = vec3(0.8, 0.95, 0.55);
uniform vec3 dirt_tint : source_color = vec3(0.75, 0.68, 0.6);
uniform vec3 rock_tint : source_color = vec3(0.55, 0.54, 0.5);
uniform float rock_tile = 4.0;
uniform vec3 scorch_color : source_color = vec3(0.12, 0.11, 0.1);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Amostra em duas escalas (a segunda girada) e mistura pelo ruído: some a grade repetida.
vec3 two_scale(sampler2D tex, vec2 uv, float mixer) {
	vec2 uv2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.37;
	return mix(texture(tex, uv).rgb, texture(tex, uv2).rgb, mixer * 0.5);
}

void fragment() {
	vec2 uv = world_pos.xz / tile_size;
	float n = texture(breakup_noise, world_pos.xz * 0.01).r;
	float macro = texture(breakup_noise, world_pos.xz * 0.002 + 0.37).r;

	float wet = 1.0 - smoothstep(water_level, water_level + wet_band, world_pos.y + (n - 0.5) * 1.2);
	float slope = 1.0 - smoothstep(0.72, 0.9, world_normal.y);
	float grass = COLOR.g * smoothstep(0.25, 0.6, COLOR.g + (n - 0.5) * 0.5);
	// Barrancos muito íngremes: rocha exposta (fora da trincheira, que tem terra).
	float rock = smoothstep(0.5, 0.8, 1.0 - world_normal.y + (n - 0.5) * 0.25) * (1.0 - COLOR.b) * (1.0 - wet);
	float dirt = max(COLOR.b, slope * (1.0 - wet) * (1.0 - rock));
	grass *= (1.0 - dirt * 0.8) * (1.0 - rock);

	// Cada camada só é lida onde aparece (áreas grandes: o desvio custa pouco na GPU).
	vec3 albedo = vec3(0.0);
	vec3 nrm = vec3(0.5, 0.5, 1.0);
	float rough = 0.95;
	if (wet < 0.99) {
		albedo = two_scale(dry_albedo, uv, macro) * dry_tint;
		nrm = texture(dry_normal, uv).rgb;
		rough = texture(dry_roughness, uv).g;
	}
	if (wet > 0.01) {
		vec2 wuv = uv * 1.3;
		albedo = mix(albedo, texture(wet_albedo, wuv).rgb * wet_tint, wet);
		nrm = mix(nrm, texture(wet_normal, wuv).rgb, wet);
		rough = mix(rough, texture(wet_roughness, wuv).g * 0.75, wet);
	}
	if (dirt > 0.01) {
		vec2 duv = world_pos.xz / dirt_tile;
		albedo = mix(albedo, texture(dirt_albedo, duv).rgb * dirt_tint, dirt);
		nrm = mix(nrm, texture(dirt_normal, duv).rgb, dirt);
	}
	if (rock > 0.01) {
		// Projeção lateral (a face é quase vertical): ao longo da encosta e na altura.
		vec2 ruv = vec2(world_pos.x + world_pos.z * 0.3, world_pos.y) / rock_tile;
		albedo = mix(albedo, texture(rock_albedo, ruv).rgb * rock_tint, rock);
		nrm = mix(nrm, texture(rock_normal, ruv).rgb, rock);
	}
	if (grass > 0.01) {
		vec2 guv = world_pos.xz / grass_tile;
		vec3 grass_c = texture(grass_albedo, guv).rgb * grass_tint * mix(0.75, 1.15, n);
		albedo = mix(albedo, grass_c, grass);
		nrm = mix(nrm, texture(grass_normal, guv).rgb, grass);
	}
	albedo *= mix(0.82, 1.08, macro);
	albedo = mix(albedo, scorch_color, COLOR.r * 0.75 * (0.7 + 0.3 * n));
	rough = mix(rough, 0.95, max(max(grass, dirt), rock));

	ALBEDO = albedo;
	NORMAL_MAP = nrm;
	ROUGHNESS = mix(rough, 0.95, COLOR.r * 0.5);
	SPECULAR = mix(0.3, 0.45, wet) * (1.0 - grass * 0.5);
}
