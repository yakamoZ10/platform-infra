# Non-sensitive settings, committed to Git.
# Your IP (admin_cidrs) goes into local.auto.tfvars, which is git-ignored.

project_id   = "gke-terraform-ardin01"
region       = "europe-west3"
zone         = "europe-west3-a"
environment  = "dev"
state_bucket = "gke-terraform-ardin01-tfstate"

machine_type      = "e2-standard-2"
system_node_count = 1
spot_min_nodes    = 1
spot_max_nodes    = 3
