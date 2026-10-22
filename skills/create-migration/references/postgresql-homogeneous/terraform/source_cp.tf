terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.37.0"
    }
  }
}

resource "google_database_migration_service_connection_profile" "source_pg" {
  project               = var.project_id
  location              = var.region
  connection_profile_id = "source-pg-cp-${var.suffix}"
  display_name          = "source-pg-cp-${var.suffix}"
  role                  = "SOURCE"

  labels = {
    agent = var.agent_name
  }

  postgresql {
    host     = var.source_instance_ip
    port     = var.source_port
    username = var.source_user
    password = var.source_password

    private_connectivity {
      private_connection = google_database_migration_service_private_connection.default.id
    }

    ssl {
      type = "REQUIRED"
    }
  }
}
