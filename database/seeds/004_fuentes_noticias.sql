-- =====================================================================
-- 004_fuentes_noticias.sql
-- Fuentes que consulta el scraper (WF04).
-- 1. Noticias públicas de la UNAB (feed RSS del sitio). Solo entradas con
--    palabras académicas y sin las categorías internas (personal, empleos).
-- 2. Boletín DEMO del CCD que sirve el propio scraper: contenido
--    sintético para demostrar la extracción HTML sin depender de internet.
-- =====================================================================

insert into fuente_noticia (nombre, url_base, tipo, activa, configuracion)
values
    ('UNAB - Noticias',
     'https://unab.edu.co/feed/',
     'rss',
     true,
     '{"palabras_clave": ["estudiante", "curso", "convocatoria", "beca", "inscripci", "certific",
                          "digital", "tecnolog", "ingenier", "sistemas", "diplomado", "taller",
                          "investigaci", "pregrado", "insignia", "inteligencia artificial"],
       "categorias_excluidas": ["Gestión Humana", "Trabaja con nosotros"]}'::jsonb),
    ('Boletín de Competencias Digitales (DEMO)',
     'http://scraper:8000/demo/boletin-ccd.html',
     'html',
     true,
     '{"selector_item": "article.novedad",
       "selector_titulo": ".novedad-titulo",
       "selector_enlace": ".novedad-titulo a",
       "selector_resumen": ".novedad-resumen",
       "selector_fecha": "time",
       "conservar_fragmento": true}'::jsonb)
on conflict (nombre) do update
    set url_base      = excluded.url_base,
        tipo          = excluded.tipo,
        activa        = excluded.activa,
        configuracion = excluded.configuracion;
