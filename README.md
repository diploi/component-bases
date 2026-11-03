# Diploi component bases

The base images Diploi's components are built on. A component's own `Dockerfile` starts `FROM` one of these and adds
only what is its own, so the runtime build contract lives in one place.

| Image                                                   | Folder    | Base             |
| ------------------------------------------------------- | --------- | ---------------- |
| `public.ecr.aws/p8t2q7f4/diploi/component-bases/node26` | `node/`   | `node:26-slim`   |

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
FROM public.ecr.aws/p8t2q7f4/diploi/component-bases/node26:v1.0.0
CMD ["npm", "run", "dev", "--", "--host"]
```

Its `diploi.yaml` builds with `diploi-pm`:

```yaml
build:
  command: diploi-pm install && NODE_ENV=production diploi-pm run build
```

## Charts

The entrypoint has to start as root to run `initScript`, so a component's chart:

- sets no `runAsUser` for the pod;
- sets `args`, never `command`, on containers that use the image, so the entrypoint runs;
- sets `allowPrivilegeEscalation: false` on every container (`su-exec` only drops privileges, so it keeps working);
- mounts the build folder read-only in the app container in staging and production.

## Releasing

Every push builds the images. A branch is tagged with its name and a git tag with the tag, so `git tag v1.1.0` and a
push of it publish `node26:v1.1.0`. Components pin an exact tag, and a base change reaches a component when it moves
to the new tag.

A new image needs its ECR Public repository (`diploi/component-bases/<identifier>`) before its first push, and an
entry in the matrix of `.github/workflows/Build.yaml`. Another Node major is one more entry with its `NODE_VERSION`;
the Bun version is `BUN_VERSION` in `node/Dockerfile`.

## Tests

`sh node/diploi-pm.test.sh` checks which package manager `diploi-pm` picks and what it runs. The workflow runs it
before the builds.
