resource "google_storage_bucket" "default" {
  project                     = var.bucket.project
  name                        = var.bucket.name
  location                    = var.bucket.location
  force_destroy               = try(var.bucket.force_destroy, false)
  uniform_bucket_level_access = true
  labels                      = try(var.bucket.labels, {})

  versioning {
    enabled = false
  }
}
