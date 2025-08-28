# Final attempt: Combine all successful fixes into one Dockerfile.

# 1. Base image with a compatible CUDA version
FROM nvidia/cuda:11.3.1-cudnn8-devel-ubuntu20.04

# 2. Set timezone and non-interactive frontend to prevent prompts
ENV TZ=Etc/UTC
ENV DEBIAN_FRONTEND=noninteractive

# 3. Install Python 3.8 using the deadsnakes PPA
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    echo -ne '\n' | add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y -q python3.8 python3.8-pip python3-pip git git-lfs ffmpeg wget && \
    rm -rf /var/lib/apt/lists/*

# 4. Make python3.8 the default python
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.8 1

# 5. Set working directory
WORKDIR /workspace

# 6. Clone the stable v0.0.2 release of SadTalker
RUN git lfs install && \
    git clone --branch v0.0.2 --single-branch https://github.com/OpenTalker/SadTalker.git

# 7. Install PyTorch version required by SadTalker v0.0.2
RUN python -m pip install torch==1.12.1+cu113 torchvision==0.13.1+cu113 torchaudio==0.12.1 --extra-index-url https://download.pytorch.org/whl/cu113

# 8. Patch SadTalker's requirements and then install them
RUN sed -i 's/numpy==1.23.4/numpy/g' /workspace/SadTalker/requirements.txt && \
    python -m pip install -r /workspace/SadTalker/requirements.txt

# 9. Patch the numpy.float error in the installed dependency
RUN find / -type f -name "my_awing_arch.py" -exec sed -i 's/np.float/float/g' {} +

# 10. Copy and install our own requirements
COPY requirements.txt /workspace/requirements.txt
RUN python -m pip install -r /workspace/requirements.txt

# 11. Force-install runpod library as the final step
RUN python -m pip install runpod

# 12. Copy our handler code
COPY handler.py /workspace/handler.py

# 13. Set the command to run our handler
CMD ["python", "/workspace/handler.py"]