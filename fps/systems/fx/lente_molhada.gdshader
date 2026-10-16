shader_type canvas_item;
// Água na lente: gotas que distorcem a imagem e escorrem; some aos poucos (`amount`).

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D drops : filter_linear, repeat_enable;
uniform float amount = 0.0;
uniform float slide = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 duv = uv * vec2(1.8, 1.0) + vec2(0.0, slide * 0.08);
	// Distância ao centro da gota mais próxima (ruído celular): gotas redondas.
	float d = texture(drops, duv).r;
	float drop = (1.0 - smoothstep(0.17, 0.24, d)) * amount;
	// Dentro da gota a imagem se inverte e amplia um pouco (lente convexa).
	vec2 grad = vec2(dFdx(d), dFdy(d));
	vec3 color = texture(screen_texture, uv - grad * 6.0 * drop).rgb;
	// Película de água: imagem um pouco mais clara e borrada nas bordas da gota.
	color = mix(color, color * 1.08 + 0.02, drop);

	COLOR = vec4(color, 1.0);
}
