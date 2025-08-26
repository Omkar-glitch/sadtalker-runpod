FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

RUN apt-get update && apt-get install -y \
    git git-lfs ffmpeg wget curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

RUN git lfs install && \
    git clone https://github.com/OpenTalker/SadTalker.git && \
    cd SadTalker && pip install --no-cache-dir -r requirements.txt

COPY requirements.txt /workspace/requirements.txt
RUN pip install --no-cache-dir -r /workspace/requirements.txt

RUN bash -lc 'cd /workspace/SadTalker && \
    if [ -f scripts/download_models.sh ]; then bash scripts/download_models.sh || true; fi'

COPY handler.py /workspace/handler.py

ENV PYTHONUNBUFFERED=1
WORKDIR /workspace/SadTalker
CMD ["python", "/workspace/handler.py"]
