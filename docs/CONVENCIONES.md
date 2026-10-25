# Convenciones

## Reglas que no se negocian

- **Nada de PES ni de Konami.** No se copia ni se extrae nada de sus juegos. La inspiración sale de jugarlos y de información pública.
- **Jugadores ficticios.** No se usan nombres ni caras de personas reales sin autorización.
- **Escudos y camisetas reales, solo con permiso del club.** Si no hay permiso, se usa la versión parodia.
- **El celular manda.** Cada cambio se prueba en un Android de gama media.

## Código

- Motor: **Godot 4.5** (cualquier 4.x más nuevo debería abrirlo). Lenguaje: **GDScript** con tipos (`var x: int`, `-> void`).
- Nombres en **español sin tildes ni eñes** en archivos, carpetas, variables y funciones: `jugador_prueba.gd`, `func reiniciar_jugada()`. Los textos que ve el jugador sí llevan tildes.
- Archivos y carpetas en `snake_case`. Constantes en `MAYUSCULAS`.
- Cada script empieza con un comentario `##` que explica para qué sirve.
- Estilo revisado con `gdlint` (configuración en `gdlintrc`, líneas de hasta 120 caracteres).
- Los datos (clubes, planteles, estadios) van en `datos/` y no escritos en el código.

## Rendimiento en el celular

- **Objetivo:** 60 FPS en un Android de gama media. Mínimo aceptable: 30 FPS estables.
- **Jugador:** de 3.000 a 5.000 polígonos. **Estadio:** menos de 100.000 en total.
- **Texturas:** de 1024 px como máximo para los jugadores y de 2048 px para el estadio.
- Reusar materiales y no crear un material por objeto.
- La escena de prueba muestra los FPS arriba a la izquierda.

## Cómo se trabaja

- `main` siempre tiene que andar. Cada cambio va en una rama propia y entra por pull request.
- Nombres de rama: `area-x/descripcion-corta`, por ejemplo `area-b/barra-de-potencia`.
- Un pull request entra cuando las pruebas de GitHub dan verde.
- Si agregás una mecánica, agregá una prueba en `tests/` y sumala a `ARCHIVOS_DE_PRUEBA` en `tests/ejecutar_tests.gd`.
