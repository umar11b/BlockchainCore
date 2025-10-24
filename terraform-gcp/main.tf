# GCP Multi-Cloud Infrastructure for BlockchainCore
# This creates a parallel GCP stack to complement the existing AWS infrastructure

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

# Random string for unique resource naming
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Variables are defined in variables.tf

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "pubsub.googleapis.com",
    "cloudfunctions.googleapis.com",
    "firestore.googleapis.com",
    "storage.googleapis.com",
    "cloudscheduler.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com"
  ])

  project = var.gcp_project_id
  service = each.value

  disable_dependent_services = false
}

# Cloud Storage bucket for raw data
resource "google_storage_bucket" "raw_data" {
  name          = "${var.project_name}-raw-data-${random_string.bucket_suffix.result}"
  location      = "US"
  force_destroy = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.required_apis]
}

# Cloud Pub/Sub topic for trade data
resource "google_pubsub_topic" "trade_data" {
  name = "${var.project_name}-trade-data"

  depends_on = [google_project_service.required_apis]
}

# Cloud Pub/Sub subscription for trade data
resource "google_pubsub_subscription" "trade_data_subscription" {
  name  = "${var.project_name}-trade-data-subscription"
  topic = google_pubsub_topic.trade_data.name

  ack_deadline_seconds = 20

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
}

# Firestore database for processed data
resource "google_firestore_database" "ohlcv_data" {
  project     = var.gcp_project_id
  name        = "${var.project_name}-ohlcv-data"
  location_id = var.gcp_region
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.required_apis]
}

# Cloud Function for processing trade data
resource "google_storage_bucket" "function_bucket" {
  name          = "${var.project_name}-functions-${random_string.bucket_suffix.result}"
  location      = "US"
  force_destroy = true
}

# Cloud Function source code
resource "google_storage_bucket_object" "function_source" {
  name   = "processor.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "../src/lambda/processor-gcp/processor.zip"
}

# Cloud Function
resource "google_cloudfunctions2_function" "processor" {
  name        = "${var.project_name}-processor"
  location    = var.gcp_region
  description = "Process trade data from Pub/Sub and store in Firestore"

  build_config {
    runtime     = "python311"
    entry_point = "process_trade_data"
      source {
        storage_source {
          bucket = google_storage_bucket.function_bucket.name
          object = "processor.zip"
        }
      }
  }

  service_config {
    max_instance_count = 10
    available_memory   = "256M"
    timeout_seconds   = 60
    service_account_email = google_service_account.function_sa.email
    environment_variables = {
      FIRESTORE_DATABASE = google_firestore_database.ohlcv_data.name
    }
  }

  event_trigger {
    trigger_region = var.gcp_region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.trade_data.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }

  depends_on = [
    google_project_service.required_apis,
    google_storage_bucket_object.function_source
  ]
}

# Cloud Scheduler for periodic tasks (replaces EventBridge)
resource "google_cloud_scheduler_job" "monitoring_job" {
  name        = "${var.project_name}-monitoring"
  description = "Periodic monitoring and cleanup tasks"
  schedule    = "0 */6 * * *"  # Every 6 hours
  time_zone   = "UTC"

  pubsub_target {
    topic_name = google_pubsub_topic.trade_data.id
    data = base64encode(jsonencode({
      "action" = "monitoring_check"
      "timestamp" = "{{.Timestamp}}"
    }))
  }

  depends_on = [google_project_service.required_apis]
}

# IAM service account for Cloud Functions
resource "google_service_account" "function_sa" {
  account_id   = "${var.project_name}-function-sa"
  display_name = "BlockchainCore Function Service Account"
}

# IAM bindings for the service account
resource "google_project_iam_member" "function_firestore" {
  project = var.gcp_project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

resource "google_project_iam_member" "function_storage" {
  project = var.gcp_project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# Cloud Logging for monitoring
resource "google_logging_project_sink" "trade_data_sink" {
  name        = "${var.project_name}-trade-data-sink"
  destination = "pubsub.googleapis.com/${google_pubsub_topic.trade_data.id}"

  filter = "resource.type=\"cloud_function\" AND resource.labels.function_name=\"${google_cloudfunctions2_function.processor.name}\""

  unique_writer_identity = true
}

# Outputs are defined in outputs.tf
