extends Node
## Lo que se eligió para el partido que se va a jugar: clubes, camisetas, estadio,
## duración, dificultad, formación y cambios. También guarda el resultado.
##
## Los menús lo llenan y el partido lo lee. Los lados se llaman "local" y "visitante";
## el jugador maneja al local.

const LADOS := ["local", "visitante"]
const FORMACIONES := ["4-4-2", "4-3-3", "3-5-2"]
const DIFICULTADES := ["Fácil", "Normal", "Difícil"]
const MAX_CAMBIOS := 5
## Por debajo de esta distancia entre colores, dos camisetas se confunden en la cancha.
const DISTANCIA_MINIMA_COLORES := 0.3

var local_id := ""
var visitante_id := ""
var camiseta := {"local": "titular", "visitante": "titular"}
var estadio_id := ""
var minutos_por_tiempo := 5
## 0 fácil, 1 normal, 2 difícil.
var dificultad := 1
var formacion := {"local": "4-4-2", "visitante": "4-4-2"}
## Ids de los jugadores en cancha y en el banco de cada lado.
var titulares := {"local": [], "visitante": []}
var suplentes := {"local": [], "visitante": []}
var cambios_hechos := {"local": 0, "visitante": 0}
var goles := {"local": 0, "visitante": 0}
var terminado := false


## Deja todo listo para un partido entre dos clubes del catálogo.
func preparar(id_local: String, id_visitante: String) -> void:
	local_id = id_local
	visitante_id = id_visitante
	elegir_camisetas()
	var estadio_local := str(Catalogo.club(id_local).get("estadio_id", ""))
	estadio_id = estadio_local if not Catalogo.estadio(estadio_local).is_empty() else _primer_estadio()
	minutos_por_tiempo = Opciones.minutos_por_tiempo
	for lado: String in LADOS:
		_armar_equipo(lado)
	reiniciar_resultado()


## Si todavía no se eligió nada (por ejemplo, al abrir el partido directo desde el
## editor), toma los dos primeros clubes del catálogo.
func preparar_si_falta() -> void:
	if not local_id.is_empty():
		return
	var lista := Catalogo.clubes()
	if lista.size() >= 2:
		preparar(str(lista[0]["id"]), str(lista[1]["id"]))
	elif lista.size() == 1:
		preparar(str(lista[0]["id"]), str(lista[0]["id"]))
	else:
		reiniciar_resultado()


func reiniciar_resultado() -> void:
	goles = {"local": 0, "visitante": 0}
	cambios_hechos = {"local": 0, "visitante": 0}
	terminado = false


## El local usa la titular. El visitante también, salvo que se confunda con la del
## local: ahí pasa a la suplente, como manda el reglamento.
func elegir_camisetas() -> void:
	camiseta["local"] = "titular"
	camiseta["visitante"] = "titular"
	if colores_se_confunden(color_camiseta("local"), color_camiseta("visitante")):
		camiseta["visitante"] = "suplente"


func cambiar_camiseta(lado: String) -> void:
	camiseta[lado] = "suplente" if camiseta[lado] == "titular" else "titular"


func club_de(lado: String) -> Dictionary:
	return Catalogo.club(local_id if lado == "local" else visitante_id)


func datos_camiseta(lado: String) -> Dictionary:
	return Catalogo.camiseta(club_de(lado), camiseta[lado])


func color_camiseta(lado: String) -> Color:
	var por_defecto := Color(0.8, 0.12, 0.15) if lado == "local" else Color(0.15, 0.3, 0.8)
	return Catalogo.color(datos_camiseta(lado), "color_base", por_defecto)


func nombre_de(lado: String) -> String:
	var datos := club_de(lado)
	return Catalogo.nombre_corto(datos) if not datos.is_empty() else lado.capitalize()


func abreviatura_de(lado: String) -> String:
	var datos := club_de(lado)
	return Catalogo.abreviatura(datos) if not datos.is_empty() else lado.left(3).to_upper()


## Datos de un jugador del plantel de ese lado, buscado por id.
func jugador(lado: String, id: String) -> Dictionary:
	var club_id := local_id if lado == "local" else visitante_id
	for datos: Dictionary in Catalogo.plantel(club_id).get("jugadores", []):
		if str(datos.get("id")) == id:
			return datos
	return {}


## El jugador de ese lado que juega más adelante (para mostrar su nombre si la
## escena de juego no dice a quién manejás). Prefiere al 9.
func jugador_destacado(lado: String) -> Dictionary:
	var elegido := {}
	for id: String in titulares[lado]:
		var datos := jugador(lado, id)
		if int(datos.get("dorsal", 0)) == 9:
			return datos
		if elegido.is_empty() or str(datos.get("posicion")) == "DC":
			elegido = datos
	return elegido


## Saca a `sale` y mete a `entra`. Devuelve false si no se puede.
func hacer_cambio(lado: String, sale: String, entra: String) -> bool:
	var en_cancha: Array = titulares[lado]
	var banco: Array = suplentes[lado]
	if cambios_hechos[lado] >= MAX_CAMBIOS or not en_cancha.has(sale) or not banco.has(entra):
		return false
	en_cancha[en_cancha.find(sale)] = entra
	banco.erase(entra)
	cambios_hechos[lado] += 1
	return true


func cambios_restantes(lado: String) -> int:
	return MAX_CAMBIOS - int(cambios_hechos[lado])


func cambiar_formacion(lado: String, nueva: String) -> void:
	if nueva in FORMACIONES:
		formacion[lado] = nueva


## Distancia entre dos colores, de 0 (iguales) a 1 (blanco contra negro).
static func distancia_colores(a: Color, b: Color) -> float:
	# Pesos aproximados de cómo ve el ojo cada canal.
	var diferencia := Vector3((a.r - b.r) * 0.55, (a.g - b.g) * 0.75, (a.b - b.b) * 0.35)
	return diferencia.length() / Vector3(0.55, 0.75, 0.35).length()


static func colores_se_confunden(a: Color, b: Color) -> bool:
	return distancia_colores(a, b) < DISTANCIA_MINIMA_COLORES


func _armar_equipo(lado: String) -> void:
	var club_id := local_id if lado == "local" else visitante_id
	var plantel := Catalogo.plantel(club_id)
	var en_cancha: Array = []
	var banco: Array = []
	for datos: Dictionary in plantel.get("jugadores", []):
		if datos.get("titular", false) and en_cancha.size() < 11:
			en_cancha.append(str(datos.get("id")))
		else:
			banco.append(str(datos.get("id")))
	titulares[lado] = en_cancha
	suplentes[lado] = banco
	var de_plantel := str(plantel.get("formacion", "4-4-2"))
	formacion[lado] = de_plantel if de_plantel in FORMACIONES else "4-4-2"


func _primer_estadio() -> String:
	var lista := Catalogo.estadios()
	return str(lista[0]["id"]) if not lista.is_empty() else ""
