# Datos de los clubes de Comodoro (área D)

Todo lo que el juego sabe de cada club, estadio y plantel vive en `datos/`, en archivos JSON que se editan a mano. El código no tiene datos de clubes escritos adentro (regla 5 del plan).

```
datos/
  clubes/<id>.json       un archivo por club
  estadios/<id>.json     un archivo por cancha
  planteles/<id>.json    un plantel por club (mismo id que el club)
herramientas/
  validar_datos.py       revisa que todo esté completo (correr antes de cada PR)
  generar_planteles.py   arma planteles con nombres inventados
docs/
  permisos.csv           registro de pedidos de permiso a los clubes
```

El registro de permisos está en `docs/` y no en `datos/` porque Godot importa los `.csv` como traducciones.

Para agregar un club: copiá un archivo de `datos/clubes/`, cambiá el `id` (tiene que ser igual al nombre del archivo), creá o elegí su estadio, corré `python3 herramientas/generar_planteles.py` y después `python3 herramientas/validar_datos.py`.

En Godot los archivos se leen desde `res://datos/...` con `FileAccess` + `JSON.parse_string()`.

## Resumen de los 14 clubes

12 de la Primera A (Clausura 2026) y 2 del Apertura 2025 (Florentino Ameghino y Tiro Federal).

| Club | Apodos | Colores | Camiseta titular | Cancha | Barrio |
|---|---|---|---|---|---|
| CAI | La CAI, Azzurro, Semillero Patagónico | azul y naranja | lisa azul (confirmado) | Estadio Municipal | Km 3 |
| Jorge Newbery | El Lobo, El Aeronauta | azul y blanco | lisa azul (probable) | La Madriguera | Jorge Newbery y Pastor Schmeider |
| Huracán | El Globo, Globito Petrolero | blanco y rojo | lisa blanca (probable) | César Augusto Muñoz | Barrio Industrial |
| USMA | Los Patricios | azul y rojo | rayas verticales (confirmado) | Don Armando Ávila | Azcuénaga, Km 5 |
| Petroquímica | Verdolaga, El Verde, Cementero | verde | lisa verde (probable) | Kilómetro 8 | Don Bosco, Km 8 |
| Laprida | El Verde, Los del Far West | verde y blanco | rayas verticales (confirmado) | Domingo Perea ("Far West") | Laprida, zona oeste |
| Dep. Sarmiento | El Depo | rojo y blanco | banda diagonal (propuesta) | Pampa Zaldúa | ciudad de Sarmiento |
| Gral. Saavedra | El Parque | azul, negro y blanco | rayas verticales (confirmado) | cancha propia | Gral. Saavedra, Km 3 |
| Rada Tilly | Aurinegro, Rada | amarillo y negro | rayas verticales (propuesta) | cancha propia | Rada Tilly |
| Dep. Portugués | Lusitano | rojo, verde y amarillo | lisa roja (propuesta) | Inmigrantes Portugueses | Belgrano 541 |
| Arg. Diadema | Diadema, El del Km 27 | blanco, azul y rojo | blanca con V tricolor (confirmado) | cancha propia | Diadema Argentina, Km 27 |
| Próspero Palazzo | El Aguilucho | rojo y negro | mitades (confirmado) | cancha propia | Próspero Palazzo |
| F. Ameghino | CAFA, El Tricolor | rojo, blanco y negro | rayas con hombreras negras (confirmado) | cancha propia | Ameghino Nuevo, Km 3 |
| Tiro Federal | Tiro, El del Barrio Cemento | celeste y blanco | rayas verticales (propuesta) | cancha propia | Barrio Moreno |

Las 4 canchas que nombra el plan: **Estadio Municipal** (CAI, y a veces Huracán y Newbery), **Far West** (Laprida), **Armando Ávila** (USMA) y **Pampa Zaldúa** (Deportivo Sarmiento).

### Qué significa la "confianza"

Cada camiseta y estadio tiene un campo `confianza`:

- `confirmado`: lo dice una fuente (Wikipedia, Once Patagónico, Estadios de Argentina).
- `probable`: los colores están confirmados pero el diseño exacto no.
- `propuesta`: lo inventamos para que el juego tenga algo. Hay que reemplazarlo cuando se consiga el dato.

Cada archivo también tiene una lista `pendiente` con lo que falta averiguar.

## Formato de un club (`datos/clubes/<id>.json`)

| Campo | Qué es |
|---|---|
| `formato_version` | Versión del formato (hoy `1`). |
| `id` | Igual al nombre del archivo, en minúsculas y con `_`. |
| `nombre_oficial`, `nombre_corto` | Nombre completo y el que entra en menús. |
| `abreviatura` | 3 letras para el marcador (`CAI`, `HUR`...). |
| `apodos` | Lista de apodos. |
| `fundacion`, `nota_fundacion` | Fecha (`AAAA-MM-DD` o `AAAA`) y aclaraciones. |
| `ciudad`, `barrio`, `sede` | Ubicación. |
| `colores`, `nombres_colores` | Colores del club en `#RRGGBB` y en palabras. |
| `camisetas.titular / suplente / arquero` | Ver abajo. |
| `uso_camiseta_oficial` | `parodia_hasta_permiso` hasta que el club autorice. |
| `escudo` | `permiso` (`sin_pedir`, `pedido`, `aprobado`, `rechazado`), `archivo_oficial` (ruta cuando haya permiso), `descripcion_oficial`, y `parodia` con forma, colores, símbolo y texto para dibujar un escudo propio. |
| `estadio_id` | Id de un archivo de `datos/estadios/`. |
| `divisiones` | En qué torneos está (`primera_a_clausura_2026`, `apertura_2025`). |
| `nivel` | Fuerza del equipo de 1 a 5. La usa el generador de planteles y puede usarla la IA. |
| `plantel` | Ruta del plantel. |
| `contacto` | Web y redes para pedir permiso. |
| `fuentes`, `pendiente` | De dónde salió cada dato y qué falta. |

### Camiseta

Pensada para que el sistema de camisetas del área E arme la textura sin dibujar a mano:

| Campo | Valores |
|---|---|
| `patron` | `liso`, `rayas_verticales`, `bandas_horizontales`, `mitades`, `banda_diagonal`, `v_frontal`, `banda_pecho` |
| `color_base`, `color_secundario`, `color_terciario` | `#RRGGBB` (los dos últimos pueden ser `null`) |
| `hombreras`, `cuello`, `numero` | `#RRGGBB` o `null` |
| `pantalon`, `medias` | `#RRGGBB` |
| `sponsor_parodia` | Texto del sponsor inventado (nunca marcas reales) |
| `confianza`, `nota` | Ver arriba |

## Formato de un estadio (`datos/estadios/<id>.json`)

`nombre`, `apodo`, `clubes`, `direccion`, `barrio`, `inaugurado`, `capacidad`, `superficie` (`natural`, `sintetico`, `tierra`, `a_confirmar`), `dimensiones_m` (105 x 68 por defecto si no se sabe), `tribunas` (lista con `lado`, `tipo` y `capacidad_aprox`), `pista_atletismo`, `iluminacion`, `entorno` (`fondo`: `cerro_chenque`, `mar`, `meseta`, etc., y `viento`), `confianza`, `notas`, `fuentes`, `pendiente`.

Hay además una `barrio_generico` para clubes sin estadio modelado.

## Formato de un plantel (`datos/planteles/<id>.json`)

20 jugadores (11 titulares en 4-4-2). Cada uno tiene `nombre` inventado, `apodo` opcional, `dorsal`, `posicion` (`ARQ`, `DFC`, `LAT`, `MC`, `MP`, `EXT`, `DC`), `titular`, `pie`, `edad`, `altura_cm`, `atributos` de 1 a 99 (`velocidad`, `pase`, `tiro`, `defensa`, `estamina`, y `atajada` para arqueros) y `apariencia` (índices de piel, pelo, color de pelo y barba para el modelo 3D).

Los nombres son combinaciones al azar de nombres y apellidos comunes en la Patagonia. **No son jugadores reales** (regla 3 del plan). Si algún nombre coincide con un jugador real de la liga, cambialo a mano.

## Permisos de escudos y camisetas

`docs/permisos.csv` lleva un renglón por club: canal de contacto, fecha del pedido, estado y respuesta. El mensaje para mandarles está en [pedido-permiso.md](pedido-permiso.md). Cuando un club dice que sí, se cambia `escudo.permiso` a `aprobado`, se pone la ruta del escudo en `archivo_oficial` y `uso_camiseta_oficial` pasa a `oficial`.

Además de cada club, conviene escribirle a la **Liga de Fútbol de Comodoro Rivadavia**, que puede reenviar el pedido a todos y dar su aval.

## Fuentes

- [Once Patagónico, Liga de Comodoro](https://oncepatagonico.com.ar/liga-de-futbol-de-comodoro-rivadavia/): ficha de cada club (colores, apodos, fundación, cancha, dirección).
- [Estadios de Argentina](https://www.estadiosdeargentina.com.ar/): Municipal, La Madriguera, César Muñoz, Armando Ávila y Petroquímica.
- [Wikipedia: CAI](https://es.wikipedia.org/wiki/Comisi%C3%B3n_de_Actividades_Infantiles), [Jorge Newbery](https://es.wikipedia.org/wiki/Club_Atl%C3%A9tico_Jorge_Newbery_(Comodoro_Rivadavia)), [Huracán](https://es.wikipedia.org/wiki/Club_Atl%C3%A9tico_Hurac%C3%A1n_(Comodoro_Rivadavia)), [Estadio Municipal](https://en.wikipedia.org/wiki/Estadio_Municipal_de_Comodoro_Rivadavia).
- [Pasta de Campeón](https://www.pastadecampeon.com/) y [Diario Jornada](https://www.diariojornada.com.ar/): torneo actual y canchas sintéticas.

Investigación hecha el 25 de octubre de 2026. Ninguna fuente describía los escudos con palabras, así que la descripción oficial queda para cuando se mire cada escudo.
