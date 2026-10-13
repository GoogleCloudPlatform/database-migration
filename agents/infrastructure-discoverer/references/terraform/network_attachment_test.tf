# Description: Creates a Network Intelligence Center Connectivity Test to verify
# connectivity from a Network Attachment to a source database, and runs it to output the results.

# This example assumes you are using a data source to fetch an existing network attachment.
# If the network attachment is created in the same Terraform state, reference the resource directly
# (e.g., google_compute_network_attachment.dms_attachment.connection_endpoints[0].ip_address).

data "google_compute_network_attachment" "attachment" {
  name    = "your-network-attachment-name"
  project = "your-project-id"
  region  = "your-region"
}

resource "google_network_management_connectivity_test" "dms_test" {
  name    = "test-from-dms-attachment-${var.suffix}"
  project = "your-project-id"

  source {
    ip_address   = data.google_compute_network_attachment.attachment.connection_endpoints[0].ip_address
    network      = "projects/your-project-id/global/networks/${data.google_compute_network_attachment.attachment.network}"
    network_type = "GCP_NETWORK"
  }

  destination {
    ip_address = "your-source-database-ip"
    port       = "your-source-database-port"
  }

  protocol = "TCP"
}

# 1. Use the data source to trigger the run / fetch results
data "google_network_management_connectivity_test_run" "dms_test_run" {
  name    = google_network_management_connectivity_test.dms_test.name
  project = google_network_management_connectivity_test.dms_test.project
}

# 2. Output the result from the data source
output "test_reachability_result" {
  description = "The result of the connectivity test"
  value       = data.google_network_management_connectivity_test_run.dms_test_run.reachability_details[0].result
}

output "test_full_details" {
  description = "Full reachability analysis details"
  value       = data.google_network_management_connectivity_test_run.dms_test_run.reachability_details
}
