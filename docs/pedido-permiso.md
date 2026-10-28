# Mensaje para pedir permiso a los clubes

Para mandar por Instagram, Facebook o mail. Cambiá lo que está entre [corchetes]. Después anotá el pedido en `docs/permisos.csv`.

---

Hola, ¿cómo andan? Soy [tu nombre], de Comodoro. Estoy haciendo un videojuego de fútbol gratuito con los clubes de la Liga de Fútbol de Comodoro Rivadavia, para celular y PC. Es un proyecto de fans, sin fines de lucro, pensado para que la gente de la ciudad juegue con sus clubes.

Les escribo para pedirles permiso para usar en el juego:

- El nombre del club ([nombre del club]).
- El escudo.
- Los colores y el diseño de la camiseta titular y suplente.

Algunas aclaraciones:

- Los jugadores del juego tienen nombres inventados. No usamos nombres ni caras de jugadores reales.
- El juego no se vende ni tiene publicidad de marcas reales.
- Si prefieren que no usemos el escudo, ponemos uno inventado con los colores del club.
- Si quieren, les mostramos cómo queda el club antes de publicarlo.

Si les parece bien, ¿nos podrían mandar el escudo en buena calidad y confirmarnos los colores de las camisetas de este año? También nos sirve cualquier foto de la cancha para armarla en 3D.

¡Muchas gracias y aguante [apodo del club]!

[tu nombre]
[tu contacto]

---

## Qué anotar cuando respondan

En `docs/permisos.csv`: `fecha_respuesta`, `estado` (`aprobado` o `rechazado`), un resumen en `respuesta` y cualquier condición en `notas` (por ejemplo, "sólo escudo, no camiseta").
