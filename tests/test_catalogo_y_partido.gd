extends "res://tests/prueba.gd"
## Catálogo de clubes y datos del partido elegido, con los clubes de prueba de tests/datos.

const DATOS_DE_PRUEBA := "res://tests/datos"


func antes_de_cada() -> void:
	Catalogo.recargar(DATOS_DE_PRUEBA)
	ConfigPartido.local_id = ""


func despues_de_cada() -> void:
	Catalogo.recargar()
	ConfigPartido.local_id = ""


func test_lee_los_clubes_ordenados_por_nombre() -> void:
	var nombres: Array[String] = []
	for club in Catalogo.clubes():
		nombres.append(Catalogo.nombre_corto(club))
	afirmar(", ".join(nombres) == "Azul FC, Celeste, Rojo SC", "orden inesperado: %s" % [nombres])
	afirmar(Catalogo.club("rojo_sc").get("abreviatura") == "ROJ", "no encontró el club por id")
	afirmar(Catalogo.club("no_existe").is_empty(), "un club que no existe debería venir vacío")


func test_lee_estadios_y_planteles() -> void:
	afirmar(Catalogo.estadios().size() == 2, "deberían ser 2 estadios")
	afirmar(Catalogo.estadio("cancha_azul").get("nombre") == "Cancha Azul", "no encontró el estadio")
	afirmar(Catalogo.plantel("azul_fc").get("jugadores", []).size() == 14, "el plantel debería tener 14 jugadores")
	afirmar(Catalogo.plantel("celeste").is_empty(), "un club sin plantel debería dar vacío")


func test_sin_carpeta_de_datos_no_hay_clubes() -> void:
	Catalogo.recargar("res://tests/no_existe")
	afirmar(Catalogo.clubes().is_empty(), "no debería haber clubes")


func test_colores_de_los_datos() -> void:
	var camiseta := Catalogo.camiseta(Catalogo.club("rojo_sc"), "titular")
	afirmar(Catalogo.color(camiseta, "color_base").is_equal_approx(Color("#C8102E")), "color mal leído")
	afirmar(Catalogo.color(camiseta, "hombreras", Color.BLACK) == Color.BLACK, "un null debería usar el color por defecto")


func test_preparar_elige_estadio_del_local_y_titulares() -> void:
	ConfigPartido.preparar("azul_fc", "rojo_sc")
	afirmar(ConfigPartido.estadio_id == "cancha_azul", "debería jugarse en la cancha del local")
	afirmar(ConfigPartido.titulares["local"].size() == 11, "deberían ser 11 titulares")
	afirmar(ConfigPartido.suplentes["local"].size() == 3, "deberían ser 3 suplentes")
	afirmar(ConfigPartido.formacion["local"] == "4-3-3", "debería usar la formación del plantel")
	afirmar(int(ConfigPartido.jugador_destacado("local").get("dorsal")) == 9, "el destacado debería ser el 9")


func test_si_el_estadio_no_existe_usa_otro() -> void:
	ConfigPartido.preparar("celeste", "rojo_sc")
	afirmar(not Catalogo.estadio(ConfigPartido.estadio_id).is_empty(), "debería elegir un estadio que exista")


func test_camisetas_parecidas_pasan_a_suplente() -> void:
	ConfigPartido.preparar("azul_fc", "celeste")
	afirmar(ConfigPartido.camiseta["visitante"] == "suplente", "azul contra azul: el visitante debería ir de suplente")
	ConfigPartido.preparar("azul_fc", "rojo_sc")
	afirmar(ConfigPartido.camiseta["visitante"] == "titular", "azul contra rojo no se confunden")


func test_cambios_respetan_el_limite() -> void:
	ConfigPartido.preparar("azul_fc", "rojo_sc")
	var titular: String = ConfigPartido.titulares["local"][5]
	var suplente: String = ConfigPartido.suplentes["local"][0]
	afirmar(ConfigPartido.hacer_cambio("local", titular, suplente), "el cambio debería poder hacerse")
	afirmar(ConfigPartido.titulares["local"].has(suplente), "el suplente debería estar en cancha")
	afirmar(not ConfigPartido.suplentes["local"].has(suplente), "el que entró no debería seguir en el banco")
	afirmar(not ConfigPartido.hacer_cambio("local", titular, suplente), "no se puede sacar a uno que ya salió")
	ConfigPartido.cambios_hechos["local"] = ConfigPartido.MAX_CAMBIOS
	var otro: String = ConfigPartido.suplentes["local"][0]
	var en_cancha: String = ConfigPartido.titulares["local"][0]
	afirmar(not ConfigPartido.hacer_cambio("local", en_cancha, otro), "no debería pasarse de 5 cambios")


func test_formacion_desconocida_se_ignora() -> void:
	ConfigPartido.preparar("azul_fc", "rojo_sc")
	ConfigPartido.cambiar_formacion("local", "1-1-8")
	afirmar(ConfigPartido.formacion["local"] == "4-3-3", "aceptó una formación que no existe")
	ConfigPartido.cambiar_formacion("local", "3-5-2")
	afirmar(ConfigPartido.formacion["local"] == "3-5-2", "no cambió la formación")


func test_pizarra_pone_once_jugadores() -> void:
	var Pizarra := load("res://scripts/ui/pizarra_formacion.gd")
	for formacion: String in ConfigPartido.FORMACIONES:
		var puntos: Array = Pizarra.posiciones(formacion)
		afirmar(puntos.size() == 11, "%s tiene %d jugadores" % [formacion, puntos.size()])


func test_reloj_cuenta_como_en_la_tele() -> void:
	var Reloj := load("res://scripts/partido/reloj_partido.gd")
	var reloj: Node = Reloj.new()
	reloj.set("segundos_reales_por_tiempo", 100.0)
	reloj.set("corriendo", false)
	add_child(reloj)
	var tiempos: Array[int] = []
	reloj.connect("termino_tiempo", func(n: int) -> void: tiempos.append(n))
	reloj.call("avanzar", 50.0)
	afirmar(reloj.call("texto") == "22:30", "a mitad del primer tiempo debería decir 22:30, dice %s" % reloj.call("texto"))
	reloj.call("avanzar", 60.0)
	afirmar(tiempos.size() == 1 and reloj.get("tiempo_actual") == 2, "no pasó al segundo tiempo")
	afirmar(reloj.call("texto") == "45:00", "el segundo tiempo arranca en 45:00")
	reloj.call("avanzar", 200.0)
	afirmar(reloj.get("terminado"), "el partido debería haber terminado")
	afirmar(reloj.call("texto") == "90:00", "al final debería decir 90:00")
	reloj.queue_free()
