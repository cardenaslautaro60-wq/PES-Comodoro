extends Node
## Juega un partido entero la máquina contra la máquina, lo más rápido posible, y
## muestra lo que pasó. No es una prueba automática: sirve para ajustar la IA y ver
## que nada se trabe.
##
## Uso (los argumentos son opcionales):
##   godot --headless --fixed-fps 60 --path . res://tests/simular_partido.tscn -- \
##     [minutos por tiempo] [dificultad 0-2] [offside|no] [club local] [club visitante]

var partido: PartidoCompleto
var estadisticas := {}
var _tiempo := 0.0
var _estado_desde := 0.0
var _mas_tiempo_parado := 0.0
var _pase_de: Jugador = null


func _ready() -> void:
	var argumentos := OS.get_cmdline_user_args()
	var configuracion := ConfiguracionPartido.new()
	configuracion.equipo_humano = -1
	configuracion.minutos_por_tiempo = int(argumentos[0]) if argumentos.size() > 0 else 3
	configuracion.dificultad = (int(argumentos[1]) if argumentos.size() > 1 else 1) as ConfiguracionPartido.Dificultad
	configuracion.offside = argumentos.size() > 2 and argumentos[2] == "offside"
	configuracion.segundos_entretiempo = 1.0
	if argumentos.size() > 4:
		configuracion.club_local = argumentos[3]
		configuracion.club_visitante = argumentos[4]
	partido = (load("res://escenas/partido/partido_completo.tscn") as PackedScene).instantiate()
	partido.configuracion = configuracion
	partido.con_cinematicas = false
	add_child(partido)

	var arbitro := partido.arbitro
	arbitro.saque_preparado.connect(func(t: int, _e: int, _j: Jugador) -> void: _sumar(Arbitro.NOMBRES_SAQUE[t]))
	arbitro.falta_sancionada.connect(func(_i: Jugador, _v: Jugador, _p: bool) -> void: _sumar("faltas"))
	arbitro.offside_sancionado.connect(func(_j: Jugador) -> void: _sumar("offside"))
	arbitro.estado_cambiado.connect(func(_e: int) -> void: _estado_desde = _tiempo)
	arbitro.partido_terminado.connect(_al_terminar)
	for ia in partido.ias:
		ia.atajada.connect(func(_j: Jugador, agarrada: bool) -> void: _sumar("atajadas" if agarrada else "desvios"))
	partido.pelota.pateada.connect(func(p: Jugador, d: Jugador) -> void: _pase_de = p if d else null)
	partido.pelota.poseedor_cambiado.connect(_al_cambiar_poseedor)
	for jugador in partido.jugadores:
		jugador.pateo.connect(_al_patear.bind(jugador))


func _physics_process(delta: float) -> void:
	_tiempo += delta
	var arbitro := partido.arbitro
	if arbitro.estado in [Arbitro.Estado.SAQUE, Arbitro.Estado.DETENIDO]:
		_mas_tiempo_parado = maxf(_mas_tiempo_parado, _tiempo - _estado_desde)
	if partido.pelota.poseedor:
		_sumar("posesion_%d (s)" % partido.pelota.poseedor.equipo, delta)


func _al_cambiar_poseedor(nuevo: Jugador) -> void:
	if nuevo == null or _pase_de == null:
		return
	_sumar("pases_%d_%s" % [_pase_de.equipo, "ok" if nuevo.equipo == _pase_de.equipo else "cortados"])
	_pase_de = null


func _al_patear(tipo: Jugador.Patada, _fuerza: float, jugador: Jugador) -> void:
	_sumar("%s_%d" % [Jugador.Patada.keys()[tipo].to_lower(), jugador.equipo])


func _sumar(clave: String, cuanto := 1.0) -> void:
	estadisticas[clave] = estadisticas.get(clave, 0.0) + cuanto


func _al_terminar(goles_local: int, goles_visitante: int) -> void:
	print("Resultado: %s %d - %d %s" % [partido.nombre_local, goles_local, goles_visitante, partido.nombre_visitante])
	for gol: Dictionary in partido.arbitro.goles:
		var autor: Jugador = gol["autor"]
		var nombre := autor.nombre_jugador if autor else "?"
		print("  %d' %s%s" % [gol["minuto"], nombre, " (en contra)" if gol["en_contra"] else ""])
	var claves := estadisticas.keys()
	claves.sort()
	for clave: String in claves:
		print("  %s: %.0f" % [clave, estadisticas[clave]])
	print("  Lo más que estuvo parado: %.1f s" % _mas_tiempo_parado)
	get_tree().quit(0)
