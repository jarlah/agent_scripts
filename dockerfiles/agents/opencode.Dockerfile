FROM node:22-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g opencode-ai

# $HOME world-writable so bind mounts work when running with host uid/gid.
RUN chmod 777 /home/node \
    && mkdir -p /app && chown node:node /app

USER node
WORKDIR /app

CMD ["opencode", "run", "--dangerously-skip-permissions"]
