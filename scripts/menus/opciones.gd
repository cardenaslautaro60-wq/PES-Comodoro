extends "res://scripts/menus/pantalla_menu.gd"
## Pantalla de opciones: volúmenes, vibración, tamaño de los botones,
## duración del partido y contador de FPS. Se guardan al salir.

signal cerrada

const Selector := preload("res://scripts/ui/selector.gd")
const PASOS_VOLUMEN := 10
const ESCALAS := [0.8, 0.9, 1.0, 1.15, 1.3, 1.4]
const NOMBRES_BUSES := {"Master": "Volumen general", "Musica": "Música", "Efectos": "Efectos", "Ambiente": "Hinchada"}

## Si es true, la pantalla está abierta arriba del partido (desde la pausa) y
## "volver" no cambia de escena sino que avisa con `cerrada`.
var dentro_del_partido := false

var selectores := {}



func armar() -> void:
	encabezado("Opciones")
	var desplazable := ScrollContainer.new()
	desplazable.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contenido.add_child(desplazable)
	var grilla := GridContainer.new()
	grilla.name = "Ajustes"
	grilla.columns = 2
	grilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grilla.add_theme_constant_override("h_separation", 18)
	grilla.add_theme_constant_override("v_separation", 10)
	desplazable.add_child(grilla)

	var niveles: Array[String] = []
	for i in PASOS_VOLUMEN + 1:
		niveles.append("■".repeat(i) + "□".repeat(PASOS_VOLUMEN - i) if i > 0 else "Sin sonido")
	for bus: String in Opciones.BUSES:
		var selector := _fila(grilla, NOMBRES_BUSES[bus], niveles, roundi(Opciones.volumen[bus] * PASOS_VOLUMEN))
		selector.circular = false
		selector.elegir(selector.indice)
		selector.cambio.connect(func(i: int) -> void: Opciones.cambiar_volumen(bus, float(i) / PASOS_VOLUMEN))
		selectores[bus] = selector

	var vibracion := _fila(grilla, "Vibración", ["Sí", "No"] as Array[String], 0 if Opciones.vibracion else 1)
	vibracion.cambio.connect(func(i: int) -> void:
		Opciones.cambiar_vibracion(i == 0)
		Opciones.vibrar(60)
	)
	selectores["vibracion"] = vibracion

	var textos_escala: Array[String] = []
	for escala: float in ESCALAS:
		textos_escala.append("%d %%" % roundi(escala * 100))
	var escala_botones := _fila(grilla, "Tamaño de botones", textos_escala, _indice_escala())
	escala_botones.circular = false
	escala_botones.elegir(escala_botones.indice)
	escala_botones.cambio.connect(func(i: int) -> void: Opciones.cambiar_escala_botones(ESCALAS[i]))
	selectores["escala_botones"] = escala_botones

	var textos_minutos: Array[String] = []
	for minutos: int in Opciones.MINUTOS_POSIBLES:
		textos_minutos.append("%d min por tiempo" % minutos)
	var duracion := _fila(
		grilla, "Duración del partido", textos_minutos, Opciones.MINUTOS_POSIBLES.find(Opciones.minutos_por_tiempo)
	)
	duracion.cambio.connect(func(i: int) -> void: Opciones.cambiar_minutos(Opciones.MINUTOS_POSIBLES[i]))
	selectores["minutos"] = duracion

	var fps := _fila(grilla, "Mostrar FPS", ["No", "Sí"] as Array[String], 1 if Opciones.mostrar_fps else 0)
	fps.cambio.connect(func(i: int) -> void: Opciones.cambiar_mostrar_fps(i == 1))
	selectores["fps"] = fps

	var abajo := HBoxContainer.new()
	abajo.alignment = BoxContainer.ALIGNMENT_END
	abajo.add_theme_constant_override("separation", 16)
	var fabrica := boton("Valores de fábrica", _restablecer)
	fabrica.name = "Restablecer"
	abajo.add_child(fabrica)
	contenido.add_child(abajo)


func volver() -> void:
	Opciones.guardar()
	if dentro_del_partido:
		cerrada.emit()
	else:
		Navegacion.ir_a(Navegacion.MENU_PRINCIPAL)


func _restablecer() -> void:
	Opciones.restablecer()
	for bus: String in Opciones.BUSES:
		selectores[bus].elegir(roundi(Opciones.volumen[bus] * PASOS_VOLUMEN))
	selectores["vibracion"].elegir(0)
	selectores["escala_botones"].elegir(_indice_escala())
	selectores["minutos"].elegir(Opciones.MINUTOS_POSIBLES.find(Opciones.minutos_por_tiempo))
	selectores["fps"].elegir(0)


func _indice_escala() -> int:
	var mejor := 0
	for i in ESCALAS.size():
		if absf(ESCALAS[i] - Opciones.escala_botones) < absf(ESCALAS[mejor] - Opciones.escala_botones):
			mejor = i
	return mejor


func _fila(grilla: GridContainer, texto: String, opciones: Array[String], inicial: int) -> Selector:
	grilla.add_child(TemaUI.etiqueta(texto, TemaUI.TAMANO_LETRA, TemaUI.TEXTO_SUAVE))
	var selector := Selector.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.custom_minimum_size.x = 420
	selector.configurar(opciones, maxi(0, inicial))
	grilla.add_child(selector)
	return selector
