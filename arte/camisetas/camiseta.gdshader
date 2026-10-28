// Material del equipo de un jugador (camiseta, short y medias).
//
// La textura del equipo la arma GeneradorCamiseta una vez por club al cargar
// el partido. El número de cada jugador NO se hornea: se dibuja acá a partir
// de un atlas de dígitos, así los 11 jugadores comparten una sola textura y
// un solo material. El número se cambia por jugador con:
//     malla.set_instance_shader_parameter("numero", 10)
//
// Distribución UV (ver docs/arte/estilo-arte-3d.md, sección "Camisetas").
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D textura_equipo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D atlas_numeros : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 color_numero : source_color = vec4(1.0);
// Borde del número, para que se lea sobre rayas. Alfa 0 = sin borde.
// GeneradorCamiseta.color_borde_numero(kit) elige el color.
uniform vec4 color_borde_numero : source_color = vec4(0.0);

// Rectángulos donde va el número, en UV: (x, y, ancho, alto).
uniform vec4 rect_numero_espalda = vec4(0.5625, 0.09375, 0.375, 0.3125);
uniform vec4 rect_numero_frente = vec4(0.1875, 0.125, 0.09375, 0.09375);
uniform bool numero_en_frente = true;

uniform float rugosidad : hint_range(0.0, 1.0) = 0.85;

// numero: 1 a 99. 0 o menos = sin número (por ejemplo, el árbitro).
// Los dos materiales del jugador (camiseta.gdshader y cuerpo.gdshader)
// declaran los mismos parámetros por instancia, en el mismo orden: Godot los
// guarda en un solo lugar por malla y, si difieren, se pisan entre sí.
instance uniform int numero = 0;
instance uniform vec4 color_piel : source_color = vec4(0.85, 0.64, 0.48, 1.0);
instance uniform vec4 color_pelo : source_color = vec4(0.1, 0.08, 0.07, 1.0);
instance uniform vec4 color_botines : source_color = vec4(0.07, 0.07, 0.07, 1.0);

// Devuelve cuánto número (x) y cuánto borde (y) hay en este punto, de 0 a 1.
vec2 numero_en_rect(vec2 uv, vec4 rect) {
	vec2 p = (uv - rect.xy) / rect.zw;
	if (numero <= 0 || p.x < 0.0 || p.y < 0.0 || p.x >= 1.0 || p.y >= 1.0) {
		return vec2(0.0);
	}
	int cifras = numero >= 10 ? 2 : 1;
	// Cada dígito ocupa una celda de proporción 1:2 dentro del rectángulo.
	float ancho_celda = (rect.w * 0.5) / rect.z;
	float inicio = 0.5 - ancho_celda * float(cifras) * 0.5;
	float x = (p.x - inicio) / ancho_celda;
	if (x < 0.0 || x >= float(cifras)) {
		return vec2(0.0);
	}
	int indice = int(floor(x));
	int digito = (cifras == 2 && indice == 0) ? (numero / 10) % 10 : numero % 10;
	vec2 uv_atlas = vec2((float(digito) + fract(x)) / 10.0, p.y);
	// textureLod evita saltos de mipmap en los bordes de cada celda.
	float relleno = textureLod(atlas_numeros, uv_atlas, 0.0).a;
	float borde = relleno;
	if (color_borde_numero.a > 0.0) {
		// Engorda el dígito mirando 8 puntos alrededor (unos 4 px del atlas).
		vec2 d = vec2(0.0065, 0.035);
		borde = max(borde, textureLod(atlas_numeros, uv_atlas + vec2(d.x, 0.0), 0.0).a);
		borde = max(borde, textureLod(atlas_numeros, uv_atlas - vec2(d.x, 0.0), 0.0).a);
		borde = max(borde, textureLod(atlas_numeros, uv_atlas + vec2(0.0, d.y), 0.0).a);
		borde = max(borde, textureLod(atlas_numeros, uv_atlas - vec2(0.0, d.y), 0.0).a);
		borde = max(borde, textureLod(atlas_numeros, uv_atlas + d * 0.7, 0.0).a);
		borde = max(borde, textureLod(atlas_numeros, uv_atlas - d * 0.7, 0.0).a);
		borde = max(borde, textureLod(atlas_numeros, uv_atlas + vec2(d.x, -d.y) * 0.7, 0.0).a);
		borde = max(borde, textureLod(atlas_numeros, uv_atlas + vec2(-d.x, d.y) * 0.7, 0.0).a);
	}
	return vec2(relleno, borde);
}

void fragment() {
	vec3 base = texture(textura_equipo, UV).rgb;
	vec2 n = numero_en_rect(UV, rect_numero_espalda);
	if (numero_en_frente) {
		n = max(n, numero_en_rect(UV, rect_numero_frente));
	}
	vec3 color = mix(base, color_borde_numero.rgb, n.y * color_borde_numero.a);
	ALBEDO = mix(color, color_numero.rgb, n.x);
	ROUGHNESS = rugosidad;
	METALLIC = 0.0;
}
