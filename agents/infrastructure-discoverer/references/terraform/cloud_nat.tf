# Example Terraform configuration to create a Cloud Router and Cloud NAT

variable "project_id" {
  description = "The ID of the project where resources will be created"
  type        = string
}

variable "region" {
  description = "The region where the Cloud Router and NAT will be created"
  type        = string
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
}

variable "subnet_id" {
  description = "The self_link or name of the subnetwork that the NAT will be applied to"
  type        = string
}

resource "google_compute_router" "router" {
  name    = "dms-cloud-router"
  region  = var.region
  network = var.network_name
  project = var.project_id
}

# Allocate a static external IP address (to allowlist on the source database)
resource "google_compute_address" "nat_ip" {
  name    = "dms-nat-ip"
  region  = var.region
  project = var.project_id
}

resource "google_compute_router_nat" "nat" {
  name                               = "dms-cloud-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  project                            = var.project_id
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat_ip.self_link]
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = var.subnet_id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
