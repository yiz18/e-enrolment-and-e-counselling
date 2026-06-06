"""FastAPI application entry-point.

Startup sequence
----------------
1. ``lifespan`` event fires → ``model_service.load()`` reads all four artifacts
   from ``backend/artifacts/`` exactly once.
2. The singleton ``model_service`` is shared across every request handler with
   zero locking overhead (PyTorch inference under ``@torch.no_grad()`` is
   thread-safe for CPU tensors).

Endpoints
---------
GET  /health    → liveness + model metadata
POST /predict   → career prediction (dominant_code, top3_codes, probabilities)
"""

from __future__ import annotations

import logging
import os
from contextlib import asynccontextmanager
from typing import AsyncIterator

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.models.schemas import HealthResponse, PredictRequest, PredictResponse
from app.services.model_service import model_service

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Lifespan — load artifacts once at startup
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    logger.info("=== RIASEC Personality-Type Prediction API — starting up ===")
    try:
        model_service.load()
        logger.info("All artifacts loaded successfully.  Server is ready.")
    except FileNotFoundError as exc:
        logger.critical("Artifact missing — server will start but /predict will fail.\n%s", exc)
    except Exception as exc:  # noqa: BLE001
        logger.critical("Failed to load model: %s", exc, exc_info=True)
    yield
    logger.info("=== Shutting down ===")


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = FastAPI(
    title="RIASEC Personality-Type Prediction API",
    description=(
        "Predicts a student's dominant Holland RIASEC personality type "
        "from 48 individual questionnaire item responses (R1–R8, I1–I8, "
        "A1–A8, S1–S8, E1–E8, C1–C8) using a trained DNN."
    ),
    version="1.0.0",
    lifespan=lifespan,
)

# Allow Flutter (or any local dev client) to call the API without CORS issues.
# Tighten ``allow_origins`` before deploying to production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "*").split(","),
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Exception handlers
# ---------------------------------------------------------------------------

@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("Unhandled error on %s %s", request.method, request.url)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error. Check server logs."},
    )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@app.get(
    "/health",
    response_model=HealthResponse,
    summary="Server and model health check",
    tags=["Meta"],
)
async def health() -> HealthResponse:
    """Returns the current liveness status and loaded model metadata.

    Use this endpoint to verify:
    - the server is reachable
    - all four artifacts were loaded successfully
    - which model version is active
    """
    return HealthResponse(
        status="ok" if model_service.is_loaded else "degraded",
        model_loaded=model_service.is_loaded,
        model_version=model_service.model_version,
        n_classes=model_service.n_classes,
        features=model_service.features,
    )


@app.post(
    "/predict",
    response_model=PredictResponse,
    summary="RIASEC personality-type prediction from 48 item scores",
    tags=["Inference"],
)
async def predict(body: PredictRequest) -> PredictResponse:
    """Predict the dominant Holland RIASEC personality type for one student.

    **Request body** — 48 integer item scores (0–4 each):

    | Fields | Range | Holland dimension |
    |---|---|---|
    | R1 … R8 | 0–4 | Realistic |
    | I1 … I8 | 0–4 | Investigative |
    | A1 … A8 | 0–4 | Artistic |
    | S1 … S8 | 0–4 | Social |
    | E1 … E8 | 0–4 | Enterprising |
    | C1 … C8 | 0–4 | Conventional |

    Item scale: 0 = Strongly Dislike, 1 = Dislike, 2 = Neutral,
    3 = Like, 4 = Strongly Like.

    **Response**:
    - `dominant_code` — single-letter Holland code with highest probability
    - `top3_codes` — ranked top-3 Holland codes (descending probability)
    - `probabilities` — softmax probability per Holland code (R,I,A,S,E,C)
    """
    if not model_service.is_loaded:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Model is not loaded. "
                "Ensure all four artifacts exist in backend/artifacts/ "
                "and restart the server."
            ),
        )

    try:
        result = model_service.predict(body.to_feature_list())
    except Exception as exc:
        logger.exception("Prediction failed for input: %s", body.model_dump())
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Prediction error: {exc}",
        ) from exc

    return PredictResponse(
        dominant_code=result["dominant_code"],
        top3_codes=result["top3_codes"],
        probabilities=result["probabilities"],
    )
