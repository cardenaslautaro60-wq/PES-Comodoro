extends "res://scripts/menus/pantalla_menu.gd"
## Últimos detalles antes de jugar: estadio, duración, dificultad y formación.

const Escudo := preload("res://scripts/ui/escudo.gd")
const Selector := preload("res://scripts/ui/selector.gd")
const PizarraFormacion := preload("res://scripts/ui/pizarra_formacion.gd")

var selector_estadio: Selector
var selector_minutos: Selector
var selector_dificultad: Selector
var selector_formacion: Selector

var _estadios: Array[Dictionary] = []
var _detalle_estadio: Label
var _pizarra: PizarraFormacion


func armar() -> void:
	ConfigPartido.preparar_si_falta()
	encabezado("Preparar el partido")
	contenido.add_child(_crear_versus())

	var fila := HBoxContainer.new()
	fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fila.add_theme_constant_override("separation", 24)
	contenido.add_child(fila)

	var ajustes := GridContainer.new()
	ajustes.name = "Ajustes"
	ajustes.columns = 2
	ajustes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ajustes.add_theme_constant_override("h_separation", 18)
	ajustes.add_theme_constant_override("v_separation", 10)
	fila.add_child(ajustes)

	_estadios = Catalogo.estadios()
	var nombres_estadios: Array[String] = []
	var actual := 0
	for i in _estadios.size():
		nombres_estadios.append(str(_estadios[i].get("nombre", _estadios[i]["id"])))
		if str(_estadios[i]["id"]) == ConfigPartido.estadio_id:
			actual = i
	if nombres_estadios.is_empty():
		nombres_estadios.append("Cancha de prueba")
	selector_estadio = _agregar_fila(ajustes, "Estadio", nombres_estadios, actual)
	selector_estadio.cambio.connect(_al_elegir_estadio)
	_detalle_estadio = TemaUI.etiqueta("", TemaUI.TAMANO_CHICO, TemaUI.TEXTO_SUAVE)
	_detalle_estadio.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ajustes.add_child(Control.new())
	ajustes.add_child(_detalle_estadio)

	var textos_minutos: Array[String] = []
	for minutos: int in Opciones.MINUTOS_POSIBLES:
		textos_minutos.append("%d min por tiempo" % minutos)
	selector_minutos = _agregar_fila(
		ajustes, "Duración", textos_minutos, Opciones.MINUTOS_POSIBLES.find(ConfigPartido.minutos_por_tiempo)
	)
	selector_minutos.cambio.connect(func(i: int) -> void:
		ConfigPartido.minutos_por_tiempo = Opciones.MINUTOS_POSIBLES[i]
	)
	var dificultades: Array[String] = []
	dificultades.assign(ConfigPartido.DIFICULTADES)
	selector_dificultad = _agregar_fila(ajustes, "Dificultad", dificultades, ConfigPartido.dificultad)
	selector_dificultad.cambio.connect(func(i: int) -> void: ConfigPartido.dificultad = i)
	var formaciones: Array[String] = []
	formaciones.assign(ConfigPartido.FORMACIONES)
	selector_formacion = _agregar_fila(
		ajustes, "Formación", formaciones, ConfigPartido.FORMACIONES.find(ConfigPartido.formacion["local"])
	)
	selector_formacion.cambio.connect(_al_elegir_formacion)

	_pizarra = PizarraFormacion.new()
	_pizarra.name = "Pizarra"
	_pizarra.custom_minimum_size = Vector2(300, 200)
	_pizarra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pizarra.formacion = ConfigPartido.formacion["local"]
	_pizarra.color_equipo = ConfigPartido.color_camiseta("local")
	fila.add_child(_pizarra)

	var abajo := HBoxContainer.new()
	abajo.alignment = BoxContainer.ALIGNMENT_END
	var jugar := boton("¡A jugar!", _jugar, true)
	jugar.name = "Jugar"
	jugar.custom_minimum_size.x = 340
	abajo.add_child(jugar)
	contenido.add_child(abajo)
	_al_elegir_estadio(selector_estadio.indice)


func volver() -> void:
	Navegacion.ir_a(Navegacion.SELECCION_EQUIPOS)


func _jugar() -> void:
	ConfigPartido.reiniciar_resultado()
	Navegacion.ir_a(Navegacion.PARTIDO)


func _crear_versus() -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.name = "Versus"
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 18)
	for lado: String in ConfigPartido.LADOS:
		var escudo := Escudo.new()
		escudo.custom_minimum_size = Vector2(64, 64)
		escudo.club = ConfigPartido.club_de(lado)
		var nombre := TemaUI.etiqueta(ConfigPartido.nombre_de(lado), 34)
		if lado == "local":
			fila.add_child(escudo)
			fila.add_child(nombre)
			fila.add_child(TemaUI.etiqueta("vs", 28, TemaUI.ACENTO))
		else:
			fila.add_child(nombre)
			fila.add_child(escudo)
	return fila


func _agregar_fila(grilla: GridContainer, texto: String, opciones: Array[String], inicial: int) -> Selector:
	var etiqueta := TemaUI.etiqueta(texto, TemaUI.TAMANO_LETRA, TemaUI.TEXTO_SUAVE)
	grilla.add_child(etiqueta)
	var selector := Selector.new()
	selector.name = "Selector" + texto.replace("ó", "o")
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.configurar(opciones, maxi(0, inicial))
	grilla.add_child(selector)
	return selector


func _al_elegir_estadio(indice: int) -> void:
	if _estadios.is_empty():
		_detalle_estadio.text = "Todavía no hay estadios en datos/estadios/"
		return
	var estadio := _estadios[indice]
	ConfigPartido.estadio_id = str(estadio["id"])
	var partes: Array[String] = []
	for clave: String in ["barrio", "superficie"]:
		var valor := str(estadio.get(clave, ""))
		if not valor.is_empty() and valor != "a_confirmar":
			partes.append(valor.replace("_", " "))
	var capacidad := int(estadio.get("capacidad", 0)) if estadio.get("capacidad") is float else 0
	if capacidad > 0:
		partes.append("%d personas" % capacidad)
	_detalle_estadio.text = " · ".join(partes)


func _al_elegir_formacion(indice: int) -> void:
	ConfigPartido.cambiar_formacion("local", ConfigPartido.FORMACIONES[indice])
	_pizarra.formacion = ConfigPartido.formacion["local"]
