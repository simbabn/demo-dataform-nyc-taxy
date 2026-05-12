variable "ingestion" {
  description = "NYC TLC Parquet ingestion configuration."
  type = object({
    project            = string
    region             = string
    bigquery_location  = string
    app_name           = string
    env                = string
    bucket_name        = string
    raw_dataset        = string
    yellow_table_id    = string
    source_base_url    = string
    yellow_months      = list(string)
    scheduler_region   = string
    scheduler_cron     = string
    scheduler_timezone = string
    labels             = optional(map(string), {})
  })
}
