# syntax=docker/dockerfile:1
# The toolchain every Node.js component runs in, in every stage. A component starts FROM this and adds only what is
# its own, such as a global CLI and its dev command. Built with the repository root as the context, once per Node
# major in the workflow's matrix
ARG NODE_VERSION=26
ARG BUN_VERSION=1.4.4
FROM oven/bun:${BUN_VERSION} AS bun
FROM node:${NODE_VERSION}-slim

# su-exec (gosu here) drops to uid 1000 after the work that needs root, and curl lets a build wait for the components
# it depends on
RUN apt-get update \
    && apt-get install -y --no-install-recommends gosu curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s "$(command -v gosu)" /usr/local/bin/su-exec

ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
# corepack runs the pnpm or Yarn version a project's packageManager names. Node.js stopped shipping it in version 25,
# and its npm package brings the pnpm and yarn commands with it
RUN npm install -g corepack@0.36.0

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PNPM_HOME/bin:$PATH"
RUN mkdir -p /home/codespace/.pnpm-store /pnpm \
    && chown -R 1000:1000 /home/codespace/.pnpm-store /pnpm

COPY --from=bun /usr/local/bin/bun /usr/local/bin/bun

# The same package manager settings as the devpod
ENV NODE_ENV=development
ENV CI=true
ENV PNPM_CONFIG_NODE_LINKER=hoisted
ENV PNPM_CONFIG_MINIMUM_RELEASE_AGE=0
ENV PNPM_CONFIG_STRICT_DEP_BUILDS=false
ENV PNPM_CONFIG_CONFIRM_MODULES_PURGE=false
USER 1000:1000
RUN pnpm config set store-dir /home/codespace/.pnpm-store --global
USER root

COPY --chmod=755 node/diploi-pm /usr/local/bin/diploi-pm
COPY --chmod=755 shared/diploi-entrypoint /usr/local/bin/diploi-entrypoint
ENTRYPOINT ["diploi-entrypoint"]
