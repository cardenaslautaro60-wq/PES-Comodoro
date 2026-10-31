# Jugabilidad (área B)

Cómo están armados la pelota, el jugador, la cámara y los controles, y qué pueden usar las otras áreas. Todo está en `scripts/partido/` y se prueba en la escena `escenas/partido/entrenamiento.tscn`.

## Las piezas

| Clase | Archivo | Qué hace |
|---|---|---|
| `Cancha` | `cancha.gd` | Pasto, líneas y arcos con medidas reglamentarias. Avisa `gol(lado)`. Tiene `esta_afuera(posicion)` y las medidas como constantes (`Cancha.LARGO`, `Cancha.ANCHO_ARCO`, etc.). |
| `Pelota` | `pelota.gd` | Física (roce del aire, efecto, roce del pasto, pique), control pegado al pie, quién la toma cuando está suelta, robos y rebotes en los cuerpos. |
| `Jugador` | `jugador.gd` | Movimiento, sprint y estamina, pases, tiro con barra de potencia, presión y barrida. No lee controles: hace lo que dice su `entrada`. |
| `EntradaJugador` | `entrada_jugador.gd` | Lo que el jugador quiere hacer: dirección y botones mantenidos. |
| `ControlHumano` | `control_humano.gd` | Pasa el teclado, el joystick o la pantalla táctil a la `entrada` del jugador que manejás, cambia de jugador y dibuja el aro amarillo. |
| `CamaraTransmision` | `camara_transmision.gd` | Cámara de TV lateral que se adelanta a la jugada y se aleja con la pelota rápida. |
| `CapasFisica` | `capas_fisica.gd` | Capas de colisión: mundo, jugadores y pelota. La pelota no choca con los jugadores; todo contacto lo decide el código. |
| `TiroLibre` | `tiro_libre.gd` | Cómo sale un tiro libre según potencia, comba y picada, cuántos van a la barrera y dónde, y el plan de la máquina para pasarla por arriba. |

## Cómo se siente (los números para ajustar)

- **Ejes:** el local ataca hacia x positivo. La cámara mira desde z positivo, así que "arriba" en la pantalla es z negativo.
- **Velocidad:** de 5,6 a 7 m/s corriendo y de 7,4 a 9,4 m/s en sprint, según el atributo `velocidad`. Con pelota, un 7 a 10 % menos.
- **Inercia (estilo PES 2006):** el arranque es explosivo pero los últimos metros por segundo cuestan (`_aceleracion`: unos 0,3 s para llegar a la mitad y más de 1 s para llegar a fondo).
- **Giros:** con pelota están limitados (8 rad/s, 4,5 en sprint), así hay que girar el cuerpo para cambiar de dirección. Sin pelota gira casi al instante al trote, pero en sprint abre el giro (7 rad/s). Un giro de más de 35° corriendo rápido frena: en una vuelta de 180° a fondo el jugador planta el pie y baja al 30 % antes de salir (`FRENO_GIRO_CERRADO`).
- **Conducción:** la pelota va pegada al pie al trote; en sprint la empuja hasta 30 cm más lejos (`TOQUE_LARGO_SPRINT`), así corre más pero el rival tiene más chances de robarla.
- **Primer toque:** hasta 15 m/s cualquiera la para. Más fuerte, el pase "pesa": según el control del que recibe (pase y velocidad), la pelota se le puede ir larga un par de metros.
- **Comba del tiro:** el tiro colocado (poca potencia) dobla hacia el palo al que apunta, saliendo más cerca del arquero; el fuerte va casi derecho. La dirección se corrige sola para que la curva termine en el mismo lugar.
- **Estamina:** el sprint la gasta (aguanta de 7 a 18 segundos según el atributo) y se recupera caminando o parado. Con menos del 30 % el jugador es más lento y erra más.
- **Barra de potencia:** se llena en 1 segundo. Pase corto: siempre busca al compañero mejor ubicado en la dirección del joystick y calcula la fuerza para que llegue. Pase al hueco: lo deja adelante del compañero, hacia el arco. Pase largo: por arriba, al compañero o a una distancia según la potencia. Tiro: poca potencia sale rasante, mucha sale arriba, y pasado el 90 % se puede ir por encima del travesaño.
- **Puntería:** el joystick arriba o abajo al tirar apunta a ese palo; sin tocar, al palo más lejano. El error depende de `pase` o `tiro`, la potencia, el sprint y el cansancio.
- **De primera:** si soltás el botón antes de que te llegue la pelota, el jugador patea apenas la toca.
- **Defensa:** con la pelota del rival, el botón de pase presiona (el jugador va solo a la pelota y tiene más chances de robarla) y el de tiro barre. La barrida que llega primero a la pelota la saca limpia; si llega primero al cuerpo es falta. Presionar desde atrás también puede terminar en falta.
- **Gravedad de la falta** (para las tarjetas, ver [IA-Y-REGLAS.md](IA-Y-REGLAS.md)): una barrida de atrás es mucho peor, igual que llegar tarde (el rival ya no tenía la pelota) o tirarse de lejos.

## Tiros libres

Cuando te cobran una falta a menos de 35 m del arco rival, el tiro libre es directo y se patea a mano, como en los PES de la época:

1. **Apuntar:** con el joystick hacia un costado la flecha blanca del pasto gira de a poco.
2. **Potencia:** mantené el botón de tiro. Más potencia sale más fuerte y más alta (la flecha se pone naranja mientras cargás).
3. **Efecto:** mientras cargás, el joystick elige el efecto. Hacia un costado, la pelota dobla para ese lado. Hacia adelante (hacia el arco), sale con efecto de arriba y baja de golpe después de la barrera. Hacia atrás flota.
4. Soltá el botón para patear. Con pase o pase largo la tocás para un compañero, como siempre.

La barrera (de 2 a 5 jugadores según la distancia y el ángulo) tapa el palo más cercano a 9,15 m y salta cuando patean. Entre 20 y 25 m, de frente, suele andar potencia media (40 a 60 %) con efecto hacia adelante y un poco de comba.
- **Cambio de jugador:** al pasar, pasás a manejar al que recibe. Defendiendo, el botón de cambiar va al compañero más cerca de la pelota.

Los valores están como constantes o `@export` al principio de cada archivo.

## Para el área C (IA, reglas y partido)

- La IA maneja un `Jugador` igual que una persona: llenando `jugador.entrada` (dirección, sprint, botones) o llamando directo a `patear(tipo, potencia, direccion)`, `barrer(direccion)`, `ir_hacia(punto)` y `detener()`.
- Tiros libres: `jugador.patear_tiro_libre(direccion, fuerza, comba, picado)`. `TiroLibre.planear()` busca solo los valores para pasar la barrera.
- `jugador.cometer_falta(victima, gravedad)` tira al rival y avisa al árbitro (`jugador.ultima_falta` guarda cómo fue).
- `jugador.aplicar_datos(dict)` carga nombre, dorsal y atributos de un jugador de `datos/planteles/`.
- Señales útiles: `Pelota.pateada(pateador, destinatario)`, `Pelota.poseedor_cambiado(nuevo)`, `Jugador.falta_cometida(victima)`, `Jugador.pelota_tomada`, `Cancha.gol(lado)`.
- `pelota.ultimo_en_tocar` sirve para laterales, córners y saques de arco. `Cancha.esta_afuera(posicion)` dice si salió.
- El arquero todavía no ataja: es un jugador quieto que toma o desvía la pelota con el cuerpo.
- El cambio automático de jugador al defender queda para C (`ControlHumano.cambiar_a(jugador)`).

## Para las áreas E (arte) y F (cinemáticas)

- Si un `Jugador` o la `Pelota` tienen un hijo llamado `Modelo`, no se crea el modelo provisorio. Ahí va el modelo 3D.
- Para animar: `Jugador.velocity`, `estado` (normal, barrida, caído), y las señales `pateo(tipo, potencia)`, `barrida_empezada` y `derribado`.
- La cámara de transmisión se puede apagar (`current = false`) para usar una de cinemática, y `cortar()` la vuelve a encuadrar sin suavizado.
- Las cinemáticas ya están hechas: ver [CINEMATICAS.md](CINEMATICAS.md).

## Para el área G (menús e interfaz)

- `Controles.escala_botones` cambia el tamaño de los botones táctiles y `Controles.vibracion_activada` prende o apaga la vibración.
- El HUD provisorio (`scripts/ui/hud_jugador.gd`) lee `jugador.potencia` (-1 si no se carga nada), `estamina_actual` y `nombre_jugador`.
