locals {
  manifest   = yamldecode(file("${path.module}/../conf/manifest.yaml"))
  env_config = yamldecode(file("${path.module}/../conf/env/${var.env}.yaml"))

  app_name = local.manifest.app_name
  project_list = merge(
    {
      process     = local.env_config.project_list.raw
      marketplace = local.env_config.project_list.raw
    },
    local.env_config.project_list
  )
  main_project_id   = local.project_list[local.env_config.main_project_key]
  bigquery_location = local.manifest.bigquery_location
  labels            = merge(try(local.env_config.labels, {}), { managed_by = "terraform" })
  nyc_taxi_source   = local.env_config.nyc_taxi_source
  enabled_api_matrix = flatten([
    for project in distinct(values(local.project_list)) : [
      for api in local.manifest.enabled_services : {
        key     = "${project}/${api}"
        project = project
        api     = api
      }
    ]
  ])

  common_template_vars = {
    app_name                   = local.app_name
    env                        = var.env
    region                     = local.manifest.region
    bigquery_location          = local.bigquery_location
    github_repo                = local.manifest.github_repo
    git_commitish              = local.manifest.git_commitish
    dataform_enable_git_remote = local.manifest.dataform_enable_git_remote
    raw_project                = local.project_list.raw
    process_project            = local.project_list.process
    marketplace_project        = local.project_list.marketplace
    raw_dataset                = local.env_config.datasets.raw.dataset_id
    staging_dataset            = local.env_config.datasets.staging.dataset_id
    marts_dataset              = local.env_config.datasets.marts.dataset_id
    assertions_dataset         = local.env_config.datasets.assertions.dataset_id
    nyc_taxi_source_table      = local.nyc_taxi_source.yellow_table_id
  }

  dataform_repository = yamldecode(templatefile(
    "${path.module}/../components/dataform/resources/dataform_repositories.yaml",
    local.common_template_vars
  ))

  dataform_release_config = yamldecode(templatefile(
    "${path.module}/../components/dataform/resources/dataform_release_configs.yaml",
    merge(local.common_template_vars, {
      dataform_repository_name = local.dataform_repository.name
    })
  ))

  dataform_workspace = yamldecode(templatefile(
    "${path.module}/../components/dataform/resources/dataform_workspaces.yaml",
    merge(local.common_template_vars, {
      dataform_repository_name = local.dataform_repository.name
    })
  ))

  dataform_workflow_config = yamldecode(templatefile(
    "${path.module}/../components/dataform/resources/dataform_workflow_configs.yaml",
    merge(local.common_template_vars, {
      dataform_repository_name     = local.dataform_repository.name
      dataform_release_config_name = local.dataform_release_config.name
    })
  ))

  datasets = {
    raw = merge(local.env_config.datasets.raw, {
      project  = local.project_list.raw
      location = local.bigquery_location
      labels   = local.labels
    })
    staging = merge(local.env_config.datasets.staging, {
      project  = local.project_list.process
      location = local.bigquery_location
      labels   = local.labels
    })
    marts = merge(local.env_config.datasets.marts, {
      project  = local.project_list.marketplace
      location = local.bigquery_location
      labels   = local.labels
    })
    assertions = merge(local.env_config.datasets.assertions, {
      project  = local.project_list.process
      location = local.bigquery_location
      labels   = local.labels
    })
  }

  ingestion_bucket = {
    name          = "${local.app_name}-${var.env}-tlc-parquet-${local.project_list.raw}"
    project       = local.project_list.raw
    location      = local.manifest.region
    force_destroy = false
    labels        = local.labels
  }

  ingestion_config = {
    project            = local.project_list.raw
    region             = local.manifest.region
    bigquery_location  = local.bigquery_location
    app_name           = local.app_name
    env                = var.env
    bucket_name        = local.ingestion_bucket.name
    raw_dataset        = local.env_config.datasets.raw.dataset_id
    yellow_table_id    = local.nyc_taxi_source.yellow_table_id
    source_base_url    = local.nyc_taxi_source.base_url
    yellow_months      = local.nyc_taxi_source.yellow_months
    scheduler_region   = local.nyc_taxi_source.scheduler_region
    scheduler_cron     = local.nyc_taxi_source.scheduler_cron
    scheduler_timezone = local.nyc_taxi_source.scheduler_timezone
    labels             = local.labels
  }
}

resource "google_project_service" "apis" {
  for_each = { for item in local.enabled_api_matrix : item.key => item }

  project            = each.value.project
  service            = each.value.api
  disable_on_destroy = false
}

module "bigquery_datasets" {
  for_each = local.datasets
  source   = "../modules/bigquery"

  dataset = each.value

  depends_on = [google_project_service.apis]
}

module "ingestion_bucket" {
  source = "../modules/storage"

  bucket = local.ingestion_bucket

  depends_on = [google_project_service.apis]
}

module "nyc_taxi_ingestion" {
  source = "../modules/nyc_taxi_ingestion"

  ingestion = local.ingestion_config

  depends_on = [
    google_project_service.apis,
    module.bigquery_datasets,
    module.ingestion_bucket
  ]
}

module "dataform" {
  source = "../modules/dataform"

  app_name        = local.app_name
  env             = var.env
  repository      = local.dataform_repository
  release_config  = local.dataform_release_config
  workspace       = local.dataform_workspace
  workflow_config = local.dataform_workflow_config
  project_list    = local.project_list
  labels          = local.labels

  depends_on = [
    google_project_service.apis,
    module.bigquery_datasets
  ]
}

module "iam_dataform" {
  source = "../modules/iam"

  project_roles = {
    dataform_raw_viewer = {
      project = local.project_list.raw
      role    = "roles/bigquery.dataViewer"
      member  = module.dataform.service_account_member
    }
    dataform_process_editor = {
      project = local.project_list.process
      role    = "roles/bigquery.dataEditor"
      member  = module.dataform.service_account_member
    }
    dataform_process_job_user = {
      project = local.project_list.process
      role    = "roles/bigquery.jobUser"
      member  = module.dataform.service_account_member
    }
    dataform_marketplace_editor = {
      project = local.project_list.marketplace
      role    = "roles/bigquery.dataEditor"
      member  = module.dataform.service_account_member
    }
    dataform_marketplace_job_user = {
      project = local.project_list.marketplace
      role    = "roles/bigquery.jobUser"
      member  = module.dataform.service_account_member
    }
  }
}
