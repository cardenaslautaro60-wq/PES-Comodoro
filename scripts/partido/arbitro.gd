class_name Arbitro
extends Node
## El árbitro: lleva el reloj, el marcador y hace cumplir las reglas.
##
## - Reloj: dos tiempos de `minutos_por_tiempo` minutos reales cada uno, que en
##   pantalla se ven como 45 minutos. Entretiempo con cambio de lado y final.
## - Saque del medio al empezar cada tiempo y después de cada gol.
## - Lateral, córner y saque de arco según quién la tocó último.
## - Faltas (las barridas que llegan al cuerpo y los empujones de atrás): tiro
##   libre, o penal si fue dentro del área del que la cometió.
## - Tarjetas según la gravedad de la falta: amarilla, roja directa (falta muy fea o
##   cortando una ocasión clara de gol) y roja por doble amarilla. El expulsado sale
##   en la próxima pelota parada y el equipo sigue con uno menos.
## - Ley de ventaja: si el equipo que recibió la falta sigue con la pelota en campo
##   rival, se juega; si la pierde enseguida, se vuelve a cobrar el tiro libre.
## - Barrera en los tiros libres cerca del arco (ver `TiroLibre`): a 9,15 m, de 2 a
##   5 jugadores que saltan cuando patean. El que patea apunta y le da efecto.
## - Offside opcional (`configuracion.offside`).
##
## Para cada saque elige quién saca, lo deja quieto con la pelota (`Jugador.inmovil`)
## y espera a que patee. Mientras, la IA acomoda al resto con `restringir_posicion()`.

signal silbato(motivo: Motivo)
signal estado_cambiado(estado: Estado)
signal saque_preparado(tipo: Saque, equipo: int, ejecutor: Jugador)
## `equipo` es el que hizo el gol. `en_contra` es true si la tocó último un rival.
signal gol_convertido(equipo: int, autor: Jugador, en_contra: bool)
signal falta_sancionada(infractor: Jugador, victima: Jugador, es_penal: bool)
signal offside_sancionado(jugador: Jugador)
## `roja` es true si lo echan (directa o por doble amarilla).
signal tarjeta_mostrada(jugador: Jugador, roja: bool)
## El expulsado ya salió de la cancha (en la pelota parada siguiente a la roja).
signal jugador_expulsado(jugador: Jugador)
signal entretiempo
signal partido_terminado(goles_local: int, goles_visitante: int)
## Texto corto para mostrar en pantalla ("¡GOL!", "Córner", ...).
signal aviso(texto: String)

enum Estado { PREVIA, SAQUE, EN_JUEGO, DETENIDO, FESTEJO, ENTRETIEMPO, FINAL }
enum Saque { INICIAL, LATERAL, CORNER, ARCO, TIRO_LIBRE, PENAL }
enum Motivo { INICIO, GOL, AFUERA, FALTA, OFFSIDE, ENTRETIEMPO, FINAL }

const NOMBRES_SAQUE := ["Saque del medio", "Lateral", "Córner", "Saque de arco", "Tiro libre", "Penal"]
## Distancia a la que tienen que estar los rivales en un tiro libre, córner o saque del medio.
const DISTANCIA_REGLAMENTARIA := 9.15
const DISTANCIA_LATERAL := 2.5
## Segundos entre el silbato y el saque (para que se vea por qué se cobró).
const PAUSA_TRAS_SILBATO := 1.3
const DURACION_FESTEJO := 3.5
## Minutos que se muestran por tiempo.
const MINUTOS_REGLAMENTARIOS := 45
## Segundos que espera el árbitro para ver si la ventaja sirvió.
const DURACION_VENTAJA := 1.6
## Qué tan estricto es: multiplica la gravedad de las faltas al decidir tarjetas.
const RIGOR := 1.0

var pelota: Pelota
## Mientras es true no corre nada (ni el reloj ni las esperas): por ejemplo, durante
## una cinemática del área F.
var en_pausa := false
## Si es mayor que 0, reemplaza a `configuracion.minutos_por_tiempo` (para las pruebas).
var segundos_por_tiempo := 0.0
## Local y visitante.
var equipos: Array[EquipoPartido] = []
var configuracion := ConfiguracionPartido.new()

var estado := Estado.PREVIA
## 1 o 2.
var periodo := 1
## Segundos reales jugados del tiempo actual.
var segundos_jugados := 0.0
var tipo_saque := Saque.INICIAL
var equipo_saque := 0
var ejecutor: Jugador
var lugar_saque := Vector3.ZERO
## Qué equipo sacó del medio en el primer tiempo.
var saca_primero := 0
## Quién hizo cada gol, en orden: [{equipo, autor, minuto, en_contra}].
var goles: Array[Dictionary] = []
## Las tarjetas, en orden: [{jugador, equipo, roja, minuto}].
var tarjetas: Array[Dictionary] = []
## Los de la barrera del tiro libre que se está por patear.
var barrera: Array[Jugador] = []
## Dados del árbitro (tarjetas). Las pruebas le fijan la semilla.
var rng := RandomNumberGenerator.new()

var _espera := 0.0
var _siguiente := Callable()
var _en_offside: Array[Jugador] = []
var _amarillas := {}
var _por_expulsar: Array[Jugador] = []
## La falta que se está dejando seguir por ventaja: {equipo, lugar, tiempo}.
var _ventaja := {}
## El próximo tiro libre es directo (falta) y no indirecto (offside).
var _proximo_directo := false
var _barrera_saltando: Array[Jugador] = []
var _tiempo_salto := 0.0


func _ready() -> void:
	# Después de los jugadores y la pelota: mira cómo quedó todo en este cuadro.
	process_physics_priority = 10


## Conecta las señales de la cancha, la pelota y los jugadores. Llamar una vez,
## con todo ya en el árbol.
func configurar(cancha: Cancha, nueva_pelota: Pelota, local: EquipoPartido, visitante: EquipoPartido) -> void:
	pelota = nueva_pelota
	equipos = [local, visitante]
	cancha.gol.connect(_al_entrar_en_arco)
	pelota.pateada.connect(_al_patear)
	pelota.poseedor_cambiado.connect(_al_cambiar_poseedor)
	for equipo in equipos:
		for jugador in equipo.jugadores:
			jugador.sentido = equipo.sentido
			jugador.falta_cometida.connect(_al_cometer_falta.bind(jugador))


## Arranca el partido con el saque del medio.
func empezar() -> void:
	periodo = 1
	segundos_jugados = 0.0
	preparar_saque(Saque.INICIAL, saca_primero, Vector3.ZERO)
	silbato.emit(Motivo.INICIO)


## Sigue después del entretiempo (lo llama el temporizador o el menú).
func continuar() -> void:
	if estado != Estado.ENTRETIEMPO:
		return
	periodo = 2
	segundos_jugados = 0.0
	for equipo in equipos:
		equipo.sentido = -equipo.sentido
		for jugador in equipo.jugadores:
			jugador.sentido = equipo.sentido
	preparar_saque(Saque.INICIAL, 1 - saca_primero, Vector3.ZERO)
	silbato.emit(Motivo.INICIO)


func duracion_tiempo() -> float:
	return segundos_por_tiempo if segundos_por_tiempo > 0.0 else configuracion.minutos_por_tiempo * 60.0


## Minuto de partido para mostrar (de 0 a 90).
func minuto() -> int:
	var del_tiempo := int(segundos_jugados / duracion_tiempo() * MINUTOS_REGLAMENTARIOS)
	return mini(del_tiempo, MINUTOS_REGLAMENTARIOS) + (MINUTOS_REGLAMENTARIOS if periodo == 2 else 0)


## Reloj como en la tele: minutos y segundos de partido ("37:12").
func texto_reloj() -> String:
	var parte := minf(segundos_jugados / duracion_tiempo(), 1.0)
	var segundos := int((parte + (periodo - 1)) * MINUTOS_REGLAMENTARIOS * 60.0)
	return "%02d:%02d" % [segundos / 60, segundos % 60]


func texto_tiempo() -> String:
	return "%dT" % periodo


## Después de una cinemática (por ejemplo, el festejo): si se estaba esperando para
## sacar, saca enseguida.
func retomar() -> void:
	en_pausa = false
	if estado == Estado.DETENIDO or estado == Estado.FESTEJO:
		_espera = minf(_espera, 0.2)


func goles_de(equipo: int) -> int:
	return equipos[equipo].goles


## True mientras corre la pelota (para la IA y los controles).
func en_juego() -> bool:
	return estado == Estado.EN_JUEGO


func _physics_process(delta: float) -> void:
	if en_pausa:
		return
	_bajar_barrera(delta)
	match estado:
		Estado.EN_JUEGO:
			_correr_reloj(delta)
			if estado == Estado.EN_JUEGO:
				_proteger_al_arquero()
				_revisar_ventaja(delta)
			if estado == Estado.EN_JUEGO:
				_revisar_si_salio()
		Estado.SAQUE:
			_correr_reloj(delta)
			if estado == Estado.SAQUE and ejecutor:
				ejecutor.proteger(0.2)
				if pelota.poseedor != ejecutor:
					# Nadie más puede tocarla antes del saque.
					pelota.colocar(lugar_saque)
					pelota.dar_a(ejecutor)
		Estado.DETENIDO, Estado.FESTEJO:
			if estado == Estado.DETENIDO:
				# Con la pelota parada el reloj sigue, como en la tele.
				_correr_reloj(delta)
				if estado != Estado.DETENIDO:
					return
			_espera -= delta
			if _espera <= 0.0 and _siguiente.is_valid():
				var siguiente := _siguiente
				_siguiente = Callable()
				siguiente.call()
		Estado.ENTRETIEMPO:
			if configuracion.segundos_entretiempo > 0.0:
				_espera -= delta
				if _espera <= 0.0:
					continuar()


# --- Saques -------------------------------------------------------------------


## Deja todo listo para un saque: elige quién saca, lo pone con la pelota en
## `lugar` y aleja a los rivales. El juego sigue cuando el que saca patea.
func preparar_saque(tipo: Saque, equipo: int, lugar: Vector3) -> void:
	_liberar_ejecutor()
	_ventaja = {}
	_echar_expulsados()
	tipo_saque = tipo
	equipo_saque = equipo
	lugar_saque = Vector3(lugar.x, Pelota.RADIO + 0.02, lugar.z)
	var propio := equipos[equipo]
	ejecutor = _elegir_ejecutor(tipo, propio)
	var direccion := _direccion_de_saque(tipo, propio)

	if tipo == Saque.INICIAL or tipo == Saque.PENAL:
		_ubicar_a_todos(tipo, equipo)
	else:
		_alejar_rivales()

	_poner(ejecutor, lugar_saque - direccion * (Jugador.RADIO + 0.3), direccion)
	ejecutor.inmovil = true
	var directo := tipo == Saque.TIRO_LIBRE and _proximo_directo
	_proximo_directo = false
	if directo and TiroLibre.jugadores_en_barrera(lugar_saque, propio.arco_rival()) > 0:
		ejecutor.tiro_libre_directo = true
		_armar_barrera(equipos[1 - equipo], propio.arco_rival())
	pelota.colocar(lugar_saque)
	pelota.dar_a(ejecutor)
	_en_offside.clear()
	_cambiar_estado(Estado.SAQUE)
	saque_preparado.emit(tipo, equipo, ejecutor)
	if ejecutor.tiro_libre_directo:
		aviso.emit("Tiro libre directo")
	elif tipo != Saque.INICIAL:
		aviso.emit(NOMBRES_SAQUE[tipo])


## Dónde puede pararse un jugador mientras se espera un saque (lo usa la IA).
func restringir_posicion(jugador: Jugador, punto: Vector3) -> Vector3:
	var p := Vector3(
		clampf(punto.x, -Cancha.LARGO / 2 + 0.5, Cancha.LARGO / 2 - 0.5),
		0,
		clampf(punto.z, -Cancha.ANCHO / 2 + 0.5, Cancha.ANCHO / 2 - 0.5)
	)
	if jugador == ejecutor:
		return p
	var es_rival := jugador.equipo != equipo_saque
	var equipo := equipos[jugador.equipo]
	match tipo_saque:
		Saque.INICIAL:
			if equipo.progreso(p) > 0.49:
				p = equipo.a_mundo(0.49, 0) + Vector3(0, 0, p.z)
			if es_rival:
				p = _fuera_del_radio(p, Vector3.ZERO, DISTANCIA_REGLAMENTARIA + 0.5)
		Saque.PENAL:
			var defensor := equipos[1 - equipo_saque]
			if jugador != defensor.arquero():
				p = _fuera_del_area(p, defensor)
				p = _fuera_del_radio(p, lugar_saque, DISTANCIA_REGLAMENTARIA + 0.5)
		Saque.ARCO:
			if es_rival:
				p = _fuera_del_area(p, equipos[equipo_saque])
		Saque.LATERAL:
			if es_rival:
				p = _fuera_del_radio(p, lugar_saque, DISTANCIA_LATERAL)
		_:
			if es_rival:
				p = _fuera_del_radio(p, lugar_saque, DISTANCIA_REGLAMENTARIA + 0.3)
	return p


func _elegir_ejecutor(tipo: Saque, equipo: EquipoPartido) -> Jugador:
	match tipo:
		Saque.ARCO:
			return equipo.arquero()
		Saque.INICIAL:
			for i in equipo.jugadores.size():
				if equipo.grupo(i) == "DEL":
					return equipo.jugadores[i]
		Saque.PENAL:
			var mejor: Jugador = null
			for jugador in equipo.jugadores:
				if jugador != equipo.arquero() and (mejor == null or jugador.tiro > mejor.tiro):
					mejor = jugador
			return mejor
	# El que esté más cerca (sin contar al arquero).
	var cercano: Jugador = null
	for jugador in equipo.jugadores:
		if jugador == equipo.arquero() and equipo.jugadores.size() > 1:
			continue
		var distancia := _en_el_piso(jugador.global_position, lugar_saque)
		if cercano == null or distancia < _en_el_piso(cercano.global_position, lugar_saque):
			cercano = jugador
	return cercano


## Hacia dónde mira el que saca.
func _direccion_de_saque(tipo: Saque, equipo: EquipoPartido) -> Vector3:
	var hacia_arco := equipo.arco_rival() - lugar_saque
	hacia_arco.y = 0
	match tipo:
		Saque.LATERAL:
			return Vector3(equipo.sentido * 0.5, 0, -signf(lugar_saque.z)).normalized()
		Saque.CORNER:
			var punto_penal := equipo.arco_rival() - Vector3(equipo.sentido * Cancha.DISTANCIA_PENAL, 0, 0)
			return (punto_penal - lugar_saque).normalized()
		Saque.INICIAL, Saque.ARCO:
			return Vector3(equipo.sentido, 0, 0)
	return hacia_arco.normalized()


## Saque del medio y penal: todos a su lugar, de una.
func _ubicar_a_todos(tipo: Saque, equipo_que_saca: int) -> void:
	for equipo in equipos:
		for i in equipo.jugadores.size():
			var jugador := equipo.jugadores[i]
			var punto := equipo.posicion_inicial(i)
			if tipo == Saque.PENAL:
				var defensor := equipos[1 - equipo_que_saca]
				if jugador == defensor.arquero():
					punto = defensor.arco_propio() + Vector3(defensor.sentido * 0.3, 0, 0)
				elif jugador == equipo.arquero():
					punto = equipo.arco_propio() + Vector3(equipo.sentido * 1.0, 0, 0)
				else:
					# Afuera del área, detrás de la pelota y repartidos a lo ancho.
					var adelante := Cancha.FONDO_AREA_GRANDE + 2.0 + float(i % 3) * 2.0
					var x := defensor.arco_propio().x + defensor.sentido * adelante
					var z := (float(i) - 5.0) * 3.0 + (0.8 if equipo.indice == 0 else -0.8)
					punto = Vector3(x, 0, z)
			punto = restringir_posicion(jugador, punto)
			var mirada := Vector3(equipo.sentido, 0, 0)
			_poner(jugador, punto, mirada)


func _alejar_rivales() -> void:
	for equipo in equipos:
		for jugador in equipo.jugadores:
			if jugador.equipo == equipo_saque:
				continue
			var punto := restringir_posicion(jugador, jugador.global_position)
			if _en_el_piso(punto, jugador.global_position) > 0.05:
				_poner(jugador, punto, jugador.direccion_mirada)


func _poner(jugador: Jugador, punto: Vector3, mirada: Vector3) -> void:
	jugador.detener()
	jugador.global_position = Vector3(punto.x, Jugador.ALTURA / 2, punto.z)
	jugador.direccion_mirada = mirada
	jugador.potencia = -1.0


func _liberar_ejecutor() -> void:
	if ejecutor:
		ejecutor.inmovil = false
		ejecutor.tiro_libre_directo = false
	_liberar_barrera()


## Pone la barrera: los jugadores de campo más cercanos a cada lugar, quietos y
## mirando la pelota.
func _armar_barrera(defensor: EquipoPartido, arco: Vector3) -> void:
	var cantidad := TiroLibre.jugadores_en_barrera(lugar_saque, arco)
	var libres: Array[Jugador] = []
	for jugador in defensor.jugadores:
		if jugador != defensor.arquero():
			libres.append(jugador)
	for punto in TiroLibre.puntos_de_barrera(lugar_saque, arco, mini(cantidad, libres.size())):
		var elegido: Jugador = libres[0]
		for jugador in libres:
			if _en_el_piso(jugador.global_position, punto) < _en_el_piso(elegido.global_position, punto):
				elegido = jugador
		libres.erase(elegido)
		var mirada := Vector3(lugar_saque.x - punto.x, 0, lugar_saque.z - punto.z).normalized()
		_poner(elegido, punto, mirada)
		elegido.inmovil = true
		elegido.en_barrera = true
		barrera.append(elegido)


## La barrera salta cuando patean (cada uno con su reflejo) y se suelta.
func _saltar_barrera() -> void:
	for jugador in barrera:
		if rng.randf() < 0.85:
			jugador.saltar()
	# Siguen "en barrera" un instante para que la pelota les pegue aunque estén bloqueados.
	for jugador in barrera:
		jugador.inmovil = false
	_barrera_saltando = barrera.duplicate()
	_tiempo_salto = 0.6
	barrera.clear()


func _bajar_barrera(delta: float) -> void:
	if _barrera_saltando.is_empty():
		return
	_tiempo_salto -= delta
	if _tiempo_salto <= 0.0:
		for jugador in _barrera_saltando:
			jugador.en_barrera = false
		_barrera_saltando.clear()


func _liberar_barrera() -> void:
	for jugador in barrera:
		jugador.inmovil = false
		jugador.en_barrera = false
	barrera.clear()


func _fuera_del_radio(p: Vector3, centro: Vector3, radio: float) -> Vector3:
	var desde := Vector3(p.x - centro.x, 0, p.z - centro.z)
	if desde.length() >= radio:
		return p
	if desde.length() < 0.1:
		desde = Vector3(0, 0, 1)
	var afuera := centro + desde.normalized() * radio
	return Vector3(afuera.x, 0, afuera.z)


func _fuera_del_area(p: Vector3, equipo: EquipoPartido) -> Vector3:
	if not equipo.en_area_propia(p):
		return p
	var borde := (Cancha.FONDO_AREA_GRANDE + 1.0) / Cancha.LARGO
	return equipo.a_mundo(borde, 0) + Vector3(0, 0, p.z)


# --- Reloj --------------------------------------------------------------------


func _correr_reloj(delta: float) -> void:
	segundos_jugados += delta
	if segundos_jugados < duracion_tiempo() or tipo_saque == Saque.PENAL and estado == Estado.SAQUE:
		return
	_liberar_ejecutor()
	_bloquear_a_todos(2.0)
	_siguiente = Callable()
	pelota.soltar()
	if periodo == 1:
		_cambiar_estado(Estado.ENTRETIEMPO)
		_espera = configuracion.segundos_entretiempo
		silbato.emit(Motivo.ENTRETIEMPO)
		aviso.emit("Entretiempo")
		entretiempo.emit()
	else:
		_cambiar_estado(Estado.FINAL)
		silbato.emit(Motivo.FINAL)
		aviso.emit("Final del partido")
		partido_terminado.emit(equipos[0].goles, equipos[1].goles)


# --- Lo que pasa en la cancha ---------------------------------------------------


func _revisar_si_salio() -> void:
	var p := pelota.global_position
	var muy_lejos := absf(p.x) > Cancha.LARGO / 2 + Cancha.FONDO_ARCO + 1.0 or p.y < -1.0
	if not Cancha.esta_afuera(p) and not muy_lejos:
		return
	var ultimo := pelota.ultimo_en_tocar
	var equipo_ultimo := ultimo.equipo if ultimo else -1
	if absf(p.z) > Cancha.ANCHO / 2 + Pelota.RADIO and absf(p.x) <= Cancha.LARGO / 2:
		var lugar := Vector3(p.x, 0, signf(p.z) * Cancha.ANCHO / 2)
		_detener(Motivo.AFUERA, Saque.LATERAL, 1 if equipo_ultimo == 0 else 0, lugar)
		return
	var lado := int(signf(p.x))
	var defensor := 0 if equipos[0].sentido == -lado else 1
	var costado := signf(p.z) if absf(p.z) > 0.01 else 1.0
	if equipo_ultimo == defensor:
		var esquina := Vector3(lado * Cancha.LARGO / 2, 0, costado * Cancha.ANCHO / 2)
		_detener(Motivo.AFUERA, Saque.CORNER, 1 - defensor, esquina)
	else:
		var x := lado * (Cancha.LARGO / 2 - Cancha.FONDO_AREA_CHICA)
		_detener(Motivo.AFUERA, Saque.ARCO, defensor, Vector3(x, 0, costado * 4.0))


## El arquero con la pelota en su área la tiene en las manos: no se la pueden robar.
func _proteger_al_arquero() -> void:
	var duenio := pelota.poseedor
	if duenio == null:
		return
	var equipo := equipos[duenio.equipo]
	if duenio == equipo.arquero() and equipo.en_area_propia(duenio.global_position):
		duenio.proteger(0.2)


func _al_entrar_en_arco(lado: int) -> void:
	if estado != Estado.EN_JUEGO:
		return
	var goleador := 0 if equipos[0].sentido == lado else 1
	var autor := pelota.ultimo_en_tocar
	var en_contra := autor != null and autor.equipo != goleador
	equipos[goleador].goles += 1
	goles.append({"equipo": goleador, "autor": autor, "minuto": minuto(), "en_contra": en_contra})
	_liberar_ejecutor()
	_ventaja = {}
	_cambiar_estado(Estado.FESTEJO)
	_bloquear_a_todos(DURACION_FESTEJO)
	_espera = DURACION_FESTEJO
	_siguiente = preparar_saque.bind(Saque.INICIAL, 1 - goleador, Vector3.ZERO)
	silbato.emit(Motivo.GOL)
	gol_convertido.emit(goleador, autor, en_contra)


func _al_cometer_falta(victima: Jugador, infractor: Jugador) -> void:
	if estado != Estado.EN_JUEGO:
		return
	var defensor := equipos[infractor.equipo]
	var lugar := victima.global_position
	var es_penal := defensor.en_area_propia(lugar)
	var ocasion := _era_ocasion_de_gol(victima, infractor)
	falta_sancionada.emit(infractor, victima, es_penal)
	_sancionar(infractor, ocasion)
	if es_penal:
		var punto := defensor.arco_propio() + Vector3(defensor.sentido * Cancha.DISTANCIA_PENAL, 0, 0)
		_detener(Motivo.FALTA, Saque.PENAL, victima.equipo, punto)
		return
	lugar.x = clampf(lugar.x, -Cancha.LARGO / 2 + 1.0, Cancha.LARGO / 2 - 1.0)
	lugar.z = clampf(lugar.z, -Cancha.ANCHO / 2 + 1.0, Cancha.ANCHO / 2 - 1.0)
	if not _ventaja.is_empty():
		# Segunda falta durante la ventaja: se cobra esta.
		_ventaja = {}
	elif _hay_ventaja(victima, lugar) and not ocasion:
		_ventaja = {"equipo": victima.equipo, "lugar": lugar, "tiempo": 0.0}
		aviso.emit("Ventaja")
		return
	_cobrar_tiro_libre(victima.equipo, lugar)


func _cobrar_tiro_libre(equipo: int, lugar: Vector3) -> void:
	_detener(Motivo.FALTA, Saque.TIRO_LIBRE, equipo, lugar)
	_proximo_directo = true
	aviso.emit("Falta")


## Se deja seguir si fue en campo rival y un compañero del que recibió la falta
## está cerca de la pelota suelta.
func _hay_ventaja(victima: Jugador, lugar: Vector3) -> bool:
	var propio := equipos[victima.equipo]
	if propio.progreso(lugar) < 0.5:
		return false
	for jugador in propio.jugadores:
		if jugador != victima and _en_el_piso(jugador.global_position, pelota.global_position) < 4.0:
			return true
	return false


## Mira si la ventaja sirvió: si el equipo sigue con la pelota, se juega; si la
## pierde o nadie la agarra, se cobra la falta donde fue.
func _revisar_ventaja(delta: float) -> void:
	if _ventaja.is_empty():
		return
	_ventaja["tiempo"] = float(_ventaja["tiempo"]) + delta
	var duenio := pelota.poseedor
	var equipo: int = _ventaja["equipo"]
	if duenio and duenio.equipo != equipo:
		var lugar: Vector3 = _ventaja["lugar"]
		_ventaja = {}
		_cobrar_tiro_libre(equipo, lugar)
	elif float(_ventaja["tiempo"]) >= DURACION_VENTAJA:
		var lugar: Vector3 = _ventaja["lugar"]
		var siguen := duenio != null and duenio.equipo == equipo
		_ventaja = {}
		if not siguen:
			_cobrar_tiro_libre(equipo, lugar)


## Ocasión manifiesta de gol: el que recibió la falta tenía la pelota, iba cerca del
## arco rival y no quedaba ningún defensor (además del que hizo la falta y el
## arquero) entre él y el arco.
func _era_ocasion_de_gol(victima: Jugador, infractor: Jugador) -> bool:
	if not infractor.ultima_falta.get("con_pelota", false):
		return false
	var atacante := equipos[victima.equipo]
	var defensor := equipos[infractor.equipo]
	var adelante := atacante.progreso(victima.global_position)
	if adelante < 0.68 or _en_el_piso(victima.global_position, atacante.arco_rival()) > 30.0:
		return false
	for jugador in defensor.jugadores:
		if jugador == infractor or jugador == defensor.arquero():
			continue
		if atacante.progreso(jugador.global_position) > adelante:
			return false
	return true


## Decide la tarjeta según la gravedad de la falta (ver `Jugador.ultima_falta`).
func _sancionar(infractor: Jugador, ocasion: bool) -> void:
	var gravedad := float(infractor.ultima_falta.get("gravedad", 0.3)) * RIGOR
	var roja := (ocasion and rng.randf() < 0.75) or (gravedad >= 0.85 and rng.randf() < (gravedad - 0.7) * 2.0)
	if roja:
		_mostrar_tarjeta(infractor, true)
	elif rng.randf() < gravedad - 0.15:
		_mostrar_tarjeta(infractor, false)


func _mostrar_tarjeta(jugador: Jugador, roja: bool) -> void:
	var equipo := equipos[jugador.equipo]
	var amarillas: int = _amarillas.get(jugador, 0)
	if not roja:
		amarillas += 1
		_amarillas[jugador] = amarillas
		roja = amarillas >= 2
	if roja and jugador == equipo.arquero():
		# No hay suplente para el arco: el arquero se queda con la amarilla.
		roja = false
		if amarillas >= 2:
			return
	tarjetas.append({"jugador": jugador, "equipo": jugador.equipo, "roja": roja, "minuto": minuto()})
	tarjeta_mostrada.emit(jugador, roja)
	if roja:
		_por_expulsar.append(jugador)
		var por := "doble amarilla" if amarillas >= 2 else "roja directa"
		aviso.emit("Expulsado: %s (%s)" % [jugador.nombre_jugador, por])
	else:
		aviso.emit("Amarilla para %s" % jugador.nombre_jugador)


func amarillas_de(jugador: Jugador) -> int:
	return _amarillas.get(jugador, 0)


## Saca de la cancha a los que vieron la roja (se hace con la pelota parada).
func _echar_expulsados() -> void:
	for jugador in _por_expulsar:
		if jugador.expulsado:
			continue
		equipos[jugador.equipo].expulsar(jugador)
		jugador.expulsar()
		jugador_expulsado.emit(jugador)
	_por_expulsar.clear()


func _al_patear(pateador: Jugador, _destinatario: Jugador) -> void:
	if estado == Estado.SAQUE and pateador == ejecutor:
		_saltar_barrera()
		_liberar_ejecutor()
		_cambiar_estado(Estado.EN_JUEGO)
		# En el lateral, el córner y el saque de arco no hay offside.
		var sin_offside := tipo_saque in [Saque.LATERAL, Saque.CORNER, Saque.ARCO]
		_marcar_offside(pateador, sin_offside)
	elif estado == Estado.EN_JUEGO and pateador:
		_marcar_offside(pateador, false)


func _al_cambiar_poseedor(nuevo: Jugador) -> void:
	if nuevo == null or estado != Estado.EN_JUEGO:
		return
	if nuevo in _en_offside:
		_en_offside.clear()
		offside_sancionado.emit(nuevo)
		aviso.emit("Offside")
		_ventaja = {}
		_detener(Motivo.OFFSIDE, Saque.TIRO_LIBRE, 1 - nuevo.equipo, nuevo.global_position)
	else:
		_en_offside.clear()


## Anota qué compañeros del que patea están en offside en este momento.
func _marcar_offside(pateador: Jugador, sin_offside: bool) -> void:
	_en_offside.clear()
	if not configuracion.offside or sin_offside:
		return
	var propio := equipos[pateador.equipo]
	var rival := equipos[1 - pateador.equipo]
	var pelota_adelante := propio.progreso(pelota.global_position)
	# El penúltimo rival (el último suele ser el arquero).
	var rivales: Array[float] = []
	for jugador in rival.jugadores:
		rivales.append(propio.progreso(jugador.global_position))
	rivales.sort()
	var penultimo := rivales[rivales.size() - 2] if rivales.size() >= 2 else 1.0
	for jugador in propio.jugadores:
		if jugador == pateador:
			continue
		var adelante := propio.progreso(jugador.global_position)
		if adelante > 0.5 and adelante > pelota_adelante + 0.002 and adelante > penultimo + 0.002:
			_en_offside.append(jugador)


func _detener(motivo: Motivo, tipo: Saque, equipo: int, lugar: Vector3) -> void:
	_liberar_ejecutor()
	_proximo_directo = false
	_cambiar_estado(Estado.DETENIDO)
	_bloquear_a_todos(PAUSA_TRAS_SILBATO + 0.1)
	if pelota.poseedor:
		pelota.soltar()
	_espera = PAUSA_TRAS_SILBATO
	_siguiente = preparar_saque.bind(tipo, equipo, lugar)
	silbato.emit(motivo)


func _bloquear_a_todos(segundos: float) -> void:
	for equipo in equipos:
		for jugador in equipo.jugadores:
			jugador.bloquear_control(segundos)


func _cambiar_estado(nuevo: Estado) -> void:
	if estado == nuevo:
		return
	estado = nuevo
	estado_cambiado.emit(nuevo)


static func _en_el_piso(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
