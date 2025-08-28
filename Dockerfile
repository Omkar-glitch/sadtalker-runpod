# Final Dockerfile based on extensive debugging and research

# 1. Use the Pytorch image that we know builds successfully.
FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

# 2. Set timezone to prevent interactive prompts
ENV TZ=Etc/UTC
ENV DEBIAN_FRONTEND=noninteractive

# 3. Install all necessary system packages, including curl.
RUN apt-get update && apt-get install -y -q git git-lfs ffmpeg curl && rm -rf /var/lib/apt/lists/*

# 4. Set working directory
WORKDIR /workspace

# 5. Clone the main branch of SadTalker, which is compatible with this environment
RUN git lfs install && \
    git clone https://github.com/OpenTalker/SadTalker.git

# 6. Install all Python requirements from both files
COPY requirements.txt /workspace/requirements.txt
RUN pip install -r /workspace/SadTalker/requirements.txt && \
    pip install -r /workspace/requirements.txt

# 7. Patch 1: Fix the numpy.float error by finding the file and replacing the deprecated alias.
RUN find /opt/conda/lib -type f -name "my_awing_arch.py" -exec sed -i "s/np.float/float/g" {} +

# 8. Patch 2: Fix the ValueError by finding the file and adding dtype=object to the numpy array creation.
RUN find /opt/conda/lib -type f -name "preprocess.py" -exec sed -i "s/trans_params = np.array(\[w0, h0, s, t\[0\], t\[1\]\])/trans_params = np.array([w0, h0, s, t[0], t[1]], dtype=object)/g" {} +

# 9. Force-install runpod library as the final step to ensure it is present.
RUN pip install runpod

# 10. Copy our handler code
COPY handler.py /workspace/handler.py

# 11. Set the command to run our handler
CMD ["python", "/workspace/handler.py"]