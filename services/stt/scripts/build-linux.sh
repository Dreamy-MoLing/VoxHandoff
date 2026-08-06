#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(cd "$script_dir/.." && pwd)
machine=$(uname -m)

case "$(uname -s)" in
  Linux) ;;
  *)
    echo "voxhandoff-stt packaging requires a Linux build host; got $(uname -s)." >&2
    exit 2
    ;;
esac

case "$machine" in
  x86_64|aarch64|riscv64) ;;
  *)
    echo "Unsupported Linux architecture for voxhandoff-stt: $machine." >&2
    exit 2
    ;;
esac

python_version=${PYTHON_VERSION:-3.11}
output_dir=${VOXHANDOFF_STT_OUTPUT_DIR:-$project_dir/dist/linux-$machine}
if [[ "$output_dir" != /* ]]; then
  output_dir="$project_dir/$output_dir"
fi
build_dir="$output_dir/.build"

mkdir -p "$output_dir" "$build_dir/spec" "$build_dir/work"
rm -f "$output_dir/voxhandoff-stt"

# Keep uv's mutable cache and project environment outside the checkout by
# default. Callers may override either location for CI cache persistence.
uv_cache_dir=${UV_CACHE_DIR:-${TMPDIR:-/tmp}/voxhandoff-stt-uv-cache}
uv_project_environment=${UV_PROJECT_ENVIRONMENT:-$build_dir/venv}
export UV_CACHE_DIR="$uv_cache_dir"
export UV_PROJECT_ENVIRONMENT="$uv_project_environment"

cd "$project_dir"
uv run --locked --python "$python_version" \
  --with-requirements "$project_dir/packaging/requirements-build.txt" \
  python -m PyInstaller \
  --clean \
  --noconfirm \
  --onefile \
  --console \
  --name voxhandoff-stt \
  --distpath "$output_dir" \
  --workpath "$build_dir/work" \
  --specpath "$build_dir/spec" \
  --paths "$project_dir" \
  --collect-all faster_whisper \
  --collect-all ctranslate2 \
  --collect-all av \
  --collect-all onnxruntime \
  "$project_dir/packaging/entrypoint.py"

artifact="$output_dir/voxhandoff-stt"
if [[ ! -x "$artifact" ]]; then
  echo "PyInstaller did not produce an executable: $artifact" >&2
  exit 1
fi

echo "$artifact"
