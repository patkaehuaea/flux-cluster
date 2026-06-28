# Migration runbook — onedr0p/cluster-template 2026.5.0

This repo was regenerated onto the **stable `2026.5.0`** upstream template (mise + Task +
`cluster.yaml`/`nodes.yaml`, flux-operator/flux-instance, envoy-gateway, cloudflare-dns/tunnel,
per-app OCIRepository sources).

The agent did everything that does **not** require the render toolchain or secrets. The steps
below (which need `mise`, the age key, and your secrets) and the **live rollout** are yours.

> ⚠️ This changes the live cluster's networking (ingress-nginx → envoy-gateway, external-dns →
> cloudflare-dns, raw Flux → flux-operator) and bumps Talos `1.7.4`→`1.12.6` and Kubernetes
> `1.30.1`→`1.35.4`. Stage it; keep console/Talos access handy.

---

## What's already done (committed)
- Vendored 2026.5.0 `templates/`, `.mise.toml`, `Taskfile.yaml`, `.taskfiles/`, `makejinja.toml`,
  `cluster.sample.yaml`, `nodes.sample.yaml`, `scripts/`, `.github/`, `.vscode/`, `.renovaterc.json5`,
  `.shellcheckrc`, README/LICENSE/editorconfig/gitattributes/gitignore.
- Removed legacy scaffolding: `justfile`, `.justfiles/`, `config.sample.yaml`, `bootstrap/`
  (old templates), `requirements.txt`, `.envrc`, `.devcontainer/`, old `.taskfiles`/`scripts`/`.github`.
- Wrote **`cluster.yaml`** and **`nodes.yaml`** from your legacy values (gitignored — local only).
- Kept `.sops.yaml` (your age recipient `age1jytk…`) — already matches the new `talos/`+`kubernetes/` layout.
- Staged modernized custom apps under **`migration/apps/`** and custom Talos patches under
  **`migration/talos-patches/`** (see below).
- **Left the legacy `kubernetes/` tree intact** as the working/rollback reference until you render.

## ⚠️ Fill these in before rendering (`cluster.yaml`, gitignored)
| Key | Status |
|---|---|
| `cloudflare_domain` | TODO — was `SECRET_DOMAIN` (encrypted; not in this worktree) |
| `cloudflare_token` | TODO — secret |
| `cluster_dns_gateway_addr` / `cluster_gateway_addr` / `cloudflare_gateway_addr` | TODO — were in the absent legacy `config.yaml`; placeholders `.11/.12/.13` set, **verify your real LB VIPs** |
| `repository_visibility` | set to `private` (you used a deploy key) — confirm |
| `cluster_api_tls_sans` | left commented (legacy `k8s-control-5` isn't a valid FQDN) |

You also need a **`cloudflare-tunnel.json`** at the repo root (`task configure` requires it):
`cloudflared tunnel login` then `cloudflared tunnel create k8s` (see README).

---

## Step 1 — Toolchain
```bash
# install mise (https://mise.jdx.dev), then:
mise trust && mise install     # flux 2.8.5, talos 1.12.6, kubectl 1.35.4, helm 4, cue, talhelper, makejinja…
```
Put your existing **`age.key`** at the repo root (gitignored).

## Step 2 — Render the base
The legacy `kubernetes/` tree must not collide with the render. Back up `.sops.yaml` first
(`task template:reset` deletes it):
```bash
cp .sops.yaml /tmp/.sops.yaml.bak
task template:reset        # removes bootstrap/ kubernetes/ talos/ .sops.yaml
cp /tmp/.sops.yaml.bak .sops.yaml
task configure             # cue vet → makejinja render → sops encrypt → kubeconform → talhelper validate
```
This renders `talos/`, `bootstrap/`, and the base `kubernetes/` (cert-manager, kube-system base,
network = envoy-gateway/cloudflare-dns/cloudflare-tunnel/k8s-gateway, flux-operator/flux-instance).

## Step 3 — Re-add custom apps (from `migration/apps/`)
```bash
cp -r migration/apps/homepage           kubernetes/apps/
cp -r migration/apps/observability      kubernetes/apps/
cp -r migration/apps/openebs-system     kubernetes/apps/
cp -r migration/apps/kube-system/kubelet-csr-approver kubernetes/apps/kube-system/
```
Then **add kubelet-csr-approver to the rendered kube-system kustomization**:
`kubernetes/apps/kube-system/kustomization.yaml` → add `- ./kubelet-csr-approver/ks.yaml`.

Per-app OCIRepository sources (verified where noted; Renovate keeps tags current after):
- **kube-prometheus-stack** & **prometheus-operator-crds** — `oci://ghcr.io/prometheus-community/charts/*` (verified, official).
- **openebs** — `oci://ghcr.io/home-operations/charts-mirror/openebs` (verified present in charts-mirror).
- **grafana** — `oci://ghcr.io/grafana-community/helm-charts/grafana` (verified; chart moved grafana → grafana-community). Bump tag to current.
- **kubelet-csr-approver** — `oci://ghcr.io/postfinance/charts/kubelet-csr-approver` (verified, official OCI).
- **homepage** — ⚠️ legacy jameswynn chart is **dead with no drop-in OCI successor**. Decide:
  (a) `oci://ghcr.io/m0nsterrr/helm-charts/homepage` (real OCI, **different values schema** — reconcile
  `helmrelease.yaml`), or (b) deploy via **bjw-s `app-template`** like the upstream `echo` app (recommended,
  most aligned with the new conventions). The staged helmrelease values will need adjusting either way.

Ingress → HTTPRoute is done for homepage/grafana/prometheus (attached to `envoy-internal`); verify
backend service names/ports after first deploy. The grafana dashboard list dropped the
ingress-nginx (`nginx`) folder; re-add envoy/gateway dashboards if you want them.

**local-path-provisioner is dropped** (it referenced an undefined GitRepository and is redundant
with `openebs-hostpath`). Re-point any PVCs still on it.

## Step 4 — Re-add custom Talos patches (from `migration/talos-patches/`)
```bash
cp migration/talos-patches/global/*.yaml talos/patches/global/   # auto-wired by talconfig
```
- `machine-openebs-mount.yaml` — **required** for openebs `openebs-hostpath`.
- `machine-kubelet-extra.yaml` — `rotate-server-certificates` (**required** by kubelet-csr-approver) + `disableSearchDomain`.
- `machine-registries.yaml` — docker.io → mirror.gcr.io.
- The new `talos/patches/global/machine-sysctls.yaml` already matches your legacy sysctls (incl. Cloudflared QUIC). ✓
- Legacy containerd `enable_unprivileged_ports/icmp`: NOT in the new `machine-files.yaml`. If you
  still need it, add it there and verify against the new cilium config. Re-run `task configure`.

## Step 5 — Validate (static)
```bash
task configure                 # re-run; must pass cue + kubeconform + talhelper
flux-local test --path kubernetes   # or rely on the .github/workflows/flux-local.yaml PR check
git diff                       # confirm domain, VIPs, node IPs, age key, repo URL are correct
```
Push a PR — the vendored `flux-local.yaml` workflow diffs the render automatically.

## Step 6 — Live rollout (staged, risky — do in order)
1. **Flux**: migrate raw Flux v2.3 → flux-operator/flux-instance (v2.8.5). Confirm reconciliation.
2. **Gateway**: bring up envoy-gateway alongside ingress-nginx; cut HTTPRoutes over app-by-app;
   verify each hostname resolves (k8s-gateway watches HTTPRoutes for LAN DNS) + serves TLS; then
   remove ingress-nginx.
3. **DNS/tunnel**: cut external-dns → cloudflare-dns + cloudflare-tunnel; confirm records publish.
4. **Talos/K8s upgrade LAST**, one node at a time: `1.7.4`→`1.12.6` / `1.30.1`→`1.35.4`. This is
   a large multi-minor jump — review the Talos upgrade path / intermediate hops before starting.

## Step 7 — Finalize
- Delete the legacy `kubernetes/` leftovers the render didn't replace (e.g.
  `kubernetes/flux/repositories/`, stray `repositories/helm/homepage`) — superseded by per-app OCIRepository.
- Ensure the **Renovate GitHub App** is installed on `patkaehuaea/flux-cluster` (config is
  `.renovaterc.json5`; runs via the App, not a workflow). Watch the Dependency Dashboard issue.
- `task template:tidy` once you're happy (archives template-only files).
- Remove this `migration/` directory.
