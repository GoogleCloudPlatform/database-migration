terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.37.0"
    }
  }
}

resource "google_database_migration_service_connection_profile" "dest_pg" {
  project               = var.project_id
  location              = var.region
  connection_profile_id = "dest-pg-cp-${var.suffix}"
  display_name          = "dest-pg-cp-${var.suffix}"
  role                  = "DESTINATION"

  labels = {
    agent = var.agent_name
  }

  postgresql {
    username     = var.dms_user
    password     = var.dms_pass
    cloud_sql_id = var.cloud_sql_id
  }
}
