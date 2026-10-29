resource "google_sql_user" "built_in_users" {
  for_each = var.built_in_users

  project  = var.project_id
  instance = var.cloud_sql_id
  name     = each.key
  type     = "BUILT_IN"
  password = each.value.password
}

resource "google_sql_user" "iam_users" {
  for_each = toset(var.iam_users)

  project  = var.project_id
  instance = var.cloud_sql_id
  name     = each.value
  type     = "CLOUD_IAM_USER"
}

resource "google_sql_user" "iam_service_accounts" {
  for_each = toset(var.iam_service_accounts)

  project  = var.project_id
  instance = var.cloud_sql_id
  name     = trimsuffix(each.value, ".gserviceaccount.com")
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}
