extends Node3D
## Entrenamiento: la escena para probar la jugabilidad.
##
## Arma la cancha, la pelota, tu equipo (rojo, ataca hacia la derecha) con cuatro
## jugadores y tres rivales azules quietos más un arquero quieto, para practicar
## conducción, pases, tiros, presión y barridas. Los rivales todavía no tienen IA
## (eso es del área C), pero si pasás muy cerca te pueden sacar la pelota.
##
## Cuenta los goles y vuelve a poner la pelota en el medio cuando sale o entra.
##
## Con `con_cinematicas`, arranca con la presentación y la salida de los equipos,
## cada gol tiene su festejo y su repetición, y a los `GOLES_PARA_TERMINAR` goles
## pasa la cinemática del final y el marcador vuelve a cero. La "R" (o "REPE" en
## el celular) muestra la repetición de la última jugada.

signal gol(equipo: String)

const ControlesTactiles := preload("res://scripts/ui/controles_tactiles.gd")
const HudJugador := preload("res://scripts/ui/hud_jugador.gd")
const BotonAccion := preload("res://scripts/ui/boton_accion.gd")

const COLOR_LOCAL := Color(0.80, 0.12, 0.15)
const COLOR_VISITANTE := Color(0.15, 0.30, 0.80)
const POSICION_SAQUE := Vector3(0, Pelota.RADIO + 0.02, 0)
## Goles de un equipo que terminan el entrenamiento (con la cinemática del final).
const GOLES_PARA_TERMINAR := 3
## Nombre, dorsal y posición de cada jugador del entrenamiento (nombres inventados).
const LOCALES := [
	["Vos", 10, Vector2(-0.7, 0)],
	["Gaitán", 9, Vector2(18, -12)],
	["Ñancucheo", 7, Vector2(14, 16)],
	["Ruiz", 5, Vector2(-14, 6)],
]
const VISITANTES := [
	["Molina", 4, Vector2(9, 3)],
	["Peralta", 6, Vector2(26, -6)],
	["Sosa", 2, Vector2(36, 9)],
	["Arquero", 1, Vector2(51, 0)],
]

## Las pruebas lo apagan antes de agregar la escena para arrancar directo a jugar.
@export var con_cinematicas := true

var goles_local := 0
var goles_visitante := 0
var nombre_local := "Local"
var nombre_visitante := "Visitante"
var nombre_estadio := "Cancha de entrenamiento"

var cancha: Cancha
var pelota: Pelota
var camara: CamaraTransmision
var control: ControlHumano
var jugadores: Array[Jugador] = []
var cinematicas: DirectorCinematicas

var _esperando_reinicio := false
var _temporizador_reinicio: Timer
var _marcador: Label
var _contador_fps: Label


func _ready() -> void:
	_temporizador_reinicio = Timer.new()
	_temporizador_reinicio.name = "TemporizadorReinicio"
	_temporizador_reinicio.one_shot = true
	_temporizador_reinicio.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_temporizador_reinicio.timeout.connect(_al_terminar_espera)
	add_child(_temporizador_reinicio)

	_crear_ambiente()
	cancha = Cancha.new()
	cancha.name = "Cancha"
	cancha.gol.connect(_al_gol)
	add_child(cancha)

	pelota = Pelota.new()
	pelota.name = "Pelota"
	# La posición se pone antes de entrar al árbol, así el cuerpo nace donde va.
	pelota.position = POSICION_SAQUE
	add_child(pelota)

	for datos: Array in LOCALES:
		_crear_jugador(datos, 0, COLOR_LOCAL)
	for datos: Array in VISITANTES:
		_crear_jugador(datos, 1, COLOR_VISITANTE)

	control = ControlHumano.new()
	control.name = "ControlHumano"
	add_child(control)
	control.configurar(pelota, jugadores[0])

	camara = CamaraTransmision.new()
	camara.name = "CamaraTransmision"
	camara.pelota = pelota
	add_child(camara)
	camara.current = true
	control.jugador_cambiado.connect(func(j: Jugador) -> void: camara.jugador = j)
	camara.jugador = control.jugador

	_crear_interfaz()

	if con_cinematicas:
		var fondo := FondoComodoroProvisorio.new()
		fondo.name = "FondoComodoro"
		add_child(fondo)
		cinematicas = DirectorCinematicas.new()
		cinematicas.name = "Cinematicas"
		cinematicas.partido = self
		add_child(cinematicas)
		_presentar.call_deferred()


func _process(_delta: float) -> void:
	_contador_fps.text = "%d FPS" % Engine.get_frames_per_second()


func _physics_process(_delta: float) -> void:
	if _esperando_reinicio or (cinematicas and cinematicas.activa):
		return
	var p := pelota.global_position
	var muy_lejos := absf(p.x) > Cancha.LARGO / 2 + Cancha.FONDO_ARCO + 1.0 or p.y < -1.0
	if Cancha.esta_afuera(p) or muy_lejos:
		_programar_reinicio(1.0)


## Pone la pelota en el medio y a cada jugador en su lugar.
func reiniciar_jugada() -> void:
	pelota.colocar(POSICION_SAQUE)
	var todos := LOCALES + VISITANTES
	for i in jugadores.size():
		var jugador := jugadores[i]
		var lugar: Vector2 = todos[i][2]
		jugador.detener()
		jugador.global_position = Vector3(lugar.x, Jugador.ALTURA / 2, lugar.y)
		jugador.direccion_mirada = Vector3(jugador.sentido_de_ataque(), 0, 0)
		jugador.estamina_actual = 1.0
	control.cambiar_a(jugadores[0])
	camara.cortar()


func _crear_jugador(datos: Array, equipo: int, color: Color) -> void:
	var jugador := Jugador.new()
	jugador.name = "%s%d" % ["Local" if equipo == 0 else "Visitante", datos[1]]
	jugador.nombre_jugador = datos[0]
	jugador.dorsal = datos[1]
	jugador.equipo = equipo
	jugador.color_equipo = color
	jugador.pelota = pelota
	jugador.direccion_mirada = Vector3(1 if equipo == 0 else -1, 0, 0)
	var lugar: Vector2 = datos[2]
	# Nace directamente en su lugar: si se lo mueve después, Godot lo toma como un
	# movimiento muy rápido.
	jugador.position = Vector3(lugar.x, Jugador.ALTURA / 2, lugar.y)
	add_child(jugador)
	jugadores.append(jugador)


func _programar_reinicio(segundos: float) -> void:
	_esperando_reinicio = true
	_temporizador_reinicio.start(segundos)


func _al_terminar_espera() -> void:
	reiniciar_jugada()
	_esperando_reinicio = false


func _al_gol(lado: int) -> void:
	if _esperando_reinicio:
		return
	# El local ataca hacia la derecha (x positivo).
	var equipo := "local" if lado > 0 else "visitante"
	if lado > 0:
		goles_local += 1
	else:
		goles_visitante += 1
	_actualizar_marcador()
	gol.emit(equipo)
	Controles.vibrar(200)
	if cinematicas == null:
		_programar_reinicio(2.0)
		return
	_esperando_reinicio = true
	await cinematicas.festejar_gol(lado)
	if maxi(goles_local, goles_visitante) >= GOLES_PARA_TERMINAR:
		reiniciar_jugada()
		await cinematicas.final_del_partido()
		goles_local = 0
		goles_visitante = 0
		_actualizar_marcador()
	reiniciar_jugada()
	_esperando_reinicio = false


func _presentar() -> void:
	await cinematicas.presentar_partido()
	reiniciar_jugada()


func _actualizar_marcador() -> void:
	_marcador.text = "%s  %d - %d  %s" % [
		nombre_local.to_upper(), goles_local, goles_visitante, nombre_visitante.to_upper()
	]


func _crear_ambiente() -> void:
	var material_cielo := ProceduralSkyMaterial.new()
	material_cielo.sky_top_color = Color(0.32, 0.52, 0.85)
	material_cielo.sky_horizon_color = Color(0.74, 0.82, 0.92)
	material_cielo.ground_horizon_color = Color(0.45, 0.42, 0.38)
	material_cielo.ground_bottom_color = Color(0.30, 0.28, 0.25)
	var cielo := Sky.new()
	cielo.sky_material = material_cielo

	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_SKY
	entorno.sky = cielo
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var mundo := WorldEnvironment.new()
	mundo.name = "Ambiente"
	mundo.environment = entorno
	add_child(mundo)

	# Tierra alrededor de la cancha hasta que el área E ponga el estadio.
	var tierra := PlaneMesh.new()
	tierra.size = Vector2(400, 400)
	var material_tierra := StandardMaterial3D.new()
	material_tierra.albedo_color = Color(0.42, 0.38, 0.30)
	material_tierra.roughness = 1.0
	tierra.material = material_tierra
	var vista_tierra := MeshInstance3D.new()
	vista_tierra.name = "Tierra"
	vista_tierra.mesh = tierra
	vista_tierra.position.y = -0.03
	vista_tierra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(vista_tierra)

	var sol := DirectionalLight3D.new()
	sol.name = "Sol"
	sol.rotation_degrees = Vector3(-50, -30, 0)
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 90.0
	add_child(sol)


func _crear_interfaz() -> void:
	var capa := CanvasLayer.new()
	capa.name = "Interfaz"
	add_child(capa)

	var hud: Control = HudJugador.new()
	hud.name = "HudJugador"
	hud.set("camara", camara)
	hud.set("control_humano", control)
	capa.add_child(hud)

	_marcador = Label.new()
	_marcador.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_marcador.offset_top = 12
	_marcador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marcador.add_theme_font_size_override("font_size", 30)
	_marcador.add_theme_color_override("font_outline_color", Color.BLACK)
	_marcador.add_theme_constant_override("outline_size", 6)
	capa.add_child(_marcador)
	_actualizar_marcador()

	_contador_fps = Label.new()
	_contador_fps.position = Vector2(12, 8)
	_contador_fps.add_theme_font_size_override("font_size", 18)
	capa.add_child(_contador_fps)

	if es_tactil():
		var tactiles: Control = ControlesTactiles.new()
		tactiles.name = "ControlesTactiles"
		tactiles.set("control_humano", control)
		capa.add_child(tactiles)
		if con_cinematicas:
			capa.add_child(_boton_repeticion())
	else:
		var ayuda := Label.new()
		ayuda.name = "Ayuda"
		ayuda.text = (
			"Mover: WASD   Sprint: Shift   Pase / presión: J   Tiro / barrida: K   "
			+ "Pase largo: L   Pase al hueco: I   Cambiar jugador: Q   Repetición: R\n"
			+ "Mantené el botón para cargar la potencia y soltalo para patear."
		)
		ayuda.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		ayuda.offset_top = -56
		ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ayuda.add_theme_font_size_override("font_size", 16)
		ayuda.add_theme_color_override("font_outline_color", Color.BLACK)
		ayuda.add_theme_constant_override("outline_size", 4)
		capa.add_child(ayuda)


## Botón chico arriba a la derecha para ver la repetición en el celular.
func _boton_repeticion() -> Button:
	var boton: Button = BotonAccion.new()
	boton.name = "BotonRepeticion"
	boton.set("accion", "repeticion")
	boton.text = "REPE"
	boton.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	boton.offset_left = -130
	boton.offset_top = 12
	boton.offset_right = -16
	boton.offset_bottom = 68
	boton.add_theme_font_size_override("font_size", 22)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0, 0, 0, 0.35)
	estilo.set_corner_radius_all(28)
	estilo.border_color = Color(1, 1, 1, 0.5)
	estilo.set_border_width_all(2)
	for estado: String in ["normal", "hover", "pressed"]:
		boton.add_theme_stylebox_override(estado, estilo)
	return boton


func es_tactil() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
