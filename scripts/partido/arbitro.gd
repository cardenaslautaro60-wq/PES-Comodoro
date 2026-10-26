class_name Arbitro
extends Node
## El árbitro: lleva el reloj, el marcador y hace cumplir las reglas.
##
## - Reloj: dos tiempos de `minutos_por_tiempo` minutos reales cada uno, que en
##   pantalla se ven como 45 minutos. Entretiempo con cambio de lado y final.
## - Saque del medio al empezar cada tiempo y después de cada gol.
## - Lateral, córner y saque de arco según quién la tocó último.
## - Faltas (las barridas que llegan al cuerpo): tiro libre, o penal si fue dentro
##   del área del que la cometió.
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

var _espera := 0.0
var _siguiente := Callable()
var _en_offside: Array[Jugador] = []


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
	match estado:
		Estado.EN_JUEGO:
			_correr_reloj(delta)
			if estado == Estado.EN_JUEGO:
				_proteger_al_arquero()
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
	pelota.colocar(lugar_saque)
	pelota.dar_a(ejecutor)
	_en_offside.clear()
	_cambiar_estado(Estado.SAQUE)
	saque_preparado.emit(tipo, equipo, ejecutor)
	if tipo != Saque.INICIAL:
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
		if jugador == equipo.arquero():
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
	falta_sancionada.emit(infractor, victima, es_penal)
	if es_penal:
		var punto := defensor.arco_propio() + Vector3(defensor.sentido * Cancha.DISTANCIA_PENAL, 0, 0)
		_detener(Motivo.FALTA, Saque.PENAL, victima.equipo, punto)
	else:
		lugar.x = clampf(lugar.x, -Cancha.LARGO / 2 + 1.0, Cancha.LARGO / 2 - 1.0)
		lugar.z = clampf(lugar.z, -Cancha.ANCHO / 2 + 1.0, Cancha.ANCHO / 2 - 1.0)
		_detener(Motivo.FALTA, Saque.TIRO_LIBRE, victima.equipo, lugar)
		aviso.emit("Falta")


func _al_patear(pateador: Jugador, _destinatario: Jugador) -> void:
	if estado == Estado.SAQUE and pateador == ejecutor:
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
