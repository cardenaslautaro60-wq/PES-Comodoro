extends "res://tests/prueba.gd"
## Pruebas del generador de texturas de camisetas.

const G := preload("res://scripts/camisetas/generador_camiseta.gd")
const AZUL := "#1F4FA8"
const BLANCO := "#FFFFFF"
const ROJO := "#C8102E"
const NEGRO := "#151515"


func _kit(patron: String) -> Dictionary:
	return {
		"patron": patron, "color_base": AZUL, "color_secundario": BLANCO, "color_terciario": null,
		"hombreras": null, "cuello": ROJO, "numero": BLANCO, "pantalon": NEGRO, "medias": AZUL,
		"sponsor_parodia": "",
	}


func _es(img: Image, x: int, y: int, color: String) -> bool:
	return img.get_pixel(x, y).is_equal_approx(Color.html(color))


func test_todos_los_patrones_arman_la_textura() -> void:
	for patron: String in G.PATRONES:
		var img := G.generar_imagen(_kit(patron))
		afirmar(img.get_size() == Vector2i(G.TAMANIO, G.TAMANIO), "tamaño incorrecto con " + patron)
		afirmar(img.has_mipmaps(), "sin mipmaps con " + patron)


func test_liso_y_zonas() -> void:
	var img := G.generar_imagen(_kit("liso"))
	afirmar(_es(img, 128, 200, AZUL), "el frente no es del color base")
	afirmar(_es(img, 384, 200, AZUL), "la espalda no es del color base")
	afirmar(_es(img, 100, 360, ROJO), "el cuello no tiene su color")
	afirmar(_es(img, 384, 320, NEGRO), "el short no tiene su color")
	afirmar(_es(img, 100, 480, AZUL), "las medias no tienen su color")


func test_rayas_alternan() -> void:
	var img := G.generar_imagen(_kit("rayas_verticales"))
	var ancho := G.FRENTE.size.x / float(G.CANTIDAD_RAYAS)
	afirmar(_es(img, int(ancho * 0.5), 200, AZUL), "la primera raya no es del color base")
	afirmar(_es(img, int(ancho * 1.5), 200, BLANCO), "la segunda raya no es del color secundario")


func test_mitades_espejadas_en_la_espalda() -> void:
	var img := G.generar_imagen(_kit("mitades"))
	afirmar(_es(img, 200, 200, BLANCO), "de frente, la mitad izquierda del jugador va a la derecha")
	afirmar(_es(img, 56, 200, AZUL), "de frente, la mitad derecha del jugador va a la izquierda")
	afirmar(_es(img, 300, 200, BLANCO), "de espaldas, la mitad izquierda del jugador va a la izquierda")


func test_v_frontal_solo_adelante() -> void:
	var img := G.generar_imagen(_kit("v_frontal"))
	var v_en_frente := false
	for y in range(0, 140):
		if _es(img, 128, y, BLANCO):
			v_en_frente = true
	afirmar(v_en_frente, "la V no llega al centro del pecho")
	afirmar(_es(img, 384, 60, AZUL), "la V no debería estar en la espalda")


func test_hombreras() -> void:
	var kit := _kit("rayas_verticales")
	kit["hombreras"] = NEGRO
	var img := G.generar_imagen(kit)
	afirmar(_es(img, 20, 5, NEGRO), "faltan las hombreras en el frente")
	afirmar(_es(img, 300, 5, NEGRO), "faltan las hombreras en la espalda")


func test_patron_desconocido_usa_liso() -> void:
	var img := G.generar_imagen(_kit("lunares"))
	afirmar(_es(img, 128, 200, AZUL), "un patrón desconocido debería quedar liso")


func test_escudo_se_pega_en_el_pecho() -> void:
	var escudo := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	escudo.fill(Color.html(ROJO))
	var img := G.generar_imagen(_kit("liso"), escudo)
	var centro := G.ZONA_ESCUDO.get_center()
	afirmar(_es(img, centro.x, centro.y, ROJO), "el escudo no está en el pecho")


func test_sponsor_vacio_no_genera_imagen() -> void:
	var sponsor: Image = await G.imagen_sponsor(get_tree(), _kit("liso"))
	afirmar(sponsor == null, "sin sponsor no debería haber imagen")


func test_atlas_y_shader_cargan() -> void:
	afirmar(load("res://arte/camisetas/atlas_numeros.png") is Texture2D, "no carga el atlas de números")
	afirmar(load("res://arte/camisetas/camiseta.gdshader") is Shader, "no carga el shader de camiseta")
