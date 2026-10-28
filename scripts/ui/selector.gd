extends HBoxContainer
## Selector táctil "◀ valor ▶": se toca una flecha para pasar a la opción
## anterior o a la siguiente. Se usa en vez de listas desplegables y deslizadores,
## que son chicos para el dedo.

signal cambio(indice: int)

const TemaUI := preload("res://scripts/ui/tema.gd")

var opciones: Array[String] = []
var indice := 0
## Si es true, después de la última opción vuelve a la primera.
var circular := true

var _anterior: Button
var _siguiente: Button
var _valor: Label


func _init() -> void:
	add_theme_constant_override("separation", 10)
	_anterior = _flecha("◀", -1)
	_valor = Label.new()
	_valor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_valor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_valor.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_valor.custom_minimum_size.x = 120
	_siguiente = _flecha("▶", 1)
	add_child(_anterior)
	add_child(_valor)
	add_child(_siguiente)


func configurar(textos: Array[String], inicial := 0) -> void:
	opciones = textos
	indice = clampi(inicial, 0, maxi(0, textos.size() - 1))
	_mostrar()


## Elige una opción sin avisar con `cambio` (para mostrar el valor guardado).
func elegir(nuevo: int) -> void:
	indice = clampi(nuevo, 0, maxi(0, opciones.size() - 1))
	_mostrar()


func mover(paso: int) -> void:
	if opciones.is_empty():
		return
	var nuevo := indice + paso
	if circular:
		nuevo = posmod(nuevo, opciones.size())
	else:
		nuevo = clampi(nuevo, 0, opciones.size() - 1)
	if nuevo == indice:
		return
	indice = nuevo
	_mostrar()
	Sonido.tocar_boton()
	cambio.emit(indice)


func texto_actual() -> String:
	return opciones[indice] if indice < opciones.size() else ""


func _mostrar() -> void:
	_valor.text = texto_actual()
	if not circular:
		_anterior.disabled = indice <= 0
		_siguiente.disabled = indice >= opciones.size() - 1


func _flecha(texto: String, paso: int) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(TemaUI.ALTO_BOTON, TemaUI.ALTO_BOTON)
	boton.pressed.connect(mover.bind(paso))
	return boton
