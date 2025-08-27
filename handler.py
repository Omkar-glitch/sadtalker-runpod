import base64, os, time, uuid, subprocess, json
from pathlib import Path
import requests
from runpod.serverless import start

REPO_DIR = Path("/workspace/SadTalker").resolve()
OUT_DIR = Path("/tmp/out").resolve(); OUT_DIR.mkdir(parents=True, exist_ok=True)

def _save_b64(data_b64: str, dest: Path):
    with open(dest, "wb") as f: f.write(base64.b64decode(data_b64))

def _download(url: str, dest: Path):
    with requests.get(url, stream=True, timeout=60) as r:
        r.raise_for_status()
        with open(dest, "wb") as f:
            for chunk in r.iter_content(8192):
                if chunk: f.write(chunk)

def _latest_mp4(directory: Path):
    files = sorted(directory.glob("*.mp4"), key=lambda p: p.stat().st_mtime, reverse=True)
    return files[0] if files else None

def ensure_models():
    """
    Download SadTalker checkpoints on first run if missing.
    Uses the repo's scripts/download_models.sh to fetch:
      - epoch_20.pth (face recon)
      - gfpgan/real-esrgan, wav2lip, hubert, etc.
    """
    ck = REPO_DIR / "checkpoints" / "epoch_20.pth"
    if ck.exists():
        return
    print("[init] downloading SadTalker checkpoints (one-time)…")
    cmd = 'cd /workspace/SadTalker && mkdir -p checkpoints && if [ -f scripts/download_models.sh ]; then bash scripts/download_models.sh; else echo "No script found"; fi'
    proc = subprocess.run(["bash", "-lc", cmd], capture_output=True, text=True, timeout=1800)
    print("[init] download_models stdout:\n", proc.stdout[-1000:])
    print("[init] download_models stderr:\n", proc.stderr[-2000:])
    if proc.returncode != 0 or not ck.exists():
        raise RuntimeError("Failed to download SadTalker checkpoints. See logs above.")

def _run_sadtalker(audio_path: Path, image_path: Path, work_dir: Path) -> Path:
    ensure_models()
    cmd = [
        "python", "inference.py",
        "--driven_audio", str(audio_path),
        "--source_image", str(image_path),
        "--result_dir", str(OUT_DIR),
        "--enhancer", "gfpgan",
        "--still",
        "--preprocess", "full"
    ]
    proc = subprocess.run(cmd, cwd=str(work_dir), capture_output=True, text=True, timeout=1800)
    if proc.returncode != 0:
        raise RuntimeError(f"SadTalker failed: {proc.stderr[:4000]}")
    out_mp4 = _latest_mp4(OUT_DIR)
    if not out_mp4:
        raise RuntimeError("SadTalker did not produce an MP4 in /tmp/out")
    return out_mp4

def handler(event):
    t0 = time.time()
    inp = event.get("input", {})
    audio_url, image_url = inp.get("audio_url"), inp.get("image_url")
    audio_b64, image_b64 = inp.get("audio_b64"), inp.get("image_b64")
    upload_url, public_video_url = inp.get("upload_url"), inp.get("video_url")

    if not ((audio_url or audio_b64) and (image_url or image_b64)):
        return {"ok": False, "error": "Provide audio_[url|b64] and image_[url|b64]."}

    uid = uuid.uuid4().hex[:8]
    a_path = OUT_DIR / f"{uid}_audio.wav"
    i_path = OUT_DIR / f"{uid}_image.jpg"

    try:
        _save_b64(audio_b64, a_path) if audio_b64 else _download(audio_url, a_path)
        _save_b64(image_b64, i_path) if image_b64 else _download(image_url, i_path)

        mp4_path = _run_sadtalker(a_path, i_path, REPO_DIR)

        if upload_url:
            with open(mp4_path, "rb") as f:
                put = requests.put(upload_url, data=f, headers={"Content-Type": "video/mp4"}, timeout=900)
                put.raise_for_status()
            return {"ok": True, "video_url": public_video_url, "elapsed_s": round(time.time() - t0, 2)}
        else:
            with open(mp4_path, "rb") as f:
                b64 = base64.b64encode(f.read()).decode()
            return {"ok": True, "video_b64": b64, "elapsed_s": round(time.time() - t0, 2)}
    except Exception as e:
        return {"ok": False, "error": str(e)}

if __name__ == "__main__":
    start({"handler": handler})
