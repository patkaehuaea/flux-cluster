set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just --list workstation

[doc('Run direnv hooks to load environment variables')]
[group('workstation')]
direnv:
    direnv allow .

[doc('Set up Python virtual environment and install pip dependencies')]
[group('workstation')]
venv:
    #!/usr/bin/env bash
    python3 -m venv "$VIRTUAL_ENV"
    "$VIRTUAL_ENV/bin/python3" -m pip install --upgrade pip setuptools wheel
    "$VIRTUAL_ENV/bin/python3" -m pip install --upgrade \
        --requirement "$ROOT_DIR/requirements.txt"

[doc('Install workstation dependencies with Homebrew')]
[group('workstation')]
brew:
    #!/usr/bin/env bash
    brewfile="$ROOT_DIR/.taskfiles/Workstation/Brewfile"
    command -v brew >/dev/null 2>&1 || { echo "error: Homebrew not installed"; exit 1; }
    test -f "$brewfile"             || { echo "error: missing Brewfile"; exit 1; }
    brew bundle --file "$brewfile"

[doc('Install workstation dependencies on Arch Linux with paru or yay')]
[group('workstation')]
arch:
    #!/usr/bin/env bash
    archfile="$ROOT_DIR/.taskfiles/Workstation/Archfile"
    test -f "$archfile" || { echo "error: missing Archfile"; exit 1; }
    helper=$(command -v yay || command -v paru || true)
    [ -n "$helper" ] || { echo "error: neither yay nor paru found"; exit 1; }
    "$helper" -Syu --needed --noconfirm --noprogressbar $(cat "$archfile" | xargs)

[doc('Install CLI tools into .bin/ using curl (generic Linux only)')]
[group('workstation')]
generic-linux:
    #!/usr/bin/env bash
    [[ "$(uname -s)" == "Linux" ]] || { echo "error: this recipe is for Linux only"; exit 1; }
    bin_dir="$ROOT_DIR/.bin"
    mkdir -p "$bin_dir"
    cd "$bin_dir"
    for tool in \
        "budimanjojo/talhelper?as=talhelper&type=script" \
        "cloudflare/cloudflared?as=cloudflared&type=script" \
        "FiloSottile/age?as=age&type=script" \
        "fluxcd/flux2?as=flux&type=script" \
        "getsops/sops?as=sops&type=script" \
        "helmfile/helmfile?as=helmfile&type=script" \
        "jqlang/jq?as=jq&type=script" \
        "kubernetes-sigs/kustomize?as=kustomize&type=script" \
        "siderolabs/talos?as=talosctl&type=script" \
        "yannh/kubeconform?as=kubeconform&type=script" \
        "mikefarah/yq?as=yq&type=script"
    do
        curl -fsSL "https://i.jpillora.com/$tool" | bash
    done
    arch=$(uname -m); [ "$arch" = "x86_64" ] && arch="amd64" || arch="arm64"
    curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/$arch/kubectl"
    chmod +x kubectl
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
        | USE_SUDO="false" HELM_INSTALL_DIR="." bash
