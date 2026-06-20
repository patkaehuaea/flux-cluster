set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just --list talos

[doc('Bootstrap the Talos cluster (generates secrets, applies config, installs helm apps)')]
[group('talos')]
bootstrap: _secret _config _apply _do-bootstrap kubeconfig helm-apps
    talosctl health --server=false

[doc('Fetch kubeconfig from the cluster')]
[group('talos')]
kubeconfig:
    #!/usr/bin/env bash
    talconfig_file="$KUBERNETES_DIR/bootstrap/talos/talconfig.yaml"
    cluster_dir="$KUBERNETES_DIR/bootstrap/talos/clusterconfig"
    test -f "$talconfig_file" || { echo "error: missing talconfig.yaml"; exit 1; }
    until talhelper gencommand kubeconfig \
        --config-file "$talconfig_file" \
        --out-dir "$cluster_dir" \
        --extra-flags="$ROOT_DIR --force" | bash; do sleep 10; done

[doc('Bootstrap core Helm apps needed for Talos (CNI, etc.)')]
[group('talos')]
helm-apps:
    #!/usr/bin/env bash
    helmfile_file="$KUBERNETES_DIR/bootstrap/helmfile.yaml"
    test -f "$KUBECONFIG"      || { echo "error: missing kubeconfig"; exit 1; }
    test -f "$helmfile_file"   || { echo "error: missing helmfile"; exit 1; }
    until kubectl wait --for=condition=Ready=False nodes --all --timeout=600s; do sleep 10; done
    helmfile --file "$helmfile_file" apply --skip-diff-on-install --suppress-diff
    until kubectl wait --for=condition=Ready nodes --all --timeout=600s; do sleep 10; done

[doc('Upgrade Talos on a single node')]
[group('talos')]
upgrade node image mode='default':
    #!/usr/bin/env bash
    test -f "$TALOSCONFIG" || { echo "error: missing talosconfig"; exit 1; }
    talosctl config info >/dev/null 2>&1 \
        || { echo "error: unable to retrieve Talos config"; exit 1; }
    talosctl --nodes "{{ node }}" get machineconfig >/dev/null 2>&1 \
        || { echo "error: node {{ node }} not found"; exit 1; }
    talosctl --nodes "{{ node }}" upgrade \
        --image "{{ image }}" --wait=true --timeout=10m \
        --preserve=true --reboot-mode="{{ mode }}"
    talosctl --nodes "{{ node }}" health --wait-timeout=10m --server=false

[doc('Upgrade Kubernetes across the cluster')]
[group('talos')]
upgrade-k8s controller to:
    #!/usr/bin/env bash
    test -f "$TALOSCONFIG" || { echo "error: missing talosconfig"; exit 1; }
    talosctl config info >/dev/null 2>&1 \
        || { echo "error: unable to retrieve Talos config"; exit 1; }
    talosctl --nodes "{{ controller }}" upgrade-k8s --to "{{ to }}"

[confirm('This will destroy your cluster and reset all nodes to maintenance mode — continue?')]
[doc('Reset all nodes back to maintenance mode (DESTRUCTIVE)')]
[group('talos')]
nuke:
    #!/usr/bin/env bash
    talconfig_file="$KUBERNETES_DIR/bootstrap/talos/talconfig.yaml"
    cluster_dir="$KUBERNETES_DIR/bootstrap/talos/clusterconfig"
    test -f "$talconfig_file" || { echo "error: missing talconfig.yaml"; exit 1; }
    talhelper gencommand reset \
        --config-file "$talconfig_file" \
        --out-dir "$cluster_dir" \
        --extra-flags="--reboot --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --graceful=false --wait=false" \
    | bash

[private]
_secret:
    #!/usr/bin/env bash
    talconfig_file="$KUBERNETES_DIR/bootstrap/talos/talconfig.yaml"
    talsecret_file="$KUBERNETES_DIR/bootstrap/talos/talsecret.sops.yaml"
    test -f "$talconfig_file"    || { echo "error: missing talconfig.yaml"; exit 1; }
    test -f "$SOPS_CONFIG"       || { echo "error: missing .sops.yaml"; exit 1; }
    test -f "$SOPS_AGE_KEY_FILE" || { echo "error: missing age key file"; exit 1; }
    if [ ! -f "$talsecret_file" ]; then
        talhelper gensecret > "$talsecret_file"
        sops --encrypt --in-place "$talsecret_file"
    fi

[private]
_config:
    #!/usr/bin/env bash
    talconfig_file="$KUBERNETES_DIR/bootstrap/talos/talconfig.yaml"
    talsecret_file="$KUBERNETES_DIR/bootstrap/talos/talsecret.sops.yaml"
    cluster_dir="$KUBERNETES_DIR/bootstrap/talos/clusterconfig"
    test -f "$talconfig_file" || { echo "error: missing talconfig.yaml"; exit 1; }
    talhelper genconfig \
        --config-file "$talconfig_file" \
        --secret-file "$talsecret_file" \
        --out-dir "$cluster_dir"

[private]
_apply:
    #!/usr/bin/env bash
    talconfig_file="$KUBERNETES_DIR/bootstrap/talos/talconfig.yaml"
    cluster_dir="$KUBERNETES_DIR/bootstrap/talos/clusterconfig"
    test -f "$talconfig_file" || { echo "error: missing talconfig.yaml"; exit 1; }
    talhelper gencommand apply \
        --config-file "$talconfig_file" \
        --out-dir "$cluster_dir" \
        --extra-flags="--insecure" | bash

[private]
_do-bootstrap:
    #!/usr/bin/env bash
    talconfig_file="$KUBERNETES_DIR/bootstrap/talos/talconfig.yaml"
    cluster_dir="$KUBERNETES_DIR/bootstrap/talos/clusterconfig"
    test -f "$talconfig_file" || { echo "error: missing talconfig.yaml"; exit 1; }
    until talhelper gencommand bootstrap \
        --config-file "$talconfig_file" \
        --out-dir "$cluster_dir" | bash; do sleep 10; done

[private]
reset:
    #!/usr/bin/env bash
    cluster_dir="$KUBERNETES_DIR/bootstrap/talos/clusterconfig"
    talsecret="$KUBERNETES_DIR/bootstrap/talos/talsecret.sops.yaml"
    talconfig="$KUBERNETES_DIR/bootstrap/talos/talconfig.yaml"
    rm -rf "$cluster_dir" "$talsecret" "$talconfig"
