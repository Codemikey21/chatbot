"""Evalúa la recuperación del RAG con un conjunto de preguntas de prueba.

Para cada pregunta genera el embedding con Voyage AI, ejecuta la búsqueda
híbrida (fn_buscar_fragmentos) y compara los documentos recuperados con los
esperados. Las preguntas fuera de alcance deben quedar sin resultados.

Uso (desde la raíz del repositorio, con el entorno del servidor MCP):
    mcp-server\\.venv\\Scripts\\python.exe rag\\evaluacion\\evaluar.py
    mcp-server\\.venv\\Scripts\\python.exe rag\\evaluacion\\evaluar.py --umbral 0.40

Métricas:
    acierto@5   la pregunta recupera al menos un documento esperado entre los 5 primeros
    MRR         promedio de 1/posición del primer documento esperado
    rechazo     preguntas fuera de alcance que no recuperan nada (evita alucinaciones)
"""

import argparse
import csv
import json
import os
import urllib.request
from pathlib import Path

import psycopg
from dotenv import find_dotenv, load_dotenv

load_dotenv(find_dotenv(usecwd=True))

CARPETA = Path(__file__).parent
K = 5


def embeddings(textos: list[str]) -> list[list[float]]:
    cuerpo = json.dumps({"input": textos, "model": "voyage-4", "input_type": "query"}).encode()
    peticion = urllib.request.Request(
        "https://api.voyageai.com/v1/embeddings",
        data=cuerpo,
        headers={
            "Authorization": f"Bearer {os.environ['VOYAGE_API_KEY']}",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(peticion, timeout=60) as respuesta:
        datos = json.load(respuesta)["data"]
    return [d["embedding"] for d in sorted(datos, key=lambda d: d["index"])]


def conectar() -> psycopg.Connection:
    return psycopg.connect(
        host=os.environ["SUPABASE_DB_HOST"],
        port=os.getenv("SUPABASE_DB_PORT", "5432"),
        dbname=os.getenv("SUPABASE_DB_NAME", "postgres"),
        user=os.environ["DB_API_USER"],
        password=os.environ["DB_API_PASSWORD"],
        sslmode=os.getenv("SUPABASE_DB_SSLMODE", "require"),
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--umbral", type=float, default=0.35, help="Similitud mínima (0 a 1)")
    args = parser.parse_args()

    with open(CARPETA / "preguntas.csv", encoding="utf-8") as archivo:
        preguntas = list(csv.DictReader(archivo))

    vectores = embeddings([p["pregunta"] for p in preguntas])
    resultados = []

    with conectar() as conexion, conexion.cursor() as cursor:
        for pregunta, vector in zip(preguntas, vectores):
            cursor.execute(
                "select nombre_archivo, similitud from fn_buscar_fragmentos(%s::vector, %s, %s, %s)",
                (str(vector), pregunta["pregunta"], K, args.umbral),
            )
            filas = cursor.fetchall()
            esperados = {d for d in pregunta["documentos_esperados"].split("|") if d}
            recuperados = [f[0] for f in filas]
            similitud_max = float(filas[0][1]) if filas else 0.0

            if esperados:
                posiciones = [i for i, d in enumerate(recuperados) if d in esperados]
                acierto = bool(posiciones)
                rr = 1 / (posiciones[0] + 1) if posiciones else 0.0
            else:
                acierto = not filas
                rr = None

            resultados.append({
                "pregunta": pregunta["pregunta"],
                "tipo": pregunta["tipo"],
                "acierto": acierto,
                "rango_reciproco": rr,
                "similitud_maxima": round(similitud_max, 4),
                "documentos_recuperados": "|".join(dict.fromkeys(recuperados)),
            })

    en_alcance = [r for r in resultados if r["tipo"] != "fuera_de_alcance"]
    fuera = [r for r in resultados if r["tipo"] == "fuera_de_alcance"]
    acierto_k = sum(r["acierto"] for r in en_alcance) / len(en_alcance)
    mrr = sum(r["rango_reciproco"] for r in en_alcance) / len(en_alcance)
    rechazo = sum(r["acierto"] for r in fuera) / len(fuera) if fuera else 1.0

    for r in resultados:
        marca = "OK " if r["acierto"] else "XX "
        print(f"{marca} [{r['similitud_maxima']:.3f}] {r['pregunta']}")
    print()
    print(f"Umbral de similitud: {args.umbral}")
    print(f"acierto@{K}: {acierto_k:.0%}  |  MRR: {mrr:.2f}  |  rechazo fuera de alcance: {rechazo:.0%}")

    with open(CARPETA / "resultados.csv", "w", encoding="utf-8", newline="") as archivo:
        escritor = csv.DictWriter(archivo, fieldnames=list(resultados[0].keys()))
        escritor.writeheader()
        escritor.writerows(resultados)
    print(f"Detalle guardado en {CARPETA / 'resultados.csv'}")


if __name__ == "__main__":
    main()
