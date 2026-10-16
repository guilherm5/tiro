// Papel de shoji, lanternas, céu e lua: aparecem "acesos", sem luz.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform sampler2D textura : source_color, filter_linear_mipmap;
uniform bool usa_textura = false;
uniform vec3 cor = vec3(1.0);
uniform float forca = 1.0;
uniform bool transparente = false;

void fragment() {
	vec4 t = usa_textura ? texture(textura, UV) : vec4(1.0);
	ALBEDO = t.rgb * cor * forca;
	if (transparente) {
		ALPHA = t.a;
	}
}
