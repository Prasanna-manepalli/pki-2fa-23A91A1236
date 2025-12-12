from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pathlib import Path
import base64
import os
import time   # FIXED: required for generate-2fa

from app.crypto_utils import load_private_key, decrypt_seed
from app.totp_utils import generate_totp_code, verify_totp_code, read_hex_seed

app = FastAPI()

# Paths
SEED_PATH = Path("/data/seed.txt")
PRIVATE_KEY_PATH = Path("/srv/app/student_private.pem")

# ----------- REQUEST MODELS ---------------- #

class SeedRequest(BaseModel):
    encrypted: str   # FIXED: evaluator sends "encrypted"

class VerifyRequest(BaseModel):
    code: str

# ----------- DECRYPT SEED ENDPOINT ----------- #

@app.post("/decrypt-seed")
def api_decrypt_seed(req: SeedRequest):
    try:
        encrypted_seed = req.encrypted   # FIXED
        if not encrypted_seed:
            raise ValueError("Missing encrypted seed")

        private_key = load_private_key(PRIVATE_KEY_PATH)
        hex_seed = decrypt_seed(encrypted_seed, private_key)

        # Store in persistent volume
        SEED_PATH.write_text(hex_seed)

        return {"status": "ok"}

    except Exception:
        return {"error": "Decryption failed"}

# ----------- GENERATE 2FA CODE --------------- #

@app.get("/generate-2fa")
def api_generate_2fa():
    try:
        if not SEED_PATH.exists():
            raise FileNotFoundError("Seed not decrypted")

        hex_seed = read_hex_seed(SEED_PATH)
        code = generate_totp_code(hex_seed)

        # FIXED: os.time.time() → time.time()
        valid_for = 30 - (int(time.time()) % 30)

        return {"code": code, "valid_for": valid_for}

    except Exception:
        raise HTTPException(status_code=500, detail="Seed not decrypted yet")

# ----------- VERIFY 2FA CODE ---------------- #

@app.post("/verify-2fa")
def api_verify_2fa(req: VerifyRequest):
    try:
        if not req.code:
            raise HTTPException(status_code=400, detail="Missing code")

        if not SEED_PATH.exists():
            raise HTTPException(status_code=500, detail="Seed not decrypted yet")

        hex_seed = read_hex_seed(SEED_PATH)
        valid = verify_totp_code(hex_seed, req.code)

        return {"valid": valid}

    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=500, detail="Unexpected error")
