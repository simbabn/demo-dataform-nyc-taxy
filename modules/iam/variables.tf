variable "project_roles" {
  description = "Project IAM bindings keyed by a stable name."
  type = map(object({
    project = string
    role    = string
    member  = string
  }))
  default = {}
}
