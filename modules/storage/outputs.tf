output "bucket_name" {
  description = "Bucket name."
  value       = google_storage_bucket.default.name
}
