output "workload_identity_provider" {
  description = "Set as GitHub variable GCP_WIF_PROVIDER in BOTH repos."
  value       = module.github_wif.workload_identity_provider
}

output "ci_apps_sa_email" {
  description = "Set as GitHub variable GCP_CI_SA in platform-apps."
  value       = module.github_wif.ci_apps_sa_email
}

output "tf_plan_sa_email" {
  description = "Set as GitHub variable GCP_TF_PLAN_SA in platform-infra."
  value       = module.github_wif.tf_plan_sa_email
}

output "tf_apply_sa_email" {
  description = "Set as GitHub variable GCP_TF_APPLY_SA in platform-infra."
  value       = module.github_wif.tf_apply_sa_email
}

output "gke_secrets_key_id" {
  description = "KMS key used by envs/* for GKE secrets encryption (read via remote state)."
  value       = module.kms.gke_secrets_key_id
}

output "github_variables_hint" {
  description = "Copy-paste helper for the GitHub repository variables."
  value       = <<-EOT
    # platform-infra  (Settings -> Secrets and variables -> Actions -> Variables)
    GCP_WIF_PROVIDER = ${module.github_wif.workload_identity_provider}
    GCP_TF_PLAN_SA   = ${module.github_wif.tf_plan_sa_email}
    GCP_TF_APPLY_SA  = ${module.github_wif.tf_apply_sa_email}

    # platform-apps
    GCP_WIF_PROVIDER = ${module.github_wif.workload_identity_provider}
    GCP_CI_SA        = ${module.github_wif.ci_apps_sa_email}
  EOT
}
