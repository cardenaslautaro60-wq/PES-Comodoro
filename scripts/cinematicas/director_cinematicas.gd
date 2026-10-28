class_name DirectorCinematicas
extends Node
## Arma y pasa las cinemáticas del partido: la presentación con la salida de los
## equipos, el festejo de gol con su repetición, la repetición manual, el
## entretiempo y el final.
##
## Todas se saltean con un toque, un clic, una tecla o un botón del joystick.
##
## Necesita un `partido`: el nodo de la escena del partido, con estas propiedades
## (como `entrenamiento.gd`): `pelota`, `jugadores`, `camara` (de transmisión) y,
## si hay, `control` (`ControlHumano`). Si además tiene `nombre_local`,
## `nombre_visitante`, `nombre_estadio`, `goles_local` y `goles_visitante`, los usa
## en los títulos. Si tiene un hijo `Interfaz` (CanvasLayer), lo esconde mientras
## dura la cinemática.
##
## Las funciones públicas se esperan con `await` y vuelven cuando terminó (o se
## salteó) la cinemática. La jugada no se reinicia sola: eso lo decide el partido.

signal cinematica_empezada(nombre: String)
signal cinematica_terminada(nombre: String, salteada: bool)

const PRESENTACION := "presentacion"
const GOL := "gol"
const REPETICION := "repeticion"
const ENTRETIEMPO := "entretiempo"
const FINAL := "final"
## Segundos de la jugada que se muestran en la repetición del gol.
const TRAMO_GOL := 4.5
## Segundos que se muestran en la repetición manual.
const TRAMO_MANUAL := 8.0
## Lo que sigue grabando después del gol (la pelota en la red).
const GRABAR_DESPUES_DEL_GOL := 0.7
## Dónde está la salida del túnel: al medio, del lado de la cámara de TV.
const TUNEL := Vector3(0, 0, Cancha.ANCHO / 2 + 6.0)
const ACCIONES_DEL_JUEGO := [
	"mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo",
	"pase", "tiro", "pase_largo", "pase_hueco", "sprint", "cambiar_jugador", "repeticion",
]

## La escena del partido (ver arriba).
@export var partido: Node3D
## Si es true, el botón de repetición ("R" o "Select") pasa la repetición manual.
@export var con_boton_repeticion := true
## Si es false, no se pasa la repetición automática después del festejo de gol.
@export var con_repeticion_de_gol := true

var activa := false
var nombre_actual := ""
var salteada := false
var camara: CamaraCinematica
var pantalla: PantallaCinematica
var grabador: GrabadorRepeticion

## Jugador -> [destino, rapidez (0 a 1), sprint, mirada final].
var _caminatas := {}
var _modo_control_antes := Node.PROCESS_MODE_INHERIT


func _ready() -> void:
	# Antes que los jugadores: las caminatas llenan su `entrada` en este cuadro.
	process_physics_priority = -5
	camara = CamaraCinematica.new()
	camara.name = "CamaraCinematica"
	add_child(camara)
	pantalla = PantallaCinematica.new()
	pantalla.name = "PantallaCinematica"
	pantalla.saltear_pedido.connect(saltear)
	add_child(pantalla)
	grabador = GrabadorRepeticion.new()
	grabador.name = "GrabadorRepeticion"
	add_child(grabador)
	if partido:
		registrar_actores.call_deferred()


## Vuelve a leer la pelota y los jugadores del partido (si cambian los equipos).
func registrar_actores() -> void:
	var nodos: Array = [_pelota()]
	nodos.append_array(_jugadores())
	grabador.registrar(nodos)


func _physics_process(_delta: float) -> void:
	if con_boton_repeticion and not activa and InputMap.has_action("repeticion"):
		if Input.is_action_just_pressed("repeticion"):
			repeticion_manual()
	_mover_caminatas()


## Corta la cinemática que está pasando.
func saltear() -> void:
	if activa:
		salteada = true


# --- Cinemáticas ---------------------------------------------------------------


## Antes del partido: pasada de cámara por el estadio, los equipos salen del
## túnel, se forman en la mitad de la cancha y la cámara pasa por la fila.
func presentar_partido() -> void:
	if not _empezar(PRESENTACION):
		return
	var pelota := _pelota()
	pelota.colocar(Vector3(0, Pelota.RADIO + 0.02, 0))
	var locales := _equipo(0)
	var visitantes := _equipo(1)
	var fila_z := Cancha.ANCHO / 2 - 7.0
	for i in locales.size():
		_poner(locales[i], TUNEL + Vector3(-0.9, 0, 1.3 * i), Vector3(0, 0, -1))
	for i in visitantes.size():
		_poner(visitantes[i], TUNEL + Vector3(0.9, 0, 1.3 * i), Vector3(0, 0, -1))

	pantalla.mostrar_titulo(_texto("nombre_estadio", "Estadio"), "Comodoro Rivadavia")
	camara.tomar(
		Toma.orbita(Vector3.ZERO, Vector2(115, 85), Vector2(48, 26), Vector2(35, 115), 5.0)
		.mirando(Vector3(0, 0, -6)).con_fov(50, 42)
	)
	pantalla.fundir(0.0, 0.0)
	if await _esperar(5.0):
		await _terminar()
		return

	# Salen del túnel caminando hacia la fila.
	for i in locales.size():
		_caminar(locales[i], Vector3(-1.5 - 1.3 * i, 0, fila_z), 0.55, false, Vector3(0, 0, 1))
	for i in visitantes.size():
		_caminar(visitantes[i], Vector3(1.5 + 1.3 * i, 0, fila_z), 0.55, false, Vector3(0, 0, 1))
	pantalla.mostrar_titulo(
		"%s  vs  %s" % [_texto("nombre_local", "Local").to_upper(), _texto("nombre_visitante", "Visitante").to_upper()]
	)
	var primero: Node3D = locales[0] if not locales.is_empty() else pelota
	camara.tomar(
		Toma.recorrido(
			Vector3(7, 1.5, Cancha.ANCHO / 2 - 11), Vector3(4.5, 1.3, Cancha.ANCHO / 2 - 12.5), 4.0
		).mirando(primero, 1.3).con_fov(40, 34)
	)
	if await _esperar(4.0):
		await _terminar()
		return

	# Paneo por la fila mientras saludan.
	pantalla.ocultar_titulo()
	for jugador in locales + visitantes:
		_terminar_caminata(jugador, true)
	var ancho_fila := 1.5 + 1.3 * maxi(maxi(locales.size(), visitantes.size()) - 1, 0)
	var camara_z := fila_z + 6.0
	camara.tomar(
		Toma.recorrido(Vector3(-ancho_fila - 1, 1.7, camara_z), Vector3(ancho_fila + 1, 1.7, camara_z), 4.5)
		.mirando_recorrido(Vector3(-ancho_fila + 1, 1.2, fila_z), Vector3(ancho_fila - 1, 1.2, fila_z))
		.con_fov(36)
	)
	for jugador in locales + visitantes:
		Gestos.hacer(jugador, Gestos.SALUDO, 4.0)
	if await _esperar(4.5):
		await _terminar()
		return

	# Grúa que sube y muestra toda la cancha.
	camara.tomar(
		Toma.recorrido(Vector3(0, 4, fila_z + 9), Vector3(0, 22, fila_z + 26), 3.0)
		.mirando_recorrido(Vector3(0, 1, fila_z), Vector3(0, 0, 0)).con_fov(42, 46)
	)
	await _esperar(2.4)
	await _fundido_y_terminar()


## Festejo de gol y su repetición. `lado` es el de `Cancha.gol`: 1 si entró en el
## arco de x positivo y -1 si entró en el otro. `equipo` es el que hizo el gol
## (0 local, 1 visitante); si no se pasa, se deduce del lado como en el primer
## tiempo (el local ataca hacia x positivo). Con cambio de lado, pasalo siempre.
func festejar_gol(lado: int, equipo := -1) -> void:
	if not _empezar(GOL, false):
		return
	var pelota := _pelota()
	var equipo_goleador := equipo if equipo >= 0 else (0 if lado > 0 else 1)
	var autor := pelota.ultimo_en_tocar
	var en_contra := autor != null and autor.equipo != equipo_goleador
	var festejante := autor if autor != null and not en_contra else _mas_cerca(equipo_goleador, pelota.global_position)
	var nombre_equipo := _texto("nombre_local" if equipo_goleador == 0 else "nombre_visitante", "")
	var subtitulo := ""
	if autor:
		subtitulo = "%s (en contra)" % autor.nombre_jugador if en_contra else "%s  %d" % [autor.nombre_jugador, autor.dorsal]
	elif nombre_equipo != "":
		subtitulo = nombre_equipo

	# La cámara de TV sigue un instante más, con la pelota entrando en la red.
	pantalla.mostrar_titulo("¡GOOOL!", subtitulo, true)
	if await _esperar(GRABAR_DESPUES_DEL_GOL):
		await _terminar()
		return
	grabador.grabando = false
	_usar_camara_cinematica(true)
	pantalla.empezar(true)

	if festejante:
		var p := _piso(festejante.global_position)
		var esquina := Vector3(lado * (Cancha.LARGO / 2 - 1.5), 0, signf(p.z + 0.01) * (Cancha.ANCHO / 2 - 1.5))
		var destino := p + (esquina - p).limit_length(14.0)
		var hacia := (destino - p).normalized() if destino.distance_to(p) > 0.5 else Vector3(lado, 0, 0)
		var costado := hacia.cross(Vector3.UP).normalized()
		_caminar(festejante, destino, 1.0, true)
		var companeros := _equipo(equipo_goleador)
		for i in companeros.size():
			var companero := companeros[i]
			if companero == festejante:
				continue
			var lugar := destino - hacia * 1.6 + costado * (1.4 * ((i % 3) - 1))
			_caminar(companero, lugar, 1.0, true)
		for rival in _equipo(1 - equipo_goleador):
			rival.detener()
			Gestos.hacer(rival, Gestos.LAMENTO)

		var lejos := hacia * 7.5 + costado * 2.0 + Vector3(0, 1.7, 0)
		var cerca := hacia * 4.0 + costado * 1.2 + Vector3(0, 1.3, 0)
		camara.tomar(Toma.recorrido(lejos, cerca, 3.0).siguiendo(festejante).mirando(festejante, 1.2).con_fov(46, 38))
		if await _esperar(3.0):
			await _terminar()
			return

		var desde_festejante := camara.global_position - festejante.global_position
		var angulo := rad_to_deg(atan2(desde_festejante.z, desde_festejante.x))
		for companero in companeros:
			Gestos.hacer(companero, Gestos.FESTEJO, 3.0)
		camara.tomar(
			Toma.orbita(Vector3.ZERO, Vector2(5.0, 4.2), Vector2(1.8, 2.6), Vector2(angulo, angulo + 70), 2.8)
			.siguiendo(festejante).mirando(festejante, 1.1).con_fov(40)
		)
		if await _esperar(2.8):
			await _terminar()
			return

	pantalla.ocultar_titulo()
	if con_repeticion_de_gol:
		await _repeticion_del_gol(lado)
	await _fundido_y_terminar()


## Repetición de los últimos segundos, cuando la pide la persona.
func repeticion_manual() -> void:
	if not grabador.hay_grabacion() or not _empezar(REPETICION, false):
		return
	_usar_camara_cinematica(true)
	pantalla.empezar(false)
	var fin := grabador.tiempo_final()
	var inicio := maxf(grabador.tiempo_inicial(), fin - TRAMO_MANUAL)
	grabador.empezar_reproduccion()
	pantalla.mostrar_repeticion(true)
	await _reproducir_tramo(inicio, fin, 1.0, _toma_tv_cerca(fin - inicio))
	grabador.terminar_reproduccion()
	await _terminar()


## Los jugadores van al túnel y se muestra el resultado del primer tiempo.
func entretiempo() -> void:
	if not _empezar(ENTRETIEMPO):
		return
	for jugador in _jugadores():
		var costado := -0.9 if jugador.equipo == 0 else 0.9
		_caminar(jugador, TUNEL + Vector3(costado, 0, 0), 0.5)
	pantalla.mostrar_titulo("ENTRETIEMPO", _resultado())
	# Desde arriba del túnel, mirando cómo vuelven.
	camara.tomar(
		Toma.recorrido(TUNEL + Vector3(-6, 14, 12), TUNEL + Vector3(4, 9, 8), 5.0)
		.mirando_recorrido(Vector3(-4, 0, 14), Vector3(2, 0, 26)).con_fov(50, 44)
	)
	await _esperar(4.5)
	await _fundido_y_terminar()


## Final del partido: el que ganó festeja, el que perdió se lamenta. Con empate,
## aplauden todos.
func final_del_partido() -> void:
	if not _empezar(FINAL):
		return
	var goles_local := int(_valor("goles_local", 0))
	var goles_visitante := int(_valor("goles_visitante", 0))
	var ganador := -1
	if goles_local != goles_visitante:
		ganador = 0 if goles_local > goles_visitante else 1
	var pelota := _pelota()
	pelota.colocar(Vector3(0, Pelota.RADIO + 0.02, -Cancha.ANCHO / 2 + 6))
	for jugador in _jugadores():
		jugador.detener()

	pantalla.mostrar_titulo("FINAL DEL PARTIDO", _resultado())
	camara.tomar(Toma.fija(Vector3(0, 30, 48), 2.5).mirando(Vector3(0, 0, 2)).con_fov(46, 38))
	if await _esperar(2.5):
		await _terminar()
		return

	var centro := Vector3.ZERO
	if ganador >= 0:
		var ganadores := _equipo(ganador)
		centro = _punto_de_reunion(ganadores)
		for i in ganadores.size():
			var angulo := TAU * i / maxf(ganadores.size(), 1)
			_caminar(ganadores[i], centro + Vector3(cos(angulo), 0, sin(angulo)) * 1.6, 0.9, true)
			Gestos.hacer(ganadores[i], Gestos.FESTEJO, 7.0)
		for perdedor in _equipo(1 - ganador):
			Gestos.hacer(perdedor, Gestos.LAMENTO)
		var nombre := _texto("nombre_local" if ganador == 0 else "nombre_visitante", "")
		pantalla.mostrar_titulo("¡GANÓ %s!" % nombre.to_upper() if nombre != "" else "¡VICTORIA!", _resultado(), true)
	else:
		for jugador in _jugadores():
			Gestos.hacer(jugador, Gestos.APLAUSO, 7.0)
		pantalla.mostrar_titulo("EMPATE", _resultado())

	camara.tomar(
		Toma.orbita(centro, Vector2(9, 6.5), Vector2(2.4, 3.4), Vector2(55, 150), 4.5)
		.mirando(centro, 1.0).con_fov(42)
	)
	if await _esperar(4.5):
		await _terminar()
		return
	camara.tomar(
		Toma.recorrido(centro + Vector3(0, 3, 9), centro + Vector3(0, 20, 30), 3.0)
		.mirando(centro, 0.5).con_fov(40, 46)
	)
	await _esperar(2.6)
	await _fundido_y_terminar()


# --- Repeticiones --------------------------------------------------------------


## Tres ángulos: TV de cerca, detrás del arco en cámara lenta y desde atrás del
## que patea.
func _repeticion_del_gol(lado: int) -> void:
	if not grabador.hay_grabacion():
		return
	var fin := grabador.tiempo_final()
	var inicio := maxf(grabador.tiempo_inicial(), fin - TRAMO_GOL)
	grabador.empezar_reproduccion()
	pantalla.mostrar_repeticion(true)

	await _reproducir_tramo(inicio, fin, 1.0, _toma_tv_cerca((fin - inicio)))
	if salteada:
		grabador.terminar_reproduccion()
		return

	var inicio_lento := maxf(inicio, fin - 2.5)
	var detras_del_arco := Vector3(lado * (Cancha.LARGO / 2 + 10.0), 5.0, 7.0)
	await _corte()
	await _reproducir_tramo(
		inicio_lento, fin, 0.5,
		Toma.fija(detras_del_arco, (fin - inicio_lento) / 0.5).mirando(_pelota(), 0.0).con_fov(40, 30)
	)
	if salteada:
		grabador.terminar_reproduccion()
		return

	var inicio_ras := maxf(inicio, fin - 2.2)
	await _corte()
	# Desde atrás del que patea, a la altura de los ojos.
	var toma_atras := Toma.recorrido(
		Vector3(-lado * 9.0, 1.6, 2.5), Vector3(-lado * 6.5, 1.3, 1.5), (fin - inicio_ras) / 0.7
	)
	toma_atras.suavizado = 3.0
	await _reproducir_tramo(
		inicio_ras, fin, 0.7, toma_atras.siguiendo(_pelota()).mirando(_pelota(), 0.2).con_fov(46, 38)
	)
	grabador.terminar_reproduccion()


func _toma_tv_cerca(segundos: float) -> Toma:
	var toma := Toma.recorrido(Vector3(0, 9, 17), Vector3(0, 8, 15), segundos)
	toma.suavizado = 2.5
	return toma.siguiendo(_pelota()).mirando(_pelota(), 0.0).con_fov(40)


## Muestra la grabación entre `desde` y `hasta` (en tiempo de la grabación) a
## `velocidad` (0,5 = la mitad de rápido), con la cámara en `toma`.
func _reproducir_tramo(desde: float, hasta: float, velocidad: float, toma: Toma) -> void:
	var t := desde
	grabador.mostrar(t)
	camara.tomar(toma)
	while t < hasta and not salteada:
		await get_tree().process_frame
		t += get_process_delta_time() * velocidad
		grabador.mostrar(minf(t, hasta))


## Un fundido rápido a negro entre dos ángulos.
func _corte() -> void:
	pantalla.fundir(1.0, 0.12)
	await _esperar(0.12)
	pantalla.fundir(0.0, 0.18)


# --- Empezar y terminar --------------------------------------------------------


## Prepara una cinemática. Devuelve false si ya hay otra pasando.
func _empezar(nombre: String, cambiar_camara := true) -> bool:
	if activa or partido == null:
		return false
	activa = true
	salteada = false
	nombre_actual = nombre
	_caminatas.clear()
	_soltar_controles()
	var control := _control()
	if control:
		_modo_control_antes = control.process_mode
		control.process_mode = Node.PROCESS_MODE_DISABLED
		if control is Node3D:
			# Esconde el aro del jugador que manejás.
			(control as Node3D).visible = false
	for jugador in _jugadores():
		jugador.entrada.limpiar()
	_mostrar_interfaz(false)
	if cambiar_camara:
		_usar_camara_cinematica(true)
		pantalla.empezar(true)
	else:
		# La cámara de TV sigue, pero ya se puede saltear.
		pantalla.empezar(false)
	cinematica_empezada.emit(nombre)
	return true


func _fundido_y_terminar() -> void:
	if not salteada:
		pantalla.fundir(1.0, 0.35)
		await _esperar(0.35)
	await _terminar()


func _terminar() -> void:
	if not activa:
		return
	var nombre := nombre_actual
	var fue_salteada := salteada
	if grabador.reproduciendo:
		grabador.terminar_reproduccion()
	_caminatas.clear()
	for jugador in _jugadores():
		Gestos.quitar(jugador)
		jugador.entrada.limpiar()
	_usar_camara_cinematica(false)
	pantalla.terminar()
	_mostrar_interfaz(true)
	var control := _control()
	if control:
		control.process_mode = _modo_control_antes
		if control is Node3D:
			(control as Node3D).visible = true
	_soltar_controles()
	grabador.limpiar()
	grabador.grabando = true
	activa = false
	nombre_actual = ""
	salteada = false
	# Un cuadro para que el partido reciba la señal con todo ya en su lugar.
	await get_tree().process_frame
	cinematica_terminada.emit(nombre, fue_salteada)


## Espera `segundos` o hasta que se saltee. Devuelve true si se salteó.
func _esperar(segundos: float) -> bool:
	var t := 0.0
	while t < segundos and not salteada:
		await get_tree().process_frame
		t += get_process_delta_time()
	return salteada


func _usar_camara_cinematica(usar: bool) -> void:
	var tv := partido.get("camara") as Camera3D
	if usar:
		camara.current = true
	else:
		camara.toma = null
		if tv:
			tv.current = true
			if tv.has_method("cortar"):
				tv.call("cortar")


func _mostrar_interfaz(mostrar: bool) -> void:
	var interfaz := partido.get_node_or_null("Interfaz") as CanvasLayer
	if interfaz:
		interfaz.visible = mostrar


func _soltar_controles() -> void:
	for accion: String in ACCIONES_DEL_JUEGO:
		if InputMap.has_action(accion):
			Input.action_release(accion)
	Controles.vector_tactil = Vector2.ZERO


# --- Mover a los jugadores -----------------------------------------------------


## Lleva al jugador a `destino` a `rapidez` (0 a 1 de lo que corre) y, al llegar,
## lo deja mirando hacia `mirada` (si no es cero).
func _caminar(jugador: Jugador, destino: Vector3, rapidez: float, sprint := false, mirada := Vector3.ZERO) -> void:
	_caminatas[jugador] = [Vector3(destino.x, 0, destino.z), rapidez, sprint, mirada]


func _terminar_caminata(jugador: Jugador, llevar_al_destino: bool) -> void:
	if not _caminatas.has(jugador):
		return
	var datos: Array = _caminatas[jugador]
	_caminatas.erase(jugador)
	if llevar_al_destino:
		var destino: Vector3 = datos[0]
		var mirada: Vector3 = datos[3]
		_poner(jugador, destino, mirada if mirada.length() > 0.1 else jugador.direccion_mirada)
	jugador.entrada.limpiar()


func _mover_caminatas() -> void:
	for jugador: Jugador in _caminatas.keys():
		if not is_instance_valid(jugador):
			_caminatas.erase(jugador)
			continue
		var datos: Array = _caminatas[jugador]
		var hacia: Vector3 = datos[0] - _piso(jugador.global_position)
		var distancia := hacia.length()
		if distancia < 0.25:
			var mirada: Vector3 = datos[3]
			if mirada.length() > 0.1:
				jugador.direccion_mirada = mirada.normalized()
			jugador.entrada.limpiar()
			jugador.velocity = Vector3.ZERO
			_caminatas.erase(jugador)
			continue
		jugador.entrada.direccion = hacia / distancia * float(datos[1]) * clampf(distancia / 1.5, 0.3, 1.0)
		jugador.entrada.sprint = datos[2]


## Pone al jugador quieto en un lugar, mirando hacia `mirada`.
func _poner(jugador: Jugador, lugar: Vector3, mirada: Vector3) -> void:
	jugador.detener()
	jugador.global_position = Vector3(lugar.x, Jugador.ALTURA / 2, lugar.z)
	if mirada.length() > 0.1:
		jugador.direccion_mirada = mirada.normalized()


# --- Datos del partido ---------------------------------------------------------


func _pelota() -> Pelota:
	return partido.get("pelota") as Pelota


func _control() -> Node:
	return partido.get("control") as Node


func _jugadores() -> Array[Jugador]:
	var lista: Array[Jugador] = []
	var todos: Variant = partido.get("jugadores")
	if todos is Array:
		for nodo: Variant in todos:
			if nodo is Jugador and is_instance_valid(nodo):
				lista.append(nodo)
	return lista


func _equipo(equipo: int) -> Array[Jugador]:
	var lista: Array[Jugador] = []
	for jugador in _jugadores():
		if jugador.equipo == equipo:
			lista.append(jugador)
	return lista


## Dónde se juntan a festejar: el centro del grupo, dentro de la cancha.
func _punto_de_reunion(grupo: Array[Jugador]) -> Vector3:
	var suma := Vector3.ZERO
	for jugador in grupo:
		suma += _piso(jugador.global_position)
	var centro := suma / maxf(grupo.size(), 1)
	centro.x = clampf(centro.x, -Cancha.LARGO / 2 + 8, Cancha.LARGO / 2 - 8)
	centro.z = clampf(centro.z, -Cancha.ANCHO / 2 + 8, Cancha.ANCHO / 2 - 8)
	return centro


func _mas_cerca(equipo: int, punto: Vector3) -> Jugador:
	var mejor: Jugador = null
	var mejor_distancia := INF
	for jugador in _equipo(equipo):
		var distancia := jugador.global_position.distance_to(punto)
		if distancia < mejor_distancia:
			mejor = jugador
			mejor_distancia = distancia
	return mejor


func _valor(propiedad: String, por_defecto: Variant) -> Variant:
	var valor: Variant = partido.get(propiedad)
	return por_defecto if valor == null else valor


func _texto(propiedad: String, por_defecto: String) -> String:
	var valor := str(_valor(propiedad, por_defecto))
	return valor if valor != "" else por_defecto


func _resultado() -> String:
	return "%s  %d - %d  %s" % [
		_texto("nombre_local", "Local").to_upper(), int(_valor("goles_local", 0)),
		int(_valor("goles_visitante", 0)), _texto("nombre_visitante", "Visitante").to_upper(),
	]


static func _piso(p: Vector3) -> Vector3:
	return Vector3(p.x, 0, p.z)
