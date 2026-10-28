#!/usr/bin/env python3
"""Revisa que los archivos de datos/ estén completos y bien enlazados.

Uso: python3 herramientas/validar_datos.py   (sale con código 1 si hay errores)
Sólo usa la librería estándar, así corre en GitHub Actions sin instalar nada.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "datos"
HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")
PATRONES = {"liso", "rayas_verticales", "bandas_horizontales", "mitades", "banda_diagonal", "v_frontal", "banda_pecho"}
CONFIANZA = {"confirmado", "probable", "propuesta"}
PERMISOS = {"sin_pedir", "pedido", "aprobado", "rechazado"}
POSICIONES = {"ARQ", "DFC", "LAT", "MC", "MP", "EXT", "DC"}
ATRIBUTOS = ("velocidad", "pase", "tiro", "defensa", "estamina")
SUPERFICIES = {"natural", "sintetico", "tierra", "a_confirmar"}

errores = []


def err(archivo, msg):
    errores.append(f"{archivo.relative_to(ROOT)}: {msg}")


def cargar(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        err(path, f"JSON inválido ({e})")
        return None


def requerir(path, obj, campos):
    for c in campos:
        if c not in obj:
            err(path, f"falta el campo '{c}'")


def validar_camiseta(path, nombre, k):
    requerir(path, k, ["patron", "color_base", "pantalon", "medias", "confianza"])
    if k.get("patron") not in PATRONES:
        err(path, f"camiseta {nombre}: patrón '{k.get('patron')}' no es uno de {sorted(PATRONES)}")
    if k.get("confianza") not in CONFIANZA:
        err(path, f"camiseta {nombre}: confianza inválida")
    for campo in ("color_base", "color_secundario", "color_terciario", "hombreras", "cuello", "numero", "pantalon", "medias"):
        v = k.get(campo)
        if v is not None and not HEX.match(v):
            err(path, f"camiseta {nombre}: '{campo}' no es un color #RRGGBB")


estadios = {}
for path in sorted((DATA / "estadios").glob("*.json")):
    e = cargar(path)
    if e is None:
        continue
    requerir(path, e, ["formato_version", "id", "nombre", "capacidad", "superficie", "dimensiones_m", "tribunas"])
    if e.get("id") != path.stem:
        err(path, "el 'id' tiene que ser igual al nombre del archivo")
    if e.get("superficie") not in SUPERFICIES:
        err(path, f"superficie inválida '{e.get('superficie')}'")
    estadios[e.get("id")] = e

clubes = {}
for path in sorted((DATA / "clubes").glob("*.json")):
    c = cargar(path)
    if c is None:
        continue
    requerir(path, c, ["formato_version", "id", "nombre_oficial", "nombre_corto", "abreviatura", "colores",
                       "camisetas", "escudo", "estadio_id", "nivel"])
    if c.get("id") != path.stem:
        err(path, "el 'id' tiene que ser igual al nombre del archivo")
    if len(c.get("abreviatura", "")) != 3:
        err(path, "la abreviatura tiene que tener 3 letras (se usa en el marcador)")
    for col in c.get("colores", []):
        if not HEX.match(col):
            err(path, f"color '{col}' no es #RRGGBB")
    for nombre in ("titular", "suplente", "arquero"):
        if nombre not in c.get("camisetas", {}):
            err(path, f"falta la camiseta '{nombre}'")
        else:
            validar_camiseta(path, nombre, c["camisetas"][nombre])
    if c.get("escudo", {}).get("permiso") not in PERMISOS:
        err(path, f"escudo.permiso tiene que ser uno de {sorted(PERMISOS)}")
    if c.get("estadio_id") not in estadios:
        err(path, f"estadio_id '{c.get('estadio_id')}' no existe en datos/estadios/")
    if not 1 <= c.get("nivel", 0) <= 5:
        err(path, "nivel tiene que ir de 1 a 5")
    clubes[c.get("id")] = c

for path in sorted((DATA / "planteles").glob("*.json")):
    p = cargar(path)
    if p is None:
        continue
    if p.get("club_id") not in clubes:
        err(path, f"club_id '{p.get('club_id')}' no existe en datos/clubes/")
    jug = p.get("jugadores", [])
    titulares = [j for j in jug if j.get("titular")]
    if len(titulares) != 11:
        err(path, f"tiene {len(titulares)} titulares, tienen que ser 11")
    if not any(j.get("posicion") == "ARQ" and j.get("titular") for j in jug):
        err(path, "no hay arquero titular")
    dorsales = [j.get("dorsal") for j in jug]
    if len(dorsales) != len(set(dorsales)):
        err(path, "hay dorsales repetidos")
    for j in jug:
        if j.get("posicion") not in POSICIONES:
            err(path, f"{j.get('id')}: posición inválida")
        for a in ATRIBUTOS:
            v = j.get("atributos", {}).get(a)
            if not isinstance(v, int) or not 1 <= v <= 99:
                err(path, f"{j.get('id')}: atributo '{a}' tiene que ser un entero de 1 a 99")

for cid in clubes:
    if not (DATA / "planteles" / f"{cid}.json").exists():
        err(DATA / "clubes" / f"{cid}.json", "no tiene plantel en datos/planteles/")

if errores:
    print("\n".join(errores))
    print(f"\n{len(errores)} error(es)")
    sys.exit(1)
print(f"OK: {len(clubes)} clubes, {len(estadios)} estadios, planteles completos.")
