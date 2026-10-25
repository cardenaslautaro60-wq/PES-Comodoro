extends Node
## Base de las pruebas automáticas.
##
## Cada método que empieza con "test_" es una prueba. Si existen,
## `antes_de_cada()` y `despues_de_cada()` corren alrededor de cada una.

var errores: Array[String] = []


func afirmar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		errores.append(mensaje)


func esperar_fisica(cuadros: int) -> void:
	for i in cuadros:
		await get_tree().physics_frame
