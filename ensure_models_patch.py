from pathlib import Path
import subprocess, json, os

REPO_DIR = Path("/workspace/SadTalker").resolve()

def robust_download(path: Path, urls):
    """Try each URL until one succeeds; raise with detailed message if all fail."""
    path.parent.mkdir(parents=True, exist_ok=True)
    errs = []
    for url in urls:
        cmd = ["bash","-lc", f"curl -fL --retry 5 --retry-all-errors -A 'curl/7 RunPod' -o '{path}' '{url}'"]
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        if path.exists() and path.stat().st_size > 1024:  # sanity
            return True
        errs.append({"url": url, "rc": proc.returncode, "stderr_tail": proc.stderr[-400:], "stdout_tail": proc.stdout[-200:]})
    raise RuntimeError("All mirrors failed for "+str(path)+": "+json.dumps(errs))

def ensure_models_verbose():
    """
    1) Try SadTalker script (fast path).
    2) If still missing, fetch exact files from multiple mirrors (GitHub Releases + HuggingFace).
    """
    ck = (REPO_DIR / "checkpoints").resolve()
    gf = (REPO_DIR / "gfpgan" / "weights").resolve()
    ck.mkdir(parents=True, exist_ok=True)
    gf.mkdir(parents=True, exist_ok=True)

    # 1) Try the repo script first (it pulls many deps at once)
    script = REPO_DIR / "scripts" / "download_models.sh"
    if script.exists():
        proc = subprocess.run(["bash","-lc", f"cd '{REPO_DIR}' && bash scripts/download_models.sh"],
                              capture_output=True, text=True, timeout=1800)
        # don't fail immediately; we'll validate below

    # 2) Ensure the specific files we need exist; if not, pull them with mirrors.
    need = {
        ck / "epoch_20.pth": [
            # mirrors (order matters)
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

    missing = [p for p in need.keys() if not (p.exists() and p.stat().st_size > 1024)]
    if not missing:
        return  # all present from script

    # fetch missing via mirrors
    for p in missing:
        robust_download(p, need[p])
