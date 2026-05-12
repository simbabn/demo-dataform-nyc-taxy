variable "app_name" {
  description = "Application name."
  type        = string
}

variable "env" {
  description = "Environment name."
  type        = string
}

variable "project_list" {
  description = "GCP projects used by the platform."
  type        = map(string)
}

variable "labels" {
  description = "Labels applied to supported resources."
  type        = map(string)
  default     = {}
}

variable "repository" {
  description = "Dataform repository configuration."
  type = object({
    name              = string
    project           = string
    region            = string
    enable_git_remote = optional(bool, false)
    git = optional(object({
      url            = string
      default_branch = string
      host_key       = string
    }))
  })
}

variable "release_config" {
  description = "Dataform release configuration."
  type = object({
    name          = string
    project       = string
    region        = string
    git_commitish = string
    cron_schedule = optional(string)
    timezone      = optional(string)
    repository = object({
      name = string
    })
    code_compilation_config = object({
      default_database = string
      default_schema   = string
      default_location = string
      assertion_schema = string
      vars             = map(string)
    })
  })
}

variable "workspace" {
  description = "Dataform development workspace configuration."
  type = object({
    name    = string
    project = string
    region  = string
    repository = object({
      name = string
    })
  })
}

variable "workflow_config" {
  description = "Dataform workflow configuration."
  type = object({
    name           = string
    project        = string
    region         = string
    release_config = string
    cron_schedule  = string
    timezone       = string
    repository = object({
      name = string
    })
    invocation_config = object({
      included_tags                            = list(string)
      transitive_dependencies_included         = bool
      transitive_dependents_included           = bool
      fully_refresh_incremental_tables_enabled = bool
    })
  })
}
