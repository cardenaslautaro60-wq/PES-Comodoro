# Cinemáticas y repeticiones (área F)

Las cinemáticas del partido: presentación con la salida de los equipos, festejo de gol con repetición, repetición manual, entretiempo y final. Todo está en `scripts/cinematicas/` y se ve en el entrenamiento (`escenas/partido/entrenamiento.tscn`).

**Todas se saltean** con un toque en la pantalla, un clic, cualquier tecla o cualquier botón del joystick. El primer tercio de segundo no cuenta, así un toque que venía del partido no saltea sin querer.

## Qué pasa en el entrenamiento

1. **Al abrir:** presentación (unos 16 segundos).
   - Pasada de cámara alta por la cancha, con el cerro y el mar de fondo, y el nombre del estadio.
   - Los equipos salen del túnel caminando, con el cartel "LOCAL vs VISITANTE".
   - Paneo por la fila mientras saludan.
   - Grúa que sube y muestra toda la cancha, fundido y arranca el juego.
2. **En cada gol:** festejo y repetición (unos 20 segundos).
   - "¡GOOOL!" con el nombre y el dorsal del autor (o "en contra").
   - El que hizo el gol corre hacia el córner con sprint, los compañeros lo siguen y los rivales se lamentan. La cámara lo toma de frente y después gira alrededor del festejo.
   - Repetición automática desde 3 ángulos: TV de cerca, detrás del arco en cámara lenta y desde atrás del que pateó.
3. **Repetición manual:** "R" en el teclado, "Select" en el joystick o el botón **REPE** arriba a la derecha en el celular. Muestra los últimos 8 segundos y el juego sigue exactamente donde estaba.
4. **Al llegar a 3 goles:** cinemática del final. El que ganó se junta a festejar y el que perdió se lamenta (con empate, aplauden todos). Después el marcador vuelve a cero.

El **entretiempo** está hecho pero el entrenamiento no tiene reloj, así que no se ve todavía. Lo llama el partido completo (área C).

## Intro del juego

`escenas/cinematicas/intro.tscn` (unos 8 segundos): la cámara baja desde el cerro hasta el pasto, cruza una pelota y aparece el título del juego (sale de `application/config/name`). Se saltea con un toque.

El menú del área G la muestra una sola vez al abrir el juego (`Navegacion.INTRO`). Al terminar llama a `Navegacion.ir_a(Navegacion.MENU_PRINCIPAL)`. Si ese autoload todavía no existe, va al menú principal o, si tampoco está, al entrenamiento. Si existe `Sonido.musica_de_menu()`, la usa.

## Las piezas

| Clase | Archivo | Qué hace |
|---|---|---|
| `DirectorCinematicas` | `director_cinematicas.gd` | Arma y pasa cada cinemática. Es lo único que usa el partido. |
| `Toma` | `toma.gd` | Una toma de cámara: recorrido, cámara fija u órbita, a qué mira, el lente y la duración. |
| `CamaraCinematica` | `camara_cinematica.gd` | La cámara que reproduce las tomas, con seguimiento suave. |
| `GrabadorRepeticion` | `grabador_repeticion.gd` | Graba los últimos 10 segundos (30 cuadros por segundo) y los vuelve a mostrar, también en cámara lenta. |
| `PantallaCinematica` | `pantalla_cinematica.gd` | Bandas negras, títulos, cartel de "REPETICIÓN", fundidos y el aviso para saltear. |
| `Gestos` | `gestos.gd` | Festejo, lamento, saludo y aplauso de los jugadores. |
| `FondoComodoroProvisorio` | `fondo_comodoro_provisorio.gd` | Un cerro de cima chata y el mar, en low poly, hasta que esté el panorama del estadio. |

## Cómo se usa desde el partido (área C)

El director necesita un nodo `partido` con estas propiedades (las tiene `entrenamiento.gd`):

- **Obligatorias:** `pelota`, `jugadores` (todos, de los dos equipos) y `camara` (la de transmisión).
- **Opcionales:** `control` (`ControlHumano`), `nombre_local`, `nombre_visitante`, `nombre_estadio`, `goles_local` y `goles_visitante`, y un hijo `Interfaz` (CanvasLayer) que se esconde durante las cinemáticas.

```gdscript
cinematicas = DirectorCinematicas.new()
cinematicas.partido = self
add_child(cinematicas)

await cinematicas.presentar_partido()  # Al empezar
await cinematicas.festejar_gol(lado)   # Con el lado de Cancha.gol
await cinematicas.entretiempo()
await cinematicas.final_del_partido()
```

- Cada función vuelve cuando terminó o se salteó. **El director no reinicia la jugada:** después del festejo, el partido decide (saque del medio, etc.). La presentación deja a los jugadores formados en la mitad de la cancha, así que hay que ubicarlos para el saque.
- Mientras dura una cinemática, el director apaga el `ControlHumano`, suelta todos los botones y maneja a los jugadores llenando su `entrada`. **La IA tiene que quedarse quieta:** escuchá `cinematica_empezada(nombre)` y `cinematica_terminada(nombre, salteada)`, o mirá `cinematicas.activa`.
- Si cambian los jugadores (por ejemplo, un cambio), llamá `cinematicas.registrar_actores()` para que la repetición los grabe.
- `con_repeticion_de_gol = false` saca la repetición automática y `con_boton_repeticion = false` desactiva la "R".

## Para el área E (arte)

- **Animaciones:** si el `Modelo` de un jugador tiene un `AnimationPlayer` con animaciones llamadas `festejo`, `lamento`, `saludo` o `aplauso`, `Gestos` usa esas. Si no, hace un movimiento simple sobre el modelo provisorio (saltitos, cabeza gacha, balanceo).
- **Fondo:** `FondoComodoroProvisorio` se saca cuando esté el panorama del estadio. Para la pasada de cámara de la presentación conviene un Chenque un poco más detallado, visto desde el lado de la tribuna principal (z positivo).
- **Cámara cercana:** el festejo y el paneo de la fila toman a los jugadores de cerca (de 4 a 6 metros), así que ahí se ve el modelo cercano (LOD0).

## Para el área G (menús, interfaz y sonido)

- El botón **REPE** del entrenamiento es provisorio. En el partido conviene ponerlo en el menú de pausa, llamando a `cinematicas.repeticion_manual()`.
- Para el sonido: `cinematica_empezada("gol")` es el momento del grito de gol y de la hinchada, y `cinematica_empezada("final")` el del silbato final.

## Rendimiento en el celular

- No suma modelos ni texturas: usa los mismos jugadores, pelota y cancha del partido, y una cámara más.
- La grabación guarda una posición por jugador 30 veces por segundo (con 23 cuerpos son unas 7.000 posiciones en 10 segundos, menos de 1 MB).
- Durante la repetición, la pelota y los jugadores no corren su física, así que cuesta menos que jugar.

## Pendiente

- **Logo** en la intro, cuando haya uno.
- **Hinchada y sonido** en las cinemáticas (áreas E y G).
- Las tomas están ajustadas con los modelos provisorios. Con los modelos y el estadio de verdad hay que retocar distancias y alturas (todo está en `director_cinematicas.gd`).
