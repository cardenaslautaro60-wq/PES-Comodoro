# IA, reglas y partido completo (área C)

Partido 11 contra 11 contra la máquina: formaciones, IA de compañeros y rivales,
árbitro con las reglas básicas, reloj configurable y tres dificultades.

## Piezas

| Archivo | Qué hace |
|---|---|
| `scripts/partido/partido_completo.gd` (`PartidoCompleto`) | Arma el partido: cancha, pelota, 22 jugadores, árbitro, IA, cámara, control, cinemáticas y HUD propio. Es la escena que envuelve `partido.gd` (menús). |
| `scripts/partido/configuracion_partido.gd` (`ConfiguracionPartido`) | Clubes, formaciones, titulares, colores, minutos, dificultad, quién maneja la persona, offside. `desde_menu()` la arma con lo elegido en `ConfigPartido`. |
| `scripts/partido/equipo_partido.gd` (`EquipoPartido`) | Un equipo: carga el club de `datos/`, elige titulares por puesto y calcula la posición táctica de cada jugador según dónde está la pelota. |
| `scripts/partido/arbitro.gd` (`Arbitro`) | Reglas, reloj, goles, entretiempo con cambio de lado y final. |
| `scripts/partido/ia_equipo.gd` (`IAEquipo`) | Una IA por equipo: maneja a todos menos al jugador de la persona. |
| `datos/formaciones/*.json` | 4-4-2, 4-3-3 y 3-5-2. Se agregan formaciones nuevas sin tocar código. |

## Reglas

- **Lateral, córner y saque de arco** según quién la tocó último.
- **Faltas**: barrida que no toca la pelota. Dentro del área del que la cometió es penal, afuera tiro libre con la barrera a 9,15 m.
- **Offside**: opcional (`configuracion.offside`). Se marca quién está adelantado en cada pase y se cobra si recibe él.
- **Saques**: el árbitro elige quién saca y lo deja quieto con la pelota (`Jugador.inmovil`) hasta que patea.
- **Reloj**: 2 tiempos de 3 a 10 minutos reales que muestran 0' a 90'. Corre en juego y en saques (no en penales ni festejos).
- **Arquero**: con la pelota en la mano dentro de su área no se la pueden sacar.

## IA

- **Sin pelota, atacando**: busca espacio adelante respetando el offside y ofrece una opción de pase.
- **Sin pelota, defendiendo**: el más cercano presiona, otro cubre y el resto marca en zona. No barre de atrás ni al arquero.
- **Con pelota**: tira si está cerca, centra desde la banda, busca el mejor pase o gambetea esquivando.
- **Arquero**: se ubica entre la pelota y el arco, sale a buscar pelotas sueltas y decide una vez por tiro si ataja (agarra o da rebote al costado).
- **Cambio automático**: la persona pasa al compañero mejor ubicado cuando la pelota la tiene el rival (nunca deja al arquero).

### Dificultad (`IAEquipo.PARAMETROS`)

| | Fácil | Normal | Difícil |
|---|---|---|---|
| Reacción (s) | 0.5 | 0.32 | 0.2 |
| Presión | 0.45 | 0.75 | 0.95 |
| Barridas | 0.15 | 0.3 | 0.45 |
| Arquero | 0.8 | 0.93 | 1.0 |
| Distancia de tiro (m) | 19 | 22 | 26 |
| Error en pases y tiros | 0.4 | 0.2 | 0.06 |
| Atributos del rival | -8 | 0 | +6 |

## Para las otras áreas

- **Señales del árbitro**: `saque_preparado`, `gol_convertido`, `falta_sancionada`, `offside_sancionado`, `entretiempo`, `partido_terminado`, `aviso`.
- **Cinemáticas (F)**: `PartidoCompleto` expone `pelota`, `jugadores`, `camara`, `control`, `nombre_*`, `goles_*` e `Interfaz`, y llama a `festejar_gol`, `entretiempo` y `final_del_partido`. Durante una cinemática se pausan árbitro e IA.
- **Menús (G)**: `partido.gd` ahora envuelve `partido_completo.tscn`. El reloj de G queda apagado y usa el del árbitro. Cambio de formación y sustituciones desde la pausa llaman a `cambiar_formacion` y `aplicar_cambios`.
- **Cambios en archivos de otras áreas**: `jugador.gd` (atajada, sentido, inmovil, proteger), `partido.gd` y `tests/test_menus.gd` (busca al 10 por dorsal).

## Simular partidos

La máquina contra la máquina, con estadísticas al final:

```
godot --headless --fixed-fps 60 --path . res://tests/simular_partido.tscn -- 10 normal no cai huracan
```

Argumentos: minutos por tiempo, dificultad, `offside` o `no`, club local, club visitante.
Partidos de 10 minutos dan entre 4 y 9 goles, de 1 a 8 faltas y ningún momento trabado.
El acierto de pases ronda el 60 % y se puede mejorar más adelante.
