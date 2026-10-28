#!/usr/bin/env python3
"""Genera los sonidos del juego por síntesis, sin grabaciones de nadie.

Uso: python3 herramientas/generar_sonidos.py

Crea archivos .wav en audio/efectos y audio/ambiente. Todo sale de fórmulas
(senos, ruido y filtros), así que los sonidos son propios del proyecto y no
tienen problemas de derechos. Sólo usa la librería estándar de Python.
Si cambiás algo, corré el script de nuevo y subí los .wav nuevos.
"""
import math
import random
import struct
import wave
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SR = 22050  # muestras por segundo: alcanza para todo y pesa la mitad que 44100
TAU = math.tau

azar = random.Random(2026)


# --- Utilidades ---------------------------------------------------------------


def escribir(ruta_relativa, muestras, pico=0.9):
    """Normaliza al pico pedido y guarda en WAV mono de 16 bits."""
    maximo = max(1e-9, max(abs(m) for m in muestras))
    escala = pico / maximo
    ruta = RAIZ / ruta_relativa
    ruta.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(ruta), "wb") as archivo:
        archivo.setnchannels(1)
        archivo.setsampwidth(2)
        archivo.setframerate(SR)
        datos = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, m * escala)) * 32767)) for m in muestras)
        archivo.writeframes(datos)
    print(f"  {ruta_relativa}  ({len(muestras) / SR:.2f} s)")


def silencio(segundos):
    return [0.0] * int(segundos * SR)


def mezclar(destino, fuente, desde=0, ganancia=1.0, envolver=False):
    """Suma `fuente` dentro de `destino` a partir de la muestra `desde`.
    Con `envolver`, lo que sobra al final vuelve al principio (para loops)."""
    n = len(destino)
    for i, m in enumerate(fuente):
        j = desde + i
        if j >= n:
            if not envolver:
                break
            j %= n
        destino[j] += m * ganancia


def ruido_blanco(n):
    return [azar.uniform(-1.0, 1.0) for _ in range(n)]


def ruido_rosa(n):
    """Ruido rosa (método de Paul Kellet): suena más natural que el blanco."""
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0
    salida = []
    for _ in range(n):
        w = azar.uniform(-1.0, 1.0)
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        salida.append((b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11)
        b6 = w * 0.115926
    return salida


def pasa_bajos(muestras, corte):
    a = 1.0 - math.exp(-TAU * corte / SR)
    y = 0.0
    salida = []
    for x in muestras:
        y += a * (x - y)
        salida.append(y)
    return salida


def pasa_altos(muestras, corte):
    bajos = pasa_bajos(muestras, corte)
    return [x - b for x, b in zip(muestras, bajos)]


def pasa_banda(muestras, centro, q):
    """Filtro pasa banda (biquad de Robert Bristow-Johnson)."""
    w0 = TAU * centro / SR
    alfa = math.sin(w0) / (2 * q)
    b0, b1, b2 = alfa, 0.0, -alfa
    a0, a1, a2 = 1 + alfa, -2 * math.cos(w0), 1 - alfa
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    x1 = x2 = y1 = y2 = 0.0
    salida = []
    for x in muestras:
        y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x, y1, y
        salida.append(y)
    return salida


def curva_suave(n, cambios_por_segundo, minimo, maximo):
    """Valores que suben y bajan despacio, para que el sonido no sea plano."""
    puntos = int(n / SR * cambios_por_segundo) + 2
    valores = [azar.uniform(minimo, maximo) for _ in range(puntos)]
    salida = []
    for i in range(n):
        t = i / n * (puntos - 1)
        k = int(t)
        f = t - k
        f = f * f * (3 - 2 * f)
        salida.append(valores[k] * (1 - f) + valores[min(k + 1, puntos - 1)] * f)
    return salida


def cerrar_loop(muestras, segundos_cruce):
    """Funde el final con el principio para que el loop no tenga salto."""
    cruce = int(segundos_cruce * SR)
    cuerpo = muestras[:-cruce]
    for i in range(cruce):
        f = i / cruce
        cuerpo[i] = cuerpo[i] * f + muestras[len(muestras) - cruce + i] * (1 - f)
    return cuerpo


# --- Pelota -------------------------------------------------------------------


def golpe(duracion, tono_inicio, tono_fin, caida, chasquido):
    n = int(duracion * SR)
    fase = 0.0
    salida = []
    clic = pasa_bajos(ruido_blanco(n), 3500)
    for i in range(n):
        t = i / SR
        f = tono_fin + (tono_inicio - tono_fin) * math.exp(-t / 0.03)
        fase += TAU * f / SR
        cuerpo = math.sin(fase) * math.exp(-t / caida)
        golpecito = clic[i] * math.exp(-t / 0.004) * chasquido
        salida.append(cuerpo + golpecito)
    return salida


def poste():
    n = int(0.9 * SR)
    parciales = [(523, 0.55, 1.0), (1371, 0.38, 0.6), (2489, 0.26, 0.45), (3702, 0.18, 0.3), (5110, 0.12, 0.2)]
    clic = ruido_blanco(n)
    salida = []
    for i in range(n):
        t = i / SR
        m = sum(a * math.sin(TAU * f * t) * math.exp(-t / c) for f, c, a in parciales)
        m += clic[i] * math.exp(-t / 0.003) * 0.8
        salida.append(m)
    return salida


# --- Silbato del árbitro --------------------------------------------------------


def silbato(duracion):
    """Silbato con bolita: un tono agudo que tiembla rápido."""
    n = int(duracion * SR)
    aire = pasa_altos(ruido_blanco(n), 2000)
    fase = 0.0
    temblor = azar.uniform(26, 32)
    salida = []
    for i in range(n):
        t = i / SR
        f = 2950 + 170 * math.sin(TAU * temblor * t) + 40 * math.sin(TAU * 5 * t)
        fase += TAU * f / SR
        subida = min(1.0, t / 0.015)
        bajada = min(1.0, (duracion - t) / 0.06)
        env = subida * bajada * (0.85 + 0.15 * math.sin(TAU * temblor * t + 1.0))
        salida.append((math.sin(fase) + 0.22 * math.sin(2 * fase) + aire[i] * 0.12) * env)
    return salida


def silbato_final():
    salida = []
    for parte in (silbato(0.32), silencio(0.16), silbato(0.32), silencio(0.16), silbato(1.1)):
        salida += parte
    return salida


# --- Hinchada -----------------------------------------------------------------


def voces(n, cantidad, tono_min, tono_max, largo_min, largo_max, envolver):
    """Muchas voces gritando "aaa" y "eee" a la vez, con tonos y largos al azar."""
    mezcla = [0.0] * n
    for _ in range(cantidad):
        largo = int(azar.uniform(largo_min, largo_max) * SR)
        f0 = azar.uniform(tono_min, tono_max)
        vibrato = azar.uniform(4, 7)
        inicio = azar.randrange(n)
        fase = 0.0
        voz = []
        for i in range(largo):
            t = i / SR
            f = f0 * (1 + 0.02 * math.sin(TAU * vibrato * t)) * (1 + 0.06 * t)
            fase += f / SR
            diente = 2 * (fase % 1.0) - 1
            env = math.sin(math.pi * i / largo) ** 1.5
            voz.append(diente * env)
        mezcla_ganancia = azar.uniform(0.3, 1.0)
        mezclar(mezcla, voz, inicio, mezcla_ganancia, envolver)
    # Formantes de una "a" abierta, como el grito de tribuna.
    return [a + b * 0.7 for a, b in zip(pasa_banda(mezcla, 750, 2.0), pasa_banda(mezcla, 1250, 2.5))]


def murmullo(n):
    rosa = ruido_rosa(n)
    banda = pasa_altos(pasa_bajos(rosa, 2400), 220)
    respiracion = curva_suave(n, 0.6, 0.65, 1.0)
    return [b * r for b, r in zip(banda, respiracion)]


def hinchada():
    """Loop de ambiente: murmullo de tribuna con gritos sueltos (8 s)."""
    total = int(8.5 * SR)
    base = murmullo(total)
    gritos = voces(total, 70, 150, 330, 0.3, 1.2, envolver=True)
    mezcla = [b * 1.0 + g * 0.35 for b, g in zip(base, gritos)]
    return cerrar_loop(mezcla, 0.5)


def grito_gol():
    """La tribuna explota con el gol: sube rápido, se sostiene y se apaga."""
    n = int(4.5 * SR)
    base = murmullo(n)
    brillo = pasa_altos(ruido_rosa(n), 900)
    gritos = voces(n, 160, 180, 420, 1.5, 3.5, envolver=False)
    salida = []
    for i in range(n):
        t = i / SR
        env = min(1.0, t / 0.35) * (1.0 if t < 2.2 else math.exp(-(t - 2.2) / 1.0))
        salida.append((base[i] * 0.8 + brillo[i] * 0.5 + gritos[i] * 0.9) * env)
    return salida


# --- Bombos y platillos ---------------------------------------------------------


def bombo():
    n = int(0.45 * SR)
    piel = pasa_bajos(ruido_blanco(n), 900)
    fase = 0.0
    salida = []
    for i in range(n):
        t = i / SR
        f = 48 + 40 * math.exp(-t / 0.04)
        fase += TAU * f / SR
        salida.append(math.sin(fase) * math.exp(-t / 0.18) + piel[i] * math.exp(-t / 0.02) * 0.4)
    return salida


def platillo():
    n = int(0.5 * SR)
    chapa = pasa_altos(ruido_blanco(n), 5000)
    return [c * math.exp(-(i / SR) / 0.12) for i, c in enumerate(chapa)]


def redoblante(fuerza):
    n = int(0.2 * SR)
    bordona = pasa_banda(ruido_blanco(n), 2500, 0.8)
    salida = []
    for i in range(n):
        t = i / SR
        tono = math.sin(TAU * 190 * t) * math.exp(-t / 0.03)
        salida.append((bordona[i] * 2.0 * math.exp(-t / 0.07) + tono * 0.5) * fuerza)
    return salida


def bombos():
    """Dos compases de murga de tribuna a 104 pulsos por minuto, en loop."""
    pulsos = 104
    octavo = int(SR * 60 / pulsos / 2)
    total = octavo * 16
    salida = [0.0] * total
    golpe_bombo = bombo()
    golpe_platillo = platillo()
    for compas in range(2):
        base = compas * 8 * octavo
        for paso in (0, 3, 4, 6):
            mezclar(salida, golpe_bombo, base + paso * octavo, 1.0, envolver=True)
        for paso in (0, 2, 4, 6):
            mezclar(salida, golpe_platillo, base + paso * octavo, 0.35, envolver=True)
        for paso in range(8):
            fuerza = 0.8 if paso in (2, 6) else 0.25
            mezclar(salida, redoblante(fuerza), base + paso * octavo, 0.5, envolver=True)
    return salida


# --- Interfaz -----------------------------------------------------------------


def bip(tono_inicio, tono_fin, duracion):
    n = int(duracion * SR)
    fase = 0.0
    salida = []
    for i in range(n):
        t = i / SR
        f = tono_inicio + (tono_fin - tono_inicio) * (i / n)
        fase += TAU * f / SR
        env = min(1.0, t / 0.004) * math.exp(-t / (duracion * 0.4))
        salida.append((math.sin(fase) + 0.25 * math.sin(3 * fase)) * env)
    return salida


def main():
    print("Generando sonidos:")
    escribir("audio/efectos/patada.wav", golpe(0.22, 150, 55, 0.05, 0.9))
    escribir("audio/efectos/pase.wav", golpe(0.15, 210, 90, 0.035, 0.5), pico=0.6)
    escribir("audio/efectos/poste.wav", poste(), pico=0.75)
    escribir("audio/efectos/silbato_corto.wav", silbato(0.35), pico=0.7)
    escribir("audio/efectos/silbato_largo.wav", silbato(1.1), pico=0.7)
    escribir("audio/efectos/silbato_final.wav", silbato_final(), pico=0.7)
    escribir("audio/efectos/grito_gol.wav", grito_gol())
    escribir("audio/efectos/ui_tocar.wav", bip(900, 1300, 0.06), pico=0.45)
    escribir("audio/efectos/ui_volver.wav", bip(700, 450, 0.08), pico=0.45)
    escribir("audio/ambiente/hinchada.wav", hinchada(), pico=0.7)
    escribir("audio/ambiente/bombos.wav", bombos(), pico=0.8)


if __name__ == "__main__":
    main()
