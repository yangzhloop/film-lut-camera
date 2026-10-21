#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"
if command -v swift >/dev/null 2>&1; then
  exec swift test --parallel --jobs 4 "$@"
fi
if command -v docker >/dev/null 2>&1; then
  # Official Swift image; keep generated files owned by the invoking user.
  exec docker run --rm --network none \
    --user "$(id -u):$(id -g)" \
    --mount "type=bind,source=$repo_root,target=/source" \
    --workdir /source \
    --env CLANG_MODULE_CACHE_PATH=/source/.build/clang-module-cache \
    --env SWIFTPM_MODULECACHE_OVERRIDE=/source/.build/swift-module-cache \
    swift:6.1.3-noble \
    swift test --parallel --jobs 4 \
    --cache-path /source/.build/cache \
    --config-path /source/.build/config \
    --security-path /source/.build/security "$@"
fi
echo 'Install Swift 5.9+ (recommended Swift 6.1.3), or Docker and the official swift:6.1.3-noble image.' >&2
exit 1
