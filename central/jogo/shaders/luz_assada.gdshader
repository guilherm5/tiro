// Superfície com luz "assada" (estilo PS2): textura (UV, repetida) x mapa de luz (UV2).
// Sem iluminação em tempo real; a neblina e as sombras-bolha (decal) continuam valendo.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D textura : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D luz : source_color, filter_linear, repeat_disable;
uniform bool usa_textura = true;
uniform vec3 tinta = vec3(1.0);
uniform vec3 cor_lisa = vec3(0.5);
uniform float ganho = 1.4;      // o bake grava a luz "baixa" para caber em 8 bits
uniform float ambiente = 0.05;
uniform float saturacao_luz = 0.6;  // a luz quente x madeira quente saturava tudo de laranja

void fragment() {
	vec3 base = usa_textura ? texture(textura, UV).rgb * tinta : cor_lisa;
	vec3 l = texture(luz, UV2).rgb;
	l = mix(vec3(dot(l, vec3(0.3, 0.55, 0.15))), l, saturacao_luz) * ganho + vec3(ambiente);
	ALBEDO = base * l;
}
