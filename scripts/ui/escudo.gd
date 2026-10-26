extends Control
## Dibuja el escudo de un club.
##
## Si el club dio permiso (`escudo.permiso` = "aprobado") y hay imagen en
## `escudo.archivo_oficial`, muestra esa imagen. Si no, dibuja un escudo parodia
## con los colores, la forma y el texto de `escudo.parodia` del archivo del club.

const TemaUI := preload("res://scripts/ui/tema.gd")

var club: Dictionary = {}:
	set(valor):
		club = valor
		_preparar()
		queue_redraw()

var _imagen: Texture2D
var _forma := "escudo"
var _colores: Array[Color] = []
var _texto := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _preparar() -> void:
	_imagen = null
	var escudo: Dictionary = club.get("escudo", {})
	var oficial = escudo.get("archivo_oficial")
	if escudo.get("permiso") == "aprobado" and oficial is String and ResourceLoader.exists(oficial):
		_imagen = load(oficial) as Texture2D

	var parodia: Dictionary = escudo.get("parodia", {})
	_forma = _tipo_de_forma(str(parodia.get("forma", "escudo")).to_lower())
	_colores.clear()
	for texto in parodia.get("colores", club.get("colores", [])):
		if texto is String and Color.html_is_valid(texto):
			_colores.append(Color.html(texto))
	while _colores.size() < 3:
		_colores.append([TemaUI.PANEL_CLARO, TemaUI.TEXTO_SUAVE, Color.WHITE][_colores.size()])
	_texto = str(parodia.get("texto", club.get("abreviatura", "")))


static func _tipo_de_forma(descripcion: String) -> String:
	if descripcion.contains("círculo") or descripcion.contains("circulo"):
		return "circulo"
	if descripcion.contains("sheriff") or descripcion.contains("estrella"):
		return "estrella"
	if descripcion.contains("mitades") or descripcion.contains("partido en dos"):
		return "mitades"
	if descripcion.contains("franjas"):
		return "franjas"
	if descripcion.contains("redonde"):
		return "redondeado"
	return "escudo"


func _draw() -> void:
	if club.is_empty():
		return
	if _imagen:
		draw_texture_rect(_imagen, _cuadro(), false)
		return
	var principal := _colores[0]
	var segundo := _colores[1]
	var borde := _colores[2] if _colores[2] != principal else segundo
	var contorno := _contorno(1.0)
	var interior := _contorno(0.86)
	draw_colored_polygon(contorno, borde)
	draw_colored_polygon(interior, principal)
	match _forma:
		"mitades":
			_pintar_dentro(interior, _rect_relativo(0.5, 0.0, 0.5, 1.0), segundo)
		"franjas":
			for i in 3:
				_pintar_dentro(interior, _rect_relativo(0.18 + i * 0.25, 0.0, 0.12, 1.0), segundo)
		"circulo", "estrella":
			pass
		_:
			_pintar_dentro(interior, _rect_relativo(0.0, 0.58, 1.0, 0.16), segundo)
	draw_polyline(_cerrar(contorno), Color(0, 0, 0, 0.35), 2.0, true)
	_escribir_texto(principal)


func _escribir_texto(fondo: Color) -> void:
	if _texto.is_empty():
		return
	var cuadro := _cuadro()
	var fuente := get_theme_default_font()
	var tamano := int(cuadro.size.y * (0.3 if _texto.length() <= 3 else 0.22))
	var ancho := fuente.get_string_size(_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	var limite := cuadro.size.x * 0.78
	if ancho > limite:
		tamano = int(tamano * limite / ancho)
		ancho = limite
	var color := Color.WHITE if fondo.get_luminance() < 0.6 else Color(0.08, 0.08, 0.1)
	var base := Vector2(cuadro.position.x + (cuadro.size.x - ancho) / 2, cuadro.position.y + cuadro.size.y * 0.47)
	base.y += fuente.get_ascent(tamano) * 0.35
	var sombra := Color(0, 0, 0, 0.45) if color == Color.WHITE else Color(1, 1, 1, 0.4)
	draw_string_outline(fuente, base, _texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, maxi(2, tamano / 8), sombra)
	draw_string(fuente, base, _texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, color)


func _cuadro() -> Rect2:
	var lado := minf(size.x, size.y)
	return Rect2((size - Vector2(lado, lado)) / 2, Vector2(lado, lado))


## Contorno de la forma, achicado por `escala` alrededor del centro.
func _contorno(escala: float) -> PackedVector2Array:
	var cuadro := _cuadro()
	var centro := cuadro.get_center()
	var radio := cuadro.size.x / 2 * escala
	var puntos := PackedVector2Array()
	match _forma:
		"circulo":
			for i in 48:
				puntos.append(centro + Vector2.from_angle(TAU * i / 48) * radio)
		"estrella":
			for i in 12:
				var r := radio if i % 2 == 0 else radio * 0.62
				puntos.append(centro + Vector2.from_angle(-PI / 2 + TAU * i / 12) * r)
		_:
			var redondeado := _forma == "redondeado"
			var arriba := centro.y - radio * 0.92
			var izquierda := centro.x - radio * 0.82
			var derecha := centro.x + radio * 0.82
			puntos.append(Vector2(izquierda, arriba))
			puntos.append(Vector2(derecha, arriba))
			puntos.append(Vector2(derecha, centro.y + radio * (0.25 if redondeado else 0.1)))
			# Parte de abajo en curva hasta la punta.
			for i in range(1, 12):
				var t := float(i) / 12
				var x := lerpf(derecha, centro.x, t)
				var curva := sin(t * PI / 2)
				var y := lerpf(centro.y + radio * (0.25 if redondeado else 0.1), centro.y + radio, curva)
				puntos.append(Vector2(x, y))
			puntos.append(Vector2(centro.x, centro.y + radio))
			for i in range(11, 0, -1):
				var t := float(i) / 12
				var x := lerpf(izquierda, centro.x, t)
				var curva := sin(t * PI / 2)
				var y := lerpf(centro.y + radio * (0.25 if redondeado else 0.1), centro.y + radio, curva)
				puntos.append(Vector2(x, y))
			puntos.append(Vector2(izquierda, centro.y + radio * (0.25 if redondeado else 0.1)))
	return puntos


func _rect_relativo(x: float, y: float, ancho: float, alto: float) -> PackedVector2Array:
	var cuadro := _cuadro()
	var desde := cuadro.position + Vector2(x, y) * cuadro.size
	var hasta := desde + Vector2(ancho, alto) * cuadro.size
	return PackedVector2Array([desde, Vector2(hasta.x, desde.y), hasta, Vector2(desde.x, hasta.y)])


## Pinta la parte de `figura` que cae dentro de `limite`.
func _pintar_dentro(limite: PackedVector2Array, figura: PackedVector2Array, color: Color) -> void:
	for pedazo in Geometry2D.intersect_polygons(limite, figura):
		if pedazo.size() >= 3:
			draw_colored_polygon(pedazo, color)


static func _cerrar(puntos: PackedVector2Array) -> PackedVector2Array:
	var cerrado := puntos.duplicate()
	cerrado.append(puntos[0])
	return cerrado
