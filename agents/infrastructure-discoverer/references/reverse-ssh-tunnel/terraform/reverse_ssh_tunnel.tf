variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "network_name" {
  type    = string
  default = "default"
}

variable "subnet_name" {
  type    = string
  default = "default"
}

variable "db_port" {
  type    = string
  default = "5432" # Adjust to match your database port
}

# Firewall rule to allow Identity-Aware Proxy (IAP) SSH access
resource "google_compute_firewall" "allow_ssh_from_iap" {
  name    = "allow-ssh-ingress-from-iap"
  project = var.project_id
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
}

# Firewall rule to allow DMS network attachment to reach the bastion on the database port
resource "google_compute_firewall" "allow_dms_to_bastion" {
  name    = "allow-dms-to-bastion"
  project = var.project_id
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = [var.db_port]
  }

  target_tags = ["dms-bastion"]
}

# Bastion VM without a public IP
resource "google_compute_instance" "bastion_vm" {
  name         = "dms-bastion-vm"
  project      = var.project_id
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network    = var.network_name
    subnetwork = var.subnet_name
    # Leaving out access_config creates a VM without a public IP
  }

  tags = ["dms-bastion"]

  metadata = {
    enable-oslogin = "true"
    startup-script = <<-EOT
      #! /bin/bash
      sed -i 's/^#*GatewayPorts.*/GatewayPorts yes/' /etc/ssh/sshd_config
      systemctl restart sshd
    EOT
  }
}
