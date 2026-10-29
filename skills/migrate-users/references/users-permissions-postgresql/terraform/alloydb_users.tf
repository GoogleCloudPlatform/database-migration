resource "google_alloydb_user" "built_in_users" {
  for_each = var.built_in_users

  cluster        = "projects/${var.project_id}/locations/${var.region}/clusters/${var.alloydb_cluster_id}"
  user_id        = each.key
  user_type      = "ALLOYDB_BUILT_IN"
  password       = each.value.password
  database_roles = each.value.database_roles
}

resource "google_alloydb_user" "iam_users" {
  for_each = var.iam_users

  cluster        = "projects/${var.project_id}/locations/${var.region}/clusters/${var.alloydb_cluster_id}"
  user_id        = each.key
  user_type      = "ALLOYDB_IAM_USER"
  database_roles = each.value.database_roles
}
