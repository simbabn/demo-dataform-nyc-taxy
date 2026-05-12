provider "google" {
  project = local.main_project_id
  region  = local.manifest.region
}

provider "google-beta" {
  project = local.main_project_id
  region  = local.manifest.region
}
