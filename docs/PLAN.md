# PES: Comodoro — Plan completo

Juego de fútbol 3D inspirado en PES 2006, con los clubes de la Liga de Fútbol de Comodoro Rivadavia. Se juega en celular y en PC, y se diseña primero para el celular.

- **Repo:** `cardenaslautaro60-wq/pes-comodoro`
- **Motor:** Godot 4 (última versión estable), en GDScript. Exporta a Android, PC (Windows y Linux) y web.
- **Lanzamiento:** noviembre de 2026. Nicolás decide la fecha.
- **Última actualización:** 25 de octubre de 2026

---

## 1. Reglas del proyecto

1. **Nos inspiramos en PES 2006, no lo copiamos.** No se abre, no se desarma y no se extrae nada del juego de Konami: ni código, ni gráficos, ni sonidos, ni datos. La referencia sale de jugarlo y de información pública como videos y wikis.
2. **Nombres de clubes reales.** Los escudos y las camisetas oficiales se usan solo con permiso del club. Si un club no da permiso, se usa una versión parodia con colores parecidos y escudo propio.
3. **Los jugadores tienen nombres inventados (parodia).** Son personas reales de una liga amateur, así que no se usan sus nombres ni sus caras sin autorización.
4. **El celular es la prioridad.** Tiene que andar a 60 FPS en un Android de gama media, y si no se puede, a 30 FPS estables. Todo se prueba en el celular primero.
5. **Los datos se pueden editar.** Clubes, camisetas, estadios y planteles van en archivos de datos, no escritos dentro del código, para que cualquiera pueda agregar o corregir un club.

## 2. Qué toma el juego de PES 2006 como inspiración

- **Ritmo y sensación:** partido más lento y táctico que un arcade, con pases cortos rápidos y control de pelota pegado al pie.
- **Barra de potencia:** para tiros, pases largos y centros.
- **Pase al hueco**, sprint con **estamina** que se gasta y cambio de jugador.
- **Cámara de TV lateral y amplia**, como en una transmisión.
- **Repeticiones** del gol desde varios ángulos.
- **Formaciones** que se pueden elegir y un editor simple. Más adelante, un modo carrera estilo "Liga Master" con los clubes de Comodoro.

## 3. Controles

**Celular (pantalla táctil):**
- **Joystick virtual a la izquierda** para moverse.
- **Botones a la derecha cuando tenés la pelota:** Pase, Tiro (mantener para cargar la potencia), Pase largo o centro, Pase al hueco y Sprint.
- **Botones a la derecha cuando defendés:** Presión, Barrida, Cambiar jugador y Sprint.
- Los botones son grandes, se puede cambiar su tamaño y hay opción de vibración.

**PC:** teclado y joystick (gamepad), con el mismo esquema que el celular.

## 4. Áreas de trabajo (una por hilo)

Cada área se puede trabajar en su propio hilo. La columna "Depende de" dice qué tiene que estar listo antes.

| # | Área | Depende de | Puede empezar |
|---|---|---|---|
| A | Base del proyecto | — | Ya |
| B | Jugabilidad: jugador, pelota y cámara | A | Después de A |
| C | IA, reglas y partido completo | B | Después de B |
| D | Datos de los clubes de Comodoro | — | Ya (investigación) |
| E | Arte 3D: jugadores, camisetas y estadios | A | Ya (estilo y referencias) |
| F | Cinemáticas y repeticiones | B, E | Después de B |
| G | Menús, interfaz y sonido | A | Después de A |
| H | Publicación y lanzamiento | todas | Al final |

### A. Base del proyecto
- Proyecto Godot 4 con el renderer *Mobile* (y *Compatibility* para la web).
- Estructura de carpetas, convenciones de código y README.
- Una escena de prueba que abra en PC y en el celular.
- Configuración de exportación para Android, PC y web.
- Compilación automática en GitHub Actions que verifica el proyecto y genera las versiones de prueba.
- **Listo cuando:** el proyecto abre en Godot, compila en GitHub y la escena de prueba corre en un Android.

### B. Jugabilidad: jugador, pelota y cámara
- Cancha 3D con las medidas reglamentarias, los arcos y las líneas.
- Pelota con física: rebote, efecto, roce con el pasto y un control que la mantiene "pegada al pie".
- Un jugador con movimiento, sprint y estamina, pase, tiro con barra de potencia, pase largo y pase al hueco.
- Cámara de TV que sigue la jugada.
- Controles táctiles y de teclado o joystick.
- **Listo cuando:** se puede llevar la pelota, pasar y meter un gol en el celular, y se siente bien.

### C. IA, reglas y partido completo
- 11 contra 11 con formaciones (4-4-2, 4-3-3 y 3-5-2 para empezar).
- IA de compañeros (desmarques, apoyos) y de rivales (presión, marca, arquero).
- Cambio automático de jugador.
- Reglas: lateral, córner, saque de arco, faltas básicas, tiros libres y penales. El offside queda opcional en la primera versión.
- Reloj de partido configurable (por ejemplo, 2 tiempos de 3 a 10 minutos), marcador y entretiempo.
- Tres niveles de dificultad.
- **Listo cuando:** se juega un partido completo contra la máquina sin errores.

### D. Datos de los clubes de Comodoro
- Investigar de cada club: nombre oficial, apodo, colores, camiseta titular y suplente, estadio y barrio.
- Pedir permiso a cada club para usar el escudo y la camiseta, y llevar un registro de las respuestas.
- Definir el formato de los datos de un club (archivo por club).
- Armar planteles con nombres inventados y atributos (velocidad, pase, tiro, defensa, estamina).
- Escudos parodia para los clubes que no den permiso.
- **Clubes de la Primera A (Clausura 2026):** CAI, Jorge Newbery, Huracán, USMA, Petroquímica, Laprida, Deportivo Sarmiento, General Saavedra, Rada Tilly, Deportivo Portugués, Argentinos Diadema y Próspero Palazzo.
- **Otros clubes del Apertura 2025:** Florentino Ameghino y Tiro Federal.
- **Canchas mencionadas:** Estadio Municipal, Far West, Armando Ávila y Pampa Zaldúa.
- **Fuentes:** Pasta de Campeón, ADNSUR y El Patagónico.
- **Listo cuando:** los 12 clubes de la A tienen un archivo de datos completo y un plantel.

### E. Arte 3D: jugadores, camisetas y estadios
- Estilo visual "low poly" prolijo, que se vea bien y ande fluido en el celular.
- Modelo de jugador base de 3.000 a 5.000 polígonos, con variantes de cara, pelo y piel.
- Animaciones (correr, pasar, patear, cabecear, barrer, festejar, atajar), propias o de Mixamo.
- Sistema de camisetas que arma la textura a partir de los datos del club: colores, rayas, bandas, número y sponsor parodia.
- Estadios. Primero el Estadio Municipal y una cancha de barrio genérica, después los de cada club.
- Detalles de Comodoro: viento patagónico, el Cerro Chenque de fondo y tribunas chicas.
- **Listo cuando:** dos equipos con camisetas distintas juegan en el Municipal a buen FPS en el celular.

### F. Cinemáticas y repeticiones
- Salida de los equipos a la cancha antes del partido.
- Presentación del estadio con una pasada de cámara, con el Cerro Chenque o el mar de fondo.
- Festejo de gol con cámara cercana y animación de festejo.
- Repetición automática del gol desde 2 o 3 ángulos, y repetición manual.
- Cinemáticas del entretiempo y del final del partido, con el ganador festejando.
- Una intro corta del juego.
- Todas se pueden saltear tocando la pantalla.
- **Listo cuando:** un partido tiene sus cinemáticas de inicio, gol y final.

### G. Menús, interfaz y sonido
- Menú principal, elección de equipos (con escudo y camiseta), elección de estadio y opciones.
- HUD del partido: marcador, reloj, nombre del jugador, barra de potencia y estamina.
- Pausa con cambios y formación.
- Sonido: pelota, silbato, ambiente de hinchada y cánticos parodia.
- Más adelante, relato parodia con humor local.
- **Listo cuando:** se puede ir del menú al partido y volver, con sonido.

### H. Publicación y lanzamiento
- Versiones finales para Android (APK y Google Play), PC e itch.io o web.
- Página del juego con capturas y un video.
- Aviso legal: proyecto de fans, permisos de los clubes y jugadores ficticios.
- Prueba con gente de Comodoro (beta cerrada) y corrección de errores.
- Difusión en las redes de los clubes y en los medios locales.
- **Listo cuando:** el juego está publicado y se puede descargar.

## 5. Calendario hacia noviembre

| Fecha | Hito |
|---|---|
| 1 de noviembre | **Prototipo:** un jugador, pelota y gol en el celular (A y B) |
| 8 de noviembre | **Partido:** 11 contra 11 con IA básica y reglas (C) |
| 15 de noviembre | **Comodoro:** 4 a 6 clubes con camisetas, el Municipal y menús (D, E y G) |
| 22 de noviembre | **Cinemáticas y sonido** (F y G) |
| 29 de noviembre | **Beta y lanzamiento**, en la fecha que decida Nicolás (H) |

**Versión de noviembre:** amistosos entre 4 y 6 clubes, en 1 o 2 estadios, con las cinemáticas principales.

**Después de noviembre:** los 14 clubes, el torneo de la Liga del Sur, el modo carrera, el multijugador local en un solo celular, el relato y más estadios.

## 6. Riesgos

- **El 3D para noviembre es justo.** Si hace falta, se recorta la cantidad de clubes y de cinemáticas antes que la calidad del juego.
- **Rendimiento en celulares de gama baja.** Se mide desde la primera semana.
- **Permisos de los clubes.** Si tardan, se sale con la versión parodia y se actualiza después.
- **Que la IA sea divertida** lleva mucho ajuste. Conviene probar jugando todas las semanas.

## 7. Herramientas

- **Para desarrollar (Claude):** trabaja en la nube y sube los cambios al repo de GitHub con pull requests.
- **Nicolás necesita** Godot 4, Git y un Android con depuración USB para probar.
- **Opcional:** Blender para modelar y Mixamo para animaciones.
