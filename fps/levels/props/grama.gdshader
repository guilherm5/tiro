shader_type spatial;
render_mode cull_disabled;
// Tufos de grama: cor da raiz para a ponta (UV.y = altura na folha), variação por tufo
// (INSTANCE_CUSTOM.r) e balanço do vento que cresce para a ponta.

uniform vec3 root_color : source_color = vec3(0.14, 0.16, 0.07);
uniform vec3 tip_color : source_color = vec3(0.3, 0.36, 0.15);
uniform vec3 dry_color : source_color = vec3(0.42, 0.4, 0.22);
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.3;

varying float tip;
varying float variation;

void vertex() {
	tip = UV.y;
	variation = INSTANCE_CUSTOM.r;
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float gust = sin(world.x * 0.15 + TIME * wind_speed) * 0.6 + sin(world.z * 0.23 + TIME * wind_speed * 1.7) * 0.4;
	float bend = tip * tip * wind_strength * (0.6 + gust);
	VERTEX.x += bend;
	VERTEX.z += bend * 0.4;
	VERTEX.y -= bend * 0.3;
}

void fragment() {
	vec3 top = mix(tip_color, dry_color, variation);
	ALBEDO = mix(root_color, top, smoothstep(0.0, 0.9, tip)) * mix(0.8, 1.1, variation);
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
