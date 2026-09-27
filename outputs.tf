###############################################################################
# Outputs
###############################################################################

output "state_bucket_name" {
  description = "The name of the created Google Cloud Storage bucket for Terraform state."
  value       = google_storage_bucket.tf_state_storage.name
}

output "state_bucket_url" {
  description = "The base URL of the created Google Cloud Storage bucket (gs://<bucket_name>)."
  value       = google_storage_bucket.tf_state_storage.url
}
