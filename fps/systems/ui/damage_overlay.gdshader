shader_type canvas_item;
// Efeito de tela para ferimentos: perda de cor, escurecimento das bordas e
// vermelho nas bordas (pulso rápido ao levar dano).

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// 0..1 — quanto a cor some (vida baixa).
uniform float desaturation : hint_range(0.0, 1.0) = 0.0;
// 0..1 — bordas escuras (vida baixa).
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
// 0..1 — vermelho nas bordas (pulso de dano).
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color : source_color = vec3(0.45, 0.02, 0.0);
// 0..1 — visão turva (supressão).
uniform float blur : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Turva mais nas bordas que no centro: o jogador ainda enxerga para onde mira.
	float center_dist = distance(UV, vec2(0.5)) * 1.41;
	// Centro nítido; só as bordas embaçam, de leve.
	float lod = blur * mix(0.0, 1.6, smoothstep(0.35, 0.95, center_dist));
	vec3 color = textureLod(screen_texture, SCREEN_UV, lod).rgb;
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(gray) * vec3(1.0, 0.95, 0.9), desaturation);

	float dist = distance(UV, vec2(0.5)) * 1.41;
	float edge = smoothstep(0.35, 1.0, dist);
	color *= 1.0 - edge * vignette * 0.85;
	color = mix(color, flash_color, edge * flash * 0.8);

	COLOR = vec4(color, 1.0);
}
