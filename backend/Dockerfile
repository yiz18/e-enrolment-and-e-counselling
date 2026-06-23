# Render deploys linux/amd64 — pin platform for reproducible builds.
FROM --platform=linux/amd64 python:3.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Tesseract binary for POST /ocr; libgl1 + libglib2.0-0 for Pillow image ops.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tesseract-ocr \
        libgl1 \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --upgrade pip \
    && pip install -r requirements.txt

COPY app/ ./app/
COPY artifacts/ ./artifacts/
COPY run.py .

EXPOSE 8000

# Render injects PORT; run.py reads it and starts uvicorn.
CMD ["python", "run.py"]
