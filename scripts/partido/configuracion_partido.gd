class_name ConfiguracionPartido
extends Resource
## Cómo se juega un partido: equipos, formaciones, duración, dificultad y reglas.
##
## Si no se pasa ninguna, `PartidoCompleto` la arma con lo elegido en los menús
## (`ConfigPartido`, área G) usando `desde_menu()`.

enum Dificultad { FACIL, NORMAL, DIFICIL }

## Nombres para mostrar de cada dificultad.
const NOMBRES_DIFICULTAD := ["Fácil", "Normal", "Difícil"]

## Id del club de `datos/clubes/` (sin ".json"). Si no existe, se usa un equipo genérico.
@export var club_local := "cai"
@export var club_visitante := "huracan"
## Formación de `datos/formaciones/`. Vacío = la que trae el plantel del club.
@export var formacion_local := ""
@export var formacion_visitante := ""
## Ids del plantel que salen a la cancha. Vacío = los titulares del plantel.
@export var titulares_local: Array[String] = []
@export var titulares_visitante: Array[String] = []
## Color de la camiseta elegida. Transparente = la titular del club.
@export var color_local := Color.TRANSPARENT
@export var color_visitante := Color.TRANSPARENT
## Minutos reales que dura cada tiempo (de 3 a 10).
@export_range(1, 10) var minutos_por_tiempo := 5
@export var dificultad := Dificultad.NORMAL
## Qué equipo maneja la persona: 0 = local, 1 = visitante, -1 = ninguno (la máquina
## contra la máquina, para demostraciones y pruebas).
@export_range(-1, 1) var equipo_humano := 0
## El offside queda opcional en la primera versión.
@export var offside := false
## Pasa solo al compañero mejor ubicado cuando defendés.
@export var cambio_automatico := true
## Segundos del entretiempo antes de seguir (0 = espera a que alguien llame a `continuar()`).
@export var segundos_entretiempo := 4.0


## Lo elegido en los menús (`ConfigPartido`): clubes, camiseta, formación, titulares,
## duración y dificultad. La persona maneja al local.
static func desde_menu() -> ConfiguracionPartido:
	var configuracion := ConfiguracionPartido.new()
	configuracion.club_local = ConfigPartido.local_id
	configuracion.club_visitante = ConfigPartido.visitante_id
	configuracion.formacion_local = str(ConfigPartido.formacion["local"])
	configuracion.formacion_visitante = str(ConfigPartido.formacion["visitante"])
	configuracion.titulares_local.assign(ConfigPartido.titulares["local"])
	configuracion.titulares_visitante.assign(ConfigPartido.titulares["visitante"])
	configuracion.color_local = ConfigPartido.color_camiseta("local")
	configuracion.color_visitante = ConfigPartido.color_camiseta("visitante")
	configuracion.minutos_por_tiempo = clampi(ConfigPartido.minutos_por_tiempo, 1, 10)
	configuracion.dificultad = clampi(ConfigPartido.dificultad, 0, 2) as Dificultad
	configuracion.equipo_humano = 0
	return configuracion
