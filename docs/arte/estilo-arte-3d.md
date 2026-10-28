# Guía de arte 3D

Cómo se ve PES: Comodoro y qué reglas sigue todo modelo, textura y animación que entre al juego. Es el área E del plan.

- **Última actualización:** 25 de octubre de 2026
- **Se lee junto con:** `docs/CONVENCIONES.md` (reglas del código) y `docs/datos-clubes.md` (formato de los datos)
- **Motor:** Godot 4, renderer *Mobile* (y *Compatibility* para la web)
- **Prioridad:** que ande en un Android de gama media. Si algo se ve lindo pero baja los FPS, se simplifica.

---

## 1. Decisiones en una tabla

| Tema | Decisión |
|---|---|
| Estilo | "Low poly prolijo": proporciones realistas, formas simples, colores planos y bien saturados. Sin texturas fotográficas. |
| Jugador | 3.500 a 5.000 triángulos en el modelo cercano, 1.500 en el medio y 500 en el lejano. |
| Esqueleto | Humanoide de unos 25 huesos (sin dedos). Animaciones de Mixamo o propias, adaptadas en Godot. |
| Materiales por jugador | 2: uno para el equipo (camiseta, short y medias) y uno para el cuerpo (piel, pelo y botines). |
| Camisetas | Se arman solas a partir de los datos del club. Una textura de 512×512 por equipo; el número lo dibuja el shader. Ya hay un prototipo andando (sección 5). |
| Estadios | Piezas modulares (tribunas, alambrado, torres de luz, carteles) que se combinan. Fondo de Comodoro pintado, no modelado. |
| Hinchada | Planos con dibujos de hinchas, en masa con `MultiMeshInstance3D` y movidos por shader. |
| Luz | Una luz direccional y luz horneada (*lightmap*) en el estadio. Sombras de jugadores simples (manchita oscura) en calidad baja y media. |
| Formato | Blender → glTF binario (`.glb`) → Godot. 1 unidad = 1 metro. |
| Licencias | Solo assets propios, CC0 o con licencia que permita uso comercial. Todo se anota en `arte/CREDITOS.md`. Nada de PES ni de otros juegos. |

---

## 2. Estilo visual

### La idea

Que se lea como una **transmisión de TV de un partido de la liga local**, pero con un acabado limpio de juego indie. De PES 2006 tomamos el encuadre (cámara lateral y alta), la escala de los jugadores en pantalla y la sensación de partido "serio". No tomamos ni un píxel de sus gráficos.

Con la cámara de TV, el jugador ocupa entre 40 y 90 píxeles de alto en un celular. A ese tamaño lo que se ve es la **silueta, los colores de la camiseta y la animación**. La cara casi no se ve en el partido, solo en las cinemáticas. Por eso el presupuesto va primero a camisetas claras y animaciones fluidas, y la cara se resuelve con textura simple.

### Reglas del estilo

1. **Proporciones realistas**, apenas estilizadas: cabeza un poco más grande (1/7 del cuerpo en vez de 1/7,5) para que se lea a distancia. Nada de "cabezones" tipo caricatura.
2. **Colores planos con poco detalle de textura.** Las camisetas son colores sólidos y patrones nítidos. Un poco de ruido suave en el pasto y en el cemento, nada más.
3. **Bordes y formas simples.** Se nota el facetado de los polígonos en las piezas de estadio y se suaviza en los jugadores.
4. **Paleta de Comodoro:** cielo celeste muy limpio y luz dura de día; ocres y marrones grises del Cerro Chenque; el azul del golfo San Jorge; pasto verde apagado o sintético bien verde; cemento gris de las tribunas.
5. **El viento se ve:** banderas y redes que se mueven, alguna bolsa o polvo que cruza, árboles chicos inclinados. Es el sello del juego.
6. **Hora del día:** tarde (luz lateral cálida) como opción principal y noche con torres de luz como segunda. Ambas con luz horneada.

### Referencias para mirar (solo de inspiración)

- **Transmisiones de partidos de la Liga de Comodoro** (videos de los clubes y de los medios locales): ángulo de cámara, cómo se ven las tribunas chicas, alambrados y canchas sintéticas.
- **Fotos propias de las canchas** (pedidas a Nicolás o a quien pueda sacarlas): son la referencia principal para cada estadio.
- **PES 2006 jugado o en videos públicos**: encuadre de la cámara, tamaño del jugador en pantalla, ritmo de las repeticiones.
- **Packs CC0 de Kenney y Quaternius**: nivel de detalle "low poly prolijo" al que apuntamos.

---

## 3. Presupuesto técnico (celular de gama media)

Todo se mide en el celular de prueba desde la primera semana. Estos números son el techo, no la meta.

### En pantalla con la cámara de TV

| Qué | Límite |
|---|---|
| Triángulos visibles en total | 150.000 |
| Llamadas de dibujo (*draw calls*) | 120 |
| Jugadores (22 + 3 árbitros) | 25 × 2 materiales = 50 llamadas |
| Estadio completo | 40.000 triángulos, 20 a 30 llamadas (las convenciones permiten hasta 100.000; apuntamos más bajo para dejar margen a la hinchada y las cinemáticas) |
| Hinchada | 1 o 2 llamadas (todo en un `MultiMesh`) |
| Memoria de texturas | 64 MB |

### Jugador

| Nivel de detalle | Triángulos | Cuándo se usa |
|---|---|---|
| Cercano (LOD0) | 3.500 a 5.000 | Cinemáticas, repeticiones, menú |
| Medio (LOD1) | ~1.500 | Partido con cámara de TV |
| Lejano (LOD2) | ~500 | Jugadores lejos de la cámara |

- Godot puede generar los LOD solo al importar (*Generate LODs*). Probar eso primero y hacer LOD a mano solo si se ve mal.
- **Huesos:** unos 25. El esqueleto de Mixamo trae 65 (con dedos); se borran los dedos y se dejan manos enteras. Menos huesos = menos trabajo para el celular con 25 jugadores animados.
- **Texturas del jugador:** equipo 512×512 (una por equipo, compartida), cuerpo 256×256 (piel, cara y pelo en una sola textura atlas).

### Estadio

- Textura atlas de 1024×1024 para todas las piezas de un estadio, con colores por paleta.
- Luz horneada con `LightmapGI` (funciona en el renderer *Mobile*). Nada de luces dinámicas extra.
- La tribuna y el fondo que no se ven con la cámara de TV no se modelan.

### Calidad configurable

| Opción | Baja | Media | Alta |
|---|---|---|---|
| Resolución 3D (*scaling 3D*) | 70 % | 85 % | 100 % |
| Sombras de jugadores | Manchita | Manchita | Sombra real de la luz principal |
| Hinchada | Mitad | Completa | Completa y animada |
| Antialiasing | No | FXAA | MSAA 2× |
| Banderas y redes con viento | No | Sí | Sí |

### Importación de texturas

- En el proyecto: compresión VRAM con **ETC2/ASTC** activada para Android.
- Texturas de colores planos y UI: sin compresión con pérdida si se ven "sucias".
- Mipmaps activados en todo lo 3D.

---

## 4. Jugadores

### Modelo provisorio (ya en el repo)

Hasta tener el modelo de Blender, `scripts/jugadores/modelo_jugador.gd` (clase `ModeloJugador`) arma un jugador low poly por código:

- **1.156 triángulos y 2 materiales:** el del equipo (`GeneradorCamiseta.crear_material`) y el del cuerpo (`arte/modelos/jugador/cuerpo.gdshader`, que pinta piel, pelo y botines con colores de vértice).
- **Esqueleto de 11 huesos** (cadera, torso, cabeza, brazos, antebrazos, muslos y piernas) con animaciones hechas por código: parado, trote y carrera según la velocidad, patada, barrida y caída.
- **Respeta la distribución de la camiseta** de la sección 5, así que la textura de cada club se ve igual que en el modelo final.
- Toma la `apariencia` del plantel. Los jugadores con el mismo pelo comparten la malla, y los colores van por instancia, sin materiales nuevos.
- Mira hacia **-Z**, como `Basis.looking_at`. Si el padre es un `CharacterBody3D`, toma su velocidad solo. Si además tiene la señal `pateo` y la variable `estado` (como `Jugador`), patea, barre y se cae solo.
- **Escena de muestra:** `escenas/arte/vestuario.tscn`, con dos clubes trotando, para medir los FPS en el celular.

Para usarlo en `Jugador`, en lugar de la cápsula:

```gdscript
var modelo := ModeloJugador.new()
modelo.name = "Modelo"
add_child(modelo)
modelo.vestir(material_del_equipo, dorsal, datos_del_plantel.get("apariencia", {}))
```

Ojo con los parámetros por instancia: los dos shaders del jugador declaran los mismos (`numero`, `color_piel`, `color_pelo`, `color_botines`) en el mismo orden, porque Godot los guarda juntos por malla. Si se agrega uno nuevo, va en los dos.

### Modelo base (Blender)

- **Uno solo** para todos los jugadores de campo, con altura 1,80 m. Las variaciones de altura se hacen escalando entre 0,94 y 1,06.
- **Contextura:** una *blend shape* "robusto" (de 0 a 1) para tener jugadores más anchos sin otro modelo.
- **Partes separadas:** cuerpo con equipo (una malla con 2 materiales), pelo (malla aparte pegada al hueso de la cabeza) y, para el arquero, guantes.
- **Arquero:** el mismo modelo con su propia camiseta (otro juego de colores en los datos del club) y guantes.
- **Árbitro:** el mismo modelo con un equipo fijo (negro, o amarillo flúor si choca con algún equipo).

### Variantes de apariencia

Los jugadores son **ficticios** (regla 3 del plan): nunca se modela la cara de una persona real.

| Variante | Cantidad inicial | Cómo se hace |
|---|---|---|
| Tono de piel | 4 (`piel` 0 a 3) | Un color en el material del cuerpo |
| Pelo | 6 (`pelo` 0 a 5: rapado, corto, rulos, largo atado, etc.) | Mallas separadas de 150 a 400 triángulos |
| Color de pelo | 4 (`color_pelo` 0 a 3) | Un color en el material |
| Barba | Sí o no (`barba`) | Textura en el atlas |
| Cara | 4 | Textura en el atlas, elegida al azar con el nombre del jugador como semilla |
| Botines | 4 colores | Color en el atlas |

Los rangos son los que ya traen los planteles en el campo `apariencia` (ver `docs/datos-clubes.md`). Si se agregan variantes, se amplía el rango en los datos y en el modelo a la vez.

### Animaciones

Todas **en el lugar** (*in place*): el código mueve al jugador y la animación solo pone el cuerpo. Se combinan en un `AnimationTree` con un *blend space* para caminar, trotar y correr.

| Prioridad | Animaciones |
|---|---|
| Para el prototipo (1 de noviembre) | Parado, trote, carrera, pase, tiro |
| Para el partido (8 de noviembre) | Correr con pelota, pase largo, cabezazo, barrida, caída, levantarse, atajadas (baja, media, alta y estirada), saque del arquero, lateral |
| Para las cinemáticas (22 de noviembre) | Salida a la cancha, saludo, 4 festejos, lamento, aplauso del final |

**Fuentes de animación, en orden:**

1. **Mixamo** (gratis con cuenta de Adobe). Se pueden usar en juegos, incluso comerciales. Lo que no se puede es subir los archivos de Mixamo tal cual a un repositorio público o revenderlos como pack. Si el repo se hace público, guardar las animaciones ya importadas en recursos de Godot (`.res`) y no los `.fbx` originales.
2. **Quaternius** (CC0): tiene packs de animaciones humanoides libres.
3. **Propias en Blender** para lo que no exista (festejos locales, por ejemplo).

**Cómo traerlas a Godot:** importar el `.fbx` o `.glb`, usar el *Retarget* de Godot con el perfil `SkeletonProfileHumanoid` y un `BoneMap`, y guardar cada animación en una `AnimationLibrary` compartida por todos los jugadores.

---

## 5. Camisetas

Ya hay un prototipo andando, probado en Godot 4.5.1 con pruebas automáticas:

- `scripts/camisetas/generador_camiseta.gd`: arma la textura del equipo a partir de los datos del club.
- `arte/camisetas/camiseta.gdshader`: dibuja la textura y el número de cada jugador, con borde cuando hace falta.
- `arte/camisetas/atlas_numeros.png`: los dígitos del 0 al 9, hechos con la tipografía Oswald (licencia OFL, copia en `arte/camisetas/fuentes/`).
- `arte/camisetas/ejemplos/`: cuatro equipos inventados para probar.
- `scripts/herramientas/exportar_camisetas.gd`: guarda las texturas en PNG para revisarlas sin abrir el juego.
- `tests/test_camisetas.gd`: pruebas del generador.

### Cómo funciona

1. Al cargar el partido, `GeneradorCamiseta.generar(kit, escudo, sponsor)` arma **una textura de 512×512 por equipo**. Tarda milisegundos porque pinta rectángulos, no píxel por píxel.
2. El texto del sponsor parodia se dibuja antes con `await GeneradorCamiseta.imagen_sponsor(get_tree(), kit)`, que elige solo el color que mejor se lee sobre la camiseta.
3. Los 11 jugadores del equipo comparten **un solo material** con esa textura. Al material se le pasan `color_numero(kit)` y `color_borde_numero(kit)`.
4. El número de cada jugador se pone con `malla.set_instance_shader_parameter("numero", 10)`. El shader lo dibuja en la espalda y chico en el pecho, sin crear una textura por jugador. En camisetas con rayas, bandas o mitades le agrega un borde en contraste para que se lea.

### Datos de una camiseta

El formato lo define el área de datos de los clubes, en `docs/datos-clubes.md`: cada club tiene `camisetas.titular`, `camisetas.suplente` y `camisetas.arquero`. El generador usa estos campos:

| Campo | Qué hace en la textura |
|---|---|
| `patron` | `liso`, `rayas_verticales`, `bandas_horizontales`, `mitades`, `banda_diagonal`, `v_frontal` o `banda_pecho`. El generador también acepta `franja_vertical` y `cuadros` para clubes futuros |
| `color_base` | Fondo de la camiseta y mangas |
| `color_secundario` | Color del patrón |
| `color_terciario` | Tercer color de la V (`v_frontal`) y filetes de la `banda_pecho` |
| `hombreras` | Franja en los hombros, adelante, atrás y en las mangas |
| `cuello` | Cuello, puños y vivos del short y las medias |
| `numero` | Color del número |
| `pantalon`, `medias` | Color del short y de las medias |
| `sponsor_parodia` | Texto del sponsor inventado |
| `cantidad_rayas` | Opcional: de 2 a 15 (por defecto, 7) |

El escudo no está en la camiseta sino en el club (`escudo.archivo_oficial` si hay permiso, `escudo.parodia.archivo` si no). Se pasa como imagen al generador.

Si un club tiene un diseño que no entra en estos patrones, se agrega uno nuevo al generador (es una función corta) y al formato de datos, o como último recurso se pinta la textura a mano respetando la distribución de abajo.

### Sponsors y marcas

- **Ninguna marca real** en las camisetas: ni la del fabricante ni la del sponsor real del club, salvo permiso escrito de esa marca.
- Los sponsors son **parodias de comercios locales inventados** (por ejemplo "Viento Sur", el del ejemplo). Se pueden hacer chistes de Comodoro, sin nombrar empresas reales.
- El texto del sponsor va en el centro del pecho. En `banda_pecho` y `v_frontal` baja un poco para no tapar el diseño.

### Distribución de la textura (UV)

Quien modele el jugador tiene que respetar esto. La textura es de 512×512 y las zonas son, en píxeles:

| Zona | Rectángulo (x, y, ancho, alto) | Notas |
|---|---|---|
| Frente de la camiseta | 0, 0, 256, 256 | Visto de frente: la izquierda de la imagen es el lado derecho del jugador |
| Espalda | 256, 0, 256, 256 | Vista desde atrás. El número va en 288–480 × 48–208 |
| Mangas | 0, 256, 256, 96 | Mitad izquierda = manga derecha |
| Cuello y puños | 0, 352, 256, 32 | Color de detalle |
| Short | 256, 256, 256, 128 | Mitad izquierda = pierna derecha. Vivos en los bordes |
| Medias | 0, 384, 256, 128 | Banda de color arriba |
| Libre | 256, 384, 256, 128 | Reservado (guantes del arquero, etc.) |

Escudo: pecho izquierdo del jugador (píxeles 150–206 × 34–90). Número chico del pecho: lado derecho (48–96 × 32–80). Sponsor: centro del pecho (40–216 × 110–170).

---

## 6. Estadios

### Cómo se arman

Con un **kit de piezas modulares** que se reutilizan entre estadios, todas sobre una grilla de 1 metro:

- Tribuna de cemento recta (3 largos y 2 alturas), con y sin techo
- Platea chica con techo de chapa
- Alambrado olímpico, paredón de ladrillo o de bloques, portón
- Torre de luz, banco de suplentes, cabina de transmisión, casilla de vestuarios
- Carteles de publicidad parodia, bandera en mástil, contenedor, auto estacionado
- Arcos con red (la red se mueve con el viento por shader)

Cada estadio es una escena de Godot que combina estas piezas, más su cancha y su fondo. Así un estadio nuevo se arma en horas, no en días.

### Cancha

- 105 × 68 m de juego (o la medida real si es más chica), con las líneas en una textura aparte para que queden nítidas.
- **Tres superficies:** pasto natural (con franjas de corte), sintético (verde parejo y brillante) y tierra (más adelante). Varias canchas de la liga son sintéticas, así que es importante tenerla desde el principio.
- Los datos de cada estadio (`superficie`, `tribunas`, `pista_atletismo`, `iluminacion` y `entorno.fondo`) dicen qué piezas, superficie y fondo usar. El Municipal tiene pista de atletismo, que va como una pieza más del kit.

### Fondo de Comodoro

No se modela la ciudad. Se pinta **un panorama en capas** (cielo, Cerro Chenque, barrio, mar o meseta, según `entorno.fondo` del estadio) en planos grandes detrás de la tribuna, con un poco de paralaje. Es barato y es lo que hace que se reconozca la ciudad. Para la cinemática de presentación del estadio (área F) se puede sumar una versión más detallada del cerro, solo para esa toma.

### Orden de trabajo

1. **Cancha de barrio genérica:** sintético, alambrado, una tribuna chica, torres de luz y el cerro de fondo. Sirve para probar todo el kit.
2. **Estadio Municipal:** primer estadio "real". Hacen falta fotos de los cuatro lados, de la tribuna principal y de lo que se ve detrás.
3. Después, el de cada club, empezando por los 4 a 6 clubes de la versión de noviembre.

### Hinchada

- Planos con dibujos de hinchas (un atlas con 16 a 32 figuras), puestos con un `MultiMeshInstance3D` sobre las tribunas.
- El color de las remeras toma los colores del club local por shader. Saltan y agitan los brazos con un movimiento simple en el shader, más fuerte después de un gol.
- Desde cerca (cinemáticas) se ven planos, así que esas tomas evitan mostrar la tribuna de cerca.

---

## 7. De dónde sacar assets

| Fuente | Qué tiene | Licencia | Para qué |
|---|---|---|---|
| [Kenney](https://kenney.nl/assets) | Modelos y texturas low poly, incluso deportes y ciudad | CC0 | Piezas de estadio, autos, detalles |
| [Quaternius](https://quaternius.com) | Personajes y animaciones low poly | CC0 | Base de jugador y animaciones |
| [Mixamo](https://www.mixamo.com) | Animaciones humanoides | Gratis con cuenta de Adobe, uso en juegos permitido | Animaciones de jugador |
| [Poly Haven](https://polyhaven.com) | Texturas, cielos HDRI y modelos | CC0 | Cielo, cemento, chapa, ladrillo |
| [ambientCG](https://ambientcg.com) | Texturas PBR | CC0 | Pasto, tierra, cemento |
| [MakeHuman](http://www.makehumancommunity.org) | Generador de cuerpos humanos | Los modelos exportados son CC0 | Punto de partida del jugador base |
| [Google Fonts](https://fonts.google.com) | Tipografías | OFL | Números de camiseta, menús |
| [Sketchfab](https://sketchfab.com) | De todo | Varía: usar solo CC0 o CC BY | Casos puntuales, con crédito |

**Qué no se usa nunca:**

- Nada de PES, FIFA ni otro juego: ni modelos, ni texturas, ni "parches" u *option files*, ni sitios de *rips* de juegos.
- Logos de marcas reales (Adidas, Nike, etc.) ni sponsors reales sin permiso.
- Fotos de jugadores reales para hacer caras.
- Escudos o camisetas oficiales de un club sin su permiso (ver el registro del área D).

**Registro de créditos:** cada asset de afuera se anota en `arte/CREDITOS.md` con nombre, autor, enlace y licencia, antes de subirlo al repo.

---

## 8. Cómo se crean y se suben

### De Blender a Godot

1. Modelar con 1 unidad = 1 metro, parado en el origen. En Godot el jugador tiene que mirar hacia **-Z**; si el `.glb` llega mirando a +Z, se gira 180° en la importación.
2. Aplicar escala y rotación (*Apply All Transforms*) antes de exportar.
3. Exportar en **glTF binario (`.glb`)**, con las animaciones si las tiene.
4. Guardar el `.blend` original en `arte/fuentes/` y el `.glb` en la carpeta del asset.
5. En Godot: revisar la importación (LOD, compresión, materiales) y guardar la configuración en el `.import`.

### Nombres y carpetas

Siguen `docs/CONVENCIONES.md` (nombres en español, sin tildes ni eñes, y el código en `scripts/`):

```
arte/
  modelos/
    jugador/      modelo base, pelos y animaciones
    estadios/
      kit/        piezas modulares compartidas
      municipal/  escena y fondo del Estadio Municipal
      barrio/     cancha de barrio genérica
    hinchada/
  texturas/       atlas del cuerpo, del estadio, fondos pintados
  camisetas/      shader, atlas de números y ejemplos
  sponsors/       logos de sponsors parodia, si alguno se dibuja a mano
  fuentes/        archivos .blend y .kra originales
  CREDITOS.md
scripts/camisetas/    generador de camisetas
scripts/herramientas/ herramientas para correr a mano
```

- Nombres en minúscula, sin tildes ni espacios: `tribuna_recta_10m.glb`, `pelo_rulos.glb`.
- Los archivos `.blend` pesados se pueden guardar con Git LFS si el repo crece mucho.

---

## 9. Calendario del arte

| Fecha | Qué tiene que estar |
|---|---|
| 1 de noviembre | Jugador provisorio (cápsula o modelo CC0) con trote, carrera, pase y tiro. Cancha con líneas. |
| 8 de noviembre | Jugador base con la distribución de UV de la sección 5 y las camisetas andando. Animaciones del partido. Árbitro. |
| 15 de noviembre | 4 a 6 equipos con camiseta, cancha de barrio y Estadio Municipal. Hinchada. Medición de FPS en el celular. |
| 22 de noviembre | Animaciones de festejo y salida, versiones cercanas (LOD0) pulidas para las cinemáticas. |
| 29 de noviembre | Solo correcciones. |

Si no llega, se recorta en este orden: menos estadios, menos variantes de pelo y cara, menos festejos. Lo último que se recorta son las camisetas y las animaciones del partido.

---

## 10. Pendientes

- **Fotos del Estadio Municipal** y de otras canchas: las necesita quien modele los estadios.
- **Camisetas marcadas como "propuesta" o "probable"** en los datos de los clubes: hay que confirmarlas con fotos.
- **Escudos parodia:** los datos describen forma, colores y símbolo de cada uno, pero falta dibujarlos.
- **Quién modela:** si Nicolás quiere modelar en Blender o si se arranca con modelos CC0 de Quaternius o MakeHuman adaptados.
