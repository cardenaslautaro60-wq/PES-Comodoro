extends Node
## Escena del partido: carga la cancha y el juego, y le suma el marcador, el
## reloj, la pausa y el sonido. Cuando termina, va a la pantalla del resultado.
##
## El juego en sí (cancha, jugadores, pelota) es otra escena, `ESCENA_JUEGO`, que
## hoy es el entrenamiento del área B. Lo que este script espera de esa escena:
## - una señal `gol(equipo: String)` con "local" o "visitante";
## - una variable `pelota` (RigidBody3D), para los sonidos;
## - opcional: `jugadores` (lista de `Jugador`), para ponerles los colores y los
##   nombres del plantel elegido;
## - opcional: `reiniciar_jugada()`, para sacar del medio después del entretiempo.
## Si la escena no trae su propio `Interfaz/HudJugador`, el HUD muestra el nombre,
## la estamina y la potencia del jugador que manejás (`control.jugador`).

const Hud := preload("res://scripts/ui/hud_partido.gd")
const Pausa := preload("res://scripts/partido/pausa.gd")
const Reloj := preload("res://scripts/partido/reloj_partido.gd")
const ESCENA_JUEGO := "res://escenas/partido/entrenamiento.tscn"

const MITAD_DEL_LARGO := 52.5
const MEDIO_ARCO := 3.66
## Cambio de velocidad (m/s) de la pelota a partir del cual suena un golpe.
const GOLPE_MINIMO := 2.5
const GOLPE_FUERTE := 15.0
const ESPERA_ENTRE_GOLPES := 0.12
const CANTICO_CADA_MIN := 35.0
const CANTICO_CADA_MAX := 70.0
const ESPERA_ANTES_DEL_RESULTADO := 3.0

var juego: Node
var hud: Hud
var pausa: Pausa
var reloj: Reloj

var _velocidad_anterior := Vector3.ZERO
var _espera_golpe := 0.0
var _espera_cantico := 0.0
var _nombre_jugador := ""


func _ready() -> void:
	ConfigPartido.preparar_si_falta()
	ConfigPartido.reiniciar_resultado()
	juego = (load(ESCENA_JUEGO) as PackedScene).instantiate()
	juego.name = "Juego"
	add_child(juego)
	_adaptar_juego()

	reloj = Reloj.new()
	reloj.name = "Reloj"
	reloj.segundos_reales_por_tiempo = ConfigPartido.minutos_por_tiempo * 60.0
	reloj.termino_tiempo.connect(_al_terminar_tiempo)
	reloj.termino_partido.connect(_al_terminar_partido)
	add_child(reloj)

	var capa := CanvasLayer.new()
	capa.name = "Interfaz"
	capa.layer = 5
	add_child(capa)
	hud = Hud.new()
	hud.name = "Hud"
	capa.add_child(hud)
	hud.mostrar_equipos(
		ConfigPartido.abreviatura_de("local"), ConfigPartido.abreviatura_de("visitante"),
		ConfigPartido.color_camiseta("local"), ConfigPartido.color_camiseta("visitante")
	)
	hud.mostrar_goles(0, 0)
	hud.pausa_pedida.connect(abrir_pausa)

	var capa_pausa := CanvasLayer.new()
	capa_pausa.name = "CapaPausa"
	capa_pausa.layer = 20
	add_child(capa_pausa)
	pausa = Pausa.new()
	pausa.name = "Pausa"
	pausa.salir_pedido.connect(_salir)
	pausa.repeticion_pedida.connect(_ver_repeticion)
	pausa.hay_repeticion = _cinematicas() != null
	capa_pausa.add_child(pausa)

	if juego.has_signal("gol"):
		juego.connect("gol", _al_gol)
	var destacado := ConfigPartido.jugador_destacado("local")
	if not destacado.is_empty():
		_nombre_jugador = "%d · %s" % [int(destacado.get("dorsal", 0)), destacado.get("nombre", "")]
	Opciones.cambiaron.connect(_aplicar_opciones)
	_aplicar_opciones()

	Sonido.ambiente_de_partido()
	Sonido.reproducir("silbato_largo")
	_espera_cantico = randf_range(CANTICO_CADA_MIN * 0.3, CANTICO_CADA_MAX * 0.5)
	var estadio := Catalogo.estadio(ConfigPartido.estadio_id)
	var detalle := str(estadio.get("nombre", "")) if not estadio.is_empty() else ""
	hud.mostrar_cartel("%s vs %s" % [ConfigPartido.nombre_de("local"), ConfigPartido.nombre_de("visitante")], detalle)


func _process(delta: float) -> void:
	hud.mostrar_reloj(reloj.texto(), reloj.texto_tiempo())
	_mostrar_jugador_activo()

	_espera_cantico -= delta
	if _espera_cantico <= 0.0:
		_espera_cantico = randf_range(CANTICO_CADA_MIN, CANTICO_CADA_MAX)
		Sonido.cantico_al_azar()


func _physics_process(delta: float) -> void:
	_escuchar_pelota(delta)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("pausa") or evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		volver()


## Botón "atrás" de Android y tecla Escape: abre o cierra la pausa.
func volver() -> void:
	if pausa.abierta:
		pausa.volver()
	else:
		abrir_pausa()


func abrir_pausa() -> void:
	if not reloj.terminado:
		pausa.abrir()


func _notification(que: int) -> void:
	# Si entra una llamada o se cambia de app, el partido queda en pausa.
	if que == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile") and is_node_ready():
		abrir_pausa()


## Ajusta la escena de juego: esconde su marcador (el del HUD es el que vale) y
## viste a los jugadores con la camiseta y los nombres de los clubes elegidos.
func _adaptar_juego() -> void:
	var marcador_viejo := juego.get_node_or_null("Interfaz/Marcador") as CanvasItem
	if marcador_viejo:
		marcador_viejo.visible = false
	var jugadores = juego.get("jugadores")
	if not jugadores is Array:
		return
	for jugador: Node in jugadores:
		var lado := "local" if int(jugador.get("equipo")) == 0 else "visitante"
		_pintar(jugador, ConfigPartido.color_camiseta(lado))
		var datos := _titular_con_dorsal(lado, int(jugador.get("dorsal")))
		if not datos.is_empty():
			jugador.set("nombre_jugador", str(datos.get("nombre", "")))


## Cambia el color del equipo en los materiales que ya tiene el jugador.
func _pintar(jugador: Node, color: Color) -> void:
	var anterior = jugador.get("color_equipo")
	if not anterior is Color:
		return
	for nodo in jugador.find_children("*", "MeshInstance3D", true, false):
		var malla := (nodo as MeshInstance3D).mesh
		var material := malla.surface_get_material(0) as StandardMaterial3D if malla else null
		if material and material.albedo_color.is_equal_approx(anterior):
			var nuevo := material.duplicate() as StandardMaterial3D
			nuevo.albedo_color = color
			(nodo as MeshInstance3D).material_override = nuevo
	jugador.set("color_equipo", color)


func _titular_con_dorsal(lado: String, dorsal: int) -> Dictionary:
	for id: String in ConfigPartido.titulares[lado]:
		var datos := ConfigPartido.jugador(lado, id)
		if int(datos.get("dorsal", -1)) == dorsal:
			return datos
	return {}


func _mostrar_jugador_activo() -> void:
	# El entrenamiento ya dibuja nombre, estamina y potencia arriba del jugador.
	if juego.has_node("Interfaz/HudJugador"):
		hud.mostrar_jugador("", 1.0)
		hud.mostrar_potencia(0.0)
		return
	var control = juego.get("control")
	var jugador = control.get("jugador") if control is Object else juego.get("jugador")
	if not jugador is Object:
		hud.mostrar_jugador(_nombre_jugador, 1.0)
		hud.mostrar_potencia(0.0)
		return
	var nombre = jugador.get("nombre_jugador")
	var texto := "%d · %s" % [int(jugador.get("dorsal")), nombre] if nombre != null else _nombre_jugador
	var estamina = jugador.get("estamina_actual")
	var potencia = jugador.get("potencia")
	hud.mostrar_jugador(texto, float(estamina) if estamina != null else 1.0)
	hud.mostrar_potencia(float(potencia) if potencia != null else 0.0)


func _aplicar_opciones() -> void:
	var fps := juego.get_node_or_null("Interfaz/ContadorFps") as CanvasItem
	if fps:
		fps.visible = Opciones.mostrar_fps


func _al_gol(equipo: String) -> void:
	if reloj.terminado or not ConfigPartido.goles.has(equipo):
		return
	ConfigPartido.goles[equipo] += 1
	hud.mostrar_goles(ConfigPartido.goles["local"], ConfigPartido.goles["visitante"])
	hud.mostrar_cartel("¡GOOOL!", "de " + ConfigPartido.nombre_de(equipo), 2.2)
	Sonido.reproducir("grito_gol")
	Sonido.reproducir("silbato_corto", -4.0)


func _al_terminar_tiempo(numero: int) -> void:
	if numero >= Reloj.TIEMPOS:
		return
	Sonido.reproducir("silbato_largo")
	hud.mostrar_cartel("Entretiempo", "%s %d - %d %s" % [
		ConfigPartido.abreviatura_de("local"), ConfigPartido.goles["local"],
		ConfigPartido.goles["visitante"], ConfigPartido.abreviatura_de("visitante"),
	], 2.5, Color.WHITE)
	if juego.has_method("reiniciar_jugada"):
		juego.call("reiniciar_jugada")


func _al_terminar_partido() -> void:
	ConfigPartido.terminado = true
	Sonido.reproducir("silbato_final")
	Sonido.intensidad(1.0)
	hud.mostrar_cartel("¡Final!", "", ESPERA_ANTES_DEL_RESULTADO, Color.WHITE)
	await get_tree().create_timer(ESPERA_ANTES_DEL_RESULTADO).timeout
	if is_inside_tree():
		Navegacion.ir_a(Navegacion.RESULTADO)


## Director de cinemáticas del área F, si la escena de juego lo tiene.
func _cinematicas() -> Object:
	var director = juego.get("cinematicas")
	return director if director is Object and director.has_method("repeticion_manual") else null


func _ver_repeticion() -> void:
	var director := _cinematicas()
	if director:
		director.call("repeticion_manual")


func _salir() -> void:
	Sonido.detener_todo()
	Navegacion.ir_a(Navegacion.MENU_PRINCIPAL)


## Hace sonar la pelota cuando cambia de golpe su velocidad (patada, pase o
## palo) y sube la hinchada cuando la pelota se acerca a un arco.
func _escuchar_pelota(delta: float) -> void:
	var pelota := juego.get("pelota") as RigidBody3D
	if pelota == null:
		return
	_espera_golpe -= delta
	var actual := pelota.linear_velocity
	var plana_actual := Vector2(actual.x, actual.z)
	var plana_anterior := Vector2(_velocidad_anterior.x, _velocidad_anterior.z)
	var cambio := (plana_actual - plana_anterior).length()
	var posicion := pelota.global_position
	if cambio >= GOLPE_MINIMO and _espera_golpe <= 0.0:
		var cerca_del_palo := absf(absf(posicion.x) - MITAD_DEL_LARGO) < 0.6 \
			and absf(absf(posicion.z) - MEDIO_ARCO) < 0.6
		if cerca_del_palo and plana_actual.dot(plana_anterior) < 0.0:
			Sonido.reproducir("poste")
			_espera_golpe = ESPERA_ENTRE_GOLPES
		elif plana_actual.length() > plana_anterior.length() + 1.0:
			var fuerte := cambio >= GOLPE_FUERTE
			var volumen := linear_to_db(clampf(cambio / GOLPE_FUERTE, 0.35, 1.0))
			Sonido.reproducir("patada" if fuerte else "pase", volumen, randf_range(0.94, 1.06))
			_espera_golpe = ESPERA_ENTRE_GOLPES
	_velocidad_anterior = actual
	Sonido.intensidad((absf(posicion.x) - 25.0) / (MITAD_DEL_LARGO - 25.0))
