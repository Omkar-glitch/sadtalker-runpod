# Base image with correct PyTorch, CUDA, and Python for SadTalker v0.0.2
FROM pytorch/pytorch:1.12.1-cuda11.3-cudnn8-runtime

# Install git and ffmpeg
RUN apt-get update && apt-get install -y -q git git-lfs ffmpeg && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Clone the stable v0.0.2 release of SadTalker
RUN git lfs install && \
    git clone --branch v0.0.2 --single-branch https://github.com/OpenTalker/SadTalker.git

# Diagnostic step to find the correct path for the patch
RUN ls -R /workspace/SadTalker

# Modify SadTalker's requirements to remove numpy version pin, then install
RUN sed -i 's/numpy==1.23.4/numpy/g' /workspace/SadTalker/requirements.txt && \
    pip install -r /workspace/SadTalker/requirements.txt

# Patch the numpy.float error in SadTalker source
RUN sed -i 's/np.float/float/g' /workspace/SadTalker/src/face3d/util/my_awing_arch.py

# Copy and install our own requirements
COPY requirements.txt /workspace/requirements.txt
RUN pip install -r /workspace/requirements.txt

# Force-install runpod library as the final step
RUN pip install runpod

# Copy our handler code
COPY handler.py /workspace/handler.py

# Set the command to run our handler
CMD ["python", "/workspace/handler.py"]