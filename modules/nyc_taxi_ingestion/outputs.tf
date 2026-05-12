output "job_name" {
  description = "Cloud Run Job name."
  value       = google_cloud_run_v2_job.ingestion.name
}

output "scheduler_name" {
  description = "Cloud Scheduler job name."
  value       = google_cloud_scheduler_job.ingestion.name
}
