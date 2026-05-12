locals {
  service_account_id = "sa-${var.ingestion.env}-${var.ingestion.app_name}-ingest"
  job_name           = "crj-${var.ingestion.env}-${var.ingestion.app_name}-ingest"
  scheduler_name     = "sch-${var.ingestion.env}-${var.ingestion.app_name}-ingest"
  yellow_months      = join(" ", var.ingestion.yellow_months)
}

resource "google_service_account" "ingestion" {
  project      = var.ingestion.project
  account_id   = local.service_account_id
  display_name = "NYC taxi ingestion service account"
}

resource "google_storage_bucket_iam_member" "object_admin" {
  bucket = var.ingestion.bucket_name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.ingestion.member
}

resource "google_project_iam_member" "bigquery_job_user" {
  project = var.ingestion.project
  role    = "roles/bigquery.jobUser"
  member  = google_service_account.ingestion.member
}

resource "google_project_iam_member" "bigquery_data_editor" {
  project = var.ingestion.project
  role    = "roles/bigquery.dataEditor"
  member  = google_service_account.ingestion.member
}

resource "google_project_iam_member" "logs_writer" {
  project = var.ingestion.project
  role    = "roles/logging.logWriter"
  member  = google_service_account.ingestion.member
}

resource "google_cloud_run_v2_job" "ingestion" {
  project             = var.ingestion.project
  location            = var.ingestion.region
  name                = local.job_name
  labels              = try(var.ingestion.labels, {})
  deletion_protection = false

  template {
    template {
      service_account = google_service_account.ingestion.email
      timeout         = "3600s"
      max_retries     = 1

      containers {
        image   = "gcr.io/google.com/cloudsdktool/google-cloud-cli:slim"
        command = ["/bin/bash"]
        args = [
          "-ceu",
          <<-EOT
          for month in $YELLOW_MONTHS; do
            file="yellow_tripdata_$${month}.parquet"
            url="$SOURCE_BASE_URL/$${file}"
            object="gs://$BUCKET_NAME/tlc/yellow/$${file}"
            if ! gsutil -q stat "$${object}"; then
              curl --fail --location --retry 3 --output "/tmp/$${file}" "$${url}"
              gsutil -q cp "/tmp/$${file}" "$${object}"
              rm -f "/tmp/$${file}"
            fi
          done

          bq --location="$BIGQUERY_LOCATION" load \
            --replace \
            --source_format=PARQUET \
            --time_partitioning_type=DAY \
            --time_partitioning_field=tpep_pickup_datetime \
            "$PROJECT_ID:$RAW_DATASET.$YELLOW_TABLE_ID" \
            "gs://$BUCKET_NAME/tlc/yellow/*.parquet"
          EOT
        ]

        env {
          name  = "PROJECT_ID"
          value = var.ingestion.project
        }
        env {
          name  = "BIGQUERY_LOCATION"
          value = var.ingestion.bigquery_location
        }
        env {
          name  = "BUCKET_NAME"
          value = var.ingestion.bucket_name
        }
        env {
          name  = "RAW_DATASET"
          value = var.ingestion.raw_dataset
        }
        env {
          name  = "YELLOW_TABLE_ID"
          value = var.ingestion.yellow_table_id
        }
        env {
          name  = "SOURCE_BASE_URL"
          value = var.ingestion.source_base_url
        }
        env {
          name  = "YELLOW_MONTHS"
          value = local.yellow_months
        }

        resources {
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
      }
    }
  }

  depends_on = [
    google_project_iam_member.bigquery_job_user,
    google_project_iam_member.bigquery_data_editor,
    google_storage_bucket_iam_member.object_admin
  ]
}

resource "google_cloud_run_v2_job_iam_member" "scheduler_invoker" {
  project  = var.ingestion.project
  location = var.ingestion.region
  name     = google_cloud_run_v2_job.ingestion.name
  role     = "roles/run.invoker"
  member   = google_service_account.ingestion.member
}

resource "google_cloud_scheduler_job" "ingestion" {
  project     = var.ingestion.project
  region      = var.ingestion.scheduler_region
  name        = local.scheduler_name
  description = "Run NYC TLC Parquet ingestion into BigQuery"
  schedule    = var.ingestion.scheduler_cron
  time_zone   = var.ingestion.scheduler_timezone

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${var.ingestion.project}/locations/${var.ingestion.region}/jobs/${google_cloud_run_v2_job.ingestion.name}:run"

    oauth_token {
      service_account_email = google_service_account.ingestion.email
    }
  }

  depends_on = [google_cloud_run_v2_job_iam_member.scheduler_invoker]
}
