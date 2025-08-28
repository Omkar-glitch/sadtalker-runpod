# Base image that we know is compatible with our requirements
FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

# Install git and ffmpeg
RUN apt-get update && apt-get install -y -q git git-lfs ffmpeg && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Clone the main branch of SadTalker
RUN git lfs install && \
    git clone https://github.com/OpenTalker/SadTalker.git

# Install all requirements
COPY requirements.txt /workspace/requirements.txt
RUN pip install -r /workspace/SadTalker/requirements.txt && \
    pip install -r /workspace/requirements.txt

# Patch the numpy.float error by finding the file in the installed packages
RUN find /opt/conda/lib -type f -name "my_awing_arch.py" -exec sed -i 's/np.float/float/g' {} +

# Force-install runpod library as the final step to ensure it is present
RUN pip install runpod

# Copy our handler code
COPY handler.py /workspace/handler.py

# Set the command to run our handler
CMD ["python", "/workspace/handler.py"]
