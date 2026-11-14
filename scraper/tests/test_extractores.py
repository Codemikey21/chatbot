from datetime import date

import pytest

from app.extractores import dominio_permitido, extraer_html, extraer_rss

CONFIG_DEMO = {
    "selector_item": "article.novedad",
    "selector_titulo": ".novedad-titulo",
    "selector_enlace": ".novedad-titulo a",
    "selector_resumen": ".novedad-resumen",
    "selector_fecha": "time",
}


def test_extraer_rss(feed):
    entradas = extraer_rss(feed)
    assert len(entradas) == 6
    assert entradas[0]["titulo"].startswith("Abierta la convocatoria")
    assert entradas[0]["fecha"] == date(2026, 11, 11)
    assert entradas[0]["categorias"] == ["Estudiantes"]
    assert "<p>" in entradas[0]["resumen"]


def test_extraer_rss_fecha_en_hora_de_bogota(feed):
    # 13 nov 00:29 UTC es 12 nov 19:29 en Bogotá
    taller = extraer_rss(feed)[-1]
    assert taller["fecha"] == date(2026, 11, 12)


def test_extraer_html_boletin_demo(demo_html):
    entradas = extraer_html(demo_html, CONFIG_DEMO)
    assert len(entradas) == 6
    assert entradas[0]["url"] == "#ccd-convocatoria-2027-1"
    assert entradas[0]["fecha"] == "2026-11-13"
    assert all(e["titulo"] and e["resumen"] for e in entradas)


def test_extraer_html_sin_selector():
    with pytest.raises(ValueError):
        extraer_html("<html></html>", {})


def test_dominio_permitido():
    dominios = ("unab.edu.co", "scraper")
    assert dominio_permitido("https://unab.edu.co/feed/", dominios)
    assert dominio_permitido("https://www.unab.edu.co/noticias", dominios)
    assert dominio_permitido("http://scraper:8000/demo/boletin-ccd.html", dominios)
    assert not dominio_permitido("https://unab.edu.co.evil.com/", dominios)
    assert not dominio_permitido("http://169.254.169.254/latest/meta-data", dominios)
