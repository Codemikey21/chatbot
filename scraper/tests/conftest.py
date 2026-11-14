import os
from pathlib import Path

import pytest

# Variables de prueba: deben existir antes de importar la aplicación
os.environ.setdefault("SCRAPER_TOKEN", "token-de-prueba")
os.environ.setdefault("SCRAPER_DOMINIOS_PERMITIDOS", "unab.edu.co,scraper")

from fastapi.testclient import TestClient  # noqa: E402

from app import robots  # noqa: E402
from app.main import app  # noqa: E402

FIXTURES = Path(__file__).parent / "fixtures"
DEMO = Path(__file__).parent.parent / "app" / "demo" / "boletin-ccd.html"


@pytest.fixture(autouse=True)
def cache_limpia():
    robots.limpiar_cache()
    yield
    robots.limpiar_cache()


@pytest.fixture
def cliente():
    return TestClient(app)


@pytest.fixture
def cabeceras():
    return {"Authorization": "Bearer token-de-prueba"}


@pytest.fixture
def feed():
    return (FIXTURES / "feed.xml").read_text(encoding="utf-8")


@pytest.fixture
def demo_html():
    return DEMO.read_text(encoding="utf-8")
