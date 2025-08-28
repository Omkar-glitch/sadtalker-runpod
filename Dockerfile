# 1. Base image with a compatible CUDA version
FROM nvidia/cuda:11.7.1-cudnn8-devel-ubuntu22.04

# 2. Set environment variables to prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# 3. Install system dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    git git-lfs wget curl build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev \
    libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev ffmpeg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 4. Create a non-root user
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:${PATH}
WORKDIR ${HOME}/app

# 5. Install pyenv to manage python versions
RUN curl https://pyenv.run | bash
ENV PATH=${HOME}/.pyenv/shims:${HOME}/.pyenv/bin:${PATH}
ENV PYTHON_VERSION=3.10.9

# 6. Install the correct python version and set it as global
RUN pyenv install ${PYTHON_VERSION} && \
    pyenv global ${PYTHON_VERSION} && \
    pip install --no-cache-dir -U pip setuptools wheel

# 7. Install a compatible PyTorch version
RUN pip install --no-cache-dir -U torch==1.12.1 torchvision==0.13.1

# 8. Clone the main branch of SadTalker
RUN git lfs install && \
    git clone https://github.com/OpenTalker/SadTalker.git

# 9. Install SadTalker's requirements
RUN pip install -r ${HOME}/app/SadTalker/requirements.txt

# 10. Apply our known patches to the installed libraries
RUN find ${HOME}/.pyenv/versions/${PYTHON_VERSION} -type f -name "my_awing_arch.py" -exec sed -i "s/np.float/float/g" {} +
RUN find ${HOME}/.pyenv/versions/${PYTHON_VERSION} -type f -name "preprocess.py" -exec sed -i "s/trans_params = np.array(\[w0, h0, s, t\[0\], t\[1\]\])/trans_params = np.array([w0, h0, s, t[0], t[1]], dtype=object)/g" {} +

# 11. Copy and install our own requirements
COPY --chown=user requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# 12. Install runpod
RUN pip install runpod

# 13. Copy our handler code
COPY --chown=user handler.py ${HOME}/app/handler.py

# 14. Set the final command to run our handler
CMD ["python", "handler.py"]
