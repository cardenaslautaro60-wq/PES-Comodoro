extends Control
## Pizarra con la cancha vista desde arriba y un punto por jugador, según la
## formación ("4-4-2", "4-3-3", "3-5-2"...). Las líneas se arman a partir del texto,
## así cualquier formación nueva se dibuja sola.

const TemaUI := preload("res://scripts/ui/tema.gd")

var formacion := "4-4-2":
	set(valor):
		formacion = valor
		queue_redraw()
var color_equipo := TemaUI.ACENTO:
	set(valor):
		color_equipo = valor
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## Posición de cada jugador en la cancha, de 0 a 1. El arquero es el primero.
## La x va del arco propio (0) al rival (1) y la y de una banda a la otra.
static func posiciones(texto: String) -> Array[Vector2]:
	var lista: Array[Vector2] = [Vector2(0.06, 0.5)]
	var lineas: Array[int] = []
	for parte in texto.split("-"):
		if parte.is_valid_int():
			lineas.append(int(parte))
	for i in lineas.size():
		var x := lerpf(0.25, 0.82, float(i) / maxi(1, lineas.size() - 1))
		var cantidad := lineas[i]
		for j in cantidad:
			lista.append(Vector2(x, (j + 1.0) / (cantidad + 1.0)))
	return lista


func _draw() -> void:
	var cancha := Rect2(Vector2(8, 8), size - Vector2(16, 16))
	var linea := Color(1, 1, 1, 0.5)
	draw_rect(cancha, Color("1d4a2a"))
	draw_rect(cancha, linea, false, 2.0)
	var medio := cancha.position.x + cancha.size.x / 2
	draw_line(Vector2(medio, cancha.position.y), Vector2(medio, cancha.end.y), linea, 2.0)
	draw_arc(cancha.get_center(), cancha.size.y * 0.13, 0, TAU, 32, linea, 2.0)
	for lado in [0.0, 1.0]:
		var area := Rect2(
			Vector2(cancha.position.x + lado * cancha.size.x * 0.84, cancha.position.y + cancha.size.y * 0.2),
			Vector2(cancha.size.x * 0.16, cancha.size.y * 0.6)
		)
		draw_rect(area, linea, false, 2.0)

	var radio := minf(cancha.size.x, cancha.size.y) * 0.045
	for punto in posiciones(formacion):
		var centro := cancha.position + punto * cancha.size
		draw_circle(centro, radio + 2, Color(0, 0, 0, 0.5))
		draw_circle(centro, radio, color_equipo)
