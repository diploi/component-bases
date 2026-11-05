# Diploi component bases

The base images Diploi's components are built on. A component's own `Dockerfile` starts `FROM` one of these and adds
only what is its own, so the runtime build contract lives in one place.

| Image                                                   | Folder    | Base             |
| ------------------------------------------------------- | --------- | ---------------- |
| `public.ecr.aws/p8t2q7f4/diploi/component-bases/node26` | `node/`   | `node:26-slim`   |
| `public.ecr.aws/p8t2q7f4/diploi/component-bases/python` | `python/` | uv on Debian     |

## What every base has

These are what a runtime-built component needs from its image (see "Runtime builds" in the Diploi docs):

- **`diploi-entrypoint`** (`shared/`). It runs the project's `initScript` from `diploi.yaml` as root, then the
  command as uid 1000. A container that starts as another user runs the command as it is.
- **`su-exec`**, which the entrypoint and core's build script use to drop to uid 1000.
- **`curl`**, which a build uses to wait for the components it imports from.

## Node.js

- Node.js 26 (LTS), with corepack, pnpm and Bun, and the same pnpm settings as the devpod.
- **`diploi-pm`** runs the project's package manager: the one `packageManager` in `package.json` names, or else the
  one its lockfile belongs to (Bun, pnpm, Yarn, then npm). corepack runs the pnpm or Yarn version the project names.
  `diploi-pm install` installs from the lockfile and falls back to a plain install when the lockfile is out of date.
  Any other arguments go to the package manager as they are, as in `diploi-pm run build`.

A component's `Dockerfile` then needs little more than this:

```dockerfile
FROM public.ecr.aws/p8t2q7f4/diploi/component-bases/node26:v1
CMD ["npm", "run", "dev", "--", "--host"]
```

Its `diploi.yaml` builds with `diploi-pm`:

```yaml
build:
  command: diploi-pm install && NODE_ENV=production diploi-pm run build
```

## Python

- [uv](https://docs.astral.sh/uv/) and no Python. uv downloads the version a project asks for when it installs, so any
  version works and there is one image for all of them.
- **`diploi-pm install`** creates `.venv` in the project's Python version: the one `.python-version` names, else
  `PYTHON_VERSION`, else 3.12. It installs with `uv sync`, from the lockfile when it can, or from `requirements.txt` in
  a project without a `pyproject.toml`. Options go to `uv sync`, as in `diploi-pm install --no-dev`. Anything else goes
  to uv as it is, as in `diploi-pm add requests`.

A component's `Dockerfile` then needs little more than this:

```dockerfile
FROM public.ecr.aws/p8t2q7f4/diploi/component-bases/python:v1
```

Its `diploi.yaml` installs with `diploi-pm`. Compiling the bytecode here matters, because the app cannot write it later
into the read-only build folder:

```yaml
build:
  command: UV_COMPILE_BYTECODE=1 diploi-pm install --no-dev
  waitForImports: false
```

Besides what every chart does (below), a Python chart sets two env vars:

- `UV_PYTHON_INSTALL_DIR` to `/app{{ .Values.folder }}/.python` on the containers that install and the app. `.venv` links
  to that Python, so it has to be in the project folder: the build container's disk is gone after the build, and in
  development the devpod uses the same `.venv`.
- `PATH` on the app container, with `/app{{ .Values.folder }}/.venv/bin` first, so start commands and terminals find the
  project's `python` and tools. The base image cannot know the folder.

## Charts

The entrypoint has to start as root to run `initScript`, so a component's chart:

- sets no `runAsUser` for the pod;
- sets `args`, never `command`, on containers that use the image, so the entrypoint runs;
- sets `allowPrivilegeEscalation: false` on every container (`su-exec` only drops privileges, so it keeps working);
- takes the port of its own host from `.Values.ports`, found by identifier (the port the Service sends to, also when a
  project changes it), and uses it for `containerPort`, a TCP `readinessProbe` in staging and production, and a `PORT`
  env var set last, which the start commands and the dev server listen on;
- annotates the pod with `diploi.com/exec-user: "1000:1000"`, so terminals and `diploi exec` log in as the app's user
  instead of the root the container starts as;
- mounts the build folder read-only in the app container in staging and production.

## Releasing

Every push builds the images. A branch is tagged with its name and a git tag with the tag, so a pushed git tag `v1`
publishes `node26:v1`. Components use the major tag: a compatible change moves `v1` and reaches a component at its
next image build, a breaking one gets `v2`, which components move to on purpose.

A new image needs its ECR Public repository (`diploi/component-bases/<identifier>`) before its first push, and an
entry in the matrix of `.github/workflows/Build.yaml`. Another Node major is one more entry with its `NODE_VERSION`;
the Bun version is `BUN_VERSION` in `node/Dockerfile`, and the uv version is `UV_VERSION` in `python/Dockerfile`.

## Tests

`sh node/diploi-pm.test.sh` checks which package manager `diploi-pm` picks and what it runs, and
`sh python/diploi-pm.test.sh` checks which Python version it asks for and what it runs. The workflow runs both before
the builds.
