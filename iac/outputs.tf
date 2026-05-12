output "datasets" {
  description = "BigQuery datasets created by the stack."
  value       = { for key, dataset in module.bigquery_datasets : key => dataset.dataset_id }
}

output "dataform_repository" {
  description = "Dataform repository resource name."
  value       = module.dataform.repository_name
}

output "dataform_workspace" {
  description = "Dataform development workspace resource name."
  value       = module.dataform.workspace_name
}

output "dataform_service_account" {
  description = "Dedicated service account used by Dataform."
  value       = module.dataform.service_account_email
}

output "nyc_taxi_parquet_source" {
  description = "Official NYC TLC Parquet source used instead of CSV files."
  value = {
    base_url = local.nyc_taxi_source.base_url
    months   = local.nyc_taxi_source.yellow_months
  }
}

output "ingestion_bucket" {
  description = "GCS bucket used as the EU landing zone for TLC Parquet files."
  value       = module.ingestion_bucket.bucket_name
}

output "ingestion_job" {
  description = "Cloud Run Job used to ingest NYC TLC Parquet files into BigQuery."
  value       = module.nyc_taxi_ingestion.job_name
}
