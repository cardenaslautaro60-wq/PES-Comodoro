# Menús, interfaz y sonido (área G)

Cómo están armadas las pantallas, el HUD del partido y el sonido, y qué tienen que respetar las otras áreas para engancharse.

## Recorrido

```
Menú principal ─▶ Elegí los equipos ─▶ Preparar el partido ─▶ Partido ─▶ Resultado
      │                                                       │ (pausa)      │
      ├─▶ Opciones                                            ├─ Cambios     ├─ Revancha
      └─▶ Créditos                                            ├─ Formación   ├─ Otros equipos
                                                              ├─ Opciones    └─ Menú principal
                                                              └─ Salir
```

- **Elegí los equipos:** flechas o deslizar el dedo sobre la tarjeta para cambiar de club. Muestra el escudo (parodia mientras no haya permiso), la camiseta, el apodo y el nivel. Si las camisetas se confunden, el visitante pasa solo a la suplente; igual se puede cambiar a mano.
- **Preparar el partido:** estadio (arranca en el del local), duración (3, 5, 7 o 10 minutos por tiempo), dificultad y formación, con una pizarra que muestra la formación.
- **Partido:** marcador con abreviaturas y colores, reloj de 0' a 90', nombre y estamina del jugador, barra de potencia, carteles de gol, entretiempo y final, y botón de pausa arriba a la derecha.
- **Pausa:** seguir, cambios (hasta 5: se toca al que sale y después al que entra), formación, opciones y salir (pide un segundo toque).
- **Atrás de Android y Escape:** vuelven a la pantalla anterior. En el partido abren o cierran la pausa. En el menú principal, en Android, cierran el juego. Si entra una llamada en el celular, el partido queda en pausa.

Todo está pensado primero para el celular: botones de 84 px de alto como mínimo (en la pantalla de referencia de 1280x720), selectores "◀ valor ▶" en vez de listas o deslizadores chicos, y márgenes que respetan el notch.

## Archivos

| Archivo | Qué hace |
|---|---|
| `scripts/autoload/opciones.gd` | Opciones guardadas en `user://opciones.cfg`: volúmenes, vibración, tamaño de botones, duración y FPS. |
| `scripts/autoload/sonido.gd` | Canales de audio y todos los sonidos por nombre. |
| `scripts/autoload/catalogo.gd` | Lee `datos/clubes`, `datos/estadios` y `datos/planteles` (formato del área D). |
| `scripts/autoload/config_partido.gd` | Lo elegido para el partido: clubes, camisetas, estadio, duración, dificultad, formación, cambios y goles. |
| `scripts/autoload/navegacion.gd` | Cambio de pantalla con fundido y botón "atrás". |
| `scripts/menus/*.gd` | Una pantalla por archivo. Todas heredan de `pantalla_menu.gd`. |
| `scripts/partido/partido.gd` | Junta el juego con el HUD, el reloj, la pausa y el sonido. |
| `scripts/partido/reloj_partido.gd` | Reloj de 2 tiempos. |
| `scripts/partido/pausa.gd` | Menú de pausa. |
| `scripts/ui/hud_partido.gd` | Marcador, reloj, jugador, potencia y carteles. |
| `scripts/ui/escudo.gd`, `vista_camiseta.gd` | Dibujan el escudo y la camiseta a partir de los datos del club. |
| `scripts/ui/tema.gd` | Colores y tamaños de la interfaz. |

Las pantallas se arman por código (como el entrenamiento), así las escenas `.tscn` son mínimas y no hay conflictos al mezclar ramas.

## Para el área B (jugabilidad) y la C (partido completo)

`partido.gd` carga la escena de `ESCENA_JUEGO` (hoy `escenas/partido/entrenamiento.tscn`, del área B). Para cambiarla por el partido 11 contra 11 alcanza con cambiar esa constante. Lo que espera de esa escena:

- La señal `gol(equipo: String)`, con `"local"` o `"visitante"`. El partido cuenta los goles en `ConfigPartido.goles`.
- Una variable `pelota` (`RigidBody3D`): el partido escucha sus cambios de velocidad para hacer sonar patadas, pases y palos, y sube la hinchada cuando la pelota se acerca a un arco.
- Opcional: `jugadores` (lista de `Jugador`). A cada uno le pone el color de la camiseta elegida según su `equipo`, y el nombre del titular del plantel que tiene su mismo `dorsal`.
- Opcional: `reiniciar_jugada()`, que se llama en el entretiempo.
- Opcional: `Interfaz/Marcador` se esconde (el que vale es el del HUD) y `Interfaz/ContadorFps` se muestra según las opciones. Si hay `Interfaz/HudJugador` (el nombre y las barras arriba del jugador), el HUD no repite esos datos; si no, los lee de `control.jugador` (`nombre_jugador`, `dorsal`, `estamina_actual` y `potencia`).

El tamaño de los botones táctiles y la vibración se eligen en Opciones y se pasan a `Controles.escala_botones` y `Controles.vibracion_activada`, que son los que leen los controles táctiles.

Lo elegido en los menús está en `ConfigPartido`: `formacion["local"]`, `titulares["local"]` (ids del plantel), `dificultad` (0 a 2), `minutos_por_tiempo`, `estadio_id` y `color_camiseta(lado)`. La señal `formacion_cambiada` de la pausa avisa si el jugador cambia la formación en medio del partido.

La acción `pausa` (Escape, P o Start del joystick) está registrada en `Controles`.

## Sonido

Canales: **Master** y adentro **Musica**, **Efectos** y **Ambiente**. Cada uno tiene su volumen en Opciones.

| Nombre | Cuándo suena |
|---|---|
| `patada`, `pase` | La pelota sale disparada (según la fuerza) |
| `poste` | La pelota rebota en un palo |
| `silbato_corto` | Gol y cambios |
| `silbato_largo` | Comienzo y entretiempo |
| `silbato_final` | Final del partido |
| `grito_gol` | La tribuna festeja |
| `ui_tocar`, `ui_volver` | Botones de los menús |
| `hinchada` (loop) | Murmullo de tribuna durante el partido |
| `bombos` (loop) | Bombos y platillos: música en los menús, ambiente en el partido |

Todos se generan con `python3 herramientas/generar_sonidos.py` (síntesis pura: senos, ruido y filtros), así que son propios y no tienen problemas de derechos. Para cambiar uno, se edita el script y se vuelve a correr, o se reemplaza el `.wav` por una grabación propia con el mismo nombre.

Desde el código: `Sonido.reproducir("silbato_corto")`, `Sonido.ambiente_de_partido()`, `Sonido.intensidad(0.0 a 1.0)`.

### Cánticos parodia

Las voces cantando no se pueden sintetizar bien, así que se graban. Cualquier `.wav` u `.ogg` que se ponga en `audio/canticos/` suena solo cada 35 a 70 segundos durante el partido, sin tocar código. Ideas en [audio/canticos/LEEME.md](../audio/canticos/LEEME.md).

## Pendiente

- Relato parodia con humor local (el plan lo deja para más adelante).
- Música propia para los menús (hoy suenan los bombos).
- Cuando el área E tenga el sistema de camisetas en 3D, la vista de camiseta de la selección puede mostrar el modelo.
- Escudos oficiales: aparecen solos cuando un club da permiso y se carga `escudo.archivo_oficial`.
