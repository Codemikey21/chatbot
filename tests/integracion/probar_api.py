"""Prueba de extremo a extremo por la API, como lo hará la app.

App → API (login con la contraseña DEMO) → pantallas con datos de Supabase
→ chat por n8n → conversación guardada en la memoria.

Uso (desde la raíz del repositorio, con docker compose levantado):
    mcp-server\\.venv\\Scripts\\python.exe tests\\integracion\\probar_api.py
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request

API = os.getenv("API_URL", "http://localhost:8080/api/v1")
CODIGO, CONTRASENA = "U00900100", "Demo2026*"


def llamar(metodo: str, ruta: str, cuerpo: dict | None = None, token: str | None = None) -> tuple[int, dict]:
    datos = json.dumps(cuerpo).encode("utf-8") if cuerpo is not None else None
    cabeceras = {"Content-Type": "application/json"}
    if token:
        cabeceras["Authorization"] = f"Bearer {token}"
    peticion = urllib.request.Request(API + ruta, data=datos, method=metodo, headers=cabeceras)
    try:
        with urllib.request.urlopen(peticion, timeout=120) as r:
            texto = r.read().decode("utf-8")
            return r.status, json.loads(texto) if texto else {}
    except urllib.error.HTTPError as e:
        texto = e.read().decode("utf-8", "replace")
        try:
            return e.code, json.loads(texto)
        except json.JSONDecodeError:
            return e.code, {"detail": texto[:200]}


def main() -> int:
    resultados = []

    def revisar(nombre: str, ok: bool, detalle: str = "") -> None:
        resultados.append(ok)
        print(f"{'OK ' if ok else 'XX '} {nombre:<26} {detalle}")

    estado, datos = llamar("POST", "/auth/login", {"codigo": CODIGO, "contrasena": "incorrecta"})
    revisar("login_incorrecto", estado == 401, f"HTTP {estado}")

    estado, datos = llamar("POST", "/auth/login", {"codigo": CODIGO, "contrasena": CONTRASENA})
    revisar("login", estado == 200 and "token" in datos, f"HTTP {estado} {datos.get('estudiante', {}).get('nombres', '')}")
    if estado != 200:
        print("\nSin login no se pueden probar las demás rutas.")
        return 1
    token = datos["token"]

    estado, datos = llamar("GET", "/estudiante/resumen", token=token)
    insignia = datos.get("insignia", {})
    revisar("resumen", estado == 200, f"pilares {insignia.get('pilares_aprobados')}/{insignia.get('pilares_totales')}, "
                                      f"avance {datos.get('plan_de_estudios', {}).get('porcentaje_avance')} %")

    for ruta, clave in [("/estudiante/historial", "cursos"), ("/estudiante/recomendaciones", "recomendaciones"),
                        ("/cursos", "pilares"), ("/calendario", "eventos"), ("/noticias", "noticias")]:
        estado, datos = llamar("GET", ruta, token=token)
        revisar(ruta.strip("/").replace("/", "_"), estado == 200 and isinstance(datos.get(clave), list),
                f"HTTP {estado}, {len(datos.get(clave, []))} {clave}")

    inicio = time.perf_counter()
    estado, datos = llamar("POST", "/chat", {"mensaje": "¿Cuándo son las inscripciones a los cursos de competencias digitales?"}, token)
    revisar("chat", estado == 200 and bool(datos.get("respuesta")),
            f"HTTP {estado} en {time.perf_counter() - inicio:.1f}s, herramientas={datos.get('herramientas')}")
    sesion = datos.get("sesion_id")

    estado, datos = llamar("POST", "/chat", {"mensaje": "¿Y cuándo es la prueba diagnóstica?", "sesion_id": sesion}, token)
    revisar("chat_misma_sesion", estado == 200 and datos.get("sesion_id") == sesion, f"HTTP {estado}")

    estado, datos = llamar("GET", f"/chat/sesiones/{sesion}/mensajes", token=token)
    revisar("memoria_guardada", estado == 200 and len(datos.get("mensajes", [])) == 4,
            f"{len(datos.get('mensajes', []))} mensajes en la sesión")

    estado, _ = llamar("GET", "/estudiante/resumen")
    revisar("sin_token", estado == 401, f"HTTP {estado}")

    print(f"\n{sum(resultados)}/{len(resultados)} pruebas aprobadas")
    return 0 if all(resultados) else 1


if __name__ == "__main__":
    sys.exit(main())
