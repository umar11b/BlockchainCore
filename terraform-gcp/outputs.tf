# GCP Terraform Outputs

output "gcp_project_id" {
  description = "GCP Project ID"
  value       = var.gcp_project_id
}

output "pubsub_topic_name" {
  description = "Pub/Sub topic name for trade data"
  value       = google_pubsub_topic.trade_data.name
}

output "pubsub_topic_id" {
  description = "Pub/Sub topic ID for trade data"
  value       = google_pubsub_topic.trade_data.id
}

output "firestore_database_name" {
  description = "Firestore database name"
  value       = google_firestore_database.ohlcv_data.name
}

output "storage_bucket_name" {
  description = "Cloud Storage bucket name for raw data"
  value       = google_storage_bucket.raw_data.name
}

output "cloud_function_name" {
  description = "Cloud Function name for processing"
  value       = google_cloudfunctions2_function.processor.name
}

output "cloud_function_url" {
  description = "Cloud Function URL"
  value       = google_cloudfunctions2_function.processor.service_config[0].uri
}

output "service_account_email" {
  description = "Service account email for Cloud Functions"
  value       = google_service_account.function_sa.email
}

output "gcp_region" {
  description = "GCP region"
  value       = var.gcp_region
}

output "gcp_zone" {
  description = "GCP zone"
  value       = var.gcp_zone
}
