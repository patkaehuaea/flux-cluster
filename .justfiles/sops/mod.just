set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just --list sops

[doc('Initialize Age key for SOPS')]
[group('sops')]
keygen:
    #!/usr/bin/env bash
    if [ -f "$SOPS_AGE_KEY_FILE" ]; then
        echo "Age key already exists at $SOPS_AGE_KEY_FILE, skipping."
    else
        age-keygen --output "$SOPS_AGE_KEY_FILE"
    fi

[doc('Encrypt all Kubernetes SOPS secrets that are not yet encrypted')]
[group('sops')]
encrypt:
    #!/usr/bin/env bash
    test -f "$SOPS_CONFIG"       || { echo "error: missing .sops.yaml"; exit 1; }
    test -f "$SOPS_AGE_KEY_FILE" || { echo "error: missing age key file"; exit 1; }
    while IFS= read -r file; do
        sops --encrypt --in-place "$file"
    done < <(find "$KUBERNETES_DIR" -type f -name "*.sops.*" \
             -exec grep -lL "ENC\[AES256_GCM" {} \; 2>/dev/null)

[private]
reset:
    rm -rf "$SOPS_CONFIG"
