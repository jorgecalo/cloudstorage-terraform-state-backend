#------------------------------------------------------------------------------
# Create Google Cloud Storage bucket to store Terraform state file v.1.0.0
#------------------------------------------------------------------------------

###############################################################################
# Enable APIs - Enable required APIs for deployment
###############################################################################

resource "google_project_service" "cloudresourcemanager" {
  project                    = var.gcp_project_id
  service                    = "cloudresourcemanager.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_project_service" "storage" {
  project                    = var.gcp_project_id
  service                    = "storage.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false

  depends_on = [
    google_project_service.cloudresourcemanager
  ]
}

###############################################################################
# Create new multi-region storage bucket in the EU with versioning enabled
###############################################################################

resource "random_id" "bucket_prefix" {
  byte_length = 8
}

moved {
  from = google_storage_bucket.tf-state-storage
  to   = google_storage_bucket.tf_state_storage
}

resource "google_storage_bucket" "tf_state_storage" {
  name                        = "${random_id.bucket_prefix.hex}-bucket-tfstate"
  project                     = var.gcp_project_id
  location                    = var.bucket_location
  storage_class               = var.storage_class
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = var.noncurrent_version_retention_count
      with_state         = "ARCHIVED"
    }
  }

  depends_on = [
    google_project_service.storage
  ]
}