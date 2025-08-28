# 1. Use RunPod's official base image for compatibility
FROM runpod/base:0.5.5-cuda11.8-runtime

# 2. Install OS packages
ENV DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC
RUN apt-get update &&     apt-get install -y --no-install-recommends git git-lfs ffmpeg curl &&     apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. Set the working directory
WORKDIR /workspace

# 4. Clone a known-stable version of SadTalker
RUN git lfs install &&     git clone --depth 1 --branch v0.0.2 https://github.com/OpenTalker/SadTalker.git

# 5. Install pinned Python dependencies to create a stable environment
COPY requirements.txt /workspace/requirements.txt
RUN pip install --upgrade pip==23.3.1 &&     pip install numpy==1.23.5 face-alignment==1.3.4 &&     pip install -r /workspace/SadTalker/requirements.txt &&     pip install -r /workspace/requirements.txt &&     pip install runpod==1.2.0

# 6. Download checkpoints at build time for faster startups
RUN mkdir -p /workspace/SadTalker/checkpoints &&     curl -L -o /workspace/SadTalker/checkpoints/wav2lip.pth          https://huggingface.co/innnky/sadtalker/resolve/main/wav2lip.pth &&     curl -L -o /workspace/SadTalker/checkpoints/auido2pose.pth          https://huggingface.co/innnky/sadtalker/resolve/main/auido2pose.pth &&     curl -L -o /workspace/SadTalker/checkpoints/mapping.pth          https://huggingface.co/innnky/sadtalker/resolve/main/mapping_00109-model.pth

# 7. Copy our handler code
COPY handler.py /workspace/handler.py

# 8. Set the runtime command
CMD ["python", "handler.py"]