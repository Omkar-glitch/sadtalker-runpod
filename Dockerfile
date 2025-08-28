# Final, most robust Dockerfile

# 1. Start from the correct CUDA base image
FROM nvidia/cuda:11.3.1-cudnn8-devel-ubuntu20.04

# 2. Set timezone and non-interactive frontend
ENV TZ=Etc/UTC
ENV DEBIAN_FRONTEND=noninteractive

# 3. Install system dependencies and add PPA for Python 3.8
RUN apt-get update && \
    apt-get install -y software-properties-common wget git git-lfs ffmpeg && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update

# 4. Install Python 3.8
RUN apt-get install -y python3.8

# 5. Install pip for Python 3.8 manually
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3.8 get-pip.py

# 6. Make python3.8 the default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.8 1

# 7. Set working directory
WORKDIR /workspace

# 8. Clone the stable v0.0.2 release of SadTalker
RUN git lfs install && \
    git clone --branch v0.0.2 --single-branch https://github.com/OpenTalker/SadTalker.git

# 9. Install the specific PyTorch version for this release
RUN pip install torch==1.12.1+cu113 torchvision==0.13.1+cu113 torchaudio==0.12.1 --extra-index-url https://download.pytorch.org/whl/cu113

# 10. Patch SadTalker's requirements and then install them
RUN sed -i 's/numpy==1.23.4/numpy/g' /workspace/SadTalker/requirements.txt && \
    pip install -r /workspace/SadTalker/requirements.txt

# 11. Patch the numpy.float error in the installed dependency
RUN find /usr/local/lib -type f -name "my_awing_arch.py" -exec sed -i 's/np.float/float/g' {} +

# 12. Copy and install our own requirements
COPY requirements.txt /workspace/requirements.txt
RUN pip install -r /workspace/requirements.txt

# 13. Install runpod
RUN pip install runpod

# 14. Copy our handler code
COPY handler.py /workspace/handler.py

# 15. Set the final command to run our handler
CMD ["python", "/workspace/handler.py"]
