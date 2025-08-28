# Base image with correct CUDA version for SadTalker v0.0.2
FROM nvidia/cuda:11.3.1-cudnn8-devel-ubuntu20.04

# Set non-interactive frontend for package installers
ENV DEBIAN_FRONTEND=noninteractive

# Install Python 3.8, pip, git, and ffmpeg
RUN apt-get update && apt-get install -y software-properties-common && add-apt-repository ppa:deadsnakes/ppa && apt-get update && apt-get install -y -q python3.8 python3.8-pip python3-pip git git-lfs ffmpeg wget && rm -rf /var/lib/apt/lists/*

# Update alternatives to make python3.8 the default python
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.8 1

# Set working directory
WORKDIR /workspace

# Clone the stable v0.0.2 release of SadTalker
RUN git lfs install && \
    git clone --branch v0.0.2 --single-branch https://github.com/OpenTalker/SadTalker.git

# Install PyTorch version required by SadTalker v0.0.2
RUN python -m pip install torch==1.12.1+cu113 torchvision==0.13.1+cu113 torchaudio==0.12.1 --extra-index-url https://download.pytorch.org/whl/cu113

# Install SadTalker's requirements
RUN python -m pip install -r /workspace/SadTalker/requirements.txt

# Patch the numpy.float error in SadTalker source
RUN sed -i 's/np.float/float/g' /workspace/SadTalker/src/face3d/util/my_awing_arch.py

# Copy and install our own requirements
COPY requirements.txt /workspace/requirements.txt
RUN python -m pip install -r /workspace/requirements.txt

# Force-install runpod library as the final step
RUN python -m pip install runpod

# Copy our handler code
COPY handler.py /workspace/handler.py

# Set the command to run our handler
CMD ["python", "/workspace/handler.py"]
