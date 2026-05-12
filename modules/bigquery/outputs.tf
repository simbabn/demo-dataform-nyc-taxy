output "dataset_id" {
  description = "Dataset id."
  value       = google_bigquery_dataset.default.dataset_id
}

output "project" {
  description = "Dataset project."
  value       = google_bigquery_dataset.default.project
}
