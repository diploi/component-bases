#!/bin/sh
# What diploi-pm runs and which Python version it asks for, with a stand-in for uv that prints its arguments.
# Run with `sh python/diploi-pm.test.sh`
set -eu
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
unset UV_PYTHON PYTHON_VERSION 2>/dev/null || true

mkdir "$work/bin"
cat > "$work/bin/uv" <<'STUB'
#!/bin/sh
echo "uv $* [${UV_PYTHON:-uv decides}]"
case "$*" in *--locked*) [ -z "${LOCKED_FAILS:-}" ] ;; esac
STUB
chmod +x "$work/bin/uv"

# pm "<files in the project>" <diploi-pm arguments...>
pm() {
  project=$(mktemp -d "$work/project.XXXXXX")
  for file in $1; do touch "$project/$file"; done
  shift
  (cd "$project" && PATH="$work/bin:$PATH" sh "$here/diploi-pm" "$@")
}

expect() {
  if [ "$1" != "$2" ]; then
    printf 'FAIL\nexpected: %s\ngot:      %s\n' "$2" "$1"
    exit 1
  fi
}

expect "$(pm 'pyproject.toml' install)" "uv sync --locked [3.12]"
expect "$(pm 'pyproject.toml' install --no-dev)" "uv sync --locked --no-dev [3.12]"
expect "$(PYTHON_VERSION=3.13 pm 'pyproject.toml' install)" "uv sync --locked [3.13]"
expect "$(PYTHON_VERSION=3.13 pm 'pyproject.toml .python-version' install)" "uv sync --locked [uv decides]"
expect "$(LOCKED_FAILS=1 pm 'pyproject.toml' install --no-dev)" "uv sync --locked --no-dev [3.12]
uv sync --no-dev [3.12]"

expect "$(pm 'pyproject.toml requirements.txt' install)" "uv sync --locked [3.12]"
expect "$(pm 'requirements.txt' install --no-dev)" "uv venv --clear [3.12]
uv pip install -r requirements.txt [3.12]"

expect "$(pm '' install)" "No pyproject.toml or requirements.txt, nothing to install"
expect "$(pm 'pyproject.toml' add requests)" "uv add requests [uv decides]"

echo "diploi-pm: all good"
