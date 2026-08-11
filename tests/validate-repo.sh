#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

mapfile -t shell_files < <(
    rg -l '^#!.*(ba)?sh' build files/usr/bin installer tests
)
bash -n "${shell_files[@]}"

if command -v shellcheck >/dev/null; then
    shellcheck -x "${shell_files[@]}"
fi

if command -v desktop-file-validate >/dev/null; then
    while IFS= read -r desktop; do
        validation=$(desktop-file-validate "$desktop" 2>&1 || true)
        unexpected=$(grep -v 'key "DesktopNames"' <<<"$validation" || true)
        [[ -z "$unexpected" ]] || { echo "$unexpected" >&2; exit 1; }
    done < <(find files installer -name '*.desktop' -type f)
fi

if command -v niri >/dev/null; then
    niri validate -c files/usr/share/axioma/niri/cosmic-base.kdl
    niri validate -c files/etc/skel/.config/niri/config.kdl
fi

python - <<'PY'
import json
from pathlib import Path
json.loads(Path("files/etc/nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json").read_text())
json.loads(Path("files/etc/containers/policy.json").read_text())
PY

while IFS= read -r pin; do
    [[ ${#pin} -eq 40 ]] || { echo "Invalid action SHA: $pin" >&2; exit 1; }
done < <(rg -o 'uses: [^ ]+@[0-9a-f]+' .github/workflows | sed 's/.*@//')

grep -Eq '^KERNEL_VERSION=[0-9].*\.fc44\.x86_64$' build/versions.env
grep -Eq '^DMS_SHA256=[0-9a-f]{64}$' build/versions.env
grep -Fq '^[A-Z_][A-Z0-9_]*$' .github/workflows/build.yml
grep -Fxq 'zram-generator' build/packages-core.txt
if grep -Fxq 'yafti' build/packages-core.txt; then
    echo 'Fedora 43-only yafti package must not be installed on Fedora 44' >&2
    exit 1
fi
grep -Fq 'Axioma COSMIC on niri' files/usr/share/wayland-sessions/axioma-cosmic-niri.desktop

echo 'Repository validation passed.'
