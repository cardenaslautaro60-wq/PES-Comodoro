#!/usr/bin/env python3
"""Genera planteles con nombres inventados para cada club de datos/clubes/.

Los jugadores de la liga son personas reales de una liga amateur, así que el
juego NO usa sus nombres (regla 3 del plan). Este script arma nombres
combinando nombres y apellidos comunes, al azar pero con semilla fija por club,
así el resultado es siempre el mismo.

Uso:
    python3 herramientas/generar_planteles.py            # crea los que faltan
    python3 herramientas/generar_planteles.py --forzar   # pisa los existentes

Después de generar, los archivos se pueden editar a mano.
"""
import json
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLUBS = ROOT / "datos" / "clubes"
OUT = ROOT / "datos" / "planteles"

NOMBRES = [
    "Agustín", "Alan", "Axel", "Benjamín", "Brian", "Bruno", "Cristian", "Damián", "Dante", "Elías",
    "Emanuel", "Enzo", "Ezequiel", "Facundo", "Federico", "Franco", "Gastón", "Gonzalo", "Ignacio",
    "Iván", "Joaquín", "Julián", "Kevin", "Lautaro", "Leandro", "Lisandro", "Lucas", "Luciano",
    "Marcos", "Matías", "Maximiliano", "Milton", "Nahuel", "Nicolás", "Thiago", "Pablo", "Ramiro",
    "Rodrigo", "Santiago", "Sergio", "Tobías", "Tomás", "Valentín", "Walter", "Yamil",
]
APELLIDOS = [
    "Aballay", "Acuña", "Aguirre", "Alvarado", "Antilef", "Arce", "Bahamonde", "Barría", "Benítez",
    "Cárcamo", "Catrilaf", "Cayún", "Correa", "Coñuecar", "Delgado", "Escobar", "Ferreyra", "Gallardo",
    "Gatica", "Huenchul", "Ibáñez", "Jaramillo", "Llancaqueo", "Maldonado", "Mansilla", "Millapi",
    "Montiel", "Nahuelquir", "Navarro", "Ojeda", "Oyarzo", "Paillacán", "Peralta", "Quintana",
    "Ríos", "Saldivia", "Soto", "Tapia", "Toledo", "Uribe", "Vargas", "Vidal", "Villarroel", "Zúñiga",
]
APODOS = ["el Pingüino", "el Ruso", "el Chino", "el Flaco", "el Tano", "el Turco", "el Gringo",
          "el Petiso", "Chenque", "el Ventarrón", "el Mono", "el Colo"]

# Formación base 4-4-2 + suplentes: (posición, cantidad)
PLANTILLA = [("ARQ", 2), ("DFC", 4), ("LAT", 3), ("MC", 4), ("MP", 2), ("EXT", 2), ("DC", 3)]

# Perfil de atributos por posición: (velocidad, pase, tiro, defensa, estamina) en relación a la base.
PERFIL = {
    "ARQ": (-10, -5, -25, 10, -5),
    "DFC": (-5, -5, -15, 12, 3),
    "LAT": (6, 0, -10, 6, 8),
    "MC": (0, 8, -2, 3, 8),
    "MP": (2, 10, 6, -8, 3),
    "EXT": (10, 3, 3, -8, 5),
    "DC": (5, -3, 12, -15, 0),
}
ATRIBUTOS = ("velocidad", "pase", "tiro", "defensa", "estamina")
DORSALES = {"ARQ": [1, 12], "DFC": [2, 6, 13, 14], "LAT": [3, 4, 15], "MC": [5, 8, 16, 18],
            "MP": [10, 20], "EXT": [7, 11], "DC": [9, 19, 17]}


def clamp(v):
    return max(30, min(95, v))


def generar(club):
    rng = random.Random(club["id"])
    base = 45 + club.get("nivel", 3) * 5  # nivel 1..5 -> base 50..70
    usados = set()
    jugadores = []
    for pos, cant in PLANTILLA:
        for i in range(cant):
            while True:
                nombre = f"{rng.choice(NOMBRES)} {rng.choice(APELLIDOS)}"
                if nombre not in usados:
                    usados.add(nombre)
                    break
            titular = i < {"ARQ": 1, "DFC": 2, "LAT": 2, "MC": 2, "MP": 1, "EXT": 1, "DC": 2}[pos]
            bonus = 4 if titular else -3
            attrs = {a: clamp(base + d + bonus + rng.randint(-7, 7)) for a, d in zip(ATRIBUTOS, PERFIL[pos])}
            if pos == "ARQ":
                attrs["atajada"] = clamp(base + bonus + 8 + rng.randint(-6, 6))
            jugadores.append({
                "id": f"{club['id']}_{len(jugadores) + 1:02d}",
                "nombre": nombre,
                "apodo": rng.choice(APODOS) if rng.random() < 0.15 else None,
                "dorsal": DORSALES[pos][i],
                "posicion": pos,
                "titular": titular,
                "pie": rng.choices(["derecho", "izquierdo", "ambos"], [70, 25, 5])[0],
                "edad": rng.randint(18, 36),
                "altura_cm": rng.randint(186, 194) if pos == "ARQ" else rng.randint(165, 190),
                "atributos": attrs,
                "apariencia": {
                    "piel": rng.randint(0, 3),
                    "pelo": rng.randint(0, 5),
                    "color_pelo": rng.randint(0, 3),
                    "barba": rng.random() < 0.35,
                },
            })
    return {
        "formato_version": 1,
        "club_id": club["id"],
        "aviso": "Nombres inventados. Cualquier parecido con jugadores reales es casualidad.",
        "formacion": "4-4-2",
        "jugadores": jugadores,
    }


def main():
    forzar = "--forzar" in sys.argv
    OUT.mkdir(parents=True, exist_ok=True)
    for path in sorted(CLUBS.glob("*.json")):
        club = json.loads(path.read_text(encoding="utf-8"))
        dest = OUT / path.name
        if dest.exists() and not forzar:
            continue
        dest.write_text(json.dumps(generar(club), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("plantel generado:", dest.relative_to(ROOT))


if __name__ == "__main__":
    main()
