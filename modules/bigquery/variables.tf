variable "dataset" {
  description = "BigQuery dataset configuration."
  type = object({
    project     = string
    dataset_id  = string
    location    = string
    description = optional(string)
    labels      = optional(map(string), {})
  })
}
