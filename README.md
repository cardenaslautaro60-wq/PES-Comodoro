# PES: Comodoro

Juego de fútbol 3D inspirado en PES 2006, con los clubes de la Liga de Fútbol de Comodoro Rivadavia. Se juega en el celular y en la compu.

> Proyecto de fans. No usa código, gráficos, sonidos ni datos de PES ni de Konami. Los jugadores son ficticios. Los escudos y camisetas reales se usan solo con permiso de cada club.

- **Plan completo:** [docs/PLAN.md](docs/PLAN.md)
- **Cómo trabajamos:** [docs/CONVENCIONES.md](docs/CONVENCIONES.md)

## Abrir el proyecto

1. Instalá [Godot 4.5](https://godotengine.org/download) o una versión 4.x más nueva (la estándar, no la de .NET).
2. Cloná el repo: `git clone https://github.com/cardenaslautaro60-wq/pes-comodoro.git`
3. Abrí Godot, tocá **Importar** y elegí el archivo `project.godot`.
4. Apretá **F5** para jugar el entrenamiento: tu equipo (rojo) contra tres rivales y un arquero que todavía están quietos.

**Controles** (mantené el botón para cargar la potencia y soltalo para patear):

| Acción | Teclado | Joystick | Celular |
|---|---|---|---|
| Moverse | WASD o flechas | Palanca izquierda | Tocar y arrastrar en la mitad izquierda |
| Sprint | Shift | RB | SPRINT |
| Pase / **presión** al defender | J o Espacio | A | PASE / PRESIÓN |
| Tiro / **barrida** al defender | K | B | TIRO / BARRIDA |
| Pase largo o centro | L | X | LARGO |
| Pase al hueco | I | Y | HUECO |
| Cambiar de jugador (al defender) | Q | LB | CAMBIAR |

Cómo funciona por dentro y qué pueden usar las otras áreas: [docs/JUGABILIDAD.md](docs/JUGABILIDAD.md).

## Probar en el celular (Android)

**Opción rápida, sin instalar nada:** cada cambio genera un APK en GitHub. Entrá a la pestaña **Actions** del repo, abrí la última ejecución que haya salido bien y bajá `pes-comodoro-android`. Pasalo al celular e instalalo (hay que permitir "instalar apps de origen desconocido").

**Desde Godot**, para probar cambios al instante:
1. Activá la depuración USB en el celular (Ajustes → Acerca del teléfono → tocar 7 veces "Número de compilación" → Opciones de desarrollador → Depuración USB).
2. En Godot: Editor → Administrar plantillas de exportación → Descargar.
3. Instalá Android Studio o solo el SDK, y Java 17. En Godot, cargá sus rutas en Editor → Configuración del editor → Exportar → Android.
4. Conectá el celular por USB y tocá el ícono de Android arriba a la derecha.

## Pruebas automáticas

```bash
godot --headless --path . --import
godot --headless --path . res://tests/ejecutar_tests.tscn
```

GitHub las corre solas en cada pull request, junto con la revisión de estilo (`gdlint`) y la exportación a Android, web, Linux y Windows.

## Estructura

| Carpeta | Qué va ahí |
|---|---|
| `escenas/` | Escenas de Godot (`.tscn`) |
| `scripts/partido/` | Jugabilidad: cancha, pelota, jugador, cámara y control |
| `scripts/` | Código GDScript, con las mismas subcarpetas que `escenas/` |
| `scripts/autoload/` | Sistemas globales, como los controles |
| `datos/clubes/` | Un archivo por club: nombre, colores, camisetas, estadio y plantel |
| `arte/` | Modelos 3D, texturas y animaciones |
| `audio/` | Sonidos y música |
| `tests/` | Pruebas automáticas |
| `docs/` | Plan y convenciones |
