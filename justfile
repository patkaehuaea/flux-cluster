set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']
set script-interpreter := ['bash', '-euo', 'pipefail']

root_dir         := justfile_directory()
age_file         := root_dir + '/age.key'
bootstrap_dir    := root_dir + '/bootstrap'
kubernetes_dir   := root_dir + '/kubernetes'
scripts_dir      := root_dir + '/scripts'
talconfig_dir    := kubernetes_dir + '/bootstrap/talos'
talosconfig_file := talconfig_dir + '/clusterconfig/talosconfig'
venv_dir         := root_dir + '/.venv'

export KUBECONFIG            := root_dir + '/kubeconfig'
export KUBERNETES_DIR        := kubernetes_dir
export PYTHONDONTWRITEBYTECODE := '1'
export ROOT_DIR              := root_dir
export SCRIPTS_DIR           := scripts_dir
export SOPS_AGE_KEY_FILE     := age_file
export SOPS_CONFIG           := root_dir + '/.sops.yaml'
export TALOSCONFIG           := talosconfig_file
export VIRTUAL_ENV           := venv_dir

mod flux       '.justfiles/flux'
mod kube       '.justfiles/kubernetes'
mod sops       '.justfiles/sops'
mod talos      '.justfiles/talos'
mod repo       '.justfiles/repository'
mod workstation '.justfiles/workstation'

[private]
default:
    just -l

[doc('Initialize configuration files')]
[group('template')]
init:
    #!/usr/bin/env bash
    if [ ! -f "{{ root_dir }}/config.yaml" ]; then
        cp "{{ root_dir }}/config.sample.yaml" "{{ root_dir }}/config.yaml"
        echo "=== Configuration file copied ==="
        echo "Proceed with updating: {{ root_dir }}/config.yaml"
    else
        echo "Config already exists, skipping."
    fi

[confirm('Any conflicting config in the kubernetes directory will be overwritten... continue?')]
[doc('Configure repository from bootstrap vars')]
[group('template')]
configure: workstation::direnv workstation::venv sops::keygen init
    "{{ venv_dir }}/bin/makejinja"
    just sops::encrypt
    bash "{{ scripts_dir }}/kubeconform.sh" "{{ kubernetes_dir }}"
    echo "=== Done rendering and validating YAML ==="
