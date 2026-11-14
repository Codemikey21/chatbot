# Servidor MCP del chatbot académico (FastMCP, HTTP streamable)
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /srv

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app ./app

# Usuario sin privilegios
RUN useradd --create-home --uid 10001 mcp
USER mcp

EXPOSE 9000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import sys, urllib.request; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:9000/health', timeout=4).status == 200 else 1)"

CMD ["python", "-m", "app.servidor"]
