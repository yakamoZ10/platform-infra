# Convenience targets. Run `make help`.
ENV_DIR   := terraform/envs/dev
BOOT_DIR  := terraform/bootstrap
CLUSTER   := platform-dev
ZONE      := europe-west3-a
PROJECT   := gke-terraform-ardin01

.PHONY: help fmt validate lint scan check bootstrap-init bootstrap-plan bootstrap-apply \
        init plan apply destroy creds my-ip secrets sleep wake

help: ## Show targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}'

fmt: ## Format all Terraform files
	terraform fmt -recursive terraform

validate: ## terraform validate both roots (no backend needed)
	terraform -chdir=$(BOOT_DIR) init -backend=false -input=false >/dev/null && terraform -chdir=$(BOOT_DIR) validate
	terraform -chdir=$(ENV_DIR)  init -backend=false -input=false >/dev/null && terraform -chdir=$(ENV_DIR) validate

lint: ## tflint (install: https://github.com/terraform-linters/tflint)
	tflint --init --config=$(CURDIR)/.tflint.hcl
	tflint --recursive --config=$(CURDIR)/.tflint.hcl

scan: ## Checkov security scan (pip install checkov)
	checkov -d terraform --config-file .checkov.yaml

check: fmt validate lint scan ## Everything CI runs

bootstrap-init: ## Init bootstrap layer
	terraform -chdir=$(BOOT_DIR) init

bootstrap-plan: ## Plan bootstrap layer
	terraform -chdir=$(BOOT_DIR) plan

bootstrap-apply: ## Apply bootstrap layer (manual, once)
	terraform -chdir=$(BOOT_DIR) apply

init: ## Init dev env
	terraform -chdir=$(ENV_DIR) init

plan: ## Plan dev env
	terraform -chdir=$(ENV_DIR) plan -out=tfplan

apply: ## Apply the saved dev plan
	terraform -chdir=$(ENV_DIR) apply tfplan

destroy: ## Destroy dev env (bootstrap stays)
	terraform -chdir=$(ENV_DIR) destroy

creds: ## Configure kubectl for the cluster
	gcloud container clusters get-credentials $(CLUSTER) --zone $(ZONE) --project $(PROJECT)

my-ip: ## Write your current public IP into local.auto.tfvars
	@echo "admin_cidrs = [\"$$(curl -s https://ifconfig.me)/32\"]" > $(ENV_DIR)/local.auto.tfvars
	@cat $(ENV_DIR)/local.auto.tfvars

secrets: ## Seed random values into Secret Manager
	PROJECT_ID=$(PROJECT) ./scripts/seed-secrets.sh

sleep: ## Scale node pools to 0
	CLUSTER=$(CLUSTER) ZONE=$(ZONE) ./scripts/cluster-sleep.sh

wake: ## Scale node pools back up
	CLUSTER=$(CLUSTER) ZONE=$(ZONE) ./scripts/cluster-wake.sh
