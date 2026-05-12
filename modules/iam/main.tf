resource "google_project_iam_member" "project_roles" {
  for_each = var.project_roles

  project = each.value.project
  role    = each.value.role
  member  = each.value.member
}
