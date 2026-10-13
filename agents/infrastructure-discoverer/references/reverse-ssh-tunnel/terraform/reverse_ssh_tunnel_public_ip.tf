# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "project_id" {
  description = "The project id."
  type        = string
}

variable "region" {
  description = "The region."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The zone."
  type        = string
  default     = "us-central1-a"
}

variable "network_name" {
  description = "The network name."
  type        = string
  default     = "default"
}

variable "subnet_name" {
  description = "The subnet name."
  type        = string
  default     = "default"
}

variable "db_port" {
  description = "The db port."
  type        = string
  default     = "5432" # Adjust to match your database port
}

variable "local_machine_ip" {
  description = "The public IP of your local machine, allowed to SSH into the Bastion."
  type        = string
}

# Firewall rule to allow SSH access from the local machine's IP
resource "google_compute_firewall" "allow_ssh_from_local" {
  name    = "allow-ssh-ingress-from-local"
  project = var.project_id
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.local_machine_ip]
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

# Bastion VM with a public IP
resource "google_compute_instance" "bastion_vm" {
  name         = "dms-bastion-vm-public"
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

    # Adding access_config provisions a public IP
    access_config {
      // Ephemeral public IP
    }
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
