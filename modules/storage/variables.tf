variable "bucket" {
  description = "Cloud Storage bucket configuration."
  type = object({
    name          = string
    project       = string
    location      = string
    force_destroy = optional(bool, false)
    labels        = optional(map(string), {})
  })
}
