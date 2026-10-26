extends Control
## Dibujo plano de una camiseta con su pantalón, armado con los datos del club
## (patrón, colores, cuello y hombreras). Sirve para elegir equipo sin cargar el 3D.

const TemaUI := preload("res://scripts/ui/tema.gd")

# Silueta de la camiseta en un cuadro de 0 a 1 (ancho) por 0 a 0,8 (alto).
const SILUETA := [
	Vector2(0.37, 0.04), Vector2(0.5, 0.1), Vector2(0.63, 0.04), Vector2(0.86, 0.12),
	Vector2(1.0, 0.33), Vector2(0.85, 0.42), Vector2(0.78, 0.36), Vector2(0.78, 0.8),
	Vector2(0.22, 0.8), Vector2(0.22, 0.36), Vector2(0.15, 0.42), Vector2(0.0, 0.33),
	Vector2(0.14, 0.12),
]
const MANGA_IZQUIERDA := [Vector2(0.37, 0.04), Vector2(0.14, 0.12), Vector2(0.0, 0.33), Vector2(0.15, 0.42),
	Vector2(0.22, 0.36), Vector2(0.3, 0.2)]
const MANGA_DERECHA := [Vector2(0.63, 0.04), Vector2(0.86, 0.12), Vector2(1.0, 0.33), Vector2(0.85, 0.42),
	Vector2(0.78, 0.36), Vector2(0.7, 0.2)]

## Datos de la camiseta, como en `camisetas.titular` del archivo del club.
var camiseta: Dictionary = {}:
	set(valor):
		camiseta = valor
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if camiseta.is_empty():
		return
	var base := Catalogo.color(camiseta, "color_base", TemaUI.PANEL_CLARO)
	var segundo := Catalogo.color(camiseta, "color_secundario", base.darkened(0.3))
	var tercero := Catalogo.color(camiseta, "color_terciario", segundo)
	var silueta := _a_pantalla(SILUETA)

	_dibujar_pantalon(Catalogo.color(camiseta, "pantalon", base))
	draw_colored_polygon(silueta, base)
	for franja in _patron(str(camiseta.get("patron", "liso")), tercero != segundo):
		_pintar_dentro(silueta, _a_pantalla(franja[0]), segundo if not franja[1] else tercero)

	var hombreras = camiseta.get("hombreras")
	if hombreras is String and Color.html_is_valid(hombreras):
		for manga in [MANGA_IZQUIERDA, MANGA_DERECHA]:
			_pintar_dentro(silueta, _a_pantalla(manga), Color.html(hombreras))

	var cuello := Catalogo.color(camiseta, "cuello", base.darkened(0.25))
	var puntos_cuello := _a_pantalla([Vector2(0.37, 0.04), Vector2(0.5, 0.1), Vector2(0.63, 0.04)])
	draw_polyline(puntos_cuello, cuello, maxf(3.0, size.x * 0.03), true)
	var contorno := silueta.duplicate()
	contorno.append(silueta[0])
	draw_polyline(contorno, Color(0, 0, 0, 0.35), 2.0, true)
	_dibujar_numero(Catalogo.color(camiseta, "numero", Color.WHITE))


## Cada franja es [polígono, usa_tercer_color].
func _patron(patron: String, hay_tercero: bool) -> Array:
	var franjas := []
	match patron:
		"rayas_verticales":
			for i in 3:
				var x := 0.29 + i * 0.16
				franjas.append([_rect(x, 0.0, 0.08, 0.8), hay_tercero and i == 1])
		"bandas_horizontales":
			for i in 3:
				franjas.append([_rect(0.0, 0.16 + i * 0.22, 1.0, 0.1), hay_tercero and i == 1])
		"mitades":
			franjas.append([_rect(0.5, 0.0, 0.5, 0.8), false])
		"banda_diagonal":
			franjas.append([[Vector2(0.14, 0.12), Vector2(0.3, 0.08), Vector2(0.86, 0.72), Vector2(0.78, 0.8)], false])
		"v_frontal":
			franjas.append([[Vector2(0.33, 0.06), Vector2(0.5, 0.36), Vector2(0.67, 0.06), Vector2(0.72, 0.09),
				Vector2(0.5, 0.46), Vector2(0.28, 0.09)], false])
			if hay_tercero:
				franjas.append([[Vector2(0.4, 0.1), Vector2(0.5, 0.3), Vector2(0.6, 0.1), Vector2(0.64, 0.12),
					Vector2(0.5, 0.38), Vector2(0.36, 0.12)], true])
		"banda_pecho":
			franjas.append([_rect(0.0, 0.3, 1.0, 0.13), false])
	return franjas


func _dibujar_pantalon(color: Color) -> void:
	var pantalon := _a_pantalla([Vector2(0.23, 0.8), Vector2(0.77, 0.8), Vector2(0.8, 0.98), Vector2(0.53, 0.98),
		Vector2(0.5, 0.9), Vector2(0.47, 0.98), Vector2(0.2, 0.98)])
	draw_colored_polygon(pantalon, color)
	var contorno := pantalon.duplicate()
	contorno.append(pantalon[0])
	draw_polyline(contorno, Color(0, 0, 0, 0.3), 2.0, true)


func _dibujar_numero(color: Color) -> void:
	var fuente := get_theme_default_font()
	var cuadro := _cuadro()
	var tamano := int(cuadro.size.x * 0.26)
	var texto := "10"
	var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	var base := cuadro.position + Vector2((cuadro.size.x - ancho) / 2, cuadro.size.y * 0.6)
	draw_string_outline(fuente, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, 4, Color(0, 0, 0, 0.35))
	draw_string(fuente, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, color)


func _cuadro() -> Rect2:
	var lado := minf(size.x, size.y)
	return Rect2((size - Vector2(lado, lado)) / 2, Vector2(lado, lado))


func _a_pantalla(puntos: Array) -> PackedVector2Array:
	var cuadro := _cuadro()
	var salida := PackedVector2Array()
	for punto: Vector2 in puntos:
		salida.append(cuadro.position + punto * cuadro.size)
	return salida


static func _rect(x: float, y: float, ancho: float, alto: float) -> Array:
	return [Vector2(x, y), Vector2(x + ancho, y), Vector2(x + ancho, y + alto), Vector2(x, y + alto)]


func _pintar_dentro(limite: PackedVector2Array, figura: PackedVector2Array, color: Color) -> void:
	for pedazo in Geometry2D.intersect_polygons(limite, figura):
		if pedazo.size() >= 3:
			draw_colored_polygon(pedazo, color)
