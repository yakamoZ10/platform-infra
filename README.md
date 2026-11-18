# platform-infra

Production-style GKE platform on Google Cloud, managed with Terraform and GitHub Actions.
Later layers (Argo CD, APISIX, Keycloak, Prometheus/Grafana, Loki) run on top of this cluster.

```
                       ┌──────────────── GCP project: gke-terraform-ardin01 ────────────────┐
 GitHub Actions ─OIDC─▶│ Workload Identity Federation ─▶ gh-tf-plan / gh-tf-apply / gh-ci-apps │
                       │                                                                       │
 you (admin IP) ──────▶│ GKE control plane (public endpoint, authorized networks only)         │
                       │        │                                                              │
                       │ ┌──────▼──────── VPC platform-dev-vpc (europe-west3) ───────────────┐ │
                       │ │ subnet 10.10.0.0/20 · pods 10.20.0.0/16 · services 10.30.0.0/20    │ │
                       │ │  ┌ system pool (1× e2-standard-2, on-demand) ┐                     │ │
                       │ │  └ spot pool   (1–3× e2-standard-2, Spot)    ┘  private nodes      │ │
                       │ │                         │                                          │ │
                       │ │                 Cloud Router + NAT ──▶ internet (image pulls)      │ │
                       │ └────────────────────────────────────────────────────────────────────┘ │
                       │ Artifact Registry · Secret Manager · KMS (etcd secrets encryption)     │
                       └───────────────────────────────────────────────────────────────────────┘
```

## Repository layout

```
terraform/
├── bootstrap/          applied ONCE by you: APIs, GitHub WIF + CI service accounts, KMS key
├── envs/dev/           applied by CI: network, GKE, Artifact Registry, Secret Manager
└── modules/
    ├── network/        VPC, subnet + secondary ranges, Cloud NAT, default-deny firewall, static ingress IP
    ├── gke/            private zonal cluster, Dataplane V2, Workload Identity, CMEK, 2 node pools, node SA
    ├── artifact-registry/  Docker repo, immutable tags, cleanup policies, repo-level IAM
    ├── secrets/        Secret Manager containers + External Secrets Operator identity
    ├── kms/            key ring + key for GKE application-layer secrets encryption
    └── github-wif/     keyless GitHub Actions auth, 3 least-privilege service accounts
scripts/                seed-secrets.sh, cluster-sleep.sh, cluster-wake.sh
.github/workflows/      terraform.yml (fmt → validate → tflint → checkov → plan/apply)
```

---

## Today's runbook (Day 1, ~5 h)

Every step says what "done" looks like. If something errors, copy the full error and ask.

### Step 0 · Finish the GCP setup from yesterday (10 min)

```bash
export PROJECT_ID=gke-terraform-ardin01
gcloud config set project $PROJECT_ID

# billing linked?  -> billingEnabled: true
gcloud billing projects describe $PROJECT_ID

# if not:
gcloud billing projects link $PROJECT_ID --billing-account=<your account id>

# state bucket exists?
gcloud storage buckets describe gs://$PROJECT_ID-tfstate --format="value(name)" || {
  gcloud storage buckets create gs://$PROJECT_ID-tfstate --location=europe-west3 --uniform-bucket-level-access
  gcloud storage buckets update gs://$PROJECT_ID-tfstate --versioning
}

# Terraform uses these credentials:
gcloud auth application-default login
gcloud auth application-default set-quota-project $PROJECT_ID
```

Also set a **budget alert** (Console → Billing → Budgets & alerts → $50 and $100) if you haven't yet.

✅ Done when: billing is enabled and the bucket exists.

### Step 1 · Put the code in Git (10 min)

```bash
# create an empty repo "platform-infra" on GitHub first (no README), then:
cd ~/projects            # or wherever you keep code
unzip ~/Downloads/platform-infra.zip
cd platform-infra
git init -b main
git remote add origin git@github.com:<your-github-user>/platform-infra.git
```

Create the second empty repo **platform-apps** on GitHub now too (you use it tomorrow).

### Step 2 · Validate and format (15 min)

```bash
make fmt        # aligns all files the way CI expects (CI fails on unformatted code)
make validate   # downloads the google provider and checks every resource/attribute
```

✅ Done when: both roots print `Success! The configuration is valid.`

> The code was security-scanned with Checkov (0 failed checks), but `terraform validate`
> couldn't be run where it was written, so this is the first real schema check. Errors here
> are usually a one-line fix.

Optional, if installed: `make lint` (tflint) and `make scan` (Checkov, `pip install checkov`).

### Step 3 · Apply the bootstrap layer (30 min)

Edit `terraform/bootstrap/terraform.tfvars` and set your GitHub username:

```hcl
github_owner = "your-github-username"
```

```bash
make bootstrap-init
make bootstrap-plan     # read it! expect ~40 resources to add, 0 to change/destroy
make bootstrap-apply    # type "yes"
terraform -chdir=terraform/bootstrap output github_variables_hint
```

Save the output of the last command: these are the GitHub variables for tomorrow.

What you just created:

| Resource | Why |
|---|---|
| 13 APIs | everything the platform needs, managed as code |
| WIF pool `github` + provider | GitHub's OIDC tokens are trusted, only from your 2 repos |
| `gh-tf-plan` SA | read-only roles; usable by any workflow in platform-infra (PR plans) |
| `gh-tf-apply` SA | scoped admin roles; usable **only from the `main` branch** of platform-infra |
| `gh-ci-apps` SA | can only push images (granted in envs/dev); usable by platform-apps |
| KMS key ring `gke` + key `gke-secrets` | encrypts Kubernetes Secrets in etcd; 90-day rotation |

✅ Done when: `Apply complete!` and the hint output shows the provider name and three SA emails.

### Step 4 · Apply the dev environment (45 min, ~15 min of it waiting)

```bash
make my-ip      # writes your public IP to envs/dev/local.auto.tfvars (git-ignored)
make init
make plan       # expect ~30 resources: VPC, NAT, firewall, IP, cluster, 2 pools, registry, secrets...
make apply      # cluster creation takes 8–15 min
```

While it runs, read `terraform/modules/gke/main.tf` top to bottom; every setting has a comment saying why.

✅ Done when: `Apply complete!` and `terraform -chdir=terraform/envs/dev output` shows the outputs.

### Step 5 · Verify the cluster (30 min)

```bash
make creds
kubectl get nodes -L pool,cloud.google.com/gke-spot
```

Expected: 2 nodes, one `pool=system`, one `pool=spot` with `gke-spot=true`.

Prove the security features actually work (good screenshots for your README/demo):

```bash
# Private nodes: no external IPs (EXTERNAL_IP column empty)
gcloud compute instances list --format="table(name,status,networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP)"

# Dataplane V2 (Cilium/eBPF) is running
kubectl -n kube-system get pods -l k8s-app=cilium

# Secrets in etcd are encrypted with your KMS key  -> ENCRYPTED + key path
gcloud container clusters describe platform-dev --zone europe-west3-a \
  --format="value(databaseEncryption.state,databaseEncryption.keyName)"

# Workload Identity enabled
gcloud container clusters describe platform-dev --zone europe-west3-a \
  --format="value(workloadIdentityConfig.workloadPool)"

# Egress through Cloud NAT works (pulls from Docker Hub)
kubectl run nat-test --image=curlimages/curl --rm -it --restart=Never -- curl -s https://ifconfig.me; echo

# Control plane is locked to your IP: this should time out from any other network (e.g. phone hotspot)
```

✅ Done when: all checks look as described.

### Step 6 · Seed secrets (5 min)

```bash
make secrets
```

Random 32-char values are written to Secret Manager. They never enter Terraform state or Git.
Keycloak, Grafana and APISIX will read them on Days 5–7 via External Secrets Operator.

### Step 7 · Commit and push (10 min)

```bash
git add .
git status            # check that local.auto.tfvars and .terraform/ are NOT listed
git commit -m "feat(terraform): bootstrap layer and hardened GKE dev environment"
git push -u origin main
```

Commit `.terraform.lock.hcl` (both roots) — it pins exact provider versions for CI.

The workflow will run on push but the plan/apply jobs fail until the GitHub variables are set.
That's tomorrow's job (Day 2), together with the app CI. If you have time left today:

1. Repo **Settings → Secrets and variables → Actions → Variables**: add `GCP_WIF_PROVIDER`,
   `GCP_TF_PLAN_SA`, `GCP_TF_APPLY_SA` (from the hint output) and `TF_ADMIN_CIDRS`
   (`["<your-ip>/32"]`).
2. **Settings → Environments → New environment `dev`** (optionally add yourself as required reviewer
   for a manual approval before every apply).
3. Set `TF_VERSION` in `.github/workflows/terraform.yml` to your local `terraform -version`.

### Step 8 · End of the day

```bash
make sleep     # scales both node pools to 0 - the cluster and everything in it survives
# next morning:
make wake
```

---

## Daily commands

| Command | What it does |
|---|---|
| `make help` | list all targets |
| `make plan` / `make apply` | plan and apply envs/dev |
| `make my-ip` | update your admin IP after it changed (then plan + apply) |
| `make sleep` / `make wake` | scale node pools to 0 / back up |
| `make check` | fmt + validate + tflint + checkov (what CI runs) |
| `make destroy` | delete envs/dev (bootstrap stays) — for the rebuild test on the last day |

## Troubleshooting

| Symptom | Fix |
|---|---|
| `kubectl` hangs / `i/o timeout` | Your public IP changed (Fritz!Box dynamic IP). `make my-ip && make plan && make apply`. Terraform itself still works because it talks to GCP APIs, not the K8s API. |
| Cluster creation: error about `master_ipv4_cidr_block` | GKE wants a VPC-peering control plane. Add `master_ipv4_cidr_block = "172.16.0.0/28"` to `envs/dev/terraform.tfvars`, apply again. |
| Cluster creation: KMS permission denied for `service-<num>@container-engine-robot...` | The GKE service agent didn't exist yet when bootstrap ran. Run `gcloud beta services identity create --service=container.googleapis.com`, then `make bootstrap-apply` again (re-creates the binding) and `make apply`. |
| `Quota 'CPUS' exceeded` or `SSD_TOTAL_GB` | Free-trial limits. Lower `spot_max_nodes` to 2. Check Console → IAM & Admin → Quotas. |
| Spot node stays `Pending` / `ZONE_RESOURCE_POOL_EXHAUSTED` | No Spot capacity in the zone right now. Wait, or change `zone` to `europe-west3-b`/`-c` (recreates the cluster). |
| `Identity namespace does not exist` | Rare race right after cluster creation. Run `make plan && make apply` again. |
| Bootstrap: WIF pool `already exists` (409) | A deleted pool is kept for 30 days. `gcloud iam workload-identity-pools undelete github --location=global`, then `terraform import`, or change `pool_id`. |
| `Error acquiring the state lock` | A previous run crashed. Make sure nothing else is running, then `terraform -chdir=terraform/envs/dev force-unlock <LOCK_ID>`. |
| `make fmt` changed files in CI | Run `make fmt` locally before committing (or install the pre-commit hooks). |

## Design decisions

**Two layers: bootstrap + envs.** The bootstrap layer holds what CI needs to run (its own identity) and what can't be recreated: KMS keys can never be deleted in GCP, and deleted WIF pool IDs are blocked for 30 days. Everything in `envs/dev` can be destroyed and rebuilt freely. CI never applies bootstrap, so a broken pipeline can't lock itself out.

**Terraform manages the cloud, Argo CD manages the cluster.** No Helm or Kubernetes providers in Terraform. That's why GitHub Actions never needs `kubectl` access, and the control plane can stay locked to the admin IP.

**Custom modules instead of `terraform-google-modules`.** The official modules are a valid choice for a team; custom modules here keep every hardening setting visible and explainable.

**Keyless CI.** Workload Identity Federation instead of JSON keys. Three service accounts: plan (read-only, PRs), apply (main branch only, enforced in the IAM binding via a combined `repo@ref` attribute), and image push (only `artifactregistry.writer` on one repository).

**Least privilege everywhere.** No basic roles (`owner`/`editor`/`viewer`). The node SA has only logging/monitoring roles plus pull access to one registry. `actAs` on the node SA is granted on that SA only, not project-wide. ESO can read exactly four secrets.

**Cluster hardening.** Private nodes + Cloud NAT, authorized networks, Dataplane V2 (eBPF NetworkPolicy enforcement), Workload Identity with the GKE metadata server, CMEK encryption of etcd secrets, Shielded Nodes with Secure Boot, no client certificates, Binary Authorization (project policy, allow-all for now), GKE security posture scanning, explicit default-deny firewall.

**Secrets never in state.** Terraform creates only Secret Manager containers and IAM; values are seeded by script and synced into the cluster by External Secrets Operator.

**Cost.** Zonal cluster (control plane covered by the free tier), Spot workload pool, 50 GB disks, Managed Prometheus disabled (own kube-prometheus-stack), `OPTIMIZE_UTILIZATION` autoscaling profile, scale-to-zero scripts. Expected ~$2–4/day while running.

**Free-trial constraints.** The trial caps usage at 8 vCPUs: 1 system + max 3 Spot × 2 vCPU = 8. Surge upgrades are therefore disabled (`max_surge = 0`, `max_unavailable = 1`).

## Production considerations (not built, by choice)

- Separate GCP projects per environment, organised in **folders** under an **organization**, with **organization policies** (e.g. allowed regions, no external IPs).
- **Shared VPC** owned by a network team; **VPC Service Controls** perimeter around Secret Manager, KMS and Artifact Registry.
- Regional (multi-zone) cluster, private control-plane endpoint reached through a bastion/IAP or the DNS-based endpoint.
- Binary Authorization policy that only admits signed images from our registry (attestations from CI).
- Secret values as Terraform write-only attributes (`secret_data_wo`, Terraform ≥ 1.11) if they must be managed by Terraform.
- GitHub Actions pinned to commit SHAs; WIF condition on the numeric `repository_owner_id` against repo-squatting.
