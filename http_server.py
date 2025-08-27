from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from handler import handler as runpod_handler  # reuse your existing logic

app = FastAPI()

class Inp(BaseModel):
    audio_url: str | None = None
    image_url: str | None = None
    audio_b64: str | None = None
    image_b64: str | None = None
    upload_url: str | None = None
    video_url: str | None = None

@app.get("/healthz")
def healthz():
    return {"ok": True}

@app.post("/runsync")
def runsync(inp: Inp):
    result = runpod_handler({"input": inp.dict()})
    if not result.get("ok"):
        raise HTTPException(status_code=500, detail=result)
    return result