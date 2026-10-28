class_name Toma
extends RefCounted
## Una toma de cámara de una cinemática: dónde está la cámara, a qué mira y
## cuánto dura. La reproduce `CamaraCinematica`.
##
## Hay dos tipos:
## - **Recorrido:** la cámara va de `desde` a `hasta`. Si hay `seguir`, esas
##   posiciones son relativas a ese nodo (la cámara lo acompaña).
## - **Órbita:** la cámara gira alrededor de un punto (o de `seguir`).
##
## Se arman con `Toma.recorrido(...)` y `Toma.orbita(...)`, y se ajustan con los
## métodos encadenables (`mirando`, `siguiendo`, `con_fov`).

enum Tipo { RECORRIDO, ORBITA }

var tipo := Tipo.RECORRIDO
var duracion := 3.0
## Recorrido: posición de la cámara al empezar y al terminar.
var desde := Vector3.ZERO
var hasta := Vector3.ZERO
## Órbita: centro, radio y altura (al empezar y al terminar) y ángulos en grados.
var centro := Vector3.ZERO
var radio_desde := 10.0
var radio_hasta := 10.0
var altura_desde := 5.0
var altura_hasta := 5.0
var angulo_desde := 0.0
var angulo_hasta := 90.0
## Si no es null, la toma se mueve con este nodo (las posiciones son relativas).
var seguir: Node3D = null
## A qué mira la cámara. Si es null, mira a `punto_mirada` (o a `seguir`).
var mirar: Node3D = null
var punto_mirada := Vector3.ZERO
## Si `mirada_movil`, el punto al que se mira va de `punto_mirada` a este (paneo).
var punto_mirada_hasta := Vector3.ZERO
var mirada_movil := false
## Altura que se le suma al punto al que se mira (1,2 = el pecho de un jugador).
var altura_mirada := 0.0
var fov_desde := 40.0
var fov_hasta := 40.0
## Qué tan rápido acompaña a lo que sigue y a lo que mira (más alto = más pegado).
var suavizado := 4.0


static func recorrido(posicion_desde: Vector3, posicion_hasta: Vector3, segundos: float) -> Toma:
	var toma := Toma.new()
	toma.tipo = Tipo.RECORRIDO
	toma.desde = posicion_desde
	toma.hasta = posicion_hasta
	toma.duracion = segundos
	return toma


## Cámara quieta en un lugar.
static func fija(posicion: Vector3, segundos: float) -> Toma:
	return recorrido(posicion, posicion, segundos)


static func orbita(
	punto: Vector3, radios: Vector2, alturas: Vector2, angulos: Vector2, segundos: float
) -> Toma:
	var toma := Toma.new()
	toma.tipo = Tipo.ORBITA
	toma.centro = punto
	toma.punto_mirada = punto
	toma.radio_desde = radios.x
	toma.radio_hasta = radios.y
	toma.altura_desde = alturas.x
	toma.altura_hasta = alturas.y
	toma.angulo_desde = angulos.x
	toma.angulo_hasta = angulos.y
	toma.duracion = segundos
	return toma


## Mira a un nodo (a `altura` metros de su base) o a un punto fijo.
func mirando(objetivo: Variant, altura := 0.0) -> Toma:
	if objetivo is Node3D:
		mirar = objetivo
	elif objetivo is Vector3:
		punto_mirada = objetivo
	altura_mirada = altura
	return self


## Paneo: la mirada va de un punto a otro durante la toma.
func mirando_recorrido(punto_desde: Vector3, punto_hasta: Vector3) -> Toma:
	punto_mirada = punto_desde
	punto_mirada_hasta = punto_hasta
	mirada_movil = true
	mirar = null
	return self


## Punto al que se mira a una fracción `t` de la toma (sin contar `mirar`).
func punto_mirada_en(t: float) -> Vector3:
	if mirada_movil:
		return punto_mirada.lerp(punto_mirada_hasta, _suave(t))
	return punto_mirada


func siguiendo(nodo: Node3D) -> Toma:
	seguir = nodo
	return self


func con_fov(fov_inicial: float, fov_final := -1.0) -> Toma:
	fov_desde = fov_inicial
	fov_hasta = fov_inicial if fov_final < 0.0 else fov_final
	return self


## Posición de la cámara a una fracción `t` (0 a 1) de la toma, con `ancla` como
## la posición actual (suavizada) de lo que se sigue.
func posicion_en(t: float, ancla: Vector3) -> Vector3:
	var s := _suave(t)
	if tipo == Tipo.ORBITA:
		var angulo := deg_to_rad(lerpf(angulo_desde, angulo_hasta, s))
		var radio := lerpf(radio_desde, radio_hasta, s)
		var base := ancla if seguir else centro
		return base + Vector3(cos(angulo) * radio, lerpf(altura_desde, altura_hasta, s), sin(angulo) * radio)
	var posicion := desde.lerp(hasta, s)
	return ancla + posicion if seguir else posicion


func fov_en(t: float) -> float:
	return lerpf(fov_desde, fov_hasta, _suave(t))


## Arranca y frena suave, como una grúa o un travelling.
static func _suave(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
