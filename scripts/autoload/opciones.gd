extends Node
## Opciones del jugador: volúmenes, vibración, tamaño de los botones táctiles,
## duración del partido y contador de FPS.
##
## Se guardan en `user://opciones.cfg` (en el celular queda en la memoria de la app).
## Cualquier parte del juego puede escuchar `cambiaron` para aplicar los cambios.

signal cambiaron

const RUTA_POR_DEFECTO := "user://opciones.cfg"
const BUSES := ["Master", "Musica", "Efectos", "Ambiente"]
const VOLUMENES_POR_DEFECTO := {"Master": 0.9, "Musica": 0.6, "Efectos": 0.9, "Ambiente": 0.8}
const ESCALA_BOTONES_MIN := 0.8
const ESCALA_BOTONES_MAX := 1.4
const MINUTOS_POSIBLES := [3, 5, 7, 10]

## Volumen de cada canal de audio, de 0 a 1.
var volumen := VOLUMENES_POR_DEFECTO.duplicate()
var vibracion := true
## Multiplica el tamaño de los botones táctiles del partido.
var escala_botones := 1.0
## Minutos reales que dura cada tiempo del partido.
var minutos_por_tiempo := 5
var mostrar_fps := false
var ruta := RUTA_POR_DEFECTO


func _ready() -> void:
	cargar()


func cargar() -> void:
	restablecer(false)
	var archivo := ConfigFile.new()
	if archivo.load(ruta) != OK:
		return
	for bus: String in BUSES:
		volumen[bus] = clampf(float(archivo.get_value("volumen", bus, volumen[bus])), 0.0, 1.0)
	vibracion = bool(archivo.get_value("tactil", "vibracion", vibracion))
	escala_botones = clampf(
		float(archivo.get_value("tactil", "escala_botones", escala_botones)), ESCALA_BOTONES_MIN, ESCALA_BOTONES_MAX
	)
	var minutos := int(archivo.get_value("partido", "minutos_por_tiempo", minutos_por_tiempo))
	minutos_por_tiempo = minutos if minutos in MINUTOS_POSIBLES else 5
	mostrar_fps = bool(archivo.get_value("pantalla", "mostrar_fps", mostrar_fps))
	cambiaron.emit()


func guardar() -> void:
	var archivo := ConfigFile.new()
	for bus: String in BUSES:
		archivo.set_value("volumen", bus, volumen[bus])
	archivo.set_value("tactil", "vibracion", vibracion)
	archivo.set_value("tactil", "escala_botones", escala_botones)
	archivo.set_value("partido", "minutos_por_tiempo", minutos_por_tiempo)
	archivo.set_value("pantalla", "mostrar_fps", mostrar_fps)
	if archivo.save(ruta) != OK:
		push_warning("No se pudieron guardar las opciones en " + ruta)


## Vuelve a los valores de fábrica. No guarda: para eso está `guardar()`.
func restablecer(avisar := true) -> void:
	volumen = VOLUMENES_POR_DEFECTO.duplicate()
	vibracion = true
	escala_botones = 1.0
	minutos_por_tiempo = 5
	mostrar_fps = false
	if avisar:
		cambiaron.emit()


func cambiar_volumen(bus: String, valor: float) -> void:
	if not volumen.has(bus):
		return
	volumen[bus] = clampf(valor, 0.0, 1.0)
	cambiaron.emit()


func cambiar_vibracion(activa: bool) -> void:
	vibracion = activa
	cambiaron.emit()


func cambiar_escala_botones(valor: float) -> void:
	escala_botones = clampf(valor, ESCALA_BOTONES_MIN, ESCALA_BOTONES_MAX)
	cambiaron.emit()


func cambiar_minutos(minutos: int) -> void:
	if minutos in MINUTOS_POSIBLES:
		minutos_por_tiempo = minutos
		cambiaron.emit()


func cambiar_mostrar_fps(mostrar: bool) -> void:
	mostrar_fps = mostrar
	cambiaron.emit()


## Hace vibrar el celular si el jugador lo tiene activado. En la compu no hace nada.
func vibrar(milisegundos: int) -> void:
	if vibracion:
		Input.vibrate_handheld(milisegundos)
