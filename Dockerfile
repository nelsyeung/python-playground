FROM ubuntu:24.04 AS base
RUN apt-get --assume-yes update && \
    apt-get --assume-yes upgrade && \
    apt-get install --assume-yes --no-install-recommends \
        ca-certificates=20240203 \
        curl=8.5.0* \
        sudo=1.9.15* && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    usermod --append --groups sudo ubuntu && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
USER ubuntu
WORKDIR /workdir
COPY --from=ghcr.io/astral-sh/uv:0.11.3 /uv /uvx /bin/
COPY README.md pyproject.toml uv.lock ./
COPY src ./src
COPY --chmod=755 <<EOF /entrypoint.sh
#!/bin/bash
. .venv/bin/activate
exec "\$@"
EOF

RUN uv sync --locked --no-cache --no-dev --python 3.10
ENTRYPOINT ["/entrypoint.sh"]

FROM base AS vim
USER root
COPY --from=hadolint/hadolint:v2.14.0-alpine /bin/hadolint /bin/
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    apt-get install --assume-yes --no-install-recommends \
        git=1:2.43.0* \
        nodejs=24.13.0* \
        vim-gtk3=2:9.1.0016* && \
    npm install --global markdownlint-cli2@"0.22.0"
USER ubuntu
RUN uv sync --locked && \
    mkdir ~/.config
# The SHELL environment variable must match CMD. By default, running /bin/bash
# only sets SHELL for that process and does not export it, so subprocesses (like
# Vim or Python) may not see the correct SHELL. Explicitly setting ENV SHELL
# ensures consistency across subprocesses.
ENV SHELL=/bin/bash
CMD ["/bin/bash"]
