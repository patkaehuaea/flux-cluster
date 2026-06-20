set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just --list repo

[doc('Clean files and directories no longer needed after cluster bootstrap')]
[group('repository')]
clean:
    #!/usr/bin/env bash
    private_dir="$ROOT_DIR/.private"
    renovate_file="$ROOT_DIR/.github/renovate.json5"
    makejinja_conf="$ROOT_DIR/makejinja.toml"
    test -d "$ROOT_DIR/bootstrap"   || { echo "error: missing bootstrap directory"; exit 1; }
    test -f "$renovate_file"        || { echo "error: missing renovate.json5"; exit 1; }
    mkdir -p "$private_dir"
    rm -rf "$ROOT_DIR/.github/tests"
    rm -rf "$ROOT_DIR/.github/workflows/e2e.yaml"
    rm -rf "$ROOT_DIR/.devcontainer/ci"
    rm -rf "$ROOT_DIR/.github/workflows/devcontainer.yaml"
    mv "$ROOT_DIR/bootstrap" "$private_dir/bootstrap-$(date +%H%M%S)"
    mv "$makejinja_conf" "$private_dir/makejinja-$(date +%H%M%S).toml"
    sed -i '' 's/(..\.j2)\?//g' "$renovate_file"

[confirm('Reset templated configuration files — continue?')]
[doc('Reset templated configuration files back to unrendered state')]
[group('repository')]
reset:
    #!/usr/bin/env bash
    rm -rf "$KUBERNETES_DIR"
    rm -rf "$SOPS_CONFIG"
    rm -rf \
        "$KUBERNETES_DIR/bootstrap/talos/clusterconfig" \
        "$KUBERNETES_DIR/bootstrap/talos/talsecret.sops.yaml" \
        "$KUBERNETES_DIR/bootstrap/talos/talconfig.yaml"

[confirm('Reset repo back to HEAD — all local changes will be lost, continue?')]
[doc('Hard reset repo back to HEAD (DESTRUCTIVE)')]
[group('repository')]
force-reset: reset
    git reset --hard HEAD
    git clean -f -d
    git pull origin main
