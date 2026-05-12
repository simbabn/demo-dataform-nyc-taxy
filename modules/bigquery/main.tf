resource "google_bigquery_dataset" "default" {
  project                    = var.dataset.project
  dataset_id                 = var.dataset.dataset_id
  location                   = var.dataset.location
  description                = try(var.dataset.description, null)
  labels                     = try(var.dataset.labels, {})
  delete_contents_on_destroy = false
}
