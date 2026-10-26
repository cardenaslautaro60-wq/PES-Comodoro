class_name CapasFisica
## Capas de colisión del partido.
##
## La pelota no choca contra los jugadores: quién la toma, quién la roba y cuándo
## rebota en un cuerpo lo decide la lógica de `Pelota` y `Jugador`. Así el control
## "pegado al pie" no se rompe con empujones de la física.

## Piso, arcos y todo lo que no se mueve.
const MUNDO := 1
## Cuerpos de los jugadores (chocan entre ellos y con el mundo).
const JUGADORES := 2
## La pelota (choca solo con el mundo).
const PELOTA := 4
