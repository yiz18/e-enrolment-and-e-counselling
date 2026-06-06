from __future__ import annotations

from pydantic import BaseModel, Field, model_validator


# ---------------------------------------------------------------------------
# Request
# ---------------------------------------------------------------------------

_ITEM_DESCRIPTION = (
    "Individual RIASEC questionnaire item response. "
    "Likert scale: 1 = Dislike, 2 = Slightly Dislike, "
    "3 = Neutral, 4 = Slightly Like, 5 = Like."
)

_item = lambda: Field(..., ge=1, le=5, description=_ITEM_DESCRIPTION)  # noqa: E731


class PredictRequest(BaseModel):
    """48 individual RIASEC questionnaire item responses.

    The model was trained on the raw item scores — NOT on pre-aggregated
    dimension totals.  Each of the six Holland dimensions (R, I, A, S, E, C)
    contributes 8 items, for a total of 48 required fields.

    Item scale
    ----------
    1 = Dislike
    2 = Slightly Dislike
    3 = Neutral
    4 = Slightly Like
    5 = Like

    Column order (must match training CSV column order exactly)
    -----------------------------------------------------------
    R1–R8  → Realistic items
    I1–I8  → Investigative items
    A1–A8  → Artistic items
    S1–S8  → Social items
    E1–E8  → Enterprising items
    C1–C8  → Conventional items
    """

    # -- Realistic (R) -------------------------------------------------------
    R1: int = _item()
    R2: int = _item()
    R3: int = _item()
    R4: int = _item()
    R5: int = _item()
    R6: int = _item()
    R7: int = _item()
    R8: int = _item()

    # -- Investigative (I) ---------------------------------------------------
    I1: int = _item()
    I2: int = _item()
    I3: int = _item()
    I4: int = _item()
    I5: int = _item()
    I6: int = _item()
    I7: int = _item()
    I8: int = _item()

    # -- Artistic (A) --------------------------------------------------------
    A1: int = _item()
    A2: int = _item()
    A3: int = _item()
    A4: int = _item()
    A5: int = _item()
    A6: int = _item()
    A7: int = _item()
    A8: int = _item()

    # -- Social (S) ----------------------------------------------------------
    S1: int = _item()
    S2: int = _item()
    S3: int = _item()
    S4: int = _item()
    S5: int = _item()
    S6: int = _item()
    S7: int = _item()
    S8: int = _item()

    # -- Enterprising (E) ----------------------------------------------------
    E1: int = _item()
    E2: int = _item()
    E3: int = _item()
    E4: int = _item()
    E5: int = _item()
    E6: int = _item()
    E7: int = _item()
    E8: int = _item()

    # -- Conventional (C) ----------------------------------------------------
    C1: int = _item()
    C2: int = _item()
    C3: int = _item()
    C4: int = _item()
    C5: int = _item()
    C6: int = _item()
    C7: int = _item()
    C8: int = _item()

    @model_validator(mode="after")
    def _check_non_trivial(self) -> "PredictRequest":
        """Reject payloads where every single item is 0 (clearly not filled in)."""
        total = sum(self.to_feature_list())
        if total == 0:
            raise ValueError(
                "All 48 item scores are 0. "
                "The questionnaire does not appear to have been completed."
            )
        return self

    def to_feature_list(self) -> list[int]:
        """Return all 48 item scores in exact training column order.

        Order: R1–R8, I1–I8, A1–A8, S1–S8, E1–E8, C1–C8
        This must be consistent with the column order in the training CSV.
        """
        return [
            # Realistic
            self.R1, self.R2, self.R3, self.R4,
            self.R5, self.R6, self.R7, self.R8,
            # Investigative
            self.I1, self.I2, self.I3, self.I4,
            self.I5, self.I6, self.I7, self.I8,
            # Artistic
            self.A1, self.A2, self.A3, self.A4,
            self.A5, self.A6, self.A7, self.A8,
            # Social
            self.S1, self.S2, self.S3, self.S4,
            self.S5, self.S6, self.S7, self.S8,
            # Enterprising
            self.E1, self.E2, self.E3, self.E4,
            self.E5, self.E6, self.E7, self.E8,
            # Conventional
            self.C1, self.C2, self.C3, self.C4,
            self.C5, self.C6, self.C7, self.C8,
        ]


# ---------------------------------------------------------------------------
# Response
# ---------------------------------------------------------------------------

class PredictResponse(BaseModel):
    """RIASEC personality-type prediction result.

    Attributes:
        dominant_code:  Single-letter Holland code with the highest softmax
                        probability (one of R, I, A, S, E, C).
        top3_codes:     Ordered list of the three most probable Holland codes
                        (descending probability), e.g. ["E", "R", "I"].
        probabilities:  Softmax probability for all six classes, keyed by
                        single-letter code.  Values sum to ~1.0.
    """

    dominant_code: str
    top3_codes: list[str]
    probabilities: dict[str, float]


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

class HealthResponse(BaseModel):
    """Server and model health summary."""

    status: str
    model_loaded: bool
    model_version: str
    n_classes: int
    features: list[str]
