resource "google_project_service_identity" "dataform" {
  provider = google-beta

  project = var.project_list.process
  service = "dataform.googleapis.com"
}

resource "google_service_account" "dataform" {
  project      = var.project_list.process
  account_id   = "sa-${var.env}-${var.app_name}-dataform"
  display_name = "Dataform service account for ${var.app_name} ${var.env}"
}

resource "google_service_account_iam_member" "dataform_token_creator" {
  service_account_id = google_service_account.dataform.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_project_service_identity.dataform.email}"
}

resource "google_secret_manager_secret" "git_deploy_key" {
  count = try(var.repository.enable_git_remote, false) ? 1 : 0

  project   = var.project_list.process
  secret_id = "sms-${var.env}-${var.app_name}-dataform-deploy-key"
  labels    = var.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "git_deploy_key_accessor" {
  count = try(var.repository.enable_git_remote, false) ? 1 : 0

  project   = var.project_list.process
  secret_id = google_secret_manager_secret.git_deploy_key[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_project_service_identity.dataform.email}"
}

resource "google_dataform_repository" "default" {
  provider = google-beta

  project         = var.repository.project
  region          = var.repository.region
  name            = var.repository.name
  service_account = google_service_account.dataform.email
  labels          = var.labels

  dynamic "git_remote_settings" {
    for_each = try(var.repository.enable_git_remote, false) ? [var.repository.git] : []
    content {
      url            = git_remote_settings.value.url
      default_branch = git_remote_settings.value.default_branch

      ssh_authentication_config {
        user_private_key_secret_version = "${google_secret_manager_secret.git_deploy_key[0].id}/versions/latest"
        host_public_key                 = git_remote_settings.value.host_key
      }
    }
  }

  depends_on = [
    google_service_account_iam_member.dataform_token_creator,
    google_secret_manager_secret_iam_member.git_deploy_key_accessor
  ]
}

resource "google_dataform_repository_release_config" "default" {
  provider = google-beta

  project    = var.release_config.project
  region     = var.release_config.region
  repository = google_dataform_repository.default.name

  name          = var.release_config.name
  git_commitish = var.release_config.git_commitish
  cron_schedule = try(var.release_config.cron_schedule, null)
  time_zone     = try(var.release_config.timezone, null)

  code_compilation_config {
    default_database = var.release_config.code_compilation_config.default_database
    default_schema   = var.release_config.code_compilation_config.default_schema
    default_location = var.release_config.code_compilation_config.default_location
    assertion_schema = var.release_config.code_compilation_config.assertion_schema
    vars             = var.release_config.code_compilation_config.vars
  }
}

resource "terraform_data" "workspace" {
  input = {
    project    = var.workspace.project
    region     = var.workspace.region
    repository = google_dataform_repository.default.name
    name       = var.workspace.name
  }

  triggers_replace = [
    var.workspace.project,
    var.workspace.region,
    google_dataform_repository.default.name,
    var.workspace.name
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      parent="projects/${self.input.project}/locations/${self.input.region}/repositories/${self.input.repository}"
      token="$(gcloud auth print-access-token)"
      workspace_url="https://dataform.googleapis.com/v1/$${parent}/workspaces/${self.input.name}"
      create_url="https://dataform.googleapis.com/v1/$${parent}/workspaces?workspaceId=${self.input.name}"

      if ! curl -fsS \
        -H "Authorization: Bearer $${token}" \
        "$${workspace_url}" >/dev/null; then
        curl -fsS \
          -X POST \
          -H "Authorization: Bearer $${token}" \
          -H "Content-Type: application/json" \
          -d '{}' \
          "$${create_url}" >/dev/null
      fi
    EOT
  }

  depends_on = [google_dataform_repository.default]
}

resource "google_dataform_repository_workflow_config" "default" {
  provider = google-beta

  project    = var.workflow_config.project
  region     = var.workflow_config.region
  repository = google_dataform_repository.default.name

  name           = var.workflow_config.name
  release_config = google_dataform_repository_release_config.default.id
  cron_schedule  = var.workflow_config.cron_schedule
  time_zone      = var.workflow_config.timezone

  invocation_config {
    included_tags                            = var.workflow_config.invocation_config.included_tags
    transitive_dependencies_included         = var.workflow_config.invocation_config.transitive_dependencies_included
    transitive_dependents_included           = var.workflow_config.invocation_config.transitive_dependents_included
    fully_refresh_incremental_tables_enabled = var.workflow_config.invocation_config.fully_refresh_incremental_tables_enabled
    service_account                          = google_service_account.dataform.email
  }
}
