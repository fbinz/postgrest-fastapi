FROM python:3.10-slim-bullseye

# Install tini (init process for docker container)
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

# Run as non-root
RUN useradd --create-home user
USER user

# Add local pip to PATH and export to profile, so that it's picked up by shells
ENV PATH=/home/user/.local/bin:$PATH
RUN pip install --upgrade pip
RUN echo "PATH=$PATH" >> /home/user/.profile

# Install and configure poetry
RUN pip install 'poetry==1.1.13'

WORKDIR /home/user/app
COPY pyproject.toml poetry.lock ./

COPY . .
RUN pip install .

ENTRYPOINT ["/tini", "--"]
CMD ["./scripts/run_backend.sh"]
