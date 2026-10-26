class_name EntradaJugador
extends RefCounted
## Lo que un jugador "quiere hacer" en este momento.
##
## La llena `ControlHumano` con el joystick, el teclado o la pantalla táctil, o la
## IA (área C) cuando el jugador lo maneja la máquina. `Jugador` solo lee esto, así
## el mismo jugador sirve para los dos casos.
##
## Los botones se leen "mantenidos": true mientras están apretados. El jugador
## detecta solo cuándo se aprietan y cuándo se sueltan (para la barra de potencia).

## Hacia dónde moverse, en el plano de la cancha (y = 0), de largo 0 a 1.
var direccion := Vector3.ZERO
var sprint := false
## Con la pelota: pase. Defendiendo: presión.
var pase := false
## Con la pelota: tiro. Defendiendo: barrida.
var tiro := false
## Pase largo o centro.
var pase_largo := false
## Pase al hueco.
var pase_hueco := false


## Suelta todo: sin movimiento y sin botones apretados.
func limpiar() -> void:
	direccion = Vector3.ZERO
	sprint = false
	pase = false
	tiro = false
	pase_largo = false
	pase_hueco = false
