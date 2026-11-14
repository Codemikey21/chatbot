import httpx
import respx

FEED = "https://unab.edu.co/feed/"
ROBOTS_UNAB = "https://unab.edu.co/robots.txt"
DEMO = "http://scraper:8000/demo/boletin-ccd.html"


def fuente_rss(**extra):
    return {"fuente_id": 1, "nombre": "UNAB - Noticias", "url": FEED, "tipo": "rss",
            "configuracion": {"palabras_clave": ["estudiantes", "diplomado"],
                              "categorias_excluidas": ["Gestión Humana"]}, **extra}


def test_salud(cliente):
    assert cliente.get("/health").json() == {"servicio": "scraper", "estado": "ok"}


def test_extraer_sin_token(cliente):
    assert cliente.post("/extraer", json=fuente_rss()).status_code == 401
    malo = {"Authorization": "Bearer otro"}
    assert cliente.post("/extraer", json=fuente_rss(), headers=malo).status_code == 401


@respx.mock
def test_extraer_rss(cliente, cabeceras, feed):
    respx.get(ROBOTS_UNAB).mock(return_value=httpx.Response(200, text="User-agent: *\nDisallow: /wp-admin/\n"))
    respx.get(FEED).mock(return_value=httpx.Response(200, text=feed))

    datos = cliente.post("/extraer", json=fuente_rss(), headers=cabeceras).json()

    assert datos["permitido_robots"] is True and datos["error"] is None
    urls = [n["url"] for n in datos["noticias"]]
    # Sin rastreo, sin duplicados, sin la noticia deportiva (no tiene palabras clave)
    # y sin la de Gestión Humana (categoría excluida)
    assert urls == [
        "https://unab.edu.co/noticias/becas-2027/",
        "https://unab.edu.co/noticias/diplomado-analitica/",
        "https://unab.edu.co/noticias/taller-programacion/",
    ]
    assert [n["categoria"] for n in datos["noticias"]] == ["convocatoria", "curso", "curso"]
    assert datos["noticias"][0]["resumen"] == "Los estudiantes pueden postularse hasta el 30 de noviembre."
    assert datos["noticias"][2]["resumen"].endswith("todas las facultades…")
    assert datos["noticias"][2]["fecha_publicacion"] == "2026-11-12"


@respx.mock
def test_robots_no_permite(cliente, cabeceras):
    respx.get(ROBOTS_UNAB).mock(return_value=httpx.Response(200, text="User-agent: *\nDisallow: /\n"))
    ruta_feed = respx.get(FEED).mock(return_value=httpx.Response(200, text=""))

    datos = cliente.post("/extraer", json=fuente_rss(), headers=cabeceras).json()

    assert datos["permitido_robots"] is False
    assert datos["noticias"] == [] and "robots.txt" in datos["error"]
    assert not ruta_feed.called


@respx.mock
def test_robots_inaccesible(cliente, cabeceras):
    respx.get(ROBOTS_UNAB).mock(side_effect=httpx.ConnectError("sin red"))
    ruta_feed = respx.get(FEED).mock(return_value=httpx.Response(200, text=""))

    datos = cliente.post("/extraer", json=fuente_rss(), headers=cabeceras).json()

    assert datos["permitido_robots"] is False
    assert "No se pudo leer el robots.txt" in datos["error"]
    assert not ruta_feed.called


@respx.mock
def test_dominio_fuera_de_la_lista(cliente, cabeceras):
    ruta = respx.get(url__regex=r".*").mock(return_value=httpx.Response(200, text=""))
    fuente = fuente_rss(url="https://ejemplo.com/feed/")

    datos = cliente.post("/extraer", json=fuente, headers=cabeceras).json()

    assert datos["noticias"] == [] and "dominios permitidos" in datos["error"]
    assert not ruta.called


@respx.mock
def test_fuente_caida(cliente, cabeceras):
    respx.get(ROBOTS_UNAB).mock(return_value=httpx.Response(404))
    respx.get(FEED).mock(return_value=httpx.Response(500))

    datos = cliente.post("/extraer", json=fuente_rss(), headers=cabeceras).json()

    assert datos["permitido_robots"] is True
    assert datos["noticias"] == [] and "No se pudo descargar" in datos["error"]


@respx.mock
def test_boletin_demo_html(cliente, cabeceras, demo_html):
    robots_propio = cliente.get("/robots.txt").text
    respx.get("http://scraper:8000/robots.txt").mock(return_value=httpx.Response(200, text=robots_propio))
    respx.get(DEMO).mock(return_value=httpx.Response(200, text=demo_html))
    fuente = {
        "fuente_id": 2, "nombre": "Boletín CCD (DEMO)", "url": DEMO, "tipo": "html",
        "configuracion": {
            "selector_item": "article.novedad", "selector_titulo": ".novedad-titulo",
            "selector_enlace": ".novedad-titulo a", "selector_resumen": ".novedad-resumen",
            "selector_fecha": "time", "conservar_fragmento": True,
        },
    }

    datos = cliente.post("/extraer", json=fuente, headers=cabeceras).json()

    assert datos["error"] is None and datos["total"] == 6
    categorias = [n["categoria"] for n in datos["noticias"]]
    assert categorias == ["convocatoria", "curso", "certificacion", "noticia", "curso", "convocatoria"]
    assert datos["noticias"][0]["url"] == DEMO + "#ccd-convocatoria-2027-1"
    assert datos["noticias"][0]["fecha_publicacion"] == "2026-11-13"


def test_pagina_demo_se_sirve(cliente):
    respuesta = cliente.get("/demo/boletin-ccd.html")
    assert respuesta.status_code == 200
    assert "DOCUMENTO DEMOSTRATIVO" in respuesta.text
