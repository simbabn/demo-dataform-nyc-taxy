output "repository_name" {
  description = "Dataform repository name."
  value       = google_dataform_repository.default.name
}

output "workspace_name" {
  description = "Dataform development workspace name."
  value       = terraform_data.workspace.input.name
}

output "service_account_email" {
  description = "Dataform service account email."
  value       = google_service_account.dataform.email
}

output "service_account_member" {
  description = "IAM member for the Dataform service account."
  value       = google_service_account.dataform.member
}
