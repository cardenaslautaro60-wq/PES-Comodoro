extends Node
## Sonido del juego: efectos, ambiente de hinchada, bombos y cánticos.
##
## Arma los canales de audio (Musica, Efectos y Ambiente, todos dentro de Master)
## y les aplica el volumen de `Opciones`. Los sonidos se piden por nombre:
## `Sonido.reproducir("silbato_corto")`. Si falta un archivo, avisa y sigue sin sonido.
##
## Los cánticos se graban aparte: cualquier .wav u .ogg que se ponga en
## `audio/canticos/` suena de vez en cuando durante el partido.

const EFECTOS := {
	"patada": "res://audio/efectos/patada.wav",
	"pase": "res://audio/efectos/pase.wav",
	"poste": "res://audio/efectos/poste.wav",
	"silbato_corto": "res://audio/efectos/silbato_corto.wav",
	"silbato_largo": "res://audio/efectos/silbato_largo.wav",
	"silbato_final": "res://audio/efectos/silbato_final.wav",
	"grito_gol": "res://audio/efectos/grito_gol.wav",
	"ui_tocar": "res://audio/efectos/ui_tocar.wav",
	"ui_volver": "res://audio/efectos/ui_volver.wav",
}
const LOOPS := {
	"hinchada": "res://audio/ambiente/hinchada.wav",
	"bombos": "res://audio/ambiente/bombos.wav",
}
const CARPETA_CANTICOS := "res://audio/canticos"
const CANTIDAD_DE_VOCES := 8
## Volumen de la hinchada en decibeles: tranquila en la mitad de la cancha y a pleno cerca del arco.
const HINCHADA_TRANQUILA_DB := -9.0
const HINCHADA_A_PLENO_DB := 0.0

var _efectos := {}
var _loops := {}
var _canticos: Array[AudioStream] = []
var _voces: Array[AudioStreamPlayer] = []
var _siguiente_voz := 0
var _hinchada: AudioStreamPlayer
var _bombos: AudioStreamPlayer
var _cantico: AudioStreamPlayer
var _intensidad := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crear_buses()
	_cargar_sonidos()
	for i in CANTIDAD_DE_VOCES:
		_voces.append(_crear_reproductor("Voz%d" % i, "Efectos"))
	_hinchada = _crear_reproductor("Hinchada", "Ambiente")
	_bombos = _crear_reproductor("Bombos", "Musica")
	_cantico = _crear_reproductor("Cantico", "Ambiente")
	Opciones.cambiaron.connect(aplicar_volumenes)
	aplicar_volumenes()


## Toca un efecto. `tono` cambia la altura (1 es normal) y `volumen_db` lo sube o baja.
func reproducir(nombre: String, volumen_db := 0.0, tono := 1.0) -> void:
	var sonido: AudioStream = _efectos.get(nombre)
	if sonido == null:
		return
	var voz := _voces[_siguiente_voz]
	_siguiente_voz = (_siguiente_voz + 1) % _voces.size()
	voz.stream = sonido
	voz.volume_db = volumen_db
	voz.pitch_scale = tono
	voz.play()


## Sonido corto para los botones de los menús.
func tocar_boton() -> void:
	reproducir("ui_tocar", 0.0, randf_range(0.97, 1.03))


func tocar_volver() -> void:
	reproducir("ui_volver")


## Bombos de fondo en los menús, por el canal de música.
func musica_de_menu() -> void:
	_hinchada.stop()
	_cantico.stop()
	_poner_loop(_bombos, "bombos", "Musica", -4.0)


## Hinchada y bombos durante el partido, por el canal de ambiente.
func ambiente_de_partido() -> void:
	_poner_loop(_hinchada, "hinchada", "Ambiente", HINCHADA_TRANQUILA_DB)
	_poner_loop(_bombos, "bombos", "Ambiente", -8.0)
	intensidad(0.0)


func detener_todo() -> void:
	for reproductor: AudioStreamPlayer in [_hinchada, _bombos, _cantico]:
		reproductor.stop()


## Qué tan metida está la hinchada, de 0 (pelota en el medio) a 1 (pelota en el área).
func intensidad(valor: float) -> void:
	_intensidad = clampf(valor, 0.0, 1.0)
	_hinchada.volume_db = lerpf(HINCHADA_TRANQUILA_DB, HINCHADA_A_PLENO_DB, _intensidad)


## Hace sonar un cántico al azar de `audio/canticos/`, si hay alguno y no está sonando otro.
## Devuelve true si arrancó uno.
func cantico_al_azar() -> bool:
	if _canticos.is_empty() or _cantico.playing:
		return false
	_cantico.stream = _canticos.pick_random()
	_cantico.play()
	return true


func hay_canticos() -> bool:
	return not _canticos.is_empty()


func tiene_efecto(nombre: String) -> bool:
	return _efectos.has(nombre)


func tiene_loop(nombre: String) -> bool:
	return _loops.has(nombre)


func aplicar_volumenes() -> void:
	for bus: String in Opciones.BUSES:
		var indice := AudioServer.get_bus_index(bus)
		if indice == -1:
			continue
		var valor: float = Opciones.volumen[bus]
		AudioServer.set_bus_mute(indice, valor <= 0.001)
		AudioServer.set_bus_volume_db(indice, linear_to_db(maxf(valor, 0.001)))


func _crear_buses() -> void:
	for bus: String in Opciones.BUSES:
		if AudioServer.get_bus_index(bus) != -1:
			continue
		AudioServer.add_bus()
		var indice := AudioServer.bus_count - 1
		AudioServer.set_bus_name(indice, bus)
		AudioServer.set_bus_send(indice, "Master")


func _cargar_sonidos() -> void:
	for nombre: String in EFECTOS:
		var sonido := _cargar(EFECTOS[nombre])
		if sonido:
			_efectos[nombre] = sonido
	for nombre: String in LOOPS:
		var sonido := _cargar(LOOPS[nombre])
		if sonido is AudioStreamWAV:
			_hacer_loop(sonido as AudioStreamWAV)
		if sonido:
			_loops[nombre] = sonido
	_canticos.clear()
	if not DirAccess.dir_exists_absolute(CARPETA_CANTICOS):
		return
	var vistos := {}
	for archivo in DirAccess.get_files_at(CARPETA_CANTICOS):
		# En el editor están "x.wav" y "x.wav.import"; en lo exportado, sólo "x.wav.import".
		var nombre := archivo.trim_suffix(".import")
		if vistos.has(nombre) or nombre.get_extension() not in ["wav", "ogg", "mp3"]:
			continue
		vistos[nombre] = true
		var sonido := _cargar(CARPETA_CANTICOS.path_join(nombre))
		if sonido:
			_canticos.append(sonido)


func _cargar(ruta: String) -> AudioStream:
	if not ResourceLoader.exists(ruta):
		push_warning("Falta el sonido " + ruta)
		return null
	return load(ruta) as AudioStream


func _hacer_loop(sonido: AudioStreamWAV) -> void:
	# Godot importa los .wav sin repetición; acá se pide que el archivo entero se repita.
	var muestras := int(round(sonido.get_length() * sonido.mix_rate))
	sonido.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sonido.loop_begin = 0
	sonido.loop_end = muestras


func _poner_loop(reproductor: AudioStreamPlayer, nombre: String, bus: String, volumen_db: float) -> void:
	var sonido: AudioStream = _loops.get(nombre)
	if sonido == null:
		return
	reproductor.bus = bus
	reproductor.volume_db = volumen_db
	if reproductor.stream != sonido or not reproductor.playing:
		reproductor.stream = sonido
		reproductor.play()


func _crear_reproductor(nombre: String, bus: String) -> AudioStreamPlayer:
	var reproductor := AudioStreamPlayer.new()
	reproductor.name = nombre
	reproductor.bus = bus
	add_child(reproductor)
	return reproductor
