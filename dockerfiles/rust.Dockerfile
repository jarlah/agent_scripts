FROM claude-code-base

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl build-essential pkg-config libssl-dev \
        libasound2-dev libudev-dev \
        libwayland-dev libxkbcommon-dev \
        libx11-dev libxcursor-dev libxi-dev libxrandr-dev \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.cargo/bin:${PATH}"
