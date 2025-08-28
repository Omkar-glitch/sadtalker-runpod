# Go back to the Pytorch image that we know builds successfully.
FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

# Set timezone to prevent interactive prompts
ENV TZ=Etc/UTC
ENV DEBIAN_FRONTEND=noninteractive

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

# Patch 1: Fix the numpy.float error
RUN find /opt/conda/lib -type f -name "my_awing_arch.py" -exec sed -i 's/np.float/float/g' {} +

# Patch 2: Fix the ValueError by ensuring the array elements are scalars
RUN find /opt/conda/lib -type f -name "preprocess.py" -exec sed -i 's/trans_params = np.array(\[w0, h0, s, t\[0\]\])/trans_params = np.array([w0, h0, s.item(), t[0].item(), t[1].item()])/g' {} +

# Force-install runpod library as the final step
RUN pip install runpod

# Copy our handler code
COPY handler.py /workspace/handler.py

# Set the command to run our handler
CMD ["python", "/workspace/handler.py"]