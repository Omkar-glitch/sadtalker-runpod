# Base image with a compatible CUDA version
FROM nvidia/cuda:11.3.1-cudnn8-devel-ubuntu20.04

# Set timezone and non-interactive frontend to prevent prompts
ENV TZ=Etc/UTC
ENV DEBIAN_FRONTEND=noninteractive

# Install Python 3.8, pip, git, and ffmpeg from the standard repositories
RUN apt-get update && \
    apt-get install -y -q python3.8 python3-pip git git-lfs ffmpeg && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Clone the stable v0.0.2 release of SadTalker
RUN git lfs install && \
    git clone --branch v0.0.2 --single-branch https://github.com/OpenTalker/SadTalker.git

# Install PyTorch version required by SadTalker v0.0.2
RUN python3 -m pip install torch==1.12.1+cu113 torchvision==0.13.1+cu113 torchaudio==0.12.1 --extra-index-url https://download.pytorch.org/whl/cu113

# Modify SadTalker's requirements to remove numpy version pin, then install
RUN sed -i 's/numpy==1.23.4/numpy/g' /workspace/SadTalker/requirements.txt && \
    python3 -m pip install -r /workspace/SadTalker/requirements.txt

# Patch the numpy.float error in the installed dependency
RUN find /usr/local/lib -type f -name "my_awing_arch.py" -exec sed -i 's/np.float/float/g' {} +

# Copy and install our own requirements
COPY requirements.txt /workspace/requirements.txt
RUN python3 -m pip install -r /workspace/requirements.txt

# Force-install runpod library as the final step
RUN python3 -m pip install runpod

# Copy our handler code
COPY handler.py /workspace/handler.py

# Set the command to run our handler
CMD ["python3", "/workspace/handler.py"]
