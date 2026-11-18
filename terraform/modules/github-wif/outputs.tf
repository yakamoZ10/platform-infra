output "workload_identity_provider" {
  description = "Full provider resource name for google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "ci_apps_sa_email" {
  description = "SA used by the apps repo to push images."
  value       = google_service_account.ci_apps.email
}

output "tf_plan_sa_email" {
  description = "SA used for terraform plan on pull requests."
  value       = google_service_account.tf_plan.email
}

output "tf_apply_sa_email" {
  description = "SA used for terraform apply on main."
  value       = google_service_account.tf_apply.email
}
