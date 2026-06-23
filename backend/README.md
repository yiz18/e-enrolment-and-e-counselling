# RIASEC Personality-Type Prediction — FastAPI Backend

FastAPI backend that serves a trained PyTorch DNN which predicts a student's
dominant Holland RIASEC personality type from 48 individual questionnaire item
responses.

---

## Model overview

| Property | Value |
|---|---|
| Input features | **48** (8 items × 6 Holland dimensions) |
| Feature order | R1–R8, I1–I8, A1–A8, S1–S8, E1–E8, C1–C8 |
| Item scale | 0 = Strongly Dislike … 4 = Strongly Like |
| Output classes | 6 Holland codes: R, I, A, S, E, C |
| Architecture | Input(48) → Linear(128) → ReLU → Dropout(0.3) → Linear(64) → ReLU → Dropout(0.3) → Linear(6) |

---

## Prerequisites

- Python 3.10+
- `pip`
- The four trained artifacts (see **Artifacts** below)
- **Tesseract OCR** (required for `POST /ocr`):
  - Windows: `winget install UB-Mannheim.TesseractOCR`
  - Ubuntu/Debian: `sudo apt-get install -y tesseract-ocr`
  - macOS: `brew install tesseract`

---

## Project structure

```
backend/
├── app/
│   ├── main.py                  ← FastAPI app, /health, /predict
│   ├── models/
│   │   └── schemas.py           ← PredictRequest (48 fields), PredictResponse
│   └── services/
│       └── model_service.py     ← ModelService + CareerClassifier DNN
├── artifacts/
│   ├── model.pt                 ← place here after training
│   ├── scaler.joblib            ← place here after training
│   ├── label_encoder.joblib     ← place here after training
│   └── meta.json                ← already committed; edit if needed
├── requirements.txt
└── README.md
```

---

## Artifacts

Copy the four files your training script produced into `backend/artifacts/`:

| File | How it was saved |
|------|-----------------|
| `model.pt` | `torch.save(model.state_dict(), "model.pt")` |
| `scaler.joblib` | `joblib.dump(scaler, "scaler.joblib")` |
| `label_encoder.joblib` | `joblib.dump(label_encoder, "label_encoder.joblib")` |
| `meta.json` | Already present — edit `hidden_dims` if your architecture differs |

---

## Quick start

```powershell
# 1. Enter the backend folder
cd backend

# 2. Create a virtual environment
python -m venv .venv
.venv\Scripts\Activate.ps1        # Windows PowerShell
# source .venv/bin/activate        # macOS / Linux

# 3. Install dependencies
pip install -r requirements.txt

# 4. Start the server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The server logs confirm every artifact loaded:

```
INFO | model_service — meta.json loaded  version=1.0.0
INFO | model_service — scaler loaded  type=StandardScaler
INFO | model_service — label_encoder loaded  classes=['A','C','E','I','R','S']
INFO | model_service — model.pt loaded and set to eval()  params=...
INFO | All artifacts loaded successfully.  Server is ready.
```

---

## Testing

### 1. Interactive Swagger UI

Open **http://localhost:8000/docs** — try `/predict` directly in the browser.

### 2. Health check

```powershell
Invoke-RestMethod -Uri http://localhost:8000/health | ConvertTo-Json
```

```bash
curl http://localhost:8000/health
```

Expected response:

```json
{
  "status": "ok",
  "model_loaded": true,
  "model_version": "1.0.0",
  "n_classes": 6,
  "features": ["R1","R2","R3","R4","R5","R6","R7","R8",
               "I1","I2","I3","I4","I5","I6","I7","I8",
               "A1","A2","A3","A4","A5","A6","A7","A8",
               "S1","S2","S3","S4","S5","S6","S7","S8",
               "E1","E2","E3","E4","E5","E6","E7","E8",
               "C1","C2","C3","C4","C5","C6","C7","C8"]
}
```

### 3. Predict endpoint

Send all 48 item scores as a flat JSON object.

**PowerShell**

```powershell
$body = @{
    R1=2; R2=3; R3=1; R4=2; R5=3; R6=2; R7=1; R8=2
    I1=1; I2=2; I3=1; I4=1; I5=2; I6=1; I7=2; I8=1
    A1=2; A2=3; A3=4; A4=3; A5=2; A6=3; A7=4; A8=3
    S1=1; S2=2; S3=1; S4=2; S5=1; S6=2; S7=1; S8=2
    E1=3; E2=4; E3=3; E4=4; E5=3; E6=4; E7=3; E8=4
    C1=1; C2=2; C3=1; C4=2; C5=1; C6=2; C7=1; C8=2
} | ConvertTo-Json

Invoke-RestMethod -Uri http://localhost:8000/predict `
    -Method POST `
    -ContentType "application/json" `
    -Body $body | ConvertTo-Json -Depth 5
```

**curl / bash**

```bash
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "R1":2,"R2":3,"R3":1,"R4":2,"R5":3,"R6":2,"R7":1,"R8":2,
    "I1":1,"I2":2,"I3":1,"I4":1,"I5":2,"I6":1,"I7":2,"I8":1,
    "A1":2,"A2":3,"A3":4,"A4":3,"A5":2,"A6":3,"A7":4,"A8":3,
    "S1":1,"S2":2,"S3":1,"S4":2,"S5":1,"S6":2,"S7":1,"S8":2,
    "E1":3,"E2":4,"E3":3,"E4":4,"E5":3,"E6":4,"E7":3,"E8":4,
    "C1":1,"C2":2,"C3":1,"C4":2,"C5":1,"C6":2,"C7":1,"C8":2
  }'
```

Expected response shape:

```json
{
  "dominant_code": "E",
  "top3_codes": ["E", "A", "R"],
  "probabilities": {
    "R": 0.121,
    "I": 0.062,
    "A": 0.198,
    "S": 0.071,
    "E": 0.489,
    "C": 0.059
  }
}
```

### 5. OCR endpoint (web upload fallback)

Requires Tesseract installed on the host.

```powershell
# With server running on port 8000
python test_ocr_local.py
```

Or upload via Swagger UI at **http://localhost:8000/docs** → `POST /ocr` → choose `spm_sample_yyz.jpg` from `backend/poc/`.

---

## Deploying OCR on Render

Add Tesseract to the Render build step (Native Environment):

```bash
apt-get update && apt-get install -y tesseract-ocr
pip install -r requirements.txt
```

Verify after deploy:

```bash
curl -F "file=@backend/poc/spm_sample_yyz.jpg" https://<your-service>.onrender.com/ocr
```

Flutter Web must point at the same backend:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://<your-service>.onrender.com
```

---

### 4. Validation error example

Sending an out-of-range value returns HTTP 422:

```bash
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"R1": 9, ...}'
```

```json
{
  "detail": [
    {
      "loc": ["body", "R1"],
      "msg": "Input should be less than or equal to 5",
      "type": "less_than_equal"
    }
  ]
}
```

---

## API reference

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Liveness check + model metadata |
| `POST` | `/predict` | RIASEC type prediction (48 item scores in) |
| `POST` | `/ocr` | Tesseract OCR for web academic document upload |
| `GET` | `/docs` | Swagger UI |
| `GET` | `/redoc` | ReDoc UI |

---

## Request field reference

All 48 fields are **required integers, 1–5**.

| Fields | Holland dimension |
|--------|------------------|
| `R1` … `R8` | Realistic |
| `I1` … `I8` | Investigative |
| `A1` … `A8` | Artistic |
| `S1` … `S8` | Social |
| `E1` … `E8` | Enterprising |
| `C1` … `C8` | Conventional |

Item scale: `1` = Dislike, `2` = Slightly Dislike, `3` = Neutral,
`4` = Slightly Like, `5` = Like.

---

## Environment variables (optional)

Create `backend/.env`:

```env
# Comma-separated allowed origins for CORS (default: *)
CORS_ORIGINS=http://localhost:3000,http://10.0.2.2:8000
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `FileNotFoundError: … model.pt` | Copy trained artifact to `backend/artifacts/model.pt` |
| `RuntimeError: State dict incompatible` | Update `meta.json → architecture.hidden_dims` to match your training script |
| HTTP 503 on `/predict` | Model failed to load at startup — check terminal logs |
| HTTP 422 with `less_than_equal` | An item score exceeded 4; check questionnaire encoding |
| `CORS` error from Flutter | Add your Flutter dev origin to `CORS_ORIGINS` in `.env` |
