extends Control
## Fondo de los menús: cielo patagónico al atardecer, el Cerro Chenque recortado
## abajo y el pasto con franjas, como una cancha vista desde la tribuna.

const TemaUI := preload("res://scripts/ui/tema.gd")

const CIELO_ARRIBA := Color("0b1626")
const CIELO_ABAJO := Color("24456e")
const CERRO := Color("0a1220")
const PASTO_CLARO := Color("1d4a2a")
const PASTO_OSCURO := Color("173d22")

# Silueta del cerro, de izquierda a derecha (x de 0 a 1, y desde el horizonte hacia arriba).
const PERFIL_CERRO := [
	Vector2(0.0, 0.05), Vector2(0.08, 0.09), Vector2(0.16, 0.08), Vector2(0.24, 0.16), Vector2(0.3, 0.22),
	Vector2(0.36, 0.26), Vector2(0.42, 0.27), Vector2(0.48, 0.25), Vector2(0.55, 0.2), Vector2(0.62, 0.17),
	Vector2(0.7, 0.12), Vector2(0.8, 0.1), Vector2(0.9, 0.06), Vector2(1.0, 0.07),
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var horizonte := size.y * 0.72
	# Cielo en degradé, en franjas finas para no necesitar una textura.
	var pasos := 24
	for i in pasos:
		var t := float(i) / pasos
		var color := CIELO_ARRIBA.lerp(CIELO_ABAJO, t)
		draw_rect(Rect2(0, horizonte * t, size.x, horizonte / pasos + 1), color)

	var cerro := PackedVector2Array()
	for punto: Vector2 in PERFIL_CERRO:
		cerro.append(Vector2(punto.x * size.x, horizonte - punto.y * size.y))
	cerro.append(Vector2(size.x, horizonte))
	cerro.append(Vector2(0, horizonte))
	draw_colored_polygon(cerro, CERRO)

	# Pasto con franjas en perspectiva.
	draw_rect(Rect2(0, horizonte, size.x, size.y - horizonte), PASTO_OSCURO)
	var franjas := 9
	for i in franjas:
		var izquierda := float(i) / franjas
		var derecha := float(i + 1) / franjas
		var color := PASTO_CLARO if i % 2 == 0 else PASTO_OSCURO
		var arriba_izq := Vector2(lerpf(0.3, 0.7, izquierda) * size.x, horizonte)
		var arriba_der := Vector2(lerpf(0.3, 0.7, derecha) * size.x, horizonte)
		var abajo_der := Vector2(lerpf(-0.6, 1.6, derecha) * size.x, size.y)
		var abajo_izq := Vector2(lerpf(-0.6, 1.6, izquierda) * size.x, size.y)
		draw_colored_polygon(PackedVector2Array([arriba_izq, arriba_der, abajo_der, abajo_izq]), color)
	draw_line(Vector2(0, horizonte), Vector2(size.x, horizonte), Color(1, 1, 1, 0.12), 2.0)
	# Velo oscuro para que se lea el texto de arriba.
	draw_rect(Rect2(Vector2.ZERO, size), Color(TemaUI.FONDO, 0.35))
