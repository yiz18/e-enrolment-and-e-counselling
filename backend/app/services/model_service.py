"""ModelService — loads all artifacts once at startup and exposes predict()."""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

import joblib
import numpy as np
import torch
import torch.nn as nn

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Holland class-name → single-letter code mapping
# ---------------------------------------------------------------------------

# The label encoder was trained on full class names.  The API contract and
# Flutter StudentInterestService both expect single-letter Holland codes.
HOLLAND_CLASS_TO_CODE: dict[str, str] = {
    "Artistic": "A",
    "Conventional": "C",
    "Enterprising": "E",
    "Investigative": "I",
    "Realistic": "R",
    "Social": "S",
    # Pass-through for encoders that already emit single letters.
    "A": "A",
    "C": "C",
    "E": "E",
    "I": "I",
    "R": "R",
    "S": "S",
}


def _to_holland_code(label: str) -> str:
    """Convert a label-encoder class name to a single-letter Holland code."""
    code = HOLLAND_CLASS_TO_CODE.get(label)
    if code is None:
        raise ValueError(
            f"Unknown Holland class label '{label}'. "
            f"Expected one of: {sorted(HOLLAND_CLASS_TO_CODE)}"
        )
    return code


# ---------------------------------------------------------------------------
# DNN architecture — must match the training script exactly
# ---------------------------------------------------------------------------

class CareerClassifier(nn.Module):
    """Feed-forward DNN for RIASEC personality-type prediction.

    Architecture (confirmed from model.pt state dict):
        Input(48) → Linear(256) → BatchNorm → ReLU → Dropout(p)
                  → Linear(128) → BatchNorm → ReLU → Dropout(p)
                  → Linear(64)  → BatchNorm → ReLU → Dropout(p)
                  → Linear(6)   ← one logit per Holland RIASEC type

    ``input_dim``, ``hidden_dims``, ``output_dim``, and ``dropout`` are all
    read from ``meta.json`` at startup so this class never hard-codes them.
    """

    def __init__(
        self,
        input_dim: int,
        hidden_dims: list[int],
        output_dim: int,
        dropout: float = 0.3,
    ) -> None:
        super().__init__()

        layers: list[nn.Module] = []
        in_features = input_dim

        for hidden_dim in hidden_dims:
            layers += [
                nn.Linear(in_features, hidden_dim),
                nn.BatchNorm1d(hidden_dim),
                nn.ReLU(),
                nn.Dropout(p=dropout),
            ]
            in_features = hidden_dim

        layers.append(nn.Linear(in_features, output_dim))
        self.net = nn.Sequential(*layers)

    def forward(self, x: torch.Tensor) -> torch.Tensor:  # type: ignore[override]
        return self.net(x)


# ---------------------------------------------------------------------------
# ModelService
# ---------------------------------------------------------------------------

class ModelService:
    """Singleton-style service that owns all ML artifacts.

    Call ``ModelService.load(artifacts_dir)`` once during application startup.
    All subsequent inference goes through ``predict()``.
    """

    _ARTIFACTS_DIR = Path(__file__).resolve().parents[2] / "artifacts"

    def __init__(self) -> None:
        self._model: CareerClassifier | None = None
        self._scaler: Any = None
        self._label_encoder: Any = None
        self._meta: dict[str, Any] = {}
        self._loaded = False

    # ------------------------------------------------------------------
    # Startup
    # ------------------------------------------------------------------

    def load(self, artifacts_dir: Path | None = None) -> None:
        """Load all artifacts from *artifacts_dir* (defaults to ``/artifacts``).

        Raises ``FileNotFoundError`` if any required artifact is missing.
        Raises ``RuntimeError`` if the state dict is incompatible with the
        architecture declared in ``meta.json``.
        """
        root = artifacts_dir or self._ARTIFACTS_DIR

        meta_path = root / "meta.json"
        model_path = root / "model.pt"
        scaler_path = root / "scaler.joblib"
        encoder_path = root / "label_encoder.joblib"

        for p in (meta_path, model_path, scaler_path, encoder_path):
            if not p.exists():
                raise FileNotFoundError(
                    f"Required artifact not found: {p}\n"
                    "See artifacts/PLACE_ARTIFACTS_HERE.md for instructions."
                )

        # 1. meta.json
        with meta_path.open() as fh:
            self._meta = json.load(fh)
        logger.info("meta.json loaded  version=%s", self._meta.get("model_version"))

        # 2. scaler
        self._scaler = joblib.load(scaler_path)
        logger.info("scaler loaded  type=%s", type(self._scaler).__name__)

        # 3. label encoder
        self._label_encoder = joblib.load(encoder_path)
        logger.info(
            "label_encoder loaded  classes=%s",
            list(self._label_encoder.classes_),
        )

        # 4. PyTorch model
        arch = self._meta["architecture"]
        self._model = CareerClassifier(
            input_dim=arch["input_dim"],
            hidden_dims=arch["hidden_dims"],
            output_dim=arch["output_dim"],
            dropout=arch.get("dropout", 0.3),
        )

        # Load state dict — map to CPU so the server runs without a GPU
        state = torch.load(model_path, map_location="cpu", weights_only=True)

        # Unwrap common training wrappers (DataParallel, etc.)
        if any(k.startswith("module.") for k in state):
            state = {k.replace("module.", "", 1): v for k, v in state.items()}

        try:
            self._model.load_state_dict(state)
        except RuntimeError as exc:
            raise RuntimeError(
                "State dict is incompatible with the CareerClassifier architecture "
                "defined in meta.json. Check hidden_dims / input_dim / output_dim."
            ) from exc

        self._model.eval()
        self._loaded = True
        logger.info(
            "model.pt loaded and set to eval()  params=%d",
            sum(p.numel() for p in self._model.parameters()),
        )

    # ------------------------------------------------------------------
    # Inference
    # ------------------------------------------------------------------

    @torch.no_grad()
    def predict(self, features: list[float]) -> dict[str, Any]:
        """Run inference for a single sample.

        Parameters
        ----------
        features:
            48 integer item scores **in exact training column order**:
            R1–R8, I1–I8, A1–A8, S1–S8, E1–E8, C1–C8.
            Use ``PredictRequest.to_feature_list()`` to produce this list.

        Returns
        -------
        dict with keys:
            ``dominant_code``  – single-letter Holland code with highest prob
            ``top3_codes``     – list[str] of top-3 Holland codes (desc prob)
            ``probabilities``  – dict[str, float] keyed by Holland code
        """
        if not self._loaded or self._model is None:
            raise RuntimeError("ModelService has not been loaded yet.")

        # Scale
        x_raw = np.array([features], dtype=np.float32)
        x_scaled = self._scaler.transform(x_raw).astype(np.float32)

        # Forward pass
        tensor = torch.from_numpy(x_scaled)
        logits = self._model(tensor)
        probs = torch.softmax(logits, dim=1).squeeze(0).numpy()

        # Decode — label encoder emits full class names; API returns Holland codes.
        classes: list[str] = list(self._label_encoder.classes_)
        prob_map: dict[str, float] = {}
        for label, prob in zip(classes, probs):
            code = _to_holland_code(label)
            prob_map[code] = round(float(prob), 6)

        sorted_codes = sorted(prob_map, key=prob_map.__getitem__, reverse=True)

        return {
            "dominant_code": sorted_codes[0],
            "top3_codes": sorted_codes[:3],
            "probabilities": prob_map,
        }

    # ------------------------------------------------------------------
    # Accessors (used by /health)
    # ------------------------------------------------------------------

    @property
    def is_loaded(self) -> bool:
        return self._loaded

    @property
    def model_version(self) -> str:
        return self._meta.get("model_version", "unknown")

    @property
    def n_classes(self) -> int:
        return int(self._meta.get("architecture", {}).get("output_dim", 0))

    @property
    def features(self) -> list[str]:
        return list(self._meta.get("features", []))


# Module-level singleton — imported by main.py
model_service = ModelService()
