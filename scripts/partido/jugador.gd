# gdlint: ignore=max-public-methods
class_name Jugador
extends CharacterBody3D
## Un futbolista: corre, hace sprint con estamina, conduce, pasa, patea con barra
## de potencia, presiona y barre.
##
## No lee el teclado ni la pantalla: hace lo que pide `entrada` (ver `EntradaJugador`).
## La llena `ControlHumano` cuando lo maneja una persona, o la IA (área C) cuando no.
## La IA también puede llamar directo a `patear()`, `barrer()` o `ir_hacia()`.
##
## Los botones dependen del momento, como en los juegos de fútbol clásicos:
## - Cuando tu equipo tiene la pelota: pase, tiro, pase largo y pase al hueco.
##   Se mantiene apretado para cargar la potencia y se suelta para patear.
## - Cuando la tiene el rival: el botón de pase presiona y el de tiro barre.
##
## El movimiento tiene inercia, como en los PES de la época: arranca rápido pero
## tarda en llegar a la velocidad máxima, en sprint abre los giros y en un giro
## cerrado planta el pie y frena antes de salir para el otro lado.
##
## En un tiro libre directo (`tiro_libre_directo`), el joystick apunta, el botón de
## tiro carga la potencia y, mientras se carga, el joystick elige el efecto: hacia
## un costado la pelota dobla para ese lado, hacia adelante baja de golpe (picada)
## y hacia atrás flota.

signal pelota_tomada
signal pateo(tipo: Patada, potencia: float)
signal barrida_empezada
signal falta_cometida(victima: Jugador)
signal derribado

enum Patada { PASE, PASE_LARGO, PASE_HUECO, TIRO }
enum Estado { NORMAL, BARRIDA, CAIDO }

const ALTURA := 1.8
const RADIO := 0.35
## Segundos que tarda en llenarse la barra de potencia.
const TIEMPO_CARGA := 1.0
## Aceleración en m/s² arrancando de parado (la achica la velocidad que ya lleva).
const ACELERACION := 18.0
const FRENADO := 24.0
## Velocidad de giro en rad/s: suelto (de parado y en sprint), con pelota y con pelota en sprint.
const GIRO_SIN_PELOTA := 14.0
const GIRO_SIN_PELOTA_SPRINT := 7.0
const GIRO_CON_PELOTA := 8.0
const GIRO_CON_PELOTA_SPRINT := 4.5
## Un giro de más de este ángulo (en grados) frena al jugador, más cuanto más cerrado.
const ANGULO_GIRO_LIBRE := 35.0
## En un giro de 180° corriendo a fondo, la velocidad baja a esta fracción.
const FRENO_GIRO_CERRADO := 0.3
## Cuánto más adelante empuja la pelota en sprint (toques largos que se pueden robar).
const TOQUE_LARGO_SPRINT := 0.3
## Efecto de los tiros comunes, en rad/s: los colocados (poca potencia) doblan más.
const EFECTO_TIRO_COLOCADO := 12.0
const EFECTO_TIRO_FUERTE := 3.0
## Velocidad a la que gira la puntería de un tiro libre, en rad/s.
const VELOCIDAD_APUNTE := 0.9
## Velocidad con la que salta (la barrera): unos 45 cm.
const VELOCIDAD_SALTO := 3.0
const DURACION_BARRIDA := 0.55
const RECUPERACION_BARRIDA := 0.45
const VELOCIDAD_BARRIDA := 9.5
const ALCANCE_BARRIDA := 0.8
const DURACION_CAIDA := 1.0
## Segundos en que no le pueden robar la pelota al que recién la tomó.
const PROTECCION_AL_TOMAR := 0.5
## Segundos que espera una patada cargada antes de que llegue la pelota (pase de primera).
const ESPERA_DE_PRIMERA := 0.7
## Error base de cada patada, en radianes. Lo achican los atributos.
const ERROR_BASE := {
	Patada.PASE: 0.05,
	Patada.PASE_LARGO: 0.06,
	Patada.PASE_HUECO: 0.05,
	Patada.TIRO: 0.08,
}
const BOTONES := {
	"pase": Patada.PASE,
	"tiro": Patada.TIRO,
	"pase_largo": Patada.PASE_LARGO,
	"pase_hueco": Patada.PASE_HUECO,
}

## 0 = local (ataca hacia x positivo), 1 = visitante (ataca hacia x negativo).
@export var equipo := 0
@export var dorsal := 10
@export var nombre_jugador := "Jugador"
@export var color_equipo := Color(0.80, 0.12, 0.15)

@export_group("Atributos (1 a 99)")
@export_range(1, 99) var velocidad := 70
@export_range(1, 99) var pase := 70
@export_range(1, 99) var tiro := 70
@export_range(1, 99) var defensa := 70
@export_range(1, 99) var estamina := 70
## Solo cuenta para los arqueros.
@export_range(1, 99) var atajada := 50

var pelota: Pelota
var entrada := EntradaJugador.new()
## De 0 (agotado) a 1 (descansado).
var estamina_actual := 1.0
## Hacia dónde mira, siempre horizontal y de largo 1.
var direccion_mirada := Vector3.RIGHT
var estado := Estado.NORMAL
## Barra de potencia: de 0 a 1 mientras se carga una patada, -1 si no se carga nada.
var potencia := -1.0
var patada_cargando := Patada.PASE
var presionando := false
var rng := RandomNumberGenerator.new()
## Hacia dónde ataca: 1 = x positivo, -1 = x negativo, 0 = según el equipo (el local
## hacia x positivo). El partido lo da vuelta en el entretiempo.
var sentido := 0
## Quieto en su lugar (por ejemplo, mientras espera para sacar un lateral). Puede
## girar para apuntar, pero no se mueve.
var inmovil := false
## Piel, pelo y barba para el modelo 3D (campo `apariencia` de los planteles).
var apariencia := {}
## Patea un tiro libre directo: apunta y le da efecto a mano (lo pone el árbitro).
var tiro_libre_directo := false
## Está en la barrera de un tiro libre (lo pone el árbitro). Salta cuando patean.
var en_barrera := false
## Lo echaron: ya no juega (ver `expulsar`).
var expulsado := false
## Cómo fue la última falta que hizo: {gravedad (0 a 1), con_pelota, de_atras}.
## La lee el árbitro para decidir la tarjeta.
var ultima_falta := {}
## Efecto elegido para el tiro libre que se está cargando: x = comba (+ a la
## derecha del que patea), y = picada (+ baja de golpe, - flota).
var efecto_tiro_libre := Vector2.ZERO

var _tiempo_estado := 0.0
var _sin_control := 0.0
var _protegido := 0.0
var _direccion_barrida := Vector3.ZERO
var _barrida_resuelta := false
var _botones_antes := {}
var _patada_pendiente := -1
var _potencia_pendiente := 0.0
var _espera_pendiente := 0.0
var _fase_toque := 0.0
var _destino := Vector3.ZERO
var _yendo_a_destino := false
var _material_camiseta: Material
var _salto_pendiente := false


func _init() -> void:
	collision_layer = CapasFisica.JUGADORES
	collision_mask = CapasFisica.MUNDO | CapasFisica.JUGADORES
	for boton: String in BOTONES:
		_botones_antes[boton] = false


func _ready() -> void:
	add_to_group("jugadores")
	if pelota == null:
		pelota = get_tree().get_first_node_in_group("pelota") as Pelota
	if get_node_or_null("Forma") == null:
		var capsula := CapsuleShape3D.new()
		capsula.radius = RADIO
		capsula.height = ALTURA
		var forma := CollisionShape3D.new()
		forma.name = "Forma"
		forma.shape = capsula
		add_child(forma)
	if get_node_or_null("Modelo") == null:
		_crear_modelo_provisorio()
	_orientar()


## Carga nombre, dorsal y atributos de un jugador de `datos/planteles/`.
func aplicar_datos(datos: Dictionary) -> void:
	var apodo: Variant = datos.get("apodo")
	nombre_jugador = str(apodo) if apodo else str(datos.get("nombre", nombre_jugador))
	dorsal = int(datos.get("dorsal", dorsal))
	var atributos: Dictionary = datos.get("atributos", datos)
	velocidad = clampi(int(atributos.get("velocidad", velocidad)), 1, 99)
	pase = clampi(int(atributos.get("pase", pase)), 1, 99)
	tiro = clampi(int(atributos.get("tiro", tiro)), 1, 99)
	defensa = clampi(int(atributos.get("defensa", defensa)), 1, 99)
	estamina = clampi(int(atributos.get("estamina", estamina)), 1, 99)
	atajada = clampi(int(atributos.get("atajada", atajada)), 1, 99)
	var datos_apariencia: Variant = datos.get("apariencia")
	if datos_apariencia is Dictionary:
		apariencia = datos_apariencia
	_actualizar_modelo()


func _physics_process(delta: float) -> void:
	_sin_control = maxf(_sin_control - delta, 0.0)
	_protegido = maxf(_protegido - delta, 0.0)
	_tiempo_estado += delta
	_fase_toque += delta

	match estado:
		Estado.NORMAL:
			_procesar_botones(delta)
			_mover(delta)
		Estado.BARRIDA:
			_paso_de_barrida(delta)
		Estado.CAIDO:
			_frenar_en_seco(delta)
			if _tiempo_estado >= DURACION_CAIDA:
				estado = Estado.NORMAL

	_actualizar_estamina(delta)
	if is_on_floor():
		velocity.y = 0.0
		if _salto_pendiente:
			velocity.y = VELOCIDAD_SALTO
	else:
		velocity.y -= _gravedad() * delta
	_salto_pendiente = false
	move_and_slide()
	_orientar()


# --- Consultas ----------------------------------------------------------------


func tiene_pelota() -> bool:
	return pelota != null and pelota.poseedor == self


## True cuando la pelota es de su equipo (la tiene un compañero o la tocó uno último).
func en_ataque() -> bool:
	if pelota == null:
		return false
	if pelota.poseedor != null:
		return pelota.poseedor.equipo == equipo
	return pelota.ultimo_en_tocar != null and pelota.ultimo_en_tocar.equipo == equipo


func puede_tomar_pelota() -> bool:
	return estado == Estado.NORMAL and _sin_control <= 0.0 and not expulsado


func esta_protegido() -> bool:
	return _protegido > 0.0


## Qué tan bien cuida la pelota (se usa en los robos).
func control_de_pelota() -> int:
	return int(pase * 0.6 + velocidad * 0.4)


## Hacia qué lado ataca: 1 = x positivo, -1 = x negativo.
func sentido_de_ataque() -> int:
	if sentido != 0:
		return sentido
	return 1 if equipo == 0 else -1


func velocidad_maxima(con_sprint: bool) -> float:
	var v := velocidad / 99.0
	var maxima := lerpf(7.4, 9.4, v) if con_sprint else lerpf(5.6, 7.0, v)
	if tiene_pelota():
		maxima *= 0.9 if con_sprint else 0.93
	if estamina_actual < 0.3:
		maxima *= lerpf(0.8, 1.0, estamina_actual / 0.3)
	return maxima


## Dónde lleva la pelota cuando conduce: adelante de los pies. Al correr la
## empuja más lejos, con toques que van y vienen.
func punto_de_conduccion() -> Vector3:
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var ritmo := clampf(horizontal.length() / velocidad_maxima(true), 0.0, 1.0)
	var toque := 0.25 * ritmo * (0.5 + 0.5 * sin(_fase_toque * TAU * (0.8 + 1.2 * ritmo)))
	if entrada.sprint and ritmo > 0.6:
		# En sprint la empuja más lejos: corre más pero se la pueden sacar.
		toque += TOQUE_LARGO_SPRINT * (ritmo - 0.6) / 0.4
	var punto := global_position + direccion_mirada * (RADIO + 0.3 + 0.35 * ritmo + toque)
	punto.y = Pelota.RADIO
	return punto


# --- Acciones (también para la IA) --------------------------------------------


## Patea la pelota si la tiene. Devuelve el compañero al que va el pase, o null.
## `direccion` es opcional: si no se pasa, usa la de la entrada o hacia dónde mira.
func patear(tipo: Patada, fuerza: float, direccion := Vector3.ZERO) -> Jugador:
	if not tiene_pelota():
		return null
	fuerza = clampf(fuerza, 0.0, 1.0)
	var dir := _direccion_de_patada(direccion)
	var destinatario: Jugador = null
	var velocidad_pelota: Vector3
	var giro := Vector3.ZERO

	match tipo:
		Patada.PASE:
			destinatario = buscar_companero(dir, 35.0, deg_to_rad(50))
			if destinatario:
				var punto := destinatario.global_position + destinatario.velocity * 0.4
				velocidad_pelota = _velocidad_rasante(punto, lerpf(4.0, 9.0, fuerza))
			else:
				velocidad_pelota = dir * lerpf(9.0, 20.0, fuerza)
		Patada.PASE_HUECO:
			destinatario = buscar_companero(dir, 45.0, deg_to_rad(60))
			if destinatario:
				var hacia_arco := Vector3(sentido_de_ataque(), 0, 0)
				var adelanto := (dir + hacia_arco).normalized()
				var punto := destinatario.global_position + adelanto * lerpf(5.0, 14.0, fuerza)
				velocidad_pelota = _velocidad_rasante(punto, 3.5)
			else:
				velocidad_pelota = dir * lerpf(10.0, 22.0, fuerza)
		Patada.PASE_LARGO:
			destinatario = buscar_companero(dir, 60.0, deg_to_rad(40))
			var punto := global_position + dir * lerpf(15.0, 50.0, fuerza)
			if destinatario:
				punto = destinatario.global_position + destinatario.velocity * 1.2
			velocidad_pelota = _velocidad_por_arriba(punto, deg_to_rad(lerpf(26.0, 34.0, fuerza)))
		Patada.TIRO:
			var tiro_calculado := _tiro_con_efecto(fuerza, dir)
			velocidad_pelota = tiro_calculado[0]
			giro = tiro_calculado[1]

	velocidad_pelota = _aplicar_error(velocidad_pelota, tipo, fuerza)
	pelota.patear(velocidad_pelota, giro, self, destinatario)
	_despues_de_patear(dir, tipo, fuerza)
	return destinatario


## Tiro libre a mano: sale hacia `direccion` (la altura y la fuerza dependen de
## `fuerza`) con `comba` (-1 a 1, + dobla a la derecha del que patea) y `picado`
## (-1 a 1, + baja de golpe, - flota). Ver `TiroLibre`.
func patear_tiro_libre(direccion: Vector3, fuerza: float, comba: float, picado: float) -> void:
	if not tiene_pelota():
		return
	fuerza = clampf(fuerza, 0.0, 1.0)
	var dir := Vector3(direccion.x, 0, direccion.z).normalized()
	var velocidad_pelota := TiroLibre.velocidad(dir, fuerza, tiro)
	var giro := TiroLibre.giro(dir, comba, picado, tiro)
	# El tiro libre se patea quieto y apuntando: sale más preciso que un tiro en carrera.
	velocidad_pelota = _aplicar_error(velocidad_pelota, Patada.TIRO, fuerza * 0.5)
	pelota.patear(velocidad_pelota, giro, self, null)
	tiro_libre_directo = false
	efecto_tiro_libre = Vector2.ZERO
	_despues_de_patear(dir, Patada.TIRO, fuerza)


func _despues_de_patear(dir: Vector3, tipo: Patada, fuerza: float) -> void:
	_sin_control = 0.3
	potencia = -1.0
	_patada_pendiente = -1
	direccion_mirada = dir
	pateo.emit(tipo, fuerza)


## Se tira a barrer hacia `direccion` (o hacia dónde mira).
func barrer(direccion := Vector3.ZERO) -> void:
	if estado != Estado.NORMAL:
		return
	var dir := direccion if direccion.length() > 0.1 else entrada.direccion
	if dir.length() < 0.2:
		dir = direccion_mirada
	dir.y = 0.0
	_direccion_barrida = dir.normalized()
	direccion_mirada = _direccion_barrida
	estado = Estado.BARRIDA
	_tiempo_estado = 0.0
	_barrida_resuelta = false
	potencia = -1.0
	estamina_actual = maxf(estamina_actual - 0.03, 0.0)
	barrida_empezada.emit()


## Le hace una falta a `victima`: la tira al piso y avisa al árbitro. `gravedad`
## va de 0 (leve) a 1 (para roja).
func cometer_falta(victima: Jugador, gravedad: float) -> void:
	var de_atras := victima.direccion_mirada.dot(direccion_mirada) > 0.5
	ultima_falta = {"gravedad": clampf(gravedad, 0.0, 1.0), "con_pelota": victima.tiene_pelota(), "de_atras": de_atras}
	victima.derribar()
	falta_cometida.emit(victima)


## Salta (la barrera, cuando patean el tiro libre).
func saltar() -> void:
	if estado == Estado.NORMAL:
		_salto_pendiente = true


## Lo echan: sale de la cancha y deja de jugar. El equipo lo saca de su lista
## (ver `EquipoPartido.expulsar`).
func expulsar() -> void:
	if tiene_pelota():
		pelota.soltar()
	expulsado = true
	inmovil = true
	en_barrera = false
	tiro_libre_directo = false
	entrada.limpiar()
	remove_from_group("jugadores")
	visible = false
	collision_layer = 0
	collision_mask = CapasFisica.MUNDO
	global_position = Vector3(global_position.x, ALTURA / 2, Cancha.ANCHO / 2 + 6.0)
	velocity = Vector3.ZERO
	process_mode = Node.PROCESS_MODE_DISABLED


## Lo tiran al piso (por una barrida). Si tenía la pelota, queda suelta.
func derribar() -> void:
	if tiene_pelota():
		pelota.soltar()
	estado = Estado.CAIDO
	_tiempo_estado = 0.0
	potencia = -1.0
	_sin_control = DURACION_CAIDA
	derribado.emit()


## Durante `segundos` no puede tomar la pelota (después de patear, de perderla, etc.).
func bloquear_control(segundos: float) -> void:
	_sin_control = maxf(_sin_control, segundos)


## Durante `segundos` no le pueden robar la pelota (por ejemplo, mientras saca).
func proteger(segundos: float) -> void:
	_protegido = maxf(_protegido, segundos)


## Lo llamá la pelota cuando este jugador la toma.
func al_tomar_pelota() -> void:
	_protegido = PROTECCION_AL_TOMAR
	pelota_tomada.emit()
	if _patada_pendiente >= 0 and _espera_pendiente > 0.0:
		# Pase o tiro de primera: el botón se soltó justo antes de que llegara.
		patear(_patada_pendiente as Patada, _potencia_pendiente)


## Lleva al jugador caminando hasta un punto (para reubicarlo o para la IA).
## Se cancela con `detener()` o cuando llega.
func ir_hacia(punto: Vector3) -> void:
	_destino = Vector3(punto.x, 0, punto.z)
	_yendo_a_destino = true


func detener() -> void:
	_yendo_a_destino = false
	velocity = Vector3.ZERO


## Toma como "ya vistos" los botones que están apretados ahora. Se usa al pasar
## el control a este jugador, así un botón que ya venía apretado no cuenta como nuevo.
func recordar_botones() -> void:
	for boton: String in BOTONES:
		_botones_antes[boton] = entrada.get(boton)


## El mejor compañero para un pase hacia `dir`: el más alineado y no muy lejos.
func buscar_companero(dir: Vector3, distancia_maxima: float, cono: float) -> Jugador:
	var mejor: Jugador = null
	var mejor_puntaje := INF
	for nodo in get_tree().get_nodes_in_group("jugadores"):
		var otro := nodo as Jugador
		if otro == null or otro == self or otro.equipo != equipo:
			continue
		var hacia := otro.global_position - global_position
		hacia.y = 0.0
		var distancia := hacia.length()
		if distancia < 2.0 or distancia > distancia_maxima:
			continue
		var angulo := dir.angle_to(hacia)
		if angulo > cono:
			continue
		var puntaje := angulo / cono + 0.5 * distancia / distancia_maxima
		if puntaje < mejor_puntaje:
			mejor = otro
			mejor_puntaje = puntaje
	return mejor


# --- Botones y movimiento -----------------------------------------------------


func _procesar_botones(delta: float) -> void:
	var ataque := en_ataque() or tiene_pelota()
	_espera_pendiente = maxf(_espera_pendiente - delta, 0.0)
	if potencia >= 0.0:
		potencia = minf(potencia + delta / TIEMPO_CARGA, 1.0)

	for boton: String in BOTONES:
		var ahora: bool = entrada.get(boton)
		var antes: bool = _botones_antes[boton]
		_botones_antes[boton] = ahora
		if ahora == antes:
			continue
		var tipo: Patada = BOTONES[boton]
		if ataque:
			if ahora and potencia < 0.0:
				potencia = 0.0
				patada_cargando = tipo
				efecto_tiro_libre = Vector2.ZERO
			elif not ahora and potencia >= 0.0 and patada_cargando == tipo:
				_soltar_patada(tipo)
		elif ahora and tipo == Patada.TIRO:
			barrer()
			return

	if not ataque:
		potencia = -1.0
	elif _cargando_tiro_libre():
		# Mientras carga, el joystick elige el efecto (relativo a hacia dónde apunta).
		var derecha := direccion_mirada.cross(Vector3.UP)
		efecto_tiro_libre = Vector2(entrada.direccion.dot(derecha), entrada.direccion.dot(direccion_mirada))
	presionando = not ataque and entrada.pase


func _cargando_tiro_libre() -> bool:
	return tiro_libre_directo and potencia >= 0.0 and patada_cargando == Patada.TIRO and tiene_pelota()


func _soltar_patada(tipo: Patada) -> void:
	var fuerza := potencia
	potencia = -1.0
	if tiro_libre_directo and tipo == Patada.TIRO and tiene_pelota():
		patear_tiro_libre(direccion_mirada, fuerza, efecto_tiro_libre.x, efecto_tiro_libre.y)
	elif tiene_pelota():
		patear(tipo, fuerza)
	else:
		# Todavía no llegó la pelota: queda anotada para patear de primera.
		_patada_pendiente = tipo
		_potencia_pendiente = fuerza
		_espera_pendiente = ESPERA_DE_PRIMERA


func _mover(delta: float) -> void:
	var deseo := entrada.direccion
	deseo.y = 0.0
	if presionando and pelota:
		deseo = _hacia(pelota.global_position)
	elif deseo.length() < 0.1 and pelota and pelota.destinatario == self and pelota.poseedor == null:
		# Le pasaron la pelota y nadie lo mueve: va al encuentro, trotando.
		deseo = _hacia(pelota.global_position) * 0.6
	elif _yendo_a_destino:
		if deseo.length() > 0.1 or _distancia_en_el_piso(_destino) < 0.3:
			_yendo_a_destino = false
		else:
			deseo = _hacia(_destino) * clampf(_distancia_en_el_piso(_destino) / 2.0, 0.3, 1.0)
	deseo = deseo.limit_length(1.0)

	if inmovil:
		if tiro_libre_directo and tiene_pelota():
			_apuntar_tiro_libre(deseo, delta)
		elif deseo.length() > 0.1:
			direccion_mirada = _girar_hacia(direccion_mirada, deseo.normalized(), GIRO_CON_PELOTA * delta)
		_frenar_en_seco(delta)
		return
	var con_sprint := entrada.sprint and estamina_actual > 0.05 and deseo.length() > 0.1
	var rapidez := velocidad_maxima(con_sprint) * deseo.length()
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var actual := horizontal.length()
	var ritmo := clampf(actual / velocidad_maxima(true), 0.0, 1.0)

	if deseo.length() > 0.05:
		var giro := lerpf(GIRO_SIN_PELOTA, GIRO_SIN_PELOTA_SPRINT, ritmo) if con_sprint else GIRO_SIN_PELOTA
		if tiene_pelota():
			giro = GIRO_CON_PELOTA_SPRINT if con_sprint else GIRO_CON_PELOTA
		direccion_mirada = _girar_hacia(direccion_mirada, deseo.normalized(), giro * delta)
		if actual > 3.0:
			# Giro cerrado a toda velocidad: planta el pie y frena antes de salir.
			var angulo := rad_to_deg(horizontal.angle_to(deseo))
			var cierre := clampf((angulo - ANGULO_GIRO_LIBRE) / (180.0 - ANGULO_GIRO_LIBRE), 0.0, 1.0)
			rapidez *= lerpf(1.0, FRENO_GIRO_CERRADO, cierre * ritmo)

	# Con la pelota o en sprint corre hacia donde mira (tiene que girar); si no, va directo.
	var hacia_mirada := tiene_pelota() or con_sprint
	var objetivo := (direccion_mirada if hacia_mirada else deseo.normalized()) * rapidez
	var aceleracion := _aceleracion(ritmo) if objetivo.length() >= actual else FRENADO
	horizontal = horizontal.move_toward(objetivo, aceleracion * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


## Aceleración según qué tan rápido va (`ritmo`, de 0 a 1 de la velocidad máxima en
## sprint): el arranque es explosivo y los últimos metros por segundo cuestan.
func _aceleracion(ritmo: float) -> float:
	return ACELERACION * lerpf(0.85, 1.1, velocidad / 99.0) * lerpf(1.2, 0.45, ritmo)


## Antes de cargar el tiro libre, el joystick hacia un costado gira la puntería de
## a poco (para afinar). Mientras se carga, la puntería queda fija.
func _apuntar_tiro_libre(deseo: Vector3, delta: float) -> void:
	if potencia >= 0.0 or deseo.length() < 0.15:
		return
	var derecha := direccion_mirada.cross(Vector3.UP)
	var lateral := deseo.dot(derecha)
	direccion_mirada = direccion_mirada.rotated(Vector3.UP, -lateral * VELOCIDAD_APUNTE * delta).normalized()


func _paso_de_barrida(delta: float) -> void:
	var t := _tiempo_estado
	if t < DURACION_BARRIDA:
		var rapidez := VELOCIDAD_BARRIDA * (1.0 - 0.6 * t / DURACION_BARRIDA)
		velocity.x = _direccion_barrida.x * rapidez
		velocity.z = _direccion_barrida.z * rapidez
		if not _barrida_resuelta:
			_comprobar_barrida()
	elif t < DURACION_BARRIDA + RECUPERACION_BARRIDA:
		_frenar_en_seco(delta)
	else:
		estado = Estado.NORMAL


## Si el pie llega primero a la pelota, la saca limpia. Si llega primero al
## rival, es falta.
func _comprobar_barrida() -> void:
	var pie := global_position + _direccion_barrida * (RADIO + 0.35)
	pie.y = 0.0
	if pelota and pelota.poseedor != self and pelota.global_position.y < 0.7:
		var a_pelota := Vector2(pelota.global_position.x - pie.x, pelota.global_position.z - pie.z).length()
		if a_pelota < ALCANCE_BARRIDA:
			var duenio := pelota.poseedor
			if duenio:
				duenio.bloquear_control(0.6)
			var salida := (_direccion_barrida + Vector3.UP * 0.15).normalized() * 7.0
			pelota.patear(salida, Vector3.ZERO, self)
			_barrida_resuelta = true
			return
	for nodo in get_tree().get_nodes_in_group("jugadores"):
		var rival := nodo as Jugador
		if rival == null or rival.equipo == equipo or rival.estado == Estado.CAIDO:
			continue
		if _distancia_en_el_piso(rival.global_position, pie) < ALCANCE_BARRIDA:
			cometer_falta(rival, _gravedad_de_barrida(rival))
			_barrida_resuelta = true
			return


## Qué tan fea fue la barrida: de atrás es mucho peor, y también si el rival ya no
## tenía la pelota (llegó tarde) o si se tiró de lejos, lanzado.
func _gravedad_de_barrida(rival: Jugador) -> float:
	var gravedad := 0.25
	if rival.direccion_mirada.dot(_direccion_barrida) > 0.5:
		gravedad += 0.4
	if not rival.tiene_pelota():
		gravedad += 0.15
	if _tiempo_estado > DURACION_BARRIDA * 0.6:
		gravedad += 0.1
	return gravedad


func _frenar_en_seco(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, FRENADO * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _actualizar_estamina(delta: float) -> void:
	var rapidez := Vector2(velocity.x, velocity.z).length()
	if entrada.sprint and rapidez > velocidad_maxima(false) * 0.9:
		# Con 99 de estamina aguanta unos 18 segundos de sprint; con 1, unos 7.
		estamina_actual -= delta / lerpf(7.0, 18.0, estamina / 99.0)
	elif rapidez < 1.0:
		estamina_actual += delta * 0.08
	else:
		estamina_actual += delta * 0.04
	estamina_actual = clampf(estamina_actual, 0.0, 1.0)


func _orientar() -> void:
	if direccion_mirada.length() > 0.01:
		global_basis = Basis.looking_at(direccion_mirada, Vector3.UP)


# --- Cálculo de patadas -------------------------------------------------------


func _direccion_de_patada(direccion: Vector3) -> Vector3:
	var dir := direccion
	if dir.length() < 0.1:
		dir = entrada.direccion if entrada.direccion.length() > 0.2 else direccion_mirada
	dir.y = 0.0
	return dir.normalized()


func _velocidad_rasante(punto: Vector3, velocidad_llegada: float) -> Vector3:
	var desde := pelota.global_position
	var hacia := Vector3(punto.x - desde.x, 0, punto.z - desde.z)
	var rapidez := pelota.velocidad_para_rodar(hacia.length(), velocidad_llegada)
	return hacia.normalized() * rapidez


func _velocidad_por_arriba(punto: Vector3, angulo: float) -> Vector3:
	var desde := pelota.global_position
	var hacia := Vector3(punto.x - desde.x, 0, punto.z - desde.z)
	var rapidez := pelota.velocidad_para_volar(hacia.length(), angulo)
	return hacia.normalized() * rapidez * cos(angulo) + Vector3.UP * rapidez * sin(angulo)


## Tiro al arco con efecto: devuelve [velocidad, giro]. El tiro colocado (poca
## potencia) dobla hacia el palo al que apunta, saliendo más cerca del arquero; el
## fuerte va casi derecho. La dirección se corrige para que la curva termine en el
## mismo lugar que el tiro sin efecto.
func _tiro_con_efecto(fuerza: float, dir: Vector3) -> Array:
	var velocidad_pelota := _velocidad_de_tiro(fuerza, dir)
	var arco := Cancha.centro_del_arco(sentido_de_ataque())
	var desde := pelota.global_position
	var horizontal := Vector3(velocidad_pelota.x, 0, velocidad_pelota.z)
	if horizontal.length() < 1.0 or absf(arco.x - desde.x) < 3.0 or absf(horizontal.x) < 0.1:
		return [velocidad_pelota, Vector3.ZERO]
	# Dónde cruzaría la línea del arco sin efecto.
	var z_objetivo := desde.z + horizontal.z * (arco.x - desde.x) / horizontal.x
	var derecha := horizontal.normalized().cross(Vector3.UP)
	var lado := signf(Vector3(0, 0, z_objetivo - arco.z).dot(derecha))
	if lado == 0.0:
		return [velocidad_pelota, Vector3.ZERO]
	var cantidad := lerpf(EFECTO_TIRO_COLOCADO, EFECTO_TIRO_FUERTE, fuerza) * lerpf(0.5, 1.0, tiro / 99.0)
	var giro := TiroLibre.giro(horizontal.normalized(), lado * cantidad / TiroLibre.COMBA_MAXIMA, 0.0, 99)
	var corregida := TiroLibre.corregir_direccion(pelota, desde, velocidad_pelota, giro, arco.x, z_objetivo)
	return [corregida, TiroLibre.giro_corregido(giro, velocidad_pelota, corregida)]


## Tiro al arco rival. Con poca potencia sale rasante; con mucha sale alto y
## fuerte, y pasado el 90 % se puede ir por arriba del travesaño.
func _velocidad_de_tiro(fuerza: float, dir: Vector3) -> Vector3:
	var arco_x := sentido_de_ataque() * Cancha.LARGO / 2
	var mitad_arco := Cancha.ANCHO_ARCO / 2 - 0.6
	# Arriba o abajo en el joystick apunta a ese palo; sin tocar, al palo más lejano.
	var apunte_z := clampf(dir.z / 0.7, -1.0, 1.0) * mitad_arco
	if absf(dir.z) < 0.25:
		# Sin apuntar a un costado: al palo más lejano.
		apunte_z = -signf(global_position.z) * mitad_arco * 0.6
	var altura := lerpf(0.2, 2.0, fuerza * fuerza)
	if fuerza > 0.9:
		altura += (fuerza - 0.9) * 14.0
	var rapidez := lerpf(15.0, 31.0, fuerza) * lerpf(0.85, 1.0, tiro / 99.0)
	var desde := pelota.global_position
	var hacia := Vector3(arco_x - desde.x, 0, apunte_z - desde.z)
	var angulo := pelota.angulo_para_altura(rapidez, hacia.length(), altura)
	return hacia.normalized() * rapidez * cos(angulo) + Vector3.UP * rapidez * sin(angulo)


## Ningún pase ni tiro sale perfecto: el error depende del atributo, de la
## potencia, del sprint y del cansancio.
func _aplicar_error(velocidad_pelota: Vector3, tipo: Patada, fuerza: float) -> Vector3:
	var habilidad := (tiro if tipo == Patada.TIRO else pase) / 99.0
	var desvio: float = ERROR_BASE[tipo] * (1.25 - habilidad) * (0.7 + 0.6 * fuerza)
	if entrada.sprint:
		desvio *= 1.3
	if estamina_actual < 0.3:
		desvio *= 1.3
	var horizontal := Vector3(velocidad_pelota.x, 0, velocidad_pelota.z).rotated(Vector3.UP, rng.randfn(0.0, desvio))
	var vertical := velocidad_pelota.y
	if tipo == Patada.TIRO or tipo == Patada.PASE_LARGO:
		vertical += rng.randfn(0.0, desvio) * velocidad_pelota.length() * 0.5
	return Vector3(horizontal.x, vertical, horizontal.z)


# --- Auxiliares ---------------------------------------------------------------


func _hacia(punto: Vector3) -> Vector3:
	var hacia := Vector3(punto.x - global_position.x, 0, punto.z - global_position.z)
	return hacia.normalized() if hacia.length() > 0.05 else Vector3.ZERO


func _distancia_en_el_piso(punto: Vector3, desde := Vector3.INF) -> float:
	var origen := global_position if desde == Vector3.INF else desde
	return Vector2(punto.x - origen.x, punto.z - origen.z).length()


func _girar_hacia(actual: Vector3, deseada: Vector3, maximo: float) -> Vector3:
	var angulo := actual.signed_angle_to(deseada, Vector3.UP)
	return actual.rotated(Vector3.UP, clampf(angulo, -maximo, maximo)).normalized()


func _gravedad() -> float:
	return ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _crear_modelo_provisorio() -> void:
	# El modelo tiene los pies en su origen; el jugador, el centro de la cápsula.
	var modelo := ModeloJugador.new()
	modelo.name = "Modelo"
	modelo.position.y = -ALTURA / 2
	add_child(modelo)
	_actualizar_modelo()


## Pone la camiseta de su equipo (un material de `GeneradorCamiseta`, el mismo
## para los 11). Sin camiseta, usa una lisa de `color_equipo`.
func vestir(material: Material) -> void:
	_material_camiseta = material
	_actualizar_modelo()


func _actualizar_modelo() -> void:
	var modelo := get_node_or_null("Modelo") as ModeloJugador
	if modelo == null:
		return
	var material := _material_camiseta if _material_camiseta else GeneradorCamiseta.material_liso(color_equipo)
	modelo.vestir(material, dorsal, apariencia)
