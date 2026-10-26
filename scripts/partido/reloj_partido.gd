extends Node
## Reloj del partido. Muestra el tiempo como en la tele (de 0' a 90'), pero cada
## tiempo dura los minutos reales que se eligieron en el menú.
##
## Se frena solo cuando el juego está en pausa. El área C puede reemplazarlo por
## un reloj con tiempo agregado y entretiempo de verdad.

signal termino_tiempo(numero: int)
signal termino_partido

const MINUTOS_POR_TIEMPO_EN_JUEGO := 45
const TIEMPOS := 2

var segundos_reales_por_tiempo := 300.0
var tiempo_actual := 1
var corriendo := true
var terminado := false

var _transcurrido := 0.0


func _process(delta: float) -> void:
	if corriendo:
		avanzar(delta)


func avanzar(segundos: float) -> void:
	if terminado:
		return
	_transcurrido += segundos
	if _transcurrido < segundos_reales_por_tiempo:
		return
	_transcurrido = segundos_reales_por_tiempo
	if tiempo_actual >= TIEMPOS:
		terminado = true
		corriendo = false
		termino_tiempo.emit(tiempo_actual)
		termino_partido.emit()
	else:
		termino_tiempo.emit(tiempo_actual)
		tiempo_actual += 1
		_transcurrido = 0.0


## Minutos de juego desde el comienzo, como los cuenta el relator.
func minuto_de_juego() -> float:
	var parte := _transcurrido / maxf(segundos_reales_por_tiempo, 0.001)
	return (tiempo_actual - 1 + parte) * MINUTOS_POR_TIEMPO_EN_JUEGO


func texto() -> String:
	var total_segundos := int(minuto_de_juego() * 60.0)
	return "%02d:%02d" % [total_segundos / 60, total_segundos % 60]


func texto_tiempo() -> String:
	return "%dT" % tiempo_actual
