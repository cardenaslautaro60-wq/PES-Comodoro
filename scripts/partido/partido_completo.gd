class_name PartidoCompleto
extends Node3D
## Partido 11 contra 11 con IA, árbitro, reloj y marcador.
##
## Arma la cancha, la pelota, los dos equipos (del `Catalogo`), la IA de cada uno, el
## árbitro, el control de la persona (maneja al local), la cámara de TV y las
## cinemáticas del área F. Lo que se juega sale de `configuracion`; si no se pasa
## ninguna, se arma con lo elegido en los menús (`ConfigPartido`).
##
## Es la escena de juego que envuelve `partido.gd` (área G), que le suma el HUD, la
## pausa, el sonido y el resultado. También se puede abrir sola (F5 sobre la escena):
## ahí muestra su propio marcador, reloj y carteles.
##
## Lo que usa el partido del menú: la señal `gol`, `pelota`, `jugadores`, `arbitro`,
## `reiniciar_jugada()` (sigue después del entretiempo), `cambiar_formacion()` y
## `aplicar_cambios()`.

## Se hizo un gol: "local" o "visitante".
signal gol(equipo: String)

const ControlesTactiles := preload("res://scripts/ui/controles_tactiles.gd")
const HudJugador := preload("res://scripts/ui/hud_jugador.gd")

## Segundos que queda el aviso en pantalla ("Córner", "Falta", ...).
const DURACION_AVISO := 2.0
## Cambio automático: cuántos metros más cerca tiene que estar el otro compañero.
const VENTAJA_PARA_CAMBIAR := 5.0
const LADOS := ["local", "visitante"]

## Presentación, festejos con repetición, entretiempo y final (área F).
@export var con_cinematicas := true

var configuracion: ConfiguracionPartido
## True cuando lo envuelve el partido del menú: ahí el marcador, el reloj, los carteles,
## el entretiempo y el final los maneja `partido.gd`.
var envuelto := false

var cancha: Cancha
var pelota: Pelota
var arbitro: Arbitro
var camara: CamaraTransmision
## Null si juegan la máquina contra la máquina.
var control: ControlHumano
var cinematicas: DirectorCinematicas
var equipos: Array[EquipoPartido] = []
var ias: Array[IAEquipo] = []
## Los 22, primero los locales.
var jugadores: Array[Jugador] = []

# Para los títulos de las cinemáticas (el partido del menú los pisa).
var nombre_local := "Local"
var nombre_visitante := "Visitante"
var nombre_estadio := ""
var goles_local: int:
	get:
		return equipos[0].goles if equipos.size() > 0 else 0
var goles_visitante: int:
	get:
		return equipos[1].goles if equipos.size() > 1 else 0

var _espera_cambio := 0.0
var _tiempo_aviso := 0.0
var _marcador: Label
var _reloj: Label
var _aviso: Label
var _cartel: Label
var _contador_fps: Label


func _ready() -> void:
	if configuracion == null:
		var hay_menu := not ConfigPartido.local_id.is_empty()
		configuracion = ConfiguracionPartido.desde_menu() if hay_menu else ConfiguracionPartido.new()
	if con_cinematicas or envuelto:
		# El entretiempo termina cuando termina su cinemática o cuando el menú lo dice.
		configuracion.segundos_entretiempo = 0.0

	Ambiente.crear(self)
	cancha = Cancha.new()
	cancha.name = "Cancha"
	add_child(cancha)
	pelota = Pelota.new()
	pelota.name = "Pelota"
	pelota.position = Vector3(0, Pelota.RADIO + 0.02, 0)
	add_child(pelota)

	_armar_equipos()

	arbitro = Arbitro.new()
	arbitro.name = "Arbitro"
	arbitro.configuracion = configuracion
	add_child(arbitro)
	arbitro.configurar(cancha, pelota, equipos[0], equipos[1])

	for k in 2:
		var ia := IAEquipo.new()
		ia.name = "IA" + ("Local" if k == 0 else "Visitante")
		var humano := k == configuracion.equipo_humano
		ia.dificultad = ConfiguracionPartido.Dificultad.NORMAL if humano else configuracion.dificultad
		ia.rng.randomize()
		add_child(ia)
		ia.configurar(equipos[k], equipos[1 - k], pelota, arbitro)
		ias.append(ia)

	camara = CamaraTransmision.new()
	camara.name = "CamaraTransmision"
	camara.pelota = pelota
	add_child(camara)
	camara.current = true

	if configuracion.equipo_humano >= 0:
		control = ControlHumano.new()
		control.name = "ControlHumano"
		control.equipo = configuracion.equipo_humano
		add_child(control)
		control.jugador_cambiado.connect(_al_cambiar_jugador_humano)
		var propio := equipos[configuracion.equipo_humano]
		control.configurar(pelota, propio.jugadores[propio.jugadores.size() - 1])

	_crear_interfaz()
	arbitro.aviso.connect(_mostrar_aviso)
	arbitro.gol_convertido.connect(_al_gol)
	arbitro.entretiempo.connect(_al_entretiempo)
	arbitro.partido_terminado.connect(_al_terminar)
	arbitro.saque_preparado.connect(func(_t: int, _e: int, _j: Jugador) -> void: _al_saque())

	if con_cinematicas:
		cinematicas = DirectorCinematicas.new()
		cinematicas.name = "Cinematicas"
		cinematicas.partido = self
		add_child(cinematicas)
		cinematicas.cinematica_empezada.connect(func(_n: String) -> void: _pausar(true))
		cinematicas.cinematica_terminada.connect(func(_n: String, _s: bool) -> void: _pausar(false))
	_empezar.call_deferred()


func _process(delta: float) -> void:
	_contador_fps.text = "%d FPS" % Engine.get_frames_per_second()
	_reloj.text = "%d'" % arbitro.minuto()
	if _tiempo_aviso > 0.0:
		_tiempo_aviso -= delta
		_aviso.modulate.a = clampf(_tiempo_aviso / 0.4, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_cambio_automatico(delta)


func _unhandled_input(evento: InputEvent) -> void:
	if envuelto or (cinematicas and cinematicas.activa):
		return
	if arbitro.estado != Arbitro.Estado.FINAL and arbitro.estado != Arbitro.Estado.ENTRETIEMPO:
		return
	var toco: bool = evento is InputEventScreenTouch and evento.pressed
	toco = toco or evento is InputEventMouseButton and evento.pressed
	toco = toco or evento.is_action_pressed("pase") or evento.is_action_pressed("ui_accept")
	if not toco:
		return
	if arbitro.estado == Arbitro.Estado.ENTRETIEMPO:
		arbitro.continuar()
	else:
		get_tree().reload_current_scene()


## Sigue después del entretiempo (lo llama el partido del menú).
func reiniciar_jugada() -> void:
	_cartel.visible = false
	arbitro.continuar()


## Cambia la formación de un equipo en pleno partido (la pausa del área G).
func cambiar_formacion(nombre_formacion: String, indice := 0) -> void:
	equipos[indice].cambiar_formacion(nombre_formacion)


## Pasa a la cancha los cambios hechos en la pausa (`ConfigPartido.titulares`): el
## que entra toma el lugar del que sale.
func aplicar_cambios() -> void:
	for k in 2:
		var equipo := equipos[k]
		if equipo.club_id.is_empty() or equipo.club_id != _club_en_menu(k):
			continue
		var ids: Array = ConfigPartido.titulares[LADOS[k]]
		var en_cancha: Array[String] = []
		for datos in equipo.titulares:
			en_cancha.append(str(datos.get("id", "")))
		var entran: Array[String] = []
		for id: Variant in ids:
			if not en_cancha.has(str(id)):
				entran.append(str(id))
		for i in en_cancha.size():
			if entran.is_empty():
				break
			if not ids.has(en_cancha[i]):
				equipo.reemplazar(i, ConfigPartido.jugador(LADOS[k], entran.pop_front()))


func _club_en_menu(k: int) -> String:
	return ConfigPartido.local_id if k == 0 else ConfigPartido.visitante_id


# --- Armado -------------------------------------------------------------------


func _armar_equipos() -> void:
	var clubes := [configuracion.club_local, configuracion.club_visitante]
	var formaciones := [configuracion.formacion_local, configuracion.formacion_visitante]
	var titulares := [configuracion.titulares_local, configuracion.titulares_visitante]
	var colores := [configuracion.color_local, configuracion.color_visitante]
	for k in 2:
		var equipo := EquipoPartido.new()
		equipo.cargar_club(clubes[k], k, formaciones[k], titulares[k])
		if colores[k].a > 0.0:
			equipo.color = colores[k]
		equipos.append(equipo)
	var local := equipos[0]
	var visitante := equipos[1]
	if ConfigPartido.colores_se_confunden(local.color, visitante.color):
		visitante.color = visitante.color_suplente
		if ConfigPartido.colores_se_confunden(local.color, visitante.color):
			visitante.color = Color.WHITE if ConfigPartido.colores_se_confunden(local.color, Color.BLUE) else Color.BLUE
	if ConfigPartido.colores_se_confunden(local.color_arquero, visitante.color_arquero):
		visitante.color_arquero = Color(0.95, 0.85, 0.15)
	nombre_local = local.nombre
	nombre_visitante = visitante.nombre
	for equipo in equipos:
		equipo.preparar_camisetas(get_tree() if is_inside_tree() else null)

	for equipo in equipos:
		var extra := 0
		if configuracion.equipo_humano >= 0 and equipo.indice != configuracion.equipo_humano:
			extra = IAEquipo.PARAMETROS[configuracion.dificultad]["atributos"]
		for i in 11:
			equipo.jugadores.append(_crear_jugador(equipo, i, extra))


func _crear_jugador(equipo: EquipoPartido, i: int, extra: int) -> Jugador:
	var jugador := Jugador.new()
	jugador.aplicar_datos(equipo.titulares[i])
	jugador.name = "%s%d" % ["Local" if equipo.indice == 0 else "Visitante", i + 1]
	jugador.equipo = equipo.indice
	jugador.sentido = equipo.sentido
	jugador.color_equipo = equipo.color_arquero if equipo.puestos[i] == "ARQ" else equipo.color
	jugador.pelota = pelota
	jugador.rng.randomize()
	if extra != 0:
		jugador.velocidad = clampi(jugador.velocidad + extra, 1, 99)
		jugador.pase = clampi(jugador.pase + extra, 1, 99)
		jugador.tiro = clampi(jugador.tiro + extra, 1, 99)
		jugador.defensa = clampi(jugador.defensa + extra, 1, 99)
		jugador.atajada = clampi(jugador.atajada + extra, 1, 99)
	jugador.direccion_mirada = Vector3(equipo.sentido, 0, 0)
	var lugar := equipo.posicion_inicial(i)
	# Nace en su lugar (moverlo después de entrar al árbol se ve como un salto).
	jugador.position = Vector3(lugar.x, Jugador.ALTURA / 2, lugar.z)
	add_child(jugador)
	jugador.vestir(equipo.material_arquero if equipo.puestos[i] == "ARQ" else equipo.material_campo)
	jugadores.append(jugador)
	return jugador


## Presentación (si hay cinemáticas) y saque del medio.
func _empezar() -> void:
	if cinematicas:
		await cinematicas.presentar_partido()
	if not is_inside_tree():
		return
	arbitro.empezar()
	camara.cortar()


func _pausar(pausa: bool) -> void:
	for ia in ias:
		ia.en_pausa = pausa
	if pausa:
		arbitro.en_pausa = true
	else:
		arbitro.retomar()


# --- Cambio de jugador ------------------------------------------------------------


func _al_cambiar_jugador_humano(jugador: Jugador) -> void:
	ias[configuracion.equipo_humano].excluir(jugador)
	camara.jugador = jugador
	_espera_cambio = 1.0


## Defendiendo, pasa solo al compañero que está claramente más cerca de la pelota.
## Nunca deja a la persona manejando al arquero cuando la pelota es del rival.
func _cambio_automatico(delta: float) -> void:
	_espera_cambio -= delta
	if control == null or not configuracion.cambio_automatico or arbitro.estado != Arbitro.Estado.EN_JUEGO:
		return
	if cinematicas and cinematicas.activa:
		return
	var propio := equipos[configuracion.equipo_humano]
	var poseedor := pelota.poseedor
	if poseedor and poseedor.equipo == propio.indice:
		return
	var actual := control.jugador
	var es_arquero := actual == propio.arquero()
	if _espera_cambio > 0.0 and not es_arquero:
		return
	var b := pelota.global_position + pelota.linear_velocity * 0.4
	var mejor: Jugador = null
	var mejor_distancia := INF
	for jugador in propio.jugadores:
		if jugador == propio.arquero() or jugador.estado != Jugador.Estado.NORMAL:
			continue
		var distancia := Vector2(jugador.global_position.x - b.x, jugador.global_position.z - b.z).length()
		if distancia < mejor_distancia:
			mejor = jugador
			mejor_distancia = distancia
	if mejor == null or mejor == actual:
		return
	var distancia_actual := Vector2(actual.global_position.x - b.x, actual.global_position.z - b.z).length()
	if es_arquero or distancia_actual - mejor_distancia > VENTAJA_PARA_CAMBIAR:
		control.cambiar_a(mejor)


# --- Lo que pasa en el partido ----------------------------------------------------


func _al_saque() -> void:
	camara.cortar()
	_cartel.visible = false


func _al_gol(equipo: int, _autor: Jugador, _en_contra: bool) -> void:
	_actualizar_marcador()
	Controles.vibrar(200)
	gol.emit(LADOS[equipo])
	if not envuelto and cinematicas == null:
		_mostrar_aviso("¡GOOOL!")
	if cinematicas:
		cinematicas.festejar_gol(equipos[equipo].sentido, equipo)


func _al_entretiempo() -> void:
	if envuelto:
		return
	if cinematicas:
		while cinematicas.activa:
			await get_tree().process_frame
		await cinematicas.entretiempo()
		reiniciar_jugada()
		return
	_cartel.text = "ENTRETIEMPO\n%s\n\nTocá para seguir" % _resultado()
	_cartel.visible = true


func _al_terminar(_goles_local: int, _goles_visitante: int) -> void:
	if envuelto:
		return
	if cinematicas:
		while cinematicas.activa:
			await get_tree().process_frame
		await cinematicas.final_del_partido()
	_cartel.text = "FINAL DEL PARTIDO\n%s\n\nTocá para jugar la revancha" % _resultado()
	_cartel.visible = true


# --- Interfaz propia (cuando se abre sola) -------------------------------------------


func _resultado() -> String:
	return "%s  %d - %d  %s" % [equipos[0].nombre, equipos[0].goles, equipos[1].goles, equipos[1].nombre]


func _mostrar_aviso(texto: String) -> void:
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	_tiempo_aviso = DURACION_AVISO


func _actualizar_marcador() -> void:
	var local := equipos[0]
	var visitante := equipos[1]
	_marcador.text = "%s  %d - %d  %s" % [local.abreviatura, local.goles, visitante.goles, visitante.abreviatura]


func _crear_interfaz() -> void:
	var capa := CanvasLayer.new()
	capa.name = "Interfaz"
	add_child(capa)

	if control:
		var hud: Control = HudJugador.new()
		hud.name = "HudJugador"
		hud.set("camara", camara)
		hud.set("control_humano", control)
		capa.add_child(hud)

	# Marcador y reloj arriba a la izquierda, como en la tele. El partido del menú lo
	# esconde y usa el suyo.
	var caja := PanelContainer.new()
	caja.name = "Marcador"
	caja.position = Vector2(16, 36)
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0, 0, 0, 0.6)
	fondo.set_corner_radius_all(6)
	fondo.content_margin_left = 12
	fondo.content_margin_right = 12
	fondo.content_margin_top = 4
	fondo.content_margin_bottom = 4
	caja.add_theme_stylebox_override("panel", fondo)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	caja.add_child(fila)
	fila.add_child(_muestra_de_color(equipos[0].color))
	_marcador = _etiqueta(24)
	fila.add_child(_marcador)
	fila.add_child(_muestra_de_color(equipos[1].color))
	_reloj = _etiqueta(24)
	_reloj.custom_minimum_size.x = 52
	_reloj.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fila.add_child(_reloj)
	capa.add_child(caja)
	_actualizar_marcador()

	_aviso = _etiqueta(44)
	_aviso.name = "Aviso"
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_aviso.offset_top = 110
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.modulate.a = 0.0
	capa.add_child(_aviso)

	_cartel = _etiqueta(36)
	_cartel.name = "Cartel"
	_cartel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cartel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cartel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cartel.visible = false
	var oscuro := StyleBoxFlat.new()
	oscuro.bg_color = Color(0, 0, 0, 0.55)
	_cartel.add_theme_stylebox_override("normal", oscuro)
	capa.add_child(_cartel)

	_contador_fps = _etiqueta(16)
	_contador_fps.name = "ContadorFps"
	_contador_fps.position = Vector2(16, 8)
	capa.add_child(_contador_fps)

	if control and (DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")):
		var tactiles: Control = ControlesTactiles.new()
		tactiles.name = "ControlesTactiles"
		tactiles.set("control_humano", control)
		capa.add_child(tactiles)


func _etiqueta(tamano: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta.add_theme_constant_override("outline_size", 6)
	return etiqueta


func _muestra_de_color(color: Color) -> ColorRect:
	var muestra := ColorRect.new()
	muestra.color = color
	muestra.custom_minimum_size = Vector2(14, 22)
	return muestra
