from datetime import date

from app.limpieza import clasificar, limpiar_texto, normalizar_url, parsear_fecha, preparar


def test_limpiar_texto_quita_html_y_espacios():
    assert limpiar_texto("<p>Hola   <b>mundo</b></p>\n") == "Hola mundo"
    assert limpiar_texto("Inscripciones &amp; becas") == "Inscripciones & becas"
    assert limpiar_texto(None) == ""


def test_limpiar_texto_cierre_de_wordpress():
    assert limpiar_texto("Texto del extracto [&#8230;]") == "Texto del extracto…"


def test_limpiar_texto_recorta_en_palabra():
    texto = limpiar_texto("uno dos tres cuatro cinco", 12)
    assert texto == "uno dos tres…"


def test_normalizar_url_quita_rastreo_y_fragmento():
    url = normalizar_url("/noticias/a/?utm_source=rss&id=7#comentarios", "https://UNAB.edu.co/feed/")
    assert url == "https://unab.edu.co/noticias/a/?id=7"


def test_normalizar_url_conserva_fragmento_si_se_pide():
    url = normalizar_url("#ccd-1", "http://scraper:8000/demo/boletin-ccd.html", conservar_fragmento=True)
    assert url == "http://scraper:8000/demo/boletin-ccd.html#ccd-1"


def test_normalizar_url_rechaza_esquemas_no_web():
    assert normalizar_url("javascript:alert(1)", "https://unab.edu.co") is None
    assert normalizar_url("mailto:a@b.co", "https://unab.edu.co") is None
    assert normalizar_url(None, "https://unab.edu.co") is None


def test_parsear_fecha_formatos():
    assert parsear_fecha("2026-11-13T10:00:00") == date(2026, 11, 13)
    assert parsear_fecha("13/11/2026") == date(2026, 11, 13)
    assert parsear_fecha("13 de noviembre de 2026") == date(2026, 11, 13)
    assert parsear_fecha("1 de Septiembre del 2026") == date(2026, 9, 1)
    assert parsear_fecha("31 de febrero de 2026") is None
    assert parsear_fecha("pronto") is None


def test_clasificar():
    assert clasificar("Abierta la convocatoria de becas", "") == "convocatoria"
    assert clasificar("Entrega de insignias digitales", "aprobaron cursos") == "certificacion"
    assert clasificar("Nuevo diplomado en analítica", "") == "curso"
    assert clasificar("Alianza deja espacios de formación", "") == "noticia"
    assert clasificar("Resultados del torneo deportivo", "") == "noticia"


def test_preparar_deduplica_filtra_y_limita():
    crudos = [
        {"titulo": "Convocatoria de becas", "url": "/a?utm_medium=x", "resumen": "para estudiantes", "fecha": "2026-11-11"},
        {"titulo": "Convocatoria de becas (repetida)", "url": "/a", "resumen": "", "fecha": None},
        {"titulo": "Torneo deportivo", "url": "/b", "resumen": "fútbol", "fecha": None},
        {"titulo": "", "url": "/c", "resumen": "sin título", "fecha": None},
        {"titulo": "Curso de datos para estudiantes", "url": "/d", "resumen": "", "fecha": "13/11/2026"},
    ]
    noticias = preparar(crudos, "https://unab.edu.co/feed/", {"palabras_clave": ["estudiantes"]}, maximo=10)
    assert [n["url"] for n in noticias] == ["https://unab.edu.co/a", "https://unab.edu.co/d"]
    assert noticias[0]["categoria"] == "convocatoria"
    assert noticias[0]["fecha_publicacion"] == "2026-11-11"
    assert noticias[1]["categoria"] == "curso"
    assert len(noticias[0]["hash_contenido"]) == 64

    uno = preparar(crudos, "https://unab.edu.co/feed/", {}, maximo=1)
    assert len(uno) == 1


def test_preparar_excluye_categorias():
    crudos = [
        {"titulo": "Pagos al personal", "url": "/p", "categorias": ["Gestión Humana"]},
        {"titulo": "Noticia para estudiantes", "url": "/e", "categorias": ["Estudiantes"]},
    ]
    noticias = preparar(crudos, "https://unab.edu.co", {"categorias_excluidas": ["gestión humana"]}, 5)
    assert [n["url"] for n in noticias] == ["https://unab.edu.co/e"]


def test_preparar_categoria_fija():
    noticias = preparar([{"titulo": "Algo", "url": "/x"}], "https://unab.edu.co", {"categoria": "curso"}, 5)
    assert noticias[0]["categoria"] == "curso"
