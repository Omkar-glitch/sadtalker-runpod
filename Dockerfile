FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

# prevent tzdata from asking questions during build
ENV DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC

RUN apt-get update && apt-get install -y -q \
    git git-lfs ffmpeg wget curl tzdata \
 && ln -fs /usr/share/zoneinfo/$TZ /etc/localtime \
 && dpkg-reconfigure -f noninteractive tzdata \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Shallow clone (faster) and install SadTalker deps
RUN git lfs install && \
    git clone --depth 1 https://github.com/OpenTalker/SadTalker.git && \
    cd SadTalker && pip install --no-cache-dir -r requirements.txt

# Worker deps only
COPY requirements.txt /workspace/requirements.txt
RUN pip install --no-cache-dir -r /workspace/requirements.txt

RUN pip install --no-cache-dir "numpy>=1.24,<2" "scipy<1.11"

# No model pre-download; they’ll fetch on first run
COPY handler.py /workspace/handler.py
COPY ensure_models_patch.py /workspace/ensure_models_patch.py

ENV PYTHONUNBUFFERED=1
WORKDIR /workspace/SadTalker
CMD ["python", "/workspace/handler.py"]
