FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

# non-interactive setup
ENV DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC
RUN apt-get update && apt-get install -y -q \
    git git-lfs ffmpeg wget curl tzdata \
 && ln -fs /usr/share/zoneinfo/$TZ /etc/localtime \
 && dpkg-reconfigure -f noninteractive tzdata \
 && rm -rf /var/lib/apt/lists/*

# work from /workspace so our files are importable
WORKDIR /workspace

# SadTalker clone + combined requirements install
COPY requirements.txt /workspace/requirements.txt
RUN git lfs install && \
    git clone --depth 1 https://github.com/OpenTalker/SadTalker.git && \
    /opt/conda/bin/pip install --no-cache-dir -r SadTalker/requirements.txt && \
    /opt/conda/bin/pip install --no-cache-dir -r /workspace/requirements.txt

# our code
COPY handler.py /workspace/handler.py
COPY ensure_models_patch.py /workspace/ensure_models_patch.py

# Final, forceful installation and verification of the runpod library
RUN /opt/conda/bin/pip install runpod && \
    /opt/conda/bin/python -c "import runpod; print('runpod library successfully verified')"

# expose HTTP and start uvicorn web server on port 8000
EXPOSE 8888
CMD ["/opt/conda/bin/python", "/workspace/handler.py"]