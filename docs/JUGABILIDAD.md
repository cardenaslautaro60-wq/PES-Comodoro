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

## Cómo se siente (los números para ajustar)

- **Ejes:** el local ataca hacia x positivo. La cámara mira desde z positivo, así que "arriba" en la pantalla es z negativo.
- **Velocidad:** de 5,6 a 7 m/s corriendo y de 7,4 a 9,4 m/s en sprint, según el atributo `velocidad`. Con pelota, un 7 a 10 % menos.
- **Giro con pelota:** limitado (8 rad/s, 4,5 en sprint), así hay que girar el cuerpo para cambiar de dirección. Sin pelota gira casi al instante.
- **Estamina:** el sprint la gasta (aguanta de 7 a 18 segundos según el atributo) y se recupera caminando o parado. Con menos del 30 % el jugador es más lento y erra más.
- **Barra de potencia:** se llena en 1 segundo. Pase corto: siempre busca al compañero mejor ubicado en la dirección del joystick y calcula la fuerza para que llegue. Pase al hueco: lo deja adelante del compañero, hacia el arco. Pase largo: por arriba, al compañero o a una distancia según la potencia. Tiro: poca potencia sale rasante, mucha sale arriba, y pasado el 90 % se puede ir por encima del travesaño.
- **Puntería:** el joystick arriba o abajo al tirar apunta a ese palo; sin tocar, al palo más lejano. El error depende de `pase` o `tiro`, la potencia, el sprint y el cansancio.
- **De primera:** si soltás el botón antes de que te llegue la pelota, el jugador patea apenas la toca.
- **Defensa:** con la pelota del rival, el botón de pase presiona (el jugador va solo a la pelota y tiene más chances de robarla) y el de tiro barre. La barrida que llega primero a la pelota la saca limpia; si llega primero al cuerpo es falta.
- **Cambio de jugador:** al pasar, pasás a manejar al que recibe. Defendiendo, el botón de cambiar va al compañero más cerca de la pelota.

Los valores están como constantes o `@export` al principio de cada archivo.

## Para el área C (IA, reglas y partido)

- La IA maneja un `Jugador` igual que una persona: llenando `jugador.entrada` (dirección, sprint, botones) o llamando directo a `patear(tipo, potencia, direccion)`, `barrer(direccion)`, `ir_hacia(punto)` y `detener()`.
- `jugador.aplicar_datos(dict)` carga nombre, dorsal y atributos de un jugador de `datos/planteles/`.
- Señales útiles: `Pelota.pateada(pateador, destinatario)`, `Pelota.poseedor_cambiado(nuevo)`, `Jugador.falta_cometida(victima)`, `Jugador.pelota_tomada`, `Cancha.gol(lado)`.
- `pelota.ultimo_en_tocar` sirve para laterales, córners y saques de arco. `Cancha.esta_afuera(posicion)` dice si salió.
- El arquero todavía no ataja: es un jugador quieto que toma o desvía la pelota con el cuerpo.
- El cambio automático de jugador al defender queda para C (`ControlHumano.cambiar_a(jugador)`).

## Para las áreas E (arte) y F (cinemáticas)

- Si un `Jugador` o la `Pelota` tienen un hijo llamado `Modelo`, no se crea el modelo provisorio. Ahí va el modelo 3D.
- Para animar: `Jugador.velocity`, `estado` (normal, barrida, caído), y las señales `pateo(tipo, potencia)`, `barrida_empezada` y `derribado`.
- La cámara de transmisión se puede apagar (`current = false`) para usar una de cinemática, y `cortar()` la vuelve a encuadrar sin suavizado.

## Para el área G (menús e interfaz)

- `Controles.escala_botones` cambia el tamaño de los botones táctiles y `Controles.vibracion_activada` prende o apaga la vibración.
- El HUD provisorio (`scripts/ui/hud_jugador.gd`) lee `jugador.potencia` (-1 si no se carga nada), `estamina_actual` y `nombre_jugador`.
