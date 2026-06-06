"""
End-to-end local test for the RIASEC Prediction API.

Runs three checks in sequence without needing pytest:
    1. Artifact loading (model.pt, scaler.joblib, label_encoder.joblib, meta.json)
    2. Direct ModelService.predict() call (bypasses HTTP)
    3. Live HTTP test against a running FastAPI server

Usage
-----
# Terminal 1 — start the server
    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Terminal 2 — run this script
    python test_local.py

The HTTP test (step 3) requires the server to be running.
Steps 1 and 2 can be run without the server.
"""

from __future__ import annotations

import json
import sys
import urllib.request
import urllib.error

DIVIDER = "=" * 60

# ---------------------------------------------------------------------------
# Sample payload — values drawn from Dataset.csv row 2 (R1–C8 only)
# All values are in range 1–5 as confirmed from the training data.
# ---------------------------------------------------------------------------
SAMPLE_PAYLOAD: dict[str, int] = {
    "R1": 3, "R2": 4, "R3": 3, "R4": 1, "R5": 1, "R6": 4, "R7": 1, "R8": 3,
    "I1": 5, "I2": 5, "I3": 4, "I4": 3, "I5": 4, "I6": 5, "I7": 4, "I8": 3,
    "A1": 5, "A2": 4, "A3": 1, "A4": 2, "A5": 4, "A6": 5, "A7": 2, "A8": 4,
    "S1": 3, "S2": 5, "S3": 5, "S4": 4, "S5": 5, "S6": 5, "S7": 5, "S8": 5,
    "E1": 2, "E2": 1, "E3": 4, "E4": 1, "E5": 2, "E6": 2, "E7": 1, "E8": 3,
    "C1": 1, "C2": 3, "C3": 1, "C4": 1, "C5": 1, "C6": 3, "C7": 1, "C8": 1,
}

BASE_URL = "http://localhost:8000"

PASS = "\033[92mPASS\033[0m"
FAIL = "\033[91mFAIL\033[0m"


def section(title: str) -> None:
    print(f"\n{DIVIDER}\n  {title}\n{DIVIDER}")


# ---------------------------------------------------------------------------
# Step 1 — artifact loading via ModelService
# ---------------------------------------------------------------------------

def test_artifact_loading() -> bool:
    section("STEP 1 — Artifact loading")
    ok = True

    try:
        from app.services.model_service import model_service
        model_service.load()

        print(f"  meta.json   : {PASS}  version={model_service.model_version}")
        print(f"  scaler      : {PASS}")
        print(f"  label_enc   : {PASS}  classes={model_service.n_classes}")
        print(f"  model.pt    : {PASS}  eval() called")
        print(f"\n  Features    : {len(model_service.features)} features")
        print(f"  Feature[0]  : {model_service.features[0]}")
        print(f"  Feature[-1] : {model_service.features[-1]}")

    except FileNotFoundError as exc:
        print(f"  {FAIL}  Missing artifact:\n  {exc}")
        ok = False
    except RuntimeError as exc:
        print(f"  {FAIL}  Architecture mismatch:\n  {exc}")
        ok = False
    except Exception as exc:  # noqa: BLE001
        print(f"  {FAIL}  Unexpected error:\n  {exc}")
        ok = False

    return ok


# ---------------------------------------------------------------------------
# Step 2 — direct inference (no HTTP)
# ---------------------------------------------------------------------------

def test_direct_inference() -> bool:
    section("STEP 2 — Direct ModelService.predict()")

    try:
        from app.services.model_service import model_service
        from app.models.schemas import PredictRequest

        req = PredictRequest(**SAMPLE_PAYLOAD)
        features = req.to_feature_list()

        print(f"  Feature list length : {len(features)}  (expected 48)")
        assert len(features) == 48, f"Expected 48, got {len(features)}"

        result = model_service.predict(features)

        dominant = result["dominant_code"]
        top3     = result["top3_codes"]
        probs    = result["probabilities"]

        assert isinstance(dominant, str) and len(dominant) > 0
        assert isinstance(top3, list) and len(top3) == 3
        assert all(isinstance(v, float) for v in probs.values())
        assert abs(sum(probs.values()) - 1.0) < 0.01, "Probabilities do not sum to ~1"

        print(f"\n  dominant_code  : {dominant}")
        print(f"  top3_codes     : {top3}")
        print(f"  probabilities  :")
        for code, p in sorted(probs.items(), key=lambda x: -x[1]):
            bar = "#" * int(p * 40)
            print(f"    {code} : {p:.4f}  {bar}")
        print(f"\n  {PASS}")
        return True

    except RuntimeError as exc:
        if "not been loaded" in str(exc):
            print(f"  {FAIL}  Model not loaded — Step 1 must pass first")
        else:
            print(f"  {FAIL}  {exc}")
        return False
    except AssertionError as exc:
        print(f"  {FAIL}  Assertion failed: {exc}")
        return False
    except Exception as exc:  # noqa: BLE001
        print(f"  {FAIL}  {exc}")
        return False


# ---------------------------------------------------------------------------
# Step 3 — HTTP test against live server
# ---------------------------------------------------------------------------

def _http_get(path: str) -> tuple[int, dict]:
    req = urllib.request.Request(f"{BASE_URL}{path}")
    with urllib.request.urlopen(req, timeout=5) as resp:
        return resp.status, json.loads(resp.read())


def _http_post(path: str, body: dict) -> tuple[int, dict]:
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read())


def test_http() -> bool:
    section("STEP 3 — HTTP /health and /predict")

    # -- /health --
    try:
        status, body = _http_get("/health")
        assert status == 200, f"Expected 200, got {status}"
        assert body["status"] == "ok", f"status={body['status']}"
        assert body["model_loaded"] is True
        print(f"  GET /health     : {PASS}")
        print(f"    status        : {body['status']}")
        print(f"    model_loaded  : {body['model_loaded']}")
        print(f"    model_version : {body['model_version']}")
        print(f"    n_classes     : {body['n_classes']}")
        print(f"    n_features    : {len(body['features'])}")
    except urllib.error.URLError as exc:
        print(f"  GET /health     : {FAIL}  Server not reachable — {exc.reason}")
        print("  → Start the server first:  uvicorn app.main:app --reload --port 8000")
        return False
    except AssertionError as exc:
        print(f"  GET /health     : {FAIL}  {exc}")
        return False

    print()

    # -- /predict --
    print("  POST /predict")
    print("  Payload (first 8 fields shown):")
    snippet = {k: v for k, v in list(SAMPLE_PAYLOAD.items())[:8]}
    print(f"    {json.dumps(snippet, separators=(',', ':'))} …")

    status, body = _http_post("/predict", SAMPLE_PAYLOAD)

    if status != 200:
        print(f"  POST /predict   : {FAIL}  HTTP {status}")
        print(f"    Response body : {json.dumps(body, indent=4)}")
        return False

    dominant = body.get("dominant_code")
    top3     = body.get("top3_codes")
    probs    = body.get("probabilities")

    try:
        assert isinstance(dominant, str) and len(dominant) > 0
        assert isinstance(top3, list) and len(top3) == 3
        assert isinstance(probs, dict) and len(probs) == 6
        assert abs(sum(probs.values()) - 1.0) < 0.01
    except AssertionError as exc:
        print(f"  POST /predict   : {FAIL}  Response shape wrong — {exc}")
        print(f"    Body: {json.dumps(body, indent=4)}")
        return False

    print(f"\n  POST /predict   : {PASS}  HTTP {status}")
    print(f"\n  Response:")
    print(f"    dominant_code  : \"{dominant}\"")
    print(f"    top3_codes     : {top3}")
    print(f"    probabilities  :")
    for code, p in sorted(probs.items(), key=lambda x: -x[1]):
        bar = "#" * int(p * 40)
        print(f"      {code} : {p:.6f}  {bar}")

    return True


# ---------------------------------------------------------------------------
# Step 3b — validation rejection test
# ---------------------------------------------------------------------------

def test_validation_rejection() -> bool:
    section("STEP 3b — Validation rejection (R1=9 should return HTTP 422)")

    bad_payload = {**SAMPLE_PAYLOAD, "R1": 9}

    try:
        status, body = _http_post("/predict", bad_payload)
        if status == 422:
            print(f"  {PASS}  Server correctly rejected R1=9 with HTTP 422")
            errors = body.get("detail", [])
            for err in errors[:3]:
                print(f"    loc={err.get('loc')}  msg={err.get('msg')}")
            return True
        else:
            print(f"  {FAIL}  Expected HTTP 422, got {status}")
            print(f"    Body: {json.dumps(body, indent=2)}")
            return False
    except urllib.error.URLError:
        print("  SKIP — server not running")
        return True  # not a test failure if server is down


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    print("\nRIASEC API — End-to-End Local Test")
    print(f"Payload source: Dataset.csv row 2 ({len(SAMPLE_PAYLOAD)} features, all 1–5)\n")

    results: dict[str, bool] = {}

    results["1_artifact_load"] = test_artifact_loading()
    results["2_direct_infer"]  = test_direct_inference() if results["1_artifact_load"] else False
    results["3_http_predict"]  = test_http()
    results["3b_validation"]   = test_validation_rejection()

    section("SUMMARY")
    all_pass = True
    labels = {
        "1_artifact_load": "Artifact loading",
        "2_direct_infer" : "Direct inference",
        "3_http_predict" : "HTTP /health + /predict",
        "3b_validation"  : "Validation rejection",
    }
    for key, passed in results.items():
        icon = PASS if passed else FAIL
        print(f"  {icon}  {labels[key]}")
        if not passed:
            all_pass = False

    print()
    if all_pass:
        print("  All checks passed. The backend is working correctly.")
    else:
        print("  One or more checks failed. See details above.")
        sys.exit(1)


if __name__ == "__main__":
    main()
