# cloudstorage-terraform-state-backend

This Terraform configuration provisions a hardened **Google Cloud Storage (GCS)** bucket designed to store remote Terraform state files (`terraform.tfstate`), along with a [`backend.tf.sample`](backend.tf.sample) template for migrating local state to the remote GCS backend.

## Features & Security Controls

- **Automated API Enablement**: Enables `cloudresourcemanager.googleapis.com` and `storage.googleapis.com` with explicit dependency ordering (`disable_on_destroy = false`).
- **Globally Unique Bucket Naming**: Uses an 8-byte random hex prefix (`<random-hex>-bucket-tfstate`) to prevent global GCS bucket naming collisions.
- **Public Access Prevention**: Enforces `public_access_prevention = "enforced"` so state files containing sensitive data can never be exposed publicly.
- **Uniform Bucket-Level Access (UBLA)**: Enables `uniform_bucket_level_access = true` to disable legacy ACLs and manage permissions strictly through Cloud IAM.
- **State Versioning & Lifecycle Retention**: Enables object versioning (`versioning.enabled = true`) for state recovery and automatically prunes archived noncurrent state versions beyond a configurable retention count (`noncurrent_version_retention_count`, default `10`).
- **Accidental Deletion Protection**: Sets `force_destroy = false` to prevent accidental destruction of a bucket containing active state files.
- **Keyless Authentication Ready**: Uses Google Cloud **Application Default Credentials (ADC)** instead of static service account JSON key files.

## Repository Structure

| File | Description |
| :--- | :--- |
| [`provider.tf`](provider.tf) | Terraform version constraints (`>= 1.5.0`), required providers (`google`, `random`), and `google` provider configuration. |
| [`main.tf`](main.tf) | Enables required Google Cloud APIs and provisions the hardened GCS state bucket. |
| [`variables.tf`](variables.tf) | Input variables with type constraints, sensible defaults, and validation rules. |
| [`outputs.tf`](outputs.tf) | Outputs the generated GCS bucket name (`state_bucket_name`) and URL (`state_bucket_url`). |
| [`backend.tf.sample`](backend.tf.sample) | Sample GCS backend configuration block for migrating local state to the remote bucket. |

## Prerequisites & IAM Permissions

1. **Tools**:
   - [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.5.0`
   - [Google Cloud SDK (`gcloud`)](https://cloud.google.com/sdk/docs/install)
2. **Google Cloud Permissions**:
   Ensure your Google Cloud principal (user account or service account) has the following IAM permissions on the target project:
   - **Service Usage** (e.g., `roles/serviceusage.serviceUsageAdmin`):
     - `serviceusage.services.enable`
     - `serviceusage.services.get`
   - **Cloud Storage** (e.g., `roles/storage.admin`):
     - `storage.buckets.create`
     - `storage.buckets.get`
     - `storage.buckets.list`
     - `storage.buckets.update`
     - `storage.objects.create`
     - `storage.objects.delete`
     - `storage.objects.get`
     - `storage.objects.update`

## Usage Guide

### 1. Authenticate with Google Cloud
Authenticate locally using **Application Default Credentials (ADC)** (avoid downloading static JSON service account keys):

```bash
gcloud auth application-default login
```

*(Optional)* Set your default quota project if prompted:
```bash
gcloud auth application-default set-quota-project YOUR_GCP_PROJECT_ID
```
> **Note for CI/CD**: In automated pipelines (GitHub Actions, GitLab CI, Cloud Build), use [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation) or service account impersonation.

### 2. Configure Input Variables
Create a `terraform.tfvars` file in the root directory (automatically ignored by [`.gitignore`](.gitignore)) or pass variables via the CLI:

```hcl
# terraform.tfvars
gcp_project_id                     = "your-gcp-project-id"
gcp_region                         = "europe-west4" # Optional (default: "europe-west4")
bucket_location                    = "EU"           # Optional (default: "EU")
storage_class                      = "STANDARD"     # Optional (default: "STANDARD")
noncurrent_version_retention_count = 10             # Optional (default: 10)
```

### 3. Initialize and Provision the State Bucket
Initialize Terraform providers, review the execution plan, and apply:

```bash
terraform init
terraform plan
terraform apply
```
*(Or without a `terraform.tfvars` file: `terraform apply -var="gcp_project_id=your-gcp-project-id"`)*

### 4. Configure and Migrate to the Remote GCS Backend
1. Retrieve the generated bucket name from the Terraform outputs:
   ```bash
   terraform output -raw state_bucket_name
   ```
2. Copy [`backend.tf.sample`](backend.tf.sample) to `backend.tf`:
   ```bash
   cp backend.tf.sample backend.tf
   ```
3. Replace `BUCKETNAME` in `backend.tf` with the output value from step 1:
   ```hcl
   terraform {
     backend "gcs" {
       bucket = "<YOUR_GENERATED_BUCKET_NAME>"
       prefix = "terraform/state"
     }
   }
   ```
4. Re-initialize Terraform to migrate your local state file into the new GCS bucket:
   ```bash
   terraform init -migrate-state
   ```
   When prompted by Terraform, type `yes` to copy the existing local state to the remote Cloud Storage bucket.
5. Verify that the remote state backend is active:
   ```bash
   terraform show
   ```
   Once verified, you can safely delete the leftover local `terraform.tfstate` and `terraform.tfstate.backup` files.

---

## Terraform Reference

### Requirements

| Name | Version |
| :--- | :--- |
| `terraform` | `>= 1.5.0` |
| `google` | `>= 5.0, < 7.0` |
| `random` | `~> 3.6` |

### Providers

| Name | Source | Version |
| :--- | :--- | :--- |
| `google` | `hashicorp/google` | `>= 5.0, < 7.0` |
| `random` | `hashicorp/random` | `~> 3.6` |

### Resources

| Name | Type |
| :--- | :--- |
| `google_project_service.cloudresourcemanager` | resource |
| `google_project_service.storage` | resource |
| `google_storage_bucket.tf_state_storage` | resource |
| `random_id.bucket_prefix` | resource |

### Inputs

| Name | Description | Type | Default | Required |
| :--- | :--- | :--- | :--- | :---: |
| `gcp_project_id` | The ID of the Google Cloud project where the state bucket will be created. | `string` | n/a | **yes** |
| `gcp_region` | Default Google Cloud region for the provider. | `string` | `"europe-west4"` | no |
| `bucket_location` | Location for the GCS state bucket (e.g., `'EU'`, `'US'`, `'ASIA'`, or a specific region like `'europe-west4'`). | `string` | `"EU"` | no |
| `storage_class` | Storage class of the GCS state bucket (`STANDARD`, `MULTI_REGIONAL`, `REGIONAL`, `NEARLINE`, `COLDLINE`, `ARCHIVE`). | `string` | `"STANDARD"` | no |
| `noncurrent_version_retention_count` | Number of noncurrent (historical) Terraform state file versions to retain before automatic cleanup. | `number` | `10` | no |

### Outputs

| Name | Description |
| :--- | :--- |
| `state_bucket_name` | The name of the created Google Cloud Storage bucket for Terraform state. |
| `state_bucket_url` | The base URL of the created Google Cloud Storage bucket (`gs://<bucket_name>`). |

---

VAMOS, happy coding! :smiley: