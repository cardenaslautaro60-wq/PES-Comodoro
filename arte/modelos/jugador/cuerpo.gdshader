// Material del cuerpo del jugador: piel, pelo y botines.
//
// La malla marca cada parte con el color de vértice: rojo = piel,
// verde = pelo, azul = botines, negro = detalles oscuros (ojos).
// Los colores reales salen de la apariencia de cada jugador y se ponen con
// set_instance_shader_parameter, así todos comparten un solo material.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

// Los dos materiales del jugador (camiseta.gdshader y cuerpo.gdshader)
// declaran los mismos parámetros por instancia, en el mismo orden: Godot los
// guarda en un solo lugar por malla y, si difieren, se pisan entre sí.
instance uniform int numero = 0;
instance uniform vec4 color_piel : source_color = vec4(0.85, 0.64, 0.48, 1.0);
instance uniform vec4 color_pelo : source_color = vec4(0.1, 0.08, 0.07, 1.0);
instance uniform vec4 color_botines : source_color = vec4(0.07, 0.07, 0.07, 1.0);

void fragment() {
	vec3 marca = COLOR.rgb;
	float resto = clamp(1.0 - marca.r - marca.g - marca.b, 0.0, 1.0);
	ALBEDO = marca.r * color_piel.rgb + marca.g * color_pelo.rgb + marca.b * color_botines.rgb
			+ resto * vec3(0.04);
	// El pelo y los botines brillan un poco más que la piel.
	ROUGHNESS = 0.8 - 0.25 * marca.b - 0.1 * marca.g;
}
