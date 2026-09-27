# cloudstorage-terraform-state-backend

By default, Terraform stores its state file (`terraform.tfstate`) locally on your computer. That works fine when you're experimenting on your own, but as soon as you work in a team or run pipelines, you need a shared, secure place to store that state.

This repository helps you spin up a **Google Cloud Storage (GCS)** bucket configured specifically for Terraform state, and includes a [`backend.tf.sample`](backend.tf.sample) file so you can easily move your local state into the cloud.

### What this setup does for you
- **Enables the required GCP APIs** automatically (Cloud Resource Manager and Cloud Storage).
- **Creates a globally unique bucket name** (`<random-hex>-bucket-tfstate`) so you don't run into naming conflicts.
- **Keeps your state safe and private** by blocking public access, enforcing IAM-only permissions (uniform bucket-level access), and preventing accidental bucket deletion (`force_destroy = false`).
- **Turns on object versioning** so you can recover previous state files if something goes wrong, while automatically cleaning up old versions (keeping the latest 10 by default) so you don't pay for clutter.

---

## Before you start

Make sure you have:
1. **[Terraform](https://developer.hashicorp.com/terraform/install)** (`v1.5.0` or newer) and the **[Google Cloud CLI (`gcloud`)](https://cloud.google.com/sdk/docs/install)** installed on your machine.
2. **A Google Cloud project** where you want to host the state bucket.
3. **The right permissions** on your Google Cloud account. Giving your account the **Storage Admin** (`roles/storage.admin`) and **Service Usage Admin** (`roles/serviceusage.serviceUsageAdmin`) roles covers everything needed, or you can grant these specific permissions:
   - `serviceusage.services.enable` & `serviceusage.services.get` (to enable the Storage and Resource Manager APIs)
   - `storage.buckets.create`, `storage.buckets.get`, `storage.buckets.list`, `storage.buckets.update`
   - `storage.objects.create`, `storage.objects.delete`, `storage.objects.get`, `storage.objects.update`

---

## Step-by-step guide

### 1. Log in to Google Cloud
Instead of downloading service account JSON keys to your laptop (which are easy to leak), log in directly with your Google Cloud CLI using Application Default Credentials:

```bash
gcloud auth application-default login
```

> **Tip:** Running this in CI/CD (like GitHub Actions or GitLab)? Use [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation) instead of static key files.

### 2. Set your Google Cloud Project ID
Create a `terraform.tfvars` file in the root of this project and add your GCP project ID (don't worry—`*.tfvars` files are already in `.gitignore` so you won't accidentally commit it):

```hcl
gcp_project_id = "your-gcp-project-id"
```

By default, the bucket is created in the **`EU`** multi-region using the **`europe-west4`** provider region. If you'd like to customize the location or retention settings, you can also add any of these optional variables to your `terraform.tfvars` file:

| Variable | What it does | Default |
| :--- | :--- | :--- |
| `gcp_project_id` | **Required.** Your Google Cloud project ID. | — |
| `gcp_region` | Default region used by the Google provider. | `"europe-west4"` |
| `bucket_location` | Where the GCS bucket lives (e.g., `"EU"`, `"US"`, `"europe-west4"`). | `"EU"` |
| `storage_class` | Storage tier for the bucket (`STANDARD`, `NEARLINE`, `COLDLINE`, etc.). | `"STANDARD"` |
| `noncurrent_version_retention_count` | How many old versions of your state file to keep before cleaning them up. | `10` |

### 3. Create the Cloud Storage bucket
Initialize Terraform and apply the configuration to create your bucket:

```bash
terraform init
terraform apply
```

Review the plan when prompted, type `yes`, and Terraform will enable the APIs and create your bucket.

### 4. Grab your new bucket's name
Once `terraform apply` finishes, it will print out the name of your newly created bucket (`state_bucket_name`). You can also grab it anytime by running:

```bash
terraform output -raw state_bucket_name
```

### 5. Switch your backend to the new bucket
Now that the bucket exists, tell Terraform to store its state inside it:

1. Copy [`backend.tf.sample`](backend.tf.sample) to a new file named `backend.tf`:
   ```bash
   cp backend.tf.sample backend.tf
   ```
2. Open `backend.tf` and replace `BUCKETNAME` with the bucket name from Step 4:
   ```hcl
   terraform {
     backend "gcs" {
       bucket = "your-generated-bucket-name-tfstate"
       prefix = "terraform/state"
     }
   }
   ```
3. Run `terraform init` with the `-migrate-state` flag:
   ```bash
   terraform init -migrate-state
   ```
   Terraform will detect your local state file and ask if you want to copy it to your new Cloud Storage bucket. Type `yes` and press Enter.

### 6. Verify everything works
Run the following command to confirm Terraform is now reading the state directly from Google Cloud Storage:

```bash
terraform show
```

You should see the details of your current state. At this point, your state is safely stored in GCS, and you can delete the leftover local `terraform.tfstate` and `terraform.tfstate.backup` files from your folder if you'd like.

VAMOS, happy coding! :smiley: