# Artifacts

Place the following trained model artifacts in this directory:

| File | Description |
|------|-------------|
| `model.pt` | PyTorch model state dict (`torch.save(model.state_dict(), "model.pt")`) |
| `scaler.joblib` | Fitted `sklearn` scaler saved with `joblib.dump` — must have been fit on 48 features |
| `label_encoder.joblib` | Fitted `sklearn` `LabelEncoder` for the 6 Holland codes (R,I,A,S,E,C) |
| `meta.json` | Already present — edit `hidden_dims` if your architecture differs |

## Expected model input shape

The scaler and the DNN both expect **exactly 48 features** per sample:

```
R1, R2, R3, R4, R5, R6, R7, R8,   ← 8 Realistic items
I1, I2, I3, I4, I5, I6, I7, I8,   ← 8 Investigative items
A1, A2, A3, A4, A5, A6, A7, A8,   ← 8 Artistic items
S1, S2, S3, S4, S5, S6, S7, S8,   ← 8 Social items
E1, E2, E3, E4, E5, E6, E7, E8,   ← 8 Enterprising items
C1, C2, C3, C4, C5, C6, C7, C8    ← 8 Conventional items
```

The column order above must match the column order in your training DataFrame.

## Expected model architecture

```
Input(48) → Linear(128) → BatchNorm → ReLU → Dropout(0.3)
          → Linear(64)  → BatchNorm → ReLU → Dropout(0.3)
          → Linear(6)
```

If your training script used different hidden dimensions, update `meta.json`:

```json
"architecture": {
  "input_dim": 48,
  "hidden_dims": [256, 128],
  "output_dim": 6,
  "dropout": 0.3
}
```

## Saving artifacts from your training script

```python
import torch, joblib

# After training:
torch.save(model.state_dict(), "artifacts/model.pt")
joblib.dump(scaler, "artifacts/scaler.joblib")          # fit on 48-column X
joblib.dump(label_encoder, "artifacts/label_encoder.joblib")  # fit on y (RIASEC codes)
```
