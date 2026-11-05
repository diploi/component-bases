# syntax=docker/dockerfile:1
# The toolchain every Python component runs in, in every stage. A component starts FROM this and adds only what is its
# own. The image has no Python: uv downloads the version a project asks for when it installs (diploi-pm), so any version
# works and every stage goes the same way. Built with the repository root as the context
ARG UV_VERSION=0.13.7
FROM ghcr.io/astral-sh/uv:${UV_VERSION}-trixie-slim

# su-exec (gosu here) drops to uid 1000 after the work that needs root, and curl lets a build wait for the components
# it depends on
RUN apt-get update \
    && apt-get install -y --no-install-recommends gosu curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s "$(command -v gosu)" /usr/local/bin/su-exec

# The base image has no uid 1000: uv keeps its cache in this home, and terminals get a named user
RUN useradd --uid 1000 --create-home app

# The cache and a project's .venv are on different disks, so uv cannot link between them
ENV UV_LINK_MODE=copy

COPY --chmod=755 python/diploi-pm /usr/local/bin/diploi-pm
COPY --chmod=755 shared/diploi-entrypoint /usr/local/bin/diploi-entrypoint
ENTRYPOINT ["diploi-entrypoint"]
