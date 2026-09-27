###############################################################################
# General Google Cloud project & storage variables
###############################################################################

variable "gcp_project_id" {
  description = "The ID of the Google Cloud project where the state bucket will be created."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.gcp_project_id))
    error_message = "The gcp_project_id must be a valid Google Cloud project ID (6 to 30 lowercase letters, digits, or hyphens; must start with a letter and cannot end with a hyphen)."
  }
}

variable "gcp_region" {
  description = "Default Google Cloud region for the provider."
  type        = string
  default     = "europe-west4"
}

variable "bucket_location" {
  description = "Location for the GCS state bucket (e.g., 'EU', 'US', 'ASIA', or a specific region like 'europe-west4')."
  type        = string
  default     = "EU"
}

variable "storage_class" {
  description = "Storage class of the GCS state bucket."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "MULTI_REGIONAL", "REGIONAL", "NEARLINE", "COLDLINE", "ARCHIVE"], var.storage_class)
    error_message = "The storage_class must be one of: STANDARD, MULTI_REGIONAL, REGIONAL, NEARLINE, COLDLINE, ARCHIVE."
  }
}

variable "noncurrent_version_retention_count" {
  description = "Number of noncurrent (historical) Terraform state file versions to retain before automatic cleanup."
  type        = number
  default     = 10

  validation {
    condition     = var.noncurrent_version_retention_count >= 1
    error_message = "At least 1 noncurrent version must be retained when versioning is enabled."
  }
}
