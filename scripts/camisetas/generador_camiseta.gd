## Arma la textura de un equipo (camiseta, short y medias) a partir de una
## camiseta del archivo de un club (formato en docs/datos-clubes.md). Se
## llama una vez por club al cargar el partido y el resultado se usa en el
## material camiseta.gdshader.
##
## Ejemplo:
##     var kit: Dictionary = club["camisetas"]["titular"]
##     var sponsor := await GeneradorCamiseta.imagen_sponsor(get_tree(), kit)
##     var tex := GeneradorCamiseta.generar(kit, escudo_img, sponsor)
##     material.set_shader_parameter("textura_equipo", tex)
##     material.set_shader_parameter("color_numero", GeneradorCamiseta.color_numero(kit))
class_name GeneradorCamiseta
extends RefCounted

const TAMANIO := 512

# Zonas de la textura en píxeles. El modelo del jugador tiene que respetar
# esta distribución de UV (docs/arte/estilo-arte-3d.md, sección 5).
const FRENTE := Rect2i(0, 0, 256, 256)        # pecho, visto de frente
const ESPALDA := Rect2i(256, 0, 256, 256)     # espalda, vista desde atrás
const MANGAS := Rect2i(0, 256, 256, 96)       # mitad izq. = manga derecha del jugador
const DETALLES := Rect2i(0, 352, 256, 32)     # cuello y puños
const SHORT := Rect2i(256, 256, 256, 128)     # mitad izq. = pierna derecha
const MEDIAS := Rect2i(0, 384, 256, 128)      # arriba la banda, abajo el pie
const LIBRE := Rect2i(256, 384, 256, 128)     # reservado (guantes del arquero, etc.)

const ZONA_ESCUDO := Rect2i(150, 34, 56, 56)      # pecho izquierdo del jugador
const ZONA_SPONSOR := Rect2i(40, 110, 176, 60)    # centro del pecho
const ZONA_SPONSOR_BAJA := Rect2i(40, 162, 176, 50)  # debajo de la banda_pecho o la V

# Los siete del formato de datos más dos extra para clubes futuros.
const PATRONES := [
	"liso", "rayas_verticales", "bandas_horizontales", "mitades",
	"banda_diagonal", "v_frontal", "banda_pecho", "franja_vertical", "cuadros",
]
const CANTIDAD_RAYAS := 7
# Patrones en los que el color secundario queda detrás del sponsor.
const PATRONES_DETRAS_DEL_SPONSOR := ["rayas_verticales", "mitades", "franja_vertical", "cuadros", "banda_diagonal"]


## Devuelve la textura lista para usar, con mipmaps.
static func generar(kit: Dictionary, escudo: Image = null, sponsor: Image = null) -> ImageTexture:
	return ImageTexture.create_from_image(generar_imagen(kit, escudo, sponsor))


static func color_numero(kit: Dictionary) -> Color:
	return _color(kit, "numero", Color.WHITE)


## Color del borde del número para el shader. En camisetas con rayas, bandas o
## mitades el número cruza colores, así que lleva borde en contraste. En las
## demás devuelve un color transparente (sin borde).
static func color_borde_numero(kit: Dictionary) -> Color:
	var patron: String = kit.get("patron", "liso")
	if not (patron in PATRONES_DETRAS_DEL_SPONSOR or patron in ["bandas_horizontales", "banda_pecho"]):
		return Color(0, 0, 0, 0)
	return Color.BLACK if color_numero(kit).get_luminance() > 0.5 else Color.WHITE


static func generar_imagen(kit: Dictionary, escudo: Image = null, sponsor: Image = null) -> Image:
	var img := Image.create(TAMANIO, TAMANIO, false, Image.FORMAT_RGBA8)
	var base := _color(kit, "color_base", Color.WHITE)
	var sec := _color(kit, "color_secundario", base)
	var ter := _color(kit, "color_terciario", sec)
	var cuello := _color(kit, "cuello", sec)
	var patron: String = kit.get("patron", "liso")
	if not patron in PATRONES:
		push_warning("Patrón de camiseta desconocido: %s. Se usa liso." % patron)
		patron = "liso"
	var n := clampi(int(kit.get("cantidad_rayas", CANTIDAD_RAYAS)), 2, 15)

	img.fill(base)

	# Camiseta
	_pintar_patron(img, FRENTE, patron, sec, ter, n, false)
	_pintar_patron(img, ESPALDA, patron, sec, ter, n, true)
	_pintar_mangas(img, patron, base, sec)
	if _tiene(kit, "hombreras"):
		var h := _color(kit, "hombreras", sec)
		for z in [FRENTE, ESPALDA]:
			img.fill_rect(Rect2i(z.position.x, z.position.y, z.size.x, 26), h)
		img.fill_rect(Rect2i(MANGAS.position.x, MANGAS.position.y, MANGAS.size.x, 40), h)
	img.fill_rect(DETALLES, cuello)

	# Short (vivos con el color del cuello)
	var c_short := _color(kit, "pantalon", base)
	img.fill_rect(SHORT, c_short)
	var vivo_short := cuello if cuello != c_short else sec
	img.fill_rect(Rect2i(SHORT.position.x, SHORT.position.y, 10, SHORT.size.y), vivo_short)
	img.fill_rect(Rect2i(SHORT.end.x - 10, SHORT.position.y, 10, SHORT.size.y), vivo_short)

	# Medias (banda arriba con el color del cuello)
	var c_medias := _color(kit, "medias", base)
	img.fill_rect(MEDIAS, c_medias)
	var vivo_medias := cuello if cuello != c_medias else sec
	img.fill_rect(Rect2i(MEDIAS.position.x, MEDIAS.position.y + 8, MEDIAS.size.x, 14), vivo_medias)

	_pegar(img, escudo, ZONA_ESCUDO)
	_pegar(img, sponsor, ZONA_SPONSOR_BAJA if patron in ["banda_pecho", "v_frontal"] else ZONA_SPONSOR)

	img.generate_mipmaps()
	return img


## Dibuja el texto de "sponsor_parodia" en una imagen transparente, usando
## un SubViewport. Hace falta el árbol de escenas y esperar un cuadro.
## Devuelve null si la camiseta no tiene sponsor.
static func imagen_sponsor(arbol: SceneTree, kit: Dictionary, fuente: Font = null) -> Image:
	var texto: String = kit.get("sponsor_parodia", "")
	# Sin pantalla (pruebas y exportaciones en la nube) no se puede dibujar texto.
	if texto.strip_edges().is_empty() or DisplayServer.get_name() == "headless":
		return null
	var vista := SubViewport.new()
	vista.size = Vector2i(512, 128)
	vista.transparent_bg = true
	vista.render_target_update_mode = SubViewport.UPDATE_ONCE
	var etiqueta := Label.new()
	etiqueta.text = texto.to_upper()
	etiqueta.size = Vector2(vista.size)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", 64 if texto.length() <= 14 else 44)
	etiqueta.add_theme_color_override("font_color", _color_sponsor(kit))
	if fuente:
		etiqueta.add_theme_font_override("font", fuente)
	vista.add_child(etiqueta)
	arbol.root.add_child(vista)
	await RenderingServer.frame_post_draw
	var img := vista.get_texture().get_image()
	vista.queue_free()
	var borde := img.get_used_rect()
	if borde.size.x <= 0:
		return null
	return img.get_region(borde)


## Elige el color del sponsor que mejor se lea: entre el del número, el del
## cuello, blanco y negro, el que más contraste contra los colores que
## quedan detrás del sponsor.
static func _color_sponsor(kit: Dictionary) -> Color:
	var fondos: Array[Color] = [_color(kit, "color_base", Color.WHITE)]
	if kit.get("patron", "liso") in PATRONES_DETRAS_DEL_SPONSOR:
		fondos.append(_color(kit, "color_secundario", fondos[0]))
	var candidatos: Array[Color] = [color_numero(kit), _color(kit, "cuello", Color.WHITE), Color.WHITE, Color.BLACK]
	var mejor := candidatos[0]
	var mejor_contraste := -1.0
	for c in candidatos:
		var contraste := 1.0
		for f in fondos:
			contraste = minf(contraste, absf(c.get_luminance() - f.get_luminance()))
		if contraste > mejor_contraste + 0.05:
			mejor = c
			mejor_contraste = contraste
	return mejor


static func _pintar_patron(
		img: Image, z: Rect2i, patron: String, sec: Color, ter: Color, n: int, es_espalda: bool
) -> void:
	var w := z.size.x
	var h := z.size.y
	match patron:
		"rayas_verticales":
			for i in range(1, n, 2):
				var x0 := roundi(i * w / float(n))
				var x1 := roundi((i + 1) * w / float(n))
				img.fill_rect(Rect2i(z.position.x + x0, z.position.y, x1 - x0, h), sec)
		"bandas_horizontales":
			for i in range(1, n, 2):
				var y0 := roundi(i * h / float(n))
				var y1 := roundi((i + 1) * h / float(n))
				img.fill_rect(Rect2i(z.position.x, z.position.y + y0, w, y1 - y0), sec)
		"banda_pecho":
			# Una franja ancha en el pecho; con color terciario, dos finas a los lados.
			var y := roundi(h * 0.36)
			var alto := roundi(h * 0.2)
			img.fill_rect(Rect2i(z.position.x, z.position.y + y, w, alto), sec)
			if ter != sec:
				img.fill_rect(Rect2i(z.position.x, z.position.y + y - 8, w, 6), ter)
				img.fill_rect(Rect2i(z.position.x, z.position.y + y + alto + 2, w, 6), ter)
		"franja_vertical":
			img.fill_rect(Rect2i(z.position.x + roundi(w * 0.36), z.position.y, roundi(w * 0.28), h), sec)
		"banda_diagonal":
			# Del hombro derecho a la cadera izquierda del jugador.
			_pintar_linea(img, z, sec, roundi(w * 0.24), func(t): return lerpf(0.0, w, 1.0 - t if es_espalda else t), 1.0)
		"v_frontal":
			# Solo adelante: una V de los hombros al centro del pecho.
			# Con terciario es tricolor: secundario, base y terciario.
			if es_espalda:
				return
			var ancho := 18
			for lado in [-1, 1]:
				var desde := 0.0 if lado == -1 else float(w)
				var hacia := w / 2.0
				var recorrido := func(t): return lerpf(desde, hacia, t)
				_pintar_linea(img, z, sec, ancho, recorrido, 0.55)
				if ter != sec:
					var desplazado := func(t): return lerpf(desde, hacia, t) - lado * ancho * 1.6
					_pintar_linea(img, z, ter, ancho, desplazado, 0.55)
		"mitades":
			# Mitad izquierda del jugador en color secundario. De frente queda
			# a la derecha de la imagen; de espaldas, a la izquierda.
			var x := 0 if es_espalda else w / 2
			img.fill_rect(Rect2i(z.position.x + x, z.position.y, w / 2, h), sec)
		"cuadros":
			var lado := maxi(w / n, 8)
			for cy in ceili(h / float(lado)):
				for cx in ceili(w / float(lado)):
					if (cx + cy) % 2 == 1:
						var r := Rect2i(z.position.x + cx * lado, z.position.y + cy * lado, lado, lado)
						img.fill_rect(r.intersection(z), sec)


## Pinta una línea gruesa que baja por la zona. centro(t) da la x del centro
## para t entre 0 (arriba) y 1 (abajo de la línea); hasta = qué fracción de
## la altura recorre.
static func _pintar_linea(img: Image, z: Rect2i, c: Color, ancho: int, centro: Callable, hasta: float) -> void:
	var filas := roundi(z.size.y * hasta)
	for y in filas:
		var cx := roundi(centro.call(y / float(maxi(filas - 1, 1))))
		var x0 := clampi(cx - ancho / 2, 0, z.size.x)
		var x1 := clampi(cx + ancho / 2, 0, z.size.x)
		if x1 > x0:
			img.fill_rect(Rect2i(z.position.x + x0, z.position.y + y, x1 - x0, 1), c)


static func _pintar_mangas(img: Image, patron: String, base: Color, sec: Color) -> void:
	img.fill_rect(MANGAS, base)
	if patron == "mitades":
		# Cada manga del color de su lado.
		img.fill_rect(Rect2i(MANGAS.position.x + MANGAS.size.x / 2, MANGAS.position.y, MANGAS.size.x / 2, MANGAS.size.y), sec)
	elif patron == "bandas_horizontales":
		for mitad in 2:
			var z := Rect2i(MANGAS.position.x + mitad * MANGAS.size.x / 2, MANGAS.position.y, MANGAS.size.x / 2, MANGAS.size.y)
			_pintar_patron(img, z, patron, sec, sec, 4, false)


static func _pegar(img: Image, fuente: Image, destino: Rect2i) -> void:
	if fuente == null or fuente.is_empty():
		return
	var copia := fuente.duplicate() as Image
	if copia.is_compressed():
		copia.decompress()
	copia.convert(Image.FORMAT_RGBA8)
	# Mantiene la proporción y centra dentro del destino.
	var escala := minf(destino.size.x / float(copia.get_width()), destino.size.y / float(copia.get_height()))
	var tam := Vector2i(maxi(1, roundi(copia.get_width() * escala)), maxi(1, roundi(copia.get_height() * escala)))
	copia.resize(tam.x, tam.y, Image.INTERPOLATE_LANCZOS)
	img.blend_rect(copia, Rect2i(Vector2i.ZERO, tam), destino.position + (destino.size - tam) / 2)


static func _tiene(d: Dictionary, clave: String) -> bool:
	var v = d.get(clave)
	return v is String and not v.is_empty()


static func _color(d: Dictionary, clave: String, por_defecto: Color) -> Color:
	return Color.html(d[clave]) if _tiene(d, clave) else por_defecto
