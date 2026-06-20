set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just --list kube

[doc('Gather common resources in your cluster, useful when asking for support')]
[group('kubernetes')]
resources *args:
    #!/usr/bin/env bash
    extra="${@:--A}"
    for resource in nodes gitrepositories kustomizations helmrepositories helmreleases \
                    certificates certificaterequests ingresses pods; do
        kubectl get "$resource" $extra
    done

[doc('Validate Kubernetes manifests with kubeconform')]
[group('kubernetes')]
validate:
    test -f "$SCRIPTS_DIR/kubeconform.sh" || { echo "error: missing kubeconform script"; exit 1; }
    bash "$SCRIPTS_DIR/kubeconform.sh" "$KUBERNETES_DIR"

[private]
reset:
    rm -rf "$KUBERNETES_DIR"
