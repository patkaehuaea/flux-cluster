set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just --list flux

[doc('Bootstrap Flux into the cluster')]
[group('flux')]
bootstrap:
    #!/usr/bin/env bash
    cluster_secret="$KUBERNETES_DIR/flux/vars/cluster-secrets.sops.yaml"
    cluster_settings="$KUBERNETES_DIR/flux/vars/cluster-settings.yaml"
    test -f "$KUBECONFIG"        || { echo "error: missing kubeconfig"; exit 1; }
    test -f "$SOPS_AGE_KEY_FILE" || { echo "error: missing age key file"; exit 1; }
    kubectl apply --server-side --kustomize "$KUBERNETES_DIR/bootstrap/flux"
    cat "$SOPS_AGE_KEY_FILE" | kubectl -n flux-system create secret generic sops-age --from-file=age.agekey=/dev/stdin
    sops --decrypt "$cluster_secret" | kubectl apply --server-side --filename -
    kubectl apply --server-side --filename "$cluster_settings"
    kubectl apply --server-side --kustomize "$KUBERNETES_DIR/flux/config"

[doc('Apply a Flux Kustomization resource for a cluster app')]
[group('flux')]
apply path ns='flux-system':
    #!/usr/bin/env bash
    test -f "$KUBECONFIG" || { echo "error: missing kubeconfig"; exit 1; }
    test -f "$KUBERNETES_DIR/apps/{{ path }}/ks.yaml" \
        || { echo "error: missing ks.yaml for {{ path }}"; exit 1; }
    ks=$(flux --namespace "{{ ns }}" get kustomizations "$(basename "{{ path }}")" 2>&1 || true)
    dry_run=""
    echo "$ks" | grep -q "not found" && dry_run="--dry-run"
    flux build ks "$(basename "{{ path }}")" \
        --namespace "{{ ns }}" \
        --kustomization-file "$KUBERNETES_DIR/apps/{{ path }}/ks.yaml" \
        --path "$KUBERNETES_DIR/apps/{{ path }}" \
        $dry_run \
    | kubectl apply --server-side --field-manager=kustomize-controller -f -

[doc('Force Flux to pull in changes from your Git repository')]
[group('flux')]
reconcile:
    test -f "$KUBECONFIG" || { echo "error: missing kubeconfig"; exit 1; }
    flux --namespace flux-system reconcile kustomization cluster --with-source

[doc('Apply the GitHub deploy key secret to the cluster')]
[group('flux')]
deploy-key:
    #!/usr/bin/env bash
    deploy_key_file="$KUBERNETES_DIR/bootstrap/flux/github-deploy-key.sops.yaml"
    test -f "$KUBECONFIG"        || { echo "error: missing kubeconfig"; exit 1; }
    test -f "$SOPS_AGE_KEY_FILE" || { echo "error: missing age key file"; exit 1; }
    test -f "$deploy_key_file"   || { echo "error: missing github deploy key file"; exit 1; }
    kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply --filename -
    sops --decrypt "$deploy_key_file" | kubectl apply --server-side --filename -
