import base64, os, time, uuid, subprocess
from pathlib import Path
import requests
try:
    from runpod.serverless import start
except Exception:
    start = None

# --------------------------------------------------------------------------------
# Config / Paths
# --------------------------------------------------------------------------------
REPO_DIR = Path("/workspace/SadTalker").resolve()
OUT_DIR = Path("/tmp/out").resolve(); OUT_DIR.mkdir(parents=True, exist_ok=True)

# --------------------------------------------------------------------------------
# Utils
# --------------------------------------------------------------------------------
def _save_b64(data_b64: str, dest: Path):
    with open(dest, "wb") as f:
        f.write(base64.b64decode(data_b64))

def _download(url: str, dest: Path):
    with requests.get(url, stream=True, timeout=120) as r:
        r.raise_for_status()
        with open(dest, "wb") as f:
            for chunk in r.iter_content(1024 * 512):
                if chunk:
                    f.write(chunk)

def _latest_mp4(directory: Path):
    files = sorted(directory.glob("*.mp4"), key=lambda p: p.stat().st_mtime, reverse=True)
    return files[0] if files else None

# --------------------------------------------------------------------------------
# Robust model downloader (inline, no external module)
# --------------------------------------------------------------------------------
def _robust_download(path: Path, urls):
    path.parent.mkdir(parents=True, exist_ok=True)
    errs = []
    for url in urls:
        cmd = ["bash","-lc", f"curl -fL --retry 5  -o '{path}' '{url}'"]
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        if path.exists() and path.stat().st_size > 1024:
            return
        errs.append({"url": url, "rc": proc.returncode,
                     "stderr_tail": proc.stderr[-400:], "stdout_tail": proc.stdout[-200:]})
    raise RuntimeError(f"All mirrors failed for {path}: {errs}")

def ensure_models():
    """
    Ensure SadTalker checkpoints exist. Try the repo script; then fetch specific
    files from GitHub Releases and Hugging Face mirrors.
    """
    ck = (REPO_DIR / "checkpoints").resolve(); ck.mkdir(parents=True, exist_ok=True)
    gf = (REPO_DIR / "gfpgan" / "weights").resolve(); gf.mkdir(parents=True, exist_ok=True)

    # 1) Fast path: try the repo script
    script = REPO_DIR / "scripts" / "download_models.sh"
    if script.exists():
        subprocess.run(
            ["bash","-lc", f"cd '{REPO_DIR}' && bash scripts/download_models.sh"],
            capture_output=True, text=True, timeout=1800
        )

    # 2) Ensure specific files exist; if missing, pull via mirrors.
    need = {
        ck / "epoch_20.pth": [
            "https://github.com/Winfredy/SadTalker/releases/download/v0.0.2/epoch_20.pth",
            "https://huggingface.co/Winfredy/SadTalker/resolve/main/checkpoints/epoch_20.pth?download=true",
        ],
        ck / "mapping_00109-model.pth.tar": [
            "https://github.com/OpenTalker/SadTalker/releases/download/v0.0.2-rc/mapping_00109-model.pth.tar",
            "https://huggingface.co/Winfredy/SadTalker/resolve/main/checkpoints/mapping_00109-model.pth.tar?download=true",
        ],
        ck / "mapping_00229-model.pth.tar": [
            "https://github.com/OpenTalker/SadTalker/releases/download/v0.0.2-rc/mapping_00229-model.pth.tar",
            "https://huggingface.co/Winfredy/SadTalker/resolve/main/checkpoints/mapping_00229-model.pth.tar?download=true",
        ],
        ck / "SadTalker_V0.0.2_256.safetensors": [
            "https://github.com/OpenTalker/SadTalker/releases/download/v0.0.2-rc/SadTalker_V0.0.2_256.safetensors",
            "https://huggingface.co/Winfredy/SadTalker/resolve/main/checkpoints/SadTalker_V0.0.2_256.safetensors?download=true",
        ],
        gf / "alignment_WFLW_4HG.pth": [
            "https://github.com/xinntao/facexlib/releases/download/v0.1.0/alignment_WFLW_4HG.pth",
            "https://huggingface.co/Winfredy/SadTalker/resolve/main/gfpgan/weights/alignment_WFLW_4HG.pth?download=true",
        ],
        gf / "detection_Resnet50_Final.pth": [
            "https://github.com/xinntao/facexlib/releases/download/v0.1.0/detection_Resnet50_Final.pth",
            "https://huggingface.co/Winfredy/SadTalker/resolve/main/gfpgan/weights/detection_Resnet50_Final.pth?download=true",
        ],
        gf / "GFPGANv1.4.pth": [
            "https://github.com/TencentARC/GFPGAN/releases/download/v1.3.0/GFPGANv1.4.pth",
            "https://huggingface.co/Winfredy/SadTalker/resolve/main/gfpgan/weights/GFPGANv1.4.pth?download=true",
        ],
    }

    missing = [p for p in need if not (p.exists() and p.stat().st_size > 1024)]
    for p in missing:
        print(f"[init] downloading {p.name} …")
        _robust_download(p, need[p])
    print("[init] checkpoints present ✔")

# --------------------------------------------------------------------------------
# Inference
# --------------------------------------------------------------------------------
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
        raise RuntimeError(f"SadTalker failed: \n{proc.stderr[-4000:]}")
    out_mp4 = _latest_mp4(OUT_DIR)
    if not out_mp4:
        raise RuntimeError("SadTalker did not produce an MP4 in /tmp/out")
    return out_mp4

# --------------------------------------------------------------------------------
# RunPod handler
# --------------------------------------------------------------------------------
def handler(event):
    t0 = time.time()
    inp = (event or {}).get("input", {}) or {}
    audio_url, image_url = inp.get("audio_url"), inp.get("image_url")
    audio_b64, image_b64 = inp.get("audio_b64"), inp.get("image_b64")
    upload_url, public_video_url = inp.get("upload_url"), inp.get("video_url")

    if not ((audio_url or audio_b64) and (image_url or image_b64)):
        return {"ok": False, "error": "Provide audio_[url|b64] and image_[url|b64]."}

    uid = uuid.uuid4().hex[:8]
    a_path = OUT_DIR / f"{uid}_audio.wav"
    i_path = OUT_DIR / f"{uid}_image.jpg"

    try:
        if audio_b64: _save_b64(audio_b64, a_path)
        else: _download(audio_url, a_path)

        if image_b64: _save_b64(image_b64, i_path)
        else: _download(image_url, i_path)

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
    if start is not None:
        start({"handler": handler})
