#!/bin/sh
# Which package manager diploi-pm picks and what it runs, with stand-ins that print their arguments.
# Run with `sh node24/diploi-pm.test.sh`
set -eu
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir "$work/bin"
for pm in bun pnpm yarn npm; do
  cat > "$work/bin/$pm" <<STUB
#!/bin/sh
echo "$pm \$*"
case "\$*" in *--frozen-lockfile*|ci) [ -z "\${FROZEN_FAILS:-}" ] ;; esac
STUB
  chmod +x "$work/bin/$pm"
done

# pm "<files in the project>" <diploi-pm arguments...>
pm() {
  project=$(mktemp -d "$work/project.XXXXXX")
  for file in $1; do touch "$project/$file"; done
  if [ -n "${PACKAGE_JSON:-}" ]; then echo "$PACKAGE_JSON" > "$project/package.json"; fi
  shift
  (cd "$project" && PATH="$work/bin:$PATH" sh "$here/diploi-pm" "$@")
}

expect() {
  if [ "$1" != "$2" ]; then
    printf 'FAIL\nexpected: %s\ngot:      %s\n' "$2" "$1"
    exit 1
  fi
}

expect "$(pm 'package.json bun.lock' install)" "bun install --frozen-lockfile"
expect "$(pm 'package.json bun.lockb' install)" "bun install --frozen-lockfile"
expect "$(pm 'package.json pnpm-lock.yaml yarn.lock' install)" "pnpm install --frozen-lockfile"
expect "$(pm 'package.json yarn.lock' install)" "yarn install --frozen-lockfile"
expect "$(pm 'package.json package-lock.json' install)" "npm ci"
expect "$(pm 'package.json' install)" "npm install"
expect "$(pm '' install)" "No package.json, nothing to install"
expect "$(FROZEN_FAILS=1 pm 'package.json pnpm-lock.yaml' install)" "pnpm install --frozen-lockfile
pnpm install"
expect "$(FROZEN_FAILS=1 pm 'package.json package-lock.json' install)" "npm ci
npm install"
expect "$(pm 'package.json yarn.lock' run build)" "yarn run build"
expect "$(PACKAGE_JSON='{"packageManager":"pnpm@10.20.0"}' pm 'yarn.lock' install)" "pnpm install --frozen-lockfile"
expect "$(PACKAGE_JSON='{"packageManager":"yarn@4.9.0+sha512.abc"}' pm 'package-lock.json' run build)" "yarn run build"
expect "$(PACKAGE_JSON='{"packageManager":"deno@2"}' pm 'pnpm-lock.yaml' install)" "pnpm install --frozen-lockfile"
expect "$(pm 'package.json' install --save left-pad)" "npm install --save left-pad"

echo "diploi-pm: all passed"
